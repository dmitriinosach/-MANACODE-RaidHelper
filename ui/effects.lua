local _, ns = ...
local format = string.format
local gsub = string.gsub
local max = math.max
local min = math.min
local floor = math.floor
local ROW = 18
local PAD = 8
local HEAD = 20
local SEARCHH = 22
local SEARCHPAD = 4
local GAP = 8
local SUBHEAD = 16
local BARW = 8
local MARKX = 2
local MARKW = 10
local ICONX = 14
local ICONSZ = 14
local TEXTX = 32
local COUNTW = 42
local TEXTGAP = 4
local TRASHSHARE = 0.32
local LISTMAX = 40
local TRASHMAX = 24
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
local Panel = {}
ns.EffectPanel = Panel
local frame, listBox, trashBox, listHead, trashHead, divider
local listBar, trashBar
local search, searchHint
local listRows, trashRows = {}, {}
local listOffset, trashOffset = 0, 0
local listCount, trashCount = 14, 7
local query = ""
local tools = {}
local wanted, onTimeline = true, false
local function Lower(text)
    return (strlower or string.lower)(text)
end
local function Filter(rows)
    if query == "" then return rows end
    local out = {}
    for i = 1, #rows do
        if Lower(rows[i].name):find(query, 1, true) then
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
local function Tint(fs, tone)
    ns.Kit.Text(fs, tone)
end
local function Paint(row, item, trash)
    if not item then
        row.id = nil
        row.name = nil
        row.tipTitle = nil
        row.tipLink = nil
        row.tipLines = nil
        row:Hide()
        return
    end
    local on = item.state == "on"
    local cat = format(ns.T("fx.hint.cat"),
        ns.Effects.CategoryLabel(ns.Effects.Category(item.id)))
    row.text:SetText(item.name)
    row.count:SetText(Num(item.count))
    if trash then
        row.mark:SetText("x")
        Tint(row.mark, TONE.trashMark)
        Tint(row.text, TONE.trashName)
        Tint(row.count, TONE.trashCount)
        row.tipLines = { cat, ns.T("fx.hint.restore"), ns.T("fx.hint.drag") }
    else
        row.mark:SetText(on and "V" or "-")
        Tint(row.mark, on and TONE.markOn or TONE.markOff)
        Tint(row.text, on and TONE.name or TONE.nameOff)
        Tint(row.count, on and TONE.count or TONE.countOff)
        row.tipLines = { cat, ns.T("fx.hint.toggle"), ns.T("fx.hint.trash"),
            ns.T("fx.hint.drag") }
    end
    row.id = item.id
    row.name = item.name
    row.tipTitle = item.name
    row.tipLink = item.id and ("spell:" .. item.id) or nil
    local icon = ns.Effects.Icon(item.id)
    if icon then
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(trash or not on)
        row.icon:SetAlpha(trash and 0.5 or (on and 1 or 0.6))
        row.icon:Show()
    else
        row.icon:Hide()
    end
    row:Show()
