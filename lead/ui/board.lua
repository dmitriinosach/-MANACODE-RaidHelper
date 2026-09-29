local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local Lay = ns.Layout
local WHEEL = 40
local STRIP_H = 24
local STRIP_GAP = 6
local NAME_L = 41
local FLAG_STEP = 15
local CHIP_LABEL_W = 140
local MAX_SPECS = 4
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
ns.Board = {}
local pane, scroll, child, bar, strip
local cardPool, chipPool, bandPool, partPool
local view = { total = 0, visible = 1 }
local built = false
local function slotLabel(slot)
    return slot.cap or ns.T("slot_" .. slot.role)
end
local function specNames(list)
    local out = {}
    for _, k in ipairs(list or {}) do out[#out + 1] = ns.T("spec_" .. k) end
    return table.concat(out, ", ")
end
local function gsOf(name)
    local d = GS_Data and GS_Data[GetRealmName()]
    local r = d and d.Players and d.Players[name]
    local own = ns.Session.Player(name).ilvl
    if not r then return nil, own end
    return r.GearScore, r.Average or own
end
local function gsText(name)
    local gs, il = gsOf(name)
    local dash = ns.Hex("text.muted") .. "-|r"
    if not gs and not il then return dash end
    return (gs or dash) .. " " .. ns.Hex("text.secondary") .. (il and math.floor(il) or "") .. "|r"
end
local function hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end
local function coloredName(m)
    return "|cff" .. hex(ns.ClassColor(m.class)) .. m.name .. "|r"
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
local function cardSkin()
    return ns.Theme.card
end
local CHIP = {}
local function chipSkin()
    local c = ns.Theme.card
    CHIP.backdrop, CHIP.bg, CHIP.border = c.backdrop, c.sticker, c.border
    return CHIP
end
local function newBand()
    local b = ns.NewFrame("Frame", nil, child)
    b:SetHeight(Lay.BAND_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.rule = ns.Fill(b, "ARTWORK")
    ns.PaintToken(b.rule, "text.secondary", 0.45)
    b.rule:SetHeight(1)
    b.rule:SetPoint("LEFT", b.text, "RIGHT", 8, 0)
    b.rule:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    return b
end
local function newPart()
    local b = ns.NewFrame("Frame", nil, child)
    b:SetHeight(Lay.PART_H)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
    ns.PaintText(b.text, "text.secondary")
    b.rule = ns.Fill(b, "ARTWORK")
    ns.PaintToken(b.rule, "text.secondary", 0.25)
    b.rule:SetHeight(1)
    b.rule:SetPoint("LEFT", b.text, "RIGHT", 6, 0)
    b.rule:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    return b
end
local function iconButton(parent, size, tex)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(tex)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    b:SetScript("OnLeave", ns.TipHide)
    return b
end
local function newCard()
    local c = ns.NewFrame("Button", nil, child)
    c:SetHeight(Lay.CARD_H)
    ns.Backdrop(c, cardSkin())
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.stripe = ns.Fill(c, "ARTWORK")
    c.stripe:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -3)
    c.stripe:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 3, 3)
    c.stripe:SetWidth(3)
    c.shade = c:CreateTexture(nil, "BORDER")
    c.shade:SetTexture(WHITE8)
    c.shade:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -3)
    c.shade:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", -3, -24)
    c.spec = c:CreateTexture(nil, "ARTWORK")
    c.spec:SetSize(18, 18)
    c.spec:SetPoint("TOPLEFT", c, "TOPLEFT", 9, -4)
    c.off = c:CreateTexture(nil, "ARTWORK")
    c.off:SetSize(11, 11)
    c.off:SetPoint("BOTTOMLEFT", c.spec, "BOTTOMRIGHT", 1, 0)
    c.off:SetAlpha(0.7)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("LEFT", c.spec, "RIGHT", 14, 0)
    c.name:SetHeight(14)
    c.name:SetJustifyH("LEFT")
    c.flags = {}
    for i = 1, 5 do
        local t = c:CreateTexture(nil, "OVERLAY")
        t:SetSize(13, 13)
        t:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6 - (i - 1) * FLAG_STEP, -6)
        c.flags[i] = t
    end
    c.sep = ns.Fill(c, "ARTWORK")
    ns.PaintToken(c.sep, "text.title", 0.18)
    c.sep:SetHeight(1)
    c.sep:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -25)
    c.sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -25)
    c.grp = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.grp:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -32)
    ns.PaintText(c.grp, "text.primary")
    c.cap = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.cap:SetPoint("LEFT", c.grp, "RIGHT", 6, 0)
    ns.PaintText(c.cap, "text.muted")
    c.cap:SetHeight(12)
    c.cap:SetJustifyH("LEFT")
    c.dice = iconButton(c, 14, ns.DICE_TEX)
    c.dice:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -30)
    c.dice:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.dice.count = c.dice:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    c.dice.count:SetPoint("BOTTOMRIGHT", c.dice, "BOTTOMRIGHT", 2, -2)
    c.note = iconButton(c, 14, ns.NOTE_TEX)
    c.note:SetPoint("RIGHT", c.dice, "LEFT", -4, 0)
    c.gs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.gs:SetPoint("RIGHT", c.note, "LEFT", -6, 0)
    c.gs:SetJustifyH("RIGHT")
    ns.PaintText(c.gs, "text.primary")
    c.dead = ns.Fill(c, "OVERLAY")
    ns.PaintToken(c.dead, "sem.death", 0.28)
    c.dead:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -3)
    c.dead:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -3, 3)
    c:SetScript("OnEnter", function(self)
        local s = cardSkin()
        ns.Backdrop(self, s, s.borderHover)
        ns.TipShow(self)
    end)
    c:SetScript("OnLeave", function(self)
        ns.Backdrop(self, cardSkin())
        ns.TipHide()
    end)
    return c
