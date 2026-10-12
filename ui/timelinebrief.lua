local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local TOPPAD = 6
local LABELH = 14
local FAULT_H = 28
local FAULT_ICON = 18
local BOSS_H = 26
local ACTS_H = 26
local STATE_ROW = 18
local STATE_PAD = 3
local LIFE_MIN = 96
local LIFE_HP = 0.6
local FEED_ROW = 17
local FEED_ROWS = 2
local FEED_ICON = 14
local FEED_GAP = 8
local FEED_MAXW = 220
local BIN = 3
local BINS_MAX = 400
local MANA_LINE = 2
local DOT = 6
local UNTIMED_MAX = 4
local B = {}
ns.TimelineBrief = B
local holder
local marks = {}
local last
local function UI()
    return ns.GetDB().settings.ui
end
function B.On()
    return UI().tlView == "brief"
end
function B.Toggle()
    local ui = UI()
    ui.tlView = (ui.tlView ~= "brief") and "brief" or nil
end
local function Folded(key)
    local f = UI().briefFold
    return type(f) == "table" and f[key] == true
end
local function FoldClick(head)
    local ui = UI()
    if type(ui.briefFold) ~= "table" then ui.briefFold = {} end
    ui.briefFold[head.foldKey] = not ui.briefFold[head.foldKey] or nil
    if last then last.ctx.redraw() end
end
local function Short(n)
    return ns.BadgeTips and ns.BadgeTips.Short(n) or tostring(floor(n + 0.5))
end
local function Visible(c, y, h)
    return y + h > 0 and y < c.canvas:GetHeight()
end
local function Label(c, key, label, y)
    if not Visible(c, y, LABELH) then return end
    local head = c.GetBlock()
    head:SetWidth(c.nameW)
    head:SetHeight(LABELH)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", 1, -(y + 1))
    ns.Kit.Shade(head.tex, "surface.laneHead")
    ns.Kit.Tone(head.label, "surface.laneText")
    head.icon:Hide()
    head.label:SetWidth(c.nameW - 6)
    head.label:SetText((Folded(key) and "+ " or "- ") .. label)
    head.tip, head.tip2 = label, ns.T("tl.track.fold")
    head.jumpTo, head.spellId = nil, nil
    head.foldKey = key
    head.onClick = FoldClick
end
local function Note(c, text, x, y, token)
    local b = c.GetBlock()
    b:SetHeight(LABELH)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -y)
    ns.Kit.Shade(b.tex, "surface.clear")
    ns.Kit.Tone(b.label, token or "text.secondary")
    b.icon:Hide()
    b.label:SetWidth(0)
    b.label:SetText(text)
    local w = (b.label:GetStringWidth() or 0) + 6
    b.label:SetWidth(w)
    b:SetWidth(w)
    b.tip, b.jumpTo, b.spellId = nil, nil, nil
end
local function Holder(c)
    if not holder then
        holder = CreateFrame("Frame", nil, c.canvas)
        holder:SetAllPoints(c.canvas)
    end
    holder:SetFrameLevel(c.canvas:GetFrameLevel() + 12)
    holder.who = c.player
    holder:Show()
    return holder
end
local function Mark(i)
    local m = marks[i]
    if not m then
        m = ns.Badges.Mark(holder, FAULT_ICON)
        m:Layout(FAULT_ICON)
        marks[i] = m
    end
    return m
end
local function PlaceMark(c, m, f, x, y)
    local kind = f.hit.rule.kind
    m:SetModel({
        icon = ns.GPList.Icon(f.hit.icon),
        count = "",
        verdict = f.grade,
        lines = ns.GPList.HitLines(c.fight, f.hit),
        fight = c.fight,
        at = f.t,
        preview = kind == "death" or kind == "anydeath" or nil,
    })
    m.who = c.player
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -y)
    m:Show()
