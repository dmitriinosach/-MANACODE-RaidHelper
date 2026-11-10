local ADDON, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local huge = math.huge
local format = string.format
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local CONE = ART .. "cone"
local RIM = ART .. "rim"
local SHARP = {
    rim = { ART .. "rim512", 80 }, ring256 = { ART .. "ring512", 160 }, ring128 = { ART .. "ring512", 96 },
    disc256 = { ART .. "disc512", 160 }, disc128 = { ART .. "disc512", 96 },
}
local RING = ART .. "ring256"
local LINE = ART .. "line"
local ICICLE = ART .. "icicle"
local STREAK = ART .. "streak"
local BEAM = ART .. "beam"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POOL_DRAW = 48
local AIM_DRAW = 2
local WAVE_DRAW = 6
local CONE_DRAW = 8
local BLAST_DRAW = 16
local ADD_DRAW = 48
local LINE_DRAW = 12
local AGGRO_W = 5
local AGGRO_HL = 14
local AGGRO_HW = 13
local AGGRO_GAP = 8
local AGGRO_SIDE = 4
local AGGRO_RING = 0.8
local THR_DRAW = 6
local THR_WARN = 80
local THR_HOT = 90
local HIT_DRAW = 32
local HIT_SHOW = 6
local HIT_YD = 3
local BLAST_SHOW = 1
local FADE = 1
local ADD_HOLD = math.huge
local BADGE = 15
local BADGE_ICON = 10
local ROW = BADGE + 1
local BADGE_PAD = (BADGE - BADGE_ICON) / 2
local BADGES = 3
local FX_SHOW = 7
local FX_POOL = 12
local FX_MAX = 32
local KEY_B = 1024
local LIFT_PX = 14
local LINE_W = 3
local PACT_GAP = 1
local MAX_PX = 4000
local SPIKE_W = 10
local SPIKE_UP = 12
local COUNT_DRAW = 8
local CHASE_DRAW = 12
local CHASE_YD = 1.6
local RING_DRAW = 12
local ceil = math.ceil
local BOMB_TOP = 30
local BOMB_H = 20
local BOMB_ICON = 16
local BOMB_EDGE = 3
local BOMB_PAD = 6
local SPIN_TEX = "Creature\\VOIDWALKER\\TORNADO2C"
local VORTEX_DRAW = 4
local VORTEX_SPIN = 1.6
local VORTEX_SWIRL = 1.1
local VORTEX_WAVE = 0.5
local DROP_DRAW = 4
local DROP_UP, DROP_SIDE = 34, 20
local ICICLE_LEN, ICICLE_W = 5, 1.3
local TRAIL_LEN = 12
local BOOM_W, BOOM_H, BOOM_SHOW = 7, 26, 1.2
local V = {}
ns.ReplayLayersView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Affine = RD.Affine
local Replay = ns.Replay
local Layers = ns.ReplayLayers
local Shield = ns.ReplayShield
local pools, cones, blasts, lines, hits = {}, {}, {}, {}, {}
local counts, chaseLines, chaseRings, addRings = {}, {}, {}, {}
local aimRings = {}
local winter = { waves = {}, rs = {}, as = {} }
local vortex = { fill = {}, edge = {}, swirl = {}, wave = {} }
local drop = { ice = {}, trail = {}, aim = {}, beam = {} }
local hitbox
local bomb
local used = { pool = 0, aim = 0, cone = 0, blast = 0, line = 0, hit = 0, count = 0, chase = 0, ring = 0, wave = 0, addRing = 0,
               vortex = 0, vortexWave = 0, drop = 0, boom = 0 }
local view, marks
local hw, hh = 0, 0
local top1, top2, top3, topN = {}, {}, {}, {}
local low = { {}, {}, {}, n = {} }
local badgeSeen, fxSeen = {}, {}
local badgeIcons = {}
local flagSpike, flagMc, flagLift, flagHalo, flagGrow = {}, {}, {}, {}, {}
local flagLook = {}
local ccAt = {}
local Cc = ns.ReplayCcView
local memo = { L = nil, from = 0, to = -1, np = 0, fk = 0, nfx = 0 }
local fxList = {}
local focusName
local fxRow = { tex = {}, more = nil, owner = nil, key = nil }
local pactK, pactFrom = {}, {}
local aggro, aggroHead, aggroRing
local thrRings = {}
local stats = { aggro = 0, thr = 0, badges = 0, pools = 0, aims = 0, cones = 0, blasts = 0, adds = 0, counts = 0, countTop = nil, chases = 0,
                chaseLines = 0, waves = 0, edge = 0, waveR = 0, collects = 0, addRings = 0, fx = 0, vortex = 0,
                vortexWave = 0, drops = 0, booms = 0 }
V.stats = stats
local mode = { bright = 1, lift = nil, liftK = nil, fx = FX_SHOW, extra = nil, aggro = 1, swap = 0 }
local extraIds = {}
local fxIcons = {}
local exSeen = {}
local swapAt = { hk = 0, t = -1e9, last = -1e9 }
local function Bright(a)
    a = a * mode.bright
    if a > 1 then return 1 end
    return a
end
local cursors = setmetatable({}, { __mode = "k" })
local function Cursor(L, t)
    local c = cursors[L]
    if not c then
        c = { t = huge, act = {}, hi = 0, blast = 1, cone = 1, hit = 1 }
        cursors[L] = c
    end
    if t < c.t then
        c.blast, c.cone, c.hit, c.hi = 1, 1, 1, 0
        local act = c.act
        for i = #act, 1, -1 do act[i] = nil end
    end
    c.t = t
    return c
end
local function FromOrder(a, b, F)
    if F[a] ~= F[b] then return F[a] < F[b] end
    return a < b
end
local function ActivePools(L, t)
    local c = Cursor(L, t)
    local np = L.np
    local F, T = L.plFrom, L.plTo
    local act = c.act
    if c.np ~= np then
        local ord = {}
        for j = 1, np do ord[j] = j end
        table.sort(ord, function(a, b) return FromOrder(a, b, F) end)
        c.ord, c.np, c.hi = ord, np, 0
        for i = #act, 1, -1 do act[i] = nil end
    end
    local ord, hi = c.ord, c.hi
    while hi < np and F[ord[hi + 1]] <= t do
        hi = hi + 1
        local j = ord[hi]
        if T[j] > t then
            local n = #act
            act[n + 1] = j
            while n >= 1 and act[n] > j do
                act[n + 1], act[n] = act[n], j
                n = n - 1
            end
        end
    end
    c.hi = hi
    local w = 0
    for r = 1, #act do
        local j = act[r]
        if T[j] > t then
            w = w + 1
            act[w] = j
        end
    end
    for r = #act, w + 1, -1 do act[r] = nil end
    return act
