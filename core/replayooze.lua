local _, ns = ...
local sqrt = math.sqrt
local min = math.min
local tsort = table.sort
local atan2 = math.atan2
local pi = math.pi
local huge = math.huge
local floor = math.floor
local ceil = math.ceil
local STEP = 0.25
local HOLD_STEP = 2
local SIM = 0.1
local MATCH = 0.4
local MISS_GAP = 1.1
local EARLY = 0.5
local CHAIN_DEG = math.rad(60)
local SMOKE_MAX = 600
local Ooze = {}
ns.ReplayOoze = Ooze
local Replay = ns.Replay
function Ooze.New(fight)
    local M = ns.replayMech
    local defs = M and M.oozes and M.oozes[fight.boss]
    local flood = M and M.floods and M.floods[fight.boss]
    if not defs and not flood then return nil end
    defs = defs or {}
    local want = {}
    local ctx = { defs = defs, byNpc = {}, aura = {}, boom = {}, slow = {}, o = {}, flood = flood, fHit = {},
                  fHits = {}, want = want }
    for _, id in ipairs(flood and flood.hit or {}) do ctx.fHit[id], want[id] = true, true end
    for i = 1, #defs do
        local d = defs[i]
        ctx.byNpc[d.npc] = i
        for _, id in ipairs(d.aura) do ctx.aura[id], want[id] = i, true end
        for _, id in ipairs(d.boom or d.catch or {}) do ctx.boom[id], want[id] = i, true end
        for _, id in ipairs(d.slow or {}) do ctx.slow[id], want[id] = i, true end
    end
    return ctx
end
local function Raw(ctx, guid)
    if not guid then return nil end
    local o = ctx.o[guid]
    if o then return o end
    local di = ctx.byNpc[ns.NpcEntry(guid) or 0]
    if not di then return nil end
    o = { di = di, runs = {}, booms = {}, slowT = {}, slowOn = {} }
    ctx.o[guid] = o
    return o
