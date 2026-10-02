local _, ns = ...
local max = math.max
local PAD = 6
local GAP = 3
local ROWGAP = 4
local TITLE_H = 14
local BTN_H = 18
local BTN_PAD = 12
local BTN_MIN = 30
local CAP_GAP = 6
local LIFT = 4
local TIP_GAP = 4
local REACH = 6
local STAY = 0.35
local REFRESH = 0.5
local Acts = {}
ns.PanelActs = Acts
local fly
local title
local anchor
local host
local pool = {}
local caps = {}
local used = 0
local away, acc = 0, 0
local function PlaceTip(b)
    if not fly or GameTooltip:GetOwner() ~= b then return end
    GameTooltip:ClearAllPoints()
    local r, edge = fly:GetRight(), UIParent:GetRight()
    if r and edge and r + GameTooltip:GetWidth() + TIP_GAP > edge then
        GameTooltip:SetPoint("TOPRIGHT", fly, "TOPLEFT", -TIP_GAP, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", fly, "TOPRIGHT", TIP_GAP, 0)
    end
end
local function Dress(b)
    local it = b.item
    local ok, why, on = it.state()
    if ok then b:Enable() else b:Disable() end
    b:SetActive(on)
    b.tipTitle = it.title
    b.tip = it.tip
    b.tipDim = not ok and why or nil
    return ok, why, on
end
local function Refresh()
    for i = 1, used do Dress(pool[i]) end
end
local function Click(b)
    local it = b.item
    if not it or not it.state() then return end
    it.run()
    Refresh()
end
local function Button(i)
    local b = pool[i]
    if not b then
        b = ns.Kit.Button(fly)
        b:SetHeight(BTN_H)
        b.tipAnchor = "ANCHOR_NONE"
        b:HookScript("OnEnter", PlaceTip)
        b.onClick = Click
        pool[i] = b
    end
    b:Show()
    return b
end
local function Caption(i)
    local fs = caps[i]
    if not fs then
        fs = fly:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetHeight(BTN_H)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        ns.Kit.Text(fs, "text.secondary")
        caps[i] = fs
    end
    fs:Show()
    return fs
end
local function Layout(rows)
    local capW = 0
    for r = 1, #rows do
        local fs = Caption(r)
        fs:SetText(rows[r].title)
        capW = max(capW, fs:GetStringWidth())
    end
    for r = #rows + 1, #caps do caps[r]:Hide() end
    used = 0
    local y = -(PAD + TITLE_H + ROWGAP)
    local w = PAD * 2 + title:GetStringWidth()
    for r = 1, #rows do
        local fs = caps[r]
        fs:SetWidth(capW + 1)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, y)
        local x = PAD + capW + CAP_GAP
        local items = rows[r].items
        for k = 1, #items do
            used = used + 1
            local b = Button(used)
            b.item = items[k]
            b:SetText(items[k].label)
            local bw = max(BTN_MIN, b.text:GetStringWidth() + BTN_PAD)
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, y)
            x = x + bw + GAP
        end
        w = max(w, x - GAP + PAD)
        y = y - BTN_H - ROWGAP
    end
    for i = used + 1, #pool do
        pool[i].item = nil
        pool[i]:Hide()
    end
    fly:SetWidth(w)
    fly:SetHeight(-y - ROWGAP + PAD)
end
local function Place()
    fly:ClearAllPoints()
    local k = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local top, bottom, left = host:GetTop(), host:GetBottom(), anchor:GetLeft()
    local lift = (top or 0) - (anchor:GetTop() or 0) + LIFT
    local drop = (anchor:GetBottom() or 0) - (bottom or 0) + LIFT
    local h, w = fly:GetHeight(), fly:GetWidth()
    local up = not top or top * k + LIFT + h <= UIParent:GetTop()
    local right = not left or left * k + w <= UIParent:GetRight()
    local side = right and "LEFT" or "RIGHT"
    if up then
        fly:SetPoint("BOTTOM" .. side, anchor, "TOP" .. side, 0, lift)
    else
        fly:SetPoint("TOP" .. side, anchor, "BOTTOM" .. side, 0, -drop)
    end
end
local function OnUpdate(self, elapsed)
    if not host or not host:IsShown() then
        Acts.Hide()
        return
    end
    if self:IsMouseOver(REACH, -REACH, -REACH, REACH) or (anchor and anchor:IsMouseOver()) then
        away = 0
    else
        away = away + elapsed
        if away >= STAY then
            Acts.Hide()
            return
        end
    end
    acc = acc + elapsed
    if acc >= REFRESH then
        acc = 0
        Refresh()
    end
end
local function Build()
    fly = CreateFrame("Frame", nil, UIParent)
    fly:SetFrameStrata("DIALOG")
    fly:SetClampedToScreen(true)
    fly:EnableMouse(true)
    ns.Kit.Skin(fly, "float")
    title = fly:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetHeight(TITLE_H)
    ns.Kit.Title(title)
    fly:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", OnUpdate))
    fly:Hide()
end
function Acts.Show(icon, panel, text)
    local rows = ns.Shell.ActionRows()
    if #rows == 0 then return false end
    if not fly then Build() end
    anchor, host = icon, panel
    title:SetText(text)
    Layout(rows)
    Refresh()
    Place()
    away, acc = 0, 0
    fly:Show()
    return true
end
function Acts.Hide()
    if not fly then return end
    local owner = GameTooltip:GetOwner()
    if owner and owner.GetParent and owner:GetParent() == fly then GameTooltip:Hide() end
    fly:Hide()
end
function Acts.IsShown()
    return fly ~= nil and fly:IsShown() and true or false
end
function Acts.Buttons()
    return pool, used
end
