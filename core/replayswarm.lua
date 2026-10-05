local _, ns = ...
local min = math.min
local tsort = table.sort
local PUFF_LIMIT = 600
local MATCH = 0.3
local VARIANTS = 8
local GOLD = 0.618
local SW = {}
ns.ReplaySwarm = SW
function SW.New(fight)
    local def = ns.replaySwarm and ns.replaySwarm[fight.boss]
    if not def then return nil end
    return { def = def, fight = fight, marks = {}, open = {}, sName = {}, sT = {}, sLife = {} }
end
function SW.Event(ctx, ts, sub, src, dst, a1)
    local id = tonumber(a1)
    if not id then return end
    local def = ctx.def
    if sub == "SPELL_SUMMON" then
        local life = def.summon[id]
        if life and src then
            local n = #ctx.sT + 1
            ctx.sName[n], ctx.sT[n], ctx.sLife[n] = src, ts, life
        end
        return
    end
    if not dst then return end
    if sub == "SPELL_CAST_SUCCESS" and def.cast[id] then
        local m = { name = dst, from = ts }
        ctx.marks[#ctx.marks + 1] = m
        ctx.open[dst] = m
    elseif sub == "SPELL_AURA_APPLIED" and def.aura[id] then
        local m = ctx.open[dst]
        if not m or m.on then
            m = { name = dst, from = ts - def.lead }
            ctx.marks[#ctx.marks + 1] = m
            ctx.open[dst] = m
        end
        m.on = ts
    elseif sub == "SPELL_AURA_REMOVED" and def.aura[id] then
        local m = ctx.open[dst]
        if m and m.on and not m.to then
            m.to = ts
            ctx.open[dst] = nil
        end
    end
end
local function Puff(S, x, y, from, life)
    if S.n >= PUFF_LIMIT then return end
    local n = S.n + 1
    S.n = n
    S.x[n], S.y[n], S.from[n], S.to[n] = x, y, from, from + life
    S.v[n] = (n * 5) % VARIANTS + 1
end
local function HasSummon(ctx, m, to)
    local T, N = ctx.sT, ctx.sName
    for i = 1, #T do
        if N[i] == m.name and T[i] >= m.on - MATCH and T[i] <= to + MATCH then return true end
    end
    return false
end
local function SortPuffs(S)
    local idx = {}
    for i = 1, S.n do idx[i] = i end
    tsort(idx, function(a, b) return S.from[a] < S.from[b] end)
    local x, y, from, to, v = {}, {}, {}, {}, {}
    for i = 1, S.n do
        local j = idx[i]
        x[i], y[i], from[i], to[i], v[i] = S.x[j], S.y[j], S.from[j], S.to[j], S.v[j]
    end
    S.x, S.y, S.from, S.to, S.v = x, y, from, to, v
end
function SW.Done(ctx, L, scene)
    local def, hi = ctx.def, ctx.fight.to
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local S = { r = def.r, tones = def.tones, n = 0, x = {}, y = {}, from = {}, to = {}, v = {},
                nm = 0, mk = {}, mFrom = {}, mOn = {}, mTo = {} }
    local PosAt = ns.Replay.PosAtTime
    for i = 1, #ctx.sT do
        local k = byK[ctx.sName[i]]
        if k then
            local t = ctx.sT[i]
            local x, y = PosAt(scene.tracks[k], t)
            if x >= 0 then Puff(S, x, y, t, ctx.sLife[i]) end
        end
    end
    for i = 1, #ctx.marks do
        local m = ctx.marks[i]
        local k = byK[m.name]
        if k then
            local on = m.on or m.from + def.lead
            local to = m.to or (m.on and min(m.on + def.span, hi)) or on
            local j = S.nm + 1
            S.nm = j
            S.mk[j], S.mFrom[j], S.mOn[j], S.mTo[j] = k, m.from, on, to
            if m.on and not HasSummon(ctx, m, to) then
                local t = m.on + def.step
                while t <= to do
                    local x, y = PosAt(scene.tracks[k], t)
                    if x >= 0 then Puff(S, x, y, t, def.life) end
                    t = t + def.step
                end
            end
        end
    end
    SortPuffs(S)
    L.swarm = S
    return S
end
function SW.Phase(i)
    return (i * GOLD) % 1
end
