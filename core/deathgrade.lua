local _, ns = ...
local tsort = table.sort
local floor = math.floor
local FALL_N = 3
local FALL_SPAN = 10
local RIDE_GAP = 8
local WAVE_FAST = 1
local HALF = 0.5
local ONESHOT = 0.8
local GUARD_WINDOW = 10
local GAP_MIN = 3
local HEAL_LOW = 0.15
local HP_BACK = 30
local REACT_MAX = 10
local CHAIN_GAP = 2
local LOCK_SLACK = 0.5
local ENRAGE_HOLD = 3
local WAVE_SHARE = 0.6
local TRANQ_CD = 8
local HUNTER = "HUNTER"
local SATED = { 57723, 57724 }
local RANK = { red = 3, yellow = 2, green = 1 }
local SCRAP = { "healIn", "hurtT", "burstT", "burstGap", "burstHeal", "lockId", "lockOn", "lockOff",
                "linkOn", "linkOff", "sated", "tranq" }
local DG = {}
ns.DeathGrade = DG
function DG.Watch(def)
    local SK = ns.SpellKey
    local gw = { names = {}, locks = {}, sated = {}, host = {} }
    for id, lock in pairs(ns.lockouts or {}) do
        if type(lock) == "table" then
            gw.names[SK(id)] = true
            gw.locks[SK(id)] = id
        end
    end
    for i = 1, #SATED do
        gw.names[SK(SATED[i])] = true
        gw.sated[SK(SATED[i])] = true
    end
    local g = def.death
    if g then
        gw.link, gw.wave, gw.frenzy = SK(g.link), SK(g.wave), SK(g.frenzy)
        gw.enrage, gw.tranq, gw.npc = SK(g.enrage), SK(g.tranq), ns.NpcKeyOf(g.npc)
        if gw.link then gw.names[gw.link] = true end
        if gw.frenzy then gw.names[gw.frenzy] = true end
        if gw.enrage then gw.names[gw.enrage] = true end
    end
    return gw
end
function DG.Aura(gw, byName, ts, sub, guid, name, spell)
    local on = sub == "SPELL_AURA_APPLIED"
    if gw.npc and ns.NpcKey(guid) == gw.npc then
        if not guid or (spell ~= gw.frenzy and spell ~= gw.enrage) then return end
        local h = gw.host[guid]
        if not h then
            h = {}
            gw.host[guid] = h
        end
        if spell == gw.frenzy then h.fz = on and ts or nil else h.en = on and ts or nil end
        return
    end
    local p = name and byName[name]
    if not p then return end
    if gw.sated[spell] then
        if on then p.sated = true end
        return
    end
    local lock = gw.locks[spell]
    if lock then
        if on then
            p.lockId, p.lockOn, p.lockOff = lock, ts, nil
        else
            p.lockOff = ts
        end
    elseif spell == gw.link then
        if on then
            p.linkOn, p.linkOff = ts, nil
        else
            p.linkOff = ts
        end
    end
end
function DG.Host(gw, e, guid)
    local h = guid and gw.host[guid]
    if not h then return end
    e.fz, e.en = h.fz, h.en
