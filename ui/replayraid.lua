local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local format = string.format
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CELL_W = 62
local ICON = 12
local CAST = 16
local MAX_K = 2
local MANA_H = 2
local EDGE = 1
local INNER = 2
local GAP = 2
local PAD = 3
local MARGIN = 6
local STRIP = 14
local GRIP = 10
local MIN_CELL_W = 34
local MAX_WIN = 3
local FONT_PREFIX = "HTP_FailWatchRepRaid"
local OPEN_PAD = 16
local OPEN_LEVEL = 3
local OPEN_BED = 3
local LR, LG, LB = 0.2126, 0.7152, 0.0722
local GRAY = 0.35
local st = { roles = {}, cols = {}, cells = {}, used = 0, t = 0 }
local V = {}
ns.ReplayRaidView = V
local Kit = ns.Kit
local RR = ns.ReplayRaid
local m = { w = CELL_W, h = 30, icon = ICON, cast = CAST, nick = 12, strip = STRIP, n = 3, nickW = 30, w0 = CELL_W,
            h0 = 30, icon0 = ICON, cast0 = CAST }
local shown = {}
local hpCur = setmetatable({}, { __mode = "k" })
local fonts = {}
local function NickFont()
    local size = max(6, floor(Kit.FontSize("GameFontHighlightSmall", true) + 0.5))
    local f = fonts[size]
    if not f then
        f = CreateFont(FONT_PREFIX .. size)
        fonts[size] = f
    end
    local base = Kit.FontFor("GameFontHighlightSmall", true) or GameFontHighlightSmall
    f:SetFontObject(base)
    local path = base:GetFont()
    if path then f:SetFont(path, size, "OUTLINE") end
    return f
end
local Saved = RR.Saved
local forced = false
function V.On()
    return forced or Saved().off ~= true
end
function V.Free()
    return Saved().dock ~= true
end
function V.Opt(key)
    return Saved()[key] ~= false
end
function V.SetOpt(key, on)
    if on then Saved()[key] = nil else Saved()[key] = false end
    for i = 1, #st.cells do
        local c = st.cells[i]
        c.state, c.castId, c.manaQ, c.hpQ = nil, nil, nil, nil
    end
    V.Layout()
end
function V.Tone(class)
    local r, g, b = Kit.ClassColor(class)
    local want = Kit.RGB("sem.rep.raidFill")
    local k = want / max(0.05, r * LR + g * LG + b * LB)
    local gray = want * GRAY
    local s = 1 - GRAY
    return min(1, r * k * s + gray), min(1, g * k * s + gray), min(1, b * k * s + gray)
end
local function Metrics()
    local k = Kit.FontScale("GameFontHighlightSmall", true)
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    m.nick = ceil(pt + 2)
    local wk = Kit.Grow().wk
    local ik = k < 1 and k or wk
    m.icon0 = max(8, floor(ICON * ik + 0.5))
    m.cast0 = max(10, floor(CAST * ik + 0.5))
    m.h0 = EDGE * 2 + INNER + m.nick + 1 + m.icon0 + INNER + MANA_H
    m.w0 = max(MIN_CELL_W, ceil(CELL_W * max(1, wk)))
    m.strip = max(STRIP, ceil(pt + 4))
    m.font = NickFont()
end
local function Adapt(w, h)
    m.w, m.h = w, h
    local k = max(1, min(MAX_K, w / m.w0, h / m.h0))
    local row = h - EDGE * 2 - INNER - m.nick - 1 - INNER - MANA_H
    m.cast = max(10, min(h - EDGE * 2 - MANA_H - INNER * 2, floor(m.cast0 * k)))
    local inner = w - EDGE * 2 - INNER * 2
    local castW = V.Opt("cast") and m.cast + INNER or 0
    m.icon = max(8, min(row, floor(m.icon0 * k), floor((inner - castW + 1) / 3) - 1))
    m.n = max(1, min(ns.replayRaid.icons, floor((inner - castW + 1) / (m.icon + 1))))
    m.nickW = max(4, inner - castW)
end
local function Rows()
    local n = 0
    for i = 1, #st.cols do n = max(n, #st.cols[i]) end
    return n
