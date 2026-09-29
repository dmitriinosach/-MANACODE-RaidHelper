local _, ns = ...
local band = bit.band
local find = string.find
local F_BY_PLAYER = 0x100
local DROP = {
    SPELL_ENERGIZE = true, SPELL_PERIODIC_ENERGIZE = true,
    SPELL_CAST_FAILED = true, SPELL_EXTRA_ATTACKS = true,
    SPELL_DRAIN = true, SPELL_LEECH = true, SPELL_PERIODIC_DRAIN = true, SPELL_PERIODIC_LEECH = true,
    ENCHANT_REMOVED = true, UNIT_DESTROYED = true,
    SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true, SPELL_DISPEL_FAILED = true,
    SPELL_DURABILITY_DAMAGE = true, SPELL_DURABILITY_DAMAGE_ALL = true,
}
local AURAS = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REMOVED_DOSE = true,
}
local Filter = {}
ns.RecFilter = Filter
Filter.DROP = DROP
local keepPower = nil
local function KeepPower()
    if keepPower then return keepPower end
    keepPower = {}
    for _, def in pairs(ns.summaries or {}) do
        for _, bd in ipairs(def.badges or {}) do
            if bd.kind == "ticks" and bd.id then keepPower[bd.id] = true end
        end
    end
    return keepPower
end
local function IsBoss(name, auto)
    if name == nil then return false end
    return ns.bosses[name] ~= nil or (auto ~= nil and auto[name] == true)
end
function Filter.All()
    local db = ns.GetDB and ns.GetDB()
    return db ~= nil and db.settings ~= nil and db.settings.recAll == true
end
function Filter.Keep(sub, srcGUID, srcName, dstGUID, dstName, spellId, auraType, auto, all)
    if all then return true end
    if DROP[sub] then
        if spellId ~= nil and KeepPower()[spellId] then return true end
        return IsBoss(srcName, auto) or IsBoss(dstName, auto)
    end
    if AURAS[sub] and auraType == "BUFF" and srcGUID ~= nil and srcGUID == dstGUID
        and ns.recProcs[spellId] ~= nil then
        return false
    end
    return true
end
function Filter.Pulls(sub, srcFlags, dstName, auto)
    if not IsBoss(dstName, auto) or srcFlags == nil or band(srcFlags, F_BY_PLAYER) == 0 then return false end
    return find(sub, "_DAMAGE", 1, true) ~= nil or find(sub, "_HEAL", 1, true) ~= nil
end