end
local function RingAdds(L, defs)
    local list = L.adds
    local c = cursors[L] or Cursor(L, huge)
    local n = list and #list or 0
    if c.ringN ~= n or c.ringDefs ~= defs then
        local out = {}
        for i = 1, n do
            local a = list[i]
            if a.npc and defs[a.npc] then out[#out + 1] = i end
        end
        c.rings, c.ringN, c.ringDefs = out, n, defs
    end
    return c.rings
end
local function PutRect(tex, l, t, r, b, u0, v0, u1, v1)
    local cl, ct, cr, cb = max(l, -hw), max(t, -hh), min(r, hw), min(b, hh)
    if cr - cl < 1 or cb - ct < 1 then
        tex:Hide()
        return false
    end
    local w, h = r - l, b - t
    local a0 = u0 + (u1 - u0) * (cl - l) / w
    local a1 = u0 + (u1 - u0) * (cr - l) / w
    local b0 = v0 + (v1 - v0) * (ct - t) / h
    local b1 = v0 + (v1 - v0) * (cb - t) / h
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", view, "CENTER", cl, -ct)
    tex:SetWidth(cr - cl)
    tex:SetHeight(cb - ct)
    tex:SetTexCoord(a0, b0, a0, b1, a1, b0, a1, b1)
    tex:Show()
    return true
end
local function PutEllipse(tex, sx, sy, rw, rh)
    if rw * 2 > MAX_PX then return false end
    V.Sharp(tex, rw)
    return PutRect(tex, sx - rw, sy - rh, sx + rw, sy + rh, 0, 0, 1, 1)
end
local function PutAffine(tex, ox, oy, ux, uy, vx, vy)
    if not view then return false end
    return Affine(tex, view, hw, hh, ox, oy, ux, uy, vx, vy)
end
local Tex = RD.Tex
function V.Build(v, m, focusLayer)
    view, marks = v, m
    Cc.Build(marks)
    for i = 1, POOL_DRAW do pools[i] = Tex(marks, RIM, "BACKGROUND") end
    for i = 1, AIM_DRAW do aimRings[i] = Tex(marks, RING, "BORDER") end
    for i = 1, RING_DRAW do addRings[i] = Tex(marks, RIM, "BACKGROUND") end
    for i = 1, WAVE_DRAW do winter.waves[i] = Tex(marks, RING, "BORDER") end
    winter.edge = Tex(marks, RING, "BORDER")
    for i = 1, DROP_DRAW do
        drop.aim[i] = Tex(marks, LINE, "BORDER", "sem.rep.icicleAim")
        drop.trail[i] = Tex(marks, STREAK, "OVERLAY", "sem.rep.icicleTrail")
        drop.ice[i] = Tex(marks, ICICLE, "OVERLAY", "sem.rep.icicle")
        drop.beam[i] = Tex(marks, BEAM, "OVERLAY", "sem.rep.icicleBoom")
    end
    for i = 1, VORTEX_DRAW do
        vortex.fill[i] = Tex(marks, RIM, "BACKGROUND")
        vortex.swirl[i] = Tex(marks, SPIN_TEX, "BORDER")
        vortex.edge[i] = Tex(marks, RING, "BORDER")
        vortex.wave[i] = Tex(marks, RING, "BORDER")
    end
    for i = 1, HIT_DRAW do hits[i] = Tex(marks, CIRCLE, "BORDER", "sem.rep.hit") end
    for i = 1, LINE_DRAW do lines[i] = Tex(marks, LINE, "BORDER", "sem.rep.pact") end
    aggro = Tex(marks, LINE, "BORDER", "sem.rep.aggro")
    aggroHead = Tex(marks, CONE, "BORDER", "sem.rep.aggro")
    aggroRing = Tex(marks, RING, "BORDER", "sem.rep.aggro")
    for i = 1, THR_DRAW do thrRings[i] = Tex(marks, RING, "BORDER") end
    for i = 1, CONE_DRAW do cones[i] = Tex(marks, CONE, "ARTWORK", "sem.rep.cone") end
    for i = 1, BLAST_DRAW do blasts[i] = Tex(marks, RIM, "ARTWORK", "sem.rep.blast") end
    for i = 1, CHASE_DRAW do
        chaseRings[i] = Tex(marks, RIM, "BORDER", "sem.rep.chase")
        chaseLines[i] = Tex(marks, LINE, "BORDER", "sem.rep.chase")
    end
    for i = 1, COUNT_DRAW do
        local fs = marks:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        Kit.Text(fs, "sem.rep.count")
        fs:Hide()
        counts[i] = fs
    end
    hitbox = Tex(marks, RIM, "BACKGROUND", "sem.rep.hitbox")
    bomb = Kit.PlainFrame(v, 8)
    bomb:SetHeight(BOMB_H)
    bomb:SetPoint("TOP", v, "TOP", 0, -BOMB_TOP)
    local bg = bomb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bomb)
    Kit.Paint(bg, "sem.rep.plate")
    local edge = bomb:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT", bomb, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", bomb, "BOTTOMLEFT", 0, 0)
    edge:SetWidth(BOMB_EDGE)
    Kit.Paint(edge, "sem.rep.bomb")
    bomb.icon = bomb:CreateTexture(nil, "ARTWORK")
    bomb.icon:SetWidth(BOMB_ICON)
    bomb.icon:SetHeight(BOMB_ICON)
    bomb.icon:SetPoint("LEFT", bomb, "LEFT", BOMB_EDGE + BOMB_PAD, 0)
    bomb.text = bomb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bomb.text:SetPoint("LEFT", bomb.icon, "RIGHT", BOMB_PAD / 2, 0)
    Kit.Text(bomb.text, "text.bad")
    bomb:Hide()
    focusLayer = focusLayer or m
    for i = 1, FX_POOL do fxRow.tex[i] = V.Badge(focusLayer) end
    fxRow.more = focusLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fxRow.more:Hide()
end
function V.Sharp(tex, rw)
    local key = tex.sharpKey
    if key == nil then
        local p = tex.GetTexture and tex:GetTexture()
        key = type(p) == "string" and strlower(p):gsub("%.%a+$", ""):match("([%w_]+)$") or false
        if key and not SHARP[key] then key = false end
        tex.sharpKey, tex.sharpSmall = key, p
    end
    if not key then return end
    local big = SHARP[key]
    local want = rw > big[2] and big[1] or tex.sharpSmall
    if tex.sharpP ~= want then
        tex:SetTexture(want)
        tex.sharpP = want
    end
end
local function BadgeRow(fig)
    local bd = {}
    for i = 1, BADGES do bd[i] = V.Badge(fig) end
    bd[2]:SetPoint("RIGHT", bd[1], "LEFT", -(ROW - BADGE_ICON), 0)
    bd[3]:SetPoint("LEFT", bd[1], "RIGHT", ROW - BADGE_ICON, 0)
    local more = fig:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    more:SetPoint("LEFT", bd[3], "RIGHT", BADGE_PAD + 1, 0)
    more:Hide()
    return bd, more
end
function V.AddDebuff(fig, id, c1, c2, c3, n)
    n = (n or 0) + (id and 1 or 0)
    local a, b, c
    if id then a, b, c = id, c1 or false, c2 or false else a, b, c = c1 or false, c2 or false, c3 or false end
    local bd = fig.adb
    if n == 0 then
        if bd and fig.adbN ~= 0 then
            for i = 1, BADGES do V.BadgeShow(bd[i], false) end
            fig.adbMore:Hide()
            fig.adbN, fig.adbA, fig.adbB, fig.adbC = 0, nil, nil, nil
        end
        return
    end
    if not bd then
        bd, fig.adbMore = BadgeRow(fig)
        fig.adb = bd
        fig.adbAt = nil
    end
    local at = fig.bdBase or fig.addHpBg or fig.icon
    if fig.adbAt ~= at then
        fig.adbAt = at
        bd[1]:ClearAllPoints()
        bd[1]:SetPoint("BOTTOM", at, "TOP", 0, BADGE_PAD + 1)
    end
    if fig.adbN == n and fig.adbA == a and fig.adbB == b and fig.adbC == c then return end
    fig.adbN, fig.adbA, fig.adbB, fig.adbC = n, a, b, c
    for i = 1, BADGES do
        local id = i == 1 and a or (i == 2 and b or c)
        if id then Kit.Icon.Spell(bd[i], id) end
        V.BadgeShow(bd[i], id and true or false)
    end
    if n > BADGES then
        fig.adbMore:SetText("+" .. (n - BADGES))
        fig.adbMore:Show()
    else
        fig.adbMore:Hide()
    end
