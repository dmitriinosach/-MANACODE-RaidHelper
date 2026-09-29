local _, ns = ...
local find = string.find
local SPAN_AT = 2097152.0
local SPAN_CHUNK = 65536.0
local KEEP = 2
local F_BY_PLAYER = 0x100
local PROGRESS_EVERY = 256
local Index = {}
ns.Index = Index
local cache = {}
local keys = setmetatable({}, { __mode = "k" })
local isSwing = setmetatable({}, { __index = function(t, sub)
    local v = find(sub, "SWING", 1, true) == 1
    t[sub] = v
    return v
end })
local function KeyOf(fight)
    local key = keys[fight]
    if not key then
        key = {}
        keys[fight] = key
    end
    return key
end
function Index.BossNames(fight)
    local names = { [fight.boss] = true }
    for name, enc in pairs(ns.bosses) do
        if enc == fight.boss then names[name] = true end
    end
    if fight.names then
        for name in pairs(fight.names) do names[name] = true end
    end
    return names
end
local function IsPull(seg, s, at, from, to)
    local ts, sub, _, _, srcFlags = ns.Store.Decode(seg, s, at, 0)
    return ts ~= nil and ts >= from and ts <= to and srcFlags ~= nil
        and bit.band(srcFlags, F_BY_PLAYER) > 0
        and (find(sub, "_DAMAGE", 1, true) or find(sub, "_MISSED", 1, true)) ~= nil
end
local function Build(fight)
    local segs = ns.Encounters.Segs(fight)
    local from, to = ns.Encounters.Lead(fight), ns.Encounters.Tail(fight)
    local common, snaps, swings, who = {}, {}, {}, {}
    local idx = { fight = fight, segs = segs, from = from, to = to,
                  common = common, snaps = snaps, swings = swings, who = who }
    local bosses = Index.BossNames(fight)
    local fixates = ns.fixates or {}
    local castSubs = ns.Encounters.BOSS_SUBS
    for name in pairs(fight.players) do who[name] = {} end
    ns.Jobs.Label("job.index")
    local span, seen = to - from, 0
    for o = 1, #segs do
        local seg = segs[o]
        for s, at, ci, ts, sub, src, dst in ns.Store.Heads(seg, from, to) do
            ns.Jobs.Step()
            seen = seen + 1
            if seen % PROGRESS_EVERY == 0 then ns.Jobs.Progress(ts - from, span) end
            if ci > 0 and ci < SPAN_CHUNK and at < SPAN_AT then
                local key = (o * SPAN_CHUNK + ci) * SPAN_AT + at
                if sub == "FW_HP" then
                    snaps[#snaps + 1] = key
                else
                    if sub == "SPELL_SUMMON" or (src and fixates[src])
                        or (src and bosses[src] and castSubs[sub]) then
                        common[#common + 1] = key
                    end
                    if not idx.pull and dst and bosses[dst] and IsPull(seg, s, at, from, to) then
                        idx.pull = key
                    end
                    local list = src and who[src]
                    if list then list[#list + 1] = key end
                    if dst ~= src then
                        list = dst and who[dst]
                        if list then list[#list + 1] = key end
                    end
                    if src and sub and isSwing[sub] then
                        swings[#swings + 1] = key
                    end
                end
            end
        end
    end
    return idx
end
local function Remember(idx)
    for i = 1, #cache do
        if cache[i] == idx then return end
    end
    table.insert(cache, 1, idx)
    while #cache > KEEP do
        table.remove(cache)
    end
end
function Index.Peek(fight)
    for i = 1, #cache do
        if cache[i].fight == fight then return cache[i] end
    end
    return nil
end
function Index.Get(fight, onDone, urgent)
    local ready = Index.Peek(fight)
    if ready then
        if onDone then onDone(ready) end
        return
    end
    for other, key in pairs(keys) do
        if other ~= fight then ns.Jobs.Cancel(key) end
    end
    ns.Jobs.Run(KeyOf(fight), function() return Build(fight) end, function(idx)
        if idx then Remember(idx) end
        if onDone then onDone(idx) end
    end, "idx.frame", urgent)
end
function Index.Line(idx, key)
    local at = key % SPAN_AT
    local rest = (key - at) / SPAN_AT
    local ci = rest % SPAN_CHUNK
    local seg = idx.segs[(rest - ci) / SPAN_CHUNK]
    return seg, seg.chunks[ci], at
end
function Index.Seek(idx, list, t)
    local lo, hi = 1, #list + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        local seg, s, at = Index.Line(idx, list[mid])
        if ns.Store.TimeAt(seg, s, at) < t then lo = mid + 1 else hi = mid end
    end
    return lo
end
function Index.Reset()
    wipe(cache)
end
