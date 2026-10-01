local _, ns = ...
local format = string.format
local sqrt = math.sqrt
local max = math.max
local min = math.min
local floor = math.floor
local tsort = table.sort
local CAST_MERGE = 1.5
local BOOM_EARLY = 0.5
local MAP_UNITS = 10000
local POS_HOLD = 2
local POS_GAP = 2
local HIT = { SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_PERIODIC_DAMAGE = true }
local CAST = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }
local BTGT = "FW_BTGT"
local M = {}
ns.ReplayMech = M
local function Set(list, v)
    local out = {}
    for i = 1, list and #list or 0 do out[list[i]] = v == nil and true or v end
    return out
end
function M.New(fight)
    local D = ns.replayMech
    local trap = D and D.traps[fight.boss]
    local zones = D and D.zones[fight.boss] or {}
    if not trap and #zones == 0 then return nil end
    local ctx = { fight = fight, players = fight.players or {}, trap = trap, casts = {}, booms = {}, open = {},
                  btgt = {}, zones = zones, zCast = {}, zSum = {}, zHit = {}, zCasts = {}, inst = {}, byGuid = {},
                  marks = {} }
    ctx.trapCast = Set(trap and trap.cast)
    ctx.trapBoom = Set(trap and trap.boom)
    for zi = 1, #zones do
        local z = zones[zi]
        for k, v in pairs(Set(z.cast, zi)) do ctx.zCast[k] = v end
        for k, v in pairs(Set(z.summon, zi)) do ctx.zSum[k] = v end
        for k, v in pairs(Set(z.hit, zi)) do ctx.zHit[k] = v end
        ctx.zCasts[zi] = {}
    end
    return ctx