end
function V.BadgesUp(fig)
    return fig.rowsUp or 0
end
function V.Badge(fig)
    local tex = fig:CreateTexture(nil, "ARTWORK")
    tex:SetWidth(BADGE_ICON)
    tex:SetHeight(BADGE_ICON)
    tex:Hide()
    local disc = fig:CreateTexture(nil, "BORDER")
    disc:SetTexture(CIRCLE)
    Kit.Tint(disc, "sem.rep.castBg")
    disc:SetWidth(BADGE)
    disc:SetHeight(BADGE)
    disc:SetPoint("CENTER", tex, "CENTER", 0, 0)
    disc:Hide()
    local ring = fig:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(RING)
    Kit.Tint(ring, "sem.rep.badgeRim")
    ring:SetWidth(BADGE)
    ring:SetHeight(BADGE)
    ring:SetPoint("CENTER", tex, "CENTER", 0, 0)
    ring:Hide()
    tex.disc, tex.ring = disc, ring
    return tex
end
function V.BadgeShow(tex, on)
    if (tex.bOn or false) == on then return end
    tex.bOn = on
    if on then
        tex:Show()
        tex.disc:Show()
        tex.ring:Show()
    else
        tex:Hide()
        tex.disc:Hide()
        tex.ring:Hide()
    end
end
function V.Attach(fig)
    fig.bdBase = fig:CreateTexture(nil, "BACKGROUND")
    fig.bdBase:SetWidth(1)
    fig.bdBase:SetHeight(1)
    fig.bdBase:SetPoint("BOTTOM", fig.icon, "TOP", 0, 0)
    fig.bd, fig.more = BadgeRow(fig)
    fig.adb, fig.adbMore = BadgeRow(fig)
    fig.bd[1]:SetPoint("BOTTOM", fig.bdBase, "TOP", 0, BADGE_PAD + 1)
    fig.rowsLow, fig.rowsUp = false, 0
    fig.spike = fig:CreateTexture(nil, "OVERLAY")
    fig.spike:SetTexture(CONE)
    fig.spike:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    fig.spike:SetVertexColor(Kit.Color("sem.rep.bone"))
    fig.spike:SetPoint("BOTTOMLEFT", fig, "CENTER", -SPIKE_W / 2, 0)
    fig.spike:SetPoint("TOPRIGHT", fig.icon, "TOP", SPIKE_W / 2, SPIKE_UP)
    fig.spike:Hide()
    fig.halo = fig:CreateTexture(nil, "BORDER")
    fig.halo:SetTexture(RIM)
    fig.halo:SetVertexColor(Kit.Color("sem.rep.victim"))
    fig.halo:SetPoint("TOPLEFT", fig, "TOPLEFT", -4, 4)
    fig.halo:SetPoint("BOTTOMRIGHT", fig, "BOTTOMRIGHT", 4, -4)
    fig.halo:Hide()
    Cc.Attach(fig)
end
function V.Role(fig)
    memo.L = nil
    fig.bKey, fig.lift, fig.mcOn, fig.grow, fig.look = nil, nil, nil, nil, nil
    fig.dbI1, fig.dbI2, fig.dbI3, fig.dbN = false, false, false, 0
    V.AddDebuff(fig, false)
    for i = 1, BADGES do V.BadgeShow(fig.bd[i], false) end
    fig.more:Hide()
    if fxRow.owner == fig then fxRow.key = nil end
    fig.spike:Hide()
    fig.halo:Hide()
    Cc.Set(fig, nil, nil, nil, nil)
end
function V.Clear(fig)
    if not fig.bd then return end
    V.Role(fig)
end
function V.Use(scene)
    if not view then return end
    for i = 1, #pools do pools[i]:Hide() end
    for i = 1, #aimRings do aimRings[i]:Hide() end
    for i = 1, #cones do cones[i]:Hide() end
    for i = 1, #blasts do blasts[i]:Hide() end
    for i = 1, #lines do lines[i]:Hide() end
    Cc.Clear()
    aggro:Hide()
    aggroHead:Hide()
    aggroRing:Hide()
    for i = 1, #thrRings do thrRings[i]:Hide() end
    for i = 1, #hits do hits[i]:Hide() end
    for i = 1, #counts do counts[i]:Hide() end
    for i = 1, #chaseLines do chaseLines[i]:Hide() end
    for i = 1, #chaseRings do chaseRings[i]:Hide() end
    for i = 1, #addRings do addRings[i]:Hide() end
    for i = 1, #winter.waves do winter.waves[i]:Hide() end
    winter.edge:Hide()
    for i = 1, DROP_DRAW do
        drop.aim[i]:Hide()
        drop.trail[i]:Hide()
        drop.ice[i]:Hide()
        drop.beam[i]:Hide()
    end
    for i = 1, VORTEX_DRAW do
        vortex.fill[i]:Hide()
        vortex.swirl[i]:Hide()
        vortex.edge[i]:Hide()
        vortex.wave[i]:Hide()
    end
    hitbox:Hide()
    bomb:Hide()
    bomb.key = nil
    for k in pairs(used) do used[k] = 0 end
    for k in pairs(stats) do stats[k] = 0 end
    stats.countTop = nil
    memo.L = nil
    for i = 1, FX_POOL do V.BadgeShow(fxRow.tex[i], false) end
    fxRow.more:Hide()
    fxRow.owner, fxRow.key, fxRow.off = nil, nil, nil
    V.scene = scene
end
local function Fade(a, from, to, t)
    local left = to - t
    if left < FADE then a = a * max(0, left / FADE) end
    local born = t - from
    if born < 0.3 then a = a * max(0.3, born / 0.3) end
    return a
end
local function Count(fs, sx, sy, left)
    if sx < -hw or sx > hw or sy < -hh or sy > hh then
        fs:Hide()
        return
    end
    if fs.left ~= left then
        fs.left = left
        fs:SetText(tostring(left))
    end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", view, "CENTER", sx, -sy)
    fs:Show()
    stats.countTop = stats.countTop or left
end
local function PlacePools(scene, cam, t)
    local L = scene.layers
    local n = 0
    local ppy, zoom = scene.ppy, cam.zoom
    local boss = scene.bossState
    local nc = 0
    stats.countTop = nil
    local act = ActivePools(L, t)
    for r = 1, #act do
        local j = act[r]
        if n >= POOL_DRAW then break end
        local def = L.plDef[j]
        if L.plFrom[j] <= t and L.plTo[j] > t and not (def.smoke or def.cloud) then
            local x, y = L.plX[j], L.plY[j]
            if def.follow then x, y = boss.vis and boss.x or -1, boss.y end
            if x >= 0 then
                local sx, sy, k = Replay.Project(cam, x, y)
                if k > 0 then
                    local rw = Layers.PoolRadius(L, j, t) * ppy * zoom * k
                    local tex = pools[n + 1]
                    if PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                        n = n + 1
                        local r, g, b, a = Kit.Color(def.tone)
                        a = Bright(a)
                        local solid = def.fade and L.plSolid and L.plSolid[j]
                        if solid and t > solid then a = a * (L.plTo[j] - t) / (L.plTo[j] - solid) end
                        tex:SetVertexColor(r, g, b, Fade(a, L.plFrom[j], L.plTo[j], t))
                        if def.boom and nc < COUNT_DRAW then
                            nc = nc + 1
                            Count(counts[nc], sx, sy, max(0, ceil(def.boom - t)))
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, used.pool do pools[i]:Hide() end
    for i = nc + 1, used.count do counts[i]:Hide() end
    used.pool, used.count = n, nc
    stats.pools, stats.counts = n, nc
