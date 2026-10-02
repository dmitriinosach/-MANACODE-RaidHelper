local _, ns = ...
local format = string.format
local floor = math.floor
local abs = math.abs
local byte = string.byte
local char = string.char
local sub = string.sub
local find = string.find
local gsub = string.gsub
local match = string.match
local concat = table.concat
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local PREFIX = "MRHF"
local VERSION = 1
local TAG = "MRH: "
local CHUNK = 230
local BODY_MAX = 250
local GAP = 0.3
local SLACK = 180
local MAX_BYTES = 262144
local MAX_CHUNKS = 1200
local ASK_WAIT = 45
local PAUSE_WAIT = 600
local SERVE_MAX = 3
local SERVE_EVERY = 10
local LINK_KEEP = 100
local BOSS_MAX = 120
local DAY_MIN = 1440
local HALF_DAY = 720
local MEMO_KEEP = 40
local PUMP_STEP = 0.1
local KB = 1024
local Share = {}
ns.Share = Share
Share.PREFIX = PREFIX
Share.VERSION = VERSION
Share.CHUNK = CHUNK
Share.GAP = GAP
Share.SLACK = SLACK
Share.ASK_WAIT = ASK_WAIT
Share.SERVE_EVERY = SERVE_EVERY
local entries = {}
local lastId = 0
local memo = {}
local memoOrder = {}
local ask = nil
local lastRid = 0
local outs = {}
local servedAt = {}
local nextAt = 0
local pump = CreateFrame("Frame")
pump:Hide()
local waitFrame = CreateFrame("Frame")
waitFrame:Hide()
local waitAcc = 0
local function T(key)
    return ns.T(key)
end
local function InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end
local function Me()
    return UnitName("player") or ""
end
function Share.Accepting()
    local db = ns.GetDB()
    local set = db and db.settings
    return not (set and set.shareOff == true)
end
function Share.SetAccepting(on)
    ns.GetDB().settings.shareOff = not on or nil
end
local function InGroup(name)
    local raid = GetNumRaidMembers() or 0
    if raid > 0 then
        for i = 1, raid do
            if GetRaidRosterInfo(i) == name then return true end
        end
        return false
    end
    for i = 1, GetNumPartyMembers() or 0 do
        if UnitName("party" .. i) == name then return true end
    end
    return false
end
local function InGuild(name)
    if not (IsInGuild and IsInGuild()) then return false end
    for i = 1, GetNumGuildMembers(true) or 0 do
        if GetGuildRosterInfo(i) == name then return true end
    end
    return false
end
local function AskRoster()
    if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
end
function Share.Trusted(name)
    if type(name) ~= "string" or name == "" then return false end
    if name == Me() then return true end
    return InGroup(name) or InGuild(name)
end
function Share.Offset()
    local sh, sm = GetGameTime()
    local lt = date("*t")
    local d = ((sh or lt.hour) * 60 + (sm or lt.min)) - (lt.hour * 60 + lt.min)
    if d >= HALF_DAY then
        d = d - DAY_MIN
    elseif d < -HALF_DAY then
        d = d + DAY_MIN
    end
    return d * 60
end
local function Outcome(killed)
    return T(killed and "share.win" or "share.wipe")
end
function Share.Inner(fight, off)
    local t = date("*t", floor(fight.from + (off or Share.Offset())))
    return format("%s, %s %02d:%02d, %02d.%02d", ns.EncName(fight.boss), Outcome(fight.killed), t.hour, t.min, t.day,
        t.month)
end
function Share.Text(fight, off)
    return "[" .. TAG .. Share.Inner(fight, off) .. "]"
end
function Share.Parse(inner)
    if type(inner) ~= "string" or #inner > BOSS_MAX + 40 or find(inner, "[%c|%[%]]") then return nil end
    local boss, what, hh, mm, dd, mo = match(inner, "^(.+), (%S+) (%d%d?):(%d%d), (%d%d?)%.(%d%d)$")
    if not boss or #boss > BOSS_MAX then return nil end
    local killed
    if what == T("share.win") then
        killed = true
    elseif what == T("share.wipe") then
        killed = false
    else
        return nil
    end
    local key = { boss = boss, killed = killed, hour = tonumber(hh), min = tonumber(mm), day = tonumber(dd),
        month = tonumber(mo) }
    if key.hour > 23 or key.min > 59 or key.day < 1 or key.day > 31 or key.month < 1 or key.month > 12 then
        return nil
    end
    return key
