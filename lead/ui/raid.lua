local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local Lay = ns.Layout
local GROUPS = 8
local COLS = 4
local GAP = 8
local HEAD_H = 20
local CELL_H = 34
local MARKS = 8
local SPECS = 4
local BAR_H = 28
local STRIP_H = 24
local STRIP_GAP = 6
local INFO_GAP = 6
local SORT_W = 150
local SORT_TIME = 10
local ICON_STEP = 13
local pane, strip, bar, barFs, sortBtn
local boxes = {}
local ghost, dragFrom
local menu, menuCatcher, menuMarks, menuBtns, menuSpecs, menuOffs, menuSlots
local built = false
local sortUntil, sortWait = 0, false
local function officer()
    return ns.Test.Active() or IsRaidLeader() or IsRaidOfficer()
end
local function inRaid()
    return ns.Compat.GroupSize() > 0 or ns.Test.Active()
end
local function addonVer(name)
    local V = root.Version
    return V and V.Of and V.Of(name) or nil
end
local function shortVer(v)
    local s = v:gsub("%-(%a)%a*%.?", "%1")
    return s
end
local function slotLabel(slot)
    return ns.Tpl.Cap(slot) or ns.T("slot_" .. slot.role)
end
local function specNames(list)
    local out = {}
    for _, k in ipairs(list or {}) do out[#out + 1] = ns.T("spec_" .. k) end
    return table.concat(out, ", ")
end
local function gsText(name)
    local d = GS_Data and GS_Data[GetRealmName()]
    local r = d and d.Players and d.Players[name]
    local il = (r and r.Average) or ns.Session.Player(name).ilvl
    local gs = r and r.GearScore
    local dash = ns.Hex("text.muted") .. "-|r"
    if not gs and not il then return dash end
    return (gs or dash) .. " " .. ns.Hex("text.secondary") .. (il and math.floor(il) or "") .. "|r"
end
local function coloredName(m)
    local r, g, b = ns.ClassColor(m.class)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)) .. m.name .. "|r"
