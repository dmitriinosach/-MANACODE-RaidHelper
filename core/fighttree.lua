local _, ns = ...
local tsort = table.sort
local Tree = {}
ns.FightTree = Tree
local raids = {}
local spots = {}
local builtFor, builtN = nil, -1
local ADOPT = 3 * 3600
local function Older(a, b)
    return a.from < b.from
end
local function Fresher(a, b)
    if a.last ~= b.last then return a.last > b.last end
    return a.key < b.key
end
local function NewRaid(key, f)
    local r = f.raid
    return {
        key = key,
        name = r and r.name or nil,
        size = r and r.size or nil,
        heroic = false,
        id = r and r.id or nil,
        from = f.from,
        to = f.to,
        last = f.from,
        encs = {},
        passed = 0,
        total = 0,
        tries = 0,
        deaths = 0,
    }
end
local function OwnKey(f)
    if f.raid then return ns.Raid.Key(f.raid) end
    return "solo|" .. date("%Y-%m-%d", f.from)
end
local function Nearest(tagged, f, same)
    local best, gap = nil, ADOPT
    for i = 1, #tagged do
        local t = tagged[i]
        if t ~= f and (not same or same(t)) then
            local d = 0
            if f.from > t.to then
                d = f.from - t.to
            elseif f.to < t.from then
                d = t.from - f.to
            end
            if d < gap then best, gap = t, d end
        end
    end
    return best
end
function Tree.Lend(fights)
    local tagged, locked = {}, {}
    for i = 1, #fights do
        local r = fights[i].raid
        if r then
            tagged[#tagged + 1] = fights[i]
            if r.id then locked[#locked + 1] = fights[i] end
        end
    end
    for i = 1, #tagged do
        local f = tagged[i]
        local r = f.raid
        if not r.id and #locked > 0 then
            local t = Nearest(locked, f, function(c)
                return c.raid.name == r.name and c.raid.size == r.size
            end)
            if t then f.raid = t.raid end
        end
    end
    for i = 1, #fights do
        local f = fights[i]
        if not f.raid then
            local t = Nearest(tagged, f, nil)
            if t then f.raid = t.raid end
        end
    end
end
local function Put(st, f, rk)
    local raid = st.byRaid[rk]
    if not raid then
        raid = NewRaid(rk, f)
        st.byRaid[rk] = raid
        st.out[#st.out + 1] = raid
    end
    if f.raid then
        if f.raid.heroic then raid.heroic = true end
        if not raid.id and f.raid.id then raid.id = f.raid.id end
    end
    if f.from < raid.from then raid.from = f.from end
    if f.to > raid.to then raid.to = f.to end
    if f.from > raid.last then raid.last = f.from end
    raid.tries = raid.tries + 1
    raid.deaths = raid.deaths + (f.deaths or 0)
    local ek = rk .. "\n" .. f.boss
    local enc = st.byEnc[ek]
    if not enc then
        enc = { key = ek, boss = f.boss, fights = {}, passed = false, last = f.from,
                deaths = 0, raid = raid }
        st.byEnc[ek] = enc
        raid.encs[#raid.encs + 1] = enc
    end
    enc.fights[#enc.fights + 1] = f
    if f.killed then enc.passed = true end
    if f.from > enc.last then enc.last = f.from end
    enc.deaths = enc.deaths + (f.deaths or 0)
end
function Tree.Build(fights)
    local st = { out = {}, byRaid = {}, byEnc = {} }
    local out, index = st.out, {}
    Tree.Lend(fights)
    for i = 1, #fights do
        Put(st, fights[i], OwnKey(fights[i]))
    end
    for i = 1, #out do
        local raid = out[i]
        tsort(raid.encs, Fresher)
        local known = raid.name and ns.raidEncounters and ns.raidEncounters[raid.name] or 0
        raid.total = known > #raid.encs and known or #raid.encs
        for k = 1, #raid.encs do
            local enc = raid.encs[k]
            if enc.passed then raid.passed = raid.passed + 1 end
            tsort(enc.fights, Older)
            for n = 1, #enc.fights do
                index[enc.fights[n]] = { raid = raid, enc = enc, n = n }
            end
        end
    end
    tsort(out, Fresher)
    return out, index
end
function Tree.Get()
    local list = ns.Encounters.Fights()
    if list ~= builtFor or #list ~= builtN then
        raids, spots = Tree.Build(list)
        builtFor, builtN = list, #list
    end
    return raids
end
function Tree.Spot(f)
    if not f then return nil end
    Tree.Get()
    return spots[f]
end
function Tree.Decisive(enc)
    local list = enc.fights
    for i = #list, 1, -1 do
        if list[i].killed then return list[i] end
    end
    return list[#list]
end
function Tree.Wipes(enc)
    local n = 0
    for i = 1, #enc.fights do
        if not enc.fights[i].killed then n = n + 1 end
    end
    return n
end
function Tree.Near(f, step)
    local spot = Tree.Spot(f)
    if not spot then return nil end
    return spot.enc.fights[spot.n + step]
end
local function MarkSegs(f, out)
    if f.segs then
        for k = 1, #f.segs do out[f.segs[k]] = true end
    elseif f.seg and f.seg > 0 then
        out[f.seg] = true
    end
end
function Tree.RaidFights(raid)
    local out = {}
    for k = 1, #raid.encs do
        local list = raid.encs[k].fights
        for n = 1, #list do out[#out + 1] = list[n] end
    end
    return out
end
function Tree.Busy()
    local _, _, _, queued = ns.Jobs.State()
    return queued > 0
end
function Tree.Plan(doomed, extra)
    if Tree.Busy() then return nil, "busy" end
    local gone, want, busy = {}, {}, {}
    for k = 1, #doomed do
        gone[doomed[k]] = true
        MarkSegs(doomed[k], want)
    end
    for k = 1, #(extra or {}) do want[extra[k]] = true end
    local list = ns.Encounters.Fights()
    for k = 1, #list do
        if not gone[list[k]] then MarkSegs(list[k], busy) end
    end
    local segs = ns.GetDB().segments
    local plan = { fights = doomed, gone = gone, segs = {}, cut = {}, kept = 0 }
    for i in pairs(want) do
        if segs[i] then
            if busy[i] then plan.kept = plan.kept + 1 else plan.segs[#plan.segs + 1] = i end
        end
    end
    tsort(plan.segs, function(a, b) return a > b end)
    for k = 1, #doomed do
        local f = doomed[k]
        if f.seg and busy[f.seg] then plan.cut[#plan.cut + 1] = f end
    end
    return plan, nil
end
function Tree.Drop(plan)
    local segs = ns.GetDB().segments
    for k = 1, #plan.cut do
        local f = plan.cut[k]
        local seg = segs[f.seg]
        if seg then
            local key = ns.Encounters.Key(f)
            seg.cut = seg.cut or {}
            seg.cut[key] = true
            if seg.totals then seg.totals[key] = nil end
        end
    end
    local removed = 0
    for k = 1, #plan.segs do
        if ns.Store.Remove(plan.segs[k]) then removed = removed + 1 end
    end
    ns.Encounters.Invalidate()
    if ns.Index then ns.Index.Reset() end
    if ns.RaidSummary then ns.RaidSummary.Reset() end
    builtFor, builtN = nil, -1
    return removed
end
