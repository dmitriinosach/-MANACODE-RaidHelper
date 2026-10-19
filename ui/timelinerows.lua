local _, ns = ...
local format = string.format
local tsort = table.sort
local Rows = {}
ns.TimelineRows = Rows
local M = { g = 0, k = 1, wk = 1, line = 12, bar = 12, row = 18, head = 14, ruler = 34, big = 15 }
function Rows.Measure()
    local Kit = ns.Kit
    local grow = Kit.Grow()
    local g = grow.g
    M.g, M.k, M.wk = g, grow.k, grow.wk
    M.line = 12 + g
    M.bar = 12 + g
    M.row = M.bar + 6
    M.head = 14 + g
    M.ruler = 34 + g * 2
    M.big = math.ceil(Kit.FontSize("GameFontNormal", true) * 1.25)
    return M
end
function Rows.Metrics()
    return M
end
function Rows.Glued()
    local ui = ns.GetDB().settings.ui
    return ui.glue ~= false
end
local function GlueIds(data)
    if not data then return {} end
    if not data.glueIds then
        local set = {}
        local lists = { data.healed, data.taken }
        for k = 1, #lists do
            local list = lists[k]
            for i = 1, #list do
                local id = tonumber(list[i].id)
                if id then set[id] = true end
            end
        end
        data.glueIds = set
    end
    return data.glueIds
end
function Rows.Aura(data, cats, dropMode, glue)
    local auraRows = {}
    local list = ns.Effects.categories
    local buckets = {}
    for i = 1, #list do
        buckets[list[i].key] = { bad = {}, good = {}, off = {} }
    end
    buckets[ns.Effects.ROOT] = { bad = {}, good = {}, off = {} }
    local items = data and data.auras
    if items then
        tsort(items, function(a, b) return a.t < b.t end)
        local index = {}
        for i = 1, #items do
            local a = items[i]
            local id = tonumber(a.id)
            local key = ns.Effects.GlueTo(id) or id
            if id and not (glue and GlueIds(data)[key]) then
                local row = index[key]
                if not row then
                    row = { label = ns.Effects.Name(key), id = key, kind = a.kind,
                            items = {} }
                    index[key] = row
                    local bucket = buckets[ns.Effects.Category(key)] or buckets.aura
                    local into
                    if not ns.Effects.Tracked(key) then
                        into = bucket.off
                    else
                        into = (a.kind == "debuff") and bucket.bad or bucket.good
                    end
                    into[#into + 1] = row
                end
                row.items[#row.items + 1] = a
                if id ~= key then
                    row.parts = row.parts or {}
                    row.parts[id] = (row.parts[id] or 0) + 1
                end
            end
        end
    end
    local function Emit(key, base)
        local bucket = buckets[key]
        if #bucket.off > 0 or dropMode then
            local hkey = key .. ":off"
            local hfold = cats[hkey] ~= true
            auraRows[#auraRows + 1] = {
                head = true,
                sub = true,
                cat = hkey,
                depth = base,
                label = ns.T("fx.cat.hidden"),
                count = #bucket.off,
                folded = hfold,
            }
            if not hfold then
                for j = 1, #bucket.off do
                    bucket.off[j].depth = base + 1
                    auraRows[#auraRows + 1] = bucket.off[j]
                end
            end
        end
        for j = 1, #bucket.bad do
            bucket.bad[j].depth = base
            auraRows[#auraRows + 1] = bucket.bad[j]
        end
        for j = 1, #bucket.good do
            bucket.good[j].depth = base
            auraRows[#auraRows + 1] = bucket.good[j]
        end
    end
    local root = buckets[ns.Effects.ROOT]
    if #root.bad + #root.good + #root.off > 0 or dropMode then
        Emit(ns.Effects.ROOT, 0)
    end
    for i = 1, #list do
        local key = list[i].key
        local bucket = buckets[key]
        local count = #bucket.bad + #bucket.good
        if count > 0 or #bucket.off > 0 or dropMode then
            local folded = cats[key] == true
            auraRows[#auraRows + 1] = {
                head = true,
                cat = key,
                depth = 0,
                label = ns.Effects.CategoryLabel(key),
                count = count,
                folded = folded,
            }
            if not folded then Emit(key, 1) end
        end
    end
    return auraRows
end
function Rows.Total(row, heal)
    local text = format(heal and ns.T("tl.row.heal") or ns.T("tl.row.hit"), ns.Num(row.total), row.hits,
        ns.Plural(row.hits, ns.T(heal and "tl.w.heal" or "tl.w.hit")))
    if row.misses > 0 then text = text .. format(ns.T("tl.row.miss"), row.misses) end
    return text
end
function Rows.MissText(it)
    local word = ns.L["tl.miss." .. it.miss] or it.miss
    if (it.missN or 0) > 0 then return word .. " " .. ns.Num(it.missN) end
    return word
end
local function SplitHot(rows, track, cats, dropMode)
    local root, hot, off = {}, {}, {}
    for i = 1, #rows do
        local row = rows[i]
        local set = ns.Effects.RowCat(row.id, track)
        local into
        if set == "off" then
            into = off
            row.off = true
        elseif set == "hot" then
            into = hot
        elseif set == "root" then
            into = root
        elseif row.hot or row.spans then
            into = hot
        else
            into = root
        end
        into[#into + 1] = row
    end
    local out = {}
    local function Shelf(bucket, key, label, sub, foldDefault)
        if #bucket == 0 and not dropMode then return end
        local folded = foldDefault ~= (cats[key] == true)
        out[#out + 1] = { head = true, cat = key, sub = sub, depth = 0,
                          folded = folded, label = label, count = #bucket }
        if folded then return end
        for i = 1, #bucket do
            bucket[i].depth = 1
            out[#out + 1] = bucket[i]
        end
    end
    Shelf(off, track .. ":off", ns.T("fx.cat.hidden"), true, true)
    for i = 1, #root do
        root[i].depth = 0
        out[#out + 1] = root[i]
    end
    Shelf(hot, track .. ":hot", ns.T("fx.cat.hot"), false, false)
    return out
end
local function AttachSpans(rows, data, glue)
    if not glue or not data or not data.auras then return end
    local byId = {}
    for i = 1, #rows do
        local id = tonumber(rows[i].id)
        if id then byId[id] = rows[i] end
    end
    for i = 1, #data.auras do
        local a = data.auras[i]
        local id = tonumber(a.id)
        local row = byId[ns.Effects.GlueTo(id) or id]
        if row then
            row.spans = row.spans or {}
            row.spans[#row.spans + 1] = a
        end
    end
end
function Rows.Amount(data, cats, dropMode, glue)
    local hitRows = ns.Encounters.GroupRows(data and data.taken)
    local healRows = ns.Encounters.GroupRows(data and data.healed)
    AttachSpans(healRows, data, glue)
    AttachSpans(hitRows, data, glue)
    healRows = SplitHot(healRows, "healed", cats, dropMode)
    hitRows = SplitHot(hitRows, "taken", cats, dropMode)
    return hitRows, healRows
end
