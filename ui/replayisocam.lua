local _, ns = ...
local floor = math.floor
local abs = math.abs
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi
local CLICK_PX = 4
local TURN = 0.01
local ZOOM_STEP = 1.15
local ZOOM_MIN = 0.5
local ZOOM_MAX = 8
local TILT_STEP = 0.05
local TILT_MIN = 0.2
local TILT_MAX = 1
local START_ANGLE = pi / 4
local START_TILT = 0.55
local START_PERSP = 0.3
local GEO_WAIT = 0.35
local TILT_DRAG = 0.004
local SEEK_STEP = ns.ReplayBar.SEEK_STEP
local NORTH_RIM = 12
local SPIN_H = 0.35
local FIG_MIN = 0.6
local FIG_MAX = 2.4
local LABEL_MIN = 0.8
local LABEL_MAX = 1.5
local HOVER_PX = 14
local IsoCam = { START_ANGLE = START_ANGLE, START_TILT = START_TILT, START_PERSP = START_PERSP,
                 TILT_STEP = TILT_STEP }
ns.ReplayIsoCam = IsoCam
local Replay = ns.Replay
local Tour = ns.ReplayTour
local Bar = ns.ReplayBar
local ViewMenu = ns.ReplayViewMenu
local Geo = ns.ReplayGeo
local ui
local run
local cam
local dim
local figs
local SetFocus
local PlaceFloor
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Num(v, default)
    if type(v) == "number" and v == v then return v end
    return default
end
local function Spin(tex, a)
    local c, s = cos(a) * SPIN_H, sin(a) * SPIN_H
    tex:SetTexCoord(0.5 - c - s, 0.5 + s - c, 0.5 - c + s, 0.5 + s + c,
        0.5 + c - s, 0.5 - s - c, 0.5 + c + s, 0.5 - s + c)
end
local function UpdateCompass()
    local a = Replay.North(cam)
    Spin(ui.needle, a)
    ui.northTag:SetPoint("CENTER", ui.compass, "CENTER", sin(a) * NORTH_RIM, cos(a) * NORTH_RIM)
end
local function ApplyCamera()
    Replay.Aim(cam)
    run.figScale = Clamp(sqrt(cam.zoom / run.fitZoom * dim.k), FIG_MIN, FIG_MAX)
    PlaceFloor()
    UpdateCompass()
    run.marksDirty = true
    run.camDirty = false
end
local function UpdateCamUi()
    if not ui.modeBtn then return end
    ui.modeBtn.text:SetText(ns.T(run.flat and "iso.cam.2d" or "iso.cam.3d"))
    ui.modeBtn.tip = ns.T(run.flat and "iso.tip.to3d" or "iso.tip.to2d")
    ViewMenu.Refresh()
end
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
local function SaveCamera()
    local saved = Saved()
    saved.angle = cam.angle % (2 * pi)
    saved.tilt, saved.flat = run.tilt3, run.flat
end
local function LoadCamera()
    local saved = Saved()
    cam.angle = Num(saved.angle, START_ANGLE)
    run.tilt3 = Clamp(Num(saved.tilt, START_TILT), TILT_MIN, TILT_MAX)
    run.persp3 = START_PERSP
    run.flat = saved.flat == true
    run.focusHeal = saved.focusHeal == true
    Geo.on = saved.geo ~= false
end
local function Reframe()
    if run.flat then
        cam.tilt, cam.persp = 1, 0
    else
        cam.tilt, cam.persp = run.tilt3, run.persp3
    end
    if run.scene then
        local ratio = cam.zoom / run.fitZoom
        run.fitZoom = Replay.Frame(cam)
        cam.zoom = run.fitZoom * ratio
    end
    run.camDirty = true
    UpdateCamUi()
end
local function SetView(tilt)
    run.flat = false
    run.tilt3 = Clamp(tilt, TILT_MIN, TILT_MAX)
    Reframe()
    SaveCamera()
    Geo.Snap(cam, cam.angle, 0, GEO_WAIT)
end
local function SetFlat(flat)
    run.flat = flat
    Reframe()
    SaveCamera()
    if not flat then Geo.Snap(cam, cam.angle, 0, 0) end
end
local function Turn(delta)
    if not run.flat and Geo.Snap(cam, cam.angle + delta, delta > 0 and 1 or delta < 0 and -1 or 0, 0) then return end
    cam.angle = (cam.angle + delta) % (2 * pi)
    run.camDirty = true
    SaveCamera()
end
local function CursorInView()
    local x, y = GetCursorPosition()
    local k = ui.view:GetEffectiveScale()
    local cx, cy = ui.view:GetCenter()
    return x / k - cx, -(y / k - cy)
end
local function PlaceLabel(fig)
    local ls = floor(Clamp(fig.scale / run.figScale, LABEL_MIN, LABEL_MAX) * 20 + 0.5) / 20
    if ls ~= run.labelScale then
        run.labelScale = ls
        ui.hoverBox:SetScale(ls)
    end
    ui.hoverBox:SetPoint("BOTTOM", ui.view, "CENTER", fig.sx / ls, (-fig.sy + (fig.top or 0) + 6 * fig.scale) / ls)
