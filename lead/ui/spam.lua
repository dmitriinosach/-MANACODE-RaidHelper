local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 10
local GAP = 6
local CHECK_H = 17
local ICON = 14
local CLS_COLS = 5
local CHAN_COLS = 4
local styleSel
local pane, textSel, delBtn, body, progE, reqSel, reqE, lootSel, timeE
local defBtn, preview, counter, chanPool, chanBox
local checks = {}
local classChecks = {}
local classCells = {}
local built = false
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
local function panel(y, h)
    local p = ns.MakePanel(pane)
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    p:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    p:SetHeight(h)
    return p
end
local function label(parent, key)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(ns.T(key))
    ns.PaintTitle(fs)
    return fs
end
local function tokenButton(parent, key)
    local b = ns.MakeKitButton(parent)
    local tok = ns.T(key)
    b:SetText(tok)
    b:SetWidth(b.text:GetStringWidth() + 14)
    b:SetHeight(20)
    b.tip = ns.T("tipToken")
    b.onClick = function()
        body:SetFocus()
        body:Insert(tok)
    end
    return b
end
local function row(parent, items, x, y)
    local prev
    for _, it in ipairs(items) do
        it:ClearAllPoints()
        if prev then
            it:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        else
            it:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        end
        prev = it
    end
end
local function buildText()
    local p = panel(0, 150)
    textSel = ns.MakeSelect(p)
    textSel:SetWidth(180)
    textSel.onPick = function(i) body:ClearFocus() ns.Spam.PickText(i) end
    local newBtn = ns.MakeKitButton(p)
    newBtn:SetText(ns.T("btnNew"))
    newBtn:SetWidth(70)
    newBtn.onClick = function() body:ClearFocus() ns.Spam.NewText(false) end
    local copyBtn = ns.MakeKitButton(p)
    copyBtn:SetText(ns.T("btnCopy"))
    copyBtn:SetWidth(70)
    copyBtn.onClick = function() body:ClearFocus() ns.Spam.NewText(true) end
    delBtn = ns.MakeKitButton(p)
    delBtn:SetText(ns.T("btnDelete"))
    delBtn:SetWidth(70)
    delBtn.onClick = function() body:ClearFocus() ns.Spam.DeleteText() end
    row(p, { textSel, newBtn, copyBtn, delBtn }, PAD, PAD)
    styleSel = ns.MakeSelect(p)
    styleSel:SetWidth(150)
    styleSel:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -PAD)
    styleSel.tip = ns.T("tipStyle")
    styleSel.onPick = function(k) ns.Session.SetField("needsStyle", k) end
    local box = ns.NewFrame("Frame", nil, p)
    box:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -(PAD + 28))
    box:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -(PAD + 28))
    box:SetHeight(46)
    ns.Skin(box, "edit")
    local sc = ns.NewFrame("ScrollFrame", nil, box)
    sc:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    sc:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    body = ns.MakeEdit(sc, true)
    body:SetBackdrop(nil)
    body.kitFrame = box
    body:SetWidth(ns.window.PANE_W - PAD * 2 - 8)
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
    body.tip = ns.T("tipLinks")
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        if text and body.focused and body:IsVisible() and not ChatEdit_GetActiveWindow() then
            body:Insert(text)
        end
    end)
    body.onChange = function(text) ns.Spam.SetBody(text) end
    progE = ns.MakeEdit(p)
    progE:SetWidth(84)
    progE.onChange = function(v) ns.Session.SetField("prog", v) end
    reqSel = ns.MakeSelect(p)
    reqSel:SetWidth(64)
    reqSel.onPick = function(k) ns.Session.SetField("reqKind", k) end
    reqE = ns.MakeEdit(p)
    reqE:SetWidth(38)
    reqE.onChange = function(v) ns.Session.SetField("req", v) end
    row(p, { tokenButton(p, "tokRaid"), tokenButton(p, "tokNeeds"), tokenButton(p, "tokCount"),
        tokenButton(p, "tokProg"), progE, tokenButton(p, "tokReq"), reqSel, reqE }, PAD, PAD + 80)
    lootSel = ns.MakeSelect(p)
    lootSel:SetWidth(170)
    lootSel.onPick = function(k) ns.Session.SetField("loot", k) end
    timeE = ns.MakeEdit(p)
    timeE:SetWidth(90)
    timeE.onChange = function(v) ns.Session.SetField("time", v) end
    row(p, { tokenButton(p, "tokLoot"), lootSel, tokenButton(p, "tokTime"), timeE }, PAD, PAD + 106)
    local prev
    for i = 8, 1, -1 do
        local b = ns.NewFrame("Button", nil, p)
        b:SetSize(16, 16)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        ns.Icon.Mark(b.icon, i)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        if prev then
            b:SetPoint("RIGHT", prev, "LEFT", -2, 0)
        else
            b:SetPoint("RIGHT", p, "TOPRIGHT", -PAD, -(PAD + 116))
        end
        b.tipTitle = ns.T("mark" .. i)
        b.tip = ns.T("tipMark")
        b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
        b:SetScript("OnLeave", ns.TipHide)
        b:SetScript("OnClick", function()
            body:SetFocus()
            body:Insert("{rt" .. i .. "}")
        end)
        prev = b
    end
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
    c.tip = ns.T("grpTitle_" .. ns.ROLE_GROUP[sp.role])
    c.onToggle = function(on) ns.Session.SetChecked(sp.key, on) end
    checks[sp.key] = c
    return c