end
local function DrawFaults(c, y, h)
    local list = ns.TimelineBriefData.Faults(c.fight, c.player, c.redraw)
    local top = y + floor((h - FAULT_ICON) / 2)
    if not list then
        Note(c, ns.T("tb.faults.wait"), c.gutter + 6, y + floor((h - LABELH) / 2))
        return 0
    end
    if #list == 0 then
        Note(c, ns.T("tb.faults.none"), c.gutter + 6, y + floor((h - LABELH) / 2), "badge.green")
        return 0
    end
    if not Visible(c, top, FAULT_ICON) then return 0 end
    Holder(c)
    local used, whole = 0, 0
    local lastX = -1e9
    local right = c.canvas:GetWidth() - FAULT_ICON - 2
    for i = 1, #list do
        local f = list[i]
        if not f.t then
            if whole < UNTIMED_MAX then
                whole = whole + 1
                used = used + 1
                PlaceMark(c, Mark(used), f, c.gutter - 4 - whole * (FAULT_ICON + 4), top)
            end
        elseif f.t >= c.from and f.t <= c.to then
            local x = max(c.XOf(f.t) - FAULT_ICON / 2, lastX + FAULT_ICON + 3, c.gutter + 1)
            if x <= right then
                used = used + 1
                PlaceMark(c, Mark(used), f, x, top)
                lastX = x
            end
        end
    end
    return used
end
local function DrawStates(c, rows, y)
    local plotR = c.canvas:GetWidth()
    for r = 1, #rows do
        local row = rows[r]
        local ry = y + (r - 1) * STATE_ROW
        if Visible(c, ry, STATE_ROW) then
            local barH = STATE_ROW - STATE_PAD * 2
            local gut = c.GetBlock()
            gut:SetWidth(c.nameW)
            gut:SetHeight(barH)
            gut:ClearAllPoints()
            gut:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", 1 + 8, -(ry + STATE_PAD))
            gut:SetWidth(c.nameW - 8)
            ns.Kit.Shade(gut.tex, "surface.alt")
            local icon = ns.Effects.IconById(row.id)
            if icon then
                gut.icon:SetWidth(barH)
                gut.icon:SetHeight(barH)
                gut.icon:SetTexture(icon)
                gut.icon:Show()
                gut.label:SetPoint("LEFT", barH + 2, 0)
                gut.castLabel = true
            else
                gut.icon:Hide()
            end
            ns.Kit.Tone(gut.label, "surface.label")
            c.FitText(gut.label, row.label, c.nameW - 14 - (icon and barH or 0))
            gut.tip, gut.spellId, gut.jumpTo = row.label, row.id, nil
            gut.tip2 = format(ns.T("tl.fx.count"), #row.items)
            local token = row.kind == "ctl" and "badge.red" or (row.kind == "bad" and "sem.dmg" or "sem.heal")
            for i = 1, #row.items do
                local a = row.items[i]
                local to = a.to or a.t
                if to >= c.from and a.t <= c.to then
                    local x0 = c.XOf(max(a.t, c.from))
                    local x1 = min(c.XOf(min(to, c.to)), plotR)
                    local b = c.GetBlock()
                    b:SetWidth(max(3, x1 - x0))
                    b:SetHeight(barH)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(ry + STATE_PAD))
                    ns.Kit.Shade(b.tex, token, 0.9)
                    b.icon:Hide()
                    b.label:SetText("")
                    b.tip, b.at, b.spellId = a.label, a.t, tonumber(a.id)
                    b.jumpTo = a.src ~= c.player and c.fight.players[a.src or ""] and a.src or nil
                    b.tip2 = format(ns.T("tl.span.fmt"), c.Clock(a.t - c.fight.from), c.Clock(to - c.fight.from),
                        to - a.t, a.src and ("  |  " .. a.src) or "")
                end
            end
        end
    end
end
local function HpBar(c, x0, x1, pct, top, hh)
    local t = c.GetBar()
    if pct <= 0 then
        ns.Kit.Shade(t, "sem.death")
        t:SetHeight(2)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - 2))
    else
        local barH = max(1, pct * hh)
        ns.Kit.Shade(t, pct < 0.35 and "sem.hpLow" or "sem.hpOk")
        t:SetHeight(barH)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - barH))
    end
    t:SetWidth(max(1, x1 - x0))
end
local function DrawLevels(c, list, top, hh, mana)
    if not list then return end
    local right = c.canvas:GetWidth()
    for i = 1, #list do
        local s = list[i]
        local nextT = list[i + 1] and list[i + 1].t or c.to
        if nextT >= c.from and s.t <= c.to then
            local x0 = c.XOf(max(s.t, c.from))
            local x1 = min(c.XOf(min(nextT, c.to)), right)
            if mana then
                local t = c.GetBar()
                ns.Kit.Shade(t, "sem.stat.hps", 0.95)
                t:SetWidth(max(1, x1 - x0))
                t:SetHeight(MANA_LINE)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - s.pct * hh - MANA_LINE / 2))
            else
                HpBar(c, x0, x1, s.pct, top, hh)
            end
        end
    end