end
function Panel.Refresh()
    if not frame then return end
    local all = ns.Effects.List()
    local list = Filter(all)
    local shown, trashed = ns.Effects.Counts()
    if query == "" then
        listHead:SetText(format(ns.T("fx.head.list"), Num(shown), Num(#all)))
    else
        listHead:SetText(format(ns.T("fx.head.found"), Num(#list), Num(#all)))
    end
    trashHead:SetText(format(ns.T("fx.head.trash"), Num(trashed)))
    listOffset = max(0, min(listOffset, max(0, #list - listCount)))
    for i = 1, listCount do
        Paint(listRows[i], list[i + listOffset], false)
    end
    if listBar then listBar:SetState(listOffset, listCount, #list) end
    local trash = Filter(ns.Effects.Trash())
    trashOffset = max(0, min(trashOffset, max(0, #trash - trashCount)))
    for i = 1, trashCount do
        Paint(trashRows[i], trash[i + trashOffset], true)
    end
    if trashBar then trashBar:SetState(trashOffset, trashCount, #trash) end
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
local function AttachRow(parent, index, width)
    local row = ns.MakeRowButton(parent, width)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW))
    row:SetHeight(ROW)
    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.mark:SetPoint("LEFT", MARKX, 0)
    row.mark:SetWidth(MARKW)
    row.mark:SetJustifyH("CENTER")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", ICONX, 0)
    row.icon:SetWidth(ICONSZ)
    row.icon:SetHeight(ICONSZ)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -BARW, 0)
    row.count:SetWidth(COUNTW)
    row.count:SetHeight(ROW)
    row.count:SetJustifyH("RIGHT")
    row.count:SetWordWrap(false)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", TEXTX, 0)
    row.text:SetWidth(width - TEXTX - COUNTW - BARW - TEXTGAP)
    row.text:SetHeight(ROW)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    return row
end
function Panel.Attach(parent, width)
    if frame then return frame end
    local inner = width - PAD * 2
    frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "surface.panel")
    listHead = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listHead:SetPoint("TOPLEFT", PAD, -4)
    search = ns.Kit.Edit(frame, false, "HTP_FailWatchFxSearch")
    search:SetPoint("TOPLEFT", PAD, -HEAD)
    search:SetWidth(inner)
    search:SetHeight(SEARCHH - SEARCHPAD)
    search:SetMaxLetters(40)
    search:SetFontObject("GameFontHighlightSmall")
    searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", 7, 0)
    searchHint:SetText(ns.T("fx.search.hint"))
    search:SetScript("OnTextChanged", function(self)
        query = Lower(self:GetText() or "")
        if query == "" then searchHint:Show() else searchHint:Hide() end
        listOffset, trashOffset = 0, 0
        Panel.Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.T("fx.search.hint"))
        ns.Kit.TipAdd(ns.T("fx.search.tip"), "text.secondary")
        GameTooltip:Show()
    end)
    search:SetScript("OnLeave", function() GameTooltip:Hide() end)
    listBox = CreateFrame("Frame", nil, frame)
    listBox:SetPoint("TOPLEFT", PAD, -(HEAD + SEARCHH))
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
    for i = 1, LISTMAX do
        local row = AttachRow(listBox, i, inner)
        row.onClick = function(self)
            if not self.id or DragBusy() then return end
            ns.Effects.Toggle(self.id)
            Panel.Refresh()
            if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
        end
        row.onRightClick = function(self)
            if not self.id then return end
            ns.Effects.Set(self.id, "trash")
            Panel.Refresh()
            if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
        end
        BindDrag(row)
        listRows[i] = row
    end
    divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    ns.Kit.Paint(divider, TONE.line)
    trashHead = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Tint(trashHead, TONE.trashHead)
    trashBox = CreateFrame("Frame", nil, frame)
    trashBox:SetWidth(inner)
    trashBox:EnableMouseWheel(true)
    trashBox:SetScript("OnMouseWheel", function(_, delta)
        trashOffset = trashOffset - delta * 3
        Panel.Refresh()
    end)
    if ns.MakeScrollBar then
        trashBar = ns.MakeScrollBar(frame, trashCount * ROW)
        trashBar.onScroll = function(offset)
            trashOffset = offset
            Panel.Refresh()
        end
    end
    for i = 1, TRASHMAX do
        local row = AttachRow(trashBox, i, inner)
        row.onClick = function(self)
            if not self.id or DragBusy() then return end
            ns.Effects.Set(self.id, "off")
            Panel.Refresh()
            if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
        end
        row.onRightClick = row.onClick
        BindDrag(row)
        trashRows[i] = row
    end
    return frame
end
local function Apply()
    for i = 1, #tools do
        if onTimeline then tools[i]:Show() else tools[i]:Hide() end
    end
    if not frame then return end
    if onTimeline and wanted then frame:Show() else frame:Hide() end
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
function Panel.Layout(height)
    if not frame then return end
    frame:SetHeight(height)
    local budget = height - HEAD - SEARCHH - GAP - SUBHEAD - PAD
    trashCount = max(3, min(TRASHMAX, floor(budget * TRASHSHARE / ROW)))
    listCount = max(4, min(LISTMAX, floor((budget - trashCount * ROW) / ROW)))
    listBox:SetHeight(listCount * ROW)
    local listBottom = HEAD + SEARCHH + listCount * ROW
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", PAD, -(listBottom + floor(GAP / 2)))
    divider:SetPoint("TOPRIGHT", -PAD, -(listBottom + floor(GAP / 2)))
    trashHead:ClearAllPoints()
    trashHead:SetPoint("TOPLEFT", PAD, -(listBottom + GAP))
    trashBox:ClearAllPoints()
    trashBox:SetPoint("TOPLEFT", PAD, -(listBottom + GAP + SUBHEAD))
    trashBox:SetHeight(trashCount * ROW)
    if listBar then
        listBar:SetHeight(listCount * ROW)
        listBar:ClearAllPoints()
        listBar:SetPoint("TOPRIGHT", listBox, "TOPRIGHT", 0, 0)
    end
    if trashBar then
        trashBar:SetHeight(trashCount * ROW)
        trashBar:ClearAllPoints()
        trashBar:SetPoint("TOPRIGHT", trashBox, "TOPRIGHT", 0, 0)
    end
    for i = listCount + 1, #listRows do listRows[i]:Hide() end
    for i = trashCount + 1, #trashRows do trashRows[i]:Hide() end
    Panel.Refresh()
end
