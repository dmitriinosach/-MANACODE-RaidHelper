local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local BLOCK_ROWS = 10
local TARGET_COLS = 3
local TARGET_KINDS = { damageTo = true, usefulTo = true, targets = true, oozes = true }
local COUNT_KINDS = { dispels = true, casts = true, removed = true }
local HIT_KINDS = { taken = true, shades = true }
local Rows = {}
ns.MiniRows = Rows
local Short = ns.Short
local function ClassOf(who, s)
    local known = s and s.byName and s.byName[who]
    return (ns.Encounters and ns.Encounters.ClassOf(who)) or (known and known.class) or nil
end
Rows.ClassOf = ClassOf
local function Note(out, text, tone)
    out[#out + 1] = { kind = "note", left = text, tone = tone or "text.note" }
end
local function ByValue(list)
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.who < b.who
    end)
end
local function RateRows(out, list, sec, total, act)
    ByValue(list)
    local top = list[1] and list[1].v or 1
    for i = 1, #list do
        local e = list[i]
        local rate = ns.Rate(e.v / sec)
        local more = act and ns.Rate((e.all or e.v) / act) or nil
        out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = e.class,
            val = format("%s  %s", Short(e.v), rate), more = more and more ~= rate and format("(%s)", more) or nil,
            pct = format("%d%%", floor(e.v * 100 / max(1, total) + 0.5)),
            fill = e.v / max(1, top), who = e.who, tip = e.tip, a = e.p, b = e.s }
    end
    if #list == 0 then Note(out, ns.T("sum.k.none")) end
