local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local GROUPS = 8
local COLS = 4
local GAP = 8
local HEAD_H = 20
local CELL_H = 34
local MARKS = 8
local PREDICT_H = 28
local PICK_W = 190
local pane, emptyFs
local predict, pickSel, predictFs
local fillPredict
local boxes = {}
local ghost, dragFrom
local menu, menuCatcher, menuMarks, menuBtns
local built = false
local function officer()
    return ns.Test.Active() or IsRaidLeader() or IsRaidOfficer()
end
local function inRaid()
    local raid = ns.Compat.GroupSize()
    return raid > 0 or ns.Test.Active()
end
local function cellOf(f)
    while f do
        if f.isRaidCell or f.isRaidBox then return f end
        f = f:GetParent()
    end
end
local function addonVer(name)
    local V = root.Version
    return V and V.Of and V.Of(name) or nil
end
local function shortVer(v)
    local s = v:gsub("%-(%a)%a*%.?", "%1")
    return s
end
local function membersByGroup()
    local out = {}
    for g = 1, GROUPS do out[g] = {} end
    for _, m in ipairs(ns.Session.Roster()) do
        if m.index and out[m.sub] then
            local list = out[m.sub]
            list[#list + 1] = m
        end
    end
    return out
end
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
    menu:SetWidth(200)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -9)
    menuMarks = {}
    for i = 1, MARKS do
        local b = ns.NewFrame("Button", nil, menu)
        b:SetSize(22, 22)
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 10 + col * 26, -30 - row * 26)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        ns.Icon.Mark(b.icon, i)
        b.frame = ns.Fill(b, "BACKGROUND")
        ns.PaintToken(b.frame, "text.title", 0.45)
        b.frame:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        b.frame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.tipTitle = ns.T("mark" .. i)
        b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
        b:SetScript("OnLeave", ns.TipHide)
        menuMarks[i] = b
    end
    menuBtns = {}
    for k, a in ipairs(ACTIONS) do
        local b = ns.MakeKitButton(menu)
        b:SetSize(180, 20)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -86 - (k - 1) * 23)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b, "LEFT", 22, 0)
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetSize(14, 14)
        b.check:SetPoint("LEFT", b, "LEFT", 5, 0)
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.action = a
        menuBtns[k] = b
    end
    menu:SetHeight(86 + #ACTIONS * 23 + 6)
end
local function openMenu(cell, m)
    if not menu then buildMenu() end
    menu.title:SetText(m.name)
    ns.ClassText(menu.title, m.class)
    local canOfficer, canLead = officer(), IsRaidLeader()
    local cur = m.mark or (m.unit and GetRaidTargetIndex(m.unit))
    for i, b in ipairs(menuMarks) do
        if cur == i then b.frame:Show() else b.frame:Hide() end
        b.icon:SetDesaturated(not canOfficer)
        b:SetScript("OnClick", function()
            if not officer() then return end
            if m.fake then ns.Test.Mark(m.name, cur == i and 0 or i) else SetRaidTarget(m.unit, cur == i and 0 or i) end
            closeMenu()
        end)
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
    c.spec = c:CreateTexture(nil, "ARTWORK")
    c.spec:SetSize(16, 16)
    c.spec:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -2)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.name:SetPoint("LEFT", c.spec, "RIGHT", 4, 0)
    c.name:SetPoint("RIGHT", c, "RIGHT", -34, 0)
    c.name:SetJustifyH("LEFT")
    c.ver = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.ver:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -18, 2)
    c.ver:SetJustifyH("RIGHT")
    c.gs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.gs:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 23, 2)
    c.gs:SetPoint("RIGHT", c.ver, "LEFT", -3, 0)
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
        if self.member then openMenu(self, self.member) end
    end)
    c:SetScript("OnEnter", function(self) if self.member then ns.TipShow(self) end end)
    c:SetScript("OnLeave", ns.TipHide)
    return c
