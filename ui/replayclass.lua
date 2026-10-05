local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local sqrt = math.sqrt
local huge = math.huge
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local DISC = ART .. "disc256"
local RING = ART .. "ring256"
local RING_S = ART .. "ring128"
local LINE = ART .. "line"
local CONE = ART .. "cone"
local ZONE_DRAW = 8
local RING_DRAW = 8
local CONE_DRAW = 4
local ARROW_DRAW = 8
local CIRCLE_DRAW = 8
local BEAM_DRAW = 6
local ICON_DRAW = 8
local ACTIVE_MAX = 24
local ICON = 14
local FILL_A = 0.3
local MARK_A = 0.18
local HALF_SQRT2 = 0.7071
local RING_YD = 2.2
local PULSE = 3
local PULSE_K = 0.08
local FADE_IN = 0.3
local FADE_OUT = 0.6
local LINE_W = 3
local BEAM_W = 2
local HEAD = 10
local MIN_R = 4
local V = {}
ns.ReplayClassView = V
local Kit = ns.Kit
local Replay = ns.Replay
local KINDS = { "zones", "rings", "cones", "arrows", "circles", "beams" }
local pool = { zones = {}, edges = {}, marks = {}, rings = {}, cones = {}, arrows = {}, heads = {}, circles = {}, beams = {},
               icons = {} }
local used = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0, icons = 0 }
local memo = { cls = nil, from = 0, to = -1 }
local active = { zones = {}, rings = {}, cones = {}, arrows = {}, circles = {}, beams = {} }
local nact = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0 }
local view
local probe = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0, icons = 0, collects = 0 }
local function Tex(layer, path, draw, token)
    local tex = layer:CreateTexture(nil, draw)
    tex:SetTexture(path)
    if token then Kit.Tint(tex, token) end
    tex:Hide()
    return tex
end
function V.Build(v, layer)
    view = v
    for i = 1, ZONE_DRAW do
        pool.zones[i] = Tex(layer, DISC, "BACKGROUND")
        pool.edges[i] = Tex(layer, RING, "BORDER")
        pool.marks[i] = layer:CreateTexture(nil, "BACKGROUND")
        pool.marks[i]:Hide()
    end
    for i = 1, RING_DRAW do pool.rings[i] = Tex(layer, RING_S, "BORDER") end
    for i = 1, CONE_DRAW do pool.cones[i] = Tex(layer, CONE, "BORDER", "sem.rep.clsCone") end
    for i = 1, ARROW_DRAW do
        pool.arrows[i] = Tex(layer, LINE, "BORDER")
        pool.heads[i] = Tex(layer, CONE, "BORDER")
    end
    for i = 1, CIRCLE_DRAW do pool.circles[i] = Tex(layer, RING_S, "BORDER", "sem.rep.clsCircle") end
    for i = 1, BEAM_DRAW do pool.beams[i] = Tex(layer, LINE, "BORDER", "sem.rep.clsBeacon") end
    for i = 1, ICON_DRAW do
        local tex = layer:CreateTexture(nil, "ARTWORK")
        tex:SetWidth(ICON)
        tex:SetHeight(ICON)
        tex:Hide()
        pool.icons[i] = tex
    end
end
local function HideAll()
    for _, list in pairs(pool) do
        for i = 1, #list do list[i]:Hide() end
    end
    for k in pairs(used) do used[k] = 0 end
end
function V.Use(scene)
    if not view then return end
    HideAll()
    memo.cls = nil
    for k in pairs(probe) do probe[k] = 0 end
end
local function Collect(cls, t)
    local nx = huge
    for _, kind in ipairs(KINDS) do
        local list, out, n = cls[kind], active[kind], 0
        for i = 1, #list do
            local it = list[i]
            if it.from > t then
                if it.from < nx then nx = it.from end
                break
            end
            if it.to > t then
                if it.to < nx then nx = it.to end
                if n < ACTIVE_MAX then
                    n = n + 1
                    out[n] = it
                end
            end
        end
        nact[kind] = n
    end
    probe.collects = probe.collects + 1
    return nx
end
local function Screen(cam, scene, x, y)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
local function Where(scene, it)
    if not it.k then return it.x, it.y end
    local st = scene.states[it.k]
    if not st or not st.vis or st.dead then return nil, 0 end
    return st.x, st.y
