local _, ns = ...
local band = bit.band
local WINDOW = 30
local IDLE_END = 3
local AFFIL_RAID = 0x7
local AFFIL_MINE = 0x1
local HOSTILE = 0x40
local SPELL_DMG = 1
local SWING_DMG = 2
local HEAL = 3
local CURVE_MAX = 64
local TYPE_PLAYER = 0x400
local OWNERS_MAX = 400
local KIND = {
    SWING_DAMAGE = SWING_DMG,
    RANGE_DAMAGE = SPELL_DMG,
    SPELL_DAMAGE = SPELL_DMG,
    SPELL_PERIODIC_DAMAGE = SPELL_DMG,
    SPELL_BUILDING_DAMAGE = SPELL_DMG,
    DAMAGE_SHIELD = SPELL_DMG,
    DAMAGE_SPLIT = SPELL_DMG,
    SPELL_HEAL = HEAL,
    SPELL_PERIODIC_HEAL = HEAL,
}
local Meter = { dmg = {}, heal = {}, curve = {}, who = {} }
ns.Meter = Meter
local dmg, heal, curve, who = Meter.dmg, Meter.heal, Meter.curve, Meter.who
for i = 1, WINDOW do
    dmg[i], heal[i] = 0, 0
end
local slot = 1
local dmgSum, healSum = 0, 0
local span = 0
local acc = 0
local watching = false
local affil = AFFIL_MINE
local inRaid = false
local wants = {}
local split = false
local owners = {}
local ownersN = 0
local RAID_UNITS, RAID_PETS, PARTY_UNITS, PARTY_PETS = {}, {}, {}, {}
for i = 1, 40 do RAID_UNITS[i], RAID_PETS[i] = "raid" .. i, "raidpet" .. i end
for i = 1, 4 do PARTY_UNITS[i], PARTY_PETS[i] = "party" .. i, "partypet" .. i end
local fighting = false
local fightAt, fightDur = 0, 0
local fightDmg, fightHeal = 0, 0
local silence = 0
local curveStep, curveTick = 1, 0
local frame = CreateFrame("Frame")
frame:Hide()
local seenAll = 0
local counter = CreateFrame("Frame")
local LOG_FIX = { tick = 1, silent = 5, gap = 15, say = 60, quiet = 0, acc = 0, last = -1, at = -60, saidAt = -60, n = 0 }
local function Clear()
    if CombatLogClearEntries then CombatLogClearEntries() end
end
counter:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        seenAll = seenAll + 1
        return
    end
    local _, kind = GetInstanceInfo()
    if kind == "raid" or kind == "party" then Clear() end
end)
counter:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
counter:RegisterEvent("PLAYER_ENTERING_WORLD")
local function GroupFighting()
    if UnitAffectingCombat("player") then return true end
    local n, unit = GetNumRaidMembers(), "raid"
    if n == 0 then n, unit = GetNumPartyMembers(), "party" end
    for i = 1, n do
        if UnitAffectingCombat(unit .. i) then return true end
    end
    return false
end
counter:SetScript("OnUpdate", function(_, elapsed)
    local F = LOG_FIX
    F.acc = F.acc + elapsed
    if F.acc < F.tick then return end
    local dt = F.acc
    F.acc = 0
    local grouped = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if seenAll ~= F.last or not grouped or not GroupFighting() then
        F.quiet, F.last = 0, seenAll
        return
    end
    F.quiet = F.quiet + dt
    local now = GetTime()
    if F.quiet < F.silent or now - F.at < F.gap then return end
    F.quiet, F.at, F.n = 0, now, F.n + 1
    Clear()
    if now - F.saidAt >= F.say then
        F.saidAt = now
        ns.Print(ns.T("log.revived"))
    end
end)
function Meter.LogRevived()
    return LOG_FIX.n
end
function Meter.Seen()
    return seenAll
end
function Meter.Window()
    return WINDOW
end
function Meter.Slot()
    return slot
end
function Meter.InRaid()
    return inRaid
end
function Meter.Fighting()
    return fighting
end
function Meter.FightTime()
    return fighting and (GetTime() - fightAt) or fightDur
end
function Meter.CurveStep()
    return curveStep
end
function Meter.Rates()
    local dur = Meter.FightTime()
    if dur < 1 then dur = 1 end
    return fightDmg / dur, fightHeal / dur
end
function Meter.WindowRates()
    if span <= 0 then return 0, 0 end
    return dmgSum / span, healSum / span
end
function Meter.Active()
    return span > 0
end
function Meter.IsWatching()
    return watching
end
local function Amount(v)
    if type(v) == "number" then return v end
    return tonumber(v) or 0
end
local function ClearCurve()
    for i = #curve, 1, -1 do curve[i] = nil end
    curveStep, curveTick = 1, 0
end
local function Own(guid, name)
    if not guid or not name or owners[guid] == name then return end
    if not owners[guid] then
        ownersN = ownersN + 1
        if ownersN > OWNERS_MAX then
            wipe(owners)
            ownersN = 1
        end
    end
    owners[guid] = name
end
local apart = nil
local function Apart()
    if apart then return apart end
    apart = {}
    for key in pairs(ns.vehicles or {}) do apart[ns.NpcKeyOf(key)] = true end
    for _, def in pairs(ns.summaries or {}) do
        local blocks = def.blocks or {}
        for i = 1, #blocks do
            if blocks[i].kind == "abom" and blocks[i].npc then apart[ns.NpcKeyOf(blocks[i].npc)] = true end
        end
    end
    return apart
