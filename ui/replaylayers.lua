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
local RING = ART .. "ring256"
local LINE = ART .. "line"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POOL_DRAW = 48
local WAVE_DRAW = 6
local CONE_DRAW = 8
local BLAST_DRAW = 16
local ADD_DRAW = 48
local LINE_DRAW = 12
local HIT_DRAW = 32
local HIT_SHOW = 6
local HIT_YD = 3
local BLAST_SHOW = 1
local FADE = 1
local ADD_HOLD = 4
local BADGE = 12
local BADGES = 3
local FX_SHOW = 6
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
local SPIN_K = 2.2
local SPIN_RATE = 2 * math.pi * 1.25
local SPIN_H = 0.5
local V = {}
ns.ReplayLayersView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Layers = ns.ReplayLayers
local Shield = ns.ReplayShield
local pools, cones, blasts, lines, hits = {}, {}, {}, {}, {}
local counts, chaseLines, chaseRings, addRings = {}, {}, {}, {}
local winter = { waves = {}, rs = {}, as = {} }
local hitbox
local bomb
local used = { pool = 0, cone = 0, blast = 0, line = 0, hit = 0, count = 0, chase = 0, ring = 0, wave = 0, addRing = 0 }
local view, marks
local hw, hh = 0, 0
local top1, top2, top3, topN = {}, {}, {}, {}
local flagSpike, flagMc, flagLift, flagHalo, flagGrow = {}, {}, {}, {}, {}
local flagLook = {}
local flagSpin = {}
local spinFigs = {}
local memo = { L = nil, from = 0, to = -1, np = 0, fk = 0, nfx = 0 }
local fxList = {}
local focusName
local fxRow = { tex = {}, more = nil, owner = nil, key = nil }
local pactK, pactFrom = {}, {}
local stats = { badges = 0, pools = 0, cones = 0, blasts = 0, adds = 0, counts = 0, countTop = nil, chases = 0,
                chaseLines = 0, waves = 0, edge = 0, waveR = 0, collects = 0, addRings = 0, fx = 0 }
V.stats = stats
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
    return PutRect(tex, sx - rw, sy - rh, sx + rw, sy + rh, 0, 0, 1, 1)
end
local function Inverse(ox, oy, ux, uy, vx, vy, x, y)
    local det = ux * vy - uy * vx
    if det == 0 then return 0, 0 end
    local dx, dy = x - ox, y - oy
    return (dx * vy - dy * vx) / det, (ux * dy - uy * dx) / det
end
local function PutAffine(tex, ox, oy, ux, uy, vx, vy)
    if not view then return false end
    local l = min(ox, ox + ux, ox + vx, ox + ux + vx)
    local r = max(ox, ox + ux, ox + vx, ox + ux + vx)
    local t = min(oy, oy + uy, oy + vy, oy + uy + vy)
    local b = max(oy, oy + uy, oy + vy, oy + uy + vy)
    if r - l > MAX_PX or b - t > MAX_PX then
        tex:Hide()
        return false
    end
    l, t, r, b = max(l, -hw), max(t, -hh), min(r, hw), min(b, hh)
    if r - l < 1 or b - t < 1 then
        tex:Hide()
        return false
    end
    local ulx, uly = Inverse(ox, oy, ux, uy, vx, vy, l, t)
    local llx, lly = Inverse(ox, oy, ux, uy, vx, vy, l, b)
    local urx, ury = Inverse(ox, oy, ux, uy, vx, vy, r, t)
    local lrx, lry = Inverse(ox, oy, ux, uy, vx, vy, r, b)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", view, "CENTER", l, -t)
    tex:SetWidth(r - l)
    tex:SetHeight(b - t)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    tex:Show()
    return true
end
local function Tex(parent, path, layer, token)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(path)
    if token then tex:SetVertexColor(Kit.Color(token)) end
    tex:Hide()
    return tex
