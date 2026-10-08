local _, ns = ...
local concat = table.concat
local tonumber = tonumber
local SUB = "FW_SPEC"
local SEP = ","
local TREES = 3
local MAX_RAID = 40
local MAX_PARTY = 4
local STEP = 1.5
local WAIT = 4
local RETRY = 60
local REFRESH = 300
local RANGE = 1
local OFF_HAND = 17
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local DEF_KEYS = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING" }
local STR_KEY = "ITEM_MOD_STRENGTH_SHORT"
local SP_KEY = "ITEM_MOD_SPELL_POWER_SHORT"
local SHIELD = "INVTYPE_SHIELD"
local Specs = {}
ns.Specs = Specs
Specs.SUB = SUB
Specs.SEP = SEP
local RAID, PARTY = {}, {}
for i = 1, MAX_RAID do RAID[i] = "raid" .. i end
for i = 1, MAX_PARTY do PARTY[i] = "party" .. i end
local tree = {}
local seenAt = {}
local gearOf = {}
local tried = {}
local readers = {}
local wants = {}
local askUnit, askGuid, doneGuid, doneName
local pend, pendAt
local acc = 0
local stats = {}
local function Top(inspect)
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect, false) or nil
    local best, top = nil, 0
    for tab = 1, TREES do
        local _, _, pts = GetTalentTabInfo(tab, inspect, false, group)
        pts = tonumber(pts) or 0
        if pts > top then best, top = tab, pts end
    end
    return best
end
local function Stats(link)
    if not GetItemStats then return nil end
    wipe(stats)
    return GetItemStats(link, stats)
end
function Specs.Gear(unit)
    local out = { def = 0 }
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        local link = GetInventoryItemLink(unit, slot)
        local st = link and Stats(link)
        if st then
            for k = 1, #DEF_KEYS do out.def = out.def + (tonumber(st[DEF_KEYS[k]]) or 0) end
            if slot == OFF_HAND then
                local loc = select(9, GetItemInfo(link))
                if (tonumber(st[SP_KEY]) or 0) > 0 then
                    out.off = "sp"
                elseif loc == SHIELD and (tonumber(st[STR_KEY]) or 0) > 0 then
                    out.off = "str"
                end
            end
        end
    end
    return out
end
local function Asked(unit)
    askUnit = unit
    askGuid = unit and UnitGUID(unit) or nil
    doneGuid, doneName = nil, nil
end
function Specs.Read()
    local unit = askUnit
    if not unit or not askGuid or UnitGUID(unit) ~= askGuid then return false end
    local name = UnitName(unit)
    if not name then return false end
    if doneGuid ~= askGuid then
        doneGuid, doneName = askGuid, name
        local _, cls = UnitClass(unit)
        if cls and ns.tankSpec and ns.tankSpec.classes[cls] then gearOf[name] = Specs.Gear(unit) end
        local t = Top(true)
        if t then
            tree[name], seenAt[name] = t, GetTime()
            for i = 1, #readers do readers[i](unit, name) end
        end
    end
    local mine = pend == name
    if mine then pend = nil end
    return mine
end
function Specs.Last()
    return doneName
