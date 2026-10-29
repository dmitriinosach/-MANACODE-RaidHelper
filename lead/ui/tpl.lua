local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local LEFT_W = 150
local MID_W = 210
local GAP = 10
local ROW_H = 24
local HEAD_H = 20
local CHECK_H = 18
local CARD_W = 200
local CARD_X = 10
local BASE = "GameFontHighlightSmall"
local CAPF = "GameFontNormalSmall"
local pane, listPool, rowPool, headPool, checkPool
local left, mid, right, scroll, child
local editCap, nameE, sizeSel, useBtn, copyBtn, delBtn, resetBtn, addBtn
local roleSel, grpSel, capE, rmBtn, emptyFs, specCap
local markCap, markBtns
local curKey, curSlot
local built = false
local function unfocus()
    if nameE then nameE:ClearFocus() end
    if capE then capE:ClearFocus() end
end
local function roleOptions()
    local out = {}
    for _, r in ipairs(ns.Tpl.ROLES) do
        out[#out + 1] = { key = r, label = ns.T("slot_" .. r) }
    end
    return out
end
local function groupOptions(auto)
    local out = { { key = 0, label = ns.T("slotGrpAuto", auto) } }
    for g = 1, ns.Layout.GROUPS do out[#out + 1] = { key = g, label = ns.T("grpN", g) } end
    return out
end
local function autoGroup(tpl, i)
    local slots = {}
    for k, s in ipairs(tpl.slots) do
        slots[k] = { role = s.role, grp = k ~= i and s.grp or nil }
    end
    return ns.Layout.Groups({ size = tpl.size, slots = slots })[i]
end
local function newListBtn()
    local b = ns.MakeKitButton(left)
    b:SetSize(LEFT_W - 20, 22)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.text:SetJustifyH("LEFT")
    return b
end
local function rowH()
    return ns.Fit(BASE, ROW_H, 8)
end
local function headH()
    return ns.Fit(CAPF, HEAD_H, 6)
end
local function newRow()
    local r = ns.NewFrame("Button", nil, child)
    r:SetSize(MID_W - 16, ROW_H - 2)
    r.bg = ns.Fill(r, "BACKGROUND")
    ns.PaintToken(r.bg, "card.sticker")
    r.bg:SetAllPoints()
    r.sel = ns.Fill(r, "BORDER")
    ns.PaintToken(r.sel, "text.title", 0.22)
    r.sel:SetAllPoints()
    r.role = r:CreateTexture(nil, "ARTWORK")
    r.role:SetSize(14, 14)
    r.role:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetSize(12, 12)
    r.mark:SetPoint("LEFT", r.role, "RIGHT", 3, 0)
    r.text = ns.Str(r, BASE)
    r.text:SetPoint("LEFT", r.role, "RIGHT", 5, 0)
    ns.PaintText(r.text, "text.primary")
    r.sps = {}
    for i = 1, 4 do
        local t = r:CreateTexture(nil, "ARTWORK")
        t:SetSize(13, 13)
        t:SetPoint("RIGHT", r, "RIGHT", -4 - (i - 1) * 14, 0)
        r.sps[i] = t
    end
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    return r
end
local function newHead()
    local fs = ns.Str(child, CAPF)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(MID_W - 16)
    ns.PaintTitle(fs)
    return fs
end
local function newCheck()
    local c = ns.MakeCheck(right)
    c:SetSize(CHECK_H + 2, CHECK_H + 2)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(14, 14)
    c.icon:SetPoint("LEFT", c, "RIGHT", 1, 0)
    c.label:ClearAllPoints()
    c.label:SetPoint("LEFT", c.icon, "RIGHT", 4, 0)
    return c
end
local function column(x, w)
    local p = ns.MakePanel(pane)
    p:SetPoint("TOPLEFT", pane, "TOPLEFT", x, 0)
    p:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", x, 0)
    p:SetWidth(w)
    return p
end
local function paintMarks(slot)
    local shared = #ns.Tpl.MarkSlots(curKey, slot.mark)
    for k, b in pairs(markBtns) do
        b:Show()
        local on = (k == 0 and not slot.mark) or slot.mark == k
        if b.frame then
            if on then b.frame:Show() else b.frame:Hide() end
            b.tipTitle = ns.T("mark" .. k)
            b.tip = (on and shared > 1) and ns.T("slotMarkShared", shared) or nil
        else
            b.active = on
            ns.StyleButton(b)
        end
    end
end
local function specText(slot)
    if not slot.specs or #slot.specs == 0 then return ns.T("slotSpecsAny") end
    local out = {}
    for k, key in ipairs(slot.specs) do out[k] = ns.T("spec_" .. key) end
    return ns.T("slotSpecsList", table.concat(out, ", "))
end
local function orderedSlots(tpl)
    local groups = ns.Layout.Groups(tpl)
    local order = {}
    for i in ipairs(tpl.slots) do order[#order + 1] = i end
    table.sort(order, function(a, b)
        if groups[a] ~= groups[b] then return groups[a] < groups[b] end
        return a < b
    end)
    return order, groups
end
local function fillList(T)
    listPool:Reset()
    local y = 12 + headH()
    for _, t in ipairs(T.List()) do
        local b = listPool:Acquire()
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -y)
        local mark = T.IsFactory(t.key) and (T.IsCustom(t.key) and "tplMarkEdited" or "tplMarkFactory") or "tplMarkOwn"
        b:SetText(T.Name(t) .. " " .. ns.Hex("text.muted") .. ns.T(mark) .. "|r")
        b.active = (t.key == curKey)
        ns.StyleButton(b)
        b.onClick = function()
            unfocus()
            curKey, curSlot = t.key, nil
            ns.TplPane.Refresh()
        end
        y = y + 24
    end
    listPool:HideExtras()
    return y
end
local function fillLeft(T, tpl, y)
    local own = not T.IsFactory(curKey)
    nameE:ClearAllPoints()
    nameE:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -(y + 10))
    if not nameE.focused then nameE:SetValue(T.Name(tpl)) end
    nameE:EnableMouse(own)
    nameE:SetAlpha(own and 1 or 0.5)
    nameE.tip = own and nil or ns.T("tipFactoryName")
    sizeSel:ClearAllPoints()
    sizeSel:SetPoint("TOPLEFT", nameE, "BOTTOMLEFT", 0, -6)
    sizeSel:SetOptions({ { key = 10, label = ns.T("size10") }, { key = 25, label = ns.T("size25") } }, tpl.size)
    useBtn:ClearAllPoints()
    useBtn:SetPoint("TOPLEFT", sizeSel, "BOTTOMLEFT", 0, -10)
    if ns.Session.Template().key == curKey then
        useBtn:Disable()
        useBtn.tip = ns.T("tipTplUsed")
    else
        useBtn:Enable()
        useBtn.tip = nil
    end
    copyBtn:ClearAllPoints()
    copyBtn:SetPoint("TOPLEFT", useBtn, "BOTTOMLEFT", 0, -10)
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -6)
    delBtn:ClearAllPoints()
    delBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -6)
    if own then
        resetBtn:Hide()
        delBtn:Show()
        delBtn:Enable()
    else
        delBtn:Hide()
        resetBtn:Show()
        if T.IsCustom(curKey) then
            resetBtn:Enable()
            resetBtn.tip = nil
        else
            resetBtn:Disable()
            resetBtn.tip = ns.T("tipTplNotEdited")
        end
    end
