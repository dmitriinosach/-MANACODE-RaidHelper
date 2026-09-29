local ADDON, ns = ...
local format = string.format
local floor = math.floor
local abs = math.abs
local sin = math.sin
local max = math.max
local min = math.min
local ICON = 30
local GAP = 4
local PAD = 5
local ROWGAP = 3
local TEXTH = 14
local DOT = 8
local TOOLGAP = 8
local COUNT_PERIOD = 1
local STRIP_H = 3
local STRIP_IN = 2
local LONG_JOB = 1
local EQ_H = 16
local EQ_BTN = 14
local EQ_GAP = 3
local EQ_BARS = 30
local GRAPH_SLOT = 2
local GRAPH_GAP = 6
local NUM_W = 44
local NUM_GAP = 3
local MUTE = 0.55
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.60, 1.50, 0.05
local WHEN = { always = true, group = true, raid = true }
local REFRESH = 0.1
local GLOW = "Interface\\Buttons\\CheckButtonHilight"
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local PAUSE = "Interface\\TimeManager\\PauseButton"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local ICONS = {
    { key = "log", label = "panel.log", tip = "panel.tip.log" },
    { key = "gp", label = "panel.gp", tip = "panel.tip.gp" },
    { key = "raid", label = "panel.raid", tip = "panel.tip.raid" },
    { key = "spam", label = "panel.spam", tip = "panel.tip.spam" },
    { key = "timer", label = "panel.timer" },
    { key = "settings", label = "panel.settings", tip = "panel.settings.tip", tool = true },
    { key = "lock", label = "panel.lock", tool = true },
}
local Panel = {}
ns.Panel = Panel
local frame, lockBtn, dot, countText, strip, stripFill
local pauseBtn, sizeBtn, eq, eqBg, graphs, dpsGraph, hpsGraph, dpsText, hpsText
local buttons = {}
local eqBars, dpsBars, hpsBars = {}, {}, {}
local buckets = {}
local alerts = {}
local countAcc, drawAcc = COUNT_PERIOD, 0
local baseSeen, eqElapsed = 0, 0
local writing = false
local lowR, lowG, lowB, midR, midG, midB, highR, highG, highB = 0, 1, 0, 1, 1, 0, 1, 0, 0
local idleR, idleG, idleB, idleA = 1, 1, 1, 0.1
local baseW = PAD * 2 + #ICONS * ICON + (#ICONS - 2) * GAP + TOOLGAP
for i = 1, EQ_BARS do buckets[i] = 0 end
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
Panel.WHENS = { "always", "group", "raid", "never" }
function Panel.When()
    local s = Saved()
    if s.hidden then return "never" end
    return WHEN[s.when or ""] and s.when or "always"
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
function Panel.IsOpen()
    return Saved().open and true or false
end
local function Short(n)
    if n < 1000 then return format("%d", n) end
    if n < 100000 then return format("%.1f%s", n / 1000, ns.T("num.k")) end
    if n < 1000000 then return format("%d%s", n / 1000, ns.T("num.k")) end
    if n < 10000000 then return format("%.1f%s", n / 1000000, ns.T("num.m")) end
    return format("%d%s", n / 1000000, ns.T("num.m"))
end
local function SavePlace()
    local s = Saved()
    local point, _, _, x, y = frame:GetPoint()
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
    SavePlace()
    if self then self.dragAt = GetTime() end
end
local function RecStateKey()
    local R = ns.Recorder
    if not R or not R.IsOn() then return "panel.rec.off" end
    if R.IsPaused and R.IsPaused() then return "panel.rec.paused" end
    return "panel.rec.on"
end
local function TintIcon(b, hot)
    b.hot = hot
    ns.Kit.Tint(b.plate, hot and "button.bgHover" or "button.bg")
    ns.Kit.Tint(b.ring, hot and "button.borderHover" or "button.border")
    ns.Kit.Tint(b.icon, hot and "button.textHover" or b.glyph or "text.primary")
end
local function DressLock()
    local locked = Panel.IsLocked()
    lockBtn.icon:SetTexture(ART .. (locked and "lock" or "unlock") .. ".tga")
    lockBtn.glyph = locked and "text.title" or "text.muted"
    TintIcon(lockBtn, lockBtn.hot)