end
local function DrawFlow(c, top, hh)
    local data = c.data
    local plot = c.canvas:GetWidth() - c.gutter
    local bin = max(BIN, plot / BINS_MAX)
    local n = floor(plot / bin) + 1
    local heal, foe, own = {}, {}, {}
    local players = c.fight.players
    local healed, taken = data.healed or {}, data.taken or {}
    for i = 1, #healed do
        local it = healed[i]
        if it.t >= c.from and it.t <= c.to then
            local k = floor((c.XOf(it.t) - c.gutter) / bin) + 1
            local v = (it.amount or 0) - (it.over or 0) + (it.absorbed or 0)
            if v > 0 then heal[k] = (heal[k] or 0) + v end
        end
    end
    for i = 1, #taken do
        local it = taken[i]
        if not it.miss and it.t >= c.from and it.t <= c.to then
            local k = floor((c.XOf(it.t) - c.gutter) / bin) + 1
            local into = (it.src and not players[it.src]) and foe or own
            into[k] = (into[k] or 0) + (it.amount or 0)
        end
    end
    local peak = 1
    for k = 1, n do
        local up, down = heal[k] or 0, (foe[k] or 0) + (own[k] or 0)
        if up > peak then peak = up end
        if down > peak then peak = down end
    end
    local half = floor(hh / 2)
    local mid = top + half
    local axis = c.GetBar()
    ns.Kit.Shade(axis, "surface.grid")
    axis:ClearAllPoints()
    axis:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.gutter, -mid)
    axis:SetWidth(plot)
    axis:SetHeight(1)
    local w = max(1, bin - 1)
    for k = 1, n do
        local x = c.gutter + (k - 1) * bin
        local up = heal[k]
        if up then
            local bh = max(1, sqrt(up / peak) * (half - 1))
            local t = c.GetBar()
            ns.Kit.Shade(t, "sem.heal", 0.95)
            t:SetWidth(w)
            t:SetHeight(bh)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(mid - bh))
        end
        local f, o = foe[k] or 0, own[k] or 0
        if f + o > 0 then
            local total = max(1, sqrt((f + o) / peak) * (half - 1))
            local fh = total * f / (f + o)
            if fh >= 1 then
                local t = c.GetBar()
                ns.Kit.Shade(t, "sem.dmg", 0.95)
                t:SetWidth(w)
                t:SetHeight(fh)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(mid + 1))
            end
            if total - fh >= 1 then
                local t = c.GetBar()
                ns.Kit.Shade(t, "badge.yellow", 0.8)
                t:SetWidth(w)
                t:SetHeight(total - fh)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(mid + 1 + fh))
            end
        end
    end
end
local function DrawLife(c, y, h)
    local hpH = floor(h * LIFE_HP)
    local flowTop = y + hpH + 4
    local flowH = h - hpH - 6
    local life = { y = y + 2, hpH = hpH - 2, flowTop = flowTop, flowH = flowH }
    if Visible(c, y, h) and c.data then
        DrawLevels(c, c.data.hp, life.y, life.hpH, false)
        if c.data.mana and #c.data.mana > 0 then
            DrawLevels(c, c.data.mana, life.y, life.hpH, true)
            Note(c, ns.T("tb.mana"), 10, y + LABELH + 2, "sem.stat.hps")
        end
        DrawFlow(c, flowTop, flowH)
        Note(c, ns.T("tb.flow"), 10, flowTop + floor((flowH - LABELH) / 2), "text.secondary")
    end
    return life
end
local function FeedIcon(tex, icon)
    if icon == "death" then
        ns.Kit.Icon.Mark(tex, 8)
    elseif icon == "wave" then
        ns.Kit.Icon.Mark(tex, 7)
    elseif icon == "phase" then
        ns.Kit.Icon.Heroic(tex)
    else
        local id = tonumber(icon)
        ns.Kit.Icon.Spell(tex, id and id > 0 and id or nil)
    end
