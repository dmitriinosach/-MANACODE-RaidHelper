local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local concat = table.concat
local Kit = ns.Kit
local PAD = 12
local BTNH = 20
local LOGH = 20
local TABS = { "give", "rules", "log" }
local PREV = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local NEXT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local LOGCOLS = { { "time", 44 }, { "who", 110 }, { "what", 0 }, { "sys", 80 }, { "n", 80 }, { "by", 100 } }
local Page = {}
ns.FaultsPage = Page
local frame, sysBtn, give, rules, log
local tabBtns = {}
local btns = {}
local top, bar, foot, logh, btnh = 40, 26, 30, LOGH, BTNH
local tab = "give"
local current, model
local follow = true
local giveOffset, logOffset = 0, 0
local function RaidKey(f)
    return ns.Raid and ns.Raid.Key(f.raid) or "solo"
end
local function RaidFights()
    local all = ns.Encounters and ns.Encounters.Fights() or {}
    local out = {}
    if not all[1] then return out end
    local key = RaidKey(current or all[1])
    for i = 1, #all do
        if RaidKey(all[i]) == key then out[#out + 1] = all[i] end
    end
    return out
end
local function IndexOf(fights, f)
    for i = 1, #fights do
        if fights[i] == f then return i end
    end
    return 0
end
function Page.SystemMenu(anchor)
    local menu = { { text = ns.T("gpset.pick"), isTitle = true, notCheckable = true } }
    local order = ns.Ledger.ORDER
    local active = ns.Ledger.Key()
    for i = 1, #order do
        local key = order[i]
        local ready, why = ns.Ledger.Get(key).Ready()
        local text = ns.Ledger.Label(key)
        if not ready and why then text = text .. " — " .. ns.T(why) end
        menu[#menu + 1] = {
            text = text,
            checked = key == active,
            disabled = why == "led.err.noqdkp",
            tip = not ready and why and ns.T(why) or nil,
            func = function() ns.Ledger.Select(key) end,
        }
    end
    ns.Tip.Hide()
    ns.Kit.Menu(menu, anchor)
end
local function Step(step)
    local fights = RaidFights()
    local i = IndexOf(fights, current) + step
    if fights[i] then
        current = fights[i]
        follow = i == 1
        giveOffset = 0
        give.list.sel = {}
        Page.Refresh()
    end
end
local function GiveWheel(delta)
    local list = give.list
    local most = max(0, (list.total or 0) - (give.slots or 1))
    local was = giveOffset
    giveOffset = max(0, min(most, giveOffset - delta))
    if giveOffset ~= was then Page.Refresh() end
end
local function LogWheel(delta)
    logOffset = max(0, logOffset - delta * 3)
    Page.Refresh()
end
local function Metrics()
    btnh = Kit.FontGrow(BTNH)
    top, bar, foot, logh = 20 + btnh, btnh + 6, btnh + 10, Kit.FontGrow(LOGH)
end
local function Btn(parent, name, kind, onClick)
    local b = ns.MakeButton(parent, name, kind)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetHeight(btnh)
    b.onClick = onClick
    btns[#btns + 1] = b
    return b
end
local function Fit(b, text)
    b.text:SetText(text)
    b:SetWidth(max(Kit.FontGrow(60), floor(b.text:GetStringWidth() + 0.5) + 24))
end
local function BuildGive()
    give = CreateFrame("Frame", nil, frame)
    give:EnableMouseWheel(true)
    give:SetScript("OnMouseWheel", function(_, d) GiveWheel(d) end)
    give.prev = ns.Kit.IconButton(give, PREV, 16, "HTP_FailWatchFaultsPrev")
    give.prev:SetPoint("TOPLEFT", 0, 0)
    give.prev.tipTitle = false
    give.prev.tip = ns.T("gpmini.prev")
    give.prev.onClick = function() Step(1) end
    give.title = Kit.Str(give, "GameFontNormal")
    ns.Kit.Text(give.title, "text.title")
    give.title:SetPoint("LEFT", give.prev, "RIGHT", 6, 0)
    give.title:SetJustifyH("LEFT")
    give.next = ns.Kit.IconButton(give, NEXT, 16, "HTP_FailWatchFaultsNext")
    give.next:SetPoint("LEFT", give.title, "RIGHT", 6, 0)
    give.next.tipTitle = false
    give.next.tip = ns.T("gpmini.next")
    give.next.onClick = function() Step(-1) end
    give.open = Btn(give, "HTP_FailWatchFaultsFilterOpen", "quiet", function()
        give.list.filter = "open"
        giveOffset = 0
        Page.Refresh()
    end)
    Fit(give.open, ns.T("fp.filter.open"))
    give.all = Btn(give, "HTP_FailWatchFaultsFilterAll", "quiet", function()
        give.list.filter = "all"
        giveOffset = 0
        Page.Refresh()
    end)
    give.all:SetPoint("LEFT", give.open, "RIGHT", 4, 0)
    Fit(give.all, ns.T("fp.filter.all"))
    give.giveAll = Btn(give, "HTP_FailWatchFaultsGiveAll", "main", function()
        if current and model then ns.GPList.Issue(current, model.all) end
    end)
    give.total = Kit.Str(give, "GameFontHighlightSmall")
    ns.Kit.Text(give.total, "text.bright")
    give.total:SetPoint("RIGHT", give.giveAll, "LEFT", -10, 0)
    give.list = ns.GPList.New(give, "HTP_FailWatchFaultsRow", ns.GPList.PAGE, true)
    give.list.filter = "open"
    give.list.onWheel = GiveWheel
    give.list.onSel = function() Page.Refresh() end
    give.marked = Kit.Str(give, "GameFontHighlightSmall")
    ns.Kit.Text(give.marked, "text.bright")
    give.marked:SetPoint("BOTTOMLEFT", 0, 8)
    give.giveSel = Btn(give, "HTP_FailWatchFaultsGiveMarked", "main", function()
        if current and model then ns.GPList.IssueKeys(current, model, give.list.sel) end
    end)
    give.giveSel:SetPoint("LEFT", give.marked, "RIGHT", 10, 0)
    give.busy = Kit.Str(give, "GameFontDisableSmall")
    ns.Kit.Text(give.busy, "text.off")
end
local function LogRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(logh)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, d) LogWheel(d) end)
    r.cells = {}
    for i = 1, #LOGCOLS do
        local fs = Kit.Str(r, "GameFontHighlightSmall")
        fs:SetJustifyH(LOGCOLS[i][1] == "n" and "RIGHT" or "LEFT")
        fs:SetWordWrap(false)
        r.cells[LOGCOLS[i][1]] = fs
    end
    return r
