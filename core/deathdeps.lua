local _, ns = ...
local format = string.format
local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs
local tsort = table.sort
local MELEE = "#melee"
local MAP_UNITS = 10000
local OPEN_MAX = 60
local SAME = 0.1
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_DISPEL = true,
               SPELL_CAST_SUCCESS = true, SWING_DAMAGE = true, SWING_MISSED = true }
local DD = {}
ns.DeathDeps = DD
local function Set(list)
    local out = {}
    for i = 1, #(list or {}) do out[ns.SpellKey(list[i]) or list[i]] = true end
    return out
end
local function SetN(list)
    local out = {}
    for i = 1, #(list or {}) do out[ns.NpcKeyOf(list[i]) or list[i]] = true end
    return out
end
function DD.Begin(fight, def, s)
    local dd = def.deps or {}
    local w = { s = s, def = dd, subs = SUBS, debuffs = {}, auras = {}, cured = {}, srcs = {}, swings = {},
                tanked = SetN(dd.tanked), tankHits = Set(dd.tankHits), mechs = {} }
    for i = 1, #(dd.dispel or {}) do w.debuffs[ns.SpellKey(dd.dispel[i].spell)] = dd.dispel[i] end
    for i = 1, #(dd.mechs or {}) do
        local m = dd.mechs[i]
        w.mechs[i] = { def = m, spells = Set(m.spells), srcs = SetN(m.srcs) }
        for k = 1, #(m.srcs or {}) do w.srcs[ns.NpcKeyOf(m.srcs[k])] = true end
    end
    return w
end
local function Mark(w, who, spell, ts, on)
    local mine = w.auras[who] or {}
    w.auras[who] = mine
    local list = mine[spell] or {}
    mine[spell] = list
    local n = #list
    local open = n > 0 and list[n] == false and ts - list[n - 1] <= (w.debuffs[spell].dur or OPEN_MAX)
    if on then
        if not open then list[n + 1], list[n + 2] = ts, false end
    elseif open then
        list[n] = ts
    end
end
function DD.Feed(w, ts, sub, srcKey, srcName, dstName, a1, sk, a4)
    local byName = w.s.byName
    if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
        if not (srcKey and w.srcs[srcKey] and dstName and byName[dstName]) then return end
        local by = w.swings[srcKey] or {}
        w.swings[srcKey] = by
        by[dstName] = (by[dstName] or 0) + 1
        return
    end
    if sub == "SPELL_DISPEL" then
        local xk = ns.SpellKey(a4)
        if not (xk and w.debuffs[xk]) then return end
        if srcName and byName[srcName] then
            local by = w.cured[xk] or {}
            w.cured[xk] = by
            by[srcName] = (by[srcName] or 0) + 1
        end
        if dstName and byName[dstName] then Mark(w, dstName, xk, ts, false) end
        return
    end
    if not (sk and w.debuffs[sk] and dstName and byName[dstName]) then return end
    if sub == "SPELL_CAST_SUCCESS" and srcName and byName[srcName] then return end
    w.s.spellIds[sk] = w.s.spellIds[sk] or tonumber(a1)
    Mark(w, dstName, sk, ts, sub ~= "SPELL_AURA_REMOVED")
end
local function Marks(w, fight)
    if w.marks then return w.marks end
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        if ns.Store.IsNew(segs[i]) then
            local m = ns.Decode.Maps(segs[i])
            for k = 1, #m do out[#out + 1] = m[k] end
        end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    w.marks = out
    return out
end
local function Scale(w, fight, t)
    local marks = Marks(w, fight)
    local mark
    for i = 1, #marks do
        if marks[i].t <= t then mark = marks[i] else break end
    end
    if not mark then mark = marks[1] end
    if not mark then return nil, nil end
    local scale = ns.mapScale or {}
    local byArea = scale[mark.name or ""] or (ns.mapAreas and scale[ns.mapAreas[mark.area] or ""])
    local size = byArea and byArea[mark.level]
    if not size then return nil, nil end
    return size.w / MAP_UNITS, size.h / MAP_UNITS