end
local function DrawFeed(c, y)
    local f = ns.TimelineBriefData.Feed(c.fight, c.redraw)
    if not f then
        Note(c, ns.T("tb.feed.wait"), c.gutter + 6, y + 2)
        return
    end
    local rows = ns.TimelineBriefData.FeedFor(f, c.player)
    local ends = {}
    for r = 1, FEED_ROWS do ends[r] = -1e9 end
    local right = c.canvas:GetWidth() - 2
    local from = c.fight.from
    for k = 1, #rows do
        local i = rows[k]
        local t = from + f.t[i]
        if t >= c.from and t <= c.to then
            local x = c.XOf(t)
            local lane
            for r = 1, FEED_ROWS do
                if x >= ends[r] + FEED_GAP then
                    lane = r
                    break
                end
            end
            if lane and x < right - FEED_ICON then
                local ry = y + (lane - 1) * FEED_ROW
                local b = c.GetBlock()
                b:SetHeight(FEED_ROW - 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(ry + 1))
                ns.Kit.Shade(b.tex, f.imp[i] and "surface.laneHead" or "surface.clear")
                b.icon:SetWidth(FEED_ICON)
                b.icon:SetHeight(FEED_ICON)
                FeedIcon(b.icon, f.icon[i])
                b.icon:Show()
                b.label:SetPoint("LEFT", FEED_ICON + 3, 0)
                b.castLabel = true
                ns.Kit.Tone(b.label, f.imp[i] and "text.bright" or "text.secondary")
                local room = min(FEED_MAXW, right - x - FEED_ICON - 6)
                c.FitText(b.label, f.text[i], room)
                b.label:SetWidth(0)
                local w = min(room, b.label:GetStringWidth() or 0) + FEED_ICON + 6
                b.label:SetWidth(w - FEED_ICON - 6)
                b:SetWidth(w)
                ends[lane] = x + w
                b.tip, b.at, b.jumpTo = f.text[i], t, nil
                b.spellId = tonumber(f.icon[i])
                b.tip2 = c.Clock(f.t[i])
                b.tip3 = f.tip[i] ~= f.text[i] and f.tip[i] or nil
            end
        end
    end
