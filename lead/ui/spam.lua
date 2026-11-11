local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 10
local VPAD = 7
local GAP = 6
local LINE_GAP = 4
local CHECK_H = 17
local ICON = 14
local CLS_ICON = 16
local BASE = "GameFontHighlightSmall"
local PREVIEW_FONT = "ChatFontNormal"
local STEP_BTN = 18
local NEED_W = 22
local CLS_W = 170
local SPEC_W = 96
local SPEC_GAP = 8
local ROW_PAD = 3
local ROW_EXTRA = 10
local PANEL_GAP = 6
local PREVIEW_MAX = 3
local BAR_W = 12
local TICK_W = 30
local TICK_EVERY = 0.25
local BLOCK_GAP = 8
local CHAN_BIG = 1.25
local styleSel, styleCap, newBtn, copyBtn, msgBlock, msgCap, optBlock, rotCheck, autoCheck
local pane, textSel, delBtn, body, textBox, progE, reqSel, reqE, lootSel, timeE, dsE
local defBtn, tplBtn, preview, counter, chanPool, chanBox, everyCap, everyE, everySec, ownCheck
local previewPanel, textPanel, chanCap, specsPanel, specsCap, needsCap, counterBox, previewCap
local previewLines = 1
local laidCols = 1
local natural = 0
local flowUnits, markBtns = {}, {}
local roleHeads = {}
local headBg
local colLines = {}
local checks = {}
local classChecks = {}
local classRows = {}
local needVals = {}
local built = false
local page, scroller
local function paneW()
    return ns.window.PANE_W - BAR_W
