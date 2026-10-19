local ADDON, ns = ...
local floor = math.floor
local max = math.max
local PAD = 4
local ROW = 22
local IN = 6
local PIC = 16
local PIC_GAP = 8
local TAIL = 10
local ARROW = 12
local SEP_H = 7
local SIDE_GAP = 2
local STAY, REACH = 0.35, 6
local NAME = "HTP_FailWatchPanelMenu"
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local ARROW_TEX = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ITEMS = {
    { key = "log" },
    { key = "gp" },
    { key = "raid" },
    { key = "spam" },
    { key = "timer", sub = true },
    { key = "cd" },
    { key = "settings" },
    { key = "sep", sep = true },
    { key = "lock" },
    { key = "normal", label = "panel.normal", tip = "panel.normal.tip", pic = "expand" },
}
local Menu = {}
ns.PanelMenu = Menu
local menu
local anchor
local rows = {}
local sep
local away = 0
local function Label(r)
    if r.key == "lock" then return ns.T(ns.Panel.IsLocked() and "panel.unlock" or "panel.lock") end
    return ns.T(r.label)
end
local function Tip(r)
    if r.key == "lock" then return ns.T(ns.Panel.IsLocked() and "panel.unlock.tip" or "panel.lock.tip") end
    if not r.tipKey then return nil end
    local text = ns.T(r.tipKey)
    if r.key == "log" then text = text .. "\n" .. ns.T(ns.Panel.RecStateKey()) end
    return text
end
local function Pic(r)
    if r.key == "lock" then return ns.Panel.IsLocked() and "lock" or "unlock" end
    return r.picKey
end
local function Paint(r)
    local hot = r.hovered
    if hot then r.hl:Show() else r.hl:Hide() end
    local tok = hot and "button.textHover" or "text.primary"
    ns.Kit.Text(r.text, tok)
    ns.Kit.Tint(r.pic, tok)
    if r.arrow then ns.Kit.Tint(r.arrow, hot and tok or "text.muted") end
end
local function RowEnter(r)
    r.hovered = true
    Paint(r)
    if r.sub then
        GameTooltip:Hide()
        ns.Panel.ShowActs(r, menu, true)
        return
    end
    if ns.PanelActs then ns.PanelActs.Hide() end
    r.tipTitle = false
    r.tip = Tip(r)
    ns.Kit.TipShow(r)
end
local function RowLeave(r)
    r.hovered = false
    Paint(r)
    ns.Kit.TipHide()
end
local function RowClick(r)
    local k = r.key
    if r.sub then
        ns.Panel.ShowActs(r, menu, true)
        return
    end
    if k == "lock" then
        ns.Panel.SetLocked(not ns.Panel.IsLocked())
        RowEnter(r)
        return
    end
    GameTooltip:Hide()
    Menu.Hide()
    if k == "normal" then
        ns.Panel.SetCompact(false)
        return
    end
    ns.Panel.Open(k)
end
local function MakeRow(it, def)
    local r = CreateFrame("Button", nil, menu)
    r:SetHeight(ROW)
    r.key, r.sub = it.key, it.sub
    r.label = it.label or (def and def.label)
    r.tipKey = it.tip or (def and def.tip)
    r.picKey = it.pic or it.key
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    ns.Kit.Paint(r.hl, "row.bgHover")
    r.pic = r:CreateTexture(nil, "ARTWORK")
    r.pic:SetWidth(PIC)
    r.pic:SetHeight(PIC)
    r.pic:SetPoint("LEFT", IN, 0)
    r.text = ns.Kit.Str(r, "GameFontHighlight")
    r.text:SetPoint("LEFT", IN + PIC + PIC_GAP, 0)
    r.text:SetJustifyH("LEFT")
    if it.sub then
        r.arrow = r:CreateTexture(nil, "ARTWORK")
        r.arrow:SetWidth(ARROW)
        r.arrow:SetHeight(ARROW)
        r.arrow:SetPoint("RIGHT", -IN, 0)
        r.arrow:SetTexture(ARROW_TEX)
    end
    r.tipAnchor = "ANCHOR_RIGHT"
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
    r:SetScript("OnClick", RowClick)
    return r
