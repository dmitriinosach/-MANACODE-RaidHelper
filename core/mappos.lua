local _, ns = ...
local floor = math.floor
local tsort = table.sort
local MAP_UNITS = 10000
local MapPos = {}
ns.MapPos = MapPos
local function ByTime(a, b) return a.t < b.t end
function MapPos.Marks(fight)
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do out[#out + 1] = m[k] end
    end
    tsort(out, ByTime)
    return out
end
function MapPos.Scale(marks, t)
    local mark = marks[1]
    for i = 1, #marks do
        if marks[i].t <= t then mark = marks[i] else break end
    end
    if not mark then return nil, nil end
    local scale = ns.mapScale or {}
    local byArea = scale[mark.name or ""] or (ns.mapAreas and scale[ns.mapAreas[mark.area] or ""])
    local size = byArea and byArea[mark.level]
    if not size then return nil, nil end
    return size.w / MAP_UNITS, size.h / MAP_UNITS
end
function MapPos.Near(tr, t, hold, gap)
    local n = #tr.t
    if n == 0 then return nil, nil end
    local lo, hi = 1, n + 1
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if tr.t[mid] <= t then lo = mid + 1 else hi = mid end
    end
    local i = lo - 1
    if i >= 1 and t - tr.t[i] <= hold then return tr.x[i], tr.y[i] end
    if lo <= n and tr.t[lo] - t <= gap then return tr.x[lo], tr.y[lo] end
    return nil, nil
end
