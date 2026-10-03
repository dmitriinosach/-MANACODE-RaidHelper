local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local REST_KEEP = 6
local Targets = {}
ns.Targets = Targets
local indexed = setmetatable({}, { __mode = "k" })
local function T(key)
    return ns.T(key)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Cell(v)
    return v > 0 and ns.BadgeTips.Short(v) or "—"
end
local function Index(def)
    local idx = indexed[def]
    if idx then return idx end
    idx = {}
    for g = 1, #(def.groups or {}) do
        local npcs = def.groups[g].npcs
        for i = 1, #npcs do idx[npcs[i]] = g end
    end
    indexed[def] = idx
    return idx
end
local function Slot(b, name)
    local t = b[name]
    if not t then
        t = {}
        b[name] = t
    end
    return t
end
function Targets.Hit(b, who, target, guid, tkey, amount, key, crit, id)
    local entry = ns.NpcEntry(guid) or tkey
    if not entry then return end
    local g = Index(b.def)[entry] or #b.def.groups + 1
    b.total = b.total + amount
    b.by[who] = (b.by[who] or 0) + amount
    local tg = Slot(b, "tg")
    local row = tg[who]
    if not row then
        row = {}
        tg[who] = row
    end
    row[g] = (row[g] or 0) + amount
    local sums = Slot(b, "gsum")
    sums[g] = (sums[g] or 0) + amount
    local col = Slot(b, "col")
    local c = col[who]
    if not c then
        c = {}
        col[who] = c
    end
    c[entry] = (c[entry] or 0) + amount
    local tn = Slot(b, "tn")
    if target and not tn[entry] then tn[entry] = target end
    if key then
        local gab = Slot(b, "gab")
        local h = gab[g]
        if not h then
            h = {}
            gab[g] = h
        end
        ns.Summary.Ab(h, who, key, amount, crit, id)
    end
end
local function Of(b, who, gs)
    if not gs then return b.by[who] or 0 end
    local row = b.tg and b.tg[who]
    local v = 0
    for i = 1, #gs do v = v + (row and row[gs[i]] or 0) end
    return v
end
local function GroupLabel(b, g)
    local def = b.def
    local grp = def.groups[g]
    if not grp then return T(def.rest) end
    if not grp.name then return T(grp.label) end
    return format(T(grp.label), b.tn and b.tn[grp.npcs[1]] or T(grp.name))
