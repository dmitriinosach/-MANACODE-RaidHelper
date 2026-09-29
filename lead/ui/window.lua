local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local EDGE = 8
local PULT_W = 206
local BODY_L = EDGE + PULT_W + 10
local RIGHT = 10
local BOTTOM = 8
local MIN_PANE_W, MIN_PANE_H = 602, 514
local TABS = {
    { key = "spam",  label = "tabSpam",  order = 20 },
    { key = "tpl",   label = "tabTpl",   order = 30 },
    { key = "board", label = "tabBoard", order = 40 },
    { key = "raid",  label = "tabRaid",  order = 50 },
}
local host, prefsBack, prefsPane
local panes = {}
local builders, sizers = {}, {}
ns.window = {
    PANE_W = 614,
    PANE_H = 522,
}
function ns.window:OnBuild(fn)
    builders[#builders + 1] = fn
end
function ns.window:OnSize(fn)
    sizers[#sizers + 1] = fn
end
function ns.window:Outer()
    if root.Shell then return root.Shell.Frame() end
    return host
end
local function selectPane(key)
    for i, def in ipairs(TABS) do
        if def.key == key then panes[i]:Show() else panes[i]:Hide() end
    end
end
local function build()
    local outer = ns.window:Outer() or UIParent
    host = ns.NewFrame("Frame", nil, outer)
    host:Hide()
    host:SetScript("OnHide", function()
        ns.SelectClose()
        if ns.RaidPane then ns.RaidPane.CloseMenu() end
        ns.window:ClampRight(0)
    end)
    host.pult = ns.MakePanel(host, ns.T("pultGather"))
    host.pult:SetPoint("TOPLEFT", host, "TOPLEFT", EDGE, -EDGE)
    host.pult:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", EDGE, BOTTOM)
    host.pult:SetWidth(PULT_W)
    for i, def in ipairs(TABS) do
        local pane = ns.NewFrame("Frame", nil, host)
        pane:SetPoint("TOPLEFT", host, "TOPLEFT", BODY_L, -EDGE)
        pane:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -RIGHT, BOTTOM)
        pane.key = def.key
        pane:Hide()
        panes[i] = pane
    end
    prefsBack = ns.NewFrame("Frame", nil, outer)
    prefsBack:Hide()
    prefsPane = ns.NewFrame("Frame", nil, prefsBack)
    prefsPane:SetPoint("TOPLEFT", prefsBack, "TOPLEFT", EDGE, -EDGE)
    prefsPane:SetPoint("BOTTOMRIGHT", prefsBack, "BOTTOMRIGHT", -EDGE, EDGE)
    for _, fn in ipairs(builders) do fn() end
end
local function resize(w, h)
    ns.window.PANE_W = math.max(MIN_PANE_W, math.floor(w - BODY_L - RIGHT))
    ns.window.PANE_H = math.max(MIN_PANE_H, math.floor(h - EDGE - BOTTOM))
    for _, fn in ipairs(sizers) do fn() end
end
local function attach(page, key)
    if not host then build() end
    host:ClearAllPoints()
    host:SetAllPoints(page)
    resize(page:GetWidth(), page:GetHeight())
    selectPane(key)
    host:Show()
    if ns.Side and ns.Side.Refresh then ns.Side.Refresh() end
end
function ns.window:Pane(key)
    if not host then build() end
    for i, def in ipairs(TABS) do
        if def.key == key then return panes[i] end
    end
end
function ns.window:Prefs()
    if not host then build() end
    return prefsPane
end
function ns.window:Pult()
    if not host then build() end
    return host.pult
end
function ns.window:ClampRight(px)
    if root.Shell and root.Shell.ClampRight then
        root.Shell.ClampRight(px)
        return
    end
    local o = self:Outer()
    if o and o ~= host and o.SetClampRectInsets then o:SetClampRectInsets(0, px or 0, 0, 0) end
end
function ns.window:Handle(region)
    if root.Shell and root.Shell.Handle then root.Shell.Handle(region) end
end
function ns.window:Toggle()
    if root.Shell then root.Shell.Toggle() end
end
local function showPrefs(body)
    ns.window:Prefs()
    prefsBack:SetParent(body)
    prefsBack:ClearAllPoints()
    prefsBack:SetAllPoints(body)
    prefsBack:Show()
    if ns.PrefsPane then ns.PrefsPane.Refresh() end
end
local function hidePrefs()
    if prefsBack then prefsBack:Hide() end
end
local function repaint()
    if host then ns.Session.Changed() end
end
local function command(arg)
    local a = arg:match("^(%S*)")
    if a == "off" then ns.Test.Stop() else ns.Test.Start(a) end
end
if root.Shell then
    for _, def in ipairs(TABS) do
        local key, label = def.key, def.label
        root.Shell.Register(key, {
            label = function() return ns.T(label) end,
            order = def.order,
            build = function() end,
            OnShow = function(page) attach(page, key) end,
            OnHide = function() if host then host:Hide() end end,
            OnSize = function(_, w, h) resize(w, h) end,
            OnTheme = repaint,
        })
    end
    if root.Shell.Section then
        root.Shell.Section("lead", {
            cat = "lead",
            order = 10,
            height = function() return ns.PrefsPane and ns.PrefsPane.Height() + EDGE * 2 or 0 end,
            build = function() end,
            OnShow = showPrefs,
            OnHide = hidePrefs,
        })
    end
    if root.Settings and root.Settings.Section then
        root.Settings.Section("lead", "marks", {
            label = function() return ns.T("prefsMarks") end,
            order = 20,
            items = {
                { kind = "check", key = "marksKeep",
                  label = function() return ns.T("marksKeepTitle") end,
                  tip = function() return ns.T("tipMarksKeep") end,
                  get = function() return ns.Marks.Enabled() end,
                  set = function(on) ns.Marks.SetEnabled(on) end },
            },
        })
        ns.Marks.OnChange(function() root.Settings.Refresh() end)
    end
    root.Shell.Command("test", command, function() return ns.T("cmdTest") end)
end
