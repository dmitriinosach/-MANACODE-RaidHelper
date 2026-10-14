local _, ns = ...
local format = string.format
local floor = math.floor
local concat = table.concat
local PREFIX = "MRHAI"
local MAX_MSG = 240
local TIMEOUT = 60
local BOT = "Fableclode"
local KEEP = 300
local NAME_MAX = 12
local TICK = 0.5
local SAME = 1
local RETRY_MAX = 1
local RETRY = { busy = true, timeout = true }
local STOP = { guild = true, budget = true }
local DROP = { limit = true }
local MODES = { off = true, mine = true, all = true }
local KIND = "R"
local GRADES = { ["справедливо"] = "fair", ["спорно"] = "disputed", ["несправедливо"] = "unfair" }
local COULD = { ["мог"] = "yes", ["не мог"] = "no" }
local Fable = {}
ns.Fable = Fable
Fable.PREFIX, Fable.MAX_MSG, Fable.TIMEOUT, Fable.BOT = PREFIX, MAX_MSG, TIMEOUT, BOT
Fable.MODE_LIST = { "off", "mine", "all" }
local states = {}
local pending = nil
local queue = {}
local queued = {}
local stopped = nil
local listeners = {}
local frame = CreateFrame("Frame")
frame:Hide()
local acc = 0
local function Store()
    local db = ns.GetDB()
    db.fable = db.fable or {}
    db.fable.answers = db.fable.answers or {}
    return db.fable
end
local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function Fold(name)
    return (name or ""):gsub("%-.*$", ""):lower()
end
function Fable.Guild()
    local g = GetGuildInfo and GetGuildInfo("player")
    return g ~= nil and g == ns.fableGuild
end
function Fable.On()
    return ns.GetDB().settings.fableOn == true and Fable.Guild()
end
function Fable.SetOn(on)
    ns.GetDB().settings.fableOn = on and true or nil
end
function Fable.Bot()
    local name = ns.GetDB().settings.fableBot
    if type(name) == "string" and name ~= "" then return name end
    return BOT
end
function Fable.SetBot(name)
    name = Trim(tostring(name or ""):gsub("[%c|%s]", ""))
    if #name > NAME_MAX * 2 then return nil end
    if name:match("^%l") then name = name:sub(1, 1):upper() .. name:sub(2) end
    ns.GetDB().settings.fableBot = (name ~= "" and name ~= BOT) and name or nil
    return Fable.Bot()
end
function Fable.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Changed(key)
    for i = 1, #listeners do listeners[i](key) end
end
function Fable.Key(fight, who, at, rule)
    return format("%.0f:%s:%.0f:%s", floor(fight.from), who, floor(at * 10 + 0.5), rule or "")
end
function Fable.State(key)
    local s = states[key]
    if s then return s end
    local a = Store().answers[key]
    if a then return { st = "done", verdict = a.v, text = a.x, grade = a.g, could = a.c } end
    return nil
end
local function Keep(key, verdict, text, grade, could)
    local answers = Store().answers
    answers[key] = { v = verdict, x = text, g = grade, c = could, t = time() }
    local n, oldest, oldKey = 0, nil, nil
    for k, a in pairs(answers) do
        n = n + 1
        if not oldest or (a.t or 0) < oldest then oldest, oldKey = a.t or 0, k end
    end
    if n > KEEP and oldKey then answers[oldKey] = nil end
end
function Fable.Split(kind, id, text)
    local total = 1
    while true do
        local out, pos, n = {}, 1, 0
        repeat
            n = n + 1
            local head = format("%s%s:%d/%d:", kind, id, n, total)
            local room = MAX_MSG - #head
            local stop = pos + room - 1
            if stop < #text then
                while stop >= pos do
                    local b = text:byte(stop + 1)
                    if not b or b < 0x80 or b >= 0xC0 then break end
                    stop = stop - 1
                end
            end
            out[n] = head .. text:sub(pos, stop)
            pos = stop + 1
        until pos > #text
        if n == total then return out end
        total = n
    end
end
function Fable.GradeCode(grade)
    return grade and GRADES[grade] or nil
