local _, ns = ...
local max = math.max
local min = math.min
local tsort = table.sort
local FxUse = {}
ns.FxUse = FxUse
FxUse.SORTS = { "name", "count", "n", "share" }
local cache = setmetatable({}, { __mode = "k" })
local keys = setmetatable({}, { __mode = "k" })
local ROLE_ORDER = { tank = 1, heal = 2, dps = 3 }
local function Add(by, id, name, a, z, from, to)
    local row = by[id]
    if not row then
        row = { n = 0, share = 0, on = {} }
        by[id] = row
    end
    if row.on[name] == nil then
        row.on[name] = 0
        row.n = row.n + 1
    end
    a, z = max(a, from), min(z, to)
    if z > a then row.on[name] = row.on[name] + (z - a) end
end
local function Build(idx)
    local fight = idx.fight
    local from, to = fight.from, fight.to
    local list = idx.aur or {}
    local T = ns.Index.Times(idx, list)
    local open, by = {}, {}
    for i = 1, #list do
        ns.Jobs.Step()
        local ts, sub, _, _, _, _, dst, _, a1 = ns.Index.ReadKey(idx, list[i], T and T[i], 1)
        local id = tonumber(a1)
        if ts and dst and id then
            local mine = open[dst]
            if not mine then
                mine = {}
                open[dst] = mine
            end
            if sub == "SPELL_AURA_REMOVED" then
                local at = mine[id]
                if at then
                    Add(by, id, dst, at, ts, from, to)
                    mine[id] = nil
                end
            elseif not mine[id] then
                mine[id] = ts
            end
        end
    end
    for dst, mine in pairs(open) do
        for id, at in pairs(mine) do Add(by, id, dst, at, idx.to, from, to) end
    end
    local span = max(1, to - from)
    for _, row in pairs(by) do
        local sum = 0
        for _, sec in pairs(row.on) do sum = sum + sec end
        row.share = row.n > 0 and min(1, sum / (row.n * span)) or 0
    end
    return by
end
function FxUse.Peek(fight)
    return fight and cache[fight] or nil
end
function FxUse.Want(fight, onDone)
    local ready = cache[fight]
    if ready then
        if onDone then onDone(ready) end
        return
    end
    ns.Index.Get(fight, function(idx)
        if not idx then
            if onDone then onDone(nil) end
            return
        end
        local key = keys[fight]
        if not key then
            key = {}
            keys[fight] = key
        end
        ns.Jobs.Run(key, function() return Build(idx) end, function(by)
            if by then cache[fight] = by end
            if onDone then onDone(by) end
        end, "tl.data")
    end)
end
local function Sort(rows, sort)
    tsort(rows, function(a, b)
        if sort == "count" and a.count ~= b.count then return a.count > b.count end
        if sort == "n" and (a.n or 0) ~= (b.n or 0) then return (a.n or 0) > (b.n or 0) end
        if sort == "share" and (a.share or 0) ~= (b.share or 0) then return (a.share or 0) > (b.share or 0) end
        if a.name ~= b.name then return a.name < b.name end
        return (a.id or 0) < (b.id or 0)
    end)
end
local function Row(id, count, use)
    local u = use and use[id]
    return { id = id, name = ns.Effects.Name(id), count = count, state = ns.Effects.State(id),
             n = u and u.n or nil, share = u and u.share or nil }
end
local function RoleOf(s, name)
    local p = s and s.byName and s.byName[name]
    local class = p and p.class or (ns.Encounters.ClassOf and ns.Encounters.ClassOf(name)) or nil
    return p and p.role or nil, class
end
local function Grouped(fight, auras, use, sort)
    local S = ns.Summary
    local s = fight and S and (S.Peek(fight) or S.Load(fight)) or nil
    local groups, order = {}, {}
    for i = 1, #auras do
        local a = auras[i]
        local id = tonumber(a.id)
        if id and ns.Effects.Tracked(id) then
            local src = a.src or "?"
            local g = groups[src]
            if not g then
                local role, class = RoleOf(s, src)
                local mate = fight and fight.players and fight.players[src] ~= nil
                g = { src = src, role = role, class = class, mate = mate, ids = {}, rows = {} }
                groups[src] = g
                order[#order + 1] = g
            end
            local r = g.ids[id]
            if not r then
                r = Row(id, 0, use)
                g.ids[id] = r
                g.rows[#g.rows + 1] = r
            end
            r.count = r.count + 1
        end
    end
    tsort(order, function(a, b)
        if a.mate ~= b.mate then return a.mate end
        local ra, rb = ROLE_ORDER[a.role or ""] or 4, ROLE_ORDER[b.role or ""] or 4
        if ra ~= rb then return ra < rb end
        return a.src < b.src
    end)
    local out = {}
    for k = 1, #order do
        local g = order[k]
        Sort(g.rows, sort)
        out[#out + 1] = { head = true, name = g.src, count = #g.rows, role = g.role, class = g.class }
        for j = 1, #g.rows do out[#out + 1] = g.rows[j] end
    end
    return out
end
function FxUse.Rows(fight, data, hidden, sort, group)
    local use = FxUse.Peek(fight)
    local auras = data and data.auras
    if auras and group and not hidden then return Grouped(fight, auras, use, sort) end
    local rows = {}
    if auras then
        local seen = {}
        for i = 1, #auras do
            local id = tonumber(auras[i].id)
            if id and ns.Effects.Tracked(id) == not hidden then
                local r = seen[id]
                if not r then
                    r = Row(id, 0, use)
                    seen[id] = r
                    rows[#rows + 1] = r
                end
                r.count = r.count + 1
            end
        end
    else
        local reg = ns.Effects.Registry()
        for id, e in pairs(reg) do
            if ns.Effects.Tracked(id) == not hidden then rows[#rows + 1] = Row(id, e.n or 0, use) end
        end
    end
    Sort(rows, sort)
    return rows
end
