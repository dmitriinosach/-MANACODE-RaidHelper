local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local UNDO = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
local REASON = 80
local DONE = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local FT = {}
ns.FaultTable = FT
local function Str(sized, parent, base)
    if sized then return ns.Kit.Str(parent, base) end
    return parent:CreateFontString(nil, "OVERLAY", base)
end
local function Scaled(f)
    local base = f.base
    if not f.sized then return base end
    local Kit = ns.Kit
    local nb = base.small and "GameFontHighlightSmall" or "GameFontHighlight"
    local np, sp = Kit.FontSize(nb, true), Kit.FontSize("GameFontHighlightSmall", true)
    local ds = sp - Kit.FontSize("GameFontHighlightSmall")
    local k = Kit.FontScale("GameFontHighlightSmall", true)
    local key = np .. ":" .. sp
    if f.scaledKey == key then return f.L end
    local L = {}
    for name, v in pairs(base) do L[name] = v end
    L.rowh = max(base.rowh + np - Kit.FontSize(nb), ceil(np * 1.15) + 6)
    L.headh = max(base.headh + ds, ceil(sp * 1.15) + 4)
    for _, name in ipairs({ "whenw", "namew", "mainw", "proofw", "hotw" }) do
        L[name] = ceil(base[name] * max(1, k))
    end
    L.k = max(1, k)
    L.icon = base.icon + max(0, floor(ds / 2))
    f.scaledKey, f.L = key, L
    return L
end
local function OpenCount(item)
    local n = 0
    for e = 1, #item.events do
        local ev = item.events[e]
        if ev.n > 0 and not ns.Ledger.Done(ev.key) then n = n + 1 end
    end
    return n
