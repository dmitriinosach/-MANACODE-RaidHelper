local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local TOPPAD = 6
local LABELH = 14
local FAULT_ICON = 18
local UNTIMED_MAX = 4
local FEED_ROW = 18
local FEED_ROWS = 2
local FEED_ICON = 14
local FEED_GAP = 6
local FEED_MAXW = 200
local FEED_TEXT_MIN = 44
local LIFE_H = 112
local FLOW_H = 72
local STATE_ROW = 18
local STATE_PAD = 3
local DEF_ROW = 18
local HELP_H = 28
local BIN = 3
local BINS_MAX = 400
local HEALERS_MAX = 3
local BIG_SHARE = 0.2
local BIG_MAX = 60
local MANA_LINE = 2
local DOT = 6
local CHIP_PAD = 8
local B = {}
ns.TimelineBrief = B
local function Fit()
    local m = ns.Kit.Grow()
    LABELH, STATE_ROW, DEF_ROW, FEED_ROW = 14 + m.g, 18 + m.g, 18 + m.g, 18 + m.g
    FEED_ICON = 14 + m.g
    FEED_MAXW, FEED_TEXT_MIN = floor(200 * m.k + 0.5), floor(44 * m.k + 0.5)
    LIFE_H, FLOW_H, HELP_H = 112 + 2 * m.g, 72 + 3 * m.g, 28 + m.g
end
local DMG_TOKEN = { boss = "sem.death", add = "sem.dmg", env = "badge.yellow", own = "sem.offline" }
local DMG_ORDER = { "boss", "add", "env", "own" }
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
function B.Window(data, lead, tail)
    return ns.TimelineBriefData.Window(data, lead, tail)
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
local Short = ns.Short
local LastBefore = ns.TimelineCursor.LastBefore
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
    return w, b
end
local function ClassShade(tex, src, a, fallback)
    local cls = src and ns.Encounters.ClassOf and ns.Encounters.ClassOf(src)
    ns.Kit.Shade(tex, fallback, a)
    if cls then
        local r, g, b = ns.Kit.ClassColor(cls)
        tex:SetTexture(r, g, b, a)
    end
end
local function Holder(c)
    if not holder then
        holder = CreateFrame("Frame", nil, c.canvas)
        holder.sized = true
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
local function DrawFaults(c, y, top, hh)
    local list = ns.TimelineBriefData.Faults(c.fight, c.player, c.redraw)
    local noteY = y + LABELH + 2
    if not list then
        Note(c, ns.T("tb.faults.wait"), 10, noteY)
        return
    end
    if #list == 0 then
        Note(c, ns.T("tb.faults.none"), 10, noteY, "badge.green")
        return
    end
    if not Visible(c, top, hh) then return end
    Holder(c)
    local used, whole = 0, 0
    local lastX = -1e9
    local right = c.canvas:GetWidth() - FAULT_ICON - 2
    local hp = c.data and c.data.hp
    for i = 1, #list do
        local f = list[i]
        if not f.t then
            if whole < UNTIMED_MAX then
                whole = whole + 1
                used = used + 1
                PlaceMark(c, Mark(used), f, c.gutter - 4 - whole * (FAULT_ICON + 4), noteY)
            end
        elseif f.t >= c.from and f.t <= c.to then
            local x = max(c.XOf(f.t) - FAULT_ICON / 2, lastX + FAULT_ICON + 3, c.gutter + 1)
            if x <= right then
                local s = LastBefore(hp, f.t)
                local pct = s and s.pct or 1
                local my = top + hh - pct * hh - FAULT_ICON / 2
                my = max(top, min(top + hh - FAULT_ICON, my))
                used = used + 1
                PlaceMark(c, Mark(used), f, x, my)
                lastX = x
            end
        end
    end