end
local function Tracks(c, stateRows, acts)
    local data = c.data
    local list = { { key = "faults", label = ns.T("tb.faults"), h = FAULT_H } }
    if data and data.boss and #data.boss > 0 then
        list[#list + 1] = { key = "boss", label = ns.T("tb.boss"), h = BOSS_H }
    end
    if #acts > 0 then list[#list + 1] = { key = "acts", label = ns.T("tb.acts"), h = ACTS_H } end
    if #stateRows > 0 then
        list[#list + 1] = { key = "states", label = ns.T("tb.states"), h = LABELH + #stateRows * STATE_ROW + 2 }
    end
    list[#list + 1] = { key = "life", label = ns.T("tb.life"), h = LIFE_MIN, rest = true }
    list[#list + 1] = { key = "feed", label = ns.T("tb.feed"), h = FEED_ROW * FEED_ROWS + 4 }
    return list
end
function B.Draw(c)
    if holder then holder:Hide() end
    for i = 1, #marks do marks[i]:Hide() end
    last = { ctx = c }
    local data = c.data
    local stateRows = data and ns.TimelineBriefData.States(data, c.fight) or {}
    local acts = data and ns.TimelineBriefData.Acts(data) or {}
    local list = Tracks(c, stateRows, acts)
    local view = max(1, c.canvas:GetHeight() - TOPPAD)
    local fixed = 0
    for i = 1, #list do
        local tr = list[i]
        tr.full = Folded(tr.key) and LABELH + 2 or tr.h
        if not tr.rest then fixed = fixed + tr.full end
    end
    for i = 1, #list do
        local tr = list[i]
        if tr.rest and not Folded(tr.key) then tr.full = max(LIFE_MIN, view - fixed) end
    end
    local total = TOPPAD
    for i = 1, #list do total = total + list[i].full end
    local scroll = max(0, min(c.scroll, total - c.canvas:GetHeight()))
    local y = TOPPAD - scroll
    for i = 1, #list do
        local tr = list[i]
        if Visible(c, y, tr.full) then
            if i % 2 == 0 then
                local bg = c.GetBar()
                ns.Kit.Shade(bg, "surface.zebra")
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.gutter, -y)
                bg:SetWidth(c.canvas:GetWidth() - c.gutter)
                bg:SetHeight(tr.full)
            end
            local sep = c.GetBar()
            ns.Kit.Shade(sep, "surface.grid")
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", 0, -y)
            sep:SetWidth(c.canvas:GetWidth())
            sep:SetHeight(1)
        end
        Label(c, tr.key, tr.label, y)
        if not Folded(tr.key) then
            local key = tr.key
            if key == "faults" then
                if c.player then DrawFaults(c, y, tr.full) end
            elseif key == "boss" then
                last.boss = { y = y, h = tr.full }
                if Visible(c, y, tr.full) then c.DrawPoints(data.boss, { y = y, h = tr.full }, "sem.lane.boss") end
            elseif key == "acts" then
                if Visible(c, y, tr.full) then c.DrawPoints(acts, { y = y, h = tr.full }, "sem.lane.casts") end
            elseif key == "states" then
                DrawStates(c, stateRows, y + LABELH + 1)
            elseif key == "life" then
                last.life = DrawLife(c, y, tr.full)
            elseif key == "feed" and c.player then
                if Visible(c, y, tr.full) then DrawFeed(c, y + 2) end
            end
        end
        y = y + tr.full
    end
    local edge = c.GetBar()
    ns.Kit.Shade(edge, "surface.edge")
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.gutter - 1, 0)
    edge:SetWidth(1)
    edge:SetHeight(c.canvas:GetHeight())
    return total, scroll
end
local function LastBefore(items, t)
    local found = nil
    for i = 1, items and #items or 0 do
        if items[i].t <= t then found = items[i] else break end
    end
    return found
end
local function SumIn(items, t0, t1, heal)
    local sum = 0
    for i = 1, items and #items or 0 do
        local it = items[i]
        if it.t > t1 then break end
        if it.t >= t0 and not it.miss then
            sum = sum + (heal and max(0, (it.amount or 0) - (it.over or 0) + (it.absorbed or 0)) or (it.amount or 0))
        end
    end
    return sum
end
function B.Readouts(t, readouts, dot)
    for i = 1, #readouts do readouts[i]:Hide() end
    dot:Hide()
    local L = last
    local c = L and L.ctx
    if not (c and c.data) then return end
    local x = c.XOf(t)
    local flip = (c.canvas:GetWidth() - x) < 130
    local text, at = {}, {}
    local life = L.life
    if life then
        local h = LastBefore(c.data.hp, t)
        local m = LastBefore(c.data.mana, t)
        if h then
            local s = h.hp and format(ns.T("tb.read.hp"), floor(h.pct * 100 + 0.5), Short(h.hp))
                or format("%d%%", floor(h.pct * 100 + 0.5))
            if m then s = s .. "  " .. format(ns.T("tb.read.mana"), floor(m.pct * 100 + 0.5)) end
            text[#text + 1], at[#at + 1] = s, life.y + 2
            dot:SetWidth(DOT)
            dot:SetHeight(DOT)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", c.overlay, "TOPLEFT", x, -(life.y + life.hpH - h.pct * life.hpH))
            dot:Show()
        end
        local up = SumIn(c.data.healed, t - 1, t, true)
        local down = SumIn(c.data.taken, t - 1, t, false)
        if up > 0 or down > 0 then
            text[#text + 1] = format(ns.T("tb.read.flow"), Short(up), Short(down))
            at[#at + 1] = life.flowTop + 1
        end
    end
    if L.boss then
        local b = LastBefore(c.data.boss, t)
        if b then text[#text + 1], at[#at + 1] = b.label, L.boss.y + 2 end
    end
    for i = 1, min(#text, #readouts) do
        local fs = readouts[i]
        fs:ClearAllPoints()
        if flip then
            fs:SetPoint("TOPRIGHT", c.overlay, "TOPLEFT", x - 4, -at[i])
            fs:SetJustifyH("RIGHT")
        else
            fs:SetPoint("TOPLEFT", c.overlay, "TOPLEFT", x + 4, -at[i])
            fs:SetJustifyH("LEFT")
        end
        fs:SetText(text[i])
        fs:Show()
    end
end
function B.Hide()
    if holder then holder:Hide() end
    last = nil
end
