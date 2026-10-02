local _, ns = ...
local format = string.format
local sub = string.sub
local sort = table.sort
local max = math.max
local PROBE_SEC = 5
local TOP = 12
local MAX_DEPTH = 30
local PREFIX = { "HTP_FailWatch", "ManaCode", "RaidLead" }
local SCRIPTS = { "OnUpdate", "OnEvent" }
local Probe = {}
ns.DevProbe = Probe
local driver
local hooks = nil
local frames, elapsed = 0, 0
local onDone = nil
local shown = {}
local function Named(name)
    if not name then return false end
    for i = 1, #PREFIX do
        if sub(name, 1, #PREFIX[i]) == PREFIX[i] then return true end
    end
    return false
end
function Probe.Ours(f, own)
    local p, depth = f, 0
    while p and depth < MAX_DEPTH do
        if own[p] or Named(p:GetName()) then return true end
        p = p:GetParent()
        depth = depth + 1
    end
    return false
end
local function Label(f)
    local name = f:GetName()
    if name then return name end
    local p, depth = f:GetParent(), 0
    while p and depth < MAX_DEPTH do
        local n = p:GetName()
        if n and n ~= "UIParent" then return n .. " > " .. f:GetObjectType() end
        p = p:GetParent()
        depth = depth + 1
    end
    return ns.T("dev.probe.anon")
end
function Probe.Frames()
    local own = ns.ownFrames or {}
    local out = {}
    if type(EnumerateFrames) ~= "function" then
        for f in pairs(own) do out[#out + 1] = f end
        return out
    end
    local f = EnumerateFrames()
    while f do
        if not (f.IsProtected and f:IsProtected()) and Probe.Ours(f, own) then out[#out + 1] = f end
        f = EnumerateFrames(f)
    end
    return out
end
local function Measure(h, rec)
    return function(...)
        local p0 = debugprofilestop()
        h(...)
        local ms = debugprofilestop() - p0
        if ms < 0 then return end
        rec.ms = rec.ms + ms
        rec.n = rec.n + 1
        if ms > rec.max then rec.max = ms end
    end
end
local function Visible(list)
    local nf, nt, ns_ = 0, 0, 0
    for i = 1, #list do
        local f = list[i]
        if f:IsVisible() then
            nf = nf + 1
            local regions = { f:GetRegions() }
            for j = 1, #regions do
                local r = regions[j]
                if r:IsShown() then
                    local kind = r:GetObjectType()
                    if kind == "Texture" then
                        nt = nt + 1
                    elseif kind == "FontString" and (r:GetText() or "") ~= "" then
                        ns_ = ns_ + 1
                    end
                end
            end
        end
    end
    return nf, nt, ns_
end
local function Ms(n)
    return ns.CpuMeter and ns.CpuMeter.Ms(n) or format("%.2f", n)
end
function Probe.Lines(list, sec, n, seen)
    local T = ns.T
    n = max(1, n)
    local total = 0
    local recs = {}
    for i = 1, #list do
        local rec = list[i].rec
        total = total + rec.ms
        if rec.n > 0 then recs[#recs + 1] = rec end
    end
    sort(recs, function(a, b) return a.ms > b.ms end)
    local out = { format(T("dev.probe.head"), Ms(sec), n, Ms(n / max(sec, 0.001)), #list, Ms(total / n)) }
    for i = 1, math.min(TOP, #recs) do
        local r = recs[i]
        out[#out + 1] = format(T("dev.probe.row"), i, Ms(r.ms / n), r.n, Ms(r.max), r.label, r.script)
    end
    if #recs == 0 then out[#out + 1] = T("dev.probe.none") end
    out[#out + 1] = format(T("dev.probe.regions"), Visible(seen))
    return out
end
local function Stop()
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    local list = hooks or {}
    hooks = nil
    for i = 1, #list do
        local k = list[i]
        if k.f:GetScript(k.script) == k.w then k.f:SetScript(k.script, k.h) end
    end
    local lines = Probe.Lines(list, elapsed, frames, shown)
    shown = {}
    local done = onDone
    onDone = nil
    if done then done(lines) end
end
local function Tick(_, dt)
    frames = frames + 1
    elapsed = elapsed + dt
    if elapsed >= PROBE_SEC then Stop() end
end
function Probe.Running()
    return hooks ~= nil
end
function Probe.Start(done)
    if hooks then return false end
    if not driver then driver = CreateFrame("Frame") end
    local list = {}
    local seen = Probe.Frames()
    for i = 1, #seen do
        local f = seen[i]
        if f ~= driver then
            for j = 1, #SCRIPTS do
                local script = SCRIPTS[j]
                local h = f.GetScript and f:HasScript(script) and f:GetScript(script)
                if h then
                    local key = ns.Prof.keys[h]
                    local rec = { label = key and (Label(f) .. " (" .. key .. ")") or Label(f), script = script,
                        ms = 0, n = 0, max = 0 }
                    local w = Measure(h, rec)
                    f:SetScript(script, w)
                    list[#list + 1] = { f = f, script = script, h = h, w = w, rec = rec }
                end
            end
        end
    end
    hooks, shown, onDone = list, seen, done
    frames, elapsed = 0, 0
    driver:SetScript("OnUpdate", Tick)
    driver:Show()
    return true
end
function Probe.Seconds()
    return PROBE_SEC
end
