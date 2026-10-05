local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local pi = math.pi
local SMOKE = "Spells\\ALPHACLOUD"
local RING = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\ring128"
local PUFF_DRAW = 72
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
local TC = {
    { 0, 0, 0, 1, 1, 0, 1, 1 }, { 1, 0, 1, 1, 0, 0, 0, 1 }, { 0, 1, 0, 0, 1, 1, 1, 0 }, { 1, 1, 1, 0, 0, 1, 0, 0 },
    { 0, 1, 1, 1, 0, 0, 1, 0 }, { 0, 0, 1, 0, 0, 1, 1, 1 }, { 1, 1, 0, 1, 1, 0, 0, 0 }, { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local V = {}
ns.ReplaySwarmView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Core = ns.ReplaySwarm
local wide, core, rings, halos = {}, {}, {}, {}
local used = { puff = 0, mark = 0 }
local view
local hw, hh = 0, 0
local probe = { puffs = 0, marks = 0, rings = 0, alpha = {}, size = {} }
local function Tex(layer, path)
    local tex = layer:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(path)
    tex:Hide()
    return tex
end
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
    if rw * 2 > MAX_PX or sx + rw < -hw or sx - rw > hw or sy + rh < -hh or sy - rh > hh then
        tex:Hide()
        return false
    end
    if v and tex.v ~= v then
        tex.v = v
        local c = TC[v]
        tex:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", view, "CENTER", sx, -sy)
    tex:SetWidth(rw * 2)
    tex:SetHeight(rh * 2)
    tex:Show()
    return true
end
local function Screen(cam, scene, x, y)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
local function PlacePuffs(scene, cam, t, S)
    local n = 0
    local ppy, zoom, tilt = scene.ppy, cam.zoom, cam.tilt
    local tones = S.tones or TONES
    local r1, g1, b1, a1 = Kit.Color(tones[1])
    local r2, g2, b2, a2 = Kit.Color(tones[2])
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
    local n, m, nr = 0, 0, 0
    if S and (S.n > 0 or S.nm > 0) then
        hw, hh = cam.w / 2, cam.h / 2
        n = PlacePuffs(scene, cam, t, S)
        m, nr = PlaceMarks(scene, cam, t, S)
    end
    probe.puffs, probe.marks, probe.rings = n, m, nr
    HideFrom(n, m)
end
function V.Probe()
    return probe
end