end
local function GridSize(w, h)
    local cols, rows = #st.cols, Rows()
    return PAD * 2 + cols * w + max(0, cols - 1) * GAP, rows * h + max(0, rows - 1) * GAP
end
local function PlaceCell(cell)
    cell:SetWidth(m.w)
    cell:SetHeight(m.h)
    cell.well:ClearAllPoints()
    cell.well:SetPoint("TOPLEFT", cell, "TOPLEFT", EDGE, -EDGE)
    cell.well:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -EDGE, EDGE)
    cell.fill:ClearAllPoints()
    cell.fill:SetPoint("TOPLEFT", cell, "TOPLEFT", EDGE, -EDGE)
    cell.fill:SetHeight(m.h - EDGE * 2 - MANA_H)
    cell.nick:ClearAllPoints()
    cell.nick:SetPoint("TOPLEFT", cell, "TOPLEFT", EDGE + INNER, -(EDGE + INNER))
    cell.nick:SetFontObject(m.font)
    cell.nick:SetWidth(m.nickW)
    cell.nick:SetHeight(m.nick)
    local y = EDGE + INNER + m.nick + 1
    for i = 1, #cell.auras do
        local a = cell.auras[i]
        a:SetWidth(m.icon)
        a:SetHeight(m.icon)
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", cell, "TOPLEFT", EDGE + INNER + (i - 1) * (m.icon + 1), -y)
        a:Hide()
        cell.ids[i] = false
    end
    cell.cast:SetWidth(m.cast)
    cell.cast:SetHeight(m.cast)
    cell.cast:ClearAllPoints()
    cell.cast:SetPoint("RIGHT", cell, "TOPRIGHT", -(EDGE + INNER), -(EDGE + (m.h - EDGE * 2 - MANA_H) / 2))
    cell.manaBg:ClearAllPoints()
    cell.manaBg:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", EDGE, EDGE)
    cell.manaBg:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -EDGE, EDGE)
    cell.manaBg:SetHeight(MANA_H)
    cell.mana:ClearAllPoints()
    cell.mana:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", EDGE, EDGE)
    cell.mana:SetHeight(MANA_H)
    cell.fill:SetVertexColor(V.Tone(cell.class))
    cell.hpQ, cell.manaQ, cell.lo, cell.hi = nil, nil, 1, 0
end
local CellEnter
local CellClick
local function NewCell(parent)
    local c = CreateFrame("Button", nil, parent)
    c.edge = c:CreateTexture(nil, "BACKGROUND")
    c.edge:SetAllPoints(c)
    Kit.Paint(c.edge, "sem.rep.raidEdge")
    c.well = c:CreateTexture(nil, "BORDER")
    Kit.Paint(c.well, "sem.rep.raidBg")
    c.fill = c:CreateTexture(nil, "ARTWORK")
    c.fill:SetTexture(WHITE)
    c.nick = c:CreateFontString(nil, "OVERLAY")
    c.nick:SetFontObject(NickFont())
    c.nick:SetJustifyH("LEFT")
    c.nick:SetJustifyV("TOP")
    c.nick:SetWordWrap(false)
    Kit.Halo(c.nick)
    c.auras, c.ids = {}, {}
    for i = 1, ns.replayRaid.icons do
        local a = c:CreateTexture(nil, "OVERLAY")
        a:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        a:Hide()
        c.auras[i] = a
    end
    c.cast = c:CreateTexture(nil, "OVERLAY")
    c.cast:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.cast:Hide()
    c.manaBg = c:CreateTexture(nil, "ARTWORK")
    Kit.Paint(c.manaBg, "sem.rep.manaBg")
    c.mana = c:CreateTexture(nil, "OVERLAY")
    Kit.Paint(c.mana, "sem.rep.mana")
    c.heal = false
    c:RegisterForClicks("LeftButtonUp")
    c:SetScript("OnClick", function(self) CellClick(self) end)
    c:SetScript("OnEnter", function(self) CellEnter(self) end)
    c:SetScript("OnLeave", function(self)
        if st.hover == self then st.hover = nil end
        Kit.Tip.Hide()
    end)
    return c
