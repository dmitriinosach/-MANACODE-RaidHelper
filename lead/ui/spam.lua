local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 10
local GAP = 6
local LINE_GAP = 6
local CHECK_H = 17
local ICON = 14
local CLS_ICON = 16
local CHAN_COLS = 3
local BASE = "GameFontHighlightSmall"
local STEP_BTN = 18
local NEED_W = 22
local CLS_W = 170
local SPEC_W = 96
local ROW_PAD = 4
local ROW_EXTRA = 10
local PANEL_GAP = 8
local BAR_W = 12
local STYLE_W = 170
local STYLE_MIN = 110
local styleSel, styleCap
local pane, textSel, delBtn, body, progE, reqSel, reqE, lootSel, timeE, dsE
local defBtn, tplBtn, preview, counter, chanPool, chanBox
local textPanel, previewPanel, chanPanel, specsPanel, specsCap, needsCap
local tokenItems, valueUnits, markBtns = {}, {}, {}
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
local function label(parent, key)
    local fs = ns.Str(parent, "GameFontNormalSmall")
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
local function unitWidth(items)
    local w = 0
    for i, it in ipairs(items) do
        w = w + it:GetWidth() + (i > 1 and GAP or 0)
    end
    return w
end
local function flow(parent, units, x, y, maxW, reserve)
    local h = lineH()
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
                it:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, -cy)
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
local function buildText()
    local p = ns.MakePanel(pane)
    textPanel = p
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
    local prev
    for _, it in ipairs({ textSel, newBtn, copyBtn, delBtn }) do
        if prev then
            it:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        else
            it:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
        end
        prev = it
    end
    styleSel = ns.MakeSelect(p)
    styleSel:SetWidth(170)
    styleSel:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -PAD)
    styleSel.tip = ns.T("tipStyle")
    styleSel.onPick = function(k) ns.Session.SetField("needsStyle", k) end
    styleCap = ns.Str(p, BASE)
    styleCap:SetText(ns.T("styleLabel"))
    ns.PaintText(styleCap, "text.secondary")
    styleCap:SetPoint("RIGHT", styleSel, "LEFT", -GAP, 0)
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
    body.tip = ns.T("tipLinks")
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        if text and body.focused and body:IsVisible() and not ChatEdit_GetActiveWindow() then
            body:Insert(text)
        end
    end)
    body.onChange = function(text) ns.Spam.SetBody(text) end
    tokenItems = {
        { tokenButton(p, "tokRaid") }, { tokenButton(p, "tokNeeds") }, { tokenButton(p, "tokCount") },
        { tokenButton(p, "tokFree", "tipTokFree") }, { tokenButton(p, "tokLead", "tipTokLead") },
        { tokenButton(p, "tokHow", "tipTokHow") },
    }
    progE = makeEdit(p, 84, "prog")
    reqSel = ns.MakeSelect(p)
    reqSel:SetWidth(64)
    reqSel.onPick = function(k) ns.Session.SetField("reqKind", k) end
    reqE = makeEdit(p, 38, "req")
    lootSel = ns.MakeSelect(p)
    lootSel:SetWidth(170)
    lootSel.onPick = function(k) ns.Session.SetField("loot", k) end
    timeE = makeEdit(p, 90, "time")
    dsE = makeEdit(p, 120, "ds")
    valueUnits = {
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
    local room = w - (textSel:GetWidth() + delBtn:GetWidth() * 3 + GAP * 5)
    local capW = styleCap:GetStringWidth() + GAP
    if room - capW >= STYLE_MIN then
        styleCap:Show()
        styleSel:SetWidth(math.min(STYLE_W, room - capW))
    else
        styleCap:Hide()
        styleSel:SetWidth(math.max(STYLE_MIN, math.min(STYLE_W, room)))
    end
    local marksW = 8 * 18
    local top = PAD + 28 + 46 + LINE_GAP
    local h1 = flow(p, tokenItems, PAD, top, w, marksW + GAP)
    for i = 8, 1, -1 do
        local b = markBtns[i]
        b:ClearAllPoints()
        if i == 8 then
            b:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -(top + 2))
        else
            b:SetPoint("RIGHT", markBtns[i + 1], "LEFT", -2, 0)
        end
    end
    local h2 = flow(p, valueUnits, PAD, top + h1 + LINE_GAP, w)
    local h = top + h1 + LINE_GAP + h2 + PAD
    p:SetHeight(h)
    return h
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
end
local function placePreview(y)
    local line = ns.Fit(BASE, 16, 2)
    local pv = ns.Fit(BASE, 28, 0, 2)
    previewPanel:ClearAllPoints()
    previewPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    previewPanel:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    preview:ClearAllPoints()
    preview:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", PAD, -(PAD + line))
    preview:SetPoint("TOPRIGHT", previewPanel, "TOPRIGHT", -PAD, -(PAD + line))
    preview:SetHeight(pv)
    local h = PAD + line + pv + PAD
    previewPanel:SetHeight(h)
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
    return r
end
local function buildChannels()
    local p = ns.MakePanel(pane)
    chanPanel = p
    local cap = label(p, "chanTitle")
    cap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    chanBox = ns.NewFrame("Frame", nil, p)
    chanPool = ns.NewPool(chanRow)
end
local function chanRowH()
    return ns.Fit(BASE, 22, 4)
