local ADDON, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local sqrt = math.sqrt
local cos = math.cos
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
local SMOKE = "Spells\\ALPHACLOUD"
local RUNE = "Spells\\DemonicRuneSummon01"
local WISP = "Spells\\MAIL_RAIDHUNTER_G_01_PARTICLE01A"
local WISP_K = 0.78
local BACK_K = 1.12
local SPIN = 2 * math.pi / 5.5
local GROW = 0.63
local BORN = 0.2
local PUFF_DRAW = 48
local PUFF_GROW = 0.45
local PUFF_CORE = 0.55
local TOTEM_DRAW = 24
local TOTEM_ICON = 10
local TOTEM_YD = 0.8
local TOTEM_MIN = 3
local TOTEM_A = 0.9
local TOTEM_HOVER = 9
local REACH_FILL_A = 0.12
local CHAN_DRAW = 16
local CHAN_W = 2.5
local CHAN_CORE = 0.7
local CHAN_PULSE = 9
local CHAIN_DRAW = 6
local CHAIN_HOPS = 6
local CHAIN_W = 3
local CHAIN_CORE = 1
local CHAIN_IN = 0.1
local CHAIN_FADE = 0.4
local HIT_YD = 1.5
local HIT_MIN = 6
local OTHER_A = 0.5
local V = {}
ns.ReplayClassView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Replay = ns.Replay
local KINDS = { "zones", "rings", "cones", "arrows", "circles", "beams", "totems", "chans", "chains" }
local pool = { zones = {}, edges = {}, marks = {}, rings = {}, cones = {}, arrows = {}, heads = {}, circles = {}, wisps = {}, runeBacks = {},
               beams = {}, icons = {}, puffs = {}, cores = {}, tIcons = {}, tRings = {}, chans = {}, chanCores = {},
               bolts = {}, hits = {} }
local used = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0, icons = 0, puffs = 0, totems = 0,
               chans = 0, bolts = 0, hits = 0 }
local memo = { cls = nil, from = 0, to = -1 }
local active = { zones = {}, rings = {}, cones = {}, arrows = {}, circles = {}, beams = {}, totems = {}, chans = {},
                 chains = {} }
local nact = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0, totems = 0, chans = 0, chains = 0 }
local view
local hw, hh = 0, 0
local ICON_TC = { 0.07, 0.07, 0.07, 0.93, 0.93, 0.07, 0.93, 0.93 }
local probe = { zones = 0, rings = 0, cones = 0, arrows = 0, circles = 0, beams = 0, icons = 0, collects = 0, puffs = 0,
                totems = 0, chans = 0, chains = 0, bolts = 0, hits = 0 }