end
local function newChip()
    local s = ns.NewFrame("Button", nil, child)
    s:SetHeight(Lay.CHIP_H)
    ns.Backdrop(s, chipSkin())
    s.role = s:CreateTexture(nil, "ARTWORK")
    s.role:SetSize(16, 16)
    s.role:SetPoint("LEFT", s, "LEFT", 5, 0)
    s.role:SetAlpha(0.45)
    s.sps = {}
    for i = 1, MAX_SPECS do
        local t = s:CreateTexture(nil, "ARTWORK")
        t:SetSize(13, 13)
        t:SetPoint("LEFT", s, "LEFT", 24 + (i - 1) * 14, 0)
        t:SetAlpha(0.6)
        s.sps[i] = t
    end
    s.count = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    s.count:SetPoint("RIGHT", s, "RIGHT", -6, 0)
    ns.PaintTitle(s.count)
    s.label = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    s.label:SetHeight(12)
    s.label:SetJustifyH("LEFT")
    ns.PaintText(s.label, "text.muted")
    s:SetScript("OnEnter", function(self)
        local k = chipSkin()
        ns.Backdrop(self, k, ns.Theme.card.borderHover)
        ns.TipShow(self)
    end)
    s:SetScript("OnLeave", function(self)
        ns.Backdrop(self, chipSkin())
        ns.TipHide()
    end)
    return s
