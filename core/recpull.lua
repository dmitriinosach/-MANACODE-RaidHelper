local _, ns = ...
local band = bit.band
local floor = math.floor
local min = math.min
local find = string.find
local gsub = string.gsub
local format = string.format
local F_PLAYER = ns.F.PLAYER
local F_BY_PLAYER = ns.F.BY_PLAYER
local NAMES_MAX = 200
local TIP = "ManaCodeRaidHelperOwnerScan"
local MAX_RAID = 40
local MAX_PARTY = 4
local RecPull = {}
ns.RecPull = RecPull
local U = ns.Units
local RAID, RAID_PET, RAID_TARGET = U.raid, U.raidPet, U.raidTarget
local PARTY, PARTY_PET, PARTY_TARGET = U.party, U.partyPet, U.partyTarget
local FIND = { "target", "focus", "mouseover", "targettarget", "focustarget", "pettarget" }
local RAID_TT, PARTY_TT = {}, {}
for i = 1, MAX_RAID do RAID_TT[i] = RAID_TARGET[i] .. "target" end
for i = 1, MAX_PARTY do PARTY_TT[i] = PARTY_TARGET[i] .. "target" end
local elapsed = 0
local dirty = false
local GROUP = { player = true, pet = true }
for i = 1, MAX_RAID do GROUP[RAID[i]], GROUP[RAID_PET[i]] = true, true end
for i = 1, MAX_PARTY do GROUP[PARTY[i]], GROUP[PARTY_PET[i]] = true, true end
local firstAt = nil
local firsts = {}
local nFirst = 0
local collecting = false
local bossAt = nil
local aggro = nil
local pending = nil
local touch = {}
local summoner = {}
local summoned = 0
local scan
local function Busy(unit, owner)
    if not UnitAffectingCombat(unit) then return false end
    if collecting then
        nFirst = nFirst + 1
        if nFirst <= ns.pullWho.ties then
            local guid, name = UnitGUID(unit), UnitName(unit)
            if guid and name then
                firsts[nFirst] = { guid = guid, name = name, owner = owner and UnitName(owner) or nil }
            else
                nFirst = nFirst - 1
            end
        end
    end
    return true
end
local function AnyBusy()
    local any = false
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        for i = 1, nRaid do
            local a = Busy(RAID[i], nil)
            local b = Busy(RAID_PET[i], RAID[i])
            if a or b then
                any = true
                if not collecting then return true end
            end
        end
        return any
    end
    local a, b = Busy("player", nil), Busy("pet", "player")
    any = a or b
    if any and not collecting then return true end
    for i = 1, GetNumPartyMembers() do
        a, b = Busy(PARTY[i], nil), Busy(PARTY_PET[i], PARTY[i])
        if a or b then
            any = true
            if not collecting then return true end
        end
    end
    return any
end
local function Tick(now)
    if firstAt then
        if not AnyBusy() then
            firstAt, nFirst = nil, 0
            wipe(firsts)
            bossAt, aggro = nil, nil
        end
        return
    end
    nFirst = 0
    wipe(firsts)
    collecting = true
    local any = AnyBusy()
    collecting = false
    if any then firstAt = now end
end
local function PetOwner(guid)
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        for i = 1, nRaid do
            if UnitGUID(RAID_PET[i]) == guid then return UnitName(RAID[i]) end
        end
        return nil
    end
    if UnitGUID("pet") == guid then return UnitName("player") end
    for i = 1, GetNumPartyMembers() do
        if UnitGUID(PARTY_PET[i]) == guid then return UnitName(PARTY[i]) end
    end
    return nil
end
local function Find(guid)
    for i = 1, #FIND do
        if UnitGUID(FIND[i]) == guid then return FIND[i] end
    end
    local nRaid = GetNumRaidMembers()
    if nRaid > 0 then
        for i = 1, nRaid do
            if UnitGUID(RAID_TARGET[i]) == guid then return RAID_TARGET[i] end
            if UnitGUID(RAID_TT[i]) == guid then return RAID_TT[i] end
        end
        return nil
    end
    for i = 1, GetNumPartyMembers() do
        if UnitGUID(PARTY_TARGET[i]) == guid then return PARTY_TARGET[i] end
        if UnitGUID(PARTY_TT[i]) == guid then return PARTY_TT[i] end
    end
    return nil
end
local function NameIn(text)
    local best, bestLen, stemOf, stems = nil, 0, nil, 0
    local nRaid = GetNumRaidMembers()
    local n = nRaid > 0 and nRaid or GetNumPartyMembers() + 1
    for i = 1, n do
        local unit = nRaid > 0 and RAID[i] or (i == 1 and "player" or PARTY[i - 1])
        local name = UnitName(unit)
        if name then
            if #name > bestLen and find(text, name, 1, true) then
                best, bestLen = name, #name
            elseif not best then
                local stem = gsub(name, "[%z\1-\127\192-\247][\128-\191]*$", "")
                if #stem >= 6 and find(text, stem, 1, true) then
                    stemOf, stems = name, stems + 1
                end
            end
        end
    end
    if best then return best end
    return stems == 1 and stemOf or nil
