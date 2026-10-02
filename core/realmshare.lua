local _, ns = ...
local floor = math.floor
local tonumber = tonumber
local match = string.match
local format = string.format
local PREFIX = "MRH_RLM"
local STEP = 1
local FRESH = 2.5
local MIN_GAP = 0.8
local MAX_PEERS = 40
local UNITS = 10000
local BOSS_UNITS = { "boss1", "boss2" }
local PATTERN = "^1:(%d+),(%d+),(%d+),([12])$"
local S = { PREFIX = PREFIX }
ns.RealmShare = S
local peers = {}
local peerN = 0
local elapsed = 0
local stats = { sent = 0, got = 0, dropped = 0 }
S.stats = stats
local function InFight()
    local rd = ns.replayMech and ns.replayMech.realms
    if not rd then return false end
    for i = 1, #BOSS_UNITS do
        local id = ns.NpcEntry(UnitGUID(BOSS_UNITS[i]))
        local key = id and ns.NpcKeyOf(id)
        if key and ns.bosses[key] and rd[ns.bosses[key]] then return true end
    end
    return false
end
S.InFight = InFight
local function MyRealm()
    local rd = ns.replayMech.realms
    for _, def in pairs(rd) do
        for i = 1, #(def.aura or {}) do
            local name = GetSpellInfo(def.aura[i])
            if name and UnitAura("player", name) then return 2 end
        end
    end
    return 1
end
function S.Message()
    local px, py = GetPlayerMapPosition("player")
    if not px or (px == 0 and py == 0) then return nil end
    local x, y = floor(px * UNITS + 0.5), floor(py * UNITS + 0.5)
    if x < 0 or y < 0 or x > UNITS or y > UNITS then return nil end
    return format("1:%d,%d,%d,%d", x, y, GetCurrentMapDungeonLevel() or 0, MyRealm())
end
function S.Receive(body, sender, chan)
    if chan ~= "RAID" or GetNumRaidMembers() == 0 or not UnitInRaid(sender) then
        stats.dropped = stats.dropped + 1
        return false
    end
    local x, y, level, w = match(body, PATTERN)
    x, y, level, w = tonumber(x), tonumber(y), tonumber(level), tonumber(w)
    if not x or x > UNITS or y > UNITS or level > 20 then
        stats.dropped = stats.dropped + 1
        return false
    end
    local now = GetTime()
    local p = peers[sender]
    if p and now - p.t < MIN_GAP then
        stats.dropped = stats.dropped + 1
        return false
    end
    if not p then
        if peerN >= MAX_PEERS then
            stats.dropped = stats.dropped + 1
            return false
        end
        peerN = peerN + 1
        p = {}
        peers[sender] = p
    end
    p.t, p.x, p.y, p.level, p.w = now, x, y, level, w
    stats.got = stats.got + 1
    return true
end
function S.Pos(name)
    local p = peers[name]
    if not p or GetTime() - p.t > FRESH then return nil, nil end
    if p.level ~= (GetCurrentMapDungeonLevel() or 0) then return nil, nil end
    return p.x / UNITS, p.y / UNITS
end
function S.Realm(name)
    local p = peers[name]
    if not p or GetTime() - p.t > FRESH then return nil end
    return p.w
end
function S.Reset()
    peers, peerN = {}, 0
end
function S.Step(dt)
    elapsed = elapsed + dt
    if elapsed < STEP then return end
    elapsed = 0
    if GetNumRaidMembers() == 0 or not InFight() then
        if peerN > 0 then S.Reset() end
        return
    end
    local msg = S.Message()
    if msg then
        ns.Comm.Send(PREFIX, msg, "RAID")
        stats.sent = stats.sent + 1
    end
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
