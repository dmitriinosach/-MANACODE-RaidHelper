local _, ns = ...
local NEAR = 4 * 3600
local LOOK = 16
local KEEP = 2
local ROLE = { tank = "t", heal = "h", dps = "d" }
local Expect = {}
ns.Expect = Expect
local cache = setmetatable({}, { __mode = "k" })
local busy = setmetatable({}, { __mode = "k" })
local order = {}
local stamps = setmetatable({}, { __mode = "k" })
local lastStamp = 0
local function Stamp(s)
    local id = stamps[s]
    if not id then
        lastStamp = lastStamp + 1
        id = lastStamp
        stamps[s] = id
    end
    return id
end
local function Put(fight, entry)
    cache[fight] = entry
    if order[1] == fight then return end
    for i = 2, #order do
        if order[i] == fight then
            table.remove(order, i)
            break
        end
    end
    table.insert(order, 1, fight)
    while #order > KEEP do
        cache[table.remove(order)] = nil
    end
end
function Expect.RaidOf(fight)
    if fight.raid then return fight.raid end
    local segs = ns.GetDB().segments or {}
    local at = fight.seg or 0
    for d = 1, LOOK do
        for _, i in ipairs({ at - d, at + d }) do
            local seg = segs[i]
            if seg and seg.raid and seg.t0 and math.abs(seg.t0 - fight.from) < NEAR then return seg.raid end
        end
    end
    return nil
end
function Expect.ModeOf(fight)
    local B = ns.Bober
    if not B then return nil, nil end
    local boss, zone = B.Code(fight.boss)
    if not boss then return nil, nil end
    local raid = Expect.RaidOf(fight)
    if not raid then return nil, nil end
    return B.Mode(zone, raid.size, raid.heroic), boss
end
local function Build(fight, s, mode, boss)
    local B = ns.Bober
    local list = {}
    for i = 1, #s.players do
        local p = s.players[i]
        if p.dmg > 0 or p.heal > 0 then list[#list + 1] = p end
    end
    local guids = s.guids or {}
    local res = { mode = mode, boss = boss, kill = fight.killed and true or false, by = {}, sum = 0, got = 0,
        all = 0, have = 0, of = 0 }
    local dur = math.max(1, ns.Totals.Time(s))
    for i = 1, #list do
        local p = list[i]
        local role = ROLE[p.role] or "d"
        local dps = ns.Totals.Good(p) / dur
        if role ~= "h" then
            res.of = res.of + 1
            res.all = res.all + dps
        end
        local id = B.IdFromGuid(guids[p.name])
        if not id then
            local found, pending = B.FindId(p.name)
            id = found
            if pending then res.pending = true end
        end
        local rec = B.Get(id)
        local st = rec and B.Stat(rec, mode, boss, role)
        if st and st.avg then
            local got = role == "h" and (p.heal / dur) or dps
            res.by[p.name] = { exp = st.avg, n = st.n, role = role, got = got }
            if role ~= "h" then
                res.have = res.have + 1
                res.sum = res.sum + st.avg
                res.got = res.got + dps
            end
        end
    end
    local bench = B.Bench(mode, boss)
    if bench then
        if res.sum > 0 then res.pctExp = B.Percent(bench, res.sum) end
        res.pctAll = B.Percent(bench, res.all)
    end
    return res
end
function Expect.Of(fight, s, onDone)
    local B = ns.Bober
    if not fight or not s or not B or not B.Ready() then return nil end
    local sid = Stamp(s)
    local hit = cache[fight]
    if hit and hit.sid == sid then return hit.res end
    if busy[fight] then return nil end
    local mode, boss = Expect.ModeOf(fight)
    if not mode then
        Put(fight, { sid = sid })
        return nil
    end
    local key = {}
    busy[fight] = key
    ns.Jobs.Run(key, function()
        ns.Jobs.Label("job.expect")
        return Build(fight, s, mode, boss)
    end, function(res)
        busy[fight] = nil
        Put(fight, { sid = sid, res = res })
        if res and res.pending then
            B.WhenIndexed(function()
                cache[fight] = nil
                if onDone then onDone(nil) end
            end)
        end
        if onDone then onDone(res) end
    end)
    return nil
end
function Expect.Reset(keep)
    for k in pairs(cache) do
        if not (keep and keep[k]) then cache[k] = nil end
    end
    for i = #order, 1, -1 do
        if not cache[order[i]] then table.remove(order, i) end
    end
end
function Expect.Held()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end
