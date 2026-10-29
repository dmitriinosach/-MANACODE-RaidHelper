local ADDON, ns = ...
local floor = math.floor
local abs = math.abs
local sin = math.sin
local max = math.max
local min = math.min
local sort = table.sort
local tremove = table.remove
local tinsert = table.insert
local format = string.format
local ICON = 30
local ORB = 32
local GAP = 4
local TOOLGAP = 8
local PAD = 8
local Kit = ns.Kit
local SMALL = "GameFontHighlightSmall"
local ROW_BASE = 16
local ROW_H = ROW_BASE
local ROWGAP = 4
local CTRL = 16
local CTRL_GAP = 4
local CTRL_CUT = 2
local ARROW_PIC = 12
local LINE_ICON = 14
local LINE_GAP = 4
local STRIP_H = 14
local CORNER = 18
local CORNER_GAP = 3
local CORNER_LIFT = 2
local DOT = 8
local JOB_H = 3
local JOB_IN = 2
local LONG_JOB = 1
local VIS_PERIOD = 1
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.60, 1.50, 0.05
local ZOOM_STEP = 0.10
local SNAP = 12
local WHEN = { always = true, group = true, raid = true }
local DEFAULT_LIST = { "count", "graphs" }
local GLOW = "Interface\\Buttons\\CheckButtonHilight"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local ARROWS = { prev = "Interface\\MoneyFrame\\Arrow-Left-Up", next = "Interface\\MoneyFrame\\Arrow-Right-Up" }
local LINE_TONES = { normal = "text.primary", muted = "text.note", warn = "text.warn", bad = "text.bad", good = "text.good" }
local EMPTY = {
    noraid = { key = "panel.noraid", tone = "muted" },
    nogroup = { key = "panel.nogroup", tone = "muted" },
    zone = { key = "panel.rec.state.zone", tone = "muted" },
    none = { key = "panel.none", tone = "muted" },
    paused = { key = "panel.rec.state.paused", tone = "warn" },
    off = { key = "panel.rec.state.off", tone = "warn" },
}
local GLYPHS = {
    del = { { x = 0, y = 0, w = 9, h = 1 } },
    add = { { x = 0, y = 0, w = 9, h = 1 }, { x = 0, y = 0, w = 1, h = 9 } },
    prev = {},
    next = {},
}
local ICONS = {
    { key = "log", label = "panel.log", tip = "panel.tip.log" },
    { key = "gp", label = "panel.gp", tip = "panel.tip.gp" },
    { key = "raid", label = "panel.raid", tip = "panel.tip.raid" },
    { key = "spam", label = "panel.spam", tip = "panel.tip.spam" },
    { key = "timer", label = "panel.timer" },
    { key = "cd", label = "panel.cd", tip = "panel.tip.cd" },
    { key = "settings", label = "panel.settings", tip = "panel.settings.tip", tool = true },
}
local ROW_W = PAD * 2 + #ICONS * ICON + (#ICONS - 2) * GAP + TOOLGAP
local ROOM_BASE = ROW_W - PAD * 2
local OUT = PAD + CTRL_GAP
local REACH = OUT + CTRL * 3 + CTRL_GAP * 2
local Panel = {}
ns.Panel = Panel
Panel.ROW_H = ROW_H
Panel.ROW_ROOM = ROOM_BASE
function Panel.RowH()
    return ROW_H
end
function Panel.RowRoom()
    return max(ROOM_BASE, floor(ROOM_BASE * Kit.FontScale(SMALL, true) + 0.5))
end
local function Sizes()
    ROW_H = Kit.GrowH(ROW_BASE, SMALL)
    Panel.ROW_H = ROW_H
    Panel.ROW_ROOM = Panel.RowRoom()
end
Panel.WHENS = { "always", "group", "raid", "never" }
Panel.ICONS = ICONS
local widgets = {}
local ordered = {}
local views = {}
local live = {}
local acc = {}
local rows = {}
local buttons = {}
local alerts = {}
local busyParts = {}
local ctx = { group = false, raid = false }
local frame, logBtn, strip, job, jobFill, lockGlyph, compactGlyph, lessGlyph, moreGlyph
local hoverRow
local ctrlHot
local ctrlSide = "RIGHT"
local visAcc = 0
local ctxKey = ""
local dirty, compactNow, panelHot = false, false, false
local Relayout
local function Saved()
    local s = ns.GetDB().settings
    if type(s.panel) ~= "table" then s.panel = {} end
    return s.panel
end
function Panel.IsLocked()
    return Saved().locked and true or false
end
function Panel.IsEnabled()
    return not Saved().hidden
end
function Panel.When()
    local s = Saved()
    if s.hidden then return "never" end
    return WHEN[s.when or ""] and s.when or "always"
end
function Panel.Compact()
    return Saved().compact and true or false
end
local function Wanted()
    local w = Panel.When()
    if w == "never" then return false end
    local raid = (GetNumRaidMembers() or 0) > 0
    if w == "raid" then return raid end
    if w == "group" then return raid or (GetNumPartyMembers() or 0) > 0 end
    return true