end
local function specTip(f, m)
    local p = ns.Session.Player(m.name)
    f.tipTitle = coloredName(m)
    local lines = {}
    if p.spec then
        lines[#lines + 1] = ns.T("tipSpec", ns.T("specFull_" .. p.spec), ns.T("src_" .. (p.specSrc or "hand")))
    else
        lines[#lines + 1] = ns.T("tipSpecUnknown")
    end
    if p.off then
        lines[#lines + 1] = ns.T("tipOff", ns.T("specFull_" .. p.off), ns.T("src_" .. (p.offSrc or "hand")))
    end
    f.tip = table.concat(lines, "\n")
end
local function specShort(key)
    local full = ns.T("specFull_" .. key)
    return full:match(":%s*(.+)$") or full
end
local function specIcon(key)
    local sp = ns.SPEC[key]
    local tex = sp and ns.Compat.SpellIcon(sp.icon)
    return tex and ("|T" .. tex .. ":14|t ") or ""
end
local function addRows(out, rows)
    if not rows then return end
    if #out > 0 then out[#out + 1] = { kind = "sep" } end
    for _, l in ipairs(rows) do out[#out + 1] = l end
end
local function cardLines(m, p, slot, ver)
    local out = {}
    local spec = p.spec and (specIcon(p.spec) .. ns.Hex("text.primary") .. specShort(p.spec) .. "|r")
    out[1] = { kind = "head", left = m.name, class = m.class, right = spec or ns.T("cardSpecNone") }
    if p.off or p.spec then
        out[2] = { kind = "note", left = p.off and ns.T("cardOff", specShort(p.off)) or "",
            right = p.spec and ns.T("srcShort_" .. (p.specSrc or "hand")) or nil }
    end
    if p.note then out[#out + 1] = { kind = "note", left = ns.T("tipNoteLine", p.note) } end
    if (p.offRolls or 0) > 0 then out[#out + 1] = { kind = "row", left = ns.T("cardDice"), right = tostring(p.offRolls) } end
    local rh = { { kind = "head", left = ns.T("cardRh") },
        { kind = "row", left = ns.T("cardVer"), right = ver or ns.T("cardVerNone"), tone = not ver and "dim" or nil } }
    if slot then
        rh[3] = { kind = "row", left = ns.T("cardSlot"), right = slotLabel(slot) }
        if slot.specs then rh[4] = { kind = "sub", left = specNames(slot.specs) } end
    elseif m.work then
        rh[3] = { kind = "row", left = ns.T("cardSlot"), right = ns.T("cardSlotNone"), tone = "warn" }
    end
    addRows(out, rh)
    addRows(out, ns.Bober.Rows(m.name, m.unit))
    addRows(out, ns.ReadyUI.TipRows(m))
    out[#out + 1] = { kind = "sep" }
    out[#out + 1] = { kind = "note", left = ns.T("tipRaidCell") }
    local baked = ns.Bober.Baked()
    if baked then out[#out + 1] = { kind = "note", left = ns.T("bbTipBaked", baked) } end
    return out
end
local function cardEnter(self)
    if self.lines then
        ns.Kit.Tip.Show(self, self.lines)
    elseif self.member or self.slotIndex then
        ns.TipShow(self)
    end
end
local function cardLeave()
    ns.TipHide()
    ns.Kit.Tip.Hide()
end
local function fillSlotButtons(btns, m, after)
    local S = ns.Session
    local slots = S.FreeSlotsFor(m, #btns)
    local tpl = S.Template()
    for k, b in ipairs(btns) do
        local i = slots[k]
        if i then
            local slot = tpl.slots[i]
            if slot.specs and #slot.specs == 1 then
                ns.Icon.Spec(b.role, slot.specs[1])
            else
                ns.Icon.Role(b.role, ns.ROLE_GROUP[slot.role])
            end
            b.tipTitle = ns.T("tipToSlot", slotLabel(slot))
            if m.work then
                b.tip = slot.specs and specNames(slot.specs) or nil
                b:Enable()
                b.role:SetDesaturated(false)
                b.onClick = function()
                    S.Assign(i, m.name)
                    if after then after() end
                end
            else
                b.tip = ns.T("tipReserve", Lay.Work(tpl.size))
                b:Disable()
                b.role:SetDesaturated(true)
                b.onClick = nil
            end
            b:Show()
        else
            b:Hide()
        end
    end
end
local function isRS(tpl)
    if (tpl.size or 25) <= 10 then return false end
    return (tpl.base or tpl.key or ""):find("^rs") ~= nil
end
local function membersByGroup()
    local out = {}
    for g = 1, GROUPS do out[g] = {} end
    if not inRaid() then return out end
    for _, m in ipairs(ns.Session.Roster()) do
        if m.index and out[m.sub] then
            local list = out[m.sub]
            list[#list + 1] = m
        end
    end
    return out
end
local function takenSlots(tpl)
    local S = ns.Session
    local out = {}
    for i = 1, #tpl.slots do
        local name = S.SlotPlayer(i)
        out[i] = name and S.Member(name) and true or false
    end
    return out
end
local function sortList()
    local S = ns.Session
    local grp = Lay.Groups(S.Template())
    local out = {}
    for _, m in ipairs(S.Roster()) do
        if m.index then
            local i = S.SlotOf(m.name)
            out[#out + 1] = { key = m.index, sub = m.sub, want = i and grp[i] or nil }
        end
    end
    return out
end
local function sortOne()
    local op = Lay.Sort(sortList())[1]
    if not op then return false end
    if ns.Test.Active() then
        if op.kind == "move" then ns.Test.Move(op.a, op.g) else ns.Test.Swap(op.a, op.b) end
    elseif op.kind == "move" then
        SetRaidSubgroup(op.a, op.g)
    else
        SwapRaidSubgroup(op.a, op.b)
    end
    return true
end
local function sortStep()
    if sortWait or GetTime() > sortUntil then return end
    if InCombatLockdown() or not officer() then
        sortUntil = 0
        return
    end
    if ns.Test.Active() then
        for _ = 1, 40 do
            if not sortOne() then break end
        end
        sortUntil = 0
    elseif sortOne() then
        sortWait = true
    else
        sortUntil = 0
    end
end
local sortEvents = ns.NewFrame("Frame")
ns.Listen(sortEvents, "RAID_ROSTER_UPDATE")
sortEvents:SetScript("OnEvent", function()
    if not sortWait then return end
    sortWait = false
    ns.Session.Invalidate()
    sortStep()
end)
local function closeMenu()
    if menuCatcher then menuCatcher:Hide() end
end
local function confirmKick(name)
    StaticPopupDialogs.RAIDLEAD_KICK = StaticPopupDialogs.RAIDLEAD_KICK or {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self) UninviteUnit(self.data) end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    local d = StaticPopup_Show("RAIDLEAD_KICK", ns.T("kickConfirm", name), nil, name)
    if d then d.data = name end
end
StaticPopupDialogs.RAIDLEAD_NOTE = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 250,
    OnAccept = function(self)
        ns.Session.SetNote(self.data, _G[self:GetName() .. "EditBox"]:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        ns.Session.SetNote(p.data, self:GetText())
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
local function editNote(name)
    local d = StaticPopup_Show("RAIDLEAD_NOTE", ns.T("notePrompt", name), nil, name)
    if not d then return end
    d.data = name
    local e = _G[d:GetName() .. "EditBox"]
    if e then
        e:SetText(ns.Session.Player(name).note or "")
        e:HighlightText()
    end
end
local ACTIONS = {
    { key = "mt", label = "flagMT", on = function(m) return m.role == "MAINTANK" end,
      run = function(m, on)
          if on then ClearPartyAssignment("MAINTANK", m.unit) else SetPartyAssignment("MAINTANK", m.unit) end
      end },
    { key = "ma", label = "flagMA", on = function(m) return m.role == "MAINASSIST" end,
      run = function(m, on)
          if on then ClearPartyAssignment("MAINASSIST", m.unit) else SetPartyAssignment("MAINASSIST", m.unit) end
      end },
    { key = "assist", label = "flagAssist", lead = true, on = function(m) return m.rank == 1 end,
      run = function(m, on)
          if on then DemoteAssistant(m.unit) else PromoteToAssistant(m.unit) end
      end },
    { key = "ml", label = "flagML", lead = true, on = function(m) return m.ml end,
      run = function(m) SetLootMethod("master", m.name) end },
    { key = "kick", label = "menuKick", danger = true, on = function() return false end,
      run = function(m) confirmKick(m.name) end },
}
local function iconButton(parent, size)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.frame = ns.Fill(b, "BACKGROUND")
    ns.PaintToken(b.frame, "text.title", 0.45)
    b.frame:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    b.frame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    b:SetScript("OnLeave", ns.TipHide)
    return b
end
local function onSpecClick(self)
    local m = menu.member
    closeMenu()
    if not m or not self.spec then return end
    if self.kind == "off" then
        ns.Session.SetOff(m.name, self.spec, "hand")
    else
        ns.Session.SetSpec(m.name, self.spec, "hand")
    end
end
local function onMarkClick(self)
    local m, cur = menu.member, menu.mark
    closeMenu()
    if not m or not officer() then return end
    local i = self.idx
    if m.fake then ns.Test.Mark(m.name, cur == i and 0 or i) else SetRaidTarget(m.unit, cur == i and 0 or i) end
end
local function menuLabel(text, y)
    local fs = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, y)
    fs:SetText(text or "")
    ns.PaintText(fs, "text.secondary")
    return fs
end
local function buildMenu()
    local win = ns.window:Pane("raid"):GetParent()
    menuCatcher = ns.NewFrame("Frame", nil, win)
    menuCatcher:SetAllPoints(win)
    menuCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    menuCatcher:EnableMouse(true)
    menuCatcher:SetScript("OnMouseDown", closeMenu)
    menuCatcher:Hide()
    menu = ns.NewFrame("Frame", nil, menuCatcher)
    menu:SetFrameLevel(menuCatcher:GetFrameLevel() + 10)
    ns.Skin(menu, "list")
    menu:SetWidth(222)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -9)
    menu.slotFs = menuLabel(nil, -34)
    menu.slotFs:SetWidth(120)
    menu.slotFs:SetJustifyH("LEFT")
    menu.unBtn = ns.MakeKitButton(menu)
    menu.unBtn:SetSize(64, 20)
    menu.unBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10, -30)
    menu.unBtn:SetText(ns.T("menuUnassign"))
    menu.unBtn.onClick = function()
        local m = menu.member
        closeMenu()
        if m then ns.Session.Unassign(m.name) end
    end
    menuSlots = {}
    for i = 1, 3 do
        local b = ns.MakeKitButton(menu)
        b:SetSize(24, 20)
        b.role = b:CreateTexture(nil, "OVERLAY")
        b.role:SetSize(14, 14)
        b.role:SetPoint("CENTER", b, "CENTER", 0, 0)
        b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10 - (i - 1) * 26, -30)
        menuSlots[i] = b
    end
    menuLabel(ns.T("menuSpecRow"), -60)
    menuLabel(ns.T("menuOffRow"), -84)
    menuSpecs, menuOffs = {}, {}
    for k = 1, SPECS do
        local s = iconButton(menu, 20)
        s:SetPoint("TOPLEFT", menu, "TOPLEFT", 80 + (k - 1) * 25, -56)
        s.kind = "spec"
        s:SetScript("OnClick", onSpecClick)
        menuSpecs[k] = s
        local o = iconButton(menu, 20)
        o:SetPoint("TOPLEFT", menu, "TOPLEFT", 80 + (k - 1) * 25, -80)
        o.kind = "off"
        o:SetScript("OnClick", onSpecClick)
        menuOffs[k] = o
    end
    menu.offNone = ns.MakeKitButton(menu)
    menu.offNone:SetSize(20, 20)
    menu.offNone:SetPoint("TOPLEFT", menu, "TOPLEFT", 80 + SPECS * 25, -80)
    menu.offNone:SetText("x")
    menu.offNone.tipTitle = ns.T("menuOffNone")
    menu.offNone.onClick = function()
        local m = menu.member
        closeMenu()
        if m then ns.Session.SetOff(m.name, nil, "hand") end
    end
    menuMarks = {}
    for i = 1, MARKS do
        local b = iconButton(menu, 20)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 10 + (i - 1) * 25, -108)
        ns.Icon.Mark(b.icon, i)
        b.idx = i
        b.tipTitle = ns.T("mark" .. i)
        b:SetScript("OnClick", onMarkClick)
        menuMarks[i] = b
    end
    menuBtns = {}
    for k, a in ipairs(ACTIONS) do
        local b = ns.MakeKitButton(menu)
        b:SetSize(202, 20)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, a.key == "kick" and -251 or -136 - (k - 1) * 23)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b, "LEFT", 22, 0)
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetSize(14, 14)
        b.check:SetPoint("LEFT", b, "LEFT", 5, 0)
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.action = a
        menuBtns[k] = b
    end
    menu.noteBtn = ns.MakeKitButton(menu)
    menu.noteBtn:SetSize(98, 20)
    menu.noteBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -228)
    menu.noteBtn:SetText(ns.T("menuNote"))
    menu.noteBtn.onClick = function()
        local m = menu.member
        closeMenu()
        if m then editNote(m.name) end
    end
    menu.diceBtn = ns.MakeKitButton(menu)
    menu.diceBtn:SetSize(100, 20)
    menu.diceBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 112, -228)
    menu.diceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    menu.diceBtn.tip = ns.T("tipDiceHow")
    menu.diceBtn.onClick = function(self, btn)
        local m = menu.member
        if not m then return end
        if btn == "RightButton" then
            ns.Session.AddOffRoll(m.name, -1)
        else
            ns.Session.AddOffRoll(m.name, 1, ns.T("noteOffRoll", date("%d.%m %H:%M")))
        end
        self:SetText(ns.T("menuDice", ns.Session.Player(m.name).offRolls or 0))
    end
    menu:SetHeight(279)
    menu.slots, menu.specs, menu.offs, menu.marks, menu.btns = menuSlots, menuSpecs, menuOffs, menuMarks, menuBtns
end
local function fillSpecRow(btns, m, cur)
    local list
    for _, cls in ipairs(ns.CLASSES) do
        if cls.token == m.class then list = cls.specs end
    end
    list = list or {}
    for k, b in ipairs(btns) do
        local sp = list[k]
        if sp then
            ns.Icon.Spec(b.icon, sp.key)
            b.spec = sp.key
            b.tipTitle = ns.T("specFull_" .. sp.key)
            if cur == sp.key then b.frame:Show() else b.frame:Hide() end
            b:Show()
        else
            b.spec = nil
            b:Hide()
        end
    end
end
local function openMenu(cell, m)
    if not menu then buildMenu() end
    local S = ns.Session
    local p = S.Player(m.name)
    menu.member = m
    menu.title:SetText(m.name)
    ns.ClassText(menu.title, m.class)
    local i = S.SlotOf(m.name)
    local slot = i and S.Template().slots[i]
    if slot then
        menu.slotFs:SetText(ns.T("menuSlot", slotLabel(slot)))
        menu.unBtn:Show()
        for _, b in ipairs(menuSlots) do b:Hide() end
    else
        menu.slotFs:SetText(ns.T("tipNoSlot"))
        menu.unBtn:Hide()
        fillSlotButtons(menuSlots, m, closeMenu)
    end
    fillSpecRow(menuSpecs, m, p.spec)
    fillSpecRow(menuOffs, m, p.off)
    if p.off then menu.offNone:Enable() else menu.offNone:Disable() end
    menu.noteBtn.tipTitle = ns.T("tipNote")
    menu.noteBtn.tip = p.note or ns.T("tipNoteEmpty")
    menu.diceBtn:SetText(ns.T("menuDice", p.offRolls or 0))
    local canOfficer, canLead = officer(), IsRaidLeader()
    local cur = m.mark or (m.unit and GetRaidTargetIndex(m.unit))
    menu.mark = cur
    for k, b in ipairs(menuMarks) do
        if cur == k then b.frame:Show() else b.frame:Hide() end
        b.icon:SetDesaturated(not canOfficer)
    end
    for _, b in ipairs(menuBtns) do
        local a = b.action
        local on = a.on(m)
        b:SetText(ns.T(a.label))
        b.tint = a.danger and ns.DANGER or nil
        if on then b.check:Show() else b.check:Hide() end
        local allowed = a.lead and canLead or (not a.lead and canOfficer)
        if allowed then
            b:Enable()
            b.tip = nil
        else
            b:Disable()
            b.tip = ns.T(a.lead and "tipNeedLeader" or "tipNeedOfficer")
        end
        b.onClick = function()
            closeMenu()
            if m.fake then ns.Test.Act(a.key, m.name, on) else a.run(m, on) end
        end
    end
    menu:ClearAllPoints()
    local g = cell.group or 1
    local col, row = (g - 1) % COLS, math.floor((g - 1) / COLS)
    local v = row == 0 and "TOP" or "BOTTOM"
    if col == COLS - 1 then
        menu:SetPoint(v .. "RIGHT", cell, v .. "LEFT", -2, 0)
    else
        menu:SetPoint(v .. "LEFT", cell, v .. "RIGHT", 2, 0)
    end
    menuCatcher:Show()
end
local function openSeat(c)
    local S = ns.Session
    local i = c.slotIndex
    if not i then return end
    local slot = S.Template().slots[i]
    local opts = {}
    for _, m in ipairs(S.Unassigned()) do
        if S.SlotFits(slot, m) then opts[#opts + 1] = { key = m.name, label = coloredName(m) } end
    end
    if #opts == 0 then return end
    ns.PopupList(c, opts, function(name) S.Assign(i, name) end)
end
local function makeGhost()
    ghost = ns.NewFrame("Frame", nil, UIParent)
    ghost:SetSize(130, 20)
    ghost:SetFrameStrata("TOOLTIP")
    ns.Skin(ghost, "list")
    ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ns.PaintTitle(ghost.text)
    ghost.text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s + 70, y / s - 12)
    end)
    ghost:Hide()
end
local function drop()
    if not dragFrom then return end
    local from = dragFrom
    dragFrom = nil
    ghost:Hide()
    if not officer() then return end
    for _, b in ipairs(boxes) do
        if b:IsShown() and MouseIsOver(b) then
            for _, c in ipairs(b.cells) do
                if c.member and MouseIsOver(c) then
                    if c.member.index ~= from.index then
                        if from.fake then ns.Test.Swap(from.index, c.member.index) else SwapRaidSubgroup(from.index, c.member.index) end
                    end
                    return
                end
            end
            if b.group ~= from.sub and (b.count or 0) < 5 then
                if from.fake then ns.Test.Move(from.index, b.group) else SetRaidSubgroup(from.index, b.group) end
            end
            return
        end
    end
end
local function newCell(box, k)
    local c = ns.NewFrame("Button", nil, box)
    c.isRaidCell = true
    c.box = box
    c.group = box.group
    c:SetHeight(CELL_H - 2)
    c:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -(HEAD_H + 2 + (k - 1) * CELL_H))
    c:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -(HEAD_H + 2 + (k - 1) * CELL_H))
    c.bg = ns.Fill(c, "BACKGROUND")
    ns.PaintToken(c.bg, "card.sticker")
    c.bg:SetAllPoints()
    c.warn = ns.Fill(c, "BORDER")
    ns.PaintToken(c.warn, "sem.notReady", 0.16)
    c.warn:SetAllPoints()
    c.spec = c:CreateTexture(nil, "ARTWORK")
    c.spec:SetSize(16, 16)
    c.spec:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -2)
    c.off = c:CreateTexture(nil, "OVERLAY")
    c.off:SetSize(9, 9)
    c.off:SetPoint("BOTTOMRIGHT", c.spec, "BOTTOMRIGHT", 3, -3)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.name:SetPoint("LEFT", c.spec, "RIGHT", 4, 0)
    c.name:SetPoint("RIGHT", c, "RIGHT", -34, 0)
    c.name:SetJustifyH("LEFT")
    c.ver = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.ver:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -18, 2)
    c.ver:SetJustifyH("RIGHT")
    c.note = c:CreateTexture(nil, "OVERLAY")
    c.note:SetSize(11, 11)
    c.note:SetTexture(ns.NOTE_TEX)
    c.dice = c:CreateTexture(nil, "OVERLAY")
    c.dice:SetSize(11, 11)
    c.dice:SetTexture(ns.DICE_TEX)
    c.gs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.gs:SetJustifyH("LEFT")
    ns.PaintText(c.gs, "text.secondary")
    c.flags = {}
    for i = 1, 3 do
        local t = c:CreateTexture(nil, "OVERLAY")
        t:SetSize(12, 12)
        t:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2 - (i - 1) * 12, -3)
        c.flags[i] = t
    end
    c.mark = c:CreateTexture(nil, "OVERLAY")
    c.mark:SetSize(14, 14)
    c.mark:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
    c.dead = ns.Fill(c, "OVERLAY")
    ns.PaintToken(c.dead, "sem.death", 0.28)
    c.dead:SetAllPoints()
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnDragStart", function(self)
        if not self.member or not officer() then return end
        dragFrom = self.member
        ghost.text:SetText(self.member.name)
        ghost:Show()
    end)
    c:SetScript("OnDragStop", drop)
    c:SetScript("OnReceiveDrag", drop)
    c:SetScript("OnClick", function(self)
        if self.member then openMenu(self, self.member) else openSeat(self) end
    end)
    c:SetScript("OnEnter", cardEnter)
    c:SetScript("OnLeave", cardLeave)
    ns.ReadyUI.Build(c)
    return c