end
local order = {}
local function Dress()
    local w = 0
    local rowH = ns.Kit.GrowH(ROW, "GameFontHighlight")
    local y = PAD
    for i = 1, #order do
        local o = order[i]
        if o.row then
            o.row:SetHeight(rowH)
            o.row:ClearAllPoints()
            o.row:SetPoint("TOPLEFT", PAD, -y)
            y = y + rowH
        else
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", PAD + IN, -(y + floor(SEP_H / 2)))
            y = y + SEP_H
        end
    end
    menu:SetHeight(y + PAD)
    for i = 1, #rows do
        local r = rows[i]
        r.text:SetText(Label(r))
        r.pic:SetTexture(ART .. Pic(r) .. ".tga")
        Paint(r)
        w = max(w, r.text:GetStringWidth() or 0)
    end
    local rw = floor(IN + PIC + PIC_GAP + w + TAIL + ARROW + IN + 0.5)
    for i = 1, #rows do rows[i]:SetWidth(rw) end
    sep:SetWidth(rw - IN * 2)
    menu:SetWidth(rw + PAD * 2)
end
local function Step(self, elapsed)
    if not anchor or not anchor:IsVisible() then
        Menu.Hide()
        return
    end
    local Acts = ns.PanelActs
    local over = self:IsMouseOver(REACH, -REACH, -REACH, REACH) or anchor:IsMouseOver() or (Acts and Acts.IsOver())
    if not over and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        Menu.Hide()
        return
    end
    if over or (Acts and Acts.IsShown()) then
        away = 0
        return
    end
    away = away + elapsed
    if away >= STAY then Menu.Hide() end
end
local function OnHide()
    if ns.PanelActs then ns.PanelActs.Hide() end
    local owner = GameTooltip:GetOwner()
    if owner and owner.GetParent and owner:GetParent() == menu then GameTooltip:Hide() end
    for i = 1, #rows do
        rows[i].hovered = false
        Paint(rows[i])
    end
end
local function Build()
    menu = CreateFrame("Frame", NAME, UIParent)
    menu:SetFrameStrata("DIALOG")
    menu.sized = true
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    ns.Kit.Skin(menu, "float")
    local defs = {}
    for _, d in ipairs(ns.Panel.ICONS) do defs[d.key] = d end
    for i = 1, #ITEMS do
        local it = ITEMS[i]
        if it.sep then
            sep = menu:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            ns.Kit.Paint(sep, "surface.edge")
            order[#order + 1] = {}
        else
            local r = MakeRow(it, defs[it.key])
            rows[#rows + 1] = r
            order[#order + 1] = { row = r }
        end
    end
    menu:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", Step))
    menu:SetScript("OnHide", OnHide)
    tinsert(UISpecialFrames, NAME)
    menu:Hide()
end
local function Place()
    menu:ClearAllPoints()
    local k = (anchor:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local right, edge = anchor:GetRight(), UIParent:GetRight()
    if right and edge and right * k + SIDE_GAP + menu:GetWidth() > edge then
        menu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -SIDE_GAP, 0)
    else
        menu:SetPoint("TOPLEFT", anchor, "TOPRIGHT", SIDE_GAP, 0)
    end
end
function Menu.Show(a)
    if not menu then Build() end
    anchor = a
    Dress()
    Place()
    away = 0
    menu:Show()
end
function Menu.Hide()
    if menu and menu:IsShown() then menu:Hide() end
end
function Menu.IsShown()
    return menu ~= nil and menu:IsShown() and true or false
end
function Menu.Refresh()
    if Menu.IsShown() then Dress() end
end
ns.Kit.OnFont(function()
    if menu and menu:IsShown() then
        Dress()
        Place()
    elseif menu then
        Dress()
    end
end)
function Menu.Rows()
    return rows
end
