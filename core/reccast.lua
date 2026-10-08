local _, ns = ...
local floor = math.floor
local SUB = "FW_CAST"
local CAST, CHANNEL, MOVED, CUT = 1, 2, 3, 0
local EARLY_MS = 200
local MAX_RAID = 40
local MAX_PARTY = 4
local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP",
}
local RecCast = { SUB = SUB, CAST = CAST, CHANNEL = CHANNEL, MOVED = MOVED, CUT = CUT }
ns.RecCast = RecCast
local UNITS = { player = true }
for i = 1, MAX_RAID do UNITS["raid" .. i] = true end
for i = 1, MAX_PARTY do UNITS["party" .. i] = true end
local open = {}
local frame = CreateFrame("Frame")
local function Writing()
    local R = ns.Recorder
    return R ~= nil and R.IsOn() and not R.IsPaused() and R.InZone() and ns.Store.Live() ~= nil
end
local function Put(name, kind, left)
    local ms = left and floor(left + 0.5) or nil
    if ms and ms < 0 then ms = 0 end
    ns.Store.Append(ns.Recorder.Now(), SUB, nil, name, 0, nil, nil, 0, kind, ms)
end
local function OnStart(unit, name, chan)
    local info = chan and UnitChannelInfo or UnitCastingInfo
    if not info then return end
    local spell, _, _, _, start, stop = info(unit)
    if not spell or not stop then return end
    local o = open[name]
    if o and o.start == start and o.chan == chan then return end
    open[name] = { start = start, stop = stop, chan = chan }
    Put(name, chan and CHANNEL or CAST, stop - GetTime() * 1000)
end
local function OnMoved(unit, name, chan)
    local o = open[name]
    local info = chan and UnitChannelInfo or UnitCastingInfo
    if not o or o.chan ~= chan or not info then return end
    local spell, _, _, _, _, stop = info(unit)
    if not spell or not stop or stop == o.stop then return end
    o.stop = stop
    Put(name, MOVED, stop - GetTime() * 1000)
end
local function OnCut(name)
    local o = open[name]
    if not o or o.cut or o.done then return end
    o.cut = true
    Put(name, CUT, nil)
end
local function OnStop(name, chan)
    local o = open[name]
    if not o or o.chan ~= chan then return end
    if not o.done and not o.cut and GetTime() * 1000 < o.stop - EARLY_MS then OnCut(name) end
    open[name] = nil
end
local function OnEvent(_, event, unit)
    if not UNITS[unit] or not Writing() then return end
    local name = UnitName(unit)
    if not name then return end
    if event == "UNIT_SPELLCAST_START" then
        OnStart(unit, name, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        OnStart(unit, name, true)
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        OnMoved(unit, name, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        OnMoved(unit, name, true)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local o = open[name]
        if o and not o.chan then o.done = true end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        OnCut(name)
    elseif event == "UNIT_SPELLCAST_STOP" then
        OnStop(name, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        OnStop(name, true)
    end
end
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.log", OnEvent))
function RecCast.Listen(on)
    for i = 1, #EVENTS do
        if on then frame:RegisterEvent(EVENTS[i]) else frame:UnregisterEvent(EVENTS[i]) end
    end
    if not on then wipe(open) end
end
