local _, ns = ...
local type = type
local tonumber = tonumber
local tostring = tostring
local strsub = string.sub
local rawget = rawget
ns.spellGroups = ns.spellGroups or {}
ns.npcGroups = ns.npcGroups or {}
local spellKey = {}
local npcKey = {}
local npcOfGuid = {}
local npcGuids = 0
local NPC_GUIDS_MAX = 8192
local npcNames = {}
local spellNames = {}
local built = false
local function Build()
    built = true
    for key, list in pairs(ns.spellGroups) do
        for i = 1, #list do spellKey[list[i]] = key end
    end
    for key, list in pairs(ns.npcGroups) do
        for i = 1, #list do npcKey[list[i]] = key end
    end
end
function ns.SpellKey(id)
    if not built then Build() end
    id = tonumber(id)
    if not id then return nil end
    return spellKey[id] or id
end
local spellSub = {}
local function IsSpellSub(sub)
    if sub == nil then return false end
    local v = spellSub[sub]
    if v == nil then
        v = strsub(sub, 1, 6) == "SPELL_" or strsub(sub, 1, 6) == "RANGE_" or strsub(sub, 1, 8) == "DAMAGE_S"
        spellSub[sub] = v
    end
    return v
end
ns.IsSpellSub = IsSpellSub
function ns.SpellOf(sub, id)
    if not IsSpellSub(sub) then return nil end
    if not built then Build() end
    id = tonumber(id)
    if not id then return nil end
    return spellKey[id] or id
end
function ns.SpellKeys()
    if not built then Build() end
    return spellKey
end
function ns.NpcEntry(guid)
    if type(guid) ~= "string" or #guid ~= 18 or strsub(guid, 1, 4) ~= "0xF1" then return nil end
    local kind = strsub(guid, 5, 5)
    if kind ~= "3" and kind ~= "5" then return nil end
    local id = tonumber(strsub(guid, 7, 12), 16)
    if id and id > 0 then return id end
    return nil
end
function ns.NpcKey(guid)
    if guid == nil then return nil end
    local v = npcOfGuid[guid]
    if v == nil then
        if not built then Build() end
        local id = ns.NpcEntry(guid)
        v = id and (npcKey[id] or id) or false
        if npcGuids >= NPC_GUIDS_MAX then ns.ForgetGuids() end
        npcGuids = npcGuids + 1
        npcOfGuid[guid] = v
    end
    return v or nil
end
function ns.ForgetGuids()
    npcOfGuid = {}
    npcGuids = 0
end
function ns.ItemName(id, fallback)
    local name = id and GetItemInfo and GetItemInfo(id)
    return name or fallback or ("#" .. tostring(id))
end
function ns.ConsumableName(id, spell, item)
    local name = id and GetItemInfo and GetItemInfo(id)
    if name then return name end
    if spell and (GetLocale() ~= "ruRU" or ns.lang ~= "ruRU") then
        name = GetSpellInfo(spell)
        if name then return name end
    end
    return item or ("#" .. tostring(id))
end
function ns.NpcKeyOf(id)
    if not id then return nil end
    if not built then Build() end
    return npcKey[id] or id
end
function ns.SpellSet(list, out)
    out = out or {}
    for i = 1, #(list or {}) do
        local k = ns.SpellKey(list[i])
        if k then out[k] = true end
    end
    return out
end
function ns.NoteNpc(guid, name)
    if not name or name == "" then return end
    local key = ns.NpcKey(guid)
    if key and not npcNames[key] then npcNames[key] = name end
end
function ns.NoteNpcKey(key, name)
    if type(key) == "number" and name and name ~= "" and not npcNames[key] then npcNames[key] = name end
end
local spellIdOf = {}
function ns.NoteSpell(id, name)
    id = tonumber(id)
    if id and name and name ~= "" and not spellNames[id] then
        spellNames[id] = name
        if not spellIdOf[name] then spellIdOf[name] = id end
    end
end
function ns.StackKey(v)
    if type(v) == "string" and not tonumber(v) then
        local id = spellIdOf[v]
        return id and ns.SpellKey(id) or nil
    end
    return ns.SpellKey(v)
end
function ns.NpcName(key)
    if key == nil then return "" end
    if type(key) == "string" then return key end
    return rawget(ns.L, "npc." .. key) or npcNames[key] or ("#" .. tostring(key))
end
function ns.SpellName(id)
    if not id then return "" end
    local name = GetSpellInfo(id) or spellNames[id]
    return name or ("#" .. tostring(id))
end
function ns.SpellIcon(id)
    if not id then return nil end
    local _, _, icon = GetSpellInfo(id)
    return icon
end
function ns.EncName(key)
    if key == nil then return "" end
    if type(key) == "string" then return key end
    return rawget(ns.L, "enc." .. key) or ns.NpcName(key)
end
function ns.EncByName(name)
    if name == nil or name == "" then return nil end
    local n = tonumber(name)
    if n then return n end
    for _, k in pairs(ns.ENC or {}) do
        if ns.EncName(k) == name then return k end
    end
    for k, v in pairs(npcNames) do
        if v == name then return k end
    end
    return name
end
function ns.IsBossKey(fight, key)
    if key == nil or not fight then return false end
    return key == fight.boss or (ns.bosses ~= nil and ns.bosses[key] == fight.boss)
        or (fight.names ~= nil and fight.names[key] == true)
end
function ns.IsBossOf(fight, guid)
    return ns.IsBossKey(fight, ns.NpcKey(guid))
end
