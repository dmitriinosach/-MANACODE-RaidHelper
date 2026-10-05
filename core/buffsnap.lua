local _, ns = ...
local concat = table.concat
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
local function Has(unit, def)
    local set = seen[unit]
    if not set then
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
    end
    return set[def.id] == true or set[ns.SpellKey(def.id)] == true
end
local signByKey
local signClass
local function Classes(signs)
    if signClass then return signClass end
    signClass = {}
    for _, sg in pairs(signs) do signClass[sg.class] = true end
    return signClass
end
local function ByKey(signs)
    if signByKey then return signByKey end
    signByKey = {}
    for id, sg in pairs(signs) do signByKey[ns.SpellKey(id)] = sg end
    return signByKey
end
local function Sign(unit, cls)
    local signs = ns.tankSigns
    local byKey = ByKey(signs)
    for i = 1, MAX_AURAS do
        local name, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not name then return nil end
        local sg = signs[id] or (id and byKey[ns.SpellKey(id)])
        if sg and sg.class == cls then return sg end
    end
    return nil
end
local function Tanks(ts, us)
    if not ns.tankSigns then return end
    local classes = Classes(ns.tankSigns)
    local strong, weak, mt, unseen = {}, {}, {}, {}
    local raid = GetNumRaidMembers() > 0
    for i = 1, #us do
        local u = us[i]
        local name = UnitName(u)
        local _, cls = UnitClass(u)
        if name then
            if raid and select(10, GetRaidRosterInfo(i)) == "MAINTANK" then mt[#mt + 1] = name end
            if cls and classes[cls] then
                if UnitIsVisible(u) then
                    local sg = Sign(u, cls)
                    if sg then
                        local out = sg.weak and weak or strong
                        out[#out + 1] = name
                    end
                else
                    unseen[#unseen + 1] = name
                end
            end
        end
    end
    ns.Store.Append(ts, TANK_SUB, nil, nil, 0, nil, nil, 0,
        concat(strong, SEP), concat(weak, SEP), concat(mt, SEP), concat(unseen, SEP))
end
function Snap.Take(ts)
    wipe(seen)
    local us = Units()
    Tanks(ts, us)
    local list = ns.buffSnap
    if not list then return end
    for k = 1, #list do
        local def = list[k]
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
end
function Snap.Names(s)
    local out = {}
    if type(s) ~= "string" then return out end
    for name in s:gmatch("[^" .. SEP .. "]+") do out[#out + 1] = name end
    return out
end
