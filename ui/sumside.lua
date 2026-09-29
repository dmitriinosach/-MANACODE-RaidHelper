local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local W = 360
local OVERLAP = 4
local INSET = 6
local PAD = 6
local GAP = 6
local WHEEL = 40
local TOGGLE = 32
local LEVEL = 60
local ARROW = "Interface\\Buttons\\UI-SpellbookIcon-%sPage-%s"
local HILITE = "Interface\\Buttons\\UI-Common-MouseHilight"
local Side = {}
ns.SumSide = Side
local Kit = ns.Kit
local side, pageBg, scroll, content, toggle, shell
local owner
local redraws = {}
local items = {}
local hosts = {}
local placed = {}
local dock = "right"
local offset = 0
local laid
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
function Side.Inside()
    return Ui().sumPlace ~= "outside"
end
function Side.Open()
    return not Side.Inside()
end
local function Inner()
    local p = INSET + (Kit.Theme().window.pad or 0)
    return p
end
function Side.Wheel(delta)
    if not content then return end
    local most = max(0, content:GetHeight() - scroll:GetHeight())
    offset = max(0, min(most, offset - delta * WHEEL))
    scroll:SetVerticalScroll(offset)
end
local function PickDock()
    local left, right = nil, nil
    if ns.Shell and ns.Shell.Room then left, right = ns.Shell.Room() end
    if not right or right >= W - OVERLAP then return "right" end
    if left and left >= W - OVERLAP then return "left" end
    return "inside"
end
local function PaintToggle()
    local open = Side.Open()
    local out = dock == "left"
    local dir = (open ~= out) and "Prev" or "Next"
    toggle:SetNormalTexture(ARROW:format(dir, "Up"))
    toggle:SetPushedTexture(ARROW:format(dir, "Down"))
    toggle.tipTitle = ns.T(open and "sum.side.in" or "sum.side.out")
    toggle.tip = ns.T("sum.side.tip")
end
local function Dock()
    dock = PickDock()
    local p = Inner()
    side:ClearAllPoints()
    toggle:ClearAllPoints()
    if dock == "right" then
        side:SetPoint("TOPLEFT", shell, "TOPRIGHT", -OVERLAP, 0)
        side:SetPoint("BOTTOMLEFT", shell, "BOTTOMRIGHT", -OVERLAP, 0)
        toggle:SetPoint("CENTER", shell, "RIGHT", -p, 0)
    elseif dock == "left" then
        side:SetPoint("TOPRIGHT", shell, "TOPLEFT", OVERLAP, 0)
        side:SetPoint("BOTTOMRIGHT", shell, "BOTTOMLEFT", OVERLAP, 0)
        toggle:SetPoint("CENTER", shell, "LEFT", p, 0)
    else
        side:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
        side:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
        if Side.Open() then
            toggle:SetPoint("CENTER", side, "LEFT", p, 0)
        else
            toggle:SetPoint("CENTER", shell, "RIGHT", -p, 0)
        end
    end
    side:SetWidth(W)
    PaintToggle()
end
local function Stack()
    local p = Inner()
    pageBg:ClearAllPoints()
    pageBg:SetPoint("TOPLEFT", side, "TOPLEFT", p, -p)
    pageBg:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -p, p)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", side, "TOPLEFT", p + PAD, -(p + PAD))
    scroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -(p + PAD), p + PAD)
    local width = floor(W - (p + PAD) * 2)
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
    local most = max(0, y - scroll:GetHeight())
    offset = min(offset, most)
    scroll:SetVerticalScroll(offset)
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
local function Refresh()
    if not side then return end
    if not Live() then
        side:Hide()
        toggle:Hide()
        Release()
        return
    end
    toggle:Show()
    Dock()
    if Side.Open() then
        side:Show()
        Stack()
    else
        side:Hide()
        Release()
    end
end
local function Redraw()
    Refresh()
    local fn = owner and redraws[owner]
    if fn then fn() end
end
local function Flip()
    Ui().sumPlace = Side.Inside() and "outside" or "inside"
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
    scroll = CreateFrame("ScrollFrame", nil, side)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Side.Wheel(delta) end)
    side:Hide()
    toggle = CreateFrame("Button", "HTP_FailWatchSideToggle", shell)
    toggle:SetWidth(TOGGLE)
    toggle:SetHeight(TOGGLE)
    toggle:SetFrameLevel(shell:GetFrameLevel() + LEVEL + 5)
    toggle:SetHighlightTexture(HILITE, "ADD")
    toggle:SetScript("OnEnter", Kit.TipShow)
    toggle:SetScript("OnLeave", Kit.TipHide)
    toggle:SetScript("OnClick", Flip)
    toggle:Hide()
    if ns.Shell and ns.Shell.OnPlace then ns.Shell.OnPlace(Refresh) end
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
    if owner ~= key then offset = 0 end
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
