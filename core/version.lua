local _, ns = ...
local random = math.random
local match = string.match
local format = string.format
local tonumber = tonumber
local type = type
local PREFIX = "MRH_VER"
local LOGIN_DELAY = 10
local ROSTER_DELAY = 2
local CHAN_GAP = 60
local RX_GAP = 1
local REPLY_LO = 1
local REPLY_HI = 6
local REPLY_FRESH = 10
local MAX_LEN = 24
local MAX_KNOWN = 2000
local MAX_RX = 200
local CHAN = "GUILD"
local STEP = 0.5
local Version = {}
ns.Version = Version
Version.PREFIX = PREFIX
Version.CHAN_GAP = CHAN_GAP
local known = {}
local knownN = 0
local rxAt = {}
local rxN = 0
local sentAt = {}
local due = {}
local toldTop = nil
local newest = nil
local listeners = {}
local loginAt = nil
local started = false
local inGuild = false
function Version.Parse(text)
    if type(text) ~= "string" or #text > MAX_LEN then return nil end
    local a, b, c, rest = match(text, "^(%d%d?%d?%d?)%.(%d%d?%d?%d?)%.(%d%d?%d?%d?)(.*)$")
    if not a then return nil end
    local v = { major = tonumber(a), minor = tonumber(b), patch = tonumber(c), pre = nil, preN = 0 }
    if rest == "" then return v end
    local label, n = match(rest, "^%-(%a+)%.(%d%d?%d?%d?)$")
    if not label then label = match(rest, "^%-(%a+)$") end
    if not label then return nil end
    v.pre = label:lower()
    v.preN = tonumber(n) or 0
    return v
end
function Version.Compare(a, b)
    local x, y = Version.Parse(a), Version.Parse(b)
    if not x or not y then return nil end
    if x.major ~= y.major then return x.major < y.major and -1 or 1 end
    if x.minor ~= y.minor then return x.minor < y.minor and -1 or 1 end
    if x.patch ~= y.patch then return x.patch < y.patch and -1 or 1 end
    if not x.pre and not y.pre then return 0 end
    if not x.pre then return 1 end
    if not y.pre then return -1 end
    if x.pre ~= y.pre then return x.pre < y.pre and -1 or 1 end
    if x.preN ~= y.preN then return x.preN < y.preN and -1 or 1 end
    return 0
end
function Version.IsStable(v)
    local p = Version.Parse(v)
    return p ~= nil and p.pre == nil
end
function Version.Mine()
    local v = ns.AddonVersion and ns.AddonVersion()
    if Version.Parse(v) then return v end
    return nil
end
function Version.NoteOn()
    local db = ns.GetDB()
    local s = type(db) == "table" and db.settings
    return not (type(s) == "table" and s.verNote == false)
end
function Version.SetNoteOn(on)
    ns.GetDB().settings.verNote = on and true or false
end
function Version.Of(name)
    if type(name) ~= "string" then return nil end
    if name == UnitName("player") then return Version.Mine() end
    return known[name]
end
function Version.Newest()
    if not newest then return nil, nil end
    return newest.v, newest.from
end
function Version.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function Version.StatusLine()
    local mine = Version.Mine() or "?"
    local seen = ns.T("ver.none")
    if newest then seen = format(ns.T("ver.seen"), newest.v, newest.from) end
    return format(ns.T("ver.status"), mine, seen)
end
local function ChanOpen(chan)
    return chan == CHAN and IsInGuild() and true or false
end
local timer = CreateFrame("Frame")
timer:Hide()
local acc = 0
local function Schedule(chan, delay, reply)
    local now = GetTime()
    local at = now + delay
    local gap = (sentAt[chan] or -1e9) + CHAN_GAP
    if at < gap then at = gap + delay end
    local d = due[chan]
    if d then
        if at < d.at then d.at = at end
        d.reply = d.reply and (reply and true or false)
    else
        due[chan] = { at = at, reply = reply and true or false }
    end
    timer:Show()
end
local function Send(chan)
    local mine = Version.Mine()
    if not mine or not ChanOpen(chan) then return end
    sentAt[chan] = GetTime()
    ns.Comm.Send(PREFIX, "V:" .. mine, chan)
end
local function Flush(now)
    local left = false
    for chan, d in pairs(due) do
        if now >= d.at then
            due[chan] = nil
            Send(chan)
        else
            left = true
        end
    end
    return left
end
timer:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < STEP then return end
    acc = 0
    local now = GetTime()
    if loginAt and now >= loginAt then
        loginAt = nil
        if IsInGuild() then Schedule(CHAN, 0) end
    end
    if not Flush(now) and not loginAt then self:Hide() end
end)
local function Changed()
    for i = 1, #listeners do listeners[i]() end
end
local function Note(v, from)
    local mine = Version.Mine()
    if not mine or Version.Compare(v, mine) ~= 1 then return end
    if not newest or Version.Compare(v, newest.v) == 1 then newest = { v = v, from = from } end
    if not Version.NoteOn() then return end
    if Version.IsStable(mine) and not Version.IsStable(v) then return end
    if toldTop and Version.Compare(v, toldTop) ~= 1 then return end
    toldTop = v
    ns.Print(format(ns.T("ver.new"), v, mine))
end
local function RxRoom(now)
    for name, at in pairs(rxAt) do
        if now - at >= RX_GAP then
            rxAt[name] = nil
            rxN = rxN - 1
        end
    end
    while rxN >= MAX_RX do
        local old, oldAt
        for name, at in pairs(rxAt) do
            if not oldAt or at < oldAt then old, oldAt = name, at end
        end
        rxAt[old] = nil
        rxN = rxN - 1
    end
end
function Version.RxCount()
    return rxN
end
function Version.OnMessage(body, sender, chan)
    if chan ~= CHAN then return end
    local now = GetTime()
    if now - (rxAt[sender] or -1e9) < RX_GAP then return end
    if not rxAt[sender] then
        if rxN >= MAX_RX then RxRoom(now) end
        rxN = rxN + 1
    end
    rxAt[sender] = now
    local v = match(body, "^V:(.+)$")
    if not v or not Version.Parse(v) then return end
    if not known[sender] then
        if knownN >= MAX_KNOWN then return end
        knownN = knownN + 1
    end
    local was = known[sender]
    known[sender] = v
    Note(v, sender)
    local mine = Version.Mine()
    local cmp = mine and Version.Compare(v, mine)
    local d = due[chan]
    if d and d.reply and cmp and cmp >= 0 then due[chan] = nil end
    local fresh = now - (sentAt[chan] or -1e9) < REPLY_FRESH
    if cmp == -1 and not fresh then
        Schedule(chan, REPLY_LO + random() * (REPLY_HI - REPLY_LO), true)
    end
    if was ~= v then Changed() end
end
local function Joined()
    local member = IsInGuild() and true or false
    local grew = member and not inGuild
    inGuild = member
    if grew and started and not loginAt then Schedule(CHAN, ROSTER_DELAY) end
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        loginAt = GetTime() + LOGIN_DELAY
        started = true
        inGuild = IsInGuild() and true or false
        timer:Show()
        return
    end
    Joined()
end)
ns.Comm.On(PREFIX, Version.OnMessage)
