local _, ns = ...
local sqrt = math.sqrt
local min = math.min
local tsort = table.sort
local SAME = 1
local POST = 0.1
local POST_MAX = 2.5
local LIMIT = 400
local NEAR_YD = 2
local CL = {}
ns.ReplayClass = CL
function CL.New(fight)
    local D = ns.replayClass
    if not D then return nil end
    local byAura, byCast, cone, jump = {}, {}, {}, {}
    for _, z in ipairs(D.zones) do
        if z.aura then byAura[z.aura] = { def = z, kind = "zones" } end
        if z.cast then byCast[z.cast] = { def = z, kind = "zones" } end
    end
    for _, g in ipairs(D.rings) do
        if g.aura then byAura[g.aura] = { def = g, kind = "rings" } end
        if g.cast then byCast[g.cast] = { def = g, kind = "rings" } end
    end
    for _, c in ipairs(D.cones) do cone[ns.SpellKey(c.spell)] = c end
    for _, j in ipairs(D.jumps) do jump[j.cast] = j end
    return {
        D = D, fight = fight, zones = {}, rings = {}, cones = {}, jumps = {}, circles = {}, beams = {},
        open = {}, seen = {}, byAura = byAura, byCast = byCast, cone = cone, jump = jump,
        beacon = D.beacon and ns.SpellKey(D.beacon),
    }
end
local function Add(list, rec)
    if #list < LIMIT then list[#list + 1] = rec end
end
local function OnSelfAura(ctx, ts, sub, name, id)
    local hit = ctx.byAura[id]
    if not hit then return end
    local key = hit.kind .. id .. name
    local rec = ctx.open[key]
    if sub == "SPELL_AURA_APPLIED" then
        if rec then return end
        rec = { name = name, from = ts, def = hit.def }
        ctx.open[key] = rec
        Add(ctx[hit.kind], rec)
    elseif sub == "SPELL_AURA_REMOVED" and rec then
        rec.to = ts
        ctx.open[key] = nil
    end
end
local function OnSpot(ctx, ts, name, id)
    local hit = ctx.byCast[id]
    if not hit then return end
    local list = ctx[hit.kind]
    for i = #list, 1, -1 do
        local r = list[i]
        if ts - r.from > SAME then break end
        if r.name == name and r.def == hit.def then return end
    end
    Add(list, { name = name, from = ts, to = ts + hit.def.dur, def = hit.def, fixed = true })
end
local function OnCircle(ctx, ts, sub, name)
    local key = "circle" .. name
    local cur = ctx.open[key]
    if sub == "SPELL_AURA_REMOVED" then
        if cur then
            cur.to = ts
            ctx.open[key] = nil
        end
        return
    end
    if cur and ts - cur.from <= SAME then return end
    if cur then cur.to = ts end
    cur = { name = name, from = ts }
    ctx.open[key] = cur
    Add(ctx.circles, cur)
end
local function OnBeacon(ctx, ts, sub, src, dst)
    if src == dst then return end
    local key = "beacon" .. dst .. "\0" .. src
    local cur = ctx.open[key]
    local seen = ctx.seen[key]
    ctx.seen[key] = true
    if sub == "SPELL_AURA_REMOVED" then
        if cur then
            cur.to = ts
            ctx.open[key] = nil
        elseif not seen then
            Add(ctx.beams, { name = dst, p = src, from = ctx.fight.from, to = ts })
        end
        return
    end
    if cur then return end
    local from = ts
    if sub == "SPELL_AURA_REFRESH" and not seen then from = ctx.fight.from end
    cur = { name = dst, p = src, from = from }
    ctx.open[key] = cur
    Add(ctx.beams, cur)
end
local function OnCone(ctx, ts, name, guid, def)
    local list = ctx.cones
    local last = ctx.open["cone" .. name]
    if not last or ts - last.to > def.join then
        last = { name = name, from = ts, to = ts, def = def, guids = {} }
        ctx.open["cone" .. name] = last
        Add(list, last)
    end
    last.to = ts
    if guid then last.guids[guid] = true end
end
function CL.Event(ctx, ts, sub, srcGUID, src, dstGUID, dst, a1)
    local id = tonumber(a1)
    if not id or not src then return end
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_REFRESH" then
        local key = ns.SpellKey(id)
        if key == ctx.beacon and dst then
            OnBeacon(ctx, ts, sub, src, dst)
        elseif id == ctx.D.circle.make and src == dst then
            OnCircle(ctx, ts, sub, src)
        elseif src == dst and sub ~= "SPELL_AURA_REFRESH" then
            OnSelfAura(ctx, ts, sub, src, id)
        end
        if sub == "SPELL_AURA_APPLIED" and ctx.cone[key] then OnCone(ctx, ts, src, dstGUID, ctx.cone[key]) end
    elseif sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_SUMMON" then
        OnSpot(ctx, ts, src, id)
        if sub == "SPELL_CAST_SUCCESS" then
            local j = ctx.jump[id]
            if j then Add(ctx.jumps, { name = src, from = ts, def = j }) end
            if id == ctx.D.circle.port then Add(ctx.jumps, { name = src, from = ts, port = true }) end
        end
    elseif sub == "SPELL_CREATE" and id == ctx.D.circle.make then
        OnCircle(ctx, ts, sub, src)
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED" then
        local def = ctx.cone[ns.SpellKey(id)]
        if def then OnCone(ctx, ts, src, dstGUID, def) end
    end
