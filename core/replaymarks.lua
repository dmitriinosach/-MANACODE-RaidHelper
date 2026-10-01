local _, ns = ...
local max = math.max
local abs = math.abs
local tsort = table.sort
local NEAR = 2
local WHO_MAX = 10
local PRIO = { spell = 4, phase = 3, pull = 2, death = 1 }
local MK = { PRIO = PRIO }
ns.ReplayMarks = MK
function MK.Defs(boss)
    local D = ns.replayMarks
    if not D or boss == nil then return {} end
    return D.bosses[boss] or {}
end
function MK.New(fight)
    local defs = MK.Defs(fight.boss)
    local by = {}
    for i = 1, #defs do
        local def = defs[i]
        local subs = type(def.sub) == "table" and def.sub or { def.sub }
        for s = 1, #subs do
            local m = by[subs[s]] or {}
            by[subs[s]] = m
            for k = 1, #def.ids do m[def.ids[k]] = i end
        end
    end
    return { from = fight.from, defs = defs, by = by, players = fight.players or {}, last = {}, lastTs = {}, list = {} }
end
local function AddWho(list, name)
    if not name or #list >= WHO_MAX then return end
    for i = 1, #list do
        if list[i] == name then return end
    end
    list[#list + 1] = name
end
function MK.Event(mc, ts, sub, src, dst, a1)
    local m = mc.by[sub]
    if not m then return end
    local id = tonumber(a1)
    local i = id and m[id]
    if not i or (src and mc.players[src]) then return end
    local who = sub ~= "SPELL_SUMMON" and dst ~= src and dst or nil
    local prev = mc.last[i]
    if prev and ts - mc.lastTs[i] <= (mc.defs[i].gap or ns.replayMarks.gap) then
        prev.n = prev.n + 1
        AddWho(prev.who, who)
        return
    end
    local mk = { t = ts - mc.from, kind = "spell", id = id, n = 1, who = {} }
    AddWho(mk.who, who)
    mc.last[i], mc.lastTs[i] = mk, ts
    mc.list[#mc.list + 1] = mk
end
local function ByTime(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return PRIO[a.kind] > PRIO[b.kind]
end
local function Absorb(list, p)
    local best, bestD
    for i = 1, #list do
        local s = list[i]
        local d = abs(s.t - p.t)
        if s.kind == "spell" and not s.phase and d <= NEAR and (not bestD or d < bestD) then best, bestD = s, d end
    end
    if not best then return false end
    best.phase = p.label
    return true
end
function MK.Done(mc, L, res)
    local list = mc.list
    local spans = res and res.spans or {}
    local phases = {}
    for k = 2, #spans do
        phases[#phases + 1] = { t = spans[k].from, kind = "phase", label = spans[k].label, n = 1, who = {} }
    end
    for i = 1, #phases do
        if not Absorb(list, phases[i]) then list[#list + 1] = phases[i] end
    end
    list[#list + 1] = { t = 0, kind = "pull", label = "rep.mk.pull", n = 1, who = {} }
    tsort(list, ByTime)
    L.marks = list
end
function MK.Deaths(deaths, pull)
    local out = {}
    for i = 1, #deaths do
        out[i] = { t = deaths[i].t - pull, kind = "death", label = "rep.mk.death", n = 1, who = { deaths[i].name } }
    end
    return out
end
function MK.Merge(a, b)
    local out = {}
    for i = 1, #a do out[#out + 1] = a[i] end
    for i = 1, #b do out[#out + 1] = b[i] end
    tsort(out, ByTime)
    return out
end
function MK.Cluster(marks, from, to, width, px)
    local dur = max(0.001, to - from)
    local groups = {}
    local cur
    for i = 1, #marks do
        local m = marks[i]
        if m.t >= from and m.t <= to then
            local x = (m.t - from) / dur * width
            if cur and x - cur.x < px then
                cur.items[#cur.items + 1] = m
                if PRIO[m.kind] > PRIO[cur.lead.kind] then cur.lead = m end
            else
                cur = { x = x, t = m.t, lead = m, items = { m } }
                groups[#groups + 1] = cur
            end
        end
    end
    return groups
end
