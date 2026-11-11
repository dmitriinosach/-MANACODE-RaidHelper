local _, ns = ...
local format = string.format
local floor, max, min = math.floor, math.max, math.min
local ICON = 16
local PAD = 6
local RETRY = 1
local RETRIES = 5
local F = ns.Flasks
local Kit = ns.Kit
local T = ns.T
local View = ns.FlaskView
local Z = { row = 20, head = 22, top = 26, ctl = 22, gap = 6, name = 150, role = 104, col = 56, colMin = 34, total = 64,
            btn = 96 }
local pg = { heads = {}, colW = Z.col }
local LogView = {}
ns.FlaskLogView = LogView
local retry = CreateFrame("Frame")
retry:Hide()
retry.left, retry.tries = 0, 0
local function Fit()
    local m = Kit.Grow()
    local g, k = m.g, m.k
    Z.row, Z.head, Z.top, Z.ctl = 20 + g, 22 + g, 26 + g, Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
    Z.gap = Kit.Space.row
    Z.name, Z.role, Z.total = floor(150 * k + 0.5), floor(104 * k + 0.5), floor(64 * k + 0.5)
    Z.col, Z.colMin, Z.btn = floor(56 * k + 0.5), floor(34 * k + 0.5), floor(96 * k + 0.5)
end
local function TableTop()
    return Z.top * 2 + Z.gap
end
function LogView.Cell(got, norm)
    if norm == 0 then
        if got == 0 then return "—", "text.off" end
        return tostring(got), "text.muted"
    end
    local text = format("%d/%d", got, norm)
    if got >= norm then return text, "text.good" end
    if got > 0 then return text, "text.warn" end
    return text, "text.bad"
