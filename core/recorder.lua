local _, ns = ...
local floor = math.floor
local band = bit.band
local find = string.find
local KILL_GRACE = 2
local AUTO_WAIT = 10
local IDLE_CLOSE = 10
local SCRIPT_HOLD = 180
local SNAP_PERIOD = 0.2
local POS_PERIOD = 0.25
local MAP_PERIOD = 1
local KEY_PERIOD = 5
local CLOCK_HOLD = 2
local CLOCK_BACK = 1
local TICK_PERIOD = 0.5
local BOSS_PERIOD = 1
local RING_PERIOD = 1
local PULL_MUTE = 30
local MAX_RAID = 40
local MAX_PARTY = 4
local F_PLAYER = 0x400
local F_BY_PLAYER = 0x100
local F_GROUP = 0x07
local WPN_AURA = 71289
local WPN_WAIT = 1.5
local WPN_STALE = 8
local WPN_FOREIGN = 5
local WPN_RANGE = 1
local WPN_CLASS = { DEATHKNIGHT = true, WARRIOR = true, ROGUE = true, PALADIN = true, SHAMAN = true }
local ACH_EVENTS = { "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT" }
local ACH_LINK = "|Hachievement:(%d+):"
local ACH_DUP = 30
local ASKED_MAX = 4096
local ACH_MAX = 512
local Recorder = {}
ns.Recorder = Recorder
local frame = CreateFrame("Frame")
frame:Hide()
local RAID, RAID_PET, RAID_TARGET = {}, {}, {}
local TARGET_OF = { target = "targettarget", focus = "focustarget" }
for i = 1, MAX_RAID do
    RAID[i] = "raid" .. i
    RAID_PET[i] = "raid" .. i .. "pet"
    RAID_TARGET[i] = "raid" .. i .. "target"
    TARGET_OF[RAID_TARGET[i]] = RAID_TARGET[i] .. "target"
end
local PARTY, PARTY_PET, PARTY_TARGET = {}, {}, {}
for i = 1, MAX_PARTY do
    PARTY[i] = "party" .. i
    PARTY_PET[i] = "partypet" .. i
    PARTY_TARGET[i] = "party" .. i .. "target"
    TARGET_OF[PARTY_TARGET[i]] = PARTY_TARGET[i] .. "target"
end
local ROSTER_EVENTS = { "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_PET", "UNIT_NAME_UPDATE" }
local isOn = false
local inZone = false
local writeAll = false
local snapElapsed = 0
local tickElapsed = 0
local mapElapsed = MAP_PERIOD
local keyElapsed = KEY_PERIOD
local bossElapsed = 0
local ringElapsed = 0
local posElapsed = POS_PERIOD
local frameHp, framePos = true, true
local bossTarget, bossTick = {}, {}
local polledHp, polledMax, polledX, polledY = {}, {}, {}, {}
local bossRound = 0
local inVehicle = {}
local vehicleFight = false
local auraStacks = {}
local clockOff = nil
local clockAt = 0
local lastNow = 0
local seen, kept = 0, 0
local slotUnit, slotGuid, slotName, slotPlayer, slotPet = {}, {}, {}, {}, {}
local slots = 0
local rosterDirty = true
local mapArea, mapLevel, mapName = nil, nil, nil
local goodArea, goodLevel = nil, nil
local levelOk = true
local levelProbes, levelFixes = 0, 0
local fighting = false
local calmAt = nil
local seenIdle = true
local hadFight = false
local killAt, killEnd, killSure, killEnc = nil, nil, false, nil
local scriptHold = nil
local dead = {}
local bossSeen = {}
local closed = { why = nil, enc = nil, at = nil, mute = nil }
local wpnQueue, wpnAt, wpnName = {}, {}, {}
local wpnGuid, wpnUnit, wpnSent = nil, nil, nil
local foreignUnit, foreignAt = nil, nil
local ownAsk = false
local achSeen = {}
local achN = 0
local paused = false
local pauseWaitIdle = false
local pauseZone = nil
local pauseLeft = false
local ZONE_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }
local function Now()
    local t = clockOff and GetTime() + clockOff or time()
    if t < lastNow and t > lastNow - CLOCK_BACK then t = lastNow end
    lastNow = t
    return t