end
local function textOptions()
    local out = {}
    for i, t in ipairs(ns.Spam.Texts()) do
        out[#out + 1] = { key = i, label = t.name }
    end
    return out
end
local function lootOptions()
    local out = {}
    for _, k in ipairs(ns.Spam.LOOT) do
        out[#out + 1] = { key = k, label = ns.T("loot_" .. k) }
    end
    return out
end
local function label(parent, key, base)
    local fs = ns.Str(parent, base or "GameFontNormalSmall")
    fs:SetText(ns.T(key))
    ns.PaintTitle(fs)
    return fs
end
local function tokenButton(parent, key, tip)
    local b = ns.MakeKitButton(parent)
    local tok = ns.T(key)
    b:SetText(tok)
    b:SetWidth(b.text:GetStringWidth() + 14)
    b:SetHeight(20)
    b.tip = ns.T(tip or "tipToken")
    b.onClick = function()
        body:SetFocus()
        body:Insert(tok)
    end
    return b
end
local function lineH()
    return ns.Fit(BASE, 20, 2)
end
local function chanRowH()
    return ns.Fit(BASE, 18, 1)
end
local function chanCols()
    if ns.Spam.OwnEvery() or ns.FontScale(BASE) <= CHAN_BIG then return 1 end
    return 2
end
local function ctlH()
    return math.max(lineH(), lootSel:GetHeight() or 0)
end
local function textBoxH()
    return ns.LineH("ChatFontNormal", 2) + 10
end
local function unitWidth(items)
    local w = 0
    for i, it in ipairs(items) do
        w = w + it:GetWidth() + (i > 1 and GAP or 0)
    end
    return w
end
local function flow(parent, units, x, y, maxW, reserve)
    local h = ctlH()
    local cx, cy = x, y
    for _, items in ipairs(units) do
        local w = unitWidth(items)
        local limit = maxW - (cy == y and (reserve or 0) or 0)
        if cx > x and cx + w > x + limit then
            cx, cy = x, cy + h + LINE_GAP
        end
        local prev
        for _, it in ipairs(items) do
            it:ClearAllPoints()
            if prev then
                it:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
            else
                it:SetPoint("LEFT", parent, "TOPLEFT", cx, -(cy + h / 2))
            end
            prev = it
        end
        cx = cx + w + GAP * 2
    end
    return cy + h - y
end
local function makeEdit(parent, w, field)
    local e = ns.MakeEdit(parent)
    e:SetWidth(w)
    e.onChange = function(v) ns.Session.SetField(field, v) end
    return e
end
local function buildMsgBlock(pult, w)
    local b = ns.NewFrame("Frame", nil, pult)
    msgBlock = b
    b:SetWidth(w)
    msgCap = ns.Caption(b, ns.T("pultText"), w)
    textSel = ns.MakeSelect(b)
    textSel:SetWidth(w)
    textSel.onPick = function(i) body:ClearFocus() ns.Spam.PickText(i) end
    newBtn = ns.MakeKitButton(b)
    newBtn:SetText(ns.T("btnNew"))
    newBtn.onClick = function() body:ClearFocus() ns.Spam.NewText(false) end
    copyBtn = ns.MakeKitButton(b)
    copyBtn:SetText(ns.T("btnCopy"))
    copyBtn.onClick = function() body:ClearFocus() ns.Spam.NewText(true) end
    delBtn = ns.MakeKitButton(b)
    delBtn:SetText(ns.T("btnDelete"))
    delBtn.onClick = function()
        body:ClearFocus()
        local t = ns.Spam.Texts()[ns.Spam.TextIndex()]
        ns.Kit.Confirm(ns.T("textDeleteAsk", t and t.name or ""), ns.T("btnDelete"), function() ns.Spam.DeleteText() end)
    end
    rotCheck = ns.MakeCheck(b)
    rotCheck.label:SetText(ns.T("textRotate"))
    rotCheck.tipTitle = ns.T("textRotate")
    rotCheck.onToggle = function(on) ns.Spam.SetRotate(on) end
    styleCap = ns.Str(b, BASE)
    styleCap:SetText(ns.T("styleLabel"))
    styleCap:SetJustifyH("LEFT")
    ns.PaintText(styleCap, "text.secondary")
    styleSel = ns.MakeSelect(b)
    styleSel:SetWidth(w)
    styleSel.tip = ns.T("tipStyle")
    styleSel.onPick = function(k) ns.Session.SetField("needsStyle", k) end
end
local function buildOptBlock(pult, w)
    local b = ns.NewFrame("Frame", nil, pult)
    optBlock = b
    b:SetWidth(w)
    everyCap = ns.Str(b, BASE)
    everyCap:SetText(ns.T("everyAll"))
    ns.PaintText(everyCap, "text.secondary")
    everyE = ns.MakeEdit(b)
    everyE:SetWidth(40)
    everyE:SetHeight(20)
    everyE:SetNumeric(true)
    everyE:SetMaxLetters(4)
    everyE:SetPoint("LEFT", everyCap, "RIGHT", 4, 0)
    everyE.onChange = nil
    everyE.onCommit = function(v)
        ns.Spam.SetEvery(v)
        everyE:SetValue(tostring(ns.Spam.Every()))
    end
    everySec = ns.Str(b, BASE)
    everySec:SetText(ns.T("sec"))
    ns.PaintText(everySec, "text.secondary")
    everySec:SetPoint("LEFT", everyE, "RIGHT", 3, 0)
    ownCheck = ns.MakeCheck(b)
    ownCheck.label:SetText(ns.T("ownEvery"))
    ownCheck.tipTitle = ns.T("ownEvery")
    ownCheck.tip = ns.T("tipOwnEvery")
    ownCheck.onToggle = function(on) ns.Spam.SetOwnEvery(on) end
    autoCheck = ns.MakeCheck(b)
    autoCheck.label:SetText(ns.T("autoStop"))
    autoCheck.tipTitle = ns.T("autoStop")
    autoCheck.tip = ns.T("tipAutoStop")
    autoCheck.onToggle = function(on) ns.Spam.SetAutoStop(on) end
end
local function placeBlocks()
    if not msgBlock then return end
    local w = msgBlock:GetWidth()
    local capH = ns.LineH("GameFontNormal")
    local selH = textSel:GetHeight() or 22
    msgCap:ClearAllPoints()
    msgCap:SetPoint("TOPLEFT", msgBlock, "TOPLEFT", 0, 0)
    local y = capH + BLOCK_GAP
    textSel:ClearAllPoints()
    textSel:SetPoint("TOPLEFT", msgBlock, "TOPLEFT", 0, -y)
    y = y + selH + 4
    local bw = math.floor((w - GAP * 2) / 3)
    local prev
    for _, btn in ipairs({ newBtn, copyBtn, delBtn }) do
        btn:SetWidth(bw)
        btn:ClearAllPoints()
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        else
            btn:SetPoint("TOPLEFT", msgBlock, "TOPLEFT", 0, -y)
        end
        prev = btn
    end
    y = y + (newBtn:GetHeight() or 22) + 4
    local checkH = math.max(rotCheck:GetHeight() or 20, ns.LineH(BASE))
    rotCheck:ClearAllPoints()
    rotCheck:SetPoint("LEFT", msgBlock, "TOPLEFT", -3, -(y + checkH / 2))
    y = y + checkH + BLOCK_GAP
    styleCap:ClearAllPoints()
    styleCap:SetPoint("TOPLEFT", msgBlock, "TOPLEFT", 0, -y)
    styleCap:SetWidth(w)
    y = y + ns.LineH(BASE) + 4
    styleSel:ClearAllPoints()
    styleSel:SetPoint("TOPLEFT", msgBlock, "TOPLEFT", 0, -y)
    msgBlock:SetHeight(y + (styleSel:GetHeight() or selH))
    local rowH = math.max(everyE:GetHeight() or 20, ns.LineH(BASE))
    everyCap:ClearAllPoints()
    everyCap:SetPoint("LEFT", optBlock, "TOPLEFT", 0, -rowH / 2)
    ownCheck:ClearAllPoints()
    ownCheck:SetPoint("LEFT", optBlock, "TOPLEFT", -3, -(rowH + 4 + rowH / 2))
    autoCheck:ClearAllPoints()
    autoCheck:SetPoint("LEFT", optBlock, "TOPLEFT", -3, -(rowH * 2 + 8 + rowH / 2))
    y = rowH * 3 + 8 + BLOCK_GAP
    chanCap:ClearAllPoints()
    chanCap:SetPoint("TOPLEFT", optBlock, "TOPLEFT", 0, -y)
    y = y + ns.LineH("GameFontNormalSmall") + 4
    laidCols = chanCols()
    local rows = math.max(1, math.ceil(#ns.Spam.Channels() / laidCols))
    chanBox:ClearAllPoints()
    chanBox:SetPoint("TOPLEFT", optBlock, "TOPLEFT", 0, -y)
    chanBox:SetSize(w, rows * chanRowH())
    optBlock:SetHeight(y + rows * chanRowH())
end
local function buildPreview()
    local p = ns.MakePanel(pane)
    previewPanel = p
    previewCap = label(p, "previewTitle", "GameFontNormal")
    counter = ns.Str(p, BASE)
    counter:SetWordWrap(false)
    local cf = ns.NewFrame("Frame", nil, p)
    counterBox = cf
    cf:SetPoint("TOPRIGHT", counter, "TOPRIGHT", 2, 2)
    cf:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", -2, -2)
    cf:EnableMouse(true)
    cf.tip = ns.T("tipBytes")
    cf:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    cf:SetScript("OnLeave", ns.TipHide)
    preview = ns.Str(p, PREVIEW_FONT)
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    ns.PaintText(preview, "text.primary")
end
local function placePreview(y)
    local p = previewPanel
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    p:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    local capH = ns.LineH("GameFontNormal")
    previewCap:ClearAllPoints()
    previewCap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -VPAD)
    counter:ClearAllPoints()
    counter:SetPoint("RIGHT", p, "TOPRIGHT", -PAD, -(VPAD + capH / 2))
    local top = VPAD + capH + LINE_GAP
    local pvH = ns.LineH(PREVIEW_FONT) * previewLines
    preview:ClearAllPoints()
    preview:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -top)
    preview:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -top)
    preview:SetHeight(pvH)
    local h = top + pvH + VPAD
    p:SetHeight(h)
    return h
end
local function previewNeed()
    local h = preview.GetStringHeight and preview:GetStringHeight()
    if type(h) ~= "number" or h <= 0 then return 1 end
    return math.max(1, math.min(PREVIEW_MAX, math.ceil(h / ns.LineH(PREVIEW_FONT) - 0.1)))
end
local function buildText()
    local p = ns.MakePanel(pane)
    textPanel = p
    local box = ns.NewFrame("Frame", nil, p)
    textBox = box
    box:SetHeight(textBoxH())
    ns.Skin(box, "edit")
    local sc = ns.NewFrame("ScrollFrame", nil, box)
    sc:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    sc:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    body = ns.MakeEdit(sc, true)
    body:SetBackdrop(nil)
    body.kitFrame = box
    body:SetWidth(paneW() - PAD * 2 - 8)
    sc:SetScrollChild(body)
    sc:EnableMouse(true)
    sc:SetScript("OnMouseDown", function() body:SetFocus() end)
    sc:EnableMouseWheel(true)
    sc:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, body:GetHeight() - self:GetHeight())
        local v = self:GetVerticalScroll() - delta * 12
        if v < 0 then v = 0 end
        if v > max then v = max end
        self:SetVerticalScroll(v)
    end)
    body:SetMaxLetters(600)
    body.tipFoot = { { kind = "foot", key = "shift", left = ns.T("tipLinks") } }
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        if text and body.focused and body:IsVisible() and not ChatEdit_GetActiveWindow() then
            body:Insert(text)
        end
    end)
    body.onChange = function(text) ns.Spam.SetBody(text) end
    progE = makeEdit(p, 84, "prog")
    reqSel = ns.MakeSelect(p)
    reqSel:SetWidth(64)
    reqSel.onPick = function(k) ns.Session.SetField("reqKind", k) end
    reqE = makeEdit(p, 38, "req")
    lootSel = ns.MakeSelect(p)
    lootSel:SetWidth(150)
    lootSel.onPick = function(k) ns.Session.SetField("loot", k) end
    timeE = makeEdit(p, 80, "time")
    dsE = makeEdit(p, 110, "ds")
    flowUnits = {
        { tokenButton(p, "tokRaid") }, { tokenButton(p, "tokNeeds") }, { tokenButton(p, "tokCount") },
        { tokenButton(p, "tokFree", "tipTokFree") }, { tokenButton(p, "tokLead", "tipTokLead") },
        { tokenButton(p, "tokHow", "tipTokHow") },
        { tokenButton(p, "tokProg"), progE },
        { tokenButton(p, "tokReq"), reqSel, reqE },
        { tokenButton(p, "tokLoot"), lootSel },
        { tokenButton(p, "tokTime"), timeE },
        { tokenButton(p, "tokDs", "tipTokDs"), dsE },
    }
    for i = 1, 8 do
        local b = ns.NewFrame("Button", nil, p)
        b:SetSize(16, 16)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        ns.Icon.Mark(b.icon, i)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.tipTitle = ns.T("mark" .. i)
        b.tip = ns.T("tipMark")
        b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
        b:SetScript("OnLeave", ns.TipHide)
        b:SetScript("OnClick", function()
            body:SetFocus()
            body:Insert("{rt" .. i .. "}")
        end)
        markBtns[i] = b
    end
