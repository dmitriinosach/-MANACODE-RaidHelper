local _, ns = ...
local format = string.format
local max = math.max
local Kit = ns.Kit
local Scan = ns.AhScan
local S = ns.Settings
local BTN_MIN = 110
local BTN_PAD = 24
local BTN_X = -8
local BTN_Y = 8
local btn
local function StatusText()
    if Scan.IsOn() then
        local i, n, item, page, pages = Scan.Progress()
        if Scan.IsPaused() then return format(ns.T("ah.st.paused"), i, n) end
        local s = format(ns.T("ah.st.run"), i, n, item or "")
        if pages > 1 then s = s .. format(ns.T("ah.st.page"), page, pages) end
        return s
    end
    local n, last = Scan.Stats()
    if n == 0 then return ns.T("ah.st.none") end
    return format(ns.T("ah.st.have"), n, ns.Plural(n, ns.T("ah.items")), ns.RaidCost.Stamp(last))
end
local function StatusToken()
    if Scan.IsPaused() then return "text.warn" end
    return "text.secondary"
end
local function ButtonText()
    if not Scan.IsOn() then return ns.T("ah.btn.scan") end
    return ns.T(Scan.IsPaused() and "ah.btn.resume" or "ah.btn.stop")
end
local function ButtonTip()
    if not Scan.IsOpen() then return ns.T("ah.tip.closed") end
    return ns.T("ah.tip")
end
local function ShortText()
    if not Scan.IsOn() then return ns.T("ah.short.scan") end
    local i, n = Scan.Progress()
    return format(ns.T(Scan.IsPaused() and "ah.short.resume" or "ah.short.stop"), i, n)
end
local function PaintButton()
    if not btn then return end
    btn:SetText(ShortText())
    btn:SetWidth(max(BTN_MIN, btn.text:GetStringWidth() + BTN_PAD))
    btn.tipTitle = ns.T("ah.title")
    btn.tip = StatusText()
    btn.tipDim = ns.T("ah.tip")
    if btn.hovered then Kit.TipShow(btn) end
end
local function MakeButton()
    local host = _G.AuctionFrame
    if btn or type(host) ~= "table" or not host.GetObjectType then return end
    btn = Kit.Button(host)
    btn:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", BTN_X, BTN_Y)
    btn.onClick = function() Scan.Toggle() end
    PaintButton()
end
function Scan.Button()
    return btn
end
Scan.OnChange(function()
    if Scan.IsOpen() then MakeButton() end
    PaintButton()
    if ns.RaidCostView and ns.RaidCostView.Refresh then ns.RaidCostView.Refresh() end
    S.Refresh()
end)
S.Section("cost", "ahscan", {
    label = "set.cost.scan",
    order = 5,
    items = {
        { kind = "text", key = "state", text = StatusText, token = StatusToken, tick = true },
        { kind = "button", key = "scan", text = ButtonText, tip = ButtonTip, tick = true,
          enabled = function() return Scan.IsOpen() end, run = function() Scan.Toggle() end },
    },
})
