local _, ns = ...
local sqrt = math.sqrt
local max = math.max
local min = math.min
local floor = math.floor
local huge = math.huge
local band = bit.band
local tsort = table.sort
local tonumber = tonumber
local pairs = pairs
local wipe = wipe
local F_NPC = 0x800
local F_HOSTILE = 0x40
local RNG = "FW_RNG"
local STEP = 0.5
local WINDOW = 2
local MELEE_MIN = 2
local MIN_HITS = 10
local OUT_YD = 6
local REACH_PAD = 2.5
local R_MIN = 2.5
local R_UP = 6
local R_LO = 0.6
local R_Q = 0.75
local R_STEP = 2
local R_SAMPLES = 3
local EPS = 1e-6
local SPEED = 7
local EASE = 0.6
local HOLD = 20
local WITNESS_HOLD = 3
local TARGET_MIN = 5
local ADD_R = 3
local RNG_MIN = 3
local RNG_BACK = 0.75
local RNG_AHEAD = 0.25
local RNG_W_MID = 0.15
local RNG_W_MELEE = 0.5
local RNG_W_PRIOR = 0.02
local RNG_W_WEAK = 0.002
local RNG_NEAR = 15
local RNG_FAR = 40
local RNG_BAD = 4
local SWING = { SWING_DAMAGE = true, SWING_MISSED = true }
local NpcPos = {}
ns.NpcPos = NpcPos
NpcPos.off = false
NpcPos.WINDOW = WINDOW
NpcPos.MELEE_MIN = MELEE_MIN
NpcPos.RNG_MIN = RNG_MIN
local px, py, qx, qy, sx, sy = {}, {}, {}, {}, {}, {}
local rmx, rmy, rlo, rhi = {}, {}, {}, {}
local pick = {}
function NpcPos.New(scene, c)
    if NpcPos.off then return nil end
    return {
        scene = scene, c = c, byK = c.byK, tracks = c.tracks, ppy = scene.ppy, bosses = c.bosses,
        hitT = {}, hitK = {}, hitN = {}, rng = {}, names = {}, witness = scene.boss,
        stats = { steps = 0, melee = 0, target = 0, witness = 0, range = 0, hold = 0, r = 0, rData = 0,
                  rngLines = 0, addPts = 0, addMoved = 0, addShift = 0, ms = 0 },
    }
end
local function Hit(np, guid, name, ts, k, byPlayer)
    local T = np.hitT[guid]
    if not T then
        T = {}
        np.hitT[guid], np.hitK[guid], np.hitN[guid] = T, {}, 0
        np.names[guid] = name
    end
    local n = #T + 1
    T[n] = ts
    np.hitK[guid][n] = k
    if byPlayer then np.hitN[guid] = np.hitN[guid] + 1 end
end
function NpcPos.Feed(np, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2)
    if SWING[sub] then
        local ks = src and np.byK[src]
        if ks and dstGUID and dstFlags and band(dstFlags, F_NPC) > 0 and band(dstFlags, F_HOSTILE) > 0 then
            Hit(np, dstGUID, dst, ts, ks, true)
            return
        end
        local kd = dst and np.byK[dst]
        if kd and srcGUID and srcFlags and band(srcFlags, F_NPC) > 0 and band(srcFlags, F_HOSTILE) > 0 then
            Hit(np, srcGUID, src, ts, kd, false)
        end
    elseif sub == RNG then
        local k = src and np.byK[src]
        local lo = tonumber(a1)
        if not k or not dstGUID or not lo then return end
        local r = np.rng[dstGUID]
        if not r then
            r = { T = {}, K = {}, lo = {}, hi = {}, at = 1 }
            np.rng[dstGUID] = r
        end
        local n = #r.T + 1
        r.T[n], r.K[n], r.lo[n], r.hi[n] = ts, k, lo, tonumber(a2) or false
        np.stats.rngLines = np.stats.rngLines + 1
    end
