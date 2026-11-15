local ADDON, ns = ...
local PERIOD = 60
local HEADROOM_KB = 60 * 1024
local LUA_LIMIT_KB = 300 * 1024
local AGAIN = 900
local KB = 1024
local MemGuard = { PERIOD = PERIOD, HEADROOM_KB = HEADROOM_KB, LUA_LIMIT_KB = LUA_LIMIT_KB, AGAIN = AGAIN }
ns.MemGuard = MemGuard
local frame = CreateFrame("Frame")
local acc = 0
local shedAt = nil
local function Call(mod, fn, ...)
    if mod and type(mod[fn]) == "function" then pcall(mod[fn], ...) end
end
local function Hold(keep, f)
    if f then keep[f] = true end
end
local function Open()
    local keep, busy = {}, false
    if ns.Shell and ns.Shell.IsOpen and ns.Shell.IsOpen() then
        busy = true
        if ns.SummaryView and ns.SummaryView.Fight then Hold(keep, ns.SummaryView.Fight()) end
        if ns.Timeline and ns.Timeline.View then Hold(keep, (ns.Timeline.View())) end
    end
    local Iso = ns.ReplayIso
    if Iso and Iso.IsShown and Iso.IsShown() then
        busy = true
        local scene = Iso.Scene and Iso.Scene()
        Hold(keep, scene and scene.fight)
    end
    return busy, keep
end
local function SegsOf(keep)
    local segs = {}
    for f in pairs(keep) do
        local ok, list = pcall(ns.Encounters.Segs, f)
        for i = 1, ok and list and #list or 0 do segs[list[i]] = true end
    end
    return segs
end
function MemGuard.Shed(keep)
    local live = ns.Store and ns.Store.Live()
    if live and not live.pull and ns.Trash and ns.Recorder then
        pcall(ns.Trash.Step, live, ns.Recorder.Now(), true)
    end
    if not keep then
        Call(ns.Summary, "Reset")
        Call(ns.RaidSummary, "Reset")
        Call(ns.Index, "Reset")
    end
    Call(ns.Achievements, "Reset")
    Call(ns.Expect, "Reset", keep)
    Call(ns.DeathPreview, "Reset", keep)
    Call(ns.Threat, "Reset", keep)
    Call(ns.ReplayFeedCore, "Reset", keep)
    Call(ns.Phases, "Reset", keep)
    Call(ns.Decode, "Reset", keep and SegsOf(keep) or nil)
    local Iso = ns.ReplayIso
    if Iso and not (Iso.IsShown and Iso.IsShown()) then Call(Iso, "Release") end
    if ns.ForgetGuids then ns.ForgetGuids() end
    collectgarbage("collect")
end
local function Used()
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ADDON) or 0
end
local function Limit()
    local bytes = 0
    if ns.Store then
        local _, _, b = ns.Store.Stats()
        bytes = b or 0
    end
    return bytes / KB + HEADROOM_KB
end
function MemGuard.Check()
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage and InCombatLockdown) then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then return end
    local over = (collectgarbage("count") or 0) > LUA_LIMIT_KB or Used() > Limit()
    if not over then return end
    local now = GetTime()
    if shedAt and now - shedAt < AGAIN then return end
    shedAt = now
    local busy, keep = Open()
    MemGuard.Shed(busy and keep or nil)
end
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.bg", function(_, elapsed)
    acc = acc + elapsed
    if acc < PERIOD then return end
    acc = 0
    MemGuard.Check()
end))
