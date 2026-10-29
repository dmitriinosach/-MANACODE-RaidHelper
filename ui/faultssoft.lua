local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local concat = table.concat
local Kit = ns.Kit
local COLS = { { "who", 120 }, { "text", 0 }, { "time", 44 } }
local View = {}
ns.FaultsSoft = View
local box, head, list, empty, report, clear
local m = { bar = 26, rowh = 20 }
local function RowEnter(self)
    local lines = self.who and ns.FaultsRoll.SoftTip(self.who)
    if lines then ns.Tip.Show(self, lines) end
end
local function Wheel(d)
    if list:Wheel(d) then View.Paint() end
end
local function Row(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, d) Wheel(d) end)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", function() ns.Tip.Hide() end)
    r.cells = {}
    for i = 1, #COLS do
        local fs = Kit.Str(r, "GameFontHighlightSmall")
        fs:SetJustifyH(COLS[i][1] == "time" and "RIGHT" or "LEFT")
        fs:SetWordWrap(false)
        r.cells[COLS[i][1]] = fs
    end
    return r
end
local function Cells(r, width)
    local fixed = 0
    for i = 1, #COLS do fixed = fixed + Kit.FontGrow(COLS[i][2]) + 6 end
    local x = 4
    for i = 1, #COLS do
        local key, w = COLS[i][1], Kit.FontGrow(COLS[i][2])
        if w == 0 then w = max(Kit.FontGrow(80), width - fixed - 8) end
        local fs = r.cells[key]
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", r, "LEFT", x, 0)
        fs:SetWidth(w)
        x = x + w + 6
    end
end
local function Fill(r, e, k)
    r:ClearAllPoints()
    r:SetHeight(m.rowh)
    local y = m.bar + m.rowh * k
    r:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
    r:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -y)
    Cells(r, box:GetWidth() or 600)
    r.who = e.who
    local parts = {}
    for i = 1, #e.lines do parts[i] = e.lines[i].text end
    r.cells.who:SetText(e.who)
    local class = ns.Encounters and ns.Encounters.ClassOf(e.who)
    if class then Kit.ClassText(r.cells.who, class) else Kit.Text(r.cells.who, "text.primary") end
    r.cells.text:SetText(concat(parts, "; "))
    r.cells.time:SetText(date("%H:%M", e.t))
    Kit.Text(r.cells.time, "text.muted")
end
function View.Build(parent, btn)
    box = CreateFrame("Frame", nil, parent)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, d) Wheel(d) end)
    box.title = Kit.Str(box, "GameFontNormal")
    Kit.Text(box.title, "text.title")
    box.title:SetPoint("TOPLEFT", 0, -2)
    box.title:SetJustifyH("LEFT")
    report = btn(box, "HTP_FailWatchFaultsSoftReport", "main", function() ns.Soft.Report() end)
    report.tip = ns.T("soft.report.tip")
    clear = btn(box, "HTP_FailWatchFaultsSoftClear", "quiet", function() ns.Soft.Clear() end)
    clear.tip = ns.T("soft.clear.tip")
    head = Row(box)
    for i = 1, #COLS do
        local fs = head.cells[COLS[i][1]]
        fs:SetText(ns.T("soft.col." .. COLS[i][1]))
        Kit.Text(fs, "text.secondary")
    end
    empty = Kit.Str(box, "GameFontDisableSmall")
    Kit.Text(empty, "text.off")
    empty:SetJustifyH("LEFT")
    empty:SetText(ns.T("soft.empty"))
    list = Kit.List(function() return Row(box) end, Fill, { step = 3 })
    ns.Soft.OnChange(function() View.Paint() end)
    return box
end
local function Fit(b, text)
    b.text:SetText(text)
    b:SetWidth(max(Kit.FontGrow(60), floor(b.text:GetStringWidth() + 0.5) + 24))
end
function View.Place(bar, rowh, btnh)
    m.bar, m.rowh = bar, rowh
    if not box then return end
    head:ClearAllPoints()
    head:SetHeight(rowh)
    head:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -bar)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -bar)
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -(bar + rowh + 6))
    empty:SetPoint("RIGHT", box, "RIGHT", -4, 0)
    for _, b in ipairs({ report, clear }) do b:SetHeight(btnh) end
    Fit(report, ns.T("soft.report"))
    Fit(clear, ns.T("roll.clear"))
    report:ClearAllPoints()
    report:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    clear:ClearAllPoints()
    clear:SetPoint("RIGHT", report, "LEFT", -4, 0)
end
function View.Paint()
    if not box or not box:IsVisible() then return end
    local items = ns.Soft.List()
    box.title:SetText(format(ns.T("soft.title"), #items))
    Cells(head, box:GetWidth() or 600)
    local slots = max(1, floor(((box:GetHeight() or 300) - m.bar - m.rowh - 4) / m.rowh))
    list:Draw(items, slots)
    if min(slots, #items - list.offset) <= 0 then empty:Show() else empty:Hide() end
    if items[1] then
        report:Enable()
        clear:Enable()
    else
        report:Disable()
        clear:Disable()
    end
end
