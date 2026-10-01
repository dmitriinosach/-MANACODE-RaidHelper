local _, ns = ...
local format = string.format
local lower = string.lower
local Raid = {}
ns.Raid = Raid
local WEEK = 7 * 86400
local function SizeOf(diff, players)
    if players and players > 0 then return players end
    if diff == 2 or diff == 4 then return 25 end
    return 10
end
local function Plain(s)
    local t = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return lower(t)
end
function Raid.Wanted(raid)
    local d = raid.diff or 1
    if raid.heroic and d <= 2 then d = d + 2 end
    return d
end
function Raid.Locks()
    local out = {}
    local total = GetNumSavedInstances and GetNumSavedInstances() or 0
    local now = time()
    for i = 1, total do
        local name, id, reset, diff, locked, extended, _, isRaid, players = GetSavedInstanceInfo(i)
        if isRaid and locked and name and id and id > 0 then
            local span = extended and 2 * WEEK or WEEK
            out[#out + 1] = {
                name = name,
                id = id,
                diff = diff or 1,
                size = SizeOf(diff, players),
                from = now + (reset or 0) - span,
                to = now + (reset or 0),
                extended = extended and true or nil,
            }
        end
    end
    return out
end
function Raid.LockoutId(raid, at, locks)
    if not raid or not raid.name then return nil end
    locks = locks or Raid.Locks()
    local want, name, best = Raid.Wanted(raid), Plain(raid.name), nil
    for i = 1, #locks do
        local l = locks[i]
        local fits = not at or (at >= l.from and at <= l.to)
        if fits and l.size == raid.size and Plain(l.name) == name then
            if l.diff == want then return l.id end
            best = best or l.id
        end
    end
    return best
end
function Raid.MapNow()
    if not GetMapInfo or (WorldMapFrame and WorldMapFrame:IsShown()) then return nil end
    local map = GetMapInfo()
    if map and map ~= "" then return map end
    return nil
end
function Raid.Current()
    local info = { GetInstanceInfo() }
    local name, kind, diff = info[1], info[2], info[3]
    if not name or name == "" or kind ~= "raid" then
        return nil
    end
    diff = diff or 1
    local raidDiff = type(GetRaidDifficulty) == "function" and GetRaidDifficulty() or nil
    local heroic = nil
    if diff == 3 or diff == 4 then
        heroic = true
    elseif info[7] and info[6] == 1 then
        heroic = true
    end
    local raid = {
        name = name,
        diff = diff,
        size = SizeOf(diff, info[5]),
        heroic = heroic,
        info = { info[4], info[5], info[6], info[7] },
        raidDiff = raidDiff,
        who = UnitName("player"),
        day = date("%Y-%m-%d"),
        map = Raid.MapNow(),
    }
    raid.id = Raid.LockoutId(raid)
    return raid
end
function Raid.IsFinal(map, boss)
    local final = map and boss and ns.raidFinal and ns.raidFinal[map]
    if type(final) == "table" then
        for i = 1, #final do
            if final[i] == boss then return true end
        end
        return false
    end
    return final ~= nil and final == boss
end
function Raid.IsLead()
    if GetNumRaidMembers() > 0 then return (IsRaidLeader() or IsRaidOfficer()) and true or false end
    if GetNumPartyMembers() > 0 then return IsPartyLeader() and true or false end
    return true
end
function Raid.Key(raid)
    if not raid then return "solo" end
    if raid.id then return tostring(raid.id) end
    return raid.name .. "|" .. raid.day .. "|" .. tostring(raid.size)
end
function Raid.Label(raid)
    if not raid then return ns.T("raid.none") end
    return format("%s, %d %s", raid.name, raid.size, ns.T("raid.people"))
end
local function FillSeg(seg, me, locks)
    local raid = seg.raid
    if not raid or raid.id then return false end
    if raid.who then
        if raid.who ~= me then return false end
    elseif not raid.info then
        return false
    end
    local id = Raid.LockoutId(raid, seg.t0, locks)
    if not id then return false end
    raid.id = id
    return true
end
function Raid.Backfill()
    local db = ns.GetDB()
    if not db or type(db.segments) ~= "table" then return 0 end
    local locks = Raid.Locks()
    if #locks == 0 then return 0 end
    local me = UnitName("player")
    local filled = 0
    for i = 1, #db.segments do
        if FillSeg(db.segments[i], me, locks) then filled = filled + 1 end
    end
    if db.live and FillSeg(db.live, me, locks) then filled = filled + 1 end
    if filled > 0 and ns.Encounters then ns.Encounters.Invalidate() end
    return filled
end
function Raid.Touch(seg)
    if not seg then return end
    if not seg.raid then
        seg.raid = Raid.Current()
    elseif not seg.raid.id then
        local cur = Raid.Current()
        if cur and cur.id and cur.size == seg.raid.size and Plain(cur.name) == Plain(seg.raid.name) then
            seg.raid.id = cur.id
        end
    end
end
local function Str(v)
    if v == nil then return "nil" end
    return tostring(v)
end
function Raid.DevLock()
    local i1, i2, i3, i4, i5, i6, i7 = GetInstanceInfo()
    ns.Print(format(ns.T("dev.lock.inst"), Str(i1), Str(i2), Str(i3), Str(i4), Str(i5), Str(i6), Str(i7)))
    ns.Print(format(ns.T("dev.lock.diff"), Str(GetInstanceDifficulty and GetInstanceDifficulty()),
        Str(type(GetRaidDifficulty) == "function" and GetRaidDifficulty() or nil)))
    local total = GetNumSavedInstances and GetNumSavedInstances() or 0
    ns.Print(format(ns.T("dev.lock.saved"), total))
    for i = 1, total do
        local name, id, reset, diff, locked, extended, _, isRaid, players, diffName = GetSavedInstanceInfo(i)
        ns.Print(format(ns.T("dev.lock.row"), i, Str(name), Str(id), Str(diff), Str(diffName),
            Str(players), Str(locked), Str(extended), Str(isRaid), (reset or 0) / 3600))
    end
    local raid = Raid.Current()
    if raid then
        ns.Print(format(ns.T("dev.lock.pick"), raid.name, raid.size, Raid.Wanted(raid),
            Str(raid.heroic), Str(raid.id), Raid.Key(raid)))
    else
        ns.Print(ns.T("dev.lock.out"))
    end
    local live = ns.Store and ns.Store.Live()
    if live then
        ns.Print(format(ns.T("dev.lock.live"), Raid.Key(live.raid)))
    end
    if RequestRaidInfo then RequestRaidInfo() end
end
local locksKnown = false
function Raid.LocksKnown()
    return locksKnown
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UPDATE_INSTANCE_INFO")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_INSTANCE_INFO" then
        locksKnown = true
        Raid.Backfill()
        return
    end
    if ns.Store then Raid.Touch(ns.Store.Live()) end
    if RequestRaidInfo then RequestRaidInfo() end
end)
ns.OnReady(function()
    if RequestRaidInfo then RequestRaidInfo() end
end)