end
Recorder.Now = Now
local function Anchor(ts)
    local g = GetTime()
    local off = ts - g
    if not clockOff or off <= clockOff or g - clockAt > CLOCK_HOLD then
        clockOff, clockAt = off, g
    end
end
function Recorder.IsOn()
    return isOn
end
function Recorder.IsPaused()
    return paused
end
function Recorder.Counts()
    return seen, kept
end
function Recorder.MapLevel()
    return goodLevel, levelProbes, levelFixes
end
local function WatchRoster(on)
    for i = 1, #ROSTER_EVENTS do
        if on then
            frame:RegisterEvent(ROSTER_EVENTS[i])
        else
            frame:UnregisterEvent(ROSTER_EVENTS[i])
        end
    end
    rosterDirty = true
end
local function ForgetKill()
    killAt, killEnd, killSure, killEnc = nil, nil, false, nil
end
local function Listen(on)
    if on then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        frame:RegisterEvent("INSPECT_TALENT_READY")
        for i = 1, #ACH_EVENTS do frame:RegisterEvent(ACH_EVENTS[i]) end
    else
        for i = 1, #ACH_EVENTS do frame:UnregisterEvent(ACH_EVENTS[i]) end
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        frame:UnregisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        frame:UnregisterEvent("INSPECT_TALENT_READY")
    end
    WatchRoster(on)
end
local function ForgetWpn()
    wipe(wpnQueue)
    wipe(wpnAt)
    wipe(wpnName)
    wpnGuid, wpnUnit, wpnSent = nil, nil, nil
end
local function CloseSegment(why, enc)
    ForgetKill()
    scriptHold = nil
    wipe(dead)
    wipe(bossSeen)
    vehicleFight = false
    hadFight = false
    seenIdle = not fighting
    if not ns.Store.Live() then return end
    closed.why, closed.enc, closed.at = why, enc, time()
    closed.mute = why == "kill" and enc and GetTime() + PULL_MUTE or nil
    ns.Raid.Touch(ns.Store.Live())
    ns.Store.Close()
    if why == "kill" and RequestRaidInfo then RequestRaidInfo() end
    if why == "kill" and ns.AutoRec and ns.AutoRec.Killed then ns.AutoRec.Killed(enc) end
end
function Recorder.LastClose()
    return closed.why, closed.enc, closed.at
end
local function WatchZone(on)
    for i = 1, #ZONE_EVENTS do
        if on then
            frame:RegisterEvent(ZONE_EVENTS[i])
        else
            frame:UnregisterEvent(ZONE_EVENTS[i])
        end
    end
end
local function ZoneWanted()
    local _, kind = GetInstanceInfo()
    if kind == "raid" then return true end
    return kind == "party" and ns.GetDB().settings.autoParty == true
end
local function Zone()
    inZone = ZoneWanted()
    if not inZone and ns.Store.Live() then CloseSegment("zone", nil) end
end
function Recorder.InZone()
    return inZone
end
function Recorder.Start()
    if isOn then
        return
    end
    local db = ns.GetDB()
    isOn = true
    db.recording = true
    db.settings.autoRaid = true
    writeAll = ns.RecFilter.All()
    seen, kept = 0, 0
    fighting, seenIdle, hadFight, calmAt = false, true, false, nil
    ForgetKill()
    wipe(dead)
    snapElapsed = 0
    tickElapsed = 0
    Listen(true)
    WatchZone(true)
    Zone()
    frame:Show()
end
function Recorder.SetAll(on)
    ns.GetDB().settings.recAll = on and true or nil
    writeAll = on and true or false
end
function Recorder.Pause(waitIdle)
    if not isOn or paused then return end
    paused = true
    ns.GetDB().paused = true
    Listen(false)
    ForgetWpn()
    CloseSegment("pause", nil)
    pauseWaitIdle = waitIdle or fighting
    local name, kind = GetInstanceInfo()
    pauseZone = kind == "raid" and name or nil
    pauseLeft = pauseZone == nil