end
local function RowHead(c, ry, barH, id, text, tip)
    local gut = c.GetBlock()
    gut:SetHeight(barH)
    gut:ClearAllPoints()
    gut:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", 1 + 8, -(ry + STATE_PAD))
    gut:SetWidth(c.nameW - 8)
    ns.Kit.Shade(gut.tex, "surface.alt")
    local icon = ns.Effects.IconById(id)
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
    c.FitText(gut.label, text, c.nameW - 14 - (icon and barH or 0))
    gut.tip, gut.spellId, gut.jumpTo = tip, id, nil
    return gut, icon
end
local function DrawStates(c, rows, y)
    local plotR = c.canvas:GetWidth()
    local barH = STATE_ROW - STATE_PAD * 2
    for r = 1, #rows do
        local row = rows[r]
        local ry = y + (r - 1) * STATE_ROW
        if Visible(c, ry, STATE_ROW) then
            local gut = RowHead(c, ry, barH, row.id, row.label, row.label)
            gut.tip2 = format(ns.T("tl.fx.count"), #row.items)
            local token = row.kind == "ctl" and "badge.red" or "sem.dmg"
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
                        ns.Fixed(to - a.t), a.src and ("  |  " .. a.src) or "")
                end
            end
        end
    end
end
local function HpBar(c, x0, x1, pct, top, hh)
    local w = max(1, x1 - x0)
    local t = c.GetBar()
    if pct <= 0 then
        ns.Kit.Shade(t, "sem.death")
        t:SetHeight(2)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - 2))
        t:SetWidth(w)
        return
    end
    local barH = max(1, pct * hh)
    local token = pct < 0.35 and "sem.hpLow" or "sem.hpOk"
    ns.Kit.Shade(t, token, 0.45)
    t:SetHeight(barH)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - barH))
    t:SetWidth(w)
    local edge = c.GetBar()
    ns.Kit.Shade(edge, token, 1)
    edge:SetHeight(2)
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(top + hh - barH))
    edge:SetWidth(w)
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
local function DrawLife(c, y, h)
    local top = y + LABELH + 3
    local hh = h - LABELH - 7
    local life = { y = top, hpH = hh }
    if not Visible(c, y, h) then return life end
    local data = c.data
    if data then
        DrawLevels(c, data.hp, top, hh, false)
        if data.mana and #data.mana > 0 then
            DrawLevels(c, data.mana, top, hh, true)
            Note(c, ns.T("tb.mana"), 10, y + LABELH * 2 + 4, "sem.stat.hps")
        end
    end
    if c.player then DrawFaults(c, y, top, hh) end
    return life
end
local function MaxHp(c)
    local hp = c.data and c.data.hp
    local top = 0
    for i = 1, hp and #hp or 0 do
        local s = hp[i]
        local m = s.max or (s.pct and s.pct > 0 and s.hp and s.hp / s.pct)
        if m and m > top then top = m end
    end
    return top > 0 and top or nil
end
local function BigHit(c, x, mid, half, it)
    local t = c.GetBar()
    ns.Kit.Shade(t, "sem.death", 1)
    t:SetWidth(2)
    t:SetHeight(half - 1)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(mid + 1))
    local b = c.GetBlock()
    b:SetWidth(6)
    b:SetHeight(half - 1)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x - 2, -(mid + 1))
    ns.Kit.Shade(b.tex, "surface.clear")
    b.icon:Hide()
    b.label:SetText("")
    b.tip, b.at, b.spellId = it.label, it.t, tonumber(it.id)
    b.jumpTo = nil
    b.tip2 = format("%s  |  %s%s", c.Clock(it.t - c.fight.from), it.src and (it.src .. ": ") or "",
        Short(it.amount or 0))
    b.tip3 = ns.T("tb.flow.big")
end
local function SortDesc(names, sums, cnt)
    for a = 2, cnt do
        local sn, sv = names[a], sums[a]
        local b = a - 1
        while b >= 1 and sums[b] < sv do
            names[b + 1], sums[b + 1] = names[b], sums[b]
            b = b - 1
        end
        names[b + 1], sums[b + 1] = sn, sv
    end
