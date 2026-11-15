local _, ns = ...
local band = bit.band
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local tsort = table.sort
local F_HOSTILE = ns.F.HOSTILE
local F_PLAYER = ns.F.PLAYER
local PRE = 20
local PRE_BACK = 60
local PRE_MIN = 5
local MELEE_YD = 8
local HIT_HOLD = 1
local SPOT_HOLD = 1
local POS_HOLD = 1.5
local POS_GAP = 1
local EDGE = 1.25
local LEAD = 10
local WENT = 2
local WENT_MIN = 1000
local PEERS_MIN = 3
local PEER_FREE = 0.5
local REZ_HOLD = 2
local NONE = {}
local DMG = { SWING_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true }
local DIRECT = { SWING_DAMAGE = true, SPELL_DAMAGE = true }
local BUFFS = { [2825] = true, [32182] = true, [10060] = true, [57933] = true, [49016] = true }
local ONLY = { ov = "g", gv = "r" }
local PINNED = { gt = true, rt = true }
local OozeFair = {}
ns.OozeFair = OozeFair
function OozeFair.Begin(s, fight, b)
    if not (b.def.green and b.def.red) then return nil end
    local kinds = { [ns.NpcKeyOf(b.def.green)] = "g", [ns.NpcKeyOf(b.def.red)] = "r" }
    return { s = s, fight = fight, b = b, from = fight.from, to = fight.to, kinds = kinds,
             oz = {}, order = {}, dmg = {}, tgt = {}, casts = {}, buf = {}, dead = {}, gone = {} }