end
function Recorder.Resume(why)
    if not paused then return end
    paused = false
    ns.GetDB().paused = nil
    fighting, seenIdle, hadFight, calmAt = false, true, false, nil
    ForgetKill()
    wipe(dead)
    Listen(true)
    if why then ns.Print(ns.T("rec.resumed." .. why)) end
end
function Recorder.Stop()
    if not isOn then
        return
    end
    isOn = false
    local db = ns.GetDB()
    db.recording = false
    db.settings.autoRaid = false
    db.paused = nil
    WatchZone(false)
    if paused then
        paused = false
    else
        Listen(false)
    end
    ForgetWpn()
    frame:Hide()
    CloseSegment("stop", nil)
    ns.Trash.Forget()
end
local asked = {}
local askedN = 0
local function NoteClass(guid, name, flags)
    if not guid or not name or asked[guid] or not flags then return end
    if band(flags, F_PLAYER) == 0 then return end
    if askedN >= ASKED_MAX then
        wipe(asked)
        askedN = 0
    end
    askedN = askedN + 1
    asked[guid] = true
    local classes = ns.GetDB().classes
    if classes[name] then return end
    local _, cls = GetPlayerInfoByGUID(guid)
    if cls then classes[name] = cls end
end
local function NoteSummon(srcName, srcFlags, dstGUID)
    if not srcName or not dstGUID or not srcFlags then return end
    if band(srcFlags, F_PLAYER) == 0 or band(srcFlags, F_GROUP) == 0 then return end
    ns.GetDB().pets[dstGUID] = srcName
end
local function ResetSegmentState()
    wipe(inVehicle)
    vehicleFight = false
    wipe(auraStacks)
    wipe(bossTarget)
    wipe(bossTick)
    wipe(polledHp)
    wipe(polledMax)
    wipe(polledX)
    wipe(polledY)
    frameHp, framePos = true, true
    mapArea, mapLevel, mapName = nil, nil, nil
    wipe(dead)
    wipe(bossSeen)
    ForgetKill()
    posElapsed = POS_PERIOD
    keyElapsed = KEY_PERIOD
    mapElapsed = MAP_PERIOD
    levelOk = true
end
local function NoteVehicleFight(guid, name)
    local key = ns.NpcKey(guid)
    if not key then return end
    local enc = ns.Encounters.Of(guid, name, nil) or ns.vehicles[key]
    if enc ~= nil and ns.bossVehicle[enc] then vehicleFight = true end
end
local function WatchEnd(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, auto)
    local E = ns.Encounters
    if spellId and srcGUID and ns.Deaths.ByScript(E.Of(srcGUID, srcName, auto), spellId) then
        scriptHold = GetTime() + SCRIPT_HOLD
    end
    local dstKey = killAt and ns.NpcKey(dstGUID)
    if dstKey and not dead[dstKey] and srcFlags ~= nil
        and band(srcFlags, F_BY_PLAYER) > 0 and find(sub, "_DAMAGE", 1, true)
        and E.Of(dstGUID, dstName, auto) ~= nil then
        ForgetKill()
    end
    local enc, who, sure = E.Ending(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, auto,
        bossSeen)
    if not enc or (killAt and dead[who]) then return end
    dead[who] = true
    local now = GetTime()
    killSure = sure or (killAt ~= nil and killSure)
    killAt = now + KILL_GRACE
    killEnd = now + AUTO_WAIT
    killEnc = enc
end
local function Asked(unit)
    if not ownAsk then foreignUnit, foreignAt = unit, GetTime() end
end
if type(hooksecurefunc) == "function" and type(NotifyInspect) == "function" then
    hooksecurefunc("NotifyInspect", Asked)
end
local function WpnAsk(guid, name)
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
        ns.Store.Append(Now(), "FW_WPN", guid, wpnName[guid], 0, nil, nil, 0, mh, oh, rg, why)
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
local function WpnReady()
    if not wpnGuid or UnitGUID(wpnUnit) ~= wpnGuid then return end
    if foreignAt and foreignAt > wpnSent then return end
    WpnRead(wpnUnit, wpnGuid)
    WpnDone()
