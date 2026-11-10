local _, ns = ...
local concat = table.concat
local GROUP = "FW_GROUP"
local AWAY = "FW_AWAY"
local SEP = ","
local DELAY = 0.5
local MAX_GROUP = 8
local ON, OFFLINE, AFK = 0, 1, 2
local EVENTS = { "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_FLAGS_CHANGED", "PARTY_MEMBER_DISABLE",
                 "PARTY_MEMBER_ENABLE" }
local RecRaid = { GROUP = GROUP, AWAY = AWAY, SEP = SEP, ON = ON, OFFLINE = OFFLINE, AFK = AFK }
ns.RecRaid = RecRaid
local RAID, PARTY = ns.Units.raid, ns.Units.party
local memo = { seg = nil, group = {}, away = {} }
local frame = CreateFrame("Frame")
local wait = 0
local function Fight()
    local R = ns.Recorder
    if not (R and R.IsOn() and not R.IsPaused() and R.InZone()) then return nil end
    local seg = ns.Store.Live()
    if not (seg and seg.pull) then return nil end
    return seg
end
local function StateOf(unit)
    if not UnitIsConnected(unit) then return OFFLINE end
    if UnitIsAFK(unit) then return AFK end
    return ON
end
local lists = {}
local function Read(state)
    for g = 1, MAX_GROUP do
        local list = lists[g]
        if list then wipe(list) else lists[g] = {} end
    end
    wipe(state)
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local name, _, sub = GetRaidRosterInfo(i)
            if name and sub and lists[sub] then
                local list = lists[sub]
                list[#list + 1] = name
                state[name] = StateOf(RAID[i])
            end
        end
        return lists
    end
    local me = UnitName("player")
    if me then
        lists[1][1] = me
        state[me] = ON
    end
    for i = 1, GetNumPartyMembers() do
        local name = UnitName(PARTY[i])
        if name then
            lists[1][#lists[1] + 1] = name
            state[name] = StateOf(PARTY[i])
        end
    end
    return lists
end
local now = {}
local function Put(ts, all)
    local seg = Fight()
    if not seg then return end
    if memo.seg ~= seg then
        memo.seg = seg
        wipe(memo.group)
        wipe(memo.away)
        all = true
    end
    local groups = Read(now)
    local Append = ns.Store.Append
    for g = 1, MAX_GROUP do
        local list = groups[g]
        local line = #list > 0 and concat(list, SEP) or ""
        if line ~= (memo.group[g] or "") or (all and line ~= "") then
            memo.group[g] = line
            Append(ts, GROUP, nil, nil, 0, nil, nil, 0, g, line)
        end
    end
    for name, v in pairs(now) do
        local was = memo.away[name] or ON
        if v ~= was or (all and v ~= ON) then
            memo.away[name] = v
            Append(ts, AWAY, nil, name, 0, nil, nil, 0, v)
        end
    end
end
function RecRaid.Pull(ts)
    memo.seg = nil
    Put(ts, true)
end
local function Tick(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    frame:Hide()
    Put(ns.Recorder.Now(), false)
end
frame:Hide()
frame:SetScript("OnUpdate", Tick)
frame:SetScript("OnEvent", function()
    if not Fight() then return end
    wait = DELAY
    frame:Show()
end)
for i = 1, #EVENTS do frame:RegisterEvent(EVENTS[i]) end
