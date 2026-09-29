local ADDON, ns = ...
local Shell = ns.Shell
local TL = ns.Timeline
local GP = ns.GPSettings
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
if GP then
    function GP.Show()
        Shell.Open("gp")
    end
    function GP.Hide()
        if Shell.IsOpen("gp") then Shell.Hide() end
    end
    function GP.Toggle()
        Shell.Toggle("gp")
    end
    Shell.Register("gp", {
        label = "shell.tab.gp.rules",
        order = 60,
        tabless = true,
        build = function(page) GP.Attach(page) end,
        OnShow = function() GP.Opened() end,
        OnSize = function() GP.Refresh() end,
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
Shell.Register("gpcfg", {
    label = "shell.tab.gp",
    order = 110,
    right = true,
    icon = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\gp.tga",
    lit = "gp",
    go = function()
        if ns.Settings and ns.Settings.Open then ns.Settings.Open("gp") else Shell.Open("gp") end
    end,
})