end
local function placeText(y)
    local p = textPanel
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    p:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    local w = paneW() - PAD * 2
    textBox:ClearAllPoints()
    textBox:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -VPAD)
    textBox:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -VPAD)
    textBox:SetHeight(textBoxH())
    local marksW = 8 * 18
    local top = VPAD + textBoxH() + LINE_GAP + 2
    local h1 = flow(p, flowUnits, PAD, top, w, marksW + GAP)
    for i = 8, 1, -1 do
        local b = markBtns[i]
        b:ClearAllPoints()
        if i == 8 then
            b:SetPoint("RIGHT", p, "TOPRIGHT", -PAD, -(top + ctlH() / 2))
        else
            b:SetPoint("RIGHT", markBtns[i + 1], "LEFT", -2, 0)
        end
    end
    local h = top + h1 + VPAD
    p:SetHeight(h)
    return h
end
local function chanRow()
    local r = ns.NewFrame("Frame", nil, chanBox)
    r:SetSize(140, 22)
    r.check = ns.MakeCheck(r)
    r.check:SetPoint("LEFT", r, "LEFT", -3, 0)
    r.check.label:SetJustifyH("LEFT")
    r.every = ns.MakeEdit(r)
    r.every:SetWidth(36)
    r.every:SetHeight(20)
    r.every:SetNumeric(true)
    r.every:SetMaxLetters(4)
    r.every:SetPoint("RIGHT", r, "RIGHT", -16, 0)
    r.sec = ns.Str(r, BASE)
    r.sec:SetPoint("LEFT", r.every, "RIGHT", 3, 0)
    r.sec:SetText(ns.T("sec"))
    ns.PaintText(r.sec, "text.secondary")
    r.left = ns.Str(r, BASE)
    r.left:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.left:SetJustifyH("RIGHT")
    r.left:SetWordWrap(false)
    ns.PaintText(r.left, "text.title")
    return r