end
local function Edge(cell)
    Kit.Paint(cell.edge, (cell.focus and "sem.rep.focus") or (cell.low and "sem.rep.raidLow") or "sem.rep.raidEdge")
    Kit.Paint(cell.well, cell.low and "sem.rep.raidLowBg" or "sem.rep.raidBg")
end
local function Low(cell)
    local q = cell.hpQ
    local on = st.low ~= nil and cell.state == "" and q ~= nil and q > 0 and q < st.low * 100
    if on ~= (cell.low == true) then
        cell.low = on
        Edge(cell)
    end
end
local function PlaceGrid(grid, x0, y0)
    st.grid = grid
    local used = 0
    for ci = 1, #st.cols do
        local col = st.cols[ci]
        for ri = 1, #col do
            used = used + 1
            local cell = st.cells[used]
            cell:SetParent(grid)
            cell:SetFrameLevel(grid:GetFrameLevel() + 1)
            PlaceCell(cell)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", grid, "TOPLEFT", x0 + PAD + (ci - 1) * (m.w + GAP), -(y0 + (ri - 1) * (m.h + GAP)))
            cell:Show()
        end
    end
    for i = used + 1, #st.cells do st.cells[i]:Hide() end
end
local Layout
local function SetFree(free)
    Saved().dock = (not free) and true or nil
    Layout()
end
function V.SetOn(on)
    forced = false
    Saved().off = (not on) and true or nil
    Layout()
end
function V.Force(on)
    if forced == on then return end
    forced = on
    Layout()
end
local function Part(parent, glyph, tip, fn, icon)
    local b = Kit.TabPart(parent, glyph, icon, icon and STRIP - 2 or nil)
    b.tipTitle = ns.T(tip)
    b.tip = ns.T(tip .. ".tip")
    b.onClick = fn
    return b
end
local function Cfg(host)
    if ns.ReplayRaidCfg then ns.ReplayRaidCfg.Toggle(host) end
end
local function SeatParts(f, list, inset)
    for i = 1, #list do
        local b = list[i]
        b:SetWidth(m.strip)
        b:SetHeight(m.strip)
        b:SetFrameLevel(f:GetFrameLevel() + 2)
        if b.icon then
            b.icon:SetWidth(m.strip - 2)
            b.icon:SetHeight(m.strip - 2)
        end
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(inset + PAD + (i - 1) * (m.strip + GAP)), -(inset + 1))
    end
end
local function BuildPanel(top)
    local p = CreateFrame("Frame", nil, top)
    p:SetFrameLevel(min(120, top:GetFrameLevel() + 1))
    p:EnableMouse(true)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints(p)
    Kit.Paint(p.bg, "sem.rep.plate")
    p.close = Part(p, "close", "iso.raid.off", function() V.SetOn(false) end)
    p.free = Part(p, "unmax", "iso.raid.free", function() SetFree(true) end)
    p.gear = Part(p, nil, "iso.raidcfg", function() Cfg(p) end, Kit.GEAR_TEX)
    p.parts = { p.close, p.free, p.gear }
    st.panel = p
end
local function Inset()
    local skin = Kit.Theme().list
    return skin and skin.backdrop and skin.backdrop.insets and skin.backdrop.insets.left or 4
end
local function Head()
    return Inset() + 1 + m.strip + 2
end
local function Limits()
    local ins = Inset()
    local gw, gh = GridSize(m.w0, m.h0)
    local w, h = gw + ins * 2, gh + Head() + GRIP + ins
    local bw, bh = GridSize(m.w0 * MAX_WIN, m.h0 * MAX_WIN)
    return w, h, max(w, bw + ins * 2), max(h, bh + Head() + GRIP + ins)
end
local function FillWin()
    local w = st.win
    local ins = Inset()
    local cols, rows = #st.cols, Rows()
    local W, H = w:GetWidth() or 0, w:GetHeight() or 0
    local cw = floor((W - ins * 2 - PAD * 2 - GAP * (cols - 1)) / max(1, cols))
    local ch = floor((H - Head() - GRIP - ins - GAP * (rows - 1)) / max(1, rows))
    Adapt(max(m.w0, cw), max(m.h0, ch))
    PlaceGrid(w, ins, Head())
end
local function SavePlace(f)
    f:StopMovingOrSizing()
    f:SetUserPlaced(false)
    local s = Saved()
    s.x, s.y = floor((f:GetLeft() or 0) + 0.5), floor((f:GetTop() or 0) + 0.5)
