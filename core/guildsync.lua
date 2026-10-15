local _, ns = ...
local concat = table.concat
local floor = math.floor
local format = string.format
local random = math.random
local tonumber = tonumber
local type = type
local PREFIX = "MRHGL"
local CHAN = "GUILD"
local FMT = "1"
local CHUNK = 200
local MAX_PARTS = 16
local MAX_BUF = 16
local STALE = 30
local LOGIN_DELAY = 20
local SEND_GAP = 300
local ASK_GAP = 300
local RX_GAP = 60
local REPLY_LO, REPLY_HI = 2, 10
local CHANGE_DELAY = 5
local STEP = 0.5
local MAX_CHARS = 12
local MAX_SAVES = 24
local MAX_AGE = 30 * 86400
local MAX_LEFT = 15 * 86400
local KEEP = 14 * 86400
local MAX_RAID = 48
local GuildSync = {}
ns.GuildSync = GuildSync
GuildSync.PREFIX = PREFIX
GuildSync.SEND_GAP = SEND_GAP
local state = { bufs = {}, nbufs = 0, rxAt = {}, sentAt = -1e9, askedAt = -1e9, dueAt = nil,
    loginAt = nil, started = false, sig = nil, seq = 0 }
local frame = CreateFrame("Frame")
frame:Hide()
local function Peers()
    local st = ns.GuildLocks.Store()
    return st and st.peers or {}
end
local function Clean(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("[%c|,;:]", ""))
end
local function Busy()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat ~= nil and UnitAffectingCombat("player") and true or false
end
local function SaveRec(s, now)
    if not s or s.ends <= now then return nil end
    local key = Clean(s.key):sub(1, MAX_RAID)
    if key == "" then return nil end
    return format("S,%s,%d,%d,%d,%d", key, s.size, s.heroic and 1 or 0, s.id, floor(s.ends - now))
