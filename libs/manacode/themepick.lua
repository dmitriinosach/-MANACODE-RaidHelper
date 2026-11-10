local _, ns = ...
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ROW_H = 20
local PAD = 6
local CHIP = 8
local CHIP_H = 12
local GAP = 6
local CHECK_W = 14
local CHECK_GAP = 8
local TEXT = { 1, 1, 1, 1 }
local TEXT_ON = { 1, 0.82, 0, 1 }
local TEXT_OFF = { 0.5, 0.5, 0.5, 1 }
local HOVER = { 1, 1, 1, 0.08 }
local NONE = { 0, 0, 0, 0 }
local PLAIN = { 1, 1, 1, 1 }
local ThemePick = {}
ThemePick.__index = ThemePick
ns.ThemePick = ThemePick
local function Ask(self, role)
    if not self.opts.color then return nil end
    local r, g, b, a = self.opts.color(role)
    if not r then return nil end
    return r, g, b, a or 1
end
local function Color(self, role, dflt)
    local r, g, b, a = Ask(self, role)
    if r then return r, g, b, a end
    return dflt[1], dflt[2], dflt[3], dflt[4] or 1
end
local function State(row, base, dflt, hover, on)
    local self, it = row.mcPick, row.item
    local r, g, b, a
    if it.on then
        r, g, b, a = Ask(self, base .. "On")
        if not r and on then r, g, b, a = on[1], on[2], on[3], on[4] or 1 end
    end
    if not r and row.hovered and not it.disabled then
        r, g, b, a = Ask(self, base .. "Hover")
        if not r and hover then r, g, b, a = hover[1], hover[2], hover[3], hover[4] or 1 end
    end
    if not r then r, g, b, a = Ask(self, base) end
    if not r and dflt then r, g, b, a = dflt[1], dflt[2], dflt[3], dflt[4] or 1 end
    return r, g, b, a
end
local function RowH(self)
    local h = self.opts.rowH
    if type(h) == "function" then h = h() end
    return h or ROW_H
end
local function Paint(row)
    local self, it = row.mcPick, row.item
    local r, g, b, a = State(row, "fill", NONE, HOVER)
    if row.hl then
        row.hl:SetVertexColor(r, g, b, a)
    else
        local er, eg, eb, ea = State(row, "edge")
        if not er then
            local e = self.opts.edge or 1
            er, eg, eb, ea = min(1, r / e), min(1, g / e), min(1, b / e), a
        end
        row:SetBackdropColor(r, g, b, a)
        row:SetBackdropBorderColor(er, eg, eb, ea)
    end
    if it.disabled then
        row.label:SetTextColor(Color(self, "textOff", TEXT_OFF))
    else
        row.label:SetTextColor(State(row, "text", TEXT, nil, TEXT_ON))
    end
end
local function Enter(row)
    row.hovered = true
    Paint(row)
    local f = row.mcPick.opts.onEnter
    if f then f(row) end
end
local function Leave(row)
    row.hovered = false
    Paint(row)
    local f = row.mcPick.opts.onLeave
    if f then f(row) end
end
local function Click(row)
    local it = row.item
    local f = row.mcPick.opts.onPick
    if it and not it.disabled and f then f(it.key, it, row) end
end
local function Frame(self, row)
    local bd = self.opts.backdrop
    if type(bd) == "function" then bd = bd() end
    if bd then
        if row.mcBd ~= bd then
            row:SetBackdrop(bd)
            row.mcBd = bd
        end
    elseif not row.hl then
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetTexture(WHITE)
        row.hl:SetAllPoints(row)
    end