end
local function PlaceAims(scene, cam, t)
    local L = scene.layers
    local A, K = L.plAimT, L.plAimK
    local n = 0
    for j = 1, A and L.np or 0 do
        if n >= AIM_DRAW then break end
        local from = A[j]
        local s = from and from <= t and L.plFrom[j] > t and scene.states[K[j]]
        if s and s.vis then
            local sx, sy, k = Replay.Project(cam, s.x, s.y)
            local def = L.plDef[j]
            local rw = def.r0 * scene.ppy * cam.zoom * k
            local tex = aimRings[n + 1]
            if k > 0 and PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                n = n + 1
                local r, g, b, a = Kit.Color(def.ring or def.tone)
                a = Bright(a)
                tex:SetVertexColor(r, g, b, Fade(a, from, L.plFrom[j] + FADE, t))
            end
        end
    end
    for i = n + 1, used.aim do aimRings[i]:Hide() end
    used.aim = n
    stats.aims = n
end
local function PlaceChase(scene, cam, t)
    local C = scene.layers.chase
    local nl, nr = 0, 0
    for i = 1, C and C.n or 0 do
        if nr >= CHASE_DRAW then break end
        local s = C.from[i] <= t and C.to[i] > t and scene.states[C.k[i]]
        if s and s.vis then
            local tx, ty, kt = Replay.Project(cam, s.x, s.y)
            if kt > 0 then
                local rw = CHASE_YD * scene.ppy * cam.zoom * kt
                if PutEllipse(chaseRings[nr + 1], tx, ty, rw, max(1, rw * min(1, cam.tilt * kt))) then nr = nr + 1 end
                local add = C.add[i]
                local ax, ay = -1, -1
                if add and add.from <= t and add.to > t then ax, ay = Replay.PosHold(add, t, ADD_HOLD) end
                if ax >= 0 then
                    local sx, sy, ka = Replay.Project(cam, ax, ay)
                    local dx, dy = tx - sx, ty - sy
                    local d = sqrt(dx * dx + dy * dy)
                    if ka > 0 and d >= 2 then
                        local nx, ny = -dy / d * LINE_W * 2, dx / d * LINE_W * 2
                        if PutAffine(chaseLines[nl + 1], sx - nx / 2, sy - ny / 2, dx, dy, nx, ny) then nl = nl + 1 end
                    end
                end
            end
        end
    end
    for i = nl + 1, used.chase do chaseLines[i]:Hide() end
    for i = nr + 1, used.ring do chaseRings[i]:Hide() end
    used.chase, used.ring = nl, nr
    stats.chases, stats.chaseLines = nr, nl
end
local function PlaceRings(scene, cam, t)
    local list = scene.layers.adds
    local defs = ns.replayData.rings
    local RV = ns.ReplayRealmView
    local n = 0
    local idx = RingAdds(scene.layers, defs)
    for r = 1, #idx do
        if n >= RING_DRAW then break end
        local a = list[idx[r]]
        local def = a.npc and defs[a.npc]
        local to = a.to or huge
        if def and a.from <= t and to > t and not (RV and RV.HideAdd(scene, a)) then
            local x, y = Replay.PosHold(a, t, ADD_HOLD)
            local sx, sy, k = 0, 0, 0
            if x >= 0 then sx, sy, k = Replay.Project(cam, x, y) end
            if k > 0 then
                local rw = def.r * scene.ppy * cam.zoom * k
                local tex = addRings[n + 1]
                if PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                    n = n + 1
                    local r, g, b, a0 = Kit.Color(def.tone)
                    a0 = Bright(a0)
                    tex:SetVertexColor(r, g, b, Fade(a0, a.from, to, t))
                end
            end
        end
    end
    for i = n + 1, used.addRing do addRings[i]:Hide() end
    used.addRing = n
    stats.addRings = n
end
local function PlaceBlasts(scene, cam, t)
    local L = scene.layers
    local n = 0
    local zoom = cam.zoom
    local c = Cursor(L, t)
    local lo = c.blast
    while lo <= L.nb and L.bT[lo] + BLAST_SHOW <= t do lo = lo + 1 end
    c.blast = lo
    for j = lo, L.nb do
        if n >= BLAST_DRAW or L.bT[j] > t then break end
        if L.bT[j] + BLAST_SHOW > t then
            local sx, sy, k = Replay.Project(cam, L.bX[j], L.bY[j])
            if k > 0 then
                local rw = L.bR[j] * zoom * k
                local tex = blasts[n + 1]
                if PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                    n = n + 1
                    tex:SetVertexColor(Kit.Color(L.bTone[j] or "sem.rep.blast"))
                    tex:SetAlpha(Bright(0.25 + 0.75 * (1 - (t - L.bT[j]) / BLAST_SHOW)))
                end
            end
        end
    end
    for i = n + 1, used.blast do blasts[i]:Hide() end
    used.blast = n
    stats.blasts = n
end
local function PlaceCones(scene, cam, t)
    local L = scene.layers
    local n = 0
    local c = Cursor(L, t)
    local lo = c.cone
    while lo <= L.nc and L.cnTo[lo] <= t do lo = lo + 1 end
    c.cone = lo
    for j = lo, L.nc do
        if n >= CONE_DRAW or L.cnT[j] > t then break end
        if L.cnTo[j] > t and L.cnX[j] >= 0 then
            local ox, oy = L.cnX[j], L.cnY[j]
            local len = L.cnLen[j]
            local lx, ly, rx, ry = Layers.ConeEdges(L.cnDeg[j], L.cnHx[j], L.cnHy[j])
            local ax, ay, ka = Replay.Project(cam, ox, oy)
            local bx, by, kb = Replay.Project(cam, ox + lx * len, oy + ly * len)
            local cx, cy, kc = Replay.Project(cam, ox + rx * len, oy + ry * len)
            if ka > 0 and kb > 0 and kc > 0 then
                local mx, my = (bx + cx) / 2, (by + cy) / 2
                local ux, uy = mx - ax, my - ay
                local vx, vy = cx - bx, cy - by
                local tex = cones[n + 1]
                if PutAffine(tex, ax - vx / 2, ay - vy / 2, ux, uy, vx, vy) then
                    n = n + 1
                    local r, g, b, a = Kit.Color(L.cnTone[j] or "sem.rep.cone")
                    a = Bright(a)
                    tex:SetVertexColor(r, g, b, Fade(a, L.cnT[j], L.cnTo[j], t))
                end
            end
        end
    end
    for i = n + 1, used.cone do cones[i]:Hide() end
    used.cone = n
    stats.cones = n
