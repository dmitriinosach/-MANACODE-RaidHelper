local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local QUICK = 20
local ICON = 16
local ROW = 19
local EDIT_H = 18
local STATUS_W = 18
local ACT_H = 20
local FLY_PAD = 8
local FLY_GAP = 6
local BOTTOM_PAD = 10
local STRIPE = 2
local HEAD = 30
local HILITE = "Interface\\Buttons\\ButtonHilight-Square"
local pult, w, cap, keep, keepFs, fold, quick, box, grab, wipeBtn
local quickBtns, rows = {}, {}
local mode = "closed"
local fly = false
local built = false
local refresh
local function listH()
    return ns.Marks.COUNT * ROW + 4 + ACT_H
end
local function paintIcon(b)
    local M = ns.Marks
    local i = b.i
    local can = M.CanMark()
    local e = M.View(i)
    local yielded, lent = M.Flags(i)
    local o = e.owner
    local alpha, token = 0.3, nil
    if o and e.now then
        alpha, token = 1, (o.src == "pin") and "text.title" or "text.secondary"
    elseif o then
        alpha, token = 0.6, "text.warn"
    elseif e.list[1] then
        alpha, token = 0.45, "sem.death"
    end
    if yielded or lent then token = "text.warn" end
    if not can then alpha = 0.35 end
    b.icon:SetDesaturated(not can)
    b.icon:SetAlpha(alpha)
    if b.under then
        if token then
            ns.PaintToken(b.under, token)
            b.under:Show()
        else
            b.under:Hide()
        end
    end
    b.tipTitle = ns.T("mark" .. i)
    b.tip = M.Describe(i)
    b.tipDim = ns.T(can and "marksTipHow" or "tipNeedOfficer")
end
local function expand()
    if mode == "quick" then fly = true else ns.Marks.SetOpen(true) end
    refresh()
end
local function onIcon(self, button)
    local r
    if button == "RightButton" then
        r = ns.Marks.Release(self.i)
    else
        r = ns.Marks.Target(self.i)
    end
    if r == "none" then expand() end
    paintIcon(self)
    ns.TipShow(self)
end
local function newIcon(parent, i, size, stripe)
    local b = ns.NewFrame("Button", nil, parent)
    b.i = i
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    ns.Icon.Mark(b.icon, i)
    if stripe then
        b.under = ns.Fill(b, "OVERLAY")
        b.under:SetHeight(STRIPE)
        b.under:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 1, -1)
        b.under:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -1, -1)
    end
    b:SetHighlightTexture(HILITE, "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onIcon)
    b:SetScript("OnEnter", function(self)
        paintIcon(self)
        ns.TipShow(self)
    end)
    b:SetScript("OnLeave", ns.TipHide)
    return b
end
local function hint(r)
    local M = ns.Marks
    local e = M.View(r.i)
    local s
    if M.Pin(r.i) or r.edit.focused then
        s = nil
    elseif e.owner then
        s = ns.T("marksHintSlot", e.owner.name)
    elseif e.list[1] then
        s = ns.T("marksHintSlot", e.list[1].name)
    else
        s = ns.T("marksHintFree")
    end
    if s then
        r.hint:SetText(s)
        r.hint:Show()
    else
        r.hint:Hide()
    end
end
local function newRow(i)
    local r = { i = i }
    r.btn = newIcon(box, i, ICON, false)
    local e = ns.MakeEdit(box)
    e:SetHeight(EDIT_H)
    e:SetMaxLetters(120)
    e:SetPoint("LEFT", r.btn, "RIGHT", 4, 0)
    e:SetWidth(w - ICON - 4 - STATUS_W - 4)
    e.tip = ns.T("tipMarkNames")
    e.onCommit = function(v)
        if (v or "") ~= ns.Marks.PinText(i) then ns.Marks.SetPins(i, v) end
        hint(r)
    end
    e:HookScript("OnEditFocusGained", function() r.hint:Hide() end)
    r.edit = e
    r.hint = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.hint:SetPoint("LEFT", e, "LEFT", 7, 0)
    r.hint:SetPoint("RIGHT", e, "RIGHT", -4, 0)
    r.hint:SetJustifyH("LEFT")
    ns.PaintText(r.hint, "text.muted")
    r.status = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.status:SetPoint("LEFT", e, "RIGHT", 4, 0)
    r.status:SetWidth(STATUS_W)
    r.status:SetJustifyH("CENTER")
    return r
end
local function placeRows(pad)
    for k, r in ipairs(rows) do
        r.btn:ClearAllPoints()
        r.btn:SetPoint("TOPLEFT", box, "TOPLEFT", pad, -(pad + (k - 1) * ROW + 1))
    end
    local half = math.floor((w - 6) / 2)
    grab:SetSize(half, ACT_H)
    wipeBtn:SetSize(half, ACT_H)
    grab:ClearAllPoints()
    grab:SetPoint("TOPLEFT", box, "TOPLEFT", pad, -(pad + ns.Marks.COUNT * ROW + 4))
    wipeBtn:ClearAllPoints()
    wipeBtn:SetPoint("LEFT", grab, "RIGHT", 6, 0)
    box:SetSize(w + pad * 2, listH() + pad * 2)
end
local function room()
    local top = cap:GetBottom()
    local bottom = pult:GetBottom()
    if not top or not bottom then return 0 end
    return top - bottom - BOTTOM_PAD
end
local function fits()
    return room() >= HEAD + listH()
end
local function layout()
    if not built then return end
    if fits() then
        mode = ns.Marks.Open() and "inline" or "quick"
    else
        mode = fly and "fly" or "quick"
    end
    box:ClearAllPoints()
    if mode == "inline" then
        quick:Hide()
        box:SetFrameStrata(pult:GetFrameStrata())
        box:SetBackdrop(nil)
        box.kitBd = nil
        placeRows(0)
        box:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", 0, -HEAD)
        box:Show()
    elseif mode == "fly" then
        quick:Show()
        box:SetFrameStrata("DIALOG")
        ns.Backdrop(box, ns.Theme.list)
        placeRows(FLY_PAD)
        box:SetPoint("BOTTOMLEFT", pult, "BOTTOMRIGHT", FLY_GAP, 0)
        box:Show()
    else
        quick:Show()
        box:Hide()
    end
    local open = mode ~= "quick"
    fold:SetText(open and "-" or "+")
    fold.tipTitle = ns.T(open and "tipMarksFold" or "tipMarksUnfold")
end
function refresh()
    if not built or not pult:IsVisible() then return end
    local M = ns.Marks
    keep:SetChecked(M.Enabled())
    local who = M.InRaid() and ns.Keeper.Who()
    local status
    if not M.Enabled() then
        status = ns.T("marksStatusOff")
    elseif who and who ~= UnitName("player") then
        status = ns.T("marksStatusPeer", who)
    elseif M.Active() then
        status = ns.T("marksStatusMine")
    elseif M.InRaid() and not M.CanMark() then
        status = ns.T("marksStatusRights")
    end
    keep.tipDim = status
    keepFs:SetText(status or "")
    layout()
    for _, b in ipairs(quickBtns) do paintIcon(b) end
    if box:IsShown() then
        local can = M.CanMark()
        for _, r in ipairs(rows) do
            paintIcon(r.btn)
            if not r.edit.focused then r.edit:SetValue(M.PinText(r.i)) end
            hint(r)
            local e = M.View(r.i)
            if e.owner and e.now then
                r.status:SetText(ns.T("marksOk"))
                ns.PaintText(r.status, "sem.ready")
            else
                r.status:SetText("-")
                ns.PaintText(r.status, "text.muted")
            end
        end
        if can then
            wipeBtn:Enable()
            wipeBtn.tip = ns.T("tipMarksWipe")
        else
            wipeBtn:Disable()
            wipeBtn.tip = ns.T("tipNeedOfficer")
        end
    end
end
local placedAt, placedDy
local function place(anchor, dy)
    if not built or (placedAt == anchor and placedDy == dy) then return end
    placedAt, placedDy = anchor, dy
    cap:ClearAllPoints()
    cap:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, dy)
    refresh()
