local _, ns = ...
local max = math.max
local min = math.min
local abs = math.abs
local tsort = table.sort
local WHO_MAX = 10
local ATTACH = 20
local MASS = 5
local MASS_GAP = 3
local DRIFT = 2
local CHANGE_LEAD = 8
local CHANGE_LAG = 3
local BAND_JOIN = 2
local FOLD_SHARE = 0.06
local FOLD_MAX = 0.3
local FOLD_MIN = 20
local MK = { DRIFT = DRIFT }
ns.ReplayMarks = MK
function MK.Defs(boss)
    local D = ns.replayMarks
    if not D or boss == nil then return {} end
    return D.bosses[boss] or {}
end
function MK.New(fight)
    local defs = MK.Defs(fight.boss)
    local by, want = {}, {}
    for i = 1, #defs do
        local def = defs[i]
        local subs = type(def.sub) == "table" and def.sub or { def.sub }
        for s = 1, #subs do
            local m = by[subs[s]] or {}
            by[subs[s]] = m
            for k = 1, #def.ids do
                m[def.ids[k]] = i
                want[def.ids[k]] = true
            end
        end
    end
    return { from = fight.from, to = fight.to or fight.from, boss = fight.boss, defs = defs, by = by, want = want, players = fight.players or {},
             last = {}, lastTs = {}, list = {} }
