local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local abs = math.abs
local GUTTER = 150
local HEADH = 22
local RULERH = 20
local ROWH = 18
local BARH = 12
local LIFEH = 2
local PULLW = 3
local NAMEPAD = 6
local MARKW = 52
local MARKGAP = 8
local TICKH = 4
local LEVEL = 90
local NEAR = 1.5
local OTHERS = 8
local CLICK_SLACK = 3
local MIN_SPAN = 5
local BTNW = 84
local BTNH = 18
local BTNGAP = 6
local AT_SPAN = 60
local STEPS = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600 }
local T = ns.T
local TV = {}
ns.ThreatView = TV
local host, hint, ruler, plot, overlay, note, cursor, anchor, btn
local fight = nil
local model = nil
local busy = false
local from, to, lead, tail = 0, 1, 0, 1
local scroll = 0
local drag = nil
local hoverKey = nil
local pool = { bar = {}, text = {}, rtext = {} }
local used = { bar = 0, text = 0, rtext = 0 }
local function Clock(sec)
    local sign = sec < 0 and "-" or ""
    local a = abs(sec)
    local m = floor(a / 60)
    return format("%s%d:%02d", sign, m, floor(a - m * 60))
end
local function Width()
    return host:GetWidth()
end
local function RowsHeight()
    return max(0, host:GetHeight() - HEADH - RULERH)
end
local function XOf(t)
    return GUTTER + (t - from) / max(1e-6, to - from) * max(1, Width() - GUTTER)
end
local function Bar()
    used.bar = used.bar + 1
    local t = pool.bar[used.bar]
    if not t then
        t = plot:CreateTexture(nil, "ARTWORK")
        pool.bar[used.bar] = t
    end
    t:Show()
    return t
end
local function Text(list, key, parent)
    used[key] = used[key] + 1
    local fs = list[used[key]]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        list[used[key]] = fs
    end
    fs:Show()
    return fs
end
local function Release()
    for i = 1, used.bar do pool.bar[i]:Hide() end
    for i = 1, used.text do pool.text[i]:Hide() end
    for i = 1, used.rtext do pool.rtext[i]:Hide() end
    used.bar, used.text, used.rtext = 0, 0, 0
