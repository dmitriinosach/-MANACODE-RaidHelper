local _, ns = ...
local format = string.format
local T = ns.T
local A = ns.AutoInvite
local S = ns.Settings
local function Tip()
    return format(T("ainv.act.tip"), A.WordsText())
end
local toggle = {
    label = "",
    title = "",
    tip = "",
    state = function() return true, nil, A.IsOn() end,
    run = function() A.Switch(not A.IsOn()) end,
}
local function Rows()
    toggle.label = T("ainv.act.toggle")
    toggle.title = T("ainv.act.toggle")
    toggle.tip = Tip()
    return { { title = T("ainv.act.row"), items = { toggle } } }
end
if ns.Shell and ns.Shell.Actions then ns.Shell.Actions(Rows, 105) end
A.OnChange(function()
    if S and S.Refresh then S.Refresh() end
end)
if S and S.Section then
    S.Section("lead", "autoinvite", {
        label = "ainv.set",
        order = 30,
        items = {
            { kind = "text", key = "state", tick = true,
              text = function() return T(A.IsOn() and "ainv.set.on" or "ainv.set.off") end,
              token = function() return A.IsOn() and "text.good" or "text.muted" end },
            { kind = "button", key = "toggle", tick = true, tip = "ainv.set.toggle.tip",
              text = function() return T(A.IsOn() and "ainv.set.toggle.off" or "ainv.set.toggle.on") end,
              run = function() A.Switch(not A.IsOn()) end },
            { kind = "field", key = "words", label = "ainv.set.words", tip = "ainv.set.words.tip", width = 220,
              maxLetters = 120, default = A.DEF.words, get = A.WordsText, set = A.SetWordsText },
        },
    })
end
