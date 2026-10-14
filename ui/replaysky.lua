local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local asin = math.asin
local pi = math.pi
local tonumber = tonumber
local HALF = 60
local DAY = 1440
local NOON = 720
local MIN_PX = 0.5
local POOL_CAP = 160
local EPS = 1e-6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local Sky = {}
ns.ReplaySky = Sky
local function Rgb()
    return { r = 0, g = 0, b = 0 }
end
local st = { on = false, laid = false, minute = NOON, nightA = 0, hazeA = 0, cloudA = 0, angle = 0, tilt = 0, w = 0,
             h = 0, drift = 0, horizon = 0, calls = 0, made = 0, top = Rgb(), mid = Rgb(), hor = Rgb(), fog = Rgb(),
             tint = Rgb() }
local pools = {}
local function Pool(layer)
    return { layer = layer, list = {}, used = 0, ok = false }
end
local function Next(pool)
    local n = pool.used + 1
    local tex = pool.list[n]
    if not tex then
        if st.made >= POOL_CAP then return nil end
        tex = st.frame:CreateTexture(nil, pool.layer)
        if pool.path then tex:SetTexture(pool.path) end
        pool.list[n] = tex
        st.made = st.made + 1
    end
    pool.used = n
    return tex
end
local function SetPath(pool, path)
    if pool.path == path then return end
    pool.path = path
    pool.ok = true
    for i = 1, #pool.list do
        if not pool.list[i]:SetTexture(path) then pool.ok = false end
    end
end
local function HideFrom(pool, from)
    local list = pool.list
    for i = from, #list do
        if list[i]:IsShown() then list[i]:Hide() end
    end