end
local function Fade(a, it, t)
    return a * min(1, (t - it.from) / FADE_IN, (it.to - t) / FADE_OUT)
end
local function Tone(tex, token, a)
    local r, g, b, ta = Kit.Color(token)
    tex:SetVertexColor(r, g, b, ta * a)
end
local function PutIcon(sx, sy, id)
    local n = used.icons + 1
    local tex = pool.icons[n]
    if not tex then return false end
    if tex.id ~= id then
        tex.id = id
        Kit.Icon.Spell(tex, id)
    end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", view, "CENTER", sx, -sy)
    tex:Show()
    used.icons = n
    return true
end
local function PutLine(tex, ax, ay, bx, by, w)
    local dx, dy = bx - ax, by - ay
    local d = sqrt(dx * dx + dy * dy)
    if d < 2 then
        tex:Hide()
        return false
    end
    local nx, ny = -dy / d * w * 2, dx / d * w * 2
    return ns.ReplayLayersView.Affine(tex, ax - nx / 2, ay - ny / 2, dx, dy, nx, ny)
end
local function PlaceRound(scene, cam, t)
    local Ellipse = ns.ReplayLayersView.Ellipse
    local ppy, zoom, tilt = scene.ppy, cam.zoom, cam.tilt
    local nz, nr = 0, 0
    local focus = ns.ReplayLayersView.FocusName()
    local list = active.zones
    for i = 1, nact.zones do
        local it = list[i]
        local x, y = Where(scene, it)
        if x and nz < ZONE_DRAW and (not it.own or it.own == focus) then
            local sx, sy, k = Screen(cam, scene, x, y)
            local rw = max(MIN_R, it.r * ppy * zoom * k)
            local rh = max(1, rw * min(1, tilt * k))
            local fill, edge, mark = pool.zones[nz + 1], pool.edges[nz + 1], pool.marks[nz + 1]
            if k > 0 and Ellipse(fill, sx, sy, rw, rh) then
                nz = nz + 1
                local a = Fade(1, it, t)
                Tone(fill, it.tone, FILL_A * a)
                if Ellipse(edge, sx, sy, rw, rh) then Tone(edge, it.tone, a) end
                if it.own and Ellipse(mark, sx, sy, rw * HALF_SQRT2, rh * HALF_SQRT2) then
                    if mark.id ~= it.icon then
                        mark.id = it.icon
                        Kit.Icon.Spell(mark, it.icon)
                    end
                    mark:SetAlpha(MARK_A * a)
                else
                    mark:Hide()
                end
                if not it.k then PutIcon(sx, sy, it.icon) end
            else
                edge:Hide()
                mark:Hide()
            end
        end
    end
    list = active.rings
    for i = 1, nact.rings do
        local it = list[i]
        local x, y = Where(scene, it)
        if x and nr < RING_DRAW then
            local sx, sy, k = Screen(cam, scene, x, y)
            local rw = max(MIN_R, RING_YD * ppy * zoom * k * (1 + PULSE_K * sin((t - it.from) * PULSE)))
            local tex = pool.rings[nr + 1]
            if k > 0 and Ellipse(tex, sx, sy, rw, max(1, rw * min(1, tilt * k))) then
                nr = nr + 1
                Tone(tex, it.tone, Fade(1, it, t))
                if not it.k then PutIcon(sx, sy, it.icon) end
            end
        end
    end
    for i = nz + 1, used.zones do
        pool.zones[i]:Hide()
        pool.edges[i]:Hide()
        pool.marks[i]:Hide()
    end
    for i = nr + 1, used.rings do pool.rings[i]:Hide() end
    used.zones, used.rings = nz, nr
    probe.zones, probe.rings = nz, nr
end
local function PlaceCones(scene, cam, t)
    local n = 0
    local list = active.cones
    for i = 1, nact.cones do
        local it = list[i]
        if n >= CONE_DRAW then break end
        local len = it.len * scene.ppy
        local lx, ly, rx, ry = ns.ReplayLayers.ConeEdges(it.deg, it.hx, it.hy)
        local ax, ay, ka = Screen(cam, scene, it.x, it.y)
        local bx, by, kb = Screen(cam, scene, it.x + lx * len, it.y + ly * len)
        local cx, cy, kc = Screen(cam, scene, it.x + rx * len, it.y + ry * len)
        if ka > 0 and kb > 0 and kc > 0 then
            local mx, my = (bx + cx) / 2, (by + cy) / 2
            local vx, vy = cx - bx, cy - by
            local tex = pool.cones[n + 1]
            if ns.ReplayLayersView.Affine(tex, ax - vx / 2, ay - vy / 2, mx - ax, my - ay, vx, vy) then
                n = n + 1
                Tone(tex, "sem.rep.clsCone", Fade(1, it, t))
            end
        end
    end
    for i = n + 1, used.cones do pool.cones[i]:Hide() end
    used.cones = n
    probe.cones = n
