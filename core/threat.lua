local _, ns = ...
local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local select = select
local type = type
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local unpack = unpack
local wipe = wipe
local tsort = table.sort
local gsub = string.gsub
local sub = string.sub
local SUB = "FW_THR"
local PACK = 1000
local MAX_RAID = 40
local ERR_LEN = 200
local LATE = 0.5
local CAST = "SPELL_CAST_SUCCESS"
local D = ns.threatData
local Threat = {}
ns.Threat = Threat
Threat.SUB = SUB
Threat.PACK = PACK
local RAID, RAID_PET, RAID_TARGET = {}, {}, {}
for i = 1, MAX_RAID do
    RAID[i] = "raid" .. i
    RAID_PET[i] = "raidpet" .. i
    RAID_TARGET[i] = "raid" .. i .. "target"
end
local session = nil
local halt = { seg = nil, why = nil, err = nil }
local said = { seg = nil }
local elapsed = 0
local stat = { ticks = 0, lines = 0, gone = 0, ms = 0, worst = 0 }
local units, guids, mobNames, hits, rank, order = {}, {}, {}, {}, {}, {}
local slot, dead = {}, {}
local topI, topS, topR = {}, {}, {}
local tail, memberNames = {}, {}
local written = {}
local function Opt()
    local db = ns.GetDB and ns.GetDB()
    return db and db.settings or {}
end
function Threat.Enabled()
    return Opt().thrOn ~= false
end
function Threat.Status()
    return { on = Threat.Enabled(), session = session, halt = halt.why, err = halt.err, stat = stat }
end
function Threat.Session()
    return session
end
local function Attempt()
    local R = ns.Ranging
    return R and R.Attempt and R.Attempt() or nil
end
local function Take(unit, n)
    if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return n end
    if not UnitCanAttack("player", unit) then return n end
    local guid = UnitGUID(unit)
    if not guid then return n end
    local k = slot[guid]
    if k then
        hits[k] = hits[k] + 1
        return n
    end
    if UnitIsDeadOrGhost(unit) then
        dead[guid] = true
        return n
    end
    if not UnitAffectingCombat(unit) then return n end
    n = n + 1
    local name = UnitName(unit)
    slot[guid] = n
    units[n], guids[n], mobNames[n], hits[n] = unit, guid, name, 1
    rank[n] = ns.bosses[ns.NpcKey(guid) or 0] and 1 or 0
    return n
end
local function Before(a, b)
    if rank[a] ~= rank[b] then return rank[a] > rank[b] end
    if hits[a] ~= hits[b] then return hits[a] > hits[b] end
    return a < b
end
local function Collect()
    wipe(slot)
    wipe(dead)
    local n = Take("target", 0)
    n = Take("focus", n)
    for i = 1, GetNumRaidMembers() do n = Take(RAID_TARGET[i], n) end
    for i = #order, n + 1, -1 do order[i] = nil end
    for i = 1, n do order[i] = i end
    tsort(order, Before)
    local enc = nil
    for i = 1, n do
        if rank[i] == 1 and not enc then enc = ns.bosses[ns.NpcKey(guids[i]) or 0] end
    end
    return min(n, D.mobs), enc
end
local function Insert(cnt, i, scaled, raw)
    local limit = D.top
    local pos = cnt + 1
    while pos > 1 and (topS[pos - 1] < scaled or (topS[pos - 1] == scaled and topR[pos - 1] < raw)) do
        pos = pos - 1
    end
    if pos > limit then return cnt end
    local last = cnt < limit and cnt + 1 or limit
    for j = last, pos + 1, -1 do
        topI[j], topS[j], topR[j] = topI[j - 1], topS[j - 1], topR[j - 1]
    end
    topI[pos], topS[pos], topR[pos] = i, scaled, raw
    return last
