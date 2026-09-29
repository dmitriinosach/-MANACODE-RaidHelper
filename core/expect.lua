local _, ns = ...
local band = bit.band
local F_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local SKIP_HP = { "FW_HP" }
local NEAR = 4 * 3600
local LOOK = 16
local ROLE = { tank = "t", heal = "h", dps = "d" }
local Expect = {}
ns.Expect = Expect
local cache = setmetatable({}, { __mode = "k" })
local busy = setmetatable({}, { __mode = "k" })
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
    local boss = B and B.CODE[fight.boss]
    if not boss then return nil, nil end
    local raid = Expect.RaidOf(fight)
    if not raid then return nil, nil end
    return B.Mode(raid.size, raid.heroic, boss == "hal"), boss
end
local function Guids(fight, names)
    local want, left, out = {}, 0, {}
    for name in pairs(names) do
        want[name] = true
        left = left + 1
    end
    local segs = ns.Encounters.Segs(fight)
    for si = 1, #segs do
        for _, _, srcGUID, srcName, srcFlags in ns.Store.Events(segs[si], fight.from, fight.to, SKIP_HP, 0) do
            ns.Jobs.Step()
            if srcName and want[srcName] and srcGUID and srcFlags and band(srcFlags, F_PLAYER) > 0 then
                out[srcName] = srcGUID
                want[srcName] = nil
                left = left - 1
                if left == 0 then return out end
            end
        end
    end
    return out
end
local function Build(fight, s, mode, boss)
    local B = ns.Bober
    local names, list = {}, {}
    for i = 1, #s.players do
        local p = s.players[i]
        if p.dmg > 0 or p.heal > 0 then
            names[p.name] = true
            list[#list + 1] = p
        end
    end
    local guids = Guids(fight, names)
    local res = { mode = mode, boss = boss, kill = fight.killed and true or false, by = {}, sum = 0, got = 0,
        all = 0, have = 0, of = 0 }
    local dur = math.max(1, s.combat or s.dur)
    for i = 1, #list do
        local p = list[i]
        local role = ROLE[p.role] or "d"
        local dps = p.dmg / dur
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
    local hit = cache[fight]
    if hit and hit.s == s then return hit.res end
    if busy[fight] then return nil end
    local mode, boss = Expect.ModeOf(fight)
    if not mode then
        cache[fight] = { s = s }
        return nil
    end
    local key = {}
    busy[fight] = key
    ns.Jobs.Run(key, function()
        ns.Jobs.Label("job.expect")
        return Build(fight, s, mode, boss)
    end, function(res)
        busy[fight] = nil
        cache[fight] = { s = s, res = res }
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
function Expect.Reset()
    for k in pairs(cache) do cache[k] = nil end
end
