local _, ns = ...
local floor = math.floor
local min = math.min
local max = math.max
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local sub = string.sub
local concat = table.concat
local tsort = table.sort
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local wipe = wipe
local PREFIX = "FW_RNG"
local RNG = "FW_RNG"
local VERSION = 2
local STEP = 0.5
local HELLO_WAIT = 2
local HEARD_KEEP = 5
local IDLE_END = 6
local MEASURERS = 6
local NPCS = 3
local MIN_DEFAULT = 3
local MIN_LO = 3
local MIN_HI = 10
local MAX_RAID = 40
local RATE = 3
local MAX_YD = 200
local GUID_HEX = 16
local WARM_STEP = 0.2
local ERR_LEN = 200
local Ranging = {}
ns.Ranging = Ranging
Ranging.PREFIX = PREFIX
Ranging.VERSION = VERSION
Ranging.MIN_LO = MIN_LO
Ranging.MIN_HI = MIN_HI
Ranging.MIN_DEFAULT = MIN_DEFAULT
Ranging.MEASURERS = MEASURERS
local RAID_TARGET = {}
for i = 1, MAX_RAID do RAID_TARGET[i] = "raid" .. i .. "target" end
local FUSE = ns.rangingData.fuse
local session = nil
local broken = nil
local elapsed = 0
local warmI, warmAcc = 1, 0
local warmList = {}
local tip = nil
local units, guids, addOf, parts, los, his = {}, {}, {}, {}, {}, {}
local seen = {}
local heard, heardAt = {}, {}
local foreign = {}
local halt = { seg = nil }
local said, saidWhy = { seg = nil }, {}
local out = { sec = -1, n = 0 }
local total = { sent = 0, got = 0 }
local last = { enc = nil, why = nil, at = nil, sent = 0, got = 0, count = 0 }
do
    local buckets = ns.rangingData.buckets
    for i = 1, #buckets do
        local items = buckets[i].items
        for j = 1, #items do warmList[#warmList + 1] = items[j] end
    end
end
local function Opt()
    local db = ns.GetDB and ns.GetDB()
    return db and db.settings or {}
end
function Ranging.Enabled()
    return Opt().rngOn ~= false
end
function Ranging.MinClients()
    local v = tonumber(Opt().rngMin) or MIN_DEFAULT
    if v < MIN_LO then v = MIN_LO elseif v > MIN_HI then v = MIN_HI end
    return floor(v)
end
function Ranging.Session()
    return session
end
function Ranging.Working()
    local s = session
    if not s or not s.decided or not s.active then return nil end
    return s.count
end
function Ranging.Status()
    local n = 0
    for _ in pairs(foreign) do n = n + 1 end
    return { on = Ranging.Enabled(), broken = broken, session = session, last = last, foreign = n,
             sent = total.sent, got = total.got }
end
local function Attempt()
    local Rec = ns.Recorder
    if not Rec or not Rec.IsOn() or Rec.IsPaused() or not Rec.InZone() then return nil end
    local _, kind = GetInstanceInfo()
    if kind ~= "raid" then return nil end
    local live = ns.Store.Live()
    if not live or not live.pull or not ns.Store.IsNew(live) then return nil end
    return live
end
Ranging.Attempt = Attempt
local function MyRole()
    local _, cls = UnitClass("player")
    local roles = cls and ns.rangingData.roles[cls]
    if not roles then return "R" end
    local group = GetActiveTalentGroup(false, false) or 1
    local best, bestN = 1, -1
    for i = 1, 3 do
        local _, _, spent = GetTalentTabInfo(i, false, false, group)
        spent = spent or 0
        if spent > bestN then best, bestN = i, spent end
    end
    return roles[best] or "R"