end
local function CharRec(out, c, saves, now)
    local name = Clean(c.name)
    if name == "" then return end
    local spec = c.spec and ns.guildNotes.specs[c.spec] and c.spec or ""
    local gs = tonumber(c.gs)
    out[#out + 1] = format("C,%s,%s,%d,%s,%s,%d", name, Clean(c.class), tonumber(c.level) or 0,
        gs and tostring(floor(gs)) or "", spec, floor(now - (tonumber(c.at) or now)))
    local n = 0
    for i = 1, #saves do
        local r = n < MAX_SAVES and SaveRec(saves[i], now)
        if r then
            out[#out + 1] = r
            n = n + 1
        end
    end
end
function GuildSync.Payload()
    local me = UnitName("player")
    if not me or not ns.Raid.LocksKnown() then return nil end
    local now = time()
    local GL = ns.GuildLocks
    local out = { FMT }
    local _, cls = UnitClass("player")
    local mine = {}
    local locks = ns.Raid.Locks()
    for i = 1, #locks do
        local l = locks[i]
        mine[#mine + 1] = GL.Norm({ name = l.name, size = l.size, diff = l.diff, id = l.id, ends = l.to }, "own")
    end
    CharRec(out, { name = me, class = cls, level = UnitLevel("player"), gs = GL.MyGs(), spec = GL.MySpec(), at = now },
        mine, now)
    local list = GL.Account()
    local n = 1
    for i = 1, #list do
        local c = list[i]
        if c.name ~= me and n < MAX_CHARS and type(c.saves) == "table" then
            local saves = {}
            for _, s in pairs(c.saves) do saves[#saves + 1] = GL.Norm(s, "own") end
            CharRec(out, c, saves, now)
            n = n + 1
        end
    end
    return concat(out, ";")
end
local function Split(data)
    local parts, pos, n = {}, 1, #data
    while pos <= n do
        local e = pos + CHUNK - 1
        while e > pos and e < n do
            local b = data:byte(e + 1)
            if b < 128 or b >= 192 then break end
            e = e - 1
        end
        parts[#parts + 1] = data:sub(pos, e)
        pos = e + 1
    end
    return parts
end
local function Sig()
    local p = GuildSync.Payload()
    if not p then return nil end
    return (p:gsub(",%d+;", ";"):gsub(",%d+$", ""))
end
local function Send()
    if not IsInGuild() or Busy() then return false end
    local data = GuildSync.Payload()
    if not data then return false end
    local parts = Split(data)
    if #parts > MAX_PARTS then return false end
    state.seq = state.seq % 9999 + 1
    local msgs = {}
    for i = 1, #parts do msgs[i] = format("D:%d:%d:%d:%s", state.seq, i, #parts, parts[i]) end
    state.sentAt = GetTime()
    state.sig = Sig()
    ns.Comm.Queue(PREFIX, msgs, CHAN)
    return true
end
local function Schedule(delay)
    local at = GetTime() + delay
    local gap = state.sentAt + SEND_GAP
    if at < gap then at = gap end
    if not state.dueAt or at < state.dueAt then state.dueAt = at end
    frame:Show()
end
function GuildSync.Ask()
    if not IsInGuild() then return false end
    local now = GetTime()
    if now - state.askedAt < ASK_GAP then return false end
    state.askedAt = now
    ns.Comm.Send(PREFIX, "Q", CHAN)
    return true
end
local function NameOk(name)
    return #name >= 2 and #name <= 24 and not name:find("[%s%d%p]")
end
local function ReadChar(f, now)
    if #f ~= 7 or not NameOk(f[2]) then return nil end
    local level, age = tonumber(f[4]), tonumber(f[7])
    if not level or level < 1 or level > 100 or level ~= floor(level) then return nil end
    if not age or age < 0 or age > MAX_AGE then return nil end
    if f[3] ~= "" and not ns.guildNotes.trees[f[3]] then return nil end
    local gs = nil
    if f[5] ~= "" then
        gs = tonumber(f[5])
        if not gs or not f[5]:match("^%d+$") or gs > 9999 then return nil end
    end
    if f[6] ~= "" and not ns.guildNotes.specs[f[6]] then return nil end
    return { name = f[2], class = f[3] ~= "" and f[3] or nil, level = level, gs = gs, spec = f[6] ~= "" and f[6] or nil,
        at = now - age, saves = {} }
end
local function ReadSave(f, now)
    if #f ~= 6 or f[2] == "" or #f[2] > MAX_RAID then return nil end
    local size, h, id, left = tonumber(f[3]), f[4], tonumber(f[5]), tonumber(f[6])
    if not size or size < 5 or size > 40 or (h ~= "0" and h ~= "1") then return nil end
    if not id or not f[5]:match("^%d+$") or #f[5] > 10 or id < 1 then return nil end
    if not left or not f[6]:match("^%d+$") or left > MAX_LEFT then return nil end
    return { key = f[2], size = size, heroic = h == "1" or nil, id = id, ends = now + left }
end
function GuildSync.Parse(data)
    if type(data) ~= "string" then return nil end
    local now = time()
    local recs = {}
    for r in data:gmatch("[^;]+") do recs[#recs + 1] = r end
    if recs[1] ~= FMT then return nil end
    local chars, cur = {}, nil
    for i = 2, #recs do
        local f = {}
        for v in (recs[i] .. ","):gmatch("([^,]*),") do f[#f + 1] = v end
        if f[1] == "C" then
            if #chars >= MAX_CHARS then return nil end
            cur = ReadChar(f, now)
            if not cur then return nil end
            chars[#chars + 1] = cur
        elseif f[1] == "S" and cur then
            if #cur.saves >= MAX_SAVES then return nil end
            local s = ReadSave(f, now)
            if not s then return nil end
            cur.saves[#cur.saves + 1] = s
        else
            return nil
        end
    end
    if #chars == 0 then return nil end
    return chars
end
local function Foreign(sender, name)
    if name == sender then return false end
    local GN = ns.GuildNotes
    local a, b = GN.MainOf(sender), GN.MainOf(name)
    if a == b then return false end
    local linked = b ~= name or next(GN.AltsOf(name)) ~= nil
    return linked
end
local function Accept(sender, chars)
    local members = ns.GuildNotes.Members()
    local kept = {}
    for i = 1, #chars do
        local c = chars[i]
        if members[c.name] and not Foreign(sender, c.name) then
            c.from = sender
            kept[c.name] = c
        end
    end
    Peers()[sender] = { at = time(), chars = kept }
    ns.GuildLocks.Invalidate()
end
local function OnPart(sender, seq, i, n, part)
    if n < 1 or n > MAX_PARTS or i < 1 or i > n then return end
    local buf = state.bufs[sender]
    if not buf or buf.seq ~= seq or buf.n ~= n then
        if not buf then
            if state.nbufs >= MAX_BUF then return end
            state.nbufs = state.nbufs + 1
        end
        buf = { seq = seq, n = n, parts = {}, got = 0 }
        state.bufs[sender] = buf
    end
    buf.at = GetTime()
    if not buf.parts[i] then
        buf.parts[i] = part
        buf.got = buf.got + 1
    end
    frame:Show()
    if buf.got < n then return end
    state.bufs[sender] = nil
    state.nbufs = state.nbufs - 1
    local now = GetTime()
    if now - (state.rxAt[sender] or -1e9) < RX_GAP then return end
    local chars = GuildSync.Parse(concat(buf.parts, "", 1, n))
    if not chars then return end
    state.rxAt[sender] = now
    Accept(sender, chars)
end
function GuildSync.OnMessage(body, sender, chan)
    if chan ~= CHAN or not ns.GuildNotes.Member(sender) then return end
    if body == "Q" then
        Schedule(REPLY_LO + random() * (REPLY_HI - REPLY_LO))
        return
    end
    local seq, i, n, part = body:match("^D:(%d+):(%d+):(%d+):(.*)$")
    if seq and #seq <= 4 and #i <= 2 and #n <= 2 then
        OnPart(sender, tonumber(seq), tonumber(i), tonumber(n), part)
    end
end
function GuildSync.Char(name)
    local best = nil
    for _, p in pairs(Peers()) do
        local c = type(p) == "table" and type(p.chars) == "table" and p.chars[name]
        if type(c) == "table" and (not best or (c.at or 0) > (best.at or 0)) then best = c end
    end
    return best
end
function GuildSync.Accounts()
    local out = {}
    for sender, p in pairs(Peers()) do
        if type(p) == "table" and type(p.chars) == "table" then
            local g = { [sender] = true }
            for name in pairs(p.chars) do g[name] = true end
            out[sender] = g
        end
    end
    return out
end
local function Prune()
    local members = ns.GuildNotes.Members()
    if not next(members) then return end
    local now = time()
    local peers = Peers()
    for sender, p in pairs(peers) do
        if type(p) ~= "table" or not members[sender] or (tonumber(p.at) or 0) < now - KEEP then peers[sender] = nil end
    end
end
local function Tick(now)
    local busy = false
    if state.loginAt then
        busy = true
        if now >= state.loginAt and not Busy() then
            state.loginAt = nil
            if IsInGuild() then
                Prune()
                Send()
                GuildSync.Ask()
            end
        end
    end
    if state.dueAt then
        busy = true
        if now >= state.dueAt and not Busy() then
            state.dueAt = nil
            Send()
        end
    end
    for sender, buf in pairs(state.bufs) do
        busy = true
        if now - buf.at > STALE then
            state.bufs[sender] = nil
            state.nbufs = state.nbufs - 1
        end
    end
    return busy
end
local acc = 0
frame:SetScript("OnUpdate", ns.Prof.Wrap("bg.guildsync", function(self, dt)
    acc = acc + dt
    if acc < STEP then return end
    acc = 0
    if not Tick(GetTime()) then self:Hide() end
end))
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_INSTANCE_INFO")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", ns.Prof.Wrap("bg.guildsync", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        state.loginAt, state.started = GetTime() + LOGIN_DELAY, true
        frame:Show()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if state.dueAt or state.loginAt then frame:Show() end
        return
    end
    if not state.started or state.loginAt or not IsInGuild() then return end
    local sig = Sig()
    if sig and sig ~= state.sig then Schedule(CHANGE_DELAY) end
end))
ns.Comm.On(PREFIX, GuildSync.OnMessage)