end
local ccTop = {}
function V.Adds(scene, t, out)
    local list = scene.layers.adds
    local RV = ns.ReplayRealmView
    local n = 0
    for i = 1, #list do
        if n >= ADD_DRAW then break end
        local a = list[i]
        if a.from <= t and a.to > t and not a.look and not (RV and RV.HideAdd(scene, a))
            and not (a.cK and Layers.CarryAt(a, t)) then
            local x, y, chase = -1, -1, false
            if a.chaseK and t < a.chaseTo then
                x, y = Replay.PosAtTime(scene.tracks[a.chaseK], t)
                chase = true
            else
                x, y = Replay.PosHold(a, t, ADD_HOLD)
            end
            if x >= 0 then
                n = n + 1
                out.x[n], out.y[n], out.icon[n], out.chase[n] = x, y, a.icon, chase
                out.hp[n] = a.boss and Layers.BossHp(scene, t, a.realm) or Layers.AddHp(a, t)
                out.debuff[n] = Layers.AddDebuff(a, t) or false
                if out.cc1 then
                    local cnt = Layers.AddCc(a, t, ccTop)
                    local list = ns.replayData.addCcList
                    out.cc1[n] = ccTop[1] and list[a.ccS[ccTop[1]]].icon or false
                    out.cc2[n] = ccTop[2] and list[a.ccS[ccTop[2]]].icon or false
                    out.cc3[n] = ccTop[3] and list[a.ccS[ccTop[3]]].icon or false
                    out.ccN[n], out.add[n] = cnt, a
                end
                if out.k then out.k[n], out.rim[n] = a.big or 1, a.rim or false end
                if out.boss then
                    out.boss[n] = a.boss and a.name or false
                    out.ghost[n], out.dusk[n] = false, false
                    if RV then out.ghost[n], out.dusk[n] = RV.AddLook(a) end
                end
            end
        end
    end
    return n
end
local function Rows(fig)
    local b = fig.bd
    local up = b[1].bOn or b[2].bOn or b[3].bOn or (fxRow.owner == fig and (fxRow.shown or 0) > 0)
    local low = (fig.adbN or 0) > 0
    if fig.rowsLow ~= low then
        fig.rowsLow = low
        b[1]:ClearAllPoints()
        b[1]:SetPoint("BOTTOM", fig.bdBase, "TOP", 0, (low and ROW or 0) + BADGE_PAD + 1)
    end
    fig.rowsUp = (up and ROW or 0) + (low and ROW or 0)
end
function V.Carry(scene, t, figs)
    local L = scene.layers
    local of = L.carryOf
    local list = ns.replayData.addCcList
    for k = 1, #scene.tracks do
        local fig = figs[k]
        local a = of and of[k] and fig and fig.bd and Layers.CarriedBy(L, k, t)
        if a then
            local cnt = Layers.AddCc(a, t, ccTop)
            V.AddDebuff(fig, false, ccTop[1] and list[a.ccS[ccTop[1]]].icon or false,
                ccTop[2] and list[a.ccS[ccTop[2]]].icon or false, ccTop[3] and list[a.ccS[ccTop[3]]].icon or false, cnt)
        elseif fig and fig.bd then
            V.AddDebuff(fig, false, fig.dbI1 or false, fig.dbI2 or false, fig.dbI3 or false, fig.dbN or 0)
        end
        if fig and fig.bd then Rows(fig) end
    end
end
local function PlaceHits(scene, cam, t)
    local L = scene.layers
    local n = 0
    local w0 = 2 * HIT_YD * scene.ppy * cam.zoom
    local lo = t - HIT_SHOW
    local c = Cursor(L, t)
    local first = c.hit
    while first <= L.nh and L.hiT[first] < lo do first = first + 1 end
    c.hit = first
    for i = first, L.nh do
        if n >= HIT_DRAW or L.hiT[i] > t then break end
        if L.hiT[i] >= lo then
            local sx, sy, k = Replay.Project(cam, L.hiX[i], L.hiY[i])
            if k > 0 then
                local tex = hits[n + 1]
                local w = w0 * k
                if PutEllipse(tex, sx, sy, w / 2, max(1, w * min(1, cam.tilt * k) / 2)) then
                    n = n + 1
                    tex:SetAlpha(0.2 + 0.6 * (1 - (t - L.hiT[i]) / HIT_SHOW))
                end
            end
        end
    end
    for i = n + 1, used.hit do hits[i]:Hide() end
    used.hit = n
end
local function PlaceHitbox(scene, cam)
    local b = scene.bossState
    local R = scene.layers.hitbox * scene.ppy
    if not b.vis or R <= 0 then
        hitbox:Hide()
        return
    end
    local sx, sy, k = Replay.Project(cam, b.x, b.y)
    if k <= 0 then
        hitbox:Hide()
        return
    end
    local rw = R * cam.zoom * k
    PutEllipse(hitbox, sx, sy, rw, max(1, rw * min(1, cam.tilt * k)))
end
local function PlaceBomb(L, t)
    local list, def = L.bombs, L.bombDef
    local left
    for i = 1, list and #list or 0 do
        local d = list[i].t - t
        if d >= 0 and d <= def.lead then
            left = d
            break
        end
    end
    stats.bomb = left
    if not left then
        if bomb.key then
            bomb.key = nil
            bomb:Hide()
        end
        return
    end
    local key = floor(left * 10)
    if bomb.key == key then return end
    if not bomb.key then Kit.Icon.Spell(bomb.icon, def.icon) end
    bomb.key = key
    bomb.str = format(ns.T("rep.bomb"), GetSpellInfo(def.icon) or "", ns.Dec(format("%.1f", key / 10)))
    bomb.text:SetText(bomb.str)
    bomb:SetWidth(BOMB_EDGE + BOMB_PAD * 2 + BOMB_ICON + BOMB_PAD / 2 + (bomb.text:GetStringWidth() or 0))
    bomb:Show()
end
function V.BombText()
    return bomb and bomb.key and bomb.str or nil
end
local function BadgeIcon(id)
    if not id then return Kit.QMARK end
    local icon = badgeIcons[id]
    if not icon then
        icon = ns.SpellIcon(id) or Kit.QMARK
        badgeIcons[id] = icon
    end
    return icon
end
local function Prio(s, k)
    local def = Layers.State(s)
    local lift = mode.lift
    if lift and mode.liftK and mode.liftK[k] then return def.prio + (lift[def.name] or 0) end
    return def.prio