end
function V.Build(v, m)
    view, marks = v, m
    for i = 1, POOL_DRAW do pools[i] = Tex(marks, RIM, "BACKGROUND") end
    for i = 1, RING_DRAW do addRings[i] = Tex(marks, RIM, "BACKGROUND") end
    for i = 1, WAVE_DRAW do winter.waves[i] = Tex(marks, RING, "BORDER") end
    winter.edge = Tex(marks, RING, "BORDER")
    for i = 1, HIT_DRAW do hits[i] = Tex(marks, CIRCLE, "BORDER", "sem.rep.hit") end
    for i = 1, LINE_DRAW do lines[i] = Tex(marks, LINE, "BORDER", "sem.rep.pact") end
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
    for i = 1, FX_SHOW do
        local tex = marks:CreateTexture(nil, "OVERLAY")
        tex:SetWidth(BADGE)
        tex:SetHeight(BADGE)
        tex:Hide()
        fxRow.tex[i] = tex
    end
    fxRow.more = marks:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fxRow.more:Hide()
end
function V.Attach(fig)
    fig.bd = {}
    for i = 1, BADGES do
        local tex = fig:CreateTexture(nil, "OVERLAY")
        tex:SetWidth(BADGE)
        tex:SetHeight(BADGE)
        tex:Hide()
        fig.bd[i] = tex
    end
    fig.bd[1]:SetPoint("BOTTOM", fig.icon, "TOP", 0, 2)
    fig.bd[2]:SetPoint("RIGHT", fig.bd[1], "LEFT", -1, 0)
    fig.bd[3]:SetPoint("LEFT", fig.bd[1], "RIGHT", 1, 0)
    fig.more = fig:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fig.more:SetPoint("LEFT", fig.bd[3], "RIGHT", 1, 0)
    fig.more:Hide()
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
    fig.spin = fig:CreateTexture(nil, "OVERLAY")
    fig.spin:SetTexture(SPIN_TEX)
    fig.spin:SetPoint("CENTER", fig.icon, "CENTER", 0, 0)
    Kit.Hue(fig.spin, "sem.rep.cyclone")
    fig.spin:Hide()
end
function V.Role(fig)
    memo.L = nil
    fig.bKey, fig.lift, fig.mcOn, fig.grow, fig.look = nil, nil, nil, nil, nil
    for i = 1, BADGES do fig.bd[i]:Hide() end
    fig.more:Hide()
    if fxRow.owner == fig then fxRow.key = nil end
    fig.spike:Hide()
    fig.halo:Hide()
    fig.spin:Hide()
    fig.spinOn = nil
end
function V.Clear(fig)
    if not fig.bd then return end
    V.Role(fig)
end
function V.Use(scene)
    if not view then return end
    for i = 1, #pools do pools[i]:Hide() end
    for i = 1, #cones do cones[i]:Hide() end
    for i = 1, #blasts do blasts[i]:Hide() end
    for i = 1, #lines do lines[i]:Hide() end
    for i = 1, #hits do hits[i]:Hide() end
    for i = 1, #counts do counts[i]:Hide() end
    for i = 1, #chaseLines do chaseLines[i]:Hide() end
    for i = 1, #chaseRings do chaseRings[i]:Hide() end
    for i = 1, #addRings do addRings[i]:Hide() end
    for i = 1, #winter.waves do winter.waves[i]:Hide() end
    winter.edge:Hide()
    hitbox:Hide()
    bomb:Hide()
    bomb.key = nil
    for k in pairs(used) do used[k] = 0 end
    for k in pairs(stats) do stats[k] = 0 end
    stats.countTop = nil
    memo.L = nil
    for i = 1, FX_SHOW do fxRow.tex[i]:Hide() end
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
    for j = 1, L.np do
        if n >= POOL_DRAW then break end
        if L.plFrom[j] <= t and L.plTo[j] > t then
            local x, y = L.plX[j], L.plY[j]
            local def = L.plDef[j]
            if def.follow then x, y = boss.vis and boss.x or -1, boss.y end
            if x >= 0 then
                local sx, sy, k = Replay.Project(cam, x, y)
                if k > 0 then
                    local rw = Layers.PoolRadius(L, j, t) * ppy * zoom * k
                    local tex = pools[n + 1]
                    if PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                        n = n + 1
                        local r, g, b, a = Kit.Color(def.tone)
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
    for i = 1, list and #list or 0 do
        if n >= RING_DRAW then break end
        local a = list[i]
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
    for j = 1, L.nb do
        if n >= BLAST_DRAW or L.bT[j] > t then break end
        if L.bT[j] + BLAST_SHOW > t then
            local sx, sy, k = Replay.Project(cam, L.bX[j], L.bY[j])
            if k > 0 then
                local rw = L.bR[j] * zoom * k
                local tex = blasts[n + 1]
                if PutEllipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
                    n = n + 1
                    tex:SetVertexColor(Kit.Color(L.bTone[j] or "sem.rep.blast"))
                    tex:SetAlpha(0.25 + 0.75 * (1 - (t - L.bT[j]) / BLAST_SHOW))
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
    for j = 1, L.nc do
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
                    tex:SetVertexColor(r, g, b, Fade(a, L.cnT[j], L.cnTo[j], t))
                end
            end
        end
    end
    for i = n + 1, used.cone do cones[i]:Hide() end
    used.cone = n
    stats.cones = n
