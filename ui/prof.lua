local _, ns = ...
local format = string.format
local max = math.max
local UPDATE_PERIOD = 0.5
local PAD = 12
local ROW = 16
local HEAD = 74
local SPIKE = 0.1
local FOOT = 40
local COLUMNS = {
    { key = "prof.col.stage", w = 210 },
    { key = "prof.col.calls", w = 70, right = true },
    { key = "prof.col.last", w = 80, right = true },
    { key = "prof.col.avg", w = 80, right = true },
    { key = "prof.col.max", w = 80, right = true },
    { key = "prof.col.total", w = 90, right = true },
    { key = "prof.col.rate", w = 90, right = true },
    { key = "prof.col.items", w = 90, right = true },
}
local STAGES = {
    "hot.log",
    "hot.rec",
    "rec.snap",
    "hot.aura",
    "hot.rng",
    "hot.realm",
    "hot.comm",
    "hot.panel",
    "hot.bg",
    "ui.page",
    "ui.click",
    "ui.tl",
    "ui.iso",
    "ui.sum",
    "ui.other",
    "scan.frame",
    "idx.frame",
    "tl.data",
    "tl.rows",
    "tl.draw",
    "map.data",
    "sum.frame",
    "tl.layout",
    "fx.layout",
    "iso.data",
    "iso.frame",
    "prev.data",
    "prev.draw",
    "prev.map",
}
local View = {}
ns.ProfView = View
local frame
local headText
local cells = {}
local startedAt = 0
local acc = 0
local spikeText
local lastMem = 0
local worst = nil
local function Width()
    local w = PAD * 2
    for i = 1, #COLUMNS do w = w + COLUMNS[i].w end
    return w
end
local function Cell(line, col)
    cells[line] = cells[line] or {}
    local fs = cells[line][col]
    if fs then return fs end
    fs = frame:CreateFontString(nil, "OVERLAY", line == 0 and "GameFontNormalSmall"
        or "GameFontHighlightSmall")
    local x = PAD
    for i = 1, col - 1 do x = x + COLUMNS[i].w end
    local c = COLUMNS[col]
    fs:SetWidth(c.w - 6)
    fs:SetJustifyH(c.right and "RIGHT" or "LEFT")
    fs:SetPoint("TOPLEFT", x, -(HEAD + line * ROW))
    cells[line][col] = fs
    return fs
end
local function Ms(ms)
    if ms >= 100 then return format("%.0f", ms) end
    if ms >= 1 then return format("%.1f", ms) end
    return format("%.2f", ms)
end
local function Refresh()
    local elapsed = max(0.001, GetTime() - startedAt)
    headText:SetText(format(ns.T("prof.head"), GetFramerate(),
        collectgarbage("count") / 1024, elapsed))
    if worst then
        spikeText:SetText(format(ns.T("prof.spike"), worst.ms, worst.before / 1024,
            worst.after / 1024, worst.ago and (GetTime() - worst.ago) or 0))
    else
        spikeText:SetText(ns.T("prof.nospike"))
    end
    for line = 1, #STAGES do
        local key = STAGES[line]
        local r = ns.Prof.rows[key]
        Cell(line, 1):SetText(ns.T("prof." .. key))
        if r and r.n > 0 then
            Cell(line, 2):SetText(ns.Num(r.n))
            Cell(line, 3):SetText(Ms(r.last))
            Cell(line, 4):SetText(Ms(r.ms / r.n))
            Cell(line, 5):SetText(Ms(r.max))
            Cell(line, 6):SetText(Ms(r.ms))
            Cell(line, 7):SetText(Ms(r.ms / elapsed))
            Cell(line, 8):SetText(r.items > 0 and ns.Num(r.items) or "")
            local hot = r.max >= 50
            ns.Kit.Tone(Cell(line, 5), hot and "text.bad" or "text.bright")
        else
            for col = 2, #COLUMNS do Cell(line, col):SetText("") end
        end
    end
end
local function Reset()
    ns.Prof.Reset()
    worst = nil
    lastMem = collectgarbage("count")
    startedAt = GetTime()
    Refresh()
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchProf", UIParent)
    frame:SetWidth(Width())
    frame:SetHeight(HEAD + (#STAGES + 1) * ROW + FOOT)
    frame:SetFrameStrata("DIALOG")
    ns.Kit.Window(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local ui = ns.GetDB().settings.ui
        ui.profPoint, ui.profX, ui.profY = point, x, y
    end)
    local ui = ns.GetDB().settings.ui
    frame:SetPoint(ui.profPoint or "CENTER", UIParent, ui.profPoint or "CENTER",
        ui.profX or 0, ui.profY or 0)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -12)
    title:SetText(ns.T("prof.title"))
    ns.Kit.Title(title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() View.Hide() end)
    headText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(headText, "text.bright")
    headText:SetPoint("TOPLEFT", PAD, -32)
    headText:SetJustifyH("LEFT")
    spikeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(spikeText, "text.bright")
    spikeText:SetPoint("TOPLEFT", PAD, -48)
    spikeText:SetJustifyH("LEFT")
    for col = 1, #COLUMNS do
        Cell(0, col):SetText(ns.T(COLUMNS[col].key))
    end
    local reset = ns.MakeButton(frame, "HTP_FailWatchProfReset")
    reset:SetWidth(110)
    reset:SetHeight(22)
    reset:SetPoint("BOTTOMLEFT", PAD - 2, 10)
    reset.text:SetText(ns.T("prof.btn.reset"))
    reset.onClick = Reset
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.Kit.Text(hint, "text.off")
    hint:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(ns.T("prof.hint"))
    frame:SetScript("OnUpdate", function(_, elapsed)
        local mem = collectgarbage("count")
        if elapsed >= SPIKE and (not worst or elapsed * 1000 > worst.ms) then
            worst = { ms = elapsed * 1000, before = lastMem, after = mem, ago = GetTime() }
        end
        lastMem = mem
        acc = acc + elapsed
        if acc < UPDATE_PERIOD then return end
        acc = 0
        Refresh()
    end)
    frame:SetScript("OnHide", function() ns.Prof.on = false end)
end
function View.Show()
    if not frame then Build() end
    ns.Prof.on = true
    frame:Show()
    Reset()
end
function View.Hide()
    if frame then frame:Hide() end
    ns.Prof.on = false
end
function View.Toggle()
    if frame and frame:IsShown() then View.Hide() else View.Show() end
end
