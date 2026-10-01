local _, ns = ...
local band = bit.band
local floor = math.floor
local min = math.min
local WINDOW = 12
local RING = 65
local RING_BYTES = 10 * 1048576
local DICT_BYTES = 262144
local STEP_CHUNKS = 32
local F_PLAYER = 0x400
local MAX_TAIL = 12
local Trash = {}
ns.Trash = Trash
Trash.WINDOW = WINDOW
Trash.RING = RING
Trash.RING_BYTES = RING_BYTES
local live = nil
local carry = nil
local function Part(prev)
    local part = ns.RaidPart.New(nil, ns.GetDB().pets or {}, nil, {})
    if prev then
        part.owners, part.feign, part.fightAt, part.shields = prev.owners, prev.feign, prev.fightAt, prev.shields
        part.shields.by, part.shields.spells = {}, {}
    end
    ns.RaidPart.Interval(part, 0)
    return part
end
local deaths = {}
local cur = deaths
function Trash.Begin(raid, t0)
    return { raid = raid, t0 = t0, st = Part(carry), seg = nil, died = 0, t1 = nil,
             mapT = -math.huge }
end
function Trash.Forget()
    carry = nil
end
local function Inside(list, ts)
    for k = #list, 1, -1 do
        local d = list[k]
        if ts >= d - WINDOW and ts <= d + WINDOW then return true end
    end
    return false
end
local function CopyStreams(a, seg, lo, hi, list)
    local out = a.seg
    for _, name in ipairs(ns.Decode.Names(seg, "hp")) do
        for ts, hp, hpMax in ns.Decode.Hp(seg, name, lo, hi) do
            if ts > hi then break end
            if ts >= lo and Inside(list, ts) then ns.RecCodec.Hp(out, ts, name, hp, hpMax, true) end
        end
    end
    for _, name in ipairs(ns.Decode.Names(seg, "pos")) do
        for ts, x, y in ns.Decode.Pos(seg, name, lo, hi) do
            if ts > hi then break end
            if ts >= lo and Inside(list, ts) then ns.RecCodec.Pos(out, ts, name, x, y, true) end
        end
    end
    local size = seg.maps and #seg.maps or 0
    if a.mapSeg ~= seg or a.mapSize ~= size then
        a.marks, a.mapSeg, a.mapSize = ns.Decode.Maps(seg), seg, size
    end
    local marks = a.marks
    for k = 1, #marks do
        local m = marks[k]
        if m.t > a.mapT and m.t <= hi then
            ns.RecCodec.Map(out, m.t, m.area, m.level, m.name)
            a.mapT = m.t
        end
    end
