local _, ns = ...
local min = math.min
local AURAS = 40
local EVERY = 2
local FIGHT_EVERY = 10
local RB = {}
ns.RaidBuffs = RB
RB.EVERY = EVERY
RB.FIGHT_EVERY = FIGHT_EVERY
local members = {}
local count = 0
local missing = {}
local missOf = {}
local givers = {}
local scanAt
local none = 0
local spellNames = {}
local function SpellName(id)
    local n = spellNames[id]
    if n == nil then
        n = GetSpellInfo(id) or false
        spellNames[id] = n
    end
    return n or nil
end
RB.SpellName = SpellName
function RB.Needs(class, tree)
    local t = ns.raidBuffs.need[class or ""]
    if not t then return {} end
    if tree and t[tree] then return t[tree] end
    local out = {}
    for flag in pairs(t[1]) do
        local all = true
        for i = 2, #t do
            if not t[i][flag] then all = false end
        end
        if all then out[flag] = true end
    end
    return out
end
local function Has(m, list)
    for i = 1, #list do
        local id = list[i]
        if m.ids[id] then return true end
        local n = SpellName(id)
        if n and m.names[n] then return true end
    end
    return false
end
local function Slot(i)
    local m = members[i]
    if not m then
        m = { ids = {}, names = {} }
        members[i] = m
    end
    wipe(m.ids)
    wipe(m.names)
    m.why, m.tree = nil, nil
    return m
end
local function ReadAuras(m, unit)
    for i = 1, AURAS do
        local aura, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then break end
        m.names[aura] = true
        if id then m.ids[id] = true end
    end
end
local function Add(unit)
    local name = UnitName(unit)
    if not name then return end
    count = count + 1
    local m = Slot(count)
    m.name = name
    local _, class = UnitClass(unit)
    m.class = class
    m.tree = ns.Specs and ns.Specs.Of and ns.Specs.Of(name) or nil
    if not UnitIsConnected(unit) then
        m.why = "offline"
    elseif UnitIsDeadOrGhost(unit) then
        m.why = "dead"
    elseif not UnitIsVisible(unit) then
        m.why = "far"
    else
        ReadAuras(m, unit)
    end
end
local function Lack(key, id, m)
    local e = missOf[key]
    if not e then
        e = { key = key, id = id, who = {} }
        missOf[key] = e
    end
    e.who[#e.who + 1] = m
end
local function CountGivers()
    local defs = ns.raidBuffs.raid
    for i = 1, #defs do givers[defs[i].key] = 0 end
    givers.paladin = 0
    for i = 1, count do
        local m = members[i]
        if m.why ~= "offline" then
            for k = 1, #defs do
                local d = defs[k]
                if m.class == d.cls and (not d.tree or m.tree == d.tree) then givers[d.key] = givers[d.key] + 1 end
            end
            if m.class == ns.raidBuffs.paladin then givers.paladin = givers.paladin + 1 end
        end
    end
end
local function LackRaid(m, need)
    local defs = ns.raidBuffs.raid
    for i = 1, #defs do
        local d = defs[i]
        if givers[d.key] > 0 and (not d.need or need[d.need]) and not Has(m, d.auras) then
            Lack(d.key, d.auras[1], m)
        end
    end
end
local want = {}
local function LackBless(m, need)
    local pals = givers.paladin
    if pals == 0 then return end
    local defs = ns.raidBuffs.bless
    local asked, have, lacks = 0, 0, 0
    for i = 1, #defs do
        local d = defs[i]
        local on = Has(m, d.auras)
        if d.extra then
            if on then have = have + 1 end
        elseif not d.need or need[d.need] then
            asked = asked + 1
            if on then
                have = have + 1
            else
                lacks = lacks + 1
                want[lacks] = d
            end
        end
    end
    for i = 1, min(min(pals, asked) - have, lacks) do
        local d = want[i]
        Lack(d.key, d.auras[1], m)
    end
end
local function Order()
    local at = 0
    for _, list in ipairs({ ns.raidBuffs.raid, ns.raidBuffs.bless }) do
        for i = 1, #list do
            local e = missOf[list[i].key]
            if e and #e.who > 0 then
                at = at + 1
                missing[at] = e
            end
        end
    end
end
local function Scan()
    count = 0
    local n = GetNumRaidMembers() or 0
    if n > 0 then
        for i = 1, n do Add(ns.Units.raid[i]) end
    else
        Add("player")
        for i = 1, GetNumPartyMembers() or 0 do Add(ns.Units.party[i]) end
    end
    for i = count + 1, #members do members[i] = nil end
    for i = #missing, 1, -1 do missing[i] = nil end
    for _, e in pairs(missOf) do wipe(e.who) end
    CountGivers()
    none = 0
    for i = 1, count do
        local m = members[i]
        if m.why then
            none = none + 1
        else
            local need = RB.Needs(m.class, m.tree)
            LackRaid(m, need)
            LackBless(m, need)
        end
    end
    Order()
    scanAt = GetTime()
end
local function Grouped()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end
function RB.Tick(force)
    if not Grouped() then
        RB.Watch(false)
        return false
    end
    local now = GetTime()
    local every = UnitAffectingCombat("player") and FIGHT_EVERY or EVERY
    if not force and scanAt and now - scanAt < every then return false end
    Scan()
    return true
end
function RB.Watch(on)
    if on then return end
    scanAt = nil
    count, none = 0, 0
    for i = #members, 1, -1 do members[i] = nil end
    for i = #missing, 1, -1 do missing[i] = nil end
end
function RB.Counts()
    return #missing, count - none, none, scanAt ~= nil
end
function RB.Missing()
    return missing
end
function RB.Members()
    return members
end
function RB.Age()
    return scanAt and (GetTime() - scanAt) or nil
end