end
local function buildSpecs()
    local top = 158
    local p = panel(top, 196)
    local cap = label(p, "specsTitle")
    cap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    defBtn = ns.MakeKitButton(p)
    defBtn:SetText(ns.T("btnDefault"))
    defBtn:SetWidth(110)
    defBtn:SetHeight(20)
    defBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -6)
    defBtn.onClick = function() ns.Session.ResetChecks() end
    for i, cls in ipairs(ns.CLASSES) do
        local cell = { specs = {} }
        classCells[i] = cell
        local cc = ns.MakeCheck(p)
        cc:SetSize(CHECK_H + 3, CHECK_H + 3)
        cell.check = cc
        cc.label:SetText(ns.T("cls_" .. cls.token))
        ns.ClassText(cc.label, cls.token)
        cc.tipTitle = ns.T("cls_" .. cls.token)
        cc.tip = ns.T(cls.classOnly and "tipClassOnly" or "tipClassCheck")
        cc.onToggle = function(on) ns.Session.SetClassChecked(cls.token, on) end
        classChecks[cls.token] = cc
        if not cls.classOnly then
            for k, sp in ipairs(cls.specs) do
                local c = makeCheck(p, sp)
                c.cls = cls.token
                cell.specs[k] = c
            end
        end
    end
end
local function placeSpecs()
    local p = classCells[1] and classCells[1].check:GetParent()
    if not p then return end
    local colW = (ns.window.PANE_W - PAD * 2) / CLS_COLS
    for i, cell in ipairs(classCells) do
        local col = (i - 1) % CLS_COLS
        local rowN = math.floor((i - 1) / CLS_COLS)
        local x = PAD + col * colW
        local y = 30 + rowN * 82
        cell.check:ClearAllPoints()
        cell.check:SetPoint("TOPLEFT", p, "TOPLEFT", x - 3, -(y - 3))
        for k, c in ipairs(cell.specs) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", p, "TOPLEFT", x + 9, -(y + 14 + (k - 1) * (CHECK_H)))
        end
    end
