local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local BLOCK_ROWS = 10
local TARGET_COLS = 3
local TARGET_KINDS = { damageTo = true, usefulTo = true, targets = true }
local Rows = {}
ns.MiniRows = Rows
local function Short(n)
    return ns.BadgeTips.Short(n)
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
Rows.Clock = Clock
local function ClassOf(who, s)
    local known = s and s.byName and s.byName[who]
    return (ns.Encounters and ns.Encounters.ClassOf(who)) or (known and known.class) or nil
end
local function Note(out, text, tone)
    out[#out + 1] = { kind = "note", left = text, tone = tone or "text.note" }
end
local function ByValue(list)
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.who < b.who
    end)
end
local function DpsRows(out, list, sec, total)
    ByValue(list)
    local top = list[1] and list[1].v or 1
    for i = 1, #list do
        local e = list[i]
        out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = e.class,
            val = format("%s  %s", Short(e.v), Short(e.v / sec)),
            pct = format("%d%%", floor(e.v * 100 / max(1, total) + 0.5)),
            fill = e.v / max(1, top), who = e.who, tip = e.p and ns.BadgeTips.Player or nil, a = e.p, b = e.s }
    end
end
function Rows.Live(out, classOf)
    local M = ns.Meter
    local sec = max(1, M.FightTime())
    local list, total = {}, 0
    for who, v in pairs(M.who) do
        if v > 0 then
            list[#list + 1] = { who = who, v = v, class = classOf(who) }
            total = total + v
        end
    end
    DpsRows(out, list, sec, total)
    return sec, total / sec
end
function Rows.Dps(out, s)
    local sec = max(1, ns.Totals.Time(s))
    local list, total = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        if (p.dmg or 0) > 0 then
            list[#list + 1] = { who = p.name, v = p.dmg, class = p.class or ClassOf(p.name, s), p = p, s = s }
            total = total + p.dmg
        end
    end
    DpsRows(out, list, sec, total)
    return s.dmg / sec
end
local function Columns(b, view)
    local keep = {}
    for c = b.def.lead and 2 or 1, #view.cols - 1 do
        local sum = 0
        for i = 1, #view.rows do sum = sum + (view.rows[i].vals[c] or 0) end
        if sum > 0 and #keep < TARGET_COLS then keep[#keep + 1] = c end
    end
    return keep
end
local function Pick(list, keep)
    local out = {}
    for i = 1, #keep do out[i] = list[keep[i]] end
    return concat(out, " / ")
end
local function TargetRows(b, s, out)
    local view = ns.Targets and ns.Targets.View(b, function(who) return ClassOf(who, s) end)
    local label = ns.T(b.label or b.def.label)
    local head = { kind = "head", left = label, val = Short(max(0, b.total)) }
    out[#out + 1] = head
    local list = {}
    for who, v in pairs(b.by) do
        if v > 0 then list[#list + 1] = { who = who, v = v } end
    end
    ByValue(list)
    local cells, keep = {}, view and Columns(b, view) or {}
    if view then
        if #keep > 0 then head.val = Pick(view.cols, keep) .. "  " .. head.val end
        for i = 1, #view.rows do cells[view.rows[i].who] = view.rows[i] end
    end
    local top = list[1] and list[1].v or 1
    local shown = min(BLOCK_ROWS, #list)
    for i = 1, shown do
        local e = list[i]
        local class = ClassOf(e.who, s)
        local r = cells[e.who]
        local val = Short(e.v)
        if r and #keep > 0 then val = Pick(r.cells, keep) end
        out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = class, val = val,
            pct = format("%d%%", floor(e.v * 100 / max(1, b.total) + 0.5)), fill = e.v / max(1, top),
            lines = r and r.lines or nil, tip = not r and ns.BadgeTips.Row or nil, a = b, b = e.who, c = e.v,
            d = class }
    end
    if #list > shown then Note(out, format(ns.T("mini.more"), #list - shown)) end
    if #list == 0 then Note(out, ns.T("sum.k.none")) end
end
function Rows.Targets(out, f, s)
    local n = 0
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        local hidden = ns.SumHide and ns.SumHide.Hidden(f.boss, b.def)
        if TARGET_KINDS[b.def.kind] and b.by and not hidden then
            n = n + 1
            TargetRows(b, s, out)
        end
    end
    if n == 0 then Note(out, ns.T("mini.notargets")) end
end
local function Killer(d)
    local k = d.killer
    if not k then return ns.T("sum.tt.nokiller") end
    local what = k.spell == "#melee" and ns.T("tl.swing") or tostring(k.spell)
    if k.src then what = format(ns.T("sum.tt.killedby"), what, k.src) end
    return what
end
local GRADE = { red = "text.bad", yellow = "text.warn", green = "text.good" }
local function Deaths(out, f, s)
    local list, tail = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            if d.tail then
                tail = tail + 1
            else
                list[#list + 1] = { p = p, d = d }
            end
        end
    end
    tsort(list, function(a, b) return a.d.t < b.d.t end)
    for i = 1, #list do
        local p, d = list[i].p, list[i].d
        out[#out + 1] = { kind = "row", lead = Clock(max(0, d.t - f.from)), left = p.name, class = p.class,
            val = Killer(d), valTone = GRADE[d.grade or ""] or "text.secondary", tip = ns.BadgeTips.Death, a = p, b = f,
            who = p.name, t = d.t }
    end
    if tail > 0 then Note(out, format(ns.T("mini.tail"), tail)) end
end
local function Faults(item)
    local order, by, first = {}, {}, nil
    local yellow = true
    for e = 1, #item.events do
        local ev = item.events[e]
        if not by[ev.short] then
            by[ev.short] = 0
            order[#order + 1] = ev.short
        end
        by[ev.short] = by[ev.short] + 1
        if ev.t and (not first or ev.t < first) then first = ev.t end
        if ev.grade ~= "yellow" then yellow = false end
    end
    for i = 1, #order do
        local n = by[order[i]]
        order[i] = n > 1 and format("%s x%d", order[i], n) or order[i]
    end
    return concat(order, ", "), first, yellow
end
local function FaultTip(f, item)
    local lines = {}
    for h = 1, #item.hits do
        local hl = ns.GPList.HitLines(f, item.hits[h])
        for k = 1, #hl do lines[#lines + 1] = hl[k] end
    end
    return lines
end
function Rows.Important(out, f, s, model)
    local start = #out
    local cause = ns.DeathDeps and ns.DeathDeps.FirstCause(s, f, model and model.pens or nil)
    if cause then
        out[#out + 1] = { kind = "row", lead = Clock(max(0, cause.t - f.from)), left = cause.who,
            class = ClassOf(cause.who, s), val = cause.text, valTone = "text.bad", who = cause.who, t = cause.t,
            lines = { { kind = "head", left = ns.T("mini.first") },
                      { kind = "text", left = format(ns.T("sum.dd.first"), cause.text, cause.who,
                          Clock(max(0, cause.t - f.from))) } } }
    end
    Deaths(out, f, s)
    local items = model and model.items or {}
    for i = 1, #items do
        local item = items[i]
        if #item.events > 0 then
            local text, t, yellow = Faults(item)
            out[#out + 1] = { kind = "row", lead = t and Clock(max(0, t - f.from)) or "", left = item.name,
                class = item.class, val = text, valTone = yellow and "text.warn" or "text.bad",
                tip = FaultTip, a = f, b = item, who = item.name, t = t }
        end
    end
    if #out == start then Note(out, ns.T("mini.noinfo"), "text.good") end
end