end
local function StopSizing(w)
    if not st.sizing then return end
    st.sizing = nil
    w:StopMovingOrSizing()
    w:SetUserPlaced(false)
    local s = Saved()
    s.w, s.h = floor(w:GetWidth() + 0.5), floor(w:GetHeight() + 0.5)
    s.x, s.y = floor((w:GetLeft() or 0) + 0.5), floor((w:GetTop() or 0) + 0.5)
    Layout()
end
local function BuildWin(frame)
    local w = CreateFrame("Frame", nil, frame)
    w:SetFrameStrata("FULLSCREEN_DIALOG")
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:SetResizable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function(self) self:StartMoving() end)
    w:SetScript("OnDragStop", SavePlace)
    w:SetScript("OnSizeChanged", function()
        if st.sizing then FillWin() end
    end)
    Kit.Skin(w, "list")
    w.title = Kit.Str(w, "GameFontNormalSmall")
    w.title:SetJustifyH("LEFT")
    w.title:SetWordWrap(false)
    w.title:SetText(ns.T("iso.raid"))
    Kit.Text(w.title, "text.title")
    w.close = Part(w, "close", "iso.raid.off", function() V.SetOn(false) end)
    w.dock = Part(w, "fold", "iso.raid.dock", function() SetFree(false) end)
    w.gear = Part(w, nil, "iso.raidcfg", function() Cfg(w) end, Kit.GEAR_TEX)
    w.parts = { w.close, w.dock, w.gear }
    local grip = Kit.Grip(w, GRIP)
    grip:SetFrameLevel(w:GetFrameLevel() + 3)
    grip.tipTitle = ns.T("iso.raid.size")
    grip.tip = ns.T("iso.raid.size.tip")
    grip.onDown = function(_, button)
        if button ~= "LeftButton" then return end
        st.sizing = true
        w:StartSizing("BOTTOMRIGHT")
    end
    grip.onUp = function() StopSizing(w) end
    grip:HookScript("OnHide", function() StopSizing(w) end)
    w.grip = grip
    w:Hide()
    st.win = w
end
local function LayoutPanel(view)
    local p = st.panel
    local nav = ns.ReplayIsoBuild.NAV_W
    local cols = #st.cols
    local room = (view:GetWidth() or 0) - nav - MARGIN * 2
    local fit = floor((room - PAD * 2 - GAP * (cols - 1)) / max(1, cols))
    Adapt(max(MIN_CELL_W, min(m.w0, fit)), m.h0)
    PlaceGrid(p, 0, m.strip + 2)
    local w, h = GridSize(m.w, m.h)
    p:SetWidth(w)
    p:SetHeight(h + m.strip + 2 + PAD)
    p:ClearAllPoints()
    p:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -nav, MARGIN)
    SeatParts(p, p.parts, -1)
    p:Show()
end
local function Screen(w)
    local k = (UIParent:GetEffectiveScale() or 1) / max(0.01, w:GetEffectiveScale() or 1)
    return (UIParent:GetWidth() or 0) * k, (UIParent:GetHeight() or 0) * k
end
local function Fit(w, s)
    local sw, sh = Screen(w)
    local W, H = w:GetWidth() or 0, w:GetHeight() or 0
    local x = min(max(0, tonumber(s.x) or 0), max(0, sw - W))
    local y = max(min(sh, tonumber(s.y) or sh), min(sh, H))
    s.x, s.y = floor(x + 0.5), floor(y + 0.5)
