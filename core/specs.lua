local _, ns = ...
local concat = table.concat
local tonumber = tonumber
local SUB = "FW_SPEC"
local SEP = ","
local TREES = 3
local MAX_RAID = 40
local MAX_PARTY = 4
local STEP = 3
local WAIT = 4
local RETRY = 60
local REFRESH = 1800
local RANGE = 1
local Specs = {}
ns.Specs = Specs
Specs.SUB = SUB
Specs.SEP = SEP
local RAID, PARTY = {}, {}
for i = 1, MAX_RAID do RAID[i] = "raid" .. i end
for i = 1, MAX_PARTY do PARTY[i] = "party" .. i end
local tree = {}
local seenAt = {}
local tried = {}
local askUnit, askGuid
local pend, pendAt
local acc = 0
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
local function Asked(unit)
    askUnit = unit
    askGuid = unit and UnitGUID(unit) or nil
end
local function Read()
    local unit = askUnit
    if not unit or not askGuid or UnitGUID(unit) ~= askGuid then return false end
    local name = UnitName(unit)
    local mine = name ~= nil and pend == name
    if mine then pend = nil end
    local t = name and Top(true)
    if t then tree[name], seenAt[name] = t, GetTime() end
    return mine
end
function Specs.Swap(name)
    if not name or not tree[name] then return end
    tree[name], seenAt[name] = nil, nil
    if Specs.frame then Specs.frame:Show() end
end
function Specs.Of(name)
    return tree[name]
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
    local me = UnitName("player")
    local us, any = Units(), false
    for i = 1, #us do
        local name = UnitName(us[i])
        local t = name and (name == me and Top(false) or tree[name])
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
    local R = ns.Recorder
    if not (R and R.IsOn() and not R.IsPaused() and R.InZone()) then return false end
    if GetNumRaidMembers() == 0 then return false end
    local live = ns.Store.Live()
    return not (live and live.pull)
end
local function Busy()
    if InspectFrame and InspectFrame:IsShown() then return true end
    local S = ns.Lead and ns.Lead.Session
    return S ~= nil and S.Active ~= nil and S.Active() == true
end
local function Next(now)
    local due = false
    for i = 1, GetNumRaidMembers() do
        local u = RAID[i]
        local name = UnitName(u)
        if name and not UnitIsUnit(u, "player") and (not seenAt[name] or now - seenAt[name] > REFRESH)
            and UnitIsConnected(u) then
            due = true
            if (not tried[name] or now - tried[name] > RETRY) and CanInspect(u)
                and CheckInteractDistance(u, RANGE) then
                return u, name, true
            end
        end
    end
    return nil, nil, due
end
local function Tick(self, dt)
    acc = acc + dt
    if acc < STEP then return end
    acc = 0
    if InCombatLockdown() or not Wanted() then
        self:Hide()
        return
    end
    if Busy() then return end
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
        if Read() and not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        self:Hide()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        wipe(tree)
        wipe(seenAt)
        wipe(tried)
    end
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
if type(hooksecurefunc) == "function" and type(NotifyInspect) == "function" then
    hooksecurefunc("NotifyInspect", Asked)
end
