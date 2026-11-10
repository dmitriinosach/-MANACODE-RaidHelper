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
    out[#out + 1] = { kind = "foot", key = "rmb", left = T("proof.tip.btn") }
    return out
end
function View.Enter(mark)
    if not (mark.proof and ns.Proof) then return false end
    hovered = mark
    local lines = mark.lines or {}
    local feet = #lines + 1
    while feet > 1 and lines[feet - 1].kind == "foot" do feet = feet - 1 end
    local out = {}
    for i = 1, feet - 1 do out[i] = lines[i] end
    if Ctrl() then
        out[#out + 1] = { kind = "sep" }
        View.Preview(mark.proof, out)
    end
    for i = feet, #lines do out[#out + 1] = lines[i] end
    out[#out + 1] = { kind = "foot", key = "ctrl", left = format(T("proof.tip.ctrl"), ns.Proof.Label(ns.Proof.Channel())) }
    if not Ctrl() then out[#out + 1] = { kind = "foot", key = "Ctrl", left = T("proof.tip.hold") } end
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
local function ChannelCells(list, can, whisper)
    local out = {}
    for i = 1, #list do
        local c = list[i]
        local off = can ~= nil and not can(c)
        local tip
        if off then tip = T("report.off." .. c) elseif c == "WHISPER" then tip = whisper end
        out[i] = { key = c, label = T("report.ch." .. c), disabled = off, tip = tip }
    end
    return out
end
function View.Menu(anchor)
    local P = ns.Proof
    local function Repaint()
        for k = 1, #settings do PaintSetting(settings[k]) end
    end
    ns.Tip.Hide()
    ns.Kit.Menu(function()
        local views = {}
        for i = 1, #VIEWS do views[i] = { key = VIEWS[i], label = T("proof.view." .. VIEWS[i]) } end
        return {
            { text = T("proof.menu"), isTitle = true },
            { text = T("report.menu.ch"), seg = ChannelCells(P.CHANNELS, nil, T("proof.ch.WHISPER")), value = P.Channel(),
              func = function(c) P.SetChannel(c) Repaint() end },
            { text = T("proof.menu.view"), seg = views, value = P.View(), func = function(v) P.SetView(v) Repaint() end },
        }
    end, anchor)
end
function View.ReportMenu(anchor, build, title, now, none)
    local R = ns.ChatReport
    local function Send()
        local lines = build(R.Size())
        if #lines < 2 then
            ns.Print(T(none or "report.none"))
            return
        end
        if now then R.SendNow(lines, R.Channel()) else R.Send(lines, R.Channel()) end
    end
    ns.Tip.Hide()
    ns.Kit.Menu(function()
        local c = R.Channel()
        local sizes = {}
        for i = 1, #R.SIZES do sizes[i] = { key = R.SIZES[i], label = tostring(R.SIZES[i]) } end
        local to = UnitExists("target") and UnitIsPlayer("target") and UnitName("target") or nil
        local can = R.Can(c)
        local menu = {
            { text = T(title or "report.menu"), isTitle = true },
            { text = T("report.menu.n"), seg = sizes, value = R.Size(), func = R.SetSize },
            { text = T("report.menu.ch"), seg = ChannelCells(R.CHANNELS, R.Can, to and format(T("report.tip.whisper"), to)),
              value = c, func = R.SetChannel },
            { text = T("report.send"), kind = "main", disabled = not can, tip = not can and T("report.off." .. c) or nil,
              func = Send },
        }
        if ns.Proof.Slow(c) then menu[#menu + 1] = { text = format(T("chat.slow"), T("report.ch." .. c)), note = "text.warn" } end
        return menu
    end, anchor)
end
function View.ReportButton(parent, build, heal)
    local b = ns.Kit.Button(parent, nil, "quiet")
    b.text:SetText(T("report.btn"))
    b.tipTitle = T("report.btn")
    b.tip = T("report.tip")
    b.onClick = function(self)
        if heal then View.ReportMenu(self, build, "report.menu.heal", nil, "report.none.heal")
        else View.ReportMenu(self, build) end
    end
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