end
function V.Adds(scene, t, out)
    local list = scene.layers.adds
    local RV = ns.ReplayRealmView
    local n = 0
    for i = 1, #list do
        if n >= ADD_DRAW then break end
        local a = list[i]
        if a.from <= t and a.to > t and not a.mdl and not (RV and RV.HideAdd(scene, a)) then
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
                out.hp[n] = Layers.AddHp(a, t)
            end
        end
    end
    return n
end
local function PlaceHits(scene, cam, t)
    local L = scene.layers
    local n = 0
    local w0 = 2 * HIT_YD * scene.ppy * cam.zoom
    local lo = t - HIT_SHOW
    for i = 1, L.nh do
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
local function Collect(L, n, t, fk)
    for k = 1, n do
        top1[k], top2[k], top3[k], topN[k] = -1, -1, -1, 0
        flagSpike[k], flagMc[k], flagLift[k], flagHalo[k] = false, false, false, false
        flagGrow[k] = false
        flagLook[k] = false
        flagSpin[k] = false
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
            if nfx < FX_MAX then
                nfx = nfx + 1
                fxList[nfx] = s
            end
            def = nil
        end
        local look = def and Shield.Of(s)
        if look and Shield.Prio(look) > Shield.Prio(flagLook[k] or nil) then flagLook[k] = look end
        if def and not def.bare then
            if def.grow then flagGrow[k] = true end
            topN[k] = topN[k] + 1
            local p = def.prio
            local a, b = top1[k], top2[k]
            if a < 0 or p > Layers.State(a).prio then
                top1[k], top2[k], top3[k] = s, a, b
            elseif b < 0 or p > Layers.State(b).prio then
                top2[k], top3[k] = s, b
            elseif top3[k] < 0 or p > Layers.State(top3[k]).prio then
                top3[k] = s
            end
            if def.spike then flagSpike[k] = true end
            if def.mc then flagMc[k] = true end
            if def.spin then flagSpin[k] = true end
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
local function DecorateFx(fig, nfx)
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
    local key = table.concat(fxList, ",", 1, nfx)
    if fxRow.owner == fig and fxRow.key == key then return end
    fxRow.owner, fxRow.key = fig, key
    fxRow.off = fig ~= nil and fig.shown == false
    local shown = fxRow.off and 0 or min(nfx, FX_SHOW)
    local w = shown * (BADGE + 1) - 1
    for i = 1, FX_SHOW do
        local tex = fxRow.tex[i]
        if i <= shown then
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", fig.icon, "TOP", -w / 2 + (i - 1) * (BADGE + 1), BADGE + 4)
            Kit.Icon.Spell(tex, Layers.State(fxList[i]).icon)
            tex:Show()
        else
            tex:Hide()
        end
    end
    if shown > 0 and nfx > FX_SHOW then
        fxRow.more:ClearAllPoints()
        fxRow.more:SetPoint("LEFT", fxRow.tex[FX_SHOW], "RIGHT", 1, 0)
        fxRow.more:SetText("+" .. (nfx - FX_SHOW))
        fxRow.more:Show()
    else
        fxRow.more:Hide()
    end
