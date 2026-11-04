local _, ns = ...
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local BASE_POOL = 1500
local OVER_POOL = 300
local FLOOR_N = 4
local FLOOR_MAX = 8
local FLOOR_FIT = 2.6
local ATLAS_MAX = 4
local MAX_STRIPS = 6
local MAX_SLICES = 3
local THRONE_SLICES = 4
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
local IMP_CELL = 11
local IMP_STRETCH = 0.2
local THRONE_NEAR = 0.5
local THRONE_PIC = "pic"
local THRONE_FACES = "faces"
local THRONE_DEFAULT = THRONE_PIC
local HUGE = 1e9
local Live = {}
ns.ReplayLive = Live
local Replay = ns.Replay
local Kit = ns.Kit
local F = { n = 0, cx = {}, cy = {}, cz = {}, ux = {}, uy = {}, uz = {}, vx = {}, vy = {}, vz = {}, nx = {}, ny = {}, nz = {},
            hu = {}, hv = {}, cu = {}, cv = {}, q = {}, du = {}, dv = {}, kind = {}, shell = {}, flat = {}, floor = {},
            fx = {}, fy = {}, fz = {}, kz = {}, ringS = {}, ringB = {}, at = {}, obj = {}, th = {} }
local objKey, objFirst, objLast, objNext = {}, {}, {}, {}
local P = { a1 = {}, b1 = {}, a2 = {}, b2 = {}, sx = {}, sy = {}, over = {}, nxt = {}, rkey = {} }
local ringList = {}
local Pr = { n = 0, row = {} }
local PROP_CELL = 8
local head, tail = {}, {}
local Th = { on = false, l = 0, t = 0, w = 0, h = 0, u0 = 0, v0 = 0, u1 = 0, v1 = 0, depth = 0, path = "", level = 0 }
local throneImp
local spireImp
local st = { floors = {}, bases = {}, overs = {}, rings = {}, used = { [POOL_BASE] = 0, [POOL_OVER] = 0, [POOL_FLOOR] = 0, [POOL_RING] = 0 },
             calls = 0, pieces = 0, hidden = 0, ringOk = false, t = 0, pfDone = -1, texA = {}, texIce = {}, path = {}, on = {},
             atlasPaths = {}, nAtlas = 1, thPaths = {}, spPaths = {}, spA = 1, thA = 1, thMode = THRONE_DEFAULT }
function Live.Build(view, level)
    st.view = view
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(level)
    top:SetAlpha(OVER_ALPHA)
    st.top = top
    st.spire = view:CreateTexture(nil, "BORDER")
    st.spire:Hide()
    local thTop = CreateFrame("Frame", nil, view)
    thTop:SetAllPoints(view)
    st.thTop = thTop
    st.thOver = thTop:CreateTexture(nil, "ARTWORK")
    st.thOver:SetAlpha(OVER_ALPHA)
    st.thOver:Hide()
    for k = 1, RING_POOL do
        st.rings[k] = view:CreateTexture(nil, "BORDER")
        st.rings[k]:Hide()
    end
    for k = 1, FLOOR_MAX * FLOOR_MAX do
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
    st.thBase = view:CreateTexture(nil, "ARTWORK")
    st.thBase:Hide()
end
local pools = { st.bases, st.overs, st.floors, st.rings }
local function Off(tex)
    if tex and st.on[tex] then
        tex:Hide()
        st.on[tex] = nil
        st.calls = st.calls + 1
    end
end
function Live.HideAll()
    local on = st.on
    for p = 1, 4 do
        local list, used = pools[p], st.used[p]
        for k = 1, used do
            local tex = list[k]
            if on[tex] then
                tex:Hide()
                on[tex] = nil
            end
        end
        st.used[p] = 0
    end
    Off(st.thOver)
    Off(st.thBase)
    Off(st.spire)
    Th.on = false
end
function Live.Release()
    Live.HideAll()
    for p = 1, 4 do
        local list = pools[p]
        for k = 1, #list do list[k]:SetTexture(nil) end
    end
    if st.thOver then
        st.thOver:SetTexture(nil)
        st.thBase:SetTexture(nil)
        st.spire:SetTexture(nil)
    end
    st.room, st.data, st.ringOk, st.pf, st.pfScene, st.pfDone = nil, nil, false, nil, nil, -1
    st.atlasPath, st.propsPath, st.nAtlas = nil, nil, 1
    for tex in pairs(st.path) do st.path[tex] = nil end
    for k = #st.atlasPaths, 1, -1 do st.atlasPaths[k] = nil end
    for k = #st.thPaths, 1, -1 do st.thPaths[k] = nil end
    for k = #st.spPaths, 1, -1 do st.spPaths[k] = nil end
    Pr.n = 0
    throneImp, spireImp = nil, nil
