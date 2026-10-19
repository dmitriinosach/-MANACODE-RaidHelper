local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local sort = table.sort
local HITCH = 0.1
local SAMPLE = 0.5
local GC_KB = 1024
local DUR = 60
local TOP = 5
local LF = { HITCH = HITCH, DUR = DUR }
ns.LagFind = LF
local frame = CreateFrame("Frame")
frame:Hide()
local st = nil
local onDone = nil
local function Snap(into, n)
    UpdateAddOnCPUUsage()
    for i = 1, n do into[i] = GetAddOnCPUUsage(i) or 0 end
end
function LF.Running()
    return st ~= nil
end
function LF.Start(done)
    local C = ns.CpuMeter
    local prof = C ~= nil and C.Profiled() and UpdateAddOnCPUUsage ~= nil
    local n = GetNumAddOns()
    st = { at = GetTime(), prof = prof, n = n, prev = {}, hitMs = {}, calmMs = {}, nHit = 0, nCalm = 0,
           inWin = false, acc = 0, mem = collectgarbage("count"), hits = {}, worst = 0, gc = 0 }
    for i = 1, n do st.hitMs[i], st.calmMs[i] = 0, 0 end
    if prof then Snap(st.prev, n) end
    onDone = done
    frame:Show()
end
local function Close(s)
    local cur = {}
    Snap(cur, s.n)
    local into = s.inWin and s.hitMs or s.calmMs
    for i = 1, s.n do into[i] = into[i] + max(0, cur[i] - (s.prev[i] or 0)) end
    if s.inWin then s.nHit = s.nHit + 1 else s.nCalm = s.nCalm + 1 end
    s.prev, s.acc, s.inWin = cur, 0, false
end
local function Num(v, d)
    return ns.Dec(format("%." .. d .. "f", v))
end
local function Lines(s)
    local T = ns.T
    local dur = max(1, GetTime() - s.at)
    local out = { format(T("lag.sum"), #s.hits, floor(dur + 0.5), floor(s.worst * 1000 + 0.5)) }
    if #s.hits >= 2 then
        local gaps = {}
        for i = 2, #s.hits do gaps[#gaps + 1] = s.hits[i] - s.hits[i - 1] end
        sort(gaps)
        out[#out + 1] = format(T("lag.gap"), Num(gaps[floor((#gaps + 1) / 2)], 1))
    end
    if #s.hits > 0 then out[#out + 1] = format(T("lag.gc"), s.gc, #s.hits) end
    if not s.prof then
        out[#out + 1] = T("lag.noprof")
        return out
    end
    if s.nHit == 0 then return out end
    local rows = {}
    for i = 1, s.n do
        local hit = s.hitMs[i] / s.nHit
        local calm = s.nCalm > 0 and s.calmMs[i] / s.nCalm or 0
        if hit - calm >= 1 then rows[#rows + 1] = { name = (GetAddOnInfo(i)), hit = hit, calm = calm } end
    end
    sort(rows, function(a, b) return a.hit - a.calm > b.hit - b.calm end)
    out[#out + 1] = T(#rows > 0 and "lag.top" or "lag.none")
    for i = 1, math.min(TOP, #rows) do
        local r = rows[i]
        out[#out + 1] = format(T("lag.row"), r.name or "?", Num(r.hit, 0), Num(r.calm, 0))
    end
    return out
end
function LF.Stop()
    local s = st
    if not s then return {} end
    frame:Hide()
    st = nil
    if s.prof and s.acc > 0 then Close(s) end
    local lines = Lines(s)
    local done = onDone
    onDone = nil
    if done then done(lines) end
    return lines
end
function LF.Tick(elapsed)
    local s = st
    if not s then return end
    local mem = collectgarbage("count")
    local hit = elapsed >= HITCH
    if hit then
        s.hits[#s.hits + 1] = GetTime()
        if elapsed > s.worst then s.worst = elapsed end
        if s.mem - mem > GC_KB then s.gc = s.gc + 1 end
        s.inWin = true
    end
    s.mem = mem
    s.acc = s.acc + elapsed
    if s.prof and (hit or s.acc >= SAMPLE) then Close(s) end
    if GetTime() - s.at >= DUR then LF.Stop() end
end
frame:SetScript("OnUpdate", function(_, elapsed) LF.Tick(elapsed) end)