local tSx, tSy, tIt = {}, {}, {}
local hoverTotem
local roles = {}
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
    for i = 1, CIRCLE_DRAW do
        pool.runeBacks[i] = Tex(layer, DISC, "BACKGROUND")
        pool.circles[i] = Tex(layer, RUNE, "BORDER")
        pool.circles[i]:SetBlendMode("ADD")
        for j = 2 * i - 1, 2 * i do
            pool.wisps[j] = Tex(layer, WISP, "BORDER")
            pool.wisps[j]:SetBlendMode("ADD")
        end
    end
    for i = 1, BEAM_DRAW do pool.beams[i] = Tex(layer, LINE, "BORDER", "sem.rep.clsBeacon") end
    for i = 1, PUFF_DRAW do
        pool.puffs[i] = Tex(layer, SMOKE, "BACKGROUND")
        pool.cores[i] = Tex(layer, SMOKE, "BACKGROUND")
    end
    for i = 1, TOTEM_DRAW do
        pool.tRings[i] = Tex(layer, RING_S, "BORDER")
        tSx[i], tSy[i] = 0, 0
        local tex = layer:CreateTexture(nil, "ARTWORK")
        tex:SetWidth(TOTEM_ICON)
        tex:SetHeight(TOTEM_ICON)
        tex:Hide()
        pool.tIcons[i] = tex
    end
    pool.reach = { Tex(layer, DISC, "BACKGROUND"), Tex(layer, RING, "BORDER") }
    for i = 1, CHAN_DRAW do
        pool.chans[i] = Tex(layer, LINE, "BORDER")
        pool.chans[i]:SetBlendMode("ADD")
        pool.chanCores[i] = Tex(layer, LINE, "BORDER", "sem.rep.chanCore")
    end
    for i = 1, CHAIN_DRAW * CHAIN_HOPS do pool.hits[i] = Tex(layer, RING_S, "BORDER") end
    for i = 1, CHAIN_DRAW * CHAIN_HOPS * 2 do
        pool.bolts[i] = Tex(layer, LINE, "BORDER")
        pool.bolts[i]:SetBlendMode("ADD")
    end
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
function V.Use(scene, who)
    roles = who or {}
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
local Screen = RD.Screen
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
    local half = ICON / 2
    if not Kit.Crop(tex, view, hw, hh, sx - half, sy - half, sx + half, sy + half, ICON_TC) then return false end
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
local function PutFloor(tex, scene, cam, x, y, R, a)
    local ox, oy, ko = Screen(cam, scene, x, y)
    if ko <= 0 then
        tex:Hide()
        return false
    end
    R = max(R, MIN_R / (cam.zoom * ko))
    local c, s = cos(a) * R, sin(a) * R
    local ux, uy, ku = Screen(cam, scene, x + c, y + s)
    local vx, vy, kv = Screen(cam, scene, x - s, y + c)
    if ku <= 0 or kv <= 0 then
        tex:Hide()
        return false
    end
    ux, uy, vx, vy = ux - ox, uy - oy, vx - ox, vy - oy
    return ns.ReplayLayersView.Affine(tex, ox - ux - vx, oy - uy - vy, ux * 2, uy * 2, vx * 2, vy * 2)
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
        local age = t - it.from
        local g = min(1, (it.to - t) / GROW)
        local a = min(1, (it.to - t) / FADE_OUT)
        if not it.pre then
            g = min(g, age / GROW)
            a = min(a, age / FADE_IN)
        end
        local R = it.r * scene.ppy * (BORN + (1 - BORN) * max(0, g))
        local rune, w1, w2 = pool.circles[nc + 1], pool.wisps[2 * nc + 1], pool.wisps[2 * nc + 2]
        local back = pool.runeBacks[nc + 1]
        if PutFloor(rune, scene, cam, it.x, it.y, R, 0) then
            nc = nc + 1
            Tone(rune, "sem.rep.clsRune", a)
            if PutFloor(back, scene, cam, it.x, it.y, R * BACK_K, 0) then Tone(back, "sem.rep.clsRuneBack", a) end
            if PutFloor(w1, scene, cam, it.x, it.y, R * WISP_K, age * SPIN) then Tone(w1, "sem.rep.clsWisp", a) end
            if PutFloor(w2, scene, cam, it.x, it.y, R * WISP_K, math.pi - age * SPIN) then Tone(w2, "sem.rep.clsWisp", a) end
        else
            w1:Hide()
            w2:Hide()
            back:Hide()
        end
    end
    for i = n + 1, used.arrows do
        pool.arrows[i]:Hide()
        pool.heads[i]:Hide()
    end
    for i = nc + 1, used.circles do
        pool.circles[i]:Hide()
        pool.runeBacks[i]:Hide()
        pool.wisps[2 * i - 1]:Hide()
        pool.wisps[2 * i]:Hide()
    end
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
local function PlaceTrails(scene, cam, t)
    local list = scene.layers.cls.trails or {}
    local n = 0
    local PosAt = Replay.PosAtTime
    for i = 1, #list do
        local it = list[i]
        if it.from > t or n >= PUFF_DRAW then break end
        local d = it.def
        if it.to + d.life > t then
            local tr = scene.tracks[it.k]
            local ts = max(it.from, t - d.life)
            ts = it.from + math.ceil((ts - it.from) / d.step) * d.step
            while ts <= min(t, it.to) and n < PUFF_DRAW do
                local x, y = PosAt(tr, ts)
                if x >= 0 then
                    local sx, sy, k = Screen(cam, scene, x, y)
                    if k > 0 then
                        local age = (t - ts) / d.life
                        local rw = d.r * (1 + PUFF_GROW * age) * scene.ppy * cam.zoom * k
                        local rh = max(1, rw * min(1, cam.tilt * k))
                        local p, c = pool.puffs[n + 1], pool.cores[n + 1]
                        local cw, ch = rw * PUFF_CORE, rh * PUFF_CORE
                        if Kit.Crop(p, view, hw, hh, sx - rw, sy - rh, sx + rw, sy + rh) then
                            n = n + 1
                            Tone(p, d.tone, 1 - age)
                            if Kit.Crop(c, view, hw, hh, sx - cw, sy - ch, sx + cw, sy + ch) then
                                local r1, g1, b1, a1 = Kit.Color(d.core)
                                if d.old then
                                    local r2, g2, b2, a2 = Kit.Color(d.old)
                                    r1, g1, b1, a1 = r1 + (r2 - r1) * age, g1 + (g2 - g1) * age, b1 + (b2 - b1) * age,
                                        a1 + (a2 - a1) * age
                                end
                                c:SetVertexColor(r1, g1, b1, a1 * (1 - age))
                            end
                        end
                    end
                end
                ts = ts + d.step
            end
        end
    end
    for i = n + 1, used.puffs do
        pool.puffs[i]:Hide()
        pool.cores[i]:Hide()
    end
    used.puffs = n
    probe.puffs = n