end
local function ByFrom(a, b)
    return a.from < b.from
end
local function Around(tr, ts)
    local i = ns.Replay.IndexAt(tr, ts)
    if i < 1 or tr.x[i] < 0 then return nil, 0, 0, 0 end
    local j = i + 1
    while j <= tr.n and tr.t[j] <= ts + POST do j = j + 1 end
    if j > tr.n or tr.t[j] > ts + POST_MAX or tr.x[j] < 0 then return nil, 0, 0, 0 end
    return tr.x[i], tr.y[i], tr.x[j], tr.y[j]
end
local function Aim(raw, x, y, scene, adds, bosses)
    local PosAt = ns.Replay.PosAtTime
    local sx, sy, n = 0, 0, 0
    local boss = scene.boss
    for guid in pairs(raw.guids) do
        local tx, ty = -1, -1
        local add = adds[guid]
        if add then
            tx, ty = PosAt(add, raw.from)
        elseif boss and bosses[ns.NpcKey(guid) or 0] then
            tx, ty = PosAt(boss, raw.from)
        end
        if tx >= 0 then sx, sy, n = sx + tx, sy + ty, n + 1 end
    end
    if n == 0 and boss then
        sx, sy = PosAt(boss, raw.from)
        n = sx >= 0 and 1 or 0
    end
    if n == 0 then return nil, 0 end
    local dx, dy = sx / n - x, sy / n - y
    local d = sqrt(dx * dx + dy * dy)
    if d < NEAR_YD * scene.ppy then return nil, 0 end
    return dx / d, dy / d
end
function CL.Done(ctx, L, scene, bosses)
    local hi, ppy = ctx.fight.to, scene.ppy
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local PosAt = ns.Replay.PosAtTime
    local out = { zones = {}, cones = {}, rings = {}, arrows = {}, circles = {}, beams = {} }
    local function Spot(name, ts)
        local k = byK[name]
        if not k then return nil, 0 end
        local x, y = PosAt(scene.tracks[k], ts)
        if x < 0 then return nil, 0 end
        return x, y
    end
    for _, kind in ipairs({ "zones", "rings" }) do
        for _, r in ipairs(ctx[kind]) do
            local k = byK[r.name]
            if k then
                local it = { from = r.from, to = min(r.to or r.from + r.def.dur, hi), r = r.def.r, tone = r.def.tone,
                             icon = r.def.icon, own = r.def.own and r.name or nil }
                if r.fixed then
                    it.x, it.y = Spot(r.name, r.from)
                else
                    it.k = k
                end
                if it.k or it.x then out[kind][#out[kind] + 1] = it end
            end
        end
    end
    local adds = {}
    for _, a in ipairs(L.adds or {}) do adds[a.guid] = a end
    for _, r in ipairs(ctx.cones) do
        local x, y = Spot(r.name, r.from)
        if x then
            local hx, hy = Aim(r, x, y, scene, adds, bosses or {})
            if hx then
                out.cones[#out.cones + 1] = { from = r.from, to = min(r.to + r.def.dur, hi), x = x, y = y, hx = hx, hy = hy,
                                              len = r.def.len, deg = r.def.deg }
            end
        end
    end
    local circ = ctx.D.circle
    local circles = {}
    for _, r in ipairs(ctx.circles) do
        local x, y = Spot(r.name, r.from)
        local it = { from = r.from, to = min(r.to or r.from + circ.life, hi), x = x, y = y, r = circ.r, name = r.name }
        if x then out.circles[#out.circles + 1] = it end
        circles[#circles + 1] = it
    end
    for _, r in ipairs(ctx.jumps) do
        local k = byK[r.name]
        local x0, y0, x1, y1
        if k then x0, y0, x1, y1 = Around(scene.tracks[k], r.from) end
        local dx, dy = (x1 or 0) - (x0 or 0), (y1 or 0) - (y0 or 0)
        local d = x0 and sqrt(dx * dx + dy * dy) / ppy or 0
        local need = r.port and NEAR_YD or r.def.min
        if x0 and d >= need then
            local show = r.port and circ.show or r.def.show
            out.arrows[#out.arrows + 1] = { from = r.from, to = min(r.from + show, hi), x = x0, y = y0, x1 = x1, y1 = y1,
                                             port = r.port }
            if r.port then
                local known = false
                for _, c in ipairs(circles) do
                    if c.name == r.name and c.from <= r.from and c.to >= r.from then known = true end
                end
                if not known then
                    out.circles[#out.circles + 1] = { from = ctx.fight.from, to = min(ctx.fight.from + circ.life, hi),
                                                      x = x1, y = y1, r = circ.r, name = r.name }
                end
            end
        end
    end
    for _, r in ipairs(ctx.beams) do
        local k, p = byK[r.name], byK[r.p]
        if k and p then out.beams[#out.beams + 1] = { from = r.from, to = min(r.to or hi, hi), k = k, p = p } end
    end
    for _, list in pairs(out) do tsort(list, ByFrom) end
    L.cls = out
    return out
end
