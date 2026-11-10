local _, ns = ...
local Kit = ns.Kit
local SELECT_ARROW = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_COORD = { 0, 0.9375, 0.9375, 0.4375 }
local ARROW_W, ARROW_H = 11, 6
local ROW_H, ROW_GAP, LIST_PAD = 20, 2, 6
local HEAD_H = 18
local MENU_W = 160
local SEG_W, SEG_CAP_GAP = 210, 10
local max = math.max
local ceil = math.ceil
local list, catcher, openOn, head, menuOn
local picks
local pickUsed = 0
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
local checks, checkUsed = {}, 0
local function AcquireCheck()
    checkUsed = checkUsed + 1
    local c = checks[checkUsed]
    if not c then
        c = Kit.Check(list)
        Kit.Bind(c.label, "GameFontNormalSmall")
        c.label:SetJustifyH("LEFT")
        c.label:SetWordWrap(false)
        c.tipTitle = false
        checks[checkUsed] = c
    end
    c:Show()
    return c
end
local segs, segUsed = {}, 0
local function AcquireSeg()
    segUsed = segUsed + 1
    local p = segs[segUsed]
    if not p then
        p = { seg = Kit.Segments(list), cap = Kit.Str(list, "GameFontNormalSmall") }
        p.cap:SetJustifyH("LEFT")
        p.cap:SetWordWrap(false)
        Kit.Text(p.cap, "list.head")
        segs[segUsed] = p
    end
    p.seg:Show()
    p.cap:Show()
    return p
end
local function PickRun(key, item)
    if item.run then item.run(key) end
end
local function AcquirePick(opt, onPick)
    if not picks then picks = Kit.ThemePick(list, PickRun) end
    pickUsed = pickUsed + 1
    return picks:Draw(pickUsed, { key = opt.key, label = opt.label or "", colors = opt.swatch, on = opt.check == true,
                                  run = opt.onSwatch or function()
                                      Kit.SelectClose()
                                      onPick(opt.key, opt)
                                  end })
