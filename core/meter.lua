local _, ns = ...
local band = bit.band
local WINDOW = 30
local IDLE_END = 3
local AFFIL_RAID = 0x7
local AFFIL_MINE = 0x1
local FRIENDLY = 0x10
local SPELL_DMG = 1
local SWING_DMG = 2
local HEAL = 3
local CURVE_MAX = 64
local KIND = {
    SWING_DAMAGE = SWING_DMG,
    RANGE_DAMAGE = SPELL_DMG,
    SPELL_DAMAGE = SPELL_DMG,
    SPELL_PERIODIC_DAMAGE = SPELL_DMG,
    DAMAGE_SHIELD = SPELL_DMG,
    DAMAGE_SPLIT = SPELL_DMG,
    SPELL_HEAL = HEAL,
    SPELL_PERIODIC_HEAL = HEAL,
}
local Meter = { dmg = {}, heal = {}, curve = {} }
ns.Meter = Meter
local dmg, heal, curve = Meter.dmg, Meter.heal, Meter.curve
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
local fighting = false
local fightAt, fightDur = 0, 0
local fightDmg, fightHeal = 0, 0
local silence = 0
local curveStep, curveTick = 1, 0
local frame = CreateFrame("Frame")
frame:Hide()
local seenAll = 0
local counter = CreateFrame("Frame")
counter:SetScript("OnEvent", function() seenAll = seenAll + 1 end)
counter:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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
local function FightStart()
    fighting = true
    fightAt = GetTime()
    fightDmg, fightHeal = 0, 0
    ClearCurve()
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
frame:SetScript("OnEvent", function(_, _, _, sub, _, _, srcFlags, _, _, dstFlags, a1, _, _, a4, a5)
    local kind = KIND[sub]
    if not kind or not srcFlags or not dstFlags or band(srcFlags, affil) == 0 then return end
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
        if band(dstFlags, FRIENDLY) ~= 0 then return end
        n = Amount(kind == SWING_DMG and a1 or a4)
        if n <= 0 then return end
        dmg[slot] = dmg[slot] + n
        dmgSum = dmgSum + n
        if not fighting then FightStart() end
        fightDmg = fightDmg + n
    end
    silence = 0
    if span == 0 then span = 1 end
end)
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
        if silence >= IDLE_END and not UnitAffectingCombat("player") then
            fighting = false
            fightDur = GetTime() - fightAt
        end
    end
end
frame:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = acc - 1
    if acc >= 1 then acc = 0 end
    Advance()
end)
function Meter.Reset()
    for i = 1, WINDOW do
        dmg[i], heal[i] = 0, 0
    end
    slot, dmgSum, healSum, span, acc = 1, 0, 0, 0, 0
    fighting, fightAt, fightDur, fightDmg, fightHeal, silence = false, 0, 0, 0, 0, 0
    ClearCurve()
    inRaid = GetNumRaidMembers() > 0
    affil = inRaid and AFFIL_RAID or AFFIL_MINE
end
function Meter.Watch(on)
    on = on and true or false
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
