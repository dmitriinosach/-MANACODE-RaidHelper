local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local MARGIN = 8
local GAP = 6
local DETAILMIN = 220
local AWARDMIN = 260
local TOTALMIN = 140
local WHEEL = 40
local RELAYOUT_DELAY = 0.15
local BUSYW = 320
local BUSYH = 14
local BUSYGAP = 8
local BUSYPAD = 4
local Kit = ns.Kit
local Badges = ns.Badges
local Grid = ns.Grid
local View = {}
ns.RaidSummaryView = View
local host, scroll, content, busy, art
local shownKey, asking
local offset = 0
local stats, panels, tiles = {}, {}, {}
local awardHead
local gpPanel, laid
local Render
local lastW = 0
local relayoutAt = 0
local pump = CreateFrame("Frame")
pump:Hide()
local function Backdrop(raid)
    Kit.RaidArtSet(art, host, raid and raid.map and ns.raidArt and ns.raidArt[raid.map] or nil)
end
local pageBar
local function SyncBar()
    if pageBar and content then pageBar:SetState(offset, host:GetHeight(), content:GetHeight()) end
end
local function Rescroll()
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    offset = min(offset, max(0, content:GetHeight() - host:GetHeight()))
    scroll:SetVerticalScroll(offset)
    SyncBar()
end
local function PageWheel(delta)
    if not content then return false end
    local most = max(0, content:GetHeight() - host:GetHeight())
    local was = offset
    offset = max(0, min(most, offset - delta * WHEEL))
    scroll:SetVerticalScroll(offset)
    SyncBar()
    return offset ~= was
end
function View.Title(raid)
    return format(ns.T("rsum.title"), ns.Raid.Title(raid))
end
local function Stat(i)
    stats[i] = stats[i] or Badges.Total(content)
    return stats[i]
end
local function Panel(i)
    panels[i] = panels[i] or Badges.Detail(content)
    return panels[i]
end
local function Progress()
    if not busy or not busy:IsShown() then return end
    local _, frac = ns.Jobs.State()
    if not frac then
        busy.bar:Hide()
        return
    end
    busy.bar:Show()
    busy.fill:SetWidth(max(1, BUSYW * frac))
    busy.pct:SetText(format(ns.T("job.pct"), floor(frac * 100)))
end
local function Busy()
    if busy then return busy end
    busy = CreateFrame("Frame", nil, host)
    busy:SetPoint("CENTER", host, "CENTER", 0, 0)
    busy:SetWidth(BUSYW)
    busy:SetHeight(BUSYH * 2 + BUSYGAP)
    busy:SetFrameLevel(scroll:GetFrameLevel() + 5)
    busy.text = busy:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Kit.Text(busy.text, "text.bright")
    busy.text:SetPoint("TOP", busy, "TOP", 0, 0)
    busy.text:SetWidth(BUSYW)
    busy.bar = CreateFrame("Frame", nil, busy)
    busy.bar:SetPoint("TOPLEFT", busy, "TOPLEFT", 0, -(BUSYH + BUSYGAP))
    busy.bar:SetWidth(BUSYW)
    busy.bar:SetHeight(BUSYH)
    local track = busy.bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    Kit.Paint(track, "progress.track")
    busy.fill = busy.bar:CreateTexture(nil, "BORDER")
    busy.fill:SetPoint("TOPLEFT", 0, 0)
    busy.fill:SetPoint("BOTTOMLEFT", 0, 0)
    busy.fill:SetWidth(1)
    Kit.Paint(busy.fill, "progress.fill")
    busy.pct = busy.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    busy.pct:SetPoint("CENTER", busy.bar, "CENTER", 0, 0)
    Kit.Text(busy.pct, "progress.text")
    busy.bar:Hide()
    return busy
end
local function ShowBusy(text, bar)
    local b = Busy()
    b.text:SetText(text)
    b:Show()
    if bar then Progress() else b.bar:Hide() end
end
local function DrawTotals(totals, w)
    local list = {}
    for i = 1, #totals do
        local c = totals[i]
        local f = Stat(i)
        f:SetModel({ title = c.title, value = c.value, sub = c.sub, subs = c.subs, unbuff = c.unbuff,
                     color = Kit.C[c.color] or Kit.C["text.accent"], lines = c.lines })
        list[i] = f
    end
    return Grid.Place(list, MARGIN, MARGIN, w, TOTALMIN, GAP, true)
end
local function Rows(rows)
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        out[i] = { who = r.who, class = r.class, icon = r.icon, text = r.text, note = r.note, noteIcon = r.noteIcon,
                   noteMuted = not r.noteLit, lines = r.lines }
    end
    return out