end
function FT.Rows(model, filter)
    local rows = {}
    local onlyOpen = filter == "open"
    for i = 1, #((model and model.items) or {}) do
        local item = model.items[i]
        local first, all = true, OpenCount(item) >= 2
        for e = 1, #item.events do
            local ev = item.events[e]
            local done = ns.Ledger.Done(ev.key)
            if not onlyOpen or not done then
                local d = { item = item, ev = ev, first = first }
                if all and not done and ev.n > 0 then
                    d.all, all = true, false
                end
                rows[#rows + 1] = d
                first = false
            end
        end
        for h = 1, onlyOpen and 0 or #item.hand do
            rows[#rows + 1] = { item = item, hand = item.hand[h], first = first }
            first = false
        end
    end
    return rows
end
local function Cols(L, width, noHot, noWhen)
    local c = { hot = {}, hotw = noHot and 0 or L.hotw, whenw = noWhen and 0 or L.whenw }
    local x = width - 2
    for i = 3, 1, -1 do
        x = x - c.hotw
        c.hot[i] = x
    end
    x = x - L.proofw
    c.proof = x
    x = x - L.mainw
    c.main = x
    x = x - c.whenw
    c.when = x
    c.left = L.checkw + (L.small and 2 or 6)
    c.nameEnd = c.when - 4
    return c
end
local function Fitted(L, width, nick, mark)
    local need = ceil(REASON * (L.k or 1))
    local c = Cols(L, width)
    local function Room(cc) return cc.nameEnd - (cc.left + mark + nick + 4) end
    if Room(c) < need and L.hotw > 0 then c = Cols(L, width, true) end
    if Room(c) < need and L.whenw > 0 then c = Cols(L, width, c.hotw == 0, true) end
    c.nick, c.mark = nick, mark
    return c
end
local function At(fs, parent, x, w)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", parent, "LEFT", x, 0)
    if w then fs:SetWidth(max(1, w)) end
end
local function Head(f, c)
    local L, h = f.L, f.head
    local unit = ns.Ledger.Unit(f.model and f.model.main)
    h:SetHeight(L.headh)
    At(h.who, h, c.left, c.nameEnd - c.left)
    FT.Pick(h.who, c.nameEnd - c.left, ns.T("ft.col.who"))
    At(h.when, h, c.when, max(1, c.whenw))
    FT.Pick(h.when, c.whenw, c.whenw > 0 and ns.T("ft.col.when"))
    At(h.main, h, c.main, L.mainw)
    FT.Pick(h.main, L.mainw, not L.small and format(ns.T("ft.col.rule"), unit), unit)
    At(h.proof, h, c.proof, L.proofw)
    FT.Pick(h.proof, L.proofw, not L.small and ns.T("ft.col.proof"))
    for i = 1, 3 do
        At(h.hot[i], h, c.hot[i], max(1, c.hotw))
        FT.Pick(h.hot[i], c.hotw, c.hotw > 0 and ns.T("ft.col." .. ns.Ledger.HOT[i]))
    end
end
local function ListOf(r)
    return r.list
end
local function MainClick(self)
    local r = self.row
    local list, d = ListOf(r), r.data
    if not (d and list.fight) then return end
    local item = d.item
    if d.all then
        ns.GPList.Issue(list.fight, { item })
    elseif d.ev.grade == "yellow" and not d.ev.bumped then
        ns.GPList.Charge(list.fight, item.name, d.ev)
    else
        ns.GPList.Issue(list.fight, { { name = item.name, sys = item.sys, events = { d.ev } } })
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
        if d.ev then
            ns.GPList.RowMenu(list.fight, d.ev.hit, d.item.name)
        else
            ns.GPList.ManualMenu(list.fight, d.item.name)
        end
    elseif d.ev and ns.ReplayLink and d.ev.t then
        ns.ReplayLink.Shift(list.fight, d.ev.t)
    end
end
local function RowEnter(self)
    local list, d = ListOf(self), self.data
    if not (d and list.fight) then return end
    local lines = d.ev and ns.GPList.HitLines(list.fight, d.ev.hit) or {}
    if d.first then
        for i = #lines, 1, -1 do
            if lines[i].kind == "foot" then table.remove(lines, i) end
        end
        local more = ns.BadgeTips.GPRow(d.item, ns.Penalties.Reason)
        for i = 1, #more do lines[#lines + 1] = more[i] end
    end
    if lines[1] then ns.Tip.Show(self, lines) end
end
local function RowLeave(self)
    ns.Tip.Hide()
end
local function Wheel(self, delta)
    local list = self.list or self
    if list.onWheel then list.onWheel(delta) end
end
local function Row(f, k)
    local r = f.rows[k]
    if r then return r end
    local L = f.L
    r = CreateFrame("Frame", nil, f)
    r.sized = f.sized
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
    r.mark = ns.Badges.Mark(r, L.icon)
    r.mark:EnableMouse(false)
    r.name = Str(f.sized, r, L.small and "GameFontHighlightSmall" or "GameFontHighlight")
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.note = Str(f.sized, r, L.small and "GameFontHighlightSmall" or "GameFontHighlight")
    r.note:SetJustifyH("LEFT")
    r.note:SetWordWrap(false)
    r.when = Str(f.sized, r, "GameFontHighlightSmall")
    ns.Kit.Text(r.when, "text.bright")
    r.when:SetJustifyH("RIGHT")
    r.main = ns.MakeButton(r, f.prefix .. k, "main")
    if f.sized then ns.Kit.Bind(r.main.text, "GameFontNormalSmall") end
    r.main:SetHeight(L.rowh - 4)
    r.main.row = r
    r.main.onClick = MainClick
    r.done = r:CreateTexture(nil, "ARTWORK")
    r.done:SetTexture(DONE)
    r.done:SetWidth(12)
    r.done:SetHeight(12)
    r.doneText = Str(f.sized, r, "GameFontHighlightSmall")
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
        if f.sized then ns.Kit.Bind(b.text, "GameFontNormalSmall") end
        b:SetHeight(L.rowh - 4)
        b:SetWidth(L.hotw - 6)
        b.row, b.slot = r, i
        b.onClick = HotClick
        r.hot[i] = b
    end
    f.rows[k] = r
    return r
end
local function Fit(r, L)
    if r.fitFor == L then return end
    r.fitFor = L
    r:SetHeight(L.rowh)
    r.main:SetHeight(L.rowh - 4)
    r.mark:Resize(L.icon)
    for i = 1, #r.hot do
        r.hot[i]:SetHeight(L.rowh - 4)
        r.hot[i]:SetWidth(L.hotw - 6)
    end
end
local function Blank(r)
    if r.check then r.check:Hide() end
    r.mark:Hide()
    r.note:SetText("")
    r.when:SetText("")
    r.main:Hide()
    r.done:Hide()
    r.doneText:Hide()
    r.undo:Hide()
    if r.proof then r.proof:Hide() end
    for i = 1, #r.hot do r.hot[i]:Hide() end
end
local function Main(r, c, L, kind, text, tip, all)
    r.main:ClearAllPoints()
    r.main:SetPoint("RIGHT", r, "LEFT", c.main + L.mainw - 4, 0)
    r.main:SetWidth(L.mainw - 6)
    ns.Kit.ButtonKind(r.main, kind)
    r.main:SetActive(all)
    r.main.text:SetText(text)
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
local function Hots(r, c, L, item)
    if c.hotw == 0 then return end
    local sys = item.sys or ns.Ledger.Key()
    local unit = ns.Ledger.Unit(sys)
    for i = 1, #r.hot do
        local b, kind = r.hot[i], ns.Ledger.HOT[i]
        local n = ns.Ledger.HotSum(kind, sys)
        b:ClearAllPoints()
        b:SetPoint("LEFT", r, "LEFT", c.hot[i] + 3, 0)
        b.text:SetText(tostring(n))
        b.tip = format(ns.T("ft.tip.hot.fault"), ns.Ledger.HotLabel(kind), n, unit)
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
local function MarkModel(ev)
    return { icon = ns.GPList.Icon(ev.hit.icon), count = tostring(#ev.hit.events),
        verdict = ev.grade == "yellow" and "yellow" or "red" }
end
local function Who(r, d, c, L)
    local x = c.left
    local w = max(1, min(c.nick, c.nameEnd - x - c.mark))
    At(r.name, r, x)
    r.name:SetWidth(0)
    ns.Badges.Clip(r.name, d.item.name, w)
    r.name:SetWidth(max(1, w))
    if d.first then
        r.name:SetTextColor(ns.GPList.ClassRGB(d.item.class))
    else
        ns.Kit.Text(r.name, "text.muted")
    end
    x = x + w + 4
    if d.ev then
        r.mark:SetModel(MarkModel(d.ev))
        r.mark:Layout(r.mark:Need())
        r.mark:ClearAllPoints()
        r.mark:SetPoint("LEFT", r, "LEFT", x, 0)
        r.mark:Show()
    end
    return x + c.mark
end
function FT.Pick(fs, room, ...)
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        if t then
            fs:SetText(t)
            if (fs:GetStringWidth() or 0) <= room then return end
        end
    end
    fs:SetText("")
end
local function Amount(item, model, L, n)
    if L.small or not model or item.sys == model.main then return tostring(n) end
    return n .. " " .. ns.Ledger.Unit(item.sys)
end
local function FillFault(r, d, fight, c)
    local list = ListOf(r)
    local L, ev, item = list.L, d.ev, d.item
    local unit = ns.Ledger.Unit(item.sys)
    local done = ns.Ledger.Done(ev.key)
    if r.check then
        r.check:ClearAllPoints()
        r.check:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.check:SetChecked(not done and list.sel[ev.key] and true or false)
        if done then r.check:Disable() else r.check:Enable() end
        r.check:Show()
    end
    local x = Who(r, d, c, L)
    local marks = ""
    if ev.wipe then marks = marks .. " " .. ns.Kit.Hex("text.note") .. ns.T("ft.wipe") .. "|r" end
    local note = d.first and ns.GPList.Note(item)
    local room = c.nameEnd - x
    At(r.note, r, x, room)
    ns.Kit.Text(r.note, done and "text.muted" or "text.primary")
    FT.Pick(r.note, room, note and (ev.reason .. marks .. "  " .. ns.Kit.Hex("text.muted") .. note .. "|r"),
        ev.reason .. marks, ev.short and ev.short .. marks, ev.short)
    if c.whenw > 0 then
        At(r.when, r, c.when, c.whenw)
        r.when:SetText(ev.t and ns.Clock(ev.t - fight.from) or ns.T("ft.whole"))
    end
    local raid = item.raid and item.raid > 0 and "\n" .. format(ns.T("ft.tip.roll.raid"), item.raid) or ""
    if d.all then
        Main(r, c, L, "main", Amount(item, list.model, L, item.pending),
            format(ns.T("ft.tip.all"), item.pending, unit) .. raid, true)
    elseif done then
        local tip = done.n and format(ns.T("ft.tip.done"), done.n, ns.Ledger.Unit(done.s)) or ns.T("led.menu.old")
        Done(r, c, L, done.n, tip, ns.Ledger.CanUndo(ev.key))
    elseif ev.grade == "yellow" and not ev.bumped then
        local n = ns.Penalties.Amount(ev.hit.rule, item.sys) or 0
        if n > 0 then Main(r, c, L, "quiet", Amount(item, list.model, L, n), format(ns.T("ft.tip.charge"), n, unit)) end
    elseif ev.n > 0 then
        Main(r, c, L, "main", Amount(item, list.model, L, ev.n), format(ns.T("ft.tip.give"), ev.n, unit) .. raid)
    end
    Proof(r, c, L, { fight = fight, name = item.name,
        hits = { { rule = ev.hit.rule, events = { ev.src }, icon = ev.hit.icon, shed = ev.hit.shed } } })
    if not done then Hots(r, c, L, item) end
end
local function FillHand(r, d, c)
    local L, h = ListOf(r).L, d.hand
    local x = Who(r, d, c, L)
    At(r.note, r, x, c.nameEnd - x)
    local label = ns.Ledger.HotLabel(h.kind or "slack")
    FT.Pick(r.note, c.nameEnd - x, format(ns.T("ft.hand"), label), label)
    ns.Kit.Text(r.note, "text.muted")
    local n = h.done.n
    Done(r, c, L, n, format(ns.T("ft.tip.done"), n or 0, ns.Ledger.Unit(h.done.s)), ns.Ledger.CanUndo(h.key))
end
local function Paint(r, k)
    local c = ns.Kit.C[k % 2 == 0 and "row.bgHover" or "row.bg"]
    r.bg:SetTexture(c[1], c[2], c[3], (c[4] or 1) * 0.5)
end
local function Draw(self, fight, model, width, offset, slots)
    local L = Scaled(self)
    self.fight, self.model = fight, model
    local rows = FT.Rows(model, self.filter)
    self.flat = rows
    self.total = #rows
    offset = offset or 0
    local shown = max(0, min(#rows - offset, slots or #rows))
    local r1 = Row(self, 1)
    Fit(r1, L)
    local nick, count = 0, 0
    r1.name:SetWidth(0)
    for k = 1, #rows do
        local d = rows[k]
        r1.name:SetText(d.item.name)
        nick = max(nick, r1.name:GetStringWidth() or 0)
        if d.ev then
            r1.mark:SetModel(MarkModel(d.ev))
            count = max(count, r1.mark:Need())
        end
    end
    local c = Fitted(L, width, nick > 0 and min(L.namew, ceil(nick) + 8) or L.namew, max(L.icon, count) + 6)
    Head(self, c)
    for k = 1, max(shown, #rows == 0 and 1 or 0) do
        local r = Row(self, k)
        Fit(r, L)
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
        else
            FillHand(r, d, c)
        end
        r:Show()
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
function FT.New(parent, prefix, layout, sized)
    local f = CreateFrame("Frame", nil, parent)
    f.rows = {}
    f.prefix = prefix
    f.L, f.base, f.sized = layout, layout, sized
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
    h.who = Str(sized, h, font)
    h.who:SetJustifyH("LEFT")
    h.who:SetWordWrap(false)
    h.when = Str(sized, h, font)
    h.when:SetJustifyH("RIGHT")
    h.when:SetWordWrap(false)
    h.main = Str(sized, h, font)
    h.main:SetJustifyH("RIGHT")
    h.main:SetWordWrap(false)
    h.proof = Str(sized, h, font)
    h.proof:SetJustifyH("CENTER")
    h.proof:SetWordWrap(false)
    h.hot = {}
    for i = 1, 3 do
        h.hot[i] = Str(sized, h, font)
        h.hot[i]:SetJustifyH("CENTER")
        h.hot[i]:SetWordWrap(false)
        ns.Kit.Text(h.hot[i], "badge.detail")
    end
    for _, fs in ipairs({ h.who, h.when, h.main, h.proof }) do ns.Kit.Text(fs, "text.secondary") end
    return f
end