end
function Share.Find(fights, key, off)
    off = off or Share.Offset()
    local best, bestD
    for i = 1, #fights do
        local f = fights[i]
        if ns.EncName(f.boss) == key.boss and (f.killed and true or false) == key.killed then
            local w = floor(f.from + off)
            local t = date("*t", w)
            local cand = time({ year = t.year, month = key.month, day = key.day, hour = key.hour, min = key.min,
                sec = 0, isdst = t.isdst })
            local d = abs(cand - w)
            if d <= SLACK and (not bestD or d < bestD) then best, bestD = f, d end
        end
    end
    return best
end
local function EscChar(c)
    if c == "~" then return "~~" end
    if c == "|" then return "~!" end
    local b = byte(c)
    if b == 127 then return "~?" end
    return "~" .. char(b + 64)
end
function Share.Escape(s)
    return (gsub(s, "[~|%c]", EscChar))
end
local bad = false
local function UnescChar(x)
    if x == "~" then return "~" end
    if x == "!" then return "|" end
    if x == "?" then return "\127" end
    local b = byte(x) - 64
    if b < 0 or b > 31 then
        bad = true
        return ""
    end
    return char(b)
end
function Share.Unescape(s)
    if type(s) ~= "string" or find(s, "[|%c]") then return nil end
    if find((gsub(s, "~.", "")), "~", 1, true) then return nil end
    bad = false
    local out = gsub(s, "~(.)", UnescChar)
    if bad then return nil end
    return out