end
local function AddCast(list, ts, target, src)
    local last = list[#list]
    if last and ts - last.t <= CAST_MERGE then
        if target and not last.target then last.target = target end
        return
    end
    list[#list + 1] = { t = ts, target = target, src = src }
end
local function AddHit(ctx, ts, srcGUID, dst, amount, join)
    local key = srcGUID or "?"
    local b = ctx.open[key]
    if not b or ts - b.t > join then
        b = { t = ts, guid = key, hits = {}, amount = {} }
        ctx.booms[#ctx.booms + 1] = b
        ctx.open[key] = b
    end
    if not b.amount[dst] then b.hits[#b.hits + 1] = dst end
    b.amount[dst] = (b.amount[dst] or 0) + (tonumber(amount) or 0)
end
local function ZoneHit(ctx, ts, srcGUID, dst)
    local z = srcGUID and ctx.byGuid[srcGUID]
    if not z then
        for i = #ctx.inst, 1, -1 do
            local c = ctx.inst[i]
            if ts >= c.t and ts - c.t <= ctx.zones[c.zi].life then
                z = c
                break
            end
        end
    end
    if z then z.hits[#z.hits + 1] = { t = ts, name = dst } end
end
function M.Event(ctx, ts, sub, srcGUID, src, dstGUID, dst, a1, amount)
    local P = ctx.players
    if sub == BTGT then
        if dst and P[dst] then ctx.btgt[#ctx.btgt + 1] = { t = ts, src = src, dst = dst } end
        return
    end
    local id = tonumber(a1)
    if not id or (src and P[src]) then return end
    local target = dst and P[dst] and dst or nil
    if CAST[sub] and ctx.trapCast[id] then
        AddCast(ctx.casts, ts, target, src)
    elseif HIT[sub] and target and ctx.trapBoom[id] then
        AddHit(ctx, ts, srcGUID, target, amount, ctx.trap.join)
    end
    local zi = ctx.zCast[id]
    if zi and CAST[sub] then AddCast(ctx.zCasts[zi], ts, target, src) end
    zi = ctx.zSum[id]
    if zi and sub == "SPELL_SUMMON" then
        local inst = { zi = zi, t = ts, guid = dstGUID, hits = {} }
        ctx.inst[#ctx.inst + 1] = inst
        if dstGUID then ctx.byGuid[dstGUID] = inst end
    end
    if ctx.zHit[id] and HIT[sub] and target then ZoneHit(ctx, ts, srcGUID, target) end
end
local function BossTarget(ctx, src, from, to)
    for i = 1, #ctx.btgt do
        local b = ctx.btgt[i]
        if b.t > to then break end
        if b.t >= from and (not src or not b.src or b.src == src) then return b.dst end
    end
    return nil
end
local function Dist(ax, ay, bx, by, ppy)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy) / ppy
end
local function Nearest(b, x, y, posAt, ppy)
    local best, bestD
    for i = 1, #b.hits do
        local hx, hy = posAt(b.hits[i], b.t)
        if hx then
            local d = Dist(hx, hy, x, y, ppy)
            if not bestD or d < bestD then best, bestD = b.hits[i], d end
        end
    end
    return best
end
local function Match(ctx, b, posAt, ppy, names, guess)
    local D = ctx.trap
    local hx, hy = {}, {}
    for i = 1, #b.hits do hx[i], hy[i] = posAt(b.hits[i], b.t) end
    local best, bx, by, bt
    local bestScore
    for ci = 1, #ctx.casts do
        local c = ctx.casts[ci]
        if not c.used and c.t + D.arm <= b.t + BOOM_EARLY and b.t - c.t <= D.life then
            local at = c.t + D.castTime
            local known = c.target or BossTarget(ctx, c.src, c.t, at + 1)
            local list = guess and names or { known }
            for k = 1, (guess or known) and #list or 0 do
                local sx, sy = posAt(list[k], at)
                if sx then
                    local score = 0
                    for i = 1, #b.hits do
                        if hx[i] then score = max(score, Dist(hx[i], hy[i], sx, sy, ppy)) end
                    end
                    if score <= D.blast + D.slack and (not bestScore or score < bestScore) then
                        best, bx, by, bestScore, bt = c, sx, sy, score, not guess and known or nil
                    end
                end
            end
        end
    end
    return best, bx, by or 0, bt
end
function M.Solve(ctx, posAt, ppy, names)
    local D = ctx.trap
    local traps, zones = {}, {}
    ctx.traps, ctx.zoneOut = traps, zones
    if D then
        for i = 1, #ctx.booms do
            local b = ctx.booms[i]
            local c, x, y, target = Match(ctx, b, posAt, ppy, names, false)
            if not c then c, x, y, target = Match(ctx, b, posAt, ppy, names, true) end
            if c then
                c.used = true
                b.x, b.y = x, y
                b.trigger = Nearest(b, x, y, posAt, ppy)
                b.guess = target == nil
                traps[#traps + 1] = { from = c.t + D.arm, to = b.t, x = x, y = y, target = target, boom = b }
            end
            b.trigger = b.trigger or b.hits[1]
        end
        for ci = 1, #ctx.casts do
            local c = ctx.casts[ci]
            local target = not c.used and (c.target or BossTarget(ctx, c.src, c.t, c.t + D.castTime + 1))
            local x, y
            if target then x, y = posAt(target, c.t + D.castTime) end
            if x then
                traps[#traps + 1] = { from = c.t + D.arm, to = min(c.t + D.life, ctx.fight.to), x = x, y = y,
                                      target = target }
            end
        end
    end
    for i = 1, #ctx.inst do
        local z = ctx.inst[i]
        local def = ctx.zones[z.zi]
        local target = z.target
        local casts = ctx.zCasts[z.zi]
        for k = #casts, 1, -1 do
            local c = casts[k]
            if c.t <= z.t and z.t - c.t <= def.link then
                target = target or c.target or BossTarget(ctx, c.src, c.t, z.t)
                break
            end
        end
        local x, y
        if target then x, y = posAt(target, z.t) end
        if not x and #z.hits > 0 then
            local n, sx, sy = 0, 0, 0
            local t0 = z.hits[1].t
            for h = 1, #z.hits do
                if z.hits[h].t - t0 <= 0.5 then
                    local px, py = posAt(z.hits[h].name, t0)
                    if px then n, sx, sy = n + 1, sx + px, sy + py end
                end
            end
            if n > 0 then x, y = sx / n, sy / n end
        end
        if x then
            zones[#zones + 1] = { from = z.t, to = min(z.t + def.life, ctx.fight.to), x = x, y = y, def = def }
        end
    end
    tsort(traps, function(a, b) return a.from < b.from end)
end
local function InsertBlast(L, t, x, y, r, n, spell)
    local j = L.nb + 1
    while j > 1 and L.bT[j - 1] > t do
        L.bT[j], L.bX[j], L.bY[j], L.bR[j], L.bN[j], L.bS[j] =
            L.bT[j - 1], L.bX[j - 1], L.bY[j - 1], L.bR[j - 1], L.bN[j - 1], L.bS[j - 1]
        j = j - 1
    end
    L.bT[j], L.bX[j], L.bY[j], L.bR[j], L.bN[j], L.bS[j] = t, x, y, r, n, spell
    L.nb = L.nb + 1
end
local function AddPool(L, from, to, x, y, r, tone)
    local j = L.np + 1
    L.np = j
    L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = x, y, from, from, to
    L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j] = r, r, 1, { tone = tone, r0 = r, rmax = r, tail = 0, gap = 0 }
end
function M.Done(ctx, L, posAt, ppy, fc)
    local names = {}
    for name in pairs(ctx.players) do names[#names + 1] = name end
    tsort(names)
    M.Solve(ctx, posAt, ppy, names)
    local D = ctx.trap
    local from = ctx.fight.from
    for i = 1, #ctx.traps do
        local tr = ctx.traps[i]
        AddPool(L, tr.from, max(tr.from, tr.to), tr.x, tr.y, D.r, D.tone)
    end
    for i = 1, D and #ctx.booms or 0 do
        local b = ctx.booms[i]
        if b.x then InsertBlast(L, b.t, b.x, b.y, D.blast * ppy, #b.hits, D.boom[1]) end
        if b.trigger then
            local text = format(ns.T("rep.f.trap"), b.trigger)
            if fc then ns.ReplayFeedCore.Add(fc, b.t, "boss", D.boom[1], true, b.trigger, text) end
            ctx.marks[#ctx.marks + 1] = { t = b.t - from, kind = "spell", id = D.boom[1], label = "rep.mk.trap", n = 1,
                                          who = { b.trigger } }
        end
    end
    for i = 1, #ctx.zoneOut do
        local z = ctx.zoneOut[i]
        AddPool(L, z.from, z.to, z.x, z.y, z.def.r, z.def.tone)
    end
    L.mech = { traps = ctx.traps, booms = ctx.booms, zones = ctx.zoneOut }
end
local function Marks(fight)
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        if ns.Store.IsNew(segs[i]) then
            local m = ns.Decode.Maps(segs[i])
            for k = 1, #m do out[#out + 1] = m[k] end
        end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    return out
end
local function Scale(marks, t)
    local mark = marks[1]
    for i = 1, #marks do
        if marks[i].t <= t then mark = marks[i] else break end
    end
    if not mark then return nil, nil end
    local scale = ns.mapScale or {}
    local byArea = scale[mark.name or ""] or (ns.mapAreas and scale[ns.mapAreas[mark.area] or ""])
    local size = byArea and byArea[mark.level]
    if not size then return nil, nil end
    return size.w / MAP_UNITS, size.h / MAP_UNITS
end
function M.LogPos(fight)
    local tracks, marks = {}, nil
    local segs = ns.Encounters.Segs(fight)
    return function(name, t)
        local tr = tracks[name]
        if not tr then
            tr = { t = {}, x = {}, y = {} }
            for i = 1, #segs do
                if ns.Store.IsNew(segs[i]) then
                    for ts, x, y in ns.Decode.Pos(segs[i], name, fight.from - 5, fight.to + 5) do
                        if ts > fight.to + 5 then break end
                        if x > 0 or y > 0 then
                            local n = #tr.t + 1
                            tr.t[n], tr.x[n], tr.y[n] = ts, x, y
                        end
                    end
                end
            end
            tracks[name] = tr
        end
        local n = #tr.t
        if n == 0 then return nil, 0 end
        local lo, hi = 1, n + 1
        while lo < hi do
            local mid = floor((lo + hi) / 2)
            if tr.t[mid] <= t then lo = mid + 1 else hi = mid end
        end
        local i = lo - 1
        local x, y
        if i >= 1 and t - tr.t[i] <= POS_HOLD then
            x, y = tr.x[i], tr.y[i]
        elseif lo <= n and tr.t[lo] - t <= POS_GAP then
            x, y = tr.x[lo], tr.y[lo]
        end
        if not x then return nil, 0 end
        marks = marks or Marks(fight)
        local yw, yh = Scale(marks, t)
        if not yw then return nil, 0 end
        return x * yw, y * yh
    end
end
function M.Begin(s, fight)
    local badge
    for i = 1, #s.badges do
        if s.badges[i].kind == "trap" then badge = i end
    end
    if not badge then return nil end
    local ctx = M.New(fight)
    if not ctx or not ctx.trap then return nil end
    ctx.badge, ctx.s = badge, s
    return ctx
end
function M.Finish(ctx)
    local s = ctx.s
    local names = {}
    for name in pairs(ctx.players) do names[#names + 1] = name end
    tsort(names)
    M.Solve(ctx, M.LogPos(ctx.fight), 1, names)
    for i = 1, #ctx.booms do
        local b = ctx.booms[i]
        local p = b.trigger and s.byName[b.trigger]
        local st = p and p.badges[ctx.badge]
        if st then
            st.n = st.n + 1
            st.times[#st.times + 1] = b.t - ctx.fight.from
            s.icons[ctx.badge] = s.icons[ctx.badge] or ctx.trap.boom[1]
        end
    end
end