end
local function HealBar(c, x, w, mid, total, up, by, names, sums)
    local cnt = 0
    for src, v in pairs(by) do
        cnt = cnt + 1
        names[cnt], sums[cnt] = src, v
    end
    SortDesc(names, sums, cnt)
    local yy = mid
    local shown = min(cnt, HEALERS_MAX)
    for a = 1, shown do
        local rest = a == shown and cnt > shown
        local v = sums[a]
        if rest then
            v = 0
            for r = shown, cnt do v = v + sums[r] end
        end
        local bh = total * v / up
        if bh >= 1 then
            local t = c.GetBar()
            if rest then
                ns.Kit.Shade(t, "sem.heal", 0.6)
            else
                ClassShade(t, names[a], 0.95, "sem.heal")
            end
            t:SetWidth(w)
            t:SetHeight(bh)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(yy - bh))
            yy = yy - bh
        end
    end
end
local function DmgBar(c, x, w, mid, total, sum, d)
    local yy = mid + 1
    for o = 1, #DMG_ORDER do
        local kind = DMG_ORDER[o]
        local v = d[kind]
        if v and v > 0 then
            local bh = total * v / sum
            if bh >= 1 then
                local t = c.GetBar()
                ns.Kit.Shade(t, DMG_TOKEN[kind], 0.95)
                t:SetWidth(w)
                t:SetHeight(bh)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -yy)
                yy = yy + bh
            end
        end
    end
end
local function DrawFlow(c, y, h)
    local top = y + 3
    local hh = h - 6
    local half = floor(hh / 2)
    local mid = top + half
    local flow = { top = top, h = hh, mid = mid }
    if not Visible(c, y, h) then return flow end
    local ly = y + LABELH + 2
    Note(c, ns.T("tb.flow.heal"), 10, ly, "sem.heal")
    local lx = 10 + Note(c, ns.T("tb.flow.dmg"), 10, ly + LABELH)
    for k = 1, #DMG_ORDER do
        local kind = DMG_ORDER[k]
        lx = lx + Note(c, ns.T("tb.flow." .. kind), lx, ly + LABELH, DMG_TOKEN[kind]) + 2
    end
    local data = c.data
    if not data then return flow end
    local plot = c.canvas:GetWidth() - c.gutter
    local bin = max(BIN, plot / BINS_MAX)
    local n = floor(plot / bin) + 1
    local heal, healBy, dmg = {}, {}, {}
    local players = c.fight.players
    local BD = ns.TimelineBriefData
    local healed, taken = data.healed or {}, data.taken or {}
    for i = 1, #healed do
        local it = healed[i]
        if it.t >= c.from and it.t <= c.to then
            local k = floor((c.XOf(it.t) - c.gutter) / bin) + 1
            local v = (it.amount or 0) - (it.over or 0) + (it.absorbed or 0)
            if v > 0 then
                heal[k] = (heal[k] or 0) + v
                local by = healBy[k]
                if not by then
                    by = {}
                    healBy[k] = by
                end
                local src = it.src or ""
                by[src] = (by[src] or 0) + v
            end
        end
    end
    local bigHp = MaxHp(c)
    local big, bigN = {}, 0
    for i = 1, #taken do
        local it = taken[i]
        if not it.miss and it.t >= c.from and it.t <= c.to then
            local k = floor((c.XOf(it.t) - c.gutter) / bin) + 1
            local d = dmg[k]
            if not d then
                d = { sum = 0 }
                dmg[k] = d
            end
            local kind = BD.SourceKind(it, players)
            local v = it.amount or 0
            d[kind] = (d[kind] or 0) + v
            d.sum = d.sum + v
            if bigHp and bigN < BIG_MAX and v >= bigHp * BIG_SHARE then
                bigN = bigN + 1
                big[bigN] = it
            end
        end
    end
    local peak = 1
    for k = 1, n do
        local up = heal[k] or 0
        if up > peak then peak = up end
        local d = dmg[k]
        if d and d.sum > peak then peak = d.sum end
    end
    local axis = c.GetBar()
    ns.Kit.Shade(axis, "surface.grid")
    axis:ClearAllPoints()
    axis:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.gutter, -mid)
    axis:SetWidth(plot)
    axis:SetHeight(1)
    local w = max(1, bin - 1)
    local names, sums = {}, {}
    for k = 1, n do
        local x = c.gutter + (k - 1) * bin
        local up = heal[k]
        if up then
            HealBar(c, x, w, mid, max(1, sqrt(up / peak) * (half - 1)), up, healBy[k], names, sums)
        end
        local d = dmg[k]
        if d and d.sum > 0 then
            DmgBar(c, x, w, mid, max(1, sqrt(d.sum / peak) * (half - 1)), d.sum, d)
        end
    end
    for i = 1, bigN do
        local it = big[i]
        BigHit(c, floor(c.XOf(it.t)), mid, half, it)
    end
    return flow
