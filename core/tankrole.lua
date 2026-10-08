local _, ns = ...
local tonumber = tonumber
local tsort = table.sort
local SpellOf = ns.SpellOf
local TANK_SHARE = 0.15
local TANK_SHARE_STRICT = 0.25
local TAUNT_TAKEN_SHARE = 0.08
local TAKEN_SHARE_STRICT = 0.16
local TANK_CASTS = 5
local TANK_TAUNTS = 3
local TANK_MAX = 3
local TANK_HOLD = 0.3
local TANK_SUB = "FW_TANKSNAP"
local TANK_KINDS = { "strong", "mt", "unseen" }
local TR = {}
ns.TankRole = TR
TR.SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_REMOVED = true, [TANK_SUB] = true }
function TR.Feed(s, byName, boss, ts, sub, dstName, a1, a2, a3, a4, a5, a6, a7)
    if sub == TANK_SUB then
        local marks = { a1, a2, a3 }
        for k = 1, #TANK_KINDS do
            for name in tostring(marks[k] or ""):gmatch("[^,]+") do
                local p = byName[name]
                if p then
                    s.tankSnap = true
                    if p.tankSnap ~= "mt" and p.tankSnap ~= "strong" then p.tankSnap = TANK_KINDS[k] end
                end
            end
        end
        local verdicts = { { a4, "tankSpec", true }, { a5, "tankSpec", false }, { a6, "tankGear", true },
            { a7, "tankGear", false } }
        for k = 1, #verdicts do
            local v = verdicts[k]
            for name in tostring(v[1] or ""):gmatch("[^,]+") do
                local p = byName[name]
                if p then p[v[2]] = v[3] end
            end
        end
        return
    end
    local p = dstName and byName[dstName]
    if not p then return end
    local auras = ns.tankAuras and ns.tankAuras[boss]
    local sk = auras and SpellOf(sub, a1)
    if sk and auras[sk] then
        if sub == "SPELL_AURA_REMOVED" then
            if p.tankAuraAt then p.tankHold = (p.tankHold or 0) + ts - p.tankAuraAt end
            p.tankAuraAt = nil
        elseif not p.tankAuraAt then
            p.tankAuraAt = math.max(ts, s.from)
        end
    end
    local sg = ns.tankSigns and ns.tankSigns[tonumber(a1)]
    if sg and sub ~= "SPELL_AURA_REMOVED" and p.class == sg.class then
        p.tankSign = "strong"
        if sub == "SPELL_AURA_APPLIED" and ts >= s.from then p.tankOn = true end
    end
end
local function Bare(cls)
    if not cls or not ns.tankSpec or not ns.tankSpec.classes[cls] then return false end
    for _, sg in pairs(ns.tankSigns) do
        if sg.class == cls then return false end
    end
    return true
end
function TR.Is(s, p, melee, taken)
    if (p.tankHold or 0) >= TANK_HOLD * s.dur then return true end
    if p.tankSpec ~= nil then return p.tankSpec end
    if p.tankGear ~= nil then return p.tankGear end
    local share = melee > 0 and p.bossMelee / melee or 0
    local took = taken > 0 and p.npcTaken / taken or 0
    local mark = p.tankSnap
    if p.taunts >= TANK_TAUNTS and p.tankCasts >= TANK_CASTS then return true end
    if s.tankSnap then
        if mark == "strong" or mark == "mt" then return true end
        if p.tankOn and (share >= TANK_SHARE or took >= TAUNT_TAKEN_SHARE) then return true end
        if mark ~= "unseen" and not Bare(p.class) then return false end
    end
    if p.tankCasts >= TANK_CASTS or (p.tankSign and share >= TANK_SHARE) then return true end
    return p.taunts > 0 and (p.tankCasts > 0 or share >= TANK_SHARE_STRICT or took >= TAKEN_SHARE_STRICT)
end
local function MoreTank(a, b)
    if a.bossMelee ~= b.bossMelee then return a.bossMelee > b.bossMelee end
    if a.tankCasts ~= b.tankCasts then return a.tankCasts > b.tankCasts end
    return a.npcTaken > b.npcTaken
end
function TR.Roles(s)
    local melee = 0
    local taken = 0
    for i = 1, #s.players do
        local p = s.players[i]
        melee = melee + p.bossMelee
        taken = taken + p.npcTaken
        if p.tankAuraAt then
            p.tankHold = (p.tankHold or 0) + math.max(0, s.from + s.dur - p.tankAuraAt)
            p.tankAuraAt = nil
        end
    end
    local tanks = {}
    for i = 1, #s.players do
        local p = s.players[i]
        if TR.Is(s, p, melee, taken) then
            tanks[#tanks + 1] = p
        elseif p.heal > p.dmg then
            p.role = "heal"
        end
    end
    tsort(tanks, MoreTank)
    for i = 1, #tanks do
        local p = tanks[i]
        if i <= TANK_MAX then
            p.role = "tank"
        elseif p.heal > p.dmg then
            p.role = "heal"
        end
    end
end