end
local function TipOwner(guid)
    local unit = Find(guid)
    if not unit or UnitIsPlayer(unit) then return nil end
    scan = scan or CreateFrame("GameTooltip", TIP, nil, "GameTooltipTemplate")
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:ClearLines()
    scan:SetUnit(unit)
    local owner
    for i = 2, min(4, scan:NumLines() or 0) do
        local fs = _G[TIP .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text ~= "" then owner = NameIn(text) end
        if owner then break end
    end
    scan:Hide()
    return owner
end
function RecPull.Owner(guid, name)
    local pets = ns.GetDB().pets
    local o = pets[guid]
    if o then return o end
    o = PetOwner(guid) or TipOwner(guid) or (name and summoner[name]) or nil
    if o then pets[guid] = o end
    return o
end
local function Engage(now)
    if aggro or (bossAt and now - bossAt > ns.pullWho.aim) then return end
    local S = ns.UnitScan.Get()
    for i = 1, S.n do
        local unit = S.unit[i]
        if S.boss[i] and S.near[i] and S.Valid(i) and UnitAffectingCombat(unit) then
            bossAt = bossAt or now
            local of = unit .. "target"
            local guid, name = UnitGUID(of), UnitName(of)
            if guid and name then
                aggro = { guid = guid, name = name,
                          owner = not UnitIsPlayer(of) and RecPull.Owner(guid, name) or nil }
                return
            end
        end
    end
end
function RecPull.Summon(srcName, dstName)
    if not dstName then return end
    if not summoner[dstName] then
        summoned = summoned + 1
        if summoned > NAMES_MAX then
            wipe(summoner)
            summoned = 1
        end
    end
    summoner[dstName] = srcName
end
function RecPull.Touch(srcGUID, srcName, srcFlags, spell)
    if not srcName or not srcFlags or band(srcFlags, F_BY_PLAYER) == 0 then return end
    local person = srcName
    if band(srcFlags, F_PLAYER) == 0 then person = srcGUID and ns.GetDB().pets[srcGUID] end
    if not person then return end
    local tc = touch[person]
    if not tc then
        tc = {}
        touch[person] = tc
    end
    tc.t, tc.spell = GetTime(), type(spell) == "string" and spell or nil
end
function RecPull.Pull(sub, srcGUID, srcName, srcFlags, spell, boss)
    if pending then return end
    local now = GetTime()
    if not firstAt then Tick(now) end
    if firstAt then Engage(now) end
    local hit
    if srcName and find(sub, "_DAMAGE", 1, true) then
        local pet = srcFlags ~= nil and band(srcFlags, F_PLAYER) == 0
        hit = { t = now, src = srcName, pet = pet, spell = (not find(sub, "SWING", 1, true)) and type(spell) == "string"
            and spell or nil, owner = pet and srcGUID and RecPull.Owner(srcGUID, srcName) or nil }
    end
    pending = { at = now, hit = hit, boss = boss }
end
local function Flush(now)
    local p = pending
    pending = nil
    local d = ns.pullWho
    local list = {}
    if aggro and now - bossAt <= d.window + d.delay then
        local age = floor((now - bossAt) * 10 + 0.5) / 10
        ns.Store.Append(ns.Recorder.Now(), ns.PullWho.SUB, aggro.guid, aggro.name, 0, nil, aggro.owner, 0, age)
        list[1] = { t = bossAt, src = aggro.name, owner = aggro.owner }
    elseif firstAt and now - firstAt <= d.window + d.delay and nFirst <= d.ties then
        local age = floor((now - firstAt) * 10 + 0.5) / 10
        local ts = ns.Recorder.Now()
        for i = 1, nFirst do
            local f = firsts[i]
            ns.Store.Append(ts, ns.PullWho.SUB, f.guid, f.name, 0, nil, f.owner, 0, age)
            list[i] = { t = firstAt, src = f.name, owner = f.owner }
        end
    end
    if p.boss and ns.PullToast and RecPull.Notify() then
        local pull = ns.PullWho.Decide(p.hit, list, touch)
        if pull then ns.PullToast.Show(RecPull.Message(pull)) end
    end
    wipe(touch)
    bossAt, aggro = nil, nil
end
function RecPull.Notify()
    return ns.GetDB().settings.notePull ~= false
end
function RecPull.SetNotify(on)
    if on then ns.GetDB().settings.notePull = nil else ns.GetDB().settings.notePull = false end
end
function RecPull.Message(pull)
    local text
    local who, sec, ends = ns.PullTimer.AtPull()
    if who then
        local early = ends - pull.t
        if early > ns.pullTimer.early then
            text = format(ns.T("sum.pull.timerearly"), sec, who, ns.Fixed(early))
        else
            text = format(ns.T("sum.pull.timer"), sec, who)
        end
    end
    return ns.PullWho.Text(pull), text
end
function RecPull.Step(dt)
    local now = GetTime()
    if pending then
        if not firstAt then Tick(now) end
        if firstAt then Engage(now) end
        if now - pending.at >= ns.pullWho.delay then Flush(now) end
        return
    end
    local live = ns.Store.Live()
    if live and live.pull then return end
    elapsed = elapsed + dt
    if not dirty and elapsed < ns.pullWho.period then return end
    elapsed, dirty = 0, false
    Tick(now)
    if firstAt then Engage(now) end
end
local flags = CreateFrame("Frame")
flags:RegisterEvent("UNIT_FLAGS")
flags:RegisterEvent("PLAYER_REGEN_DISABLED")
flags:SetScript("OnEvent", function(_, ev, unit)
    if ev == "PLAYER_REGEN_DISABLED" or GROUP[unit] then dirty = true end
end)
function RecPull.Forget()
    pending = nil
    wipe(touch)
    bossAt, aggro = nil, nil
end
