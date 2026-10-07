local _, ns = ...
local floor = math.floor
local abs = math.abs
local format = string.format
local tsort = table.sort
local TOTALS_VERSION = 36
local TRASH_VERSION = 2
local ABIL_KEEP = 10
local TRASH_KEY = "#trash"
local FROZEN = "frozen"
local SKIP_HP = { "FW_HP" }
local MAX_TAIL = 9
local TO_SLACK = 0.01
local ROOTS = { "summaries", "buffsGiven", "actions", "achDefs", "bossPhases", "penaltyPresets", "immunities",
                "defensives", "shieldSpells", "shieldEat", "shieldPassive", "consumeCast", "consumeCreate",
                "consumeEnchant", "consumeAura", "vehicles", "fixates", "taunts", "tankSpells", "scriptedKills", "bossParts" }
local COMMON = { "buffsGiven", "actions", "immunities", "defensives", "shieldSpells", "shieldEat", "shieldPassive",
                 "consumeCast", "consumeCreate", "consumeEnchant", "consumeAura", "vehicles", "fixates", "taunts", "tankSpells",
                 "scriptedKills", "bosses", "trashBosses", "bossParts", "bossWin", "bossSurvive", "pullTimer", "deathDeps" }
local DROP = { byName = true, track = true, set = true, rides = true, apart = true }
local STAT_ZERO = { n = true, hits = true, amount = true, cleansed = true, max = true }
local STAT_LIST = { times = true, notes = true }
local Digest = {}
ns.Digest = Digest
Digest.VERSION = TOTALS_VERSION
local extIndex = nil
local sigs = {}
local commonSig = nil
local function Walk(t, path, index)
    if index[t] then return end
    index[t] = path
    for k, v in pairs(t) do
        local tk = type(k)
        if type(v) == "table" and (tk == "string" or tk == "number") then
            local sub = {}
            for i = 1, #path do sub[i] = path[i] end
            sub[#sub + 1] = k
            Walk(v, sub, index)
        end
    end
end
local function ExtIndex()
    if extIndex then return extIndex end
    local index = {}
    for i = 1, #ROOTS do
        local root = ns[ROOTS[i]]
        if type(root) == "table" then Walk(root, { ROOTS[i] }, index) end
    end
    extIndex = index
    return index
end
local function ExtOf(t)
    return extIndex[t]
end
local function Resolve(path)
    local t = ns[path[1]]
    for i = 2, #path do
        if type(t) ~= "table" then return nil end
        t = t[path[i]]
    end
    return type(t) == "table" and t or nil
end
local function Common()
    if commonSig then return commonSig end
    local parts = {}
    for i = 1, #COMMON do parts[i] = ns[COMMON[i]] or false end
    commonSig = ns.Codec.Sig(TOTALS_VERSION, unpack(parts)) .. (ns.TuneSig and ns.TuneSig() or "")
    return commonSig
end
function Digest.Sig(boss)
    local s = sigs[boss]
    if s then return s end
    local watch = ns.Penalties and ns.Penalties.Watch(boss) or false
    local ach = ns.Achievements and ns.Achievements.Defs(boss) or false
    s = TOTALS_VERSION .. ":" .. Common() .. ":" .. ns.Codec.Sig(boss, ns.summaries and ns.summaries[boss] or false,
        ns.bossPhases and ns.bossPhases[boss] or false, watch, ach)
    sigs[boss] = s
    return s
end
function Digest.Forget()
    for k in pairs(sigs) do sigs[k] = nil end
    commonSig = nil
    extIndex = nil
end
local function Key(fight)
    return format("%s|%.0f", fight.boss, floor(fight.from * 1000 + 0.5))
end
local function SegOf(fight)
    local segs = ns.GetDB().segments
    return fight.seg and segs[fight.seg] or nil
end
local function Count(set)
    local n = 0
    for _ in pairs(set or {}) do n = n + 1 end
    return n
end
local function EmptyStat(st)
    for k, v in pairs(st) do
        if STAT_ZERO[k] then
            if v ~= 0 then return false end
        elseif STAT_LIST[k] then
            if type(v) ~= "table" or next(v) ~= nil then return false end
        else
            return false
        end
    end
    return true
end
local function ByAmount(a, b)
    if a.r.a ~= b.r.a then return a.r.a > b.r.a end
    return a.key < b.key
end
local function Top(own, pets)
    local list = {}
    for key, r in pairs(own or {}) do
        if r.a > 0 then list[#list + 1] = { key = key, r = r } end
    end
    for key, r in pairs(pets or {}) do
        if r.a > 0 then list[#list + 1] = { key = key, r = r, pet = true } end
    end
    tsort(list, ByAmount)
    local keep, keepPets = {}, pets and {} or nil
    local rest
    for k = 1, #list do
        local e = list[k]
        if k <= ABIL_KEEP then
            if e.pet then keepPets[e.key] = e.r else keep[e.key] = e.r end
        else
            rest = rest or { n = 0, a = 0 }
            rest.n = rest.n + 1
            rest.a = rest.a + e.r.a
        end
    end
    return keep, keepPets, rest
end
local function Pack(s)
    local ps = {}
    for k, v in pairs(s) do ps[k] = v end
    local players = {}
    local nb = #s.badges
    for i = 1, #s.players do
        local p = s.players[i]
        local cp = {}
        for k, v in pairs(p) do cp[k] = v end
        local badges = {}
        for j = 1, nb do
            local st = p.badges[j]
            badges[j] = (st == nil or EmptyStat(st)) and 0 or st
        end
        cp.badges = badges
        if p.role == "heal" then
            local rest
            cp.healBy, rest, cp.abRest = Top(p.healBy, nil)
            cp.dmgBy, cp.petBy = nil, nil
        else
            cp.dmgBy, cp.petBy, cp.abRest = Top(p.dmgBy, p.petBy)
            cp.healBy = nil
        end
        players[i] = cp
    end
    ps.players = players
    return ps
end
local function Unpack(s)
    local byName = {}
    local nb = #s.badges
    for i = 1, #s.players do
        local p = s.players[i]
        for j = 1, nb do
            if p.badges[j] == 0 or p.badges[j] == nil then
                p.badges[j] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
            end
        end
        p.dmgBy = p.dmgBy or {}
        p.healBy = p.healBy or {}
        p.petBy = p.petBy or {}
        if not p.class then p.class = ns.Encounters.ClassOf(p.name) end
        byName[p.name] = p
    end
    s.byName = byName
    return s
end
local function Entry(fight)
    local seg = SegOf(fight)
    local e = seg and seg.totals and seg.totals[Key(fight)]
    if type(e) ~= "table" or type(e.s) ~= "string" then return nil end
    if abs((e.to or 0) - fight.to) > TO_SLACK or e.n ~= Count(fight.players) then return nil end
    if e.sig ~= Digest.Sig(fight.boss) and not ns.Store.Bare(fight) then return nil end
    return e
end
function Digest.Has(fight)
    return Entry(fight) ~= nil
end
function Digest.Stale(fight)
    local seg = SegOf(fight)
    if seg == nil or ns.Store.Bare(fight) then return false end
    return seg.totals ~= nil and seg.totals[Key(fight)] ~= nil and Entry(fight) == nil
end
function Digest.Load(fight)
    local e = Entry(fight)
    if not e then return nil end
    ExtIndex()
    local s, ok = ns.Codec.Decode(e.s, Resolve)
    if not ok or type(s) ~= "table" or type(s.players) ~= "table" or type(s.badges) ~= "table" then
        local seg = SegOf(fight)
        if seg and seg.totals then seg.totals[Key(fight)] = nil end
        return nil
    end
    return Unpack(s)
end
local function Prune(seg, i)
    local live = {}
    local list = ns.Encounters.Fights()
    for k = 1, #list do
        if list[k].seg == i then live[Key(list[k])] = true end
    end
    for key in pairs(seg.totals) do
        if key ~= TRASH_KEY and not live[key] then seg.totals[key] = nil end
    end
end
function Digest.Save(fight, s)
    local seg = SegOf(fight)
    if not seg or ns.Store.Bare(fight) then return nil end
    ExtIndex()
    local blob = ns.Codec.Encode(Pack(s), ExtOf, DROP)
    seg.totals = seg.totals or {}
    if ns.Encounters.Ready() then Prune(seg, fight.seg) end
    seg.totals[Key(fight)] = { sig = Digest.Sig(fight.boss), to = fight.to, n = Count(fight.players), s = blob }
    return #blob
end
function Digest.Size(fight)
    local e = Entry(fight)
    return e and #e.s or 0
end
function Digest.Clear()
    for _, seg in ns.Store.Segments() do
        if not seg.bare then
            local keep = Digest.Frozen(seg) and seg.totals[TRASH_KEY] or nil
            seg.totals = keep and { [TRASH_KEY] = keep } or nil
        end
    end
end
local function Windows(seg)
    local t0, t1 = seg.t0, seg.t1 or seg.t0
    local out, before = {}, 0
    local list = ns.Encounters.Fights()
    for k = 1, #list do
        local f = list[k]
        if f.to >= t0 and f.from <= t1 then
            out[#out + 1] = f
        elseif f.to < t0 and f.to > before then
            before = f.to
        end
    end
    tsort(out, function(a, b) return a.from < b.from end)
    return out, before
end
local function WinSig(wins)
    local parts = { TRASH_VERSION, Common() }
    for k = 1, #wins do
        parts[#parts + 1] = format("%.0f-%.0f", floor(wins[k].from * 1000 + 0.5), floor(wins[k].to * 1000 + 0.5))
    end
    return table.concat(parts, ",")
end
local function ReadGap(part, seg, lo, hi, lines)
    for ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5, a6, a7, _, a9
        in ns.Store.Events(seg, lo, hi, SKIP_HP, MAX_TAIL, ns.Encounters.KeepHp, lines) do
        ns.Jobs.Step()
        if sub and (not lo or ts > lo) and (not hi or ts < hi) then
            ns.RaidPart.Feed(part, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                a1, a2, a3, a4, a5, a6, a7, a9)
        end
    end
end
local function TrashPass(i, seg)
    local wins, before = Windows(seg)
    local shared = ns.Encounters.HpLines(-math.huge, math.huge)
    local known = {}
    for k = 1, #wins do
        for name in pairs(wins[k].players or {}) do known[name] = true end
    end
    local part = ns.RaidPart.New(nil, ns.GetDB().pets or {}, shared, known)
    part.fightAt = before
    local died, lines = {}, {}
    local lo = nil
    for k = 1, #wins + 1 do
        local w = wins[k]
        local hi = w and w.from or nil
        if not (lo and hi and hi <= lo) then
            ns.RaidPart.Interval(part, hi or seg.t1 or seg.t0)
            local from = #part.died
            ReadGap(part, seg, lo, hi, shared)
            local hp = { from = lo or -math.huge, to = hi or math.huge, list = shared.list, bySeg = shared.bySeg }
            for d = from + 1, #part.died do
                died[#died + 1] = part.died[d]
                lines[#died] = hp
            end
        end
        if w then
            lo = lo and math.max(lo, w.to) or w.to
            if w.to > part.fightAt then part.fightAt = w.to end
        end
    end
    local piece = ns.RaidPart.Close(part, nil)
    local deaths = {}
    for d = 1, #died do
        local e = died[d]
        if ns.Encounters.RealDeathIn({ seg = i }, e.who, e.t, lines[d], seg) then
            deaths[e.who] = (deaths[e.who] or 0) + 1
        end
    end
    piece.deaths = deaths
    return piece
end
function Digest.Trash(i, seg)
    local e = seg.totals and seg.totals[TRASH_KEY]
    if type(e) == "table" and (e.sig == FROZEN or seg.bare) and type(e.s) == "string" then
        local piece, ok = ns.Codec.Decode(e.s, nil)
        if ok and type(piece) == "table" then return piece end
    end
    local wins = Windows(seg)
    local sig = WinSig(wins)
    if type(e) == "table" and e.sig == sig and type(e.s) == "string" then
        local piece, ok = ns.Codec.Decode(e.s, nil)
        if ok and type(piece) == "table" then return piece end
    end
    local piece = TrashPass(i, seg)
    seg.totals = seg.totals or {}
    seg.totals[TRASH_KEY] = { sig = sig, s = ns.Codec.Encode(piece, nil, nil) }
    return piece
end
function Digest.HasTrash(i, seg)
    local e = seg.totals and seg.totals[TRASH_KEY]
    if seg.bare then return true end
    return type(e) == "table" and (e.sig == FROZEN or e.sig == WinSig((Windows(seg))))
end
function Digest.Freeze(seg, piece)
    seg.totals = seg.totals or {}
    seg.totals[TRASH_KEY] = { sig = FROZEN, s = ns.Codec.Encode(piece, nil, nil) }
end
function Digest.Frozen(seg)
    local e = seg.totals and seg.totals[TRASH_KEY]
    return type(e) == "table" and e.sig == FROZEN
end
function Digest.Stats()
    local n, bytes, trash = 0, 0, 0
    for _, seg in ns.Store.Segments() do
        for key, e in pairs(seg.totals or {}) do
            if type(e) == "table" and type(e.s) == "string" then
                if key == TRASH_KEY then
                    trash = trash + #e.s
                else
                    n = n + 1
                    bytes = bytes + #e.s
                end
            end
        end
    end
    return n, bytes, trash
end
local REFRESH_KEY = "digest.refresh"
function Digest.Refresh()
    if ns.Jobs.Busy(REFRESH_KEY) then return end
    local list = ns.Encounters.Fights()
    local stale = {}
    for k = 1, #list do
        if Digest.Stale(list[k]) then stale[#stale + 1] = list[k] end
    end
    if #stale == 0 then return end
    ns.Jobs.Run(REFRESH_KEY, function()
        for k = 1, #stale do
            local f = stale[k]
            if Digest.Stale(f) then ns.Summary.Full(f) end
            ns.Jobs.Yield()
        end
        return true
    end, nil, "digest.refresh")
end
