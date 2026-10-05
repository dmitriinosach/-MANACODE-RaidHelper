local ADDON, ns = ...
local max = math.max
local min = math.min
local sqrt = math.sqrt
local ceil = math.ceil
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local RIM = ART .. "rim"
local DISC = ART .. "disc256"
local LINE = ART .. "line"
local CONE = ART .. "cone"
local RING_DRAW = 4
local ARROW_DRAW = 12
local LINK_DRAW = 12
local MAX_PX = 4000
local LINE_W = 3
local HEAD_L = 14
local HEAD_W = 12
local GAP = 7
local FILL = 0.35
local ADD_HOLD = 4
local EMPTY = {}
local V = {}
ns.ReplayCueView = V
local Kit = ns.Kit
local Replay = ns.Replay
local rims, fills, flashes, counts = {}, {}, {}, {}
local shafts, heads, links = {}, {}, {}
local used = { ring = 0, fill = 0, flash = 0, count = 0, arrow = 0, link = 0 }
local view
local hw, hh = 0, 0
local probe = { rings = 0, fills = 0, flashes = 0, counts = 0, arrows = 0, links = 0, count = nil, fillR = 0 }
local function Tex(layer, path, draw)
    local tex = layer:CreateTexture(nil, draw)
    tex:SetTexture(path)
    tex:Hide()
    return tex
end
function V.Build(v, layer)
    view = v
    for i = 1, RING_DRAW do
        fills[i] = Tex(layer, DISC, "BACKGROUND")
        rims[i] = Tex(layer, RIM, "BORDER")
        flashes[i] = Tex(layer, DISC, "ARTWORK")
        local fs = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        Kit.Text(fs, "sem.rep.count")
        fs:Hide()
        counts[i] = fs
    end
    for i = 1, ARROW_DRAW do
        shafts[i] = Tex(layer, LINE, "ARTWORK")
        heads[i] = Tex(layer, CONE, "ARTWORK")
    end
    for i = 1, LINK_DRAW do links[i] = Tex(layer, LINE, "BORDER") end
end
local function HideRange(list, from, to)
    for i = from + 1, to do list[i]:Hide() end