end
function DG.Tranq(p, ts)
    local list = p.tranq
    if not list then
        list = {}
        p.tranq = list
    end
    list[#list + 1] = ts
end
local function Held(on, off, ts)
    return on ~= nil and (off == nil or off < on or ts - off <= LOCK_SLACK)
end
function DG.Snap(p, d)
    if Held(p.lockOn, p.lockOff, d.t) then d.lock = p.lockId end
    if Held(p.linkOn, p.linkOff, d.t) then d.link = true end
    d.burstT, d.gap, d.gapHeal = p.burstT, p.burstGap, p.burstHeal
end
local function Earlier(a, b)
    if a.d.t ~= b.d.t then return a.d.t < b.d.t end
    return a.p.name < b.p.name
end
local function IsFall(s, e, fall)
    local k = e.d.killer
    if not (k and k.key == fall) then return false end
    return not (ns.Summary.Unseated and ns.Summary.Unseated(s, e.p, e.d.t, RIDE_GAP))
end
local function Jumped(s, list)
    local fall = ns.EnvName("FALLING")
    for i = 1, #list do
        if IsFall(s, list[i], fall) then
            local n = 0
            for k = i, #list do
                if list[k].d.t - list[i].d.t > FALL_SPAN then break end
                if IsFall(s, list[k], fall) then n = n + 1 end
            end
            if n >= FALL_N then return i end
        end
    end
    return nil
end
local function Tail(s, list)
    local n, tanks = #s.players, 0
    for i = 1, n do
        if s.players[i].role == "tank" then tanks = tanks + 1 end
    end
    local dead, gone, tanksGone, first = {}, 0, 0, nil
    local share, step, wave = ns.Tune("tail") / 100, ns.Tune("waveStep"), ns.Tune("waveMin")
    for i = 1, #list do
        local p = list[i].p
        if not first and (gone >= n * share or (tanks > 0 and tanksGone >= tanks)) then first = i end
        if not dead[p.name] then
            dead[p.name] = true
            gone = gone + 1
            if p.role == "tank" then tanksGone = tanksGone + 1 end
        end
    end
    if first then
        local lo, hi = first, first
        while lo > 1 and list[lo].d.t - list[lo - 1].d.t <= step do lo = lo - 1 end
        while hi < #list and list[hi + 1].d.t - list[hi].d.t <= step do hi = hi + 1 end
        if hi - lo + 1 >= wave then
            for k = lo, hi do list[k].d.mass = true end
            first = hi + 1
        end
    end
    local why = "tail"
    local jump = Jumped(s, list)
    if jump and (not first or jump <= first) then first, why = jump, "intent" end
    for k = first or #list + 1, #list do
        local d = list[k].d
        d.tail, d.mass, d.why, d.grade = true, nil, why, nil
    end
end
function DG.NoReset(s)
    local n, out = 0, {}
    for i = 1, #s.players do
        if s.players[i].sated then n = n + 1 end
    end
    if n * 2 < #s.players then return out end
    for i = 1, #s.players do
        if not s.players[i].sated then out[s.players[i].name] = true end
    end
    return out
end
local function Rules(fight)
    local out = {}
    local list = ns.Penalties and ns.Penalties.Watch(fight.boss).deaths or {}
    for i = 1, #list do
        if ns.Penalties.Applies(list[i], fight) then out[#out + 1] = list[i] end
    end
    return out
end
local function Facts(ctx, p, d)
    local hp = ns.Encounters.HpTrail(ctx.lines, p.name, d.t - HP_BACK, d.t)
    local most, below, high, pre = 0, nil, false, nil
    for i = 1, #hp do
        local h = hp[i]
        if h.max > most then most = h.max end
        if h.hp >= HALF * h.max then
            below, high = nil, true
        elseif not below then
            below = h.t
        end
        if d.burstT and h.t < d.burstT then pre = h.hp / h.max end
    end
    local react
    if #hp > 0 then
        react = not high and REACT_MAX or (below and d.t - below or 0)
    else
        local recent, from = d.recent or {}, d.t
        for i = #recent, 1, -1 do
            if from - recent[i].t > CHAIN_GAP then break end
            from = recent[i].t
        end
        react = d.t - from
    end
    local k = d.killer
    local oneshot = k ~= nil and most > 0 and (k.amount or 0) - (k.over or 0) >= ONESHOT * most
    return react, most, pre, oneshot
end
local function Blocked(lock, id)
    for i = 1, lock and #lock or 0 do
        if lock[i] == id then return true end
    end
    return false
end
function DG.Seen(p, t, defs, times, ids)
    local reg = not defs and ns.Encounters and ns.Encounters.Pressed and ns.Encounters.Pressed(p.name)
    defs = defs or ns.defensives or {}
    local has, win, all = {}, {}, {}
    times, ids = times or p.guardT or {}, ids or p.guardId or {}
    for k = 1, #times do
        local at, id = times[k], ids[k]
        if defs[id] and at <= t then
            has[id] = true
            if not win[id] or at > win[id] then win[id] = at end
        end
    end
    for k = 1, reg and #reg or 0, 2 do
        local at, id = reg[k], reg[k + 1]
        has[id] = true
        if at <= t and (not all[id] or at > all[id]) then all[id] = at end
    end
    return { has = has, win = win, all = all }
end
function DG.Left(seen, id, t, noReset, lock, defs)
    local def = (defs or ns.defensives or {})[id]
    local last = seen.win[id]
    if noReset then last = seen.all[id] or last end
    local left = def and last and math.max(0, def.cd - (t - last)) or 0
    return left, Blocked(lock, id) and lock or nil
end
function DG.LockAt(p, ts)
    if Held(p.lockOn, p.lockOff, ts) then return p.lockId, p.lockOn end
    return nil, nil
end
local function Guards(ctx, p, d)
    local defs = ns.defensives or {}
    local saving = ns.saving or {}
    local lock = d.lock and ns.lockouts and ns.lockouts[d.lock]
    local noReset = ctx.noReset[p.name]
    local seen = DG.Seen(p, d.t)
    local used, usedT
    local times, ids = p.guardT or {}, p.guardId or {}
    for k = 1, #times do
        local t, def = times[k], defs[ids[k]]
        if def and t <= d.t and not def.item and d.t - t <= GUARD_WINDOW and (not usedT or t >= usedT) then
            used, usedT = ids[k], t
        end
    end
    local best, cd, n = nil, -1, 0
    for id in pairs(seen.has) do
        local def = saving[id] and defs[id]
        if def and not def.item then
            local left, blocked = DG.Left(seen, id, d.t, noReset, lock)
            if left == 0 and not blocked then
                n = n + 1
                if def.cd > cd or (def.cd == cd and id < best) then best, cd = id, def.cd end
            end
        end
    end
    return best, n, used
end
local function Set(d, grade, why)
    d.grade, d.why = grade, why
end
local function Ready(d, ready, n, late)
    if not ready then return end
    d.ready = ready
    d.readyN = n > 1 and n - 1 or nil
    d.late = late or nil
end
local function Marked(s)
    local out = {}
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "death" and not bd.neutral then
            local spells, srcs = {}, {}
            for k = 1, #(bd.spells or {}) do spells[ns.SpellKey(bd.spells[k]) or bd.spells[k]] = true end
            for k = 1, #(bd.srcs or {}) do srcs[ns.NpcKeyOf(bd.srcs[k]) or bd.srcs[k]] = true end
            out[#out + 1] = { bd = bd, spells = spells, srcs = srcs }
        end
    end
    return out
end
local function RuleHit(ctx, p, d)
    for i = 1, #ctx.rules do
        if ns.Penalties.DeathMatch(ctx.rules[i], d) then return true end
    end
    for i = 1, #ctx.marked do
        local m = ctx.marked[i]
        if ns.Summary.DeathFits(ctx.s, m.bd, p, d, m.spells, m.srcs) then return true end
    end
    return false
end
local function Alive(q, t)
    for k = 1, #q.deathInfo do
        if q.deathInfo[k].t <= t then return false end
    end
    return true
end
local function Hunters(ctx, p, d, k)
    local players = ctx.s.players
    for i = 1, #players do
        local q = players[i]
        if q.class == HUNTER and q ~= p and Alive(q, k.fz) then
            local grade = "red"
            local list = q.tranq or {}
            for j = 1, #list do
                local t = list[j]
                if t >= k.fz and t <= k.t then
                    grade = nil
                    break
                elseif t >= k.fz - TRANQ_CD and t < k.fz then
                    grade = "yellow"
                end
            end
            if grade then
                q.blame = q.blame or {}
                q.blame[#q.blame + 1] = { t = d.t, victim = p.name, grade = grade }
            end
        end
    end
end
local function Tank(ctx, p, d, k, most, react, ready, n)
    local gw = ctx.gw
    if not gw.npc or k.srcKey ~= gw.npc then return false end
    local enraged = k.en ~= nil and k.t - k.en >= ENRAGE_HOLD
    if enraged and ready and k.key == gw.wave and most > 0 and (k.amount or 0) >= WAVE_SHARE * most then
        Set(d, "red", "horror")
        Ready(d, ready, n, false)
        return true
    end
    if k.fz then
        Set(d, "yellow", "frenzy")
        Ready(d, ready, n, react < ns.Tune("react"))
        Hunters(ctx, p, d, k)
        return true
    end
    if enraged and ready then
        Set(d, "yellow", "must")
        Ready(d, ready, n, false)
        return true
    end
    return false
end
local function Judge(ctx, p, d)
    if d.tail then return end
    local react, most, pre, oneshot = Facts(ctx, p, d)
    d.react = floor(react * 10) / 10
    local ready, n, used = Guards(ctx, p, d)
    local k = d.killer
    if d.mc then
        Set(d, d.mc.grade == "yellow" and "yellow" or "green", "mc")
        d.by = d.mc.by
        return
    end
    if not k then return Set(d, "gray", "nodmg") end
    if k.src and k.src ~= p.name and ctx.s.byName[k.src] then
        d.by = k.src
        return Set(d, d.link and "yellow" or "green", d.link and "link" or "ally")
    end
    local fast = react < ns.Tune("react")
    if RuleHit(ctx, p, d) then
        local short = pre ~= nil and pre < HALF and (d.gap or 0) >= GAP_MIN and most > 0
            and (d.gapHeal or 0) < HEAL_LOW * most
        if short or d.mass then
            d.nogp = true
            Set(d, "yellow", short and "noheal" or "waverule")
        else
            Set(d, "red", "rule")
        end
        return Ready(d, ready, n, fast)
    end
    if p.role == "tank" and Tank(ctx, p, d, k, most, react, ready, n) then return end
    if used then
        d.used = used
        return Set(d, "green", "used")
    end
    if d.mass then
        local quick = react <= WAVE_FAST
        Set(d, quick and "green" or "yellow", quick and "wavefast" or "wave")
        return Ready(d, ready, n, quick)
    end
    if ready then
        Set(d, fast and "green" or "yellow", fast and (oneshot and "oneshot" or "late") or "ready")
        return Ready(d, ready, n, fast)
    end
    Set(d, "green", fast and (oneshot and "oneshot" or "fast") or "slow")
end
local function Clean(s)
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #SCRAP do p[SCRAP[k]] = nil end
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            d.burstT = nil
            if d.why ~= "noheal" then d.gap, d.gapHeal = nil, nil end
        end
    end
end
function DG.Run(s, fight, lines)
    local gw = s.gw or DG.Watch({})
    s.gw = nil
    local list = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do list[#list + 1] = { p = p, d = p.deathInfo[k] } end
    end
    tsort(list, Earlier)
    if not fight.killed then Tail(s, list) end
    local ctx = { s = s, gw = gw, lines = lines, rules = Rules(fight), marked = Marked(s),
                  noReset = DG.NoReset(s) }
    for i = 1, #list do Judge(ctx, list[i].p, list[i].d) end
    if ns.DeathDeps then ns.DeathDeps.Run(s, fight) end
    s.dd = nil
    Clean(s)
end
function DG.Worse(a, b)
    if (RANK[b or ""] or 0) > (RANK[a or ""] or 0) then return b end
    return a
end
function DG.Skull(p)
    local n, worst = 0, nil
    for k = 1, #p.deathInfo do
        local d = p.deathInfo[k]
        if not d.tail then
            n = n + 1
            worst = DG.Worse(worst, d.grade)
        end
    end
    return n, worst
end
function DG.Ready(p)
    local out, by = {}, {}
    for k = 1, #p.deathInfo do
        local d = p.deathInfo[k]
        if d.ready and not d.late and not d.tail and d.grade then
            local m = by[d.ready]
            if not m then
                m = { id = d.ready, n = 0, times = {} }
                by[d.ready] = m
                out[#out + 1] = m
            end
            m.n = m.n + 1
            m.times[m.n] = d.t
        end
    end
    return out
end
