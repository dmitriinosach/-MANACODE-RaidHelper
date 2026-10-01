local _, ns = ...
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local BASE_POOL = 640
local OVER_POOL = 120
local FLOOR_N = 4
local FLOOR_FIT = 2.6
local MAX_STRIPS = 6
local MAX_SLICES = 3
local BUCKETS = 256
local KEY_MAX = 140
local MIN_PX = 2
local NZ_FLAT = 0.64
local OVER_ALPHA = 0.42
local OVER_TINT = "text.secondary"
local EPS = 1e-6
local POOL_BASE = 1
local POOL_OVER = 2
local POOL_FLOOR = 3
local POOL_RING = 4
local RING_POOL = 400
local RING_ALPHA_MIN = 0.02
local RING_STONE = "sem.room.stone"
local RING_ICE = "sem.room.ice"
local Live = {}
ns.ReplayLive = Live
local Replay = ns.Replay
local Kit = ns.Kit
local F = { n = 0, cx = {}, cy = {}, cz = {}, ux = {}, uy = {}, uz = {}, vx = {}, vy = {}, vz = {}, nx = {}, ny = {}, nz = {},
            hu = {}, hv = {}, cu = {}, cv = {}, q = {}, du = {}, dv = {}, kind = {}, shell = {}, flat = {}, floor = {},
            fx = {}, fy = {}, fz = {}, kz = {}, ringS = {}, ringB = {} }
local P = { a1 = {}, b1 = {}, a2 = {}, b2 = {}, sx = {}, sy = {}, over = {}, nxt = {}, rkey = {} }
local ringList = {}
local Pr = { n = 0, row = {} }
local PROP_CELL = 8
local head, tail = {}, {}
local st = { floors = {}, bases = {}, overs = {}, rings = {}, used = { [POOL_BASE] = 0, [POOL_OVER] = 0, [POOL_FLOOR] = 0, [POOL_RING] = 0 },
             calls = 0, pieces = 0, hidden = 0, ringOk = false, t = 0, pfDone = -1, texA = {}, texIce = {}, path = {} }
function Live.Build(view, level)
    st.view = view
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(level)
    top:SetAlpha(OVER_ALPHA)
    st.top = top
    for k = 1, RING_POOL do
        st.rings[k] = view:CreateTexture(nil, "BORDER")
        st.rings[k]:Hide()
    end
    for k = 1, FLOOR_N * FLOOR_N do
        st.floors[k] = view:CreateTexture(nil, "BORDER")
        st.floors[k]:Hide()
    end
    for k = 1, BASE_POOL do
        st.bases[k] = view:CreateTexture(nil, "ARTWORK")
        st.bases[k]:Hide()
    end
    for k = 1, OVER_POOL do
        st.overs[k] = top:CreateTexture(nil, "ARTWORK")
        st.overs[k]:Hide()
    end
end
local pools = { st.bases, st.overs, st.floors, st.rings }
function Live.HideAll()
    for p = 1, 4 do
        local list, used = pools[p], st.used[p]
        for k = 1, used do list[k]:Hide() end
        st.used[p] = 0
    end
end
function Live.Release()
    Live.HideAll()
    for p = 1, 4 do
        local list = pools[p]
        for k = 1, #list do list[k]:SetTexture(nil) end
    end
    st.room, st.data, st.ringOk, st.pf, st.pfScene, st.pfDone = nil, nil, false, nil, nil, -1
    st.atlasPath, st.propsPath = nil, nil
    for tex in pairs(st.path) do st.path[tex] = nil end
    Pr.n = 0
end
local function SetFace(i, row)
    F.cx[i], F.cy[i], F.cz[i] = row[1], row[2], row[3]
    F.ux[i], F.uy[i], F.uz[i] = row[4], row[5], row[6]
    F.vx[i], F.vy[i], F.vz[i] = row[7], row[8], row[9]
    F.hu[i], F.hv[i] = row[10], row[11]
    F.cu[i], F.cv[i], F.q[i] = row[12], row[13], row[14]
    F.du[i], F.dv[i] = row[15], row[16]
    F.kind[i], F.shell[i] = row[17], row[18]
    local nx = row[5] * row[9] - row[6] * row[8]
    local ny = row[6] * row[7] - row[4] * row[9]
    local nz = row[4] * row[8] - row[5] * row[7]
    F.nx[i], F.ny[i], F.nz[i] = nx, ny, nz
    F.fx[i], F.fy[i], F.fz[i] = row[19] or nx, row[20] or ny, row[21] or nz
    F.kz[i] = row[22] or 0
    F.ringS[i], F.ringB[i] = row[23], row[24]
    F.flat[i] = nz > NZ_FLAT
    F.floor[i] = false