end
function Share.Split(s, size)
    local out, i, n = {}, 1, #s
    while i <= n do
        local j = i + size - 1
        if j < n then
            while j > i do
                local b = byte(s, j + 1)
                if b < 128 or b >= 192 then break end
                j = j - 1
            end
        else
            j = n
        end
        out[#out + 1] = sub(s, i, j)
        i = j + 1
    end
    return out
end
local function Whisper(body, to)
    SendAddonMessage(PREFIX, body, "WHISPER", to)
end
local function Remember(key, value)
    if memo[key] == nil then
        memoOrder[#memoOrder + 1] = key
        if #memoOrder > MEMO_KEEP then memo[table.remove(memoOrder, 1)] = nil end
    end
    memo[key] = value
end
function Share.Register(who, inner, own)
    local key = Share.Parse(inner)
    if not key then return nil end
    lastId = lastId + 1
    local e = { id = lastId, who = who, self = own, inner = inner, key = key }
    entries[lastId] = e
    entries[lastId - LINK_KEEP] = nil
    return e
end
function Share.Entry(id)
    return id and entries[id] or nil
end
function Share.Linkify(msg, author, inform, line, wrap, member)
    if type(msg) ~= "string" or not find(msg, "[" .. TAG, 1, true) then return nil end
    if not Share.Accepting() then return nil end
    local own = inform == true or author == Me()
    if not own and not member and not Share.Trusted(author) then return nil end
    local mkey = tostring(author) .. "\n" .. tostring(line) .. "\n" .. msg
    local done = memo[mkey]
    if done ~= nil then return done ~= "" and done or nil end
    local changed = false
    local out = gsub(msg, "%[MRH: ([^%]|]+)%]", function(inner)
        local e = Share.Register(own and Me() or author, inner, own)
        if not e then return nil end
        changed = true
        return wrap(e, "[" .. TAG .. inner .. "]")
    end)
    Remember(mkey, changed and out or "")
    return changed and out or nil
end
local function Say(text)
    ns.Print(text)
end
local function Kb(n)
    return math.max(1, floor(n / KB + 0.5))
end
local function Eta(n)
    return math.max(1, floor(n * GAP + 0.5))
end
local function Wake()
    if ask and not ask.done then
        waitAcc = 0
        waitFrame:Show()
    else
        waitFrame:Hide()
    end
end
local function Fail(code)
    local a = ask
    if not a then return end
    ask = nil
    Wake()
    Say(format(T("share.fail." .. code), a.who))
end
function Share.Ask(entry)
    if ask and not ask.done then
        if ask.who == entry.who and ask.entry.inner == entry.inner then
            Say(T("share.ask.again"))
            return
        end
        Say(format(T("share.ask.drop"), ask.who))
    end
    lastRid = lastRid % 9999 + 1
    ask = { who = entry.who, rid = lastRid, entry = entry, got = {}, count = 0, at = GetTime() }
    Whisper(format("Q:%d:%d:%s", lastRid, VERSION, entry.inner), entry.who)
    Say(format(T("share.ask"), entry.who, entry.inner))
    Wake()
end
function Share.Asking()
    return ask
end
function Share.Open(entry)
    local E = ns.Encounters
    if not E.Ready() then Say(T("share.scan")) end
    E.Scan(function()
        local f = Share.Find(E.Fights(), entry.key)
        if f then
            if Share.onLocal then Share.onLocal(f) end
            return
        end
        if entry.self then
            Say(format(T("share.norecord"), entry.inner))
            return
        end
        Share.Ask(entry)
    end)
end
local function Foreign(a, s)
    local key = a.entry.key
    local players = {}
    for i = 1, #s.players do
        local p = s.players[i]
        players[p.name] = p.deaths or 0
    end
    return { boss = ns.EncByName(key.boss), from = a.from, to = a.to, killed = key.killed, deaths = s.deaths or 0,
        players = players, won = key.killed, wipe = not key.killed, sum = s,
        foreign = { who = a.who, inner = a.entry.inner, tver = a.tver } }
end
local function Finish(a)
    a.done = true
    Wake()
    local joined = concat(a.got, "", 1, a.n)
    local blob = Share.Unescape(joined)
    if not blob or #blob ~= a.bytes then
        if ask == a then Fail("bad") end
        return
    end
    ns.Jobs.Run(a, function()
        ns.Jobs.Label("job.share")
        return ns.Digest.Decode(blob)
    end, function(s)
        if ask ~= a then return end
        if type(s) ~= "table" then
            Fail("bad")
            return
        end
        ask = nil
        Say(format(T("share.got"), a.who))
        if Share.onForeign then Share.onForeign(Foreign(a, s)) end
    end, "share.decode")
end
local function OnHead(a, rest)
    local n, bytes, from, to, tver = match(rest, "^(%d+):(%d+):([%d%.]+):([%d%.]+):(%d+)$")
    n, bytes, from, to, tver = tonumber(n), tonumber(bytes), tonumber(from), tonumber(to), tonumber(tver)
    if not (n and bytes and from and to and tver) or a.n or n < 1 or n > MAX_CHUNKS or bytes < 1
        or bytes > MAX_BYTES or to < from then
        Fail("bad")
        return
    end
    a.n, a.bytes, a.from, a.to, a.tver = n, bytes, from, to, tver
    Say(format(T("share.eta"), a.who, Kb(bytes), Eta(n)))
    if tver ~= ns.Digest.VERSION then Say(format(T("share.version"), a.who)) end
end
local function OnData(a, rest)
    if not a.n then
        Fail("bad")
        return
    end
    local i, payload = match(rest, "^(%d+):(.*)$")
    i = tonumber(i)
    if not i or i < 1 or i > a.n or #payload > CHUNK or #payload == 0 then
        Fail("bad")
        return
    end
    if a.got[i] then return end
    a.got[i] = payload
    a.count = a.count + 1
    if a.count == a.n then Finish(a) end
end
local function OnReply(sender, kind, rest)
    local a = ask
    if not a or a.done or a.who ~= sender then return end
    local rid, tail = match(rest, "^(%d+):?(.*)$")
    if tonumber(rid) ~= a.rid then return end
    a.at = GetTime()
    a.paused = nil
    if kind == "H" then
        OnHead(a, tail)
    elseif kind == "D" then
        OnData(a, tail)
    elseif kind == "E" then
        local code = match(tail, "^(%a+)$")
        Fail((code == "none" or code == "busy") and code or "bad")
    elseif kind == "P" then
        a.paused = true
        Say(format(T("share.paused"), a.who))
    elseif kind == "W" then
        a.paused = true
    end
end
local function Busy(out)
    return out.i <= #out.msgs
end
local function Serving(who)
    for i = 1, #outs do
        if outs[i].to == who then return true end
    end
    return false
end
local function Queue(who, rid, inner, f, blob)
    local chunks = Share.Split(Share.Escape(blob), CHUNK)
    local msgs = { format("H:%d:%d:%d:%.3f:%.3f:%d", rid, #chunks, #blob, f.from, f.to, ns.Digest.VERSION) }
    for i = 1, #chunks do msgs[#msgs + 1] = format("D:%d:%d:%s", rid, i, chunks[i]) end
    outs[#outs + 1] = { to = who, rid = rid, msgs = msgs, i = 1, label = inner }
    Say(format(T("share.serve"), who, inner, Kb(#blob), Eta(#msgs)))
    pump:Show()
end
local function Resolve(who, rid, inner)
    local key = Share.Parse(inner)
    if not key then
        Whisper(format("E:%d:bad", rid), who)
        return
    end
    local E = ns.Encounters
    if not E.Ready() then Whisper(format("W:%d", rid), who) end
    E.Scan(function()
        local f = Share.Find(E.Fights(), key)
        if not f then
            Whisper(format("E:%d:none", rid), who)
            return
        end
        local blob = ns.Digest.Blob(f)
        if blob then
            Queue(who, rid, inner, f, blob)
            return
        end
        Whisper(format("W:%d", rid), who)
        ns.Summary.Compute(f, function()
            local b = ns.Digest.Blob(f)
            if b then
                Queue(who, rid, inner, f, b)
            else
                Whisper(format("E:%d:none", rid), who)
            end
        end)
    end)
end
local function OnQuery(sender, rest)
    local rid, ver, inner = match(rest, "^(%d+):(%d+):(.+)$")
    rid, ver = tonumber(rid), tonumber(ver)
    if not rid then return end
    if not Share.Trusted(sender) then
        AskRoster()
        return
    end
    local now = GetTime()
    if servedAt[sender] and now - servedAt[sender] < SERVE_EVERY then return end
    servedAt[sender] = now
    if ver ~= VERSION then
        Whisper(format("E:%d:bad", rid), sender)
        return
    end
    if Serving(sender) or #outs >= SERVE_MAX then
        Whisper(format("E:%d:busy", rid), sender)
        return
    end
    Resolve(sender, rid, inner)
end
function Share.OnAddon(prefix, body, chan, sender)
    if prefix ~= PREFIX or chan ~= "WHISPER" then return end
    if type(body) ~= "string" or type(sender) ~= "string" or sender == "" or sender == Me() then return end
    if #body > BODY_MAX or find(body, "[%c|]") then return end
    local kind, rest = match(body, "^(%u):(.*)$")
    if not kind then return end
    if kind == "Q" then
        OnQuery(sender, rest)
    else
        OnReply(sender, kind, rest)
    end
end
function Share.Post(fight, want, target)
    if not fight or fight.foreign then return false end
    if InCombat() then
        Say(T("share.err.combat"))
        return false
    end
    local chat, to, err = ns.Proof.Route(want, target)
    if err then
        Say(T((gsub(err, "^proof", "share"))))
        return false
    end
    local text = Share.Text(fight)
    if chat == "GUILD" then AskRoster() end
    SendChatMessage(text, chat, nil, to)
    Say(format(T("share.sent"), text))
    return true
end
local function PauseAll()
    for i = 1, #outs do
        local o = outs[i]
        if not o.paused then
            o.paused = true
            Whisper(format("P:%d", o.rid), o.to)
        end
    end
end
local rr = 0
pump:SetScript("OnUpdate", ns.Prof.Wrap("bg.share", function(self)
    if #outs == 0 then
        self:Hide()
        return
    end
    if InCombat() then
        PauseAll()
        return
    end
    local now = GetTime()
    if now < nextAt then return end
    rr = rr % #outs + 1
    local o = outs[rr]
    o.paused = nil
    Whisper(o.msgs[o.i], o.to)
    o.i = o.i + 1
    nextAt = now + GAP
    if not Busy(o) then
        table.remove(outs, rr)
        rr = rr - 1
    end
end))
waitFrame:SetScript("OnUpdate", ns.Prof.Wrap("bg.share", function(self, elapsed)
    waitAcc = waitAcc + (elapsed or 0)
    if waitAcc < PUMP_STEP then return end
    waitAcc = 0
    local a = ask
    if not a or a.done then
        self:Hide()
        return
    end
    if GetTime() - a.at > (a.paused and PAUSE_WAIT or ASK_WAIT) then Fail("time") end
end))
function Share.Sending()
    return #outs
end
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:SetScript("OnEvent", ns.Prof.Wrap("bg.share", function(_, event, prefix, body, chan, sender)
    if event == "CHAT_MSG_ADDON" then
        Share.OnAddon(prefix, body, chan, sender)
    else
        AskRoster()
    end
end))