end
local function placeChannels(y)
    local cap = ns.Fit("GameFontNormalSmall", 14, 2) + 4
    local rows = math.max(1, math.ceil(#ns.Spam.Channels() / CHAN_COLS))
    chanPanel:ClearAllPoints()
    chanPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    chanPanel:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    chanBox:ClearAllPoints()
    chanBox:SetPoint("TOPLEFT", chanPanel, "TOPLEFT", PAD, -(PAD + cap))
    chanBox:SetPoint("TOPRIGHT", chanPanel, "TOPRIGHT", -PAD, -(PAD + cap))
    chanBox:SetHeight(rows * chanRowH())
    local h = PAD + cap + rows * chanRowH() + PAD - 4
    chanPanel:SetHeight(h)
    return h
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
    h.name = ns.Str(p, "GameFontNormalSmall")
    h.name:SetText(ns.T("needShort_" .. role))
    ns.PaintTitle(h.name)
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
    specsCap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
    defBtn = ns.MakeKitButton(p)
    defBtn:SetText(ns.T("btnDefault"))
    defBtn:SetWidth(defBtn.text:GetStringWidth() + 20)
    defBtn:SetHeight(20)
    defBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -6)
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
    needsCap = label(p, "needsTitle")
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
    return ns.Wide(BASE, SPEC_W)
end
local function placeSpecs(y)
    local p = specsPanel
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -y)
    p:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -y)
    local pageH = page:GetHeight() or 0
    local roles = ns.Spam.ROLES
    local clsW = ns.Wide(BASE, CLS_W)
    local cellW = (paneW() - PAD * 2 - clsW) / #roles
    local headY = PAD + 28
    local headH = ns.Fit(BASE, 20, 2)
    headBg:ClearAllPoints()
    headBg:SetPoint("TOPLEFT", p, "TOPLEFT", PAD - 4, -(headY - 3))
    headBg:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(PAD - 4), -(headY - 3))
    headBg:SetHeight(headH + 6)
    needsCap:ClearAllPoints()
    needsCap:SetPoint("LEFT", p, "TOPLEFT", PAD, -(headY + headH / 2))
    for k, role in ipairs(roles) do
        local h = roleHeads[role]
        h.name:ClearAllPoints()
        h.name:SetPoint("LEFT", p, "TOPLEFT", PAD + clsW + (k - 1) * cellW, -(headY + headH / 2))
    end
    local perLine = math.max(1, math.floor(cellW / specW()))
    local heights, natural = {}, 0
    for i, row in ipairs(classRows) do
        local lines = 1
        for _, list in pairs(row.cells) do
            lines = math.max(lines, math.ceil(#list / perLine))
        end
        heights[i] = lines * CHECK_H + ROW_PAD * 2
        natural = natural + heights[i]
    end
    local top = headY + headH + 6
    local avail = pageH - y - top - PAD
    local extra = 0
    if avail > natural then extra = math.min(ROW_EXTRA, math.floor((avail - natural) / #classRows)) end
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
                    c:SetPoint("TOPLEFT", p, "TOPLEFT", x0 - 3 + col * specW(), -(y0 + ln * CHECK_H - 1))
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
    local h = math.max(cy + PAD, pageH - y)
    p:SetHeight(h)
    return h
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
local function refreshChannels()
    chanPool:Reset()
    local colW = (paneW() - PAD * 2) / CHAN_COLS
    local rh = chanRowH()
    for i, c in ipairs(ns.Spam.Channels()) do
        local r = chanPool:Acquire()
        local col = (i - 1) % CHAN_COLS
        local rowN = math.floor((i - 1) / CHAN_COLS)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", chanBox, "TOPLEFT", col * colW, -rowN * rh)
        r:SetSize(colW - 12, rh)
        r.check.label:SetWidth(colW - 110)
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
local chanCount = -1
local function layout()
    local y = placeText(0) + PANEL_GAP
    y = y + placePreview(y) + PANEL_GAP
    y = y + placeChannels(y) + PANEL_GAP
    y = y + placeSpecs(y)
    pane:SetWidth(paneW())
    pane:SetHeight(y)
    scroller:Rescroll()
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    local S, P = ns.Session, ns.Spam
    if #P.Channels() ~= chanCount then
        chanCount = #P.Channels()
        layout()
    end
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
    counter:SetText(ns.Hex(color) .. len .. "/" .. P.Limit() .. "|r")
    refreshChannels()
end
local function relayout()
    if not built then return end
    body:SetWidth(paneW() - PAD * 2 - 8)
    for _, fs in pairs(needVals) do fs:SetWidth(ns.Wide(BASE, NEED_W)) end
    layout()
    refresh()
end
local function build()
    page = ns.window:Pane("spam")
    scroller = ns.ScrollPage(page, { fill = true, bar = "deck" })
    pane = scroller.content
    buildText()
    buildPreview()
    buildChannels()
    buildSpecs()
    built = true
    layout()
    page:SetScript("OnShow", function()
        layout()
        refresh()
    end)
    page:SetScript("OnSizeChanged", function() layout() end)
    refresh()
end
ns.Session.OnChange(refresh)
ns.OnFont(relayout)
ns.window:OnSize(relayout)
ns.SpamPane = { Build = build, Refresh = refresh }
ns.window:OnBuild(build)