end
local function clearCell(c, tok)
    c.member, c.slotIndex = nil, nil
    ns.PaintToken(c.bg, tok)
    c.bg:SetAlpha(0.5)
    c:SetAlpha(1)
    c.spec:Hide()
    c.off:Hide()
    c.warn:Hide()
    c.name:SetText("")
    c.gs:SetText("")
    c.ver:SetText("")
    c.note:Hide()
    c.dice:Hide()
    for _, t in ipairs(c.flags) do t:Hide() end
    c.mark:Hide()
    c.dead:Hide()
    ns.ReadyUI.ClearCell(c)
    c.tipTitle, c.tip, c.tipDim, c.lines = nil, nil, nil, nil
end
local function fillGhost(c, i, tpl, tok)
    clearCell(c, tok)
    if not i then return end
    local S = ns.Session
    local slot = tpl.slots[i]
    c.slotIndex = i
    c.spec:Show()
    c.spec:SetDesaturated(true)
    c.spec:SetAlpha(0.6)
    if slot.specs and #slot.specs == 1 then
        ns.Icon.Spec(c.spec, slot.specs[1])
    else
        ns.Icon.Role(c.spec, ns.ROLE_GROUP[slot.role])
    end
    c.name:SetText(slotLabel(slot))
    ns.Tone(c.name, "text.muted")
    local names = {}
    for k, key in ipairs(slot.specs or {}) do
        if k > 4 then break end
        names[#names + 1] = ns.T("spec_" .. key)
    end
    c.gs:SetText(#names > 0 and table.concat(names, "/") or ns.T("tipAnySpec"))
    c.tipTitle = ns.T("tipNeed", slotLabel(slot))
    c.tip = slot.specs and specNames(slot.specs) or ns.T("tipAnySpec")
    local fits = 0
    for _, m in ipairs(S.Unassigned()) do
        if S.SlotFits(slot, m) then fits = fits + 1 end
    end
    c.tipDim = fits > 0 and ns.T("tipSockClick", fits) or nil
end
local function fillCell(c, m, tok)
    clearCell(c, tok)
    local S = ns.Session
    local p = S.Player(m.name)
    c.member = m
    c.bg:SetAlpha(1)
    c:SetAlpha((m.away and m.online) and 0.55 or 1)
    c.spec:Show()
    c.spec:SetAlpha(1)
    ns.Icon.Who(c.spec, p.spec, m.class)
    c.spec:SetDesaturated(not m.online)
    if p.off then
        ns.Icon.Spec(c.off, p.off)
        c.off:SetDesaturated(not m.online)
        c.off:Show()
    end
    local slotI = S.SlotOf(m.name)
    local noSlot = m.work and not slotI
    c.name:SetText(m.name .. (noSlot and (" " .. ns.Hex("sem.notReady") .. "!|r") or ""))
    if m.online then ns.ClassText(c.name, m.class) else ns.Tone(c.name, "sem.offline") end
    if noSlot then c.warn:Show() end
    local exp = ns.Bober.ExpText(m.name, m.unit)
    c.gs:SetText(gsText(m.name) .. (exp and ("  " .. exp) or ""))
    local ver = addonVer(m.name)
    c.ver:SetText(ver and shortVer(ver) or ns.T("verNone"))
    ns.PaintText(c.ver, ver and "text.secondary" or "text.muted")
    local x = -18 - (c.ver:GetStringWidth() or 0) - 3
    local rolls = p.offRolls or 0
    if rolls > 0 then
        c.dice:ClearAllPoints()
        c.dice:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", x, 3)
        c.dice:Show()
        x = x - ICON_STEP
    end
    if p.note then
        c.note:ClearAllPoints()
        c.note:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", x, 3)
        c.note:Show()
        x = x - ICON_STEP
    end
    c.gs:ClearAllPoints()
    c.gs:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 23, 2)
    c.gs:SetPoint("RIGHT", c, "RIGHT", x, 0)
    local flags = {}
    if m.rank == 2 then flags[#flags + 1] = ns.FLAG_TEX.leader end
    if m.rank == 1 then flags[#flags + 1] = ns.FLAG_TEX.assist end
    if m.role == "MAINTANK" then flags[#flags + 1] = ns.FLAG_TEX.mt end
    if m.role == "MAINASSIST" then flags[#flags + 1] = ns.FLAG_TEX.ma end
    if m.ml then flags[#flags + 1] = ns.FLAG_TEX.ml end
    for i, t in ipairs(c.flags) do
        if flags[i] then
            t:SetTexture(flags[i])
            t:Show()
        end
    end
    local mark = m.mark or (m.unit and GetRaidTargetIndex(m.unit))
    if mark then
        ns.Icon.Mark(c.mark, mark)
        c.mark:Show()
    end
    if m.dead then c.dead:Show() end
    c.lines = cardLines(m, p, slotI and S.Template().slots[slotI], ver)
    ns.ReadyUI.FillCell(c, m)
end
local function newBox(g)
    local b = ns.NewFrame("Frame", nil, pane)
    b.isRaidBox = true
    b.group = g
    ns.Skin(b, "card")
    b:EnableMouse(true)
    b:SetScript("OnReceiveDrag", drop)
    b:SetScript("OnMouseUp", drop)
    b.head = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.head:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    b.sum = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sum:SetPoint("TOPRIGHT", b, "TOPRIGHT", -7, -5)
    b.sum:SetJustifyH("RIGHT")
    ns.PaintText(b.sum, "text.secondary")
    b.cells = {}
    for k = 1, 5 do b.cells[k] = newCell(b, k) end
    return b
end
local function buildStrip()
    strip = ns.MakePanel(pane)
    strip:SetHeight(STRIP_H)
    strip:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.text:SetPoint("LEFT", strip, "LEFT", 10, 0)
    ns.PaintText(strip.text, "text.secondary")
    strip.show = ns.MakeKitButton(strip)
    strip.show:SetSize(90, 18)
    strip.show:SetPoint("RIGHT", strip, "RIGHT", -4, 0)
    strip.show:SetText(ns.T("btnShowLists"))
    strip.show.tipTitle = ns.T("tipSideOpen")
    strip.show.onClick = function()
        ns.Store.DB().sideOpen = true
        ns.Session.Changed()
    end
    strip:Hide()
end
local function buildBar()
    bar = ns.MakePanel(pane)
    bar:SetHeight(BAR_H)
    bar:EnableMouse(true)
    bar.tipAnchor = "ANCHOR_TOP"
    bar:SetScript("OnEnter", function(self) if self.tip then ns.TipShow(self) end end)
    bar:SetScript("OnLeave", ns.TipHide)
    sortBtn = ns.MakeKitButton(bar)
    sortBtn:SetSize(SORT_W, 20)
    sortBtn:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    sortBtn:SetText(ns.T("btnSortGroups"))
    sortBtn.tipTitle = ns.T("btnSortGroups")
    sortBtn.onClick = function()
        sortUntil, sortWait = GetTime() + SORT_TIME, false
        sortStep()
    end
    barFs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barFs:SetJustifyH("LEFT")
    ns.PaintText(barFs, "text.primary")
end
local function fillStrip(raid)
    local S = ns.Session
    local open = ns.Side and ns.Side.Open()
    local un = (raid and not open) and #S.Unassigned() or 0
    local wait = (not open) and #ns.Whisper.Waiting() or 0
    if un + wait == 0 then
        strip:Hide()
        return 0
    end
    strip:SetWidth(ns.window.PANE_W)
    strip.text:SetText(ns.T("stripLists", un, wait))
    strip:Show()
    return STRIP_H + STRIP_GAP
end
local function fillSort(raid)
    if not raid then
        sortBtn:Hide()
        return
    end
    sortBtn:Show()
    local left = #Lay.Sort(sortList())
    sortBtn.tip = ns.T("tipSortGroups")
    if not officer() then
        sortBtn:Disable()
        sortBtn.tip = ns.T("tipNeedOfficer")
    elseif InCombatLockdown() then
        sortBtn:Disable()
        sortBtn.tip = ns.T("tipInCombat")
    elseif left == 0 then
        sortBtn:Disable()
        sortBtn.tip = ns.T("tipSortNone")
    else
        sortBtn:Enable()
    end
end
local function fillBar(raid)
    fillSort(raid)
    barFs:ClearAllPoints()
    barFs:SetPoint("RIGHT", sortBtn, "LEFT", -8, 0)
    barFs:SetPoint("LEFT", bar, "LEFT", 10, 0)
    bar.tipTitle, bar.tip = nil, nil
    local r = raid and ns.Bober.Ready() and ns.Bober.Raid(ns.Session.Roster())
    if not raid then
        barFs:SetText(ns.Hex("text.muted") .. ns.T("raidSoon") .. "|r")
        bar.predict = false
        return
    end
    if not r then
        barFs:SetText("")
        bar.predict = false
        return
    end
    bar.tipTitle = ns.T("bbRaidTitle")
    bar.tip = ns.Bober.PickText() .. "\n" .. ns.T("bbRaidHow")
    local text
    if r.have == 0 then
        text = ns.Hex("text.muted") .. ns.T("bbRaidNone") .. "|r"
    elseif r.pct then
        text = ns.T("bbRaidSum", ns.Bober.Short(r.sum), r.pct, r.have, r.of)
    else
        text = ns.T("bbRaidSumRaw", ns.Bober.Short(r.sum), r.have, r.of)
    end
    barFs:SetText(ns.T("bbRaidTitle") .. ": " .. text)
    bar.predict = true
end
local function placeBoxes(top)
    if not built then return end
    top = top or 0
    local W = ns.window.PANE_W
    local boxW = math.floor((W - (COLS - 1) * GAP) / COLS)
    local boxH = HEAD_H + 5 * CELL_H + 6
    for g, b in ipairs(boxes) do
        local col, row = (g - 1) % COLS, math.floor((g - 1) / COLS)
        b:SetSize(boxW, boxH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pane, "TOPLEFT", col * (boxW + GAP), -(top + row * (boxH + GAP)))
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(top + 2 * boxH + 2 * GAP))
    bar:SetWidth(W)
    local infoTop = top + 2 * boxH + 2 * GAP + BAR_H + INFO_GAP
    ns.RaidInfo.Place(pane, infoTop, W, ns.window.PANE_H - infoTop)
end
local function fillBox(b, list, gl, tpl, work, rs)
    local g = b.group
    b.count = #list
    local reserve = g > work
    local side = rs and (g <= 2 and "rsDark" or (g <= 5 and "rsLight")) or nil
    local head = reserve and ns.T("grpBoxReserve", g) or ns.T("grpBox", g)
    local hidden = math.min(#gl, math.max(0, #list + #gl - Lay.SEATS))
    if hidden > 0 then head = head .. "  " .. ns.Hex("text.muted") .. ns.T("grpHidden", hidden) .. "|r" end
    b.head:SetText(head)
    b.side = side
    local border = side and ns.C["card." .. side .. "Edge"] or (reserve and ns.C["card.borderDim"]) or nil
    ns.Backdrop(b, ns.Theme.card, border)
    if reserve then
        ns.PaintText(b.head, "text.muted")
        b:SetAlpha(0.8)
    else
        ns.PaintTitle(b.head)
        b:SetAlpha(1)
    end
    local tok = side and ("card." .. side) or "card.sticker"
    for k, c in ipairs(b.cells) do
        if list[k] then fillCell(c, list[k], tok) else fillGhost(c, gl[k - #list], tpl, tok) end
    end
    local sum = ns.Bober.Ready() and #list > 0 and ns.Bober.Sum(list)
    b.sum:SetText(sum and sum.have > 0 and ns.Bober.Short(sum.sum) or "")
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    local S = ns.Session
    local tpl = S.Template()
    local raid = inRaid()
    local top = fillStrip(raid)
    placeBoxes(top + ns.ReadyUI.FillStrip(pane, top))
    local groups = membersByGroup()
    local ghosts = Lay.Ghosts(tpl, takenSlots(tpl))
    local work, rs = Lay.Work(tpl.size), isRS(tpl)
    for g, b in ipairs(boxes) do
        fillBox(b, groups[g], ghosts[g] or {}, tpl, work, rs)
    end
    fillBar(raid)
    ns.RaidInfo.Refresh()
end
local function onSize()
    if built then refresh() end
end
local function build()
    pane = ns.window:Pane("raid")
    for g = 1, GROUPS do
        boxes[g] = newBox(g)
    end
    buildStrip()
    ns.ReadyUI.BuildStrip(pane)
    buildBar()
    makeGhost()
    built = true
    placeBoxes(0)
    pane:SetScript("OnShow", refresh)
    refresh()
end
ns.Session.OnChange(refresh)
ns.ReadyBuffs.OnChange(refresh)
if root.Version and root.Version.OnChange then root.Version.OnChange(refresh) end
ns.window:OnSize(onSize)
local function predictText()
    return bar and bar.predict and barFs:GetText() or nil
end
ns.RaidPane = {
    Build = build,
    Refresh = refresh,
    CloseMenu = closeMenu,
    PredictText = predictText,
    GsText = gsText,
    SpecTip = specTip,
    ColoredName = coloredName,
    FillSlotButtons = fillSlotButtons,
    SortLeft = function() return #Lay.Sort(sortList()) end,
    Menu = function() return menu end,
    BarText = function() return barFs and barFs:GetText() or "" end,
    Bar = function() return bar end,
}
ns.window:OnBuild(build)
