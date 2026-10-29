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
local SWING = { SWING_DAMAGE = true, SWING_MISSED = true }
local REMOVED = { SPELL_AURA_REMOVED = true, SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true }
local BTGT = "FW_BTGT"
local FLASK_HIT = 0.5
local VICTIM_LIMIT = 2000
local SPAWN_EARLY = 0.1
local SOUL_DIE = 1
local SOUL_JOIN = 10
local SCATTER_TOL = 2
local HIT_WIN = 0.5
local M = {}
ns.ReplayMech = M
local function Put(out, list, v)
    for i = 1, list and #list or 0 do out[list[i]] = v end
end
function M.New(fight)
    local D = ns.replayMech
    local trap = D and D.traps[fight.boss]
    local zones = D and D.zones[fight.boss] or {}
    local bomb = D and D.bombs and D.bombs[fight.boss]
    local chase = D and D.chase and D.chase[fight.boss] or {}
    local oozes = ns.ReplayOoze and D and D.oozes and D.oozes[fight.boss]
    if oozes and #chase > 0 then
        local skip, left = {}, {}
        for i = 1, #oozes do skip[oozes[i].npc] = true end
        for i = 1, #chase do
            if not skip[chase[i].npc] then left[#left + 1] = chase[i] end
        end
        chase = left
    end
    local winter = D and D.winters and D.winters[fight.boss]
    local soul = D and D.souls and D.souls[fight.boss]
    if not trap and #zones == 0 and not bomb and #chase == 0 and not winter and not soul then return nil end
    local ctx = { fight = fight, players = fight.players or {}, trap = trap, casts = {}, booms = {}, open = {},
                  btgt = {}, zones = zones, zCast = {}, zSum = {}, zDrop = {}, zHit = {}, zCasts = {}, inst = {}, byGuid = {},
                  marks = {}, bomb = bomb, bCasts = {}, bHits = {}, chase = chase, cAura = {}, cSpawn = {},
                  cNpc = {}, cSeen = {}, cWait = {}, cLone = {}, cOpen = {}, runs = {},
                  winter = winter, rings = {}, wHits = {}, soul = soul, sOpen = {}, spans = {} }
    ctx.wAura = ns.IdSet(winter and winter.aura)
    ctx.wHit = ns.IdSet(winter and winter.hit)
    ctx.sAura = ns.IdSet(soul and soul.aura)
    ctx.trapCast = ns.IdSet(trap and trap.cast)
    ctx.trapBoom = ns.IdSet(trap and trap.boom)
    ctx.bCast = ns.IdSet(bomb and bomb.cast)
    ctx.bGas = ns.IdSet(bomb and bomb.gas)
    ctx.bBoom = ns.IdSet(bomb and bomb.boom)
    ctx.bTomb = ns.IdSet(bomb and bomb.tomb)
    ctx.bFall = ns.IdSet(bomb and bomb.fall and bomb.fall.cast)
    ctx.tombs, ctx.tombCasts = {}, {}
    for di = 1, #chase do
        local d = chase[di]
        ctx.cNpc[ns.NpcKeyOf(d.npc)] = di
        Put(ctx.cAura, d.aura, di)
        Put(ctx.cSpawn, d.spawn, di)
    end
    for zi = 1, #zones do
        local z = zones[zi]
        Put(ctx.zCast, z.cast, zi)
        Put(ctx.zSum, z.summon, zi)
        Put(ctx.zDrop, z.drop, zi)
        Put(ctx.zHit, z.hit, zi)
        ctx.zCasts[zi] = {}
    end
    if #chase == 0 then
        local want = {}
        for _, set in ipairs({ ctx.wAura, ctx.wHit, ctx.sAura, ctx.trapCast, ctx.trapBoom, ctx.bCast, ctx.bGas,
                               ctx.bBoom, ctx.bTomb, ctx.bFall, ctx.zCast, ctx.zSum, ctx.zDrop, ctx.zHit }) do
            for id in pairs(set) do want[id] = true end
        end
        ctx.want = want
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
local function Banner(ctx)
    local list, hits, join = {}, ctx.bHits, ctx.bomb.join
    for i = 1, #hits do
        local h = hits[i]
        if h.boom then
            local b = list[#list]
            if not b or h.t - b.t > join then
                b = { t = h.t, hits = {} }
                list[#list + 1] = b
            end
            b.hits[#b.hits + 1] = h.name
        end
    end
    return list
end
local function Meet(L)
    local a, b, c, p, q, m = 0, 0, 0, 0, 0, 0
    for i = 1, #L do
        local l = L[i]
        if l.on then
            local m11, m12, m22 = 1 - l.ux * l.ux, -l.ux * l.uy, 1 - l.uy * l.uy
            a, b, c = a + m11, b + m12, c + m22
            p, q = p + m11 * l.x + m12 * l.y, q + m12 * l.x + m22 * l.y
            m = m + 1
        end
    end
    local det = a * c - b * b
    if m < 2 or det < 0.05 * m then return nil end
    return (p * c - b * q) / det, (a * q - b * p) / det
end
local function BombAt(ctx, t, hit, posAt, ppy, names)
    local B = ctx.bomb
    local tx, ty, inTomb = {}, {}, {}
    for i = 1, #ctx.tombs do
        local tb = ctx.tombs[i]
        if tb.from <= t and (not tb.to or tb.to >= t) then
            local x, y = posAt(tb.name, t)
            if x then tx[#tx + 1], ty[#ty + 1] = x, y end
            inTomb[tb.name] = true
        end
    end
    if #tx == 0 then return nil end
    local hide2 = (B.hide * ppy) ^ 2
    local lines = {}
    local ux, uy = 0, 0
    for i = 1, #names do
        if not inTomb[names[i]] and not hit[names[i]] then
            local x, y = posAt(names[i], t - 0.3)
            local best, bq = hide2, nil
            for q = 1, x and #tx or 0 do
                local d2 = (tx[q] - x) ^ 2 + (ty[q] - y) ^ 2
                if d2 <= best then best, bq = d2, q end
            end
            if bq and best > 0 then
                local d = sqrt(best)
                local l = { x = tx[bq], y = ty[bq], ux = (tx[bq] - x) / d, uy = (ty[bq] - y) / d, on = true }
                lines[#lines + 1] = l
                ux, uy = ux + l.ux, uy + l.uy
            end
        end
    end
    local ulen = sqrt(ux * ux + uy * uy)
    if #lines == 0 or ulen < 0.01 then return nil end
    ux, uy = ux / ulen, uy / ulen
    local cone = math.cos(math.rad(B.cone))
    for i = 1, #lines do
        local l = lines[i]
        l.on = l.ux * ux + l.uy * uy >= cone
    end
    local X, Y = Meet(lines)
    if X then
        local miss2 = (B.miss * ppy) ^ 2
        for i = 1, #lines do
            local l = lines[i]
            local dx, dy = X - l.x, Y - l.y
            local along = dx * l.ux + dy * l.uy
            l.on = l.on and along > 0 and dx * dx + dy * dy - along * along <= miss2
        end
        X, Y = Meet(lines)
    end
    local cx, cy, n = 0, 0, 0
    for i = 1, #lines do
        if lines[i].on then cx, cy, n = cx + lines[i].x, cy + lines[i].y, n + 1 end
    end
    if n == 0 then
        for i = 1, #lines do cx, cy, n = cx + lines[i].x, cy + lines[i].y, n + 1 end
    end
    cx, cy = cx / n, cy / n
    local dx, dy, dist = ux, uy, B.near
    if X and (X - cx) * ux + (Y - cy) * uy > 0 then
        dx, dy = X - cx, Y - cy
    end
    local len = sqrt(dx * dx + dy * dy)
    if len < 0.01 then return nil end
    dx, dy = dx / len, dy / len
    local bx, by, far = cx, cy, -1e9
    for i = 1, #lines do
        local l = lines[i]
        local pr = l.x * dx + l.y * dy
        if (l.on or n == #lines) and pr > far then bx, by, far = l.x, l.y, pr end
    end
    if X then
        local d = ((X - bx) * dx + (Y - by) * dy) / ppy
        if d >= B.near and d <= B.far then return X, Y end
        dist = min(B.far, max(B.near, d))
    end
    return bx + dx * dist * ppy, by + dy * dist * ppy
end
local function Falls(ctx, hits)
    local B = ctx.bomb
    local F = B.fall
    local out, used = {}, {}
    for i = 1, F and #ctx.tombCasts or 0 do
        for k = 0, F.n - 1 do
            local t = ctx.tombCasts[i] + F.first + k * F.step
            if t < ctx.fight.to then
                local got = nil
                for j = 1, #hits do
                    if not used[j] and math.abs(hits[j].t - t) <= F.join then
                        got, used[j] = hits[j], true
                        break
                    end
                end
                out[#out + 1] = got or { t = t, hits = {} }
            end
        end
    end
    for j = 1, #hits do
        if not used[j] then out[#out + 1] = hits[j] end
    end
    tsort(out, function(x, y) return x.t < y.t end)
    return out
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
local function OnWinter(ctx, ts, sub, id, target)
    local rings = ctx.rings
    local last = rings[#rings]
    if target then
        if HIT[sub] and ctx.wHit[id] then ctx.wHits[#ctx.wHits + 1] = { t = ts, name = target } end
        return
    end
    if not ctx.wAura[id] then return end
    if sub == "SPELL_CAST_START" then
        ctx.wStart = ts
    elseif sub == "SPELL_AURA_APPLIED" then
        if last and not last.to then return end
        local W = ctx.winter
        local start = ctx.wStart
        if not start or ts - start > W.castTime + 1 or start > ts then start = ts - W.castTime end
        rings[#rings + 1] = { from = start, on = ts }
        ctx.wStart = nil
    elseif REMOVED[sub] and last and not last.to then
        last.to = ts
    end
end
local function OnSoul(ctx, ts, sub, name)
    if sub == "SPELL_AURA_APPLIED" then
        if not ctx.sOpen[name] then ctx.sOpen[name] = ts end
    elseif REMOVED[sub] then
        local from = ctx.sOpen[name]
        if from then
            ctx.sOpen[name] = nil
            ctx.spans[#ctx.spans + 1] = { name = name, from = from, to = ts }
        end
    end
end
local function SoulDied(ctx, ts, name)
    local from = ctx.sOpen[name]
    if from then
        ctx.sOpen[name] = nil
        ctx.spans[#ctx.spans + 1] = { name = name, from = from, to = ts, died = ts }
        return
    end
    for i = #ctx.spans, 1, -1 do
        local s = ctx.spans[i]
        if s.name == name then
            if ts - s.to <= SOUL_DIE then s.died = ts end
            return
        end
    end
end
local function RunEnd(ctx, guid, ts)
    local run = ctx.cOpen[guid]
    if not run then return end
    run.to = ts
    ctx.cOpen[guid] = nil
end
local function RunStart(ctx, guid, name, ts, npc)
    RunEnd(ctx, guid, ts)
    local run = { guid = guid, name = name, from = ts, npc = npc }
    ctx.runs[#ctx.runs + 1] = run
    ctx.cOpen[guid] = run
end
local function Spawned(ctx, guid, di, ts)
    local link = ctx.chase[di].link or 0
    local wait = ctx.cWait
    for i = #wait, 1, -1 do
        local w = wait[i]
        if ts - w.t > link then break end
        if not w.used and w.di == di and w.t - SPAWN_EARLY <= ts then
            w.used = true
            RunStart(ctx, guid, w.name, ts, ctx.chase[di].npc)
            return
        end
    end
    ctx.cLone[#ctx.cLone + 1] = { t = ts, guid = guid, di = di }
end
local function Waited(ctx, w)
    local lone = ctx.cLone
    for i = #lone, 1, -1 do
        local o = lone[i]
        if w.t - o.t > SPAWN_EARLY then break end
        if not o.used and o.di == w.di then
            o.used, w.used = true, true
            RunStart(ctx, o.guid, w.name, o.t, ctx.chase[w.di].npc)
            return
        end
    end
end
local function Chase(ctx, ts, sub, srcGUID, dstGUID, dst, id, sk, dk)
    local target = dst and ctx.players[dst] and dst or nil
    local si, dI = sk and ctx.cNpc[sk], dk and ctx.cNpc[dk]
    if sub == "UNIT_DIED" then
        if dI then RunEnd(ctx, dstGUID, ts) end
        return
    end
    for pass = 1, 2 do
        local guid, di = srcGUID, si
        if pass == 2 then guid, di = dstGUID, dI end
        if di and not ctx.cSeen[guid] then
            ctx.cSeen[guid] = true
            if ctx.chase[di].spawn then Spawned(ctx, guid, di, ts) end
        end
    end
    if not target then return end
    if SWING[sub] then
        local run = si and ctx.chase[si].swing and ctx.cOpen[srcGUID]
        if run and run.name ~= target then RunStart(ctx, srcGUID, target, ts, run.npc) end
        return
    end
    if not id then return end
    local ai = ctx.cAura[id]
    if ai and si == ai then
        if sub == "SPELL_AURA_APPLIED" then
            RunStart(ctx, srcGUID, target, ts, ctx.chase[ai].npc)
        elseif REMOVED[sub] and ctx.cOpen[srcGUID] and ctx.cOpen[srcGUID].name == target then
            RunEnd(ctx, srcGUID, ts)
        end
    end
    local wi = ctx.cSpawn[id]
    if wi and REMOVED[sub] then
        local w = { t = ts, name = target, di = wi }
        ctx.cWait[#ctx.cWait + 1] = w
        Waited(ctx, w)
    end
end
function M.Event(ctx, ts, sub, srcGUID, src, dstGUID, dst, a1, amount, id, srcKey, dstKey)
    local P = ctx.players
    id = id or tonumber(a1)
    if #ctx.chase > 0 then
        if srcKey == nil then srcKey = ns.NpcKey(srcGUID) end
        if dstKey == nil then dstKey = ns.NpcKey(dstGUID) end
        Chase(ctx, ts, sub, srcGUID, dstGUID, dst, id, srcKey or nil, dstKey or nil)
    end
    if sub == BTGT then
        if dst and P[dst] then ctx.btgt[#ctx.btgt + 1] = { t = ts, src = src, dst = dst } end
        return
    end
    if sub == "UNIT_DIED" then
        if ctx.soul and dst and P[dst] then SoulDied(ctx, ts, dst) end
        return
    end
    if not id or (src and P[src]) then return end
    local target = dst and P[dst] and dst or nil
    if ctx.bomb then
        if sub == "SPELL_CAST_SUCCESS" and ctx.bCast[id] then
            AddCast(ctx.bCasts, ts, nil, src)
        elseif HIT[sub] and target and (ctx.bGas[id] or ctx.bBoom[id]) then
            ctx.bHits[#ctx.bHits + 1] = { t = ts, name = target, boom = ctx.bBoom[id] }
        elseif sub == "SPELL_CAST_START" and ctx.bFall[id] then
            ctx.tombCasts[#ctx.tombCasts + 1] = ts
        elseif target and ctx.bTomb[id] and sub == "SPELL_AURA_APPLIED" then
            ctx.tombs[#ctx.tombs + 1] = { name = target, from = ts }
        elseif target and ctx.bTomb[id] and REMOVED[sub] then
            for i = #ctx.tombs, 1, -1 do
                local tb = ctx.tombs[i]
                if tb.name == target and not tb.to then
                    tb.to = ts
                    break
                end
            end
        end
    end
    if ctx.wAura[id] or ctx.wHit[id] then OnWinter(ctx, ts, sub, id, target) end
    if ctx.sAura[id] and target then OnSoul(ctx, ts, sub, target) end
    if CAST[sub] and ctx.trapCast[id] then
        AddCast(ctx.casts, ts, target, src)
    elseif HIT[sub] and target and ctx.trapBoom[id] then
        AddHit(ctx, ts, srcGUID, target, amount, ctx.trap.join)
    end
    local zi = ctx.zCast[id]
    if zi and CAST[sub] then AddCast(ctx.zCasts[zi], ts, target, src) end
    zi = ctx.zDrop[id]
    if zi and target and REMOVED[sub] then AddCast(ctx.zCasts[zi], ts, target, src) end
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
local function Scatter(z, def, target, posAt, ppy, names, to)
    local hits = z.hits
    local ax, ay, reach
    if target then
        ax, ay = posAt(target, z.t)
        reach = def.scatter
    elseif hits[1] then
        ax, ay = posAt(hits[1].name, hits[1].t)
        reach = def.r + SCATTER_TOL
    end
    if not ax then return nil end
    local PX, PY, PH, np = {}, {}, {}, 0
    local tp, last = z.t + (def.arm or 0), min(z.t + def.life, to)
    while tp <= last do
        np = np + 1
        local X, Y, H = {}, {}, {}
        for i = 1, #names do
            local x, y = posAt(names[i], tp)
            X[i], Y[i] = x or false, y or 0
        end
        for h = 1, #hits do
            if hits[h].t >= tp - HIT_WIN and hits[h].t <= tp + HIT_WIN then H[hits[h].name] = true end
        end
        PX[np], PY[np], PH[np] = X, Y, H
        tp = tp + (def.pulse or def.life)
    end
    local rIn, rOut = ((def.r - SCATTER_TOL) * ppy) ^ 2, ((def.r + SCATTER_TOL) * ppy) ^ 2
    local best, sx, sy, n = 1e9, 0, 0, 0
    local span = floor(reach)
    for dy = -span, span do
        ns.Jobs.Step()
        for dx = -span, span do
            if dx * dx + dy * dy <= reach * reach then
                local x, y = ax + dx * ppy, ay + dy * ppy
                local bad = 0
                for p = 1, np do
                    local X, Y, H = PX[p], PY[p], PH[p]
                    for i = 1, #names do
                        local px = X[i]
                        if px then
                            local d2 = (px - x) ^ 2 + (Y[i] - y) ^ 2
                            if H[names[i]] then
                                if d2 > rOut then bad = bad + 1 end
                            elseif d2 < rIn then
                                bad = bad + 1
                            end
                        end
                    end
                    if bad > best then break end
                end
                if bad < best then
                    best, sx, sy, n = bad, x, y, 1
                elseif bad == best then
                    sx, sy, n = sx + x, sy + y, n + 1
                end
            end
        end
    end
    if n == 0 then return nil end
    return sx / n, sy / n
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
        z.target = target
        local x, y
        if def.scatter then
            x, y = Scatter(z, def, target, posAt, ppy, names, ctx.fight.to)
        elseif target then
            x, y = posAt(target, z.t)
        end
        if not x and not def.scatter and #z.hits > 0 then
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
        L.bT[j], L.bX[j], L.bY[j], L.bR[j], L.bN[j], L.bS[j], L.bTone[j] =
            L.bT[j - 1], L.bX[j - 1], L.bY[j - 1], L.bR[j - 1], L.bN[j - 1], L.bS[j - 1], L.bTone[j - 1]
        j = j - 1
    end
    L.bT[j], L.bX[j], L.bY[j], L.bR[j], L.bN[j], L.bS[j], L.bTone[j] = t, x, y, r, n, spell, nil
    L.nb = L.nb + 1
end
M.InsertBlast = InsertBlast
local function AddPool(L, from, to, x, y, r, tone, boom)
    local j = L.np + 1
    L.np = j
    L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = x, y, from, from, to
    L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j] = r, r, 1,
        { tone = tone, r0 = r, rmax = r, tail = 0, gap = 0, boom = boom }
end
local function ChaseLayer(ctx, L, byK)
    local addBy = {}
    for i = 1, L.adds and #L.adds or 0 do addBy[L.adds[i].guid] = L.adds[i] end
    local C = { n = 0, k = {}, from = {}, to = {}, add = {}, npc = {} }
    for i = 1, #ctx.runs do
        local run = ctx.runs[i]
        local to = run.to or ctx.fight.to
        local k = byK[run.name]
        if k and to > run.from then
            local n = C.n + 1
            C.n = n
            C.k[n], C.from[n], C.to[n], C.npc[n] = k, run.from, to, run.npc
            C.add[n] = addBy[run.guid] or false
        end
    end
    L.chase = C.n > 0 and C or nil
end
local function AddRing(L, ring, W)
    local j = L.np + 1
    L.np = j
    L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = -1, -1, ring.from, ring.on + W.full, ring.to
    L.plR0[j], L.plR1[j], L.plN[j] = W.r0, W.r, 0
    L.plDef[j] = { tone = W.tone, r0 = W.r0, rmax = W.r, tail = 0, gap = 0, follow = true }
end
local function Pulse(hits, ring, W)
    local last, gaps, t0 = {}, {}, nil
    for i = 1, #hits do
        local h = hits[i]
        if h.t >= ring.on and h.t <= ring.to then
            if not t0 or h.t < t0 then t0 = h.t end
            local p = last[h.name]
            local gap = p and h.t - p or 0
            if gap > W.tick * 0.5 and gap < W.tick * 1.5 then gaps[#gaps + 1] = gap end
            last[h.name] = h.t
        end
    end
    tsort(gaps)
    ring.tick = #gaps > 0 and gaps[floor(#gaps / 2) + 1] or W.tick
    ring.t0 = t0 or ring.on + W.full
end
function M.Waves(ring, W, t, rs, as)
    if t < ring.on or t >= (ring.to or t) then return 0, 0 end
    local tick, t0 = ring.tick or W.tick, ring.t0 or ring.on
    local beat = (t - t0) / tick
    local k = floor(beat)
    local n = 0
    while n < W.waves do
        local born = t0 + k * tick
        local age = t - born
        if age >= W.wave or born < ring.on then break end
        n = n + 1
        local u = age / W.wave
        rs[n] = W.r0 + (W.r - W.r0) * u
        as[n] = (1 - u) * min(1, age / W.waveIn)
        k = k - 1
    end
    if t < ring.on + W.full then return n, 0 end
    local fall = 1 - (beat - floor(beat))
    return n, W.edge + (1 - W.edge) * fall * fall
end
local function SpanOrder(a, b)
    if a.from ~= b.from then return a.from < b.from end
    return a.name < b.name
end
local function Waves(ctx)
    local spans = ctx.spans
    for name, from in pairs(ctx.sOpen) do spans[#spans + 1] = { name = name, from = from, to = ctx.fight.to } end
    ctx.sOpen = {}
    tsort(spans, SpanOrder)
    local waves, cur = {}, nil
    for i = 1, #spans do
        local s = spans[i]
        if not cur or s.from - cur.from > SOUL_JOIN then
            cur = { from = s.from, to = s.to, spans = {} }
            waves[#waves + 1] = cur
        end
        cur.spans[#cur.spans + 1] = s
        if s.to > cur.to then cur.to = s.to end
    end
    return { waves = waves, room = ctx.soul.room }
end
function M.Done(ctx, L, posAt, ppy, fc, byK)
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
            ctx.marks[#ctx.marks + 1] = { t = b.t - from, kind = "spell", id = D.boom[1], label = "rep.mk.trap", n = 1,
                                          who = { b.trigger } }
        end
    end
    if fc then M.FeedRows(ctx, fc) end
    for i = 1, #ctx.zoneOut do
        local z = ctx.zoneOut[i]
        if not z.def.spin then AddPool(L, z.from, z.to, z.x, z.y, z.def.r, z.def.tone) end
    end
    local B = ctx.bomb
    if B and B.show == "banner" then
        local list = Banner(ctx)
        if B.fall then list = Falls(ctx, list) end
        if #list > 0 then L.bombs, L.bombDef = list, B end
        ctx.drops = {}
        for i = 1, B.drop and #list or 0 do
            local b = list[i]
            local hit = {}
            for j = 1, #b.hits do hit[b.hits[j]] = true end
            local x, y = BombAt(ctx, b.t, hit, posAt, ppy, names)
            if x then
                ctx.drops[#ctx.drops + 1] = { t = b.t, x = x, y = y, hits = b.hits }
                AddPool(L, b.t - B.lead, b.t, x, y, B.r, B.tone, b.t)
                InsertBlast(L, b.t, x, y, B.blast * ppy, #b.hits, B.boom[1])
            end
        end
    end
    if byK then ChaseLayer(ctx, L, byK) end
    local W = ctx.winter
    for i = 1, W and #ctx.rings or 0 do
        local ring = ctx.rings[i]
        ring.to = ring.to or ctx.fight.to
        Pulse(ctx.wHits, ring, W)
        AddRing(L, ring, W)
    end
    L.mech = { traps = ctx.traps, booms = ctx.booms, zones = ctx.zoneOut, drops = ctx.drops, casts = ctx.bCasts,
               runs = ctx.runs, rings = ctx.rings, winter = W, winterHits = ctx.wHits }
    L.souls = ctx.soul and Waves(ctx) or nil
end
local function AddVictim(L, t, k)
    if L.nv >= VICTIM_LIMIT then return end
    local j = L.nv + 1
    while j > 1 and L.vT[j - 1] > t do
        L.vT[j], L.vK[j] = L.vT[j - 1], L.vK[j - 1]
        j = j - 1
    end
    L.vT[j], L.vK[j] = t, k
    L.nv = L.nv + 1
end
local function NearFlask(list, first, x, y)
    local best, bestD = list[first], nil
    for i = first, #list do
        local d = (list[i].x - x) ^ 2 + (list[i].y - y) ^ 2
        if not bestD or d < bestD then best, bestD = list[i], d end
    end
    return best
end
local function AddOnce(list, name)
    for i = 1, #list do
        if list[i] == name then return end
    end
    list[#list + 1] = name
end
local function ByFrom(a, b)
    return a.from < b.from
end
function M.Flasks(ctx, L, scene)
    local B = ctx.bomb
    local out = {}
    if not B or B.show ~= "flask" then return out end
    ctx.flasks = out
    if L.mech then L.mech.flasks = out end
    local boss, ppy = scene.boss, scene.ppy
    if not boss then return out end
    local Replay = ns.Replay
    local byK = Replay.ByK(scene)
    local casts, hits = ctx.bCasts, ctx.bHits
    local def = { tone = B.tone, flashTone = B.flashTone, tex = B.tex }
    local cue = L.cue or { rings = {}, arrows = {}, links = {} }
    L.cue = cue
    local hi = ctx.fight.to
    for ci = 1, #casts do
        local c = casts[ci]
        local bx, by = Replay.PosAtTime(boss, c.t)
        local bi = Replay.IndexAt(boss, c.t)
        if bx >= 0 and bi > 0 and c.t < hi then
            local fx, fy = boss.fx and boss.fx[bi] or 0, boss.fy and boss.fy[bi] or 1
            local boom = c.t + B.fuse
            for i = 1, #hits do
                local h = hits[i]
                if h.boom and math.abs(h.t - boom) <= B.slack then
                    boom = h.t
                    break
                end
            end
            boom = min(boom, hi)
            local from = min(c.t + B.spawn, boom)
            local first = #out + 1
            for a = 1, #B.at do
                local f, r = B.at[a][1] * ppy, B.at[a][2] * ppy
                out[#out + 1] = { cast = c.t, from = from, boom = boom, x = bx + f * fx + r * fy, y = by + f * fy - r * fx,
                                  gas = {}, hit = {} }
            end
            for i = 1, #hits do
                local h = hits[i]
                local mine = h.t >= (h.boom and boom or from) - FLASK_HIT and h.t <= boom + FLASK_HIT
                local k = mine and byK[h.name]
                if k then
                    local x, y = Replay.PosOf(scene, h.name, h.t)
                    local fl = x and NearFlask(out, first, x, y) or out[first]
                    AddOnce(h.boom and fl.hit or fl.gas, h.name)
                    AddVictim(L, h.t, k)
                end
            end
            for i = first, #out do
                local fl = out[i]
                AddPool(L, fl.from, fl.boom, fl.x, fl.y, B.r, B.tone)
                cue.rings[#cue.rings + 1] = { from = fl.from, boom = fl.boom, to = fl.boom + B.flash, r = B.blast,
                                              n = #fl.hit, def = def, x = fl.x, y = fl.y }
            end
        end
    end
    tsort(cue.rings, ByFrom)
    return out
end
local function Marks(fight)
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do out[#out + 1] = m[k] end
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
                for ts, x, y in ns.Decode.Pos(segs[i], name, fight.from - 5, fight.to + 5) do
                    if ts > fight.to + 5 then break end
                    if x > 0 or y > 0 then
                        local n = #tr.t + 1
                        tr.t[n], tr.x[n], tr.y[n] = ts, x, y
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
function M.FeedRows(ctx, fc)
    local D = ctx.trap
    if not D then return end
    for i = 1, #ctx.booms do
        local b = ctx.booms[i]
        if b.trigger then
            ns.ReplayFeedCore.Add(fc, b.t, "boss", D.boom[1], true, b.trigger, format(ns.T("rep.f.trap"), b.trigger))
        end
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