end
local function Collect(L, n, t, fk)
    for icon in pairs(fxSeen) do fxSeen[icon] = nil end
    for k = 1, n do
        local seen = badgeSeen[k]
        if seen then
            for icon in pairs(seen) do seen[icon] = nil end
        else
            badgeSeen[k] = {}
        end
        top1[k], top2[k], top3[k], topN[k] = -1, -1, -1, 0
        low[1][k], low[2][k], low[3][k], low.n[k] = -1, -1, -1, 0
        flagSpike[k], flagMc[k], flagLift[k], flagHalo[k] = false, false, false, false
        flagGrow[k] = false
        flagLook[k] = false
        ccAt[k] = -1
    end
    local np, nx, nfx = 0, huge, 0
    for i = 1, L.ns do
        local from, k, s = L.stFrom[i], L.stK[i], L.stS[i]
        local def = Layers.State(s)
        local mine = not def.focus or k == fk
        if mine and from > t then
            if from < nx then nx = from end
            break
        end
        local to = L.stTo[i]
        if not mine or to <= t then def = nil end
        if def and to < nx then nx = to end
        if def and def.focus then
            local icon = BadgeIcon(def.icon)
            if nfx < FX_MAX and not fxSeen[icon] then
                fxSeen[icon] = true
                nfx = nfx + 1
                fxList[nfx] = s
            end
            def = nil
        end
        local look = def and Shield.Of(s)
        if look and Shield.Prio(look) > Shield.Prio(flagLook[k] or nil) then flagLook[k] = look end
        if def and def.cc and (ccAt[k] < 0 or def.prio >= Layers.State(L.stS[ccAt[k]]).prio) then ccAt[k] = i end
        if def and not def.bare and not def.ccLook then
            if def.grow then flagGrow[k] = true end
            local seen = badgeSeen[k]
            local icon = BadgeIcon(def.icon)
            if not seen[icon] then
                seen[icon] = true
                local t1, t2, t3, tn = top1, top2, top3, topN
                if def.cc or def.debuff then t1, t2, t3, tn = low[1], low[2], low[3], low.n end
                tn[k] = tn[k] + 1
                local p = Prio(s, k)
                local a, b = t1[k], t2[k]
                if a < 0 or p > Prio(a, k) then
                    t1[k], t2[k], t3[k] = s, a, b
                elseif b < 0 or p > Prio(b, k) then
                    t2[k], t3[k] = s, b
                elseif t3[k] < 0 or p > Prio(t3[k], k) then
                    t3[k] = s
                end
            end
            if def.spike then flagSpike[k] = true end
            if def.mc then flagMc[k] = true end
            if def.lift then flagLift[k] = true end
            if def.link then
                np = np + 1
                pactK[np], pactFrom[np] = k, L.stFrom[i]
            end
        end
    end
    for i = 1, L.nv do
        local vt = L.vT[i]
        if vt > t then
            if vt < nx then nx = vt end
            break
        end
        if vt + BLAST_SHOW > t then
            flagHalo[L.vK[i]] = true
            if vt + BLAST_SHOW < nx then nx = vt + BLAST_SHOW end
        end
    end
    return np, nx, nfx
end
local function DecorateFx(fig, nfx, k)
    if not fig then nfx = 0 end
    for i = 2, nfx do
        local s = fxList[i]
        local p = Layers.State(s).prio
        local j = i - 1
        while j >= 1 and Layers.State(fxList[j]).prio < p do
            fxList[j + 1] = fxList[j]
            j = j - 1
        end
        fxList[j + 1] = s
    end
    local n = 0
    for icon in pairs(exSeen) do exSeen[icon] = nil end
    local hidden = 0
    if fig and k and k > 0 then
        for i = 1, BADGES do
            local s = i == 1 and top1[k] or (i == 2 and top2[k] or top3[k])
            if s >= 0 then
                n = n + 1
                fxIcons[n] = Layers.State(s).icon
                exSeen[BadgeIcon(fxIcons[n])] = true
            end
        end
        hidden = max(0, topN[k] - BADGES)
    end
    for i = 1, nfx do
        local icon = Layers.State(fxList[i]).icon
        if not exSeen[BadgeIcon(icon)] then
            n = n + 1
            fxIcons[n] = icon
            exSeen[BadgeIcon(icon)] = true
        end
    end
    local nex = fig and memo.nex or 0
    for i = 1, nex do
        local id = extraIds[i]
        local icon = BadgeIcon(id)
        if not exSeen[icon] then
            exSeen[icon] = true
            n = n + 1
            fxIcons[n] = id
        end
    end
    nfx = n
    for i = n + 1, #fxIcons do fxIcons[i] = nil end
    local cap = mode.fx
    local key = table.concat(fxIcons, ",", 1, nfx) .. "|" .. cap .. "|" .. hidden
    if fxRow.owner == fig and fxRow.key == key then return end
    fxRow.owner, fxRow.key = fig, key
    fxRow.off = fig ~= nil and fig.shown == false
    local shown = fxRow.off and 0 or min(nfx, cap)
    fxRow.shown = shown
    local w = shown * ROW - 1
    for i = 1, FX_POOL do
        local tex = fxRow.tex[i]
        if i <= shown then
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOM", fig.bd[1], "BOTTOM", -w / 2 + BADGE / 2 + (i - 1) * ROW, 0)
            Kit.Icon.Spell(tex, fxIcons[i])
            V.BadgeShow(tex, true)
        else
            V.BadgeShow(tex, false)
        end
    end
    local rest = max(0, nfx - cap) + hidden
    if shown > 0 and rest > 0 then
        fxRow.more:ClearAllPoints()
        fxRow.more:SetPoint("LEFT", fxRow.tex[shown], "RIGHT", BADGE_PAD + 1, 0)
        fxRow.more:SetText("+" .. rest)
        fxRow.more:Show()
    else
        fxRow.more:Hide()
    end
end
local function Decorate(fig, k)
    local mine = k == memo.fk
    local key = (top1[k] + 2) + (top2[k] + 2) * KEY_B + (top3[k] + 2) * KEY_B * KEY_B
        + (topN[k] + (flagSpike[k] and KEY_B or 0)) * KEY_B * KEY_B * KEY_B
    if mine then key = -1 - (flagSpike[k] and 1 or 0) end
    if fig.bKey ~= key then
        fig.bKey = key
        for i = 1, BADGES do
            local s = i == 1 and top1[k] or (i == 2 and top2[k] or top3[k])
            if s >= 0 and not mine then Kit.Icon.Spell(fig.bd[i], Layers.State(s).icon) end
            V.BadgeShow(fig.bd[i], s >= 0 and not mine)
        end
        if topN[k] > BADGES and not mine then
            fig.more:SetText("+" .. (topN[k] - BADGES))
            fig.more:Show()
        else
            fig.more:Hide()
        end
        if flagSpike[k] then fig.spike:Show() else fig.spike:Hide() end
    end
    for i = 1, BADGES do
        local s = low[i][k]
        fig["dbI" .. i] = s >= 0 and Layers.State(s).icon or false
    end
    fig.dbN = low.n[k]
    if flagMc[k] ~= (fig.mcOn or false) then
        fig.mcOn = flagMc[k]
        ns.ReplayFigs.Rim(fig)
    end
    local cc = ccAt[k]
    local ccDef = cc >= 0 and Layers.State(memo.L.stS[cc]) or nil
    local ccKind = ccDef and (ccDef.ccLook or ccDef.hard and "ring") or nil
    local lift = (flagLift[k] or ccKind == "cyclone") and LIFT_PX or nil
    if fig.lift ~= lift then
        fig.lift = lift
        fig.sQ = nil
    end
    fig.grow = flagGrow[k]
    fig.look = flagLook[k] or nil
    if flagHalo[k] then fig.halo:Show() else fig.halo:Hide() end
    Cc.Set(fig, memo.scene, ccKind, ccKind and memo.L.stSrc[cc] or nil, ccKind and memo.L.stFrom[cc] or nil)
    if topN[k] > 0 then stats.badges = stats.badges + min(BADGES, topN[k]) end
    if low.n[k] > 0 then stats.badges = stats.badges + min(BADGES, low.n[k]) end
end
local function PlacePacts(figs, np)
    local n = 0
    for i = 1, np do
        for j = i + 1, np do
            if n < LINE_DRAW and math.abs(pactFrom[i] - pactFrom[j]) <= PACT_GAP then
                local a, b = figs[pactK[i]], figs[pactK[j]]
                if a.shown and b.shown then
                    local dx, dy = b.sx - a.sx, b.sy - a.sy
                    local d = sqrt(dx * dx + dy * dy)
                    if d >= 2 then
                        local nx, ny = -dy / d * LINE_W * 2, dx / d * LINE_W * 2
                        if PutAffine(lines[n + 1], a.sx - nx / 2, a.sy - ny / 2, dx, dy, nx, ny) then n = n + 1 end
                    end
                end
            end
        end
    end
    for i = n + 1, used.line do lines[i]:Hide() end
    used.line = n
