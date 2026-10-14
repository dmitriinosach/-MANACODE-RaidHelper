local _, ns = ...
local Shed = {}
ns.SummaryShed = Shed
local tsort = table.sort
local SpellKey = ns.SpellKey
local IMMUNE_WINDOW = 1.5
local SHED_FULL = 20
local SHED_RELINK = 0.3
local SHED_SLACK = 1
local SHED_DEATH = 1
local function ShedAura(st, bd, sub, ts, id, from, im)
    local list = st.hangs
    local h = list and list[#list]
    if sub == "SPELL_AURA_REMOVED" then
        if h and not h.gone then
            h.gone = ts
            if im and math.abs(ts - im.t) <= IMMUNE_WINDOW then h.by = im.key end
        end
        return false
    end
    if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REFRESH" then return false end
    local full = bd.shed[id or 0] or SHED_FULL
    if h and (not h.gone or ts - h.gone <= SHED_RELINK) then
        h.on, h.gone, h.by, h.full = ts, nil, nil, full
        return false
    end
    if sub ~= "SPELL_AURA_APPLIED" then return false end
    list = list or {}
    st.hangs = list
    list[#list + 1] = { t = ts - from, on = ts, full = full }
    return true
end
local function ShedBy(p, badges, ts, name)
    for i = 1, #badges do
        local list = badges[i].shed and p.badges[i].hangs
        local h = list and list[#list]
        if h and h.gone and not h.by and math.abs(ts - h.gone) <= IMMUNE_WINDOW then h.by = name end
    end
end
local function DiedNear(list, t)
    for i = 1, #list do
        if math.abs(list[i] - t) <= SHED_DEATH then return true end
    end
    return false
end
local function Forgive(list, a, b)
    for i = #(list or {}), 1, -1 do
        if list[i] >= a - SHED_RELINK and list[i] <= b + SHED_RELINK then table.remove(list, i) end
    end
end
local function Cures(p, h, t, noReset)
    local DG = ns.DeathGrade
    if not p.class or not DG then return nil end
    local immune = ns.immunities or {}
    local lock = h.lockId and ns.lockouts and ns.lockouts[h.lockId]
    local seen = DG.Seen(p, t)
    local out = {}
    for id in pairs(ns.defensives or {}) do
        if immune[SpellKey(id)] == p.class then
            local left, blocked = DG.Left(seen, id, t, noReset, lock)
            local wait = blocked and math.max(0, (h.lockOn or t) + (blocked.dur or 0) - t) or 0
            if wait > left then
                out[#out + 1] = { id = id, left = wait, lock = h.lockId }
            else
                out[#out + 1] = { id = id, left = left }
            end
        end
    end
    tsort(out, function(a, b) return a.id < b.id end)
    return out
end
local function ShedClose(s, fight)
    local noReset = ns.DeathGrade and ns.DeathGrade.NoReset(s) or {}
    for i = 1, #s.badges do
        local bd = s.badges[i]
        for k = 1, bd.shed and #s.players or 0 do
            local p = s.players[k]
            local list = p.badges[i].hangs or {}
            for j = 1, #list do
                local h = list[j]
                local off = h.gone and h.gone < fight.to - SHED_RELINK and h.gone or nil
                h.dur = math.max(0, (off or fight.to) - (fight.from + h.t))
                if not off then
                    h.off = "end"
                elseif DiedNear(p.deathAt, off) then
                    h.off = "died"
                elseif off < h.on + h.full - SHED_SLACK then
                    h.off = "shed"
                    Forgive(p.hits[SpellKey(bd.spell)], fight.from + h.t, off)
                else
                    h.off = "full"
                end
                if h.off ~= "shed" then h.cure = Cures(p, h, fight.from + h.t, noReset[p.name]) end
                h.on, h.gone, h.lockId, h.lockOn = nil, nil, nil, nil
            end
        end
    end
end
local Buffed = { IDS = { 57933, 10060, 49016 }, SKIP = { [57934] = true, [59628] = true } }
function Buffed.Event(s, fight, sub, ts, id, sk, src, dst)
    local set = Buffed.set
    if not set then
        set = {}
        for i = 1, #Buffed.IDS do set[SpellKey(Buffed.IDS[i])] = Buffed.IDS[i] end
        Buffed.set = set
    end
    local key = set[sk]
    if not key or Buffed.SKIP[id or 0] or ts > fight.to or ts < s.lead then return end
    local e = dst.buffed and dst.buffed[key]
    if sub == "SPELL_AURA_REMOVED" then
        if e and e.on then
            e.sec = e.sec + math.max(0, ts - e.on)
            e.on = nil
        end
        return
    end
    if not src or src == dst then return end
    if not e then
        dst.buffed = dst.buffed or {}
        e = { n = 0, sec = 0, by = {} }
        dst.buffed[key] = e
    end
    e.n = e.n + 1
    e.by[src.name] = (e.by[src.name] or 0) + 1
    if not e.on then e.on = math.max(ts, fight.from) end
end
function Buffed.End(p, fight)
    for _, e in pairs(p.buffed or {}) do
        if e.on then e.sec = e.sec + math.max(0, fight.to - e.on) end
        e.on = nil
        e.sec = math.floor(e.sec + 0.5)
    end
end
Buffed.ROD_AURA = { 69762 }
Buffed.ROD_CAST = { 72762 }
Buffed.ROD_SKIP = { [61969] = true }
local function RodSets()
    if Buffed.rodAura then return Buffed.rodAura, Buffed.rodCast end
    local aura, cast = {}, {}
    local function Add(set, id)
        if id and not Buffed.ROD_SKIP[id] then set[SpellKey(id) or id] = true end
    end
    local function AddAll(set, list)
        for i = 1, #(list or {}) do Add(set, list[i]) end
    end
    local rd = ns.replayData or {}
    for i = 1, #(rd.states or {}) do
        if rd.states[i].imp and type(rd.states[i].name) == "number" then Add(aura, rd.states[i].name) end
    end
    AddAll(aura, rd.control and rd.control.ids)
    local mech = ns.replayMech or {}
    for _, list in pairs(mech.chase or {}) do
        for i = 1, #list do
            AddAll(aura, list[i].aura)
            AddAll(aura, list[i].spawn)
        end
    end
    for _, sl in pairs(mech.souls or {}) do AddAll(aura, sl.aura) end
    for _, rl in pairs(mech.realms or {}) do
        for i = 1, #(rl.puddles or {}) do Add(aura, rl.puddles[i].aura) end
    end
    AddAll(aura, Buffed.ROD_AURA)
    AddAll(cast, Buffed.ROD_CAST)
    Buffed.rodAura, Buffed.rodCast = aura, cast
    return aura, cast
end
function Buffed.Rod(fight, sub, ts, sk, dst)
    if ts < fight.from or ts > fight.to then return end
    local aura, cast = RodSets()
    local set = sub == "SPELL_AURA_APPLIED" and aura or cast
    if not set[sk] then return end
    dst.rod = dst.rod or {}
    dst.rod[sk] = (dst.rod[sk] or 0) + 1
end
local function MainBoss(fight, key)
    return key ~= nil and (key == fight.boss or (ns.bosses ~= nil and ns.bosses[key] == fight.boss))
end
local function SniffHit(fight, dst, ts, srcKey)
    if not dst.sniffT and ts >= fight.from and MainBoss(fight, srcKey) then dst.sniffT = ts end
end
local function Sniffed(s, fight)
    local d = ns.pullSniff
    local t0 = s.pull and s.pull.t or fight.from
    local melee = 0
    for i = 1, #s.players do melee = melee + (s.players[i].bossMelee or 0) end
    for i = 1, #s.players do
        local p = s.players[i]
        local at = p.sniffT
        p.sniffT = nil
        local held = d ~= nil and melee > 0 and (p.bossMelee or 0) >= d.share * melee
        if d and p.role ~= "tank" and not held then
            local hit = at ~= nil and at - t0 <= d.hit
            local info = p.deathInfo[1]
            local killer = info and info.killer
            local kill = info ~= nil and info.t - t0 <= d.kill and killer ~= nil and MainBoss(fight, killer.srcKey)
            if hit or kill then
                local sec = math.max(0, (hit and at or info.t) - t0)
                p.jopo = { t = math.floor(sec * 10 + 0.5) / 10, kill = kill or nil }
            end
        end
    end
end
Shed.Aura = ShedAura
Shed.By = ShedBy
Shed.Close = ShedClose
Shed.Buffed = Buffed
Shed.SniffHit = SniffHit
Shed.Sniffed = Sniffed
