local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local AIR = 2
local GROUP = 1
local HIT_FROM, HIT_TO = 31, 37
local LAND_FROM, LAND_TO = 20, 60
local LAND_LAG = 4
local DEFAULT = 33.2
local GRACE_LAND, GRACE_DEFAULT = 0.2, 0.3
local HALF = 0.5
local FLOOR_H = 0.02
local CROWD = 1.5
local CROWD_STEP = 0.1
local MANUAL = 1.5
local KEEP = 1
local ACTS = 8
local MELEE = 0
local DEATH_SHARE = 1 / 3
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_APPLIED_DOSE = true,
               SPELL_AURA_REMOVED = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
               SWING_DAMAGE = true, SWING_MISSED = true, DAMAGE_SHIELD = true }
local TB = {}
ns.TombBreak = TB
function TB.Begin(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "tombbreak" then
            return { s = s, fight = fight, i = i, def = bd, subs = SUBS, npc = ns.NpcKeyOf(bd.npc),
                     beacon = ns.SpellKey(bd.beacon), tombAura = ns.SpellKey(bd.spell), bomb = ns.SpellKey(bd.bomb),
                     beacons = {}, swings = {}, bombs = {}, freed = {}, tombs = {}, order = {}, tick = {} }
        end
    end
    return nil
end
function TB.Feed(st, ts, sub, srcGUID, srcName, who, dstGUID, dstName, srcBoss, a1, a2, a4, a5)
    local swing = sub == "SWING_DAMAGE" or sub == "SWING_MISSED"
    if srcBoss and swing then
        st.swings[#st.swings + 1] = ts
        return
    end
    local sk = (not swing) and ns.SpellKey(a1) or nil
    local byName = st.s.byName
    if sk and dstName and byName[dstName] then
        if sk == st.beacon and sub == "SPELL_AURA_APPLIED" then
            st.beacons[#st.beacons + 1] = ts
        elseif sk == st.tombAura and sub == "SPELL_AURA_REMOVED" then
            st.freed[#st.freed + 1] = { t = ts, who = dstName }
        elseif sk == st.bomb and sub == "SPELL_DAMAGE" then
            st.bombs[#st.bombs + 1] = { t = ts, who = dstName, dead = (tonumber(a5) or 0) > 0 }
        end
        return
    end
    local id = tonumber(a1) or 0
    if sub == "SPELL_PERIODIC_DAMAGE" and who and byName[who] and (st.def.dots or {})[id] then
        local key = who .. ":" .. id
        local v = st.tick[key] or { 0, 0 }
        st.tick[key] = v
        v[1], v[2] = v[1] + max(0, (tonumber(a4) or 0) - max(0, tonumber(a5) or 0)), v[2] + 1
    end
    if not (dstGUID and ns.NpcKey(dstGUID) == st.npc) then return end
    local tomb = st.tombs[dstGUID]
    if not tomb then
        tomb = { first = ts, ev = {} }
        st.tombs[dstGUID] = tomb
        st.order[#st.order + 1] = dstGUID
    end
    if sub == "SWING_MISSED" or sub == "SPELL_AURA_REMOVED" then return end
    local dmg = swing or sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE"
        or sub == "DAMAGE_SHIELD"
    local eff = 0
    if dmg then
        local amount = tonumber(swing and a1 or a4) or 0
        local over = tonumber(swing and a2 or a5) or 0
        eff = max(0, amount - max(0, over))
    end
    if not dmg and not (st.def.dots or {})[tonumber(a1) or 0] then return end
    tomb.ev[#tomb.ev + 1] = { t = ts, who = who and byName[who] and who or nil, id = swing and MELEE or (tonumber(a1) or 0),
                             per = sub == "SPELL_PERIODIC_DAMAGE", app = not dmg, eff = eff }
end
function TB.Died(st, ts, dstGUID)
    local tomb = dstGUID and st.tombs[dstGUID]
    if tomb then tomb.died = ts end
end
local function Groups(st)
    local out = {}
    for i = 1, #st.beacons do
        local t = st.beacons[i]
        local g = out[#out]
        if g and t - g.t < GROUP then g.n = g.n + 1 else out[#out + 1] = { t = t, n = 1 } end
    end
    return out
end
local function Bomb(st, g)
    local at, hits = nil, {}
    for i = 1, #st.bombs do
        local b = st.bombs[i]
        if b.t >= g.t + HIT_FROM and b.t <= g.t + HIT_TO then
            hits[#hits + 1] = b
            if not at or b.t > at then at = b.t end
        end
    end
    if at then return at, "hit", hits end
    for i = 1, #st.swings do
        local t = st.swings[i]
        if t > g.t + LAND_FROM and t < g.t + LAND_TO then return t - LAND_LAG, "land", hits end
    end
    return g.t + DEFAULT, "def", hits
end
local function Weight(h)
    if h >= HALF then return 0 end
    return HALF / max(h, FLOOR_H)
end
local function Ticks(st)
    local out, all, onTomb = {}, {}, {}
    for g = 1, #st.order do
        local ev = st.tombs[st.order[g]].ev
        for k = 1, #ev do
            local e = ev[k]
            if e.per and e.who and e.eff > 0 then
                local key = e.who .. ":" .. e.id
                local v = onTomb[key] or { 0, 0 }
                onTomb[key] = v
                v[1], v[2] = v[1] + e.eff, v[2] + 1
            end
        end
    end
    for key, v in pairs(st.tick) do
        local own = onTomb[key] or v
        out[key] = own[1] / own[2]
        local id = key:match(":([^:]+)$")
        local a = all[id] or { 0, 0 }
        all[id] = a
        a[1], a[2] = a[1] + own[1], a[2] + own[2]
    end
    for id, a in pairs(all) do out["*:" .. id] = a[1] / a[2] end
    return out
end
local function Charges(st, tomb, top, B, avg)
    local dots, series, link = st.def.dots or {}, st.def.series or {}, st.def.link or {}
    local hp, out, app, ser = top, {}, {}, {}
    for k = 1, #tomb.ev do
        local e = tomb.ev[k]
        local h = hp / top
        hp = hp - e.eff
        local who = e.who
        if who and who ~= tomb.prisoner then
            local key = who .. ":" .. e.id
            local d = dots[e.id]
            if e.app then
                if d then
                    local prev = app[key]
                    local iv = d[2]
                    local oldEnd = prev and prev.t + d[1] * iv or e.t
                    local n = 0
                    for i = 1, d[1] do
                        local tt = e.t + i * iv
                        if tt > oldEnd and tt <= B then n = n + 1 end
                    end
                    local tick = avg[key] or avg["*:" .. e.id] or 0
                    local pot = n * tick
                    if d[4] and e.t + d[1] * iv <= B then pot = pot + d[4] * tick end
                    local c = { who = who, id = e.id, t = e.t, h = h, pot = pot, mult = d[3] and 1 or MANUAL, dot = true }
                    out[#out + 1] = c
                    app[key] = c
                end
            elseif e.eff > 0 then
                local counted = e.per and app[key] ~= nil
                local owners = link[e.id]
                for o = 1, owners and #owners or 0 do
                    if app[who .. ":" .. owners[o]] then counted = true end
                end
                if not counted and series[e.id] then
                    local c = ser[key]
                    if not c or e.t - c.last > 2 then
                        c = { who = who, id = e.id, t = e.t, last = e.t, h = h, act = 0, mult = 1, dur = series[e.id] }
                        ser[key] = c
                        out[#out + 1] = c
                    end
                    c.act, c.last = c.act + e.eff, e.t
                elseif not counted then
                    out[#out + 1] = { who = who, id = e.id, t = e.t, h = h, pot = e.eff, mult = 1, direct = true }
                end
            end
        end
    end
    for i = 1, #out do
        local c = out[i]
        if c.dur then
            local rate = c.act / max(1, min(c.dur, tomb.died - c.t))
            c.pot = rate * max(0, min(c.dur, B - c.t))
        end
    end
    return out
end
local function Score(st, charges, top, B)
    local hitters = {}
    for i = 1, #charges do
        local c = charges[i]
        if (c.direct or c.dur) and c.h < HALF then hitters[#hitters + 1] = c end
    end
    local by = {}
    for i = 1, #charges do
        local c = charges[i]
        local w = Weight(c.h)
        if w > 0 and c.pot > 0 then
            local seen, n = {}, 0
            for k = 1, #hitters do
                local o = hitters[k]
                if not seen[o.who] and o.t >= c.t - CROWD and o.t <= c.t + CROWD then
                    seen[o.who] = true
                    n = n + 1
                end
            end
            local pot = min(c.pot, max(c.h * top, 1))
            local pts = w * c.mult * (1 + CROWD_STEP * max(0, n - 1)) * pot / top * 100
            local r = by[c.who] or { pts = 0, by = {}, acts = {} }
            by[c.who] = r
            r.pts = r.pts + pts
            local kind = c.dot and "dot" or (c.dur and "series") or nil
            local key = c.id .. ":" .. (kind or "")
            local a = r.by[key]
            if not a then
                a = { id = c.id, kind = kind, n = 0, pts = 0, h = c.h }
                r.by[key] = a
                r.acts[#r.acts + 1] = a
            end
            a.n, a.pts = a.n + 1, a.pts + pts
            if c.h < a.h then a.h = c.h end
        end
    end
    return by
end
local function ByPts(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    return a.id < b.id
end
local function Pack(acts, top)
    tsort(acts, ByPts)
    if #acts > ACTS then
        local rest = { id = -1, n = 0, pts = 0, h = 1 }
        for k = ACTS, #acts do
            local a = acts[k]
            rest.n, rest.pts = rest.n + a.n, rest.pts + a.pts
            if a.h < rest.h then rest.h = a.h end
            acts[k] = nil
        end
        acts[ACTS] = rest
    end
    for k = 1, #acts do
        local a = acts[k]
        a.hp = floor(a.h * top + 0.5)
        a.h = floor(a.h * 1000 + 0.5) / 1000
        a.pts = floor(a.pts * 10 + 0.5) / 10
    end
    return acts
end
function TB.Finish(st)
    local s, i = st.s, st.i
    local groups = Groups(st)
    local top
    for g = 1, #st.order do
        local tomb = st.tombs[st.order[g]]
        if tomb.died then
            local sum = 0
            for k = 1, #tomb.ev do sum = sum + tomb.ev[k].eff end
            if sum > 0 and (not top or sum < top) then top = sum end
        end
    end
    if not top or #groups == 0 then return end
    local avg = Ticks(st)
    local used = {}
    for g = 1, #st.order do
        local tomb = st.tombs[st.order[g]]
        local grp
        for k = 1, #groups do
            if groups[k].t <= tomb.first then grp = groups[k] end
        end
        if tomb.died and grp and grp.n >= AIR then
            local best, bestD
            for k = 1, #st.freed do
                local f = st.freed[k]
                local d = math.abs(f.t - tomb.died)
                if not used[k] and d < 0.3 and (not bestD or d < bestD) then best, bestD = k, d end
            end
            if best then
                used[best] = true
                tomb.prisoner = st.freed[best].who
            end
            local B, src, hits = Bomb(st, grp)
            local grace = src == "hit" and 0 or (src == "land" and GRACE_LAND or GRACE_DEFAULT)
            if tomb.died < B - grace then
                local dead, seen = {}, {}
                for k = 1, #hits do
                    local h = hits[k]
                    if h.dead and h.t >= tomb.died - 0.3 and not seen[h.who] then
                        seen[h.who] = true
                        dead[#dead + 1] = h.who
                    end
                end
                tsort(dead)
                local by = Score(st, Charges(st, tomb, top, B, avg), top, B)
                for who, r in pairs(by) do
                    local p = s.byName[who]
                    local b = p and p.badges[i]
                    if b and r.pts >= KEEP then
                        local n = b.n + 1
                        b.n = n
                        b.times[n] = tomb.died - s.from
                        b.notes[n] = tomb.prisoner or "?"
                        b.pts, b.dead, b.dn, b.before, b.src, b.acts = b.pts or {}, b.dead or {}, b.dn or {},
                            b.before or {}, b.src or {}, b.acts or {}
                        b.pts[n] = floor(r.pts * 10 + 0.5) / 10
                        b.dead[n] = #dead
                        b.dn[n] = concat(dead, ", ")
                        b.before[n] = floor((B - tomb.died) * 10 + 0.5) / 10
                        b.src[n] = src
                        b.acts[n] = Pack(r.acts, top)
                        s.icons[i] = s.icons[i] or tonumber(st.def.id)
                    end
                end
            end
        end
    end
end
function TB.Limit(def)
    local rule = ns.Penalties and def.limit and ns.Penalties.Get(def.limit)
    return rule and ns.Penalties.Threshold(rule) or 0
end
function TB.Shown(st, lim)
    local list, pts, deadly = {}, 0, {}
    for k = 1, st.n do
        local v = st.pts and st.pts[k] or 0
        list[#list + 1] = k
        pts = pts + v
        if (st.dead and st.dead[k] or 0) > 0 and v >= lim * DEATH_SHARE then deadly[#deadly + 1] = k end
    end
    if st.n == 0 or pts < lim then return {}, 0, nil, {} end
    return list, pts, #deadly > 0 and "yellow" or "green", deadly
end
function TB.StatOf(s, p)
    for i = 1, #s.badges do
        if s.badges[i].kind == "tombbreak" then
            local st = p.badges and p.badges[i]
            return st and st.n > 0 and st or nil, s.badges[i]
        end
    end
    return nil, nil
end