end
local function Build(self)
    local o = self.opts
    local row = CreateFrame("Button", nil, self.parent)
    row.mcPick = self
    local pad, chip, chipH = o.pad or PAD, o.chip or CHIP, o.chipH or CHIP_H
    row.rim = row:CreateTexture(nil, "ARTWORK")
    row.rim:SetTexture(WHITE)
    row.rim:SetWidth(chip * 4 + 2)
    row.rim:SetHeight(chipH + 2)
    row.rim:SetPoint("LEFT", row, "LEFT", pad, 0)
    row.chips = {}
    for k = 1, 4 do
        local t = row:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        t:SetWidth(chip)
        t:SetHeight(chipH)
        t:SetPoint("LEFT", row.rim, "LEFT", 1 + (k - 1) * chip, 0)
        row.chips[k] = t
    end
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetJustifyH("LEFT")
    row.label:SetPoint("LEFT", row.rim, "RIGHT", o.gap or GAP, 0)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetWidth(CHECK_W)
    row.check:SetHeight(CHECK_W)
    row.check:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    row:SetScript("OnClick", Click)
    return row
end
function ThemePick.New(parent, opts)
    return setmetatable({ parent = parent, opts = opts or {}, list = {}, top = 0 }, ThemePick)
end
function ThemePick:Draw(i, item)
    local row = self.list[i]
    if not row then
        row = Build(self)
        self.list[i] = row
        if i > self.top then self.top = i end
    end
    local o = self.opts
    row.item = item
    row:SetFrameLevel(self.parent:GetFrameLevel() + 1)
    Frame(self, row)
    for k = 1, 4 do
        local c, t = item.colors and item.colors[k], row.chips[k]
        if c then
            t:SetVertexColor(c[1], c[2], c[3], 1)
            t:Show()
        else
            t:Hide()
        end
    end
    local rr, rg, rb, ra = Ask(self, "rim")
    if rr then
        row.rim:SetVertexColor(rr, rg, rb, ra)
    else
        row.rim:SetVertexColor(0, 0, 0, 0)
    end
    local fs = row.label
    if o.text then
        o.text(fs, item.label or "")
    else
        fs:SetFontObject(GameFontHighlight)
        fs:SetText(item.label or "")
    end
    if item.on then
        local tex = o.check
        if type(tex) == "function" then tex = tex() end
        row.check:SetTexture(tex or CHECK)
        row.check:SetVertexColor(Color(self, "check", PLAIN))
        row.check:Show()
    else
        row.check:Hide()
    end
    local pad, chip = o.pad or PAD, o.chip or CHIP
    row.need = pad + chip * 4 + 2 + (o.gap or GAP) + ceil(fs:GetStringWidth() or 0) + CHECK_GAP + CHECK_W + pad
    row:SetHeight(RowH(self))
    row:Show()
    row.hovered = row:IsMouseOver() and true or false
    Paint(row)
    return row
end
function ThemePick:Hide(i)
    local row = self.list[i]
    if row then
        row:Hide()
        row.hovered = false
    end
end
function ThemePick:HideFrom(from)
    for i = from, self.top do self:Hide(i) end
end
function ThemePick:Need(n)
    local w = 0
    for i = 1, min(n, self.top) do
        local row = self.list[i]
        if row and row:IsShown() and row.need > w then w = row.need end
    end
    return w
end
function ThemePick:Fill(items, x, y, room, cols)
    local n = #items
    for i = 1, n do self:Draw(i, items[i]) end
    self:HideFrom(n + 1)
    if n == 0 then return 0, 0 end
    local o = self.opts
    local gx, gy = o.gapX or 0, o.gapY or 0
    local cw = max(self:Need(n), o.minW or 0)
    local per = 1
    if room then per = max(1, min(cols or n, n, floor((room + gx) / (cw + gx)))) end
    local lines = ceil(n / per)
    per = ceil(n / lines)
    local h = RowH(self)
    for i = 1, n do
        local row = self.list[i]
        local col, line = (i - 1) % per, floor((i - 1) / per)
        row:SetWidth(cw)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.parent, "TOPLEFT", x + col * (cw + gx), -(y + line * (h + gy)))
    end
    return per * cw + (per - 1) * gx, lines * h + (lines - 1) * gy
end
