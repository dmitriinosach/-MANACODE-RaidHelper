local _, ns = ...
local tsort = table.sort
local POS_HOLD = 5
local DEATH_WINDOW = 1.5
local MAP_UNITS = 10000
local Streams = {}
ns.Streams = Streams
function Streams.New(segs)
    local out = {}
    for i = 1, #segs do
        if ns.Store.IsNew(segs[i]) then out[#out + 1] = segs[i] end
    end
    return out
end
function Streams.Any(segs)
    for i = 1, #segs do
        if ns.Store.IsNew(segs[i]) then return true end
    end
    return false
end
function Streams.HpList(segs, who, from, to)
    local out = {}
    local held = nil
    for i = 1, #segs do
        local seg = segs[i]
        if ns.Store.IsNew(seg) then
            for ts, hp, hpMax in ns.Decode.Hp(seg, who, from, to) do
                if hpMax > 0 then
                    if ts < from then
                        held = { t = from, hp = hp, max = hpMax, pct = hp / hpMax }
                    elseif ts <= to then
                        if held then
                            out[#out + 1] = held
                            held = nil
                        end
                        out[#out + 1] = { t = ts, hp = hp, max = hpMax, pct = hp / hpMax }
                    end
                end
            end
        end
    end
    if held then out[#out + 1] = held end
    return out
end
function Streams.Real(segs, who, t)
    local from, to = t - DEATH_WINDOW, t + DEATH_WINDOW
    local seen, zero, heldHp = false, false, nil
    for i = 1, #segs do
        local seg = segs[i]
        if ns.Store.IsNew(seg) then
            for ts, hp, hpMax in ns.Decode.Hp(seg, who, from, to) do
                if hpMax > 0 then
                    if ts < from then
                        heldHp = hp
                    else
                        seen = true
                        if hp == 0 then zero = true end
                    end
                end
            end
        end
    end
    if heldHp ~= nil then
        seen = true
        if heldHp == 0 then zero = true end
    end
    return zero or not seen
end
local function Tracks(segs, kind, from, to, times)
    local out = {}
    for i = 1, #segs do
        local seg = segs[i]
        local names = ns.Decode.Names(seg, kind)
        for k = 1, #names do
            local name = names[k]
            local tr = out[name]
            if not tr then
                tr = { t = {}, a = {}, b = {}, i = 1 }
                out[name] = tr
            end
            local iter = kind == "hp" and ns.Decode.Hp or ns.Decode.Pos
            for ts, a, b in iter(seg, name, from, to) do
                if ts <= to then
                    local n = #tr.t + 1
                    tr.t[n], tr.a[n], tr.b[n] = ts, a, b
                    if ts >= from then times[ts] = true end
                end
            end
        end
    end
    return out
end
local function PutPos(state, seen, unit, hp, x, y, ts)
    if x > 0 or y > 0 then
        state[unit] = { x = x, y = y, hp = hp }
        seen[unit] = ts
        return
    end
    local prev = state[unit]
    if prev and (prev.x > 0 or prev.y > 0) and ts - (seen[unit] or ts) <= POS_HOLD then
        state[unit] = { x = prev.x, y = prev.y, hp = hp, stale = true }
    else
        state[unit] = { x = 0, y = 0, hp = hp }
    end
end
local function MapAt(marks, t, k)
    while marks[k + 1] and marks[k + 1].t <= t do k = k + 1 end
    return k
end
function Streams.Frames(segs, out, from, to)
    segs = Streams.New(segs)
    if #segs == 0 then return end
    local times = {}
    local pos = Tracks(segs, "pos", from - POS_HOLD, to, times)
    local hps = Tracks(segs, "hp", from - POS_HOLD, to, times)
    local list = {}
    for t in pairs(times) do list[#list + 1] = t end
    tsort(list)
    local marks = {}
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do marks[#marks + 1] = m[k] end
    end
    tsort(marks, function(a, b) return a.t < b.t end)
    local state, seen, hpNow = {}, {}, {}
    local lastFloor, lastLive = nil, nil
    local mk = 0
    local total = #list
    for fi = 1, total do
        ns.Jobs.Step(16)
        ns.Jobs.Progress(fi, total)
        local ts = list[fi]
        for name, tr in pairs(hps) do
            local i = tr.i
            while tr.t[i] and tr.t[i] <= ts do
                hpNow[name] = tr.a[i]
                local pt = state[name]
                if pt then state[name] = { x = pt.x, y = pt.y, hp = tr.a[i], stale = pt.stale } end
                i = i + 1
            end
            tr.i = i
        end
        for name, tr in pairs(pos) do
            local i = tr.i
            while tr.t[i] and tr.t[i] <= ts do
                PutPos(state, seen, name, hpNow[name] or 0, tr.a[i] / MAP_UNITS, tr.b[i] / MAP_UNITS, tr.t[i])
                i = i + 1
            end
            tr.i = i
        end
        mk = MapAt(marks, ts, mk)
        local mark = marks[mk]
        local snap, live = {}, 0
        for name, pt in pairs(state) do
            if pt.stale and ts - (seen[name] or ts) > POS_HOLD then
                pt = { x = 0, y = 0, hp = pt.hp }
                state[name] = pt
            end
            if not pt.stale and (pt.x > 0 or pt.y > 0) then live = live + 1 end
            snap[name] = pt
        end
        local level = mark and mark.level or 0
        local lost = nil
        if live > 0 then
            lastFloor, lastLive = level, ts
        elseif next(snap) then
            level = lastFloor or level
            lost = lastLive or ts
        end
        out[#out + 1] = { t = ts, map = mark and mark.name, area = mark and mark.area or 0,
                          floor = level, units = snap, lost = lost }
    end
end
function Streams.PosX(segs, who, from, to)
    local ts, xs = {}, {}
    for i = 1, #segs do
        local seg = segs[i]
        if ns.Store.IsNew(seg) then
            for t, x in ns.Decode.Pos(seg, who, from, to) do
                if t <= to then
                    ts[#ts + 1] = t
                    xs[#xs + 1] = x
                end
            end
        end
    end
    return ts, xs
end
local function SegAt(ts)
    local live = ns.Store.Live()
    if ns.Store.IsNew(live) and ts >= live.t0 then return live end
    for _, seg in ns.Store.Segments() do
        if ns.Store.IsNew(seg) and ts >= seg.t0 and ts <= (seg.t1 or seg.t0) + 1 then return seg end
    end
    return nil
end
function Streams.HealthAt(m, name, ts)
    if not ts then return nil, nil end
    local c = m.hpCursor
    if not c then
        c = { seg = nil, tracks = {} }
        m.hpCursor = c
    end
    local seg = c.seg
    if not seg or ts < seg.t0 or ts > (seg.t1 or seg.t0) + 1 then
        seg = SegAt(ts)
        c.seg, c.tracks = seg, {}
        if not seg then return nil, nil end
    end
    local tr = c.tracks[name]
    if not tr or ts > tr.upto then
        tr = { t = {}, a = {}, b = {}, i = 0, upto = seg.t1 or ts }
        for t, hp, hpMax in ns.Decode.Hp(seg, name) do
            local n = #tr.t + 1
            tr.t[n], tr.a[n], tr.b[n] = t, hp, hpMax
        end
        c.tracks[name] = tr
    end
    local i = tr.i
    if i > 0 and tr.t[i] > ts then i = 0 end
    while tr.t[i + 1] and tr.t[i + 1] <= ts do i = i + 1 end
    tr.i = i
    if i == 0 or tr.b[i] <= 0 then return nil, nil end
    return tr.a[i], tr.b[i]
end
function Streams.Names(segs, kind)
    local seen, out = {}, {}
    for i = 1, #segs do
        if ns.Store.IsNew(segs[i]) then
            local names = ns.Decode.Names(segs[i], kind)
            for k = 1, #names do
                if not seen[names[k]] then
                    seen[names[k]] = true
                    out[#out + 1] = names[k]
                end
            end
        end
    end
    return out
end