end
local function Spent(guid, name, auto)
    if not closed.mute then return false end
    if GetTime() >= closed.mute then
        closed.mute = nil
        return false
    end
    return ns.Encounters.Of(guid, name, auto) == closed.enc
end
local function RecordEvent(ts, ...)
    local sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, _, _, auraType = ...
    NoteClass(srcGUID, srcName, srcFlags)
    NoteClass(dstGUID, dstName, dstFlags)
    if sub == "SPELL_SUMMON" then NoteSummon(srcName, srcFlags, dstGUID) end
    local seg = ns.GetDB().live
    if not seg then
        ns.Store.Open(ts)
        ResetSegmentState()
        seg = ns.GetDB().live
    end
    local ok = false
    if ns.RecFilter.Keep(sub, srcGUID, srcName, dstGUID, dstName, spellId, auraType, seg.bosses, writeAll) then
        ok = ns.Store.Append(ts, ...)
    end
    if not seg.pull and ns.RecFilter.Pulls(sub, srcFlags, dstGUID, dstName, seg.bosses)
        and not Spent(dstGUID, dstName, seg.bosses) then
        ns.Trash.Pull(seg, ts)
        ns.BuffSnap.Take(ts)
        if ns.PullTimer then ns.PullTimer.OnPull(ts) end
        frameHp, framePos = true, true
    end
    if sub == "UNIT_DIED" and dstFlags and band(dstFlags, F_PLAYER) > 0 then ns.Trash.Died(ts) end
    if spellId == WPN_AURA and sub == "SPELL_AURA_APPLIED" then WpnAsk(dstGUID, dstName) end
    Anchor(ts)
    WatchEnd(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, seg.bosses)
    if not vehicleFight then
        NoteVehicleFight(srcGUID, srcName)
        NoteVehicleFight(dstGUID, dstName)
    end
    return ok
end
local function OnCombatEvent(ts, ...)
    seen = seen + 1
    if not inZone then return end
    if not ns.Prof.on then
        if RecordEvent(ts, ...) then kept = kept + 1 end
        return
    end
    local p0 = debugprofilestop()
    if RecordEvent(ts, ...) then kept = kept + 1 end
    ns.Prof.Add("rec.event", debugprofilestop() - p0, 1)
end
local function AddSlot(unit, isPlayer, pet)
    local guid = UnitGUID(unit)
    if not guid then return end
    slots = slots + 1
    slotUnit[slots] = unit
    slotGuid[slots] = guid
    slotName[slots] = UnitName(unit) or UNKNOWN
    slotPlayer[slots] = isPlayer
    slotPet[slots] = pet or false
end
local function ReadRoster()
    slots = 0
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        for i = 1, nRaid do
            AddSlot(RAID[i], true, RAID_PET[i])
        end
        AddSlot("pet", false)
    else
        AddSlot("player", true, "pet")
        AddSlot("pet", false)
        for i = 1, GetNumPartyMembers() do
            AddSlot(PARTY[i], true, PARTY_PET[i])
            AddSlot(PARTY_PET[i], false)
        end
    end
    rosterDirty = false
end
local function UnitOf(guid)
    for k = 1, slots do
        if slotGuid[k] == guid and slotPlayer[k] then return slotUnit[k] end
    end
    return nil
end
local function InGroup(name)
    if rosterDirty then ReadRoster() end
    for k = 1, slots do
        if slotPlayer[k] and slotName[k] == name then return true end
    end
    return false
end
local function OnAchievement(msg, sender)
    if not inZone or type(msg) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local id = tonumber(msg:match(ACH_LINK))
    if not id then return end
    local name = sender:match("^([^%-]+)") or sender
    if not InGroup(name) then return end
    local key = name .. ":" .. id
    local now = GetTime()
    if achSeen[key] and now - achSeen[key] < ACH_DUP then return end
    if not achSeen[key] then
        achN = achN + 1
        if achN > ACH_MAX then
            wipe(achSeen)
            achN = 1
        end
    end
    achSeen[key] = now
    local ts = Now()
    if not ns.Store.Live() then
        ns.Store.Open(ts)
        ResetSegmentState()
    end
    ns.Store.Append(ts, "FW_ACH", nil, name, 0, nil, nil, 0, id)