end
local function Track(w, fight, name)
    w.tracks = w.tracks or {}
    local tr = w.tracks[name]
    if tr then return tr end
    tr = { t = {}, x = {}, y = {} }
    local segs = ns.Encounters.Segs(fight)
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
    w.tracks[name] = tr
    return tr
end
local function Near(tr, t)
    local n = #tr.t
    if n == 0 then return nil, nil end
    local lo, hi = 1, n + 1
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if tr.t[mid] <= t then lo = mid + 1 else hi = mid end
    end
    local data = ns.deathDeps
    local i = lo - 1
    if i >= 1 and t - tr.t[i] <= data.posHold then return tr.x[i], tr.y[i] end
    if lo <= n and tr.t[lo] - t <= data.posGap then return tr.x[lo], tr.y[lo] end
    return nil, nil
end
local function Gap(w, fight, ta, tb, t)
    local ax, ay = Near(ta, t)
    local bx, by = Near(tb, t)
    local yw, yh = Scale(w, fight, t)
    if not (ax and bx and yw) then return nil end
    local dx, dy = (ax - bx) * yw, (ay - by) * yh
    return sqrt(dx * dx + dy * dy)
end
local function Closest(w, fight, a, b, t0, t1)
    local ta, tb = Track(w, fight, a), Track(w, fight, b)
    local best = nil
    local function Try(t)
        local d = Gap(w, fight, ta, tb, t)
        if d and (not best or d < best) then best = d end
    end
    Try(t0)
    Try(t1)
    for _, tr in ipairs({ ta, tb }) do
        for i = 1, #tr.t do
            local t = tr.t[i]
            if t > t1 then break end
            if t >= t0 then Try(t) end
        end
    end
    return best
end
local function AliveIn(q, t1)
    for k = 1, #q.deathInfo do
        local t = q.deathInfo[k].t
        if t <= t1 then return false end
    end
    return true
end
local function AppliedAt(w, name, spell, t)
    local list = w.auras[name] and w.auras[name][spell]
    local dur = w.debuffs[spell].dur or OPEN_MAX
    local on
    for i = 1, list and #list or 0, 2 do
        local off = list[i + 1]
        if off == false then off = list[i] + dur end
        if list[i] <= t and off >= t - 0.5 then on = list[i] end
    end
    return on
end
local function Dispel(w, fight, p, d)
    local k = d.killer
    local dk = k and k.key
    local deb = dk and w.debuffs[dk]
    if not deb then return nil end
    local on = AppliedAt(w, p.name, dk, d.t)
    local data = ns.deathDeps
    local hold = deb.hold or data.hold
    if not on or d.t - on < hold then return nil end
    local classes = data.by[deb.type] or {}
    local cured = w.cured[dk] or {}
    local best, bestRank, bestDist
    local players = w.s.players
    for i = 1, #players do
        local q = players[i]
        local rank = cured[q.name] and 1 or (q.role == "heal" and 2 or nil)
        if q ~= p and rank and classes[q.class or ""] and AliveIn(q, d.t) then
            local dist = Closest(w, fight, p.name, q.name, on + hold, d.t)
            if dist and dist <= data.range
                and (not best or rank < bestRank or (rank == bestRank and dist < bestDist)) then
                best, bestRank, bestDist = q.name, rank, dist
            end
        end
    end
    return { kind = "dispel", by = best, spell = dk, held = floor((d.t - on) * 10 + 0.5) / 10,
             near = bestDist and floor(bestDist + 0.5) or nil }
end
local function IsBoss(fight, key)
    return ns.IsBossKey(fight, key)
end
local function HitBy(d, src)
    for i = 1, #(d.recent or {}) do
        if d.recent[i].src == src then return true end
    end
    return false