end
function V.Use(scene)
    if not view then return end
    HideRange(rims, 0, #rims)
    HideRange(fills, 0, #fills)
    HideRange(flashes, 0, #flashes)
    HideRange(counts, 0, #counts)
    HideRange(shafts, 0, #shafts)
    HideRange(heads, 0, #heads)
    HideRange(links, 0, #links)
    for k in pairs(used) do used[k] = 0 end
    for i = 1, #counts do counts[i].left = nil end
end
local function PutRect(tex, l, t, r, b)
    local cl, ct, cr, cb = max(l, -hw), max(t, -hh), min(r, hw), min(b, hh)
    if cr - cl < 1 or cb - ct < 1 then
        tex:Hide()
        return false
    end
    local w, h = r - l, b - t
    local a0, a1 = (cl - l) / w, (cr - l) / w
    local b0, b1 = (ct - t) / h, (cb - t) / h
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", view, "CENTER", cl, -ct)
    tex:SetWidth(cr - cl)
    tex:SetHeight(cb - ct)
    tex:SetTexCoord(a0, b0, a0, b1, a1, b0, a1, b1)
    tex:Show()
    return true
end
local function PutEllipse(tex, sx, sy, rw, rh)
    if rw * 2 > MAX_PX then
        tex:Hide()
        return false
    end
    return PutRect(tex, sx - rw, sy - rh, sx + rw, sy + rh)
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
local function Screen(cam, scene, x, y)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
local function Fade(a, from, to, t)
    local left = to - t
    if left < 1 then a = a * max(0, left) end
    local born = t - from
    if born < 0.3 then a = a * max(0.3, born / 0.3) end
    return a
end
local function RingAt(scene, o, t)
    if o.add then return Replay.PosHold(o.add, t, ADD_HOLD) end
    local b = scene.bossState
    if b and b.vis then return b.x, b.y end
    return -1, -1
end
local function PlaceRings(scene, cam, t, list)
    local nr, nf, nx, nc = 0, 0, 0, 0
    probe.count, probe.fillR = nil, 0
    for i = 1, #list do
        local o = list[i]
        if o.from > t or nr >= RING_DRAW then break end
        if o.to > t then
            local x, y = RingAt(scene, o, t)
            local sx, sy, k = -1, -1, 0
            if x >= 0 then sx, sy, k = Screen(cam, scene, x, y) end
            if k > 0 then
                local s, tilt = scene.ppy * cam.zoom * k, min(1, cam.tilt * k)
                local rw = o.r * s
                local def = o.def
                if t < o.boom then
                    local r, g, b, a = Kit.Color(def.tone)
                    if PutEllipse(rims[nr + 1], sx, sy, rw, max(1, rw * tilt)) then
                        nr = nr + 1
                        rims[nr]:SetVertexColor(r, g, b, a * min(1, (t - o.from) / 0.3 + 0.3))
                    end
                    local p = (t - o.from) / max(0.1, o.boom - o.from)
                    local fw = rw * p
                    if fw >= 1 and PutEllipse(fills[nf + 1], sx, sy, fw, max(1, fw * tilt)) then
                        nf = nf + 1
                        fills[nf]:SetVertexColor(r, g, b, a * FILL)
                        probe.fillR = o.r * p
                    end
                    local left = max(1, ceil(o.boom - t))
                    local fs = counts[nc + 1]
                    if fs then
                        nc = nc + 1
                        if fs.left ~= left then
                            fs.left = left
                            fs:SetText(tostring(left))
                        end
                        fs:ClearAllPoints()
                        fs:SetPoint("CENTER", view, "CENTER", sx, -sy)
                        fs:Show()
                        probe.count = probe.count or left
                    end
                elseif PutEllipse(flashes[nx + 1], sx, sy, rw, max(1, rw * tilt)) then
                    nx = nx + 1
                    local r, g, b, a = Kit.Color(def.flashTone)
                    flashes[nx]:SetVertexColor(r, g, b, a * (1 - (t - o.boom) / max(0.1, o.to - o.boom)))
                end
            end
        end
    end
    HideRange(rims, nr, used.ring)
    HideRange(fills, nf, used.fill)
    HideRange(flashes, nx, used.flash)
    HideRange(counts, nc, used.count)
    used.ring, used.fill, used.flash, used.count = nr, nf, nx, nc
    probe.rings, probe.fills, probe.flashes, probe.counts = nr, nf, nx, nc
end
local function Who(scene, cam, k)
    local st = k == 0 and scene.bossState or scene.states[k]
    if not (st and st.vis) or st.dead then return 0, 0, false end
    local sx, sy, kk = Screen(cam, scene, st.x, st.y)
    return sx, sy, kk > 0
end
local function PlacePairs(scene, cam, t, C)
    local na, nl = 0, 0
    local list = C.arrows
    for i = 1, #list do
        local e = list[i]
        if e.from > t or na >= ARROW_DRAW then break end
        if e.to > t then
            local ax, ay, okA = Who(scene, cam, e.a)
            local bx, by, okB = Who(scene, cam, e.b)
            local dx, dy = bx - ax, by - ay
            local d = sqrt(dx * dx + dy * dy)
            if okA and okB and d > GAP * 2 + HEAD_L then
                local ux, uy = dx / d, dy / d
                local tx, ty = bx - ux * GAP, by - uy * GAP
                local hx, hy = tx - ux * HEAD_L, ty - uy * HEAD_L
                local sx, sy = ax + ux * GAP, ay + uy * GAP
                local r, g, b, a = Kit.Color(e.def.tone)
                a = Fade(a, e.from, e.to, t)
                local nx, ny = -uy * LINE_W * 2, ux * LINE_W * 2
                local wx, wy = -uy * HEAD_W, ux * HEAD_W
                if PutAffine(shafts[na + 1], sx - nx / 2, sy - ny / 2, hx - sx, hy - sy, nx, ny) then
                    if PutAffine(heads[na + 1], tx - wx / 2, ty - wy / 2, hx - tx, hy - ty, wx, wy) then
                        na = na + 1
                        shafts[na]:SetVertexColor(r, g, b, a)
                        heads[na]:SetVertexColor(r, g, b, a)
                    else
                        shafts[na + 1]:Hide()
                    end
                end
            end
        end
    end
    list = C.links
    for i = 1, #list do
        local e = list[i]
        if e.from > t or nl >= LINK_DRAW then break end
        if e.to > t then
            local ax, ay, okA = Who(scene, cam, e.a)
            local bx, by, okB = Who(scene, cam, e.b)
            local dx, dy = bx - ax, by - ay
            local d = sqrt(dx * dx + dy * dy)
            if okA and okB and d >= 2 then
                local nx, ny = -dy / d * LINE_W * 2, dx / d * LINE_W * 2
                if PutAffine(links[nl + 1], ax - nx / 2, ay - ny / 2, dx, dy, nx, ny) then
                    nl = nl + 1
                    local r, g, b, a = Kit.Color(e.def.tone)
                    links[nl]:SetVertexColor(r, g, b, Fade(a, e.from, e.to, t))
                end
            end
        end
    end
    HideRange(shafts, na, used.arrow)
    HideRange(heads, na, used.arrow)
    HideRange(links, nl, used.link)
    used.arrow, used.link = na, nl
    probe.arrows, probe.links = na, nl
end
function V.Place(scene, cam, t)
    if not view then return end
    local C = scene.layers and scene.layers.cue
    hw, hh = cam.w / 2, cam.h / 2
    PlaceRings(scene, cam, t, C and C.rings or EMPTY)
    if C then
        PlacePairs(scene, cam, t, C)
    elseif used.arrow + used.link > 0 then
        HideRange(shafts, 0, used.arrow)
        HideRange(heads, 0, used.arrow)
        HideRange(links, 0, used.link)
        used.arrow, used.link = 0, 0
        probe.arrows, probe.links = 0, 0
    end
end
function V.Probe()
    return probe
end
