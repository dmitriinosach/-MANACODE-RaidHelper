local _, ns = ...
local min, max = math.min, math.max
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
local STAY = 0.1
local REFRESH = 0.5
local PIC = 14
local PIC_DIM = 0.55
local CHECK = 18
local CHECK_PAD = 4
local STATUS_GAP = 6
local Acts = {}
ns.PanelActs = Acts
local fly
local title
local anchor
local host
local pool = {}
local checks = {}
local caps = {}
local stats = {}
local shown = {}
local used, usedChecks = 0, 0
local curH, curMin = BTN_H, BTN_MIN
local away, acc = 0, 0
local sideways = false
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
function Acts.Dress(b)
    local it = b.item
    local ok, why, on = it.state()
    if ok then b:Enable() else b:Disable() end
    if it.check then
        b:SetChecked(on and true or false)
    else
        b:SetActive(on)
    end
    if b.pic and it.icon then
        b.pic:SetDesaturated(not ok)
        b.pic:SetAlpha((on or not ok) and 1 or PIC_DIM)
    end
    b.tipTitle = it.title
    if type(it.tip) == "function" then b.tip = it.tip() else b.tip = it.tip end
    b.tipDim = not ok and why or it.hint
    return ok, why, on
end
local Dress = Acts.Dress
function Acts.Fire(b, button)
    local it = b.item
    if not it or not it.state() then return false end
    if button == "RightButton" then
        if not it.alt then return false end
        it.alt()
    else
        it.run()
    end
    return true
end
local function Status(r)
    local fs, row = stats[r], shown[r]
    if not fs or not row or not row.status then return false end
    fs:SetText(row.status() or "")
    return fs:GetStringWidth() > (fs.room or 0)
end
local Layout
local function Refresh()
    for i = 1, used do Dress(pool[i]) end
    for i = 1, usedChecks do Dress(checks[i]) end
    local grown = false
    for r = 1, #shown do
        if Status(r) then grown = true end
    end
    if grown then Layout(shown) end
end
local function Click(b, button)
    if Acts.Fire(b, button) then Refresh() end
end
local function Button(i)
    local b = pool[i]
    if not b then
        b = ns.Kit.Button(fly)
        ns.Kit.RoundButton(b)
        b:SetHeight(BTN_H)
        b.tipAnchor = "ANCHOR_NONE"
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:HookScript("OnEnter", PlaceTip)
        b.onClick = Click
        b.pic = b:CreateTexture(nil, "OVERLAY")
        b.pic:SetWidth(PIC)
        b.pic:SetHeight(PIC)
        b.pic:SetPoint("CENTER", b, "CENTER", 0, 0)
        pool[i] = b
    end
    b:Show()
    return b
end
local function CheckToggle(self)
    Click(self, "LeftButton")
end
local function Check(i)
    local c = checks[i]
    if not c then
        c = ns.Kit.Check(fly)
        c:SetWidth(CHECK)
        c:SetHeight(CHECK)
        c.tipAnchor = "ANCHOR_NONE"
        c:HookScript("OnEnter", PlaceTip)
        c.onToggle = function() CheckToggle(c) end
        checks[i] = c
    end
    c:Show()
    return c