end
local function Measure(unit, nRaid)
    local cnt, holder = 0, nil
    for i = 1, nRaid do
        local isTanking, _, scaled, raw = UnitDetailedThreatSituation(RAID[i], unit)
        if scaled then
            if isTanking then holder = RAID[i] end
            cnt = Insert(cnt, i, floor(scaled + 0.5), min(D.cap, max(0, floor((raw or 0) + 0.5))))
        end
    end
    if not holder then
        for i = 1, nRaid do
            local pet = RAID_PET[i]
            if UnitExists(pet) and UnitDetailedThreatSituation(pet, unit) then
                holder = pet
                break
            end
        end
    end
    return cnt, holder
end
local function Changed(w, cnt, who)
    if not w or w.who ~= (who or false) or w.n ~= cnt then return true end
    local delta = D.delta
    for j = 1, cnt do
        local name = memberNames[topI[j]]
        local at = nil
        for q = 1, w.n do
            if w.nm[q] == name then
                at = q
                break
            end
        end
        if not at or abs(w.s[at] - topS[j]) > delta or abs(w.r[at] - topR[j]) > delta then return true end
    end
    return false
end
local function Put(now, guid, mobName, cnt, holder)
    local who = holder and UnitName(holder) or nil
    local w = written[guid]
    if w then w.seen = now end
    if not Changed(w, cnt, who) then return end
    if not w then
        w = { nm = {}, s = {}, r = {}, n = 0, who = false, seen = now }
        written[guid] = w
    end
    w.name, w.who, w.n, w.seen = mobName, who or false, cnt, now
    local k = 0
    for j = 1, cnt do
        local name = memberNames[topI[j]]
        w.nm[j], w.s[j], w.r[j] = name, topS[j], topR[j]
        tail[k + 1], tail[k + 2] = name, topR[j] * PACK + topS[j]
        k = k + 2
    end
    ns.Store.Append(now, SUB, guid, mobName, 0, holder and UnitGUID(holder) or nil, who, 0, unpack(tail, 1, k))
    stat.lines = stat.lines + 1
end
local function Sweep(now, all)
    for guid, w in pairs(written) do
        if all or dead[guid] or now - w.seen >= D.gone then
            written[guid] = nil
            ns.Store.Append(now, SUB, guid, w.name, 0)
            stat.gone = stat.gone + 1
        end
    end
end
local function Finish(close)
    local s = session
    session = nil
    if s and close and ns.Store.Live() == s.seg and ns.Recorder and ns.Recorder.Now then
        Sweep(ns.Recorder.Now(), true)
    end
    wipe(written)
end
local function Halt(why)
    local s = session
    local seg = s and s.seg or ns.Store.Live()
    halt.seg, halt.why = seg, why
    Finish(why ~= "error")
    if said.seg ~= seg then
        said.seg = seg
        ns.Print(ns.T("thr.stop." .. why))
    end
end
local function Tick(now)
    local seg = Threat.Enabled() and UnitDetailedThreatSituation and GetNumRaidMembers() > 0 and Attempt() or nil
    if not seg or seg == halt.seg then
        if session then Finish(true) end
        return
    end
    local s = session
    if s and s.seg ~= seg then
        Finish(false)
        s = nil
    end
    local n, enc = Collect()
    if enc then
        if not s then
            s = { seg = seg, enc = enc, last = now, slow = 0 }
            session = s
        end
        s.last = now
    elseif not s then
        return
    elseif now - s.last > D.idle then
        Finish(true)
        return
    end
    local p0 = debugprofilestop()
    local nRaid = GetNumRaidMembers()
    for i = 1, nRaid do memberNames[i] = UnitName(RAID[i]) end
    local stamp = ns.Recorder.Now()
    for q = 1, n do
        local k = order[q]
        local cnt, holder = Measure(units[k], nRaid)
        if cnt > 0 then Put(stamp, guids[k], mobNames[k], cnt, holder) end
    end
    Sweep(stamp, false)
    local spent = debugprofilestop() - p0
    stat.ticks, stat.ms = stat.ticks + 1, spent
    if spent > stat.worst then stat.worst = spent end
    if spent > D.fuse.ms then
        s.slow = s.slow + 1
        if s.slow >= D.fuse.run then Halt("slow") end
    else
        s.slow = 0
    end