end
local function Hover()
    if run.drag or not ui.view:IsMouseOver() then
        if run.hover then
            run.hover = nil
            ui.hoverText:Hide()
        end
        return
    end
    local mx, my = CursorInView()
    local best, bestD = nil, HOVER_PX * HOVER_PX
    for k = 1, run.figCount do
        local fig = figs[k]
        if fig.shown then
            local dx, dy = fig.sx - mx, fig.sy - (fig.hy or 0) - my
            local d = dx * dx + dy * dy
            if d < bestD then best, bestD = k, d end
        end
    end
    if best ~= run.hover then
        run.hover = best
        if best then
            ui.hoverText:SetText(figs[best].name)
            ui.hoverText:Show()
        else
            ui.hoverText:Hide()
        end
    end
    if best then PlaceLabel(figs[best]) end
end
local function Drag()
    local x, y = GetCursorPosition()
    local k = ui.view:GetEffectiveScale()
    x, y = x / k, y / k
    if run.drag == "LeftButton" then
        cam.angle = run.dragAngle + (x - run.dragX) * TURN
        Tour.Note("turn", abs(cam.angle - run.dragAngle))
        if not run.flat then
            local tilt = Clamp(run.dragTilt + (y - run.dragY) * TILT_DRAG, TILT_MIN, TILT_MAX)
            if tilt ~= run.tilt3 then
                run.tilt3 = tilt
                Reframe()
            end
            Tour.Note("tilt", abs(tilt - run.dragTilt))
        end
    else
        local rx = -(x - run.dragX) / cam.zoom
        local ry = (y - run.dragY) / (cam.zoom * cam.tilt)
        cam.cx = run.dragCx + rx * cam.c + ry * cam.s
        cam.cy = run.dragCy - rx * cam.s + ry * cam.c
    end
    run.camDirty = true
end
local function ResetCamera(defaults)
    if defaults then
        cam.angle, run.tilt3, run.persp3, run.flat = START_ANGLE, START_TILT, START_PERSP, false
        SaveCamera()
    else
        LoadCamera()
    end
    if Geo.Iso(run.scene and run.scene.room) then run.persp3, run.flat = 0, false end
    if run.flat then
        cam.tilt, cam.persp = 1, 0
    else
        cam.tilt, cam.persp = run.tilt3, run.persp3
    end
    Replay.Fit(cam, run.scene)
    run.fitZoom = cam.zoom
    run.camDirty = true
    UpdateCamUi()
end
local function Zoom(dir)
    if not run.scene then return end
    local z = cam.zoom * (dir > 0 and ZOOM_STEP or 1 / ZOOM_STEP)
    cam.zoom = Clamp(z, run.fitZoom * ZOOM_MIN, run.fitZoom * ZOOM_MAX)
    run.camDirty = true
    Tour.Note("zoom", dir)
end
local function Wheel(_, delta)
    if not run.scene then return end
    if IsShiftKeyDown() then
        SetView(run.tilt3 + delta * TILT_STEP)
        return
    end
    if IsControlKeyDown() or IsAltKeyDown() then
        Bar.Seek(delta * SEEK_STEP)
        Tour.Note("seek")
        return
    end
    Zoom(delta)
end
local function ViewDown(_, button)
    if not run.scene or button == "MiddleButton" then return end
    local x, y = GetCursorPosition()
    local k = ui.view:GetEffectiveScale()
    run.drag = button
    Geo.Cancel()
    ViewMenu.Hide()
    run.pressHover = run.hover
    run.dragX, run.dragY = x / k, y / k
    run.dragAngle, run.dragCx, run.dragCy, run.dragTilt = cam.angle, cam.cx, cam.cy, run.tilt3
end
local function ViewUp()
    local x, y = GetCursorPosition()
    local k = ui.view:GetEffectiveScale()
    local moved = run.dragX and (abs(x / k - run.dragX) + abs(y / k - run.dragY) > CLICK_PX)
    if run.drag == "LeftButton" and not moved then
        cam.angle = run.dragAngle
        local fig = run.pressHover and figs[run.pressHover]
        if fig and not fig.isBoss then
            SetFocus(fig.name)
            Tour.Note("pick")
        else
            SetFocus(nil)
        end
    elseif run.drag == "LeftButton" then
        SaveCamera()
        if not run.flat then Geo.Snap(cam, cam.angle, 0, 0) end
    end
    run.drag = nil
end
function IsoCam.Bind(s)
    ui, run, cam, dim, figs = s.ui, s.run, s.cam, s.dim, s.figs
    SetFocus, PlaceFloor = s.SetFocus, s.PlaceFloor
end
IsoCam.ApplyCamera = ApplyCamera
IsoCam.UpdateCamUi = UpdateCamUi
IsoCam.Saved = Saved
IsoCam.SaveCamera = SaveCamera
IsoCam.LoadCamera = LoadCamera
IsoCam.Reframe = Reframe
IsoCam.SetView = SetView
IsoCam.SetFlat = SetFlat
IsoCam.Turn = Turn
IsoCam.Hover = Hover
IsoCam.Drag = Drag
IsoCam.ResetCamera = ResetCamera
IsoCam.Zoom = Zoom
IsoCam.Wheel = Wheel
IsoCam.ViewDown = ViewDown
IsoCam.ViewUp = ViewUp
