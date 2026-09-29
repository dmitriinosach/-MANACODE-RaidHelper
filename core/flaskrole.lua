local _, ns = ...
local tonumber = tonumber
local AURAS = 40
local RANK = { tank = 3, ap = 2, sp = 1 }
local Role = {}
ns.FlaskRole = Role
local F = ns.Flasks
local talents = {}
local names = {}
local asked
local seen
local function Names(class)
    local out = names[class]
    if out then return out end
    out = {}
    for id, kind in pairs(ns.flaskStance[class]) do
        local name = GetSpellInfo(id)
        if name then out[name] = kind end
    end
    names[class] = out
    return out
end
function Role.Aura(name, class)
    local map = ns.flaskStance[class or ""]
    if not map then return nil end
    local unit = F.UnitOf(name)
    local best
    for i = 1, AURAS do
        local aura, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then break end
        local kind
        if id then kind = map[id] else kind = Names(class)[aura] end
        if kind and (not best or RANK[kind] > RANK[best]) then best = kind end
    end
    return best
end
local function FromTalents(name, class)
    local kind = talents[name]
    if kind == "form" then return Role.Aura(name, class) end
    return kind
end
local function InspectOpen()
    local f = InspectFrame
    return f ~= nil and f.IsShown ~= nil and f:IsShown() and true or false
end
function Role.Want(name)
    if F.Journal().hand[name] then return false end
    return ns.flaskTalent[F.ClassOf(name) or ""] ~= nil
end
function Role.Ask(name)
    if InspectOpen() then return false end
    local unit = F.UnitOf(name)
    if CanInspect and not CanInspect(unit, false) then return false end
    asked = name
    NotifyInspect(unit)
    return seen == name
end
function Role.Ready()
    local name = asked
    asked = nil
    if not name or seen ~= name then return nil end
    local map = ns.flaskTalent[F.ClassOf(name) or ""]
    if not map then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup(true) or nil
    local best, top = nil, 0
    for tab = 1, #map do
        local _, _, points = GetTalentTabInfo(tab, true, false, group)
        points = tonumber(points) or 0
        if points > top then best, top = tab, points end
    end
    if not InspectOpen() and ClearInspectPlayer then ClearInspectPlayer() end
    if best then talents[name] = map[best] end
    return name
end
local function Seen(unit)
    seen = unit and UnitName(unit) or nil
end
hooksecurefunc("NotifyInspect", Seen)
F.RoleSource("talent", FromTalents, 3)
F.RoleSource("aura", Role.Aura, 5)
