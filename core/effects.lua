local _, ns = ...
local tsort = table.sort
local format = string.format
local Effects = {}
ns.Effects = Effects
local RAID_TARGETS = 8
local function Reg()
    local db = ns.GetDB()
    if type(db.fx) ~= "table" then db.fx = {} end
    return db.fx
end
local function User()
    local db = ns.GetDB()
    if type(db.fxUser) ~= "table" then db.fxUser = {} end
    return db.fxUser
end
local function Mine(id)
    local user = User()
    local row = user[id]
    if not row then
        row = {}
        user[id] = row
    end
    return row
end
Effects.ROOT = "fx"
Effects.categories = {
    { key = "raid",   labelKey = "fx.cat.raid" },
    { key = "buff",   labelKey = "fx.cat.buff" },
    { key = "debuff", labelKey = "fx.cat.debuff" },
    { key = "self",   labelKey = "fx.cat.self" },
    { key = "proc",   labelKey = "fx.cat.proc" },
    { key = "aura",   labelKey = "fx.cat.aura" },
}
local catOrder = {}
for i = 1, #Effects.categories do
    catOrder[Effects.categories[i].key] = i
end
local catLegacy = {
    ally = "buff",
    other = "aura",
}
local function Shelf(e)
    local n = e.n or 0
    if n == 0 then return "aura" end
    if (e.debuff or 0) * 2 > n then return "debuff" end
    if (e.mine or 0) * 2 > n then
        return (e.cast or 0) * 2 >= n and "self" or "proc"
    end
    if (e.tmax or 0) >= RAID_TARGETS then
        return (e.cast or 0) * 2 >= n and "raid" or "aura"
    end
    return "buff"
end
function Effects.ResetCounts()
    local db = ns.GetDB()
    db.fx = {}
end
function Effects.Absorb(stats)
    local reg = Reg()
    for id, s in pairs(stats) do
        local e = reg[id]
        if not e then
            e = { n = 0, debuff = 0, hostile = 0, mine = 0, cast = 0, tmax = 0 }
            reg[id] = e
        end
        if not e.name and s.name then e.name = s.name end
        e.n = e.n + s.n
        e.debuff = e.debuff + s.debuff
        e.hostile = e.hostile + s.hostile
        e.mine = e.mine + s.mine
        e.cast = e.cast + s.cast
        if s.tn > e.tmax then e.tmax = s.tn end
        e.orig = Shelf(e)
    end
end
function Effects.Entry(id)
    if id == nil then return nil end
    return Reg()[id]
end
local synthetic = {}
function Effects.Synthetic(id, name, cat)
    synthetic[id] = { name = name, cat = cat }
end
function Effects.Name(id)
    local fake = id and synthetic[id]
    if fake then return fake.name end
    local e = Effects.Entry(id)
    if e and e.name then return e.name end
    local name = id and GetSpellInfo(id)
    return name or tostring(id)
end
local iconCache = {}
function Effects.IconById(id)
    local spellId = tonumber(id)
    if not spellId then return nil end
    local cached = iconCache[spellId]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local _, _, icon = GetSpellInfo(spellId)
    iconCache[spellId] = icon or false
    return icon
end
function Effects.Icon(id)
    return Effects.IconById(id)
end
local function Default(id)
    local defaults = ns.effectDefaults
    local e = Effects.Entry(id)
    local key = e and e.name
    return (key and defaults and defaults[key]) or "on"
end
function Effects.HasCategory(key)
    return key ~= nil and (catOrder[key] ~= nil or key == Effects.ROOT)
end
function Effects.Category(id)
    local row = id and User()[id]
    local key = row and row.cat
    key = catLegacy[key] or key
    if key and Effects.HasCategory(key) then return key end
    local fake = id and synthetic[id]
    if fake and catOrder[fake.cat] then return fake.cat end
    local e = Effects.Entry(id)
    key = e and e.orig
    key = catLegacy[key] or key
    if key and catOrder[key] then return key end
    return "aura"
end
function Effects.SetCategory(id, key)
    if not Effects.HasCategory(key) then return end
    local e = Effects.Entry(id)
    if e and e.orig == key then
        local row = User()[id]
        if row then row.cat = nil end
    else
        Mine(id).cat = key
    end
end
function Effects.RowCat(id, track)
    local row = id and User()[id]
    local t = row and row.t
    return t and t[track] or nil
