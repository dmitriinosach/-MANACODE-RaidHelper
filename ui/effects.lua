local _, ns = ...
local format = string.format
local gsub = string.gsub
local max = math.max
local min = math.min
local floor = math.floor
local Kit = ns.Kit
local ROW = 18
local PAD = 8
local HEAD = 20
local SEARCHH = 22
local SEARCHPAD = 4
local COLH = 16
local GAP = 8
local SUBHEAD = 16
local BARW = 8
local MARKX = 2
local MARKW = 10
local ICONX = 14
local ICONSZ = 14
local TEXTX = 32
local COUNTW = 36
local NW = 30
local SHAREW = 34
local TEXTGAP = 4
local GROUPW = 108
local HIDDENSHARE = 0.32
local LISTMAX = 40
local HIDDENMAX = 24
local NBSP = "\194\160"
local TONE = {
    name = "fx.name",
    nameOff = "fx.nameOff",
    count = "fx.count",
    countOff = "fx.countOff",
    markOn = "fx.markOn",
    markOff = "fx.markOff",
    trashName = "fx.trashName",
    trashCount = "fx.trashCount",
    trashMark = "fx.trashMark",
    trashHead = "fx.trashHead",
    line = "fx.line",
}
local COL_KEY = { name = "fx.col.name", count = "fx.col.count", n = "fx.col.n", share = "fx.col.share" }
local Panel = {}
ns.EffectPanel = Panel
local frame, listBox, hiddenBox, listHead, hiddenHead, divider, groupBtn, colBox
local curWidth, fitKey = 0, nil
local listBar, hiddenBar
local search, searchHint
local listRows, hiddenRows, cols = {}, {}, {}
local listOffset, hiddenOffset = 0, 0
local listCount, hiddenCount = 14, 7
local query = ""
local tools = {}
local wanted, onTimeline = true, false
local srcFight = nil
local srcData = nil
local function Lower(text)
    local ru = ns.AutoInvite and ns.AutoInvite.Lower
    if ru then return ru(text) end
    return (strlower or string.lower)(text)
end
local function Ui()
    return ns.GetDB().settings.ui
end
local function SortKey()
    local s = Ui().fxSort
    return COL_KEY[s or ""] and s or "name"
end
local function Grouping()
    return Ui().fxGroup == true and srcData ~= nil
