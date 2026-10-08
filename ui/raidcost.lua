local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local floor = math.floor
local ROWH = 20
local ICON = 16
local INFOH = 18
local HEADH = 18
local NAMEW = 230
local AHW = 90
local EDITW = 70
local COL_AH = ICON + 6 + NAMEW + 10
local COL_EDIT = COL_AH + AHW + 10
local COL_DATE = COL_EDIT + EDITW + 12
local sec = { rows = {}, offset = 0 }
local function GoldText(copper)
    if not copper then return ns.T("cost.none") end
    return ns.RaidCost.Gold(copper)
end
local function EditText(copper)
    if not copper then return "" end
    local g = copper / 10000
    if g == floor(g) then return tostring(g) end
    return (format("%.2f", g):gsub("0+$", ""))
end
local function Visible()
    local h = sec.body and sec.body:GetHeight() or 0
    return max(1, floor((h - INFOH - HEADH - INFOH) / ROWH))
end
local Refresh
local function Commit(row, text)
    if not row.item then return end
    local clean = (text or ""):gsub(",", ".")
    local g = tonumber(clean) or 0
    local was = ns.RaidCost.Manual(row.item.item) or 0
    if floor(g * 10000 + 0.5) == was then return end
    ns.RaidCost.Set(row.item.item, g)
    if ns.RaidSummaryView and ns.RaidSummaryView.Refresh then ns.RaidSummaryView.Refresh() end
    Refresh()
end
local function NewRow(body, i)
    local r = CreateFrame("Frame", nil, body)
    r:SetHeight(ROWH)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(ICON)
    r.icon:SetHeight(ICON)
    r.icon:SetPoint("LEFT", 0, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(r.name, "text.bright")
    r.name:SetPoint("LEFT", ICON + 6, 0)
    r.name:SetWidth(NAMEW)
    r.name:SetJustifyH("LEFT")
    r.ah = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.ah:SetPoint("LEFT", COL_AH, 0)
    r.ah:SetWidth(AHW)
    r.ah:SetJustifyH("LEFT")
    r.ahHit = CreateFrame("Frame", nil, r)
    r.ahHit:SetWidth(AHW)
    r.ahHit:SetHeight(ROWH)
    r.ahHit:SetPoint("LEFT", COL_AH, 0)
    r.ahHit:EnableMouse(true)
    r.ahHit.tipTitle = false
    r.ahHit:SetScript("OnEnter", ns.Kit.TipShow)
    r.ahHit:SetScript("OnLeave", ns.Kit.TipHide)
    r.edit =ns.Kit.Edit(r, false, "HTP_FailWatchCostEdit" .. i)
    r.edit:SetWidth(EDITW)
    r.edit:SetHeight(ROWH - 2)
    r.edit:SetPoint("LEFT", COL_EDIT, 0)
    r.edit:SetMaxLetters(9)
    r.edit.tipTitle = false
    r.edit.tip = ns.T("set.cost.tip")
    r.edit.onCommit = function(text) Commit(r, text) end
    r.when = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.when:SetPoint("LEFT", COL_DATE, 0)
    r.when:SetJustifyH("LEFT")
    ns.Kit.Text(r.ah, "text.secondary")
    ns.Kit.Text(r.when, "text.muted")
    return r
end
local function PaintAH(r, it)
    local Cost = ns.RaidCost
    local c, t, rec = Cost.Scan(it.item)
    local hit = r.ahHit
    if c then
        r.ah:SetText(GoldText(c))
        ns.Kit.Text(r.ah, "text.secondary")
        hit.tip = format(ns.T("set.cost.tip.scan"), Cost.Stamp(t), rec.n or 0, rec.l or 0)
    else
        c, t = Cost.AH(it.item)
        r.ah:SetText(GoldText(c))
        ns.Kit.Text(r.ah, "text.muted")
        hit.tip = c and format(ns.T("set.cost.tip.atr"), Cost.Date(t)) or ns.T("set.cost.tip.none")
    end
    hit.tipDim = Cost.Manual(it.item) and ns.T("set.cost.tip.own") or nil
end
Refresh = function()
    local body = sec.body
    if not body then return end
    local items = ns.RaidCost.Items()
    local ah = ns.RaidCost.HasAH()
    local stamp = _G.AUCTIONATOR_LAST_SCAN_TIME
    sec.info:SetText(ah and format(ns.T("set.cost.ah"), ns.RaidCost.Date(type(stamp) == "number" and stamp or nil))
        or ns.T("set.cost.noah"))
    local shown = Visible()
    sec.offset = max(0, min(sec.offset, #items - shown))
    for i = 1, #sec.rows do
        local r = sec.rows[i]
        local it = items[i + sec.offset]
        if it and i <= shown then
            r.item = it
            r.icon:SetTexture(ns.RaidCost.Icon(it.id))
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.name:SetText(ns.ConsumableName(it.id, it.spell, it.item))
            PaintAH(r, it)
            local c, t = ns.RaidCost.Manual(it.item)
            if not r.edit:HasFocus() then r.edit:SetValue(EditText(c)) end
            r.when:SetText(t and ns.RaidCost.Date(t) or "")
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(INFOH + HEADH + (i - 1) * ROWH))
            r:SetPoint("RIGHT", body, "RIGHT", 0, 0)
            r:Show()
        else
            r.item = nil
            r:Hide()
        end
    end
    if #items > shown then
        sec.more:SetText(format(ns.T("set.cost.more"), sec.offset + 1, min(#items, sec.offset + shown), #items))
        sec.more:ClearAllPoints()
        sec.more:SetPoint("TOPLEFT", 0, -(INFOH + HEADH + shown * ROWH + 2))
        sec.more:Show()
    else
        sec.more:Hide()
    end
end
local function Head(body, x, key)
    local fs = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ns.Kit.Text(fs, "text.title")
    fs:SetPoint("TOPLEFT", x, -INFOH)
    fs:SetText(ns.T(key))
end
local function Build(body)
    sec.body = body
    sec.info = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sec.info:SetPoint("TOPLEFT", 0, 0)
    sec.info:SetPoint("RIGHT", body, "RIGHT", 0, 0)
    sec.info:SetJustifyH("LEFT")
    ns.Kit.Text(sec.info, "text.secondary")
    Head(body, ICON + 6, "set.cost.item")
    Head(body, COL_AH, "set.cost.auc")
    Head(body, COL_EDIT, "set.cost.own")
    Head(body, COL_DATE, "set.cost.date")
    sec.more = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.Kit.Text(sec.more, "text.off")
    local items = ns.RaidCost.Items()
    for i = 1, #items do sec.rows[i] = NewRow(body, i) end
    body:SetScript("OnSizeChanged", function() Refresh() end)
    Refresh()
end
ns.RaidCostView = { Refresh = function() Refresh() end }
ns.Shell.Section("cost", {
    cat = "cost",
    order = 10,
    height = function() return INFOH + HEADH + #ns.RaidCost.Items() * ROWH + INFOH end,
    build = Build,
    OnShow = Refresh,
})