end
local function AddWho(list, name)
    if not name or #list >= WHO_MAX then return end
    for i = 1, #list do
        if list[i] == name then return end
    end
    list[#list + 1] = name
end
MK.AddWho = AddWho
function MK.Event(mc, ts, sub, src, dst, a1, id)
    local m = mc.by[sub]
    if not m then return end
    id = id or tonumber(a1)
    local i = id and m[id]
    if not i or (src and mc.players[src]) then return end
    local who = sub ~= "SPELL_SUMMON" and dst ~= src and mc.players[dst] and dst or nil
    local prev = mc.last[i]
    if prev and ts - mc.lastTs[i] <= (mc.defs[i].gap or ns.replayMarks.gap) then
        AddWho(prev.who, who)
        return
    end
    local mk = { t = ts - mc.from, kind = "spell", key = "s" .. i, id = id, n = 1, who = {} }
    AddWho(mk.who, who)
    mc.last[i], mc.lastTs[i] = mk, ts
    mc.list[#mc.list + 1] = mk
end
local function ByTime(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.key < b.key
end
local function PhaseIcon(def, look, key)
    if look and look.icons[key] then return look.icons[key] end
    for _, step in ipairs(def and def.steps or {}) do
        local on = step.key == key and step.on and step.on[1]
        if on then return on[2] end
    end
    return nil
end
local function PhaseIds(def, boss, look)
    local set = {}
    for _, step in ipairs(def and def.steps or {}) do
        for _, on in ipairs(step.on or {}) do
            for k = 2, #on do set[on[k]] = true end
        end
    end
    local gone = ns.replayData and ns.replayData.gone[boss]
    for _, g in ipairs(gone or {}) do
        for _, id in ipairs(g.ids) do set[id] = true end
    end
    for kind in pairs(look and look.bands or {}) do
        local on = def and def.waves and def.waves[kind] and def.waves[kind].on
        for k = 2, on and #on or 0 do set[on[k]] = true end
    end
    return set
end
local function ByFrom(a, b)
    return a.from < b.from
end
local function Bands(away, res, look)
    local out = {}
    if not look then return out end
    if look.away then
        for _, a in ipairs(away) do
            out[#out + 1] = { from = a.from, to = a.to, key = "away", label = look.away, icon = look.icons.away }
        end
    end
    for kind, label in pairs(look.bands or {}) do
        local times, ends = res and res.waves[kind], res and res.ends[kind]
        for j = 1, times and #times or 0 do
            local to = ends and ends[j]
            if to and to > times[j] then
                out[#out + 1] = { from = times[j], to = to, key = kind, label = label, icon = look.icons[kind] }
            end
        end
    end
    tsort(out, ByFrom)
    local kept = {}
    for k = 1, #out do
        local b, prev = out[k], kept[#kept]
        if prev and b.from < prev.to then b.from = prev.to end
        if prev and b.from - prev.to < BAND_JOIN then prev.to = b.from end
        if b.to > b.from then kept[#kept + 1] = b end
    end
    return kept
end
local function Split(phases, bands)
    if #bands == 0 then return phases end
    local out = {}
    for k = 1, #phases do
        local ph = phases[k]
        local from = ph.from
        for _, b in ipairs(bands) do
            if b.to > from and b.from < ph.to then
                local at = max(b.from, from)
                if at - from >= BAND_JOIN then
                    out[#out + 1] = { from = from, to = at, key = ph.key, label = ph.label, icon = ph.icon }
                    from = at
                end
                local to = min(b.to, ph.to)
                if ph.to - to < BAND_JOIN then to = ph.to end
                out[#out + 1] = { from = from, to = to, key = b.key, label = b.label, icon = b.icon }
                from = to
            end
        end
        if ph.to > from then out[#out + 1] = { from = from, to = ph.to, key = ph.key, label = ph.label, icon = ph.icon } end
    end
    return out
end
local function Fold(phases, collapse, folds)
    local out = {}
    for k = 1, #phases do
        local ph = phases[k]
        local keep = collapse[ph.key]
        local cut = keep and ph.to - keep
        if cut and cut - ph.from >= FOLD_MIN then
            out[#out + 1] = { from = ph.from, to = cut, key = ph.key, label = ph.label, icon = ph.icon, fold = true }
            out[#out + 1] = { from = cut, to = ph.to, key = ph.key, label = ph.label, icon = ph.icon }
            folds[#folds + 1] = { from = ph.from, to = cut }
        else
            out[#out + 1] = ph
        end
    end
    return out
end
function MK.Done(mc, L, res)
    local spans = res and res.spans or {}
    local def = ns.bossPhases and mc.boss and ns.bossPhases[mc.boss]
    local look = mc.boss and ns.replayMarks.phases[mc.boss]
    local phases = {}
    for k = 1, #spans do
        local sp = spans[k]
        if sp.key ~= "gone" then
            phases[#phases + 1] = { from = sp.from, to = sp.to, key = sp.key, label = sp.label,
                                    icon = PhaseIcon(def, look, sp.key) }
        end
    end
    for k = 1, #phases - 1 do phases[k].to = phases[k + 1].from end
    if #phases == 0 then
        phases[1] = { from = 0, to = mc.to - mc.from, key = "fight", label = "ph.fight", icon = look and look.icons.fight }
    end
    local bands = Bands(L.away or {}, res, look)
    phases = Split(phases, bands)
    local ids, starts = PhaseIds(def, mc.boss, look), {}
    for k = 2, #phases do starts[#starts + 1] = phases[k].from end
    for _, a in ipairs(L.away or {}) do starts[#starts + 1] = a.at end
    local kept, dropped = {}, {}
    for _, mk in ipairs(mc.list) do
        local change = false
        if mk.id and ids[mk.id] then
            for _, s in ipairs(starts) do
                if mk.t >= s - CHANGE_LEAD and mk.t <= s + CHANGE_LAG then change = true end
            end
        end
        if change then dropped[#dropped + 1] = mk else kept[#kept + 1] = mk end
    end
    mc.list, L.phaseMarks = kept, dropped
    local waves = {}
    for kind, times in pairs(res and res.waves or {}) do
        if #times > 0 then
            local w = def and def.waves and def.waves[kind]
            waves[#waves + 1] = { label = w and w.label or kind, times = times }
        end
    end
    tsort(waves, function(a, b) return a.times[1] < b.times[1] end)
    local folds = {}
    if look and look.collapse then phases = Fold(phases, look.collapse, folds) end
    L.phases, L.waves, L.folds = phases, waves, folds
    tsort(mc.list, ByTime)
    L.marks = mc.list
end
function MK.Merge(a, b)
    local out = {}
    for i = 1, #a do out[#out + 1] = a[i] end
    for i = 1, #b do
        local m = b[i]
        m.key = m.key or ("m" .. tostring(m.id or m.label))
        out[#out + 1] = m
    end
    tsort(out, ByTime)
    return out
end
local function RowNames(L, i)
    local all = L.fdAll and L.fdAll[i]
    if all then return all end
    local who = L.fdWho[i]
    return who and { who } or {}
end
local function MassRez(L)
    local out = {}
    local i = 1
    while i <= L.nf do
        local id = L.fdKind[i] == "death" and type(L.fdIcon[i]) == "number" and L.fdIcon[i] or nil
        if id then
            local j, n = i, 1
            local idx = { i }
            for k = i + 1, L.nf do
                if L.fdT[k] - L.fdT[i] > MASS_GAP then break end
                if L.fdKind[k] == "death" and L.fdIcon[k] == id then
                    n = n + 1
                    idx[#idx + 1] = k
                    j = k
                end
            end
            if n >= MASS then
                for k = 1, #idx do out[idx[k]] = true end
                i = j + 1
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return out
end
function MK.Lanes(L, laneOf)
    local lists = { {}, {}, {}, {} }
    if not L then return lists end
    local marks = L.marks or {}
    for i = 1, #marks do
        local mk = marks[i]
        mk.lane = 1
        lists[1][#lists[1] + 1] = mk
    end
    local n = L.nf or 0
    if n == 0 or not L.fdT then return lists end
    local D = ns.replayMarks.lanes
    local byId = {}
    for i = 1, #marks do
        local id = marks[i].id
        if id then
            local key = ns.SpellKey(id) or id
            byId[key] = byId[key] or {}
            byId[key][#byId[key] + 1] = marks[i]
        end
    end
    local mass = MassRez(L)
    local massAt = {}
    for i = 1, n do
        local kind, icon, t = L.fdKind[i], L.fdIcon[i], L.fdT[i]
        local id = type(icon) == "number" and icon > 0 and icon or nil
        if kind == "boss" and id and L.fdWho[i] then
            local list = byId[ns.SpellKey(id) or id]
            local best
            for k = 1, list and #list or 0 do
                if list[k].t <= t + 0.5 and t - list[k].t <= ATTACH then best = list[k] end
            end
            if best then
                local names = RowNames(L, i)
                for k = 1, #names do AddWho(best.who, names[k]) end
            end
        elseif id and mass[i] then
            local m = massAt[id]
            if m and t - m.t <= MASS_GAP then
                AddWho(m.who, L.fdWho[i])
            else
                m = { t = t, kind = "event", key = "r" .. id, id = id, n = 1, who = {}, text = L.fdText[i], lane = 1 }
                AddWho(m.who, L.fdWho[i])
                massAt[id] = m
                lists[1][#lists[1] + 1] = m
            end
        elseif (D.role[kind] or D.tank[kind]) and (kind ~= "death" or id) then
            local names = RowNames(L, i)
            local by = L.fdLane and L.fdLane[i] or L.fdWho[i]
            local lane = D.tank[kind] and 2 or laneOf(by)
            local list = lists[lane]
            list[#list + 1] = { t = t, kind = "event", key = kind .. (id or icon), id = id, text = L.fdText[i],
                                n = kind == "def" and max(1, #names) or 1, who = names, lane = lane, by = by or nil,
                                class = by and ns.Encounters.ClassOf(by) or nil }
        end
    end
    for lane = 1, #lists do tsort(lists[lane], ByTime) end
    return lists
end
local function ByX(a, b)
    if a.x0 ~= b.x0 then return a.x0 < b.x0 end
    return a.key < b.key
end
local function LastT(g)
    return g.items[#g.items].t
end
function MK.Scale(from, to, folds)
    local sc = { from = from, to = to, folds = {}, share = 0, rate = 0 }
    local folded = 0
    for _, f in ipairs(folds or {}) do
        local a, b = max(f.from, from), min(f.to, to)
        if b > a then
            sc.folds[#sc.folds + 1] = { from = a, to = b }
            folded = folded + b - a
        end
    end
    local n = #sc.folds
    sc.share = n > 0 and min(FOLD_SHARE, FOLD_MAX / n) or 0
    sc.rate = (1 - n * sc.share) / max(0.001, to - from - folded)
    return sc
end
function MK.Frac(sc, t)
    if t <= sc.from then return 0 end
    local f, at = 0, sc.from
    for _, d in ipairs(sc.folds) do
        if t < d.from then break end
        f = f + (d.from - at) * sc.rate
        if t < d.to then return min(1, f + (t - d.from) / (d.to - d.from) * sc.share) end
        f, at = f + sc.share, d.to
    end
    return min(1, f + (t - at) * sc.rate)
end
function MK.TimeAt(sc, x)
    local f, at = 0, sc.from
    for _, d in ipairs(sc.folds) do
        local f1 = f + (d.from - at) * sc.rate
        if x < f1 then return at + (x - f) / sc.rate end
        if x < f1 + sc.share then return d.to end
        f, at = f1 + sc.share, d.to
    end
    return min(sc.to, at + (x - f) / sc.rate)
end
function MK.Skip(folds, a, b)
    for _, d in ipairs(folds or {}) do
        if a < d.from and b >= d.from and b < d.to then return d.to end
    end
    return b
end
local function Group(marks, sc, width, win)
    local groups, open = {}, {}
    local again = ns.replayMarks.again
    for i = 1, #marks do
        local m = marks[i]
        local x = max(0, MK.Frac(sc, m.t) * width)
        local g = open[m.key]
        if g and x - g.x0 < win and m.t - LastT(g) <= again then
            g.items[#g.items + 1] = m
            g.n = g.n + m.n
        else
            g = { x0 = x, x = x, t = m.t, key = m.key, lead = m, items = { m }, n = m.n }
            open[m.key] = g
            groups[#groups + 1] = g
        end
    end
    tsort(groups, ByX)
    return groups
end
local function Place(groups, width, step, edge)
    local blocks = {}
    for i = 1, #groups do
        local b = { first = i, n = 1, sum = groups[i].x0 }
        while true do
            b.x = min(max(b.sum / b.n - (b.n - 1) * step / 2, 0), max(0, width - edge - (b.n - 1) * step))
            local prev = blocks[#blocks]
            if not (prev and prev.x + prev.n * step > b.x) then break end
            blocks[#blocks] = nil
            b = { first = prev.first, n = prev.n + b.n, sum = prev.sum + b.sum }
        end
        blocks[#blocks + 1] = b
    end
    local drift, wf, wn = 0, 1, 0
    for k = 1, #blocks do
        local b = blocks[k]
        for j = 0, b.n - 1 do
            local g = groups[b.first + j]
            g.x = b.x + j * step
            local d = abs(g.x - g.x0)
            if d > drift then drift, wf, wn = d, b.first, b.n end
        end
    end
    for k = 1, #blocks do
        local b = blocks[k]
        if b.n > 1 and b.x + (b.n - 1) * step > width - edge + 1e-6 then return math.huge, b.first, b.n end
    end
    return drift, wf, wn
end
local function Nearest(groups, lo, hi)
    local last, bi, bj, gap = {}, nil, nil, nil
    local again = ns.replayMarks.again
    for k = max(1, lo), min(#groups, hi) do
        local g = groups[k]
        local p = last[g.key]
        if p and g.t - LastT(groups[p]) <= again and (not gap or g.x0 - groups[p].x0 < gap) then
            bi, bj, gap = p, k, g.x0 - groups[p].x0
        end
        last[g.key] = k
    end
    return bi, bj
end
local function Closest(groups, lo, hi)
    local bi, gap
    for k = max(1, lo), min(#groups, hi) - 1 do
        local d = groups[k + 1].x0 - groups[k].x0
        if not gap or d < gap then bi, gap = k, d end
    end
    if not bi then return nil, nil end
    return bi, bi + 1
end
local function Join(g, h)
    for k = 1, #h.items do g.items[#g.items + 1] = h.items[k] end
    tsort(g.items, ByTime)
    local count, best = {}, nil
    for k = 1, #g.items do
        local mk = g.items[k]
        count[mk.key] = (count[mk.key] or 0) + mk.n
        if not best or count[mk.key] > count[best] then best = mk.key end
    end
    g.key, g.n, g.mixed = best, count[best], nil
    for key in pairs(count) do
        if key ~= best then g.mixed = true end
    end
    for k = 1, #g.items do
        if g.items[k].key == best then
            g.lead = g.items[k]
            break
        end
    end
end
function MK.Pack(marks, from, to, width, step, edge, sc)
    edge = edge or 0
    sc = sc or MK.Scale(from, to, nil)
    local inRange = {}
    for i = 1, #marks do
        if marks[i].t <= to then inRange[#inRange + 1] = marks[i] end
    end
    local groups = Group(inRange, sc, width, step)
    local drift, wf, wn = Place(groups, width, step, edge)
    while drift > step * DRIFT do
        local i, j = Nearest(groups, wf, wf + wn - 1)
        if not i then i, j = Nearest(groups, wf - wn, wf + 2 * wn) end
        if not i then i, j = Closest(groups, wf, wf + wn - 1) end
        if not i then break end
        Join(groups[i], groups[j])
        table.remove(groups, j)
        drift, wf, wn = Place(groups, width, step, edge)
    end
    return groups, drift
end