end
local function NpcOf(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return nil, nil, false end
    if not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then return nil, nil, false end
    local guid = UnitGUID(unit)
    if not guid or #guid ~= GUID_HEX + 2 then return nil, nil, false end
    local key = ns.NpcKey(guid)
    local enc = key and ns.bosses[key]
    if enc then return guid, enc, true end
    local id = tonumber(sub(guid, 7, 12), 16)
    enc = id and ns.rangingData.adds[id]
    if enc then return guid, enc, false end
    return nil, nil, false
end
local function Take(unit, n, want)
    local guid, enc, boss = NpcOf(unit)
    if not guid or seen[guid] or (want and enc ~= want) then return n, nil end
    if not boss and not want then return n, nil end
    seen[guid] = true
    n = n + 1
    units[n], guids[n], addOf[n] = unit, guid, not boss
    return n, boss and UnitAffectingCombat(unit) and enc or nil
end
local function FindUnits(want)
    wipe(seen)
    local n, fighting, f = 0, nil, nil
    n, f = Take("target", n, want)
    fighting = fighting or f
    n, f = Take("focus", n, want)
    fighting = fighting or f
    for i = 1, GetNumRaidMembers() do
        n, f = Take(RAID_TARGET[i], n, want)
        fighting = fighting or f
    end
    local k = 0
    for i = 1, n do
        if not addOf[i] then
            k = k + 1
            units[k], units[i] = units[i], units[k]
            guids[k], guids[i] = guids[i], guids[k]
            addOf[k], addOf[i] = addOf[i], addOf[k]
        end
    end
    return min(n, NPCS), fighting
end
local function InBucket(b, unit)
    local items = b.items
    for i = 1, #items do
        local v = IsItemInRange(items[i], unit)
        if v == 1 or v == true then return true end
        if v == 0 or v == false then return false end
    end
    if b.interact then return CheckInteractDistance(unit, b.interact) and true or false end
    return nil
end
function Ranging.Measure(unit)
    local lo, hi = 0, nil
    local list = ns.rangingData.buckets
    for i = 1, #list do
        local r = InBucket(list[i], unit)
        if r == true then
            hi = list[i].yd
            break
        elseif r == false then
            lo = list[i].yd
        end
    end
    return lo, hi
end
local function Write(s, name, guid, lo, hi)
    local Rec = ns.Recorder
    if not Rec or not Rec.Now or ns.Store.Live() ~= s.seg or not s.seg.pull then return false end
    ns.Store.Append(Rec.Now(), RNG, nil, name, 0, guid, nil, 0, lo, hi)
    return true
end
local function Finish(why)
    local s = session
    if not s then return end
    last.enc, last.sent, last.got, last.count = s.enc, s.sent, s.got, s.count
    if why then last.why, last.at = why, time() end
    session = nil
end
local function Say(seg, why)
    if said.seg ~= seg then
        said.seg = seg
        wipe(saidWhy)
    end
    if saidWhy[why] then return false end
    saidWhy[why] = true
    ns.Print(ns.T("rng.stop." .. why))
    return true
end
local function Halt(why)
    local s = session
    local seg = s and s.seg or ns.Store.Live()
    halt.seg = seg
    Finish(why)
    last.why, last.at = why, time()
    Say(seg, why)
end
local function Broke(err)
    if broken then return end
    local text = gsub(tostring(err), "[%c|]", " ")
    broken = sub(text, 1, ERR_LEN)
    Finish("error")
    ns.Print(ns.T("rng.broken"))
end
local function Send(msg, now)
    local sec = floor(now)
    if out.sec ~= sec then out.sec, out.n = sec, 0 end
    if out.n >= FUSE.outMax then
        Halt("out")
        return false
    end
    out.n = out.n + 1
    total.sent = total.sent + 1
    if session then session.sent = session.sent + 1 end
    ns.Comm.Send(PREFIX, msg, "RAID")
    return true
end
local function Start(now, seg, enc)
    local me = UnitName("player")
    session = { seg = seg, enc = enc, at = now, last = now, peers = {}, rate = {}, rateAt = {}, decided = false,
                active = false, me = false, reply = false, count = 0, sent = 0, got = 0, order = {}, slow = 0,
                lowAt = nil, lowFps = false, inSec = -1, inN = 0, inOver = -9, inRun = 0 }
    local s = session
    s.peers[me] = MyRole()
    for name, role in pairs(heard) do
        if now - (heardAt[name] or -1e9) <= HEARD_KEEP and name ~= me then s.peers[name] = role end
    end
    wipe(heard)
    wipe(heardAt)
    if not Send("H" .. VERSION .. ":" .. s.peers[me], now) then return nil end
    return s
end
local function Decide()
    local s = session
    local list, peers, rank = s.order, s.peers, ns.rangingData.rank
    for name in pairs(peers) do list[#list + 1] = name end
    tsort(list, function(a, b)
        local ra, rb = rank[peers[a]] or 9, rank[peers[b]] or 9
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    s.decided = true
    s.count = #list
    s.active = #list >= Ranging.MinClients()
    local me = UnitName("player")
    for i = 1, min(#list, MEASURERS) do
        if list[i] == me then s.me = true end
    end
end
local function Warm(now)
    if warmI > #warmList or now - warmAcc < WARM_STEP then return end
    warmAcc = now
    local id = warmList[warmI]
    warmI = warmI + 1
    if GetItemInfo(id) then return end
    if not tip then
        tip = CreateFrame("GameTooltip", "HTP_FailWatchRangeTip", nil, "GameTooltipTemplate")
        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    tip:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0")
end
local function LowFps(s, now)
    if GetFramerate() >= FUSE.fpsMin then
        s.lowAt = nil
        return false
    end
    s.lowAt = s.lowAt or now
    if now - s.lowAt < FUSE.fpsFor then return false end
    s.me, s.lowFps = false, true
    last.why, last.at = "fps", time()
    Say(s.seg, "fps")
    return true
end
local function MeasureAll(s, n, now)
    Warm(now)
    local p0 = debugprofilestop()
    for i = 1, n do los[i], his[i] = Ranging.Measure(units[i]) end
    if debugprofilestop() - p0 > FUSE.slowMs then
        s.slow = s.slow + 1
        if s.slow >= FUSE.slowRun then
            Halt("slow")
            return
        end
    else
        s.slow = 0
    end
    local me = UnitName("player")
    local k = 0
    for i = 1, n do
        local lo, hi = los[i], his[i]
        if lo > 0 or hi then
            k = k + 1
            parts[k] = sub(guids[i], 3) .. ":" .. lo .. ":" .. (hi or "")
            Write(s, me, guids[i], lo, hi)
        end
    end
    if k > 0 then Send("M" .. concat(parts, ";", 1, k), now) end
end
local function Tick(now)
    local seg = Ranging.Enabled() and GetNumRaidMembers() > 0 and Attempt() or nil
    if not seg or seg == halt.seg then
        Finish(nil)
        return
    end
    local s = session
    if s and s.seg ~= seg then
        Finish(nil)
        s = nil
    end
    local n, enc = FindUnits(s and s.enc)
    if enc then
        if not s then
            s = Start(now, seg, enc)
            if not s then return end
        end
        s.last = now
    elseif not s then
        return
    elseif now - s.last > IDLE_END then
        Finish(nil)
        return
    end
    if not s.decided then
        if now - s.at >= HELLO_WAIT then Decide() end
        return
    end
    if s.reply then
        s.reply = false
        Send("H" .. VERSION .. ":" .. s.peers[UnitName("player")], now)
        return
    end
    if not (s.active and s.me) or n == 0 or LowFps(s, now) then return end
    MeasureAll(s, n, now)
end
local function Allowed(s, sender, now)
    if now - (s.rateAt[sender] or -1e9) >= 1 then
        s.rateAt[sender] = now
        s.rate[sender] = 0
    end
    local c = s.rate[sender] + 1
    s.rate[sender] = c
    return c <= RATE
end
local function Budget(s, now)
    local sec = floor(now)
    if s.inSec ~= sec then s.inSec, s.inN = sec, 0 end
    s.inN = s.inN + 1
    local measurers = s.decided and max(1, min(s.count, MEASURERS)) or MEASURERS
    if s.inN ~= measurers * 2 + FUSE.inSlack + 1 then return true end
    s.inRun = s.inOver == sec - 1 and s.inRun + 1 or 1
    s.inOver = sec
    if s.inRun < FUSE.inRun then return true end
    Halt("in")
    return false
end
local function OnHello(body, sender, now)
    local ver, role = match(body, "^H(%d+):(%a)$")
    if not ver or not ns.rangingData.rank[role] then return end
    if tonumber(ver) ~= VERSION then
        foreign[sender] = tonumber(ver)
        return
    end
    foreign[sender] = nil
    local s = session
    if not s then
        heard[sender], heardAt[sender] = role, now
        return
    end
    if s.peers[sender] then return end
    s.peers[sender] = role
    if s.decided then s.reply = true end
end
local function OnMeasure(s, body, sender, now)
    if not s.peers[sender] or not Allowed(s, sender, now) then return end
    for hex, lo, hi in gmatch(body, "(%x+):(%d+):(%d*)") do
        local a, b = tonumber(lo), tonumber(hi)
        if #hex == GUID_HEX and a <= MAX_YD and (not b or (b <= MAX_YD and b >= a)) then
            if Write(s, sender, "0x" .. hex, a, b) then
                s.got = s.got + 1
                total.got = total.got + 1
            end
        end
    end
end
local function OnMessage(body, sender)
    if not Ranging.Enabled() or GetNumRaidMembers() == 0 or not UnitInRaid(sender) then return end
    local now = GetTime()
    local s = session
    if s and not Budget(s, now) then return end
    local kind = sub(body, 1, 1)
    if kind == "H" then
        OnHello(body, sender, now)
    elseif kind == "M" and s then
        OnMeasure(s, body, sender, now)
    end
end
function Ranging.OnMessage(body, sender)
    if broken then return end
    local ok, err = pcall(OnMessage, body, sender)
    if not ok then Broke(err) end
end
ns.Comm.On(PREFIX, Ranging.OnMessage)
local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < STEP or broken then return end
    elapsed = 0
    local ok, err = pcall(Tick, GetTime())
    if not ok then Broke(err) end
end)