end
local function LayoutWin()
    local w = st.win
    local ins = Inset()
    local s = Saved()
    local lw, lh, hw, hh = Limits()
    local sw, sh = Screen(w)
    hw, hh = max(lw, min(hw, sw)), max(lh, min(hh, sh))
    w:SetMinResize(lw, lh)
    w:SetMaxResize(hw, hh)
    w:SetWidth(min(hw, max(lw, tonumber(s.w) or lw)))
    w:SetHeight(min(hh, max(lh, tonumber(s.h) or lh)))
    FillWin()
    w.title:ClearAllPoints()
    w.title:SetPoint("TOPLEFT", w, "TOPLEFT", ins + PAD, -(ins + 1))
    w.title:SetPoint("RIGHT", w, "RIGHT", -(ins + PAD + (m.strip + GAP) * #w.parts), 0)
    w.title:SetHeight(m.strip)
    SeatParts(w, w.parts, ins)
    w.grip:ClearAllPoints()
    w.grip:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -ins + 2, ins - 2)
    w:ClearAllPoints()
    if s.x and s.y then
        Fit(w, s)
        w:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x, s.y)
    else
        w:SetPoint("BOTTOMRIGHT", ns.ReplayIso.ViewFrame(), "BOTTOMRIGHT", -ns.ReplayIsoBuild.NAV_W, MARGIN)
        local l, top = w:GetLeft(), w:GetTop()
        if l and top then
            local at = { x = l, y = top }
            Fit(w, at)
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", at.x, at.y)
        end
    end
    w:Show()
end
local function PlaceOpen(view, show)
    local b, bed = st.open, st.openBed
    if not show then
        bed:Hide()
        b:Hide()
        return
    end
    local h = Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
    local w = ceil((b.text:GetStringWidth() or 0) + OPEN_PAD * 2)
    local lv = min(126, st.top:GetFrameLevel() + OPEN_LEVEL)
    bed:SetWidth(w + OPEN_BED * 2)
    bed:SetHeight(h + OPEN_BED * 2)
    bed:SetFrameLevel(lv)
    bed:ClearAllPoints()
    bed:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -ns.ReplayIsoBuild.NAV_W, MARGIN)
    bed:Show()
    b:SetHeight(h)
    b:SetWidth(w)
    b:SetFrameLevel(lv + 1)
    b:ClearAllPoints()
    b:SetPoint("CENTER", bed, "CENTER", 0, 0)
    b:Show()
