local _, ns = ...
local abs = math.abs
local max = math.max
local min = math.min
local sqrt = math.sqrt
local pi = math.pi
local AIM_EPS = 0.001
local SNAP_TIME = 0.25
local LIVE_PERSP = 0.03
local Geo = { on = false }
ns.ReplayGeo = Geo
local Replay = ns.Replay
local st = { shown = false }
local LIVE_ISO = {}
local function LiveMod()
    return ns.ReplayLive
end
function Geo.Build(view, level)
    st.view = view
    if LiveMod() then LiveMod().Build(view, level) end
end
function Geo.Release()
    if LiveMod() then LiveMod().Release() end
    st.room, st.snap, st.shown = nil, nil, false
end
function Geo.Use(room)
    if st.room and room == st.room then return end
    Geo.Release()
    if not room or not st.view or not LiveMod() then return end
    if ns.RoomPacks.Load(room) and LiveMod().Use(room) then st.room = room end
end
function Geo.Missing(room)
    if not room or room == st.room then return nil end
    return ns.RoomPacks.Missing(room)
end
function Geo.Time(scene, t)
    if not st.room or not Geo.on or not LiveMod() then return false end
    return LiveMod().Time(scene, t)
end
function Geo.Has(room)
    return room ~= nil and room == st.room
end
function Geo.Iso(room)
    if not Geo.on or not room or room ~= st.room then return nil end
    return LIVE_ISO
end
function Geo.Place(cam, room, ppy)
    local live = LiveMod()
    if st.room and Geo.on and room == st.room and cam.persp <= LIVE_PERSP and live.Place(cam, room, ppy) then
        st.shown = true
        return true
    end
    if st.shown then
        live.HideAll()
        st.shown = false
    end
    return false
end
function Geo.Where(cam, scene, x, y)
    if not st.shown or scene.room ~= st.room then return x, y, 0 end
    local fx, fy = Replay.FixPoint(scene.room, x, y)
    local z = Replay.HeightAt(scene.room, fx, fy)
    if not z then return fx, fy, 0 end
    return fx, fy, z * scene.ppy * sqrt(max(0, 1 - cam.tilt * cam.tilt)) * cam.zoom
end
function Geo.Snap(cam, want, dir, wait)
    if not st.room or not Geo.on then return false end
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
    return st.shown
end