end
local function PlaceTotems(scene, cam, t)
    local Ellipse = ns.ReplayLayersView.Ellipse
    local n, reach = 0, nil
    local list = active.totems
    local half = TOTEM_ICON / 2
    for i = 1, nact.totems do
        local it = list[i]
        if n >= TOTEM_DRAW then break end
        local sx, sy, k = Screen(cam, scene, it.x, it.y)
        if k > 0 then
            local rw = max(TOTEM_MIN, TOTEM_YD * scene.ppy * cam.zoom * k)
            local rh = max(1, rw * min(1, cam.tilt * k))
            local ring, icon = pool.tRings[n + 1], pool.tIcons[n + 1]
            local cy = sy - half
            if Kit.Crop(icon, view, hw, hh, sx - half, cy - half, sx + half, cy + half, ICON_TC) then
                n = n + 1
                if icon.id ~= it.icon then
                    icon.id = it.icon
                    Kit.Icon.Spell(icon, it.icon)
                end
                local a = Fade(TOTEM_A, it, t)
                icon:SetAlpha(a)
                if Ellipse(ring, sx, sy, rw, rh) then Tone(ring, it.tone, a) end
                tSx[n], tSy[n], tIt[n] = sx, cy, it
                if it == hoverTotem and (it.r or 0) > 0 then
                    local Rw = it.r * scene.ppy * cam.zoom * k
                    local Rh = max(1, Rw * min(1, cam.tilt * k))
                    reach = Rw
                    if Ellipse(pool.reach[1], sx, sy, Rw, Rh) then Tone(pool.reach[1], it.tone, REACH_FILL_A) end
                    if Ellipse(pool.reach[2], sx, sy, Rw, Rh) then Tone(pool.reach[2], it.tone, a) end
                end
            else
                ring:Hide()
            end
        end
    end
    for i = n + 1, used.totems do
        pool.tIcons[i]:Hide()
        pool.tRings[i]:Hide()
        tIt[i] = nil
    end
    if not reach then
        pool.reach[1]:Hide()
        pool.reach[2]:Hide()
    end
    used.totems = n
    probe.totems, probe.reach = n, reach or 0
end
function V.Hover(mx, my)
    local best, bestD = nil, TOTEM_HOVER * TOTEM_HOVER
    for i = 1, mx and used.totems or 0 do
        local dx, dy = tSx[i] - mx, tSy[i] - my
        local d = dx * dx + dy * dy
        if d < bestD then best, bestD = tIt[i], d end
    end
    hoverTotem = best
    return best ~= nil
end
local function TargetAt(scene, cam, tg, t)
    local x, y
    if type(tg) == "number" then
        local s = tg == 0 and scene.bossState or scene.states[tg]
        if not (s and s.vis) or s.dead then return 0, 0, false end
        x, y = s.x, s.y
    else
        if tg.from > t or tg.to <= t then return 0, 0, false end
        x, y = Replay.PosHold(tg, t, huge)
        if not x or x < 0 then return 0, 0, false end
    end
    local sx, sy, k = Screen(cam, scene, x, y)
    return sx, sy, k > 0
end
local function Whose(scene, k, focus)
    local name = scene.tracks[k] and scene.tracks[k].name
    local mine = name ~= nil and name == focus
    local UV = ns.ReplayUnitsView
    if UV and UV.CastShown and not UV.CastShown(roles[name or ""] or "dd", mine) then return nil end
    return (focus and not mine) and OTHER_A or 1
end
local function PlaceChans(scene, cam, t, focus)
    local n = 0
    local list = active.chans
    local pulse = 0.75 + 0.25 * sin(t * CHAN_PULSE)
    for i = 1, nact.chans do
        local it = list[i]
        if n >= CHAN_DRAW then break end
        local s = scene.states[it.k]
        local a = s and s.vis and not s.dead and Whose(scene, it.k, focus)
        if a then
            local ax, ay, ka = Screen(cam, scene, s.x, s.y)
            local bx, by, ok = TargetAt(scene, cam, it.tg, t)
            local glow, core = pool.chans[n + 1], pool.chanCores[n + 1]
            if ka > 0 and ok and PutLine(glow, ax, ay, bx, by, CHAN_W) then
                n = n + 1
                a = a * min(1, (t - it.from) / BORN, (it.to - t) / BORN)
                Tone(glow, it.tone, a * pulse)
                if PutLine(core, ax, ay, bx, by, CHAN_CORE) then Tone(core, "sem.rep.chanCore", a) end
            else
                core:Hide()
            end
        end
    end
    for i = n + 1, used.chans do
        pool.chans[i]:Hide()
        pool.chanCores[i]:Hide()
    end
    used.chans = n
    probe.chans = n
