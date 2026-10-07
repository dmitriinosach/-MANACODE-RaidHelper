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
local function RateRows(out, list, sec, total)
    ByValue(list)
    local top = list[1] and list[1].v or 1
    for i = 1, #list do
        local e = list[i]
        out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = e.class,
            val = format("%s  %s", Short(e.v), Short(e.v / sec)),
            pct = format("%d%%", floor(e.v * 100 / max(1, total) + 0.5)),
            fill = e.v / max(1, top), who = e.who, tip = e.p and ns.BadgeTips.Player or nil, a = e.p, b = e.s }
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
    local list, total = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        local v = (heal and p.heal or p.dmg) or 0
        if v > 0 then
            list[#list + 1] = { who = p.name, v = v, class = p.class or ClassOf(p.name, s), p = p, s = s }
            total = total + v
        end
    end
    RateRows(out, list, sec, total)
    return total / sec
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
local function BlockRows(b, s, out)
    local view = TARGET_KINDS[b.def.kind] and ns.Targets and ns.Targets.View(b, function(who) return ClassOf(who, s) end)
    local label = ns.T(b.label or b.def.label)
    local count = COUNT_KINDS[b.def.kind]
    local head = { kind = "head", left = label, val = count and tostring(b.total) or Short(max(0, b.total)) }
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
        local val = Value(b, e.who, e.v)
        if r and #keep > 0 then val = Pick(r.cells, keep) end
        out[#out + 1] = { kind = "row", lead = tostring(i), left = e.who, class = class, val = val,
            pct = format("%d%%", floor(e.v * 100 / max(1, b.total) + 0.5)), fill = e.v / max(1, top),
            lines = r and r.lines or nil, tip = not r and ns.BadgeTips.Row or nil, a = b, b = e.who, c = e.v,
            d = class, who = e.who }
    end
    if #list > shown then Note(out, format(ns.T("mini.more"), #list - shown)) end
    if #list == 0 then Note(out, ns.T("sum.k.none")) end
end
local function Fill(set, list, keyOf)
    if type(list) ~= "table" then return end
    for i = 1, #list do
        local k = keyOf(list[i])
        if k then set[k] = true end
    end
end
local function SpellKey(id)
    return ns.SpellKey and ns.SpellKey(id) or id
end
local function NpcKey(id)
    return ns.NpcKeyOf and ns.NpcKeyOf(id) or id
end
local function RuleKeys(boss)
    local spells, npcs = {}, {}
    local rules = ns.Penalties and ns.Penalties.Rules and ns.Penalties.Rules(boss) or {}
    for i = 1, #rules do
        local r = rules[i]
        Fill(spells, r.spells, SpellKey)
        Fill(npcs, r.targets, NpcKey)
        Fill(npcs, r.srcs, NpcKey)
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
local function StackRows(s, i, over, out)
    local bd = s.badges[i]
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
    out[#out + 1] = { kind = "head", left = format(ns.T("mini.over"), ns.T(bd.tip or ""), over), val = tostring(#list) }
    local top = list[1] and list[1].v or 1
    for k = 1, min(BLOCK_ROWS, #list) do
        local e = list[k]
        out[#out + 1] = { kind = "row", lead = tostring(k), left = e.who, class = e.p.class or ClassOf(e.who, s),
            val = format(ns.T("mini.peak"), e.peak), pct = format("x%d", e.v), fill = e.v / max(1, top),
            tip = ns.StackTips and ns.StackTips.Badge or nil, a = e.st, b = bd, who = e.who }
    end
    if #list > BLOCK_ROWS then Note(out, format(ns.T("mini.more"), #list - BLOCK_ROWS)) end
    if #list == 0 then Note(out, ns.T("stk.never"), "text.good") end
end
function Rows.Targets(out, f, s)
    local n = 0
    local spells, npcs = RuleKeys(f.boss)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        local hidden = ns.SumHide and ns.SumHide.Hidden(f.boss, b.def)
        if b.by and not hidden and (TARGET_KINDS[b.def.kind] or Linked(b.def, spells, npcs)) then
            n = n + 1
            BlockRows(b, s, out)
        end
    end
    for i = 1, #(s.badges or {}) do
        local over = OverOf(s, i)
        if over then
            n = n + 1
            StackRows(s, i, over, out)
        end
    end
    if n == 0 then Note(out, ns.T("mini.notargets")) end
end
