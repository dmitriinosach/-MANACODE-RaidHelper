local _, ns = ...
local floor = math.floor
local sqrt = math.sqrt
local tsort = table.sort
local MAP_UNITS = 10000
local HIT = { SPELL_DAMAGE = true, SPELL_MISSED = true, DAMAGE_SHIELD_MISSED = true }
local BN = {}
ns.BloodNova = BN
function BN.Begin(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "nova" then
            return { s = s, fight = fight, i = i, key = ns.SpellKey(bd.id), win = bd.win or 1, near = bd.near or 12,
                     tie = bd.tie or 1, ahead = bd.ahead or 2, list = {}, subs = HIT }
        end
    end
    return nil
end
function BN.Feed(st, ts, dstName, sk)
    if sk ~= st.key or not dstName or not st.s.byName[dstName] then return end
    if ts < st.fight.from or ts > st.fight.to then return end
    local nv = st.list[#st.list]
    if not nv or ts - nv.t > st.win then
        nv = { t = ts, names = {}, seen = {} }
        st.list[#st.list + 1] = nv
    end
    if nv.seen[dstName] then return end
    nv.seen[dstName] = true
    nv.names[#nv.names + 1] = dstName
end
local function Free(p)
    if p.role == "tank" then return false end
    if p.role == "heal" then return true end
    return not ns.IsMelee(p)
end
local function Marks(fight)
    local out = {}
    local segs = ns.Encounters.Segs(fight)
    for i = 1, #segs do
        local m = ns.Decode.Maps(segs[i])
        for k = 1, #m do out[#out + 1] = m[k] end
    end
    tsort(out, function(a, b) return a.t < b.t end)
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
local function PosAt(st, name, t)
    local fight = st.fight
    local segs = ns.Encounters.Segs(fight)
    local bx, by, ax, ay
    for i = 1, #segs do
        for ts, x, y in ns.Decode.Pos(segs[i], name, fight.from - 5, t + st.ahead) do
            if x > 0 or y > 0 then
                if ts <= t then
                    bx, by = x, y
                elseif not ax then
                    ax, ay = x, y
                end
            end
        end
    end
    if bx then return bx, by end
    return ax, ay
end
local function Dist(a, b, yw, yh)
    local dx, dy = (a.x - b.x) * yw, (a.y - b.y) * yh
    return sqrt(dx * dx + dy * dy)
end
local function Tenth(v)
    return floor(v * 10 + 0.5) / 10
end
local function Put(st, p, t, with, yd, bad)
    local c = p.badges[st.i]
    if not c then return end
    local n = c.n + 1
    c.n = n
    c.times[n] = Tenth(t - st.fight.from)
    c.with = c.with or {}
    c.yd = c.yd or {}
    c.bad = c.bad or {}
    c.with[n], c.yd[n], c.bad[n] = with or "", yd and Tenth(yd) or -1, bad
    if bad then
        c.hits = c.hits + 1
        c.grade = "yellow"
    end
    st.s.icons[st.i] = st.s.icons[st.i] or st.s.badges[st.i].id
end
local function Judge(st, nv, marks)
    local byName = st.s.byName
    local yw, yh = Scale(marks, nv.t)
    local pts = {}
    for k = 1, #nv.names do
        local x, y
        if yw then x, y = PosAt(st, nv.names[k], nv.t) end
        if x then pts[#pts + 1] = { n = nv.names[k], x = x, y = y } end
    end
    local best, second
    for k = 1, #pts do
        local far = 0
        for j = 1, #pts do
            if j ~= k then
                local d = Dist(pts[k], pts[j], yw, yh)
                if d > far then far = d end
            end
        end
        pts[k].far = far
        if not best or far < best.far then
            second = best
            best = pts[k]
        elseif not second or far < second.far then
            second = pts[k]
        end
    end
    local target = best and #pts == #nv.names and (not second or second.far - best.far >= st.tie) and best or nil
    local at = {}
    for k = 1, #pts do at[pts[k].n] = pts[k] end
    for k = 1, #nv.names do
        local name = nv.names[k]
        local p = byName[name]
        if p and name ~= (target and target.n) and Free(p) then
            local me = at[name]
            local with, yd
            if me and target then
                with, yd = target.n, Dist(me, target, yw, yh)
            elseif me then
                for j = 1, #pts do
                    if pts[j] ~= me then
                        local d = Dist(me, pts[j], yw, yh)
                        if not yd or d < yd then with, yd = pts[j].n, d end
                    end
                end
            end
            Put(st, p, nv.t, with, yd, yd ~= nil and yd <= st.near)
        end
    end
end
function BN.Finish(st)
    local marks
    for k = 1, #st.list do
        local nv = st.list[k]
        if #nv.names > 1 then
            marks = marks or Marks(st.fight)
            Judge(st, nv, marks)
        end
    end
end
function BN.StatOf(s, p)
    for i = 1, #s.badges do
        if s.badges[i].kind == "nova" then return p.badges[i] end
    end
    return nil
end