end
local function DrawAwards(awards, y, w)
    local AV = ns.AwardView
    if not AV or not awards or #awards == 0 then return y end
    awardHead = awardHead or AV.Head(content)
    awardHead:ClearAllPoints()
    awardHead:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    awardHead:Show()
    local list = {}
    for i = 1, #awards do
        tiles[i] = tiles[i] or AV.Tile(content)
        tiles[i]:SetModel(awards[i])
        list[i] = tiles[i]
    end
    return Grid.Place(list, MARGIN, y + AV.HEAD_H, w, AWARDMIN, GAP, true)
end
local function DrawDetails(details, y, w)
    local list = {}
    for i = 1, #details do
        local d = details[i]
        local f = Panel(i)
        f:SetModel({ title = d.title, rows = Rows(d.rows), empty = d.empty, tip = d.tip, onWheel = PageWheel })
        list[i] = f
    end
    return Grid.Place(list, MARGIN, y, w, DETAILMIN, GAP, true)
end
local function Inside()
    return not ns.SumSide or ns.SumSide.Inside()
end
local function SideWheel(delta)
    if Inside() then return PageWheel(delta) end
    return ns.SumSide.Wheel(delta)
end
local function SplitGP(details)
    local rest, gp = {}, nil
    for i = 1, #details do
        if details[i].key == "gp" then gp = details[i] else rest[#rest + 1] = details[i] end
    end
    return rest, gp
end
local function SideItems(raid, res, d)
    local parent = ns.SumSide and ns.SumSide.Parent(content) or content
    local out = {}
    if d then
        gpPanel = gpPanel or Badges.Detail(parent)
        gpPanel:SetParent(parent)
        gpPanel:SetModel({ title = d.title, rows = Rows(d.rows), empty = d.empty, onWheel = SideWheel })
        out[#out + 1] = gpPanel
    elseif gpPanel then
        gpPanel:Hide()
    end
    local ach = ns.AchView and ns.AchView.RaidItem(parent, raid, res.earned, SideWheel, Render)
    if ach then out[#out + 1] = ach end
    return out
end
local function DrawSide(list, y, w)
    if ns.SumSide then ns.SumSide.Show("raid", list) end
    if #list == 0 or not Inside() then return y end
    return Grid.Place(list, MARGIN, y, w, DETAILMIN, GAP, true)
end
local function Mark(key, top, bottom)
    if bottom > top then laid[#laid + 1] = { key = key, top = top, bottom = bottom - GAP } end
end
local function HideAll()
    if gpPanel then gpPanel:Hide() end
    for i = 1, #stats do stats[i]:Hide() end
    for i = 1, #panels do panels[i]:Hide() end
    for i = 1, #tiles do tiles[i]:Hide() end
    if awardHead then awardHead:Hide() end
    if busy then busy:Hide() end
    if ns.AchView then ns.AchView.HideRaid() end
end
local function Ask(raid)
    local key = raid.key
    if asking == key then return end
    asking = key
    ns.RaidSummary.Compute(raid, function()
        asking = nil
        if shownKey == key then Render() end
    end)
end
Render = function()
    if not host or not host:IsShown() then return end
    lastW = floor(host:GetWidth())
    HideAll()
    content:SetWidth(host:GetWidth())
    local raid = ns.RaidSummary.Find(shownKey)
    local res = raid and ns.RaidSummary.Get(raid)
    Backdrop(raid)
    laid = {}
    if not res then
        if ns.SumSide then ns.SumSide.Show("raid", {}) end
        local err = ns.RaidSummary.Failed(raid)
        if err then
            ShowBusy(format(ns.T("rsum.fail"), err), false)
        else
            ShowBusy(ns.T(raid and "rsum.busy" or "rsum.gone"), raid ~= nil)
        end
        content:SetHeight(host:GetHeight())
        Rescroll()
        if raid and not err then Ask(raid) end
        return
    end
    local model = ns.RaidModel.Build(res)
    local w = max(200, host:GetWidth() - MARGIN * 2)
    local y = DrawTotals(model.totals, w)
    Mark("totals", MARGIN, y)
    local rest, gp = SplitGP(model.details)
    local top = y
    y = DrawSide(SideItems(raid, res, gp), y, w)
    Mark("gp", top, y)
    top = y
    y = DrawDetails(rest, y, w)
    Mark("details", top, y)
    top = y
    y = DrawAwards(model.awards, y + GAP, w)
    Mark("awards", top, y)
    content:SetHeight(max(host:GetHeight(), y + MARGIN))
    Rescroll()
end
function View.Attach(frame)
    host = frame
    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Kit.Paint(bg, "float.bg")
    art = Kit.RaidArt(host)
    scroll = CreateFrame("ScrollFrame", nil, host)
    scroll:SetAllPoints()
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) PageWheel(delta) end)
    local deck = CreateFrame("Frame", nil, host)
    deck:SetFrameLevel(host:GetFrameLevel() + 40)
    deck:SetPoint("TOPRIGHT", host, "TOPRIGHT", -1, -MARGIN)
    deck:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, MARGIN)
    deck:SetWidth(8)
    pageBar = ns.Kit.ScrollBar(deck, 1)
    pageBar:SetPoint("TOPRIGHT", deck, "TOPRIGHT", 0, 0)
    pageBar:SetPoint("BOTTOMRIGHT", deck, "BOTTOMRIGHT", 0, 0)
    pageBar.onScroll = function(want)
        offset = max(0, min(max(0, content:GetHeight() - host:GetHeight()), want))
        scroll:SetVerticalScroll(offset)
        SyncBar()
    end
    host:Hide()
    if ns.DiscordView then ns.DiscordView.Attach(host) end
    if ns.SumSide then ns.SumSide.Watch("raid", host, function() Render() end) end
end
function View.Show(raid)
    if not host or not raid then return end
    if shownKey ~= raid.key then offset = 0 end
    if shownKey ~= raid.key or not host:IsShown() then ns.RaidSummary.Retry(raid) end
    shownKey = raid.key
    host:Show()
    Render()
end
function View.Hide()
    shownKey = nil
    if host then host:Hide() end
    if ns.SumSide then ns.SumSide.Drop("raid") end
end
function View.Blocks()
    return laid or {}
end
function View.Details()
    local out = {}
    for i = 1, #panels do
        if panels[i]:IsShown() then out[#out + 1] = panels[i] end
    end
    return out
end
function View.Tiles()
    local out = {}
    for i = 1, #tiles do
        if tiles[i]:IsShown() then out[#out + 1] = tiles[i] end
    end
    return out
end
function View.IsShown()
    return host ~= nil and host:IsShown() and shownKey ~= nil
end
function View.ShownKey()
    if not View.IsShown() then return nil end
    return shownKey
end
function View.Fresh()
    local latest = ns.Encounters and ns.Encounters.Fights()[1]
    if not latest or not latest.from then return nil end
    local ui = ns.GetDB().settings.ui
    local at = floor(latest.from)
    local seen = tonumber(ui.landedAt)
    if seen and at <= seen then return nil end
    ui.landedAt = at
    if not seen then return nil end
    return latest
end
function View.Land(current)
    if not ns.Timeline then return end
    local fresh = View.Fresh()
    if fresh and ns.Timeline.ShowFight then
        ns.Timeline.ShowFight(fresh)
        return
    end
    if current or View.IsShown() then return end
    local raid, fight = ns.RaidSummary.Landing()
    if raid and ns.Timeline.ShowRaid then
        ns.Timeline.ShowRaid(raid)
    elseif fight and ns.Timeline.ShowFight then
        ns.Timeline.ShowFight(fight)
    end
end
pump:SetScript("OnUpdate", ns.Prof.Wrap("ui.sum", function(self)
    if GetTime() < relayoutAt then return end
    self:Hide()
    Render()
end))
function View.Relayout()
    if not View.IsShown() then return end
    Kit.RaidArtFit(art, host)
    if floor(host:GetWidth()) == lastW then return end
    relayoutAt = GetTime() + RELAYOUT_DELAY
    pump:Show()
end
function View.Refresh()
    Render()
end
if ns.GPList and ns.GPList.OnChange then
    ns.GPList.OnChange(function()
        ns.RaidSummary.GPDirty()
        if View.IsShown() then Render() end
    end)
end
Kit.OnTheme(function()
    if View.IsShown() then Render() end
end)
if ns.Jobs and ns.Jobs.OnChange then ns.Jobs.OnChange(Progress) end
local lander = CreateFrame("Frame")
lander:Hide()
function View.Scanned()
    lander:Hide()
    if not (ns.Shell and ns.Shell.IsOpen("log") and ns.Timeline) then return end
    if ns.Encounters and ns.Encounters.Ready and not ns.Encounters.Ready() then return end
    local fresh = View.Fresh()
    if fresh and ns.Timeline.ShowFight then ns.Timeline.ShowFight(fresh) end
end
lander:SetScript("OnUpdate", View.Scanned)
if ns.FightTree and hooksecurefunc then
    hooksecurefunc(ns.FightTree, "Lend", function() lander:Show() end)
end
