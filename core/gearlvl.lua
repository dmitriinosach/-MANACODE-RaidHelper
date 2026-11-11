local _, ns = ...
local concat = table.concat
local tonumber = tonumber
local min = math.min
local SUB = "FW_GEAR"
local SEP = ","
local PART = ":"
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local OFF_HAND = 17
local RANGED = 18
local TWO_HAND = "INVTYPE_2HWEAPON"
local RELIC = "INVTYPE_RELIC"
local TRIES = 3
local SLOT_NAME = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", nil, "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "WRISTSLOT",
    "HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT",
    "SECONDARYHANDSLOT", "RANGEDSLOT" }
local Gear = {}
ns.GearLvl = Gear
Gear.SUB = SUB
local seen = {}
local miss = {}
local since = 0
function Gear.Scan(unit)
    local out = {}
    local any, twoHand = false, false
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        local link = GetInventoryItemLink(unit, slot)
        local item = link or (GetInventoryItemID and GetInventoryItemID(unit, slot)) or nil
        local lvl = 0
        if item then
            local _, _, _, ilvl, _, _, _, _, loc = GetItemInfo(item)
            ilvl = tonumber(ilvl)
            if not ilvl then return nil, true end
            any = true
            lvl = ilvl
            if loc == TWO_HAND then twoHand = true end
            if loc == RELIC then
                out.relic = ilvl
                lvl = nil
            end
        elseif slot == OFF_HAND and twoHand then
            lvl = nil
        end
        if lvl and (not out.min or lvl < out.min) then out.min, out.slot = lvl, slot end
    end
    if not any or not out.min then return nil end
    return out
end
local function OnRead(unit, name)
    local g, uncached = Gear.Scan(unit)
    if g then
        g.at = GetTime()
        seen[name], miss[name] = g, nil
    else
        seen[name] = nil
        miss[name] = uncached and (miss[name] or 0) + 1 or TRIES
    end
end
local function Need(name)
    local g = seen[name]
    if g then return g.at < since end
    return (miss[name] or 0) < TRIES
end
function Gear.Arm()
    since = GetTime()
    for name in pairs(miss) do miss[name] = nil end
    local S = ns.Specs
    if S and S.frame and not InCombatLockdown() then S.frame:Show() end
end
function Gear.Of(name)
    if name == UnitName("player") then return (Gear.Scan("player")) end
    local g = seen[name]
    if g and g.at >= since then return g end
    return nil
end
local function Item(name, g)
    local s = name .. PART .. g.min .. PART .. g.slot
    if g.relic then s = s .. PART .. g.relic end
    return s
end
function Gear.Pull(ts, enc)
    local raid = ns.Raid and ns.Raid.Current()
    local map = raid and (raid.map or ns.Raid.MapNow())
    local last = map and ns.raidEp and ns.raidEp.END[map]
    if not last or tonumber(enc) ~= last then return end
    local list = {}
    for i = 1, GetNumRaidMembers() do
        local name = GetRaidRosterInfo(i)
        local g = name and Gear.Of(name)
        if g then list[#list + 1] = Item(name, g) end
    end
    if not list[1] then return end
    ns.Store.Append(ts, SUB, nil, nil, 0, nil, nil, 0, concat(list, SEP))
end
function Gear.Parse(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for item in text:gmatch("[^" .. SEP .. "]+") do
        local name, lvl, slot, relic = item:match("^([^" .. PART .. "]+)" .. PART .. "(%d+)" .. PART .. "(%d+)" .. PART .. "?(%d*)$")
        if name then out[name] = { min = tonumber(lvl), slot = tonumber(slot), relic = tonumber(relic) } end
    end
    return out
end
function Gear.Check(g, need, relicMax)
    if g.min < need then return false, g.slot, g.min end
    if g.relic and g.relic < min(need, relicMax or need) then return false, RANGED, g.relic end
    return true
end
function Gear.SlotName(slot)
    local key = slot and SLOT_NAME[slot]
    local text = key and _G[key]
    return type(text) == "string" and text or tostring(slot or "?")
end
if ns.Specs then
    ns.Specs.OnRead(OnRead)
    ns.Specs.Need(Need)
end