end
function Recorder.Mark(sub, ...)
    if not isOn or paused or not inZone then return false end
    local ts = Now()
    if not ns.Store.Live() then
        ns.Store.Open(ts)
        ResetSegmentState()
    end
    return ns.Store.Append(ts, sub, ...)
end
local function WpnStep(now)
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
local function CountOnMap()
    if rosterDirty then ReadRoster() end
    local on, alive = 0, 0
    for k = 1, slots do
        local unit = slotUnit[k]
        if slotPlayer[k] and not UnitIsDeadOrGhost(unit) then
            alive = alive + 1
            local x, y = GetPlayerMapPosition(unit)
            if (x or 0) > 0 or (y or 0) > 0 then on = on + 1 end
        end
    end
    return on, alive
end
local function TryLevel(level)
    levelProbes = levelProbes + 1
    SetDungeonMapLevel(level)
    return CountOnMap()
end
local function PickLevel()
    local on, alive = CountOnMap()
    local was = GetCurrentMapDungeonLevel() or 0
    local area = GetCurrentMapAreaID()
    if on * 2 > alive then
        if was > 0 then goodArea, goodLevel = area, was end
        return true
    end
    local n = GetNumDungeonMapLevels() or 0
    if n < 2 then return on > 0 end
    local first = goodLevel and goodArea == area and goodLevel ~= was and goodLevel <= n and goodLevel or nil
    local best, bestOn = was, on
    if first then
        local c = TryLevel(first)
        if c > bestOn then best, bestOn = first, c end
    end
    if bestOn * 2 <= alive then
        for level = 1, n do
            if level ~= was and level ~= first then
                local c = TryLevel(level)
                if c > bestOn then best, bestOn = level, c end
                if c * 2 > alive then break end
            end
        end
    end
    if bestOn == 0 then best = first or was end
    if best == 0 then
        SetMapToCurrentZone()
    elseif best ~= GetCurrentMapDungeonLevel() then
        SetDungeonMapLevel(best)
    end
    if bestOn == 0 then return false end
    if best ~= was then levelFixes = levelFixes + 1 end
    goodArea, goodLevel = area, best
    return true
end
local function ReadMap()
    local area, level, name = GetCurrentMapAreaID(), GetCurrentMapDungeonLevel(), GetMapInfo() or ""
    if area == mapArea and level == mapLevel and name == mapName then return false end
    mapArea, mapLevel, mapName = area, level, name
    return ns.Store.Map(Now(), area, level, name)
end
local function PollAuras(k, guid)
    local poll = ns.pollAuras
    if not poll or not slotPlayer[k] then return end
    local unit = slotUnit[k]
    for i = 1, #poll do
        local want = GetSpellInfo(poll[i])
        local name, count
        if want then
            local n, _, _, c = UnitAura(unit, want)
            name, count = n, c
        end
        local c = name and ((count and count > 0) and count or 1) or 0
        local stacks = auraStacks[i]
        if not stacks then
            stacks = {}
            auraStacks[i] = stacks
        end
        if (stacks[guid] or 0) ~= c then
            stacks[guid] = c
            ns.Store.Append(Now(), "FW_STACK", guid, slotName[k], 0, nil, nil, 0, poll[i], c)
        end
    end
end
local function PutSlot(live, k, now, withPos, forceHp, forcePos)
    local unit, guid, name = slotUnit[k], slotGuid[k], slotName[k]
    local hp = UnitIsDeadOrGhost(unit) and 0 or (UnitHealth(unit) or 0)
    local hpMax = UnitHealthMax(unit) or 0
    if forceHp or polledHp[name] ~= hp or polledMax[name] ~= hpMax then
        polledHp[name], polledMax[name] = hp, hpMax
        ns.RecCodec.Hp(live, now, name, hp, hpMax, forceHp)
    end
    if withPos then
        local px, py = GetPlayerMapPosition(unit)
        local x, y = floor((px or 0) * 10000 + 0.5), floor((py or 0) * 10000 + 0.5)
        if forcePos or polledX[name] ~= x or polledY[name] ~= y then
            polledX[name], polledY[name] = x, y
            ns.RecCodec.Pos(live, now, name, x, y, forcePos)
        end
        if vehicleFight then
            local veh = UnitInVehicle(unit) and 1 or 0
            if (inVehicle[guid] or 0) ~= veh then
                inVehicle[guid] = veh
                local pet = veh == 1 and slotPet[k]
                ns.Store.Append(Now(), "FW_VEH", guid, slotName[k], 0, nil, nil, 0, veh, pet and UnitGUID(pet) or nil)
            end
        end
        PollAuras(k, guid)
    end
