local _, ns = ...
local MANA = 0
local MODES = { "off", "heal", "all" }
local DEFAULT = "heal"
local RecMana = { MODES = MODES, DEFAULT = DEFAULT }
ns.RecMana = RecMana
local polled, polledMax = {}, {}
function RecMana.Mode()
    local v = ns.GetDB().settings.recMana
    if v == "off" or v == "all" or v == "heal" then return v end
    return DEFAULT
end
function RecMana.SetMode(mode)
    if mode ~= "off" and mode ~= "all" then mode = DEFAULT end
    ns.GetDB().settings.recMana = mode ~= DEFAULT and mode or nil
end
function RecMana.Wanted(name, unit)
    local mode = RecMana.Mode()
    if mode == "off" then return false end
    if mode == "all" then return true end
    local _, class = UnitClass(unit)
    return ns.Specs.Healer(name, class) == true
end
function RecMana.Put(live, unit, name, now, force)
    if not (UnitPowerType and UnitPower and UnitPowerMax) then return end
    if UnitPowerType(unit) ~= MANA then return end
    local mp, mpMax = UnitPower(unit, MANA) or 0, UnitPowerMax(unit, MANA) or 0
    if mpMax <= 0 then return end
    if force or polled[name] ~= mp or polledMax[name] ~= mpMax then
        polled[name], polledMax[name] = mp, mpMax
        ns.RecCodec.Mana(live, now, name, mp, mpMax, force)
    end
end
function RecMana.Reset()
    wipe(polled)
    wipe(polledMax)
end
