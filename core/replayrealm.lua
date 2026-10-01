local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local atan2 = math.atan2
local pi = math.pi
local tsort = table.sort
local DEG = pi / 180
local HALF = pi / 2
local GRID = 720
local PHYS, TWI, ON, OFF, DIED = 1, 2, 3, 4, 5
local HUGE = math.huge
local HIT = {
    SPELL_DAMAGE = true, SPELL_MISSED = true, SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true,
    RANGE_MISSED = true,
}
local CUT = { SPELL_DAMAGE = true, SPELL_MISSED = true }
local EMOTE = "FW_EMOTE"
local STACK = "FW_STACK"
local LEAVE = "SPELL_CAST_SUCCESS"
local R = {}
ns.ReplayRealm = R
local function Ids(list)
    local out = {}
    for i = 1, list and #list or 0 do out[list[i]] = true end
    return out
end
function R.New(fight)
    local D = ns.replayMech
    local rd = D and D.realms and D.realms[fight.boss]
    if not rd then return nil end
    local cd = D.cutters and D.cutters[fight.boss]
    local ctx = {
        fight = fight, players = fight.players or {}, rd = rd, cd = cd, ev = {}, bossT = { {}, {} }, bossNames = {},
        emotes = {}, hits = {}, twi = Ids(rd.twi), phys = Ids(rd.phys), aura = ns.SpellSet(rd.aura),
        leave = ns.SpellSet(rd.leave), split = ns.SpellSet(rd.split), cutHit = ns.SpellSet(cd and cd.hit),
        cutPulse = ns.SpellSet(cd and cd.pulse), cutStart = ns.SpellSet(cd and cd.start),
        pudAura = {}, pudMark = {}, marks = {}, puds = {}, meteorHit = ns.SpellSet(rd.meteor and rd.meteor.hit),
        meteors = {},
    }
    R.PudIndex(ctx)
    return ctx
end
function R.PudIndex(ctx)
    local list = ctx.rd.puddles or {}
    for i = 1, #list do
        ctx.pudAura[ns.SpellKey(list[i].aura)] = i
        ctx.pudMark[ns.SpellKey(list[i].mark)] = i
        ctx.marks[i] = {}
    end
end
local function Add(ctx, name, ts, k)
    local e = ctx.ev[name]
    if not e then
        e = { t = {}, k = {} }
        ctx.ev[name] = e
    end
    local n = #e.t + 1
    e.t[n], e.k[n] = ts, k