end
local function ScanPets()
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do Own(UnitGUID(RAID_PETS[i]), UnitName(RAID_UNITS[i])) end
        return
    end
    Own(UnitGUID("pet"), UnitName("player"))
    for i = 1, GetNumPartyMembers() do Own(UnitGUID(PARTY_PETS[i]), UnitName(PARTY_UNITS[i])) end
end
local function FightStart()
    fighting = true
    fightAt = GetTime()
    fightDmg, fightHeal = 0, 0
    ClearCurve()
    if split then
        wipe(who)
        ScanPets()
    end
end
local function Credit(srcGUID, srcName, srcFlags, n)
    local name = band(srcFlags, TYPE_PLAYER) ~= 0 and srcName or owners[srcGUID]
    if name then who[name] = (who[name] or 0) + n end
end
local function StepCurve()
    curveTick = curveTick + 1
    if curveTick < curveStep then return end
    curveTick = 0
    local dur = GetTime() - fightAt
    if dur < 1 then dur = 1 end
    local n = #curve + 1
    curve[n] = fightDmg / dur
    if n < CURVE_MAX then return end
    local half = CURVE_MAX / 2
    for i = 1, half do curve[i] = curve[i * 2] end
    for i = half + 1, n do curve[i] = nil end
    curveStep = curveStep * 2
end
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.log", function(_, event, _, sub, srcGUID, srcName, srcFlags, dstGUID, _,
                                                         dstFlags, a1, _, _, a4, a5)
    if event == "UNIT_PET" then
        ScanPets()
        return
    end
    local kind = KIND[sub]
    if not kind then
        if split and sub == "SPELL_SUMMON" and srcFlags and band(srcFlags, affil) ~= 0
            and band(srcFlags, TYPE_PLAYER) ~= 0 then
            Own(dstGUID, srcName)
        end
        return
    end
    if not srcFlags or not dstFlags or band(srcFlags, affil) == 0 then return end
    local n
    if kind == HEAL then
        if band(dstFlags, affil) == 0 then return end
        n = Amount(a4) - Amount(a5)
        if n <= 0 then return end
        heal[slot] = heal[slot] + n
        healSum = healSum + n
        if not fighting then FightStart() end
        fightHeal = fightHeal + n
    else
        if band(dstFlags, AFFIL_RAID) ~= 0 then return end
        if band(dstFlags, HOSTILE) == 0 then
            local key = ns.NpcKey(dstGUID)
            if not (key and ns.dummies and ns.dummies[key]) then return end
        end
        if band(srcFlags, TYPE_PLAYER) == 0 then
            local key = ns.NpcKey(srcGUID)
            if key and Apart()[key] then return end
        end
        n = Amount(kind == SWING_DMG and a1 or a4)
        if n <= 0 then return end
        dmg[slot] = dmg[slot] + n
        dmgSum = dmgSum + n
        if not fighting then FightStart() end
        fightDmg = fightDmg + n
        if split then Credit(srcGUID, srcName, srcFlags, n) end
    end
    silence = 0
    if span == 0 then span = 1 end
end))
local function Advance()
    slot = slot % WINDOW + 1
    dmgSum = dmgSum - dmg[slot]
    healSum = healSum - heal[slot]
    dmg[slot], heal[slot] = 0, 0
    if dmgSum < 0 then dmgSum = 0 end
    if healSum < 0 then healSum = 0 end
    if span > 0 then
        if dmgSum == 0 and healSum == 0 then
            span = 0
        elseif span < WINDOW then
            span = span + 1
        end
    end
    inRaid = GetNumRaidMembers() > 0
    affil = inRaid and AFFIL_RAID or AFFIL_MINE
    if fighting then
        StepCurve()
        silence = silence + 1
        if silence >= IDLE_END and not GroupFighting() then
            fighting = false
            fightDur = GetTime() - fightAt
        end
    end
end
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = acc - 1
    if acc >= 1 then acc = 0 end
    Advance()
end))
function Meter.Reset()
    for i = 1, WINDOW do
        dmg[i], heal[i] = 0, 0
    end
    slot, dmgSum, healSum, span, acc = 1, 0, 0, 0, 0
    fighting, fightAt, fightDur, fightDmg, fightHeal, silence = false, 0, 0, 0, 0, 0
    ClearCurve()
    wipe(who)
    inRaid = GetNumRaidMembers() > 0
    affil = inRaid and AFFIL_RAID or AFFIL_MINE
end
function Meter.Want(key, on)
    wants[key] = on and true or nil
    on = next(wants) ~= nil
    if on == watching then return end
    watching = on
    if on then
        Meter.Reset()
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        frame:Show()
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        frame:Hide()
    end
end
function Meter.Watch(on)
    Meter.Want("panel", on)
end
function Meter.Split(on)
    on = on and true or false
    if on == split then return end
    split = on
    if on then
        ScanPets()
        frame:RegisterEvent("UNIT_PET")
    else
        frame:UnregisterEvent("UNIT_PET")
        wipe(who)
        wipe(owners)
        ownersN = 0
    end
end