end
function Threat.Step(dt)
    elapsed = elapsed + dt
    if elapsed < D.step then return end
    elapsed = 0
    local ok, err = pcall(Tick, GetTime())
    if not ok then
        halt.err = sub(gsub(tostring(err), "[%c|]", " "), 1, ERR_LEN)
        Halt("error")
    end
end
function Threat.New()
    return { mobs = {}, by = {}, taunts = {}, marks = {} }
end
function Threat.Feed(b, ts, guid, mobName, who, ...)
    if not guid then return end
    local m = b.by[guid]
    if not m then
        m = { guid = guid, name = mobName or "?", boss = false, first = ts, last = ts, rows = {}, spans = {},
              pulls = {} }
        b.by[guid] = m
        b.mobs[#b.mobs + 1] = m
    end
    m.last = ts
    local top = {}
    for j = 1, select("#", ...) - 1, 2 do
        local name, v = select(j, ...)
        if type(name) == "string" and type(v) == "number" then
            local raw = floor(v / PACK)
            top[#top + 1] = { name = name, raw = raw, scaled = v - raw * PACK }
        end
    end
    local rows = m.rows
    if #top == 0 and not who then
        rows[#rows + 1] = { t = ts, gone = true }
    else
        rows[#rows + 1] = { t = ts, who = who, top = top }
    end
end
function Threat.Taunt(b, who, ts)
    local list = b.taunts[who]
    if not list then
        list = {}
        b.taunts[who] = list
    end
    list[#list + 1] = ts
end
local function Taunted(b, who, t)
    local list = b.taunts[who]
    if not list then return false end
    for i = 1, #list do
        if list[i] >= t - D.taunt and list[i] <= t + LATE then return true end
    end
    return false
end
local function Spans(m, to)
    local cur = nil
    local rows = m.rows
    for i = 1, #rows do
        local r = rows[i]
        local who = not r.gone and r.who or nil
        if cur and (r.gone or cur.who ~= who) then
            cur.to = r.t
            cur = nil
        end
        if who and not cur then
            cur = { from = r.t, to = r.t, who = who }
            m.spans[#m.spans + 1] = cur
        end
    end
    if cur then cur.to = max(cur.from, to) end
end
local function BossTanks(m, tanks)
    local spans = m.spans
    if not spans[1] then return end
    tanks[spans[1].who] = true
    local held, best, bestT = {}, nil, D.tankHold
    for i = 1, #spans do
        local sp = spans[i]
        held[sp.who] = (held[sp.who] or 0) + sp.to - sp.from
        if held[sp.who] >= bestT then best, bestT = sp.who, held[sp.who] end
    end
    if best then tanks[best] = true end
end
local function MobOrder(a, b)
    if a.boss ~= b.boss then return a.boss end
    if a.first ~= b.first then return a.first < b.first end
    return a.guid < b.guid
end
function Threat.Finish(b, from, to, bosses, players)
    local tanks, all = {}, {}
    for who, list in pairs(b.taunts) do
        if #list >= D.tankTaunts then tanks[who] = true end
    end
    for i = 1, #b.mobs do
        local m = b.mobs[i]
        m.boss = (bosses and bosses[ns.NpcKey(m.guid) or 0]) and true or false
        Spans(m, to)
        if m.boss then BossTanks(m, tanks) end
    end
    tsort(b.mobs, MobOrder)
    for i = 1, #b.mobs do
        local m = b.mobs[i]
        local prev = nil
        for j = 1, #m.spans do
            local sp = m.spans[j]
            if prev and prev.to == sp.from and prev.who ~= sp.who and not tanks[sp.who]
                and (not players or players[sp.who] ~= nil) and not Taunted(b, sp.who, sp.from) then
                local p = { t = sp.from, who = sp.who, prev = prev.who, mob = m }
                m.pulls[#m.pulls + 1] = p
                all[#all + 1] = p
                sp.pull = true
            end
            prev = sp
        end
    end
    tsort(all, function(x, y) return x.t < y.t end)
    return { mobs = b.mobs, by = b.by, pulls = all, tanks = tanks, marks = b.marks, any = b.mobs[1] ~= nil,
             from = from, to = to }
end
function Threat.RowAt(m, t)
    local rows = m.rows
    local lo, hi, found = 1, #rows, 0
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if rows[mid].t <= t then
            found = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    local r = rows[found]
    if not r or r.gone then return nil end
    return r
end
function Threat.SpanAt(m, t)
    local spans = m.spans
    for i = 1, #spans do
        local sp = spans[i]
        if sp.from <= t and t < sp.to then return sp end
        if sp.from > t then break end
    end
    return nil
end
local function HeldBy(model, who, t)
    for i = 1, #model.mobs do
        local m = model.mobs[i]
        local sp = Threat.SpanAt(m, t)
        if sp and sp.who == who then return m end
    end
    return nil
end
function Threat.Series(model, who, hitT, hitG)
    local out = {}
    if not model.any then return out end
    local step = D.step
    local h, lastG, lastT = 0, nil, -1e9
    local t = model.from
    while t <= model.to do
        ns.Jobs.Step()
        while hitT[h + 1] and hitT[h + 1] <= t do
            h = h + 1
            lastG, lastT = hitG[h], hitT[h]
        end
        local m = lastG and t - lastT <= D.hitKeep and model.by[lastG] or nil
        if not (m and Threat.RowAt(m, t)) then m = HeldBy(model, who, t) end
        local raw, ceil, mob = nil, nil, nil
        local r = m and Threat.RowAt(m, t)
        if r then
            mob = m
            local top = r.top
            for i = 1, #top do
                if top[i].name == who then
                    raw = top[i].raw
                    break
                end
            end
            if not raw and #top >= D.top then
                ceil = top[1].raw
                for i = 2, #top do
                    if top[i].raw < ceil then ceil = top[i].raw end
                end
            end
        end
        local last = out[#out]
        if last and last.raw == raw and last.ceil == ceil and last.mob == mob and last.to >= t then
            last.to = t + step
        else
            out[#out + 1] = { from = t, to = t + step, raw = raw, ceil = ceil, mob = mob }
        end
        t = t + step
    end
    return out
end
function Threat.SampleAt(list, t)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        local s = list[mid]
        if t < s.from then
            hi = mid - 1
        elseif t >= s.to then
            lo = mid + 1
        else
            return s
        end
    end
    return nil
end
local models = setmetatable({}, { __mode = "k" })
local keys = setmetatable({}, { __mode = "k" })
local PLAYER_KEY = {}
local function KeyOf(fight)
    local k = keys[fight]
    if not k then
        k = {}
        keys[fight] = k
    end
    return k
end
local function ReadMarks(fight, idx, b)
    local wanted = ns.phases and ns.phases[fight.boss]
    local bosses = ns.Index.BossKeys(fight)
    local seen, taken = {}, {}
    local list = idx.common
    for i = 1, #list do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, list[i])
        local ts, what, srcGUID, _, _, _, _, _, a1, a2 = ns.Store.Decode(seg, s, at, 2)
        if ts and ts >= idx.from and ts <= idx.to then
            if what == "FW_MARK" and ns.DevMarks then
                b.marks[#b.marks + 1] = { t = ts, label = ns.DevMarks.Line(a1, a2) }
            elseif wanted and srcGUID and bosses[ns.NpcKey(srcGUID) or 0] and ns.Encounters.BOSS_SUBS[what] then
                local label = tostring(a2 or a1)
                local sk = ns.SpellOf(what, a1)
                if not seen[label] or ts - seen[label] > 3 then
                    seen[label] = ts
                    for k = 1, #wanted do
                        local w = wanted[k]
                        if sk and ns.SpellKey(w.spell) == sk and (w.every or not taken[k]) then
                            taken[k] = true
                            b.marks[#b.marks + 1] = { t = ts, label = ns.T(w.label), dim = true }
                        end
                    end
                end
            end
        end
    end
end
local function ReadTaunts(idx, b)
    local taunts = ns.taunts or {}
    local asked = {}
    for i = 1, #b.mobs do
        local rows = b.mobs[i].rows
        for j = 1, #rows do
            local who = rows[j].who
            if who and not asked[who] then asked[who] = true end
        end
    end
    for who in pairs(asked) do
        local list = idx.who[who]
        for i = 1, list and #list or 0 do
            ns.Jobs.Step()
            local seg, s, at = ns.Index.Line(idx, list[i])
            local ts, what, _, srcName, _, _, _, _, a1 = ns.Store.Decode(seg, s, at, 2)
            local sk = ns.SpellOf(what, a1)
            if what == CAST and srcName == who and sk and taunts[sk] then Threat.Taunt(b, who, ts) end
        end
    end
end
local function Build(fight, idx)
    ns.Jobs.Label("job.thr")
    local b = Threat.New()
    local list = idx.thr or {}
    for i = 1, #list do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, list[i])
        local ts, _, guid, mobName, _, _, who, _, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
            = ns.Store.Decode(seg, s, at, 10)
        if ts then Threat.Feed(b, ts, guid, mobName, who, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) end
    end
    if b.mobs[1] then
        ReadTaunts(idx, b)
        ReadMarks(fight, idx, b)
    end
    return Threat.Finish(b, idx.from, idx.to, ns.Index.BossKeys(fight), fight.players)
end
function Threat.Peek(fight)
    return fight and models[fight] or nil
end
function Threat.Load(fight, onDone)
    local ready = models[fight]
    if ready then
        onDone(ready)
        return
    end
    if ns.Store.Bare(fight) then
        onDone(nil)
        return
    end
    ns.Index.Get(fight, function(idx)
        if not idx then
            onDone(nil)
            return
        end
        ns.Jobs.Run(KeyOf(fight), function() return Build(fight, idx) end, function(model)
            if model then models[fight] = model end
            onDone(model)
        end, "thr.data", true)
    end, true)
end
local function BuildPlayer(idx, model, who)
    local hitT, hitG = {}, {}
    local list = idx.who[who]
    for i = 1, list and #list or 0 do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, list[i])
        local ts, what, _, srcName, _, dstGUID = ns.Store.Decode(seg, s, at, 0)
        if srcName == who and dstGUID and model.by[dstGUID] and what
            and (what == "SWING_DAMAGE" or what:find("_DAMAGE", 1, true)) then
            hitT[#hitT + 1], hitG[#hitG + 1] = ts, dstGUID
        end
    end
    local pulls = {}
    for i = 1, #model.pulls do
        if model.pulls[i].who == who then pulls[#pulls + 1] = model.pulls[i] end
    end
    return { who = who, samples = Threat.Series(model, who, hitT, hitG), pulls = pulls }
end
function Threat.Player(fight, who, onDone)
    Threat.Load(fight, function(model)
        if not model or not model.any then
            onDone(model, nil)
            return
        end
        ns.Index.Get(fight, function(idx)
            if not idx then
                onDone(model, nil)
                return
            end
            ns.Jobs.Cancel(PLAYER_KEY)
            ns.Jobs.Run(PLAYER_KEY, function() return BuildPlayer(idx, model, who) end, function(p)
                onDone(model, p)
            end, "thr.player", true)
        end, true)
    end)
end
function Threat.Reset()
    wipe(models)
end