end
local function NotePets(nRaid)
    local pets = ns.GetDB().pets
    local g = UnitGUID("pet")
    if g then pets[g] = UnitName("player") end
    if nRaid > 0 then
        for i = 1, nRaid do
            g = UnitGUID(RAID_PET[i])
            if g then pets[g] = UnitName(RAID[i]) end
        end
    else
        for i = 1, GetNumPartyMembers() do
            g = UnitGUID(PARTY_PET[i])
            if g then pets[g] = UnitName(PARTY[i]) end
        end
    end
end
local function CollectUnits(keyframe, withPos, mapMoved)
    if keyframe or rosterDirty then
        ReadRoster()
    end
    if keyframe then NotePets(GetNumRaidMembers()) end
    local now = Now()
    local live = ns.Store.Live()
    if not ns.Store.IsNew(live) then return 0 end
    local forceHp, forcePos = frameHp, withPos and (framePos or mapMoved)
    for k = 1, slots do
        PutSlot(live, k, now, withPos, forceHp, forcePos)
    end
    frameHp = false
    if withPos then framePos = false end
    return slots
end
local function BossName(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then
        return nil
    end
    if not UnitCanAttack("player", unit) then
        return nil
    end
    if UnitLevel(unit) ~= -1 and UnitClassification(unit) ~= "worldboss" then
        return nil
    end
    return UnitName(unit)
end
local function NoteBossTarget(unit, name)
    local guid = UnitGUID(unit)
    if not guid or bossTick[guid] == bossRound then return end
    bossTick[guid] = bossRound
    local of = TARGET_OF[unit]
    local tg = of and UnitGUID(of) or false
    if bossTarget[guid] == tg then return end
    bossTarget[guid] = tg
    ns.Store.Append(Now(), "FW_BTGT", guid, name, 0, tg or nil, tg and UnitName(of) or nil, 0)
end
local function NoteBoss(unit)
    local name = BossName(unit)
    if name then
        ns.Store.MarkBoss(name)
        if not vehicleFight then NoteVehicleFight(UnitGUID(unit), name) end
        local live = ns.Store.Live()
        if live and live.pull then NoteBossTarget(unit, name) end
    end
end
local function BossFighting(unit)
    return BossName(unit) ~= nil and UnitAffectingCombat(unit) and true or false
end
local function EachTarget(each)
    local r = each("target") or each("focus")
    if r then return r end
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        for i = 1, nRaid do
            r = each(RAID_TARGET[i])
            if r then return r end
        end
    else
        for i = 1, GetNumPartyMembers() do
            r = each(PARTY_TARGET[i])
            if r then return r end
        end
    end
    return nil
end
local function NoteBosses()
    bossRound = bossRound + 1
    EachTarget(NoteBoss)
end
local function PauseStep()
    if not fighting then
        pauseWaitIdle = false
        return
    end
    if pauseWaitIdle then return end
    if EachTarget(BossFighting) then Recorder.Resume("boss") end
end
local function PauseZone()
    local name, kind = GetInstanceInfo()
    if kind ~= "raid" then
        pauseLeft = true
    elseif pauseLeft or name ~= pauseZone then
        Recorder.Resume("zone")
    end
end
local function GroupFighting()
    if UnitAffectingCombat("player") then return true end
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        local here = GetRealZoneText()
        for i = 1, nRaid do
            local _, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
            if online and zone == here and UnitAffectingCombat(RAID[i]) then return true end
        end
        return false
    end
    for i = 1, GetNumPartyMembers() do
        if UnitAffectingCombat(PARTY[i]) then return true end
    end
    return false
end
local function PollFight(now)
    fighting = GroupFighting()
    if fighting then
        calmAt = nil
        if seenIdle then hadFight = true end
    else
        calmAt = calmAt or now
        seenIdle = true
    end
end
local function CheckClose(now)
    if killAt and now >= killAt then
        if killSure or not fighting then
            CloseSegment("kill", killEnc)
            return
        end
        if now >= killEnd then ForgetKill() end
    end
    if hadFight and calmAt and now - calmAt >= IDLE_CLOSE and not (scriptHold and now < scriptHold) then
        CloseSegment("idle", nil)
    end
end
local function Snapshot()
    local withPos = posElapsed >= POS_PERIOD
    local moved = false
    if withPos then
        posElapsed = posElapsed - POS_PERIOD
        if posElapsed >= POS_PERIOD then posElapsed = 0 end
        local busy = WorldMapFrame:IsShown()
        local fresh = false
        if mapElapsed >= MAP_PERIOD then
            mapElapsed = 0
            if not busy then
                SetMapToCurrentZone()
                fresh = true
            end
        end
        if not busy and (fresh or (levelOk and CountOnMap() == 0)) then
            levelOk = PickLevel()
        end
        moved = ReadMap()
    elseif not mapArea then
        moved = ReadMap()
    end
    local keyframe = keyElapsed >= KEY_PERIOD
    if keyframe then
        keyElapsed = 0
    end
    local p0 = ns.Prof.on and debugprofilestop()
    local count = CollectUnits(keyframe, withPos, moved)
    if p0 then ns.Prof.Add("rec.snap", debugprofilestop() - p0, count) end
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatEvent(...)
    elseif event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        local msg, sender, _, _, target = ...
        if ns.Store.Live() and type(msg) == "string" then
            ns.Store.Append(Now(), "FW_EMOTE", nil, sender, 0, nil, target, 0, msg)
        end
    elseif event == "INSPECT_TALENT_READY" then
        WpnReady()
    elseif event == "CHAT_MSG_ACHIEVEMENT" or event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
        local msg, sender = ...
        OnAchievement(msg, sender)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if paused then PauseZone() end
        Zone()
    else
        rosterDirty = true
    end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    snapElapsed = snapElapsed + elapsed
    tickElapsed = tickElapsed + elapsed
    mapElapsed = mapElapsed + elapsed
    keyElapsed = keyElapsed + elapsed
    posElapsed = posElapsed + elapsed
    bossElapsed = bossElapsed + elapsed
    ringElapsed = ringElapsed + elapsed
    if snapElapsed >= SNAP_PERIOD then
        snapElapsed = snapElapsed - SNAP_PERIOD
        if snapElapsed >= SNAP_PERIOD then snapElapsed = 0 end
        if ns.Store.Live() then
            Snapshot()
        end
    end
    if bossElapsed >= BOSS_PERIOD then
        bossElapsed = 0
        if paused then
            PauseStep()
        elseif ns.Store.Live() then
            NoteBosses()
        end
    end
    if tickElapsed >= TICK_PERIOD then
        tickElapsed = 0
        PollFight(GetTime())
    end
    if ringElapsed >= RING_PERIOD then
        ringElapsed = 0
        local live = ns.Store.Live()
        if live and not live.pull and ns.Store.IsNew(live) then ns.Trash.Step(live, Now()) end
    end
    if wpnGuid or wpnQueue[1] then WpnStep(GetTime()) end
    if ns.Threat then ns.Threat.Step(elapsed) end
    if (killAt or (hadFight and calmAt)) and ns.Store.Live() then
        CheckClose(GetTime())
    end
end)
ns.OnReady(function()
    local db = ns.GetDB()
    if db.recording or db.settings.autoRaid then
        db.recording = false
        Recorder.Start()
        if isOn and db.paused then
            Recorder.Pause(true)
            ns.Print(ns.T("slash.restored.paused"))
        elseif isOn then
            ns.Print(ns.T("slash.restored"))
        end
    end
end)