end
local function SetFace(i, row, ring)
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
    if ring then
        F.ringS[i], F.ringB[i], F.at[i], F.obj[i] = row[23], row[24], 1, 0
    else
        F.ringS[i], F.ringB[i], F.at[i], F.obj[i] = nil, nil, row[23] or 1, row[24] or 0
    end
    F.flat[i] = nz > NZ_FLAT
    F.th[i] = nil
    F.floor[i] = false
end
local function Load(d)
    local faces = d.faces
    local n = 0
    for k = 1, #faces do
        n = n + 1
        SetFace(n, faces[k])
    end
    local tf = st.thMode == THRONE_FACES and d.tfaces or {}
    for k = 1, #tf do
        n = n + 1
        SetFace(n, tf[k])
        F.th[n] = true
    end
    local pieces = d.ring and d.ring.pieces or {}
    for k = 1, #pieces do
        n = n + 1
        SetFace(n, pieces[k], true)
    end
    local fn = min(FLOOR_MAX, d.fn or FLOOR_N)
    local w = (d.fspan or d.fhalf * 2 / FLOOR_FIT) * 2 / fn
    local q = 1 / (2 * d.fhalf)
    local dm = w / 2
    for a = 1, fn do
        for b = 1, fn do
            n = n + 1
            local tx, ty = (a - (fn + 1) / 2) * w, (b - (fn + 1) / 2) * w
            SetFace(n, { (d.fcx or 0) + tx, (d.fcy or 0) + ty, 0, 1, 0, 0, 0, 1, 0, w / 2, w / 2, 0.5 + tx * q, 0.5 - ty * q, q, dm, dm, 1, 0 })
            F.floor[n] = true
        end
    end
    F.n = n
    for i = n + 1, #F.cx do F.cx[i] = nil end
end
function Live.SetThrone(mode)
    mode = (mode == THRONE_PIC or mode == THRONE_FACES) and mode or THRONE_DEFAULT
    if mode == st.thMode then return end
    st.thMode = mode
    if st.data then Load(st.data) end
end
function Live.ThroneMode()
    return st.thMode, st.data ~= nil and st.data.tfaces ~= nil
end
local function LoadImp(im, base, paths, tex)
    for s = 1, im.sheets do
        local p = s > 1 and base .. s or base
        if not tex:SetTexture(p) then return nil end
        paths[s] = p
        st.path[tex] = p
    end
    return im
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
    local nA = min(ATLAS_MAX, d.atlases or 1)
    local paths = st.atlasPaths
    paths[1] = atlas
    for a = 2, nA do
        paths[a] = atlas .. a
        if not st.bases[a]:SetTexture(paths[a]) then
            Live.Release()
            return false
        end
    end
    st.nAtlas = nA
    for k = 1, #st.bases do
        local p = paths[(k - 1) % nA + 1]
        if k > nA then st.bases[k]:SetTexture(p) end
        st.path[st.bases[k]] = p
    end
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
    throneImp = d.throne and LoadImp(d.throne, d.art .. "_throne", st.thPaths, st.thBase) or nil
    spireImp = throneImp and d.spire and LoadImp(d.spire, d.art .. "_spire", st.spPaths, st.spire) or nil
    for k = 2, #st.floors do st.floors[k]:SetTexture(fl) end
    for k = 1, #st.overs do
        local p = paths[(k - 1) % nA + 1]
        st.overs[k]:SetTexture(p)
        st.path[st.overs[k]] = p
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
    if not st.on[tex] then
        tex:Show()
        st.on[tex] = true
        st.calls = st.calls + 1
    end
    st.calls = st.calls + 4
    return true
end
local function NextTex(pool, at)
    local used, nA = st.used[pool], st.nAtlas
    local j = used + 1
    if nA > 1 then
        j = j + (at - 1 - used) % nA
        local list, on = pools[pool], st.on
        for k = used + 1, j - 1 do
            local tex = list[k]
            if tex and on[tex] then
                tex:Hide()
                on[tex] = nil
                st.calls = st.calls + 1
            end
        end
    end
    return j
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
        for k = 1, F.th[i] and THRONE_SLICES or MAX_SLICES do
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
    local faces = pool == POOL_BASE or pool == POOL_OVER
    local fix = pool == POOL_BASE and st.propsPath
    local at = F.at[i]
    local bx, by = A1 * h1 / nu + A2 * h2 / nv, B1 * h1 / nu + B2 * h2 / nv
    for a = 1, nu do
        local ou = -h1 + (2 * a - 1) * h1 / nu
        for b = 1, nv do
            local ov = -h2 + (2 * b - 1) * h2 / nv
            local used = faces and NextTex(pool, at) or st.used[pool] + 1
            local tex = list[used]
            if not tex then return end
            if fix then
                local want = st.atlasPaths[at]
                if st.path[tex] ~= want then
                    tex:SetTexture(want)
                    st.path[tex] = want
                    st.calls = st.calls + 1
                end
            end
            local px, py = sx + a1 * ou + a2 * ov, sy + b1 * ou + b2 * ov
            if Put(tex, px - bx, py - by, px + bx, py + by, px, py, i11, i12, i21, i22, cu + ou * q, cv - ov * q, q, hw, hh) then
                st.used[pool] = used
                st.pieces = st.pieces + 1
            end
        end
    end
