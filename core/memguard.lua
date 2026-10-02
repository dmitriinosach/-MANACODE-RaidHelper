local ADDON, ns = ...
local floor = math.floor
local format = string.format
local PERIOD = 60
local LIMIT_KB = 400 * 1024
local HEADROOM_KB = 250 * 1024
local AGAIN = 900
local RECORD_SHARE = 0.9
local KB = 1024
local MB = 1048576
local MemGuard = { PERIOD = PERIOD, LIMIT_KB = LIMIT_KB, AGAIN = AGAIN }
ns.MemGuard = MemGuard
local frame = CreateFrame("Frame")
local acc = 0
local shedAt = nil
local warned = false
local function Call(mod, fn)
    if mod and type(mod[fn]) == "function" then pcall(mod[fn]) end
end
function MemGuard.Shed()
    local live = ns.Store and ns.Store.Live()
    if live and not live.pull and ns.Store.IsNew(live) and ns.Trash and ns.Recorder then
        pcall(ns.Trash.Step, live, ns.Recorder.Now(), true)
    end
    Call(ns.Summary, "Reset")
    Call(ns.RaidSummary, "Reset")
    Call(ns.Index, "Reset")
    Call(ns.Achievements, "Reset")
    Call(ns.Expect, "Reset")
    Call(ns.DeathPreview, "Reset")
    Call(ns.Decode, "Forget")
    if ns.ForgetGuids then ns.ForgetGuids() end
    collectgarbage("collect")
end
local function Used()
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ADDON) or 0
end
local function Record()
    if warned or not ns.Store then return end
    local _, _, bytes = ns.Store.Stats()
    local limit = ns.Store.LimitBytes()
    if limit <= 0 or bytes < limit * RECORD_SHARE then return end
    warned = true
    ns.Print(format(ns.T("mem.record"), floor(bytes / MB + 0.5), floor(limit / MB + 0.5)))
end
local function Busy()
    if ns.Shell and ns.Shell.IsOpen and ns.Shell.IsOpen() then return true end
    return ns.ReplayIso ~= nil and ns.ReplayIso.IsShown ~= nil and ns.ReplayIso.IsShown()
end
local function Limit()
    local bytes = 0
    if ns.Store then
        local _, _, b = ns.Store.Stats()
        bytes = b or 0
    end
    return math.max(LIMIT_KB, bytes / KB + HEADROOM_KB)
end
function MemGuard.Check()
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage and InCombatLockdown) then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then return end
    Record()
    if Busy() then return end
    local kb = Used()
    local limitKb = Limit()
    if kb <= limitKb then return end
    local now = GetTime()
    if shedAt and now - shedAt < AGAIN then return end
    shedAt = now
    MemGuard.Shed()
    local after = Used()
    ns.Print(format(ns.T("mem.shed"), floor(kb / KB + 0.5), floor(limitKb / KB + 0.5), floor(after / KB + 0.5)))
end
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.bg", function(_, elapsed)
    acc = acc + elapsed
    if acc < PERIOD then return end
    acc = 0
    MemGuard.Check()
end))
