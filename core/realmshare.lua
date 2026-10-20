local _, ns = ...
local floor = math.floor
local tonumber = tonumber
local match = string.match
local gmatch = string.gmatch
local sub = string.sub
local format = string.format
local PREFIX = "MRH_RLM"
local STEP = 1
local FRESH = 2.5
local FRESH_REALM = 6
local PEER_FRESH = 6
local WINDOW = 0.9
local MAX_CHUNKS = 6
local MAX_PEERS = 40
local MAX_MEMBERS = 40
local MAX_BODY = 240
local MAX_LEVEL = 20
local UNITS = 10000
local MY_STEP = 0.5
local BOSS_UNITS = { "boss1", "boss2" }
local HEAD = "^2:([12]):(%d+):(.+)$"
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local CELL = "^[0-9a-z][0-9a-z][0-9a-z]$"
local S = { PREFIX = PREFIX, MAX_BODY = MAX_BODY }
ns.RealmShare = S
local points = {}
local pointN = 0
local peers = {}
local peerN = 0
local elapsed = 0
local myW, myT = 1, nil
local auraSet
local auraNames
local stats = { sent = 0, chunks = 0, got = 0, points = 0, dropped = 0, used = 0 }
S.stats = stats
local function FightDef()
    local rd = ns.replayMech and ns.replayMech.realms
    if not rd then return nil end
    for i = 1, #BOSS_UNITS do
        local id = ns.NpcEntry(UnitGUID(BOSS_UNITS[i]))
        local key = id and ns.NpcKeyOf(id)
        local def = key and ns.bosses[key] and rd[ns.bosses[key]]
        if def then return def end
    end
    return nil
