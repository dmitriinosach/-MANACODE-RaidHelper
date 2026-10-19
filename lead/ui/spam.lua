local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 10
local GAP = 6
local CHECK_H = 17
local ICON = 14
local CLS_COLS = 5
local CHAN_COLS = 4
local SPECS_TOP = 158
local ROW_B = 26
local BASE = "GameFontHighlightSmall"
local STEP_BTN = 18
local NEED_W = 22
local styleSel
local pane, textSel, delBtn, body, progE, reqSel, reqE, lootSel, timeE
local defBtn, tplBtn, preview, counter, chanPool, chanBox
local specsPanel, specsCap, previewPanel, chCap
local checks = {}
local classChecks = {}
local classCells = {}
local needVals = {}
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
    local fs = ns.Str(parent, "GameFontNormalSmall")
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
    c.tip = ns.T("needFull_" .. sp.role)
    c.onToggle = function(on) ns.Session.SetChecked(sp.key, on) end
    checks[sp.key] = c
    return c
end
local function rowHeights()
    local out = {}
    for i, cls in ipairs(ns.CLASSES) do
        local r = math.floor((i - 1) / CLS_COLS) + 1
        local n = cls.classOnly and 0 or #cls.specs
        out[r] = math.max(out[r] or 0, 14 + n * CHECK_H)
    end
    return out
end
local function rowB()
    return ns.Fit(BASE, ROW_B, 8)
end
local function gridTop()
    return 30 + rowB()
end
local function specsHeight()
    local h = gridTop()
    for _, rh in ipairs(rowHeights()) do h = h + rh end
    return h + 6
end
local function stepButton(parent, text, role, delta)
    local b = ns.MakeKitButton(parent)
    b:SetSize(STEP_BTN, STEP_BTN)
    b:SetText(text)
    b.tipTitle = ns.T("needFull_" .. role)
    b.onClick = function() ns.Spam.AddNeed(role, delta) end
    return b
end
local function buildNeeds(p)
    local cap = label(p, "needsTitle")
    cap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    local prev = cap
    for _, role in ipairs(ns.Spam.ROLES) do
        local name = ns.Str(p, "GameFontNormalSmall")
        name:SetText(ns.T("needShort_" .. role))
        ns.PaintText(name, "text.secondary")
        name:SetPoint("LEFT", prev, "RIGHT", prev == cap and 8 or 10, 0)
        local minus = stepButton(p, "-", role, -1)
        minus:SetPoint("LEFT", name, "RIGHT", 4, 0)
        local val = ns.Str(p, BASE)
        val:SetWidth(ns.Wide(BASE, NEED_W))
        val:SetJustifyH("CENTER")
        val:SetPoint("LEFT", minus, "RIGHT", 0, 0)
        local plus = stepButton(p, "+", role, 1)
        plus:SetPoint("LEFT", val, "RIGHT", 0, 0)
        needVals[role] = val
        prev = plus
    end
    tplBtn = ns.MakeKitButton(p)
    tplBtn:SetText(ns.T("btnNeedsTpl"))
    tplBtn:SetWidth(tplBtn.text:GetStringWidth() + 20)
    tplBtn:SetHeight(20)
    tplBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -6)
    tplBtn.tipTitle = ns.T("btnNeedsTpl")
    tplBtn.onClick = function() ns.Spam.NeedsFromTemplate() end
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
    for role, fs in pairs(needVals) do
        fs:SetText(tostring(cur[role]))
        ns.PaintText(fs, cur[role] > 0 and "text.primary" or "text.muted")
    end
    local t = P.TemplateNeeds(ns.Session.Template())
    local same = true
    for _, role in ipairs(P.ROLES) do
        if t[role] ~= cur[role] then same = false end
    end
    tplBtn.tip = needsTip(t)
    if same then tplBtn:Disable() else tplBtn:Enable() end