end
local function tick(r)
    local left = r.key and ns.Spam.Left(r.key)
    local text = left and (math.ceil(left) .. " " .. ns.T("sec")) or ""
    if r.leftText ~= text then
        r.leftText = text
        r.left:SetText(text)
    end
    local ago = r.key and ns.Spam.Ago(r.key)
    ago = ago and math.floor(ago)
    if r.ago ~= ago then
        r.ago = ago
        r.check.tip = ago and (ns.T("tipChanLast", ago) .. "\n" .. ns.T("tipChanHour", ns.Spam.HourCount(r.key))) or nil
    end
end
local function buildChannels()
    chanCap = label(optBlock, "chanTitle")
    chanBox = ns.NewFrame("Frame", nil, optBlock)
    chanPool = ns.NewPool(chanRow)
end
local function makeCheck(parent, sp)
    local c = ns.MakeCheck(parent)
    c:SetSize(CHECK_H + 3, CHECK_H + 3)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("LEFT", c, "RIGHT", 1, 0)
    c.icon:SetTexture(ns.Compat.SpellIcon(sp.icon))
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.label:ClearAllPoints()
    c.label:SetPoint("LEFT", c.icon, "RIGHT", 4, 0)
    c.label:SetText(ns.T("spec_" .. sp.key))
    ns.PaintText(c.label, "text.primary")
    c.tipTitle = ns.T("specFull_" .. sp.key)
    c.tip = ns.T("needFull_" .. sp.role)
    c.onToggle = function(on) ns.Session.SetChecked(sp.key, on) end
    checks[sp.key] = c
    return c
