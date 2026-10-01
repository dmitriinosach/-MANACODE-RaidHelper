local _, ns = ...
local format = string.format
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
function Targets.Hit(b, who, target, guid, tkey, amount)
    local entry = ns.NpcEntry(guid) or tkey
    if not entry then return end
    local g = Index(b.def)[entry] or #b.def.groups + 1
    b.total = b.total + amount
    b.by[who] = (b.by[who] or 0) + amount
    local tg = b.tg
    if not tg then
        tg = {}
        b.tg = tg
    end
    local row = tg[who]
    if not row then
        row = {}
        tg[who] = row
    end
    row[g] = (row[g] or 0) + amount
    local sums = b.gsum
    if not sums then
        sums = {}
        b.gsum = sums
    end
    sums[g] = (sums[g] or 0) + amount
    local col = b.col
    if not col then
        col = {}
        b.col = col
    end
    local c = col[who]
    if not c then
        c = {}
        col[who] = c
    end
    c[entry] = (c[entry] or 0) + amount
    local tn = b.tn
    if not tn then
        tn = {}
        b.tn = tn
    end
    if target and not tn[entry] then tn[entry] = target end
end
local function Of(b, who, g)
    local row = b.tg and b.tg[who]
    return row and row[g] or 0
end
local function GroupLabel(b, g)
    local def = b.def
    return T(def.groups[g] and def.groups[g].label or def.rest)
end
local function GroupLines(b, who, g, out)
    local def = b.def
    local col = b.col and b.col[who] or {}
    local v = Of(b, who, g)
    Put(out, "row", GroupLabel(b, g), Cell(v), nil, v == 0 and "dim" or nil)
    if v == 0 then return end
    local list = {}
    local grp = def.groups[g]
    if grp then
        for i = 1, #grp.npcs do
            local id = grp.npcs[i]
            local tag = def.tags and def.tags[id]
            if tag and (col[id] or 0) > 0 then list[#list + 1] = { k = T(tag), v = col[id] } end
        end
    else
        local idx = Index(def)
        for entry, amount in pairs(col) do
            if not idx[entry] then list[#list + 1] = { k = b.tn and b.tn[entry] or ("#" .. tostring(entry)), v = amount } end
        end
        local merged, by = {}, {}
        for i = 1, #list do
            local r = by[list[i].k]
            if r then
                r.v = r.v + list[i].v
            else
                by[list[i].k] = list[i]
                merged[#merged + 1] = list[i]
            end
        end
        list = merged
    end
    tsort(list, function(x, y)
        if x.v ~= y.v then return x.v > y.v end
        return x.k < y.k
    end)
    local shown = grp and #list or min(REST_KEEP, #list)
    for i = 1, shown do Put(out, "sub", list[i].k, ns.BadgeTips.Short(list[i].v)) end
    if #list > shown then Put(out, "sub", (format(T("sum.tip.more"), #list - shown):gsub("^%s+", "")), nil, nil, "dim") end
end
local function RowTip(b, who, class)
    local out = { { kind = "head", left = who, right = ns.BadgeTips.Short(b.by[who] or 0), class = class } }
    for g = 1, #b.def.groups + 1 do GroupLines(b, who, g, out) end
    Put(out, "sep")
    Put(out, "row", T("sum.tt.total"), ns.BadgeTips.Short(b.by[who] or 0))
    return out
end
local function PanelTip(b)
    local Short = ns.BadgeTips.Short
    local out = { { kind = "head", left = T(b.def.label), right = Short(b.total) } }
    for g = 1, #b.def.groups + 1 do
        local v = b.gsum and b.gsum[g] or 0
        Put(out, "row", GroupLabel(b, g), Cell(v), b.total > 0 and format("%.1f%%", v / b.total * 100) or nil,
            v == 0 and "dim" or nil)
    end
    return out
end
function Targets.View(b, classOf)
    if b.def.kind ~= "targets" or not b.by then return nil end
    local names = {}
    for who in pairs(b.by) do names[#names + 1] = who end
    tsort(names, function(x, y)
        local hx, hy = Of(b, x, 1), Of(b, y, 1)
        if hx ~= hy then return hx > hy end
        local vx, vy = b.by[x] or 0, b.by[y] or 0
        if vx ~= vy then return vx > vy end
        return x < y
    end)
    local n = #b.def.groups + 1
    local cols = {}
    for g = 1, n do cols[g] = GroupLabel(b, g) end
    cols[n + 1] = T("sum.tt.total")
    local rows = {}
    for i = 1, #names do
        local who = names[i]
        local cells = {}
        for g = 1, n do cells[g] = Cell(Of(b, who, g)) end
        cells[n + 1] = Cell(b.by[who] or 0)
        local class = classOf and classOf(who) or nil
        rows[i] = { who = who, class = class, cells = cells, marks = {}, lines = RowTip(b, who, class) }
    end
    local label = T(b.def.label)
    return { title = format(T("sum.k.title"), label, ns.BadgeTips.Short(max(0, b.total))), cols = cols, heads = {},
             rows = rows, tip = PanelTip(b), span = 2 }
end
