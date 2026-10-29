local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local floor = math.floor
local Panel = ns.Panel
local Kit = ns.Kit
local EQ_BARS = 30
local EQ_SLOT = 2
local EQ_H = 10
local GRAPH_MAX = 30
local GRAPH_SLOT = 3
local GRAPH_GAP = 8
local NUM_W = 36
local NUM_PROBE = 999.9
local NUM_GAP = 4
local MUTE = 0.55
local DIM = 0.6
local RATE_PROBE = 9999
local FLASK_TEX = "Interface\\Icons\\INV_Alchemy_EndlessFlask_06"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local lowR, lowG, lowB, midR, midG, midB, highR, highG, highB = 0, 1, 0, 1, 1, 0, 1, 0, 0
local idleR, idleG, idleB, idleA = 1, 1, 1, 0.1
local vals = {}
local function OnTheme()
    lowR, lowG, lowB = ns.Kit.Color("badge.green")
    midR, midG, midB = ns.Kit.Color("badge.yellow")
    highR, highG, highB = ns.Kit.Color("badge.red")
    idleR, idleG, idleB, idleA = ns.Kit.Color("surface.edge")
end
local function Short(n)
    return ns.Short(n, 1, 1e5, 1e7)
end
local function MakeBars(bars, n, parent, token)
    for i = 1, n do
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetWidth(1)
        t:SetHeight(1)
        t:SetTexture(WHITE8)
        if token then ns.Kit.Paint(t, token) end
        bars[i] = t
    end
end
local function LayBars(bars, slot)
    for i = 1, #bars do
        local t = bars[i]
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", (i - 1) * slot, 0)
        t:SetWidth(max(1, slot - 1))
    end
end
local function Graph(parent, bars, n, slot, h, token)
    local g = CreateFrame("Frame", nil, parent)
    g:SetHeight(h)
    g:SetWidth(n * slot - 1)
    local bg = g:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "progress.track")
    MakeBars(bars, n, g, token)
    LayBars(bars, slot)
    return g
end
local function RecState()
    local R = ns.Recorder
    if not R or not R.IsOn() then return "off" end
    if R.IsPaused and R.IsPaused() then return "paused" end
    if R.InZone and not R.InZone() then return "zone" end
    return "on"
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
    t:SetVertexColor(r, g, b, 1)
end
local function FeedEq(row, seen, dt, on)
    local b = row.buckets
    if on ~= row.writing then
        row.writing = on
        row.base = seen
        for i = 1, EQ_BARS do b[i] = 0 end
    end
    if not on then return end
    if seen < row.base then row.base = seen end
    b[EQ_BARS] = seen - row.base
    row.tick = row.tick + dt
    if row.tick >= 1 then
        row.tick = row.tick - 1
        if row.tick >= 1 then row.tick = 0 end
        row.base = seen
        for i = 1, EQ_BARS - 1 do b[i] = b[i + 1] end
        b[EQ_BARS] = 0
    end
end
local function DrawEq(row)
    local b, peak = row.buckets, 1
    for i = 1, EQ_BARS do
        if b[i] > peak then peak = b[i] end
    end
    for i = 1, EQ_BARS do
        local v, t = b[i], row.bars[i]
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
local function PerSec(row)
    return row.buckets[EQ_BARS - 1] or 0
