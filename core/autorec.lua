local _, ns = ...
local TICK_PERIOD = 0.5
local STOP_AFTER = 10
local MOVIE_WAIT = 60
local WEEK = 7 * 86400
local KEEP = 14 * 86400
local ICC = {
    ["Цитадель Ледяной Короны"] = true,
    ["Icecrown Citadel"] = true,
}
local AutoRec = {}
ns.AutoRec = AutoRec
local frame = CreateFrame("Frame")
local inIcc = false
local inZone = false
local diedAt = nil
local movieSeen = false
local tick = 0
local function ZoneState()
    local name, kind = GetInstanceInfo()
    local icc = kind == "raid" and name ~= nil and (ICC[name] == true or ns.Raid.MapNow() == "IcecrownCitadel")
    return kind == "raid", icc
end
local function Disarm()
    diedAt = nil
    movieSeen = false
end
local function OnZone()
    local now, icc = ZoneState()
    if now == inZone and icc == inIcc then
        return
    end
    inZone, inIcc = now, icc
    Disarm()
    if icc then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
local function OnCombat(sub, srcGUID, dstGUID)
    local lich = ns.ENC.lichking
    if sub == "UNIT_DIED" then
        if dstGUID and ns.NpcKey(dstGUID) == lich and ns.Recorder.IsOn() then
            diedAt = GetTime()
            movieSeen = false
        end
    elseif diedAt and srcGUID and ns.NpcKey(srcGUID) == lich and sub:find("_DAMAGE", 1, true) then
        Disarm()
    end
end
local function ShowingMovie()
    if InCinematic() then
        return true
    end
    return (MovieFrame and MovieFrame:IsShown()) and true or false
end
local function CheckStop()
    if not diedAt then
        return
    end
    if not ns.Recorder.IsOn() or ns.Recorder.IsPaused() then
        Disarm()
        return
    end
    local since = GetTime() - diedAt
    if since < STOP_AFTER or UnitAffectingCombat("player") or ShowingMovie() then
        return
    end
    if not movieSeen and since < MOVIE_WAIT then
        return
    end
    Disarm()
    ns.Recorder.Pause(true)
    ns.Print(ns.T("auto.done"))
end
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.log", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, srcGUID, _, _, dstGUID = ...
        OnCombat(sub, srcGUID, dstGUID)
    elseif event == "PLAY_MOVIE" or event == "CINEMATIC_START" then
        if diedAt then
            movieSeen = true
        end
    else
        OnZone()
    end
end))
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.bg", function(_, elapsed)
    tick = tick + elapsed
    if tick < TICK_PERIOD then
        return
    end
    tick = 0
    CheckStop()
end))
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAY_MOVIE")
frame:RegisterEvent("CINEMATIC_START")
local DEV_MOVIE = 16
local function SameKillRaid(e, raid, name, now)
    if e.name ~= name then return false end
    local id = raid and raid.id
    if e.id and id then return e.id == id end
    return e.size == (raid and raid.size) and now - e.at <= WEEK
end
local function AllFinals(name, enc)
    local final = ns.raidFinal and ns.raidFinal[name]
    if type(final) ~= "table" then return true end
    local db = ns.GetDB()
    if type(db.finals) ~= "table" then db.finals = {} end
    local list, now = db.finals, time()
    for i = #list, 1, -1 do
        local e = list[i]
        if type(e) ~= "table" or type(e.at) ~= "number" or now - e.at > KEEP then table.remove(list, i) end
    end
    local raid = ns.Raid.Current()
    list[#list + 1] = { boss = enc, name = name, size = raid and raid.size, id = raid and raid.id, at = now }
    for i = 1, #final do
        local hit = false
        for k = 1, #list do
            if list[k].boss == final[i] and SameKillRaid(list[k], raid, name, now) then hit = true end
        end
        if not hit then return false end
    end
    return true
end
function AutoRec.Killed(enc)
    if not enc or enc == ns.ENC.lichking then return end
    local R = ns.Recorder
    if not R.IsOn() or R.IsPaused() then return end
    local _, kind = GetInstanceInfo()
    local map = kind == "raid" and ns.Raid.MapNow() or nil
    if not map or not ns.Raid.IsFinal(map, enc) then return end
    if not AllFinals(map, enc) then return end
    Disarm()
    R.Pause(true)
    ns.Print(string.format(ns.T("auto.final"), ns.EncName(enc)))
end
function AutoRec.DevAsk()
    ns.Print(ns.T(ns.Recorder.InZone() and "auto.here" or "auto.away"))
end
function AutoRec.Refresh()
    OnZone()
end
function AutoRec.DevLich(withMovie)
    if not ns.Recorder.IsOn() then
        ns.Print(ns.T("dev.needrec"))
        return
    end
    diedAt = GetTime()
    movieSeen = false
    ns.Print(ns.T("dev.lich"))
    if withMovie then
        if type(MovieFrame_PlayMovie) == "function" and MovieFrame then
            movieSeen = true
            MovieFrame_PlayMovie(MovieFrame, DEV_MOVIE)
        else
            ns.Print(ns.T("dev.nomovie"))
        end
    end
end
function AutoRec.DevState()
    local yes, no = ns.T("dev.yes"), ns.T("dev.no")
    local name, kind = GetInstanceInfo()
    ns.Print(string.format(ns.T("dev.state.zone"), tostring(name), tostring(kind),
        inIcc and yes or no, ns.Recorder.InZone() and yes or no))
    if ns.Recorder and ns.Recorder.MapLevel then
        local good, probes, fixes = ns.Recorder.MapLevel()
        local x, y = GetPlayerMapPosition("player")
        ns.Print(string.format(ns.T("dev.state.map"), GetCurrentMapDungeonLevel() or 0, GetNumDungeonMapLevels() or 0,
            x or 0, y or 0, good and tostring(good) or no, probes, fixes))
    end
    if not diedAt then
        ns.Print(ns.T("dev.state.idle"))
        return
    end
    ns.Print(string.format(ns.T("dev.state.armed"), GetTime() - diedAt,
        UnitAffectingCombat("player") and yes or no,
        ShowingMovie() and yes or no, movieSeen and yes or no))
end
