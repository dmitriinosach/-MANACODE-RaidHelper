local _, ns = ...
local concat = table.concat
local tonumber = tonumber
local MAX_AURAS = 40
local MAX_RAID = 40
local MAX_PARTY = 4
local SUB = "FW_BUFFSNAP"
local TANK_SUB = "FW_TANKSNAP"
local SEP = ","
local Snap = {}
ns.BuffSnap = Snap
Snap.SUB = SUB
Snap.TANK_SUB = TANK_SUB
Snap.SEP = SEP
local RAID, PARTY = {}, {}
for i = 1, MAX_RAID do RAID[i] = "raid" .. i end
for i = 1, MAX_PARTY do PARTY[i] = "party" .. i end
local units = {}
local function Units()
    wipe(units)
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do units[i] = RAID[i] end
        return units
    end
    units[1] = "player"
    for i = 1, GetNumPartyMembers() do units[i + 1] = PARTY[i] end
    return units
end
local seen = {}
local namesOf = {}
local function Names(def)
    local list = namesOf[def]
    if list then return list end
    list = {}
    local have = {}
    for i = 1, #def.ids do
        local name = GetSpellInfo(def.ids[i])
        if name and not have[name] then
            have[name] = true
            list[#list + 1] = name
        end
    end
    namesOf[def] = list
    return list
end
local function Auras(unit)
    local set = seen[unit]
    if set then return set end
    set = {}
    for i = 1, MAX_AURAS do
        local name, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        if id then
            set[id] = true
            set[ns.SpellKey(id)] = true
        end
    end
    seen[unit] = set
    return set
end
local function Has(unit, def)
    if def.ids then
        local names = Names(def)
        for i = 1, #names do
            if UnitAura(unit, names[i]) then return true end
        end
        return false
    end
    local set = Auras(unit)
    return set[def.id] == true or set[ns.SpellKey(def.id)] == true
end
local function Sign(set, cls)
    for id, sg in pairs(ns.tankSigns) do
        if sg.class == cls and (set[id] or set[ns.SpellKey(id)]) then return true end
    end
    return false
end
local function BySpec(name, cls, set)
    local def = ns.tankSpec
    local want = def.trees[cls]
    local t = want and ns.Specs.Of(name)
    if not t then return nil end
    if t ~= want then return false end
    local forms = def.forms[cls]
    if not forms then return true end
    if not set then return nil end
    for id, tank in pairs(forms) do
        if set[id] or set[ns.SpellKey(id)] then return tank end
    end
    return nil
end
local function ByGear(unit, name, cls)
    local def = ns.tankSpec
    local yes, no = false, false
    local mana = def.manaMax[cls]
    if mana and (tonumber(UnitManaMax(unit)) or 0) > mana then no = true end
    local g = ns.Specs.GearOf(name)
    if g then
        if g.def >= def.defense or g.off == "str" then yes = true end
        if g.off == "sp" then no = true end
    end
    if yes == no then return nil end
    return yes
end
local function Put(list, v, name)
    if v == nil then return end
    local out = list[v]
    out[#out + 1] = name
end
local function Tanks(ts, us)
    local def = ns.tankSpec
    if not def or not ns.tankSigns then return end
    local strong, mt, unseen = {}, {}, {}
    local spec, gear = { [true] = {}, [false] = {} }, { [true] = {}, [false] = {} }
    local raid = GetNumRaidMembers() > 0
    for i = 1, #us do
        local u = us[i]
        local name = UnitName(u)
        local _, cls = UnitClass(u)
        if name then
            if raid and select(10, GetRaidRosterInfo(i)) == "MAINTANK" then mt[#mt + 1] = name end
            if cls and def.classes[cls] then
                local set = UnitIsVisible(u) and Auras(u) or nil
                if not set then
                    unseen[#unseen + 1] = name
                elseif Sign(set, cls) then
                    strong[#strong + 1] = name
                end
                Put(spec, BySpec(name, cls, set), name)
                Put(gear, ByGear(u, name, cls), name)
            end
        end
    end
    ns.Store.Append(ts, TANK_SUB, nil, nil, 0, nil, nil, 0, concat(strong, SEP), concat(mt, SEP), concat(unseen, SEP),
        concat(spec[true], SEP), concat(spec[false], SEP), concat(gear[true], SEP), concat(gear[false], SEP))
end
local function Line(ts, us, def)
    local on, off = {}, {}
    for i = 1, #us do
        local u = us[i]
        local name = UnitName(u)
        local _, cls = UnitClass(u)
        if name and (not def.class or cls == def.class) and UnitIsVisible(u) then
            if Has(u, def) then on[#on + 1] = name else off[#off + 1] = name end
        end
    end
    if #on + #off > 0 then
        ns.Store.Append(ts, SUB, nil, nil, 0, nil, nil, 0, def.id, concat(on, SEP), concat(off, SEP))
    end
end
function Snap.Take(ts)
    wipe(seen)
    local us = Units()
    Tanks(ts, us)
    local list = ns.buffSnap
    if not list then return end
    local map = ns.Raid and ns.Raid.MapNow()
    for k = 1, #list do
        local def = list[k]
        if not def.map or map == def.map then Line(ts, us, def) end
    end
end
function Snap.Names(s)
    local out = {}
    if type(s) ~= "string" then return out end
    for name in s:gmatch("[^" .. SEP .. "]+") do out[#out + 1] = name end
    return out
end