end
local function LogLayout(r, width)
    local fixed = 0
    for i = 1, #LOGCOLS do fixed = fixed + Kit.FontGrow(LOGCOLS[i][2]) + 6 end
    local x = 4
    for i = 1, #LOGCOLS do
        local key, w = LOGCOLS[i][1], Kit.FontGrow(LOGCOLS[i][2])
        if w == 0 then w = max(Kit.FontGrow(80), width - fixed - 8) end
        local fs = r.cells[key]
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", r, "LEFT", x, 0)
        fs:SetWidth(w)
        x = x + w + 6
    end
end
local function BuildLog()
    log = CreateFrame("Frame", nil, frame)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(_, d) LogWheel(d) end)
    log.title = Kit.Str(log, "GameFontNormal")
    ns.Kit.Text(log.title, "text.title")
    log.title:SetPoint("TOPLEFT", 0, -2)
    log.sums = Kit.Str(log, "GameFontHighlight")
    ns.Kit.Text(log.sums, "text.bright")
    log.sums:SetPoint("TOPRIGHT", 0, -2)
    log.head = LogRow(log)
    for i = 1, #LOGCOLS do
        local fs = log.head.cells[LOGCOLS[i][1]]
        fs:SetText(ns.T("fp.log.col." .. LOGCOLS[i][1]))
        ns.Kit.Text(fs, "text.secondary")
    end
    log.rows = {}
    log.empty = Kit.Str(log, "GameFontDisableSmall")
    ns.Kit.Text(log.empty, "text.off")
    log.empty:SetText(ns.T("fp.log.empty"))
end
local function LogTexts(row)
    local unit = ns.Ledger.Get(row.s) and ns.Ledger.Unit(row.s) or tostring(row.s)
    local what = row.r or ""
    if row.kind == "hand" then what = format(ns.T("ft.hand"), what) end
    local sys = row.kind == "undo" and format(ns.T("fp.log.undo"), unit) or unit
    local n = tostring(row.n or 0)
    if row.want and row.n and row.want > row.n then n = format(ns.T("fp.log.of"), row.n, row.want) end
    return what, sys, n
end
local function RaidLabel(key)
    local all = ns.Encounters and ns.Encounters.Fights() or {}
    for i = #all, 1, -1 do
        local r = all[i].raid
        if r and (RaidKey(all[i]) == key or ns.Raid.DayKey(r) == key) then return ns.Raid.Label(r) end
    end
    return key
