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
local NAME_GAP = 4
local TIP_USES = 8
local CHECK = 18
local LABEL_GAP = 4
local HEAD_GAP = 6
local ARROW = 10
local F = {}
ns.ReplayFeed = F
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Who = ns.ReplayWho
local ceil = math.ceil
local m = { headH = HEAD_H, rowH = ROW_H, icon = ICON, timeW = TIME_W, checkX = 0, k = 1 }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true), Kit.FontScale("GameFontNormalSmall", true))
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    local nt = Kit.FontSize("GameFontNormalSmall", true)
    m.k = k
    m.rowH = max(ROW_H, ceil(pt * 1.15) + 4)
    m.icon = max(ICON, m.rowH - 4)
    m.timeW = ceil(TIME_W * k)
    m.headH = max(HEAD_H, ceil(nt * 1.15) + 12)
end
local side, title, check, snd, sndList
local rows = {}
local kinds = {}
local vis = {}
local count = {}
local filters = {}
local st = { n = 0, top = 1, cur = 0, scrolledAt = -1e9, L = nil, onSeek = nil, rows = 0, width = 0, drawnTop = -1,
             drawnCur = -1, focus = nil, hi = 0, rare = {}, rareN = 0, fight = nil }
local Saved = RD.Saved
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
    local g = type(icon) == "string" and ns.replayFeed.glyphs[icon]
    if g and g.mark then
        Kit.Icon.Mark(tex, g.mark)
    elseif g and g.heroic then
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
local function RowRoom()
    return st.width - PAD * 2 - m.timeW - m.icon - 10
end
local function NamesWidth(row)
    return (row.actor:GetStringWidth() or 0) + (row.target:GetStringWidth() or 0)