end
local function Fit(tex, l, t, w, h, u0, v0, u1, v1, hw, hh)
    local x0, x1 = max(l, -hw), min(l + w, hw)
    local y0, y1 = max(t, -hh), min(t + h, hh)
    if x1 - x0 < 1 or y1 - y0 < 1 then return false end
    local a0, a1 = u0 + (u1 - u0) * (x0 - l) / w, u0 + (u1 - u0) * (x1 - l) / w
    local b0, b1 = v0 + (v1 - v0) * (y0 - t) / h, v0 + (v1 - v0) * (y1 - t) / h
    tex:SetPoint("TOPLEFT", st.view, "CENTER", x0, -y0)
    tex:SetWidth(x1 - x0)
    tex:SetHeight(y1 - y0)
    tex:SetTexCoord(a0, b0, a0, b1, a1, b0, a1, b1)
    st.calls = st.calls + 4
    return true
end
local function SetPath(tex, path)
    if st.path[tex] ~= path then
        tex:SetTexture(path)
        st.path[tex] = path
        st.calls = st.calls + 1
    end
end
local function On(tex)
    if not st.on[tex] then
        tex:Show()
        st.on[tex] = true
        st.calls = st.calls + 1
    end
end
local function PlaceProp(p, l, t, w, h, hw, hh)
    if min(l + w, hw) - max(l, -hw) < 1 or min(t + h, hh) - max(t, -hh) < 1 then return end
    local used = NextTex(POOL_BASE, 1)
    local tex = st.bases[used]
    if not tex then return end
    SetPath(tex, st.propsPath)
    local o = 4 + PROP_CELL * P.pk
    local row = Pr.row[p]
    Fit(tex, l, t, w, h, row[o], row[o + 1], row[o + 2], row[o + 3], hw, hh)
    On(tex)
    st.used[POOL_BASE] = used
    st.pieces = st.pieces + 1
end
local function ImpRect(im, cam, ox, oy, zp, k)
    local twoPi = 2 * math.pi
    local n, tilts, tilt = im.n, im.tilts, cam.tilt
    local ti, best = 1, HUGE
    for j = 1, #tilts do
        local d = abs(tilts[j] - tilt)
        if d < best then ti, best = j, d end
    end
    local o = ((ti - 1) * n + floor(((cam.angle % twoPi) / twoPi) * n + 0.5) % n) * IMP_CELL + 1
    local cells = im.cells
    if cells[o] == 0 then return nil, 0, 0, 0, 0, 0 end
    local c, s = cam.c, cam.s
    local f = max(IMP_STRETCH, cells[o + 9] * tilt - cells[o + 10] * k)
    local sx = ox + (im.x * c - im.y * s) * zp
    local sy = oy + ((im.x * s + im.y * c) * tilt - im.z * k) * zp
    return o, sx - cells[o + 7] * zp, sy - cells[o + 8] * zp * f, cells[o + 5] * zp, cells[o + 6] * zp * f, sy
end
local function PlaceThrone(cam, ox, oy, zp, k, hw, hh)
    Th.on = false
    local im, tex = throneImp, st.thBase
    local o, l, t, w, h, sy
    if im then o, l, t, w, h, sy = ImpRect(im, cam, ox, oy, zp, k) end
    local cells = im and im.cells
    if o then
        Th.u0, Th.v0, Th.u1, Th.v1, Th.path = cells[o + 1], cells[o + 2], cells[o + 3], cells[o + 4], st.thPaths[cells[o]]
        SetPath(tex, Th.path)
    end
    if not o or not Fit(tex, l, t, w, h, Th.u0, Th.v0, Th.u1, Th.v1, hw, hh) then
        Off(tex)
        Off(st.thOver)
        return
    end
    Th.on, Th.l, Th.t, Th.w, Th.h, Th.depth = true, l, t, w, h, sy
    local d = sqrt(im.x * im.x + im.y * im.y)
    local toCam = d > 0 and (im.x * cam.s + im.y * cam.c) / d or 0
    SetPath(st.thOver, Th.path)
    Fit(st.thOver, l, t, w, h, Th.u0, Th.v0, Th.u1, Th.v1, hw, hh)
    if st.thMode == THRONE_FACES then
        Off(tex)
        Off(st.thOver)
        return
    end
    local near = min(1, max(0, toCam / THRONE_NEAR))
    local a = floor((1 - (1 - OVER_ALPHA) * near * near * (3 - 2 * near)) * 100 + 0.5) / 100
    if st.thA ~= a then
        tex:SetAlpha(a)
        st.thA = a
        st.calls = st.calls + 1
    end
    On(tex)
