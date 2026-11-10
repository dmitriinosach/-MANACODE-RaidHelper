local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local cos = math.cos
local pi = math.pi
local SMOKE = "Spells\\ALPHACLOUD"
local RING = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\ring128"
local PUFF_DRAW = 96
local MARK_DRAW = 4
local MAX_PX = 4000
local GROW = 0.6
local FADE = 3
local GROW_FROM = 0.55
local WIDE = 1.5
local CORE = 0.95
local BREATH = 1.1
local BREATH_K = 0.07
local BREATH_A = 0.12
local RING_FROM = 1.8
local RING_PULSE = 6
local HALO = 0.9
local TONES = { "sem.rep.swarm", "sem.rep.swarmCore", "sem.rep.swarmMark" }
local CA, CR, CS = { 0 }, { 0 }, { 0.55 }
for i = 0, 9 do
    local n = #CA + 1
    CA[n], CR[n], CS[n] = i * 2 * pi / 10, 0.8 + 0.05 * ((i * 5) % 3 - 1), 0.42 + 0.04 * ((i * 7) % 3 - 1)
end
local FLOW_N, FLOW_R0, FLOW_R1 = 9, 0.1, 0.72
local FA, FU = {}, {}
for i = 1, FLOW_N do FA[i], FU[i] = i * 2 * pi / FLOW_N + 0.35 * (i % 2), (i * 0.382) % 1 end
local CLOUD_BORN = 0.3
local CLOUD_FADE = 1
local TC = {
    { 0, 0, 0, 1, 1, 0, 1, 1 }, { 1, 0, 1, 1, 0, 0, 0, 1 }, { 0, 1, 0, 0, 1, 1, 1, 0 }, { 1, 1, 1, 0, 0, 1, 0, 0 },
    { 0, 1, 1, 1, 0, 0, 1, 0 }, { 0, 0, 1, 0, 0, 1, 1, 1 }, { 1, 1, 0, 1, 1, 0, 0, 0 }, { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local V = {}
ns.ReplaySwarmView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Core = ns.ReplaySwarm
local Layers = ns.ReplayLayers
local wide, core, rings, halos = {}, {}, {}, {}
local used = { puff = 0, mark = 0 }
local view
local hw, hh = 0, 0
local probe = { puffs = 0, marks = 0, rings = 0, alpha = {}, size = {}, clouds = 0, cloudR = {}, cloudA = {}, flowU = 0 }
local cloudL
local cloudList = {}
local ICE_A = 0.6
local iceCls
local iceList = {}
local Tex = RD.Tex
function V.Build(v, layer)
    view = v
    for i = 1, PUFF_DRAW do
        wide[i] = Tex(layer, SMOKE)
        core[i] = Tex(layer, SMOKE)
    end
    for i = 1, MARK_DRAW do
        halos[i] = Tex(layer, SMOKE)
        rings[i] = Tex(layer, RING)
    end
end
local function HideFrom(n, m)
    for i = n + 1, used.puff do
        wide[i]:Hide()
        core[i]:Hide()
    end
    for i = m + 1, used.mark do
        halos[i]:Hide()
        rings[i]:Hide()
    end
    used.puff, used.mark = n, m
end
function V.Use(scene)
    if not view then return end
    used.puff, used.mark = PUFF_DRAW, MARK_DRAW
    HideFrom(0, 0)
end
local function Put(tex, sx, sy, rw, squash, v)
    local rh = max(1, rw * min(1, squash))
    if rw * 2 > MAX_PX then
        tex:Hide()
        return false
    end
    local LV = ns.ReplayLayersView
    if not v and LV and LV.Sharp then LV.Sharp(tex, rw) end
    return Kit.Crop(tex, view, hw, hh, sx - rw, sy - rh, sx + rw, sy + rh, v and TC[v])
end
local Screen = RD.Screen
local function PlacePuffs(scene, cam, t, S)
    local n = 0
    local ppy, zoom, tilt = scene.ppy, cam.zoom, cam.tilt
    local tones = S.tones or TONES
    local r1, g1, b1, a1 = Kit.Color(tones[1])
    local r2, g2, b2, a2 = Kit.Color(tones[2])
    local ka = S.ka
    if ka then a1, a2 = a1 * ka[1], a2 * ka[2] end
    local F, T = S.from, S.to
    for i = S.n, 1, -1 do
        if n >= PUFF_DRAW then break end
        local from = F[i]
        if from <= t and T[i] > t then
            local sx, sy, k = Screen(cam, scene, S.x[i], S.y[i])
            if k > 0 then
                local age = t - from
                local a = min(1, age / GROW, (T[i] - t) / FADE)
                local grow = GROW_FROM + (1 - GROW_FROM) * min(1, age / GROW)
                local ph = Core.Phase(i) * 2 * pi
                local s1, s2 = sin(t * BREATH + ph), sin(t * BREATH * 1.37 + ph * 2)
                local rw = S.r * ppy * zoom * k * grow
                local v = S.v[i]
                local tw, tc = wide[n + 1], core[n + 1]
                local ww = rw * WIDE * (1 + BREATH_K * s1)
                if Put(tw, sx, sy, ww, tilt * k, v) then
                    n = n + 1
                    tw:SetVertexColor(r1, g1, b1, a1 * a * (1 - BREATH_A + BREATH_A * s2))
                    if Put(tc, sx, sy, rw * CORE * (1 + BREATH_K * s2), tilt * k, v % 8 + 1) then
                        tc:SetVertexColor(r2, g2, b2, a2 * a * (1 - BREATH_A + BREATH_A * s1))
                    end
                    probe.alpha[n], probe.size[n] = a, ww
                else
                    tc:Hide()
                end
            end
        end
    end
    return n
end
local function CloudIndex(L)
    if cloudL == L then return end
    cloudL = L
    for i = #cloudList, 1, -1 do cloudList[i] = nil end
    for j = 1, L.np or 0 do
        if L.plDef[j].cloud then cloudList[#cloudList + 1] = j end
    end
end
local function Puff(scene, cam, t, n, x, y, rw, a, C, seed)
    if n >= PUFF_DRAW then return n end
    local sx, sy, k = Screen(cam, scene, x, y)
    if k <= 0 then return n end
    local tilt = cam.tilt * k
    rw = rw * cam.zoom * k
    local ph = Core.Phase(seed) * 2 * pi
    local s1, s2 = sin(t * BREATH + ph), sin(t * BREATH * 1.37 + ph * 2)
    local v = seed % 8 + 1
    local tw, tc = wide[n + 1], core[n + 1]
    if not Put(tw, sx, sy, rw * WIDE * (1 + BREATH_K * s1), tilt, v) then
        tc:Hide()
        return n
    end
    tw:SetVertexColor(C[1], C[2], C[3], C[4] * a * (1 - BREATH_A + BREATH_A * s2))
    if Put(tc, sx, sy, rw * CORE * (1 + BREATH_K * s2), tilt, v % 8 + 1) then
        tc:SetVertexColor(C[5], C[6], C[7], C[8] * a * (1 - BREATH_A + BREATH_A * s1))
    end
    return n + 1
end
local tone8 = {}
local function Cloud(scene, cam, t, n, x, y, R, a, tones, flow, age, seed)
    local C = tone8
    C[1], C[2], C[3], C[4] = Kit.Color(tones[1])
    C[5], C[6], C[7], C[8] = Kit.Color(tones[2])
    for p = 1, #CA do
        n = Puff(scene, cam, t, n, x + cos(CA[p]) * CR[p] * R, y + sin(CA[p]) * CR[p] * R, CS[p] * R, a, C, p + seed * 7)
    end
    for i = 1, FLOW_N do
        local u = (FU[i] + flow * age) % 1
        local w = min(1, u / 0.2, (1 - u) / 0.3)
        local r = (FLOW_R0 + (FLOW_R1 - FLOW_R0) * u) * R
        probe.flowU = u
        n = Puff(scene, cam, t, n, x + cos(FA[i]) * r, y + sin(FA[i]) * r, (0.28 + 0.14 * u) * R, a * w, C,
            #CA + i + seed * 7)
    end
    return n
end
local function Life(from, to, t)
    local a = 1
    if to - t < CLOUD_FADE then a = (to - t) / CLOUD_FADE end
    if t - from < CLOUD_BORN then a = a * max(0.3, (t - from) / CLOUD_BORN) end
    return a
end
local function PlaceClouds(scene, cam, t, n)
    local L = scene.layers
    CloudIndex(L)
    local nc = 0
    for q = 1, #cloudList do
        local j = cloudList[q]
        local from, to = L.plFrom[j], L.plTo[j]
        if from <= t and to > t and L.plX[j] >= 0 then
            local def = L.plDef[j]
            local C = def.cloud
            local a = Life(from, to, t)
            local solid = def.fade and L.plSolid and L.plSolid[j]
            if solid and t > solid then a = a * (to - t) / (to - solid) end
            local R = Layers.PoolRadius(L, j, t) * scene.ppy
            nc = nc + 1
            probe.cloudR[nc], probe.cloudA[nc] = R, a
            n = Cloud(scene, cam, t, n, L.plX[j], L.plY[j], R, a, C.tones, C.flow, t - from, j)
        end
    end
    for i = nc + 1, #probe.cloudR do probe.cloudR[i], probe.cloudA[i] = nil, nil end
    return n, nc
end
local function IceIndex(cls)
    if iceCls == cls then return end
    iceCls = cls
    for i = #iceList, 1, -1 do iceList[i] = nil end
    for _, it in ipairs(cls and cls.zones or {}) do
        if it.ice and it.x then iceList[#iceList + 1] = it end
    end
end
local function PlaceIce(scene, cam, t, n)
    IceIndex(scene.layers.cls)
    local ni = 0
    for q = 1, #iceList do
        local it = iceList[q]
        if it.from <= t and it.to > t then
            ni = ni + 1
            n = Cloud(scene, cam, 0, n, it.x, it.y, it.r * scene.ppy, Life(it.from, it.to, t) * ICE_A, it.ice, 0, 0, 50 + q)
        end
    end
    return n, ni
end
local function PlaceMarks(scene, cam, t, S)
    local m, nr = 0, 0
    local ppy, zoom, tilt = scene.ppy, cam.zoom, cam.tilt
    local tones = S.tones or TONES
    local rr, gr, br, ar = Kit.Color(tones[3])
    local rh, gh, bh, ah = Kit.Color(tones[2])
    for j = 1, S.nm do
        if m >= MARK_DRAW then break end
        local from, on, to = S.mFrom[j], S.mOn[j], S.mTo[j]
        local st = scene.states[S.mk[j]]
        if from <= t and t < max(on, to) and st and st.vis and not st.dead then
            local sx, sy, k = Screen(cam, scene, st.x, st.y)
            if k > 0 then
                m = m + 1
                local rw = S.r * ppy * zoom * k
                local ring, halo = rings[m], halos[m]
                local p = 1
                if t < on then
                    p = (t - from) / max(0.1, on - from)
                    local pulse = 0.65 + 0.35 * sin((t - from) * RING_PULSE)
                    if Put(ring, sx, sy, rw * (RING_FROM - (RING_FROM - 1) * p), tilt * k) then
                        nr = nr + 1
                        ring:SetVertexColor(rr, gr, br, ar * pulse)
                    end
                else
                    ring:Hide()
                end
                if Put(halo, sx, sy, rw * HALO, tilt * k, j % 8 + 1) then
                    halo:SetVertexColor(rh, gh, bh, ah * (0.25 + 0.5 * p))
                end
            end
        end
    end
    return m, nr
end
function V.Place(scene, cam, t)
    if not view then return end
    local S = scene.layers and scene.layers.swarm
    local n, m, nr, nc = 0, 0, 0, 0
    hw, hh = cam.w / 2, cam.h / 2
    if S and (S.n > 0 or S.nm > 0) then
        n = PlacePuffs(scene, cam, t, S)
        m, nr = PlaceMarks(scene, cam, t, S)
    end
    local ni = 0
    if scene.layers then
        n, nc = PlaceClouds(scene, cam, t, n)
        n, ni = PlaceIce(scene, cam, t, n)
    end
    probe.puffs, probe.marks, probe.rings, probe.clouds, probe.ice = n, m, nr, nc, ni
    HideFrom(n, m)
end
function V.Probe()
    return probe
end