end
local function RingUnder(tex, fig, grow)
    local rw = (fig.w or 0) * AGGRO_RING * (grow or 1)
    return rw >= 2 and PutEllipse(tex, fig.sx, fig.sy, rw, max(1, rw * (fig.flat or 1)))
end
local function ThreatRow(scene, t)
    local m = scene.thr
    if not ns.Threat then return nil end
    if m == nil then
        scene.thr = false
        ns.Threat.Load(scene.fight, function(model) scene.thr = model or false end)
        return nil
    end
    if not m then return nil end
    for i = 1, #m.mobs do
        local mob = m.mobs[i]
        if mob.boss then
            local r = ns.Threat.RowAt(mob, t)
            if r then return r end
        end
    end
    return nil
end
local function PlaceAggro(scene, t, figs)
    local b = scene.bossState
    local hk = b.vis and b.hk or 0
    local fig = hk > 0 and figs[hk]
    local bf = figs[#scene.tracks + 1]
    stats.aggro = 0
    if t < swapAt.last then swapAt.hk, swapAt.t = hk, -1e9 end
    swapAt.last = t
    if hk ~= swapAt.hk then
        if hk > 0 and swapAt.hk > 0 then swapAt.t = t end
        swapAt.hk = hk
    end
    local aw, ahw = AGGRO_W * mode.aggro, AGGRO_HW * mode.aggro
    local grow = 1
    if mode.swap > 0 and t - swapAt.t < mode.swap then grow = 1 + 0.8 * (1 - (t - swapAt.t) / mode.swap) end
    stats.swap = grow > 1 and 1 or 0
    local drawn = false
    if fig and fig.shown and bf and bf.shown then
        local dx, dy = fig.sx - bf.sx, fig.sy - bf.sy
        local d = sqrt(dx * dx + dy * dy)
        if d > AGGRO_GAP * 2 + AGGRO_HL then
            local ux, uy = dx / d, dy / d
            local ox, oy = -uy * AGGRO_SIDE, ux * AGGRO_SIDE
            local tx, ty = fig.sx - ux * AGGRO_GAP + ox, fig.sy - uy * AGGRO_GAP + oy
            local hx, hy = tx - ux * AGGRO_HL, ty - uy * AGGRO_HL
            local sx, sy = bf.sx + ux * AGGRO_GAP + ox, bf.sy + uy * AGGRO_GAP + oy
            local nx, ny = -uy * aw, ux * aw
            local wx, wy = -uy * ahw, ux * ahw
            drawn = PutAffine(aggro, sx - nx / 2, sy - ny / 2, hx - sx, hy - sy, nx, ny)
                and PutAffine(aggroHead, tx - wx / 2, ty - wy / 2, hx - tx, hy - ty, wx, wy)
        elseif d >= 2 then
            local nx, ny = -dy / d * aw, dx / d * aw
            drawn = PutAffine(aggro, bf.sx - nx / 2, bf.sy - ny / 2, dx, dy, nx, ny)
            aggroHead:Hide()
        end
    end
    if drawn then
        stats.aggro = hk
    else
        aggro:Hide()
        aggroHead:Hide()
    end
    if not (fig and fig.shown and RingUnder(aggroRing, fig, grow)) then aggroRing:Hide() end
    local n = 0
    local r = b.vis and ThreatRow(scene, t)
    local top = r and r.top
    if top then
        local byK = Replay.ByK(scene)
        for i = 1, #top do
            local e = top[i]
            local k = e.scaled >= THR_WARN and e.name ~= r.who and byK[e.name]
            local f = k and k ~= hk and figs[k]
            if f and f.shown and n < THR_DRAW and RingUnder(thrRings[n + 1], f) then
                n = n + 1
                thrRings[n]:SetVertexColor(Kit.Color(e.scaled >= THR_HOT and "sem.rep.thrHot" or "sem.rep.thrWarn"))
            end
        end
    end
    for i = n + 1, THR_DRAW do thrRings[i]:Hide() end
    stats.thr = n
end
local function PlaceWinter(scene, cam, t)
    local M = scene.layers.mech
    local W = M and M.winter
    local boss = scene.bossState
    local n, lit = 0, false
    if W and boss.vis then
        for i = 1, #M.rings do
            local g = M.rings[i]
            local nw, edge = ns.ReplayMech.Waves(g, W, t, winter.rs, winter.as)
            if nw > 0 or edge > 0 then
                local sx, sy, k = Replay.Project(cam, boss.x, boss.y)
                if k > 0 then
                    local s, tilt = scene.ppy * cam.zoom * k, min(1, cam.tilt * k)
                    local fade = Fade(1, g.on, g.to, t)
                    local r, gg, b, a = Kit.Color(W.waveTone)
                    for q = 1, nw do
                        local tex = winter.waves[n + 1]
                        local rw = winter.rs[q] * s
                        if tex and PutEllipse(tex, sx, sy, rw, max(1, rw * tilt)) then
                            n = n + 1
                            tex:SetVertexColor(r, gg, b, a * winter.as[q] * fade)
                        end
                    end
                    local rw = W.r * s
                    if edge > 0 and not lit and PutEllipse(winter.edge, sx, sy, rw, max(1, rw * tilt)) then
                        lit = true
                        r, gg, b, a = Kit.Color(W.edgeTone)
                        winter.edge:SetVertexColor(r, gg, b, a * edge * fade)
                    end
                end
            end
        end
    end
    for i = n + 1, used.wave do winter.waves[i]:Hide() end
    if not lit then winter.edge:Hide() end
    used.wave = n
    stats.waves, stats.edge, stats.waveR = n, lit and 1 or 0, n > 0 and winter.rs[1] or 0
end
local function PlaceDrops(scene, cam, t)
    local L = scene.layers
    local list = L.mech and L.mech.drops
    local lead = L.bombDef and L.bombDef.lead or 0
    local n, nb = 0, 0
    for i = 1, list and #list or 0 do
        local d = list[i]
        if nb < DROP_DRAW and t >= d.t and t < d.t + BOOM_SHOW then
            local gx, gy, k = Replay.Project(cam, d.x, d.y)
            local tex = drop.beam[nb + 1]
            local yd = scene.ppy * cam.zoom * k
            local w, h = BOOM_W * yd, BOOM_H * yd * min(1, cam.tilt * k + 0.3)
            local q = (t - d.t) / BOOM_SHOW
            local half = w * (1 + 0.4 * q) / 2
            if k > 0 and w < MAX_PX and h < MAX_PX and PutRect(tex, gx - half, gy - h, gx + half, gy, 0, 0, 1, 1) then
                nb = nb + 1
                local r, g, b, a = Kit.Color("sem.rep.icicleBoom")
                tex:SetVertexColor(r, g, b, a * (1 - q))
            end
        end
        if n < DROP_DRAW and lead > 0 and t >= d.t - lead and t < d.t then
            local gx, gy, k = Replay.Project(cam, d.x, d.y)
            if k > 0 then
                n = n + 1
                local yd = scene.ppy * cam.zoom * k
                local sx, sy = gx + DROP_SIDE * yd, gy - DROP_UP * yd
                local q = (t - (d.t - lead)) / lead
                q = q * q
                local px, py = sx + (gx - sx) * q, sy + (gy - sy) * q
                local dx, dy = gx - sx, gy - sy
                local len = sqrt(dx * dx + dy * dy)
                local fx, fy = dx / len, dy / len
                local nx, ny = -fy, fx
                local ax, ay = gx - px, gy - py
                local rest = sqrt(ax * ax + ay * ay)
                local w = max(1, LINE_W * 0.5)
                if rest >= 2 then
                    PutAffine(drop.aim[n], px - nx * w / 2, py - ny * w / 2, ax, ay, nx * w, ny * w)
                else
                    drop.aim[n]:Hide()
                end
                local tl = min(TRAIL_LEN * yd, len * q)
                local tw = ICICLE_W * yd * 1.1
                if tl >= 2 then
                    PutAffine(drop.trail[n], px - nx * tw / 2, py - ny * tw / 2, -fx * tl, -fy * tl, nx * tw, ny * tw)
                else
                    drop.trail[n]:Hide()
                end
                local il, iw = ICICLE_LEN * yd, ICICLE_W * yd
                PutAffine(drop.ice[n], px - nx * iw / 2, py - ny * iw / 2, -fx * il, -fy * il, nx * iw, ny * iw)
            end
        end
    end
    for i = n + 1, used.drop do
        drop.aim[i]:Hide()
        drop.trail[i]:Hide()
        drop.ice[i]:Hide()
    end
    for i = nb + 1, used.boom do drop.beam[i]:Hide() end
    used.drop, used.boom = n, nb
    stats.booms = nb
    stats.drops = n
end
local function PlaceVortex(scene, cam, t)
    local M = scene.layers.mech
    local zones = M and M.zones
    local n, nw = 0, 0
    for i = 1, zones and #zones or 0 do
        local z = zones[i]
        local def = z.def
        if n < VORTEX_DRAW and def.spin and z.from <= t and z.to > t then
            local sx, sy, k = Replay.Project(cam, z.x, z.y)
            local rw = def.r * scene.ppy * cam.zoom * k
            if k > 0 and rw * 2 <= MAX_PX then
                n = n + 1
                local tilt = min(1, cam.tilt * k)
                local on, arm = t - z.from, def.arm or 0
                local lit = on >= arm and 1 or 0.5
                local fade = Fade(1, z.from, z.to, t)
                local tex = vortex.fill[n]
                local r, g, b, a = Kit.Color(def.tone)
                if PutEllipse(tex, sx, sy, rw, max(1, rw * tilt)) then tex:SetVertexColor(r, g, b, a * lit * fade) end
                tex = vortex.edge[n]
                r, g, b, a = Kit.Color("sem.rep.vortexEdge")
                if PutEllipse(tex, sx, sy, rw, max(1, rw * tilt)) then tex:SetVertexColor(r, g, b, a * lit * fade) end
                local grow = arm > 0 and min(1, on / arm) or 1
                local s = rw * (0.35 + 0.65 * grow) * VORTEX_SWIRL
                local ang = t * VORTEX_SPIN + i
                local c, sn = math.cos(ang) * s, math.sin(ang) * s
                tex = vortex.swirl[n]
                if PutAffine(tex, sx - c + sn, sy - (sn + c) * tilt, 2 * c, 2 * sn * tilt, -2 * sn, 2 * c * tilt) then
                    r, g, b, a = Kit.Color("sem.rep.vortexSwirl")
                    tex:SetVertexColor(r, g, b, a * (0.5 + 0.5 * lit) * fade)
                end
                local ph = def.pulse and on >= arm and (on - arm) % def.pulse or VORTEX_WAVE
                if ph < VORTEX_WAVE then
                    local q = ph / VORTEX_WAVE
                    local wr = rw * (0.25 + 0.75 * q)
                    tex = vortex.wave[nw + 1]
                    if PutEllipse(tex, sx, sy, wr, max(1, wr * tilt)) then
                        nw = nw + 1
                        r, g, b, a = Kit.Color("sem.rep.vortexWave")
                        tex:SetVertexColor(r, g, b, a * (1 - q) * fade)
                    end
                end
            end
        end
    end
    for i = n + 1, used.vortex do
        vortex.fill[i]:Hide()
        vortex.edge[i]:Hide()
        vortex.swirl[i]:Hide()
    end
    for i = nw + 1, used.vortexWave do vortex.wave[i]:Hide() end
    used.vortex, used.vortexWave = n, nw
    stats.vortex, stats.vortexWave = n, nw
end
function V.Place(scene, cam, t, figs)
    local L = scene.layers
    if not L or not view then return end
    hw, hh = cam.w / 2, cam.h / 2
    PlacePools(scene, cam, t)
    PlaceAims(scene, cam, t)
    PlaceRings(scene, cam, t)
    PlaceWinter(scene, cam, t)
    PlaceVortex(scene, cam, t)
    PlaceDrops(scene, cam, t)
    PlaceChase(scene, cam, t)
    PlaceHits(scene, cam, t)
    PlaceBlasts(scene, cam, t)
    PlaceCones(scene, cam, t)
    PlaceHitbox(scene, cam)
    PlaceBomb(L, t)
    if memo.L ~= L or t < memo.from or t >= memo.to then
        local n = #scene.tracks
        local fk = 0
        for k = 1, focusName and n or 0 do
            if scene.tracks[k].name == focusName then fk = k end
        end
        memo.fk = fk
        memo.np, memo.to, memo.nfx = Collect(L, n, t, fk)
        memo.nex = 0
        if mode.extra and fk > 0 then
            local nex, nx = mode.extra(fk, t, extraIds)
            memo.nex = nex
            if nx and nx < memo.to then memo.to = nx end
        end
        memo.L, memo.from = L, t
        stats.badges, stats.fx = 0, 0
        stats.collects = stats.collects + 1
        memo.scene = scene
        Cc.Reset()
        for k = 1, n do
            local fig = figs[k]
            if fig.bd then Decorate(fig, k) end
        end
        local owner = fk > 0 and figs[fk].bd and figs[fk] or nil
        DecorateFx(owner, memo.nfx, fk)
        stats.fx = owner and fxRow.shown or 0
    end
    local owner = fxRow.owner
    local off = owner ~= nil and owner.shown == false
    if owner and off ~= fxRow.off then
        fxRow.key = nil
        DecorateFx(owner, memo.nfx, memo.fk)
    end
    PlacePacts(figs, memo.np)
    PlaceAggro(scene, t, figs)
    Cc.Place(scene, t, figs)
    V.Carry(scene, t, figs)
    local boss = figs[#scene.tracks + 1]
    if boss and boss.isBoss then ns.ReplayFigs.Rage(boss, Layers.Rage(L, t)) end
end
function V.Focus(name)
    if focusName == name then return end
    focusName = name
    memo.L = nil
end
function V.FocusName()
    return focusName
end
function V.SetMode(m)
    m = m or {}
    mode.bright = m.bright or 1
    mode.lift, mode.liftK = m.lift, m.liftK
    mode.fx = math.min(FX_POOL, m.fx or FX_SHOW)
    mode.extra = m.extra
    mode.aggro = m.aggro or 1
    mode.swap = m.swap or 0
    memo.L = nil
    fxRow.key = nil
end
function V.Mode()
    return mode
end
V.FxRow = fxRow
V.Ellipse = PutEllipse
V.Affine = PutAffine
