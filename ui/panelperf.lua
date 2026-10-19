local _, ns = ...
local format = string.format
local floor = math.floor
local sort = table.sort
local Panel = ns.Panel
local TOP = 8
local MEM_EVERY = 5
local ICON = "Interface\\Icons\\Trade_Engineering"
local FPS_WARN, FPS_BAD = 20, 10
local MEM_WARN, MEM_BAD = 400, 800
local LAT_WARN, LAT_BAD = 200, 400
local TONE_RANK = { normal = 0, warn = 1, bad = 2 }
local mem = {}
local memAt, memTotal = nil, 0
local function Reset()
    for i in pairs(mem) do mem[i] = nil end
    memAt, memTotal = nil, 0
end
local function SampleMem()
    UpdateAddOnMemoryUsage()
    local total = 0
    for i = 1, GetNumAddOns() do
        local m = GetAddOnMemoryUsage(i) or 0
        mem[i] = m
        total = total + m
    end
    return total
end
local function NetFps()
    local _, _, latency = GetNetStats()
    return floor((GetFramerate() or 0) + 0.5), floor((latency or 0) + 0.5)
end
local function ToneOf(v, warn, bad, low)
    if low then
        if v < bad then return "bad" end
        return v < warn and "warn" or "normal"
    end
    if v >= bad then return "bad" end
    return v >= warn and "warn" or "normal"
end
local function Worse(a, b)
    return TONE_RANK[b] > TONE_RANK[a] and b or a
end
local function ByValue(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.name < b.name
end
local function Grouped()
    local C = ns.CpuMeter
    local n = GetNumAddOns()
    local loaded = {}
    for i = 1, n do
        local name = GetAddOnInfo(i)
        if name and IsAddOnLoaded(name) then loaded[name] = 1 end
    end
    local by, list, total, mine = {}, {}, 0, 0
    for i = 1, n do
        local v = mem[i]
        local name = GetAddOnInfo(i)
        if name and loaded[name] and v and v > 0 then
            local g = C.Group(name, loaded)
            local e = by[g]
            if not e then
                e = { name = g, v = 0, mine = C.IsMine(g) }
                by[g] = e
                list[#list + 1] = e
            end
            e.v = e.v + v
            total = total + v
            if e.mine then mine = mine + v end
        end
    end
    sort(list, ByValue)
    return list, total, mine
end
local function Mb(kb)
    return format(ns.T("panel.perf.unit.mem"), ns.Dec(format(kb >= 100 * 1024 and "%.0f" or "%.1f", kb / 1024)))
end
local function Share(part, total)
    return format(ns.T("panel.perf.pct"), total > 0 and floor(part / total * 100 + 0.5) or 0)
end
local function TopRows(list, total, lines)
    local mineShown = false
    for i = 1, #list do
        local e = list[i]
        if i <= TOP or (e.mine and not mineShown) then
            if e.mine then mineShown = true end
            lines[#lines + 1] = { kind = "row", left = e.mine and ns.T("panel.cpu.mine") or e.name,
                mid = Mb(e.v), right = Share(e.v, total), tone = e.mine and "good" or nil }
        end
    end
end
local function Tip(row)
    local fps, ms = NetFps()
    if not memAt then memTotal = SampleMem() end
    local list, total, mine = Grouped()
    local lines = {
        { kind = "head", left = ns.T("set.panel.row.perf") },
        { kind = "row", left = ns.T("panel.perf.fps.row"), right = tostring(fps), tone = ToneOf(fps, FPS_WARN, FPS_BAD, true) },
        { kind = "row", left = ns.T("panel.perf.lat.row"), right = format(ns.T("panel.perf.ms"), ms),
          tone = ToneOf(ms, LAT_WARN, LAT_BAD) },
        { kind = "row", left = ns.T("panel.perf.mem.all"), right = Mb(total) },
        { kind = "row", left = ns.T("panel.perf.mem.mine"), right = Mb(mine) },
    }
    for i = 2, #lines do
        if lines[i].tone == "normal" then lines[i].tone = nil end
    end
    lines[#lines + 1] = { kind = "sep" }
    lines[#lines + 1] = { kind = "row", left = ns.T("panel.perf.head.mem") }
    TopRows(list, total, lines)
    return lines
end
Panel.Widget({
    key = "perf",
    order = 40,
    label = "set.panel.row.perf",
    rate = 1,
    Live = function()
        Reset()
    end,
    Build = function(row)
        Panel.Line(row, ICON, ns.T("panel.line.perf"))
        Panel.Reserve(row, format(ns.T("panel.perf.val"), 999, 9999))
    end,
    Update = function(row, now)
        local fps = NetFps()
        if not memAt or now - memAt >= MEM_EVERY then
            memAt = now
            memTotal = SampleMem()
        end
        local mb = floor(memTotal / 1024 + 0.5)
        local tone = Worse(ToneOf(fps, FPS_WARN, FPS_BAD, true), ToneOf(mb, MEM_WARN, MEM_BAD))
        Panel.Value(row, format(ns.T("panel.perf.val"), fps, mb), tone)
    end,
    Tip = Tip,
})
