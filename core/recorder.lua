local _, ns = ...
local floor = math.floor
local band = bit.band
local find = string.find
local format = string.format
local KILL_GRACE = 2
local AUTO_WAIT = 10
local IDLE_CLOSE = 10
local SPEC_CALM = 5
local SCRIPT_HOLD = 180
local SNAP_PERIOD = 0.2
local POS_PERIOD = 0.25
local MAP_PERIOD = 1
local KEY_PERIOD = 5
local CLOCK_HOLD = 2
local CLOCK_BACK = 1
local TICK_PERIOD = 0.5
local BOSS_PERIOD = 1
local CAST_POLL = 0.7
local RING_PERIOD = 1
local NPC_PERIOD = 3
local NPC_MAX = 40
local NPC_STREAMS = 400
local PULL_MUTE = 30
local MAX_RAID = 40
local MAX_PARTY = 4
local F_PLAYER = ns.F.PLAYER
local F_BY_PLAYER = ns.F.BY_PLAYER
local F_GROUP = ns.F.GROUP
local WPN_AURA = ns.RecWpn.AURA
local SPEC_SWAP = ns.SpellSet(ns.specSwap, nil, true)
local ACH_EVENTS = ns.RecAch.EVENTS
local ASKED_MAX = 4096
local Recorder = {}
ns.Recorder = Recorder
local frame = CreateFrame("Frame")
frame:Hide()
local U = ns.Units
local RAID, RAID_PET, RAID_TARGET = U.raid, U.raidPet, U.raidTarget
local PARTY, PARTY_PET, PARTY_TARGET = U.party, U.partyPet, U.partyTarget
local TARGET_OF = { target = "targettarget", focus = "focustarget" }
for i = 1, MAX_RAID do TARGET_OF[RAID_TARGET[i]] = RAID_TARGET[i] .. "target" end
for i = 1, MAX_PARTY do TARGET_OF[PARTY_TARGET[i]] = PARTY_TARGET[i] .. "target" end
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
local ringMore = false
local posElapsed = POS_PERIOD
local frameHp, framePos = true, true
local bossTarget, bossTick = {}, {}
local polledHp, polledMax, polledX, polledY = {}, {}, {}, {}
local bossRound = 0
local npcElapsed = 0
local npcKnown, npcKnownN = {}, 0
local inVehicle = {}
local vehicleFight = false
local auraStacks = {}
local pollNow = {}
local posShared = {}
local clockOff = nil
local clockAt = 0
local lastNow = 0
local seen, kept = 0, 0
local hearAt = nil
local FLASK = {}
for id, c in pairs(ns.consumeCast) do
    if c.cat == "flask" then FLASK[id] = true end
end
local slotUnit, slotGuid, slotName, slotPlayer, slotPet, slotMana = {}, {}, {}, {}, {}, {}
local slots = 0
local rosterDirty = true
local fighting = false
local calmAt = nil
local seenIdle = true
local hadFight = false
local killAt, killEnd, killSure, killEnc = nil, nil, false, nil
local scriptHold = nil
local dummyAt = nil
local specAt = nil
local dead = {}
local bossSeen = {}
local closed = { why = nil, enc = nil, at = nil, mute = nil }
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
    return ns.RecMap.Level()
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
local function Hear(on)
    if on then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        hearAt = hearAt or GetTime()
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        hearAt = nil
    end
    if ns.Meter and ns.Meter.Borrow then ns.Meter.Borrow(on) end
end
local function Listen(on)
    if on then
        frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        frame:RegisterEvent("INSPECT_TALENT_READY")
        for i = 1, #ACH_EVENTS do frame:RegisterEvent(ACH_EVENTS[i]) end
        ns.RecCast.Listen(true)
        Hear(isOn and inZone)
    else
        ns.RecCast.Listen(false)
        for i = 1, #ACH_EVENTS do frame:UnregisterEvent(ACH_EVENTS[i]) end
        Hear(false)
        frame:UnregisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        frame:UnregisterEvent("INSPECT_TALENT_READY")
    end
    WatchRoster(on)
