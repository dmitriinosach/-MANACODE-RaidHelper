local _, ns = ...
local WPN_AURA = 71289
local WPN_WAIT = 1.5
local WPN_STALE = 8
local WPN_FOREIGN = 5
local WPN_RANGE = 1
local WPN_CLASS = { DEATHKNIGHT = true, WARRIOR = true, ROGUE = true, PALADIN = true, SHAMAN = true }
local RecWpn = { AURA = WPN_AURA }
ns.RecWpn = RecWpn
local wpnQueue, wpnAt, wpnName = {}, {}, {}
local wpnGuid, wpnUnit, wpnSent = nil, nil, nil
local foreignUnit, foreignAt = nil, nil
local ownAsk = false
function RecWpn.Forget()
    wipe(wpnQueue)
    wipe(wpnAt)
    wipe(wpnName)
    wpnGuid, wpnUnit, wpnSent = nil, nil, nil
end
local function Asked(unit)
    if not ownAsk then foreignUnit, foreignAt = unit, GetTime() end
end
if type(hooksecurefunc) == "function" and type(NotifyInspect) == "function" then
    hooksecurefunc("NotifyInspect", Asked)
end
function RecWpn.Ask(guid, name)
    if not guid or not name or wpnAt[guid] then return end
    local cls = ns.GetDB().classes[name]
    if not cls then
        local _, c = GetPlayerInfoByGUID(guid)
        cls = c
    end
    if cls and not WPN_CLASS[cls] then return end
    wpnQueue[#wpnQueue + 1] = guid
    wpnAt[guid] = GetTime()
    wpnName[guid] = name
end
local function WpnWrite(guid, mh, oh, rg, why)
    if ns.Store.Live() then
        ns.Store.Append(ns.Recorder.Now(), "FW_WPN", guid, wpnName[guid], 0, nil, nil, 0, mh, oh, rg, why)
    end
    wpnAt[guid], wpnName[guid] = nil, nil
end
local function WpnRead(unit, guid)
    WpnWrite(guid, GetInventoryItemID(unit, 16) or 0, GetInventoryItemID(unit, 17) or 0,
        GetInventoryItemID(unit, 18) or 0, nil)
end
local function WpnDone()
    wpnGuid, wpnUnit, wpnSent = nil, nil, nil
    local back = foreignUnit and foreignAt and GetTime() - foreignAt <= WPN_FOREIGN and foreignUnit or nil
    if back and UnitExists(back) then
        ownAsk = true
        NotifyInspect(back)
        ownAsk = false
    elseif not (InspectFrame and InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end
end
function RecWpn.Ready()
    if not wpnGuid or UnitGUID(wpnUnit) ~= wpnGuid then return end
    if foreignAt and foreignAt > wpnSent then return end
    WpnRead(wpnUnit, wpnGuid)
    WpnDone()
end
local function UnitOf(guid)
    local slots, slotUnit, slotGuid, _, slotPlayer = ns.Recorder.Roster(false)
    for k = 1, slots do
        if slotGuid[k] == guid and slotPlayer[k] then return slotUnit[k] end
    end
    return nil
end
function RecWpn.Step()
    if not wpnGuid and not wpnQueue[1] then return end
    local now = GetTime()
    if wpnGuid then
        if now - wpnSent > WPN_WAIT then
            WpnWrite(wpnGuid, nil, nil, nil, "wait")
            WpnDone()
        end
        return
    end
    local guid = table.remove(wpnQueue, 1)
    if not guid then return end
    local unit = UnitOf(guid)
    if now - (wpnAt[guid] or now) > WPN_STALE then
        WpnWrite(guid, nil, nil, nil, "late")
    elseif not unit then
        WpnWrite(guid, nil, nil, nil, "gone")
    elseif UnitIsUnit(unit, "player") then
        WpnRead("player", guid)
    elseif InspectFrame and InspectFrame:IsShown() then
        WpnWrite(guid, nil, nil, nil, "busy")
    elseif not (CanInspect and CanInspect(unit)) then
        WpnWrite(guid, nil, nil, nil, "deny")
    elseif not CheckInteractDistance(unit, WPN_RANGE) then
        WpnWrite(guid, nil, nil, nil, "far")
    else
        wpnGuid, wpnUnit, wpnSent = guid, unit, now
        ownAsk = true
        NotifyInspect(unit)
        ownAsk = false
    end
end
