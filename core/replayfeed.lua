local _, ns = ...
local format = string.format
local band = bit.band
local tsort = table.sort
local concat = table.concat
local F_PLAYER = 0x400
local F_HOSTILE = 0x40
local RAW_LIMIT = 6000
local ROW_LIMIT = 2500
local MERGE = 1
local SAME = 3
local HERO_GAP = 10
local DEATH_NEAR = 1.5
local NAMES_MAX = 4
local FC = {}
ns.ReplayFeedCore = FC
local function Fill(set, list)
    if not list then return end
    if #list > 0 then
        for i = 1, #list do set[list[i]] = true end
    else
        for k, v in pairs(list) do
            if v then set[k] = true end
        end
    end
end
local function Ids(set, trig)
    if not trig then return end
    for k = 2, #trig do set[trig[k]] = true end
end
local function PhaseIds(boss)
    local set = {}
    local def = ns.bossPhases and ns.bossPhases[boss]
    if not def then return set end
    for j = 2, #(def.steps or {}) do
        local on = def.steps[j].on or {}
        for k = 1, #on do Ids(set, on[k]) end
    end
    for _, w in pairs(def.waves or {}) do Ids(set, w.on) end
    return set
end
local function KeyDispels(boss)
    local set = {}
    local FD = ns.replayFeed
    local b = FD.bosses[boss]
    Fill(set, b and b.dispels)
    local def = ns.summaries and ns.summaries[boss]
    for i = 1, def and def.blocks and #def.blocks or 0 do
        local bl = def.blocks[i]
        if bl.kind == "dispels" and bl.spell then set[bl.spell] = true end
        if bl.kind == "removed" then Fill(set, bl.spells) end
    end
    return set
end
function FC.New(fight)
    local FD = ns.replayFeed
    local D = ns.replayData
    local boss = fight.boss
    local b = FD.bosses[boss] or {}
    local casts, auras, defs, selfRez = {}, {}, {}, {}
    Fill(casts, D and D.feed and D.feed[boss])
    Fill(casts, b.casts)
    Fill(auras, b.auras)
    for i = 1, D and #D.states or 0 do
        local st = D.states[i]
        if st.feed and st.imp then auras[st.name] = true end
    end
    for _, d in pairs(ns.defensives or {}) do defs[d[1]] = true end
    local acts = ns.actions
    Fill(selfRez, acts and acts.selfRez)
    local db = ns.GetDB()
    return {
        fight = fight, from = fight.from, to = fight.to, players = fight.players or {},
        bosses = ns.Index.BossNames(fight), pets = db and db.pets or {}, owners = {},
        casts = casts, auras = auras, hits = b.hits or {}, keyDisp = KeyDispels(boss), skipIds = PhaseIds(boss),
        help = FD.help, hero = FD.hero, defs = defs, selfRez = selfRez, stone = acts and acts.stone,
        valkyr = D ~= nil and D.valkyr ~= nil and D.valkyr.boss == boss,
        veh = {}, dead = {}, stoneT = {}, last = {}, heroAt = -1e9, auraIds = {},
        r = { n = 0, t = {}, kind = {}, icon = {}, imp = {}, key = {}, head = {}, obj = {}, who = {}, text = {},
              tip = {} },
    }
end
local function Row(fc, ts, kind, icon, imp, key, head, obj, who, text, tip)
    local r = fc.r
    if r.n >= RAW_LIMIT then return end
    local n = r.n + 1
    r.n = n
    r.t[n], r.kind[n], r.icon[n], r.imp[n] = ts - fc.from, kind, icon or 0, imp and true or false
    r.key[n], r.head[n], r.obj[n], r.who[n] = key, head, obj, who
    r.text[n], r.tip[n] = text, tip or text
end
local function Fresh(fc, key, ts, gap)
    local last = fc.last[key]
    fc.last[key] = ts
    return not last or ts - last >= gap
end
local function WithClass(name)
    local cls = ns.Encounters.ClassOf(name)
    if not cls then return name end
    return format(ns.T("rep.f.class"), name, ns.T("cls." .. cls))
end
local function Actor(fc, srcGUID, src, srcFlags)
    if src and fc.players[src] then return src end
    if not srcGUID then return nil end
    local owner = fc.owners[srcGUID] or fc.pets[srcGUID]
    if owner and fc.players[owner] then return owner end
    return nil