end
local function Decorate(fig, k)
    local key = (top1[k] + 2) + (top2[k] + 2) * KEY_B + (top3[k] + 2) * KEY_B * KEY_B
        + (topN[k] + (flagSpike[k] and KEY_B or 0)) * KEY_B * KEY_B * KEY_B
    if fig.bKey ~= key then
        fig.bKey = key
        for i = 1, BADGES do
            local s = i == 1 and top1[k] or (i == 2 and top2[k] or top3[k])
            if s >= 0 then
                Kit.Icon.Spell(fig.bd[i], Layers.State(s).icon)
                fig.bd[i]:Show()
            else
                fig.bd[i]:Hide()
            end
        end
        if topN[k] > BADGES then
            fig.more:SetText("+" .. (topN[k] - BADGES))
            fig.more:Show()
        else
            fig.more:Hide()
        end
        if flagSpike[k] then fig.spike:Show() else fig.spike:Hide() end
    end
    if flagMc[k] ~= (fig.mcOn or false) then
        fig.mcOn = flagMc[k]
        ns.ReplayFigs.Rim(fig)
    end
    local lift = flagLift[k] and LIFT_PX or nil
    if fig.lift ~= lift then
        fig.lift = lift
        fig.sQ = nil
    end
    fig.grow = flagGrow[k]
    fig.look = flagLook[k] or nil
    if flagHalo[k] then fig.halo:Show() else fig.halo:Hide() end
    local spin = flagSpin[k]
    if fig.spinOn ~= spin then
        if spin then fig.spin:Show() else fig.spin:Hide() end
    end
    fig.spinOn = spin
    if topN[k] > 0 then stats.badges = stats.badges + min(BADGES, topN[k]) end
end
local function PlaceSpin(t)
    for i = 1, #spinFigs do
        local fig = spinFigs[i]
        local tex = fig.spin
        local w = floor(fig.icon:GetWidth() * SPIN_K + 0.5)
        if fig.spinW ~= w then
            fig.spinW = w
            tex:SetWidth(max(1, w))
            tex:SetHeight(max(1, w))
        end
        local a = t * SPIN_RATE + i
        local c, s = math.cos(a) * SPIN_H, math.sin(a) * SPIN_H
        tex:SetTexCoord(0.5 - c - s, 0.5 + s - c, 0.5 - c + s, 0.5 + s + c,
            0.5 + c - s, 0.5 - s - c, 0.5 + c + s, 0.5 - s + c)
    end
    stats.spins = #spinFigs
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
function V.Place(scene, cam, t, figs)
    local L = scene.layers
    if not L or not view then return end
    hw, hh = cam.w / 2, cam.h / 2
    PlacePools(scene, cam, t)
    PlaceRings(scene, cam, t)
    PlaceWinter(scene, cam, t)
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
        memo.L, memo.from = L, t
        stats.badges, stats.fx = 0, 0
        stats.collects = stats.collects + 1
        for i = #spinFigs, 1, -1 do spinFigs[i] = nil end
        for k = 1, n do
            local fig = figs[k]
            if fig.bd then Decorate(fig, k) end
            if fig.spinOn then spinFigs[#spinFigs + 1] = fig end
        end
        local owner = fk > 0 and figs[fk].bd and figs[fk] or nil
        DecorateFx(owner, memo.nfx)
        stats.fx = owner and min(memo.nfx, FX_SHOW) or 0
    end
    local owner = fxRow.owner
    local off = owner ~= nil and owner.shown == false
    if owner and off ~= fxRow.off then
        fxRow.key = nil
        DecorateFx(owner, memo.nfx)
    end
    PlacePacts(figs, memo.np)
    PlaceSpin(t)
end
function V.Focus(name)
    if focusName == name then return end
    focusName = name
    memo.L = nil
end
function V.FocusName()
    return focusName
end
V.FxRow = fxRow
V.Ellipse = PutEllipse
V.Affine = PutAffine
function V.Lift(fig)
    return fig.lift or 0
end
function V.Round(v)
    return floor(v + 0.5)
end
