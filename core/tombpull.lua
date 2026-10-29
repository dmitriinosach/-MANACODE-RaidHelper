local _, ns = ...
local floor = math.floor
local sqrt = math.sqrt
local tsort = table.sort
local concat = table.concat
local WIN = 1.5
local WAVE = 0.5
local HELD = 5
local MARGIN = 1
local POS_HOLD = 10
local POS_GAP = 2
local MAP_UNITS = 10000
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true }
local TP = {}
ns.TombPull = TP
function TP.Begin(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "pulled" then
            return { s = s, fight = fight, i = i, def = bd, beacon = ns.SpellKey(bd.spell), tomb = ns.SpellKey(bd.splash),
                     on = {}, off = {}, waves = {}, ends = {}, subs = SUBS }
        end
    end
    return nil
end
local function Carriers(st, ts)
    local out = {}
    for name, at in pairs(st.off) do
        if ts - at <= WIN and ts >= at then out[#out + 1] = name end
    end
    for name, at in pairs(st.on) do
        if ts - at >= HELD then out[#out + 1] = name end
    end
    tsort(out)
    return out
end
function TP.Feed(st, ts, sub, dstName, a1)
    if not (dstName and st.s.byName[dstName]) then return end
    local sk = ns.SpellKey(a1)
    if sk == st.beacon then
        if sub == "SPELL_AURA_APPLIED" then
            st.on[dstName] = ts
        else
            st.on[dstName] = nil
            st.off[dstName] = ts
        end
        st.s.spellIds[sk] = st.s.spellIds[sk] or tonumber(a1)
        return
    end
    if sk ~= st.tomb then return end
    if sub == "SPELL_AURA_REMOVED" then
        local list = st.ends[dstName] or {}
        st.ends[dstName] = list
        list[#list + 1] = ts
        return
    end
    if sub ~= "SPELL_AURA_APPLIED" then return end
    local w = st.waves[#st.waves]
    if not w or ts - w.t > WAVE then
        w = { t = ts, hit = {}, seen = {}, carriers = Carriers(st, ts) }
        st.waves[#st.waves + 1] = w
    end
    if not w.seen[dstName] then
        w.seen[dstName] = true
        w.hit[#w.hit + 1] = dstName
    end
end
local function Marks(st)
    if st.marks then return st.marks end
    local out = {}
    local segs = ns.Encounters.Segs(st.fight)
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do out[#out + 1] = m[k] end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    st.marks = out
    return out
end
local function Scale(st, t)
    local marks = Marks(st)
    local mark = marks[1]
    for i = 1, #marks do
        if marks[i].t <= t then mark = marks[i] else break end
    end
    if not mark then return nil, nil end
    local scale = ns.mapScale or {}
    local byArea = scale[mark.name or ""] or (ns.mapAreas and scale[ns.mapAreas[mark.area] or ""])
    local size = byArea and byArea[mark.level]
    if not size then return nil, nil end
    return size.w / MAP_UNITS, size.h / MAP_UNITS
end
local function Track(st, name)
    st.tracks = st.tracks or {}
    local tr = st.tracks[name]
    if tr then return tr end
    tr = { t = {}, x = {}, y = {} }
    local from, to = st.fight.from - 5, st.fight.to + 5
    local segs = ns.Encounters.Segs(st.fight)
    for i = 1, #segs do
        for ts, x, y in ns.Decode.Pos(segs[i], name, from, to) do
            if ts > to then break end
            if x > 0 or y > 0 then
                local n = #tr.t + 1
                tr.t[n], tr.x[n], tr.y[n] = ts, x, y
            end
        end
    end
    st.tracks[name] = tr
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
    local i = lo - 1
    if i >= 1 and t - tr.t[i] <= POS_HOLD then return tr.x[i], tr.y[i] end
    if lo <= n and tr.t[lo] - t <= POS_GAP then return tr.x[lo], tr.y[lo] end
    return nil, nil
end
local function Nearest(st, victim, carriers, t)
    local yw, yh = Scale(st, t)
    local vx, vy = Near(Track(st, victim), t)
    if not (yw and vx) then return nil end
    local best, bestD, second
    for i = 1, #carriers do
        local cx, cy = Near(Track(st, carriers[i]), t)
        if not cx then return nil end
        local dx, dy = (cx - vx) * yw, (cy - vy) * yh
        local d = sqrt(dx * dx + dy * dy)
        if not bestD or d < bestD then
            second, best, bestD = bestD, carriers[i], d
        elseif not second or d < second then
            second = d
        end
    end
    if second and second - bestD < MARGIN then return nil end
    return best
end
local function Dist(st, a, b, t)
    local yw, yh = Scale(st, t)
    local ax, ay = Near(Track(st, a), t)
    local bx, by = Near(Track(st, b), t)
    if not (yw and ax and bx) then return nil end
    local dx, dy = (ax - bx) * yw, (ay - by) * yh
    return sqrt(dx * dx + dy * dy)
end
local function DiedIn(st, wave)
    local after = st.def.after or 0
    for k = 1, #wave.hit do
        local name = wave.hit[k]
        local till = wave.t
        local ends = st.ends[name] or {}
        for e = 1, #ends do
            if ends[e] >= wave.t then
                till = ends[e]
                break
            end
        end
        local d = st.s.byName[name].deathInfo or {}
        for e = 1, #d do
            if d[e].t >= wave.t and d[e].t <= till + after then return true end
        end
    end
    return false
end
local function Pairs(st, wave)
    local out, hit = {}, {}
    for k = 1, #wave.hit do hit[wave.hit[k]] = true end
    local r = st.def.radius or 0
    for a = 1, #wave.carriers do
        for b = a + 1, #wave.carriers do
            local A, B = wave.carriers[a], wave.carriers[b]
            local d = hit[A] and hit[B] and Dist(st, A, B, wave.t)
            if d and d <= r then
                out[A], out[B] = out[A] or {}, out[B] or {}
                out[A][#out[A] + 1], out[B][#out[B] + 1] = B, A
            end
        end
    end
    return out
end
local function Judge(st, wave)
    local s, i = st.s, st.i
    local carrier = {}
    for k = 1, #wave.carriers do carrier[wave.carriers[k]] = true end
    local by, order = {}, {}
    local function Add(who, v)
        if not by[who] then
            by[who] = {}
            order[#order + 1] = who
        end
        by[who][#by[who] + 1] = v
    end
    for k = 1, #wave.hit do
        local v = wave.hit[k]
        if not carrier[v] then
            local who = #wave.carriers == 1 and wave.carriers[1] or nil
            if #wave.carriers > 1 then who = Nearest(st, v, wave.carriers, wave.t) end
            if who and s.byName[who] then Add(who, v) end
        end
    end
    local died = DiedIn(st, wave)
    local free = {}
    for k = 1, #order do free[order[k]] = #by[order[k]] end
    if died then
        for who, list in pairs(Pairs(st, wave)) do
            if s.byName[who] then
                for v = 1, #list do Add(who, list[v]) end
            end
        end
    end
    for k = 1, #order do
        local who = order[k]
        local b = s.byName[who].badges[i]
        local grade = (not died and (free[who] or 0) >= (st.def.red or math.huge)) and "red" or "yellow"
        local n = b.n + 1
        b.n = n
        b.times[n] = wave.t - s.from
        b.whom = b.whom or {}
        b.whom[n] = concat(by[who], ", ")
        b.grades = b.grades or {}
        b.grades[n] = grade
        for v = 1, #by[who] do b.notes[#b.notes + 1] = by[who][v] end
        if grade == "red" or not b.grade then b.grade = grade end
    end
end
function TP.Finish(st)
    for w = 1, #st.waves do Judge(st, st.waves[w]) end
    st.s.icons[st.i] = st.s.icons[st.i] or st.s.spellIds[st.beacon]
    st.tracks, st.marks = nil, nil
end
function TP.Of(s, p)
    local out = {}
    for i = 1, #s.badges do
        if s.badges[i].kind == "pulled" then
            local b = p.badges[i]
            for k = 1, #((b and b.times) or {}) do
                out[#out + 1] = { t = s.from + b.times[k], whom = b.whom and b.whom[k] or nil,
                                  grade = b.grades and b.grades[k] or "yellow" }
            end
        end
    end
    return out
end