end
function Effects.SetRowCat(id, track, key)
    local row = User()[id]
    if not key then
        if row and type(row.t) == "table" then row.t[track] = nil end
        return
    end
    row = Mine(id)
    if type(row.t) ~= "table" then row.t = {} end
    row.t[track] = key
end
function Effects.GlueTo(id)
    local row = id and User()[id]
    return row and row.glue or nil
end
function Effects.SetGlue(id, target)
    local seen = 0
    while target and User()[target] and User()[target].glue and seen < 8 do
        target = User()[target].glue
        seen = seen + 1
    end
    if target == id then target = nil end
    if not target then
        local row = User()[id]
        if row then row.glue = nil end
        return
    end
    Mine(id).glue = target
end
function Effects.CategoryLabel(key)
    local i = catOrder[key]
    if not i then return key end
    return ns.T(Effects.categories[i].labelKey)
end
function Effects.State(id)
    local row = id and User()[id]
    return (row and row.state) or (id and Default(id)) or "on"
end
function Effects.Set(id, state)
    if state == Default(id) then
        local row = User()[id]
        if row then row.state = nil end
    else
        Mine(id).state = state
    end
end
function Effects.Toggle(id)
    Effects.Set(id, Effects.State(id) == "on" and "off" or "on")
end
function Effects.Tracked(id)
    if id == nil then return false end
    return Effects.State(id) == "on"
end
local function Collect(wanted)
    local list = {}
    for id, e in pairs(Reg()) do
        local state = Effects.State(id)
        local inTrash = state == "trash"
        if (wanted == "trash") == inTrash then
            list[#list + 1] = { id = id, name = e.name or Effects.Name(id),
                                count = e.n or 0, state = state }
        end
    end
    tsort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list
end
function Effects.List()
    return Collect("list")
end
function Effects.Trash()
    return Collect("trash")
end
function Effects.Counts()
    local shown, trashed = 0, 0
    for id in pairs(Reg()) do
        local state = Effects.State(id)
        if state == "trash" then
            trashed = trashed + 1
        elseif state == "on" then
            shown = shown + 1
        end
    end
    return shown, trashed
end
local function NameIndex()
    local byName = {}
    for id, e in pairs(Reg()) do
        local name = e.name
        if name then
            local ids = byName[name]
            if not ids then
                byName[name] = { id }
            else
                ids[#ids + 1] = id
            end
        end
    end
    return byName
end
function Effects.MergeVariants()
    local byName = NameIndex()
    local reg = Reg()
    local merged, skipped = 0, {}
    for name, ids in pairs(byName) do
        if #ids > 1 then
            local shelf = nil
            local same = true
            for i = 1, #ids do
                local orig = Effects.Category(ids[i])
                shelf = shelf or orig
                if orig ~= shelf then same = false end
            end
            if not same then
                skipped[#skipped + 1] = name
            else
                local best = ids[1]
                for i = 2, #ids do
                    if (reg[ids[i]].n or 0) > (reg[best].n or 0) then best = ids[i] end
                end
                for i = 1, #ids do
                    if ids[i] ~= best then
                        Effects.SetGlue(ids[i], best)
                        merged = merged + 1
                    end
                end
            end
        end
    end
    tsort(skipped)
    return merged, skipped
end
function Effects.Migrate()
    local db = ns.GetDB()
    local oldState = type(db.effectState) == "table" and db.effectState or nil
    local oldCat = type(db.effectCat) == "table" and db.effectCat or nil
    if not oldState and not oldCat and db.effects == nil and db.effectIds == nil then
        return
    end
    local byName = NameIndex()
    local clash = {}
    for name, ids in pairs(byName) do
        if #ids > 1 then
            clash[#clash + 1] = name
        else
            local id = ids[1]
            local state = oldState and oldState[name]
            if state then Effects.Set(id, state) end
            local cat = oldCat and oldCat[name]
            cat = catLegacy[cat] or cat
            if cat and catOrder[cat] then Effects.SetCategory(id, cat) end
        end
    end
    db.effects = nil
    db.effectIds = nil
    db.effectState = nil
    db.effectCat = nil
    if #clash > 0 then
        tsort(clash)
        ns.Print(format(ns.T("fx.clash"), #clash, table.concat(clash, ", ")))
    end
end