end
local function Place(tex, x, y, w, h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", tex:GetParent(), "TOPLEFT", x, -y)
    if w then tex:SetWidth(max(1, w)) end
    if h then tex:SetHeight(max(1, h)) end
end
local function ClassOf(who)
    return ns.Encounters and ns.Encounters.ClassOf and ns.Encounters.ClassOf(who) or nil
end
local function Visible()
    return max(1, floor(RowsHeight() / ROWH))
end
local function Clamp()
    local n = model and #model.mobs or 0
    scroll = max(0, min(scroll, n - Visible()))
end
local function DrawRuler()
    local span = to - from
    local slots = max(4, floor((Width() - GUTTER) / (MARKW + MARKGAP)))
    local step = STEPS[#STEPS]
    for i = 1, #STEPS do
        if span / STEPS[i] <= slots then
            step = STEPS[i]
            break
        end
    end
    local base = fight.from
    local k = ceil((from - base) / step)
    while base + k * step <= to do
        local t = base + k * step
        local x = XOf(t)
        local fs = Text(pool.rtext, "rtext", ruler)
        ns.Kit.Tone(fs, "text.secondary")
        fs:SetText(Clock(t - base))
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", ruler, "BOTTOMLEFT", x + 2, 3)
        local tick = Bar()
        ns.Kit.Shade(tick, "surface.grid")
        Place(tick, x, 0, 1, RowsHeight())
        k = k + 1
    end
end
local function DrawRow(m, y)
    local x0, x1 = XOf(from), XOf(to)
    local mid = y + ROWH / 2
    local name = Text(pool.text, "text", plot)
    ns.Kit.Tone(name, m.boss and "text.title" or "text.primary")
    name:SetWidth(GUTTER - NAMEPAD * 2)
    name:SetHeight(ROWH)
    name:SetText(m.name)
    Place(name, NAMEPAD, y)
    local rows = m.rows
    local stop = to
    if rows[#rows] and rows[#rows].gone then stop = rows[#rows].t end
    if m.first < to and stop > from then
        local life = Bar()
        ns.Kit.Shade(life, "sem.threat.life")
        local xa, xb = XOf(max(m.first, from)), XOf(min(stop, to))
        Place(life, xa, mid - LIFEH / 2, xb - xa, LIFEH)
    end
    local _, _, _, alpha = ns.Kit.Color("sem.threat.span")
    local spans = m.spans
    for i = 1, #spans do
        local sp = spans[i]
        if sp.to > from and sp.from < to then
            local xa, xb = max(x0, XOf(sp.from)), min(x1, XOf(sp.to))
            local bar = Bar()
            local cls = fight.players[sp.who] ~= nil and ClassOf(sp.who) or nil
            if cls then
                local r, g, b = ns.Kit.ClassColor(cls)
                bar:SetTexture(r, g, b, alpha)
            else
                ns.Kit.Shade(bar, "sem.threat.other")
            end
            Place(bar, xa, mid - BARH / 2, xb - xa, BARH)
        end
    end
    for i = 1, #m.pulls do
        local p = m.pulls[i]
        if p.t >= from and p.t <= to then
            local mark = Bar()
            ns.Kit.Shade(mark, "sem.threat.pull")
            Place(mark, XOf(p.t) - floor(PULLW / 2), y + 1, PULLW, ROWH - 2)
        end
    end
end
local function DrawMarks()
    local h = RowsHeight()
    local marks = { { t = fight.from }, { t = fight.to } }
    for i = 1, #model.marks do marks[#marks + 1] = model.marks[i] end
    for i = 1, #marks do
        local mk = marks[i]
        if mk.t >= from and mk.t <= to then
            local line = Bar()
            ns.Kit.Shade(line, mk.dim and "sem.phaseDim" or "sem.phase")
            Place(line, XOf(mk.t), 0, 1, h)
            if mk.label then
                local fs = Text(pool.text, "text", plot)
                fs:SetWidth(0)
                ns.Kit.Tone(fs, mk.dim and "sem.phaseDimText" or "sem.phaseText")
                fs:SetText(mk.label)
                Place(fs, XOf(mk.t) + 3, 1)
            end
        end
    end
end
local function Say(text)
    note:SetText(text)
    note:Show()
end
local function Draw()
    if not host then return end
    Release()
    note:Hide()
    if not host:IsShown() then return end
    if not fight then
        Say(T("thr.view.pick"))
        return
    end
    if busy then
        Say(T("thr.view.loading"))
        return
    end
    if not (model and model.any) then
        Say(T(ns.Store.Bare(fight) and "rec.bare" or "thr.view.old"))
        return
    end
    Clamp()
    local edge = Bar()
    ns.Kit.Shade(edge, "surface.edge")
    Place(edge, GUTTER - 1, 0, 1, RowsHeight())
    DrawRuler()
    local n = Visible()
    for r = 1, n do
        local m = model.mobs[scroll + r]
        if not m then break end
        local y = (r - 1) * ROWH
        if r % 2 == 0 then
            local zebra = Bar()
            ns.Kit.Shade(zebra, "surface.zebra")
            Place(zebra, 0, y, Width(), ROWH)
        end
        DrawRow(m, y)
    end
    DrawMarks()
end
local function MobAt(row)
    return model and model.mobs[scroll + row] or nil
end
function TV.Lines(m, t)
    local lines = { { kind = "head", left = m.name, right = Clock(t - fight.from) } }
    local r = ns.Threat.RowAt(m, t)
    local sp = ns.Threat.SpanAt(m, t)
    if not r then
        lines[#lines + 1] = { kind = "note", left = T("thr.tip.gone") }
    else
        if sp then
            lines[#lines + 1] = { kind = "row", left = sp.who, right = T("thr.tip.holds"), class = ClassOf(sp.who) }
        else
            lines[#lines + 1] = { kind = "note", left = T("thr.tip.nobody") }
        end
        local top = r.top or {}
        for i = 1, #top do
            local e = top[i]
            lines[#lines + 1] = { kind = "sub", left = e.name, right = format(T("thr.pct"), e.raw),
                                  class = ClassOf(e.name), tone = e.raw > 100 and "bad" or nil }
        end
    end
    for i = 1, #m.pulls do
        local p = m.pulls[i]
        if abs(p.t - t) <= NEAR then
            lines[#lines + 1] = { kind = "row", left = T("thr.tip.pulled"), right = p.who, tone = "bad" }
            lines[#lines + 1] = { kind = "sub", left = format(T("thr.tip.from"), p.prev) }
        end
    end
    local others = 0
    for i = 1, #model.mobs do
        local o = model.mobs[i]
        if o ~= m and others < OTHERS and ns.Threat.RowAt(o, t) then
            if others == 0 then
                lines[#lines + 1] = { kind = "sep" }
                lines[#lines + 1] = { kind = "note", left = T("thr.tip.others") }
            end
            others = others + 1
            local osp = ns.Threat.SpanAt(o, t)
            lines[#lines + 1] = { kind = "sub", left = o.name, right = osp and osp.who or "-" }
        end
    end
    if sp and fight.players[sp.who] ~= nil then
        lines[#lines + 1] = { kind = "foot", left = format(T("thr.tip.click"), sp.who) }
    end
    return lines
end
function TV.HoverAt(t, row)
    local m = fight and MobAt(row)
    if not m then
        ns.Tip.Hide()
        return nil
    end
    local lines = TV.Lines(m, t)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", overlay, "TOPLEFT", XOf(t), -(row - 1) * ROWH)
    ns.Tip.Show(anchor, lines)
    return lines
end
local function Open(who, t)
    local span = to - from
    local a = max(lead, min(tail - span, t - span / 2))
    TV.Hide()
    ns.Timeline.SelectPlayer(who)
    ns.Timeline.SetView(a, a + span)
end
function TV.ClickAt(t, row)
    local m = fight and MobAt(row)
    local sp = m and ns.Threat.SpanAt(m, t)
    if not sp or fight.players[sp.who] == nil then return nil end
    Open(sp.who, t)
    return sp.who
end
local function At(x, y)
    if x < GUTTER or x > Width() or y < 0 then return nil, 0 end
    local t = from + (x - GUTTER) / max(1, Width() - GUTTER) * (to - from)
    return t, floor(y / ROWH) + 1
end
local function Cursor(self)
    local cx, cy = GetCursorPosition()
    local s = self:GetEffectiveScale()
    return cx / s - (self:GetLeft() or 0), (self:GetTop() or 0) - cy / s
end
function TV.Wheel(delta, x)
    if not model then return end
    if IsShiftKeyDown() or x < GUTTER then
        scroll = scroll - delta
        Clamp()
        Draw()
        return
    end
    local cx = max(0, min(1, (x - GUTTER) / max(1, Width() - GUTTER)))
    local span = to - from
    local anchorT = from + span * cx
    local newSpan = max(MIN_SPAN, min(tail - lead, span * (delta > 0 and 0.75 or 1.3333)))
    from = anchorT - newSpan * cx
    to = from + newSpan
    if from < lead then from, to = lead, lead + newSpan end
    if to > tail then from, to = tail - newSpan, tail end
    Draw()
end
local function OnUpdate(self)
    if not fight or not model then return end
    local x, y = Cursor(self)
    if drag then
        if not IsMouseButtonDown("LeftButton") then
            drag = nil
        else
            if abs(x - drag.x) > CLICK_SLACK then drag.moved = true end
            local span = to - from
            local nf = max(lead, min(tail - span, drag.from + (drag.x - x) / max(1, Width() - GUTTER) * span))
            if nf ~= from then
                from, to = nf, nf + span
                Draw()
            end
        end
    end
    local t, row = At(x, y)
    if not t or not self:IsMouseOver() then
        cursor:Hide()
        if hoverKey then
            hoverKey = nil
            ns.Tip.Hide()
        end
        return
    end
    cursor:ClearAllPoints()
    cursor:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
    cursor:SetHeight(RowsHeight())
    cursor:Show()
    local key = row * 100000 + floor(t * 2)
    if key ~= hoverKey then
        hoverKey = key
        TV.HoverAt(t, row)
    end
end
local function SetButton()
    if btn then btn.text:SetText(T(TV.IsShown() and "tl.btn.thr.back" or "tl.btn.thr")) end
end
function TV.Attach(frame, clip, margin, headH)
    host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -margin, -headH)
    host:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
    host:SetFrameLevel(clip:GetFrameLevel() + LEVEL)
    host:EnableMouse(true)
    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "surface.bg")
    hint = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -6)
    hint:SetJustifyH("LEFT")
    hint:SetText(T("thr.view.hint"))
    ns.Kit.Text(hint, "text.secondary")
    ruler = CreateFrame("Frame", nil, host)
    ruler:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -HEADH)
    ruler:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -HEADH)
    ruler:SetHeight(RULERH)
    plot = CreateFrame("Frame", nil, host)
    plot:SetPoint("TOPLEFT", ruler, "BOTTOMLEFT", 0, 0)
    plot:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    plot:EnableMouse(true)
    plot:EnableMouseWheel(true)
    overlay = CreateFrame("Frame", nil, plot)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(plot:GetFrameLevel() + 5)
    cursor = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(cursor, "sem.cursor")
    cursor:SetWidth(1)
    cursor:Hide()
    anchor = CreateFrame("Frame", nil, overlay)
    anchor:SetWidth(1)
    anchor:SetHeight(ROWH)
    note = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("CENTER", plot, "CENTER", 0, 0)
    ns.Kit.Text(note, "text.secondary")
    note:Hide()
    plot:SetScript("OnMouseWheel", function(self, delta)
        local x = Cursor(self)
        TV.Wheel(delta, x)
    end)
    plot:SetScript("OnMouseDown", function(self)
        local x = Cursor(self)
        drag = { x = x, from = from, moved = false }
    end)
    plot:SetScript("OnMouseUp", function(self)
        local d = drag
        drag = nil
        if not d or d.moved then return end
        local t, row = At(Cursor(self))
        if t then TV.ClickAt(t, row) end
    end)
    plot:SetScript("OnUpdate", ns.Prof.Wrap("ui.tl", OnUpdate))
    plot:SetScript("OnLeave", function()
        cursor:Hide()
        hoverKey = nil
        ns.Tip.Hide()
    end)
    host:SetScript("OnSizeChanged", function() Draw() end)
    host:Hide()
end
function TV.Head(parent, anchor)
    btn = ns.Kit.Button(parent, "HTP_FailWatchThreatToggle")
    btn:SetWidth(BTNW)
    btn:SetHeight(BTNH)
    btn:SetPoint("LEFT", anchor, "RIGHT", BTNGAP, 0)
    btn.tipTitle = T("tl.btn.thr")
    btn.tip = T("tl.btn.thr.tip")
    btn.onClick = function() TV.Toggle() end
    SetButton()
    TV.SetFight(nil)
    return btn
end
function TV.HeadFrame()
    return btn
end
function TV.SetFight(f)
    if not btn then return end
    if f then btn:Show() else btn:Hide() end
end
function TV.Show(f)
    if not host or not f then return end
    fight, model, busy, scroll, hoverKey = f, nil, true, 0, nil
    lead, tail = ns.Encounters.Lead(f), ns.Encounters.Tail(f)
    from, to = lead, tail
    local tf, _, vf, vt = ns.Timeline.View()
    if tf == f and vt and vf and vt > vf then from, to = vf, vt end
    host:Show()
    SetButton()
    Draw()
    ns.Threat.Load(f, function(m)
        if fight ~= f then return end
        model, busy = m, false
        Draw()
    end)
end
function TV.OpenAt(f, t)
    if not f then return end
    if ns.Shell then ns.Shell.Open("log") end
    ns.Timeline.ShowThreat(f)
    if not (host and t and host:IsShown()) then return end
    local span = min(to - from, AT_SPAN)
    from = max(lead, min(tail - span, t - span / 2))
    to = from + span
    Draw()
end
function TV.Hide()
    if not host or not host:IsShown() then return end
    host:Hide()
    drag, hoverKey = nil, nil
    ns.Tip.Hide()
    SetButton()
end
function TV.IsShown()
    return host ~= nil and host:IsShown() and true or false
end
function TV.Toggle()
    if TV.IsShown() then
        ns.Timeline.LeaveThreat()
        return
    end
    local f = ns.Timeline.View()
    if not f then
        ns.Print(T("thr.view.pick"))
        return
    end
    ns.Timeline.ShowThreat(f)
end
function TV.View()
    return from, to, scroll
end
function TV.Frame()
    return host
end
TV.Redraw = Draw
if ns.Settings and ns.Settings.Item then
    ns.Settings.Item("rec", "what", {
        kind = "check", key = "thr", label = "set.rec.thr", tip = "set.rec.thr.tip", default = true,
        get = function() return ns.Threat.Enabled() end,
        set = function(on) ns.GetDB().settings.thrOn = on and true or false end,
    })
end