end
local function CloseSegment(why, enc)
    ForgetKill()
    scriptHold = nil
    dummyAt = nil
    wipe(dead)
    wipe(bossSeen)
    vehicleFight = false
    hadFight = false
    seenIdle = not fighting
    local live = ns.Store.Live()
    if not live then return end
    local kill = why == "kill" and live.pull ~= nil
    closed.why, closed.enc, closed.at = why, enc, time()
    closed.mute = why == "kill" and enc and GetTime() + PULL_MUTE or nil
    ns.Raid.Touch(live)
    if ns.CpuMeter then ns.CpuMeter.Close(enc) end
    ns.Store.Close()
    if kill and RequestRaidInfo then RequestRaidInfo() end
    if kill and ns.AutoRec and ns.AutoRec.Killed then ns.AutoRec.Killed(enc) end
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
    if kind == "raid" or ns.Encounters.Dummy() then return true end
    return kind == "party" and ns.GetDB().settings.autoParty == true
end
local function Zone()
    inZone = ZoneWanted()
    Hear(isOn and inZone)
    if not inZone and ns.Store.Live() then CloseSegment("zone", nil) end
end
function Recorder.InZone()
    return inZone
end
function Recorder.HearSince()
    return hearAt
end
function Recorder.SetSpec(on)
    ns.GetDB().settings.specRec = on and true or nil
    ns.RecFilter.spec = on and true or false
    specAt = nil
end
function Recorder.Spec()
    return ns.RecFilter.spec == true