end
local function fillRows(tpl)
    rowPool:Reset()
    headPool:Reset()
    local step, hh = rowH(), headH()
    local order, groups = orderedSlots(tpl)
    local y, lastG = 0, nil
    for _, i in ipairs(order) do
        local s = tpl.slots[i]
        local g = groups[i]
        if g ~= lastG then
            local h = headPool:Acquire()
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -(y + (lastG and 4 or 0)))
            h:SetHeight(hh)
            h:SetText(ns.T("grpN", g))
            y = y + hh + (lastG and 4 or 0)
            lastG = g
        end
        local r = rowPool:Acquire()
        r:ClearAllPoints()
        r:SetHeight(step - 2)
        r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        ns.Icon.Role(r.role, ns.ROLE_GROUP[s.role])
        r.text:SetText(i .. ". " .. (ns.Tpl.Cap(s) or ns.T("slot_" .. s.role)))
        r.text:ClearAllPoints()
        if s.mark then
            ns.Icon.Mark(r.mark, s.mark)
            r.mark:Show()
            r.text:SetPoint("LEFT", r.mark, "RIGHT", 4, 0)
        else
            r.mark:Hide()
            r.text:SetPoint("LEFT", r.role, "RIGHT", 5, 0)
        end
        local sps = s.specs or {}
        r.text:SetPoint("RIGHT", r, "RIGHT", -(6 + #sps * 14), 0)
        r.text:SetHeight(ns.LineH(BASE))
        for k, t in ipairs(r.sps) do
            local key = sps[#sps - k + 1]
            if key and k <= #sps then
                ns.Icon.Spec(t, key)
                t:Show()
            else
                t:Hide()
            end
        end
        if curSlot == i then r.sel:Show() else r.sel:Hide() end
        r:SetScript("OnClick", function()
            unfocus()
            curSlot = i
            ns.TplPane.Refresh()
        end)
        y = y + step
    end
    rowPool:HideExtras()
    headPool:HideExtras()
    child:SetHeight(math.max(1, y))
end
local function fillCard(T, tpl)
    checkPool:Reset()
    local slot = curSlot and tpl.slots[curSlot]
    if not slot then
        curSlot = nil
        for _, f in ipairs({ roleSel, grpSel, capE, rmBtn, markCap, specCap }) do f:Hide() end
        for _, b in pairs(markBtns) do b:Hide() end
        emptyFs:Show()
        checkPool:HideExtras()
        return
    end
    emptyFs:Hide()
    for _, f in ipairs({ roleSel, grpSel, capE, rmBtn, markCap, specCap }) do f:Show() end
    paintMarks(slot)
    roleSel:SetOptions(roleOptions(), slot.role)
    grpSel:SetOptions(groupOptions(autoGroup(tpl, curSlot)), slot.grp or 0)
    if not capE.focused then capE:SetValue(ns.Tpl.Cap(slot) or "") end
    specCap:SetText(specText(slot))
    local on = {}
    for _, k in ipairs(slot.specs or {}) do on[k] = true end
    local n, last = 0, nil
    for _, cls in ipairs(ns.CLASSES) do
        for _, sp in ipairs(cls.specs) do
            if T.SpecFits(slot.role, sp.key) then
                n = n + 1
                local c = checkPool:Acquire()
                local col = (n - 1) % 2
                local rowN = math.floor((n - 1) / 2)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", specCap, "BOTTOMLEFT", -2 + col * 110, -(4 + rowN * CHECK_H))
                ns.Icon.Spec(c.icon, sp.key)
                c.label:SetText(ns.T("spec_" .. sp.key))
                ns.ClassText(c.label, sp.class)
                c.tipTitle = ns.T("specFull_" .. sp.key)
                c:SetChecked(on[sp.key] or false)
                c.onToggle = function(v)
                    unfocus()
                    ns.Tpl.ToggleSpec(curKey, curSlot, sp.key, v)
                end
                last = c
            end
        end
    end
    checkPool:HideExtras()
    rmBtn:ClearAllPoints()
    if last then
        rmBtn:SetPoint("TOPLEFT", specCap, "BOTTOMLEFT", 0, -(4 + math.ceil(n / 2) * CHECK_H + 12))
    else
        rmBtn:SetPoint("TOPLEFT", specCap, "BOTTOMLEFT", 0, -12)
    end
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    local T = ns.Tpl
    if not curKey or not T.Exists(curKey) then curKey = ns.Session.Template().key end
    local tpl = T.Get(curKey)
    local y = fillList(T)
    fillLeft(T, tpl, y)
    fillRows(tpl)
    addBtn.tipTitle = ns.T("btnAddSlot")
    fillCard(T, tpl)
end
local function askDelete()
    local T = ns.Tpl
    local key = curKey
    ns.Kit.Confirm(ns.T("tplDeleteAsk", T.Name(T.Get(key))), ns.T("btnTplDelete"), function()
        T.Delete(key)
        curKey, curSlot = nil, nil
        refresh()
    end)
end
local function build()
    pane = ns.window:Pane("tpl")
    left = column(0, LEFT_W)
    mid = column(LEFT_W + GAP, MID_W)
    right = column(LEFT_W + MID_W + GAP * 2, ns.window.PANE_W - LEFT_W - MID_W - GAP * 2)
    right:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    editCap = ns.Str(left, CAPF)
    editCap:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -10)
    editCap:SetText(ns.T("tplEditing"))
    ns.PaintTitle(editCap)
    listPool = ns.NewPool(newListBtn)
    nameE = ns.MakeEdit(left)
    nameE:SetWidth(LEFT_W - 20)
    nameE:SetMaxLetters(24)
    nameE.onCommit = function(v)
        local name = ns.Tpl.Clean(v)
        if not ns.Tpl.Rename(curKey, v) and name ~= "" and ns.Tpl.NameTaken(name, curKey) then
            ns.say(ns.T("tplNameTaken", name))
        end
        refresh()
    end
    sizeSel = ns.MakeSelect(left)
    sizeSel:SetWidth(LEFT_W - 20)
    sizeSel.onPick = function(k)
        unfocus()
        ns.Tpl.SetSize(curKey, k)
    end
    useBtn = ns.MakeKitButton(left)
    useBtn:SetSize(LEFT_W - 20, 22)
    useBtn:SetText(ns.T("btnTplUse"))
    useBtn.tipTitle = ns.T("btnTplUse")
    useBtn.onClick = function()
        unfocus()
        ns.Session.SetTemplate(curKey)
    end
    copyBtn = ns.MakeKitButton(left)
    copyBtn:SetSize(LEFT_W - 20, 22)
    copyBtn:SetText(ns.T("btnTplCopy"))
    copyBtn.onClick = function()
        unfocus()
        curKey = ns.Tpl.Copy(curKey) or curKey
        curSlot = nil
        refresh()
    end
    resetBtn = ns.MakeKitButton(left)
    resetBtn:SetSize(LEFT_W - 20, 22)
    resetBtn:SetText(ns.T("btnTplReset"))
    resetBtn.onClick = function()
        unfocus()
        curSlot = nil
        ns.Tpl.Reset(curKey)
        refresh()
    end
    delBtn = ns.MakeKitButton(left, nil, "danger")
    delBtn:SetSize(LEFT_W - 20, 22)
    delBtn:SetText(ns.T("btnTplDelete"))
    delBtn.onClick = function()
        unfocus()
        askDelete()
    end
    scroll = ns.NewFrame("ScrollFrame", nil, mid)
    scroll:SetPoint("TOPLEFT", mid, "TOPLEFT", 8, -10)
    scroll:SetPoint("BOTTOMRIGHT", mid, "BOTTOMRIGHT", -8, 40)
    child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(MID_W - 16, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, child:GetHeight() - (ns.window.PANE_H - 50))
        local v = self:GetVerticalScroll() - delta * rowH() * 2
        if v < 0 then v = 0 end
        if v > maxScroll then v = maxScroll end
        self:SetVerticalScroll(v)
    end)
    rowPool = ns.NewPool(newRow)
    headPool = ns.NewPool(newHead)
    addBtn = ns.MakeKitButton(mid)
    addBtn:SetPoint("BOTTOMLEFT", mid, "BOTTOMLEFT", 8, 10)
    addBtn:SetSize(MID_W - 16, 22)
    addBtn:SetText(ns.T("btnAddSlot"))
    addBtn.onClick = function()
        unfocus()
        local t = ns.Tpl.Get(curKey)
        local role = curSlot and t.slots[curSlot] and t.slots[curSlot].role or "dd"
        curSlot = ns.Tpl.AddSlot(curKey, curSlot, role) or curSlot
        refresh()
    end
    roleSel = ns.MakeSelect(right)
    roleSel:SetPoint("TOPLEFT", right, "TOPLEFT", CARD_X, -12)
    roleSel:SetWidth(CARD_W)
    roleSel.onPick = function(k)
        unfocus()
        ns.Tpl.SetRole(curKey, curSlot, k)
    end
    grpSel = ns.MakeSelect(right)
    grpSel:SetPoint("TOPLEFT", roleSel, "BOTTOMLEFT", 0, -6)
    grpSel:SetWidth(CARD_W)
    grpSel.tipTitle = ns.T("slotGrpTitle")
    grpSel.tip = ns.T("tipSlotGrp")
    grpSel.onPick = function(k)
        unfocus()
        ns.Tpl.SetGroup(curKey, curSlot, k ~= 0 and k or nil)
    end
    capE = ns.MakeEdit(right)
    capE:SetPoint("TOPLEFT", grpSel, "BOTTOMLEFT", 0, -6)
    capE:SetWidth(CARD_W)
    capE.tip = ns.T("tipSlotCap")
    capE:SetMaxLetters(24)
    capE.onCommit = function(v) ns.Tpl.SetCap(curKey, curSlot, v) end
    markCap = ns.Str(right, CAPF)
    markCap:SetPoint("TOPLEFT", capE, "BOTTOMLEFT", 0, -10)
    markCap:SetText(ns.T("slotMark"))
    ns.PaintTitle(markCap)
    markBtns = {}
    local none = ns.MakeKitButton(right)
    none:SetSize(22, 20)
    none:SetPoint("TOPLEFT", markCap, "BOTTOMLEFT", 0, -4)
    none:SetText("x")
    none.tipTitle = ns.T("slotMarkNone")
    none.tip = ns.T("tipSlotMark")
    none.onClick = function()
        unfocus()
        ns.Tpl.SetMark(curKey, curSlot, nil)
    end
    markBtns[0] = none
    for k = 1, 8 do
        local b = ns.NewFrame("Button", nil, right)
        b:SetSize(18, 18)
        b:SetPoint("LEFT", none, "RIGHT", 8 + (k - 1) * 23, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        ns.Icon.Mark(b.icon, k)
        b.frame = ns.Fill(b, "BACKGROUND")
        ns.PaintToken(b.frame, "text.title", 0.45)
        b.frame:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        b.frame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function()
            unfocus()
            ns.Tpl.SetMark(curKey, curSlot, k)
        end)
        b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
        b:SetScript("OnLeave", ns.TipHide)
        markBtns[k] = b
    end
    specCap = ns.Str(right, CAPF)
    specCap:SetPoint("TOPLEFT", none, "BOTTOMLEFT", 0, -10)
    specCap:SetWidth(CARD_W + 40)
    specCap:SetJustifyH("LEFT")
    ns.PaintTitle(specCap)
    checkPool = ns.NewPool(newCheck)
    rmBtn = ns.MakeKitButton(right, nil, "danger")
    rmBtn:SetSize(140, 22)
    rmBtn:SetText(ns.T("btnRemoveSlot"))
    rmBtn.onClick = function()
        unfocus()
        ns.Tpl.RemoveSlot(curKey, curSlot)
        curSlot = nil
        refresh()
    end
    emptyFs = ns.Str(right, BASE)
    emptyFs:SetPoint("TOP", right, "TOP", 0, -40)
    emptyFs:SetText(ns.T("tplPickSlot"))
    ns.PaintText(emptyFs, "text.secondary")
    built = true
    pane:SetScript("OnShow", refresh)
    refresh()
end
ns.Session.OnChange(refresh)
ns.OnFont(refresh)
ns.TplPane = { Build = build, Refresh = refresh,
    Parts = function() return useBtn, delBtn, specCap, rmBtn, headPool, rowPool end }
ns.window:OnBuild(build)