end
local function stepButton(parent, text, role, delta)
    local b = ns.MakeKitButton(parent)
    b:SetSize(STEP_BTN, STEP_BTN)
    b:SetText(text)
    b.tipTitle = ns.T("needFull_" .. role)
    b.onClick = function() ns.Spam.AddNeed(role, delta) end
    return b
end
local function buildRoleHead(p, role)
    local h = {}
    h.col = ns.Str(p, "GameFontNormalSmall")
    h.col:SetText(ns.T("needShort_" .. role))
    ns.PaintTitle(h.col)
    h.name = ns.Str(p, BASE)
    h.name:SetText(ns.T("needShort_" .. role))
    ns.PaintText(h.name, "text.secondary")
    h.minus = stepButton(p, "-", role, -1)
    h.minus:SetPoint("LEFT", h.name, "RIGHT", 6, 0)
    h.val = ns.Str(p, BASE)
    h.val:SetWidth(ns.Wide(BASE, NEED_W))
    h.val:SetJustifyH("CENTER")
    h.val:SetPoint("LEFT", h.minus, "RIGHT", 0, 0)
    h.plus = stepButton(p, "+", role, 1)
    h.plus:SetPoint("LEFT", h.val, "RIGHT", 0, 0)
    needVals[role] = h.val
    roleHeads[role] = h
