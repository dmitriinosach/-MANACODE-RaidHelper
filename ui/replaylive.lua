local ADDON, ns = ...
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
local ATLAS_MAX = 6
local MAX_STRIPS = 6
local MAX_SLICES = 3
local THRONE_SLICES = 4
local TRI_POOL = 320
local TRI_C = 240 / 512
local TRI_T = 32 / 512
local TRI_LO = 2 / 512
local TRI_HI = 510 / 512
local TRI_SPLIT = 8
local TRI_MIN = 2
local TRI_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\tri"
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
local COL_MAX = 4
local COL_POOL = 48
local COL_ALPHA = 0.6
local POOL_COL = 5
local COL_LAYERS = { "BORDER", "ARTWORK", "OVERLAY" }
local POOL_BACK = POOL_COL + COL_MAX * 6
local BACK_POOL = 240
local FIRE_MAX = 4
local FIRE_SHIFT = 5
local FIRE_ROW = 5
local HORN_STAGGER = 0.16
local HORN_FALL = 0.9
local HORN_DEPTH = 14
local HORN_FADE = 0.35
local HORN_NEAR = 0.28
local HORN_GRAZE = 0.14
local Live = {}
ns.ReplayLive = Live
local Replay = ns.Replay
local Kit = ns.Kit
local F = { n = 0, cx = {}, cy = {}, cz = {}, ux = {}, uy = {}, uz = {}, vx = {}, vy = {}, vz = {}, nx = {}, ny = {}, nz = {},
            hu = {}, hv = {}, cu = {}, cv = {}, q = {}, du = {}, dv = {}, kind = {}, shell = {}, flat = {}, floor = {},
            fx = {}, fy = {}, fz = {}, kz = {}, ringS = {}, ringB = {}, at = {}, obj = {}, th = {}, tier = {}, col = {}, tri = {}, gone = {}, hx = {}, hy = {} }
local C = { n = 0, obj = {}, x = {}, y = {}, z = {}, list = {}, cnt = {}, depth = {}, l = {}, t = {}, r = {}, b = {},
            rank = {}, level = {}, oLevel = {}, filled = {}, base = {}, over = {}, stamp = 0 }
local objKey, objFirst, objLast, objNext = {}, {}, {}, {}
local P = { a1 = {}, b1 = {}, a2 = {}, b2 = {}, sx = {}, sy = {}, over = {}, nxt = {}, rkey = {}, fade = {} }
local ringList = {}
local colDraw = {}
local triDraw = {}
local Pr = { n = 0, row = {} }
local PROP_CELL = 8
local head, tail = {}, {}
local Th = { on = false, l = 0, t = 0, w = 0, h = 0, u0 = 0, v0 = 0, u1 = 0, v1 = 0, depth = 0, path = "", level = 0 }
local throneImp
local spireImp
local st = { floors = {}, bases = {}, overs = {}, rings = {}, backs = {}, cols = {}, tris = {}, triUsed = 0, triCol = {}, triOk = false,
             used = { [POOL_BASE] = 0, [POOL_OVER] = 0, [POOL_FLOOR] = 0, [POOL_RING] = 0, [POOL_BACK] = 0 },
             calls = 0, pieces = 0, hidden = 0, ringOk = false, t = 0, pfDone = -1, texA = {}, texIce = {}, path = {}, on = {},
             atlasPaths = {}, nAtlas = 1, thPaths = {}, spPaths = {}, spA = 1, thA = 1, thMode = THRONE_DEFAULT,
             goneDone = false, goneSpan = HORN_FALL, faded = {}, seq = false, dropped = 0, colPeak = 0,
             fires = {}, fire = { ok = false, acc = 0, at = -1, on = {}, x0 = {}, x1 = {}, y0 = {}, y1 = {} } }
