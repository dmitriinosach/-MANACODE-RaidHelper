local _, ns = ...
local sqrt = math.sqrt
local min = math.min
local tsort = table.sort
local STEP = 0.25
local HOLD_STEP = 2
local SIM = 0.1
local MATCH = 0.4
local Ooze = {}
ns.ReplayOoze = Ooze
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
    if ctx.fHit[id] and dst and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") then
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
local function Floods(ctx, L, scene, Pos, ppy)
    local F, hits, room = ctx.flood, ctx.fHits, scene.room
    if not F or #hits == 0 or not room then return 0 end
    local px, py = {}, {}
    for p = 1, #F.pipes do px[p], py[p] = room.cx + F.pipes[p][1] * ppy, room.cy + F.pipes[p][2] * ppy end
    local t0 = (scene.pull or scene.fight.from) + F.first
    local last, n, i = hits[#hits].t, 0, 1
    local def = { tone = F.tone, r0 = F.r0, rmax = F.r, tail = 0, gap = 0 }
    local k = 0
    while t0 + k * F.step - F.early <= last do
        local s = t0 + k * F.step
        local e = s + F.step
        local lit = {}
        while i <= #hits and hits[i].t < e - F.early do
            local h = hits[i]
            if h.t >= s - F.early then
                local x, y = Pos(h.n, h.t)
                local best, bp = 1e18, nil
                for p = 1, x and #px or 0 do
                    local d = (px[p] - x) ^ 2 + (py[p] - y) ^ 2
                    if d < best then best, bp = d, p end
                end
                if bp and (not lit[bp] or h.t < lit[bp]) then lit[bp] = h.t end
            end
            i = i + 1
        end
        for p, tf in pairs(lit) do
            local from = min(s, tf)
            local j = L.np + 1
            L.np = j
            L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = px[p], py[p], from, from + F.pour, e + F.keep
            L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j] = F.r0, F.r, 1, def
            n = n + 1
        end
        k = k + 1
    end
    return n
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
    st.floods = Floods(ctx, L, scene, Pos, ppy)
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
