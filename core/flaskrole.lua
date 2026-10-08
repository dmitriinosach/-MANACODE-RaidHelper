local _, ns = ...
local AURAS = 40
local RANK = { tank = 3, ap = 2, sp = 1 }
local Role = {}
ns.FlaskRole = Role
local F = ns.Flasks
local names = {}
local asked
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
    local map = ns.flaskTalent[class or ""]
    local t = map and ns.Specs.Of(name)
    local kind = t and map[t]
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
    asked = name
    return ns.Specs.Ask(F.UnitOf(name))
end
function Role.Ready()
    local name = asked
    asked = nil
    if not name then return nil end
    ns.Specs.Read()
    if ns.Specs.Last() ~= name then return nil end
    return name
end
F.RoleSource("talent", FromTalents, 3)
F.RoleSource("aura", Role.Aura, 5)