end
local function DrawDefs(c, lanes, y)
    local BD = ns.TimelineBriefData
    local plotR = c.canvas:GetWidth()
    local deaths = c.data and c.data.deaths or {}
    local barH = DEF_ROW - STATE_PAD * 2
    local first = deaths[1]
    for r = 1, #lanes do
        local lane = lanes[r]
        local ry = y + (r - 1) * DEF_ROW
        if Visible(c, ry, DEF_ROW) then
            local left = first and BD.LaneLeft(lane, first) or nil
            local text = lane.label
            if left then text = text .. ns.T(left <= 0 and "tb.def.readyMark" or "tb.def.cdMark") end
            local gut, icon = RowHead(c, ry, barH, lane.id, text, lane.label)
            if left and left <= 0 then ns.Kit.Tone(gut.label, "badge.red") end
            gut.tip2 = format(ns.T("tb.def.cd"), lane.cd, #lane.casts)
            if left then
                gut.tip3 = left <= 0 and ns.T("tb.def.ready") or format(ns.T("tb.def.left"), floor(left + 0.5))
            end
            for i = 1, #lane.casts do
                local at = lane.casts[i]
                local to = at + lane.cd
                if to >= c.from and at <= c.to then
                    local x0 = c.XOf(max(at, c.from))
                    local x1 = min(c.XOf(min(to, c.to)), plotR)
                    local t = c.GetBar()
                    ns.Kit.Shade(t, "sem.notReady", 0.22)
                    t:SetWidth(max(1, x1 - x0))
                    t:SetHeight(barH)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x0, -(ry + STATE_PAD))
                end
                if at >= c.from and at <= c.to then
                    local b = c.GetBlock()
                    b:SetWidth(barH)
                    b:SetHeight(barH)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.XOf(at), -(ry + STATE_PAD))
                    ns.Kit.Shade(b.tex, "surface.clear")
                    b.icon:SetWidth(barH)
                    b.icon:SetHeight(barH)
                    if icon then
                        b.icon:SetTexture(icon)
                        b.icon:Show()
                    else
                        b.icon:Hide()
                    end
                    b.label:SetText("")
                    b.tip, b.at, b.spellId, b.jumpTo = lane.label, at, lane.id, nil
                    b.tip2 = c.Clock(at - c.fight.from)
                end
            end
            for k = 1, #deaths do
                local d = deaths[k]
                if d >= c.from and d <= c.to and BD.LaneLeft(lane, d) <= 0 then
                    local t = c.GetBar()
                    ns.Kit.Shade(t, "badge.red", 0.95)
                    t:SetWidth(3)
                    t:SetHeight(barH)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", c.XOf(d) - 1, -(ry + STATE_PAD))
                end
            end
        end
    end