end
function Recorder.SetDummy(on)
    ns.GetDB().settings.dummyRec = on and true or nil
    ns.Encounters.SetDummy(on)
    local live = ns.Store.Live()
    if on and live then live.dummy = true end
    if isOn then Zone() end
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
    closed.mute = nil
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
    ns.RecWpn.Forget()
    CloseSegment("pause", nil)
    pauseWaitIdle = waitIdle or fighting
    local name = GetInstanceInfo()
    pauseZone = ZoneWanted() and name or nil
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
    ns.RecWpn.Forget()
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
local function PollFor(enc)
    wipe(pollNow)
    local poll, boss = ns.pollAuras or {}, ns.pollAuraBoss or {}
    for i = 1, #poll do
        local id = poll[i]
        local name = (boss[id] == nil or boss[id] == enc) and GetSpellInfo(id)
        if name then pollNow[#pollNow + 1] = { i = i, id = id, name = name } end
    end
end
local function ResetSegmentState()
    wipe(inVehicle)
    vehicleFight = false
    wipe(auraStacks)
    wipe(pollNow)
    wipe(posShared)
    wipe(bossTarget)
    wipe(bossTick)
    wipe(npcKnown)
    npcKnownN = 0
    wipe(polledHp)
    wipe(polledMax)
    wipe(polledX)
    wipe(polledY)
    ns.RecMana.Reset()
    frameHp, framePos = true, true
    ns.RecMap.Reset()
    wipe(dead)
    wipe(bossSeen)
    ForgetKill()
    posElapsed = POS_PERIOD
    keyElapsed = KEY_PERIOD
    mapElapsed = MAP_PERIOD
end
local function NoteVehicleFight(guid, name, key)
    key = key or ns.NpcKey(guid)
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
        local enc = ns.Encounters.Of(dstGUID, dstName, seg.bosses)
        ns.Trash.Pull(seg, ts)
        if not ns.RecFilter.BossOn(enc) then
            seg.lite = enc
            ns.Print(format(ns.T("rec.boss.lite"), ns.EncName(enc)))
        end
        PollFor(enc)
        if ns.CpuMeter then ns.CpuMeter.Pull(enc) end
        ns.BuffSnap.Take(ts)
        if ns.FlaskReady then ns.FlaskReady.Pull() end
        ns.Specs.Take(ts)
        if ns.PullTimer then ns.PullTimer.OnPull(ts) end
        frameHp, framePos = true, true
    end
    if sub == "UNIT_DIED" and dstFlags and band(dstFlags, F_PLAYER) > 0 and band(dstFlags, F_GROUP) > 0 then
        ns.Trash.Died(ts)
    end
    if srcFlags and band(srcFlags, F_BY_PLAYER) > 0 and ns.Encounters.Dummy() and find(sub, "_DAMAGE", 1, true)
        and ns.Encounters.IsDummy(ns.NpcKey(dstGUID)) then
        dummyAt = GetTime()
    end
    if spellId == WPN_AURA and sub == "SPELL_AURA_APPLIED" then ns.RecWpn.Ask(dstGUID, dstName) end
    if SPEC_SWAP[spellId] and sub == "SPELL_CAST_SUCCESS" then ns.Specs.Swap(srcName) end
    if ok and FLASK[spellId] and sub == "SPELL_CAST_SUCCESS" and srcFlags and band(srcFlags, F_GROUP) > 0
        and ns.FlaskReady then
        ns.FlaskReady.Cast(srcName)
    end
    Anchor(ts)
    local srcKey, dstKey = ns.NpcKey(srcGUID), ns.NpcKey(dstGUID)
    if sub == "SPELL_CAST_START" and srcKey and ns.bosses[srcKey] and bossElapsed < BOSS_PERIOD - CAST_POLL then
        bossElapsed = BOSS_PERIOD - CAST_POLL
    end
    if srcKey or dstKey then
        if ns.RecFilter.spec and ((srcKey and ns.bosses[srcKey]) or (dstKey and ns.bosses[dstKey])) then specAt = GetTime() end
        WatchEnd(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, seg.bosses)
        if ns.AutoRec then ns.AutoRec.Combat(sub, srcGUID, dstGUID) end
        if not vehicleFight then
            if srcKey then NoteVehicleFight(srcGUID, srcName, srcKey) end
            if dstKey then NoteVehicleFight(dstGUID, dstName, dstKey) end
        end
    end
    return ok
end
local function OnCombatEvent(ts, ...)
    seen = seen + 1
    if not inZone then return end
    if RecordEvent(ts, ...) then kept = kept + 1 end
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
    slotMana[slots] = isPlayer and ns.RecMana.Wanted(slotName[slots], unit) or false
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
function Recorder.Roster(fresh)
    if fresh and rosterDirty then ReadRoster() end
    return slots, slotUnit, slotGuid, slotName, slotPlayer
end
function Recorder.Now()
    return Now()
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
local function PollAuras(k, guid)
    if not pollNow[1] or not slotPlayer[k] then return end
    local unit = slotUnit[k]
    for j = 1, #pollNow do
        local p = pollNow[j]
        local i = p.i
        local name, _, _, count = UnitAura(unit, p.name)
        local c = name and ((count and count > 0) and count or 1) or 0
        local share = ns.RealmShare
        if share then c = share.AuraCount(slotName[k], p.id) or c end
        local stacks = auraStacks[i]
        if not stacks then
            stacks = {}
            auraStacks[i] = stacks
        end
        if (stacks[guid] or 0) ~= c then
            stacks[guid] = c
            ns.Store.Append(Now(), "FW_STACK", guid, slotName[k], 0, nil, nil, 0, p.id, c)
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
    if slotMana[k] then ns.RecMana.Put(live, unit, name, now, forceHp) end
    if withPos then
        local px, py = GetPlayerMapPosition(unit)
        local share = ns.RealmShare
        if share then
            local shared
            px, py, shared = share.Pick(name, px, py)
            if (posShared[name] or false) ~= shared then
                posShared[name] = shared
                ns.Store.Append(Now(), "FW_PSRC", guid, name, 0, nil, nil, 0, shared and 1 or 0)
            end
        end
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
        if ns.Prof.Busy() then
            local p0 = debugprofilestop()
            PollAuras(k, guid)
            ns.Prof.Part("hot.aura", "hot.rec", debugprofilestop() - p0)
        else
            PollAuras(k, guid)
        end
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
    if not live then return 0 end
    local forceHp, forcePos = frameHp, withPos and (framePos or mapMoved)
    for k = 1, slots do
        PutSlot(live, k, now, withPos, forceHp, forcePos)
    end
    frameHp = false
    if withPos then framePos = false end
    return slots
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
local function NoteBosses()
    bossRound = bossRound + 1
    local S = ns.UnitScan.Get()
    local live = ns.Store.Live()
    for i = 1, S.n do
        local name = S.near[i] and S.boss[i] and S.name[i]
        if name then
            ns.Store.MarkBoss(name)
            if not vehicleFight and S.guid[i] then NoteVehicleFight(S.guid[i], name, S.key[i] or nil) end
            if live and live.pull and S.Valid(i) then NoteBossTarget(S.unit[i], name) end
        end
    end
end
local function BossFighting()
    local S = ns.UnitScan.Get()
    for i = 1, S.n do
        if S.near[i] and S.boss[i] and S.combat[i] then return true end
    end
    return false
end
local function PutNpc(live, S, i, now, bossOnly)
    local guid, hpMax = S.guid[i], S.hpMax[i]
    if not guid or hpMax <= 0 then return false end
    local key = ns.Streams.GuidKey(guid)
    local new = not npcKnown[key]
    if (bossOnly or (new and npcKnownN >= NPC_STREAMS)) and not S.boss[i] then return false end
    if new then
        npcKnown[key] = true
        npcKnownN = npcKnownN + 1
    end
    ns.RecCodec.Hp(live, now, key, S.hp[i], hpMax, false)
    return true
end
local function SampleNpcs()
    local live = ns.Store.Live()
    if not (live and live.pull) then return end
    local S = ns.UnitScan.Get(true)
    local now, n = Now(), 0
    for i = 1, S.n do
        if PutNpc(live, S, i, now, n >= NPC_MAX) then n = n + 1 end
    end
end
local function PauseStep()
    if not fighting then
        pauseWaitIdle = false
        return
    end
    if pauseWaitIdle then return end
    if BossFighting() then Recorder.Resume("boss") end
end
local function PauseZone()
    local name = GetInstanceInfo()
    if not ZoneWanted() then
        pauseLeft = true
    elseif pauseLeft or name ~= pauseZone then
        Recorder.Resume("zone")
    end
end
local function GroupFighting()
    if UnitAffectingCombat("player") then return true end
    if specAt and GetTime() - specAt < SPEC_CALM then return true end
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
        return
    end
    if dummyAt and now - dummyAt >= IDLE_CLOSE then CloseSegment("idle", nil) end
end
local function Snapshot()
    local withPos = posElapsed >= POS_PERIOD
    local refresh = false
    if withPos then
        posElapsed = posElapsed - POS_PERIOD
        if posElapsed >= POS_PERIOD then posElapsed = 0 end
        if mapElapsed >= MAP_PERIOD then
            mapElapsed = 0
            refresh = true
        end
    end
    local moved = ns.RecMap.Read(withPos, refresh)
    local keyframe = keyElapsed >= KEY_PERIOD
    if keyframe then
        keyElapsed = 0
    end
    local p0 = ns.Prof.on and debugprofilestop()
    local count = CollectUnits(keyframe, withPos, moved)
    ns.RecMap.Restore()
    if p0 then ns.Prof.Add("rec.snap", debugprofilestop() - p0, count) end
end
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.log", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatEvent(...)
    elseif event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        local msg, sender, _, _, target = ...
        if ns.Store.Live() and type(msg) == "string" then
            ns.Store.Append(Now(), "FW_EMOTE", nil, sender, 0, nil, target, 0, msg)
        end
    elseif event == "INSPECT_TALENT_READY" then
        ns.RecWpn.Ready()
    elseif event == "CHAT_MSG_ACHIEVEMENT" or event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
        local msg, sender = ...
        ns.RecAch.On(msg, sender)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local live = event == "PLAYER_ENTERING_WORLD" and ns.Store.Live()
        if live and not live.pull then CloseSegment("zone", nil) end
        if paused then PauseZone() end
        Zone()
    else
        rosterDirty = true
    end
end))
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.rec", function(_, elapsed)
    snapElapsed = snapElapsed + elapsed
    tickElapsed = tickElapsed + elapsed
    mapElapsed = mapElapsed + elapsed
    keyElapsed = keyElapsed + elapsed
    posElapsed = posElapsed + elapsed
    bossElapsed = bossElapsed + elapsed
    ringElapsed = ringElapsed + elapsed
    npcElapsed = npcElapsed + elapsed
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
    if npcElapsed >= NPC_PERIOD then
        npcElapsed = 0
        if not paused then SampleNpcs() end
    end
    if tickElapsed >= TICK_PERIOD then
        tickElapsed = 0
        PollFight(GetTime())
    end
    if ringElapsed >= RING_PERIOD or ringMore then
        ringElapsed = 0
        local live = ns.Store.Live()
        ringMore = live ~= nil and not live.pull and ns.Trash.Step(live, Now()) or false
    end
    ns.RecWpn.Step()
    if ns.Threat then ns.Threat.Step(elapsed) end
    if (killAt or dummyAt or (hadFight and calmAt)) and ns.Store.Live() then
        CheckClose(GetTime())
    end
end))
ns.OnReady(function()
    local db = ns.GetDB()
    ns.Encounters.SetDummy(db.settings.dummyRec == true)
    ns.RecFilter.spec = db.settings.specRec == true
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