local function FireCell(j, frame)
    local fi, d = st.fire, st.data.fire
    local k = (frame + (j - 1) * FIRE_SHIFT) % d.n
    local cols = d.cols
    local rows = ceil(d.n / cols)
    local u, v = k % cols, floor(k / cols)
    local a0, a1 = (u + fi.x0[j]) / cols, (u + fi.x1[j]) / cols
    local b0, b1 = (v + fi.y0[j]) / rows, (v + fi.y1[j]) / rows
    st.fires[j]:SetTexCoord(a0, b0, a0, b1, a1, b0, a1, b1)
end
local function FireTick(_, elapsed)
    local fi = st.fire
    local d = st.data and st.data.fire
    if not d or not fi.ok then return end
    fi.acc = fi.acc + elapsed
    local frame = floor(fi.acc * d.fps)
    if frame == fi.at then return end
    fi.at = frame
    for j = 1, FIRE_MAX do
        if fi.on[j] then FireCell(j, frame) end
    end
end
local function PlaceFire(c, s, t, k, ox, oy, zp, hw, hh)
    local fi, d = st.fire, st.data.fire
    if not d or not fi.ok then return end
    local at = d.at
    for j = 1, min(FIRE_MAX, floor(#at / FIRE_ROW)) do
        local o, tex = (j - 1) * FIRE_ROW, st.fires[j]
        local x, y = at[o + 1], at[o + 2]
        local w, h = at[o + 4] * zp, at[o + 5] * k * zp
        local l = ox + (x * c - y * s) * zp - w / 2
        local b = oy + ((x * s + y * c) * t - at[o + 3] * k) * zp
        local x0, x1 = max(l, -hw), min(l + w, hw)
        local y0, y1 = max(b - h, -hh), min(b, hh)
        if x1 - x0 >= 1 and y1 - y0 >= 1 then
            tex:SetPoint("TOPLEFT", st.view, "CENTER", x0, -y0)
            tex:SetWidth(x1 - x0)
            tex:SetHeight(y1 - y0)
            fi.x0[j], fi.x1[j], fi.y0[j], fi.y1[j] = (x0 - l) / w, (x1 - l) / w, (y0 - b + h) / h, (y1 - b + h) / h
            FireCell(j, max(fi.at, 0))
            st.calls = st.calls + 4
            if not fi.on[j] then
                tex:Show()
                fi.on[j] = true
                st.calls = st.calls + 1
            end
        elseif fi.on[j] then
            tex:Hide()
            fi.on[j] = nil
            st.calls = st.calls + 1
        end
    end
end
function Live.Build(view, level)
    st.view = view
    local ff = CreateFrame("Frame", nil, view)
    ff:SetScript("OnUpdate", FireTick)
    ff:Hide()
    st.fireFrame = ff
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(level)
    top:SetAlpha(OVER_ALPHA)
    st.top = top
    for k = 1, BACK_POOL do
        st.backs[k] = view:CreateTexture(nil, "BACKGROUND")
        st.backs[k]:Hide()
    end
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
    for k = 1, TRI_POOL do
        st.tris[k] = view:CreateTexture(nil, "BORDER")
        st.tris[k]:Hide()
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
    for k = 1, FIRE_MAX do
        st.fires[k] = view:CreateTexture(nil, "OVERLAY")
        st.fires[k]:SetBlendMode("ADD")
        st.fires[k]:Hide()
    end
    for c = 1, COL_MAX do
        for o = 0, 1 do
            local f = CreateFrame("Frame", nil, view)
            f:SetAllPoints(view)
            f:SetFrameLevel(view:GetFrameLevel() + c)
            if o == 1 then
                f:SetAlpha(COL_ALPHA)
                f:Hide()
                C.over[c] = f
            else
                C.base[c] = f
            end
            for tier = 1, #COL_LAYERS do
                local list = st.cols[POOL_COL + ((c - 1) * 2 + o) * 3 + tier - 1]
                for k = 1, COL_POOL do
                    list[k] = f:CreateTexture(nil, COL_LAYERS[tier])
                    list[k]:Hide()
                end
            end
        end
    end
end
local pools = { st.bases, st.overs, st.floors, st.rings }
for p = POOL_COL, POOL_COL + COL_MAX * 6 - 1 do
    st.cols[p] = {}
    pools[p] = st.cols[p]
    st.used[p] = 0
end
local POOL_LAST = POOL_COL + COL_MAX * 6 - 1
Live.COL_MAX, Live.COL_POOL = COL_MAX, COL_POOL
pools[POOL_BACK] = st.backs
local function ColPool(c, over, tier)
    return POOL_COL + ((c - 1) * 2 + (over and 1 or 0)) * 3 + tier - 1
end
local function Off(tex)
    if tex and st.on[tex] then
        tex:Hide()
        st.on[tex] = nil
        st.calls = st.calls + 1
    end
end
function Live.HideAll()
    local on = st.on
    for p = 1, POOL_BACK do
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
    for j = 1, #st.fires do
        if st.fire.on[j] then
            st.fires[j]:Hide()
            st.fire.on[j] = nil
        end
    end
    for j = 1, st.triUsed do Off(st.tris[j]) end
    st.triUsed = 0
    for c = 1, C.n do
        C.cnt[c], C.depth[c], C.oLevel[c], C.filled[c] = 0, nil, nil, nil
        if C.over[c] then C.over[c]:Hide() end
    end
end
function Live.Release()
    Live.HideAll()
    for p = 1, POOL_BACK do
        local list = pools[p]
        for k = 1, #list do list[k]:SetTexture(nil) end
    end
    if st.thOver then
        st.thOver:SetTexture(nil)
        st.thBase:SetTexture(nil)
        st.spire:SetTexture(nil)
    end
    st.room, st.data, st.ringOk, st.pf, st.pfScene, st.pfDone, st.goneT, st.goneDone = nil, nil, false, nil, nil, -1, nil, false
    st.fire.ok = false
    if st.fireFrame then st.fireFrame:Hide() end
    for k = 1, #st.fires do st.fires[k]:SetTexture(nil) end
    st.atlasPath, st.propsPath, st.nAtlas, st.seq = nil, nil, 1, false
    for tex in pairs(st.path) do st.path[tex] = nil end
    for k = #st.atlasPaths, 1, -1 do st.atlasPaths[k] = nil end
    for k = #st.thPaths, 1, -1 do st.thPaths[k] = nil end
    for k = #st.spPaths, 1, -1 do st.spPaths[k] = nil end
    Pr.n = 0
    C.n = 0
    for k = 1, #st.tris do st.tris[k]:SetTexture(nil) end
    for tex in pairs(st.triCol) do st.triCol[tex] = nil end
    st.triOk = false
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
    F.tier[i] = not ring and row[25] ~= 0 and row[25] or nil
    F.gone[i] = not ring and row[26] and row[26] > 0 and row[26] or nil
    F.tri[i] = nil
    F.col[i] = nil
    F.hx[i], F.hy[i] = nil, nil
end
local function LoadCols(n)
    C.n = 0
    for i = 1, n do
        local tier, ob = F.tier[i], F.obj[i]
        if tier and ob and ob > 0 and not (F.gone[i] and st.thMode == THRONE_FACES) then
            local c
            for k = 1, C.n do
                if C.obj[k] == ob then c = k end
            end
            if not c and C.n < COL_MAX then
                C.n = C.n + 1
                c = C.n
                C.obj[c], C.x[c], C.y[c], C.z[c], C.cnt[c] = ob, 0, 0, HUGE, 0
            end
            if c then
                F.col[i] = c
                C.cnt[c] = C.cnt[c] + 1
                C.x[c], C.y[c] = C.x[c] + F.cx[i], C.y[c] + F.cy[i]
                C.z[c] = min(C.z[c], F.cz[i] - abs(F.vz[i]) * F.hv[i])
            else
                F.tier[i] = nil
            end
        end
    end
    for c = 1, C.n do
        C.x[c], C.y[c] = C.x[c] / C.cnt[c], C.y[c] / C.cnt[c]
        C.cnt[c], C.depth[c], C.list[c] = 0, nil, C.list[c] or {}
    end
end
local function Load(d)
    local faces = d.faces
    local n, wedges = 0, 1
    for k = 1, #faces do
        n = n + 1
        SetFace(n, faces[k])
        if F.gone[n] and F.gone[n] > wedges then wedges = F.gone[n] end
    end
    st.goneSpan = (wedges - 1) * HORN_STAGGER + HORN_FALL
    local m = n
    while m >= 1 do
        local ob = F.gone[m] and F.obj[m] or 0
        if ob > 0 and not F.hx[m] then
            local x, y, cnt = 0, 0, 0
            for i = 1, m do
                if F.obj[i] == ob and F.gone[i] then x, y, cnt = x + F.cx[i], y + F.cy[i], cnt + 1 end
            end
            for i = 1, m do
                if F.obj[i] == ob and F.gone[i] then F.hx[i], F.hy[i] = x / cnt, y / cnt end
            end
        end
        m = m - 1
    end
    LoadCols(n)
    local tf = st.thMode == THRONE_FACES and d.tfaces or {}
    for k = 1, #tf do
        n = n + 1
        SetFace(n, tf[k])
        F.th[n] = true
        F.tier[n] = nil
        F.gone[n] = nil
        F.tri[n] = tf[k][31] and tf[k] or nil
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
    if st.data then
        Live.HideAll()
        Load(st.data)
    end
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
    st.seq = d.seq and nA > 1 or false
    for k = 1, #st.bases do
        local p = paths[(k - 1) % nA + 1]
        if k > nA then st.bases[k]:SetTexture(p) end
        st.path[st.bases[k]] = p
    end
    for k = 1, #st.backs do
        local p = paths[(k - 1) % nA + 1]
        st.backs[k]:SetTexture(p)
        st.path[st.backs[k]] = p
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
    spireImp = d.spire and LoadImp(d.spire, d.art .. "_spire", st.spPaths, st.spire) or nil
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
    st.triOk = d.tfaces ~= nil and st.tris[1] ~= nil and st.tris[1]:SetTexture(TRI_PATH) and true or false
    for k = 2, st.triOk and #st.tris or 0 do st.tris[k]:SetTexture(TRI_PATH) end
    Load(d)
    st.room, st.data = room, d
    local fi = st.fire
    fi.ok = d.fire ~= nil and st.fires[1]:SetTexture(d.art .. "_fire") and true or false
    for k = 2, fi.ok and #st.fires or 0 do st.fires[k]:SetTexture(d.art .. "_fire") end
    if fi.ok then st.fireFrame:Show() else st.fireFrame:Hide() end
    return true
end
function Live.Time(scene, t)
    st.t = t
    local d = st.data
    if not d or not d.ring or not st.ringOk or not scene then
        st.goneT, st.goneDone = nil, false
        return false
    end
    if st.pfScene ~= scene then
        local Platform = ns.ReplayPlatform
        local def = Platform and scene.fight and Platform.Def(scene.fight.boss)
        local L = scene.layers
        if not def or Replay.ROOMS[def.room] ~= st.room then
            st.pf, st.pfScene, st.goneT, st.goneDone = nil, scene, nil, false
        elseif L and (L.pfQuake or L.pfWinter) then
            local w = L.pfWinter and L.pfWinter[1]
            st.pf = { tl = Platform.Timeline(def, L.pfQuake or {}, L.pfWinter or {}), def = def, ring = d.ring, gone = w and w + def.winter.delay }
            st.pfScene, st.pfDone = scene, -1
        else
            st.goneT, st.goneDone = nil, false
            return false
        end
    end
    local pf = st.pf
    if not pf then return false end
    local busy, done = ns.ReplayPlatform.State(pf.tl, pf.def, pf.ring, t)
    local goneT = pf.gone ~= nil and t >= pf.gone and t - pf.gone or nil
    local goneDone = goneT ~= nil and goneT >= st.goneSpan
    local changed = busy or done ~= st.pfDone or (goneT ~= nil and not goneDone) or goneDone ~= st.goneDone
        or (goneT ~= nil) ~= (st.goneT ~= nil)
    st.pfDone, st.goneT, st.goneDone = done, goneT, goneDone
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
    if nA > 1 and not st.seq then
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
local PX, PY = {}, {}
local function TriBand(alongX, l, t, r, b, n, s)
    local lo, hi = alongX and l or t, alongX and r or b
    local a0, a9 = lo + (hi - lo) * (s - 1) / n, lo + (hi - lo) * s / n
    return s == 1 and a0 - 1 or a0, s == n and a9 + 1 or a9
end
local function TriSpan(alongX, a0, a9)
    local A, B = alongX and PX or PY, alongX and PY or PX
    local lo, hi = HUGE, -HUGE
    for k = 1, 3 do
        local ak, bk = A[k], B[k]
        if ak >= a0 and ak <= a9 then lo, hi = min(lo, bk), max(hi, bk) end
        local m = k % 3 + 1
        local am, bm = A[m], B[m]
        if am ~= ak then
            for q = 1, 2 do
                local f = ((q == 1 and a0 or a9) - ak) / (am - ak)
                if f >= 0 and f <= 1 then
                    local bb = bk + (bm - bk) * f
                    lo, hi = min(lo, bb), max(hi, bb)
                end
            end
        end
    end
    return lo - 1, hi + 1
end
local function Patch(i, hw, hh)
    local row, list = F.tri[i], st.tris
    if not st.triOk then return end
    local a1, b1, a2, b2, sx, sy = P.a1[i], P.b1[i], P.a2[i], P.b2[i], P.sx[i], P.sy[i]
    local px, py = PX, PY
    for k = 0, 2 do
        local u, v = row[25 + 2 * k], row[26 + 2 * k]
        px[k + 1], py[k + 1] = sx + a1 * u + a2 * v, sy + b1 * u + b2 * v
    end
    local x0, y0 = px[1], py[1]
    local ex1, ey1, ex2, ey2 = px[2] - x0, py[2] - y0, px[3] - x0, py[3] - y0
    local det = ex1 * ey2 - ex2 * ey1
    if abs(det) < TRI_MIN then return end
    local m11, m12, m21, m22 = TRI_T * ey2 / det, -TRI_T * ex2 / det, -TRI_T * ey1 / det, TRI_T * ex1 / det
    local l, r = min(px[1], px[2], px[3]), max(px[1], px[2], px[3])
    local t, b = min(py[1], py[2], py[3]), max(py[1], py[2], py[3])
    local alongX = r - l >= b - t
    for n = 1, TRI_SPLIT do
        local ok = true
        for s = 1, n do
            local a0, a9 = TriBand(alongX, l, t, r, b, n, s)
            local c0, c9 = TriSpan(alongX, a0, a9)
            for c = 1, c0 <= c9 and 4 or 0 do
                local x, y
                if alongX then x, y = c <= 2 and a0 or a9, (c % 2 == 1) and c0 or c9 else x, y = (c % 2 == 1) and c0 or c9, c <= 2 and a0 or a9 end
                local tu, tv = TRI_C + m11 * (x - x0) + m12 * (y - y0), TRI_C + m21 * (x - x0) + m22 * (y - y0)
                if tu < TRI_LO or tu > TRI_HI or tv < TRI_LO or tv > TRI_HI then ok = false end
            end
            if not ok then break end
        end
        if ok then
            local col = row[31]
            for s = 1, n do
                local a0, a9 = TriBand(alongX, l, t, r, b, n, s)
                local c0, c9 = TriSpan(alongX, a0, a9)
                local j = st.triUsed + 1
                local tex = list[j]
                if not tex then return end
                if c0 > c9 then c0, c9 = 0, 0 end
                local L, T, R, B
                if alongX then L, T, R, B = a0, c0, a9, c9 else L, T, R, B = c0, a0, c9, a9 end
                if Put(tex, L, T, R, B, x0, y0, m11, m12, -m21, -m22, TRI_C, TRI_C, 1, hw, hh) then
                    st.triUsed = j
                    if st.triCol[tex] ~= col then
                        tex:SetVertexColor(floor(col / 65536) / 255, floor(col / 256) % 256 / 255, col % 256 / 255)
                        st.triCol[tex] = col
                        st.calls = st.calls + 1
                    end
                end
            end
            return
        end
    end
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
        local tri = F.tri[i]
        if tri and tri[32] == 1 then Patch(i, hw, hh) end
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
            if tri and tri[32] ~= 1 then Patch(i, hw, hh) end
            st.hidden = st.hidden + 1
            return
        end
    end
    local list, cu, cv, q = pools[pool], F.cu[i], F.cv[i], F.q[i]
    local faces = pool == POOL_BASE or pool == POOL_OVER or pool == POOL_BACK
    local fix = (faces and st.seq) or (pool == POOL_BASE and st.propsPath) or (pool >= POOL_COL and pool <= POOL_LAST)
    local at = F.at[i]
    local bx, by = A1 * h1 / nu + A2 * h2 / nv, B1 * h1 / nu + B2 * h2 / nv
    for a = 1, nu do
        local ou = -h1 + (2 * a - 1) * h1 / nu
        for b = 1, nv do
            local ov = -h2 + (2 * b - 1) * h2 / nv
            local used = faces and NextTex(pool, at) or st.used[pool] + 1
            local tex = list[used]
            if not tex then
                st.dropped = st.dropped + 1
                return
            end
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
                local fa = st.fadeA
                if fa then
                    tex:SetAlpha(fa)
                    st.faded[#st.faded + 1] = tex
                    st.calls = st.calls + 1
                end
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
    if not im or not im.far then return Off(tex) end
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
local function HideFrom(p, prev)
    local list, on = pools[p], st.on
    for j = st.used[p] + 1, prev do
        local tex = list[j]
        if tex and on[tex] then
            tex:Hide()
            on[tex] = nil
            st.calls = st.calls + 1
        end
    end
end
local function FillCol(n, over)
    local list, cnt = C.list[n], C.cnt[n]
    for tier = 1, #COL_LAYERS do
        local p = ColPool(n, over, tier)
        local prev = st.used[p]
        st.used[p] = 0
        for m = 1, cnt do
            local i = list[m]
            if F.tier[i] == tier then
                st.fadeA = P.fade[i]
                Pieces(i, p, C.hw, C.hh)
                st.fadeA = nil
            end
        end
        if st.used[p] > st.colPeak then st.colPeak = st.used[p] end
        HideFrom(p, prev)
    end
end
local function DrawCols(cam, ox, oy, zp, k, hw, hh)
    if C.n == 0 then return end
    C.stamp, C.hw, C.hh = C.stamp + 1, hw, hh
    local c, s, t = cam.c, cam.s, cam.tilt
    for n = 1, C.n do
        FillCol(n, false)
        local l, tp, r, b = HUGE, HUGE, -HUGE, -HUGE
        local list = C.list[n]
        for m = 1, C.cnt[n] do
            local i = list[m]
            local bx = abs(P.a1[i]) * F.hu[i] + abs(P.a2[i]) * F.hv[i]
            local by = abs(P.b1[i]) * F.hu[i] + abs(P.b2[i]) * F.hv[i]
            l, r = min(l, P.sx[i] - bx), max(r, P.sx[i] + bx)
            tp, b = min(tp, P.sy[i] - by), max(b, P.sy[i] + by)
        end
        C.l[n], C.t[n], C.r[n], C.b[n] = l, tp, r, b
        C.depth[n] = C.cnt[n] > 0 and oy + ((C.x[n] * s + C.y[n] * c) * t - C.z[n] * k) * zp or nil
    end
    local base = st.view:GetFrameLevel()
    for n = 1, C.n do
        local rank, d = 1, C.depth[n] or -HUGE
        for m = 1, C.n do
            local e = C.depth[m] or -HUGE
            if m ~= n and (e < d or (e == d and m < n)) then rank = rank + 1 end
        end
        C.rank[n] = rank
        if C.level[n] ~= base + rank then
            C.level[n] = base + rank
            C.base[n]:SetFrameLevel(base + rank)
        end
    end
end
function Live.Place(cam, room, ppy)
    if room ~= st.room or not st.data then return false end
    local prevUsed = { st.used[1], st.used[2], st.used[3], st.used[4] }
    prevUsed[POOL_BACK] = st.used[POOL_BACK]
    st.used[1], st.used[2], st.used[3], st.used[4], st.used[POOL_BACK] = 0, 0, 0, 0, 0
    st.calls, st.pieces, st.hidden, st.dropped, st.colPeak = 0, 0, 0, 0, 0
    local triPrev = st.triUsed
    st.triUsed = 0
    for n = 1, C.n do C.cnt[n] = 0 end
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
    local goneF, goneT, goneDone, fadeF = F.gone, st.goneT, st.goneDone, P.fade
    local faded = st.faded
    for j = #faded, 1, -1 do
        faded[j]:SetAlpha(1)
        faded[j] = nil
        st.calls = st.calls + 1
    end
    local Platform = ns.ReplayPlatform
    for i = 1, F.n do
        if ringS[i] then
            if st.ringOk then
                local alpha, dz = 1, 0
                if pf then alpha, dz = Platform.Piece(pf.tl, pf.def, pf.ring, ringS[i], F.ringB[i], st.t) end
                if kind[i] ~= 4 and fx[i] * vwx + fy[i] * vwy + fz[i] * vwz <= 0 then alpha = 0 end
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
        elseif not (goneF[i] and goneDone) then
        local dz, fa = 0, nil
        if goneT and goneF[i] then
            local u = (goneT - (goneF[i] - 1) * HORN_STAGGER) / HORN_FALL
            if u >= 1 then
                dz = nil
            elseif u > 0 then
                dz = -min(HORN_DEPTH, max(0, cz[i])) * u * u
                if u > HORN_FADE then fa = floor((1 - (u - HORN_FADE) / (1 - HORN_FADE)) * 20 + 0.5) / 20 end
            end
        end
        fadeF[i] = fa
        local nd = dz and fx[i] * vwx + fy[i] * vwy + fz[i] * vwz or -1
        local front = nd > (goneF[i] and HORN_GRAZE or 0)
        if front and kind[i] >= 4 then front = F.nx[i] * vwx + F.ny[i] * vwy + F.nz[i] * vwz > 0 end
        if front or shell[i] == 1 then
            local a1 = (ux[i] * c - uy[i] * s) * zp
            local b1 = ((ux[i] * s + uy[i] * c) * t - uz[i] * k) * zp
            local a2 = (vx[i] * c - vy[i] * s) * zp
            local b2 = ((vx[i] * s + vy[i] * c) * t - vz[i] * k) * zp
            local h1, h2 = hu[i], hv[i]
            local bx = abs(a1) * h1 + abs(a2) * h2
            local by = abs(b1) * h1 + abs(b2) * h2
            local sx = ox + (cx[i] * c - cy[i] * s) * zp
            local sy = oy + ((cx[i] * s + cy[i] * c) * t - (cz[i] + dz) * k) * zp
            if abs(a1 * b2 - a2 * b1) * h1 * h2 * 4 >= MIN_PX * MIN_PX and sx + bx > -hw and sx - bx < hw and sy + by > -hh and sy - by < hh then
                pa1[i], pb1[i], pa2[i], pb2[i], psx[i], psy[i] = a1, b1, a2, b2, sx, sy
                if floorF[i] then
                    Pieces(i, POOL_FLOOR, hw, hh)
                elseif not front or (F.hx[i] and F.hx[i] * s + F.hy[i] * c > 0) then
                    st.fadeA = F.hx[i] and (fa or 1) * HORN_NEAR or fa
                    Pieces(i, POOL_OVER, hw, hh)
                    st.fadeA = nil
                elseif F.col[i] then
                    local n = F.col[i]
                    local m = C.cnt[n] + 1
                    C.cnt[n] = m
                    C.list[n][m] = i
                else
                    local key
                    if thF[i] then
                        key = (cx[i] * s + cy[i] * c) * k
                    elseif kind[i] == 4 then
                        key = ((cx[i] - vx[i] * h2) * s + (cy[i] - vy[i] * h2) * c) * k + (cz[i] - vz[i] * h2) * t
                            - abs((ux[i] * s + uy[i] * c) * k + uz[i] * t) * h1
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
    DrawCols(cam, ox, oy, zp, k, hw, hh)
    PlaceThrone(cam, ox, oy, zp, k, hw, hh)
    PlaceSpire(cam, ox, oy, zp, k, hw, hh)
    PlaceRing(nRing, hw, hh)
    for b = 1, BUCKETS do
        local i = head[b]
        while i ~= 0 do
            if i > nF then
                PlaceProp(i - nF, P.sx[i], P.sy[i], P.a1[i], P.b1[i], hw, hh)
            elseif kind[i] == 4 then
                Pieces(i, POOL_BACK, hw, hh)
            else
                st.fadeA = fadeF[i]
                Pieces(i, POOL_BASE, hw, hh)
                st.fadeA = nil
            end
            i = nxt[i]
        end
    end
    PlaceFire(c, s, t, k, ox, oy, zp, hw, hh)
    local on = st.on
    for j = st.triUsed + 1, triPrev do
        local tex = st.tris[j]
        if on[tex] then
            tex:Hide()
            on[tex] = nil
            st.calls = st.calls + 1
        end
    end
    for p = 1, POOL_BACK do
        local list = pools[p]
        for j = st.used[p] + 1, prevUsed[p] or 0 do
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
    return st.pieces, st.calls, st.hidden, F.n, st.dropped, st.colPeak
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
function Live.Fires()
    return st.fires, st.fire.on
end
function Live.Textures()
    local m = 0
    for r = 1, C.n do
        for n = 1, C.n do
            if C.rank[n] == r then
                for tier = 1, #COL_LAYERS do
                    local p = ColPool(n, false, tier)
                    for j = 1, st.used[p] do
                        m = m + 1
                        colDraw[m] = pools[p][j]
                    end
                end
            end
        end
    end
    for j = m + 1, #colDraw do colDraw[j] = nil end
    for j = 1, #triDraw do triDraw[j] = nil end
    for j = 1, st.triUsed do triDraw[j] = st.tris[j] end
    return st.bases, st.overs, st.floors, st.used, st.rings, st.spire, st.thOver, st.thBase, colDraw, st.backs, triDraw
end
function Live.Cols()
    return C.n
end
function Live.Col(n)
    if not C.depth[n] then return nil, 0, 0, 0, 0, C.base[n] end
    return C.depth[n], C.l[n], C.t[n], C.r[n], C.b[n], C.base[n]
end
function Live.ColOver(n, level)
    local f = C.over[n]
    if not f then return end
    if not level or not C.depth[n] then
        if C.oLevel[n] then
            f:Hide()
            C.oLevel[n] = nil
        end
        return
    end
    if C.filled[n] ~= C.stamp then
        C.filled[n] = C.stamp
        FillCol(n, true)
    end
    if C.oLevel[n] ~= level then
        if not C.oLevel[n] then f:Show() end
        f:SetFrameLevel(level)
        C.oLevel[n] = level
    end
end