end
local function Boss(ctx, npc, name, ts)
    local w = npc and ctx.rd.boss[npc]
    if not w then return end
    local list = ctx.bossT[w]
    list[#list + 1] = ts
    if name then ctx.bossNames[name] = true end
end
local function Puddle(ctx, ts, sub, sid, dst)
    if ctx.meteorHit[sid] and CUT[sub] then
        ctx.meteors[#ctx.meteors + 1] = { t = ts, name = dst }
        return
    end
    local i = ctx.pudMark[sid]
    if i then
        local m = ctx.marks[i]
        if sub == "SPELL_AURA_APPLIED" then
            m[dst] = 1
        elseif sub == "SPELL_AURA_APPLIED_DOSE" then
            m[dst] = (m[dst] or 1) + 1
        end
        return
    end
    i = ctx.pudAura[sid]
    if i and sub == "SPELL_AURA_REMOVED" then
        ctx.puds[#ctx.puds + 1] = { t = ts, name = dst, i = i, n = ctx.marks[i][dst] or 1 }
        ctx.marks[i][dst] = nil
    end
end
function R.Event(ctx, ts, sub, srcGUID, src, dstGUID, dst, a1, a2)
    if sub == STACK then
        local id = ns.SpellKey(a1)
        if id and ctx.aura[id] and src and ctx.players[src] then Add(ctx, src, ts, (tonumber(a2) or 0) > 0 and ON or OFF) end
        return
    end
    if sub == EMOTE then
        ctx.emotes[#ctx.emotes + 1] = { t = ts, src = src }
        return
    end
    local P = ctx.players
    local sn, dn = ns.NpcEntry(srcGUID), ns.NpcEntry(dstGUID)
    Boss(ctx, sn, src, ts)
    Boss(ctx, dn, dst, ts)
    if sub == "UNIT_DIED" then
        if dst and P[dst] then Add(ctx, dst, ts, DIED) end
        return
    end
    if HIT[sub] then
        local pl, npc
        if src and P[src] and dn then
            pl, npc = src, dn
        elseif dst and P[dst] and sn then
            pl, npc = dst, sn
        end
        local w = npc and (ctx.twi[npc] and TWI or ctx.phys[npc] and PHYS)
        if w then Add(ctx, pl, ts, w) end
    end
    local sid = ns.SpellOf(sub, a1)
    if not sid then return end
    if ctx.aura[sid] and dst and P[dst] then
        if sub == "SPELL_AURA_APPLIED" then
            Add(ctx, dst, ts, ON)
        elseif sub == "SPELL_AURA_REMOVED" then
            Add(ctx, dst, ts, OFF)
        end
    end
    if ctx.leave[sid] and sub == LEAVE and src and P[src] then Add(ctx, src, ts, OFF) end
    if not ctx.split3 and ctx.split[sid] then ctx.split3 = ts end
    if dst and P[dst] then Puddle(ctx, ts, sub, sid, dst) end
    if not ctx.cd then return end
    if not ctx.start and ctx.cutStart[sid] then ctx.start = ts end
    local pulse = ctx.cutPulse[sid]
    if CUT[sub] and (ctx.cutHit[sid] or pulse) and dst and P[dst] then
        local pair = sn and ctx.cd.pairs[sn]
        if pair then ctx.hits[#ctx.hits + 1] = { t = ts, name = dst, pair = pair, pulse = pulse == true } end
    end
end
local function Order(e)
    local idx = {}
    for i = 1, #e.t do idx[i] = i end
    tsort(idx, function(a, b)
        if e.t[a] ~= e.t[b] then return e.t[a] < e.t[b] end
        return a < b
    end)
    return idx
end
local function Spans(e, rd, to)
    local out = { from = {}, to = {} }
    local idx = Order(e)
    local auras = false
    for i = 1, #idx do
        if e.k[idx[i]] == ON then auras = true end
    end
    local open, first, last, lastPhys = false, 0, 0, nil
    local function Close(at)
        local n = #out.from + 1
        out.from[n], out.to[n] = first, max(first, at)
        open = false
    end
    for i = 1, #idx do
        local t, k = e.t[idx[i]], e.k[idx[i]]
        if auras then
            if k == ON and not open then
                open, first, last = true, t, t
            elseif k == OFF and open then
                Close(t)
            end
        elseif k == TWI then
            if open and t - last > rd.gap then Close(last + rd.pad) end
            if not open then
                open, first = true, t - rd.pad
                if lastPhys and first < lastPhys then first = lastPhys end
            end
            last = t
        elseif k == DIED then
            if open and t - last <= rd.gap then last = HUGE end
        elseif k == PHYS or k == OFF then
            if open then Close(k == OFF and t or min(last + rd.pad, t)) end
            if k == PHYS then lastPhys = t end
        end
    end
    if open then Close(auras and to or min(to, last + rd.pad)) end
    return out, auras
end
local function Runs(list, join, to)
    tsort(list)
    local out = { from = {}, to = {} }
    local n = 0
    for i = 1, #list do
        local t = list[i]
        if n > 0 and t - out.to[n] <= join then
            out.to[n] = t
        else
            n = n + 1
            out.from[n], out.to[n] = t, t
        end
    end
    for i = 1, n do
        if to - out.to[i] <= join then out.to[i] = to end
    end
    return out
end
local function Wrap(a)
    a = a % pi
    if a > HALF then a = a - pi end
    return a
end
R.Wrap = Wrap
local function Fit(hits, cut, a0p, wp, skip)
    local best, bestE
    for g = 0, GRID - 1 do
        local a0 = g * pi / GRID
        local d = Wrap(a0 - a0p)
        local err = wp * d * d
        for i = 1, #hits do
            local h = hits[i]
            if h.th and i ~= skip then
                local r = Wrap(h.th - a0 - cut.w * (h.t - cut.from) - h.pair * HALF)
                err = err + r * r
            end
        end
        if not bestE or err < bestE then best, bestE = a0, err end
    end
    return best
end
local function Windows(ctx, cut)
    local cd = ctx.cd
    local marks = {}
    for i = 1, #ctx.emotes do
        local e = ctx.emotes[i]
        if not (e.src and ctx.bossNames[e.src]) and e.t >= cut.from - cd.warn then marks[#marks + 1] = e.t end
    end
    tsort(marks)
    local base = marks[1] or (cut.from + cd.first)
    local k0 = floor((cut.from - base) / cd.period)
    for k = k0, floor((cut.to - base) / cd.period) do
        local want = base + k * cd.period
        local got
        for i = 1, #marks do
            if abs(marks[i] - want) <= cd.warn then got = marks[i] end
        end
        local on = (got or want) + cd.warn
        if on + cd.burn > cut.from and on < cut.to then
            local n = #cut.wFrom + 1
            cut.wFrom[n], cut.wTo[n] = max(on, cut.from), min(on + cd.burn, cut.to)
        end
    end
    for i = 1, #cut.hits do
        local t = cut.hits[i].t
        local inside = false
        for j = 1, #cut.wFrom do
            if t >= cut.wFrom[j] - 0.5 and t <= cut.wTo[j] + 0.5 then inside = true end
        end
        if not inside then
            local n = #cut.wFrom + 1
            cut.wFrom[n], cut.wTo[n] = t - 1, min(t - 1 + cd.burn, cut.to)
        end
    end
    local idx = {}
    for i = 1, #cut.wFrom do idx[i] = i end
    tsort(idx, function(a, b) return cut.wFrom[a] < cut.wFrom[b] end)
    local f, t = {}, {}
    for i = 1, #idx do f[i], t[i] = cut.wFrom[idx[i]], cut.wTo[idx[i]] end
    cut.wFrom, cut.wTo = f, t
end
function R.Cutter(ctx, posAt, ppy)
    local cd = ctx.cd
    if not cd then return nil end
    local from = ctx.start
    for i = 1, #ctx.hits do
        if not from or ctx.hits[i].t < from then from = ctx.hits[i].t end
    end
    if not from then return nil end
    local fight = ctx.fight
    local two = false
    for i = 1, #ctx.hits do two = two or ctx.hits[i].pair == 1 end
    if not two then
        local n = 0
        for _ in pairs(ctx.players) do n = n + 1 end
        two = n > 12
    end
    local cut = { cx = cd.cx, cy = cd.cy, r = cd.r * ppy, from = from, to = fight.to, a0 = cd.a0 * DEG,
                  w = cd.wps * DEG, pairs = two and 2 or 1, wFrom = {}, wTo = {}, hits = ctx.hits, used = 0 }
    local near = cd.near * ppy
    for i = 1, #ctx.hits do
        local h = ctx.hits[i]
        local x, y = posAt(h.name, h.t)
        if x then
            local dx, dy = x - cd.cx, y - cd.cy
            if dx * dx + dy * dy >= near * near then
                h.th = atan2(dy, dx)
                cut.used = cut.used + 1
            end
        end
    end
    local wp = (cd.sigma / cd.prior) ^ 2
    if cut.used > 0 then
        cut.a0 = Fit(ctx.hits, cut, cd.a0 * DEG, wp)
        local sum = 0
        for i = 1, #ctx.hits do
            local h = ctx.hits[i]
            if h.th then
                h.res = Wrap(h.th - cut.a0 - cut.w * (h.t - cut.from) - h.pair * HALF)
                sum = sum + abs(h.res)
            end
        end
        cut.err = sum / cut.used
    end
    Windows(ctx, cut)
    return cut
end
function R.HoldOut(ctx, cut)
    local cd = ctx.cd
    local wp = (cd.sigma / cd.prior) ^ 2
    local sum, n = 0, 0
    for i = 1, #cut.hits do
        local h = cut.hits[i]
        if h.th then
            local a0 = Fit(cut.hits, cut, cd.a0 * DEG, wp, i)
            sum = sum + abs(Wrap(h.th - a0 - cut.w * (h.t - cut.from) - h.pair * HALF))
            n = n + 1
        end
    end
    return n > 0 and sum / n or nil
end
function R.Angle(cut, t)
    return cut.a0 + cut.w * (t - cut.from)
end
function R.Burning(cut, t)
    for i = 1, #cut.wFrom do
        if t >= cut.wFrom[i] and t < cut.wTo[i] then return true end
        if cut.wFrom[i] > t then break end
    end
    return false
end
function R.Puddles(ctx, posAt, ppy)
    local out = {}
    local defs = ctx.rd.puddles or {}
    local to = ctx.fight.to
    for i = 1, #ctx.puds do
        local p = ctx.puds[i]
        local d = defs[p.i]
        local x, y = posAt(p.name, p.t)
        if x then
            out[#out + 1] = { x = x, y = y, r = min(d.max, d.base + d.per * p.n) * ppy, from = p.t, to = to,
                              realm = d.realm, tone = d.tone, n = p.n }
        end
    end
    local M = ctx.rd.meteor
    local i = 1
    while M and i <= #ctx.meteors do
        local t0 = ctx.meteors[i].t
        local n, sx, sy, hit = 0, 0, 0, 0
        while i <= #ctx.meteors and ctx.meteors[i].t - t0 <= M.join do
            hit = hit + 1
            local x, y = posAt(ctx.meteors[i].name, ctx.meteors[i].t)
            if x then n, sx, sy = n + 1, sx + x, sy + y end
            i = i + 1
        end
        if n > 0 then
            out[#out + 1] = { x = sx / n, y = sy / n, r = M.r * ppy, from = t0, to = min(to, t0 + M.burn), realm = M.realm,
                              tone = M.tone, n = hit, flash = M.flash }
        end
    end
    tsort(out, function(a, b) return a.from < b.from end)
    return out
end
function R.Done(ctx, L, posAt, ppy)
    local to = ctx.fight.to
    local spans, auras = {}, false
    for name, e in pairs(ctx.ev) do
        local s, a = Spans(e, ctx.rd, to)
        if #s.from > 0 then spans[name] = s end
        auras = auras or a
    end
    local boss = {}
    for w = 1, 2 do boss[w] = Runs(ctx.bossT[w], ctx.rd.join, to) end
    local p2 = boss[2].from[1]
    if p2 then
        boss[1] = { from = { ctx.fight.from }, to = { p2 } }
        if ctx.split3 and ctx.split3 > p2 then boss[1].from[2], boss[1].to[2] = ctx.split3, to end
        boss[2] = { from = { p2 }, to = { to } }
    end
    local seg = (ctx.fight.seg or ctx.fight.segs) and ns.Encounters.Segs(ctx.fight)[1] or nil
    local me = seg and type(seg.raid) == "table" and seg.raid.who or nil
    L.realm = { spans = spans, boss = boss, auras = auras, me = me, p2 = p2 }
    L.cutter = R.Cutter(ctx, posAt, ppy)
    L.puddles = R.Puddles(ctx, posAt, ppy)
end
function R.In(s, t)
    if not s then return false end
    for i = 1, #s.from do
        if t < s.from[i] then return false end
        if t <= s.to[i] then return true end
    end
    return false
end
