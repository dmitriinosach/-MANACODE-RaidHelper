local ADDON, ns = ...
local format = string.format
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\spam.tga"
local VIEWS = { "chron", "short" }
local View = {}
ns.ProofView = View
local hovered
local settings = {}
local watcher = CreateFrame("Frame")
local function T(key)
    return ns.T(key)
end
local function Ctrl()
    return IsControlKeyDown ~= nil and IsControlKeyDown() and true or false
end
function View.Preview(ask, out)
    local msgs = ask and ns.Proof.Messages(ask) or {}
    if #msgs == 0 then
        out[#out + 1] = { kind = "note", left = T("proof.tip.none") }
        return out
    end
    out[#out + 1] = { kind = "row", left = format(T("proof.tip.will"), #msgs), tone = "dim" }
    for i = 1, #msgs do out[#out + 1] = { kind = "note", left = msgs[i] } end
    return out
end
function View.Lines(ask)
    local out = { { kind = "head", left = format(T("proof.tip.head"), ns.Proof.Label(ns.Proof.Channel()),
        T("proof.view." .. ns.Proof.View())) } }
    View.Preview(ask, out)
    out[#out + 1] = { kind = "foot", left = T("proof.tip.btn") }
    return out
end
function View.Enter(mark)
    if not (mark.proof and ns.Proof) then return false end
    hovered = mark
    local out = {}
    for i = 1, #(mark.lines or {}) do out[i] = mark.lines[i] end
    if Ctrl() then
        out[#out + 1] = { kind = "sep" }
        View.Preview(mark.proof, out)
    end
    out[#out + 1] = { kind = "foot", left = format(T("proof.tip.ctrl"), ns.Proof.Label(ns.Proof.Channel())) }
    ns.Tip.Dock(mark, out, mark.tipIcon)
    return true
end
function View.Leave(mark)
    if hovered == mark or not mark then hovered = nil end
end
function View.Click(mark, button)
    if not (mark.proof and ns.Proof and button == "LeftButton" and Ctrl()) then return false end
    ns.Tip.Hide()
    hovered = nil
    ns.Proof.Send(mark.proof)
    return true
end
local function PaintSetting(b)
    local label = format(T("proof.set"), ns.Proof.Label(ns.Proof.Channel()), T("proof.view." .. ns.Proof.View()))
    b.text:SetText(label)
    b.tipTitle = label
end
function View.Menu(anchor)
    local menu = { { text = T("proof.menu"), isTitle = true, notCheckable = true } }
    local cur = ns.Proof.Channel()
    for i = 1, #ns.Proof.CHANNELS do
        local c = ns.Proof.CHANNELS[i]
        menu[#menu + 1] = {
            text = ns.Proof.Label(c),
            checked = c == cur,
            func = function()
                ns.Proof.SetChannel(c)
                for k = 1, #settings do PaintSetting(settings[k]) end
            end,
        }
    end
    menu[#menu + 1] = { text = T("proof.menu.view"), isTitle = true, notCheckable = true }
    local view = ns.Proof.View()
    for i = 1, #VIEWS do
        local v = VIEWS[i]
        menu[#menu + 1] = {
            text = T("proof.view." .. v),
            checked = v == view,
            func = function()
                ns.Proof.SetView(v)
                for k = 1, #settings do PaintSetting(settings[k]) end
            end,
        }
    end
    ns.Tip.Hide()
    ns.Kit.Menu(menu, anchor)
end
function View.ReportMenu(anchor, build, title)
    local R = ns.ChatReport
    local menu = { { text = T(title or "report.menu"), isTitle = true, notCheckable = true } }
    local cur = R.Channel()
    for i = 1, #R.CHANNELS do
        local c = R.CHANNELS[i]
        menu[#menu + 1] = {
            text = T("report.ch." .. c),
            checked = c == cur,
            func = function()
                local lines = build(R.Size())
                if #lines < 2 then
                    ns.Print(T("report.none"))
                    return
                end
                R.Send(lines, c)
            end,
        }
    end
    menu[#menu + 1] = { text = T("report.menu.n"), isTitle = true, notCheckable = true }
    local n = R.Size()
    for i = 1, #R.SIZES do
        local k = R.SIZES[i]
        menu[#menu + 1] = {
            text = format(T("report.n"), k),
            checked = k == n,
            func = function()
                R.SetSize(k)
                View.ReportMenu(anchor, build, title)
            end,
        }
    end
    ns.Tip.Hide()
    ns.Kit.Menu(menu, anchor)
end
function View.ReportButton(parent, build)
    local b = ns.Kit.Button(parent, nil, "quiet")
    b.text:SetText(T("report.btn"))
    b.tipTitle = T("report.btn")
    b.tip = T("report.tip")
    b.onClick = function(self) View.ReportMenu(self, build) end
    return b
end
local function ButtonEnter(self)
    if self.ask then ns.Tip.Show(self, View.Lines(self.ask)) end
end
local function ButtonLeave(self)
    ns.Tip.Hide()
end
local function ButtonClick(self, button)
    if button == "RightButton" then
        View.Menu(self)
        return
    end
    ns.Tip.Hide()
    if self.ask then ns.Proof.Send(self.ask) end
end
function View.Button(parent, size)
    local b = ns.Kit.IconButton(parent, ICON, size)
    b.tipTitle = false
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:HookScript("OnEnter", ButtonEnter)
    b:HookScript("OnLeave", ButtonLeave)
    b.onClick = ButtonClick
    return b
end
function View.Repaint()
    for k = 1, #settings do PaintSetting(settings[k]) end
end
function View.Setting(parent, name)
    local b = ns.MakeButton(parent, name)
    b.tip = T("proof.set.tip")
    b.onClick = function() View.Menu(b) end
    PaintSetting(b)
    settings[#settings + 1] = b
    return b
end
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", ns.Prof.Wrap("bg.proof", function()
    local m = hovered
    if m and m:IsVisible() and m.proof then View.Enter(m) end
end))
