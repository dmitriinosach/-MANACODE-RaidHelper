local _, ns = ...
local min = math.min
local tsort = table.sort
local CASTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }
local HITS = { SPELL_DAMAGE = true, SPELL_MISSED = true }
local APPLIED = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true }
local REMOVED = { SPELL_AURA_REMOVED = true, SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true }
local LIMIT = 400
local C = {}
ns.ReplayCue = C
local keysOf = setmetatable({}, { __mode = "k" })
local function Has(ids, id)
    if not (ids and id) then return false end
    local set = keysOf[ids]
    if not set then
        set = {}
        for i = 1, #ids do set[ns.SpellKey(ids[i])] = true end
        keysOf[ids] = set
    end
    return set[id] == true
end
function C.New(fight)
    local D = ns.replayCue
    if not D then return nil end
    local rings, arrows, links = D.rings[fight.boss], D.arrows[fight.boss], D.links[fight.boss]
    if not (rings or arrows or links) then return nil end
    return {
        fight = fight, players = fight.players or {}, bosses = ns.Index.BossKeys(fight),
        rings = rings or {}, arrows = arrows or {}, links = links or {},
        ringOut = {}, open = {}, arrowRaw = {}, linkOn = {}, linkRaw = {},
    }
end
local function Rings(ctx, ts, sub, srcGUID, dst, id)
    local defs = ctx.rings
    for di = 1, #defs do
        local def = defs[di]
        if sub == def.sub and Has(def.cast, id) then
            local key = ns.NpcKey(srcGUID)
            local own = def.npc and key == ns.NpcKeyOf(def.npc) or (not def.npc and key and ctx.bosses[key])
            if own and #ctx.ringOut < LIMIT then
                local o = { from = ts, r = def.r, n = 0, def = def, guid = def.npc and srcGUID or nil }
                ctx.ringOut[#ctx.ringOut + 1] = o
                ctx.open[di] = o
            end
        elseif HITS[sub] and Has(def.hit, id) and dst and ctx.players[dst] then
            local o = ctx.open[di]
            if o and ts - o.from <= def.lead + def.slack then
                o.boom = o.boom or ts
                o.n = o.n + 1
            end
        end
    end
end
function C.Event(ctx, ts, sub, srcGUID, src, dst, a1)
    local id = ns.SpellOf(sub, a1)
    if not id then return end
    local P = ctx.players
    if #ctx.rings > 0 then Rings(ctx, ts, sub, srcGUID, dst, id) end
    if CASTS[sub] and dst and P[dst] and #ctx.arrowRaw < LIMIT then
        local defs = ctx.arrows
        for di = 1, #defs do
            if Has(defs[di].cast, id) then
                local key = ns.NpcKey(srcGUID)
                local from = (src and P[src]) and src or ((key and ctx.bosses[key]) and "" or nil)
                if from and from ~= dst then
                    ctx.arrowRaw[#ctx.arrowRaw + 1] = { t = ts, src = from ~= "" and from or nil, dst = dst, def = defs[di] }
                end
            end
        end
    end
    if not (src and dst and P[src] and P[dst] and src ~= dst) then return end
    local defs = ctx.links
    for di = 1, #defs do
        local def = defs[di]
        if Has(def.aura, id) then
            local key = src .. ">" .. dst
            local on = ctx.linkOn[key]
            if APPLIED[sub] and not on then
                ctx.linkOn[key] = { t = ts, src = src, dst = dst, def = def }
            elseif REMOVED[sub] and on then
                ctx.linkOn[key] = nil
                if #ctx.linkRaw < LIMIT then
                    ctx.linkRaw[#ctx.linkRaw + 1] = { from = on.t, to = ts, src = src, dst = dst, def = def }
                end
            end
        end
    end
end
local function ByFrom(a, b)
    return a.from < b.from
end
function C.Done(ctx, L, scene)
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local addBy = {}
    for i = 1, #(L.adds or {}) do addBy[L.adds[i].guid] = L.adds[i] end
    local hi = ctx.fight.to
    local out = { rings = {}, arrows = {}, links = {} }
    for i = 1, #ctx.ringOut do
        local o = ctx.ringOut[i]
        o.boom = o.boom or o.from + o.def.lead
        o.to = o.boom + o.def.flash
        o.add = o.guid and addBy[o.guid] or nil
        if not o.guid or o.add then out.rings[#out.rings + 1] = o end
    end
    for i = 1, #ctx.arrowRaw do
        local e = ctx.arrowRaw[i]
        local a, b = e.src and byK[e.src] or 0, byK[e.dst]
        if b and a then out.arrows[#out.arrows + 1] = { from = e.t, to = e.t + e.def.dur, a = a, b = b, def = e.def } end
    end
    for _, on in pairs(ctx.linkOn) do
        ctx.linkRaw[#ctx.linkRaw + 1] = { from = on.t, to = hi, src = on.src, dst = on.dst, def = on.def }
    end
    for i = 1, #ctx.linkRaw do
        local e = ctx.linkRaw[i]
        local a, b = byK[e.src], byK[e.dst]
        if a and b and e.to > e.from then
            out.links[#out.links + 1] = { from = e.from, to = min(e.to, hi), a = a, b = b, def = e.def }
        end
    end
    tsort(out.rings, ByFrom)
    tsort(out.arrows, ByFrom)
    tsort(out.links, ByFrom)
    L.cue = out
    return out
end