end
local function Ooze(st, guid, k, ts)
    local o = st.oz[guid]
    if not o then
        o = { guid = guid, k = k, a = ts, z = st.to, by = {}, hits = {}, spot = {}, taken = {} }
        st.oz[guid] = o
        st.order[#st.order + 1] = guid
    end
    return o
end
local function Bump(t, who, sec, v)
    local r = t[who]
    if not r then
        r = {}
        t[who] = r
    end
    r[sec] = (r[sec] or 0) + v
end
local function Rise(st, who, ts)
    local w = st.dead[who]
    local last = w and w[#w]
    if last and not last.z and ts - last.a > REZ_HOLD then last.z = ts end
end
function OozeFair.Feed(st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a4, who, srcKey, dstKey)
    if ts < st.from or ts > st.to then return end
    local sec = floor(ts - st.from)
    local byName = st.s.byName
    local sk2 = srcKey and st.kinds[srcKey]
    local dk = dstKey and st.kinds[dstKey]
    if sub == "UNIT_DIED" then
        if dk then
            local o = Ooze(st, dstGUID, dk, ts)
            o.z, o.died = ts, true
        elseif dstName and byName[dstName] then
            local w = st.dead[dstName]
            if not w then
                w = {}
                st.dead[dstName] = w
            end
            if not w[#w] or w[#w].z then w[#w + 1] = { a = ts } end
        end
        return
    end
    if sk2 then Ooze(st, srcGUID, sk2, ts) end
    if dk and DMG[sub] then
        local o = Ooze(st, dstGUID, dk, ts)
        o.taken[sec] = (o.taken[sec] or 0) + (tonumber(sub == "SWING_DAMAGE" and a1 or a4) or 0)
    end
    if DMG[sub] and who and byName[who] and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
        local amount = tonumber(sub == "SWING_DAMAGE" and a1 or a4) or 0
        if sub == "SWING_DAMAGE" and srcName == who then Rise(st, who, ts) end
        Bump(st.dmg, who, sec, amount)
        local by = st.tgt[who]
        if not by then
            by = {}
            st.tgt[who] = by
        end
        local at = by[sec]
        if not at then
            at = {}
            by[sec] = at
        end
        local key = dk and dstGUID or dstName or "?"
        at[key] = (at[key] or 0) + amount
        if dk then
            local o = Ooze(st, dstGUID, dk, ts)
            o.by[who] = (o.by[who] or 0) + amount
            if DIRECT[sub] and srcName == who then
                local set = o.hits[sec]
                if not set then
                    set = {}
                    o.hits[sec] = set
                end
                set[who] = true
            end
        end
        return
    end
    if dk then Ooze(st, dstGUID, dk, ts) end
    if sub == "SPELL_CAST_SUCCESS" and who and srcName == who and srcFlags and band(srcFlags, F_PLAYER) > 0
        and byName[who] then
        Rise(st, who, ts)
        Bump(st.casts, who, sec, 1)
        return
    end
    if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REMOVED" then return end
    local id = tonumber(a1)
    if not (id and BUFFS[id] and dstName and byName[dstName]) then return end
    local w = st.buf[dstName]
    if not w then
        w = {}
        st.buf[dstName] = w
    end
    if sub == "SPELL_AURA_APPLIED" then
        w[#w + 1] = { ts, st.to }
    elseif w[#w] then
        w[#w][2] = ts
    end
end
local function Track(fight, name)
    local tr = { t = {}, x = {}, y = {} }
    local from, to = fight.from - 5, fight.to + 5
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        for ts, x, y in ns.Decode.Pos(segs[i], name, from, to) do
            if ts > to then break end
            if x > 0 or y > 0 then
                local n = #tr.t + 1
                tr.t[n], tr.x[n], tr.y[n] = ts, x, y
            end
        end
    end
    return tr
end
local function Places(fight)
    local marks = ns.MapPos.Marks(fight)
    local tracks = {}
    return function(name, t)
        local tr = tracks[name]
        if not tr then
            tr = Track(fight, name)
            tracks[name] = tr
        end
        local x, y = ns.MapPos.Near(tr, t, POS_HOLD, POS_GAP)
        if not x then return nil, nil end
        local yw, yh = ns.MapPos.Scale(marks, t)
        if not yw then return nil, nil end
        return x * yw, y * yh
    end
end
local function In(w, t)
    for i = 1, #(w or {}) do
        if t >= w[i][1] and t < w[i][2] then return true end
    end
    return false
end
local function DeadAt(w, t)
    for i = 1, #(w or {}) do
        if t >= w[i].a and (not w[i].z or t < w[i].z) then return true end
    end
    return false
end
local function Gone(w, from, to)
    if not w then return NONE end
    local set = {}
    for i = 1, #w do
        for sec = floor(w[i].a - from), ceil((w[i].z or to + 1) - from) - 1 do set[sec] = true end
    end
    return set
end
local function Allowed(eps, k, t)
    for i = 1, #(eps or {}) do
        local e = eps[i]
        local only = ONLY[e.k]
        if only and only ~= k and t >= e.a and t <= (e.z or t) then return false end
    end
    return true
end
local function Only(eps, a, z)
    local best, top = nil, 0
    for i = 1, #(eps or {}) do
        local e = eps[i]
        local span = ONLY[e.k] and min(z, e.z or z) - max(a, e.a) or 0
        if span > top then best, top = e, span end
    end
    if not best then return nil, nil, nil end
    local ea, ez = floor(best.a + 0.5), floor((best.z or z) + 0.5)
    return ONLY[best.k], ea > a + 1 and ea or nil, ez < z - 1 and ez or nil
end
local function Pinned(eps, t)
    for i = 1, #(eps or {}) do
        local e = eps[i]
        if PINNED[e.k] and t >= e.a and t <= (e.z or t) then return true end
    end
    return false
end
local function Stunned(p, t)
    local list = p.held
    for i = 1, #(list or {}) do
        local e = list[i]
        if e.k == "stun" and t >= e.t and t <= e.to then return true end
    end
    return false
end
local function Median(list)
    tsort(list)
    local n = #list
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return (list[n / 2] + list[n / 2 + 1]) / 2
end
local function Spot(o, sec, melee, Pos, at)
    local sp = o.spot[sec]
    if sp == nil then
        local xs, ys, seen = {}, {}, {}
        for d = -SPOT_HOLD, SPOT_HOLD do
            for name in pairs(o.hits[sec + d] or {}) do
                if melee[name] and not seen[name] then
                    seen[name] = true
                    local x, y = Pos(name, at)
                    if x then xs[#xs + 1], ys[#ys + 1] = x, y end
                end
            end
        end
        sp = #xs > 0 and { Median(xs), Median(ys) } or false
        o.spot[sec] = sp
    end
    if not sp then return nil, nil end
    return sp[1], sp[2]
end
function OozeFair.Rate(c, base)
    local v = max(c.pre or 0, c.dur or 0)
    return v > 0 and v or (base or 0)
end
function OozeFair.Window(near, peers, free)
    if #peers < PEERS_MIN then return min(near, free), nil end
    local med = floor(Median(peers) + 0.5)
    return min(max(near, med), free), med
end
local function Cell(st, p, o, melee)
    local from, name = st.from, p.name
    local dmg, casts, buf = st.dmg[name] or {}, st.casts[name] or {}, st.buf[name]
    local dead, gone = st.dead[name], st.gone[name] or NONE
    local last = dead and dead[#dead]
    local eps = st.b.eps and st.b.eps[name]
    local c = { on = floor((o.by[name] or 0) + 0.5), n = 0, reach = 0, life = 0, dur = 0, cut = { v = 0, s = 0, d = 0 } }
    local a0 = floor(o.a - from)
    local got, sum, sec = 0, 0, a0 - 1
    while got < PRE and sec >= 0 and sec >= a0 - PRE_BACK do
        local t = from + sec + 0.5
        if not DeadAt(dead, t) then
            if In(buf, t) then
                c.buf = true
            else
                got, sum = got + 1, sum + (dmg[sec] or 0)
            end
        end
        sec = sec - 1
    end
    c.pre = got >= PRE_MIN and floor(sum / got + 0.5) or nil
    local near, free = {}, {}
    local dsum = 0
    for t = a0, floor(o.z - from) - 1 do
        local why
        if gone[t] then
            why = t > a0 and "d"
        else
            c.life = c.life + 1
            dsum = dsum + (dmg[t] or 0)
            c.n = c.n + (casts[t] or 0)
            why = t > a0 and (not Allowed(eps, o.k, t + 0.5) and "v" or Stunned(p, t + 0.5) and "s" or "ok")
        end
        if why == "v" or why == "s" or why == "d" then
            c.cut[why] = c.cut[why] + 1
        elseif why then
            if not melee then
                free[t] = true
            else
                local hit = o.hits[t] and o.hits[t][name] or o.hits[t - HIT_HOLD] and o.hits[t - HIT_HOLD][name]
                if not hit then
                    local at = from + t + 0.5
                    local mx, my = st.Pos(name, at)
                    local ox, oy = Spot(o, t, melee, st.Pos, at)
                    hit = mx and ox and sqrt((mx - ox) ^ 2 + (my - oy) ^ 2) <= MELEE_YD
                end
                if hit then near[t] = true end
                if hit or not Pinned(eps, t + 0.5) then free[t] = true end
            end
        end
    end
    c.dur = c.life > 0 and floor(dsum / c.life + 0.5) or 0
    c.only, c.vfrom, c.vto = Only(eps, a0, floor(min(o.z, last and not last.z and last.a or st.to) - from))
    return c, near, free
end
local function Count(set, a, z)
    local n = 0
    for t = a, z do
        if set[t] then n = n + 1 end
    end
    return n
end
local function Pick(w, crowd, a, z)
    local sel, rest = {}, {}
    for t = a, z do
        if w.near[t] then
            sel[t] = true
        elseif w.free[t] then
            rest[#rest + 1] = t
        end
    end
    tsort(rest, function(x, y)
        local cx, cy = crowd[x] or 0, crowd[y] or 0
        if cx ~= cy then return cx > cy end
        return x < y
    end)
    for i = 1, min(#rest, w.c.reach - w.c.near) do sel[rest[i]] = true end
    return sel
end
local function Measure(st, o, j, list, melee)
    local a, z = floor(o.a - st.from), floor(o.z - st.from)
    local crowd = {}
    for i = 1, #list do
        local e = list[i]
        local c, near, free = Cell(st, e.p, o, e.m and melee or nil)
        c.reach = Count(free, a, z)
        e.w[j] = { c = c, near = near, free = free, cap = c.reach }
        e.row.c[j] = c
        if e.m then
            c.near = Count(near, a, z)
            for t = a, z do
                if near[t] then crowd[t] = (crowd[t] or 0) + 1 end
            end
        end
    end
    for i = 1, #list do
        local e = list[i]
        if e.m then
            local peers = {}
            for k = 1, #list do
                local w = list[k].w[j]
                if k ~= i and list[k].m and w.cap >= (z - a - 1) * PEER_FREE then peers[#peers + 1] = w.c.near end
            end
            local w = e.w[j]
            w.c.reach, w.c.med = OozeFair.Window(w.c.near, peers, w.cap)
            w.sel = Pick(w, crowd, a, z)
        end
    end
end
local function Taken(o, a, z)
    local n = 0
    for t = a, z do n = n + (o.taken[t] or 0) end
    return n
end
local function Health(st, oz)
    local top, got = {}, {}
    for j = 1, #oz do
        local o = oz[j]
        got[j] = Taken(o, floor(o.a - st.from), floor(o.z - st.from))
        if o.died then top[o.k] = max(top[o.k] or 0, got[j]) end
    end
    local out = {}
    for j = 1, #oz do out[j] = oz[j].died and got[j] or max(top[oz[j].k] or 0, got[j]) end
    return out
end
function OozeFair.With(sec, rate, hp, life, on, died)
    if not died or hp <= 0 or life <= 0 then return sec end
    local v = hp / life
    local add = rate - on / life
    if add <= 0 then return sec end
    return sec * v / (v + add)
end
local function Single(tgt, a, z, gone)
    local sum, n = 0, 0
    for t = a, z do
        if not gone[t] then
            local top = 0
            for _, v in pairs(tgt[t] or {}) do
                if v > top then top = v end
            end
            sum, n = sum + top, n + 1
        end
    end
    return n > 0 and sum / n or 0
end
local function Went(st, w, guid)
    local by = {}
    for key, v in pairs(w or {}) do
        if key ~= guid then
            local o = st.oz[key]
            local n = o and ("#" .. o.k) or key
            by[n] = (by[n] or 0) + v
        end
    end
    local list = {}
    for n, v in pairs(by) do
        if v >= WENT_MIN then list[#list + 1] = { n = n, v = floor(v + 0.5) } end
    end
    tsort(list, function(x, y)
        if x.v ~= y.v then return x.v > y.v end
        return x.n < y.n
    end)
    for i = #list, WENT + 1, -1 do list[i] = nil end
    return #list > 0 and list or nil
end
local function Cuts(c, span, busy)
    local v, s, d = c.cut.v, c.cut.s, c.cut.d
    local n = span - c.sec - d - v - s - busy
    local cut = { v = v > 0 and v or nil, s = s > 0 and s or nil, o = busy > 0 and busy or nil, n = n > 0 and n or nil,
                  d = d > 0 and d or nil }
    return next(cut) and cut or nil
end
local function BySpan(x, y)
    if x.a ~= y.a then return x.a < y.a end
    return x.k < y.k
end
local function Tape(b, name, dur)
    local eps = b.eps and b.eps[name]
    local var, tg = {}, {}
    for i = 1, #(eps or {}) do
        local e = eps[i]
        local a, z = floor(e.a + 0.5), floor(min(e.z or dur, dur) + 0.5)
        if ONLY[e.k] then
            var[#var + 1] = { k = ONLY[e.k], id = b.ids and b.ids[e.k] or nil, a = a, z = z }
        elseif PINNED[e.k] then
            tg[#tg + 1] = { k = e.k == "gt" and "g" or "r", a = a, z = z }
        end
    end
    tsort(var, BySpan)
    tsort(tg, BySpan)
    return var[1] and var or nil, tg[1] and tg or nil
end
function OozeFair.Finish(st, s)
    local from, b = st.from, st.b
    local oz = {}
    for i = 1, #st.order do
        local o = st.oz[st.order[i]]
        if o.z - o.a >= 2 then oz[#oz + 1] = o end
    end
    tsort(oz, function(x, y)
        if x.a ~= y.a then return x.a < y.a end
        return x.guid < y.guid
    end)
    if #oz == 0 then return end
    st.Pos = st.Pos or Places(st.fight)
    local melee, list = {}, {}
    for i = 1, #s.players do
        local p = s.players[i]
        local m = ns.IsMelee(p) == true
        if m then melee[p.name] = true end
        if p.role == "dps" then
            list[#list + 1] = { p = p, m = m, w = {}, row = { m = m or nil, pot = 0, c = {} } }
            st.gone[p.name] = Gone(st.dead[p.name], from, st.to)
        end
    end
    for j = 1, #oz do Measure(st, oz[j], j, list, melee) end
    local hp = Health(st, oz)
    for i = 1, #list do
        local e = list[i]
        local name = e.p.name
        local secs, went, busy = {}, {}, {}
        local tgt = st.tgt[name] or {}
        local gone, fin = st.gone[name], floor(st.to - from)
        for t = floor(oz[1].a - from), fin - 1 do
            local got = false
            for j = 1, #oz do
                if (e.w[j].sel or e.w[j].free)[t] then
                    if got then
                        busy[j] = (busy[j] or 0) + 1
                    else
                        got = true
                        secs[j] = (secs[j] or 0) + 1
                        local w = went[j] or {}
                        went[j] = w
                        for key, v in pairs(tgt[t] or {}) do w[key] = (w[key] or 0) + v end
                    end
                end
            end
        end
        local floorRate = Single(tgt, 0, fin - 1, gone)
        for j = 1, #oz do
            local c, o = e.row.c[j], oz[j]
            c.can, c.sec = 0, secs[j] or 0
            local a0 = floor(o.a - from)
            c.cut = Cuts(c, floor(o.z - from) - a0 - 1, busy[j] or 0)
            if c.sec > 0 then
                c.rate = floor(max(Single(tgt, max(0, a0 - LEAD), floor(o.z - from) - 1, gone), floorRate) + 0.5)
                c.went = Went(st, went[j], o.guid)
                local with = floor(OozeFair.With(c.sec, c.rate, hp[j], o.z - o.a, c.on, o.died) + 0.5)
                c.with = with < c.sec and with or nil
                c.can = floor(max(c.rate * (c.with or c.sec), c.on) + 0.5)
            end
        end
    end
    local out, by = {}, {}
    for j = 1, #oz do
        local o = oz[j]
        out[j] = { k = o.k, a = floor(o.a - from + 0.5), z = floor(o.z - from + 0.5), died = o.died or nil }
    end
    for i = 1, #list do
        local e = list[i]
        local pot = 0
        for j = 1, #oz do pot = pot + (e.row.c[j].can or 0) end
        e.row.pot = pot
        local dead = st.dead[e.p.name]
        for k = 1, #(dead or {}) do
            e.row.dead = e.row.dead or {}
            e.row.dead[k] = { a = floor(dead[k].a - from + 0.5), z = dead[k].z and floor(dead[k].z - from + 0.5) or nil }
        end
        e.row.var, e.row.tg = Tape(b, e.p.name, floor(st.to - from + 0.5))
        by[e.p.name] = e.row
    end
    b.fair = { oz = out, by = by }
end
function OozeFair.Of(s, name)
    for i = 1, #(s.blocks or {}) do
        local b = s.blocks[i]
        if b.def and b.def.kind == "oozes" and b.fair then return b.fair.by[name], b.fair end
    end
    return nil, nil
end
function OozeFair.Verdict(row, need)
    if row.pot < need then return "no" end
    if row.pot < need * EDGE then return "edge" end
    return "yes"
end
