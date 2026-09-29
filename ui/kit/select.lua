local _, ns = ...
local Kit = ns.Kit
local SELECT_ARROW = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_COORD = { 0, 0.9375, 0.9375, 0.4375 }
local ARROW_W, ARROW_H = 11, 6
local ROW_H, ROW_GAP, LIST_PAD = 20, 2, 6
local HEAD_H = 18
local MENU_W = 160
local list, catcher, openOn, head
local pool = {}
local used = 0
local function RootOf(f)
    if not f then return UIParent end
    while f do
        local p = f:GetParent()
        if not p or p == UIParent then return f end
        f = p
    end
end
local function PaintList()
    if list then Kit.Backdrop(list, Kit.Theme().list) end
end
local function Acquire()
    used = used + 1
    local b = pool[used]
    if not b then
        b = Kit.Button(list)
        b:SetHeight(ROW_H)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.text:SetJustifyH("LEFT")
        pool[used] = b
    end
    b:Show()
    return b
end
local function EnsureList(sel)
    local win = RootOf(sel)
    if not win then return nil end
    if list then
        if catcher:GetParent() ~= win then
            catcher:SetParent(win)
            catcher:ClearAllPoints()
            catcher:SetAllPoints(win)
            catcher:SetFrameStrata("FULLSCREEN_DIALOG")
            list:SetFrameLevel(catcher:GetFrameLevel() + 10)
        end
        return list
    end
    catcher = CreateFrame("Frame", nil, win)
    catcher:SetAllPoints(win)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function() Kit.SelectClose() end)
    catcher:Hide()
    list = CreateFrame("Frame", nil, catcher)
    list:SetFrameLevel(catcher:GetFrameLevel() + 10)
    list:SetClampedToScreen(true)
    head = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD + 4, -LIST_PAD - 3)
    head:SetJustifyH("LEFT")
    Kit.Text(head, "list.head")
    PaintList()
    return list
end
function Kit.SelectClose()
    if catcher then catcher:Hide() end
    if openOn then
        openOn.active = false
        Kit.StyleButton(openOn)
        openOn = nil
    end
end
local function ShowList(sel, options, value, onPick, owner, title)
    Kit.SelectClose()
    if not EnsureList(sel) then return end
    local win = RootOf(sel)
    openOn = owner
    used = 0
    local y = LIST_PAD
    local w = (sel and sel:GetWidth() or MENU_W) - LIST_PAD * 2
    if title then
        head:SetText(title)
        head:Show()
        y = y + HEAD_H
        local need = head:GetStringWidth() + 8
        if need > w then w = need end
    else
        head:Hide()
    end
    for _, opt in ipairs(options or {}) do
        local b = Acquire()
        b:SetText(opt.label or opt.key)
        b.tip = opt.tip
        b.tipTitle = opt.tipTitle
        b.active = (value ~= nil and opt.key == value)
        b.tint = opt.color
        if opt.disabled then b:Disable() else b:Enable() end
        b.onClick = function()
            Kit.SelectClose()
            onPick(opt.key, opt)
        end
        Kit.StyleButton(b)
        local need = b.text:GetStringWidth() + 22
        if need > w then w = need end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD, -y)
        y = y + ROW_H + ROW_GAP
    end
    for i = used + 1, #pool do pool[i]:Hide() end
    if used == 0 then Kit.SelectClose() return end
    for i = 1, used do pool[i]:SetWidth(w) end
    list:SetWidth(w + LIST_PAD * 2)
    local h = y - ROW_GAP + LIST_PAD
    list:SetHeight(h)
    if not sel then
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale - 4, cy / scale + 4)
        catcher:Show()
        return
    end
    local up = false
    local bottom, top = sel:GetBottom(), sel:GetTop()
    local floorY, ceilY = win:GetBottom(), win:GetTop()
    if bottom and top and floorY and ceilY then
        up = (bottom - 2 - h < floorY) and (top + 2 + h <= ceilY)
    end
    list:ClearAllPoints()
    if up then
        list:SetPoint("BOTTOMLEFT", sel, "TOPLEFT", 0, 2)
    else
        list:SetPoint("TOPLEFT", sel, "BOTTOMLEFT", 0, -2)
    end
    catcher:Show()
    if owner then
        owner.active = true
        Kit.StyleButton(owner)
    end
end
function Kit.Popup(anchor, options, onPick)
    ShowList(anchor, options, nil, onPick, nil)
end
local function OpenList(sel)
    if sel.btnDisabled then return end
    if openOn == sel then Kit.SelectClose() return end
    ShowList(sel, sel.options, sel.value, function(key, opt)
        sel.value = key
        sel:SetText(opt.label or key)
        if sel.onPick then sel.onPick(key, opt) end
    end, sel)
end
local function SetOptions(self, options, value)
    if openOn == self then return end
    self.options = options
    local cur
    for _, o in ipairs(options or {}) do
        if o.key == value then cur = o end
    end
    if not cur then cur = options and options[1] end
    self.value = cur and cur.key or value
    self:SetText(cur and (cur.label or cur.key) or "?")
end
function Kit.Select(parent)
    local b = Kit.Button(parent)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -(ARROW_W + 8), 0)
    b.text:SetJustifyH("LEFT")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetTexture(SELECT_ARROW)
    b.arrow:SetTexCoord(ARROW_COORD[1], ARROW_COORD[2], ARROW_COORD[3], ARROW_COORD[4])
    b.arrow:SetWidth(ARROW_W)
    b.arrow:SetHeight(ARROW_H)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.clickSfx = "open"
    b.onClick = OpenList
    b.SetOptions = SetOptions
    return b
end
function Kit.Menu(items, anchor)
    local options, title, value = {}, nil, nil
    for i = 1, #items do
        local it = items[i]
        if it.isTitle and not title and #options == 0 then
            title = it.text
        elseif not it.isTitle then
            options[#options + 1] = { key = i, label = it.text, disabled = it.disabled, tipTitle = false }
            if it.checked then value = i end
        end
    end
    ShowList(anchor, options, value, function(key)
        local it = items[key]
        if it and it.func then it.func() end
    end, nil, title)
end
Kit.OnTheme(PaintList)