end
local notes, noteUsed = {}, 0
local function AcquireNote()
    noteUsed = noteUsed + 1
    local fs = notes[noteUsed]
    if not fs then
        fs = Kit.Str(list, "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        notes[noteUsed] = fs
    end
    fs:Show()
    return fs
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
    catcher:SetScript("OnHide", function(self)
        if self:IsShown() then Kit.SelectClose() end
    end)
    catcher:Hide()
    list = CreateFrame("Frame", nil, catcher)
    list:SetFrameLevel(catcher:GetFrameLevel() + 10)
    list:SetClampedToScreen(true)
    head = Kit.Str(list, "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD + 4, -LIST_PAD - 3)
    head:SetJustifyH("LEFT")
    Kit.Text(head, "list.head")
    PaintList()
    return list
end
function Kit.SelectClose()
    if catcher then catcher:Hide() end
    menuOn = nil
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
    checkUsed = 0
    segUsed = 0
    noteUsed = 0
    pickUsed = 0
    local rowH = Kit.GrowH(ROW_H, "GameFontNormalSmall")
    local headH = Kit.GrowH(HEAD_H, "GameFontNormalSmall")
    local w = (sel and sel:GetWidth() or MENU_W) - LIST_PAD * 2
    if title then
        head:SetText(title)
        head:Show()
        local need = head:GetStringWidth() + 8
        if need > w then w = need end
    else
        head:Hide()
    end
    local rows, capW = {}, 0
    for _, opt in ipairs(options or {}) do
        if opt.swatch then
            local row = AcquirePick(opt, onPick)
            if row.need > w then w = row.need end
            rows[#rows + 1] = { pick = row }
        elseif opt.seg then
            local p = AcquireSeg()
            p.cap:SetText(opt.label or "")
            p.seg:SetCells(opt.seg, opt.value)
            p.seg.onPick = opt.onSeg
            capW = max(capW, ceil(p.cap:GetStringWidth() or 0) + SEG_CAP_GAP)
            rows[#rows + 1] = { seg = p, need = p.seg:Measure(Kit.FontGrow(SEG_W, "GameFontNormalSmall")) }
        elseif opt.note then
            local fs = AcquireNote()
            fs:SetText(opt.label or "")
            Kit.Text(fs, opt.note)
            rows[#rows + 1] = { note = fs }
        elseif opt.check ~= nil then
            local c = AcquireCheck()
            c:SetWidth(rowH)
            c:SetHeight(rowH)
            c:SetChecked(opt.check)
            c.label:SetText(opt.label or opt.key)
            c.tip = opt.tip
            if opt.disabled then c:Disable() else c:Enable() end
            c.onToggle = function()
                Kit.SelectClose()
                onPick(opt.key, opt)
            end
            local need = rowH + 2 + c.label:GetStringWidth() + 8
            if need > w then w = need end
            rows[#rows + 1] = { check = c }
        else
            local b = Acquire()
            Kit.ButtonKind(b, opt.kind)
            b.text:ClearAllPoints()
            if opt.kind then
                b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
                b.text:SetJustifyH("CENTER")
            else
                b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
                b.text:SetJustifyH("LEFT")
            end
            b:SetText(opt.label or opt.key)
            b.tip = opt.tip
            b.tipTitle = opt.tipTitle
            if type(value) == "table" then b.active = value[opt.key] == true else b.active = value ~= nil and opt.key == value end
            b.tint = opt.color
            if opt.disabled then b:Disable() else b:Enable() end
            b.onClick = function()
                Kit.SelectClose()
                onPick(opt.key, opt)
            end
            Kit.StyleButton(b)
            local need = b.text:GetStringWidth() + 22
            if need > w then w = need end
            rows[#rows + 1] = { button = b }
        end
    end
    for i = 1, #rows do
        local r = rows[i]
        if r.seg and capW + r.need > w then w = capW + r.need end
    end
    for i = used + 1, #pool do pool[i]:Hide() end
    for i = checkUsed + 1, #checks do checks[i]:Hide() end
    for i = segUsed + 1, #segs do segs[i].seg:Hide() segs[i].cap:Hide() end
    for i = noteUsed + 1, #notes do notes[i]:Hide() end
    if picks then picks:HideFrom(pickUsed + 1) end
    if used + checkUsed + segUsed + pickUsed == 0 then Kit.SelectClose() return end
    local y = LIST_PAD + (title and headH or 0)
    for i = 1, #rows do
        local r = rows[i]
        local f, h
        if r.seg then
            local s, cap = r.seg.seg, r.seg.cap
            s:Place(w - capW)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD + capW, -y)
            cap:ClearAllPoints()
            cap:SetPoint("LEFT", list, "TOPLEFT", LIST_PAD + 2, -(y + (s.cells[1]:GetHeight() + 6) / 2))
            h = s:GetHeight()
        elseif r.note then
            f = r.note
            f:SetWidth(w - 4)
            h = ceil(f:GetStringHeight() or 0)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD + 2, -y)
        else
            f = r.check or r.button or r.pick
            if not r.check then f:SetWidth(w) end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD, -y)
            h = rowH
        end
        y = y + h + ROW_GAP
    end
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
    local build
    if type(items) == "function" then build, items = items, items() end
    local options, title, value = {}, nil, {}
    for i = 1, #items do
        local it = items[i]
        if it.isTitle and not title and #options == 0 then
            title = it.text
        elseif it.isTitle then
            options[#options + 1] = { key = i, label = it.text, disabled = true, tipTitle = false }
        else
            options[#options + 1] = { key = i, label = it.text, disabled = it.disabled, tip = it.tip, tipTitle = false,
                                      check = it.checked, seg = it.seg, swatch = it.swatch, value = it.value, note = it.note, kind = it.kind,
                                      onSeg = it.seg and function(k)
                                          it.value = k
                                          if it.func then it.func(k) end
                                          Kit.Menu(build or items, anchor)
                                      end,
                                      onSwatch = it.swatch and build and function()
                                          if it.func then it.func() end
                                          Kit.Menu(build, anchor)
                                      end or nil }
        end
    end
    ShowList(anchor, options, value, function(key)
        local it = items[key]
        if it and it.func then it.func() end
    end, nil, title)
    if catcher and catcher:IsShown() then menuOn = anchor end
end
function Kit.MenuOpenAt(anchor)
    return anchor ~= nil and menuOn == anchor and catcher ~= nil and catcher:IsShown() or false
end
Kit.OnTheme(PaintList)