end
local function DrawHelp(c, items, y, h)
    if not Visible(c, y, h) then return end
    local size = h - 8
    local top = y + 4
    local lastX, shown = -100, 0
    for i = 1, #items do
        local it = items[i]
        if it.t >= c.from and it.t <= c.to then
            local x = c.XOf(it.t)
            local nx = lastX + size + 2
            if nx > x and nx - x <= size then x = nx end
            if x - lastX >= size + 2 and shown < 150 then
                shown = shown + 1
                local b = c.GetBlock()
                b:SetWidth(size)
                b:SetHeight(size)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -top)
                ns.Kit.Shade(b.tex, "surface.clear")
                b.icon:SetWidth(size)
                b.icon:SetHeight(size)
                ns.Kit.Icon.Spell(b.icon, tonumber(it.id))
                b.icon:Show()
                b.label:SetText("")
                b.tip, b.at, b.spellId = it.label, it.t, tonumber(it.id)
                b.jumpTo = it.got and it.src or nil
                b.tip2 = c.Clock(it.t - c.fight.from)
                if it.got then
                    b.tip3 = format(ns.T("tb.help.from"), it.src)
                    local u = c.GetBar()
                    ClassShade(u, it.src, 1, "sem.heal")
                    u:SetWidth(size)
                    u:SetHeight(2)
                    u:ClearAllPoints()
                    u:SetPoint("TOPLEFT", c.canvas, "TOPLEFT", x, -(top + size + 1))
                elseif it.taunt then
                    b.tip3 = ns.T("tb.help.taunt")
                end
                lastX = x
            end
        end
    end
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
local function ZoomClick(b)
    if ns.Timeline and ns.Timeline.SetView then ns.Timeline.SetView(b.zoomFrom, b.zoomTo) end
end
local function ZoomChip(c, y)
    if not (ns.Timeline and ns.Timeline.View and c.data) then return end
    local _, _, _, _, lead, tail = ns.Timeline.View()
    local full = c.from <= lead + 0.5 and c.to >= tail - 0.5
    local text, f0, f1
    if not full then
        text, f0, f1 = ns.T("tb.zoom.all"), lead, tail
    else
        f0, f1 = B.Window(c.data, lead, tail)
        if not f0 then return end
        text = ns.T("tb.zoom.death")
    end
    local w, b = Note(c, text, 0, y + 2, "text.bright")
    ns.Kit.Shade(b.tex, "surface.laneHead")
    b:SetWidth(w + CHIP_PAD)
    b.label:SetPoint("LEFT", CHIP_PAD / 2, 0)
    b.castLabel = true
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", c.canvas, "TOPRIGHT", -4, -(y + 2))
    b.tip, b.tip2 = text, ns.T("tb.zoom.tip")
    b.zoomFrom, b.zoomTo = f0, f1
    b.onClick = ZoomClick
end
local function DrawFeed(c, y)
    local f = ns.TimelineBriefData.Feed(c.fight, c.redraw)
    if not f then
        Note(c, ns.T("tb.feed.wait"), c.gutter + 6, y + 2)
        return
    end
    local rows = ns.TimelineBriefData.FeedFor(f, c.player)
    local right = c.canvas:GetWidth() - 2
    local from = c.fight.from
    local ids, xs, n = {}, {}, 0
    for k = 1, #rows do
        local i = rows[k]
        local t = from + f.t[i]
        if t >= c.from and t <= c.to then
            n = n + 1
            ids[n], xs[n] = i, c.XOf(t)
        end
    end
    local ends = {}
    for r = 1, FEED_ROWS do ends[r] = -1e9 end
    for k = 1, n do
        local i, x = ids[k], xs[k]
        local lane
        for r = 1, FEED_ROWS do
            if x >= ends[r] + FEED_GAP then
                lane = r
                break
            end
        end
        if lane and x < right - FEED_ICON then
            local ry = y + (lane - 1) * FEED_ROW
            local nextX = xs[k + 1] or right
            local room = min(FEED_MAXW, nextX - x - FEED_ICON - 8, right - x - FEED_ICON - 6)
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
            local w
            if room >= FEED_TEXT_MIN then
                c.FitText(b.label, f.text[i], room)
                b.label:SetWidth(0)
                w = min(room, b.label:GetStringWidth() or 0) + FEED_ICON + 6
                b.label:SetWidth(w - FEED_ICON - 6)
            else
                b.label:SetText("")
                b.label:SetWidth(1)
                w = FEED_ICON + 2
            end
            b:SetWidth(w)
            ends[lane] = x + w
            b.tip, b.at, b.jumpTo = f.text[i], from + f.t[i], nil
            b.spellId = tonumber(f.icon[i])
            b.tip2 = c.Clock(f.t[i])
            b.tip3 = f.tip[i] ~= f.text[i] and f.tip[i] or nil
        end
    end