end
local function Caption(i)
    local fs = caps[i]
    if not fs then
        fs = ns.Kit.Str(fly, "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        ns.Kit.Text(fs, "text.secondary")
        caps[i] = fs
    end
    fs:Show()
    return fs
end
local function StatusText(i)
    local fs = stats[i]
    if not fs then
        fs = ns.Kit.Str(fly, "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        ns.Kit.Text(fs, "text.muted")
        stats[i] = fs
    end
    return fs
end
local function PlaceItem(it, x, y)
    local w
    if it.check then
        usedChecks = usedChecks + 1
        local c = Check(usedChecks)
        c.item = it
        c.label:SetText(it.label)
        w = CHECK + CHECK_PAD + c.label:GetStringWidth()
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", x, y - (curH - CHECK) / 2)
        return w
    end
    used = used + 1
    local b = Button(used)
    b.item = it
    if it.icon then
        b:SetText("")
        it.icon(b.pic)
        b.pic:Show()
        w = curH
    else
        b.pic:Hide()
        b:SetText(it.label)
        w = max(curMin, b.text:GetStringWidth() + BTN_PAD)
    end
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", x, y)
    return w
end
function Layout(rows)
    shown = rows
    local Kit = ns.Kit
    curH = Kit.GrowH(BTN_H, "GameFontNormalSmall")
    curMin = math.floor(BTN_MIN * Kit.FontScale("GameFontNormalSmall", true) + 0.5)
    local titleH = Kit.GrowH(TITLE_H, "GameFontNormalSmall")
    title:SetHeight(titleH)
    local capW = 0
    for r = 1, #rows do
        local fs = Caption(r)
        fs:SetText(rows[r].title)
        fs:SetHeight(curH)
        StatusText(r):SetHeight(curH)
        capW = max(capW, fs:GetStringWidth())
    end
    for r = #rows + 1, #caps do caps[r]:Hide() end
    used, usedChecks = 0, 0
    local y = -(PAD + titleH + ROWGAP)
    local w = PAD * 2 + title:GetStringWidth()
    for r = 1, #rows do
        local fs = caps[r]
        fs:SetWidth(capW + 1)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, y)
        local x = PAD + capW + CAP_GAP
        local items = rows[r].items
        for k = 1, #items do
            x = x + PlaceItem(items[k], x, y) + GAP
        end
        local st = StatusText(r)
        if rows[r].status then
            st:SetText(rows[r].status() or "")
            st.room = st:GetStringWidth()
            st:SetWidth(st.room + 1)
            st:ClearAllPoints()
            st:SetPoint("TOPLEFT", x - GAP + STATUS_GAP, y)
            st:Show()
            x = x - GAP + STATUS_GAP + st.room + GAP
        else
            st.room = 0
            st:Hide()
        end
        w = max(w, x - GAP + PAD)
        y = y - curH - ROWGAP
    end
    for r = #rows + 1, #stats do stats[r]:Hide() end
    for i = used + 1, #pool do
        pool[i].item = nil
        pool[i]:Hide()
    end
    for i = usedChecks + 1, #checks do
        checks[i].item = nil
        checks[i]:Hide()
    end
    fly:SetWidth(w)
    fly:SetHeight(-y - ROWGAP + PAD)
end
local function PlaceSide(k)
    local right, hostR, hostL, left = anchor:GetRight(), host:GetRight(), host:GetLeft(), anchor:GetLeft()
    if not hostR or hostR * k + LIFT + fly:GetWidth() <= UIParent:GetRight() then
        fly:SetPoint("TOPLEFT", anchor, "TOPRIGHT", (hostR or 0) - (right or 0) + LIFT, PAD)
    else
        fly:SetPoint("TOPRIGHT", anchor, "TOPLEFT", (hostL or 0) - (left or 0) - LIFT, PAD)
    end
end
local function Place()
    fly:ClearAllPoints()
    local k = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if sideways then
        PlaceSide(k)
        return
    end
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
local function Box(f)
    local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
    if not (l and r and b and t) or r <= l or t <= b then return nil, 0, 0, 0 end
    local s = f:GetEffectiveScale()
    return l * s, r * s, b * s, t * s
end
local function OnBridge()
    local al, ar, ab, at = Box(anchor)
    local fl, fr, fb, ft = Box(fly)
    if not (al and fl) then return false end
    local x, y = GetCursorPosition()
    if at <= fb or ft <= ab then
        return x >= min(al, fl) and x <= max(ar, fr) and y >= min(at, ft) and y <= max(ab, fb)
    end
    return y >= min(ab, fb) and y <= max(at, ft) and x >= min(ar, fr) and x <= max(al, fl)
end
local function OnUpdate(self, elapsed)
    if not host or not host:IsShown() then
        Acts.Hide()
        return
    end
    if self:IsMouseOver(REACH, -REACH, -REACH, REACH) or (anchor and (anchor:IsMouseOver() or OnBridge())) then
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
    ns.Kit.Skin(fly, "pop")
    fly.sized = true
    title = ns.Kit.Str(fly, "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetHeight(TITLE_H)
    ns.Kit.Title(title)
    fly:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", OnUpdate))
    fly:Hide()
end
function Acts.Show(icon, panel, text, side)
    local rows = ns.Shell.ActionRows()
    if #rows == 0 then return false end
    if not fly then Build() end
    anchor, host, sideways = icon, panel, side and true or false
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
    if ns.Tip then ns.Tip.Hide() end
    fly:Hide()
end
ns.Kit.OnFont(function()
    if fly and fly:IsShown() and anchor then
        Layout(shown)
        Refresh()
        Place()
    end
end)
function Acts.IsShown()
    return fly ~= nil and fly:IsShown() and true or false
end
function Acts.IsOver()
    return fly ~= nil and fly:IsShown() and fly:IsMouseOver() and true or false
end
function Acts.Buttons()
    return pool, used
end
function Acts.Checks()
    return checks, usedChecks
end
