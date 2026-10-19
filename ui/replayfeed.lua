local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local HEAD_H = 24
local KIND_H = 20
local KIND_SIZE = 16
local KIND_GAP = 3
local ROW_H = 18
local TIME_W = 34
local ICON = 14
local PAD = 4
local FOLLOW_AFTER = 4
local LEAD_ROWS = 3
local OFF_ALPHA = 0.35
local MARK_W = 2
local F = {}
ns.ReplayFeed = F
local Kit = ns.Kit
local ceil = math.ceil
local m = { headH = HEAD_H, rowH = ROW_H, icon = ICON, timeW = TIME_W, checkX = 70, k = 1 }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true), Kit.FontScale("GameFontNormalSmall", true))
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    local nt = Kit.FontSize("GameFontNormalSmall", true)
    m.k = k
    m.rowH = max(ROW_H, ceil(pt * 1.15) + 4)
    m.icon = max(ICON, m.rowH - 4)
    m.timeW = ceil(TIME_W * k)
    m.headH = max(HEAD_H, ceil(nt * 1.15) + 12)
    m.checkX = ceil(70 * k)
end
local side, title, check
local rows = {}
local kinds = {}
local vis = {}
local count = {}
local st = { n = 0, top = 1, cur = 0, scrolledAt = -1e9, L = nil, onSeek = nil, rows = 0, width = 0, drawnTop = -1,
             drawnCur = -1, focus = nil, hi = 0 }
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
local function Off()
    local saved = Saved()
    if type(saved.feedOff) ~= "table" then saved.feedOff = {} end
    return saved.feedOff
end
local function Clock(sec)
    sec = max(0, floor(sec))
    return format("%d:%02d", floor(sec / 60), sec % 60)
end
local function SetIcon(tex, icon)
    if icon == "death" then
        Kit.Icon.Mark(tex, 8)
    elseif icon == "wave" then
        Kit.Icon.Mark(tex, 7)
    elseif icon == "phase" then
        Kit.Icon.Heroic(tex)
    else
        local id = tonumber(icon)
        Kit.Icon.Spell(tex, id and id > 0 and id or nil)
    end
end
local function Mine(L, i, name)
    if not name or not L.fdWho then return false end
    if L.fdWho[i] == name then return true end
    local all = L.fdAll and L.fdAll[i]
    if not all then return false end
    for k = 1, #all do
        if all[k] == name then return true end
    end
    return false
end
local function RowClick(self)
    local L = st.L
    if not (self.idx and L and st.onSeek) then return end
    local who = L.fdWho and L.fdWho[self.idx] or nil
    if self.mine then who = st.focus end
    st.onSeek(L.fdT[self.idx], who or nil)
end
local function Draw()
    local L = st.L
    if not L then
        for r = 1, st.rows do rows[r]:Hide() end
        return
    end
    if st.drawnTop == st.top and st.drawnCur == st.cur then return end
    st.drawnTop, st.drawnCur = st.top, st.cur
    local hi = 0
    for r = 1, st.rows do
        local row = rows[r]
        local pos = st.top + r - 1
        local i = vis[pos]
        if pos <= st.n and i then
            row.idx = i
            row.time:SetText(Clock(L.fdT[i]))
            row.text:SetText(L.fdText[i])
            row.tip = L.fdTip and L.fdTip[i] or L.fdText[i]
            SetIcon(row.icon, L.fdIcon[i])
            row.mine = Mine(L, i, st.focus)
            if row.mine then
                hi = hi + 1
                row.mark:Show()
                Kit.Text(row.text, "sem.rep.focusText")
            else
                row.mark:Hide()
                Kit.Text(row.text, L.fdImp[i] and "sem.rep.important" or "text.secondary")
            end
            row.on = pos == st.cur
            Kit.StyleRow(row)
            row:Show()
        else
            row.idx, row.mine = nil, nil
            row:Hide()
        end
    end
    st.hi = hi
end
local function ScrollTo(top)
    st.top = max(1, min(top, st.n - st.rows + 1))
    Draw()
end
local function Wheel(_, delta)
    if st.n == 0 then return end
    st.scrolledAt = GetTime()
    ScrollTo(st.top - delta * 3)
end
local function StyleKind(b)
    local on = not Off()[b.kind]
    b.icon:SetDesaturated(not on)
    b.icon:SetAlpha(on and 1 or OFF_ALPHA)
    Kit.Paint(b.bg, on and "row.bgOn" or "row.bg")
    local n = count[b.kind] or 0
    b.tip = format(ns.T(on and "rep.k.on" or "rep.k.off"), ns.T(b.def.tip), n)
end
local function Refilter()
    local L = st.L
    local only = Saved().feedImp == true
    local off = Off()
    for k in pairs(count) do count[k] = nil end
    local n = 0
    if L then
        for i = 1, L.nf do
            local kind = L.fdKind and L.fdKind[i] or "boss"
            count[kind] = (count[kind] or 0) + 1
            if not off[kind] and (not only or L.fdImp[i]) then
                n = n + 1
                vis[n] = i
            end
        end
    end
    for i = n + 1, #vis do vis[i] = nil end
    for i = 1, #kinds do StyleKind(kinds[i]) end
    st.n, st.top, st.cur, st.drawnTop, st.drawnCur = n, 1, 0, -1, -1
    st.scrolledAt = -1e9
    Draw()
