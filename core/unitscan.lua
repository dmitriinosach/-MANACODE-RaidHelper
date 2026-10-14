local _, ns = ...
local PERIOD = 0.5
local MAX_RAID = 40
local MAX_PARTY = 4
local Scan = { n = 0, unit = {}, guid = {}, key = {}, name = {}, attack = {}, boss = {}, combat = {}, dead = {},
               hits = {}, near = {}, hp = {}, hpMax = {} }
ns.UnitScan = Scan
local RAID_T, RAID_TT, PARTY_T, PARTY_TT = ns.Units.raidTarget, {}, ns.Units.partyTarget, {}
for i = 1, MAX_RAID do RAID_TT[i] = RAID_T[i] .. "target" end
for i = 1, MAX_PARTY do PARTY_TT[i] = PARTY_T[i] .. "target" end
local NEAR = { "target", "focus" }
local FAR = { "mouseover", "targettarget" }
local slot = {}
local at = -math.huge
local far = false
local function Take(unit, near)
    if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
    local guid = UnitGUID(unit)
    local i = slot[guid or unit]
    if i then
        if near then
            Scan.hits[i] = Scan.hits[i] + 1
            Scan.near[i] = true
        end
        return
    end
    i = Scan.n + 1
    Scan.n = i
    slot[guid or unit] = i
    local key = guid and ns.NpcKey(guid)
    local attack = UnitCanAttack("player", unit) and true or false
    Scan.unit[i], Scan.guid[i], Scan.key[i] = unit, guid or false, key or false
    Scan.name[i] = UnitName(unit)
    Scan.attack[i] = attack
    Scan.boss[i] = attack and (UnitLevel(unit) == -1 or UnitClassification(unit) == "worldboss")
        and not (key and ns.trashBosses[key]) or false
    Scan.combat[i] = UnitAffectingCombat(unit) and true or false
    Scan.dead[i] = UnitIsDeadOrGhost(unit) and true or false
    Scan.hits[i], Scan.near[i] = near and 1 or 0, near
    Scan.hpMax[i] = UnitHealthMax(unit) or 0
    Scan.hp[i] = Scan.dead[i] and 0 or (UnitHealth(unit) or 0)
end
local function Build(withFar)
    wipe(slot)
    Scan.n = 0
    for i = 1, #NEAR do Take(NEAR[i], true) end
    local nRaid = GetNumRaidMembers()
    local count, t, tt = nRaid, RAID_T, RAID_TT
    if nRaid == 0 then count, t, tt = GetNumPartyMembers(), PARTY_T, PARTY_TT end
    for i = 1, count do Take(t[i], true) end
    if withFar then
        for i = 1, #FAR do Take(FAR[i], false) end
        for i = 1, count do Take(tt[i], false) end
    end
    far = withFar
end
function Scan.Get(withFar)
    local now = GetTime()
    if now - at >= PERIOD or now < at or (withFar and not far) then
        Build(withFar and true or false)
        at = now
    end
    return Scan
end
function Scan.Valid(i)
    local guid = Scan.guid[i]
    return guid ~= false and UnitGUID(Scan.unit[i]) == guid
end
function Scan.Forget()
    at, far = -math.huge, false
end