end
local function PlaceMoves(scene, cam, t)
    local n, nc = 0, 0
    local list = active.arrows
    for i = 1, nact.arrows do
        local it = list[i]
        if n >= ARROW_DRAW then break end
        local ax, ay, ka = Screen(cam, scene, it.x, it.y)
        local bx, by, kb = Screen(cam, scene, it.x1, it.y1)
        local line, head = pool.arrows[n + 1], pool.heads[n + 1]
        if ka > 0 and kb > 0 and PutLine(line, ax, ay, bx, by, LINE_W) then
            n = n + 1
            local token = it.port and "sem.rep.clsPort" or "sem.rep.clsJump"
            local a = Fade(1, it, t)
            Tone(line, token, a)
            local dx, dy = bx - ax, by - ay
            local d = sqrt(dx * dx + dy * dy)
            local h = min(HEAD, d * 0.4)
            local ux, uy = -dx / d * h, -dy / d * h
            local vx, vy = -uy * 0.9, ux * 0.9
            if ns.ReplayLayersView.Affine(head, bx - vx / 2, by - vy / 2, ux, uy, vx, vy) then Tone(head, token, a) end
        else
            head:Hide()
        end
    end
    list = active.circles
    for i = 1, nact.circles do
        local it = list[i]
        if nc >= CIRCLE_DRAW then break end
        local sx, sy, k = Screen(cam, scene, it.x, it.y)
        local rw = max(MIN_R, it.r * scene.ppy * cam.zoom * k)
        local tex = pool.circles[nc + 1]
        if k > 0 and ns.ReplayLayersView.Ellipse(tex, sx, sy, rw, max(1, rw * min(1, cam.tilt * k))) then
            nc = nc + 1
            Tone(tex, "sem.rep.clsCircle", Fade(1, it, t))
        end
    end
    for i = n + 1, used.arrows do
        pool.arrows[i]:Hide()
        pool.heads[i]:Hide()
    end
    for i = nc + 1, used.circles do pool.circles[i]:Hide() end
    used.arrows, used.circles = n, nc
    probe.arrows, probe.circles = n, nc
end
local function PlaceBeams(scene, cam)
    local n = 0
    local list = active.beams
    local focus = ns.ReplayLayersView.FocusName()
    local tracks = scene.tracks
    for i = 1, focus and nact.beams or 0 do
        local it = list[i]
        if n >= BEAM_DRAW then break end
        local a, b = scene.states[it.k], scene.states[it.p]
        local mine = tracks[it.k] and tracks[it.k].name == focus or tracks[it.p] and tracks[it.p].name == focus
        if mine and a and b and a.vis and b.vis and not a.dead and not b.dead then
            local ax, ay, ka = Screen(cam, scene, a.x, a.y)
            local bx, by, kb = Screen(cam, scene, b.x, b.y)
            if ka > 0 and kb > 0 and PutLine(pool.beams[n + 1], ax, ay, bx, by, BEAM_W) then n = n + 1 end
        end
    end
    for i = n + 1, used.beams do pool.beams[i]:Hide() end
    used.beams = n
    probe.beams = n
end
function V.Place(scene, cam, t)
    if not view then return end
    local cls = scene.layers and scene.layers.cls
    if not cls then
        if used.zones + used.rings + used.cones + used.arrows + used.circles + used.beams + used.icons > 0 then HideAll() end
        return
    end
    if memo.cls ~= cls or t < memo.from or t >= memo.to then
        memo.to = Collect(cls, t)
        memo.cls, memo.from = cls, t
    end
    local icons = used.icons
    used.icons = 0
    PlaceRound(scene, cam, t)
    PlaceCones(scene, cam, t)
    PlaceMoves(scene, cam, t)
    PlaceBeams(scene, cam)
    for i = used.icons + 1, icons do pool.icons[i]:Hide() end
    probe.icons = used.icons
end
function V.Probe()
    return probe
end
