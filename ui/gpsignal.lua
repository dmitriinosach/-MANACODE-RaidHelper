local _, ns = ...
local format = string.format
local floor = math.floor
local RETRY = 1
local RETRY_MAX = 60
local Signal = {}
ns.GPSignal = Signal
local waiter = CreateFrame("Frame")
waiter:Hide()
local due, tries = 0, 0
local function FaultsShown()
    return ns.ShellMini ~= nil and ns.ShellMini.IsShown() and ns.ShellMini.View() == "faults"
end
local function LastSegment()
    local last, seg
    for i, s in ns.Store.Segments() do last, seg = i, s end
    if seg and seg.bosses and next(seg.bosses) then return last end
    return nil
end
local function LastSegOf(f)
    return f.segs and f.segs[#f.segs] or f.seg
end
local function Announce(f, s)
    local m = ns.GPList.Build(f, s)
    if #m.items == 0 or m.pending <= 0 then return end
    if ns.Panel and ns.Panel.SetAlert and not FaultsShown() then ns.Panel.SetAlert("gp", true) end
    if not ns.Raid.IsLead() then return end
    ns.Print(format(ns.T("gp.signal"), m.ready, ns.Plural(m.ready, ns.T("gp.players")), m.pending, ns.Ledger.Unit(),
        ns.EncName(f.boss)))
end
local function Check(seg)
    local f = ns.Encounters.Fights()[1]
    if not f or LastSegOf(f) ~= seg then return end
    local key = format("%s|%d", ns.Penalties.FightKey(f), floor(f.to))
    local gp = ns.GetDB().gp
    if gp.signaled == key then return end
    gp.signaled = key
    ns.Summary.Compute(f, function(s)
        Announce(f, s)
        if ns.Fable then ns.Fable.Auto(f, s) end
    end)
end
waiter:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", function(self)
    if GetTime() < due then return end
    due = GetTime() + RETRY
    tries = tries + 1
    if tries > RETRY_MAX then
        self:Hide()
        return
    end
    local seg = LastSegment()
    if not seg then
        self:Hide()
        return
    end
    local started = ns.Encounters.Scan(function()
        self:Hide()
        Check(seg)
    end)
    if not started and not ns.Encounters.Ready() then return end
    if started then self:Hide() end
end))
local function OnInvalidate()
    due = GetTime()
    tries = 0
    waiter:Show()
end
if ns.Encounters and ns.Store and ns.Summary and ns.Penalties and ns.GPList then
    hooksecurefunc(ns.Encounters, "Invalidate", OnInvalidate)
end