end
local function PlaceSpire(cam, ox, oy, zp, k, hw, hh)
    local im, tex = spireImp, st.spire
    if not im or not im.far or st.thMode == THRONE_FACES then return Off(tex) end
    local d = sqrt(im.x * im.x + im.y * im.y)
    local far = d > 0 and -(im.x * cam.s + im.y * cam.c) / d or 1
    local a = (far - im.far[1]) / (im.far[2] - im.far[1])
    if a <= 0 then return Off(tex) end
    local o, l, t, w, h = ImpRect(im, cam, ox, oy, zp, k)
    if not o then return Off(tex) end
    local cells = im.cells
    SetPath(tex, st.spPaths[cells[o]])
    if not Fit(tex, l, t, w, h, cells[o + 1], cells[o + 2], cells[o + 3], cells[o + 4], hw, hh) then return Off(tex) end
    a = min(1, a)
    a = floor(a * a * (3 - 2 * a) * 100 + 0.5) / 100
    if st.spA ~= a then
        tex:SetAlpha(a)
        st.spA = a
        st.calls = st.calls + 1
    end
    On(tex)
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
    local obj, thF = F.obj, F.th
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
                    if thF[i] then
                        key = (cx[i] * s + cy[i] * c) * k
                    elseif kind[i] == 3 then
                        key = ((cx[i] + fx[i] * h2) * s + (cy[i] + fy[i] * h2) * c) * k + kz[i] * t - 0.002
                    elseif flat[i] then
                        key = ((cx[i] * s + cy[i] * c) * k + cz[i] * t) - abs((ux[i] * s + uy[i] * c) * k + uz[i] * t) * h1 - abs((vx[i] * s + vy[i] * c) * k + vz[i] * t) * h2
                    else
                        key = ((cx[i] - vx[i] * h2) * s + (cy[i] - vy[i] * h2) * c) * k + (cz[i] - vz[i] * h2) * t + 0.001
                    end
                    local ob = obj[i]
                    if ob and ob > 0 then
                        if not flat[i] and (objKey[ob] == nil or key > objKey[ob]) then objKey[ob] = key end
                        if objKey[ob] == nil then objKey[ob] = key - 1000 end
                        objNext[i] = 0
                        if objFirst[ob] == nil then objFirst[ob] = i else objNext[objLast[ob]] = i end
                        objLast[ob] = i
                    else
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
    end
    for ob, key in pairs(objKey) do
        local b = floor((key + KEY_MAX) * kscale) + 1
        if b < 1 then b = 1 elseif b > BUCKETS then b = BUCKETS end
        local i = objFirst[ob]
        while i and i ~= 0 do
            nxt[i] = 0
            if tail[b] == 0 then head[b] = i else nxt[tail[b]] = i end
            tail[b] = i
            i = objNext[i]
        end
        objKey[ob], objFirst[ob], objLast[ob] = nil, nil, nil
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
    PlaceThrone(cam, ox, oy, zp, k, hw, hh)
    PlaceSpire(cam, ox, oy, zp, k, hw, hh)
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
    local on = st.on
    for p = 1, 4 do
        local list = pools[p]
        for j = st.used[p] + 1, prevUsed[p] do
            local tex = list[j]
            if on[tex] then
                tex:Hide()
                on[tex] = nil
                st.calls = st.calls + 1
            end
        end
    end
    return true
end
function Live.Stats()
    return st.pieces, st.calls, st.hidden, F.n
end
function Live.Throne()
    if not Th.on or st.thMode == THRONE_FACES then return nil, 0, 0, 0, 0 end
    return Th.depth, Th.l, Th.t, Th.l + Th.w, Th.t + Th.h
end
function Live.ThroneOver(level)
    local tex = st.thOver
    if not tex then return end
    if not level or not Th.on then
        if st.on[tex] then
            tex:Hide()
            st.on[tex] = nil
        end
        return
    end
    if Th.level ~= level then
        st.thTop:SetFrameLevel(level)
        Th.level = level
    end
    if not st.on[tex] then
        tex:Show()
        st.on[tex] = true
    end
end
function Live.Textures()
    return st.bases, st.overs, st.floors, st.used, st.rings, st.spire, st.thOver, st.thBase
end