end
local function IconLeave(b)
    TintIcon(b, false)
    GameTooltip:Hide()
end
local function ShowActs(b)
    return ns.PanelActs ~= nil and ns.PanelActs.Show(b, frame, ns.T(b.def.label))
end
local function IconEnter(b)
    TintIcon(b, true)
    if b.def.key == "timer" then
        GameTooltip:Hide()
        ShowActs(b)
        return
    end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    if b.def.key == "lock" then
        local locked = Panel.IsLocked()
        ns.Kit.TipAdd(ns.T(locked and "panel.unlock" or "panel.lock"), "tip.title")
        ns.Kit.TipAdd(ns.T(locked and "panel.unlock.tip" or "panel.lock.tip"), "tip.body", true)
        GameTooltip:Show()
        return
    end
    ns.Kit.TipAdd(ns.T(b.def.label), "tip.title")
    ns.Kit.TipAdd(ns.T(b.def.tip), "tip.body", true)
    if b.def.key == "log" then
        ns.Kit.TipAdd(ns.T(RecStateKey()), "text.secondary", true)
        local _, frac, text = ns.Jobs.State()
        if frac and text then
            local r, g, bl = ns.Kit.Color("progress.fill")
            GameTooltip:AddLine(format(ns.T("job.tip"), text, floor(frac * 100)), r, g, bl, true)
        end
    end
    if alerts[b.def.key] then
        ns.Kit.TipAdd(ns.T("panel.tip." .. b.def.key .. ".alert"), "badge.alert", true)
    end
    local open = ns.Shell.IsOpen(b.def.key)
    local hide, show = "panel.tip.hide", "panel.tip.open"
    if b.def.key == "gp" and ns.GPMini then
        open = ns.GPMini.IsShown()
        hide, show = "panel.tip.gp.hide", "panel.tip.gp.open"
    end
    ns.Kit.TipAdd(ns.T(open and hide or show), "text.secondary", true)
    GameTooltip:Show()
end
local function IconClick(b)
    if b.dragAt == GetTime() then return end
    GameTooltip:Hide()
    if b.def.key == "timer" then
        ShowActs(b)
        return
    end
    if b.def.key == "gp" and ns.GPMini then
        ns.GPMini.Toggle()
        return
    end
    if b.def.key == "lock" then
        Panel.SetLocked(not Panel.IsLocked())
        IconEnter(b)
        return
    end
    ns.Shell.Toggle(b.def.key)
