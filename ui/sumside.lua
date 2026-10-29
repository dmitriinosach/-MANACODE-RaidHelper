local _, ns = ...
local floor = math.floor
local max = math.max
local W = 420
local OVERLAP = 4
local INSET = 6
local PAD = 6
local GAP = 6
local LEVEL = 60
local Side = {}
ns.SumSide = Side
local Kit = ns.Kit
local side, pageBg, scroll, content, toggle, shell
local pane
local owner
local redraws = {}
local items = {}
local function Width()
    local k = 1
    for i = 1, #items do
        if items[i].sized then k = max(k, Kit.FontScale("GameFontHighlightSmall", true)) end
    end
    return floor(W * k + 0.5)
end
local hosts = {}
local placed = {}
local dock = "right"
local laid
local wasInside
local function Ui()
    local set = ns.GetDB().settings
    if type(set.ui) ~= "table" then set.ui = {} end
    local ui = set.ui
    if ui.sumSide ~= nil then
        if ui.sumPlace == nil then ui.sumPlace = ui.sumSide == true and "outside" or "inside" end
        ui.sumSide = nil
    end
    return ui
end
local function PickDock()
    local left, right = nil, nil
    if ns.Shell and ns.Shell.Room then left, right = ns.Shell.Room() end
    if not right or right >= Width() - OVERLAP then return "right" end
    if left and left >= Width() - OVERLAP then return "left" end
    return nil
end
function Side.Inside()
    return Ui().sumPlace ~= "outside" or PickDock() == nil
end
function Side.Open()
    return not Side.Inside()
end
local function Inner()
    local p = INSET + (Kit.Theme().window.pad or 0)
    return p
end
function Side.Wheel(delta)
    return pane ~= nil and pane:Wheel(delta)
end
function Side.PageWheel(pageWheel)
    return function(delta)
        if Side.Inside() then return pageWheel(delta) end
        return Side.Wheel(delta)
    end
end
local function PaintToggle()
    if not toggle then return end
    local open = Side.Open()
    local room = PickDock() ~= nil
    toggle:SetLabel(ns.T(open and "sum.side.btn.in" or "sum.side.btn.out"))
    toggle.tipTitle = ns.T(open and "sum.side.in" or "sum.side.out")
    toggle.tip = ns.T(room and "sum.side.tip" or "sum.side.noroom")
    if room or open then toggle:Enable() else toggle:Disable() end
end
local function Dock()
    dock = PickDock() or "right"
    side:ClearAllPoints()
    if dock == "right" then
        side:SetPoint("TOPLEFT", shell, "TOPRIGHT", -OVERLAP, 0)
        side:SetPoint("BOTTOMLEFT", shell, "BOTTOMRIGHT", -OVERLAP, 0)
    else
        side:SetPoint("TOPRIGHT", shell, "TOPLEFT", OVERLAP, 0)
        side:SetPoint("BOTTOMRIGHT", shell, "BOTTOMLEFT", OVERLAP, 0)
    end
    side:SetWidth(Width())
end
local function Stack()
    local p = Inner()
    pageBg:ClearAllPoints()
    pageBg:SetPoint("TOPLEFT", side, "TOPLEFT", p, -p)
    pageBg:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -p, p)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", side, "TOPLEFT", p + PAD, -(p + PAD))
    scroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -(p + PAD), p + PAD)
    local width = floor(Width() - (p + PAD) * 2)
    content:SetWidth(width)
    for i = 1, #placed do
        local keep = false
        for k = 1, #items do
            if items[k] == placed[i] then keep = true end
        end
        if not keep then placed[i]:Hide() end
    end
    local y = 0
    laid = { dock = dock, width = width, items = {} }
    for i = 1, #items do
        local f = items[i]
        local h = f:Layout(width)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        f:Show()
        laid.items[i] = { top = y, bottom = y + h, width = f:GetWidth() }
        y = y + h + GAP
    end
    placed = {}
    for i = 1, #items do placed[i] = items[i] end
    content:SetHeight(max(1, y))
    pane:ScrollTo(pane.offset)
end
local function Live()
    if not owner or #items == 0 or not shell or not shell:IsShown() then return false end
    local host = hosts[owner]
    return host ~= nil and host:IsVisible() and true or false
end
local function Release()
    for i = 1, #placed do
        if placed[i]:GetParent() == content then placed[i]:Hide() end
    end
    placed = {}
    laid = nil
end
local Redraw
local function Refresh()
    if not side then return end
    if not Live() then
        side:Hide()
        if toggle then toggle:Hide() end
        Release()
        return
    end
    if toggle then toggle:Show() end
    PaintToggle()
    local inside = Side.Inside()
    if wasInside ~= nil and inside ~= wasInside then
        wasInside = inside
        Redraw()
        return
    end
    wasInside = inside
    if not inside then
        Dock()
        side:Show()
        Stack()
    else
        side:Hide()
        Release()
    end
end
Redraw = function()
    Refresh()
    local fn = owner and redraws[owner]
    if fn then fn() end
end
local function Flip()
    Ui().sumPlace = Side.Open() and "inside" or "outside"
    Redraw()
end
local function Build()
    if side then return end
    shell = ns.Shell and ns.Shell.Frame and ns.Shell.Frame() or UIParent
    side = CreateFrame("Frame", nil, shell)
    side:SetFrameLevel(shell:GetFrameLevel() + LEVEL)
    side:EnableMouse(true)
    Kit.Window(side)
    if ns.Shell and ns.Shell.Handle then ns.Shell.Handle(side) end
    pageBg = side:CreateTexture(nil, "BORDER")
    Kit.Paint(pageBg, "surface.page")
    pane = Kit.ScrollPage(side)
    scroll, content = pane.scroll, pane.content
    side:Hide()
    if ns.Shell and ns.Shell.OnPlace then ns.Shell.OnPlace(Refresh) end
end
function Side.Head(host)
    toggle = Kit.ToolButton(host, "HTP_FailWatchSideToggle")
    toggle.onClick = Flip
    toggle:Hide()
    PaintToggle()
    return toggle
end
function Side.Content()
    Build()
    return content
end
function Side.Parent(page)
    if Side.Inside() then return page end
    return Side.Content()
end
function Side.Watch(key, host, redraw)
    Build()
    hosts[key] = host
    redraws[key] = redraw
    local w = CreateFrame("Frame", nil, host)
    w:SetScript("OnShow", Refresh)
    w:SetScript("OnHide", Refresh)
end
function Side.Show(key, list)
    Build()
    if owner ~= key then pane.offset = 0 end
    owner = key
    items = list or {}
    Refresh()
end
function Side.Drop(key)
    if owner ~= key then return end
    owner = nil
    items = {}
    Refresh()
end
function Side.SetInside(inside)
    Ui().sumPlace = inside and "inside" or "outside"
    Redraw()
end
function Side.IsShown()
    return side ~= nil and side:IsShown() and true or false
end
function Side.HasToggle()
    return toggle ~= nil and toggle:IsShown() and true or false
end
function Side.Layout()
    return laid
end
Side.Refresh = Refresh
Kit.OnTheme(Refresh)