end
local function cardMenu(c, m)
    local S = ns.Session
    local p = S.Player(m.name)
    local opts = { { key = "unassign", label = ns.T("menuUnassign") } }
    for _, cls in ipairs(ns.CLASSES) do
        if cls.token == m.class then
            for _, sp in ipairs(cls.specs) do
                opts[#opts + 1] = { key = "spec:" .. sp.key, label = ns.T("menuSpec", ns.T("spec_" .. sp.key)),
                    color = p.spec == sp.key and ns.EDGE or nil }
            end
            for _, sp in ipairs(cls.specs) do
                opts[#opts + 1] = { key = "off:" .. sp.key, label = ns.T("menuOff", ns.T("spec_" .. sp.key)),
                    color = p.off == sp.key and ns.EDGE or nil }
            end
        end
    end
    if p.off then opts[#opts + 1] = { key = "off:", label = ns.T("menuOffNone") } end
    ns.PopupList(c, opts, function(key)
        if key == "unassign" then S.Unassign(m.name) return end
        local kind, spec = key:match("^(%a+):(.*)$")
        if kind == "spec" then S.SetSpec(m.name, spec, "hand") end
        if kind == "off" then S.SetOff(m.name, spec ~= "" and spec or nil, "hand") end
    end)
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
local function fillFlags(c, m)
    local flags = {}
    if m.rank == 2 then flags[#flags + 1] = ns.FLAG_TEX.leader end
    if m.rank == 1 then flags[#flags + 1] = ns.FLAG_TEX.assist end
    if m.role == "MAINTANK" then flags[#flags + 1] = ns.FLAG_TEX.mt end
    if m.role == "MAINASSIST" then flags[#flags + 1] = ns.FLAG_TEX.ma end
    if m.ml then flags[#flags + 1] = ns.FLAG_TEX.ml end
    local mark = m.mark or (m.unit and GetRaidTargetIndex(m.unit))
    for k, t in ipairs(c.flags) do
        if k == #flags + 1 and mark then
            ns.Icon.Mark(t, mark)
            t:Show()
        elseif flags[k] then
            t:SetTexture(flags[k])
            t:SetTexCoord(0, 1, 0, 1)
            t:Show()
        else
            t:Hide()
        end
    end
    return #flags + (mark and 1 or 0)
end
local function fillCard(c, it, slot, m)
    local S = ns.Session
    local p = S.Player(m.name)
    local r, g, b = ns.ClassColor(m.class)
    local w = it.w
    c:SetWidth(w)
    ns.Backdrop(c, cardSkin())
    c.stripe:SetVertexColor(r, g, b, 1)
    ns.Gradient(c.shade, "HORIZONTAL", r, g, b, 0.22, r, g, b, 0)
    ns.Icon.Who(c.spec, p.spec, m.class)
    if p.off then
        ns.Icon.Spec(c.off, p.off)
        c.off:Show()
    else
        c.off:Hide()
    end
    c.name:SetText(m.name)
    c.name:SetTextColor(r, g, b)
    local nf = fillFlags(c, m)
    c.name:SetWidth(math.max(40, w - NAME_L - 8 - nf * FLAG_STEP))
    c.grp:SetText(m.sub and (m.work and m.sub or (ns.Hex("text.muted") .. m.sub .. "|r")) or "")
    c.cap:SetText(it.label or ns.T("slot_" .. slot.role))
    local parse = ns.Bober.ParseText(m.name, m.unit)
    c.gs:SetText(gsText(m.name) .. (parse and ("  " .. parse) or ""))
    local room = w - 66 - c.grp:GetStringWidth() - c.gs:GetStringWidth()
    c.cap:SetWidth(math.max(20, math.min(w - 150, room)))
    local rolls = p.offRolls or 0
    c.dice.count:SetText(rolls > 0 and rolls or "")
    c.dice.icon:SetDesaturated(rolls == 0)
    c.dice.icon:SetAlpha(rolls > 0 and 1 or 0.45)
    c.dice.tipTitle = ns.T("tipDice", rolls)
    c.dice.tip = ns.T("tipDiceHow")
    c.dice:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            S.AddOffRoll(m.name, -1)
        else
            S.AddOffRoll(m.name, 1, ns.T("noteOffRoll", date("%d.%m %H:%M")))
        end
    end)
    c.note.icon:SetDesaturated(not p.note)
    c.note.icon:SetAlpha(p.note and 1 or 0.45)
    c.note.tipTitle = ns.T("tipNote")
    c.note.tip = p.note or ns.T("tipNoteEmpty")
    c.note:SetScript("OnClick", function()
        local d = StaticPopup_Show("RAIDLEAD_NOTE", ns.T("notePrompt", m.name), nil, m.name)
        if d then
            d.data = m.name
            local e = _G[d:GetName() .. "EditBox"]
            if e then
                e:SetText(S.Player(m.name).note or "")
                e:HighlightText()
            end
        end
    end)
    local off = not m.online
    c.spec:SetDesaturated(off)
    c.off:SetDesaturated(off)
    if off then ns.Tone(c.name, "sem.offline") end
    if m.dead then c.dead:Show() else c.dead:Hide() end
    c:SetAlpha((m.away and not off) and 0.55 or 1)
    specTip(c, m)
    c.tip = ns.Bober.Tip(c.tip, m.name, m.unit)
    c.tipDim = ns.T("tipCardClick")
    c:SetScript("OnClick", function(self) cardMenu(self, m) end)
end
local function fillChip(s, it, slot, free)
    local w = it.w
    s:SetWidth(w)
    ns.Backdrop(s, chipSkin())
    ns.Icon.Role(s.role, ns.ROLE_GROUP[it.role])
    local sps = it.specs or {}
    local n = math.min(#sps, MAX_SPECS)
    for k, t in ipairs(s.sps) do
        if k <= n then
            ns.Icon.Spec(t, sps[k])
            t:Show()
        else
            t:Hide()
        end
    end
    s.count:SetText(it.n > 1 and ns.T("chipMany", it.n) or "")
    local text
    if n == 0 then
        text = it.label or ns.T("slot_" .. it.role)
    elseif w >= CHIP_LABEL_W then
        local names = {}
        for k = 1, n do names[#names + 1] = ns.T("spec_" .. sps[k]) end
        text = table.concat(names, "/")
    end
    s.label:ClearAllPoints()
    s.label:SetPoint("LEFT", s, "LEFT", 24 + n * 14 + 2, 0)
    s.label:SetWidth(math.max(1, w - (24 + n * 14 + 2) - (it.n > 1 and 26 or 6)))
    s.label:SetText(text or "")
    local label = it.label or ns.T("slot_" .. it.role)
    s.tipTitle = ns.T("tipNeed", label)
    local lines = { #sps > 0 and specNames(sps) or ns.T("tipAnySpec") }
    if it.n > 1 then lines[#lines + 1] = ns.T("tipChipMany", it.n) end
    s.tip = table.concat(lines, "\n")
    local i = it.slots[1]
    local fits = {}
    for _, m in ipairs(free) do
        if ns.Session.SlotFits(slot, m) then fits[#fits + 1] = m end
    end
    if #fits > 0 then
        s.tipDim = ns.T("tipSockClick", #fits)
        s:SetScript("OnClick", function(self)
            local opts = {}
            for _, m in ipairs(fits) do
                opts[#opts + 1] = { key = m.name, label = coloredName(m) }
            end
            ns.PopupList(self, opts, function(name) ns.Session.Assign(i, name) end)
        end)
    else
        s.tipDim = nil
        s:SetScript("OnClick", nil)
    end
end
local function fillBand(b, it)
    b:SetWidth(it.w)
    ns.Icon.Role(b.icon, ns.ROLE_GROUP[it.key])
    b.text:SetText(ns.T("grpTitle_" .. it.key) .. "  " .. it.have .. "/" .. it.total)
    ns.PaintText(b.text, it.have >= it.total and "sem.full" or "text.secondary")
end
function ns.Board.FillSlotButtons(btns, m)
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
                b.onClick = function() S.Assign(i, m.name) end
            else
                b.tip = ns.T("tipReserve", math.floor(tpl.size / 5))
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
local function setScroll(v)
    local maxScroll = math.max(0, view.total - view.visible)
    if v > maxScroll then v = maxScroll end
    if v < 0 then v = 0 end
    scroll:SetVerticalScroll(v)
    bar:SetState(v, view.visible, view.total)
end
local function fillStrip()
    local S = ns.Session
    local open = ns.Side and ns.Side.Open()
    local un = (S.Active() and not open) and #S.Unassigned() or 0
    local wait = (S.Active() and not open) and #ns.Whisper.Waiting() or 0
    if un + wait == 0 then
        strip:Hide()
        return 0
    end
    strip:SetWidth(ns.window.PANE_W)
    strip.text:SetText(ns.T("stripLists", un, wait))
    strip:Show()
    return STRIP_H + STRIP_GAP
end
local function seatsOf(tpl)
    local S = ns.Session
    local seats = {}
    for i = 1, #tpl.slots do
        local name = S.SlotPlayer(i)
        local m = name and S.Member(name)
        if m then
            seats[i] = { class = m.class, spec = S.Player(name).spec, taken = m.work and true or false }
        end
    end
    return seats
end
local function layout()
    local S = ns.Session
    local tpl = S.Template()
    local top = fillStrip()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    local H = ns.window.PANE_H - top
    local plan = Lay.Plan(tpl.slots, seatsOf(tpl), ns.window.PANE_W, H)
    local free = S.Unassigned()
    bandPool:Reset()
    partPool:Reset()
    cardPool:Reset()
    chipPool:Reset()
    for _, it in ipairs(plan.items) do
        local f
        if it.kind == "band" then
            f = bandPool:Acquire()
            fillBand(f, it)
        elseif it.kind == "part" then
            f = partPool:Acquire()
            f:SetWidth(it.w)
            f.text:SetText(it.text)
        elseif it.kind == "card" then
            local m = S.Member(S.SlotPlayer(it.i))
            f = cardPool:Acquire()
            fillCard(f, it, tpl.slots[it.i], m)
        else
            f = chipPool:Acquire()
            fillChip(f, it, tpl.slots[it.slots[1]], free)
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", child, "TOPLEFT", it.x, -it.y)
    end
    bandPool:HideExtras()
    partPool:HideExtras()
    cardPool:HideExtras()
    chipPool:HideExtras()
    child:SetWidth(math.max(plan.W, 1))
    child:SetHeight(math.max(plan.h, 1))
    scroll:UpdateScrollChildRect()
    view.total, view.visible = plan.h, H
    if plan.scroll then bar:Show() else bar:Hide() end
    setScroll(scroll:GetVerticalScroll())
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    layout()
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
local function build()
    pane = ns.window:Pane("board")
    scroll = ns.NewFrame("ScrollFrame", nil, pane)
    scroll:SetAllPoints(pane)
    child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(ns.window.PANE_W, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        setScroll(self:GetVerticalScroll() - delta * WHEEL)
    end)
    bar = ns.Kit.ScrollBar(pane, 100)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    bar:SetFrameLevel(scroll:GetFrameLevel() + 10)
    bar.onScroll = setScroll
    bar:Hide()
    buildStrip()
    bandPool = ns.NewPool(newBand)
    partPool = ns.NewPool(newPart)
    cardPool = ns.NewPool(newCard)
    chipPool = ns.NewPool(newChip)
    built = true
    pane:SetScript("OnShow", refresh)
    refresh()
end
ns.Session.OnChange(refresh)
ns.window:OnSize(refresh)
ns.Board.Build = build
ns.Board.Refresh = refresh
ns.Board.GsText = gsText
ns.Board.ColoredName = coloredName
ns.Board.SpecTip = specTip
ns.window:OnBuild(build)