end
local function Put(tex, x, y, w, h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", st.frame, "TOPLEFT", x, -y)
    tex:SetWidth(w)
    tex:SetHeight(h)
    tex:Show()
end
local function Curve(arr, x)
    local n = #arr
    if x <= arr[1] then return arr[2] end
    for i = 3, n, 2 do
        if x <= arr[i] then
            local x0, x1 = arr[i - 2], arr[i]
            local f = x1 > x0 and (x - x0) / (x1 - x0) or 0
            return arr[i - 1] + (arr[i + 1] - arr[i - 1]) * f
        end
    end
    return arr[n]
end
local function Hex(out, hex)
    out.r = (tonumber(hex:sub(1, 2), 16) or 0) / 255
    out.g = (tonumber(hex:sub(3, 4), 16) or 0) / 255
    out.b = (tonumber(hex:sub(5, 6), 16) or 0) / 255
end
local tmpA, tmpB = Rgb(), Rgb()
local function LightAt(light, m, key, out)
    local n = #light
    local i = n - 1
    for j = 1, n - 1, 2 do
        if light[j] <= m then i = j end
    end
    local j = i + 2 > n and 1 or i + 2
    local m0, m1 = light[i], light[j]
    if m1 <= m0 then m1 = m1 + DAY end
    local f = m1 > m0 and (m - m0) / (m1 - m0) or 0
    Hex(tmpA, light[i + 1][key])
    Hex(tmpB, light[j + 1][key])
    out.r = tmpA.r + (tmpB.r - tmpA.r) * f
    out.g = tmpA.g + (tmpB.g - tmpA.g) * f
    out.b = tmpA.b + (tmpB.b - tmpA.b) * f
end
local function MinuteOf(fight)
    local ts = fight and fight.from
    if type(ts) ~= "number" then return NOON end
    local d = date("*t", floor(ts))
    if type(d) ~= "table" then return NOON end
    return (d.hour or 12) * 60 + (d.min or 0)
end
local function Off()
    if not st.on then return end
    st.on = false
    if st.frame then st.frame:Hide() end
    if st.bg then st.bg:Show() end
end
function Sky.Build(frame, bg)
    st.frame, st.bg = frame, bg
    frame:Hide()
    pools.day = Pool("BACKGROUND")
    pools.grad = Pool("BACKGROUND")
    pools.night = Pool("BORDER")
    pools.clouds = Pool("ARTWORK")
    pools.haze = Pool("OVERLAY")
    Next(pools.day)
    Next(pools.night)
    Next(pools.clouds)
    Next(pools.haze)
    SetPath(pools.grad, WHITE)
    Next(pools.grad)
    Next(pools.grad)
    for _, pool in pairs(pools) do
        pool.used = 0
        HideFrom(pool, 1)
    end
end
function Sky.Use(room, fight)
    st.room, st.fight, st.laid = room, fight, false
    local def = room and room.sky and ns.replaySky and ns.replaySky[room.sky]
    st.def = def
    if not def or not st.frame then
        Off()
        return
    end
    local m = MinuteOf(fight)
    local fade = def.fade
    st.minute = m
    st.nightA = Curve(fade.night, m)
    local dayA, cd, cn = Curve(fade.day, m), Curve(fade.cloudDay, m), Curve(fade.cloudNight, m)
    st.hazePath = dayA >= st.nightA and def.haze.day or def.haze.night
    st.hazeA = max(dayA, st.nightA)
    st.cloudPath = cd >= cn and def.clouds.day or def.clouds.night
    st.cloudA = max(cd, cn)
    SetPath(pools.day, def.bowl.day)
    SetPath(pools.night, def.bowl.night)
    SetPath(pools.clouds, st.cloudPath)
    SetPath(pools.haze, st.hazePath)
    LightAt(def.light, m, "top", st.top)
    LightAt(def.light, m, "mid", st.mid)
    LightAt(def.light, m, "hor", st.hor)
    LightAt(def.light, m, "fog", st.fog)
    Hex(st.tint, def.clouds.tint or "ffffff")
end
local function YOf(e, k, h, phi)
    return h / 2 - (phi + e) * k
end
local function Bowl(def, e, k, w, h, top, bot)
    local at, u0, u1 = def.bowl.at, def.bowl.u0, def.bowl.u1
    local night = st.nightA > EPS
    for i = 1, #at - 2, 2 do
        local lo, hi = max(at[i], bot), min(at[i + 2], top)
        if hi - lo > EPS then
            local f0, f1 = at[i], at[i + 2]
            local vHi = at[i + 1] + (at[i + 3] - at[i + 1]) * (hi - f0) / (f1 - f0)
            local vLo = at[i + 1] + (at[i + 3] - at[i + 1]) * (lo - f0) / (f1 - f0)
            local y, sh = YOf(e, k, h, hi), (hi - lo) * k
            local tex = Next(pools.day)
            if tex then
                Put(tex, 0, y, w, sh)
                tex:SetTexCoord(u0, u1, vHi, vLo)
            end
            if night then
                tex = Next(pools.night)
                if tex then
                    Put(tex, 0, y, w, sh)
                    tex:SetTexCoord(u0, u1, vHi, vLo)
                    tex:SetAlpha(st.nightA)
                end
            end
        end
    end
end
local function Fallback(e, k, w, h, top)
    local yH = max(0, min(h, YOf(e, k, h, 0)))
    local s, f, m, t = st.hor, st.fog, st.mid, st.top
    if yH > MIN_PX then
        local tex = Next(pools.grad)
        Put(tex, 0, 0, w, yH)
        local q = max(0, min(1, top / 90))
        local r = m.r + (t.r - m.r) * q
        local g = m.g + (t.g - m.g) * q
        local b = m.b + (t.b - m.b) * q
        tex:SetGradient("VERTICAL", s.r, s.g, s.b, r, g, b)
    end
    if h - yH > MIN_PX then
        local tex = Next(pools.grad)
        Put(tex, 0, yH, w, h - yH)
        tex:SetGradient("VERTICAL", f.r, f.g, f.b, f.r, f.g, f.b)
    end
end
local function Band(pool, y, sh, k, w, deg, pan, a, b, rot, aTop, aBot)
    local tint = st.tint
    local uL = pan / deg
    local uR = uL + w / (k * deg)
    local i = floor(uL)
    local base = floor(min(a, b) + EPS)
    if rot then base = 0 end
    local va, vb = a - base, b - base
    local x = 0
    while x < w - MIN_PX do
        local s0 = max(uL, i)
        local s1 = min(uR, i + 1)
        local x1 = (s1 - uL) * deg * k
        if x1 - x >= MIN_PX then
            local tex = Next(pool)
            if not tex then return end
            Put(tex, x, y, x1 - x, sh)
            local c0, c1 = s0 - i, s1 - i
            if rot then
                tex:SetTexCoord(va, c0, vb, c0, va, c1, vb, c1)
                tex:SetAlpha(aTop)
            else
                tex:SetTexCoord(c0, c1, va, vb)
                tex:SetGradientAlpha("VERTICAL", tint.r, tint.g, tint.b, aBot, tint.r, tint.g, tint.b, aTop)
            end
        end
        x = x1
        i = i + 1
    end
end
local function Clouds(def, e, k, w, h, top, pan)
    local c = def.clouds
    local at, wgt = c.at, st.cloudA
    if wgt <= EPS then return end
    for i = 1, #at - 3, 3 do
        local lo, hi = at[i], min(at[i + 3], top)
        if hi - lo > EPS then
            local f = (hi - lo) / (at[i + 3] - lo)
            local vHi = at[i + 1] + (at[i + 4] - at[i + 1]) * f
            local aHi = (at[i + 2] + (at[i + 5] - at[i + 2]) * f) * wgt
            Band(pools.clouds, YOf(e, k, h, hi), (hi - lo) * k, k, w, c.deg, pan, vHi, at[i + 1], false, aHi,
                at[i + 2] * wgt)
        end
    end
end
local function Haze(def, e, k, w, h, top, pan)
    local z = def.haze
    local at = z.at
    if st.hazeA <= EPS then return end
    for i = 1, #at - 2, 2 do
        local lo, hi = at[i], min(at[i + 2], top)
        if hi - lo > EPS then
            local uHi = at[i + 1] + (at[i + 3] - at[i + 1]) * (hi - lo) / (at[i + 2] - lo)
            Band(pools.haze, YOf(e, k, h, hi), (hi - lo) * k, k, w, z.deg, pan, uHi, at[i + 1], true, st.hazeA,
                st.hazeA)
        end
    end
end
local function Layout(cam, k, drift)
    local def = st.def
    local full = not st.laid or cam.tilt ~= st.tilt or cam.w ~= st.w or cam.h ~= st.h
    local turn = full or cam.angle ~= st.angle
    st.calls = st.calls + 1
    st.angle, st.tilt, st.w, st.h, st.drift, st.laid = cam.angle, cam.tilt, cam.w, cam.h, drift, true
    local w, h = cam.w, cam.h
    local e = asin(max(-1, min(1, cam.tilt))) * 180 / pi
    local top, bot = HALF - e, -HALF - e
    st.horizon = YOf(e, k, h, 0)
    if full then
        pools.day.used, pools.night.used, pools.grad.used = 0, 0, 0
        if pools.day.ok then
            Bowl(def, e, k, w, h, top, bot)
        else
            Fallback(e, k, w, h, top)
        end
        HideFrom(pools.day, pools.day.used + 1)
        HideFrom(pools.night, pools.night.used + 1)
        HideFrom(pools.grad, pools.grad.used + 1)
    end
    local pan = -cam.angle * 180 / pi - w / (2 * k)
    pools.clouds.used = 0
    if top > 0 then Clouds(def, e, k, w, h, top, pan + drift / k) end
    HideFrom(pools.clouds, pools.clouds.used + 1)
    if turn then
        pools.haze.used = 0
        if top > 0 then Haze(def, e, k, w, h, top, pan) end
        HideFrom(pools.haze, pools.haze.used + 1)
    end
end
function Sky.Place(cam, scene, t, shown)
    local room, fight = scene and scene.room, scene and scene.fight
    if room ~= st.room or fight ~= st.fight then Sky.Use(room, fight) end
    local def = st.def
    if not (def and shown and cam.h > 0) then
        Off()
        return
    end
    if not st.on then
        st.on, st.laid = true, false
        st.frame:Show()
        st.bg:Hide()
    end
    local k = cam.h / (2 * HALF)
    local c = def.clouds
    local drift = c.drift and c.drift > 0 and floor(t / c.drift * c.deg * k) or 0
    if st.laid and cam.angle == st.angle and cam.tilt == st.tilt and cam.w == st.w and cam.h == st.h
        and drift == st.drift then
        return
    end
    Layout(cam, k, drift)
end
function Sky.Probe()
    return st, pools
end