end
local function AuraNames()
    if auraNames then return auraNames end
    local out = {}
    for _, def in pairs(ns.replayMech.realms or {}) do
        for i = 1, #(def.aura or {}) do
            local name = GetSpellInfo(def.aura[i])
            if name then out[#out + 1] = name end
        end
    end
    auraNames = out
    return out
end
local function RealmOfUnit(unit)
    local names = AuraNames()
    for i = 1, #names do
        if UnitAura(unit, names[i]) then return 2 end
    end
    return 1
end
S.RealmOfUnit = RealmOfUnit
local function Mine()
    local now = GetTime()
    if not myT or now - myT >= MY_STEP then myW, myT = RealmOfUnit("player"), now end
    return myW
end
S.Mine = Mine
local function Enc(v)
    local a, b, c = floor(v / 1296), floor(v / 36) % 36, v % 36
    return sub(DIGITS, a + 1, a + 1) .. sub(DIGITS, b + 1, b + 1) .. sub(DIGITS, c + 1, c + 1)
end
S.Enc = Enc
local function Put(unit, name, out)
    local px, py = GetPlayerMapPosition(unit)
    if not px or (px == 0 and py == 0) then return end
    local x, y = floor(px * UNITS + 0.5), floor(py * UNITS + 0.5)
    if x < 0 or y < 0 or x > UNITS or y > UNITS then return end
    out[#out + 1] = name .. Enc(x) .. Enc(y)
end
function S.Collect(all)
    local w = RealmOfUnit("player")
    myW, myT = w, GetTime()
    local out = {}
    local me = UnitName("player")
    if me then Put("player", me, out) end
    if not all then return out, w end
    for i = 1, GetNumRaidMembers() do
        local unit = "raid" .. i
        local name = UnitName(unit)
        if name and name ~= me and UnitIsVisible(unit) and RealmOfUnit(unit) == w then Put(unit, name, out) end
    end
    return out, w
end
function S.Pack(entries, w, level)
    local head = format("2:%d:%d:", w, level)
    local msgs, cur = {}, nil
    for i = 1, #entries do
        local e = entries[i]
        if cur and #cur + 1 + #e <= MAX_BODY then
            cur = cur .. ";" .. e
        else
            if cur then msgs[#msgs + 1] = cur end
            cur = head .. e
        end
    end
    if cur then msgs[#msgs + 1] = cur end
    return msgs
end
local function OtherHeard(w)
    local now = GetTime()
    for _, p in pairs(peers) do
        if p.w ~= w and now - p.t <= PEER_FRESH then return true end
    end
    return false
end
function S.Messages()
    local all = OtherHeard(Mine())
    local entries, w = S.Collect(all)
    if #entries == 0 then return nil end
    return S.Pack(entries, w, GetCurrentMapDungeonLevel() or 0)
end
local function Peer(sender, now)
    local p = peers[sender]
    if not p then
        if peerN >= MAX_PEERS then return nil end
        peerN = peerN + 1
        p = { t0 = now, n = 0, w = 1, t = now }
        peers[sender] = p
    end
    if now - p.t0 >= WINDOW then p.t0, p.n = now, 0 end
    p.n = p.n + 1
    if p.n > MAX_CHUNKS then return nil end
    return p
end
local function Parse(list)
    local out = {}
    for e in gmatch(list, "[^;]+") do
        if #e < 7 then return nil end
        local xs, ys = sub(e, -6, -4), sub(e, -3)
        if not (match(xs, CELL) and match(ys, CELL)) then return nil end
        local x, y = tonumber(xs, 36), tonumber(ys, 36)
        if x > UNITS or y > UNITS then return nil end
        out[#out + 1] = { sub(e, 1, -7), x, y }
        if #out > MAX_MEMBERS then return nil end
    end
    return out
end
function S.Receive(body, sender, chan)
    if chan ~= "RAID" or GetNumRaidMembers() == 0 or not UnitInRaid(sender) or #body > MAX_BODY then
        stats.dropped = stats.dropped + 1
        return false
    end
    local w, level, list = match(body, HEAD)
    w, level = tonumber(w), tonumber(level)
    local got = w and level <= MAX_LEVEL and Parse(list)
    if not got then
        stats.dropped = stats.dropped + 1
        return false
    end
    local now = GetTime()
    local p = Peer(sender, now)
    if not p then
        stats.dropped = stats.dropped + 1
        return false
    end
    p.w, p.t = w, now
    local me = UnitName("player")
    for i = 1, #got do
        local name, x, y = got[i][1], got[i][2], got[i][3]
        if name ~= me and UnitInRaid(name) then
            local pt = points[name]
            if not pt and pointN < MAX_MEMBERS then
                pointN = pointN + 1
                pt = {}
                points[name] = pt
            end
            if pt then
                pt.t, pt.x, pt.y, pt.level, pt.w = now, x, y, level, w
                stats.points = stats.points + 1
            end
        end
    end
    stats.got = stats.got + 1
    return true
end
function S.Pos(name)
    local p = points[name]
    if not p or GetTime() - p.t > FRESH then return nil, nil end
    if p.level ~= (GetCurrentMapDungeonLevel() or 0) then return nil, nil end
    return p.x / UNITS, p.y / UNITS
end
function S.Realm(name, age)
    local p = points[name]
    if not p or GetTime() - p.t > (age or FRESH) then return nil end
    return p.w
end
function S.Pick(name, px, py)
    if pointN == 0 then return px, py, false end
    local p = points[name]
    if not p then return px, py, false end
    local sx, sy = S.Pos(name)
    if not sx then return px, py, false end
    if ((px or 0) == 0 and (py or 0) == 0) or p.w ~= Mine() then
        stats.used = stats.used + 1
        return sx, sy, true
    end
    return px, py, false
end
function S.AuraCount(name, spellId)
    if pointN == 0 then return nil end
    if not auraSet then
        auraSet = {}
        for _, def in pairs(ns.replayMech.realms or {}) do
            ns.IdSet(def.aura, auraSet)
        end
    end
    if not auraSet[spellId] then return nil end
    local w = S.Realm(name, FRESH_REALM)
    if not w then return nil end
    return w == 2 and 1 or 0
end
function S.Reset()
    points, pointN, peers, peerN = {}, 0, {}, 0
end
function S.Step(dt)
    elapsed = elapsed + dt
    if elapsed < STEP then return end
    elapsed = 0
    if GetNumRaidMembers() == 0 or not FightDef() then
        if pointN > 0 or peerN > 0 then S.Reset() end
        return
    end
    if ns.Comm.Queued() > 0 then return end
    local msgs = S.Messages()
    if not msgs then return end
    ns.Comm.Queue(PREFIX, msgs, "RAID")
    stats.sent = stats.sent + 1
    stats.chunks = stats.chunks + #msgs
end
ns.Comm.On(PREFIX, function(body, sender, chan)
    local ok = pcall(S.Receive, body, sender, chan)
    if not ok then stats.dropped = stats.dropped + 1 end
end)
local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.realm", function(_, dt)
    local ok = pcall(S.Step, dt)
    if not ok then elapsed = 0 end
end))