end
local function KindClick(self)
    local off = Off()
    off[self.kind] = not off[self.kind] or nil
    Kit.Sound(off[self.kind] and "checkOff" or "checkOn")
    Refilter()
    Kit.TipShow(self)
end
local function KindButton(parent, i, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(KIND_SIZE + 2)
    b:SetHeight(KIND_SIZE + 2)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetWidth(KIND_SIZE)
    b.icon:SetHeight(KIND_SIZE)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    SetIcon(b.icon, def.icon)
    b.kind, b.def = def.key, def
    b.tipTitle = ns.T(def.label)
    b:SetScript("OnClick", KindClick)
    b:SetScript("OnEnter", Kit.TipShow)
    b:SetScript("OnLeave", Kit.TipHide)
    StyleKind(b)
    return b
end
local function PlaceHead()
    title:ClearAllPoints()
    title:SetPoint("LEFT", side, "TOPLEFT", PAD + 2, -floor(m.headH / 2))
    check:ClearAllPoints()
    check:SetPoint("TOPRIGHT", side, "TOPRIGHT", -m.checkX, -floor((m.headH - 18) / 2))
    for i = 1, #kinds do
        kinds[i]:ClearAllPoints()
        kinds[i]:SetPoint("TOPLEFT", side, "TOPLEFT", PAD + (i - 1) * (KIND_SIZE + 2 + KIND_GAP), -(m.headH - 1))
    end
end
local function PlaceRow(row, r)
    local width = st.width
    row:SetWidth(width - PAD * 2)
    row:SetHeight(m.rowH)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", side, "TOPLEFT", PAD, -(m.headH + KIND_H + (r - 1) * m.rowH))
    row.time:SetWidth(m.timeW)
    row.icon:SetWidth(m.icon)
    row.icon:SetHeight(m.icon)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", m.timeW + 2, 0)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.text:SetWidth(width - PAD * 2 - m.timeW - m.icon - 10)
    row.text:SetHeight(m.rowH - 4)
end
local function NewRow(r)
    local row = Kit.Row(side, st.width - PAD * 2)
    Kit.Bind(row.text, "GameFontHighlightSmall")
    row.time = Kit.Str(row, "GameFontHighlightSmall")
    row.time:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.time:SetJustifyH("LEFT")
    Kit.Text(row.time, "text.secondary")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    PlaceRow(row, r)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetWidth(MARK_W)
    row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    Kit.Paint(row.mark, "sem.rep.focus")
    row.mark:Hide()
    row.onClick = RowClick
    row:Hide()
    rows[r] = row
    return row
end
function F.Build(parent, width, height, onSeek)
    side = parent
    st.onSeek = onSeek
    st.width = width
    Metrics()
    title = Kit.Str(parent, "GameFontNormalSmall")
    title:SetText(ns.T("rep.feed"))
    Kit.Text(title, "text.primary")
    check = Kit.Check(parent)
    check:SetWidth(18)
    check:SetHeight(18)
    Kit.Bind(check.label, "GameFontNormalSmall")
    check.label:SetText(ns.T("rep.feed.imp"))
    check.tip = ns.T("rep.feed.imp.tip")
    check.tipTitle = false
    check:SetChecked(Saved().feedImp == true)
    check.onToggle = function(on)
        Saved().feedImp = on
        Refilter()
    end
    local defs = ns.replayFeed.kinds
    for i = 1, #defs do kinds[i] = KindButton(parent, i, defs[i]) end
    PlaceHead()
    st.height = height
    st.rows = max(0, floor((height - m.headH - KIND_H) / m.rowH))
    for r = 1, st.rows do NewRow(r) end
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", Wheel)
end
function F.Fit(width, height)
    if not side then return end
    local was = m.rowH * 1000 + m.timeW * 10 + m.headH * 100000 + m.checkX
    Metrics()
    local now = m.rowH * 1000 + m.timeW * 10 + m.headH * 100000 + m.checkX
    local n = max(0, floor((height - m.headH - KIND_H) / m.rowH))
    if n == st.rows and now == was and width == st.width and height == st.height then return end
    st.width, st.height = width, height
    side:SetWidth(width)
    PlaceHead()
    for r = #rows + 1, n do NewRow(r) end
    for r = 1, #rows do PlaceRow(rows[r], r) end
    for r = n + 1, #rows do rows[r]:Hide() end
    st.rows = n
    st.drawnTop, st.drawnCur = -1, -1
    ScrollTo(st.top)
end
function F.SetHeight(height)
    F.Fit(st.width, height)
end
function F.Use(L)
    st.L = L
    Refilter()
    return L ~= nil and L.nf > 0
end
function F.Update(sec)
    local L = st.L
    if not L or st.n == 0 then return end
    local lo, hi = 0, st.n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if L.fdT[vis[mid]] <= sec then lo = mid else hi = mid - 1 end
    end
    if lo == st.cur then return end
    st.cur = lo
    if GetTime() - st.scrolledAt > FOLLOW_AFTER and lo > 0 then
        st.top = max(1, min(lo - LEAD_ROWS, st.n - st.rows + 1))
    end
    Draw()
end
function F.SetFocus(name)
    if st.focus == name then return end
    st.focus = name
    st.drawnTop = -1
    Draw()
end
function F.Ready()
    return side ~= nil
end
function F.Stats()
    return { shown = st.n, rows = st.rows, kinds = #kinds, count = count, focus = st.focus, hi = st.hi }
end
