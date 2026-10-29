local _, ns = ...
local floor = math.floor
local max = math.max
local sqrt = math.sqrt
local MAP_UNITS = 10000
local STEP = 1
local POS_HOLD = 1.5
local POS_GAP = 1
local MIN_PEERS = 3
local MIN_SAMPLES = 10
local ICON = "Interface\\Icons\\Ability_Hunter_RunningShot"
local Away = {}
ns.Away = Away
function Away.Begin(s, fight)
    local classes = ns.Penalties and ns.Penalties.Watch(fight.boss).away
    if not classes then return nil end
    for i = 1, #s.badges do
        if s.badges[i].kind == "away" then
            local set = {}
            for k = 1, #classes do set[classes[k]] = true end
            return { s = s, fight = fight, i = i, classes = set }
        end
    end
    return nil
end
local function Windows(st)
    local from, to = st.fight.from, st.fight.to
    local ph = st.s.phases
    local starts = ph and ph.waves and ph.waves.storm or {}
    local ends = ph and ph.ends and ph.ends.storm or {}
    local out, at = {}, from
    for k = 1, #starts do
        local a = from + starts[k]
        if a > at then out[#out + 1] = { at, a } end
        at = max(at, from + (ends[k] or (to - from)))
    end
    if to > at then out[#out + 1] = { at, to } end
    return out
end
local function Marks(fight)
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do out[#out + 1] = m[k] end
    end
    table.sort(out, function(a, b) return a.t < b.t end)
    return out
end
local function Scale(marks, t)
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
local function DiedAt(p)
    local d = p.deathInfo and p.deathInfo[1]
    return d and d.t or math.huge
end
function Away.Finish(st)
    local s, fight = st.s, st.fight
    local want = {}
    for i = 1, #s.players do
        local p = s.players[i]
        if st.classes[p.class or ""] then want[#want + 1] = p end
    end
    if #want == 0 then return end
    local marks = Marks(fight)
    local all = {}
    for i = 1, #s.players do
        local p = s.players[i]
        all[i] = { p = p, tr = Track(fight, p.name), dead = DiedAt(p) }
    end
    local dist = {}
    for k = 1, #want do dist[want[k].name] = { d = {}, peak = 0, peakT = 0, sum = 0 } end
    local wins = Windows(st)
    for w = 1, #wins do
        local t = wins[w][1]
        while t <= wins[w][2] do
            local yw, yh = Scale(marks, t)
            if yw then
                local sx, sy, n, at = 0, 0, 0, {}
                for i = 1, #all do
                    local a = all[i]
                    if t < a.dead then
                        local x, y = Near(a.tr, t)
                        if x then
                            sx, sy, n = sx + x * yw, sy + y * yh, n + 1
                            at[a.p.name] = { x * yw, y * yh }
                        end
                    end
                end
                for k = 1, #want do
                    local me = at[want[k].name]
                    if me and n - 1 >= MIN_PEERS then
                        local cx, cy = (sx - me[1]) / (n - 1), (sy - me[2]) / (n - 1)
                        local dx, dy = me[1] - cx, me[2] - cy
                        local d = sqrt(dx * dx + dy * dy)
                        local r = dist[want[k].name]
                        r.d[#r.d + 1] = floor(d + 0.5)
                        r.sum = r.sum + d
                        if d > r.peak then r.peak, r.peakT = d, t - fight.from end
                    end
                end
            end
            t = t + STEP
        end
    end
    for k = 1, #want do
        local p = want[k]
        local r = dist[p.name]
        local c = p.badges[st.i]
        if c and #r.d >= MIN_SAMPLES then
            c.n = 1
            c.avg = floor(r.sum / #r.d * 10 + 0.5) / 10
            c.peak = floor(r.peak * 10 + 0.5) / 10
            c.peakT = floor(r.peakT * 10 + 0.5) / 10
            c.d = r.d
            c.times[1] = c.peakT
            s.icons[st.i] = s.icons[st.i] or ICON
        end
    end
end
function Away.Run(s, fight)
    local st = Away.Begin(s, fight)
    if st then Away.Finish(st) end
end
function Away.StatOf(s, p)
    for i = 1, #s.badges do
        if s.badges[i].kind == "away" then
            local st = p.badges[i]
            return st and st.n > 0 and st.avg and st or nil
        end
    end
    return nil
end
function Away.Limit(def)
    local rule = ns.Penalties and def.limit and ns.Penalties.Get(def.limit)
    return rule and ns.Penalties.Threshold(rule) or 0
end
function Away.Share(st, lim)
    local d, n = st.d or {}, 0
    for i = 1, #d do
        if d[i] > lim then n = n + 1 end
    end
    return #d > 0 and n / #d or 0
end
function Away.Grade(st, def)
    return st.avg > Away.Limit(def) and "yellow" or "green"
end
