local ADDON, ns = ...
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local pi = math.pi
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\geo\\"
local AIM_EPS = 0.001
local MAX_ANGLES = 8
local SNAP_TIME = 0.25
local OVER_ALPHA = 0.42
local LIVE_PERSP = 0.03
local Geo = { on = false, legacy = false }
ns.ReplayGeo = Geo
local Replay = ns.Replay
local st = { bases = {}, overs = {}, k = 0, live = false }
local LIVE_ISO = {}
local function LiveMod()
    return ns.ReplayLive
end
function Geo.Build(view, level)
    st.view = view
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(level)
    if LiveMod() then LiveMod().Build(view, level) end
    for k = 1, MAX_ANGLES do
        st.bases[k] = view:CreateTexture(nil, "BORDER")
        st.bases[k]:Hide()
        st.overs[k] = top:CreateTexture(nil, "ARTWORK")
        st.overs[k]:Hide()
    end
end
local function HideAll()
    for k = 1, #st.bases do
        st.bases[k]:Hide()
        st.overs[k]:Hide()
    end
    st.k = 0
end
function Geo.Release()
    HideAll()
    for k = 1, #st.bases do
        st.bases[k]:SetTexture(nil)
        st.overs[k]:SetTexture(nil)
    end
    if LiveMod() then LiveMod().Release() end
    st.room, st.iso, st.snap, st.live = nil, nil, nil, false
end
function Geo.Use(room)
    if st.room and room == st.room then return end
    Geo.Release()
    st.room, st.iso, st.snap = nil, nil, nil
    if room and st.view and not Geo.legacy and LiveMod() and LiveMod().Use(room) then
        st.room, st.live = room, true
        return
    end
    local iso = Replay.IsoOf(room)
    if not iso or not st.view then return end
    local n = min(MAX_ANGLES, iso.n or 1)
    for k = 1, n do
        local path = ART .. room.tex .. "_" .. k
        if not st.bases[k]:SetTexture(path .. "_base") or not st.overs[k]:SetTexture(path .. "_over") then
            Geo.Release()
            return
        end
        st.overs[k]:SetAlpha(iso.over or OVER_ALPHA)
    end
    st.room, st.iso = room, iso
end
function Geo.Has(room)
    return room ~= nil and room == st.room
end
function Geo.Iso(room)
    if not Geo.on or not room or room ~= st.room then return nil end
    if st.live then return LIVE_ISO end
    return st.iso
end
local function Step()
    return 2 * pi / min(MAX_ANGLES, st.iso.n or 1)
end
function Geo.Nearest(angle)
    local iso = st.iso
    if not iso or st.live then return angle end
    local step = Step()
    return (iso.angle + floor((angle - iso.angle) / step + 0.5) * step) % (2 * pi)
end
local function Aimed(cam)
    local iso = Geo.on and st.iso
    if not iso or st.snap or cam.persp ~= 0 or abs(cam.tilt - iso.tilt) >= AIM_EPS then return nil end
    local step = Step()
    local q = (cam.angle - iso.angle) / step
    local r = floor(q + 0.5)
    if abs(q - r) * step >= AIM_EPS then return nil end
    return r % min(MAX_ANGLES, iso.n or 1) + 1
end
local function Clip(tex, cam, l, t, w, h)
    local hw, hh = cam.w / 2, cam.h / 2
    local x0, x1 = max(l, -hw), min(l + w, hw)
    local y0, y1 = max(t, -hh), min(t + h, hh)
    if x1 - x0 < 1 or y1 - y0 < 1 then
        tex:Hide()
        return
    end
    tex:SetPoint("TOPLEFT", st.view, "CENTER", x0, -y0)
    tex:SetWidth(x1 - x0)
    tex:SetHeight(y1 - y0)
    tex:SetTexCoord((x0 - l) / w, (x1 - l) / w, (y0 - t) / h, (y1 - t) / h)
    tex:Show()
end
function Geo.Place(cam, room, ppy)
    if st.live then
        local live = LiveMod()
        if Geo.on and room == st.room and cam.persp <= LIVE_PERSP and live.Place(cam, room, ppy) then
            st.k = 1
            return true
        end
        if st.k > 0 then
            live.HideAll()
            st.k = 0
        end
        return false
    end
    local k = room == st.room and Aimed(cam)
    if not k then
        if st.k > 0 then HideAll() end
        return false
    end
    if st.k ~= k then
        HideAll()
        st.k = k
    end
    local iso = st.iso
    local f = cam.zoom * ppy / iso.ppy
    local sx, sy = Replay.Project(cam, room.cx, room.cy)
    local l, t, w, h = sx - iso.ox * f, sy - iso.oy * f, iso.w * f, iso.h * f
    Clip(st.bases[k], cam, l, t, w, h)
    Clip(st.overs[k], cam, l, t, w, h)
    return true
end
function Geo.Where(cam, scene, x, y)
    if st.k == 0 or scene.room ~= st.room then return x, y, 0 end
    local fx, fy = Replay.FixPoint(scene.room, x, y)
    local z = Replay.HeightAt(scene.room, fx, fy)
    if not z then return fx, fy, 0 end
    return fx, fy, z * scene.ppy * sqrt(max(0, 1 - cam.tilt * cam.tilt)) * cam.zoom
end
function Geo.Snap(cam, want, dir, wait)
    if st.live then
        if not Geo.on then return false end
        local a0, a1 = cam.angle, want
        while a1 - a0 > pi do a1 = a1 - 2 * pi end
        while a0 - a1 > pi do a1 = a1 + 2 * pi end
        if abs(a1 - a0) < AIM_EPS and cam.persp <= 0 then
            cam.angle = a1 % (2 * pi)
            return true
        end
        st.snap = { a0 = a0, a1 = a1, t0 = cam.tilt, t1 = cam.tilt, p0 = cam.persp, t = -(wait or 0) }
        return true
    end
    local iso = Geo.on and st.iso
    if not iso then return false end
    local step = Step()
    local r = floor((want - iso.angle) / step + 0.5)
    local cur = floor((cam.angle - iso.angle) / step + 0.5)
    if dir ~= 0 and r == cur then r = cur + (dir > 0 and 1 or -1) end
    local a0, a1 = cam.angle, iso.angle + r * step
    while a1 - a0 > pi do a1 = a1 - 2 * pi end
    while a0 - a1 > pi do a1 = a1 + 2 * pi end
    st.snap = { a0 = a0, a1 = a1, t0 = cam.tilt, t1 = iso.tilt, p0 = cam.persp, t = -(wait or 0) }
    return true
end
function Geo.Cancel()
    st.snap = nil
end
function Geo.Step(cam, elapsed)
    local s = st.snap
    if not s then return false, false end
    s.t = s.t + elapsed
    if s.t < 0 then return false, false end
    local f = min(1, s.t / SNAP_TIME)
    local e = f * f * (3 - 2 * f)
    cam.angle = s.a0 + (s.a1 - s.a0) * e
    cam.tilt = s.t0 + (s.t1 - s.t0) * e
    cam.persp = s.p0 * (1 - e)
    if f < 1 then return true, false end
    cam.angle, cam.tilt, cam.persp = s.a1 % (2 * pi), s.t1, 0
    st.snap = nil
    return true, true
end
function Geo.Shown()
    return st.k > 0
end
function Geo.Layers()
    local k = max(1, st.k)
    return st.bases[k], st.overs[k]
end
function Geo.Live()
    return st.live
end
