local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local STRIPE = 3
local PAD = STRIPE + 6
local TOTALH = 52
local TOTAL_L = 10
local TOTAL_R = 8
local SUBGAP = 6
local SUBMIN = 24
local LINES_DEFAULT = 5
local LINES_MIN = 3
local LINES_MAX = 15
local LINEH = 14
local PERSONALH = 58
local PERSONAL_R = 7
local CLASS_ICON = 22
local MARK = 16
local MARKTOP = 36
local MARKROW = MARK + 10
local ROW_ICON = 12
local NOTE_ICON = 10
local COLGAP = 6
local NAMEGAP = 4
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local ARROW_TEX = "Interface\\TalentFrame\\UI-TalentArrows"
local ARROW = { out = { 0, 0.5, 0.5, 0 }, ["in"] = { 0, 0.5, 0, 0.5 } }
local ARROW_SIZE = 16
local ARROW_EDGE = 4
local ARROW_DIP = 8
local MARKGAP = 7
local WIDE_ICON = 12
local WIDE_GAP = 6
local WIDE_INDENT = 16
local Badges = {}
ns.Badges = Badges
Badges.style = ns.Kit.Group("badge")
local style = Badges.style
local named = {}
local function ClampLines(n)
    n = tonumber(n)
    if not n then return LINES_DEFAULT end
    return max(LINES_MIN, min(LINES_MAX, floor(n + 0.5)))
end
local function UiSettings()
    local db = ns.GetDB and ns.GetDB()
    local set = db and db.settings
    if type(set) ~= "table" then return nil end
    if type(set.ui) ~= "table" then set.ui = {} end
    return set.ui
end
function Badges.Lines()
    local ui = UiSettings()
    return ClampLines(ui and ui.detailRows)
end
function Badges.LinesRange()
    return LINES_MIN, LINES_MAX, LINES_DEFAULT
end
function Badges.SetLines(n)
    local v = ClampLines(n)
    local ui = UiSettings()
    if ui then ui.detailRows = v end
    return v
