local _, ns = ...
local tsort = table.sort
local Cures = {}
ns.Cures = Cures
local function T(key)
    return ns.T(key)
end
local function Pct(v, all)
    if all <= 0 then return nil end
    return ns.Fixed(v * 100 / all) .. "%"
end
local function Col(by, list, b, name)
    local c = by[name]
    if not c then
        c = { name = name, id = b.ids and b.ids[name] or nil, laid = 0, done = 0 }
        by[name] = c
        list[#list + 1] = c
    end
    return c
end
local function ColBefore(x, y)
    if x.laid ~= y.laid then return x.laid > y.laid end
    if x.done ~= y.done then return x.done > y.done end
    return x.name < y.name
end
local function Columns(b)
    local list = {}
    if b.def.kind == "dispels" then
        local laid = 0
        for _, n in pairs(b.laid or {}) do laid = laid + n end
        list[1] = { name = ns.SpellName(b.def.spell), id = b.def.spell, laid = laid, done = b.total }
        return list
    end
    local by = {}
    for name, n in pairs(b.laid or {}) do Col(by, list, b, name).laid = n end
    for _, sp in pairs(b.split) do
        for name, n in pairs(sp) do
            local c = Col(by, list, b, name)
            c.done = c.done + n
        end
    end
    tsort(list, ColBefore)
    return list
end
local function Of(b, who, c)
    if b.def.kind == "dispels" then return b.by[who] or 0 end
    local sp = b.split[who]
    return sp and sp[c.name] or 0
end
local function ColTip(c, known)
    local out = { { kind = "head", left = c.name } }
    if known then out[#out + 1] = { kind = "row", left = T("sum.cure.laid"), right = tostring(c.laid) } end
    out[#out + 1] = { kind = "row", left = T("sum.tt.removed"), right = tostring(c.done),
                      mid = known and Pct(c.done, c.laid) or nil }
    return out
end
local function CellTip(b, who, class, c)
    local v = Of(b, who, c)
    local out = { { kind = "head", left = who, right = Pct(v, c.done), class = class },
                  { kind = "row", left = c.name, right = tostring(v) } }
    local totem = b.def.kind == "dispels" and b.split[who] and b.split[who]["#totem"]
    if totem then out[#out + 1] = { kind = "sub", left = T("sum.tt.totem"), right = tostring(totem) } end
    return out
end
local function RowTip(b, who, class, cols)
    local all = b.by[who] or 0
    local out = { { kind = "head", left = who, right = Pct(all, b.total), class = class } }
    for k = 1, #cols do
        local v = Of(b, who, cols[k])
        if v > 0 then out[#out + 1] = { kind = "row", left = cols[k].name, right = tostring(v) } end
    end
    out[#out + 1] = { kind = "sep" }
    out[#out + 1] = { kind = "row", left = T("sum.tt.removed"), right = tostring(all) }
    return out
end
local function SumRow(cols, who, field, known)
    local cells, vals, tips, tones = {}, {}, {}, {}
    local lines = { { kind = "head", left = who } }
    for k = 1, #cols do
        local c = cols[k]
        local v = c[field]
        vals[k], cells[k], tips[k] = v, tostring(v), ColTip(c, known)
        tones[k] = v > 0 and "text.secondary" or "text.off"
        lines[#lines + 1] = { kind = "row", left = c.name, right = tostring(v),
                              mid = field == "done" and known and Pct(v, c.laid) or nil }
    end
    return { who = who, pin = true, tone = "text.secondary", cells = cells, vals = vals, tips = tips, tones = tones,
             marks = {}, lines = lines }
end
function Cures.View(b, classOf)
    local kind = b.def.kind
    if kind ~= "removed" and kind ~= "dispels" then return nil end
    local cols = Columns(b)
    if #cols == 0 then return nil end
    local known = b.laid ~= nil
    local labels, icons = {}, {}
    for k = 1, #cols do labels[k], icons[k] = cols[k].name, cols[k].id or false end
    local rows = {}
    if known then rows[1] = SumRow(cols, T("sum.cure.laid"), "laid", known) end
    rows[#rows + 1] = SumRow(cols, T("sum.tt.removed"), "done", known)
    local names = {}
    for who in pairs(b.by) do names[#names + 1] = who end
    tsort(names, function(x, y)
        local vx, vy = b.by[x] or 0, b.by[y] or 0
        if vx ~= vy then return vx > vy end
        return x < y
    end)
    for i = 1, #names do
        local who = names[i]
        local class = classOf and classOf(who) or nil
        local cells, vals, tips, tones = {}, {}, {}, {}
        for k = 1, #cols do
            local v = Of(b, who, cols[k])
            vals[k], cells[k] = v, v > 0 and tostring(v) or "—"
            tips[k] = CellTip(b, who, class, cols[k])
            tones[k] = v > 0 and false or "text.off"
        end
        rows[#rows + 1] = { who = who, class = class, cells = cells, vals = vals, tips = tips, tones = tones,
                            marks = {}, lines = RowTip(b, who, class, cols) }
    end
    return { cols = labels, colIcons = icons, rows = rows }
end
Cures.Columns = Columns