end
local function PickRole(name, b)
    local opts = {}
    for i = 1, #ns.flaskKinds do
        local kind = ns.flaskKinds[i]
        opts[i] = { key = kind, label = T("flask.kind." .. kind) }
    end
    opts[#opts + 1] = { key = "", label = T("flask.log.role.auto") }
    Kit.Popup(b, opts, function(kind) F.SetHand(name, kind ~= "" and kind or nil) end)
end
local function Cells(r, n)
    for i = #r.cells + 1, n do
        local fs = Kit.Str(r, "GameFontHighlightSmall")
        fs:SetJustifyH("CENTER")
        r.cells[i] = fs
    end
end
local function NewRow()
    local r = CreateFrame("Frame", nil, pg.page)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = Kit.Str(r, "GameFontHighlightSmall")
    r.name:SetJustifyH("LEFT")
    r.role = Kit.Button(r, nil, "quiet")
    Kit.Bind(r.role.text, "GameFontNormalSmall")
    Kit.ExactSize(r.role)
    r.role.tipTitle = false
    r.role.tip = T("flask.log.role.tip")
    r.role.onClick = function(b) if r.who then PickRole(r.who, b) end end
    r.cells = {}
    r.total = Kit.Str(r, "GameFontHighlightSmall")
    r.total:SetJustifyH("CENTER")
    return r
end
local function FillRow(r, row, k)
    local t = pg.data
    r.who = row.name
    r:SetHeight(Z.row)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", pg.page, "TOPLEFT", 0, -(TableTop() + Z.head + (k - 1) * Z.row))
    r:SetPoint("RIGHT", pg.page, "RIGHT", 0, 0)
    local c = Kit.C[k % 2 == 0 and "row.bgHover" or "row.bg"]
    r.bg:SetTexture(c[1], c[2], c[3], c[4] or 1)
    r.name:ClearAllPoints()
    r.name:SetPoint("LEFT", r, "LEFT", PAD, 0)
    r.name:SetWidth(Z.name - PAD * 2)
    r.name:SetText(row.here and row.name or format(T("flask.log.gone"), row.name))
    Kit.ClassText(r.name, row.class)
    r.role:SetWidth(Z.role - PAD * 2)
    r.role:SetHeight(Z.row - 2)
    r.role:ClearAllPoints()
    r.role:SetPoint("LEFT", r, "LEFT", Z.name, 0)
    r.role:SetText(row.kind and T("flask.kind." .. row.kind) or T("flask.log.norole"))
    r.role:SetActive(row.src == "hand")
    local ids = t and t.ids or {}
    Cells(r, #ids)
    local x = Z.name + Z.role
    for i = 1, #r.cells do
        local fs = r.cells[i]
        local id = ids[i]
        if id then
            local cell = row.cells[id]
            local text, tok = LogView.Cell(cell.got, cell.norm)
            fs:SetText(text)
            Kit.Text(fs, tok)
            fs:SetWidth(pg.colW)
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", r, "LEFT", x, 0)
            fs:Show()
            x = x + pg.colW
        else
            fs:Hide()
        end
    end
    local text, tok = LogView.Cell(row.got, row.norm)
    r.total:SetText(text)
    Kit.Text(r.total, tok)
    r.total:SetWidth(Z.total)
    r.total:ClearAllPoints()
    r.total:SetPoint("LEFT", r, "LEFT", x, 0)
end
local function Head(i)
    local h = pg.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, pg.page)
    h:EnableMouse(true)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetPoint("CENTER")
    h.tipTitle = false
    h:SetScript("OnEnter", Kit.TipShow)
    h:SetScript("OnLeave", Kit.TipHide)
    pg.heads[i] = h
    return h
end
local function Cap(fs, x, w)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", pg.page, "TOPLEFT", x, -(TableTop() + Z.head / 2))
    fs:SetWidth(w)
end
local function DrawHead(t)
    local page, n = pg.page, #t.ids
    local y = TableTop()
    Cap(pg.capName, PAD, Z.name - PAD)
    Cap(pg.capRole, Z.name + PAD, Z.role - PAD)
    local x, miss = Z.name + Z.role, false
    for i = 1, max(n, #pg.heads) do
        local id = t.ids[i]
        if id then
            local hd = Head(i)
            hd:SetWidth(pg.colW)
            hd:SetHeight(Z.head)
            hd:ClearAllPoints()
            hd:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
            hd.icon:SetWidth(ICON)
            hd.icon:SetHeight(ICON)
            hd.icon:SetTexture(F.Icon(id))
            hd.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local cached = GetItemInfo(id) ~= nil
            hd.tipLink = cached and ("item:" .. id) or nil
            hd.tip = not cached and F.Name(id) or nil
            if not cached then miss = true end
            hd:Show()
            x = x + pg.colW
        elseif pg.heads[i] then
            pg.heads[i]:Hide()
        end
    end
    Cap(pg.capTotal, x, Z.total)
    return miss
end
local function Draw()
    local page, t = pg.page, pg.data
    if not page or not t then return end
    local w, h = page:GetWidth(), page:GetHeight()
    local n = #t.ids
    pg.colW = n > 0 and max(Z.colMin, min(Z.col, floor((w - Z.name - Z.role - Z.total) / n))) or Z.col
    local miss = DrawHead(t)
    local top = TableTop() + Z.head
    local slots = max(1, floor((h - top - Z.row) / Z.row))
    pg.list:Draw(t.rows, slots)
    if #t.rows == 0 then
        pg.none:ClearAllPoints()
        pg.none:SetPoint("TOPLEFT", page, "TOPLEFT", PAD, -(top + PAD))
        pg.none:Show()
    else
        pg.none:Hide()
    end
    if #t.rows > slots then
        local off = pg.list.offset
        pg.more:SetText(format(T("flask.log.more"), off + 1, min(#t.rows, off + slots), #t.rows))
        pg.more:ClearAllPoints()
        pg.more:SetPoint("TOPLEFT", page, "TOPLEFT", PAD, -(top + slots * Z.row + 2))
        pg.more:Show()
    else
        pg.more:Hide()
    end
    if miss and page:IsVisible() and retry.tries < RETRIES then
        retry.left, retry.tries = RETRY, retry.tries + 1
        retry:Show()
    elseif not miss then
        retry.tries = 0
    end
end
function LogView.Summary()
    local t = pg.data or F.Table()
    return format(T("flask.log.sum"), t.given, View.Word(t.given, "flask.w.item"), t.people,
        View.Word(t.people, "flask.w.people"), t.short, View.Word(t.short, "flask.w.people"))
end
local function Place(page)
    Fit()
    local x = 0
    for _, b in ipairs({ pg.new, pg.say, pg.chat }) do
        b:SetWidth(Z.btn)
        b:SetHeight(Z.ctl)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", page, "TOPRIGHT", -x, -Z.top / 2)
        x = x + b:GetWidth() + Z.gap
    end
    pg.sum:ClearAllPoints()
    pg.sum:SetPoint("LEFT", page, "TOPLEFT", PAD, -Z.top / 2)
    pg.sum:SetPoint("RIGHT", pg.chat, "LEFT", -Z.gap, 0)
    pg.kit:ClearAllPoints()
    pg.kit:SetPoint("LEFT", page, "TOPLEFT", PAD, -(Z.top + Z.top / 2))
end
function LogView.Refresh()
    if not pg.page or not pg.page:IsVisible() then return end
    pg.data = F.Table()
    pg.sum:SetText(LogView.Summary())
    Kit.Text(pg.sum, pg.data.short > 0 and "text.warn" or "text.primary")
    pg.kit:SetText(format(T("flask.log.kit"), F.Kit().name or ""))
    local on = F.IsOn() and F.InGroup()
    if on then pg.say:Enable() else pg.say:Disable() end
    pg.say.tip = on and format(T("flask.act.say.tip"), View.AnnounceText()) or T("flask.act.say.off")
    if pg.data.given > 0 then pg.new:Enable() else pg.new:Disable() end
    Draw()
end
View.LogRefresh = LogView.Refresh
function LogView.Data()
    return pg.data
end
function LogView.Buttons()
    return { pg.chat, pg.say, pg.new }
end
local function Btn(page, text, tip, run, kind)
    local b = Kit.Button(page, nil, kind)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetText(text)
    b.tipTitle = false
    b.tip = tip
    b.onClick = function() run() end
    return b
end
local function AskReset()
    Kit.Confirm(T("flask.log.new.ask"), T("flask.log.new.yes"), function() F.Reset() end)
end
local function Str(page, base, token)
    local fs = Kit.Str(page, base)
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function Build(page)
    pg.page = page
    pg.sum = Str(page, "GameFontNormal", "text.primary")
    pg.kit = Str(page, "GameFontHighlightSmall", "text.secondary")
    pg.more = Str(page, "GameFontDisableSmall", "text.off")
    pg.none = Str(page, "GameFontHighlightSmall", "text.muted")
    pg.none:SetText(T("flask.log.none"))
    pg.chat = Btn(page, T("flask.log.chat"), T("flask.log.chat.tip"), View.PrintLog)
    pg.say = Btn(page, T("flask.act.say"), "", View.Announce)
    pg.new = Btn(page, T("flask.log.new"), T("flask.log.new.tip"), AskReset, "danger")
    pg.capName = Str(page, "GameFontNormalSmall", "text.title")
    pg.capRole = Str(page, "GameFontNormalSmall", "text.title")
    pg.capTotal = Str(page, "GameFontNormalSmall", "text.title")
    pg.capTotal:SetJustifyH("CENTER")
    pg.capName:SetText(T("flask.log.col.name"))
    pg.capRole:SetText(T("flask.log.col.role"))
    pg.capTotal:SetText(T("flask.log.col.total"))
    pg.list = Kit.List(NewRow, FillRow, { clear = function(r) r.who = nil end })
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        if pg.list:Wheel(delta) then Draw() end
    end)
    Place(page)
end
retry:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - elapsed
    if self.left > 0 then return end
    self:Hide()
    LogView.Refresh()
end)
local roster = CreateFrame("Frame")
roster:RegisterEvent("RAID_ROSTER_UPDATE")
roster:RegisterEvent("PARTY_MEMBERS_CHANGED")
roster:SetScript("OnEvent", function() LogView.Refresh() end)
if ns.Shell and ns.Shell.Register then
    ns.Shell.Register("flasklog", {
        label = function() return T("flask.tab") end,
        order = 125,
        tabless = true,
        build = Build,
        OnShow = function() LogView.Refresh() end,
        OnSize = function(page)
            Place(page)
            LogView.Refresh()
        end,
        OnTheme = function() LogView.Refresh() end,
    })
end
Kit.OnFont(function()
    if pg.page then Place(pg.page) end
    LogView.Refresh()
end)