end
function Panel.Scale()
    local v = tonumber(Saved().scale) or 1
    return min(SCALE_MAX, max(SCALE_MIN, v)), SCALE_MIN, SCALE_MAX, SCALE_STEP
end
local function ByOrder(a, b)
    local x, y = a.order or 0, b.order or 0
    if x ~= y then return x < y end
    return a.key < b.key
end
local function KeyOrder(a, b)
    return ByOrder(widgets[a], widgets[b])
end
local sortedList
local function List()
    local s = Saved()
    if type(s.list) ~= "table" then
        s.list = {}
        for i = 1, #DEFAULT_LIST do s.list[i] = DEFAULT_LIST[i] end
    end
    if next(widgets) then
        local l = s.list
        for i = #l, 1, -1 do
            if not widgets[l[i]] then tremove(l, i) end
        end
        if sortedList ~= l then
            sortedList = l
            sort(l, KeyOrder)
        end
    end
    return s.list
end
function Panel.Rows()
    local out, l = {}, List()
    for i = 1, #l do out[i] = l[i] end
    return out
end
local function InList(key)
    local l = List()
    for i = 1, #l do
        if l[i] == key then return true end
    end
    return false
end
function Panel.Widget(def)
    assert(type(def) == "table" and type(def.key) == "string" and def.Build and def.Update,
        "Panel.Widget: key, Build and Update are required")
    if widgets[def.key] then return end
    widgets[def.key] = def
    ordered[#ordered + 1] = def
    sort(ordered, ByOrder)
    dirty = true
end
function Panel.Get(key)
    return widgets[key]
end
local function FitLine(row)
    local lw = row.label:GetStringWidth() or 0
    if lw > row.lw then row.lw = lw end
    row.need = row.lx + row.lw + LINE_GAP * 2 + row.vw + row.extra
end
function Panel.Line(row, lead, label)
    if type(lead) == "string" then
        local t = row:CreateTexture(nil, "ARTWORK")
        t:SetWidth(LINE_ICON)
        t:SetHeight(LINE_ICON)
        t:SetTexture(lead)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        lead = t
    end
    local x = 0
    if lead then
        lead:ClearAllPoints()
        lead:SetPoint("LEFT", row, "LEFT", 0, 0)
        x = (lead:GetWidth() or 0) + LINE_GAP
    end
    local l = Kit.Str(row, SMALL)
    l:SetJustifyH("LEFT")
    l:SetPoint("LEFT", row, "LEFT", x, 0)
    ns.Kit.Text(l, "text.secondary")
    l:SetText(label or "")
    local v = Kit.Str(row, SMALL)
    v:SetJustifyH("RIGHT")
    v:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    ns.Kit.Text(v, LINE_TONES.normal)
    row.icon, row.label, row.value = lead, l, v
    row.lx, row.lw, row.vw, row.extra, row.tone, row.shown = x, 0, 0, 0, "normal", nil
    FitLine(row)
    row:SetWidth(row.need)
end
local function IsEmptyWord(text)
    for _, e in pairs(EMPTY) do
        if e.tone == "muted" and ns.T(e.key) == text then return true end
    end
    return false
end
function Panel.Value(row, text, tone)
    tone = LINE_TONES[tone or ""] and tone or "normal"
    if tone ~= row.tone then
        row.tone = tone
        ns.Kit.Text(row.value, LINE_TONES[tone])
    end
    if text == row.shown then return false end
    if tone == "muted" and not IsEmptyWord(text) then
        error("Panel.Value: muted only for Panel.Empty words, got " .. tostring(text), 2)
    end
    row.shown = text
    row.value:SetText(text)
    local w = row.value:GetStringWidth() or 0
    if w > row.vw then
        row.vw = w
        FitLine(row)
    end
    return true
end
function Panel.Empty(row, word)
    local e = EMPTY[word]
    assert(e, "Panel.Empty: unknown word")
    return Panel.Value(row, ns.T(e.key), e.tone)
end
function Panel.EmptyText(word)
    return ns.T(EMPTY[word].key)
end
function Panel.Refit(row)
    if not row.value then return end
    row.lw, row.vw = 0, 0
    local was = row.value:GetText()
    if row.probe then
        row.value:SetText(row.probe)
        row.vw = row.value:GetStringWidth() or 0
    end
    if row.shown then
        row.value:SetText(row.shown)
        row.vw = max(row.vw, row.value:GetStringWidth() or 0)
    end
    row.value:SetText(was or "")
    FitLine(row)
    row:SetWidth(row.need)
end
function Panel.Label(row, text, class)
    if class ~= row.lclass then
        row.lclass = class
        if class then
            ns.Kit.ClassText(row.label, class)
        else
            ns.Kit.Text(row.label, "text.secondary")
        end
    end
    if row.label:GetText() == text then return end
    row.label:SetText(text)
    FitLine(row)
end
function Panel.Reserve(row, probe, extra)
    if probe then
        row.probe = probe
        local was = row.value:GetText()
        row.value:SetText(probe)
        row.vw = math.max(row.vw, row.value:GetStringWidth() or 0)
        row.value:SetText(was or "")
    end
    if extra then
        row.extra = extra
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", row, "RIGHT", -extra, 0)
    end
    FitLine(row)
end
local function Ctx()
    local raid = (GetNumRaidMembers() or 0) > 0
    ctx.raid = raid
    ctx.group = raid or (GetNumPartyMembers() or 0) > 0
end
function Panel.Ctx()
    Ctx()
    return ctx
end
local function Visible(def)
    if not def.Shown then return true end
    return def.Shown(ctx) and true or false
end
local function Spare()
    local any
    for i = 1, #ordered do
        local d = ordered[i]
        if not InList(d.key) then
            if Visible(d) then return d end
            any = any or d
        end
    end
    return any
end
local function Neighbour(key, dir)
    local n, at = #ordered, nil
    for i = 1, n do
        if ordered[i].key == key then at = i end
    end
    if not at then return nil end
    for k = 1, n - 1 do
        local d = ordered[(at - 1 + dir * k) % n + 1]
        if not InList(d.key) and Visible(d) then return d end
    end
    return nil
end
local function ApplyLive()
    local on = frame ~= nil and frame:IsShown() and not Panel.Compact()
    for i = 1, #ordered do
        local d = ordered[i]
        local want = on and InList(d.key)
        if (live[d.key] or false) ~= want then
            live[d.key] = want
            if d.Live then d.Live(want) end
        end
    end
end
local function Changed()
    if frame then Relayout() else ApplyLive() end
end
function Panel.Add(key)
    local d = key and widgets[key] or Spare()
    if not d or InList(d.key) then return end
    local l = List()
    local at = #l + 1
    for i = 1, #l do
        local o = widgets[l[i]]
        if o and ByOrder(d, o) then
            at = i
            break
        end
    end
    tinsert(l, at, d.key)
    Changed()
end
function Panel.Remove(at)
    local l = List()
    if not l[at] then return end
    tremove(l, at)
    Changed()
end
function Panel.Step(at, dir)
    local l = List()
    local d = l[at] and Neighbour(l[at], dir)
    if not d then return end
    l[at] = d.key
    Changed()
end
local function SavePlace(snap)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local W, H = UIParent:GetRight(), UIParent:GetTop()
    if not (l and r and t and b and W and H) then return end
    local k = frame:GetScale() or 1
    W, H = W / k, H / k
    local h, x = "LEFT", l
    if l + r > W then h, x = "RIGHT", r - W end
    local v, y = "BOTTOM", b
    if t + b > H then v, y = "TOP", t - H end
    if snap then
        if abs(x) < SNAP then x = 0 end
        if abs(y) < SNAP then y = 0 end
    end
    local point = v .. h
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
    local s = Saved()
    s.point, s.x, s.y = point, x, y
end
local function DragStart(self)
    if Panel.IsLocked() then return end
    frame:StartMoving()
    frame.moving = true
end
local function DragStop(self)
    if not frame.moving then return end
    frame.moving = false
    frame:StopMovingOrSizing()
    SavePlace(true)
    if self then self.dragAt = GetTime() end
end
local function Draggable(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)
end
function Panel.RecStateKey()
    local R = ns.Recorder
    if not R or not R.IsOn() then return "panel.rec.off" end
    if R.IsPaused and R.IsPaused() then return "panel.rec.paused" end
    return "panel.rec.on"
end
local function TintIcon(b, hot)
    b.hot = hot
    ns.Kit.Tint(b.plate, hot and "button.bgHover" or "button.bg")
    ns.Kit.Tint(b.ring, hot and "button.borderHover" or "button.border")
    ns.Kit.Tint(b.icon, hot and "button.textHover" or "text.primary")
end
local function FaultsShown()
    return ns.Shell.IsFolded() and ns.ShellMini.View() == "faults"
end
function Panel.ToggleMini()
    if not ns.ShellMini then return end
    if ns.Shell.IsFolded() then ns.Shell.Hide() else ns.Shell.FoldTo(ns.ShellMini.View()) end
end
function Panel.Open(key)
    if key == "mini" then
        Panel.ToggleMini()
        return
    end
    if key == "gp" and ns.ShellMini then
        if FaultsShown() then ns.Shell.Hide() else ns.Shell.FoldTo("faults") end
        return
    end
    ns.Shell.Toggle(key)
end
function Panel.ShowActs(anchor, host, side)
    return ns.PanelActs ~= nil and ns.PanelActs.Show(anchor, host, ns.T("panel.timer"), side) or false
end
local function HideMenu()
    if ns.PanelMenu then ns.PanelMenu.Hide() end
end
local tipOn
local function TipLine(text, token)
    return { kind = "text", left = text, rgb = ns.Kit.GameColor(token) }
end
local function IconTip(b)
    tipOn = b
    local lines = { { kind = "title", left = ns.T(b.def.label), rgb = ns.Kit.GameColor("tip.title") } }
    if b.def.tip then lines[#lines + 1] = TipLine(ns.T(b.def.tip), "tip.body") end
    if b.def.key == "log" then
        lines[#lines + 1] = TipLine(ns.T(Panel.RecStateKey()), "text.secondary")
        local _, frac, text = ns.Jobs.State()
        if frac and text then
            lines[#lines + 1] = TipLine(string.format(ns.T("job.tip"), text, floor(frac * 100)), "progress.fill")
        end
    end
    if alerts[b.def.key] then
        lines[#lines + 1] = TipLine(ns.T("panel.tip." .. b.def.key .. ".alert"), "badge.alert")
    end
    local open = ns.Shell.IsOpen(b.def.key)
    local hide, show = "panel.tip.hide", "panel.tip.open"
    if b.def.key == "gp" and ns.ShellMini then
        open = FaultsShown()
        hide, show = "panel.tip.gp.hide", "panel.tip.gp.open"
    end
    lines[#lines + 1] = TipLine(ns.T(open and hide or show), "text.secondary")
    ns.Tip.Dock(b, lines)
end
local function IconTipHide()
    tipOn = nil
    ns.Tip.Hide()
end
local function IconEnter(b)
    TintIcon(b, true)
    local key = b.def.key
    if key ~= "timer" and ns.PanelActs then ns.PanelActs.Hide() end
    if key == "timer" then
        IconTipHide()
        Panel.ShowActs(b, frame)
        return
    end
    if key == "log" and compactNow and ns.PanelMenu then
        IconTipHide()
        alerts.gp = nil
        ns.PanelMenu.Show(b)
        return
    end
    IconTip(b)
    if key == "gp" then alerts.gp = nil end
end
local function IconLeave(b)
    TintIcon(b, false)
    IconTipHide()
end
local function IconClick(b, button)
    if b.dragAt == GetTime() then return end
    IconTipHide()
    if button == "RightButton" then
        if compactNow and ns.PanelMenu then ns.PanelMenu.Show(b) end
        return
    end
    HideMenu()
    if b.def.key == "timer" then
        Panel.ShowActs(b, frame)
        return
    end
    Panel.Open(b.def.key)
end
local function RoundIcon(b, file)
    b.plate = b:CreateTexture(nil, "BACKGROUND")
    b.plate:SetAllPoints()
    b.plate:SetTexture(ART .. "plate.tga")
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetAllPoints()
    b.ring:SetTexture(ART .. "ring.tga")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(ART .. file .. ".tga")
    TintIcon(b, false)
end
local function MakeIcon(def)
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(ICON)
    b:SetHeight(ICON)
    b.def = def
    RoundIcon(b, def.key)
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAllPoints()
    b.glow:SetTexture(GLOW)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    b.busyDot = b:CreateTexture(nil, "OVERLAY")
    b.busyDot:SetWidth(DOT)
    b.busyDot:SetHeight(DOT)
    b.busyDot:SetPoint("TOPRIGHT", 1, 1)
    b.busyDot:SetTexture(ART .. "dot.tga")
    ns.Kit.Tint(b.busyDot, "sem.rec")
    b.busyDot:Hide()
    if def.key == "log" then
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    else
        b:RegisterForClicks("LeftButtonUp")
    end
    Draggable(b)
    b:SetScript("OnEnter", IconEnter)
    b:SetScript("OnLeave", IconLeave)
    b:SetScript("OnClick", IconClick)
    return b
end
local function Bars(b, list)
    b.bars = {}
    for i = 1, #list do
        local g = list[i]
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE8)
        t:SetWidth(g.w)
        t:SetHeight(g.h)
        t:SetPoint("CENTER", b, "CENTER", g.x, g.y)
        b.bars[i] = t
    end
end
local function CutPlate(b, inset, layer)
    local cut = CTRL_CUT + inset
    local mid = b:CreateTexture(nil, layer)
    mid:SetPoint("TOPLEFT", b, "TOPLEFT", cut, -inset)
    mid:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -cut, inset)
    local l = b:CreateTexture(nil, layer)
    l:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -cut)
    l:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", cut, cut)
    local r = b:CreateTexture(nil, layer)
    r:SetPoint("TOPRIGHT", b, "TOPRIGHT", -inset, -cut)
    r:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", -cut, cut)
    return { mid, l, r }
end
local function PaintGlyph(b)
    local hot = b.hovered
    if b.plate then
        TintIcon(b, hot)
        return
    end
    local tok = hot and "text.title" or "text.muted"
    if b.pic then ns.Kit.Tint(b.pic, tok) end
    for i = 1, #b.bars do ns.Kit.Paint(b.bars[i], tok) end
    if b.bg then ns.Kit.Paint(b.bg, hot and "float.toolHover" or "float.tool") end
    if b.rim then
        for i = 1, #b.rim do
            ns.Kit.Paint(b.rim[i], hot and "button.borderHover" or "button.border")
            ns.Kit.Paint(b.plates[i], hot and "button.bgHover" or "button.bg")
        end
    end
end
local function CtrlTip(b)
    local k = b.kind
    b.tipTitle, b.tip = nil, nil
    if k == "add" then
        local d = Spare()
        b.tipTitle = ns.T("panel.row.add")
        b.tip = d and ns.T(d.label) or nil
    elseif k == "del" then
        b.tipTitle = ns.T("panel.row.del")
    elseif k == "lock" then
        local locked = Panel.IsLocked()
        b.tipTitle = ns.T(locked and "panel.unlock" or "panel.lock")
        b.tip = ns.T(locked and "panel.unlock.tip" or "panel.lock.tip")
    elseif k == "compact" then
        b.tipTitle = ns.T("panel.compact")
        b.tip = ns.T("panel.compact.tip")
    elseif k == "less" or k == "more" then
        b.tipTitle = format(ns.T("panel.scale.tip"), floor((Panel.Scale()) * 100 + 0.5))
        b.tip = ns.T(k == "less" and "shell.scale.less.tip" or "shell.scale.more.tip")
    else
        local key = b.row and b.row.key
        local d = key and Neighbour(key, k == "next" and 1 or -1)
        if d then
            b.tipTitle = format(k == "next" and "%s >" or "< %s", ns.T(d.label))
        else
            b.tipTitle = ns.T(k == "next" and "panel.row.next" or "panel.row.prev")
        end
    end
end
local function CtrlEnter(b)
    b.hovered = true
    ctrlHot = b
    PaintGlyph(b)
    CtrlTip(b)
    ns.Kit.TipShow(b)
end
local function CtrlLeave(b)
    b.hovered = false
    ctrlHot = nil
    PaintGlyph(b)
    ns.Kit.TipHide()
end
local function CtrlClick(b)
    ns.Kit.TipHide()
    local k, r = b.kind, b.row
    if k == "add" then
        Panel.Add()
    elseif k == "del" then
        Panel.Remove(r.at)
    elseif k == "lock" then
        Panel.SetLocked(not Panel.IsLocked())
    elseif k == "less" or k == "more" then
        Panel.Zoom(k == "more" and 1 or -1)
    elseif k == "compact" then
        b.hovered, ctrlHot = false, nil
        PaintGlyph(b)
        Panel.SetCompact(true)
        return
    else
        Panel.Step(r.at, k == "next" and 1 or -1)
    end
    if b.hovered and b:IsShown() then CtrlEnter(b) end
end
local function CtrlScripts(b)
    b.tipAnchor = "ANCHOR_TOP"
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", CtrlEnter)
    b:SetScript("OnLeave", CtrlLeave)
    b:SetScript("OnClick", CtrlClick)
end
local function Ctrl(parent, kind, w, h, strip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w)
    b:SetHeight(h)
    b.kind = kind
    if strip then
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
    else
        b.rim = CutPlate(b, 0, "BACKGROUND")
        b.plates = CutPlate(b, 1, "BORDER")
    end
    if ARROWS[kind] then
        b.pic = b:CreateTexture(nil, "ARTWORK")
        b.pic:SetWidth(ARROW_PIC)
        b.pic:SetHeight(ARROW_PIC)
        b.pic:SetPoint("CENTER", 0, 0)
        b.pic:SetTexture(ARROWS[kind])
        b.pic:SetDesaturated(true)
    end
    Bars(b, GLYPHS[kind] or GLYPHS.add)
    CtrlScripts(b)
    PaintGlyph(b)
    return b
end
local function MakeCorner(kind, file)
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(CORNER)
    b:SetHeight(CORNER)
    b.kind = kind
    b.bars = {}
    RoundIcon(b, file)
    CtrlScripts(b)
    return b
end
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetHeight(ROW_H)
    r.prev = Ctrl(r, "prev", CTRL, ROW_H)
    r.next = Ctrl(r, "next", CTRL, ROW_H)
    r.del = Ctrl(r, "del", CTRL, ROW_H)
    r.prev.row, r.next.row, r.del.row = r, r, r
    rows[i] = r
    return r
end
local function Vis(f, on)
    if on then f:Show() else f:Hide() end
end
local function Slot(b, on, slot)
    Vis(b, on)
    if not on then return end
    b:ClearAllPoints()
    local off = OUT + slot * (CTRL + CTRL_GAP)
    if ctrlSide == "LEFT" then
        b:SetPoint("RIGHT", b.row, "LEFT", -off, 0)
    else
        b:SetPoint("LEFT", b.row, "RIGHT", off, 0)
    end
end
local function ShowCtrls(r, on)
    local key = r.key
    local can = on and key ~= nil and Neighbour(key, 1) ~= nil
    local left = ctrlSide == "LEFT"
    Slot(r.prev, can, left and 2 or 0)
    Slot(r.next, can, 1)
    Slot(r.del, on and key ~= nil, (left or not can) and 0 or 2)
end
local function SideOf()
    local r, edge = frame:GetRight(), UIParent:GetRight()
    if not (r and edge) then return "RIGHT" end
    local k = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    return (r + REACH) * k > edge and "LEFT" or "RIGHT"
end
function Panel.CtrlSide()
    return ctrlSide
end
local function OverSide(f, top, span)
    if ctrlSide == "LEFT" then return f:IsMouseOver(top, 0, -span, 0) and true or false end
    return f:IsMouseOver(top, 0, 0, span) and true or false
end
local shownCtrls = {}
local CTRL_KEYS = { "prev", "next", "del" }
local function CtrlsShown()
    for i = #shownCtrls, 1, -1 do shownCtrls[i] = nil end
    local r = hoverRow
    if r then
        for i = 1, #CTRL_KEYS do
            local b = r[CTRL_KEYS[i]]
            if b:IsShown() then shownCtrls[#shownCtrls + 1] = b end
        end
    end
    if ctrlHot and ctrlHot:IsShown() and frame then shownCtrls[#shownCtrls + 1] = frame end
    return shownCtrls
end
Kit.Tip.SetAvoid(CtrlsShown)
function Panel.Tip(owner, lines)
    local span = REACH - PAD
    if ctrlSide == "LEFT" then
        local l, o = frame:GetLeft(), owner:GetLeft()
        ns.Tip.Show(owner, lines, nil, nil, (l and o) and (o - l + span) or span)
        return
    end
    local r, o = frame:GetRight(), owner:GetRight()
    ns.Tip.Show(owner, lines, nil, (r and o) and (r - o + span) or span)
end
local function ViewEnter(v)
    local d = v.def
    if not d.Tip then return end
    local lines = d.Tip(v, ns.Tip)
    if type(lines) == "table" then Panel.Tip(v, lines) end
end
local function ViewLeave(v)
    ns.Tip.Hide()
end
local function ViewClick(v, button)
    if v.dragAt == GetTime() or not v.def.Click then return end
    v.def.Click(v, button)
end
local function View(d)
    local v = views[d.key]
    if v then return v end
    v = CreateFrame("Frame", nil, frame)
    v:SetHeight(ROW_H)
    v:SetWidth(1)
    v.def = d
    if d.Tip or d.Click then
        v:EnableMouse(true)
        Draggable(v)
        v:SetScript("OnEnter", ViewEnter)
        v:SetScript("OnLeave", ViewLeave)
        v:SetScript("OnMouseUp", ViewClick)
    end
    d.Build(v)
    v.w = v.need or v:GetWidth()
    v:Hide()
    views[d.key] = v
    return v
end
local function Feed(d, v)
    d.Update(v, GetTime())
    local w = v.need or v:GetWidth() or 0
    if abs(w - (v.w or 0)) > 0.5 then
        v.w = w
        dirty = true
    end
end
local function LayTop(compact)
    for i = 1, #buttons do
        local b = buttons[i]
        local on = not compact or b == logBtn
        Vis(b, on)
        if on then
            local size = compact and ORB or ICON
            b:SetWidth(size)
            b:SetHeight(size)
            b:ClearAllPoints()
            if compact then
                b:SetPoint("TOPLEFT", 0, 0)
            elseif b.def.tool then
                b:SetPoint("TOPRIGHT", -PAD, -PAD)
            else
                b:SetPoint("TOPLEFT", PAD + (i - 1) * (ICON + GAP), -PAD)
            end
        end
    end
end
local function Bare(bare)
    if frame.bare == bare then return end
    frame.bare = bare
    if bare then
        ns.Kit.Skin(frame, "bare")
        frame:SetBackdrop(nil)
        frame.kitBd = nil
    else
        ns.Kit.Skin(frame, "float")
    end
end
local function FillRows()
    for _, v in pairs(views) do v.on = false end
    local l = List()
    local n, cw = 0, 0
    for i = 1, #l do
        local d = widgets[l[i]]
        if d and Visible(d) then
            n = n + 1
            local r = Row(n)
            r.at, r.key = i, d.key
            local v = View(d)
            v.on = true
            if not v:IsShown() then
                acc[d.key] = 0
                Feed(d, v)
            end
            cw = max(cw, v.need or v:GetWidth() or 0)
        end
    end
    return n, cw
end
local function HideRows(from)
    for i = from, #rows do
        rows[i].key, rows[i].at = nil, nil
        rows[i]:Hide()
    end
    for _, v in pairs(views) do
        if not v.on then v:Hide() end
    end
end
local function LayRows(n, w, y)
    for i = 1, n do
        local r = rows[i]
        y = y + ROWGAP
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        r:SetWidth(w - PAD * 2)
        r:Show()
        local v = views[r.key]
        v:ClearAllPoints()
        v:SetPoint("LEFT", r, "LEFT", 0, 0)
        if v.need then v:SetWidth(w - PAD * 2) end
        v:Show()
        ShowCtrls(r, r == hoverRow)
        y = y + ROW_H
    end
    HideRows(n + 1)
    if Spare() then
        y = y + ROWGAP
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        strip:SetWidth(w - PAD * 2)
        strip:Show()
        y = y + STRIP_H
    else
        strip:Hide()
    end
    return y
end
local function DressLock()
    lockGlyph.icon:SetTexture(ART .. (Panel.IsLocked() and "lock" or "unlock") .. ".tga")
    PaintGlyph(lockGlyph)
end
local function ShowCorners()
    local on = panelHot and not compactNow
    Vis(lessGlyph, on)
    Vis(moreGlyph, on)
    Vis(lockGlyph, on)
    Vis(compactGlyph, on)
end
function Relayout()
    compactNow = Panel.Compact()
    ApplyLive()
    Ctx()
    LayTop(compactNow)
    Bare(compactNow)
    if compactNow then
        for _, v in pairs(views) do v.on = false end
        HideRows(1)
        strip:Hide()
        panelHot = false
        ShowCorners()
        frame:SetWidth(ORB)
        frame:SetHeight(ORB)
        dirty = false
        return
    end
    local n, cw = FillRows()
    local w = max(ROW_W, PAD * 2 + cw)
    local y = LayRows(n, w, PAD + ICON)
    ShowCorners()
    frame:SetWidth(w)
    frame:SetHeight(y + PAD)
    dirty = false
end
local function VisChanged()
    Ctx()
    local l = List()
    for i = 1, #l do
        local d = widgets[l[i]]
        if d then
            local v = views[d.key]
            if Visible(d) ~= (v ~= nil and v.on == true) then return true end
        end
    end
    return false
end
local function StepHover()
    if compactNow then return end
    if not panelHot then ctrlSide = SideOf() end
    local over = OverSide(frame, CORNER + CORNER_LIFT, REACH - PAD)
    if over ~= panelHot then
        panelHot = over
        ShowCorners()
        for i = 1, #rows do
            local r = rows[i]
            if r:IsShown() then ShowCtrls(r, r == hoverRow) end
        end
    end
    if not over and not hoverRow then return end
    local hit
    if over then
        for i = 1, #rows do
            local r = rows[i]
            if r:IsShown() and OverSide(r, 0, REACH) then
                hit = r
                break
            end
        end
    end
    if hit == hoverRow then return end
    if hoverRow then ShowCtrls(hoverRow, false) end
    hoverRow = hit
    if hit then ShowCtrls(hit, true) end
end
local function Glow(b, on)
    if on then
        b.glow:Show()
        b.glow:SetAlpha(0.4 + 0.6 * abs(sin(GetTime() * 4)))
    elseif b.glow:IsShown() then
        b.glow:Hide()
    end
end
local function StepAlerts()
    local pulse = 0.35 + 0.65 * abs(sin(GetTime() * 3))
    for i = 1, #buttons do
        local b = buttons[i]
        local on = alerts[b.def.key]
        if compactNow and b == logBtn then on = alerts.log or alerts.gp end
        Glow(b, on and b:IsShown() or false)
        local busy = busyParts[b.def.key]
        if compactNow and b == logBtn then busy = next(busyParts) ~= nil end
        if busy and b:IsShown() then
            b.busyDot:Show()
            b.busyDot:SetAlpha(pulse)
        elseif b.busyDot:IsShown() then
            b.busyDot:Hide()
        end
    end
end
local function OnUpdate(self, elapsed)
    StepAlerts()
    StepHover()
    visAcc = visAcc + elapsed
    if visAcc >= VIS_PERIOD then
        visAcc = 0
        if not compactNow and VisChanged() then dirty = true end
        local key = (ctx.group and "g" or "") .. (ctx.raid and "r" or "")
        if key ~= ctxKey then
            ctxKey = key
            for i = 1, #rows do
                local r = rows[i]
                if r.key and r:IsShown() then Feed(widgets[r.key], views[r.key]) end
            end
        end
    end
    for i = 1, #rows do
        local r = rows[i]
        local key = r.key
        if key and r:IsShown() then
            local d = widgets[key]
            local a = (acc[key] or 0) + elapsed
            if a >= (d.rate or 1) then
                a = 0
                Feed(d, views[key])
            end
            acc[key] = a
        end
    end
    if dirty then Relayout() end
end
local function ShowProgress()
    if not job then return end
    local _, frac, _, _, age = ns.Jobs.State()
    if frac and age >= LONG_JOB then
        jobFill:SetWidth(max(1, ((logBtn:GetWidth() or ICON) - JOB_IN * 2) * frac))
        job:Show()
    elseif job:IsShown() then
        job:Hide()
    end
    if not compactNow and tipOn == logBtn then IconTip(logBtn) end
end
local function BuildMarks()
    job = CreateFrame("Frame", nil, logBtn)
    job:SetPoint("BOTTOMLEFT", JOB_IN, JOB_IN)
    job:SetPoint("BOTTOMRIGHT", -JOB_IN, JOB_IN)
    job:SetHeight(JOB_H)
    local bg = job:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "progress.ring")
    jobFill = job:CreateTexture(nil, "ARTWORK")
    jobFill:SetPoint("TOPLEFT", 0, 0)
    jobFill:SetPoint("BOTTOMLEFT", 0, 0)
    jobFill:SetWidth(1)
    ns.Kit.Paint(jobFill, "progress.fill")
    job:Hide()
end
local function BuildCorners()
    compactGlyph = MakeCorner("compact", "compact")
    compactGlyph:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, CORNER_LIFT)
    lockGlyph = MakeCorner("lock", "unlock")
    lockGlyph:SetPoint("RIGHT", compactGlyph, "LEFT", -CORNER_GAP, 0)
    moreGlyph = MakeCorner("more", "more")
    moreGlyph:SetPoint("RIGHT", lockGlyph, "LEFT", -CORNER_GAP, 0)
    lessGlyph = MakeCorner("less", "less")
    lessGlyph:SetPoint("RIGHT", moreGlyph, "LEFT", -CORNER_GAP, 0)
    local level = (frame:GetFrameLevel() or 0) + 5
    for _, b in ipairs({ lessGlyph, moreGlyph, lockGlyph, compactGlyph }) do
        b:SetFrameLevel(level)
        b:Hide()
    end
    DressLock()
end
local function BuildTop()
    for i = 1, #ICONS do buttons[i] = MakeIcon(ICONS[i]) end
    logBtn = buttons[1]
    BuildMarks()
    strip = Ctrl(frame, "add", 1, STRIP_H, true)
    strip:Hide()
    BuildCorners()
end
local function Build()
    local s = Saved()
    s.open, s.rows = nil, nil
    frame = CreateFrame("Frame", "HTP_FailWatchPanel", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame.sized = true
    Sizes()
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() DragStart() end)
    frame:SetScript("OnDragStop", function() DragStop() end)
    ns.Kit.Skin(frame, "float")
    frame.bare = false
    frame:SetScale((Panel.Scale()))
    frame:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or -200)
    BuildTop()
    frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", OnUpdate))
    frame:SetScript("OnHide", function()
        HideMenu()
        if ns.PanelActs then ns.PanelActs.Hide() end
        DragStop()
        ApplyLive()
    end)
    frame:SetScript("OnShow", ApplyLive)
    Relayout()
    SavePlace()
end
local function Apply()
    if Wanted() then
        if not frame then Build() end
        frame:Show()
    elseif frame then
        frame:Hide()
    end
    ApplyLive()
    if ns.Settings then ns.Settings.Refresh() end
end
function Panel.SetWhen(key)
    local s = Saved()
    if key == "never" then
        s.hidden = true
    elseif WHEN[key or ""] then
        s.hidden = nil
        s.when = key ~= "always" and key or nil
    end
    Apply()
end
function Panel.Toggle()
    if frame and frame:IsShown() then
        Panel.SetWhen("never")
        return
    end
    Saved().hidden = nil
    if not Wanted() then Saved().when = nil end
    Apply()
end
function Panel.SetScale(v)
    v = min(SCALE_MAX, max(SCALE_MIN, floor((tonumber(v) or 1) * 100 + 0.5) / 100))
    Saved().scale = v ~= 1 and v or nil
    if not frame then return end
    local old = frame:GetScale() or 1
    SavePlace()
    frame:SetScale(v)
    local s = Saved()
    if s.point and v > 0 then
        local k = old / v
        s.x, s.y = (s.x or 0) * k, (s.y or 0) * k
        frame:ClearAllPoints()
        frame:SetPoint(s.point, UIParent, s.point, s.x, s.y)
    end
end
function Panel.Zoom(dir)
    Panel.SetScale((Panel.Scale()) + dir * ZOOM_STEP)
    if ns.Settings then ns.Settings.Refresh() end
end
local function Shift(d)
    local l, t = frame:GetLeft(), frame:GetTop()
    if not (l and t) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l + d, t - d)
end
function Panel.SetCompact(on)
    on = on and true or false
    local was = Panel.Compact()
    Saved().compact = on or nil
    HideMenu()
    if frame then
        if was ~= on then Shift(on and PAD or -PAD) end
        Relayout()
        if was ~= on then SavePlace() end
    end
    if ns.Settings then ns.Settings.Refresh() end
end
function Panel.SetAlert(key, on)
    alerts[key] = on and true or nil
end
function Panel.HasAlert(key)
    return alerts[key] == true
end
function Panel.SetBusy(key, on)
    busyParts[key] = on and true or nil
end
function Panel.IsBusy(key)
    return busyParts[key] == true
end
function Panel.SetLocked(on)
    Saved().locked = on and true or false
    if frame then DressLock() end
    if ns.PanelMenu then ns.PanelMenu.Refresh() end
    if ns.Settings then ns.Settings.Refresh() end
end
Kit.OnFont(function()
    Sizes()
    for i = 1, #rows do
        local r = rows[i]
        r:SetHeight(ROW_H)
        r.prev:SetHeight(ROW_H)
        r.next:SetHeight(ROW_H)
        r.del:SetHeight(ROW_H)
    end
    for _, v in pairs(views) do
        v:SetHeight(ROW_H)
        if v.value then Panel.Refit(v) end
        v.w = v.need or v:GetWidth()
    end
    dirty = true
end)
ns.OnReady(function()
    Apply()
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("RAID_ROSTER_UPDATE")
    watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
    watch:RegisterEvent("PLAYER_ENTERING_WORLD")
    watch:SetScript("OnEvent", function()
        local shown = frame and frame:IsShown() and true or false
        if shown ~= Wanted() then Apply() end
        if frame and shown then dirty = true end
    end)
end)
ns.Jobs.OnChange(ShowProgress)
