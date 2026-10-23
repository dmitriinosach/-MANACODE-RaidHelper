local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Kit = ns.Kit
local GAP = 16
local PEN_COLS = { { "who", 0 }, { "n", 60 } }
local ROLL_COLS = { { "who", 0 }, { "n", 54 }, { "pen", 54 }, { "net", 54 } }
local View = {}
ns.FaultsRoll = View
local box, pens, rolls
local m = { bar = 26, rowh = 20, btnh = 20 }
local where = {}
local function Row(parent, cols, wheel)
    local r = CreateFrame("Frame", nil, parent)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, d) wheel(d) end)
    r.cells = {}
    for i = 1, #cols do
        local fs = Kit.Str(r, "GameFontHighlightSmall")
        fs:SetJustifyH(cols[i][1] == "who" and "LEFT" or "RIGHT")
        fs:SetWordWrap(false)
        r.cells[cols[i][1]] = fs
    end
    return r
end
local function Cells(r, cols, width)
    local fixed = 0
    for i = 1, #cols do fixed = fixed + Kit.FontGrow(cols[i][2]) + 6 end
    local x = 4
    for i = 1, #cols do
        local key, w = cols[i][1], Kit.FontGrow(cols[i][2])
        if w == 0 then w = max(Kit.FontGrow(60), width - fixed - 8) end
        local fs = r.cells[key]
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", r, "LEFT", x, 0)
        fs:SetWidth(w)
        x = x + w + 6
    end
end
local function Put(side, r, k)
    r:ClearAllPoints()
    r:SetHeight(m.rowh)
    local y = side.top + m.rowh * k
    r:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -y)
    r:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, -y)
end
local function Minus(n)
    return n > 0 and format(ns.T("roll.minus"), n) or "0"
end
local function FillPen(r, item, k)
    Put(pens, r, k)
    Cells(r, PEN_COLS, pens:GetWidth() or 200)
    r.cells.who:SetText(item.who)
    r.cells.n:SetText(Minus(item.n))
    Kit.Text(r.cells.n, "text.bad")
end
local function FillRoll(r, t, k)
    Put(rolls, r, k)
    Cells(r, ROLL_COLS, rolls:GetWidth() or 300)
    r.cells.who:SetText(t.who)
    r.cells.n:SetText(t.hi ~= 100 and format(ns.T("roll.range"), t.n, t.lo, t.hi) or tostring(t.n))
    r.cells.pen:SetText(Minus(t.pen or 0))
    r.cells.net:SetText(tostring(t.net or t.n))
    Kit.Text(r.cells.pen, (t.pen or 0) > 0 and "text.bad" or "text.muted")
    Kit.Text(r.cells.net, k == 1 and rolls.list.offset == 0 and "text.good" or "text.bright")
end
local function Head(side, cols, prefix)
    side.head = Row(side, cols, function() end)
    for i = 1, #cols do
        local fs = side.head.cells[cols[i][1]]
        fs:SetText(ns.T(prefix .. cols[i][1]))
        Kit.Text(fs, "text.secondary")
    end
    side.empty = Kit.Str(side, "GameFontDisableSmall")
    Kit.Text(side.empty, "text.off")
    side.empty:SetJustifyH("LEFT")
end
local function Wheel(side, d)
    if side.list:Wheel(d) then View.Paint() end