end
local function buildSpecs()
    local p = ns.MakePanel(pane)
    specsPanel = p
    specsCap = label(p, "specsTitle")
    defBtn = ns.MakeKitButton(p)
    defBtn:SetText(ns.T("btnDefault"))
    defBtn:SetWidth(defBtn.text:GetStringWidth() + 20)
    defBtn:SetHeight(20)
    defBtn.onClick = function() ns.Session.ResetChecks() end
    tplBtn = ns.MakeKitButton(p)
    tplBtn:SetText(ns.T("btnNeedsTpl"))
    tplBtn:SetWidth(tplBtn.text:GetStringWidth() + 20)
    tplBtn:SetHeight(20)
    tplBtn:SetPoint("RIGHT", defBtn, "LEFT", -GAP, 0)
    tplBtn.tipTitle = ns.T("btnNeedsTpl")
    tplBtn.onClick = function() ns.Spam.NeedsFromTemplate() end
    headBg = p:CreateTexture(nil, "BACKGROUND")
    ns.PaintToken(headBg, "surface.head")
    for k = 1, #ns.Spam.ROLES do
        local t = p:CreateTexture(nil, "BORDER")
        ns.PaintToken(t, "surface.grid")
        t:SetWidth(1)
        colLines[k] = t
    end
    needsCap = ns.Str(p, "GameFontNormalSmall")
    needsCap:SetText(ns.T("needsLine", ns.T("tokNeeds")))
    ns.PaintTitle(needsCap)
    for _, role in ipairs(ns.Spam.ROLES) do buildRoleHead(p, role) end
    for i, cls in ipairs(ns.CLASSES) do
        local row = { cls = cls, cells = {} }
        classRows[i] = row
        row.bg = p:CreateTexture(nil, "BACKGROUND")
        ns.PaintToken(row.bg, i % 2 == 0 and "surface.hover" or "surface.alt")
        local cc = ns.MakeCheck(p)
        cc:SetSize(CHECK_H + 3, CHECK_H + 3)
        cc.icon = cc:CreateTexture(nil, "ARTWORK")
        cc.icon:SetSize(CLS_ICON, CLS_ICON)
        cc.icon:SetPoint("LEFT", cc, "RIGHT", 2, 0)
        ns.Icon.Class(cc.icon, cls.token)
        cc.label:ClearAllPoints()
        cc.label:SetPoint("LEFT", cc.icon, "RIGHT", 5, 0)
        cc.label:SetText(ns.T("cls_" .. cls.token))
        ns.ClassText(cc.label, cls.token)
        cc.tipTitle = ns.T("cls_" .. cls.token)
        cc.tip = ns.T(cls.classOnly and "tipClassOnly" or "tipClassCheck")
        cc.onToggle = function(on) ns.Session.SetClassChecked(cls.token, on) end
        classChecks[cls.token] = cc
        row.check = cc
        for _, sp in ipairs(cls.specs) do
            local c = makeCheck(p, sp)
            c.cls = cls.token
            if cls.classOnly then
                c.classOnly = true
                c.onToggle = function(on) ns.Session.SetClassChecked(cls.token, on) end
            end
            local list = row.cells[sp.role]
            if not list then
                list = {}
                row.cells[sp.role] = list
            end
            list[#list + 1] = c
        end
    end
end
local function specW()
    local w = 0
    for _, c in pairs(checks) do
        w = math.max(w, c.label:GetStringWidth() or 0)
    end
    if w <= 0 then return ns.Wide(BASE, SPEC_W) end
    return math.ceil(w) + CHECK_H + 3 + 1 + ICON + 4 + SPEC_GAP
end
local function needsWidth()
    local w = (needsCap:GetStringWidth() or 0) + 10
    for _, role in ipairs(ns.Spam.ROLES) do
        w = w + (roleHeads[role].name:GetStringWidth() or 0) + 6 + STEP_BTN * 2 + ns.Wide(BASE, NEED_W) + 14
    end
    return w
end
local function placeNeeds(x, mid)
    local p = specsPanel
    needsCap:ClearAllPoints()
    needsCap:SetPoint("LEFT", p, "TOPLEFT", x, -mid)
    x = x + (needsCap:GetStringWidth() or 0) + 10
    for _, role in ipairs(ns.Spam.ROLES) do
        local h = roleHeads[role]
        h.name:ClearAllPoints()
        h.name:SetPoint("LEFT", p, "TOPLEFT", x, -mid)
        x = x + (h.name:GetStringWidth() or 0) + 6 + STEP_BTN * 2 + ns.Wide(BASE, NEED_W) + 14
    end
end
local function placeSpecs(y)
    local p = specsPanel
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    p:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    local pageH = ns.window.PANE_H
    local roles = ns.Spam.ROLES
    local clsW = ns.Wide(BASE, CLS_W)
    local cellW = (paneW() - PAD * 2 - clsW) / #roles
    local headH = ns.Fit(BASE, 20, 2)
    local top1 = math.max(headH, defBtn:GetHeight() or 0)
    local mid1 = VPAD + top1 / 2
    specsCap:ClearAllPoints()
    specsCap:SetPoint("LEFT", p, "TOPLEFT", PAD, -mid1)
    defBtn:ClearAllPoints()
    defBtn:SetPoint("RIGHT", p, "TOPRIGHT", -PAD, -mid1)
    local capEnd = PAD + (specsCap:GetStringWidth() or 0) + 20
    local btnStart = paneW() - PAD - defBtn:GetWidth() - GAP - tplBtn:GetWidth() - 16
    local headY
    if capEnd + needsWidth() <= btnStart then
        placeNeeds(capEnd, mid1)
        headY = VPAD + top1 + 6
    else
        placeNeeds(PAD, VPAD + top1 + LINE_GAP + headH / 2)
        headY = VPAD + top1 + LINE_GAP + headH + 6
    end
    headBg:ClearAllPoints()
    headBg:SetPoint("TOPLEFT", p, "TOPLEFT", PAD - 4, -(headY - 3))
    headBg:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(PAD - 4), -(headY - 3))
    headBg:SetHeight(headH + 6)
    for k, role in ipairs(roles) do
        local h = roleHeads[role]
        h.col:ClearAllPoints()
        h.col:SetPoint("LEFT", p, "TOPLEFT", PAD + clsW + (k - 1) * cellW, -(headY + headH / 2))
    end
    local sw = specW()
    local perLine = math.max(1, math.floor(cellW / sw))
    local top = headY + headH + 6
    local heights, sum = {}, 0
    for _, pad in ipairs({ ROW_PAD, 1, 0 }) do
        sum = 0
        for i, row in ipairs(classRows) do
            local lines = 1
            for _, list in pairs(row.cells) do
                lines = math.max(lines, math.ceil(#list / perLine))
            end
            heights[i] = lines * CHECK_H + pad * 2
            sum = sum + heights[i]
        end
        if y + top + sum + VPAD <= pageH then break end
    end
    local avail = pageH - y - top - VPAD
    local extra = 0
    if avail > sum then extra = math.min(ROW_EXTRA, math.floor((avail - sum) / #classRows)) end
    local cy = top
    for i, row in ipairs(classRows) do
        local rh = heights[i] + extra
        local mid = cy + rh / 2
        row.bg:ClearAllPoints()
        row.bg:SetPoint("TOPLEFT", p, "TOPLEFT", PAD - 4, -cy)
        row.bg:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(PAD - 4), -cy)
        row.bg:SetHeight(rh)
        row.check:ClearAllPoints()
        row.check:SetPoint("LEFT", p, "TOPLEFT", PAD - 3, -mid)
        for k, role in ipairs(roles) do
            local list = row.cells[role]
            if list then
                local x0 = PAD + clsW + (k - 1) * cellW
                local lines = math.ceil(#list / perLine)
                local y0 = mid - lines * CHECK_H / 2
                for j, c in ipairs(list) do
                    local col = (j - 1) % perLine
                    local ln = math.floor((j - 1) / perLine)
                    c:ClearAllPoints()
                    c:SetPoint("TOPLEFT", p, "TOPLEFT", x0 - 3 + col * sw, -(y0 + ln * CHECK_H - 1))
                end
            end
        end
        cy = cy + rh
    end
    for k, t in ipairs(colLines) do
        local x = PAD + clsW + (k - 1) * cellW - 8
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", p, "TOPLEFT", x, -(headY - 3))
        t:SetHeight(cy - headY + 3)
    end
    local need = cy - extra * #classRows + VPAD
    local h = math.max(cy + VPAD, pageH - y)
    p:SetHeight(h)
    return h, need
end
local function needsTip(t)
    local parts = {}
    for _, role in ipairs(ns.Spam.ROLES) do
        parts[#parts + 1] = ns.T("needShort_" .. role) .. " " .. t[role]
    end
    return ns.Tpl.Name(ns.Session.Template()) .. ": " .. table.concat(parts, ", ")
end
local function refreshNeeds()
    local P = ns.Spam
    local cur = P.Needs()
    local open, got = P.Open()
    for role, fs in pairs(needVals) do
        fs:SetText(tostring(cur[role]))
        ns.PaintText(fs, open[role] > 0 and "text.primary" or "text.muted")
        local h = roleHeads[role]
        h.minus.tip = ns.T("tipNeedHave", got[role], open[role])
        h.plus.tip = h.minus.tip
    end
    local t = P.TemplateNeeds(ns.Session.Template())
    local same = true
    for _, role in ipairs(P.ROLES) do
        if t[role] ~= cur[role] then same = false end
    end
    tplBtn.tip = needsTip(t)
    if same then tplBtn:Disable() else tplBtn:Enable() end
end
local function refreshChannels()
    chanPool:Reset()
    local colW = (optBlock:GetWidth() + 3) / laidCols
    local rh = chanRowH()
    local own = ns.Spam.OwnEvery()
    local tickW = ns.Spam.Running() and ns.Wide(BASE, TICK_W) or 0
    if not everyE.focused then everyE:SetValue(tostring(ns.Spam.Every())) end
    everyE.tip = ns.T("tipEvery", ns.Spam.MinEvery())
    ownCheck:SetChecked(own)
    for i, c in ipairs(ns.Spam.Channels()) do
        local r = chanPool:Acquire()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", chanBox, "TOPLEFT", ((i - 1) % laidCols) * colW, -math.floor((i - 1) / laidCols) * rh)
        r:SetSize(colW - 3, rh)
        r.key = c.key
        r.ago = false
        r.every:ClearAllPoints()
        r.every:SetPoint("RIGHT", r, "RIGHT", -(14 + tickW), 0)
        r.left:SetWidth(tickW)
        r.check.label:SetWidth((own and (colW - 84) or (colW - 26)) - tickW)
        r.check.label:SetWordWrap(false)
        r.check.label:SetText(c.label)
        tick(r)
        if own then
            r.every:Show()
            r.sec:Show()
        else
            r.every:Hide()
            r.sec:Hide()
        end
        r.check.tipTitle = c.label
        r.check:SetChecked(ns.Spam.ChanOn(c.key))
        r.check.onToggle = function(on) ns.Spam.SetChanOn(c.key, on) end
        if not r.every.focused then r.every:SetValue(tostring(ns.Spam.ChanEvery(c.key))) end
        r.every.tip = ns.T("tipEvery", ns.Spam.MinEvery())
        r.every.onChange = nil
        r.every.onCommit = function(v)
            ns.Spam.SetChanEvery(c.key, v)
            r.every:SetValue(tostring(ns.Spam.ChanEvery(c.key)))
        end
    end
    chanPool:HideExtras()
end
local chanCount = -1
local function layout()
    local y = placePreview(0) + PANEL_GAP
    y = y + placeText(y) + PANEL_GAP
    local h, need = placeSpecs(y)
    natural = y + need
    pane:SetWidth(paneW())
    pane:SetHeight(y + h)
    scroller:Rescroll()
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    local S, P = ns.Session, ns.Spam
    if #P.Channels() ~= chanCount or chanCols() ~= laidCols then
        chanCount = #P.Channels()
        placeBlocks()
        layout()
    end
    textSel:SetOptions(textOptions(), P.TextIndex())
    if #P.Texts() < 2 then
        delBtn:Disable()
        delBtn.tip = ns.T("tipDeleteLast")
        rotCheck:Disable()
        rotCheck.tip = ns.T("tipTextRotateOne")
    else
        delBtn:Enable()
        delBtn.tip = nil
        rotCheck:Enable()
        rotCheck.tip = ns.T("tipTextRotate")
    end
    rotCheck:SetChecked(P.Rotate())
    autoCheck:SetChecked(P.AutoStop())
    if not body.focused then body:SetValue(P.Body()) end
    if not progE.focused then progE:SetValue(S.Field("prog")) end
    if not reqE.focused then reqE:SetValue(S.Field("req")) end
    if not timeE.focused then timeE:SetValue(S.Field("time")) end
    if not dsE.focused then dsE:SetValue(S.Field("ds")) end
    reqSel:SetOptions({ { key = "none", label = ns.T("reqKindNone") }, { key = "gs", label = ns.T("reqKindGs") },
        { key = "ilvl", label = ns.T("reqKindIlvl") } }, S.Field("reqKind"))
    local noReq = S.Field("reqKind") == "none"
    reqE:EnableMouse(not noReq)
    reqE:SetAlpha(noReq and 0.4 or 1)
    if noReq then reqE:ClearFocus() end
    lootSel:SetOptions(lootOptions(), S.Field("loot"))
    styleSel:SetOptions({ { key = "count", label = ns.T("styleCount") }, { key = "slash", label = ns.T("styleSlash") },
        { key = "roles", label = ns.T("styleRoles") } }, S.Field("needsStyle") or "count")
    for token, cc in pairs(classChecks) do cc:SetChecked(S.ClassChecked(token)) end
    for key, c in pairs(checks) do
        local on = S.ClassChecked(c.cls)
        if c.classOnly then
            c:SetChecked(on)
        else
            c:SetChecked(S.Checked(key))
            c:SetAlpha(on and 1 or 0.4)
            c:EnableMouse(on)
        end
    end
    if S.ChecksAreDefault() then
        defBtn:Disable()
        defBtn.tip = ns.T("tipChecksDefault")
    else
        defBtn:Enable()
        defBtn.tip = nil
    end
    refreshNeeds()
    local msg, len, fits, short = P.Build()
    preview:SetText(msg)
    local color = fits and (short and "text.title" or "text.primary") or "sem.notReady"
    counter:SetText(ns.Hex(color) .. ns.T("bytesN", len, P.Limit()) .. "|r")
    counterBox.tip = ns.T("tipBytes") .. (short and ("\n" .. ns.T("tipShort", ns.T("tokNeeds"))) or "")
    local need = previewNeed()
    if need ~= previewLines then
        previewLines = need
        layout()
    end
    refreshChannels()
end
local function relayout()
    if not built then return end
    body:SetWidth(paneW() - PAD * 2 - 8)
    for _, fs in pairs(needVals) do fs:SetWidth(ns.Wide(BASE, NEED_W)) end
    placeBlocks()
    layout()
    refresh()
    if ns.Pult and ns.Pult.Refresh then ns.Pult.Refresh() end
end
local function probe()
    return {
        natural = natural,
        view = ns.window.PANE_H,
        panels = { previewPanel, textPanel, specsPanel },
        content = pane,
        blocks = { msgBlock, optBlock },
        lines = previewLines,
    }
end
local function build()
    page = ns.window:Pane("spam")
    scroller = ns.ScrollPage(page, { fill = true, bar = "deck" })
    pane = scroller.content
    local pult = ns.window:Pult()
    local bw = ns.Pult and ns.Pult.Width and ns.Pult.Width() or 0
    if bw <= 0 then bw = pult:GetWidth() - 24 end
    buildMsgBlock(pult, bw)
    buildOptBlock(pult, bw)
    msgBlock:Hide()
    optBlock:Hide()
    buildPreview()
    buildText()
    buildChannels()
    buildSpecs()
    built = true
    placeBlocks()
    layout()
    page:SetScript("OnShow", function()
        layout()
        refresh()
    end)
    page:SetScript("OnSizeChanged", function() layout() end)
    local acc = 0
    page:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < TICK_EVERY then return end
        acc = 0
        for _, r in ipairs(chanPool.items) do
            if r:IsShown() then tick(r) end
        end
    end)
    refresh()
    if ns.Pult and ns.Pult.Refresh then ns.Pult.Refresh() end
end
ns.Session.OnChange(refresh)
ns.Spam.OnRun(refresh)
ns.OnFont(relayout)
ns.window:OnSize(relayout)
ns.SpamPane = {
    Build = build, Refresh = refresh, Probe = probe,
    PultBlocks = function() return msgBlock, optBlock end,
}
ns.window:OnBuild(build)