end
local function SortCols(T, cols)
    local n = #T
    local sorted = true
    for i = 2, n do
        if T[i] < T[i - 1] then
            sorted = false
            break
        end
    end
    if sorted then return end
    local order = {}
    for i = 1, n do order[i] = i end
    tsort(order, function(a, b)
        if T[a] ~= T[b] then return T[a] < T[b] end
        return a < b
    end)
    cols[#cols + 1] = T
    for c = 1, #cols do
        local src, copy = cols[c], {}
        for i = 1, n do copy[i] = src[order[i]] end
        for i = 1, n do src[i] = copy[i] end
    end
end
local function Order(np)
    for guid, T in pairs(np.hitT) do SortCols(T, { np.hitK[guid] }) end
    for _, r in pairs(np.rng) do SortCols(r.T, { r.K, r.lo, r.hi }) end
end
local function NewSweep(T, K)
    return { T = T, K = K, hi = 0, last = {} }
end
local function Gather(np, sw, t)
    local T, K, last = sw.T, sw.K, sw.last
    local n, hi = #T, sw.hi
    while hi < n and T[hi + 1] <= t + WINDOW do
        hi = hi + 1
        last[K[hi]] = T[hi]
    end
    sw.hi = hi
    local m = 0
    local tracks = np.tracks
    local PosAtTime = ns.Replay.PosAtTime
    for k, lt in pairs(last) do
        if lt < t - WINDOW then
            last[k] = nil
        else
            local x, y = PosAtTime(tracks[k], t)
            if x >= 0 then
                m = m + 1
                px[m], py[m] = x, y
            end
        end
    end
    return m
end
local function Sort(list, n)
    for i = 2, n do
        local v = list[i]
        local j = i - 1
        while j >= 1 and list[j] > v do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = v
    end
end
local function Inliers(m, lim)
    for i = 1, m do sx[i], sy[i] = px[i], py[i] end
    Sort(sx, m)
    Sort(sy, m)
    local h = floor((m + 1) / 2)
    local mx, my = sx[h], sy[h]
    local q = 0
    for i = 1, m do
        local dx, dy = px[i] - mx, py[i] - my
        if dx * dx + dy * dy <= lim * lim then
            q = q + 1
            qx[q], qy[q] = px[i], py[i]
        end
    end
    return q, mx, my
end
local function Circum(i, j, k)
    local ax, ay, bx, by, cx, cy = qx[i], qy[i], qx[j], qy[j], qx[k], qy[k]
    local d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if d > -EPS and d < EPS then return nil, 0, 0 end
    local a2, b2, c2 = ax * ax + ay * ay, bx * bx + by * by, cx * cx + cy * cy
    local x = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
    local y = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
    return x, y, (ax - x) * (ax - x) + (ay - y) * (ay - y)
end
local function Out(i, x, y, r2)
    local dx, dy = qx[i] - x, qy[i] - y
    return dx * dx + dy * dy > r2 * (1 + EPS) + EPS
end
local function Enclose(q)
    local x, y, r2 = qx[1], qy[1], 0
    for i = 2, q do
        if Out(i, x, y, r2) then
            x, y, r2 = qx[i], qy[i], 0
            for j = 1, i - 1 do
                if Out(j, x, y, r2) then
                    x, y = (qx[i] + qx[j]) / 2, (qy[i] + qy[j]) / 2
                    r2 = ((qx[i] - x) * (qx[i] - x) + (qy[i] - y) * (qy[i] - y))
                    for k = 1, j - 1 do
                        if Out(k, x, y, r2) then
                            local cx, cy, c2 = Circum(i, j, k)
                            if cx then x, y, r2 = cx, cy, c2 end
                        end
                    end
                end
            end
        end
    end
    return x, y
end
local function MeleeFit(m, lim, far, tx, ty)
    local q, mx, my = Inliers(m, lim)
    if q < MELEE_MIN then return -1, -1, 0 end
    if tx >= 0 then
        local dx, dy = tx - mx, ty - my
        if dx * dx + dy * dy <= far * far then
            q = q + 1
            qx[q], qy[q] = tx, ty
        end
    end
    local x, y = Enclose(q)
    return x, y, q
end
local function MeleeMean(m, lim)
    local q = Inliers(m, lim)
    if q < MELEE_MIN then return -1, -1, 0 end
    local cx, cy = 0, 0
    for i = 1, q do cx, cy = cx + qx[i], cy + qy[i] end
    return cx / q, cy / q, q
end
local function EstimateR(np, T, K, rData)
    local ppy = np.ppy
    local c = np.c
    local sw = NewSweep(T, K)
    local lim = (rData + R_UP + OUT_YD) * ppy
    local spans = {}
    local t = c.from
    while t <= c.to do
        ns.Jobs.Step(2)
        local m = Gather(np, sw, t)
        if m >= 3 then
            local q = Inliers(m, lim)
            if q >= 3 then
                local far = 0
                for i = 1, q - 1 do
                    for j = i + 1, q do
                        local dx, dy = qx[i] - qx[j], qy[i] - qy[j]
                        local d = dx * dx + dy * dy
                        if d > far then far = d end
                    end
                end
                spans[#spans + 1] = sqrt(far) / 2 / ppy
            end
        end
        t = t + R_STEP
    end
    if #spans < R_SAMPLES then return rData end
    tsort(spans)
    local v = spans[max(1, min(#spans, floor(#spans * R_Q + 0.5)))]
    return max(max(R_MIN, R_LO * rData), min(v, rData + R_UP))
end
local function Primary(np)
    local best, bestN = nil, MIN_HITS - 1
    for guid, n in pairs(np.hitN) do
        local name = np.names[guid]
        if name and np.bosses[name] and n > bestN then best, bestN = guid, n end
    end
    if best then return best end
    bestN = MIN_HITS - 1
    for guid, r in pairs(np.rng) do
        local name = np.names[guid]
        if (not name or np.bosses[name]) and #r.T > bestN then best, bestN = guid, #r.T end
    end
    return best
end
local function Cost(x, y, cnt, m, reach, gx, gy, wp, ppy)
    local s = 0
    for i = 1, cnt do
        local dx, dy = x - rmx[i], y - rmy[i]
        local d = sqrt(dx * dx + dy * dy) / ppy
        local lo, hi = rlo[i], rhi[i]
        if d < lo then
            s = s + (lo - d) * (lo - d)
        elseif hi and d > hi then
            s = s + (d - hi) * (d - hi)
        end
        if hi then
            local e = d - (lo + hi) / 2
            s = s + RNG_W_MID * e * e
        end
    end
    for i = 1, m do
        local dx, dy = x - px[i], y - py[i]
        local d = sqrt(dx * dx + dy * dy) / ppy
        if d > reach then s = s + RNG_W_MELEE * (d - reach) * (d - reach) end
    end
    local dx, dy = (x - gx) / ppy, (y - gy) / ppy
    return s + wp * (dx * dx + dy * dy)
end
local function Outside(cnt, x, y, ppy)
    local s = 0
    for i = 1, cnt do
        local dx, dy = x - rmx[i], y - rmy[i]
        local d = sqrt(dx * dx + dy * dy) / ppy
        if d < rlo[i] then
            s = s + (rlo[i] - d) * (rlo[i] - d)
        elseif rhi[i] and d > rhi[i] then
            s = s + (d - rhi[i]) * (d - rhi[i])
        end
    end
    return sqrt(s / cnt)
end
local function Measurers(np, rs, t, offYd)
    local T, n = rs.T, #rs.T
    local at = rs.at
    while at <= n and T[at] < t - RNG_BACK do at = at + 1 end
    rs.at = at
    wipe(pick)
    local j = at
    while j <= n and T[j] <= t + RNG_AHEAD do
        pick[rs.K[j]] = j
        j = j + 1
    end
    local cnt = 0
    local PosAtTime = ns.Replay.PosAtTime
    for k, i in pairs(pick) do
        local x, y = PosAtTime(np.tracks[k], T[i])
        if x >= 0 then
            cnt = cnt + 1
            rmx[cnt], rmy[cnt] = x, y
            rlo[cnt] = rs.lo[i] + offYd
            rhi[cnt] = rs.hi[i] and (rs.hi[i] + offYd) or false
        end
    end
    return cnt
end
function NpcPos.Range(np, rs, t, offYd, reachYd, gx, gy, m, strong)
    if not rs then return nil, 0, 0 end
    local cnt = Measurers(np, rs, t, offYd)
    if cnt < RNG_MIN then return nil, 0, cnt end
    local ppy = np.ppy
    local wp, span = RNG_W_PRIOR, RNG_NEAR
    if gx < 0 then
        gx, gy = 0, 0
        for i = 1, cnt do gx, gy = gx + rmx[i], gy + rmy[i] end
        gx, gy = gx / cnt, gy / cnt
        wp, span = RNG_W_WEAK, RNG_FAR
    elseif not strong then
        wp, span = RNG_W_WEAK, RNG_FAR
    end
    local bx, by, best = gx, gy, huge
    local step = 2
    local ox, oy, half = gx, gy, span
    for _ = 1, 3 do
        local steps = floor(half / step + 0.5)
        for i = -steps, steps do
            ns.Jobs.Step()
            local x = ox + i * step * ppy
            for j = -steps, steps do
                local y = oy + j * step * ppy
                local v = Cost(x, y, cnt, m, reachYd, gx, gy, wp, ppy)
                if v < best then bx, by, best = x, y, v end
            end
        end
        ox, oy, half = bx, by, step
        step = step / 4
    end
    if Outside(cnt, bx, by, ppy) > RNG_BAD then return nil, 0, cnt end
    return bx, by, cnt
end
local function RaidMean(c, t)
    local sx0, sy0, n = 0, 0, 0
    local tracks = c.tracks
    local PosAtTime = ns.Replay.PosAtTime
    for k = 1, #tracks do
        local x, y = PosAtTime(tracks[k], t)
        if x >= 0 then sx0, sy0, n = sx0 + x, sy0 + y, n + 1 end
    end
    if n == 0 then return -1, -1 end
    return sx0 / n, sy0 / n
end
local function AtTarget(np, t, tx, ty)
    local old, c = np.witness, np.c
    local mx, my = -1, -1
    if old then mx, my = ns.Replay.PosHold(old, t, WITNESS_HOLD) end
    if tx >= 0 then
        if mx < 0 then mx, my = RaidMean(c, t) end
        local cx, cy = tx, ty
        if mx >= 0 then
            local dx, dy = mx - tx, my - ty
            local d = sqrt(dx * dx + dy * dy)
            if d > 0.01 then
                local off = min(c.L.hitbox * np.ppy, d * 0.5)
                cx, cy = tx + dx / d * off, ty + dy / d * off
            end
        end
        return cx, cy, "target"
    end
    if mx >= 0 then return mx, my, "witness" end
    return -1, -1, nil
end
local function PlaceAdds(np)
    local st, ppy = np.stats, np.ppy
    local lim = (ADD_R + OUT_YD) * ppy
    local off = ns.ReplayLayers.Hitbox("")
    for guid, add in pairs(np.c.addBy) do
        local T, rs = np.hitT[guid], np.rng[guid]
        if add.n > 0 and (T or rs) then
            local sw = T and NewSweep(T, np.hitK[guid])
            for i = 1, add.n do
                ns.Jobs.Step(2)
                local x, y = add.x[i], add.y[i]
                if x >= 0 then
                    st.addPts = st.addPts + 1
                    local m = sw and Gather(np, sw, add.t[i]) or 0
                    local cx, cy = -1, -1
                    if m >= MELEE_MIN then cx, cy = MeleeMean(m, lim) end
                    local rx, ry = NpcPos.Range(np, rs, add.t[i], off, ADD_R + 1, cx, cy, m, cx >= 0)
                    if rx then cx, cy = rx, ry end
                    if cx >= 0 then
                        local dx, dy = (cx - x) / ppy, (cy - y) / ppy
                        st.addMoved = st.addMoved + 1
                        st.addShift = st.addShift + sqrt(dx * dx + dy * dy)
                        add.x[i], add.y[i] = cx, cy
                    end
                end
            end
        end
    end
end
function NpcPos.Place(np, TargetAt)
    local p0 = debugprofilestop()
    Order(np)
    local c, scene, st, ppy = np.c, np.scene, np.stats, np.ppy
    local guid = Primary(np)
    st.guid = guid
    if not guid then
        PlaceAdds(np)
        st.ms = debugprofilestop() - p0
        scene.npcPos = np
        return false
    end
    local L = c.L
    local rData = L.hitbox + REACH_PAD
    local T, K = np.hitT[guid], np.hitK[guid]
    local rYd = T and EstimateR(np, T, K, rData) or rData
    st.r, st.rData = rYd, rData
    local lim = (rYd + OUT_YD) * ppy
    local sw = T and NewSweep(T, K)
    local rs = np.rng[guid]
    local useTarget = L.targets >= TARGET_MIN
    local stepMax = SPEED * ppy * STEP
    local tr = ns.Replay.NewTrack(scene.bossName or scene.fight.boss)
    tr.fx, tr.fy = {}, {}
    local lo = 0
    local ax, ay, at = nil, 0, -1e9
    local lastX, lastY, lastT = nil, 0, 0
    local t = c.from
    while t <= c.to do
        ns.Jobs.Step(4)
        st.steps = st.steps + 1
        local k = 0
        if useTarget then k, lo = TargetAt(c, t, lo) end
        local tx, ty = -1, -1
        if k > 0 then tx, ty = ns.Replay.PosAtTime(c.tracks[k], t) end
        local m = sw and Gather(np, sw, t) or 0
        local cx, cy, src = -1, -1, nil
        if m >= MELEE_MIN then
            cx, cy = MeleeFit(m, lim, lim + rYd * ppy, tx, ty)
            if cx >= 0 then src = "melee" end
        end
        if not src then cx, cy, src = AtTarget(np, t, tx, ty) end
        local hx, hy = cx, cy
        if hx < 0 and ax and t - at <= STEP * 1.5 then hx, hy = ax, ay end
        local melee = src == "melee"
        local rx, ry = NpcPos.Range(np, rs, t, L.hitbox, rYd + 1, hx, hy, melee and m or 0, melee)
        if rx then cx, cy, src = rx, ry, "range" end
        if not src and lastX and t - lastT <= HOLD then cx, cy, src = lastX, lastY, "hold" end
        if src then
            st[src] = st[src] + 1
            if src ~= "hold" then lastX, lastY, lastT = cx, cy, t end
            if ax and t - at <= STEP * 1.5 then
                if src == "melee" or src == "range" then
                    cx, cy = ax + (cx - ax) * EASE, ay + (cy - ay) * EASE
                end
                local dx, dy = cx - ax, cy - ay
                local d = sqrt(dx * dx + dy * dy)
                if d > stepMax then cx, cy = ax + dx / d * stepMax, ay + dy / d * stepMax end
            end
            ax, ay, at = cx, cy, t
            local fx, fy = tr.fx[tr.n] or 0, tr.fy[tr.n] or 1
            if tx >= 0 then
                local dx, dy = tx - cx, ty - cy
                local d = sqrt(dx * dx + dy * dy)
                if d > 0.01 then fx, fy = dx / d, dy / d end
            end
            ns.Replay.Push(tr, t, cx, cy, 1, 0)
            tr.fx[tr.n], tr.fy[tr.n] = fx, fy
        elseif tr.n > 0 and tr.x[tr.n] >= 0 then
            ns.Replay.Push(tr, t, -1, -1, 1, 0)
            tr.fx[tr.n], tr.fy[tr.n] = 0, 1
        end
        t = t + STEP
    end
    if tr.n > 0 then
        scene.boss = tr
        scene.bossName = scene.bossName or scene.fight.boss
        L.bossMoved = true
    end
    PlaceAdds(np)
    st.ms = debugprofilestop() - p0
    scene.npcPos = np
    return true
end
function NpcPos.Points(np, guid, t)
    local T = np.hitT[guid]
    if not T then return 0, {}, {} end
    local m = Gather(np, NewSweep(T, np.hitK[guid]), t)
    local xs, ys = {}, {}
    for i = 1, m do xs[i], ys[i] = px[i], py[i] end
    return m, xs, ys
end
