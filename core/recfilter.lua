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
local ENERGIZE = { SPELL_ENERGIZE = true, SPELL_PERIODIC_ENERGIZE = true }
local AURAS = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REMOVED_DOSE = true,
}
local Filter = {}
ns.RecFilter = Filter
Filter.DROP = DROP
local keepPower = nil
local powerNpcs = nil
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
local function PowerNpcs()
    if powerNpcs then return powerNpcs end
    powerNpcs = {}
    for _, def in pairs(ns.summaries or {}) do
        for _, bd in ipairs(def.blocks or {}) do
            if bd.power and bd.npc then powerNpcs[ns.NpcKeyOf(bd.npc)] = true end
        end
    end
    return powerNpcs
end
local function IsBoss(guid, name, auto)
    local key = ns.NpcKey(guid)
    if key == nil or ns.trashBosses[key] then return false end
    return ns.bosses[key] ~= nil or (auto ~= nil and name ~= nil and auto[name] == true) or ns.Encounters.IsDummy(key)
end
function Filter.All()
    local db = ns.GetDB and ns.GetDB()
    return db ~= nil and db.settings ~= nil and db.settings.recAll == true
end
function Filter.Keep(sub, srcGUID, srcName, dstGUID, dstName, spellId, auraType, auto, all)
    if all then return true end
    if DROP[sub] then
        if spellId ~= nil and KeepPower()[spellId] then return true end
        if ENERGIZE[sub] and dstGUID ~= nil and PowerNpcs()[ns.NpcKey(dstGUID) or 0] then return true end
        return IsBoss(srcGUID, srcName, auto) or IsBoss(dstGUID, dstName, auto)
    end
    if AURAS[sub] and auraType == "BUFF" and srcGUID ~= nil and srcGUID == dstGUID
        and ns.recProcs[spellId] ~= nil then
        return false
    end
    return true
end
function Filter.Pulls(sub, srcFlags, dstGUID, dstName, auto)
    if not IsBoss(dstGUID, dstName, auto) or srcFlags == nil or band(srcFlags, F_BY_PLAYER) == 0 then
        return false
    end
    return find(sub, "_DAMAGE", 1, true) ~= nil or find(sub, "_HEAL", 1, true) ~= nil
end