end
local function Enemy(srcFlags)
    return srcFlags ~= nil and band(srcFlags, F_HOSTILE) > 0 and band(srcFlags, F_PLAYER) == 0
end
local function BossCast(fc, ts, dst, spell, id)
    local n = tonumber(id)
    if n and fc.skipIds[n] then return end
    if not Fresh(fc, "c" .. spell, ts, SAME) then return end
    local on = dst and fc.players[dst] and dst or false
    local text = on and format(ns.T("rep.f.cast"), spell, on) or spell
    Row(fc, ts, "boss", n, true, "b|" .. spell, spell, false, on, text)
end
local function BossAura(fc, ts, dst, spell, id)
    local c = fc.last["c" .. spell]
    if c and ts - c < SAME then return end
    if not Fresh(fc, "a" .. spell .. dst, ts, SAME) then return end
    local n = tonumber(id)
    if n then fc.auraIds[n] = true end
    Row(fc, ts, "boss", n, true, "b|" .. spell, spell, false, dst, format(ns.T("rep.f.on"), spell, dst))
end
local function BossHit(fc, ts, spell, id)
    local gap = fc.hits[spell]
    if not Fresh(fc, "h" .. spell, ts, gap) then return end
    Row(fc, ts, "boss", tonumber(id), true, "b|" .. spell, spell, false, false, spell)
end
local function Help(fc, ts, who, dst, spell, id)
    local to = dst and dst ~= who and fc.players[dst] and dst or nil
    if not Fresh(fc, "p" .. spell .. who .. (to or ""), ts, SAME) then return end
    local text, tip
    if to then
        text = format(ns.T("rep.f.given"), spell, to, who)
        tip = format(ns.T("rep.f.given"), spell, to, WithClass(who))
    else
        text = format(ns.T("rep.f.on"), spell, who)
        tip = format(ns.T("rep.f.on"), spell, WithClass(who))
    end
    Row(fc, ts, "help", tonumber(id), false, "p|" .. spell .. "|" .. who, spell, false, to or who, text, tip)
end
local function Defensive(fc, ts, who, dst, spell, id)
    local to = dst and dst ~= who and fc.players[dst] and dst or nil
    local on = to or who
    if not Fresh(fc, "d" .. spell .. on, ts, SAME) then return end
    local text, tip
    if to then
        text = format(ns.T("rep.f.given"), spell, to, who)
        tip = format(ns.T("rep.f.given"), spell, to, WithClass(who))
    else
        text = format(ns.T("rep.f.on"), spell, who)
        tip = format(ns.T("rep.f.on"), spell, WithClass(who))
    end
    Row(fc, ts, "def", tonumber(id), false, "d|" .. spell, spell, false, on, text, tip)
end
local function Hero(fc, ts, who, spell, id)
    if ts - fc.heroAt < HERO_GAP then return end
    fc.heroAt = ts
    Row(fc, ts, "hero", tonumber(id), true, false, spell, false, who, format(ns.T("rep.f.on"), spell, who),
        format(ns.T("rep.f.on"), spell, WithClass(who)))
end
local function Rez(fc, ts, dst, by, spell, id)
    fc.dead[dst] = nil
    local text, tip
    if by == dst then
        text = format(ns.T("rep.f.rez.self"), dst, spell or "?")
        tip = format(ns.T("rep.f.rez.self"), WithClass(dst), spell or "?")
    else
        text = format(ns.T("rep.f.rez"), dst, by)
        tip = spell and format(ns.T("rep.f.rez.tip"), dst, WithClass(by), spell) or text
    end
    Row(fc, ts, "death", tonumber(id), true, false, ns.T("rep.f.rez.head"), false, dst, text, tip)
end
local function Dispel(fc, ts, sub, who, dst, dstFlags, a1, a2, a4, a5)
    local what = type(a5) == "string" and a5 or nil
    if not what then return end
    local on = dst or "?"
    local text = format(ns.T("rep.f.dispel"), what, on, who)
    local tip = format(ns.T("rep.f.dispel.tip"), what, on, WithClass(who), tostring(a2))
    if sub == "SPELL_STOLEN" then tip = tip .. "\n" .. ns.T("rep.f.stolen") end
    local icon = tonumber(a4) or tonumber(a1)
    Row(fc, ts, "dispel", icon, fc.keyDisp[what] == true, "x|" .. what, ns.T("rep.f.dispel.head"), what, on,
        text, tip)