end
local function fillCell(c, m)
    c.member = m
    if not m then
        c.spec:Hide()
        c.name:SetText("")
        c.gs:SetText("")
        c.ver:SetText("")
        for _, t in ipairs(c.flags) do t:Hide() end
        c.mark:Hide()
        c.dead:Hide()
        c.bg:SetAlpha(0.5)
        c:SetAlpha(1)
        return
    end
    local p = ns.Session.Player(m.name)
    c.bg:SetAlpha(1)
    c.spec:Show()
    ns.Icon.Who(c.spec, p.spec, m.class)
    c.spec:SetDesaturated(not m.online)
    c.name:SetText(m.name)
    if m.online then ns.ClassText(c.name, m.class) else ns.Tone(c.name, "sem.offline") end
    local d = GS_Data and GS_Data[GetRealmName()]
    local r = d and d.Players and d.Players[m.name]
    local gs = r and r.GearScore
    local il = (r and r.Average) or p.ilvl
    local exp = ns.Bober.ExpText(m.name, m.unit)
    c.gs:SetText((gs or "-") .. "  " .. (il and math.floor(il) or "") .. (exp and ("  " .. exp) or ""))
    local ver = addonVer(m.name)
    c.ver:SetText(ver and shortVer(ver) or ns.T("verNone"))
    ns.PaintText(c.ver, ver and "text.secondary" or "text.muted")
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
        else
            t:Hide()
        end
    end
    local mark = m.mark or (m.unit and GetRaidTargetIndex(m.unit))
    if mark then
        ns.Icon.Mark(c.mark, mark)
        c.mark:Show()
    else
        c.mark:Hide()
    end
    if m.dead then c.dead:Show() else c.dead:Hide() end
    c.tipTitle = m.name
    local lines = {}
    if p.spec then lines[#lines + 1] = ns.T("specFull_" .. p.spec) end
    local slot = ns.Session.SlotOf(m.name)
    if slot then lines[#lines + 1] = ns.T("tipInSlot", ns.T("slot_" .. ns.Session.Template().slots[slot].role)) end
    lines[#lines + 1] = ver and ns.T("tipAddonVer", ver) or ns.T("tipAddonNone")
    c.tip = ns.Bober.Tip(#lines > 0 and table.concat(lines, "\n") or nil, m.name, m.unit)
    c.tipDim = ns.T("tipRaidCell")
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
local function buildPredict()
    predict = ns.MakePanel(pane)
    predict:SetHeight(PREDICT_H)
    pickSel = ns.MakeSelect(predict)
    pickSel:SetSize(PICK_W, 20)
    pickSel:SetPoint("LEFT", predict, "LEFT", 6, 0)
    pickSel.tipTitle = ns.T("bbPickTip")
    pickSel.tip = ns.T("bbPickHow")
    pickSel.onPick = function(key) ns.Bober.SetPick(key) end
    predictFs = predict:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    predictFs:SetPoint("LEFT", pickSel, "RIGHT", 10, 0)
    predictFs:SetPoint("RIGHT", predict, "RIGHT", -8, 0)
    predictFs:SetJustifyH("LEFT")
    ns.PaintText(predictFs, "text.primary")
    predict:Hide()
end
function fillPredict()
    if not predict then return end
    local r = ns.Bober.Ready() and ns.Bober.Raid(ns.Session.Roster())
    if not r then
        predict:Hide()
        return
    end
    local _, _, key = ns.Bober.Pick()
    pickSel:SetOptions(ns.Bober.Options(), key)
    local text
    if r.have == 0 then
        text = ns.Hex("text.muted") .. ns.T("bbRaidNone") .. "|r"
    elseif r.pct then
        text = ns.T("bbRaidSum", ns.Bober.Short(r.sum), r.pct, r.have, r.of)
    else
        text = ns.T("bbRaidSumRaw", ns.Bober.Short(r.sum), r.have, r.of)
    end
    predictFs:SetText(ns.T("bbRaidTitle") .. ": " .. text)
    predict:Show()
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    if not inRaid() then
        for _, b in ipairs(boxes) do b:Hide() end
        if predict then predict:Hide() end
        emptyFs:Show()
        return
    end
    emptyFs:Hide()
    local work = math.floor(ns.Session.Template().size / 5)
    local groups = membersByGroup()
    for g, b in ipairs(boxes) do
        b:Show()
        local list = groups[g]
        b.count = #list
        local reserve = g > work
        b.head:SetText(reserve and ns.T("grpBoxReserve", g) or ns.T("grpBox", g))
        ns.Backdrop(b, ns.Theme.card, reserve and ns.C["card.borderDim"] or nil)
        if reserve then
            ns.PaintText(b.head, "text.muted")
            b:SetAlpha(0.8)
        else
            ns.PaintTitle(b.head)
            b:SetAlpha(1)
        end
        for k, c in ipairs(b.cells) do fillCell(c, list[k]) end
        local sum = ns.Bober.Ready() and #list > 0 and ns.Bober.Sum(list)
        b.sum:SetText(sum and sum.have > 0 and ns.Bober.Short(sum.sum) or "")
    end
    fillPredict()
end
local function placeBoxes()
    if not built then return end
    local W = ns.window.PANE_W
    local boxW = math.floor((W - (COLS - 1) * GAP) / COLS)
    local boxH = HEAD_H + 5 * CELL_H + 6
    for g, b in ipairs(boxes) do
        local col, row = (g - 1) % COLS, math.floor((g - 1) / COLS)
        b:SetSize(boxW, boxH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pane, "TOPLEFT", col * (boxW + GAP), -row * (boxH + GAP))
    end
    if predict then
        predict:ClearAllPoints()
        predict:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(2 * boxH + 2 * GAP))
        predict:SetWidth(W)
    end
end
local function build()
    pane = ns.window:Pane("raid")
    for g = 1, GROUPS do
        boxes[g] = newBox(g)
    end
    emptyFs = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyFs:SetPoint("TOP", pane, "TOP", 0, -40)
    emptyFs:SetText(ns.T("raidNotIn"))
    ns.PaintText(emptyFs, "text.secondary")
    buildPredict()
    makeGhost()
    built = true
    placeBoxes()
    pane:SetScript("OnShow", refresh)
    refresh()
end
ns.Session.OnChange(refresh)
if root.Version and root.Version.OnChange then root.Version.OnChange(refresh) end
ns.window:OnSize(placeBoxes)
local function predictText()
    return predict and predict:IsShown() and predictFs:GetText() or nil
end
ns.RaidPane = { Build = build, Refresh = refresh, CloseMenu = closeMenu, PredictText = predictText }
ns.window:OnBuild(build)