end
local function LogRaid()
    if current then
        local r = current.raid
        return RaidKey(current), r and ns.Raid.Label(r) or RaidKey(current), r and r.id and ns.Raid.DayKey(r) or nil
    end
    local all = ns.Ledger.Log()
    local last = all[#all]
    if last and last.raid then return last.raid, last.rl or RaidLabel(last.raid) end
    return nil, ns.T("fp.log.all")
end
local function PaintLog()
    local raid, label, alt = LogRaid()
    local rows = ns.Ledger.Log(raid, alt)
    log.title:SetText(format(ns.T("fp.log.raid"), label))
    local sums, parts = ns.Ledger.Sums(rows), {}
    for i = 1, #ns.Ledger.ORDER do
        local s = ns.Ledger.ORDER[i]
        if sums[s] then parts[#parts + 1] = ns.Ledger.Unit(s) .. " " .. sums[s] end
    end
    log.sums:SetText(concat(parts, ", "))
    local width = log:GetWidth() or 600
    LogLayout(log.head, width)
    local slots = max(1, floor(((log:GetHeight() or 300) - bar - logh - 4) / logh))
    logOffset = max(0, min(logOffset, #rows - slots))
    local shown = 0
    for k = 1, slots do
        local row = rows[#rows - logOffset - k + 1]
        local r = log.rows[k]
        if row and not r then
            r = LogRow(log)
            log.rows[k] = r
        end
        if row then
            r:ClearAllPoints()
            r:SetHeight(logh)
            r:SetPoint("TOPLEFT", 0, -(bar + logh * k))
            r:SetPoint("TOPRIGHT", 0, -(bar + logh * k))
            LogLayout(r, width)
            local what, sys, n = LogTexts(row)
            r.cells.time:SetText(date("%H:%M", row.t or 0))
            r.cells.who:SetText(row.who or "")
            r.cells.what:SetText(what)
            r.cells.sys:SetText(sys)
            r.cells.n:SetText(n)
            r.cells.by:SetText(row.by or "")
            ns.Kit.Text(r.cells.sys, row.kind == "undo" and "text.bad" or "text.title")
            r:Show()
            shown = shown + 1
        elseif r then
            r:Hide()
        end
    end
    for k = slots + 1, #log.rows do log.rows[k]:Hide() end
    if shown == 0 then log.empty:Show() else log.empty:Hide() end
end
local function PaintGive()
    local fights = RaidFights()
    if current and IndexOf(fights, current) == 0 then current = nil end
    if follow or not current then
        current = fights[1]
        follow = true
    end
    local i = IndexOf(fights, current)
    if fights[i + 1] then give.prev:Enable() else give.prev:Disable() end
    if i > 1 then give.next:Enable() else give.next:Disable() end
    give.open:SetActive(give.list.filter == "open")
    give.all:SetActive(give.list.filter == "all")
    local unit = ns.Ledger.Unit()
    if not current then
        model = nil
        give.title:SetText(ns.T("gpmini.nofight"))
        give.list:Hide()
        give.busy:SetText(ns.T("gpmini.none"))
        give.busy:Show()
        give.giveAll:Disable()
        give.giveSel:Disable()
        return
    end
    local n, total = 0, 0
    for k = 1, #fights do
        if fights[k].boss == current.boss then
            total = total + 1
            if fights[k].from <= current.from then n = n + 1 end
        end
    end
    give.title:SetText(format(ns.T("fp.try"), ns.EncName(current.boss), n, total,
        ns.T(current.killed and "fl.win" or "fl.wipe"), ns.Clock(current.to - current.from)))
    local summary = ns.Summary.Get(current)
    if not summary then
        model = nil
        give.list:Hide()
        give.busy:SetText(ns.T("sum.busy"))
        give.busy:Show()
        local f = current
        ns.Summary.Compute(f, function()
            if frame:IsVisible() and current == f then Page.Refresh() end
        end)
        return
    end
    give.busy:Hide()
    model = ns.GPList.Build(current, summary)
    local width = give:GetWidth() or 800
    local L = give.list.L
    give.slots = max(1, floor(((give:GetHeight() or 400) - bar * 2 - 4 - foot - L.headh) / L.rowh))
    local rows = ns.FaultTable.Rows(model, give.list.filter)
    giveOffset = max(0, min(giveOffset, #rows - give.slots))
    give.list:Draw(current, model, width, giveOffset, give.slots)
    give.list:Show()
    give.total:SetText(format(ns.T("fp.pending"), model.pending, unit, model.ready, ns.Plural(model.ready, ns.T("gp.players"))))
    Fit(give.giveAll, format(ns.T("sum.gp.all"), model.pending))
    if model.pending > 0 then give.giveAll:Enable() else give.giveAll:Disable() end
    local marked, count = ns.GPList.Marked(model, give.list.sel), 0
    for _ in pairs(give.list.sel) do count = count + 1 end
    give.marked:SetText(format(ns.T("fp.marked"), count))
    Fit(give.giveSel, format(ns.T("fp.give.marked"), marked))
    if marked > 0 then give.giveSel:Enable() else give.giveSel:Disable() end
end
function Page.Refresh()
    if not frame or not frame:IsVisible() then return end
    sysBtn.text:SetText(format(ns.T("gpset.system"), ns.Ledger.Label()))
    sysBtn:SetWidth(max(Kit.FontGrow(160), floor(sysBtn.text:GetStringWidth() + 0.5) + 24))
    for i = 1, #TABS do tabBtns[TABS[i]]:SetActive(TABS[i] == tab) end
    if tab == "give" then give:Show() else give:Hide() end
    if tab == "rules" then rules:Show() else rules:Hide() end
    if tab == "log" then log:Show() else log:Hide() end
    if tab == "give" then PaintGive() end
    if tab == "log" then PaintLog() end
    if tab == "rules" and ns.GPSettings then ns.GPSettings.Refresh() end
end
local function SetTab(key)
    tab = key
    if key == "rules" and ns.GPSettings then
        rules:Show()
        ns.GPSettings.Opened()
    end
    Page.Refresh()
end
local function Place()
    local x = PAD - 2
    for i = 1, #TABS do
        local b = tabBtns[TABS[i]]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -10)
        Fit(b, ns.T("fp.tab." .. TABS[i]))
        x = x + b:GetWidth() + 4
    end
    for i = 1, #btns do btns[i]:SetHeight(btnh) end
    give:SetPoint("TOPLEFT", PAD, -top)
    give:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    give.open:SetPoint("TOPLEFT", 0, -bar)
    Fit(give.open, ns.T("fp.filter.open"))
    Fit(give.all, ns.T("fp.filter.all"))
    give.giveAll:SetPoint("TOPRIGHT", 0, -bar)
    give.list:SetPoint("TOPLEFT", 0, -(bar * 2 + 4))
    give.busy:SetPoint("TOPLEFT", give.list, "TOPLEFT", 6, -(bar - 2))
    rules:SetPoint("TOPLEFT", 0, -top + 6)
    log:SetPoint("TOPLEFT", PAD, -top)
    log:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    log.head:SetPoint("TOPLEFT", 0, -bar)
    log.head:SetPoint("TOPRIGHT", 0, -bar)
    log.empty:SetPoint("TOPLEFT", 4, -(bar + logh + 6))
end
function Page.Attach(host)
    frame = host
    frame.sized = true
    Metrics()
    for i = 1, #TABS do
        local key = TABS[i]
        local b = Btn(frame, "HTP_FailWatchFaultsTab" .. key, "quiet", function() SetTab(key) end)
        tabBtns[key] = b
    end
    sysBtn = Btn(frame, "HTP_FailWatchGPSystem", "quiet", function() Page.SystemMenu(sysBtn) end)
    sysBtn:SetPoint("TOPRIGHT", -PAD, -10)
    sysBtn.tip = ns.T("gpset.pick")
    BuildGive()
    rules = CreateFrame("Frame", nil, frame)
    rules:SetPoint("BOTTOMRIGHT", 0, 0)
    if ns.GPSettings then ns.GPSettings.Attach(rules) end
    BuildLog()
    Place()
    ns.GPList.OnChange(function() Page.Refresh() end)
    Kit.OnFont(function()
        Metrics()
        Place()
        Page.Refresh()
    end)
end
function Page.Opened()
    if not frame then return end
    if ns.Encounters and not ns.Encounters.Ready() then
        ns.Encounters.Scan(function() Page.Refresh() end)
    end
    if tab == "rules" then SetTab("rules") else Page.Refresh() end
end
function Page.Open(key, f)
    tab = key or tab
    if f then
        current = f
        local fights = ns.Encounters and ns.Encounters.Fights() or {}
        follow = f == fights[1]
        giveOffset = 0
    end
    if ns.Shell then ns.Shell.Open("gp") end
    if frame and frame:IsVisible() then Page.Opened() end
end
function Page.Tab()
    return tab
end