end
local function Tank(w, fight, list, p, d)
    local k = d.killer
    if p.role == "tank" or not k.src or w.s.byName[k.src] then return nil end
    if not ((k.srcKey and w.tanked[k.srcKey]) or IsBoss(fight, k.srcKey)) then return nil end
    if k.key ~= MELEE and not w.tankHits[k.key or ""] then return nil end
    local best
    for i = 1, #list do
        local e = list[i]
        local td = e.d
        if e.p ~= p and e.p.role == "tank" and not td.tail and td.t < k.t and d.t - td.t <= ns.deathDeps.tank
            and HitBy(td, k.src) and (not best or td.t > best.d.t) then
            best = e
        end
    end
    if not best then return nil end
    return { kind = "tank", by = best.p.name, t = best.d.t, src = k.src }
end
local function Holder(w, p, d, srcs)
    local best, most = nil, 0
    local players = w.s.players
    for i = 1, #players do
        local q = players[i]
        if q ~= p and q.role == "tank" and AliveIn(q, d.t) then
            local n = 0
            for k = 1, #srcs do n = n + ((w.swings[ns.NpcKeyOf(srcs[k])] or {})[q.name] or 0) end
            if n > most then best, most = q.name, n end
        end
    end
    return best
end
local function Mech(w, p, d)
    local k = d.killer
    for i = 1, #w.mechs do
        local m = w.mechs[i]
        local def = m.def
        local hit = (k.key and m.spells[k.key]) or (k.srcKey and m.srcs[k.srcKey] and (not def.melee or k.key == MELEE))
        if hit and (not def.ride or (ns.Summary.Unseated and ns.Summary.Unseated(w.s, p, d.t, def.ride))) then
            local by = def.by == "tank" and Holder(w, p, d, def.srcs or {}) or nil
            return { kind = "mech", key = def.key, text = def.text, by = by, src = k.src }
        end
    end
    return nil
end
local function Earlier(a, b)
    if a.d.t ~= b.d.t then return a.d.t < b.d.t end
    return a.p.name < b.p.name