end
local function placeSpecsHead()
    specsCap:ClearAllPoints()
    specsCap:SetPoint("TOPLEFT", specsPanel, "TOPLEFT", PAD, -(PAD + rowB()))
    defBtn:ClearAllPoints()
    defBtn:SetPoint("TOPRIGHT", specsPanel, "TOPRIGHT", -PAD, -(6 + rowB()))
end
local function buildSpecs()
    local p = panel(SPECS_TOP, specsHeight())
    specsPanel = p
    buildNeeds(p)
    specsCap = label(p, "specsTitle")
    defBtn = ns.MakeKitButton(p)
    defBtn:SetText(ns.T("btnDefault"))
    defBtn:SetWidth(110)
    defBtn:SetHeight(20)
    placeSpecsHead()
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
    local tops, y0 = {}, gridTop()
    for r, h in ipairs(rowHeights()) do
        tops[r] = y0
        y0 = y0 + h
    end
    for i, cell in ipairs(classCells) do
        local col = (i - 1) % CLS_COLS
        local rowN = math.floor((i - 1) / CLS_COLS)
        local x = PAD + col * colW
        local y = tops[rowN + 1]
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
    r.sec = ns.Str(r, BASE)
    r.sec:SetPoint("LEFT", r.every, "RIGHT", 3, 0)
    r.sec:SetText(ns.T("sec"))
    ns.PaintText(r.sec, "text.secondary")
    return r
end
local function placePreview()
    local top = SPECS_TOP + specsHeight() + 8
    local line = ns.Fit(BASE, 16, 2)
    local pv = ns.Fit(BASE, 40, 0, 3)
    local capY = PAD + line + pv + 4
    local boxY = capY + ns.Fit("GameFontNormalSmall", 14, 2)
    previewPanel:ClearAllPoints()
    previewPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    previewPanel:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    preview:ClearAllPoints()
    preview:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", PAD, -(PAD + line))
    preview:SetPoint("TOPRIGHT", previewPanel, "TOPRIGHT", -PAD, -(PAD + line))
    preview:SetHeight(pv)
    chCap:ClearAllPoints()
    chCap:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", PAD, -capY)
    chanBox:ClearAllPoints()
    chanBox:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", PAD, -boxY)
    chanBox:SetPoint("BOTTOMRIGHT", previewPanel, "BOTTOMRIGHT", -PAD, 4)
end
local function buildPreview()
    local p = ns.MakePanel(pane)
    previewPanel = p
    local cap = label(p, "previewTitle")
    cap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    counter = ns.Str(p, BASE)
    counter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -PAD)
    local cf = ns.NewFrame("Frame", nil, p)
    cf:SetPoint("TOPRIGHT", counter, "TOPRIGHT", 2, 2)
    cf:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", -2, -2)
    cf:EnableMouse(true)
    cf.tip = ns.T("tipBytes")
    cf:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    cf:SetScript("OnLeave", ns.TipHide)
    preview = ns.Str(p, BASE)
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    ns.PaintText(preview, "text.primary")
    chCap = label(p, "chanTitle")
    chanBox = ns.NewFrame("Frame", nil, p)
    chanPool = ns.NewPool(chanRow)
    placePreview()
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
    refreshNeeds()
    local msg, len, fits, short = P.Build()
    preview:SetText(msg)
    local color = fits and (short and "text.title" or "text.primary") or "sem.notReady"
    counter:SetText(ns.Hex(color) .. len .. "/" .. P.Limit() .. "|r")
    refreshChannels()
end
local function onFont()
    if not built then return end
    for _, fs in pairs(needVals) do fs:SetWidth(ns.Wide(BASE, NEED_W)) end
    specsPanel:SetHeight(specsHeight())
    placeSpecsHead()
    placeSpecs()
    placePreview()
    refresh()
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
ns.OnFont(onFont)
ns.window:OnSize(resize)
ns.SpamPane = { Build = build, Refresh = refresh }
ns.window:OnBuild(build)
