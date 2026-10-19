local _, ns = ...
local SUB = "FW_PULLT"
local CHAT_EVENTS = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_PARTY",
                      "CHAT_MSG_PARTY_LEADER" }
local GROUP_CHAN = { RAID = true, PARTY = true }
local PullTimer = {}
ns.PullTimer = PullTimer
PullTimer.SUB = SUB
local active = nil
local function Who(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^([^%-]+)") or name
    name = name:gsub("[%c|]", "")
    if name == "" then return nil end
    return name
end
local function Seconds(sec)
    local d = ns.pullTimer
    if not sec then return nil end
    if sec == 0 then return 0 end
    if sec < d.min or sec > d.max then return nil end
    return sec
end
function PullTimer.FromAddon(prefix, body)
    local kind = ns.pullTimer.addon[prefix]
    if type(body) ~= "string" then return nil end
    if kind == "pt" then
        return Seconds(tonumber(body:match("^(%d+)")))
    elseif kind == "pizza" then
        local sec, text = body:match("^(%d+)%s*(.-)$")
        if not text or not ns.pullTimer.pizza[text] then return nil end
        sec = tonumber(sec)
        if sec == 0 then return nil end
        return Seconds(sec)
    end
    return nil
end
function PullTimer.FromChat(msg)
    if type(msg) ~= "string" then return nil end
    local d = ns.pullTimer
    for i = 1, #d.chat do
        local _, e, n = msg:find(d.chat[i])
        if n then
            local tail = msg:sub(e + 1, e + 12)
            for k = 1, #d.minutes do
                if tail:find(d.minutes[k], 1, true) then return nil end
            end
            return Seconds(tonumber(n))
        end
    end
    return nil
end
function PullTimer.Note(who, sec)
    who = Who(who)
    if not who or not sec or not ns.Recorder or not ns.Recorder.Mark then return false end
    local now = GetTime()
    if active and now > active.ends + ns.pullTimer.dup then active = nil end
    if sec == 0 then
        if not active then return false end
        active = nil
        if ns.Specs then ns.Specs.Soon(0) end
        return ns.Recorder.Mark(SUB, nil, who, 0, nil, nil, 0, 0)
    end
    local ends = now + sec
    if active and math.abs(ends - active.ends) <= ns.pullTimer.dup then return false end
    if not ns.Recorder.Mark(SUB, nil, who, 0, nil, nil, 0, sec) then return false end
    active = { ends = ends, start = now, sec = sec, who = who }
    if ns.Specs then ns.Specs.Soon(sec) end
    return true
end
function PullTimer.OnPull(ts)
    local a = active
    if not a or a.pulled or not ns.Store then return false end
    local ago = GetTime() - a.start
    if ago < 0 or ago > ns.pullTimer.window then return false end
    a.pulled = true
    return ns.Store.Append(ts, SUB, nil, a.who, 0, nil, nil, 0, a.sec, math.floor(ago * 10 + 0.5) / 10) and true or false
end
function PullTimer.Forget()
    active = nil
    if ns.Specs then ns.Specs.Soon(0) end
end
function PullTimer.Feed(s, ts, who, sec, ago)
    sec = tonumber(sec)
    if not who or not sec then return end
    ago = tonumber(ago)
    s.pullMarks = s.pullMarks or {}
    s.pullMarks[#s.pullMarks + 1] = { t = ago and ts - ago or ts, who = who, sec = sec }
end
function PullTimer.Puller(pull)
    if not pull then return nil end
    return pull.owner or (not pull.pet and pull.src) or nil
end
function PullTimer.Judge(s)
    local marks = s.pullMarks
    s.pullMarks = nil
    local pull = s.pull
    if not marks or not pull or not pull.t then return nil end
    local d = ns.pullTimer
    local last
    for i = 1, #marks do
        local m = marks[i]
        if m.t <= pull.t and m.t >= pull.t - d.window then
            last = m.sec > 0 and m or nil
        end
    end
    if not last then return nil end
    local early = last.t + last.sec - pull.t
    local v = { who = last.who, sec = last.sec, t = last.t, early = early > d.early and early or nil }
    pull.timer = v
    return v
end
function PullTimer.EarlyOf(s, name)
    local pull = s and s.pull
    local v = pull and pull.timer
    if not v or not v.early or PullTimer.Puller(pull) ~= name then return nil end
    return v
end
local clock = { kind = "pull", ends = 0, sec = 0 }
local hooked = false
local function PizzaKind(text)
    if type(text) ~= "string" then return nil end
    local d = ns.pullTimer
    if d.pizza[text] or text == DBM_CORE_TIMER_PULL then return "pull" end
    if d.breaks[text] or text == DBM_CORE_TIMER_BREAK then return "break" end
    return nil
end
local function SetClock(kind, sec, who)
    if not kind or not sec or sec > ns.pullTimer.clockMax then return end
    local now = GetTime()
    if sec <= 0 then
        if clock.kind == kind then clock.ends = now end
        return
    end
    clock.kind, clock.ends, clock.sec, clock.who = kind, now + sec, sec, Who(who)
end
function PullTimer.ClockFromAddon(prefix, body)
    local kind = ns.pullTimer.addon[prefix]
    if type(body) ~= "string" then return nil, nil end
    if kind == "pt" then return "pull", tonumber(body:match("^(%d+)")) end
    if kind ~= "pizza" then return nil, nil end
    local sec, text = body:match("^(%d+)%s*(.-)$")
    local k = PizzaKind(text)
    if not k then return nil, nil end
    return k, tonumber(sec)
end
function PullTimer.Clock()
    local left = clock.ends - GetTime()
    if left <= 0 then return nil, nil, nil, nil end
    return clock.kind, left, clock.who, clock.sec
end
local function OnPizza(_, sec, text, _broadcast, sender)
    SetClock(PizzaKind(text), tonumber(sec), sender or UnitName("player"))
end
function PullTimer.HookDbm()
    if hooked or type(DBM) ~= "table" or type(DBM.CreatePizzaTimer) ~= "function" then return end
    hooked = true
    hooksecurefunc(DBM, "CreatePizzaTimer", OnPizza)
end
local function OnAddon(prefix, body, sender, chan)
    if not GROUP_CHAN[chan] then return end
    local kind, sec = PullTimer.ClockFromAddon(prefix, body)
    SetClock(kind, sec, sender)
    PullTimer.Note(sender, PullTimer.FromAddon(prefix, body))
end
if ns.OnReady then ns.OnReady(PullTimer.HookDbm) end
if ns.Comm and ns.Comm.On then
    for prefix in pairs(ns.pullTimer.addon) do
        ns.Comm.On(prefix, function(body, sender, chan) OnAddon(prefix, body, sender, chan) end)
    end
end
local frame = CreateFrame("Frame")
for i = 1, #CHAT_EVENTS do frame:RegisterEvent(CHAT_EVENTS[i]) end
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.pulltimer", function(_, _, msg, sender)
    local sec = PullTimer.FromChat(msg)
    SetClock(sec and "pull" or nil, sec, sender)
    if not ns.Recorder or not ns.Recorder.IsOn() then return end
    PullTimer.Note(sender, sec)
end))
