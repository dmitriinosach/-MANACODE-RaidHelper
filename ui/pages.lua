local ADDON, ns = ...
local Shell = ns.Shell
local TL = ns.Timeline
local GP = ns.GPSettings
local FP = ns.FaultsPage
if TL then
    function TL.Show()
        Shell.Open("log")
    end
    function TL.Hide()
        if Shell.IsOpen("log") then Shell.Hide() end
    end
    function TL.Toggle()
        Shell.Toggle("log")
    end
    Shell.Register("log", {
        label = "shell.tab.log",
        order = 10,
        build = function(page) TL.Attach(page) end,
        OnShow = function() TL.Opened() end,
        OnSize = function() TL.Layout() end,
        OnTheme = function() TL.Layout() end,
    })
end
local function Alive(f)
    local list = f and ns.Encounters and ns.Encounters.Fights() or {}
    for i = 1, #list do
        local g = list[i]
        if g == f or (g.from == f.from and g.boss == f.boss) then return g end
    end
    return nil
end
local function LogRead()
    local fight, who, from, to = TL.View()
    local TV, SV, RV = ns.ThreatView, ns.SummaryView, ns.RaidSummaryView
    local raid = RV and RV.ShownKey()
    if raid then return { kind = "raid", raid = raid, top = RV.Offset() } end
    if not fight then return nil end
    if TV and TV.IsShown() then return { kind = "threat", fight = fight } end
    if not who then return { kind = "fight", fight = fight, top = SV and SV.Offset() or 0 } end
    local fx = ns.TimelineLinks and ns.TimelineLinks.Focused()
    local at = fx and fx.fight == fight and fx.who == who and fx.t or nil
    return { kind = "player", fight = fight, who = who, from = from, to = to, at = at }
end
local function LogWrite(place)
    local kind = place.kind
    if kind == "raid" then
        local raid = ns.RaidSummary.Find(place.raid)
        if not raid then return end
        TL.ShowRaid(raid)
        ns.RaidSummaryView.ScrollTo(place.top or 0)
        return
    end
    local f = Alive(place.fight)
    if not f then return end
    if kind == "threat" then
        TL.ShowThreat(f)
    elseif kind == "player" then
        if TL.View() ~= f then TL.ShowFight(f) end
        local Links = ns.TimelineLinks
        if place.at and Links then Links.Focus(place.who, place.at, true) else TL.SelectPlayer(place.who) end
        TL.SetView(place.from, place.to)
    else
        TL.ShowFight(f)
        if ns.SummaryView then ns.SummaryView.ScrollTo(place.top or 0) end
    end
end
local function LogSame(a, b)
    return a.kind == b.kind and a.raid == b.raid and a.fight == b.fight and a.who == b.who
end
local function LogValid(place)
    if place.kind == "raid" then return ns.RaidSummary.Find(place.raid) ~= nil end
    return Alive(place.fight) ~= nil
end
local function LogLabel(place)
    local kind, f = place.kind, place.fight
    if kind == "raid" then
        local raid = ns.RaidSummary.Find(place.raid)
        return raid and string.format(ns.T("nav.to.raid"), ns.RaidSummaryView.Title(raid)) or nil
    end
    if kind == "threat" then return string.format(ns.T("thr.view.title"), ns.EncName(f.boss)) end
    local try = ns.ReplayLink and ns.ReplayLink.TryText(f) or ns.EncName(f.boss)
    if kind == "player" then return string.format(ns.T("nav.to.player"), place.who, try) end
    return string.format(ns.T("nav.to.fight"), try)
end
if TL and ns.ShellNav then
    ns.ShellNav.Place("log", { read = LogRead, write = LogWrite, same = LogSame, valid = LogValid, label = LogLabel })
end
if FP and not ns.ReadOnly then
    if GP then
        function GP.Show()
            FP.Open("rules")
        end
        function GP.Hide()
            if Shell.IsOpen("gp") then Shell.Hide() end
        end
        function GP.Toggle()
            Shell.Toggle("gp")
        end
    end
    Shell.Register("gp", {
        label = "shell.tab.gp",
        order = 60,
        tabless = true,
        build = function(page) FP.Attach(page) end,
        OnShow = function() FP.Opened() end,
        OnSize = function() FP.Refresh() end,
    })
end
local function TestNote()
    local id, title = ns.TestSet()
    if id then
        Shell.SetNote(string.format(ns.T("test.mark"), title or id), ns.T("test.mark.tip"))
    else
        Shell.SetNote(nil)
    end
end
if ns.TestSet then
    ns.OnReady(TestNote)
    ns.OnTestSet(TestNote)
end
if ns.ReadOnly then return end
Shell.Register("gpcfg", {
    label = "shell.tab.rules",
    order = 110,
    right = true,
    icon = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\gp.tga",
    lit = "gp",
    go = function()
        if FP then FP.Open("rules") else Shell.Open("gp") end
    end,
})
