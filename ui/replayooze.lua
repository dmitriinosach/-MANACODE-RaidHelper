local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local floor = math.floor
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local SMOKE = "Spells\\ALPHACLOUD"
local BLOB = ART .. "ooze_blob"
local RIM = ART .. "rim"
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
local RING_YD = 4.2
local ADD_TOK = "sem.rep.add"
local PCT_GAP = 1
local DIE = 1.3
local SQUASH = 0.45
local WIDE = 0.7
local FLAT = 0.85
local POOL_R0 = 1.2
local POOL_R1 = 2.8
local POOL_IN = 0.15
local POOL_OUT = 0.35
local TC = {
    { 0, 0, 0, 1, 1, 0, 1, 1 }, { 1, 0, 1, 1, 0, 0, 0, 1 }, { 0, 1, 0, 0, 1, 1, 1, 0 }, { 1, 1, 1, 0, 0, 1, 0, 0 },
    { 0, 1, 1, 1, 0, 0, 1, 0 }, { 0, 0, 1, 0, 0, 1, 1, 1 }, { 1, 1, 0, 1, 1, 0, 0, 0 }, { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local LOOK = {
    gas = { dark = "sem.rep.gasDark", lit = "sem.rep.gasBody", hi = "sem.rep.gasHi", pool = "sem.rep.gasCore",
            puffs = true },
    blob = { dark = "sem.rep.oozeDark", lit = "sem.rep.oozeBody", hi = "sem.rep.oozeHi", pool = "sem.rep.ooze" },
}
local V = {}
ns.ReplayOozeView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Figs = ns.ReplayFigs
local slots = {}
local used = 0
local view
local arcOk = false
local hw, hh = 0, 0
local stats = { gas = 0, blob = 0, puffs = 0, slow = 0, bodyW = 0, lean = 0, hp = 0, pct = 0, arc = 0, melt = 0,
                meltW = 0, meltH = 0, poolW = 0, poolA = 0 }
V.stats = stats
local function Tex(layer, path, draw)
    local tex = layer:CreateTexture(nil, draw)
    tex:SetTexture(path)
    tex:Hide()
    return tex
end
local function Recolor(s)
    Kit.Hue(s.arc, ADD_TOK)
    local _, _, _, a = Kit.Color(ADD_TOK)
    Kit.Hue(s.trail, ADD_TOK, (a or 1) * Figs.TRAIL_A)
end
function V.Build(v, layer)
    view = v
    for i = 1, GAS_DRAW do
        local s = { puff = {} }
        s.pool = Tex(layer, RIM, "BACKGROUND")
        for p = 1, PUFFS do s.puff[p] = Tex(layer, SMOKE, "BACKGROUND") end
        s.trail = layer:CreateTexture(nil, "BACKGROUND")
        arcOk = s.trail:SetTexture(Figs.ARC_TEX) and true or false
        Figs.ArcFrame(s.trail, Figs.ARC_N)
        s.trail:Hide()
        s.arc = Tex(layer, Figs.ARC_TEX, "BACKGROUND")
        s.dark = Tex(layer, BLOB, "BORDER")
        s.lit = Tex(layer, BLOB, "ARTWORK")
        s.hi = Tex(layer, BLOB, "OVERLAY")
        s.slow = layer:CreateTexture(nil, "OVERLAY")
        s.slow:SetWidth(BADGE)
        s.slow:SetHeight(BADGE)
        s.slow:Hide()
        s.pct = layer:CreateFontString(nil, "OVERLAY")
        s.pct:SetFontObject(Figs.PctFont())
        s.pct:SetJustifyH("CENTER")
        Kit.Text(s.pct, "sem.rep.pct")
        s.pct:Hide()
        Recolor(s)
        slots[i] = s
    end
end
local function HideHp(s)
    s.arc:Hide()
    s.trail:Hide()
    s.pct:Hide()
end
local function HideSlot(s)
    for p = 1, PUFFS do s.puff[p]:Hide() end
    s.dark:Hide()
    s.lit:Hide()
    s.hi:Hide()
    s.slow:Hide()
    s.pool:Hide()
    HideHp(s)
end
local function HideFrom(from)
    for i = from + 1, used do HideSlot(slots[i]) end
    used = from
end
function V.Use(scene)
    if not view then return end
    used = GAS_DRAW
    HideFrom(0)
    for i = 1, GAS_DRAW do
        local s = slots[i]
        s.look, s.arcF, s.pctN = nil, nil, nil
        Recolor(s)
    end
    for k in pairs(stats) do stats[k] = 0 end
end
local function Oval(tex, sx, sy, rw, rh)
    if rw * 2 > MAX_PX or sx + rw < -hw or sx - rw > hw or sy + rh < -hh or sy - rh > hh then
        tex:Hide()
        return false
    end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", view, "CENTER", sx, -sy)
    tex:SetWidth(rw * 2)
    tex:SetHeight(rh * 2)
    tex:Show()
    return true
end
local function Puff(tex, sx, sy, rw, tilt, v)
    if tex.v ~= v then
        tex.v = v
        local c = TC[v]
        tex:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    end
    return Oval(tex, sx, sy, rw, max(1, rw * tilt))
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
local function Body(s, sx, sy, w, h, lean, f)
    Shear(s.dark, 0, lean)
    Shear(s.lit, 1, lean)
    Shear(s.hi, 2, lean)
    Stand(s.dark, sx, sy, w, h)
    Stand(s.lit, sx, sy, w, h)
    Stand(s.hi, sx, sy, w, h)
    if s.fade ~= f then
        s.fade = f
        s.dark:SetAlpha(f)
        s.lit:SetAlpha(f)
        s.hi:SetAlpha(f)
    end
end
local function Puffs(s, sx, sy, yd, tilt, i, s1, s2, f)
    local np = 0
    for p = 1, PUFFS do
        local rw = PUFF_YD[p] * yd * (1 + BREATH_K * (p == 2 and s2 or s1))
        local tex = s.puff[p]
        if Puff(tex, sx, sy, rw, tilt, (i * 3 + p) % 8 + 1) then
            np = np + 1
            local r, g, b, al = Kit.Color(PUFF_TONE[p])
            tex:SetVertexColor(r, g, b, al * (1 - 0.12 + 0.12 * s2) * f)
        end
    end
    return np
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
local function PlaceHp(s, a, t, sx, sy, yd, tilt, top)
    local hp = Figs.HpOn() and ns.ReplayLayers.AddHp(a, t)
    if not hp then
        HideHp(s)
        return 0
    end
    stats.hp = stats.hp + 1
    if arcOk then
        local f = Figs.ArcOf(hp)
        if s.arcF ~= f then
            s.arcF = f
            Figs.ArcFrame(s.arc, f)
        end
        local rw = RING_YD * yd / 2
        local rh = max(1, rw * tilt)
        if Oval(s.arc, sx, sy, rw, rh) and f < Figs.ARC_N then Oval(s.trail, sx, sy, rw, rh) else s.trail:Hide() end
        stats.arc = f
    end
    local n = max(1, min(100, floor(hp * 100 + 0.5)))
    if s.pctN ~= n then
        s.pctN = n
        s.pct:SetText(tostring(n))
    end
    s.pct:ClearAllPoints()
    s.pct:SetPoint("BOTTOM", view, "CENTER", sx, -(sy - top) + PCT_GAP)
    s.pct:Show()
    stats.pct = n
    return Figs.PCT_H + PCT_GAP
end
local function Melt(s, look, sx, sy, yd, tilt, p, i, s1, s2)
    local q = min(1, p / SQUASH)
    local e = 1 - (1 - q) * (1 - q)
    local w = BLOB_YD * yd * (1 + WIDE * e)
    local h = BLOB_YD * yd * max(0.05, 1 - FLAT * e)
    Body(s, sx, sy, w, h, 0, 1 - q)
    s.slow:Hide()
    HideHp(s)
    local spread = 1 - (1 - p) * (1 - p)
    local rw = (POOL_R0 + (POOL_R1 - POOL_R0) * spread) * yd
    ns.ReplayLayersView.Sharp(s.pool, rw)
    local np = 0
    if look.puffs then np = Puffs(s, sx, sy, yd, tilt, i, s1, s2, 1 - q) end
    if Puff(s.pool, sx, sy, rw, tilt, 1) then
        local r, g, b, al = Kit.Color(look.pool)
        al = (al or 1) * min(1, p / POOL_IN) * (1 - max(0, (p - POOL_OUT) / (1 - POOL_OUT)))
        s.pool:SetVertexColor(r, g, b, al)
        stats.poolW, stats.poolA = rw * 2, al
    end
    stats.meltW, stats.meltH = w, h
    return np
end
local function Paint(s, key, look)
    if s.look == key then return end
    s.look = key
    s.dark:SetVertexColor(Kit.Color(look.dark))
    s.lit:SetVertexColor(Kit.Color(look.lit))
    s.hi:SetVertexColor(Kit.Color(look.hi))
end
function V.Place(scene, cam, t)
    if not view then return end
    local list = scene.layers and scene.layers.adds
    local n, nb, np, ns_, nd = 0, 0, 0, 0, 0
    stats.hp = 0
    hw, hh = cam.w / 2, cam.h / 2
    for i = 1, list and #list or 0 do
        local a = list[i]
        if n >= GAS_DRAW then break end
        local look = a.look and LOOK[a.look]
        local die = look and a.died and a.to <= t and t - a.to < DIE and (t - a.to) / DIE or nil
        if look and a.from <= t and (a.to > t or die) then
            local x, y = Replay.PosHold(a, die and a.to or t, HOLD)
            local sx, sy, k = -1, 0, 0
            if x >= 0 then sx, sy, k = Replay.Project(cam, x, y) end
            if k > 0 then
                n = n + 1
                local s = slots[n]
                Paint(s, a.look, look)
                local yd = scene.ppy * cam.zoom * k
                local tilt = min(1, cam.tilt * k)
                local ph = i * 1.7
                local s1, s2 = sin(t * BREATH + ph), sin(t * BREATH * 1.37 + ph * 2)
                if not look.puffs then
                    nb = nb + 1
                    for p = 1, PUFFS do s.puff[p]:Hide() end
                end
                if die then
                    np = np + Melt(s, look, sx, sy, yd, tilt, die, i, s1, s2)
                    nd = nd + 1
                else
                    s.pool:Hide()
                    if look.puffs then np = np + Puffs(s, sx, sy, yd, tilt, i, s1, s2, 1) end
                    local w = BLOB_YD * yd * (1 + BREATH_K * s1)
                    local h = BLOB_YD * yd * (1 - BREATH_K * 0.8 * s1)
                    local lean = Lean(a, cam, t, sx, yd)
                    Body(s, sx, sy, w, h, lean, 1)
                    stats.bodyW, stats.lean = w, lean
                    local up = PlaceHp(s, a, t, sx, sy, yd, tilt, h * GROUND)
                    local id = ns.ReplayLayers.AddDebuff(a, t)
                    if id then
                        if s.slowId ~= id then
                            Kit.Icon.Spell(s.slow, id)
                            s.slowId = id
                        end
                        s.slow:ClearAllPoints()
                        s.slow:SetPoint("BOTTOM", view, "CENTER", sx, -(sy - h * GROUND - 2) + up)
                        s.slow:Show()
                        ns_ = ns_ + 1
                    else
                        s.slow:Hide()
                    end
                end
            end
        end
    end
    if n < used then HideFrom(n) end
    used = n
    stats.gas, stats.blob, stats.puffs, stats.slow, stats.melt = n - nb, nb, np, ns_, nd
end
