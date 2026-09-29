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
local function IsBoss(fight, name)
    if not name then return false end
    return name == fight.boss or ns.bosses[name] == fight.boss
        or (fight.names ~= nil and fight.names[name] == true)
end
local function NewPlayer(name)
    return { name = name, class = ns.Encounters.ClassOf(name), all = 0, cut = 0, enc = 0, boss = 0, heal = 0,
             deaths = 0, deathBy = {}, flask = 0, elixir = 0, potion = 0, food = 0, stone = 0, used = {} }
end
local function NewSum(raid, segs)
    local res = {
        key = raid.key, name = raid.name, size = raid.size, heroic = raid.heroic, id = raid.id,
        from = raid.from, to = raid.to, busy = 0, sessions = 0, tries = raid.tries, wipes = 0,
        passed = raid.passed, encs = #raid.encs, known = raid.name and ns.raidEncounters
            and ns.raidEncounters[raid.name] or nil,
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
            if not res.byName[name] then
                local p = NewPlayer(name)
                res.byName[name] = p
                res.players[#res.players + 1] = p
            end
        end
    end
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
                    sp = { item = item, id = u.id, cat = u.cat, n = 0, free = u.free, by = {} }
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
local function Settle(st, f, s)
    local byName = st.byName
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
function RaidSum.Compute(raid, onDone)
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
        if res then onDone(res) end
    end, "raidsum.frame")
end
function RaidSum.Reset()
    for k in pairs(cache) do cache[k] = nil end
    for i = #order, 1, -1 do order[i] = nil end
end
function RaidSum.GP(res)
    if res.gp then return res.gp, res.gpOffer, res.gpIssued end
    if not (ns.Penalties and ns.Penalties.Evaluate) then return nil, 0, 0 end
    local issued = ns.GetDB().gpIssued or {}
    local by, offer, given = {}, 0, 0
    for k = 1, #res.sums do
        local e = res.sums[k]
        local pens = ns.Penalties.Evaluate(e.s, e.fight)
        for name, hits in pairs(pens) do
            local row = by[name]
            if not row then
                row = { offer = 0, issued = 0, n = 0 }
                by[name] = row
            end
            for h = 1, #hits do
                local evs = hits[h].events
                for x = 1, #evs do
                    local gp = evs[x].gp or 0
                    row.offer = row.offer + gp
                    row.n = row.n + 1
                    offer = offer + gp
                    if issued[evs[x].key] then
                        row.issued = row.issued + gp
                        given = given + gp
                    end
                end
            end
        end
    end
    res.gp, res.gpOffer, res.gpIssued = by, offer, given
    return by, offer, given
end
function RaidSum.GPDirty()
    for _, res in pairs(cache) do res.gp = nil end
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
        if enc.passed and ns.Raid.IsFinal(raid.name, enc.boss) then return true, "final" end
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