end
local lit = {}
local dimmed = {}
local skinned = {}
local function ClassRGB(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return cc.r, cc.g, cc.b end
    return style.noClass[1], style.noClass[2], style.noClass[3]
end
local function Edge(f, c)
    f:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
end
function Badges.Skin(f, color)
    if not f.stripe then
        f:SetBackdrop(ns.Kit.Theme().badge.backdrop)
        f:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4] or 1)
        Edge(f, style.edge)
        f.stripe = f:CreateTexture(nil, "ARTWORK")
        f.stripe:SetPoint("TOPLEFT", 1, -1)
        f.stripe:SetPoint("BOTTOMLEFT", 1, 1)
        f.stripe:SetWidth(STRIPE)
        skinned[#skinned + 1] = f
    end
    f.stripe:SetTexture(color[1], color[2], color[3], 1)
end
local function ShowLines(self)
    if self.lines then ns.Tip.Dock(self, self.lines, self.tipIcon) end
end
local function HideTip()
    ns.Tip.Hide()
end
function Badges.Highlight(names, source)
    Badges.Unhighlight()
    for i = 1, #names do
        local b = named[names[i]]
        if b and b:IsShown() and not b.lit then
            b.lit = true
            Edge(b, style.link)
            b.glow:Show()
            lit[#lit + 1] = b
        end
    end
    if #lit == 0 then return end
    local a = style.dim or 0.35
    for _, b in pairs(named) do
        if not b.lit and b ~= source and b:IsShown() then
            b:SetAlpha(a)
            dimmed[#dimmed + 1] = b
        end
    end
end
function Badges.Unhighlight()
    for i = #lit, 1, -1 do
        local b = lit[i]
        b.lit = nil
        Edge(b, style.edge)
        b.glow:Hide()
        lit[i] = nil
    end
    for i = #dimmed, 1, -1 do
        dimmed[i]:SetAlpha(1)
        dimmed[i] = nil
    end
end
function Badges.ResetLinks()
    Badges.Unhighlight()
    for k in pairs(named) do named[k] = nil end
end
local function Fit(fs, text, room)
    fs:SetWidth(0)
    fs:SetText(text)
    local need = fs:GetStringWidth() or 0
    if text == "" or room < 1 then
        fs:Hide()
        return 0, text ~= ""
    end
    local w = min(ceil(need) + 2, room)
    fs:SetWidth(w)
    fs:Show()
    return w, need > room
end
local function SubParts(m)
    local parts = {}
    if m.sub and m.sub ~= "" then parts[1] = m.sub end
    for i = 1, #(m.subs or {}) do
        if m.subs[i] ~= "" then parts[#parts + 1] = m.subs[i] end
    end
    return parts
end
local function FullLines(m, parts)
    local base = m.lines
    local out, from = {}, 1
    if base and base[1] and base[1].kind == "head" and base[1].left == m.title then
        out[1], from = base[1], 2
    else
        out[1] = { kind = "head", left = m.title, right = m.value }
    end
    for i = 1, #parts do out[#out + 1] = { kind = "sub", left = parts[i] } end
    if base and base[from] then
        out[#out + 1] = { kind = "sep" }
        for i = from, #base do out[#out + 1] = base[i] end
    end
    return out
end
local function OneLine(fs)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
end
function Badges.Total(parent)
    local f = CreateFrame("Frame", nil, parent)
    Badges.Skin(f, style.edge)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", TOTAL_L, -6)
    OneLine(f.title)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.value:SetPoint("BOTTOMLEFT", TOTAL_L, 7)
    OneLine(f.value)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.sub:SetPoint("BOTTOMLEFT", f.value, "BOTTOMRIGHT", SUBGAP, 1)
    OneLine(f.sub)
    f.subTop = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.subTop:SetPoint("BOTTOMLEFT", f.sub, "TOPLEFT", 0, 0)
    OneLine(f.subTop)
    f:SetScript("OnEnter", ShowLines)
    f:SetScript("OnLeave", HideTip)
    function f.SetModel(self, m)
        local c = m.color
        Badges.Skin(self, c)
        self.model = m
        self.title:SetText(m.title)
        self.title:SetTextColor(c[1], c[2], c[3])
        self.lines = m.lines
        self:EnableMouse(m.lines ~= nil)
    end
    function f.Layout(self, width)
        self:SetWidth(width)
        self:SetHeight(TOTALH)
        local m = self.model
        if not m then return TOTALH end
        local inner = width - TOTAL_L - TOTAL_R
        local parts = SubParts(m)
        local _, cutTitle = Fit(self.title, m.title, inner)
        local vw, cutValue = Fit(self.value, m.value, inner)
        local room = inner - vw - SUBGAP
        if room < SUBMIN then room = 0 end
        local top, bottom = "", parts[1] or ""
        if #parts > 1 then top, bottom = parts[1], table.concat(parts, "  ", 2) end
        local _, cutTop = Fit(self.subTop, top, room)
        local _, cutBottom = Fit(self.sub, bottom, room)
        local cut = cutTitle or cutValue or cutTop or cutBottom
        self.lines = cut and FullLines(m, parts) or m.lines
        self:EnableMouse(self.lines ~= nil)
        return TOTALH
    end
    return f
end
local function RowIcon(row, tex)
    row.name:ClearAllPoints()
    if tex then
        row.icon:SetTexture(tex)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:Show()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
    else
        row.icon:Hide()
        row.name:SetPoint("LEFT", 4, 0)
    end
    row.name:SetPoint("RIGHT", row.val, "LEFT", -NAMEGAP, 0)
end
local function Widest(probe, list, key)
    local w, any = 0, false
    for i = 1, #list do
        local s = list[i][key]
        if s and s ~= "" then
            any = true
            probe:SetText(s)
            w = max(w, probe:GetStringWidth() or 0)
        end
    end
    return w > 0 and ceil(w) + 2 or 0, any
end
local function Columns(f)
    local list = f.list
    local noteW, hasNote = Widest(f.probe, list, "note")
    local valW = hasNote and Widest(f.probe, list, "text") or 0
    local coin = false
    for i = 1, #list do
        if list[i].noteIcon then coin = true end
    end
    for k = 1, #f.rows do
        local row = f.rows[k]
        row.note:ClearAllPoints()
        row.note:SetPoint("RIGHT", -(2 + (coin and NOTE_ICON + 2 or 0)), 0)
        row.note:SetWidth(noteW)
        row.val:ClearAllPoints()
        if hasNote then
            row.val:SetPoint("RIGHT", row.note, "LEFT", -COLGAP, 0)
        else
            row.val:SetPoint("RIGHT", -2, 0)
        end
        row.val:SetWidth(valW)
    end
end
local function RowNote(row, e)
    local note = e and e.note
    row.note:SetText(note or "")
    if note and e.noteMuted then
        row.note:SetTextColor(style.muted[1], style.muted[2], style.muted[3])
    else
        ns.Kit.Tone(row.note, "text.bright")
    end
    if note and e.noteIcon then
        row.coin:SetTexture(e.noteIcon)
        row.coin:Show()
    else
        row.coin:Hide()
    end
end
local function DrawRows(f)
    local list = f.list
    local lines = f.lineCount or LINES_DEFAULT
    local most = max(0, #list - lines)
    f.offset = max(0, min(most, f.offset or 0))
    for k = 1, #f.rows do
        local row = f.rows[k]
        local e = k <= lines and list[k + f.offset]
        if e then
            row.name:SetText(e.who)
            row.name:SetTextColor(ClassRGB(e.class))
            RowIcon(row, e.icon)
            row.val:SetText(e.text)
            RowNote(row, e)
            row.lines = e.lines
            row.tipIcon = e.tipIcon
            row:Show()
        else
            row:Hide()
        end
        if f.paint then f.paint(row, e or nil) end
    end
    if most > 0 then
        f.more:SetText(format(ns.T("sum.k.more"), f.offset + 1, min(#list, f.offset + lines), #list))
        f.more:Show()
        f.title:SetPoint("TOPRIGHT", f.more, "TOPLEFT", -COLGAP, 0)
    else
        f.more:Hide()
        f.title:SetPoint("TOPRIGHT", -8, -6)
    end
    if #list == 0 then
        local row = f.rows[1]
        RowIcon(row, nil)
        row.name:SetText(f.empty or "")
        row.name:SetTextColor(style.muted[1], style.muted[2], style.muted[3])
        row.val:SetText("")
        RowNote(row, nil)
        row.lines = nil
        row.tipIcon = nil
        if f.paint then f.paint(row, nil) end
        row:Show()
    end
end
local function DetailWheel(self, delta)
    local most = max(0, #self.list - (self.lineCount or LINES_DEFAULT))
    local want = (self.offset or 0) - delta
    if most == 0 or want < 0 or want > most then
        if self.onWheel then self.onWheel(delta) end
        return
    end
    self.offset = want
    DrawRows(self)
end
local function NewDetailRow(f, k)
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(LINEH)
    row:SetPoint("TOPLEFT", 6, -(8 + k * LINEH))
    row:SetPoint("TOPRIGHT", -6, -(8 + k * LINEH))
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowLines)
    row:SetScript("OnLeave", HideTip)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(ROW_ICON)
    row.icon:SetHeight(ROW_ICON)
    row.icon:SetPoint("LEFT", 3, 0)
    row.icon:Hide()
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetHeight(LINEH)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.val:SetPoint("RIGHT", -2, 0)
    row.val:SetHeight(LINEH)
    row.val:SetJustifyH("RIGHT")
    row.val:SetWordWrap(false)
    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.note:SetPoint("RIGHT", -2, 0)
    row.note:SetHeight(LINEH)
    row.note:SetJustifyH("RIGHT")
    row.note:SetWordWrap(false)
    row.coin = row:CreateTexture(nil, "ARTWORK")
    row.coin:SetWidth(NOTE_ICON)
    row.coin:SetHeight(NOTE_ICON)
    row.coin:SetPoint("RIGHT", -2, 0)
    row.coin:Hide()
    return row
end
local function Grow(f, n)
    for k = #f.rows + 1, n do f.rows[k] = NewDetailRow(f, k) end
    f.lineCount = n
end
function Badges.Detail(parent)
    local f = CreateFrame("Frame", nil, parent)
    Badges.Skin(f, style.detail)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", DetailWheel)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 10, -6)
    f.title:SetPoint("TOPRIGHT", -8, -6)
    f.title:SetHeight(LINEH - 2)
    f.title:SetJustifyH("LEFT")
    f.title:SetJustifyV("TOP")
    f.title:SetWordWrap(false)
    f.more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.more:SetPoint("TOPRIGHT", -8, -6)
    f.head = CreateFrame("Frame", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(8 + LINEH)
    f.head:SetScript("OnEnter", ShowLines)
    f.head:SetScript("OnLeave", HideTip)
    f.head:EnableMouse(false)
    f.probe = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.probe:Hide()
    f.list = {}
    f.rows = {}
    f.lineCount = 0
    Grow(f, Badges.Lines())
    function f.SetModel(self, m)
        Badges.Skin(self, style.detail)
        self.title:SetText(m.title)
        self.head.lines = m.tip
        self.head:EnableMouse(m.tip ~= nil)
        self.list = m.rows or {}
        self.empty = m.empty
        self.onWheel = m.onWheel
        self.paint = m.paint
        self.offset = 0
        Grow(self, Badges.Lines())
        Columns(self)
        DrawRows(self)
    end
    function f.Layout(self, width)
        local lines = Badges.Lines()
        if lines ~= self.lineCount then
            Grow(self, lines)
            Columns(self)
            DrawRows(self)
        end
        local h = 14 + (max(1, min(lines, #self.list)) + 1) * LINEH
        self:SetWidth(width)
        self:SetHeight(h)
        return h
    end
    return f
end
local paired = {}
local function PairOn(self)
    local kids = { self:GetParent():GetChildren() }
    for i = 1, #kids do
        local b = kids[i]
        if b.pair == self.pair and b.pairGlow and b:IsShown() then
            b.pairGlow:Show()
            paired[#paired + 1] = b
        end
    end
end
local function PairOff()
    for i = #paired, 1, -1 do
        paired[i].pairGlow:Hide()
        paired[i] = nil
    end
end
local function MarkEnter(self)
    if self.pair then PairOn(self) end
    if self.links then Badges.Highlight(self.links, self.owner or self:GetParent()) end
    if not (ns.ProofView and ns.ProofView.Enter(self)) then ShowLines(self) end
    if ns.DeathPreviewView then ns.DeathPreviewView.Enter(self) end
end
local function MarkLeave(self)
    if ns.ProofView then ns.ProofView.Leave(self) end
    HideTip()
    if ns.DeathPreviewView then ns.DeathPreviewView.Leave() end
    if self.links then Badges.Unhighlight() end
    PairOff()
end
local function MarkClick(self, button)
    if ns.ProofView and ns.ProofView.Click(self, button) then return end
    local owner = self.owner or self:GetParent()
    if ns.ReplayLink and ns.ReplayLink.Shift(self.fight, self.at, self.who or (owner and owner.who)) then return end
    if self.onClick then
        self.onClick(self, button)
    elseif ns.TimelineLinks then
        ns.TimelineLinks.OpenMark(self, button)
    end
end
function Badges.Mark(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b.size = size
    b:SetHeight(size)
    b:SetWidth(size + 16)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.ring = b:CreateTexture(nil, "BACKGROUND")
    b.ring:SetWidth(size + 4)
    b.ring:SetHeight(size + 4)
    b.ring:SetPoint("LEFT", -2, 0)
    b.pairGlow = b:CreateTexture(nil, "BORDER")
    b.pairGlow:SetPoint("TOPLEFT", -3, 3)
    b.pairGlow:SetPoint("BOTTOMRIGHT", 1, -3)
    ns.Kit.Paint(b.pairGlow, "badge.link", 0.35)
    b.pairGlow:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetWidth(size)
    b.icon:SetHeight(size)
    b.icon:SetPoint("LEFT", 0, 0)
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("LEFT", b.icon, "RIGHT", 2, 0)
    b.arrowF = CreateFrame("Frame", nil, b)
    b.arrowF:SetFrameLevel((b:GetFrameLevel() or 0) + 2)
    b.arrowF:SetWidth(ARROW_SIZE + ARROW_EDGE)
    b.arrowF:SetHeight(ARROW_SIZE + ARROW_EDGE)
    b.arrowF:SetPoint("BOTTOM", b.icon, "TOP", 0, -ARROW_DIP)
    b.arrowBg = b.arrowF:CreateTexture(nil, "BORDER")
    b.arrowBg:SetAllPoints()
    b.arrowBg:SetTexture(ARROW_TEX)
    ns.Kit.Tint(b.arrowBg, "text.shadow", 1)
    b.arrow = b.arrowF:CreateTexture(nil, "ARTWORK")
    b.arrow:SetWidth(ARROW_SIZE)
    b.arrow:SetHeight(ARROW_SIZE)
    b.arrow:SetPoint("CENTER", 0, 0)
    b.arrow:SetTexture(ARROW_TEX)
    b.arrowF:Hide()
    b:SetScript("OnEnter", MarkEnter)
    b:SetScript("OnLeave", MarkLeave)
    b:SetScript("OnClick", MarkClick)
    function b.SetModel(self, m)
        self.icon:SetTexture(m.icon)
        self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        self.count:SetText(m.count or "")
        local ac = m.arrow and ARROW[m.arrow]
        if ac then
            self.arrow:SetTexCoord(ac[1], ac[2], ac[3], ac[4])
            self.arrowBg:SetTexCoord(ac[1], ac[2], ac[3], ac[4])
            self.arrowF:Show()
        else
            self.arrowF:Hide()
        end
        local tc = m.alert and style.alert
        if tc then
            self.count:SetTextColor(tc[1], tc[2], tc[3])
        else
            ns.Kit.Tone(self.count, "text.bright")
        end
        local c = m.verdict and style[m.verdict]
        if c then
            self.ring:SetTexture(c[1], c[2], c[3], c[4] or 1)
            self.ring:Show()
        else
            self.ring:Hide()
        end
        self.lines = m.lines
        self.tipIcon = m.icon
        self.links = m.links and #m.links > 0 and m.links or nil
        self.pair = m.pair
        self.pairGlow:Hide()
        self.onClick = m.onClick
        self.fight, self.at = m.fight, m.at
        self.preview = m.preview
        self.proof = m.proof
    end
    function b.Layout(self, width)
        self:SetWidth(width)
        return self.size
    end
    function b.Need(self)
        return self.size + 2 + ceil(self.count:GetStringWidth() or 0)
    end
    return b
end
local VERDICT_RANK = { red = 1, yellow = 2, green = 4 }
local function Ordered(marks)
    local out = {}
    for rank = 1, 4 do
        for i = 1, #marks do
            local m = marks[i]
            if (VERDICT_RANK[m.verdict or ""] or 3) == rank then out[#out + 1] = m end
        end
    end
    return out
end
local function PersonalEnter(self)
    Edge(self, style.hover)
    ShowLines(self)
end
local function PersonalLeave(self)
    Edge(self, self.lit and style.link or style.edge)
    HideTip()
end
local function PersonalClick(self, button)
    HideTip()
    local name = self.who
    if not name then return end
    if button == "RightButton" then
        if self.onRightClick then self.onRightClick(name) end
    elseif self.onClick then
        self.onClick(name)
    end
end
local function PersonalWheel(self, delta)
    if self.onWheel then self.onWheel(delta) end
end
function Badges.Personal(parent)
    local t = CreateFrame("Button", nil, parent)
    Badges.Skin(t, style.edge)
    t:SetHeight(PERSONALH)
    t.glow = t:CreateTexture(nil, "BORDER")
    t.glow:SetPoint("TOPLEFT", 1, -1)
    t.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    ns.Kit.Paint(t.glow, "badge.linkFill")
    t.glow:Hide()
    t.cls = t:CreateTexture(nil, "ARTWORK")
    t.cls:SetWidth(CLASS_ICON)
    t.cls:SetHeight(CLASS_ICON)
    t.cls:SetPoint("TOPLEFT", PAD, -5)
    t.cls:SetTexture(CLASS_TEX)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.name:SetPoint("LEFT", t.cls, "RIGHT", 5, 0)
    OneLine(t.name)
    t.value = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.value:SetPoint("TOPRIGHT", -PERSONAL_R, -6)
    OneLine(t.value)
    t.value:SetJustifyH("RIGHT")
    t.sub = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.sub:SetPoint("TOPRIGHT", -PERSONAL_R, -22)
    OneLine(t.sub)
    t.sub:SetJustifyH("RIGHT")
    t.marks = {}
    t.shown = 0
    t:SetScript("OnEnter", PersonalEnter)
    t:SetScript("OnLeave", PersonalLeave)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:SetScript("OnClick", PersonalClick)
    t:SetScript("OnMouseWheel", PersonalWheel)
    function t.SetModel(self, m)
        local r, g, b = ClassRGB(m.class)
        Badges.Skin(self, { r, g, b })
        local tc = m.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class]
        if tc then
            self.cls:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
            self.cls:Show()
        else
            self.cls:Hide()
        end
        self.name:SetText(m.name)
        self.name:SetTextColor(r, g, b)
        self.valueText = m.value or ""
        self.subText = m.sub or ""
        self.value:SetText(self.valueText)
        self.sub:SetText(self.subText)
        if self.who and named[self.who] == self then named[self.who] = nil end
        self.who = m.name
        named[m.name] = self
        self.lines = m.lines
        self.onClick = m.onClick
        self.onRightClick = m.onRightClick
        self.onWheel = m.onWheel
        self:EnableMouseWheel(m.onWheel ~= nil)
        local list = Ordered(m.marks or {})
        for k = 1, #list do
            local mk = self.marks[k]
            if not mk then
                mk = Badges.Mark(self, MARK)
                self.marks[k] = mk
            end
            mk:SetModel(list[k])
            mk.who = m.name
            mk:Show()
        end
        for k = #list + 1, #self.marks do self.marks[k]:Hide() end
        self.shown = #list
    end
    function t.Layout(self, width)
        self:SetWidth(width)
        local inner = width - PAD - CLASS_ICON - 5 - PERSONAL_R
        local vw = Fit(self.value, self.valueText or "", inner)
        Fit(self.sub, self.subText or "", inner)
        self.name:SetWidth(max(1, inner - vw - NAMEGAP))
        local room = width - PAD - 5
        local x, row = 0, 0
        for k = 1, self.shown do
            local mk = self.marks[k]
            local w = mk:Need()
            if x > 0 and x + w > room then x, row = 0, row + 1 end
            mk:Layout(w)
            mk:ClearAllPoints()
            mk:SetPoint("TOPLEFT", PAD + x, -(MARKTOP + row * MARKROW))
            x = x + w + MARKGAP
        end
        local h = PERSONALH + row * MARKROW
        self:SetHeight(h)
        return h
    end
    return t
end
local function WideSlots(row, n, m)
    for c = #row.cells + 1, n do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetHeight(LINEH)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(false)
        row.cells[c] = fs
    end
    for k = #row.icons + 1, m do
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetWidth(WIDE_ICON)
        tex:SetHeight(WIDE_ICON)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetHeight(LINEH)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetPoint("LEFT", tex, "RIGHT", 2, 0)
        row.icons[k], row.counts[k] = tex, fs
    end
end
local function NewWideRow(f, k)
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(LINEH)
    row:SetPoint("TOPLEFT", 6, -(8 + (k + 1) * LINEH))
    row:SetPoint("TOPRIGHT", -6, -(8 + (k + 1) * LINEH))
    row:EnableMouse(k > 0)
    row:SetScript("OnEnter", ShowLines)
    row:SetScript("OnLeave", HideTip)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetHeight(LINEH)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.cells, row.icons, row.counts = {}, {}, {}
    return row
end
local function WideGrow(f, want)
    for k = #f.rows + 1, want do f.rows[k] = NewWideRow(f, k) end
    f.lineCount = want
end
local function SlotWidth(f, i)
    local w, any = 0, f.heads[i] and true or false
    for r = 1, #f.list do
        local mk = f.list[r].marks and f.list[r].marks[i]
        if mk then
            any = true
            f.probe:SetText(mk.count or "")
            w = max(w, f.probe:GetStringWidth() or 0)
        end
    end
    if not any then return 0 end
    return WIDE_ICON + 2 + ceil(w) + 2
end
local function WidePlace(f, row)
    local nc, ns2 = #f.cols, #f.heads
    WideSlots(row, nc, ns2)
    for c = 1, #row.cells do
        if c <= nc then row.cells[c]:Show() else row.cells[c]:Hide() end
    end
    for k = ns2 + 1, #row.icons do
        row.icons[k]:Hide()
        row.counts[k]:Hide()
    end
    local off = 2
    for k = ns2, 1, -1 do
        local sw = f.slotW[k]
        row.icons[k]:ClearAllPoints()
        row.icons[k]:SetPoint("LEFT", row, "RIGHT", -(off + sw), 0)
        row.counts[k]:SetWidth(max(1, sw - WIDE_ICON - 2))
        if sw > 0 then off = off + sw + WIDE_GAP end
    end
    for c = nc, 1, -1 do
        local fs = row.cells[c]
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", -off, 0)
        fs:SetWidth(f.colW[c])
        off = off + f.colW[c] + COLGAP
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -(off - COLGAP + NAMEGAP), 0)
    row.nameOff = off - COLGAP + NAMEGAP
end
local function WideColumns(f)
    f.colW, f.slotW = {}, {}
    for c = 1, #f.cols do
        f.probe:SetText(f.cols[c])
        local w = f.probe:GetStringWidth() or 0
        for r = 1, #f.list do
            local s = f.list[r].cells and f.list[r].cells[c]
            if s and s ~= "" then
                f.probe:SetText(s)
                w = max(w, f.probe:GetStringWidth() or 0)
            end
        end
        f.colW[c] = ceil(w) + 2
    end
    for i = 1, #f.heads do f.slotW[i] = SlotWidth(f, i) end
    WidePlace(f, f.header)
    for k = 1, #f.rows do WidePlace(f, f.rows[k]) end
end
local function WideRow(row, e, f)
    row.name:SetPoint("LEFT", (e and e.sub) and WIDE_INDENT or 4, 0)
    for c = 1, #f.cols do
        row.cells[c]:SetText(e and e.cells and e.cells[c] or "")
        ns.Kit.Tone(row.cells[c], "text.bright")
    end
    for k = 1, #f.heads do
        local mk = e and e.marks and e.marks[k]
        if mk and f.slotW[k] > 0 then
            row.icons[k]:SetTexture(mk.icon)
            row.icons[k]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icons[k]:Show()
            row.counts[k]:SetText(mk.count or "")
            ns.Kit.Tone(row.counts[k], "text.bright")
            row.counts[k]:Show()
        else
            row.icons[k]:Hide()
            row.counts[k]:Hide()
        end
    end
    row.lines = e and e.lines
    row.tipIcon = nil
end
local function DrawWide(f)
    local list = f.list
    local lines = f.lineCount
    local most = max(0, #list - lines)
    f.offset = max(0, min(most, f.offset or 0))
    local h = f.header
    h.name:SetText("")
    for c = 1, #f.cols do
        h.cells[c]:SetText(f.cols[c])
        h.cells[c]:SetTextColor(style.muted[1], style.muted[2], style.muted[3])
    end
    for k = 1, #f.heads do
        local icon = f.heads[k]
        if icon and f.slotW[k] > 0 then
            h.icons[k]:SetTexture(icon)
            h.icons[k]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            h.icons[k]:Show()
        else
            h.icons[k]:Hide()
        end
        h.counts[k]:Hide()
    end
    for k = 1, #f.rows do
        local row = f.rows[k]
        local e = k <= lines and list[k + f.offset]
        if e then
            row.name:SetText(e.who)
            row.name:SetTextColor(ClassRGB(e.class))
            WideRow(row, e, f)
            row:Show()
        else
            row:Hide()
        end
    end
    if most > 0 then
        f.more:SetText(format(ns.T("sum.k.more"), f.offset + 1, min(#list, f.offset + lines), #list))
        f.more:Show()
        f.title:SetPoint("TOPRIGHT", f.more, "TOPLEFT", -COLGAP, 0)
    else
        f.more:Hide()
        f.title:SetPoint("TOPRIGHT", -8, -6)
    end
    if #list == 0 then
        local row = f.rows[1]
        WideRow(row, nil, f)
        row.name:SetText(f.empty or "")
        row.name:SetTextColor(style.muted[1], style.muted[2], style.muted[3])
        row:Show()
    end
end
local function WideWheel(self, delta)
    local most = max(0, #self.list - self.lineCount)
    local want = (self.offset or 0) - delta
    if most == 0 or want < 0 or want > most then
        if self.onWheel then self.onWheel(delta) end
        return
    end
    self.offset = want
    DrawWide(self)
end
function Badges.Wide(parent)
    local f = CreateFrame("Frame", nil, parent)
    Badges.Skin(f, style.detail)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", WideWheel)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 10, -6)
    f.title:SetPoint("TOPRIGHT", -8, -6)
    f.title:SetHeight(LINEH - 2)
    f.title:SetJustifyH("LEFT")
    f.title:SetJustifyV("TOP")
    f.title:SetWordWrap(false)
    f.more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.more:SetPoint("TOPRIGHT", -8, -6)
    f.head = CreateFrame("Frame", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(8 + LINEH * 2)
    f.head:SetScript("OnEnter", ShowLines)
    f.head:SetScript("OnLeave", HideTip)
    f.head:EnableMouse(false)
    f.probe = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.probe:Hide()
    f.header = NewWideRow(f, 0)
    f.list, f.rows, f.cols, f.heads = {}, {}, {}, {}
    f.lineCount = 0
    WideGrow(f, Badges.Lines())
    function f.SetModel(self, m)
        Badges.Skin(self, style.detail)
        self.title:SetText(m.title)
        self.head.lines = m.tip
        self.head:EnableMouse(m.tip ~= nil)
        self.list = m.rows or {}
        self.cols = m.cols or {}
        self.heads = m.heads or {}
        self.empty = m.empty
        self.onWheel = m.onWheel
        self.span = m.span
        self.offset = 0
        WideGrow(self, Badges.Lines())
        WideColumns(self)
        DrawWide(self)
    end
    function f.Layout(self, width)
        local lines = Badges.Lines()
        if lines ~= self.lineCount then
            WideGrow(self, lines)
            WideColumns(self)
            DrawWide(self)
        end
        local h = 14 + (max(1, min(lines, #self.list)) + 2) * LINEH
        self:SetWidth(width)
        self:SetHeight(h)
        return h
    end
    return f
end
if ns.Tip and ns.Tip.SetAvoid then ns.Tip.SetAvoid(function() return lit end) end
ns.Kit.OnTheme(function()
    for i = 1, #skinned do
        local f = skinned[i]
        f:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4] or 1)
        Edge(f, f.lit and style.link or style.edge)
    end
end)
