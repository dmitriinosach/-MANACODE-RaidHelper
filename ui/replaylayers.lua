local ADDON, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local CONE = ART .. "cone"
local RIM = ART .. "rim"
local LINE = ART .. "line"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POOL_DRAW = 48
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
local LIFT_PX = 14
local LINE_W = 3
local PACT_GAP = 1
local MAX_PX = 4000
local SPIKE_W = 10
local SPIKE_UP = 12
local V = {}
ns.ReplayLayersView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Layers = ns.ReplayLayers
local Shield = ns.ReplayShield
local pools, cones, blasts, lines, hits = {}, {}, {}, {}, {}
local hitbox
local used = { pool = 0, cone = 0, blast = 0, line = 0, hit = 0 }
local view, marks
local hw, hh = 0, 0
local top1, top2, top3, topN = {}, {}, {}, {}
local flagBox, flagSpike, flagMc, flagLift, flagHalo, flagGrow = {}, {}, {}, {}, {}, {}
local flagLook = {}
local pactK, pactFrom = {}, {}
local stats = { badges = 0, pools = 0, cones = 0, blasts = 0, adds = 0 }
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
    for i = 1, HIT_DRAW do hits[i] = Tex(marks, CIRCLE, "BORDER", "sem.rep.hit") end
    for i = 1, LINE_DRAW do lines[i] = Tex(marks, LINE, "BORDER", "sem.rep.pact") end
    for i = 1, CONE_DRAW do cones[i] = Tex(marks, CONE, "ARTWORK", "sem.rep.cone") end
    for i = 1, BLAST_DRAW do blasts[i] = Tex(marks, RIM, "ARTWORK", "sem.rep.blast") end
    hitbox = Tex(marks, RIM, "BACKGROUND", "sem.rep.hitbox")
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
    fig.box = fig:CreateTexture(nil, "OVERLAY")
    fig.box:SetPoint("TOPLEFT", fig.icon, "TOPLEFT", -4, 4)
    fig.box:SetPoint("BOTTOMRIGHT", fig.icon, "BOTTOMRIGHT", 4, -4)
    fig.box:SetAlpha(0.6)
    fig.box:Hide()
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
end
function V.Role(fig)
    fig.bKey, fig.lift, fig.mcOn, fig.grow, fig.look = nil, nil, nil, nil, nil
    for i = 1, BADGES do fig.bd[i]:Hide() end
    fig.more:Hide()
    fig.box:Hide()
    fig.spike:Hide()
    fig.halo:Hide()
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
    hitbox:Hide()
    for k in pairs(used) do used[k] = 0 end
    for k in pairs(stats) do stats[k] = 0 end
    V.scene = scene
end
local function Fade(a, from, to, t)
    local left = to - t
    if left < FADE then a = a * max(0, left / FADE) end
    local born = t - from
    if born < 0.3 then a = a * max(0.3, born / 0.3) end
    return a
end
local function PlacePools(scene, cam, t)
    local L = scene.layers
    local n = 0
    local ppy, zoom = scene.ppy, cam.zoom
    local boss = scene.bossState
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
                    end
                end
            end
        end
    end
    for i = n + 1, used.pool do pools[i]:Hide() end
    used.pool = n
    stats.pools = n
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
                    local r, g, b, a = Kit.Color("sem.rep.cone")
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
local function Collect(L, n, t)
    for k = 1, n do
        top1[k], top2[k], top3[k], topN[k] = -1, -1, -1, 0
        flagBox[k], flagSpike[k], flagMc[k], flagLift[k], flagHalo[k] = false, false, false, false, false
        flagGrow[k] = false
        flagLook[k] = false
    end
    local np = 0
    for i = 1, L.ns do
        if L.stFrom[i] > t then break end
        local k, s = L.stK[i], L.stS[i]
        local def = L.stTo[i] > t and Layers.State(s)
        local look = def and Shield.Of(s)
        if look and Shield.Prio(look) > Shield.Prio(flagLook[k] or nil) then flagLook[k] = look end
        if def and def.grow then
            flagGrow[k] = true
        elseif def then
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
            if def.box then flagBox[k] = true end
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
        if vt > t then break end
        if vt + BLAST_SHOW > t then flagHalo[L.vK[i]] = true end
    end
    return np
end
local function Decorate(fig, k)
    local key = (top1[k] + 2) + (top2[k] + 2) * 64 + (top3[k] + 2) * 4096 + topN[k] * 262144
        + (flagBox[k] and 1e8 or 0) + (flagSpike[k] and 2e8 or 0)
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
        if flagBox[k] then
            Kit.Icon.Spell(fig.box, 70157)
            fig.box:Show()
        else
            fig.box:Hide()
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
    if topN[k] > 0 then stats.badges = stats.badges + min(BADGES, topN[k]) end
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
function V.Place(scene, cam, t, figs)
    local L = scene.layers
    if not L or not view then return end
    hw, hh = cam.w / 2, cam.h / 2
    PlacePools(scene, cam, t)
    PlaceHits(scene, cam, t)
    PlaceBlasts(scene, cam, t)
    PlaceCones(scene, cam, t)
    PlaceHitbox(scene, cam)
    local n = #scene.tracks
    local np = Collect(L, n, t)
    stats.badges = 0
    for k = 1, n do
        local fig = figs[k]
        if fig.bd then Decorate(fig, k) end
    end
    PlacePacts(figs, np)
end
function V.Lift(fig)
    return fig.lift or 0
end
function V.Round(v)
    return floor(v + 0.5)
end