end
function Specs.OnRead(fn)
    readers[#readers + 1] = fn
end
function Specs.Want(fn)
    wants[#wants + 1] = fn
end
function Specs.Wake()
    acc = STEP
    if Specs.frame and not InCombatLockdown() then Specs.frame:Show() end
end
function Specs.Swap(name)
    if not name or not tree[name] then return end
    tree[name], seenAt[name], gearOf[name] = nil, nil, nil
    if Specs.frame then Specs.frame:Show() end
end
function Specs.Of(name)
    if name == UnitName("player") then return Top(false) end
    return tree[name]
end
function Specs.GearOf(name)
    if name == UnitName("player") then return Specs.Gear("player") end
    return gearOf[name]
end
function Specs.At(name)
    return seenAt[name]
end
local function InspectOpen()
    return InspectFrame ~= nil and InspectFrame:IsShown() and true or false
end
function Specs.Ask(unit)
    if not unit or InspectOpen() or InCombatLockdown() then return false end
    if CanInspect and not CanInspect(unit, false) then return false end
    local name = UnitName(unit)
    if not name then return false end
    pend, pendAt = name, GetTime()
    NotifyInspect(unit)
    return askUnit == unit
end
local healTrees
local function HealTrees()
    if healTrees then return healTrees end
    local classes = ns.Lead and ns.Lead.CLASSES
    if type(classes) ~= "table" then return nil end
    healTrees = {}
    for _, c in ipairs(classes) do
        local set = {}
        for _, sp in ipairs(c.specs or {}) do
            if sp.role == "heal" and sp.tree then set[sp.tree] = true end
        end
        healTrees[c.token] = set
    end
    return healTrees
end
function Specs.Healer(name, class)
    local S = ns.Lead and ns.Lead.Session
    if S and S.FlaskRole then
        local ok, role = pcall(S.FlaskRole, name)
        if ok and role then return role == "heal" end
    end
    local trees = HealTrees()
    local set = trees and class and trees[class]
    if not set then return nil end
    if not next(set) then return false end
    local t = tree[name]
    if not t and name == UnitName("player") then t = Top(false) end
    if not t then return nil end
    return set[t] == true
end
local function Units()
    local out, n = {}, GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do out[i] = RAID[i] end
        return out
    end
    out[1] = "player"
    for i = 1, GetNumPartyMembers() do out[i + 1] = PARTY[i] end
    return out
end
function Specs.Take(ts)
    local by = {}
    for k = 1, TREES do by[k] = {} end
    local us, any = Units(), false
    for i = 1, #us do
        local name = UnitName(us[i])
        local t = name and Specs.Of(name)
        if t then
            local list = by[t]
            list[#list + 1] = name
            any = true
        end
    end
    if not any then return end
    ns.Store.Append(ts, SUB, nil, nil, 0, nil, nil, 0, concat(by[1], SEP), concat(by[2], SEP), concat(by[3], SEP))
end
function Specs.Parse(a1, a2, a3)
    local out, cols = {}, { a1, a2, a3 }
    for k = 1, TREES do
        local s = cols[k]
        if type(s) == "string" then
            for name in s:gmatch("[^" .. SEP .. "]+") do out[name] = k end
        end
    end
    return out
end
function Specs.Feed(byName, a1, a2, a3)
    for name, t in pairs(Specs.Parse(a1, a2, a3)) do
        local p = byName[name]
        if p then p.tree = t end
    end
end
local function Wanted()
    for i = 1, #wants do
        if wants[i]() then return true end
    end
    local R = ns.Recorder
    if not (R and R.IsOn() and not R.IsPaused() and R.InZone()) then return false end
    if GetNumRaidMembers() == 0 then return false end
    local live = ns.Store.Live()
    return not (live and live.pull)
end
local function Next(now)
    local due, best, bestName, bestAt = false, nil, nil, nil
    local us = Units()
    for i = 1, #us do
        local u = us[i]
        local name = UnitName(u)
        local at = name and seenAt[name] or -1
        if name and not UnitIsUnit(u, "player") and (at < 0 or now - at > REFRESH) and UnitIsConnected(u) then
            due = true
            if (not bestAt or at < bestAt) and (not tried[name] or now - tried[name] > RETRY)
                and (not CanInspect or CanInspect(u)) and CheckInteractDistance(u, RANGE) then
                best, bestName, bestAt = u, name, at
            end
        end
    end
    return best, bestName, due
end
local function Tick(self, dt)
    acc = acc + dt
    if acc < STEP then return end
    acc = 0
    if InCombatLockdown() or not Wanted() then
        self:Hide()
        return
    end
    if InspectOpen() then return end
    local now = GetTime()
    if pend and now - pendAt < WAIT then return end
    pend = nil
    local u, name, due = Next(now)
    if not u then
        if not due then self:Hide() end
        return
    end
    pend, pendAt, tried[name] = name, now, now
    NotifyInspect(u)
end
local function OnEvent(self, event)
    if event == "INSPECT_TALENT_READY" then
        if Specs.Read() and not InspectOpen() then ClearInspectPlayer() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        self:Hide()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then wipe(tried) end
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then acc = STEP end
    if not InCombatLockdown() then self:Show() end
end
local frame = CreateFrame("Frame")
Specs.frame = frame
frame:Hide()
frame:SetScript("OnUpdate", ns.Prof.Wrap("bg.specs", Tick))
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.specs", OnEvent))
frame:RegisterEvent("INSPECT_TALENT_READY")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
if type(hooksecurefunc) == "function" and type(NotifyInspect) == "function" then
    hooksecurefunc("NotifyInspect", Asked)
end