end
Layout = function()
    if not st.panel then return end
    local view = ns.ReplayIso.ViewFrame()
    local shut = not V.On()
    Metrics()
    PlaceOpen(view, shut and st.scene ~= nil and #st.cols > 0)
    local on = not shut and st.scene ~= nil and #st.cols > 0
    if not on then
        st.panel:Hide()
        st.win:Hide()
        if ns.ReplayRaidCfg then ns.ReplayRaidCfg.Hide() end
        return
    end
    if V.Free() then
        st.panel:Hide()
        LayoutWin()
    else
        st.win:Hide()
        LayoutPanel(view)
    end
    if ns.ReplayRaidCfg then ns.ReplayRaidCfg.Refresh(st.grid) end
    if ns.ReplayIso.Wake then ns.ReplayIso.Wake() end
end
V.Layout = Layout
local function NickText(fs, cell)
    local s = cell.state
    if s == "" or not V.Opt("state") then
        fs:SetText(cell.name)
        Kit.Text(fs, s == "" and "sem.rep.raidText" or "sem.rep.raidOff")
    else
        fs:SetText(ns.T("rep.raid." .. s))
        Kit.Text(fs, "sem.rep.raidOff")
    end
end
local function SetHp(cell, hp, state)
    local q = state == "" and RR.Q(hp) or 0
    if q ~= cell.hpQ then
        cell.hpQ = q
        if q <= 0 then
            cell.fill:Hide()
        else
            cell.fill:SetWidth(max(1, (m.w - EDGE * 2) * q / 100))
            cell.fill:Show()
        end
    end
    if state ~= cell.state then
        cell.state = state
        NickText(cell.nick, cell)
    end
    if st.low or cell.low then Low(cell) end
end
function V.SetLow(pct)
    st.low = tonumber(pct)
    for i = 1, st.used do Low(st.cells[i]) end
end
local function SetAuras(cell, u, t)
    if t >= cell.lo and t < cell.hi then return end
    local n, lo, hi = 0, -1e12, 1e12
    if u and st.want then n, lo, hi = RR.Shown(u, st.want, t, shown, m.n) end
    cell.lo, cell.hi = lo, hi
    local ids = cell.ids
    for i = 1, #cell.auras do
        local a = cell.auras[i]
        local id = i <= n and u.I[shown[i]] or false
        if id ~= ids[i] then
            ids[i] = id
            if id then
                a:SetTexture(ns.SpellIcon(id))
                a:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                a:Show()
            else
                a:Hide()
            end
        end
    end
    if st.hover == cell then CellEnter(cell) end
end
local function SetCast(cell, rec)
    local id = rec and rec.id or false
    local cut = rec and rec.cut or false
    if id == cell.castId and cut == cell.castCut then return end
    cell.castId, cell.castCut = id, cut
    if not id then
        cell.cast:Hide()
        return
    end
    cell.cast:SetTexture(ns.SpellIcon(id))
    cell.cast:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if cut then Kit.Tint(cell.cast, "sem.rep.castCut") else Kit.Tint(cell.cast, "sem.rep.icon") end
    cell.cast:Show()
end
local function SetMana(cell, v)
    local q = (cell.heal and v) and RR.Q(v) or false
    if q == cell.manaQ then return end
    cell.manaQ = q
    if not q then
        cell.mana:Hide()
        cell.manaBg:Hide()
        return
    end
    cell.manaBg:Show()
    if q <= 0 then
        cell.mana:Hide()
    else
        cell.mana:SetWidth(max(1, (m.w - EDGE * 2) * q / 100))
        cell.mana:Show()
    end
end
function V.Place(t)
    local scene = st.scene
    if not scene or not V.On() or st.used == 0 then return end
    st.t = t
    local R, units = st.R, scene.units
    local RU = ns.ReplayUnits
    local tracks = scene.tracks
    local castOn, manaOn = V.Opt("cast"), V.Opt("mana")
    for i = 1, st.used do
        local cell = st.cells[i]
        local k = cell.k
        local tr = tracks[k]
        local hp, dead = RR.Hp(tr, t, hpCur)
        local away = R and RR.Away(R, k, t) or 0
        local state = dead and "rip" or (away == 1 and "dc") or (away == 2 and "afk") or ""
        SetHp(cell, hp, state)
        SetAuras(cell, R and R.per[k], t)
        SetCast(cell, castOn and units and not dead and RU.CastAt(units.casts[tr.name], t) or nil)
        SetMana(cell, manaOn and units and not dead and RU.ManaAt(units.mana[tr.name], t) or nil)
    end
end
local function Bind(cell, k)
    local tr = st.scene.tracks[k]
    cell.k, cell.name, cell.class = k, tr.name, tr.class
    cell.heal = st.roles[tr.name] == "heal"
    cell.hpQ, cell.state, cell.castId, cell.castCut, cell.manaQ = nil, nil, nil, nil, nil
    cell.lo, cell.hi = 1, 0
    cell.fill:SetVertexColor(V.Tone(tr.class))
    cell.focus = tr.name == st.focus
    cell.low = nil
    Edge(cell)
    for i = 1, #cell.auras do
        cell.auras[i]:Hide()
        cell.ids[i] = false
    end
    cell.cast:Hide()
    cell.mana:Hide()
    cell.manaBg:Hide()
end
function V.Rewant()
    local scene = st.scene
    if not scene then return end
    st.want = RR.Want(scene.fight.boss)
    if st.R then RR.Filter(st.R, st.want) end
    for i = 1, #st.cells do st.cells[i].lo, st.cells[i].hi = 1, 0 end
    if ns.ReplayIso.Wake then ns.ReplayIso.Wake() end
end
function V.Scene()
    return st.scene, st.R, st.want
end
function V.Use(scene, roles)
    st.scene, st.R = scene, scene and scene.raid or nil
    st.roles = roles or {}
    st.used = 0
    st.cols = {}
    if ns.ReplayRaidCfg then ns.ReplayRaidCfg.Hide() end
    if not scene or not st.panel then
        if st.panel then Layout() end
        return
    end
    st.cols = RR.Columns(scene, st.roles)
    local parent = st.panel
    for ci = 1, #st.cols do
        local col = st.cols[ci]
        for ri = 1, #col do
            st.used = st.used + 1
            local cell = st.cells[st.used]
            if not cell then
                cell = NewCell(parent)
                st.cells[st.used] = cell
            end
            Bind(cell, col[ri])
        end
    end
    V.Rewant()
    Layout()
end
function V.Focus(name)
    st.focus = name
    for i = 1, st.used do
        local cell = st.cells[i]
        local on = cell.name ~= nil and cell.name == name
        if on ~= (cell.focus == true) then
            cell.focus = on
            Edge(cell)
        end
    end
end
CellClick = function(cell)
    if not cell.name then return end
    ns.ReplayIso.Focus(cell.name ~= st.focus and cell.name or nil)
end
function V.IconText(id)
    local icon = ns.SpellIcon(id)
    if not icon then return ns.SpellName(id) end
    return "|T" .. icon .. ":0|t " .. ns.SpellName(id)
end
local function Important(key)
    local boss = st.scene and st.scene.fight and st.scene.fight.boss
    local Layers = ns.ReplayLayers
    local s = Layers and Layers.StateFor(ns.replayData, key, boss)
    return s ~= nil and not Layers.State(s).focus
end
CellEnter = function(cell)
    st.hover = cell
    local R = st.R
    local u = R and cell.k and R.per[cell.k]
    local t = st.t
    local all = IsAltKeyDown() and true or false
    st.hoverAll = all
    local lines = { { kind = "head", left = cell.name or "", class = cell.class } }
    local units = st.scene and st.scene.units
    local mana = units and units.mana and cell.name and ns.ReplayUnits.ManaAt(units.mana[cell.name], t)
    lines[#lines + 1] = { kind = "row", left = format(ns.T("rep.raid.hp"), cell.hpQ or 0),
                          right = mana and format(ns.T("rep.raid.mana"), RR.Q(mana)) or nil }
    local list = u and RR.All(u, t) or {}
    local last, shown = nil, 0
    for j = 1, #list do
        local i = list[j]
        local deb = u.D[i] == true
        if all or deb or Important(u.S[i]) then
            if deb ~= last then
                lines[#lines + 1] = { kind = "sub", left = ns.T(deb and "rep.raid.debuffs" or "rep.raid.buffs"), tone = "dim" }
                last = deb
            end
            lines[#lines + 1] = { kind = "row", left = V.IconText(u.I[i]),
                                  right = format(ns.T("rep.raid.left"), max(0, ceil(u.T[i] - t))) }
            shown = shown + 1
        end
    end
    if shown == 0 then lines[#lines + 1] = { kind = "text", left = ns.T("rep.raid.none"), tone = "dim" } end
    if not all then lines[#lines + 1] = { kind = "foot", key = "alt", left = ns.T("rep.raid.all") } end
    Kit.Tip.Show(cell, lines)
end
function V.Build(ui)
    if st.panel then return end
    local mods = CreateFrame("Frame", nil, ui.frame)
    mods:RegisterEvent("MODIFIER_STATE_CHANGED")
    mods:SetScript("OnEvent", function()
        local cell = st.hover
        if cell and cell:IsVisible() and (IsAltKeyDown() and true or false) ~= st.hoverAll then CellEnter(cell) end
    end)
    st.top = ui.top
    BuildPanel(ui.top)
    BuildWin(ui.frame)
    local bed = CreateFrame("Frame", nil, ui.frame)
    Kit.Skin(bed, "plate")
    bed:Hide()
    st.openBed = bed
    local open = Kit.Button(ui.frame, nil, "main")
    Kit.ExactSize(open)
    Kit.Bind(open.text, "GameFontNormalSmall")
    open.text:SetWordWrap(false)
    open.text:SetText(ns.T("iso.raid.open"))
    open.tipTitle = ns.T("iso.raid.title")
    open.tip = ns.T("iso.raid.tip")
    open.onClick = function() V.SetOn(true) end
    open:Hide()
    st.open = open
end
function V.Auras()
    if not V.On() then V.SetOn(true) end
    if st.grid and st.grid:IsShown() and ns.ReplayRaidCfg then ns.ReplayRaidCfg.Toggle(st.grid) end
end
Kit.OnFont(function() Layout() end)
Kit.OnTheme(function()
    if st.win then Kit.Skin(st.win, "list") end
    Layout()
end)
function V.Probe()
    return { panel = st.panel, win = st.win, cells = st.cells, used = st.used, cols = st.cols, m = m, bed = st.openBed,
             want = st.want, R = st.R, focus = st.focus, grid = st.grid, limits = { Limits() }, open = st.open }
end