end
local function Kick(fc, ts, who, dst, a1, a2, a5)
    local what = type(a5) == "string" and a5 or "?"
    local text = format(ns.T("rep.f.kick"), what, who)
    local tip = format(ns.T("rep.f.kick.tip"), what, dst or "?", WithClass(who), tostring(a2))
    Row(fc, ts, "kick", tonumber(a1), false, "k|" .. what, ns.T("rep.f.kick.head"), what, who, text, tip)
end
local function OwnCast(fc, ts, who, a1, a2)
    local d = fc.dead[who]
    if d then
        if fc.selfRez[a2] then
            Rez(fc, ts, who, who, a2, a1)
        elseif fc.stoneT[who] and math.abs(fc.stoneT[who] - d) <= DEATH_NEAR then
            Rez(fc, ts, who, who, fc.stone, a1)
        end
    end
end
local function OnCast(fc, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, a1, a2)
    if type(a2) ~= "string" then return end
    if Enemy(srcFlags) or (src and fc.bosses[src]) then
        if fc.casts[a2] then BossCast(fc, ts, dst, a2, a1) end
        return
    end
    local who = Actor(fc, srcGUID, src, srcFlags)
    if not who then return end
    if sub == "SPELL_SUMMON" then
        if dstGUID then fc.owners[dstGUID] = who end
        return
    end
    if sub ~= "SPELL_CAST_SUCCESS" then return end
    OwnCast(fc, ts, who, a1, a2)
    if fc.help[a2] then
        Help(fc, ts, who, dst, a2, a1)
    elseif fc.hero[a2] then
        Hero(fc, ts, who, a2, a1)
    elseif fc.defs[a2] then
        Defensive(fc, ts, who, dst, a2, a1)
    end
end
local function OnApplied(fc, ts, srcGUID, src, srcFlags, dst, a1, a2)
    if type(a2) ~= "string" or not dst or not fc.players[dst] then return end
    if fc.auras[a2] and (not src or Enemy(srcFlags) or fc.bosses[src]) then
        BossAura(fc, ts, dst, a2, a1)
        return
    end
    local who = Actor(fc, srcGUID, src, srcFlags)
    if not who then return end
    if fc.help[a2] == true and who ~= dst then
        Help(fc, ts, who, dst, a2, a1)
    elseif fc.defs[a2] and who == dst then
        Defensive(fc, ts, who, nil, a2, a1)
    end
end
local function OnVehicle(fc, ts, src, on)
    if not fc.valkyr or not src or not fc.players[src] then return end
    if on and not fc.veh[src] then
        Row(fc, ts, "boss", ns.replayData.valkyr.icon, true, "v|", ns.T("rep.f.valkyr.head"), false, src,
            format(ns.T("rep.f.valkyr"), src))
    end
    fc.veh[src] = on or nil
end
function FC.Event(fc, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4, a5)
    if sub == "SPELL_AURA_APPLIED" then
        OnApplied(fc, ts, srcGUID, src, srcFlags, dst, a1, a2)
    elseif sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_START" or sub == "SPELL_SUMMON" then
        OnCast(fc, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, a1, a2)
    elseif sub == "SPELL_DAMAGE" then
        if a2 and fc.hits[a2] and dst and fc.players[dst] and (Enemy(srcFlags) or not src) then
            BossHit(fc, ts, a2, a1)
        end
    elseif sub == "SPELL_DISPEL" or sub == "SPELL_STOLEN" then
        local who = Actor(fc, srcGUID, src, srcFlags)
        if who then Dispel(fc, ts, sub, who, dst, dstFlags, a1, a2, a4, a5) end
    elseif sub == "SPELL_INTERRUPT" then
        local who = Actor(fc, srcGUID, src, srcFlags)
        if who then Kick(fc, ts, who, dst, a1, a2, a5) end
    elseif sub == "UNIT_DIED" then
        if dst and fc.players[dst] then
            fc.dead[dst] = ts
            fc.veh[dst] = nil
            Row(fc, ts, "death", "death", true, "death", ns.T("rep.f.death.head"), false, dst,
                format(ns.T("rep.f.death"), dst))
        end
    elseif sub == "SPELL_RESURRECT" then
        if dst and fc.dead[dst] and ts <= fc.to then Rez(fc, ts, dst, src or "?", a2, a1) end
    elseif sub == "SPELL_AURA_REMOVED" then
        if a2 == fc.stone and dst and fc.players[dst] then fc.stoneT[dst] = ts end
    elseif sub == "FW_VEH" then
        OnVehicle(fc, ts, src, tonumber(a1) == 1)
    end
