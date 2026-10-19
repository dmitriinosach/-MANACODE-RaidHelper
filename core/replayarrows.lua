local _, ns = ...
local min = math.min
local max = math.max
local floor = math.floor
local huge = math.huge
local tsort = table.sort
local tremove = table.remove
local HOLD = 2
local HOLD_HEAL = 1.5
local MERGE = 4
local LEAD = 0.2
local AOE = 0.4
local CAST_PRE = 0.3
local CAST_FLY = 2.5
local CAST_TAIL = 0.5
local BOSS_HOLD = 2
local SWING_ID = 0
local SUBS = {
    SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
    SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_HEAL = true,
    SPELL_CAST_SUCCESS = true, SPELL_CAST_START = true,
}
local SWINGS = { SWING_DAMAGE = true, SWING_MISSED = true }
local AR = {}
ns.ReplayArrows = AR
AR.SUBS = SUBS
function AR.New(scene)
    return { names = ns.Replay.ByK(scene), bosses = ns.Index.BossKeys(scene.fight), raw = {},
             boss = { t = {}, id = {}, k = {}, n = 0 } }
end
function AR.Event(c, ts, sub, src, dstGUID, dst, id, srcKey)
    local names = c.names
    local k = src and names[src]
    if k then
        if dst == src then return end
        local g = dst and names[dst] or dstGUID
        if not g or g == "" then return end
        local r = c.raw[k]
        if not r then
            r = { t = {}, id = {}, g = {}, n = 0 }
            c.raw[k] = r
        end
        local n = r.n + 1
        r.n = n
        r.t[n], r.id[n], r.g[n] = ts, SWINGS[sub] and SWING_ID or id or SWING_ID, g
        return
    end
    if srcKey and c.bosses[srcKey] and (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_START") then
        local tk = dst and names[dst]
        if not tk then return end
        local b = c.boss
        local p = b.n
        id = id or SWING_ID
        if p > 0 and b.k[p] == tk and b.id[p] == id and ts - b.t[p] < BOSS_HOLD then return end
        local n = p + 1
        b.n = n
        b.t[n], b.id[n], b.k[n] = ts, id, tk
    end
end
local function Resolve(g, addBy, bosses)
    if type(g) == "number" then return g end
    local add = addBy[g]
    if add then return add end
    local key = ns.NpcKey(g)
    if key and bosses[key] then return 0 end
    return nil
end
local function ByFrom(a, b)
    return a.from < b.from
end
local function Flatten(spans)
    tsort(spans, ByFrom)
    local out = { F = {}, T = {}, G = {}, H = {}, i = 1 }
    local F, T, G, H = out.F, out.T, out.G, out.H
    local n, i, cnt = 0, 1, #spans
    local act = {}
    local t = cnt > 0 and spans[1].from or 0
    while i <= cnt or #act > 0 do
        local nextFrom = i <= cnt and spans[i].from or huge
        local nextTo, win = huge, nil
        for j = 1, #act do
            local s = act[j]
            if s.to < nextTo then nextTo = s.to end
            if not win or s.from >= win.from then win = s end
        end
        local nb = min(nextFrom, nextTo)
        if win and nb > t then
            if n > 0 and T[n] == t and G[n] == win.tg and H[n] == win.heal then
                T[n] = nb
            else
                n = n + 1
                F[n], T[n], G[n], H[n] = t, nb, win.tg, win.heal
            end
        end
        t = nb
        for j = #act, 1, -1 do
            if act[j].to <= nb then tremove(act, j) end
        end
        while i <= cnt and spans[i].from <= nb do
            act[#act + 1] = spans[i]
            i = i + 1
        end
    end
    return out
end
local function AoeIds(r, tg)
    local aoe, lastT, lastG = {}, {}, {}
    for j = 1, r.n do
        local id, g = r.id[j], tg[j]
        if id ~= SWING_ID and g then
            local lt = lastT[id]
            if lt and lastG[id] ~= g and r.t[j] - lt <= AOE then aoe[id] = true end
            lastT[id], lastG[id] = r.t[j], g
        end
    end
    return aoe
end
local function CastSpans(spans, r, tg, cs)
    if not cs then return end
    local byId = {}
    for j = 1, r.n do
        local id = r.id[j]
        if id ~= SWING_ID and tg[j] then
            local l = byId[id]
            if not l then
                l = { pos = 1 }
                byId[id] = l
            end
            l[#l + 1] = j
        end
    end
    local R = cs.R
    for q = 1, #R do
        local rec = R[q]
        local l = rec.id and not rec.cut and rec.stop and byId[rec.id]
        if l and rec.stop > rec.from then
            local lo = rec.stop - CAST_PRE
            local p = l.pos
            while l[p] and r.t[l[p]] < lo do p = p + 1 end
            l.pos = p
            local j = l[p]
            if j and r.t[j] <= rec.stop + CAST_FLY then
                local g = tg[j]
                spans[#spans + 1] = { from = rec.from, to = r.t[j] + CAST_TAIL, tg = g, heal = type(g) == "number" and g > 0 }
            end
        end
    end
end
local function HitSpans(r, tg, aoe, spans)
    local run
    for j = 1, r.n do
        local g = tg[j]
        if g and not aoe[r.id[j]] then
            local ts = r.t[j]
            local heal = type(g) == "number" and g > 0
            if run and run.tg == g and ts - run.last <= MERGE then
                run.last = ts
                run.to = ts + (heal and HOLD_HEAL or HOLD)
            else
                run = { from = ts - LEAD, last = ts, to = ts + (heal and HOLD_HEAL or HOLD), tg = g, heal = heal }
                spans[#spans + 1] = run
            end
        end
    end
end
function AR.Done(c, L, scene)
    local addBy = {}
    for i = 1, #(L.adds or {}) do addBy[L.adds[i].guid] = L.adds[i] end
    local casts = scene.units and scene.units.casts or {}
    local lanes, stats = {}, { arrows = 0, raw = 0, aoe = 0 }
    for k, r in pairs(c.raw) do
        local tg = {}
        for j = 1, r.n do tg[j] = Resolve(r.g[j], addBy, c.bosses) or false end
        local aoe = AoeIds(r, tg)
        for _ in pairs(aoe) do stats.aoe = stats.aoe + 1 end
        local spans = {}
        HitSpans(r, tg, aoe, spans)
        local track = scene.tracks[k]
        CastSpans(spans, r, tg, track and casts[track.name])
        local lane = Flatten(spans)
        if #lane.F > 0 then lanes[k] = lane end
        stats.raw = stats.raw + r.n
        stats.arrows = stats.arrows + #lane.F
    end
    local b = c.boss
    local boss = { F = {}, T = {}, G = {}, I = {}, i = 1 }
    for j = 1, b.n do
        boss.F[j], boss.T[j], boss.G[j], boss.I[j] = b.t[j], b.t[j] + BOSS_HOLD, b.k[j], b.id[j]
    end
    stats.boss = b.n
    local out = { lanes = lanes, boss = boss, stats = stats }
    L.arrows = out
    return out
end
local function Seek(F, i, t)
    local n = #F
    if n == 0 or t < F[1] then return 0 end
    if i < 1 or i > n then i = 1 end
    if F[i] <= t and (i == n or F[i + 1] > t) then return i end
    local lo, hi = 1, n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if F[mid] <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end
AR.Seek = Seek
function AR.At(lane, t)
    if not lane then return nil, false end
    local i = Seek(lane.F, lane.i, t)
    if i == 0 then return nil, false end
    lane.i = i
    if lane.T[i] <= t then return nil, false end
    return lane.G[i], lane.H[i]
end
function AR.BossAt(boss, t, out, n)
    local i = Seek(boss.F, boss.i, t)
    if i == 0 then return 0 end
    boss.i = i
    local m = 0
    local lo = max(1, i - n * 4)
    for j = i, lo, -1 do
        if boss.T[j] > t then
            m = m + 1
            out[m] = j
            if m >= n then break end
        elseif t - boss.F[j] > BOSS_HOLD then
            break
        end
    end
    return m
end