end
function Ooze.Event(ctx, ts, sub, srcGUID, dstGUID, dst, a1, id)
    id = id or tonumber(a1)
    if not id then return end
    if ctx.fHit[id] and dst and (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") then
        ctx.fHits[#ctx.fHits + 1] = { t = ts, n = dst }
        return
    end
    local ai, bi, si = ctx.aura[id], ctx.boom[id], ctx.slow[id]
    if not (ai or bi or si) then return end
    if si then
        local o = Raw(ctx, dstGUID)
        if o and o.di == si and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED") then
            local n = #o.slowT + 1
            o.slowT[n], o.slowOn[n] = ts, sub == "SPELL_AURA_APPLIED"
            o.slowId = o.slowId or id
        end
        return
    end
    local o = Raw(ctx, srcGUID)
    if not o then return end
    if bi and bi == o.di and sub == "SPELL_CAST_SUCCESS" then
        o.booms[#o.booms + 1] = ts
    elseif ai and ai == o.di and dst then
        if sub == "SPELL_AURA_APPLIED" then
            o.runs[#o.runs + 1] = { a = ts, n = dst }
        elseif sub == "SPELL_AURA_REMOVED" then
            for i = #o.runs, 1, -1 do
                local r = o.runs[i]
                if r.n == dst and not r.e then
                    r.e = ts
                    break
                end
            end
        end
    end
end
local function Clear(add)
    add.n, add.cur = 0, 1
    add.t, add.x, add.y, add.hp, add.dz, add.old = {}, {}, {}, {}, {}, {}
    add.chaseK, add.chaseTo = nil, nil
end
local function Hold(add, from, to, x, y)
    local t = from
    while t < to do
        ns.Replay.Push(add, t, x, y, 1, 0)
        t = t + HOLD_STEP
    end
    ns.Replay.Push(add, to, x, y, 1, 0)
end
local function Slowed(o, t)
    local on = false
    for i = 1, #o.slowT do
        if o.slowT[i] > t then break end
        on = o.slowOn[i]
    end
    return on
end
local function Near(list, t, lo)
    for i = 1, #list do
        if list[i] >= lo and list[i] - t <= MATCH and t - list[i] <= MATCH then return list[i] end
    end
    return nil
end
local function Lead(add, d, r, e, x, y, Pos)
    local arr = e - min(d.lag or 0, (e - r.a) / 2)
    local t = r.a + STEP
    while t < arr do
        local tx, ty = Pos(r.n, t)
        if tx then
            local k = (t - r.a) / (arr - r.a)
            ns.Replay.Push(add, t, x + (tx - x) * k, y + (ty - y) * k, 1, 0)
        end
        t = t + STEP
    end
    local tx, ty = Pos(r.n, arr)
    if tx then x, y = tx, ty end
    Hold(add, arr, e, x, y)
    return x, y
end
local function Chase(o, d, r, e, x, y, ppy, Pos, add, st)
    ns.Jobs.Step()
    local v, reach, aim = (d.v or 7) * ppy, (d.reach or 2) * ppy, d.aim or 0
    local caught = d.kind == "chase" and Near(o.booms, e, r.a)
    local t, nextAt, aimAt = r.a, r.a + STEP, r.a
    local gx, gy
    while t < e do
        if t >= aimAt then
            local tx, ty = Pos(r.n, t)
            if tx then gx, gy = tx, ty end
            aimAt = aimAt + (aim > 0 and aim or SIM)
        end
        if gx then
            local dx, dy = gx - x, gy - y
            local dist = sqrt(dx * dx + dy * dy)
            if dist > 0.01 then
                local s = v * SIM
                if Slowed(o, t) then s = s * (d.slowK or 1) end
                s = min(s, dist)
                x, y = x + dx / dist * s, y + dy / dist * s
            end
        end
        t = t + SIM
        if t >= nextAt then
            ns.Replay.Push(add, t, x, y, 1, 0)
            nextAt = nextAt + STEP
        end
    end
    ns.Replay.Push(add, e, x, y, 1, 0)
    if caught then
        local tx, ty = Pos(r.n, caught)
        if tx then st.caught[#st.caught + 1] = sqrt((tx - x) ^ 2 + (ty - y) ^ 2) / ppy end
    end
    return x, y
end
local function Calm(scene, byName, s, e, fx, fy)
    local n = 0
    local tracks = scene.tracks
    for k = 1, #tracks do
        local tr = tracks[k]
        local own = byName[tr.name]
        local j = 1
        for t = s + 1, e - 0.5, 1 do
            local i = Replay.IndexAt(tr, t)
            if i > 0 and (tr.dz[i] or 0) == 0 then
                local x, y = Replay.PosAtTime(tr, t)
                if x >= 0 then
                    local near = false
                    if own then
                        while j <= #own and own[j] < t - MISS_GAP do j = j + 1 end
                        near = j <= #own and own[j] <= t + MISS_GAP
                    end
                    if not near then
                        n = n + 1
                        fx[n], fy[n] = x, y
                    end
                end
            end
        end
    end
    return n
end
local function Lit(F, px, py, r2, tx, ty, i0, i1, fx, fy, nf)
    local lit, cov, calm = {}, {}, {}
    while true do
        local best, gain = nil, 0
        for p = 1, #px do
            if not lit[p] then
                local g = 0
                for i = i0, i1 do
                    if not cov[i] and (tx[i] - px[p]) ^ 2 + (ty[i] - py[p]) ^ 2 <= r2 then g = g + 1 end
                end
                if g > 0 then
                    local f = 0
                    for q = 1, nf do
                        if not calm[q] and (fx[q] - px[p]) ^ 2 + (fy[q] - py[p]) ^ 2 <= r2 then f = f + 1 end
                    end
                    local v = g - F.lam * f
                    if v > gain then best, gain = p, v end
                end
            end
        end
        if not best then return lit end
        lit[best] = true
        for i = i0, i1 do
            if (tx[i] - px[best]) ^ 2 + (ty[i] - py[best]) ^ 2 <= r2 then cov[i] = true end
        end
        for q = 1, nf do
            if (fx[q] - px[best]) ^ 2 + (fy[q] - py[best]) ^ 2 <= r2 then calm[q] = true end
        end
    end
end
local function Chain(F, lit)
    local cx, cy = F.wall[1], F.wall[2]
    local list = {}
    for p in pairs(lit) do
        local a = atan2(F.spots[p][2] - cy, F.spots[p][1] - cx)
        list[#list + 1] = { p = p, a = a }
    end
    tsort(list, function(x, y) return x.a < y.a end)
    local n = #list
    local start = 1
    for i = 1, n do
        local nxt = list[i % n + 1]
        local gap = (nxt.a - list[i].a) % (2 * pi)
        if n > 1 and gap > CHAIN_DEG then
            start = i % n + 1
            break
        end
    end
    local delay, run = {}, {}
    local function Flush()
        if #run == 0 then return end
        local function Pipe(p)
            local best = huge
            for q = 1, #F.pipes do
                local d = (F.spots[p][1] - F.pipes[q][1]) ^ 2 + (F.spots[p][2] - F.pipes[q][2]) ^ 2
                if d < best then best = d end
            end
            return best
        end
        local rev = Pipe(run[#run]) < Pipe(run[1])
        for i = 1, #run do delay[run[i]] = F.chain * (rev and (#run - i) or (i - 1)) end
        run = {}
    end
    for i = 0, n - 1 do
        local e = list[(start - 1 + i) % n + 1]
        if #run > 0 then
            local prev = list[(start - 2 + i) % n + 1]
            if (e.a - prev.a) % (2 * pi) > CHAIN_DEG then Flush() end
        end
        run[#run + 1] = e.p
    end
    Flush()
    return delay
end
local function Floods(ctx, L, scene, Pos, ppy)
    local F, hits, room = ctx.flood, ctx.fHits, scene.room
    if not F or #hits == 0 or not room then return 0 end
    local px, py = {}, {}
    for p = 1, #F.spots do px[p], py[p] = room.cx + F.spots[p][1] * ppy, room.cy + F.spots[p][2] * ppy end
    local r2 = (F.r * ppy) ^ 2
    tsort(hits, function(a, b) return a.t < b.t end)
    local tx, ty, tt, byName = {}, {}, {}, {}
    for i = 1, #hits do
        local h = hits[i]
        local own = byName[h.n] or {}
        byName[h.n] = own
        own[#own + 1] = h.t
        local x, y = Pos(h.n, h.t)
        if x then
            local m = #tt + 1
            tx[m], ty[m], tt[m] = x, y, h.t
        end
    end
    local t0 = (scene.pull or scene.fight.from) + F.first
    local def = { tone = F.tone, r0 = F.r * F.r0, rmax = F.r, tail = 0, gap = 0, smoke = true }
    local fx, fy = {}, {}
    local n, i, k = 0, 1, 0
    while i <= #tt do
        local s = t0 + k * F.step
        local e = s + F.life
        while i <= #tt and tt[i] < s - EARLY do i = i + 1 end
        local i0 = i
        while i <= #tt and tt[i] < e do i = i + 1 end
        if i > i0 then
            local nf = Calm(scene, byName, s, e, fx, fy)
            local lit = Lit(F, px, py, r2, tx, ty, i0, i - 1, fx, fy, nf)
            local from = min(s, tt[i0]) - F.lead
            for p, dt in pairs(Chain(F, lit)) do
                local j = L.np + 1
                L.np = j
                L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = px[p], py[p], from + dt, from + dt + F.pour, e
                L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j] = F.r * F.r0, F.r, 1, def
                n = n + 1
            end
        end
        k = k + 1
    end
    return n
end
local function Jitter(i, j)
    local h = (i * 73856093 + j * 19349663) % 1000003
    return (h % 1000) / 500 - 1, (floor(h / 1000) % 1000) / 500 - 1
end
local function Smoke(F, L, scene, ppy, j0)
    local K, room = F.smoke, scene.room
    if not K or L.swarm or L.np <= j0 then return 0 end
    local S = { r = K.r, tones = { F.tone, F.tone, F.tone }, ka = K.alpha, n = 0, x = {}, y = {}, from = {}, to = {}, v = {},
                nm = 0, mk = {}, mFrom = {}, mOn = {}, mTo = {} }
    local wx, wy = room.cx + F.wall[1] * ppy, room.cy + F.wall[2] * ppy
    local wr2 = ((F.wall[3] - K.inset) * ppy) ^ 2
    local gap, dy = K.gap * ppy, K.gap * ppy * 0.866
    local nr = ceil(F.wall[3] / (K.gap * 0.866))
    local nc = ceil(F.wall[3] / K.gap) + 1
    local j = j0 + 1
    while j <= L.np do
        local e = L.plTo[j]
        local k = j
        while k < L.np and L.plTo[k + 1] == e do k = k + 1 end
        for row = -nr, nr do
            for col = -nc, nc do
                local jx, jy = Jitter(row, col)
                local x = wx + (col + (row % 2) * 0.5) * gap + jx * K.jitter * ppy
                local y = wy + row * dy + jy * K.jitter * ppy
                if (x - wx) ^ 2 + (y - wy) ^ 2 <= wr2 then
                    local from = huge
                    for p = j, k do
                        local rin = (L.plR1[p] - K.inset) * ppy
                        if (x - L.plX[p]) ^ 2 + (y - L.plY[p]) ^ 2 <= rin * rin then
                            local best = huge
                            for q = 1, #F.pipes do
                                local d = (x - room.cx - F.pipes[q][1] * ppy) ^ 2 + (y - room.cy - F.pipes[q][2] * ppy) ^ 2
                                if d < best then best = d end
                            end
                            local at = L.plFrom[p] + sqrt(best) / ppy * K.pour
                            if at < from then from = at end
                        end
                    end
                    if from < huge and S.n < SMOKE_MAX then
                        local n = S.n + 1
                        S.n = n
                        S.x[n], S.y[n], S.from[n], S.to[n] = x, y, from, e
                        S.v[n] = (row * 3 + col * 5) % 8 + 1
                    end
                end
            end
        end
        j = k + 1
    end
    if S.n == 0 then return 0 end
    local idx = {}
    for i = 1, S.n do idx[i] = i end
    tsort(idx, function(a, b) return S.from[a] < S.from[b] end)
    local x, y, from, to, v = {}, {}, {}, {}, {}
    for i = 1, S.n do
        local q = idx[i]
        x[i], y[i], from[i], to[i], v[i] = S.x[q], S.y[q], S.from[q], S.to[q], S.v[q]
    end
    S.x, S.y, S.from, S.to, S.v = x, y, from, to, v
    L.swarm = S
    return S.n
end
local function ByStart(a, b)
    return a.a < b.a
end
local function ChaseLayer(ctx, L, scene)
    local byK = ns.Replay.ByK(scene)
    local list = {}
    local adds = L.adds
    for i = 1, adds and #adds or 0 do
        local add = adds[i]
        local o = ctx.o[add.guid or ""]
        local to = add.to or add.from
        if o and to > add.from then
            tsort(o.runs, ByStart)
            local t = add.from
            for k = 1, #o.runs do
                local r = o.runs[k]
                if r.a >= to then break end
                local nxt = o.runs[k + 1]
                local e = min(r.e or (nxt and nxt.a) or to, to)
                local a = r.a < t and t or r.a
                local tk = byK[r.n]
                if tk and e > a then
                    list[#list + 1] = { k = tk, from = a, to = e, add = add, npc = ctx.defs[o.di].npc }
                end
                t = e
            end
        end
    end
    if #list == 0 then return end
    tsort(list, function(x, y) return x.from < y.from end)
    local C = L.chase or { n = 0, k = {}, from = {}, to = {}, add = {}, npc = {} }
    for i = 1, #list do
        local e = list[i]
        local n = C.n + 1
        C.n = n
        C.k[n], C.from[n], C.to[n], C.add[n], C.npc[n] = e.k, e.from, e.to, e.add, e.npc
    end
    L.chase = C
end
function Ooze.Done(ctx, L, scene, Pos, ppy)
    local p0 = debugprofilestop()
    local room = scene.room
    local st = { adds = 0, runs = 0, caught = {}, ms = 0, floods = 0 }
    L.ooze = st
    if not room then
        ChaseLayer(ctx, L, scene)
        return
    end
    local j0 = L.np
    st.floods = Floods(ctx, L, scene, Pos, ppy)
    st.smoke = ctx.flood and Smoke(ctx.flood, L, scene, ppy, j0) or 0
    local adds = L.adds
    for i = 1, adds and #adds or 0 do
        local add = adds[i]
        local o = ctx.o[add.guid or ""]
        local to = add.to or add.from
        if o and to > add.from then
            local d = ctx.defs[o.di]
            local x, y = room.cx + d.at[1] * ppy, room.cy + d.at[2] * ppy
            tsort(o.runs, ByStart)
            Clear(add)
            local first = o.runs[1]
            if first and first.a - (d.wait or 0) < add.from then add.from = first.a - (d.wait or 0) end
            local t = add.from
            for k = 1, #o.runs do
                local r = o.runs[k]
                if r.a >= to then break end
                if r.a > t then Hold(add, t, r.a, x, y) end
                local nxt = o.runs[k + 1]
                local e = min(r.e or (nxt and nxt.a) or to, to)
                if r.a < t then r = { a = t, n = r.n, e = r.e } end
                if e > r.a then
                    if d.kind == "lead" and Near(o.booms, e, r.a) then
                        x, y = Lead(add, d, r, e, x, y, Pos)
                    else
                        x, y = Chase(o, d, r, e, x, y, ppy, Pos, add, st)
                    end
                    st.runs = st.runs + 1
                end
                t = e
            end
            if to > t then Hold(add, t, to, x, y) end
            add.debT, add.debOn, add.debId = o.slowT, o.slowOn, o.slowId
            add.look = d.look
            st.adds = st.adds + 1
        end
    end
    ChaseLayer(ctx, L, scene)
    st.ms = debugprofilestop() - p0
end