end
local function RecTip(row)
    local state = RecState()
    local lines = { { kind = "head", left = ns.T("panel.line.rec"), right = ns.T("panel.rec.state." .. state) } }
    if state == "on" then
        local seen, kept = ns.Recorder.Counts()
        lines[2] = { kind = "row", left = ns.T("panel.rec.rate.row"), right = ns.Num(PerSec(row)) }
        lines[3] = { kind = "row", left = ns.T("panel.rec.seen"), right = ns.Num(seen) }
        lines[4] = { kind = "row", left = ns.T("panel.rec.kept"), right = ns.Num(kept) }
        lines[5] = { kind = "sub", left = ns.T("panel.rec.what") }
    else
        lines[2] = { kind = "sub", left = ns.T("panel.rec.why." .. state) }
    end
    lines[#lines + 1] = { kind = "foot", left = ns.T("panel.rec.click") }
    return lines
end
Panel.Widget({
    key = "count",
    order = 10,
    label = "set.panel.row.count",
    rate = 0.1,
    Build = function(row)
        row.buckets, row.bars = {}, {}
        for i = 1, EQ_BARS do row.buckets[i] = 0 end
        row.base, row.tick, row.writing = 0, 0, false
        row.eq = Graph(row, row.bars, EQ_BARS, EQ_SLOT, EQ_H, nil)
        Panel.Line(row, row.eq, ns.T("panel.line.rec"))
        Panel.Reserve(row, format(ns.T("panel.rec.rate"), ns.Num(RATE_PROBE)))
        DrawEq(row)
        Panel.Empty(row, "zone")
    end,
    Update = function(row, now)
        local dt = now - (row.last or now)
        row.last = now
        local on = RecState() == "on"
        FeedEq(row, on and (ns.Recorder.Counts()) or 0, dt, on)
        DrawEq(row)
        if on then
            Panel.Value(row, format(ns.T("panel.rec.rate"), ns.Num(PerSec(row))))
        else
            Panel.Empty(row, RecState())
        end
    end,
    Tip = RecTip,
    Click = function(row, button)
        if button == "LeftButton" then Panel.Open("log") end
    end,
})
local BLOCKS = {
    { kind = "dmg", token = "sem.dmg", view = "dps" },
    { kind = "heal", token = "sem.heal", view = "hps" },
}
local function PaintBars(bars, n, peak, a)
    for i = 1, n do
        local v, t = vals[i], bars[i]
        if v <= 0 then
            t:SetHeight(1)
            t:SetAlpha(0.25 * a)
        else
            t:SetHeight(max(1.5, v / peak * Panel.RowH()))
            t:SetAlpha(a)
        end
    end
end
local function Peak(n)
    local peak = 1
    for i = 1, n do
        if vals[i] > peak then peak = vals[i] end
    end
    return peak
end
local function FromRing(ring, n, slot, size)
    local m = min(n, size)
    for i = 1, n - m do vals[i] = 0 end
    for i = 1, m do vals[n - m + i] = ring[(slot - m + i - 1) % size + 1] or 0 end
end
local function Number(b, text, a)
    if text ~= b.shown then
        b.shown = text
        b.text:SetText(text)
    end
    if a ~= b.a then
        b.a = a
        b.text:SetAlpha(a)
    end
end
local function DrawWindow(b, live, fighting, rate)
    local n = b.n
    if live then
        PaintBars(b.bars, n, Peak(n), 1)
        Number(b, Short(rate), 1)
        if fighting then
            for i = 1, n do b.snap[i] = vals[i] end
            b.snapV = rate
        end
        return
    end
    for i = 1, n do vals[i] = b.snapV and b.snap[i] or 0 end
    PaintBars(b.bars, n, Peak(n), DIM)
    Number(b, b.snapV and Short(b.snapV) or ns.T("panel.none"), DIM)
end
local function HadFight(M)
    return M ~= nil and (M.Fighting() or M.FightTime() > 0)
end
local function DrawGraphs(row)
    local M, b = ns.Meter, row.blocks
    if not M then
        for i = 1, #b do
            for k = 1, b[i].n do vals[k] = 0 end
            PaintBars(b[i].bars, b[i].n, 1, DIM)
            Number(b[i], ns.T("panel.none"), DIM)
        end
        return
    end
    local slot, size = M.Slot(), M.Window()
    local live, fighting = M.Active(), M.Fighting()
    local wd, wh = M.WindowRates()
    if live then FromRing(M.dmg, b[1].n, slot, size) end
    DrawWindow(b[1], live, fighting, wd)
    if live then FromRing(M.heal, b[2].n, slot, size) end
    DrawWindow(b[2], live, fighting, wh)
end
local function FightState(M)
    if M.Fighting() then return ns.T("panel.state.going") end
    return ns.T(M.FightTime() > 0 and "panel.state.last" or "panel.state.none")
end
local function NowTip(M, b)
    local heal = b.kind == "heal"
    local dps, hps = M.Rates()
    local wd, wh = M.WindowRates()
    local key = (heal and "panel.hps.now" or "panel.dps.now") .. (M.InRaid() and ".raid" or "")
    local lines = { { kind = "head", left = ns.T(key), right = FightState(M) } }
    if M.Active() then
        lines[2] = { kind = "row", left = format(ns.T("panel.tip.window"), M.Window()), right = Short(heal and wh or wd) }
    elseif b.snapV then
        lines[2] = { kind = "row", left = ns.T("panel.tip.window.last"), right = Short(b.snapV), tone = "dim" }
    end
    if HadFight(M) then
        lines[#lines + 1] = { kind = "row", left = ns.T("panel.tip.fight"), right = Short(heal and hps or dps) }
    end
    lines[#lines + 1] = { kind = "foot", left = ns.T("panel.graphs.click." .. b.view) }
    return lines
end
local function GraphEnter(self)
    local M = ns.Meter
    if not M then
        Panel.Tip(self, { { kind = "head", left = ns.T("set.panel.row.graphs"), right = ns.T("panel.state.none") },
            { kind = "foot", left = ns.T("panel.graphs.click." .. self.block.view) } })
        return
    end
    Panel.Tip(self, NowTip(M, self.block))
end
local function GraphClick(self, button)
    if button ~= "LeftButton" or not (ns.Shell and ns.Shell.FoldTo) then return end
    ns.Tip.Hide()
    ns.Shell.FoldTo(self.block.view)
end
local function NumWidth(row)
    local fs = row.blocks[1].text
    local was = fs:GetText()
    fs:SetText(ns.Short(NUM_PROBE * 1000, 1, false))
    local w = max(NUM_W, (fs:GetStringWidth() or 0) + 4)
    fs:SetText(was or "")
    return w
end
local graphRows = {}
local function FitBars(b, gw)
    local n = max(1, min(GRAPH_MAX, floor((gw + 1) / GRAPH_SLOT)))
    b.n = n
    b.g:SetWidth(gw)
    LayBars(b.bars, (gw + 1) / n)
    for i = 1, GRAPH_MAX do
        if i <= n then b.bars[i]:Show() else b.bars[i]:Hide() end
    end
end
local function LayGraphs(row)
    local nw = NumWidth(row)
    local room = Panel.RowRoom()
    local gw = max(GRAPH_SLOT * 4 - 1, floor((room - GRAPH_GAP * (#BLOCKS - 1)) / #BLOCKS) - NUM_GAP - nw)
    for i = 1, #row.blocks do
        local b = row.blocks[i]
        b.g:SetHeight(Panel.RowH())
        b.text:SetWidth(nw)
        FitBars(b, gw)
    end
    row.need = room
    row:SetWidth(room)
end
Panel.Widget({
    key = "graphs",
    order = 20,
    label = "set.panel.row.graphs",
    rate = 0.1,
    Live = function(on)
        if ns.Meter then ns.Meter.Watch(on) end
    end,
    Build = function(row)
        row.blocks = {}
        local prev
        for i = 1, #BLOCKS do
            local b = { kind = BLOCKS[i].kind, view = BLOCKS[i].view, bars = {}, snap = {}, n = GRAPH_MAX }
            b.g = Graph(row, b.bars, GRAPH_MAX, GRAPH_SLOT, Panel.RowH(), BLOCKS[i].token)
            b.text = Kit.Str(row, "GameFontHighlightSmall")
            b.text:SetJustifyH("RIGHT")
            ns.Kit.Text(b.text, "text.primary")
            if i == #BLOCKS then
                b.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                b.g:SetPoint("RIGHT", b.text, "LEFT", -NUM_GAP, 0)
            else
                if prev then
                    b.g:SetPoint("LEFT", prev, "RIGHT", GRAPH_GAP, 0)
                else
                    b.g:SetPoint("LEFT", row, "LEFT", 0, 0)
                end
                b.text:SetPoint("LEFT", b.g, "RIGHT", NUM_GAP, 0)
            end
            local h = CreateFrame("Frame", nil, row)
            h:SetPoint("TOPLEFT", b.g, "TOPLEFT", 0, 0)
            h:SetPoint("BOTTOMRIGHT", b.text, "BOTTOMRIGHT", 0, 0)
            h:EnableMouse(true)
            h.kind, h.block = b.kind, b
            h:SetScript("OnEnter", GraphEnter)
            h:SetScript("OnLeave", ns.Tip.Hide)
            h:SetScript("OnMouseUp", GraphClick)
            prev = b.text
            row.blocks[i] = b
        end
        graphRows[#graphRows + 1] = row
        LayGraphs(row)
        DrawGraphs(row)
    end,
    Update = DrawGraphs,
})
Kit.OnFont(function()
    for i = 1, #graphRows do
        local row = graphRows[i]
        LayGraphs(row)
        DrawGraphs(row)
    end
end)
local function CanCheck()
    local L = ns.Lead
    return L ~= nil and L.ReadyUI ~= nil and L.ReadyUI.Check ~= nil
end
local function OpenCheck()
    if CanCheck() then
        ns.Lead.ReadyUI.Check()
    elseif ns.Shell then
        ns.Shell.Open("raid")
    end
end
local function FlaskUpdate(row)
    local R = ns.FlaskReady
    if not Panel.Ctx().group then
        Panel.Empty(row, "nogroup")
        return
    end
    if not R then return end
    R.Tick()
    local ready, total, known = R.Counts()
    local F = ns.Flasks
    local given = F and F.IsOn() and format(ns.T("flaskrow.given"), F.Total()) or ""
    if known and total > 0 then
        Panel.Value(row, format("%d/%d", ready, total) .. given, ready >= total and "good" or "warn")
    elseif given ~= "" then
        Panel.Value(row, Panel.EmptyText("none") .. given)
    else
        Panel.Empty(row, "none")
    end
end
local FLASK_LIST = 10
local function HandoutTip(lines)
    local F = ns.Flasks
    if not F then return end
    local on = F.IsOn()
    local n, people = F.Stats()
    if not on and n == 0 then return end
    lines[#lines + 1] = { kind = "row", left = ns.T("flaskrow.handout"),
                          right = ns.T(on and "flaskrow.on" or "flaskrow.off"), tone = on and "good" or "dim" }
    lines[#lines + 1] = { kind = "sub", left = ns.T("flaskrow.got"), right = format("%d / %d", n, people) }
    local R = ns.FlaskReady
    local list = R and R.Members() or {}
    local miss = {}
    for i = 1, #list do
        local m = list[i]
        if m.name and F.Count(m.name) == 0 then miss[#miss + 1] = m end
    end
    if #miss > 0 then
        lines[#lines + 1] = { kind = "row", left = ns.T("flaskrow.nogot"), right = tostring(#miss), tone = "warn" }
        for i = 1, #miss do
            if i > FLASK_LIST then
                lines[#lines + 1] = { kind = "sub", left = format(ns.T("flaskrow.more"), #miss - FLASK_LIST) }
                break
            end
            lines[#lines + 1] = { kind = "sub", left = miss[i].name, class = miss[i].class }
        end
    end
    lines[#lines + 1] = { kind = "note", left = ns.T("flaskrow.note") }
end
Panel.Widget({
    key = "flasks",
    order = 30,
    label = "set.panel.row.flasks",
    rate = 1,
    Build = function(row)
        Panel.Line(row, FLASK_TEX, ns.T("panel.line.flasks"))
        Panel.Reserve(row, "99/99")
        Panel.Empty(row, "nogroup")
    end,
    Update = FlaskUpdate,
    Tip = function(row)
        local R = ns.FlaskReady
        FlaskUpdate(row)
        local lines
        local group = Panel.Ctx().group
        if R and group then
            lines = R.TipRows()
            HandoutTip(lines)
        else
            lines = { { kind = "head", left = ns.T("flaskrow.head"), right = Panel.EmptyText("nogroup") } }
        end
        local toggle = group and ns.FlaskTrade
        lines[#lines + 1] = { kind = "foot", left = ns.T(toggle and "flaskrow.click" or "buffrow.click") }
        return lines
    end,
    Click = function(row, button)
        local T = ns.FlaskTrade
        if button == "LeftButton" and T and Panel.Ctx().group then
            T.Switch(not ns.Flasks.IsOn())
            FlaskUpdate(row)
        elseif button == "LeftButton" or button == "RightButton" then
            OpenCheck()
        end
    end,
})
OnTheme()
ns.Kit.OnTheme(OnTheme)