end
local function chanRow()
    local r = ns.NewFrame("Frame", nil, chanBox)
    r:SetSize(140, 22)
    r.check = ns.MakeCheck(r)
    r.check:SetPoint("LEFT", r, "LEFT", -3, 0)
    r.check.label:SetWidth(72)
    r.check.label:SetJustifyH("LEFT")
    r.every = ns.MakeEdit(r)
    r.every:SetWidth(36)
    r.every:SetHeight(20)
    r.every:SetNumeric(true)
    r.every:SetMaxLetters(4)
    r.every:SetPoint("RIGHT", r, "RIGHT", -16, 0)
    r.sec = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.sec:SetPoint("LEFT", r.every, "RIGHT", 3, 0)
    r.sec:SetText(ns.T("sec"))
    ns.PaintText(r.sec, "text.secondary")
    return r
end
local function buildPreview()
    local top = 362
    local p = panel(top, ns.window.PANE_H - top)
    p:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    local cap = label(p, "previewTitle")
    cap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    counter = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -PAD)
    local cf = ns.NewFrame("Frame", nil, p)
    cf:SetPoint("TOPRIGHT", counter, "TOPRIGHT", 2, 2)
    cf:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", -2, -2)
    cf:EnableMouse(true)
    cf.tip = ns.T("tipBytes")
    cf:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    cf:SetScript("OnLeave", ns.TipHide)
    preview = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preview:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -(PAD + 16))
    preview:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -(PAD + 16))
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    preview:SetHeight(40)
    ns.PaintText(preview, "text.primary")
    local chCap = label(p, "chanTitle")
    chCap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -(PAD + 60))
    chanBox = ns.NewFrame("Frame", nil, p)
    chanBox:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -(PAD + 74))
    chanBox:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 4)
    chanPool = ns.NewPool(chanRow)
end
local function refreshChannels()
    chanPool:Reset()
    local colW = (ns.window.PANE_W - PAD * 2) / CHAN_COLS
    for i, c in ipairs(ns.Spam.Channels()) do
        local r = chanPool:Acquire()
        local col = (i - 1) % CHAN_COLS
        local rowN = math.floor((i - 1) / CHAN_COLS)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", chanBox, "TOPLEFT", col * colW, -rowN * 22)
        r.check.label:SetText(c.label)
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
local function refresh()
    if not built or not pane:IsVisible() then return end
    local S, P = ns.Session, ns.Spam
    textSel:SetOptions(textOptions(), P.TextIndex())
    if #P.Texts() < 2 then
        delBtn:Disable()
        delBtn.tip = ns.T("tipDeleteLast")
    else
        delBtn:Enable()
        delBtn.tip = nil
    end
    if not body.focused then body:SetValue(P.Body()) end
    if not progE.focused then progE:SetValue(S.Field("prog")) end
    if not reqE.focused then reqE:SetValue(S.Field("req")) end
    if not timeE.focused then timeE:SetValue(S.Field("time")) end
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
        c:SetChecked(S.Checked(key))
        local on = S.ClassChecked(c.cls)
        c:SetAlpha(on and 1 or 0.4)
        c:EnableMouse(on)
    end
    if S.ChecksAreDefault() then
        defBtn:Disable()
        defBtn.tip = ns.T("tipChecksDefault")
    else
        defBtn:Enable()
        defBtn.tip = nil
    end
    local msg, len, fits, short = P.Build()
    preview:SetText(msg)
    local color = fits and (short and "text.title" or "text.primary") or "sem.notReady"
    counter:SetText(ns.Hex(color) .. len .. "/" .. P.Limit() .. "|r")
    refreshChannels()
end
local function build()
    pane = ns.window:Pane("spam")
    buildText()
    buildSpecs()
    buildPreview()
    placeSpecs()
    built = true
    pane:SetScript("OnShow", refresh)
    refresh()
end
local function resize()
    if not built then return end
    body:SetWidth(ns.window.PANE_W - PAD * 2 - 8)
    placeSpecs()
    refresh()
end
ns.Session.OnChange(refresh)
ns.window:OnSize(resize)
ns.SpamPane = { Build = build, Refresh = refresh }
ns.window:OnBuild(build)