end
function View.Build(parent, btn)
    box = CreateFrame("Frame", nil, parent)
    box.title = Kit.Str(box, "GameFontNormal")
    Kit.Text(box.title, "text.title")
    box.title:SetPoint("TOPLEFT", 0, -2)
    box.title:SetJustifyH("LEFT")
    box.state = Kit.Str(box, "GameFontHighlightSmall")
    box.state:SetPoint("TOPRIGHT", 0, -4)
    box.state:SetJustifyH("RIGHT")
    pens = CreateFrame("Frame", nil, box)
    pens:EnableMouseWheel(true)
    pens:SetScript("OnMouseWheel", function(_, d) Wheel(pens, d) end)
    pens.cap = Kit.Str(pens, "GameFontNormalSmall")
    Kit.Text(pens.cap, "text.title")
    pens.cap:SetPoint("TOPLEFT", 0, 0)
    Head(pens, PEN_COLS, "roll.col.")
    pens.empty:SetText(ns.T("roll.pens.empty"))
    pens.list = Kit.List(function() return Row(pens, PEN_COLS, function(d) Wheel(pens, d) end) end, FillPen, { step = 3 })
    rolls = CreateFrame("Frame", nil, box)
    rolls:EnableMouseWheel(true)
    rolls:SetScript("OnMouseWheel", function(_, d) Wheel(rolls, d) end)
    rolls.cap = Kit.Str(rolls, "GameFontNormalSmall")
    Kit.Text(rolls.cap, "text.title")
    rolls.cap:SetPoint("TOPLEFT", 0, 0)
    rolls.report = btn(rolls, "HTP_FailWatchFaultsRollReport", "main", function()
        ns.RollPen.Report(where.raid, where.alt)
    end)
    rolls.report.tip = ns.T("roll.report.tip")
    rolls.clear = btn(rolls, "HTP_FailWatchFaultsRollClear", "quiet", function() ns.RollPen.Clear() end)
    rolls.clear.tip = ns.T("roll.clear.tip")
    Head(rolls, ROLL_COLS, "roll.col.")
    rolls.list = Kit.List(function() return Row(rolls, ROLL_COLS, function(d) Wheel(rolls, d) end) end, FillRoll, { step = 3 })
    ns.RollPen.OnChange(function() View.Paint() end)
    return box
end
local function Fit(b, text)
    b.text:SetText(text)
    b:SetWidth(max(Kit.FontGrow(60), floor(b.text:GetStringWidth() + 0.5) + 24))
end
function View.Place(bar, rowh, btnh)
    m.bar, m.rowh, m.btnh = bar, rowh, btnh
    if not box then return end
    local w = box:GetWidth() or 600
    local left = floor((w - GAP) * 0.4)
    pens:ClearAllPoints()
    pens:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -bar)
    pens:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
    pens:SetWidth(left)
    rolls:ClearAllPoints()
    rolls:SetPoint("TOPLEFT", box, "TOPLEFT", left + GAP, -bar)
    rolls:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    for _, side in ipairs({ pens, rolls }) do
        side.top = bar
        side.head:ClearAllPoints()
        side.head:SetHeight(rowh)
        side.head:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -side.top)
        side.head:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, -side.top)
        side.empty:ClearAllPoints()
        side.empty:SetPoint("TOPLEFT", side, "TOPLEFT", 4, -(side.top + rowh + 6))
        side.empty:SetPoint("RIGHT", side, "RIGHT", -4, 0)
    end
    for _, b in ipairs({ rolls.report, rolls.clear }) do b:SetHeight(btnh) end
    Fit(rolls.report, ns.T("roll.report"))
    Fit(rolls.clear, ns.T("roll.clear"))
    rolls.report:ClearAllPoints()
    rolls.report:SetPoint("TOPRIGHT", rolls, "TOPRIGHT", 0, 2)
    rolls.clear:ClearAllPoints()
    rolls.clear:SetPoint("RIGHT", rolls.report, "LEFT", -4, 0)
end
local function Draw(side, items, cols)
    Cells(side.head, cols, side:GetWidth() or 200)
    local slots = max(1, floor(((side:GetHeight() or 300) - side.top - m.rowh - 4) / m.rowh))
    side.list:Draw(items, slots)
    if min(slots, #items - side.list.offset) <= 0 then side.empty:Show() else side.empty:Hide() end
end
function View.Paint(raid, label, alt)
    if not box or not box:IsVisible() then return end
    if label then where.raid, where.label, where.alt = raid, label, alt end
    box.title:SetText(format(ns.T("roll.title"), where.label or ""))
    local on = ns.RollPen.Listening()
    box.state:SetText(on and ns.T("roll.on") or format(ns.T("roll.off"), ns.Ledger.Label("roll")))
    Kit.Text(box.state, on and "text.good" or "text.muted")
    local pen, sum = ns.RollPen.List(where.raid, where.alt), 0
    for i = 1, #pen do sum = sum + pen[i].n end
    pens.cap:SetText(format(ns.T("roll.pens"), sum))
    Draw(pens, pen, PEN_COLS)
    local list = ns.RollPen.Throws(where.raid, where.alt)
    rolls.cap:SetText(format(ns.T("roll.throws"), #list))
    rolls.empty:SetText(ns.T(on and "roll.throws.empty" or "roll.throws.off"))
    Draw(rolls, list, ROLL_COLS)
    if list[1] then rolls.report:Enable() else rolls.report:Disable() end
    if list[1] then rolls.clear:Enable() else rolls.clear:Disable() end
end