end
local function Phases(fc, res)
    if not res then return end
    local def = ns.bossPhases and ns.bossPhases[fc.fight.boss]
    for k = 2, #res.spans do
        local label = ns.T(res.spans[k].label)
        Row(fc, fc.from + res.spans[k].from, "phase", "phase", true, false, label, false, false, label)
    end
    for kind, times in pairs(res.waves) do
        local w = def and def.waves and def.waves[kind]
        local label = w and ns.T(w.label) or kind
        local ids = {}
        Ids(ids, w and w.on)
        for id in pairs(ids) do
            if fc.auraIds[id] then times = {} end
        end
        for i = 1, #times do
            Row(fc, fc.from + times[i], "phase", "wave", true, false, label, false, false,
                format(ns.T("rep.f.wave"), label, i))
        end
    end
end
local function Names(names)
    if #names <= NAMES_MAX then return concat(names, ", ") end
    local out = {}
    for i = 1, NAMES_MAX do out[i] = names[i] end
    return format(ns.T("rep.f.more"), concat(out, ", "), #names - NAMES_MAX)
end
local function Merge(L, r, order)
    local open, cnt, names, seen, tips, heads, objs = {}, {}, {}, {}, {}, {}, {}
    local n = 0
    for o = 1, #order do
        local i = order[o]
        local key = r.key[i]
        local g = key and open[key]
        if g and r.t[i] - L.fdT[g] <= MERGE then
            cnt[g] = cnt[g] + 1
            local who = r.who[i]
            if who and not seen[g][who] then
                seen[g][who] = true
                names[g][#names[g] + 1] = who
            end
            tips[g][#tips[g] + 1] = r.tip[i]
            if r.imp[i] then L.fdImp[g] = true end
        elseif n < ROW_LIMIT then
            n = n + 1
            L.fdT[n], L.fdIcon[n], L.fdText[n], L.fdImp[n], L.fdKind[n] = r.t[i], r.icon[i], r.text[i], r.imp[i],
                r.kind[i]
            cnt[n], names[n], seen[n], tips[n] = 1, {}, {}, { r.tip[i] }
            local who = r.who[i]
            if who then
                seen[n][who] = true
                names[n][1] = who
            end
            if key then open[key] = n end
            heads[n], objs[n] = r.head[i], r.obj[i]
        end
    end
    for g = 1, n do
        if cnt[g] > 1 then
            local head, obj = heads[g], objs[g]
            if obj then
                L.fdText[g] = format(ns.T("rep.f.many"), head, cnt[g], obj)
            else
                L.fdText[g] = format(ns.T("rep.f.on"), head, Names(names[g]))
            end
            L.fdTip[g] = concat(tips[g], "\n")
        else
            L.fdTip[g] = tips[g][1]
        end
    end
    L.nf = n
end
function FC.Done(fc, L, res)
    Phases(fc, res)
    local r = fc.r
    local order = {}
    local death = ns.T("rep.f.death.head")
    for i = 1, r.n do
        local who = r.who[i]
        if r.kind[i] == "def" and who and L.tanks[who] then r.imp[i] = true end
        local feigned = r.head[i] == death and who and ns.Encounters.ClassOf(who) == "HUNTER"
            and not ns.Encounters.RealDeath(fc.fight, who, fc.from + r.t[i])
        if not feigned then order[#order + 1] = i end
    end
    local T = r.t
    tsort(order, function(a, b)
        if T[a] ~= T[b] then return T[a] < T[b] end
        return a < b
    end)
    L.fdT, L.fdIcon, L.fdText, L.fdImp, L.fdKind, L.fdTip = {}, {}, {}, {}, {}, {}
    Merge(L, r, order)
    L.feedRaw = r.n
end
