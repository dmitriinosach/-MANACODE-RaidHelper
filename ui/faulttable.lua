local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local UNDO = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
local DONE = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local TOGGLE = 14
local MARKS = 10
local FT = {}
ns.FaultTable = FT
local open = {}
local fresh
local freshGen = 0
function FT.IsOpen(name)
    return open[name] == true
end
function FT.SetOpen(name, on)
    open[name] = on and true or nil
    if on then
        fresh = name
        freshGen = freshGen + 1
    end
    ns.GPList.Changed()
end
function FT.Rows(model, filter)
    local rows = {}
    local onlyOpen = filter == "open"
    for i = 1, #((model and model.items) or {}) do
        local item = model.items[i]
        local evs = {}
        for e = 1, #item.events do
            local ev = item.events[e]
            if not onlyOpen or not ns.Ledger.Done(ev.key) then evs[#evs + 1] = ev end
        end
        if #evs > 0 or (not onlyOpen and #item.hand > 0) then
            rows[#rows + 1] = { item = item }
            if open[item.name] then
                for e = 1, #evs do rows[#rows + 1] = { item = item, ev = evs[e] } end
                if not onlyOpen then
                    for h = 1, #item.hand do rows[#rows + 1] = { item = item, hand = item.hand[h] } end
                end
            end
        end
    end
    return rows
end
local function Cols(L, width)
    local c = { hot = {} }
    local x = width - 2
    for i = 3, 1, -1 do
        x = x - L.hotw
        c.hot[i] = x
    end
    x = x - L.proofw
    c.proof = x
    x = x - L.mainw
    c.main = x
    x = x - L.whenw
    c.when = x
    c.left = L.checkw + (L.small and 2 or 6)
    c.nameEnd = c.when - 4
    return c
end
local function At(fs, parent, x, w)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", parent, "LEFT", x, 0)
    if w then fs:SetWidth(max(1, w)) end
end
local function Head(f, c)
    local L, h = f.L, f.head
    local unit = ns.Ledger.Unit()
    h:SetHeight(L.headh)
    At(h.who, h, c.left, c.nameEnd - c.left)
    h.who:SetText(ns.T("ft.col.who"))
    At(h.when, h, c.when, L.whenw)
    h.when:SetText(L.whenw > 0 and ns.T("ft.col.when") or "")
    At(h.main, h, c.main, L.mainw)
    h.main:SetText(L.small and unit or format(ns.T("ft.col.rule"), unit))
    At(h.proof, h, c.proof, L.proofw)
    h.proof:SetText(L.small and "" or ns.T("ft.col.proof"))
    for i = 1, 3 do
        At(h.hot[i], h, c.hot[i], L.hotw)
        h.hot[i]:SetText(L.hotw > 0 and ns.T("ft.col." .. ns.Ledger.HOT[i]) or "")
    end
end
local function ListOf(r)
    return r.list
end
local function MainClick(self)
    local r = self.row
    local list, d = ListOf(r), r.data
    if not (d and list.fight) then return end
    if d.ev then
        if d.ev.grade == "yellow" and not d.ev.bumped then
            ns.GPList.Charge(list.fight, d.item.name, d.ev)
        else
            ns.GPList.Issue(list.fight, { { name = d.item.name, events = { d.ev } } })
        end
    else
        ns.GPList.Issue(list.fight, { d.item })
    end
end
local function UndoClick(self)
    local d = self.row.data
    local key = d and ((d.ev and d.ev.key) or (d.hand and d.hand.key))
    if key then ns.GPList.Undo(key) end
end
local function HotClick(self)
    local r = self.row
    local list, d = ListOf(r), r.data
    if d and list.fight then ns.GPList.Hot(list.fight, d.item.name, ns.Ledger.HOT[self.slot], d.ev) end
end
local function ToggleClick(self)
    local d = self.row.data
    if d then FT.SetOpen(d.item.name, not open[d.item.name]) end
end
local function CheckToggle(box, on)
    local r = box.row
    local list, d = ListOf(r), r.data
    if not (d and d.ev) then return end
    list.sel[d.ev.key] = on or nil
    if list.onSel then list.onSel() end
end
local function RowUp(self, button)
    local list, d = ListOf(self), self.data
    if not (d and list.fight) then return end
    if button == "RightButton" then
        ns.GPList.ManualMenu(list.fight, d.item.name)
    elseif d.ev then
        if ns.ReplayLink and d.ev.t then ns.ReplayLink.Shift(list.fight, d.ev.t) end
    elseif not d.hand then
        FT.SetOpen(d.item.name, not open[d.item.name])
    end
end
local function RowEnter(self)
    local list, d = ListOf(self), self.data
    if not (d and list.fight) then return end
    local lines
    if d.ev then
        lines = ns.GPList.HitLines(list.fight, d.ev.hit)
    elseif not d.hand then
        lines = ns.BadgeTips.GPRow(d.item, ns.Penalties.Reason)
        if ns.ReplayLink then ns.ReplayLink.Tag(lines, list.fight, ns.GPList.FirstAt(d.item.events)) end
    end
    if lines then ns.Tip.Show(self, lines) end
end
local function RowLeave(self)
    ns.Tip.Hide()
end
local function Wheel(self, delta)
    local list = self.list or self
    if list.onWheel then list.onWheel(delta) end
end
local function MarkClick(mark)
    local list = mark:GetParent().list
    if mark.hit and list.fight then ns.GPList.EventMenu(list.fight, mark.hit, mark.player) end
end
local function Row(f, k)
    local r = f.rows[k]
    if r then return r end
    local L = f.L
    r = CreateFrame("Frame", nil, f)
    r:SetHeight(L.rowh)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseUp", RowUp)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
    r:SetScript("OnMouseWheel", Wheel)
    r.list = f
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if L.checkw > 0 then
        r.check = ns.Kit.Check(r, f.prefix .. "Check" .. k)
        r.check:SetWidth(20)
        r.check:SetHeight(20)
        r.check.row = r
        r.check.onToggle = function(on) CheckToggle(r.check, on) end
    end
    r.toggle = CreateFrame("Button", f.prefix .. "Toggle" .. k, r)
    r.toggle:SetWidth(TOGGLE)
    r.toggle:SetHeight(TOGGLE)
    r.toggle.tex = r.toggle:CreateTexture(nil, "ARTWORK")
    r.toggle.tex:SetAllPoints()
    r.toggle.row = r
    r.toggle:SetScript("OnClick", ToggleClick)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(L.icon)
    r.icon:SetHeight(L.icon)
    r.name = r:CreateFontString(nil, "OVERLAY", L.small and "GameFontHighlightSmall" or "GameFontHighlight")
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.marks = {}
    r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.note:SetJustifyH("LEFT")
    r.note:SetWordWrap(false)
    r.when = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.when:SetJustifyH("RIGHT")
    r.main = ns.MakeButton(r, f.prefix .. k, "main")
    r.main:SetHeight(L.rowh - 4)
    r.main.row = r
    r.main.onClick = MainClick
    r.done = r:CreateTexture(nil, "ARTWORK")
    r.done:SetTexture(DONE)
    r.done:SetWidth(12)
    r.done:SetHeight(12)
    r.doneText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.doneText:SetJustifyH("LEFT")
    ns.Kit.Text(r.doneText, "text.good")
    r.undo = ns.Kit.IconButton(r, UNDO, 12, f.prefix .. "Undo" .. k)
    r.undo.row = r
    r.undo.tipTitle = false
    r.undo.onClick = UndoClick
    if ns.ProofView then r.proof = ns.ProofView.Button(r, L.small and 13 or 16) end
    r.hot = {}
    for i = 1, L.hotw > 0 and 3 or 0 do
        local b = ns.MakeButton(r, f.prefix .. "Hot" .. i .. "_" .. k, "hot")
        b:SetHeight(L.rowh - 4)
        b:SetWidth(L.hotw - 6)
        b.row, b.slot = r, i
        b.onClick = HotClick
        r.hot[i] = b
    end
    f.rows[k] = r
    return r
end
local function Blank(r)
    if r.check then r.check:Hide() end
    r.toggle:Hide()
    r.icon:Hide()
    for i = 1, #r.marks do r.marks[i]:Hide() end
    r.note:Hide()
    r.when:SetText("")
    r.main:Hide()
    r.done:Hide()
    r.doneText:Hide()
    r.undo:Hide()
    if r.proof then r.proof:Hide() end
    for i = 1, #r.hot do r.hot[i]:Hide() end
end
local function Main(r, c, L, kind, n, tip)
    r.main:ClearAllPoints()
    r.main:SetPoint("RIGHT", r, "LEFT", c.main + L.mainw - 4, 0)
    r.main:SetWidth(max(36, min(L.mainw - 6, 18 + 8 * #tostring(n))))
    ns.Kit.ButtonKind(r.main, kind)
    r.main.text:SetText(tostring(n))
    r.main.tip = tip
    r.main:Show()
end
local function Done(r, c, L, n, tip, undo)
    local right = c.main + L.mainw - 4
    if undo then
        r.undo:ClearAllPoints()
        r.undo:SetPoint("RIGHT", r, "LEFT", right, 0)
        r.undo.tip = ns.T("ft.tip.undo")
        r.undo:Show()
        right = right - 20
    end
    r.doneText:ClearAllPoints()
    r.doneText:SetPoint("RIGHT", r, "LEFT", right, 0)
    r.doneText:SetText(n and tostring(n) or "")
    r.doneText:Show()
    r.done:ClearAllPoints()
    r.done:SetPoint("RIGHT", r.doneText, "LEFT", -1, 0)
    r.done:Show()
    r.doneTip = tip
end
local function Hots(r, c, L, ev)
    local unit = ns.Ledger.Unit()
    for i = 1, #r.hot do
        local b, kind = r.hot[i], ns.Ledger.HOT[i]
        local n = ns.Ledger.HotSum(kind)
        b:ClearAllPoints()
        b:SetPoint("LEFT", r, "LEFT", c.hot[i] + 3, 0)
        b.text:SetText(tostring(n))
        b.tip = format(ns.T(ev and "ft.tip.hot.fault" or "ft.tip.hot"), ns.Ledger.HotLabel(kind), n, unit)
        b:Show()
    end
end
local function Proof(r, c, L, ask)
    if not r.proof then return end
    r.proof:ClearAllPoints()
    r.proof:SetPoint("CENTER", r, "LEFT", c.proof + L.proofw / 2, 0)
    r.proof.ask = ask
    r.proof:Show()
end
local function Marks(r, item, fight, x, stop)
    local L = ListOf(r).L
    local icons = max(0, min(MARKS, floor((stop - x) / L.iconw)))
    local guards = item.guards or {}
    local nh = #item.hits
    local pair = #guards > 0 and "death" or nil
    for i = 1, max(icons, #r.marks) do
        local hit = i <= icons and item.hits[i] or nil
        local guard = not hit and i <= icons and guards[i - nh] or nil
        local b = r.marks[i]
        if (hit or guard) and not b then
            b = ns.Badges.Mark(r, L.icon)
            b:Layout(L.iconw - 2)
            r.marks[i] = b
        end
        if b then
            b:ClearAllPoints()
            b:SetPoint("LEFT", r, "LEFT", x + (i - 1) * L.iconw, 0)
        end
        if hit then
            local info = hit.events[1] and hit.events[1].info
            local count = info and info.missing and tostring(info.have or 0) or tostring(#hit.events)
            if i == icons and nh > icons then count = "+" .. (nh - icons + 1) end
            local kind = hit.rule.kind
            b:SetModel({
                icon = ns.GPList.Icon(hit.icon),
                count = count,
                verdict = ns.Penalties.Grade(hit),
                pair = (kind == "death" or kind == "anydeath") and pair or nil,
                lines = ns.GPList.HitLines(fight, hit),
                onClick = MarkClick,
                fight = fight,
                at = ns.GPList.FirstAt(hit.events),
                proof = { fight = fight, name = item.name, hits = { hit } },
            })
            b.hit, b.player = hit, item.name
            b:Show()
        elseif guard then
            b:SetModel({
                icon = ns.GPList.Icon(guard.id),
                count = tostring(guard.n),
                verdict = "yellow",
                pair = pair,
                lines = ns.BadgeTips.Ready(guard, fight),
                fight = fight,
                at = guard.times[1],
            })
            b.hit, b.player = nil, item.name
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    return x + min(icons, nh + #guards) * L.iconw
end
local function FillPlayer(r, d, fight, c)
    local L, item = ListOf(r).L, d.item
    local unit = ns.Ledger.Unit()
    r.toggle:ClearAllPoints()
    r.toggle:SetPoint("LEFT", r, "LEFT", c.left, 0)
    r.toggle.tex:SetTexture(open[item.name] and MINUS or PLUS)
    r.toggle:Show()
    local x = c.left + TOGGLE + 4
    At(r.name, r, x, min(L.namew, c.nameEnd - x))
    r.name:SetText(item.name)
    r.name:SetTextColor(ns.GPList.ClassRGB(item.class))
    local after = Marks(r, item, fight, x + L.namew + 4, c.nameEnd)
    local note, yellow = ns.GPList.Note(item)
    local room = c.nameEnd - after - 4
    if note and room >= L.iconw then
        At(r.note, r, after + 4, room)
        r.note:SetText(note)
        if yellow then ns.Kit.Text(r.note, "badge.yellow") else ns.Kit.Text(r.note, "text.muted") end
        r.note:Show()
    end
    if item.pending > 0 then
        Main(r, c, L, "main", item.pending, format(ns.T("ft.tip.all"), item.pending, unit))
    elseif item.given > 0 then
        Done(r, c, L, item.given, format(ns.T("ft.tip.given"), item.given), false)
    end
    if #item.hits > 0 then Proof(r, c, L, { fight = fight, name = item.name, hits = item.hits }) end
    Hots(r, c, L, nil)
end
local function FillFault(r, d, fight, c)
    local list = ListOf(r)
    local L, ev = list.L, d.ev
    local unit = ns.Ledger.Unit()
    local done = ns.Ledger.Done(ev.key)
    local x = c.left + TOGGLE + 4
    if r.check then
        r.check:ClearAllPoints()
        r.check:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.check:SetChecked(not done and list.sel[ev.key] and true or false)
        if done then r.check:Disable() else r.check:Enable() end
        r.check:Show()
    end
    r.icon:ClearAllPoints()
    r.icon:SetPoint("LEFT", r, "LEFT", x, 0)
    r.icon:SetTexture(ns.GPList.Icon(ev.hit.icon))
    r.icon:Show()
    x = x + L.icon + 4
    At(r.name, r, x, c.nameEnd - x)
    local text = ev.reason
    if ev.grade == "yellow" then text = text .. " " .. ns.Kit.Hex("badge.yellow") .. ns.T("ft.maybe") .. "|r" end
    if ev.wipe then text = text .. " " .. ns.Kit.Hex("text.note") .. ns.T("ft.wipe") .. "|r" end
    r.name:SetText(text)
    ns.Kit.Text(r.name, done and "text.muted" or "text.primary")
    r.when:SetText(ev.t and ns.GPList.Clock(ev.t - fight.from) or ns.T("ft.whole"))
    if done then
        local tip = done.n and format(ns.T("ft.tip.done"), done.n, ns.Ledger.Unit(done.s)) or ns.T("led.menu.old")
        Done(r, c, L, done.n, tip, ns.Ledger.CanUndo(ev.key))
    elseif ev.grade == "yellow" and not ev.bumped then
        local n = ns.Penalties.Amount(ev.hit.rule, ns.Ledger.Key()) or 0
        if n > 0 then Main(r, c, L, "quiet", n, format(ns.T("ft.tip.charge"), n, unit)) end
    elseif ev.n > 0 then
        Main(r, c, L, "main", ev.n, format(ns.T("ft.tip.give"), ev.n, unit))
    end
    Proof(r, c, L, { fight = fight, name = d.item.name,
        hits = { { rule = ev.hit.rule, events = { ev.src }, icon = ev.hit.icon, shed = ev.hit.shed } } })
    if not done then Hots(r, c, L, ev) end
end
local function FillHand(r, d, c)
    local L, h = ListOf(r).L, d.hand
    local x = c.left + TOGGLE + 4 + L.icon + 4
    At(r.name, r, x, c.nameEnd - x)
    r.name:SetText(format(ns.T("ft.hand"), ns.Ledger.HotLabel(h.kind or "slack")))
    ns.Kit.Text(r.name, "text.muted")
    local n = h.done.n
    Done(r, c, L, n, format(ns.T("ft.tip.done"), n or 0, ns.Ledger.Unit(h.done.s)), ns.Ledger.CanUndo(h.key))
end
local function Paint(r, k)
    local c = ns.Kit.C[k % 2 == 0 and "row.bgHover" or "row.bg"]
    r.bg:SetTexture(c[1], c[2], c[3], (c[4] or 1) * 0.5)
end
local function Draw(self, fight, model, width, offset, slots)
    local L = self.L
    self.fight, self.model = fight, model
    local rows = FT.Rows(model, self.filter)
    self.flat = rows
    self.total = #rows
    local c = Cols(L, width)
    Head(self, c)
    offset = offset or 0
    local unseen = self.seenGen ~= freshGen and fresh
    self.seenGen = freshGen
    local shown = max(0, min(#rows - offset, slots or #rows))
    for k = 1, max(shown, #rows == 0 and 1 or 0) do
        local r = Row(self, k)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(L.headh + (k - 1) * L.rowh))
        r:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(L.headh + (k - 1) * L.rowh))
        Blank(r)
        Paint(r, k)
        local d = rows[k + offset]
        r.data = d
        if not d then
            At(r.name, r, c.left, width - c.left - 8)
            r.name:SetText(ns.T(self.filter == "open" and "ft.none.open" or (L.small and "gp.none.short" or "sum.gp.none")))
            ns.Kit.Text(r.name, "text.muted")
        elseif d.ev then
            FillFault(r, d, fight, c)
        elseif d.hand then
            FillHand(r, d, c)
        else
            FillPlayer(r, d, fight, c)
        end
        r:Show()
        if unseen and d and (d.ev or d.hand) and d.item.name == unseen then ns.Kit.FadeIn(r) end
    end
    for k = max(shown, #rows == 0 and 1 or 0) + 1, #self.rows do
        self.rows[k].data = nil
        self.rows[k]:Hide()
    end
    local h = L.headh + max(1, shown) * L.rowh
    self:SetWidth(width)
    self:SetHeight(h)
    return h
end
function FT.New(parent, prefix, layout)
    local f = CreateFrame("Frame", nil, parent)
    f.rows = {}
    f.prefix = prefix
    f.L = layout
    f.filter = "all"
    f.sel = {}
    f.total = 0
    f.Draw = Draw
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)
    f.head = CreateFrame("Frame", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    local h = f.head
    local font = "GameFontNormalSmall"
    h.who = h:CreateFontString(nil, "OVERLAY", font)
    h.who:SetJustifyH("LEFT")
    h.when = h:CreateFontString(nil, "OVERLAY", font)
    h.when:SetJustifyH("RIGHT")
    h.main = h:CreateFontString(nil, "OVERLAY", font)
    h.main:SetJustifyH("RIGHT")
    h.proof = h:CreateFontString(nil, "OVERLAY", font)
    h.proof:SetJustifyH("CENTER")
    h.hot = {}
    for i = 1, 3 do
        h.hot[i] = h:CreateFontString(nil, "OVERLAY", font)
        h.hot[i]:SetJustifyH("CENTER")
        ns.Kit.Text(h.hot[i], "badge.detail")
    end
    for _, fs in ipairs({ h.who, h.when, h.main, h.proof }) do ns.Kit.Text(fs, "text.secondary") end
    return f
end
