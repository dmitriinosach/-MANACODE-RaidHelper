local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local floor = math.floor
local SMOKE = "Spells\\ALPHACLOUD"
local BLOB = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\ooze_blob"
local GAS_DRAW = 6
local PUFFS = 3
local MAX_PX = 4000
local HOLD = 4
local PUFF_YD = { 4.5, 3, 1.6 }
local PUFF_TONE = { "sem.rep.gasWide", "sem.rep.gasCore", "sem.rep.gasLight" }
local BLOB_YD = 3.2
local BREATH = 1.9
local BREATH_K = 0.07
local FRAME = 0.25
local GROUND = 100 / 128
local LEAN_DT = 0.3
local LEAN_K = 0.018
local LEAN_MAX = 0.14
local BADGE = 12
local TC = {
    { 0, 0, 0, 1, 1, 0, 1, 1 }, { 1, 0, 1, 1, 0, 0, 0, 1 }, { 0, 1, 0, 0, 1, 1, 1, 0 }, { 1, 1, 1, 0, 0, 1, 0, 0 },
    { 0, 1, 1, 1, 0, 0, 1, 0 }, { 0, 0, 1, 0, 0, 1, 1, 1 }, { 1, 1, 0, 1, 1, 0, 0, 0 }, { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local LOOK = {
    gas = { dark = "sem.rep.gasDark", lit = "sem.rep.gasBody", hi = "sem.rep.gasHi", puffs = true },
    blob = { dark = "sem.rep.oozeDark", lit = "sem.rep.oozeBody", hi = "sem.rep.oozeHi" },
}
local V = {}
ns.ReplayOozeView = V
local Kit = ns.Kit
local Replay = ns.Replay
local slots = {}
local used = 0
local view
local hw, hh = 0, 0
local stats = { gas = 0, blob = 0, puffs = 0, slow = 0, bodyW = 0, lean = 0 }
V.stats = stats
local function Tex(layer, path, draw)
    local tex = layer:CreateTexture(nil, draw)
    tex:SetTexture(path)
    tex:Hide()
    return tex
end
function V.Build(v, layer)
    view = v
    for i = 1, GAS_DRAW do
        local s = { puff = {} }
        for p = 1, PUFFS do s.puff[p] = Tex(layer, SMOKE, "BACKGROUND") end
        s.dark = Tex(layer, BLOB, "BORDER")
        s.lit = Tex(layer, BLOB, "ARTWORK")
        s.hi = Tex(layer, BLOB, "OVERLAY")
        s.slow = layer:CreateTexture(nil, "OVERLAY")
        s.slow:SetWidth(BADGE)
        s.slow:SetHeight(BADGE)
        s.slow:Hide()
        slots[i] = s
    end
end
local function HideSlot(s)
    for p = 1, PUFFS do s.puff[p]:Hide() end
    s.dark:Hide()
    s.lit:Hide()
    s.hi:Hide()
    s.slow:Hide()
end
local function HideFrom(from)
    for i = from + 1, used do HideSlot(slots[i]) end
    used = from
end
function V.Use(scene)
    if not view then return end
    used = GAS_DRAW
    HideFrom(0)
    for i = 1, GAS_DRAW do slots[i].look = nil end
    for k in pairs(stats) do stats[k] = 0 end
end
local function Puff(tex, sx, sy, rw, tilt, v)
    local rh = max(1, rw * tilt)
    if rw * 2 > MAX_PX or sx + rw < -hw or sx - rw > hw or sy + rh < -hh or sy - rh > hh then
        tex:Hide()
        return false
    end
    if tex.v ~= v then
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
local function Shear(tex, frame, lean)
    if tex.lean == lean then return end
    tex.lean = lean
    local u0 = frame * FRAME
    local u1 = u0 + FRAME
    local s = lean * FRAME
    tex:SetTexCoord(u0 - s, 0, u0, 1, u1 - s, 0, u1, 1)
end
local function Stand(tex, sx, sy, w, h)
    local below = h * (1 - GROUND)
    if w > MAX_PX or sx + w / 2 < -hw or sx - w / 2 > hw or sy + below < -hh or sy - h * GROUND > hh then
        tex:Hide()
        return false
    end
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOM", view, "CENTER", sx, -(sy + below))
    tex:SetWidth(w)
    tex:SetHeight(h)
    tex:Show()
    return true
end
local function Lean(a, cam, t, sx, yd)
    local x0, y0 = Replay.PosHold(a, t - LEAN_DT, HOLD)
    if x0 < 0 then return 0 end
    local sx0, _, k0 = Replay.Project(cam, x0, y0)
    if k0 <= 0 then return 0 end
    local lean = (sx - sx0) / (yd * LEAN_DT) * LEAN_K
    lean = floor(max(-LEAN_MAX, min(LEAN_MAX, lean)) * 64 + 0.5) / 64
    return lean
end
function V.Place(scene, cam, t)
    if not view then return end
    local list = scene.layers and scene.layers.adds
    local n, nb, np, ns_ = 0, 0, 0, 0
    hw, hh = cam.w / 2, cam.h / 2
    for i = 1, list and #list or 0 do
        local a = list[i]
        if n >= GAS_DRAW then break end
        local look = a.look and LOOK[a.look]
        if look and a.from <= t and a.to > t then
            local x, y = Replay.PosHold(a, t, HOLD)
            local sx, sy, k = -1, 0, 0
            if x >= 0 then sx, sy, k = Replay.Project(cam, x, y) end
            if k > 0 then
                n = n + 1
                local s = slots[n]
                if s.look ~= a.look then
                    s.look = a.look
                    s.dark:SetVertexColor(Kit.Color(look.dark))
                    s.lit:SetVertexColor(Kit.Color(look.lit))
                    s.hi:SetVertexColor(Kit.Color(look.hi))
                end
                local yd = scene.ppy * cam.zoom * k
                local tilt = min(1, cam.tilt * k)
                local ph = i * 1.7
                local s1, s2 = sin(t * BREATH + ph), sin(t * BREATH * 1.37 + ph * 2)
                if look.puffs then
                    for p = 1, PUFFS do
                        local rw = PUFF_YD[p] * yd * (1 + BREATH_K * (p == 2 and s2 or s1))
                        local tex = s.puff[p]
                        if Puff(tex, sx, sy, rw, tilt, (i * 3 + p) % 8 + 1) then
                            np = np + 1
                            local r, g, b, al = Kit.Color(PUFF_TONE[p])
                            tex:SetVertexColor(r, g, b, al * (1 - 0.12 + 0.12 * s2))
                        end
                    end
                else
                    nb = nb + 1
                    for p = 1, PUFFS do s.puff[p]:Hide() end
                end
                local w = BLOB_YD * yd * (1 + BREATH_K * s1)
                local h = BLOB_YD * yd * (1 - BREATH_K * 0.8 * s1)
                local lean = Lean(a, cam, t, sx, yd)
                Shear(s.dark, 0, lean)
                Shear(s.lit, 1, lean)
                Shear(s.hi, 2, lean)
                Stand(s.dark, sx, sy, w, h)
                Stand(s.lit, sx, sy, w, h)
                Stand(s.hi, sx, sy, w, h)
                stats.bodyW, stats.lean = w, lean
                local id = ns.ReplayLayers.AddDebuff(a, t)
                if id then
                    if s.slowId ~= id then
                        Kit.Icon.Spell(s.slow, id)
                        s.slowId = id
                    end
                    s.slow:ClearAllPoints()
                    s.slow:SetPoint("BOTTOM", view, "CENTER", sx, -(sy - h * GROUND - 2))
                    s.slow:Show()
                    ns_ = ns_ + 1
                else
                    s.slow:Hide()
                end
            end
        end
    end
    if n < used then HideFrom(n) end
    used = n
    stats.gas, stats.blob, stats.puffs, stats.slow = n - nb, nb, np, ns_
end