end
local function Filter(rows)
    if query == "" then return rows end
    local out = {}
    for i = 1, #rows do
        if not rows[i].head and Lower(rows[i].name):find(query, 1, true) then
            out[#out + 1] = rows[i]
        end
    end
    return out
end
local function Num(value)
    local text = format("%d", value)
    local done
    repeat
        text, done = gsub(text, "^(%d+)(%d%d%d)", "%1" .. NBSP .. "%2")
    until done == 0
    return text
end
local function Pct(share)
    if not share then return "" end
    return format("%d%%", floor(share * 100 + 0.5))
end
local function Tint(fs, tone)
    ns.Kit.Text(fs, tone)
end
local function PaintHead(row, item)
    row.id, row.name, row.tipLink, row.tipLines = nil, nil, nil, nil
    row.tipTitle = false
    row.mark:SetText("")
    row.icon:Hide()
    local text = item.name == "?" and ns.T("fx.src.none") or item.name
    if item.role then text = format(ns.T("fx.src.role"), text, ns.T("sum.tt.role." .. item.role)) end
    row.text:SetText(text)
    if item.class then ns.Kit.ClassText(row.text, item.class) else Tint(row.text, TONE.trashHead) end
    row.count:SetText(Num(item.count))
    Tint(row.count, TONE.countOff)
    row.n:SetText("")
    row.share:SetText("")
    row:Show()
end
local function Paint(row, item, hidden)
    if not item then
        row.id = nil
        row.name = nil
        row.tipTitle = nil
        row.tipLink = nil
        row.tipLines = nil
        row:Hide()
        return
    end
    if item.head then return PaintHead(row, item) end
    local cat = format(ns.T("fx.hint.cat"),
        ns.Effects.CategoryLabel(ns.Effects.Category(item.id)))
    row.text:SetText(item.name)
    row.count:SetText(Num(item.count))
    row.n:SetText(item.n and Num(item.n) or "")
    row.share:SetText(Pct(item.share))
    local lines = { cat }
    if item.n then lines[#lines + 1] = format(ns.T("fx.hint.use"), Num(item.n), Pct(item.share)) end
    if hidden then
        row.mark:SetText("x")
        Tint(row.mark, TONE.trashMark)
        Tint(row.text, TONE.trashName)
        Tint(row.count, TONE.trashCount)
        lines[#lines + 1] = ns.T("fx.hint.show")
    else
        row.mark:SetText("V")
        Tint(row.mark, TONE.markOn)
        Tint(row.text, TONE.name)
        Tint(row.count, TONE.count)
        lines[#lines + 1] = ns.T("fx.hint.toggle")
    end
    Tint(row.n, hidden and TONE.trashCount or TONE.count)
    Tint(row.share, hidden and TONE.trashCount or TONE.count)
    lines[#lines + 1] = ns.T("fx.hint.drag")
    row.tipLines = lines
    row.id = item.id
    row.name = item.name
    row.tipTitle = item.name
    row.tipLink = item.id and ("spell:" .. item.id) or nil
    local icon = ns.Effects.Icon(item.id)
    if icon then
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(hidden)
        row.icon:SetAlpha(hidden and 0.5 or 1)
        row.icon:Show()
    else
        row.icon:Hide()
    end
    row:Show()
end
local function PaintCols()
    local sort = SortKey()
    for key, b in pairs(cols) do
        b.on = key == sort
        ns.Kit.StyleRow(b)
    end
    if groupBtn then
        groupBtn.on = Ui().fxGroup == true
        groupBtn.text:SetText((groupBtn.on and "V " or "- ") .. ns.T("fx.col.group"))
        ns.Kit.StyleRow(groupBtn)
        if srcData then groupBtn:Show() else groupBtn:Hide() end
    end
end
function Panel.Refresh()
    if not frame then return end
    local sort = SortKey()
    local shownAll = ns.FxUse.Rows(srcFight, srcData, false, sort, Grouping())
    local hiddenAll = ns.FxUse.Rows(srcFight, srcData, true, sort, false)
    local list = Filter(shownAll)
    local hidden = Filter(hiddenAll)
    local effects = 0
    for i = 1, #shownAll do
        if not shownAll[i].head then effects = effects + 1 end
    end
    local total = effects + #hiddenAll
    if query ~= "" then
        listHead:SetText(format(ns.T("fx.head.found"), Num(#list + #hidden), Num(total)))
    elseif srcData then
        local dict = 0
        for _ in pairs(ns.Effects.Registry()) do dict = dict + 1 end
        listHead:SetText(format(ns.T("fx.head.who"), Num(total), Num(dict)))
    else
        listHead:SetText(format(ns.T("fx.head.list"), Num(effects), Num(total)))
    end
    hiddenHead:SetText(format(ns.T("fx.head.hidden"), Num(#hidden)))
    PaintCols()
    listOffset = max(0, min(listOffset, max(0, #list - listCount)))
    for i = 1, listCount do
        Paint(listRows[i], list[i + listOffset], false)
    end
    if listBar then listBar:SetState(listOffset, listCount, #list) end
    hiddenOffset = max(0, min(hiddenOffset, max(0, #hidden - hiddenCount)))
    for i = 1, hiddenCount do
        Paint(hiddenRows[i], hidden[i + hiddenOffset], true)
    end
    if hiddenBar then hiddenBar:SetState(hiddenOffset, hiddenCount, #hidden) end
end
local function WantUse()
    local fight = srcFight
    if fight and frame and frame:IsShown() and ns.FxUse.Peek(fight) == nil then
        ns.FxUse.Want(fight, function()
            if srcFight == fight then Panel.Refresh() end
        end)
    end
end
function Panel.SetSource(fight, who, data)
    srcFight, srcData = fight, data
    listOffset, hiddenOffset = 0, 0
    WantUse()
    Panel.Refresh()
end
local function DragBusy()
    return ns.FxDrag ~= nil and ns.FxDrag.Busy()
end
local function BindDrag(row)
    if not ns.FxDrag then return end
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnMouseDown", function()
        ns.FxDrag.Clear()
    end)
    row:SetScript("OnDragStart", function(self)
        if not self.id then return end
        GameTooltip:Hide()
        ns.FxDrag.Start(self.id, self.name, ns.Effects.Icon(self.id))
    end)
    row:SetScript("OnDragStop", function()
        ns.FxDrag.Stop()
    end)
end
local function Measure()
    local m = ns.Kit.Grow()
    local key = m.g .. ":" .. m.k
    if key == fitKey then return false end
    fitKey = key
    local g, k = m.g, m.k
    ROW, HEAD, SEARCHH, COLH, SUBHEAD = 18 + g, 20 + g, 22 + g, 16 + g, 16 + g
    MARKW = floor(10 * k + 0.5)
    ICONX = MARKX + MARKW + 2
    ICONSZ = 14 + g
    TEXTX = ICONX + ICONSZ + 4
    COUNTW, NW, SHAREW = floor(36 * k + 0.5), floor(30 * k + 0.5), floor(34 * k + 0.5)
    GROUPW = floor(108 * k + 0.5)
    return true
end
local function Column(parent, fs, right, width)
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
    fs:SetWidth(width)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
end
local function RowGeom(row, index, width)
    row:SetWidth(width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW))
    row:SetHeight(ROW)
    row.mark:SetWidth(MARKW)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", ICONX, 0)
    row.icon:SetWidth(ICONSZ)
    row.icon:SetHeight(ICONSZ)
    Column(row, row.count, BARW + SHAREW + NW, COUNTW)
    Column(row, row.n, BARW + SHAREW, NW)
    Column(row, row.share, BARW, SHAREW)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", TEXTX, 0)
    row.text:SetWidth(width - TEXTX - COUNTW - NW - SHAREW - BARW - TEXTGAP)
    row.text:SetHeight(ROW)
end
local function AttachRow(parent, index, width)
    local row = ns.MakeRowButton(parent, width)
    Kit.Bind(row.text, "GameFontHighlightSmall")
    row.mark = Kit.Str(row, "GameFontHighlightSmall")
    row.mark:SetPoint("LEFT", MARKX, 0)
    row.mark:SetJustifyH("CENTER")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = Kit.Str(row, "GameFontHighlightSmall")
    row.n = Kit.Str(row, "GameFontHighlightSmall")
    row.share = Kit.Str(row, "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    RowGeom(row, index, width)
    return row
end
local function PlaceCol(key, left, width)
    local b = cols[key]
    b:SetWidth(width)
    b:SetHeight(COLH)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", left, 0)
end
local function AttachCol(parent, key, left, width)
    local b = ns.Kit.Row(parent, width)
    Kit.Bind(b.text, "GameFontHighlightSmall")
    b:SetHeight(COLH)
    b:SetPoint("TOPLEFT", left, 0)
    b.text:SetText(ns.T(COL_KEY[key]))
    b.text:ClearAllPoints()
    if key == "name" then
        b.text:SetPoint("LEFT", 2, 0)
    else
        b.text:SetPoint("RIGHT", -2, 0)
        b.text:SetJustifyH("RIGHT")
    end
    b.tipTitle = ns.T(COL_KEY[key])
    b.tip = ns.T(COL_KEY[key] .. ".tip")
    b.tipAnchor = "ANCHOR_LEFT"
    b.onClick = function()
        Ui().fxSort = key ~= "name" and key or nil
        listOffset, hiddenOffset = 0, 0
        Panel.Refresh()
    end
    cols[key] = b
end
local function Geom(width)
    curWidth = width
    local inner = width - PAD * 2
    frame:SetWidth(width)
    groupBtn:SetWidth(GROUPW)
    groupBtn:SetHeight(HEAD - 4)
    search:ClearAllPoints()
    search:SetPoint("TOPLEFT", PAD, -HEAD)
    search:SetWidth(inner)
    search:SetHeight(SEARCHH - SEARCHPAD)
    colBox:ClearAllPoints()
    colBox:SetPoint("TOPLEFT", PAD, -(HEAD + SEARCHH))
    colBox:SetWidth(inner)
    colBox:SetHeight(COLH)
    local right = inner - BARW
    PlaceCol("share", right - SHAREW, SHAREW)
    PlaceCol("n", right - SHAREW - NW, NW)
    PlaceCol("count", right - SHAREW - NW - COUNTW, COUNTW)
    PlaceCol("name", TEXTX - 2, right - SHAREW - NW - COUNTW - TEXTX + 2)
    listBox:ClearAllPoints()
    listBox:SetPoint("TOPLEFT", PAD, -(HEAD + SEARCHH + COLH))
    listBox:SetWidth(inner)
    hiddenBox:SetWidth(inner)
    for i = 1, #listRows do RowGeom(listRows[i], i, inner) end
    for i = 1, #hiddenRows do RowGeom(hiddenRows[i], i, inner) end
end
function Panel.Attach(parent, width)
    if frame then return frame end
    local inner = width - PAD * 2
    Measure()
    frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "surface.panel")
    listHead = Kit.Str(frame, "GameFontNormalSmall")
    listHead:SetPoint("TOPLEFT", PAD, -4)
    groupBtn = ns.Kit.Row(frame, GROUPW)
    Kit.Bind(groupBtn.text, "GameFontHighlightSmall")
    groupBtn:SetHeight(HEAD - 4)
    groupBtn:SetPoint("TOPRIGHT", -PAD, -2)
    groupBtn.text:ClearAllPoints()
    groupBtn.text:SetPoint("RIGHT", -2, 0)
    groupBtn.text:SetJustifyH("RIGHT")
    groupBtn.tipTitle = ns.T("fx.col.group")
    groupBtn.tip = ns.T("fx.col.group.tip")
    groupBtn.tipAnchor = "ANCHOR_LEFT"
    groupBtn.onClick = function()
        Ui().fxGroup = not Ui().fxGroup or nil
        listOffset = 0
        Panel.Refresh()
    end
    search = ns.Kit.Edit(frame, false, "HTP_FailWatchFxSearch")
    search:SetPoint("TOPLEFT", PAD, -HEAD)
    search:SetWidth(inner)
    search:SetHeight(SEARCHH - SEARCHPAD)
    search:SetMaxLetters(40)
    search:SetFontObject(Kit.FontFor("GameFontHighlightSmall", true))
    searchHint = Kit.Str(search, "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", 7, 0)
    searchHint:SetText(ns.T("fx.search.hint"))
    search:SetScript("OnTextChanged", function(self)
        query = Lower(self:GetText() or "")
        if query == "" then searchHint:Show() else searchHint:Hide() end
        listOffset, hiddenOffset = 0, 0
        Panel.Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    search.tipTitle, search.tip = ns.T("fx.search.hint"), ns.T("fx.search.tip")
    search.tipTone, search.tipAnchor = "text.secondary", "ANCHOR_LEFT"
    colBox = CreateFrame("Frame", nil, frame)
    colBox:SetPoint("TOPLEFT", PAD, -(HEAD + SEARCHH))
    colBox:SetWidth(inner)
    colBox:SetHeight(COLH)
    local right = inner - BARW
    AttachCol(colBox, "share", right - SHAREW, SHAREW)
    AttachCol(colBox, "n", right - SHAREW - NW, NW)
    AttachCol(colBox, "count", right - SHAREW - NW - COUNTW, COUNTW)
    AttachCol(colBox, "name", TEXTX - 2, right - SHAREW - NW - COUNTW - TEXTX + 2)
    listBox = CreateFrame("Frame", nil, frame)
    listBox:SetPoint("TOPLEFT", PAD, -(HEAD + SEARCHH + COLH))
    listBox:SetWidth(inner)
    listBox:EnableMouseWheel(true)
    listBox:SetScript("OnMouseWheel", function(_, delta)
        listOffset = listOffset - delta * 3
        Panel.Refresh()
    end)
    if ns.MakeScrollBar then
        listBar = ns.MakeScrollBar(frame, listCount * ROW)
        listBar.onScroll = function(offset)
            listOffset = offset
            Panel.Refresh()
        end
    end
    local function Setter(on)
        return function(self)
            if not self.id or DragBusy() then return end
            ns.Effects.Set(self.id, on and "on" or "off")
            Panel.Refresh()
            if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
        end
    end
    for i = 1, LISTMAX do
        local row = AttachRow(listBox, i, inner)
        row.onClick = Setter(false)
        row.onRightClick = row.onClick
        BindDrag(row)
        listRows[i] = row
    end
    divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    ns.Kit.Paint(divider, TONE.line)
    hiddenHead = Kit.Str(frame, "GameFontNormalSmall")
    Tint(hiddenHead, TONE.trashHead)
    hiddenBox = CreateFrame("Frame", nil, frame)
    hiddenBox:SetWidth(inner)
    hiddenBox:EnableMouseWheel(true)
    hiddenBox:SetScript("OnMouseWheel", function(_, delta)
        hiddenOffset = hiddenOffset - delta * 3
        Panel.Refresh()
    end)
    if ns.MakeScrollBar then
        hiddenBar = ns.MakeScrollBar(frame, hiddenCount * ROW)
        hiddenBar.onScroll = function(offset)
            hiddenOffset = offset
            Panel.Refresh()
        end
    end
    for i = 1, HIDDENMAX do
        local row = AttachRow(hiddenBox, i, inner)
        row.onClick = Setter(true)
        row.onRightClick = row.onClick
        BindDrag(row)
        hiddenRows[i] = row
    end
    Geom(width)
    return frame
end
local function Apply()
    for i = 1, #tools do
        if onTimeline then tools[i]:Show() else tools[i]:Hide() end
    end
    if not frame then return end
    if onTimeline and wanted then frame:Show() else frame:Hide() end
    WantUse()
end
function Panel.SetShown(show)
    wanted = show and true or false
    Apply()
end
function Panel.BindTools(...)
    tools = { ... }
    Apply()
end
function Panel.SetTimeline(on)
    onTimeline = on and true or false
    Apply()
end
function Panel.IsShown()
    return frame ~= nil and frame:IsShown()
end
function Panel.Layout(height, width)
    if not frame then return end
    local fresh = Measure()
    if fresh or (width and width ~= curWidth) then Geom(width or curWidth) end
    frame:SetHeight(height)
    local budget = height - HEAD - SEARCHH - COLH - GAP - SUBHEAD - PAD
    hiddenCount = max(3, min(HIDDENMAX, floor(budget * HIDDENSHARE / ROW)))
    listCount = max(4, min(LISTMAX, floor((budget - hiddenCount * ROW) / ROW)))
    listBox:SetHeight(listCount * ROW)
    local listBottom = HEAD + SEARCHH + COLH + listCount * ROW
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", PAD, -(listBottom + floor(GAP / 2)))
    divider:SetPoint("TOPRIGHT", -PAD, -(listBottom + floor(GAP / 2)))
    hiddenHead:ClearAllPoints()
    hiddenHead:SetPoint("TOPLEFT", PAD, -(listBottom + GAP))
    hiddenBox:ClearAllPoints()
    hiddenBox:SetPoint("TOPLEFT", PAD, -(listBottom + GAP + SUBHEAD))
    hiddenBox:SetHeight(hiddenCount * ROW)
    if listBar then
        listBar:SetHeight(listCount * ROW)
        listBar:ClearAllPoints()
        listBar:SetPoint("TOPRIGHT", listBox, "TOPRIGHT", 0, 0)
    end
    if hiddenBar then
        hiddenBar:SetHeight(hiddenCount * ROW)
        hiddenBar:ClearAllPoints()
        hiddenBar:SetPoint("TOPRIGHT", hiddenBox, "TOPRIGHT", 0, 0)
    end
    for i = listCount + 1, #listRows do listRows[i]:Hide() end
    for i = hiddenCount + 1, #hiddenRows do hiddenRows[i]:Hide() end
    Panel.Refresh()
end