end
local function Columns(b)
    local def = b.def
    local cols = {}
    if def.lead then cols[1] = { label = T(def.lead.label), gs = def.lead.of, lead = true } end
    local rest = #def.groups + 1
    for g = 1, rest do
        if g < rest or (b.gsum and (b.gsum[rest] or 0) > 0) then
            cols[#cols + 1] = { label = GroupLabel(b, g), gs = { g } }
        end
    end
    cols[#cols + 1] = { label = T("sum.tt.total") }
    return cols
end
local function RestNames(b, who, out)
    local idx = Index(b.def)
    local list, by = {}, {}
    for entry, amount in pairs(b.col and b.col[who] or {}) do
        if not idx[entry] then
            local k = b.tn and b.tn[entry] or ("#" .. tostring(entry))
            local r = by[k]
            if r then
                r.v = r.v + amount
            else
                r = { k = k, v = amount }
                by[k] = r
                list[#list + 1] = r
            end
        end
    end
    tsort(list, function(x, y)
        if x.v ~= y.v then return x.v > y.v end
        return x.k < y.k
    end)
    local shown = min(REST_KEEP, #list)
    for i = 1, shown do Put(out, "sub", list[i].k, ns.BadgeTips.Short(list[i].v)) end
    if #list > shown then Put(out, "sub", (format(T("sum.tip.more"), #list - shown):gsub("^%s+", "")), nil, nil, "dim") end
end
local function ColLines(b, who, c, out)
    local v = Of(b, who, c.gs)
    Put(out, "row", c.label, Cell(v), nil, v == 0 and "dim" or nil)
    if v == 0 then return end
    if c.lead then
        for i = 1, #c.gs do Put(out, "sub", GroupLabel(b, c.gs[i]), Cell(Of(b, who, { c.gs[i] }))) end
    elseif not b.def.groups[c.gs[1]] then
        RestNames(b, who, out)
    end
end
local function Abilities(b, who, gs)
    local maps = {}
    for i = 1, #gs do
        local h = b.gab and b.gab[gs[i]]
        local m = h and h.ab and h.ab[who]
        if m then maps[#maps + 1] = m end
    end
    if #maps < 2 then return maps[1] end
    local out = {}
    for i = 1, #maps do
        for key, r in pairs(maps[i]) do
            local o = out[key]
            if not o then
                o = { a = 0, n = 0, c = 0, k = 0, id = r.id }
                out[key] = o
            end
            o.a, o.n, o.c, o.k = o.a + r.a, o.n + r.n, o.c + (r.c or 0), o.k + (r.k or 0)
        end
    end
    return out
end
local function CellTip(b, who, class, c)
    local v = Of(b, who, c.gs)
    local all = b.by[who] or 0
    local out = { { kind = "head", left = who, right = all > 0 and format("%d%%", floor(v * 100 / all + 0.5)) or nil,
                    class = class } }
    ColLines(b, who, c, out)
    if v > 0 then ns.BadgeTips.Abil(out, Abilities(b, who, c.gs), true, v) end
    return out
end
local function RowTip(b, who, class, cols)
    local out = { { kind = "head", left = who, right = ns.BadgeTips.Short(b.by[who] or 0), class = class } }
    for i = 1, #cols - 1 do ColLines(b, who, cols[i], out) end
    Put(out, "sep")
    Put(out, "row", T("sum.tt.total"), ns.BadgeTips.Short(b.by[who] or 0))
    return out
end
local function PanelTip(b, cols)
    local Short = ns.BadgeTips.Short
    local out = { { kind = "head", left = T(b.def.label), right = Short(b.total) } }
    local under = {}
    for i = 1, #(b.def.lead and b.def.lead.of or {}) do under[b.def.lead.of[i]] = true end
    for i = 1, #cols - 1 do
        local c = cols[i]
        local v = 0
        for k = 1, #c.gs do v = v + (b.gsum and b.gsum[c.gs[k]] or 0) end
        Put(out, (not c.lead and under[c.gs[1]]) and "sub" or "row", c.label, Cell(v),
            b.total > 0 and format("%.1f%%", v / b.total * 100) or nil, v == 0 and "dim" or nil)
    end
    return out
end
function Targets.View(b, classOf)
    if b.def.kind ~= "targets" or not b.by then return nil end
    local cols = Columns(b)
    local first = cols[1].gs
    local names = {}
    for who in pairs(b.by) do names[#names + 1] = who end
    tsort(names, function(x, y)
        local hx, hy = Of(b, x, first), Of(b, y, first)
        if hx ~= hy then return hx > hy end
        local vx, vy = b.by[x] or 0, b.by[y] or 0
        if vx ~= vy then return vx > vy end
        return x < y
    end)
    local labels = {}
    for c = 1, #cols do labels[c] = cols[c].label end
    local rows = {}
    for i = 1, #names do
        local who = names[i]
        local class = classOf and classOf(who) or nil
        local cells, vals, tips = {}, {}, {}
        for c = 1, #cols do
            vals[c] = Of(b, who, cols[c].gs)
            cells[c] = Cell(vals[c])
            tips[c] = cols[c].gs and CellTip(b, who, class, cols[c]) or false
        end
        rows[i] = { who = who, class = class, cells = cells, vals = vals, tips = tips, marks = {},
                    lines = RowTip(b, who, class, cols) }
    end
    return { title = format(T("sum.k.title"), T(b.def.label), ns.BadgeTips.Short(max(0, b.total))), cols = labels,
             heads = {}, rows = rows, tip = PanelTip(b, cols), span = 2 }
end