end
function Fable.CouldCode(could)
    return could and COULD[could] or nil
end
function Fable.Parse(text)
    local g, c, rest = text:match("^%s*([^~]-)%s*~%s*([^~]-)%s*~(.*)$")
    if g and GRADES[g] then
        local v, x = rest:match("^(.-)~(.*)$")
        if not v then return Trim(rest), "", g, c end
        return Trim(v), Trim(x), g, c
    end
    local v, x = text:match("^(.-)~(.*)$")
    if not v then return Trim(text), "" end
    return Trim(v), Trim(x)
end
local function Set(key, st)
    states[key] = st
    Changed(key)
end
local function Combat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat ~= nil and UnitAffectingCombat("player") and true or false
end
function Fable.Queued()
    return #queue + (pending and 1 or 0)
end
local Start
local function Next()
    if pending or not queue[1] then return end
    if Combat() then
        frame:Show()
        return
    end
    local ask = table.remove(queue, 1)
    queued[ask.key] = nil
    Start(ask)
end
local function Fail(code)
    local p = pending
    if not p then return end
    pending = nil
    local ask = p.ask
    if RETRY[code] and (ask.tries or 0) < RETRY_MAX then
        ask.tries = (ask.tries or 0) + 1
        queue[#queue + 1] = ask
        queued[ask.key] = true
        Set(ask.key, { st = "queue" })
    else
        Set(p.key, { st = "err", code = code })
    end
    if STOP[code] then stopped = code end
    if STOP[code] or DROP[code] then
        for i = #queue, 1, -1 do
            local q = queue[i]
            if q.auto then
                table.remove(queue, i)
                queued[q.key] = nil
                Set(q.key, nil)
            end
        end
    end
    Next()
end
Start = function(ask)
    local p = { key = ask.key, ask = ask, at = GetTime(), parts = {} }
    pending = p
    acc = 0
    frame:Show()
    Set(ask.key, { st = "build" })
    ns.FableRec.Build(ask, function(text)
        if pending ~= p then return end
        if not text or text == "" then return Fail("norec") end
        p.id = format("%04x", math.random(0, 65535))
        ns.Comm.Queue(PREFIX, Fable.Split(KIND, p.id, text), "WHISPER", Fable.Bot())
        Set(p.key, { st = "wait" })
    end)
end
function Fable.Ask(ask, auto)
    if not Fable.On() then return false end
    if (pending and pending.key == ask.key) or queued[ask.key] then return false end
    ask.auto = auto or nil
    ask.tries = 0
    if auto then
        queue[#queue + 1] = ask
    else
        table.insert(queue, 1, ask)
    end
    queued[ask.key] = true
    Set(ask.key, { st = "queue" })
    Next()
    return true
end
function Fable.AskAll(asks)
    local n = 0
    for i = #asks, 1, -1 do
        if Fable.Ask(asks[i]) then n = n + 1 end
    end
    return n
end
function Fable.Make(fight, who, at, rule, reason, grade)
    return { fight = fight, who = who, at = at, reason = reason, grade = grade, rule = rule,
             key = Fable.Key(fight, who, at, rule and rule.key) }
end
function Fable.EventAsk(fight, hit, who, ev)
    local grade = ev.grade == "yellow" and "yellow" or "red"
    local info = ev.info or (ev.src and ev.src.info) or ev
    if not ev.t then
        return { fight = fight, who = who, reason = ns.Penalties.Reason(hit.rule), grade = grade, rule = hit.rule,
                 info = info, whole = true, key = "e:" .. tostring(ev.key) }
    end
    local ask = Fable.Make(fight, who, ev.t, hit.rule, ns.Penalties.Reason(hit.rule), grade)
    ask.info = info
    return ask
end
function Fable.DeathAsk(fight, who, t, hits)
    for i = 1, hits and #hits or 0 do
        local hit = hits[i]
        for k = 1, #hit.events do
            local ev = hit.events[k]
            if ev.t and math.abs(ev.t - t) < SAME then return Fable.EventAsk(fight, hit, who, ev) end
        end
    end
    return Fable.Make(fight, who, t)
end
function Fable.Issuer()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 and IsRaidLeader and IsRaidLeader() then return true end
    local sys = ns.Ledger and ns.Ledger.Active and ns.Ledger.Active()
    if not (sys and sys.Can) then return false end
    local ok, can = pcall(sys.Can)
    return ok and can == true
end
function Fable.Mode()
    local m = ns.GetDB().settings.fableAuto
    if MODES[m] then return m end
    return Fable.Issuer() and "all" or "off"
end
function Fable.SetMode(m)
    if MODES[m] then ns.GetDB().settings.fableAuto = m end
end
function Fable.Collect(fight, s, me)
    local pens = ns.Penalties and ns.Penalties.Evaluate(s, fight) or {}
    local out = {}
    for i = 1, #s.players do
        local p = s.players[i]
        if not me or p.name == me then
            local hits = pens[p.name] or {}
            for h = 1, #hits do
                for k = 1, #hits[h].events do
                    local ev = hits[h].events[k]
                    out[#out + 1] = Fable.EventAsk(fight, hits[h], p.name, ev)
                end
            end
            for k = 1, #p.deathInfo do
                local d = p.deathInfo[k]
                if d.grade and not d.tail then
                    local ask = Fable.DeathAsk(fight, p.name, d.t, hits)
                    if not ask.reason then out[#out + 1] = ask end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local x, y = a.at or fight.to, b.at or fight.to
        if x ~= y then return x < y end
        return a.key < b.key
    end)
    return out
end
function Fable.Auto(fight, s)
    local mode = Fable.Mode()
    if not Fable.On() or mode == "off" or stopped or ns.Store.Bare(fight) then return 0 end
    local asks = Fable.Collect(fight, s, mode == "mine" and UnitName("player") or nil)
    local n = 0
    for i = 1, #asks do
        if not Fable.State(asks[i].key) and Fable.Ask(asks[i], true) then n = n + 1 end
    end
    return n
end
function Fable.OnMessage(body, sender, chan)
    local p = pending
    if not (p and p.id) or chan ~= "WHISPER" or not Fable.On() or Fold(sender) ~= Fold(Fable.Bot()) then return end
    local kind, id, rest = body:match("^([AE])(%x%x%x%x):(.*)$")
    if not kind or id:lower() ~= p.id then return end
    if kind == "E" then
        local code = rest:match("^(%w+)")
        return Fail(code or "parse")
    end
    local n, total, chunk = rest:match("^(%d+)/(%d+):(.*)$")
    n, total = tonumber(n), tonumber(total)
    if not (n and total and n >= 1 and n <= total and total <= 64) then return end
    if p.total and p.total ~= total then return end
    p.total = total
    p.parts[n] = chunk
    for k = 1, total do
        if not p.parts[k] then return end
    end
    local verdict, text, grade, could = Fable.Parse(concat(p.parts, "", 1, total))
    pending = nil
    Keep(p.key, verdict, text, grade, could)
    Set(p.key, { st = "done", verdict = verdict, text = text, grade = grade, could = could })
    Next()
end
local function OnSystem(msg)
    local p = pending
    if not (p and p.id and ERR_CHAT_PLAYER_NOT_FOUND_S) then return end
    if msg == format(ERR_CHAT_PLAYER_NOT_FOUND_S, Fable.Bot()) then Fail("offline") end
end
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, msg)
    if event == "PLAYER_REGEN_ENABLED" then
        Next()
    elseif type(msg) == "string" then
        OnSystem(msg)
    end
end)
frame:SetScript("OnUpdate", ns.Prof.Wrap("bg.fable", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < TICK then return end
    acc = 0
    local p = pending
    if not p then
        if queue[1] then Next() else frame:Hide() end
    elseif GetTime() - p.at >= TIMEOUT then
        Fail("timeout")
    elseif not p.id and ns.Jobs.Failed("fable:" .. p.key) then
        Fail("norec")
    end
end))
ns.Comm.On(PREFIX, Fable.OnMessage)