end
local function ActionLines(action)
    if action.tipLines then return action.tipLines end
    local lines = { { kind = "head", left = action.spell } }
    for i, use in ipairs(action.uses) do
        if i > TIP_USES then break end
        lines[#lines + 1] = Who.Row(Who.Use(use.by, use.target and { use.target } or {}), Clock(use.t))
    end
    if #action.uses > TIP_USES then
        lines[#lines + 1] = { kind = "note", left = format(ns.T("rep.mk.rest"), #action.uses - TIP_USES) }
    end
    action.tipLines = lines
    return lines
end
function F.RowLines(row)
    if row.action then row.lines = ActionLines(row.action) end
    return row.lines
end
local function RowEnter(self)
    F.RowLines(self)
    Kit.ShowLines(self)
end
local function ActionText(row, action)
    row.lines, row.action = nil, action
    row.actor:Show()
    row.target:Show()
    local font = Kit.FontFor("GameFontHighlightSmall", true)
    local path, fsize, flags
    if font then path, fsize, flags = font:GetFont() end
    local room = RowRoom()
    local c = action.fit
    if c and c.room == room and c.font == font and c.fsize == fsize then
        if c.size and path then
            row.nameShrink = true
            row.actor:SetFont(path, c.size, flags)
            row.target:SetFont(path, c.size, flags)
        elseif row.nameShrink then
            row.nameShrink = nil
            row.actor:SetFontObject(font)
            row.target:SetFontObject(font)
        end
        row.actor:SetText(c.by)
        row.target:SetText(c.to)
        row.text:Show()
        local spellW = Kit.Fit(row.text, action.spell, c.spellRoom)
        row.target:ClearAllPoints()
        row.target:SetPoint("LEFT", row.actor, "RIGHT", spellW + (spellW > 0 and 2 * NAME_GAP or NAME_GAP), 0)
        return
    end
    local actors, targets, seenBy, seenTo = {}, {}, {}, {}
    for _, use in ipairs(action.uses) do
        local by, target = use.by, use.target
        if not seenBy[by] then
            seenBy[by] = true
            actors[#actors + 1] = by
        end
        if target and not seenTo[target] then
            seenTo[target] = true
            targets[#targets + 1] = target
        end
    end
    if row.nameShrink then
        row.nameShrink = nil
        row.actor:SetFontObject(font)
        row.target:SetFontObject(font)
    end
    local byN, toN = min(5, #actors), min(5, #targets)
    local nameRoom = RowRoom() - 2 * NAME_GAP
    local used, byText, toText
    repeat
        byText = Who.List(actors, nil, byN) or ""
        toText = Who.List(targets, nil, toN) or ""
        row.actor:SetText(byText)
        row.target:SetText(toText)
        used = NamesWidth(row)
        if used < nameRoom or (byN <= 1 and toN <= 1) then break end
        if toN >= byN then toN = toN - 1 else byN = byN - 1 end
    until false
    local shrunk
    if used > nameRoom and font and path and fsize then
        row.nameShrink = true
        shrunk = max(1, floor(fsize * nameRoom / used))
        row.actor:SetFont(path, shrunk, flags)
        row.target:SetFont(path, shrunk, flags)
        used = NamesWidth(row)
    end
    action.fit = { room = room, font = font, fsize = fsize, size = shrunk, by = byText, to = toText,
                   spellRoom = nameRoom - used }
    row.text:Show()
    local spellW = Kit.Fit(row.text, action.spell, nameRoom - used)
    row.target:ClearAllPoints()
    row.target:SetPoint("LEFT", row.actor, "RIGHT", spellW + (spellW > 0 and 2 * NAME_GAP or NAME_GAP), 0)
end
local function RowText(row, L, i)
    if row.data == L and row.idx == i then return end
    row.data, row.idx = L, i
    row.time:SetText(Clock(L.fdT[i]))
    SetIcon(row.icon, L.fdIcon[i])
    local action = L.fdAction and L.fdAction[i]
    row.text:ClearAllPoints()
    if action then
        row.text:SetPoint("LEFT", row.actor, "RIGHT", NAME_GAP, 0)
        row.tip = nil
        ActionText(row, action)
    else
        row.text:SetPoint("LEFT", row.icon, "RIGHT", PAD, 0)
        row.text:SetWidth(RowRoom())
        row.text:SetText(L.fdText[i])
        row.text:Show()
        row.actor:Hide()
        row.target:Hide()
        row.lines, row.action = nil, nil
        row.tip = L.fdTip and L.fdTip[i] or L.fdText[i]
    end
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
            row:Show()
            RowText(row, L, i)
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
    b.tipClick = ns.T(on and "fx.hint.toggle" or "fx.hint.show")
end
local function Fight()
    if st.fight then return st.fight end
    local sc = ns.ReplayIso and ns.ReplayIso.Scene and ns.ReplayIso.Scene()
    return sc and sc.layers == (st.base or st.L) and sc.fight or nil
end
local function Pass(L, i)
    for _, fn in pairs(filters) do
        if not fn(L, i) then return false end
    end
    return true
end
local function Refilter()
    local L = st.L
    local only = Saved().feedImp == true
    local off = Off()
    for k in pairs(count) do count[k] = nil end
    local n = 0
    local rare = st.rare
    if L and only then rare, st.rareN = ns.ReplayRare.Mark(L, Fight(), st.rare) end
    if L then
        for i = 1, L.nf do
            local kind = L.fdKind and L.fdKind[i] or "boss"
            count[kind] = (count[kind] or 0) + 1
            if not off[kind] and (not only or rare[i]) and Pass(L, i) then
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
    local y = -floor((m.headH - CHECK) / 2)
    m.checkX = ceil(check.label:GetStringWidth() or 0) + LABEL_GAP + PAD
    check:ClearAllPoints()
    check:SetPoint("TOPRIGHT", side, "TOPRIGHT", -m.checkX, y)
    local x = m.checkX + CHECK + HEAD_GAP
    sndList:ClearAllPoints()
    sndList:SetPoint("TOPRIGHT", side, "TOPRIGHT", -x, -floor((m.headH - (sndList:GetHeight() or 0)) / 2))
    x = x + (sndList:GetWidth() or 0) + 1 + ceil(snd.label:GetStringWidth() or 0) + LABEL_GAP
    snd:ClearAllPoints()
    snd:SetPoint("TOPRIGHT", side, "TOPRIGHT", -x, y)
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
    row.text:SetHeight(m.rowH - 4)
    row.data = nil
end
local function NewRow(r)
    local row = Kit.Row(side, st.width - PAD * 2)
    Kit.Bind(row.text, "GameFontHighlightSmall")
    Kit.OneLine(row.text)
    row.time = Kit.Str(row, "GameFontHighlightSmall")
    row.time:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.time:SetJustifyH("LEFT")
    Kit.Text(row.time, "text.secondary")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.actor = Kit.Str(row, "GameFontHighlightSmall")
    Kit.OneLine(row.actor)
    row.actor:SetPoint("LEFT", row.icon, "RIGHT", PAD, 0)
    Kit.Text(row.actor, "text.secondary")
    row.target = Kit.Str(row, "GameFontHighlightSmall")
    Kit.OneLine(row.target)
    Kit.Text(row.target, "text.secondary")
    PlaceRow(row, r)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetWidth(MARK_W)
    row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    Kit.Paint(row.mark, "sem.rep.focus")
    row.mark:Hide()
    row.onClick = RowClick
    row:HookScript("OnEnter", RowEnter)
    row:HookScript("OnLeave", Kit.HideLines)
    row:Hide()
    rows[r] = row
    return row
end
local function SoundTip()
    local Snd = ns.ReplaySound
    sndList.tip = Snd.Tip(st.base or st.L)
    snd:SetChecked(Snd.On())
    if sndList.hovered then Kit.TipShow(sndList) end
end
local function BuildSound(parent)
    local Snd = ns.ReplaySound
    snd = Kit.Check(parent)
    snd:SetWidth(CHECK)
    snd:SetHeight(CHECK)
    Kit.Bind(snd.label, "GameFontNormalSmall")
    snd.label:SetText(ns.T("rep.snd"))
    snd.tip = ns.T("rep.snd.tip")
    snd.tipTitle = false
    snd:SetChecked(Snd.On())
    snd.onToggle = function(on) Snd.SetOn(on) end
    sndList = Kit.IconButton(parent, nil, ARROW)
    Kit.Arrow(sndList.icon, false)
    sndList.tipTitle = ns.T("rep.snd.menu")
    sndList.clickSfx = "open"
    sndList.onClick = function(self) Snd.Menu(self, SoundTip) end
    SoundTip()
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
    BuildSound(parent)
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
    local was = m.rowH * 1000 + m.timeW * 10 + m.headH * 100000
    Metrics()
    local now = m.rowH * 1000 + m.timeW * 10 + m.headH * 100000
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
function F.Use(L, fight)
    st.base, st.L, st.fight = L, L, fight
    for r = 1, #rows do rows[r].data = nil end
    Refilter()
    if sndList then SoundTip() end
    return L ~= nil and L.nf > 0
end
function F.SetSource(src)
    local L = src or st.base
    if st.L == L then return end
    st.L = L
    for r = 1, #rows do rows[r].data = nil end
    Refilter()
end
function F.SetFilter(key, fn)
    filters[key] = fn
    if side then Refilter() end
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
    return { shown = st.n, rows = st.rows, kinds = #kinds, count = count, focus = st.focus, hi = st.hi, rare = st.rareN,
             head = { title = title, imp = check, snd = snd, sndList = sndList },
             mode = st.L and st.L ~= st.base and st.L.mode or nil, vis = vis, L = st.L }
end