end
local function Feed(a, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if not ts then return false end
    ns.Jobs.Step()
    if not a.seg then a.seg = ns.RecCodec.Open(a.t0 and a.t0 < ts and a.t0 or ts, a.raid) end
    a.t1 = ts
    local a1, a2, a3, a4, a5, a6, a7, _, a9 = ...
    ns.RaidPart.Feed(a.st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
        a1, a2, a3, a4, a5, a6, a7, a9)
    if Inside(cur, ts) then
        ns.RecCodec.Append(a.seg, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    end
    return true
end
function Trash.FeedChunk(a, seg, s, list)
    cur = list
    local m = a.st.shields
    if not m.hpCursor or m.hpCursor.seg ~= seg then m.hpCursor = { seg = seg, tracks = {} } end
    local head = ns.RecCodec.Head(s)
    local lo = seg.t0 + head / 1000
    local it = ns.Decode.Chunk(seg, s, MAX_TAIL)
    while Feed(a, it()) do end
    cur = deaths
    local died = a.st.died
    for k = a.died + 1, #died do
        died[k].real = ns.Streams.Real({ seg }, died[k].who, died[k].t)
    end
    a.died = #died
    if a.seg and a.t1 and #list > 0 then CopyStreams(a, seg, lo, a.t1, list) end
end
function Trash.Finish(a)
    if not a then return nil end
    carry = a.st
    if not a.seg then return nil end
    local out = a.seg
    ns.RecCodec.Seal(out)
    if a.t1 and a.t1 > out.t1 then out.t1 = a.t1 end
    local part = a.st
    local iv = part.ivs[#part.ivs]
    if iv then iv.to = out.t1 end
    local piece = ns.RaidPart.Close(part, nil)
    local deaths = {}
    for k = 1, #part.died do
        local d = part.died[k]
        if d.real then deaths[d.who] = (deaths[d.who] or 0) + 1 end
    end
    piece.deaths = next(deaths) and deaths or nil
    ns.Digest.Freeze(out, piece)
    out.bosses = nil
    return out
end
local function DeathsIn(seg)
    local list = {}
    for ts, sub, _, _, _, _, _, dstFlags in ns.Store.Events(seg, nil, nil, nil, 0) do
        if sub == "UNIT_DIED" and dstFlags and band(dstFlags, F_PLAYER) > 0 then list[#list + 1] = ts end
    end
    return list
end
function Trash.Collapse(seg)
    ns.RecCodec.Seal(seg)
    local list = DeathsIn(seg)
    local a = Trash.Begin(seg.raid, seg.t0)
    for i = 1, #seg.chunks do Trash.FeedChunk(a, seg, seg.chunks[i], list) end
    return Trash.Finish(a)
end
function Trash.Died(ts)
    deaths[#deaths + 1] = ts
end
local function Trim(seg, cutMs)
    local first = ns.RecCodec.Head(seg.chunks[1] or (seg.buf and seg.buf[1]))
    ns.RecCodec.TrimStreams(seg, first and min(cutMs, first) or cutMs)
    local keep = seg.t0 + (first or cutMs) / 1000 - 2 * WINDOW
    while deaths[1] and deaths[1] < keep do table.remove(deaths, 1) end
end
local function Drain(seg)
    live = live or Trash.Begin(seg.raid, seg.t0)
    Trash.FeedChunk(live, seg, ns.RecCodec.Shift(seg), deaths)
end
function Trash.Step(seg, now, all)
    if seg.pull then return false end
    local Codec = ns.RecCodec
    local cutMs = floor((now - (all and 0 or RING) - seg.t0) * 1000)
    if all then Codec.Flush(seg) end
    local n = 0
    while (all or n < STEP_CHUNKS) and Codec.FrontOld(seg, cutMs) do
        Drain(seg)
        n = n + 1
    end
    if all and seg.chunks[1] then
        Drain(seg)
        n = n + 1
    end
    while n < STEP_CHUNKS and seg.chunks[1] and Codec.Size(seg) > Trash.RING_BYTES do
        Drain(seg)
        n = n + 1
        local first = Codec.Head(seg.chunks[1] or (seg.buf and seg.buf[1]))
        if first and first > cutMs then cutMs = first end
    end
    Trim(seg, cutMs)
    if all or Codec.DictBytes(seg) > DICT_BYTES then Codec.Compact(seg) end
    return n > 0
end
function Trash.Pull(seg, ts)
    seg.pull = ts
    local cutMs = floor((ts - RING - seg.t0) * 1000)
    ns.RecCodec.Flush(seg)
    while ns.RecCodec.FrontOld(seg, cutMs) do
        live = live or Trash.Begin(seg.raid, seg.t0)
        Trash.FeedChunk(live, seg, ns.RecCodec.Shift(seg), deaths)
    end
    local old = ns.RecCodec.SplitFront(seg, cutMs)
    if old then
        live = live or Trash.Begin(seg.raid, seg.t0)
        Trash.FeedChunk(live, seg, old, deaths)
    end
    local first = ns.RecCodec.Head(seg.chunks[1] or (seg.buf and seg.buf[1]))
    Trim(seg, first or cutMs)
    if first and first > 0 then ns.RecCodec.Rebase(seg, seg.t0 + first / 1000) end
end
function Trash.Close(seg)
    if seg and not seg.pull then
        ns.RecCodec.Flush(seg)
        while seg.chunks[1] do
            live = live or Trash.Begin(seg.raid, seg.t0)
            Trash.FeedChunk(live, seg, ns.RecCodec.Shift(seg), deaths)
        end
    end
    local out = Trash.Finish(live)
    live = nil
    wipe(deaths)
    return out
end
function Trash.Live()
    return live
end