end
local function Deaths(s)
    local list = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do list[#list + 1] = { p = p, d = p.deathInfo[k] } end
    end
    tsort(list, Earlier)
    return list
end
local function Pin(d, dep)
    d.dep = dep
    if not dep.by or dep.kind == "mc" then return end
    if d.grade == "red" then
        dep.weak = true
        return
    end
    d.grade, d.why, d.nogp = "green", "dep", true
    if dep.kind ~= "tank" then dep.gp = true end
end
function DD.Run(s, fight)
    local w = s.dd
    s.dd = nil
    local list = Deaths(s)
    for i = 1, #list do
        local e = list[i]
        local d = e.d
        if not d.tail then
            local dep
            if d.mc then
                dep = { kind = "mc", by = d.mc.by }
            elseif w and d.killer then
                dep = Dispel(w, fight, e.p, d) or Tank(w, fight, list, e.p, d) or Mech(w, e.p, d)
            end
            if dep then Pin(d, dep) end
        end
    end
end
local function Fits(dep, rule)
    if not rule then return true end
    if rule.dep and rule.dep ~= dep.kind then return false end
    if rule.mech and rule.mech ~= dep.key then return false end
    if rule.spells then
        for i = 1, #rule.spells do
            if ns.SpellKey(rule.spells[i]) == dep.spell then return true end
        end
        return false
    end
    return true
end
function DD.Caused(s, p, rule)
    local out = {}
    for i = 1, #s.players do
        local q = s.players[i]
        for k = 1, #q.deathInfo do
            local d = q.deathInfo[k]
            local dep = d.dep
            if dep and dep.gp and dep.by == p.name and not d.tail and Fits(dep, rule) then
                out[#out + 1] = { t = d.t, victim = q.name, dep = dep }
            end
        end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    return out
end
local function Dec(v)
    local s = format("%.1f", v):gsub("%.0$", "")
    return ns.Dec(s)
end
function DD.What(dep)
    local T = ns.T
    if dep.kind == "dispel" and dep.near then
        return format(T("sum.dd.dispelnear"), dep.spell and ns.SpellName(dep.spell) or "?", Dec(dep.held or 0), dep.near)
    end
    if dep.kind == "dispel" then
        return format(T("sum.dd.dispel"), dep.spell and ns.SpellName(dep.spell) or "?", Dec(dep.held or 0))
    end
    if dep.kind == "tank" then return format(T("sum.dd.tank"), dep.by or "?") end
    if dep.kind == "mc" then return format(T("sum.dg.mc"), dep.by or "?") end
    return T(dep.text or "sum.dd.m.none")
end
function DD.Text(d)
    local dep = d.dep
    local T = ns.T
    if not dep then return "" end
    if dep.kind == "tank" or dep.kind == "mc" then return DD.What(dep) end
    if dep.by and not dep.weak then return format(T("sum.dd.by"), dep.by, DD.What(dep)) end
    if dep.kind == "dispel" and not dep.by then
        return format(T("sum.dd.nodispel"), dep.spell and ns.SpellName(dep.spell) or "?", Dec(dep.held or 0))
    end
    if dep.weak then return format(T("sum.dd.weak"), dep.by or "?", DD.What(dep)) end
    return format(T("sum.dd.mech"), DD.What(dep))
end
local function DeathWhat(p, d)
    local k = d.killer
    local T = ns.T
    local what
    if not k then
        what = T("sum.dd.death.none")
    elseif k.spell == MELEE then
        what = format(T("sum.dd.death.melee"), k.src or "?")
    else
        what = format(T("sum.dd.death"), tostring(k.spell))
    end
    return p.role == "tank" and format(T("sum.dd.death.tank"), what) or what
end
function DD.FirstCause(s, fight, pens)
    if fight.killed then return nil end
    local list = Deaths(s)
    if #list == 0 then return nil end
    local lead = ns.deathDeps.lead
    local last = #list
    for i = 1, #list do
        if list[i].d.tail or list[i].d.mass then
            last = i
            break
        end
    end
    if not (list[last].d.tail or list[last].d.mass) and fight.to - list[last].d.t > ns.deathDeps.quiet then return nil end
    local first = last
    while first > 1 and list[first].d.t - list[first - 1].d.t <= lead do first = first - 1 end
    local lo, hi = list[first].d.t - lead, list[first].d.t + SAME
    local best
    local function Offer(t, who, text)
        if t and t >= lo and t <= hi and (not best or t < best.t) then best = { t = t, who = who, text = text } end
    end
    local names = {}
    for name in pairs(pens or {}) do names[#names + 1] = name end
    tsort(names)
    for n = 1, #names do
        local hits = pens[names[n]]
        for i = 1, #hits do
            for k = 1, #hits[i].events do
                Offer(hits[i].events[k].t, names[n], ns.Penalties.Reason(hits[i].rule))
            end
        end
    end
    for i = 1, last do
        local e = list[i]
        local d = e.d
        if not d.tail and d.grade == "red" then Offer(d.t, e.p.name, DeathWhat(e.p, d)) end
        if not d.tail and d.dep and d.dep.gp then Offer(d.t, d.dep.by, format(ns.T("sum.dd.caused"), e.p.name)) end
    end
    if not best then
        local e, n = list[first], 1
        for i = first + 1, #list do
            if list[i].d.t - list[first].d.t > SAME then break end
            n = n + 1
            if list[i].p.role == "tank" and e.p.role ~= "tank" then e = list[i] end
        end
        if n >= ns.Tune("waveMin") then
            best = { t = e.d.t, who = format(ns.T("sum.dd.wavewho"), e.p.name, n - 1),
                     text = format(ns.T("sum.dd.wave"), n) }
        else
            best = { t = e.d.t, who = e.p.name, text = DeathWhat(e.p, e.d) }
        end
    end
    return best
end
