local _, ns = ...
local Kit = ns.Kit
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local INSET, GAP = 3, 1
local CELL_H, CELL_PAD, CELL_MIN = 18, 8, 28
local all = {}
local function Paint(s)
    Kit.Backdrop(s, Kit.Theme().edit)
end
local function CellClick(self)
    local s = self:GetParent()
    s:Select(self.segKey)
    if s.onPick then s.onPick(self.segKey) end
end
local function Select(self, key)
    self.value = key
    for i = 1, self.n do
        local c = self.cells[i]
        c:SetActive(c.segKey == key)
    end
end
local function SetCells(self, list, value)
    self.n = #list
    for i = 1, #list do
        local c = self.cells[i]
        if not c then
            c = Kit.Button(self, nil, "quiet")
            c:SetHeight(CELL_H)
            c.onClick = CellClick
            self.cells[i] = c
        end
        local e = list[i]
        c.segKey = e.key
        c:SetText(e.label or tostring(e.key))
        c.tipTitle = e.tip and (e.label or tostring(e.key)) or false
        c.tip = e.tip
        if e.disabled then c:Disable() else c:Enable() end
        c:Show()
    end
    for i = #list + 1, #self.cells do self.cells[i]:Hide() end
    Select(self, value)
end
local function Measure(self, maxW)
    local n = max(1, self.n)
    local cw = CELL_MIN
    for i = 1, self.n do cw = max(cw, ceil(self.cells[i].text:GetStringWidth() or 0) + CELL_PAD * 2) end
    local cols = max(1, min(n, floor((maxW - INSET * 2 + GAP) / (cw + GAP))))
    local rows = ceil(n / cols)
    cols = ceil(n / rows)
    self.cols, self.rows = cols, rows
    local ch = self.n > 0 and self.cells[1]:GetHeight() or CELL_H
    self:SetHeight(rows * ch + (rows - 1) * GAP + INSET * 2)
    return cols * cw + (cols - 1) * GAP + INSET * 2
end
local function Place(self, w)
    self:SetWidth(w)
    local cols = self.cols or self.n
    local inner = w - INSET * 2 - (cols - 1) * GAP
    local cw = floor(inner / cols)
    local ch = self.n > 0 and self.cells[1]:GetHeight() or CELL_H
    for i = 1, self.n do
        local c = self.cells[i]
        local col, row = (i - 1) % cols, floor((i - 1) / cols)
        c:SetWidth(col == cols - 1 and inner - cw * (cols - 1) or cw)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", INSET + col * (cw + GAP), -(INSET + row * (ch + GAP)))
    end
end
local function Layout(self, maxW)
    Place(self, Measure(self, maxW))
end
function Kit.Segments(parent, onPick)
    local s = CreateFrame("Frame", nil, parent)
    s.cells, s.n = {}, 0
    s.onPick = onPick
    s.SetCells, s.Select, s.Measure, s.Place, s.Layout = SetCells, Select, Measure, Place, Layout
    Paint(s)
    all[#all + 1] = s
    return s
end
Kit.OnTheme(function()
    for i = 1, #all do Paint(all[i]) end
end)