end
local function PutHit(ring, scene, cam, tg, t)
    local x, y
    if type(tg) == "number" then
        local s = tg == 0 and scene.bossState or scene.states[tg]
        if not (s and s.vis) or s.dead then return false end
        x, y = s.x, s.y
    else
        if tg.from > t or tg.to <= t then return false end
        x, y = Replay.PosHold(tg, t, huge)
        if not x or x < 0 then return false end
    end
    local sx, sy, k = Screen(cam, scene, x, y)
    if k <= 0 then return false end
    local rw = max(HIT_MIN, HIT_YD * scene.ppy * cam.zoom * k)
    return ns.ReplayLayersView.Ellipse(ring, sx, sy, rw, max(1, rw * min(1, cam.tilt * k)))
end
local function PlaceChains(scene, cam, t, focus)
    local n, nh, nc = 0, 0, 0
    local list = active.chains
    local per = CHAIN_HOPS * 2
    for i = 1, nact.chains do
        local it = list[i]
        if nc >= CHAIN_DRAW then break end
        local s = scene.states[it.k]
        local a = s and s.vis and not s.dead and Whose(scene, it.k, focus)
        if a then
            local base, hbase = nc * per, nc * CHAIN_HOPS
            local m, mh = base, hbase
            a = a * min(1, (t - it.from) / CHAIN_IN, (it.to - t) / CHAIN_FADE)
            local ax, ay, ka = Screen(cam, scene, s.x, s.y)
            local okA = ka > 0
            for h = 1, min(#it.hops, CHAIN_HOPS) do
                local tg = it.hops[h]
                local bx, by, okB = TargetAt(scene, cam, tg, t)
                if okB then
                    if okA and PutLine(pool.bolts[m + 1], ax, ay, bx, by, CHAIN_W) then
                        Tone(pool.bolts[m + 1], it.tone, a)
                        m = m + 1
                        if PutLine(pool.bolts[m + 1], ax, ay, bx, by, CHAIN_CORE) then
                            Tone(pool.bolts[m + 1], "sem.rep.chanCore", a)
                            m = m + 1
                        end
                    end
                    local ring = pool.hits[mh + 1]
                    if PutHit(ring, scene, cam, tg, t) then
                        Tone(ring, it.tone, a)
                        mh = mh + 1
                    end
                    ax, ay, okA = bx, by, true
                end
            end
            for j = m + 1, base + per do pool.bolts[j]:Hide() end
            for j = mh + 1, hbase + CHAIN_HOPS do pool.hits[j]:Hide() end
            if m > base or mh > hbase then
                nc = nc + 1
                n, nh = n + (m - base), nh + (mh - hbase)
            end
        end
    end
    for j = nc * per + 1, used.bolts do pool.bolts[j]:Hide() end
    for j = nc * CHAIN_HOPS + 1, used.hits do pool.hits[j]:Hide() end
    used.bolts, used.hits = nc * per, nc * CHAIN_HOPS
    probe.chains, probe.bolts, probe.hits = nc, n, nh
end
function V.Place(scene, cam, t)
    if not view then return end
    local cls = scene.layers and scene.layers.cls
    if not cls then
        if used.zones + used.rings + used.cones + used.arrows + used.circles + used.beams + used.icons + used.puffs
            + used.totems + used.chans + used.bolts + used.hits > 0 then
            HideAll()
        end
        return
    end
    if memo.cls ~= cls or t < memo.from or t >= memo.to then
        memo.to = Collect(cls, t)
        memo.cls, memo.from = cls, t
    end
    local icons = used.icons
    used.icons = 0
    hw, hh = cam.w / 2, cam.h / 2
    PlaceRound(scene, cam, t)
    PlaceCones(scene, cam, t)
    PlaceMoves(scene, cam, t)
    PlaceBeams(scene, cam)
    PlaceTrails(scene, cam, t)
    local focus = ns.ReplayLayersView.FocusName()
    PlaceTotems(scene, cam, t)
    PlaceChans(scene, cam, t, focus)
    PlaceChains(scene, cam, t, focus)
    for i = used.icons + 1, icons do pool.icons[i]:Hide() end
    probe.icons = used.icons
end
function V.Probe()
    return probe
end