end
local function Tracks(c, stateRows, lanes, help)
    local list = {}
    if c.player then list[#list + 1] = { key = "feed", label = ns.T("tb.feed"), h = FEED_ROW * FEED_ROWS + 4 } end
    list[#list + 1] = { key = "life", label = ns.T("tb.life"), h = LIFE_H }
    if c.data then list[#list + 1] = { key = "flow", label = ns.T("tb.flow"), h = FLOW_H } end
    if #stateRows > 0 then
        list[#list + 1] = { key = "states", label = ns.T("tb.foes"), h = LABELH + #stateRows * STATE_ROW + 2 }
    end
    if #lanes > 0 then
        list[#list + 1] = { key = "defs", label = ns.T("tb.defs"), h = LABELH + #lanes * DEF_ROW + 2 }
    end
    if #help > 0 then list[#list + 1] = { key = "help", label = ns.T("tb.help"), h = HELP_H } end
    return list
end
function B.Draw(c)
    Fit()
    if holder then holder:Hide() end
    for i = 1, #marks do marks[i]:Hide() end
    last = { ctx = c }
    local data = c.data
    local BD = ns.TimelineBriefData
    local stateRows = data and BD.States(data, c.fight) or {}
    local lanes = data and c.player and BD.Defs(data, c.player) or {}
    local help = data and c.player and BD.Help(data, c.fight, c.player) or {}
    local list = Tracks(c, stateRows, lanes, help)
    local total = TOPPAD
    for i = 1, #list do
        local tr = list[i]
        tr.full = Folded(tr.key) and LABELH + 2 or tr.h
        total = total + tr.full
    end
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
            if key == "feed" then
                if Visible(c, y, tr.full) then
                    DrawFeed(c, y + 2)
                    ZoomChip(c, y)
                end
            elseif key == "life" then
                last.life = DrawLife(c, y, tr.full)
            elseif key == "flow" then
                last.flow = DrawFlow(c, y, tr.full)
            elseif key == "states" then
                DrawStates(c, stateRows, y + LABELH + 1)
            elseif key == "defs" then
                DrawDefs(c, lanes, y + LABELH + 1)
            elseif key == "help" then
                DrawHelp(c, help, y, tr.full)
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
local function SumIn(items, t0, t1, heal)
    local sum = 0
    local by, best, bestV = {}, nil, 0
    for i = 1, items and #items or 0 do
        local it = items[i]
        if it.t > t1 then break end
        if it.t >= t0 and not it.miss then
            local v = heal and max(0, (it.amount or 0) - (it.over or 0) + (it.absorbed or 0)) or (it.amount or 0)
            sum = sum + v
            if heal then
                local src = it.src or ""
                by[src] = (by[src] or 0) + v
                if by[src] > bestV then best, bestV = src, by[src] end
            elseif v > bestV then
                best, bestV = it.src and (it.src .. ": " .. it.label) or it.label, v
            end
        end
    end
    return sum, best
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
            text[#text + 1], at[#at + 1] = s, life.y
            dot:SetWidth(DOT)
            dot:SetHeight(DOT)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", c.overlay, "TOPLEFT", x, -(life.y + life.hpH - h.pct * life.hpH))
            dot:Show()
        end
    end
    local flow = L.flow
    if flow then
        local up, healer = SumIn(c.data.healed, t - 1, t, true)
        local down, hit = SumIn(c.data.taken, t - 1, t, false)
        if up > 0 or down > 0 then
            text[#text + 1] = format(ns.T("tb.read.flow"), Short(up), Short(down))
            at[#at + 1] = flow.top
            if healer or hit then
                text[#text + 1] = format(ns.T("tb.read.src"), healer or "—", hit or "—")
                at[#at + 1] = flow.top + LABELH
            end
        end
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
