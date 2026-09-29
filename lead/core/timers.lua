local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local T = {}
ns.Timers = T
local MIN_SEC, MAX_SEC = 3, 3600
local DEFAULTS = {
    { kind = "break", sec = 65 },
    { kind = "break", sec = 210 },
    { kind = "break", sec = 300 },
    { kind = "break", sec = 600 },
    { kind = "pull",  sec = 10 },
    { kind = "pull",  sec = 65 },
}
local function copyDefaults()
    local out = {}
    for i, t in ipairs(DEFAULTS) do out[i] = { kind = t.kind, sec = t.sec } end
    return out
end
function T.List()
    local db = ns.Store.DB()
    if not db.timers then db.timers = copyDefaults() end
    return db.timers
end
function T.Add(kind)
    local list = T.List()
    list[#list + 1] = { kind = kind or "break", sec = 60 }
    ns.Session.Changed()
end
function T.Remove(i)
    table.remove(T.List(), i)
    ns.Session.Changed()
end
function T.Set(i, kind, sec)
    local t = T.List()[i]
    if not t then return end
    if kind then t.kind = kind end
    if sec then
        sec = math.floor(tonumber(sec) or t.sec)
        if sec < MIN_SEC then sec = MIN_SEC end
        if sec > MAX_SEC then sec = MAX_SEC end
        t.sec = sec
    end
    ns.Session.Changed()
end
function T.Reset()
    ns.Store.DB().timers = copyDefaults()
    ns.Session.Changed()
end
function T.IsDefault()
    local list = T.List()
    if #list ~= #DEFAULTS then return false end
    for i, t in ipairs(list) do
        if t.kind ~= DEFAULTS[i].kind or t.sec ~= DEFAULTS[i].sec then return false end
    end
    return true
end
function T.Duration(sec)
    if sec >= 120 and sec % 30 == 0 then
        local m = sec / 60
        local s = (m == math.floor(m)) and tostring(m)
            or (tostring(math.floor(m)) .. "," .. tostring(math.floor((m % 1) * 10 + 0.5)))
        return ns.T("durMin", s)
    end
    return ns.T("durSec", sec)
end
function T.HasDBM()
    return DBM and DBM.CreatePizzaTimer and SlashCmdList and SlashCmdList.DEADLYBOSSMODSPULL and true or false
end
local function breakText()
    return DBM_CORE_TIMER_BREAK or ns.T("timerBreakText")
end
function T.Run(t)
    if not T.HasDBM() then return end
    if t.kind == "pull" then
        SlashCmdList.DEADLYBOSSMODSPULL(tostring(t.sec))
    else
        DBM:CreatePizzaTimer(t.sec, breakText(), true)
    end
end
function T.Cancel()
    if not T.HasDBM() then return false end
    if DBM.Unschedule then
        DBM:Unschedule(SendChatMessage)
        DBM:Unschedule(PlaySoundFile)
    end
    local raid, party = ns.Compat.GroupSize()
    local sync = raid > 0 and "RAID" or (party > 0 and "PARTY" or nil)
    for _, text in ipairs({ DBM_CORE_TIMER_PULL or "", breakText() }) do
        if text ~= "" then
            DBM:CreatePizzaTimer(0, text)
            if sync then ns.Compat.SendAddon("DBMv4-Pizza", "0\t" .. text, sync) end
        end
    end
    if sync then SendChatMessage(ns.T("timerCancelSay"), raid > 0 and "RAID_WARNING" or "PARTY") end
    return true
end