end
function Rows.Live(out, classOf, heal)
    local M = ns.Meter
    local sec = max(1, M.FightTime())
    local list, total = {}, 0
    for who, v in pairs(heal and M.heals or M.who) do
        if v > 0 then
            list[#list + 1] = { who = who, v = v, class = classOf(who) }
            total = total + v
        end
    end
    RateRows(out, list, sec, total)
    return sec, total / sec
end
function Rows.Dps(out, s, heal)
    local sec = max(1, ns.Totals.Time(s))
    local act = max(1, ns.Totals.Active(s))
    local list, total = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        local v = heal and (p.heal or 0) or ns.Totals.Good(p)
        if v > 0 then
            list[#list + 1] = { who = p.name, v = v, all = heal and p.heal or p.dmg, class = p.class or ClassOf(p.name, s),
                p = p, s = s, tip = p.raid and ns.BadgeTips.RaidPlayer or ns.BadgeTips.Player }
            total = total + v
        end
    end
    RateRows(out, list, sec, total, act)
    return total / sec
end
function Rows.Raid(fights, peek)
    local sum = { raid = true, dur = 0, combat = 0, players = {}, byName = {}, n = 0, miss = 0, parts = {} }
    for i = 1, #fights do
        local f = fights[i]
        local s = peek(f)
        if s then
            sum.n = sum.n + 1
            sum.dur = sum.dur + ns.Totals.Time(s)
            sum.combat = sum.combat + ns.Totals.Active(s)
            sum.parts[#sum.parts + 1] = { fight = f, s = s }
            for k = 1, #s.players do
                local p = s.players[k]
                local m = sum.byName[p.name]
                if not m then
                    m = { raid = true, name = p.name, class = p.class or ClassOf(p.name, s), dmg = 0, goodDmg = 0, heal = 0,
                          deaths = 0, tries = 0 }
                    sum.byName[p.name] = m
                    sum.players[#sum.players + 1] = m
                end
                m.dmg = m.dmg + (p.dmg or 0)
                m.goodDmg = m.goodDmg + ns.Totals.Good(p)
                m.heal = m.heal + (p.heal or 0)
                m.deaths = m.deaths + (p.deaths or 0)
                m.tries = m.tries + 1
            end
        else
            sum.miss = sum.miss + 1
        end
    end
    tsort(sum.parts, function(a, b)
        if a.fight.from ~= b.fight.from then return a.fight.from > b.fight.from end
        return tostring(a.fight.boss) < tostring(b.fight.boss)
    end)
    return sum
end
local GRADE_TONE = { red = "text.bad", yellow = "text.warn", green = "text.good" }
local function DeathList(s)
    local list = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #(p.deathInfo or {}) do list[#list + 1] = { p = p, d = p.deathInfo[k] } end
    end
    tsort(list, function(a, b)
        if a.d.t ~= b.d.t then return a.d.t < b.d.t end
        return a.p.name < b.p.name
    end)
    return list
end
local function DeathRows(out, f, s, list)
    local tail = 0
    for i = 1, #list do
        local p, d = list[i].p, list[i].d
        local k = d.killer
        local what = ns.T("sum.tt.nokiller")
        if k then what = k.spell == "#melee" and ns.T("tl.swing") or tostring(k.spell) end
        if d.tail then tail = tail + 1 end
        local tone = d.tail and "text.note" or GRADE_TONE[d.grade or ""]
        out[#out + 1] = { kind = "row", lead = ns.Clock(max(0, d.t - f.from)), left = p.name,
            class = p.class or ClassOf(p.name, s), val = what, valTone = tone,
            pct = k and (k.amount or 0) > 0 and Short(k.amount) or "", pctTone = tone,
            who = p.name, at = d.t, fight = f, tip = ns.BadgeTips.DeathLog, a = p, b = d, c = f }
    end
    return tail
end
local function DeathSub(n, tail)
    if tail > 0 then return format(ns.T("mini.deaths.tail"), n - tail, tail) end
    return tostring(n)
end
function Rows.Deaths(out, f, s)
    local list = DeathList(s)
    local tail = DeathRows(out, f, s, list)
    if #list == 0 then Note(out, ns.T("mini.nodeaths"), "text.good") end
    return DeathSub(#list, tail)
end
function Rows.RaidDeaths(out, sum, title)
    local n, tail = 0, 0
    for i = 1, #sum.parts do
        local f, s = sum.parts[i].fight, sum.parts[i].s
        local list = DeathList(s)
        if #list > 0 then
            out[#out + 1] = { kind = "head", left = title(f), val = tostring(#list), fight = f }
            n = n + #list
            tail = tail + DeathRows(out, f, s, list)
        end
    end
    if n == 0 then Note(out, ns.T("mini.nodeaths"), "text.good") end
    return DeathSub(n, tail)
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
local function Value(b, who, v)
    local kind = b.def.kind
    if COUNT_KINDS[kind] then return tostring(v) end
    if (HIT_KINDS[kind] or b.def.soak) and b.hits then return format("%s x%d", Short(v), b.hits[who] or 0) end
    return Short(v)
end
function Rows.Cells(b, s)
    local view = TARGET_KINDS[b.def.kind] and ns.Targets and ns.Targets.View(b, function(who) return ClassOf(who, s) end)
    local cells, keep = {}, view and Columns(b, view) or {}
    if not view then return nil, cells, keep end
    for i = 1, #view.rows do cells[view.rows[i].who] = view.rows[i] end
    return #keep > 0 and Pick(view.cols, keep) or nil, cells, keep
end
function Rows.ByWho(b)
    local list = {}
    for who, v in pairs(b.by) do
        if v > 0 then list[#list + 1] = { who = who, v = v } end
    end
    ByValue(list)
    return list
end
function Rows.Pick(r, keep)
    return Pick(r.cells, keep)
end
local function BlockRows(b, s, out)
    local label = ns.T(b.label or b.def.label)
    local count = COUNT_KINDS[b.def.kind]
    local head = { kind = "head", left = label, val = count and tostring(b.total) or Short(max(0, b.total)) }
    out[#out + 1] = head
    local list = Rows.ByWho(b)
    local cols, cells, keep = Rows.Cells(b, s)
    if cols then head.val = cols .. "  " .. head.val end
    local chat = {}
    head.chat = { title = cols and format("%s (%s)", label, cols) or label, rows = chat }
    local top = list[1] and list[1].v or 1
    local shown = min(BLOCK_ROWS, #list)
    for i = 1, #list do
        local e = list[i]
        local r = cells[e.who]
        local val = Value(b, e.who, e.v)
        if r and #keep > 0 then val = Pick(r.cells, keep) end
        local pct = format("%d%%", floor(e.v * 100 / max(1, b.total) + 0.5))
        chat[i] = { who = e.who, val = val, rest = { pct } }
        if i <= shown then
            local class = ClassOf(e.who, s)
            out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = class, val = val, pct = pct,
                fill = e.v / max(1, top), lines = r and r.lines or nil, tip = not r and ns.BadgeTips.Row or nil, a = b,
                b = e.who, c = e.v, d = class, who = e.who }
        end
    end
    if #list > shown then Note(out, format(ns.T("mini.more"), #list - shown)) end
    if #list == 0 then Note(out, ns.T("sum.k.none")) end
end
local function SpellKey(id)
    return ns.SpellKey and ns.SpellKey(id) or id
end
local function NpcKey(id)
    return ns.NpcKeyOf and ns.NpcKeyOf(id) or id
end
local function RuleKeys(f)
    local spells, npcs = {}, {}
    local rules = ns.Penalties and ns.Penalties.Rules(f.boss, ns.Penalties.DiffOf(f)) or {}
    for i = 1, #rules do
        local r = rules[i]
        ns.SpellSet(r.spells, spells)
        ns.NpcSet(r.targets, npcs)
        ns.NpcSet(r.srcs, npcs)
        if r.npc then npcs[NpcKey(tonumber(r.npc) or r.npc)] = true end
    end
    return spells, npcs
end
local function Linked(def, spells, npcs)
    local list = def.spells or {}
    for i = 1, #list do
        if spells[SpellKey(list[i])] then return true end
    end
    if def.spell and spells[SpellKey(def.spell)] then return true end
    list = def.names or {}
    for i = 1, #list do
        if npcs[NpcKey(list[i])] then return true end
    end
    return def.npc ~= nil and npcs[NpcKey(def.npc)] == true
end
local function Peaks(st)
    local peak, above = 0, 0
    local eps = st and st.eps or {}
    for k = 1, #eps do
        local pk = eps[k].pk or 0
        if pk > peak then peak = pk end
        if st.over and pk > st.over then above = above + 1 end
    end
    return peak, above
end
local function OverOf(s, i)
    if s.badges[i].kind ~= "stack" then return nil end
    for k = 1, #s.players do
        local st = s.players[k].badges and s.players[k].badges[i]
        if st and st.over then return st.over end
    end
    return nil
end
function Rows.Over(s, i)
    local list = {}
    for k = 1, #s.players do
        local p = s.players[k]
        local st = p.badges and p.badges[i]
        local peak, above = Peaks(st)
        if above > 0 then list[#list + 1] = { who = p.name, v = above, peak = peak, p = p, st = st } end
    end
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        if a.peak ~= b.peak then return a.peak > b.peak end
        return a.who < b.who
    end)
    return list
end
local function StackRows(s, i, over, out)
    local bd = s.badges[i]
    local list = Rows.Over(s, i)
    local title = format(ns.T("mini.over"), ns.T(bd.tip or ""), over)
    local chat = {}
    out[#out + 1] = { kind = "head", left = title, val = tostring(#list), chat = { title = title, rows = chat } }
    local top = list[1] and list[1].v or 1
    for k = 1, #list do
        local e = list[k]
        local val, pct = format(ns.T("mini.peak"), e.peak), format("x%d", e.v)
        chat[k] = { who = e.who, val = val, rest = { pct } }
        if k <= BLOCK_ROWS then
            out[#out + 1] = { kind = "row", lead = tostring(k), left = e.who, class = e.p.class or ClassOf(e.who, s),
                val = val, pct = pct, fill = e.v / max(1, top), tip = ns.StackTips and ns.StackTips.Badge or nil,
                a = e.st, b = bd, who = e.who }
        end
    end
    if #list > BLOCK_ROWS then Note(out, format(ns.T("mini.more"), #list - BLOCK_ROWS)) end
    if #list == 0 then Note(out, ns.T("stk.never"), "text.good") end
end
function Rows.Important(f, s)
    local out = {}
    local spells, npcs = RuleKeys(f)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        local hidden = ns.SumHide and ns.SumHide.Hidden(f.boss, b.def)
        if b.by and not hidden and (TARGET_KINDS[b.def.kind] or Linked(b.def, spells, npcs)) then
            out[#out + 1] = { b = b }
        end
    end
    for i = 1, #(s.badges or {}) do
        local over = OverOf(s, i)
        if over then out[#out + 1] = { i = i, over = over } end
    end
    return out
end
function Rows.IsCount(b)
    return COUNT_KINDS[b.def.kind] == true
end
function Rows.HasHits(b)
    return (HIT_KINDS[b.def.kind] or b.def.soak) and b.hits ~= nil or false
end
function Rows.Targets(out, f, s)
    local list = Rows.Important(f, s)
    for k = 1, #list do
        local e = list[k]
        if e.b then BlockRows(e.b, s, out) else StackRows(s, e.i, e.over, out) end
    end
    if #list == 0 then Note(out, ns.T("mini.notargets")) end
end