end
local function build(parent, width)
    pult, w = parent, width
    cap = ns.Caption(pult, ns.T("pultMarks"), w - 24)
    fold = ns.MakeKitButton(pult)
    fold:SetSize(18, 16)
    fold:SetPoint("LEFT", cap, "LEFT", w - 18, 0)
    fold.onClick = function()
        if mode == "inline" then
            ns.Marks.SetOpen(false)
        elseif mode == "fly" then
            fly = false
        elseif fits() then
            ns.Marks.SetOpen(true)
        else
            fly = true
        end
        refresh()
    end
    keep = ns.MakeCheck(pult)
    keep:SetSize(18, 18)
    keep:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", -2, -6)
    keep.label:SetText(ns.T("marksKeep"))
    keep.tipTitle = ns.T("marksKeepTitle")
    keep.tip = ns.T("tipMarksKeep")
    keep.onToggle = function(on) ns.Marks.SetEnabled(on) end
    keepFs = pult:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keepFs:SetPoint("TOPRIGHT", cap, "BOTTOMLEFT", w, -10)
    keepFs:SetWidth(w - 90)
    keepFs:SetJustifyH("RIGHT")
    ns.PaintText(keepFs, "text.secondary")
    quick = ns.NewFrame("Frame", nil, pult)
    quick:SetSize(w, QUICK + STRIPE + 1)
    quick:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", 0, -HEAD)
    local gap = math.floor((w - ns.Marks.COUNT * QUICK) / (ns.Marks.COUNT - 1))
    for i = 1, ns.Marks.COUNT do
        local b = newIcon(quick, i, QUICK, true)
        b:SetPoint("TOPLEFT", quick, "TOPLEFT", (i - 1) * (QUICK + gap), 0)
        quickBtns[i] = b
    end
    box = ns.NewFrame("Frame", nil, pult)
    box:EnableMouse(true)
    box:Hide()
    grab = ns.MakeKitButton(box)
    grab:SetText(ns.T("btnMarksGrab"))
    grab.tip = ns.T("tipMarksGrab")
    grab.onClick = function() ns.Marks.Grab() end
    wipeBtn = ns.MakeKitButton(box)
    wipeBtn:SetText(ns.T("btnMarksWipe"))
    wipeBtn.tint = ns.DANGER
    wipeBtn.onClick = function() ns.Marks.ClearAll() end
    for i = 1, ns.Marks.COUNT do rows[i] = newRow(i) end
    pult:HookScript("OnHide", function() fly = false end)
    pult:HookScript("OnShow", function() refresh() end)
    built = true
end
ns.Session.OnChange(refresh)
ns.Marks.OnChange(refresh)
ns.window:OnSize(layout)
ns.PultMarks = {
    Build = build, Place = place, Refresh = refresh,
    Mode = function() return mode end,
    Quick = quickBtns, Rows = rows,
    Parts = function() return cap, pult, fold, keep, grab, wipeBtn end,
}
