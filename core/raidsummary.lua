local _, ns = ...
local floor = math.floor
local max = math.max
local tsort = table.sort
local SESSION_GAP = 3600
local QUIET_OUT = 3600
local QUIET_LONG = 12 * 3600
local TRASH = "#trash"
local KEEP = 2
local RaidSum = {}
ns.RaidSummary = RaidSum
RaidSum.TRASH = TRASH
local cache = {}
local order = {}
local jobKeys = {}
local failed = {}
local function FightSegs(raid)
    local set = {}
    for k = 1, #raid.encs do
        local list = raid.encs[k].fights
        for n = 1, #list do
            local f = list[n]
            if f.segs then
                for s = 1, #f.segs do set[f.segs[s]] = true end
            elseif f.seg then
                set[f.seg] = true
            end
        end
    end
    return set
end
local function Tag(raid, seg)
    local r = seg.raid
    if not r then return nil end
    if ns.Raid.Key(r) == raid.key then return true end
    if not r.id and r.name == raid.name and r.size == raid.size then return nil end
    return false
end
function RaidSum.Segments(raid)
    local mine = FightSegs(raid)
    local lo, hi
    for i, seg in ns.Store.Segments() do
        if mine[i] or Tag(raid, seg) == true then
            mine[i] = true
            if not lo or seg.t0 < lo then lo = seg.t0 end
            local t1 = seg.t1 or seg.t0
            if not hi or t1 > hi then hi = t1 end
        end
    end
    local out = {}
    for i, seg in ns.Store.Segments() do
        local own = mine[i] or (lo ~= nil and Tag(raid, seg) == nil and seg.t0 >= lo and (seg.t1 or seg.t0) <= hi)
        if own then out[#out + 1] = { i = i, seg = seg } end
    end
    return out
end
local function Signature(raid, segs)
    local first, last = segs[1], segs[#segs]
    return string.format("%d|%d|%d|%d|%d", raid.tries, floor(raid.to),
        first and floor(first.seg.t0) or 0, last and floor(last.seg.t0) or 0, #segs)
end
local function Attempts(raid)
    local out = {}
    for k = 1, #raid.encs do
        local list = raid.encs[k].fights
        for n = 1, #list do out[#out + 1] = list[n] end
    end
    tsort(out, function(a, b) return a.from < b.from end)
    return out
end
local function IsBoss(fight, npc)
    return ns.IsBossKey(fight, ns.NpcKeyOf(npc))
end
local function NewPlayer(name)
    return { name = name, class = ns.Encounters.ClassOf(name), all = 0, cut = 0, enc = 0, boss = 0, heal = 0,
             deaths = 0, deathBy = {}, flask = 0, elixir = 0, potion = 0, food = 0, scroll = 0, other = 0,
             stone = 0, used = {}, tries = 0, prio = 0, prioBy = {}, bad = 0, badHits = 0, badBy = {}, kicks = 0,
             cures = 0, purges = 0, first = 0, firstBy = {}, buffN = 0, buffSec = 0, buffBy = {}, rod = 0, rodBy = {},
             jopo = 0, jopoKill = 0, jopoBy = {} }
end
local function TimeOf(fights)
    local t = { combat = 0, wipe = 0, idle = 0, gaps = 0 }
    for k = 1, #fights do
        local f = fights[k]
        local dur = max(0, f.to - f.from)
        t.combat = t.combat + dur
        if not f.killed then t.wipe = t.wipe + dur end
        if not t.long or dur > t.long.to - t.long.from then t.long = f end
        local prev = fights[k - 1]
        local gap = prev and f.from - prev.to or 0
        if gap > 0 and gap <= SESSION_GAP then
            t.idle = t.idle + gap
            t.gaps = t.gaps + 1
            if not t.longest or gap > t.longest.dur then
                t.longest = { dur = gap, from = prev.to, to = f.from, after = prev, before = f }
            end
        end
    end
    return t
end
local function NewSum(raid, segs)
    local res = {
        key = raid.key, name = raid.name, size = raid.size, heroic = raid.heroic, id = raid.id, map = raid.map,
        from = raid.from, to = raid.to, busy = 0, sessions = 0, tries = raid.tries, wipes = 0,
        passed = raid.passed, encs = #raid.encs, known = raid.map and ns.raidEncounters
            and ns.raidEncounters[raid.map] or nil,
        trash = 0, segs = #segs, players = {}, byName = {}, spent = {}, earned = {}, sums = {},
        sig = Signature(raid, segs),
    }
    local fights = Attempts(raid)
    for k = 1, #fights do
        local f = fights[k]
        if not f.killed then res.wipes = res.wipes + 1 end
        if not res.cut and ns.raidCut and ns.raidCut[f.boss] then
            res.cut, res.cutAt = f.boss, f.from
        end
        for name in pairs(f.players) do
            local p = res.byName[name]
            if not p then
                p = NewPlayer(name)
                res.byName[name] = p
                res.players[#res.players + 1] = p
            end
            p.tries = p.tries + 1
        end
    end
    res.time = TimeOf(fights)
    local endAt
    for k = 1, #segs do
        local seg = segs[k].seg
        local t0, t1 = seg.t0, seg.t1 or seg.t0
        if t0 < res.from then res.from = t0 end
        if t1 > res.to then res.to = t1 end
        if not endAt or t0 - endAt > SESSION_GAP then
            res.sessions = res.sessions + 1
            res.busy = res.busy + (t1 - t0)
            endAt = t1
        elseif t1 > endAt then
            res.busy = res.busy + (t1 - endAt)
            endAt = t1
        end
    end
    return res, fights
end
local function AddUse(st, piece)
    for item, u in pairs(piece.use or {}) do
        for name, c in pairs(u.by) do
            local p = st.byName[name]
            if p then
                p[u.cat] = (p[u.cat] or 0) + c
                p.used[item] = (p.used[item] or 0) + c
                local sp = st.spent[item]
                if not sp then
                    sp = { item = item, id = u.id, cat = u.cat, n = 0, free = u.free, spell = u.spell, by = {} }
                    st.spent[item] = sp
                    st.res.spent[#st.res.spent + 1] = sp
                end
                sp.n = sp.n + c
                sp.by[name] = (sp.by[name] or 0) + c
            end
        end
    end
    for id, got in pairs(piece.got or {}) do
        for name, ts in pairs(got) do
            if st.byName[name] then
                local e = st.earned[id]
                if not e then
                    e = { id = id, t = ts, who = {}, n = 0 }
                    st.earned[id] = e
                    st.res.earned[#st.res.earned + 1] = e
                end
                if not e.who[name] then e.n = e.n + 1 end
                if not e.who[name] or ts < e.who[name] then e.who[name] = ts end
                if ts < e.t then e.t = ts end
            end
        end
    end
end
local function AddTrash(st, piece)
    local res = st.res
    for name, r in pairs(piece.rows or {}) do
        local p = st.byName[name]
        if p then
            p.all = p.all + r.all
            p.heal = p.heal + r.heal
            res.trash = res.trash + r.all
        end
    end
    local cutAt = res.cutAt
    for k = 1, cutAt and #(piece.ivs or {}) or 0 do
        local iv = piece.ivs[k]
        if iv.to <= cutAt then
            for name, v in pairs(iv.all) do
                local p = st.byName[name]
                if p then p.cut = p.cut + v end
            end
        end
    end
    for name, n in pairs(piece.deaths or {}) do
        local p = st.byName[name]
        if p then
            p.deaths = p.deaths + n
            p.deathBy[TRASH] = (p.deathBy[TRASH] or 0) + n
        end
    end
    AddUse(st, piece)
end
local function AddAttempt(st, f, s)
    local piece = s.rp
    if not piece then return end
    local inCut = st.res.cutAt ~= nil and f.from < st.res.cutAt
    for name, r in pairs(piece.rows or {}) do
        local p = st.byName[name]
        if p then
            p.all = p.all + r.all
            p.enc = p.enc + r.all
            p.boss = p.boss + r.boss
            p.heal = p.heal + r.heal
            if inCut then p.cut = p.cut + r.all end
        end
    end
    AddUse(st, piece)
end
function RaidSum.TrashOf(ref)
    return ns.Digest.Trash(ref.i, ref.seg)
end
local PRIO = { damageTo = "prio", oozes = "prio", usefulTo = "prio", taken = "bad" }
local function Part(p, key, f, label, v, hits)
    p[key] = p[key] + v
    local by = p[key .. "By"]
    local k = tostring(f.boss) .. "|" .. label
    local e = by[k]
    if not e then
        e = { boss = f.boss, label = label, v = 0, hits = 0 }
        by[k] = e
    end
    e.v = e.v + v
    e.hits = e.hits + hits
    if key == "bad" then p.badHits = p.badHits + hits end
end
local function Credit(st, f, s)
    local byName = st.byName
    for i = 1, #(s.blocks or {}) do
        local b = s.blocks[i]
        local def = b.def
        local key = def and PRIO[def.kind]
        if key and b.by then
            local label = def.plain or def.label or def.kind
            for who, v in pairs(b.by) do
                local p = byName[who]
                if p and v > 0 then Part(p, key, f, label, v, b.hits and b.hits[who] or 0) end
            end
        end
    end
    local firstAt, firstWho
    for k = 1, #s.players do
        local sp = s.players[k]
        local p = byName[sp.name]
        if p then
            p.kicks = p.kicks + (sp.interrupts or 0)
            if sp.disp and next(sp.disp) then
                for _, d in pairs(sp.disp) do
                    for _, w in pairs(d.what or {}) do
                        if w.purge then p.purges = p.purges + w.n else p.cures = p.cures + w.n end
                    end
                end
            else
                p.cures = p.cures + (sp.dispels or 0)
            end
            if sp.role == "dps" then
                for key, e in pairs(sp.buffed or {}) do
                    local b = p.buffBy[key]
                    if not b then
                        b = { n = 0, sec = 0, by = {} }
                        p.buffBy[key] = b
                    end
                    b.n, b.sec = b.n + e.n, b.sec + e.sec
                    p.buffN, p.buffSec = p.buffN + e.n, p.buffSec + e.sec
                    for giver, n in pairs(e.by) do b.by[giver] = (b.by[giver] or 0) + n end
                end
            end
            for sk, n in pairs(sp.rod or {}) do
                p.rod = p.rod + n
                p.rodBy[sk] = (p.rodBy[sk] or 0) + n
            end
            local jo = sp.jopo
            if jo then
                p.jopo = p.jopo + 1
                if jo.kill then p.jopoKill = p.jopoKill + 1 end
                p.jopoBy[#p.jopoBy + 1] = { boss = f.boss, from = f.from, t = jo.t, kill = jo.kill }
            end
            local at = sp.deathAt and sp.deathAt[1]
            if at and (not firstAt or at < firstAt) then firstAt, firstWho = at, p end
        end
    end
    if firstWho then
        firstWho.first = firstWho.first + 1
        firstWho.firstBy[f.boss] = (firstWho.firstBy[f.boss] or 0) + 1
    end
end
local function Settle(st, f, s)
    local byName = st.byName
    Credit(st, f, s)
    for k = 1, #s.players do
        local sp = s.players[k]
        local p = byName[sp.name]
        if p and (sp.deaths or 0) > 0 then
            p.deaths = p.deaths + sp.deaths
            p.deathBy[f.boss] = (p.deathBy[f.boss] or 0) + sp.deaths
        end
    end
    local u = s.useful
    if not (u and u.full and not u.normal) then return end
    local names = u.def.names or {}
    local bossy = false
    for k = 1, #names do
        if IsBoss(f, names[k]) then bossy = true end
    end
    local inCut = st.res.cutAt ~= nil and f.from < st.res.cutAt
    for who, full in pairs(u.full.by) do
        local p = byName[who]
        local waste = full - (u.by[who] or 0)
        if p and waste > 0 then
            p.enc = max(0, p.enc - waste)
            if bossy then p.boss = max(0, p.boss - waste) end
            p.all = max(0, p.all - waste)
            if inCut then p.cut = max(0, p.cut - waste) end
        end
    end
end
local function ByCount(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.item < b.item
end
local function ByTime(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.id < b.id
end
local function Build(raid)
    ns.Jobs.Label("job.raidsum")
    local segs = RaidSum.Segments(raid)
    local res, fights = NewSum(raid, segs)
    local st = { res = res, byName = res.byName, spent = {}, earned = {} }
    local total = max(1, #segs + #fights)
    local step = 0
    for k = 1, #segs do
        ns.Jobs.Band(step / total, (step + 1) / total)
        step = step + 1
        AddTrash(st, RaidSum.TrashOf(segs[k]))
    end
    local have = {}
    for k = 1, #fights do
        local f = fights[k]
        local s = ns.Summary.Peek(f) or ns.Summary.Load(f)
        if s then
            have[k] = s
            ns.Jobs.Band(step / total, (step + 1) / total)
            step = step + 1
        end
    end
    for k = 1, #fights do
        if not have[k] then
            ns.Jobs.Band(step / total, (step + 1) / total)
            step = step + 1
            have[k] = ns.Summary.Full(fights[k])
            ns.Jobs.Label("job.raidsum")
        end
    end
    for k = 1, #fights do AddAttempt(st, fights[k], have[k]) end
    for k = 1, #fights do
        Settle(st, fights[k], have[k])
        res.sums[#res.sums + 1] = { fight = fights[k], s = have[k] }
    end
    tsort(res.spent, ByCount)
    tsort(res.earned, ByTime)
    tsort(res.players, function(a, b) return a.name < b.name end)
    return res
end
function RaidSum.Get(raid)
    local res = raid and cache[raid.key]
    if not res then return nil end
    if res.sig ~= Signature(raid, RaidSum.Segments(raid)) then return nil end
    return res
end
function RaidSum.Failed(raid)
    return raid and failed[raid.key] or nil
end
function RaidSum.Retry(raid)
    if raid then failed[raid.key] = nil end
end
function RaidSum.Compute(raid, onDone)
    failed[raid.key] = nil
    local have = RaidSum.Get(raid)
    if have then
        onDone(have)
        return
    end
    for key, jk in pairs(jobKeys) do
        if key ~= raid.key then
            ns.Jobs.Cancel(jk)
            jobKeys[key] = nil
        end
    end
    local jk = jobKeys[raid.key] or {}
    jobKeys[raid.key] = jk
    ns.Jobs.Run(jk, function()
        local res = Build(raid)
        for i = #order, 1, -1 do
            if order[i] == raid.key then table.remove(order, i) end
        end
        table.insert(order, 1, raid.key)
        while #order > KEEP do
            cache[table.remove(order)] = nil
        end
        cache[raid.key] = res
        return res
    end, function(res)
        jobKeys[raid.key] = nil
        if not res then failed[raid.key] = ns.Jobs.Failed(jk) or "?" end
        onDone(res)
    end, "raidsum.frame")
end
function RaidSum.Reset()
    for k in pairs(cache) do cache[k] = nil end
    for i = #order, 1, -1 do order[i] = nil end
end
function RaidSum.GP(res)
    if res.gp then return res.gp, res.gpOffer, res.gpIssued end
    if not (ns.Penalties and ns.Penalties.Evaluate) then return nil, 0, 0 end
    local by, offer, given = {}, 0, 0
    local faults, byRule = {}, {}
    for k = 1, #res.sums do
        local e = res.sums[k]
        local pens = ns.Penalties.Evaluate(e.s, e.fight)
        local fk = ns.Penalties.FightKey(e.fight)
        for name, hits in pairs(pens) do
            local row = by[name]
            if not row then
                row = { offer = 0, issued = 0, n = 0 }
                by[name] = row
            end
            for h = 1, #hits do
                local evs = hits[h].events
                local rule = hits[h].rule
                local fl = byRule[rule.key]
                if not fl then
                    fl = { rule = rule, n = 0, red = 0, gp = 0, by = {}, tries = {} }
                    byRule[rule.key] = fl
                    faults[#faults + 1] = fl
                end
                fl.tries[fk] = true
                for x = 1, #evs do
                    local gp = evs[x].n or 0
                    fl.n = fl.n + 1
                    if evs[x].grade ~= "yellow" then fl.red = fl.red + 1 end
                    fl.gp = fl.gp + gp
                    fl.by[name] = (fl.by[name] or 0) + 1
                    row.offer = row.offer + gp
                    row.n = row.n + 1
                    offer = offer + gp
                    local done = ns.Ledger and ns.Ledger.Done(evs[x].key)
                    if done then
                        local n = done.n or gp
                        row.issued = row.issued + n
                        given = given + n
                    end
                end
            end
        end
    end
    tsort(faults, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        if a.gp ~= b.gp then return a.gp > b.gp end
        return a.rule.key < b.rule.key
    end)
    res.gp, res.gpOffer, res.gpIssued, res.faults = by, offer, given, faults
    return by, offer, given
end
function RaidSum.Faults(res)
    if not RaidSum.GP(res) then return nil end
    return res.faults
end
function RaidSum.GPDirty()
    for _, res in pairs(cache) do res.gp, res.faults = nil, nil end
end
local function LastRecord(raid)
    local last = raid.to
    local segs = RaidSum.Segments(raid)
    local tail = segs[#segs]
    if tail and (tail.seg.t1 or 0) > last then last = tail.seg.t1 end
    return last
end
local function LockGone(raid)
    if not raid.id then return false end
    local locks = ns.Raid.Locks()
    if #locks == 0 then return false end
    for i = 1, #locks do
        if locks[i].id == raid.id then return false end
    end
    return true
end
function RaidSum.Finished(raid)
    if not raid then return false, nil end
    local raids = ns.FightTree.Get()
    if raids[1] and raids[1].key ~= raid.key then return true, "newer" end
    for k = 1, #raid.encs do
        local enc = raid.encs[k]
        if enc.passed and ns.Raid.IsFinal(raid.map, enc.boss) then return true, "final" end
    end
    if LockGone(raid) then return true, "reset" end
    local quiet = time() - LastRecord(raid)
    if quiet >= QUIET_LONG then return true, "quiet" end
    local here = ns.Raid.Current()
    if quiet >= QUIET_OUT and not (here and here.name == raid.name) then return true, "left" end
    return false, nil
end
function RaidSum.Landing()
    local raid = ns.FightTree.Get()[1]
    local enc = raid and raid.encs[1]
    return nil, enc and ns.FightTree.Decisive(enc) or nil
end
function RaidSum.Find(key)
    if not key then return nil end
    local raids = ns.FightTree.Get()
    for i = 1, #raids do
        if raids[i].key == key then return raids[i] end
    end
    return nil
end