end
local function Load(d)
    local faces = d.faces
    local n = 0
    for k = 1, #faces do
        n = n + 1
        SetFace(n, faces[k])
    end
    local pieces = d.ring and d.ring.pieces or {}
    for k = 1, #pieces do
        n = n + 1
        SetFace(n, pieces[k])
    end
    local w = d.fhalf / FLOOR_FIT
    local q = 1 / (2 * d.fhalf)
    local dm = w / 2
    for a = 1, FLOOR_N do
        for b = 1, FLOOR_N do
            n = n + 1
            local tx, ty = (a - (FLOOR_N + 1) / 2) * w, (b - (FLOOR_N + 1) / 2) * w
            SetFace(n, { (d.fcx or 0) + tx, (d.fcy or 0) + ty, 0, 1, 0, 0, 0, 1, 0, w / 2, w / 2, 0.5 + tx * q, 0.5 - ty * q, q, dm, dm, 1, 0 })
            F.floor[n] = true
        end
    end
    F.n = n
    for i = n + 1, #F.cx do F.cx[i] = nil end
end
function Live.Use(room)
    if room and room == st.room then return true end
    Live.Release()
    local d = room and ns.roomLive and ns.roomLive[room.tex]
    if not d or not st.view then return false end
    local atlas, fl = d.art .. "_atlas", d.art .. "_floor"
    if not st.bases[1]:SetTexture(atlas) or not st.floors[1]:SetTexture(fl) then
        Live.Release()
        return false
    end
    for k = 2, #st.bases do st.bases[k]:SetTexture(atlas) end
    for k = 1, #st.bases do st.path[st.bases[k]] = atlas end
    st.atlasPath = atlas
    local pr = d.props
    if pr and st.bases[#st.bases]:SetTexture(d.art .. "_props") then
        st.propsPath = d.art .. "_props"
        st.path[st.bases[#st.bases]] = st.propsPath
        Pr.n, Pr.k = #pr.list, pr.n
        for p = 1, #pr.list do Pr.row[p] = pr.list[p] end
    else
        Pr.n = 0
    end
    for k = 2, #st.floors do st.floors[k]:SetTexture(fl) end
    for k = 1, #st.overs do
        st.overs[k]:SetTexture(atlas)
        Kit.Tint(st.overs[k], OVER_TINT)
    end
    st.ringOk = d.ring ~= nil and st.rings[1]:SetTexture(d.art .. "_ring") and true or false
    for k = 1, #st.rings do
        if st.ringOk then st.rings[k]:SetTexture(d.art .. "_ring") end
        st.texA[st.rings[k]], st.texIce[st.rings[k]] = nil, nil
    end
    Load(d)
    st.room, st.data = room, d
    return true
end
function Live.Time(scene, t)
    st.t = t
    local d = st.data
    if not d or not d.ring or not st.ringOk or not scene then return false end
    if st.pfScene ~= scene then
        local Platform = ns.ReplayPlatform
        local def = Platform and scene.fight and Platform.Def(scene.fight.boss)
        local L = scene.layers
        if not def or Replay.ROOMS[def.room] ~= st.room then
            st.pf, st.pfScene = nil, scene
        elseif L and L.pfQuake then
            st.pf = { tl = Platform.Timeline(def, L.pfQuake, L.pfWinter), def = def, ring = d.ring }
            st.pfScene, st.pfDone = scene, -1
        else
            return false
        end
    end
    local pf = st.pf
    if not pf then return false end
    local busy, done = ns.ReplayPlatform.State(pf.tl, pf.def, pf.ring, t)
    local changed = busy or done ~= st.pfDone
    st.pfDone = done
    return changed
end
function Live.Has(room)
    return room ~= nil and room == st.room
end
local function Put(tex, l, t, r, b, sx, sy, i11, i12, i21, i22, cu, cv, q, hw, hh)
    local x0, x1 = max(l, -hw), min(r, hw)
    local y0, y1 = max(t, -hh), min(b, hh)
    if x1 - x0 < 1 or y1 - y0 < 1 then return false end
    tex:SetPoint("TOPLEFT", st.view, "CENTER", x0, -y0)
    tex:SetWidth(x1 - x0)
    tex:SetHeight(y1 - y0)
    local dx0, dx1, dy0, dy1 = x0 - sx, x1 - sx, y0 - sy, y1 - sy
    tex:SetTexCoord(
        cu + (i11 * dx0 + i12 * dy0) * q, cv - (i21 * dx0 + i22 * dy0) * q,
        cu + (i11 * dx0 + i12 * dy1) * q, cv - (i21 * dx0 + i22 * dy1) * q,
        cu + (i11 * dx1 + i12 * dy0) * q, cv - (i21 * dx1 + i22 * dy0) * q,
        cu + (i11 * dx1 + i12 * dy1) * q, cv - (i21 * dx1 + i22 * dy1) * q)
    tex:Show()
    st.calls = st.calls + 5
    return true
end
local function Pieces(i, pool, hw, hh)
    local a1, b1, a2, b2, sx, sy = P.a1[i], P.b1[i], P.a2[i], P.b2[i], P.sx[i], P.sy[i]
    local det = a1 * b2 - a2 * b1
    local inv = 1 / det
    local i11, i12, i21, i22 = b2 * inv, -a2 * inv, -b1 * inv, a1 * inv
    local h1, h2 = F.hu[i], F.hv[i]
    local A1, B1, A2, B2 = abs(a1), abs(b1), abs(a2), abs(b2)
    local nu, nv = 1, 1
    if F.kind[i] >= 2 then
        local I11, I12, I21, I22 = abs(i11), abs(i12), abs(i21), abs(i22)
        local gU1 = max(0, I11 * A1 + I12 * B1 - 1)
        local gU2 = I11 * A2 + I12 * B2
        local gV1 = I21 * A1 + I22 * B1
        local gV2 = max(0, I21 * A2 + I22 * B2 - 1)
        local du, dv = F.du[i], F.dv[i]
        nu = nil
        for k = 1, MAX_SLICES do
            local h2k = h2 / k
            local remV, remU = dv - h2k * gV2, du - h2k * gU2
            if remV > EPS and remU > EPS then
                local need = max(h1 * gV1 / remV, h1 * gU1 / remU, 1)
                if need <= MAX_STRIPS + 0.001 then
                    nu, nv = ceil(need - 0.001), k
                    break
                end
            end
        end
        if not nu then
            st.hidden = st.hidden + 1
            return
        end
    end
    local list, cu, cv, q = pools[pool], F.cu[i], F.cv[i], F.q[i]
    local fix = pool == POOL_BASE and st.propsPath
    local bx, by = A1 * h1 / nu + A2 * h2 / nv, B1 * h1 / nu + B2 * h2 / nv
    for a = 1, nu do
        local ou = -h1 + (2 * a - 1) * h1 / nu
        for b = 1, nv do
            local ov = -h2 + (2 * b - 1) * h2 / nv
            local used = st.used[pool] + 1
            local tex = list[used]
            if not tex then return end
            if fix and st.path[tex] ~= st.atlasPath then
                tex:SetTexture(st.atlasPath)
                st.path[tex] = st.atlasPath
                st.calls = st.calls + 1
            end
            local px, py = sx + a1 * ou + a2 * ov, sy + b1 * ou + b2 * ov
            if Put(tex, px - bx, py - by, px + bx, py + by, px, py, i11, i12, i21, i22, cu + ou * q, cv - ov * q, q, hw, hh) then
                st.used[pool] = used
                st.pieces = st.pieces + 1
            end
        end
    end
end
local function PlaceProp(p, l, t, w, h, hw, hh)
    local x0, x1 = max(l, -hw), min(l + w, hw)
    local y0, y1 = max(t, -hh), min(t + h, hh)
    if x1 - x0 < 1 or y1 - y0 < 1 then return end
    local used = st.used[POOL_BASE] + 1
    local tex = st.bases[used]
    if not tex then return end
    if st.path[tex] ~= st.propsPath then
        tex:SetTexture(st.propsPath)
        st.path[tex] = st.propsPath
        st.calls = st.calls + 1
    end
    local o = 4 + PROP_CELL * P.pk
    local row = Pr.row[p]
    local u0, v0, u1, v1 = row[o], row[o + 1], row[o + 2], row[o + 3]
    local a0, a1 = u0 + (u1 - u0) * (x0 - l) / w, u0 + (u1 - u0) * (x1 - l) / w
    local b0, b1 = v0 + (v1 - v0) * (y0 - t) / h, v0 + (v1 - v0) * (y1 - t) / h
    tex:SetPoint("TOPLEFT", st.view, "CENTER", x0, -y0)
    tex:SetWidth(x1 - x0)
    tex:SetHeight(y1 - y0)
    tex:SetTexCoord(a0, b0, a0, b1, a1, b0, a1, b1)
    tex:Show()
    st.calls = st.calls + 5
    st.used[POOL_BASE] = used
    st.pieces = st.pieces + 1
end
local function Shade(from, to, alpha, ice)
    local list, texA, texIce = st.rings, st.texA, st.texIce
    local tok = ice and RING_ICE or RING_STONE
    for j = from, to do
        local tex = list[j]
        if texA[tex] ~= alpha or texIce[tex] ~= ice then
            Kit.Hue(tex, tok, alpha)
            texA[tex], texIce[tex] = alpha, ice
            st.calls = st.calls + 1
        end
    end
end
local function PlaceRing(n, hw, hh)
    local key = P.rkey
    for a = 2, n do
        local i, kv = ringList[a], key[ringList[a]]
        local b = a - 1
        while b >= 1 and key[ringList[b]] > kv do
            ringList[b + 1] = ringList[b]
            b = b - 1
        end
        ringList[b + 1] = i
    end
    local pf = st.pf
    local Platform = ns.ReplayPlatform
    for a = 1, n do
        local i = ringList[a]
        local alpha, ice = 1, false
        if pf then
            local a, _, e = Platform.Piece(pf.tl, pf.def, pf.ring, F.ringS[i], F.ringB[i], st.t)
            alpha, ice = a, e
        end
        local u0 = st.used[POOL_RING]
        Pieces(i, POOL_RING, hw, hh)
        Shade(u0 + 1, st.used[POOL_RING], alpha, ice)
    end
end
function Live.Place(cam, room, ppy)
    if room ~= st.room or not st.data then return false end
    local prevUsed = { st.used[1], st.used[2], st.used[3], st.used[4] }
    st.used[1], st.used[2], st.used[3], st.used[4] = 0, 0, 0, 0
    st.calls, st.pieces, st.hidden = 0, 0, 0
    local c, s, t = cam.c, cam.s, cam.tilt
    local k = sqrt(max(0, 1 - t * t))
    local zp = cam.zoom * ppy
    local ox, oy = Replay.Project(cam, room.cx, room.cy)
    local hw, hh = cam.w / 2, cam.h / 2
    local vwx, vwy, vwz = s * k, c * k, t
    local cx, cy, cz, ux, uy, uz, vx, vy, vz = F.cx, F.cy, F.cz, F.ux, F.uy, F.uz, F.vx, F.vy, F.vz
    local fx, fy, fz, hu, hv, shell, flat, floorF, kind, kz = F.fx, F.fy, F.fz, F.hu, F.hv, F.shell, F.flat, F.floor, F.kind, F.kz
    local pa1, pb1, pa2, pb2, psx, psy, pover, nxt = P.a1, P.b1, P.a2, P.b2, P.sx, P.sy, P.over, P.nxt
    for b = 1, BUCKETS do head[b] = 0 tail[b] = 0 end
    local kscale = BUCKETS / (2 * KEY_MAX)
    local ringS, pf, nRing = F.ringS, st.pf, 0
    local Platform = ns.ReplayPlatform
    for i = 1, F.n do
        if ringS[i] then
            if st.ringOk then
                local alpha, dz = 1, 0
                if pf then alpha, dz = Platform.Piece(pf.tl, pf.def, pf.ring, ringS[i], F.ringB[i], st.t) end
                if alpha > RING_ALPHA_MIN then
                    local a1 = (ux[i] * c - uy[i] * s) * zp
                    local b1 = ((ux[i] * s + uy[i] * c) * t - uz[i] * k) * zp
                    local a2 = (vx[i] * c - vy[i] * s) * zp
                    local b2 = ((vx[i] * s + vy[i] * c) * t - vz[i] * k) * zp
                    local h1, h2 = hu[i], hv[i]
                    local bx = abs(a1) * h1 + abs(a2) * h2
                    local by = abs(b1) * h1 + abs(b2) * h2
                    local z = cz[i] + dz
                    local sx = ox + (cx[i] * c - cy[i] * s) * zp
                    local sy = oy + ((cx[i] * s + cy[i] * c) * t - z * k) * zp
                    if sx + bx > -hw and sx - bx < hw and sy + by > -hh and sy - by < hh then
                        pa1[i], pb1[i], pa2[i], pb2[i], psx[i], psy[i] = a1, b1, a2, b2, sx, sy
                        nRing = nRing + 1
                        ringList[nRing] = i
                        P.rkey[i] = (cx[i] * s + cy[i] * c) * k + z * t
                    end
                end
            end
        else
        local nd = fx[i] * vwx + fy[i] * vwy + fz[i] * vwz
        local front = nd > 0
        if front or shell[i] == 1 then
            local a1 = (ux[i] * c - uy[i] * s) * zp
            local b1 = ((ux[i] * s + uy[i] * c) * t - uz[i] * k) * zp
            local a2 = (vx[i] * c - vy[i] * s) * zp
            local b2 = ((vx[i] * s + vy[i] * c) * t - vz[i] * k) * zp
            local h1, h2 = hu[i], hv[i]
            local bx = abs(a1) * h1 + abs(a2) * h2
            local by = abs(b1) * h1 + abs(b2) * h2
            local sx = ox + (cx[i] * c - cy[i] * s) * zp
            local sy = oy + ((cx[i] * s + cy[i] * c) * t - cz[i] * k) * zp
            if abs(a1 * b2 - a2 * b1) * h1 * h2 * 4 >= MIN_PX * MIN_PX and sx + bx > -hw and sx - bx < hw and sy + by > -hh and sy - by < hh then
                pa1[i], pb1[i], pa2[i], pb2[i], psx[i], psy[i] = a1, b1, a2, b2, sx, sy
                if floorF[i] then
                    Pieces(i, POOL_FLOOR, hw, hh)
                elseif not front then
                    Pieces(i, POOL_OVER, hw, hh)
                else
                    local key
                    if kind[i] == 3 then
                        key = ((cx[i] + fx[i] * h2) * s + (cy[i] + fy[i] * h2) * c) * k + kz[i] * t - 0.002
                    elseif flat[i] then
                        key = ((cx[i] * s + cy[i] * c) * k + cz[i] * t) - abs((ux[i] * s + uy[i] * c) * k + uz[i] * t) * h1 - abs((vx[i] * s + vy[i] * c) * k + vz[i] * t) * h2
                    else
                        key = ((cx[i] - vx[i] * h2) * s + (cy[i] - vy[i] * h2) * c) * k + (cz[i] - vz[i] * h2) * t + 0.001
                    end
                    local b = floor((key + KEY_MAX) * kscale) + 1
                    if b < 1 then b = 1 elseif b > BUCKETS then b = BUCKETS end
                    nxt[i] = 0
                    if tail[b] == 0 then head[b] = i else nxt[tail[b]] = i end
                    tail[b] = i
                end
            end
        end
        end
    end
    local nF = F.n
    if Pr.n > 0 then
        local twoPi = 2 * math.pi
        P.pk = floor(((cam.angle % twoPi) / twoPi) * Pr.k + 0.5) % Pr.k
        local o = 4 + PROP_CELL * P.pk
        for p = 1, Pr.n do
            local row = Pr.row[p]
            local x, y, z = row[1], row[2], row[3]
            local w, h, ax, ay = row[o + 4] * zp, row[o + 5] * zp, row[o + 6] * zp, row[o + 7] * zp
            local sx = ox + (x * c - y * s) * zp
            local sy = oy + ((x * s + y * c) * t - z * k) * zp
            local l, tp = sx - ax, sy - ay
            if l + w > -hw and l < hw and tp + h > -hh and tp < hh then
                local i = nF + p
                P.sx[i], P.sy[i], P.a1[i], P.b1[i] = l, tp, w, h
                local key = (x * s + y * c) * k + z * t
                local b = floor((key + KEY_MAX) * kscale) + 1
                if b < 1 then b = 1 elseif b > BUCKETS then b = BUCKETS end
                nxt[i] = 0
                if tail[b] == 0 then head[b] = i else nxt[tail[b]] = i end
                tail[b] = i
            end
        end
    end
    PlaceRing(nRing, hw, hh)
    for b = 1, BUCKETS do
        local i = head[b]
        while i ~= 0 do
            if i > nF then
                PlaceProp(i - nF, P.sx[i], P.sy[i], P.a1[i], P.b1[i], hw, hh)
            else
                Pieces(i, POOL_BASE, hw, hh)
            end
            i = nxt[i]
        end
    end
    for p = 1, 4 do
        local list = pools[p]
        for j = st.used[p] + 1, prevUsed[p] do list[j]:Hide() end
    end
    return true
end
function Live.Stats()
    return st.pieces, st.calls, st.hidden, F.n
end
function Live.Textures()
    return st.bases, st.overs, st.floors, st.used, st.rings
end
