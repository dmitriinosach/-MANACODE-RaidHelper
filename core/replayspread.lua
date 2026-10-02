local _, ns = ...
local sqrt = math.sqrt
local min = math.min
local tsort = table.sort
local CASTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }
local APPLIED = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true }
local HITS = { SPELL_DAMAGE = true, SPELL_MISSED = true }
local LIFE = 15
local MERGE = 0.3
local STEP = 0.25
local PRE = 5
local S = {}
ns.ReplaySpread = S
local function Index(defs, field)
    local out = {}
    for di = 1, #defs do
        local ids = defs[di][field]
        for i = 1, ids and #ids or 0 do
            local list = out[ids[i]] or {}
            list[#list + 1] = di
            out[ids[i]] = list
        end
    end
    return out
end
function S.Defs(boss)
    local D = ns.replaySpread
    return D and D.bosses[boss]
end
function S.New(fight)
    local defs = S.Defs(fight.boss)
    if not defs or #defs == 0 then return nil end
    local ctx = { fight = fight, players = fight.players or {}, defs = defs, hold = ns.replaySpread.hold or 0,
                  cast = Index(defs, "cast"), aura = Index(defs, "aura"), hit = Index(defs, "hit"),
                  open = Index(defs, "open"), openT = {}, on = {}, raw = {} }
    for di = 1, #defs do ctx.on[di], ctx.raw[di] = {}, {} end
    return ctx
end
local function Add(ctx, di, name, from, to)
    local raw = ctx.raw[di]
    raw[#raw + 1] = { name = name, from = from, to = to }
end
local function Stop(ctx, di, name, ts)
    local from = ctx.on[di][name]
    if not from then return end
    ctx.on[di][name] = nil
    Add(ctx, di, name, from, ts + ctx.hold)
end
function S.Event(ctx, ts, sub, src, dst, a1)
    local id = tonumber(a1)
    if not id then return end
    local P = ctx.players
    if src and P[src] then return end
    local list = ctx.open[id]
    if list and (CASTS[sub] or sub == "SPELL_AURA_APPLIED") then
        for i = 1, #list do ctx.openT[list[i]] = ts end
    end
    if not (dst and P[dst]) then return end
    list = ctx.cast[id]
    if list and CASTS[sub] then
        for i = 1, #list do
            local on = ctx.on[list[i]]
            on[dst] = on[dst] or ts
        end
    end
    list = ctx.aura[id]
    if list and APPLIED[sub] then
        for i = 1, #list do
            local on = ctx.on[list[i]]
            on[dst] = on[dst] or ts
        end
    elseif list and sub == "SPELL_AURA_REMOVED" then
        for i = 1, #list do Stop(ctx, list[i], dst, ts) end
    end
    list = ctx.hit[id]
    if list and HITS[sub] then
        for i = 1, #list do
            local di = list[i]
            local def = ctx.defs[di]
            local o = ctx.openT[di]
            local from = (o and ts - o <= (def.span or 0)) and o or ts - (def.lead or 0)
            Add(ctx, di, dst, from, ts + ctx.hold)
        end
    end
end
local function ByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.from < b.from
end
local function ByFrom(a, b)
    if a.from ~= b.from then return a.from < b.from end
    return a.k < b.k
end
function S.Done(ctx, L, scene)
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local lo, hi = ctx.fight.from - PRE, ctx.fight.to
    local out = {}
    for di = 1, #ctx.defs do
        for name, from in pairs(ctx.on[di]) do Add(ctx, di, name, from, min(from + LIFE, hi)) end
        ctx.on[di] = {}
        local raw = ctx.raw[di]
        tsort(raw, ByName)
        local cur
        for i = 1, #raw do
            local w = raw[i]
            local k = byK[w.name]
            local from, to = w.from < lo and lo or w.from, w.to > hi and hi or w.to
            if k and to > from then
                if cur and cur.k == k and from <= cur.to + MERGE then
                    if to > cur.to then cur.to = to end
                else
                    cur = { k = k, from = from, to = to, r = ctx.defs[di].r, di = di }
                    out[#out + 1] = cur
                end
            end
        end
    end
    tsort(out, ByFrom)
    L.spread = out
    return out
end
function S.Near(states, k, rpx, out)
    local me = states[k]
    local n = 0
    if not (me and me.vis and not me.dead) then return 0 end
    local r2 = rpx * rpx
    for j = 1, #states do
        local s = states[j]
        if j ~= k and s.vis and not s.dead then
            local dx, dy = s.x - me.x, s.y - me.y
            if dx * dx + dy * dy < r2 then
                n = n + 1
                out[n] = j
            end
        end
    end
    return n
end
local function StateAt(tr, t, st)
    local x, y = ns.Replay.PosAtTime(tr, t)
    local i = ns.Replay.IndexAt(tr, t)
    st.vis = x >= 0
    st.x, st.y = x, y
    st.dead = i > 0 and tr.dz[i] > 0
end
function S.Check(scene, list)
    list = list or (scene.layers and scene.layers.spread) or {}
    local tracks, ppy = scene.tracks, scene.ppy
    local states, near, out = {}, {}, {}
    for j = 1, #tracks do states[j] = {} end
    for i = 1, #list do
        local w = list[i]
        local hit
        local t = w.from
        while t <= w.to do
            for j = 1, #tracks do StateAt(tracks[j], t, states[j]) end
            local n = S.Near(states, w.k, w.r * ppy, near)
            if n > 0 then
                local me, best = states[w.k], nil
                hit = hit or { w = w, t = t, who = {}, seen = {} }
                for m = 1, n do
                    local j = near[m]
                    local dx, dy = states[j].x - me.x, states[j].y - me.y
                    local d = sqrt(dx * dx + dy * dy) / ppy
                    if not best or d < best then best = d end
                    if not hit.seen[j] then
                        hit.seen[j] = true
                        hit.who[#hit.who + 1] = j
                    end
                end
                if not hit.d or best < hit.d then hit.d = best end
            end
            t = t + STEP
        end
        if hit then
            hit.seen = nil
            local te = w.to - (ns.replaySpread.hold or 0)
            for j = 1, #tracks do StateAt(tracks[j], te, states[j]) end
            hit.final = S.Near(states, w.k, w.r * ppy, near)
            out[#out + 1] = hit
        end
    end
    return out
end