end
local function MakeIcon(i)
    local def = ICONS[i]
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(ICON)
    b:SetHeight(ICON)
    if def.tool then
        b:SetPoint("TOPRIGHT", -(PAD + (#ICONS - i) * (ICON + GAP)), -PAD)
    else
        b:SetPoint("TOPLEFT", PAD + (i - 1) * (ICON + GAP), -PAD)
    end
    b.def = def
    b.plate = b:CreateTexture(nil, "BACKGROUND")
    b.plate:SetAllPoints()
    b.plate:SetTexture(ART .. "plate.tga")
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetAllPoints()
    b.ring:SetTexture(ART .. "ring.tga")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(ART .. def.key .. ".tga")
    TintIcon(b, false)
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAllPoints()
    b.glow:SetTexture(GLOW)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
    b:SetScript("OnEnter", IconEnter)
    b:SetScript("OnLeave", IconLeave)
    b:SetScript("OnClick", IconClick)
    return b
end
local function PaintTool(b)
    ns.Kit.Paint(b.bg, b.hovered and "float.toolHover" or "float.tool")
end
local function ToolEnter(b)
    b.hovered = true
    PaintTool(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    ns.Kit.TipAdd(b.tipTitle, "tip.title")
    if b.tip then ns.Kit.TipAdd(b.tip, "tip.body", true) end
    GameTooltip:Show()
end
local function ToolLeave(b)
    b.hovered = false
    PaintTool(b)
    GameTooltip:Hide()
end
local function MakeTool(parent, size, texture)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tex:SetTexture(texture)
    b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetScript("OnEnter", ToolEnter)
    b:SetScript("OnLeave", ToolLeave)
    PaintTool(b)
    return b
end
local function DressPause()
    local R = ns.Recorder
    local on = R and R.IsOn()
    local paused = on and R.IsPaused and R.IsPaused()
    ns.Kit.Hue(pauseBtn.tex, "sem.rep.icon")
    if not on then
        pauseBtn.tex:SetAlpha(0.35)
        pauseBtn.tipTitle = ns.T("panel.pause.off")
        pauseBtn.tip = ns.T("panel.pause.off.tip")
    elseif paused then
        pauseBtn.tex:SetAlpha(1)
        local r, g, b = ns.Kit.Color("text.warn")
        pauseBtn.tex:SetVertexColor(r, g, b, 1)
        pauseBtn.tipTitle = ns.T("panel.resume")
        pauseBtn.tip = ns.T("panel.resume.tip")
    else
        pauseBtn.tex:SetAlpha(1)
        pauseBtn.tipTitle = ns.T("panel.pause")
        pauseBtn.tip = ns.T("panel.pause.tip")
    end
end
local function DressTools()
    DressLock()
    local open = Saved().open
    sizeBtn.tex:SetTexture(open and MINUS or PLUS)
    sizeBtn.tex:SetTexCoord(0, 1, 0, 1)
    sizeBtn.tipTitle = ns.T(open and "panel.collapse" or "panel.expand")
    sizeBtn.tip = ns.T(open and "panel.collapse.tip" or "panel.expand.tip")
    DressPause()
end
local function Writing()
    local R = ns.Recorder
    return R ~= nil and R.IsOn() and not (R.IsPaused and R.IsPaused()) or false
end
local function RefreshCounts()
    if Writing() then
        local seen, kept = ns.Recorder.Counts()
        countText:SetText(format(ns.T("panel.counts"), ns.Num(seen), ns.Num(kept)))
    else
        local seen = ns.Meter and ns.Meter.Seen() or 0
        countText:SetText(format(ns.T("panel.counts.seen"), ns.Num(seen)))
    end
end
local function MakeBars(bars, parent, layer, token)
    for i = 1, EQ_BARS do
        local t = parent:CreateTexture(nil, layer)
        t:SetWidth(1)
        t:SetHeight(1)
        t:SetTexture(WHITE8)
        if token then ns.Kit.Paint(t, token) end
        bars[i] = t
    end
end
local function LayBars(bars, slot)
    for i = 1, EQ_BARS do
        local t = bars[i]
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", (i - 1) * slot, 0)
        t:SetWidth(max(1, slot - 1))
    end
end
local function WatchMeter()
    if ns.Meter then ns.Meter.Watch(frame:IsShown() and Saved().open and true or false) end
end
local function NumWidth()
    local w = NUM_W
    if dpsText then
        local was = hpsText:GetText()
        hpsText:SetText("999.9к")
        w = max(w, hpsText:GetStringWidth() + 4)
        hpsText:SetText(was)
    end
    return w
end
local function Width()
    local w = baseW
    if Saved().open then w = max(w, PAD * 2 + (EQ_BARS * GRAPH_SLOT - 1 + NUM_GAP) * 2 + NumWidth() * 2 + GRAPH_GAP) end
    return max(w, countText:GetStringWidth() + PAD * 2 + 4)
end
local function ApplySize()
    RefreshCounts()
    local w = Width()
    local h = PAD * 2 + ICON + ROWGAP + EQ_H + 2 + TEXTH
    local eqW = w - PAD * 2 - (EQ_BTN + EQ_GAP) * 2
    local eqSlot = max(2, floor(eqW / EQ_BARS))
    eq:SetWidth(eqSlot * EQ_BARS - 1)
    LayBars(eqBars, eqSlot)
    if Saved().open then
        local nw = NumWidth()
        dpsText:SetWidth(nw)
        hpsText:SetWidth(nw)
        graphs:SetWidth(w - PAD * 2)
        graphs:Show()
        h = h + ROWGAP + EQ_H
    else
        graphs:Hide()
    end
    frame:SetWidth(w)
    frame:SetHeight(h)
    DressTools()
    WatchMeter()
end
local function TintEq(t, ratio)
    local r, g, b
    if ratio < 0.5 then
        local k = ratio * 2
        r, g, b = lowR + (midR - lowR) * k, lowG + (midG - lowG) * k, lowB + (midB - lowB) * k
    else
        local k = (ratio - 0.5) * 2
        r, g, b = midR + (highR - midR) * k, midG + (highG - midG) * k, midB + (highB - midB) * k
    end
    if writing then
        t:SetVertexColor(r, g, b, 1)
    else
        t:SetVertexColor(r * MUTE, g * MUTE, b * MUTE, 0.8)
    end
end
local function FeedEq(elapsed)
    local now = Writing()
    local seen = now and ns.Recorder.Counts() or (ns.Meter and ns.Meter.Seen() or 0)
    if now ~= writing then
        writing = now
        baseSeen = seen
    end
    if seen < baseSeen then baseSeen = seen end
    buckets[EQ_BARS] = seen - baseSeen
    eqElapsed = eqElapsed + elapsed
    if eqElapsed >= 1 then
        eqElapsed = eqElapsed - 1
        if eqElapsed >= 1 then eqElapsed = 0 end
        baseSeen = seen
        for i = 1, EQ_BARS - 1 do buckets[i] = buckets[i + 1] end
        buckets[EQ_BARS] = 0
    end
end
local function DrawEq()
    local peak = 1
    for i = 1, EQ_BARS do
        if buckets[i] > peak then peak = buckets[i] end
    end
    for i = 1, EQ_BARS do
        local v, t = buckets[i], eqBars[i]
        if v <= 0 then
            t:SetHeight(1)
            t:SetVertexColor(idleR, idleG, idleB, idleA)
        else
            local ratio = v / peak
            t:SetHeight(max(1.5, ratio * EQ_H))
            TintEq(t, ratio)
        end
    end
end
local function DrawGraph(bars, ring, slot)
    local peak = 1
    for i = 1, EQ_BARS do
        if ring[i] > peak then peak = ring[i] end
    end
    for i = 1, EQ_BARS do
        local v = ring[(slot + i - 1) % EQ_BARS + 1]
        local t = bars[i]
        if v <= 0 then
            t:SetHeight(1)
            t:SetAlpha(0.25)
        else
            t:SetHeight(max(1.5, v / peak * EQ_H))
            t:SetAlpha(1)
        end
    end
end
local function DrawGraphs()
    local M = ns.Meter
    if not M then return end
    local slot = M.Slot()
    DrawGraph(dpsBars, M.dmg, slot)
    DrawGraph(hpsBars, M.heal, slot)
    local dps, hps = M.Rates()
    local raid = M.InRaid()
    dpsText:SetText(Short(dps))
    hpsText:SetText(Short(hps))
    local a = M.Fighting() and 1 or 0.7
    dpsText:SetAlpha(a)
    hpsText:SetAlpha(a)
end
local function StepDot()
    local R = ns.Recorder
    if R and R.IsOn() and not (R.IsPaused and R.IsPaused()) then
        dot:Show()
        dot:SetAlpha(0.35 + 0.65 * abs(sin(GetTime() * 3)))
    else
        dot:Hide()
    end
end
local function StepAlerts()
    for i = 1, #buttons do
        local b = buttons[i]
        if alerts[b.def.key] then
            b.glow:Show()
            b.glow:SetAlpha(0.4 + 0.6 * abs(sin(GetTime() * 4)))
        elseif b.glow:IsShown() then
            b.glow:Hide()
        end
    end
end
local function OnUpdate(self, elapsed)
    StepDot()
    StepAlerts()
    FeedEq(elapsed)
    drawAcc = drawAcc + elapsed
    if drawAcc >= REFRESH then
        drawAcc = 0
        DrawEq()
        if Saved().open then DrawGraphs() end
    end
    countAcc = countAcc + elapsed
    if countAcc >= COUNT_PERIOD then
        countAcc = 0
        RefreshCounts()
        local w = Width()
        if abs(frame:GetWidth() - w) > 0.5 then ApplySize() end
        if pauseBtn.recKey ~= RecStateKey() then
            pauseBtn.recKey = RecStateKey()
            DressPause()
        end
    end
end
local function ShowProgress()
    if not strip then return end
    local _, frac, _, _, age = ns.Jobs.State()
    if frac and age >= LONG_JOB then
        stripFill:SetWidth(max(1, (ICON - STRIP_IN * 2) * frac))
        strip:Show()
    elseif strip:IsShown() then
        strip:Hide()
    end
    local b = buttons[1]
    if GameTooltip:GetOwner() == b and GameTooltip:IsShown() then IconEnter(b) end
end
local function OnTheme()
    lowR, lowG, lowB = ns.Kit.Color("badge.green")
    midR, midG, midB = ns.Kit.Color("badge.yellow")
    highR, highG, highB = ns.Kit.Color("badge.red")
    idleR, idleG, idleB, idleA = ns.Kit.Color("surface.edge")
    if pauseBtn then DressPause() end
end
local function PauseClick()
    local R = ns.Recorder
    if not R or not R.IsOn() then return end
    if R.IsPaused() then
        R.Resume("hand")
    else
        R.Pause()
        ns.Print(ns.T("rec.paused"))
    end
    DressPause()
    ToolEnter(pauseBtn)
    if ns.Settings and ns.Settings.RefreshRecord then ns.Settings.RefreshRecord() end
end
local function BuildStrip()
    pauseBtn = MakeTool(frame, EQ_BTN, PAUSE)
    pauseBtn:SetPoint("TOPLEFT", PAD, -(PAD + ICON + ROWGAP + (EQ_H - EQ_BTN) / 2))
    pauseBtn.tex:SetTexCoord(0, 1, 0, 1)
    pauseBtn:SetScript("OnClick", PauseClick)
    sizeBtn = MakeTool(frame, EQ_BTN, PLUS)
    sizeBtn:SetPoint("TOPRIGHT", -PAD, -(PAD + ICON + ROWGAP + (EQ_H - EQ_BTN) / 2))
    sizeBtn:SetScript("OnClick", function(self)
        Saved().open = not Saved().open
        countAcc = COUNT_PERIOD
        ApplySize()
        ToolEnter(self)
    end)
    eq = CreateFrame("Frame", nil, frame)
    eq:SetHeight(EQ_H)
    eq:SetPoint("TOPLEFT", PAD + EQ_BTN + EQ_GAP, -(PAD + ICON + ROWGAP))
    eqBg = eq:CreateTexture(nil, "BACKGROUND")
    eqBg:SetAllPoints()
    ns.Kit.Paint(eqBg, "progress.track")
    MakeBars(eqBars, eq, "ARTWORK", nil)
    countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOP", 0, -(PAD + ICON + ROWGAP + EQ_H + 2))
    countText:SetJustifyH("CENTER")
    ns.Kit.Text(countText, "text.secondary")
end
local function MakeGraph(parent, bars, token)
    local g = CreateFrame("Frame", nil, parent)
    g:SetHeight(EQ_H)
    g:SetWidth(EQ_BARS * GRAPH_SLOT - 1)
    local bg = g:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "progress.track")
    MakeBars(bars, g, "ARTWORK", token)
    LayBars(bars, GRAPH_SLOT)
    return g
end
local function MakeNumber(g)
    local fs = graphs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", g, "RIGHT", NUM_GAP, 0)
    fs:SetWidth(NUM_W)
    fs:SetHeight(EQ_H)
    fs:SetJustifyH("LEFT")
    ns.Kit.Text(fs, "text.primary")
    return fs
end
local function GraphEnter(self)
    local M = ns.Meter
    if not M then return end
    local heal = self.heal
    local dps, hps = M.Rates()
    local wd, wh = M.WindowRates()
    local raid = M.InRaid()
    local key = heal and (raid and "panel.hps.raid" or "panel.hps") or (raid and "panel.dps.raid" or "panel.dps")
    ns.Tip.Show(self, {
        { kind = "head", left = ns.T(key) },
        { kind = "row", left = ns.T("panel.tip.fight"), right = Short(heal and hps or dps) },
        { kind = "row", left = format(ns.T("panel.tip.window"), M.Window()), right = Short(heal and wh or wd) },
        { kind = "foot", left = ns.T(heal and "panel.tip.heal" or "panel.tip.dmg") },
    })
end
local function Hover(g, num, heal)
    local h = CreateFrame("Frame", nil, graphs)
    h:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", num, "BOTTOMRIGHT", 0, 0)
    h:EnableMouse(true)
    h.heal = heal
    h:SetScript("OnEnter", GraphEnter)
    h:SetScript("OnLeave", ns.Tip.Hide)
end
local function BuildGraphs()
    graphs = CreateFrame("Frame", nil, frame)
    graphs:SetHeight(EQ_H)
    graphs:SetPoint("TOPLEFT", PAD, -(PAD + ICON + ROWGAP + EQ_H + 2 + TEXTH + ROWGAP))
    dpsGraph = MakeGraph(graphs, dpsBars, "sem.dmg")
    dpsGraph:SetPoint("LEFT", 0, 0)
    dpsText = MakeNumber(dpsGraph)
    hpsGraph = MakeGraph(graphs, hpsBars, "sem.heal")
    hpsGraph:SetPoint("LEFT", dpsText, "RIGHT", GRAPH_GAP, 0)
    hpsText = MakeNumber(hpsGraph)
    Hover(dpsGraph, dpsText, false)
    Hover(hpsGraph, hpsText, true)
    graphs:Hide()
end
local function Build()
    local s = Saved()
    frame = CreateFrame("Frame", "HTP_FailWatchPanel", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() DragStart() end)
    frame:SetScript("OnDragStop", function() DragStop() end)
    ns.Kit.Skin(frame, "float")
    frame:SetScale((Panel.Scale()))
    frame:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or -200)
    for i = 1, #ICONS do
        buttons[i] = MakeIcon(i)
        if ICONS[i].key == "lock" then lockBtn = buttons[i] end
    end
    dot = buttons[1]:CreateTexture(nil, "OVERLAY")
    dot:SetWidth(DOT)
    dot:SetHeight(DOT)
    dot:SetPoint("TOPRIGHT", 1, 1)
    ns.Kit.Paint(dot, "sem.rec")
    dot:Hide()
    strip = CreateFrame("Frame", nil, buttons[1])
    strip:SetPoint("BOTTOMLEFT", STRIP_IN, STRIP_IN)
    strip:SetPoint("BOTTOMRIGHT", -STRIP_IN, STRIP_IN)
    strip:SetHeight(STRIP_H)
    local stripBg = strip:CreateTexture(nil, "BACKGROUND")
    stripBg:SetAllPoints()
    ns.Kit.Paint(stripBg, "progress.ring")
    stripFill = strip:CreateTexture(nil, "ARTWORK")
    stripFill:SetPoint("TOPLEFT", 0, 0)
    stripFill:SetPoint("BOTTOMLEFT", 0, 0)
    stripFill:SetWidth(1)
    ns.Kit.Paint(stripFill, "progress.fill")
    strip:Hide()
    BuildStrip()
    BuildGraphs()
    OnTheme()
    ns.Kit.OnTheme(OnTheme)
    frame:SetScript("OnUpdate", OnUpdate)
    frame:SetScript("OnHide", function()
        if ns.PanelActs then ns.PanelActs.Hide() end
        DragStop()
        WatchMeter()
    end)
    frame:SetScript("OnShow", WatchMeter)
    ApplySize()
end
local function Apply()
    if Wanted() then
        if not frame then Build() end
        frame:Show()
        WatchMeter()
    elseif frame then
        frame:Hide()
    end
    if ns.Settings then ns.Settings.Refresh() end
end
function Panel.SetEnabled(on)
    Saved().hidden = not on
    Apply()
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
    local l, t = frame:GetLeft(), frame:GetTop()
    frame:SetScale(v)
    if l and t and v > 0 then
        local k = old / v
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l * k, t * k - UIParent:GetTop() / v)
        SavePlace()
    end
end
function Panel.SetOpen(on)
    Saved().open = on and true or false
    if frame then ApplySize() end
end
function Panel.SetAlert(key, on)
    alerts[key] = on and true or nil
end
function Panel.HasAlert(key)
    return alerts[key] == true
end
function Panel.SetLocked(on)
    Saved().locked = on and true or false
    if frame then DressTools() end
    if ns.Settings then ns.Settings.Refresh() end
end
ns.OnReady(function()
    Apply()
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("RAID_ROSTER_UPDATE")
    watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
    watch:RegisterEvent("PLAYER_ENTERING_WORLD")
    watch:SetScript("OnEvent", function()
        local shown = frame and frame:IsShown() and true or false
        if shown ~= Wanted() then Apply() end
    end)
end)
ns.Jobs.OnChange(ShowProgress)
