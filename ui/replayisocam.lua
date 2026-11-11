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
local PRESETS = { low = 0.35, mid = START_TILT, high = 0.8 }
local PRESET_KEYS = { "low", "mid", "high" }
local PRESET_NEAR = 0.03
local GEO_WAIT = 0.35
local TILT_DRAG = 0.004
local SEEK_STEP = ns.ReplayBar.SEEK_STEP
local NORTH_RIM = 12
local SPIN_H = 0.35
local FIG_MIN = 0.6
local FIG_MAX = 2.4
local HOVER_PX = 14
local VIEW_TILT = PRESETS.mid
local VIEW_ZOOM = 1
local VIEW_AT = { 3, 6, 10, 15, 20, 30 }
local VIEW_STEPS = 72
local IsoCam = { START_ANGLE = START_ANGLE, START_TILT = START_TILT, START_PERSP = START_PERSP,
                 TILT_STEP = TILT_STEP, PRESETS = PRESETS, PRESET_KEYS = PRESET_KEYS }
ns.ReplayIsoCam = IsoCam
local Kit = ns.Kit
local RD = ns.ReplayDraw
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
local Clamp = RD.Clamp
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
local function Allow(b, on, tip)
    b.btnDisabled = (not on) or nil
    b.tip = tip
    b.kitStyle(b)
    if b.icon then Kit.Tint(b.icon, on and "text.title" or "text.muted") end
    if b.hovered then Kit.TipShow(b) end
end
local function UpdateCamUi()
    if not ui.modeBtn then return end
    ui.modeBtn.text:SetText(ns.T(run.flat and "iso.cam.2d" or "iso.cam.3d"))
    ui.modeBtn.tip = ns.T(run.flat and "iso.tip.to3d" or "iso.tip.to2d")
    ui.modeBtn.tipClick = ns.T(run.flat and "iso.tip.to3d.act" or "iso.tip.to2d.act")
    local nav = ui.nav
    if nav and nav.tiltmore then
        Allow(nav.tiltmore, not run.flat, ns.T(run.flat and "iso.tip.tilt2d" or "iso.tip.tiltmore"))
        Allow(nav.tiltless, not run.flat, ns.T(run.flat and "iso.tip.tilt2d" or "iso.tip.tiltless"))
    end
    ViewMenu.Refresh()
end
local Saved = RD.Saved
local function ViewKey()
    local sc = run and run.scene
    if not sc then return nil end
    if sc.room and sc.room.tex then return sc.room.tex end
    return "b" .. tostring(sc.fight and sc.fight.boss)
end
local function Views()
    local saved = Saved()
    if type(saved.views) ~= "table" then saved.views = {} end
    saved.angle, saved.tilt, saved.flat = nil, nil, nil
    return saved.views
end
local function SaveCamera()
    local key = ViewKey()
    if not key then return end
    local views = Views()
    local v = views[key]
    if type(v) ~= "table" then
        v = {}
        views[key] = v
    end
    v.a, v.t, v.f = cam.angle % (2 * pi), run.tilt3, run.flat or nil
    if run.fitZoom and run.fitZoom > 0 then v.z, v.r = cam.zoom / run.fitZoom, cam.r end
end
local function LoadCamera()
    local saved = Saved()
    cam.angle = START_ANGLE
    run.tilt3 = VIEW_TILT
    run.persp3 = START_PERSP
    run.flat = false
    run.focusHeal = saved.focusHeal == true
    Geo.on = saved.geo ~= false
    ns.ReplayLive.SetThrone(saved.throne)
end
local function Reframe(quiet)
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
    if not quiet then UpdateCamUi() end
end
local function SetView(tilt)
    run.flat = false
    run.tilt3 = Clamp(tilt, TILT_MIN, TILT_MAX)
    Reframe()
    SaveCamera()
    Geo.Snap(cam, cam.angle, 0, GEO_WAIT)
end
local function SetPreset(key)
    local tilt = PRESETS[key]
    if tilt then SetView(tilt) end
end
local function Preset()
    if run.flat then return nil end
    for i = 1, #PRESET_KEYS do
        local key = PRESET_KEYS[i]
        if abs(run.tilt3 - PRESETS[key]) <= PRESET_NEAR then return key end
    end
    return nil
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
local function Hover()
    if run.drag or not ui.view:IsMouseOver() then
        run.hover = nil
        if ns.ReplayTombView then ns.ReplayTombView.Hover(nil, nil, nil, run.t) end
        ns.ReplayCcView.AddHover(nil, nil, run.t)
        ns.ReplayClassView.Hover(nil, nil)
        return
    end
    local mx, my = CursorInView()
    ns.ReplayClassView.Hover(mx, my)
    local best, bestD = nil, HOVER_PX * HOVER_PX
    for k = 1, run.figCount do
        local fig = figs[k]
        if fig.shown then
            local dx, dy = fig.sx - mx, fig.sy - (fig.hy or 0) - my
            local d = dx * dx + dy * dy
            if d < bestD then best, bestD = k, d end
        end
    end
    run.hover = best
    if ns.ReplayTombView then ns.ReplayTombView.Hover(run.scene, best and figs[best] or nil, best, run.t) end
    local addFig = nil
    if not best then
        local afigs = ns.ReplayIsoFigs.afigs
        for j = 1, #afigs do
            local fig = afigs[j]
            if fig.shown and fig.ccAdd then
                local dx, dy = fig.sx - mx, fig.sy - (fig.hy or 0) - my
                local d = dx * dx + dy * dy
                if d < bestD then addFig, bestD = fig, d end
            end
        end
    end
    ns.ReplayCcView.AddHover(run.scene, addFig, run.t)
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
                Reframe(true)
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
local farD = {}
local function RaidAndBoss(scene)
    local rx, ry
    for i = 1, #VIEW_AT do
        Replay.Sample(scene, scene.pull + VIEW_AT[i])
        local b = scene.bossState
        local boss = b and b.vis
        local n = 0
        for k = 1, #scene.tracks do
            local s = scene.states[k]
            if s and s.vis and not s.dead then
                n = n + 1
                farD[n] = boss and (s.x - b.x) ^ 2 + (s.y - b.y) ^ 2 or 0
            end
        end
        for j = #farD, n + 1, -1 do farD[j] = nil end
        if n > 0 then
            table.sort(farD)
            local cut = farD[floor((n + 1) / 2)]
            local sx, sy, m = 0, 0, 0
            for k = 1, #scene.tracks do
                local s = scene.states[k]
                if s and s.vis and not s.dead
                    and (not boss or (s.x - b.x) ^ 2 + (s.y - b.y) ^ 2 >= cut) then
                    sx, sy, m = sx + s.x, sy + s.y, m + 1
                end
            end
            if not rx then rx, ry = sx / m, sy / m end
            if boss then return sx / m, sy / m, b.x, b.y end
        end
    end
    return rx, ry, nil, nil
end
local function AngleToBoss(rx, ry, bx, by)
    if (bx - rx) ^ 2 + (by - ry) ^ 2 < 1 then return nil end
    local best, bestK = nil, -2
    local a0 = cam.angle
    for i = 0, VIEW_STEPS - 1 do
        cam.angle = 2 * pi * i / VIEW_STEPS
        Replay.Aim(cam)
        local x1, y1 = Replay.Project(cam, rx, ry)
        local x2, y2 = Replay.Project(cam, bx, by)
        local dx, dy = x2 - x1, y2 - y1
        local d = sqrt(dx * dx + dy * dy)
        local k = d > 0 and -dy / d or -2
        if k > bestK then best, bestK = cam.angle, k end
    end
    cam.angle = a0
    return best
end
local function ResetCamera(defaults)
    Geo.Cancel()
    LoadCamera()
    local scene = run.scene
    local key = ViewKey()
    if defaults and key then Views()[key] = nil end
    local v = key and Views()[key]
    if type(v) ~= "table" then v = nil end
    local def = scene and scene.room and scene.room.view
    if v then
        cam.angle = Num(v.a, START_ANGLE)
        run.tilt3 = Clamp(Num(v.t, VIEW_TILT), TILT_MIN, TILT_MAX)
        run.flat = v.f == true
    else
        run.tilt3 = Clamp(def and def.tilt or VIEW_TILT, TILT_MIN, TILT_MAX)
    end
    if Geo.Iso(scene and scene.room) then run.persp3, run.flat = 0, false end
    if run.flat then
        cam.tilt, cam.persp = 1, 0
    else
        cam.tilt, cam.persp = run.tilt3, run.persp3
    end
    Replay.Fit(cam, scene)
    run.fitZoom = cam.zoom
    local vz = v and v.r and tonumber(v.z)
    if vz then vz = vz * cam.r / Num(v.r, cam.r) end
    local zk = Clamp(vz or (def and def.zoom) or VIEW_ZOOM, ZOOM_MIN, ZOOM_MAX)
    if scene then
        local rx, ry, bx, by = RaidAndBoss(scene)
        if not v then
            cam.angle = def and def.angle or (bx and AngleToBoss(rx, ry, bx, by)) or START_ANGLE
        end
        if zk > 1 and rx then
            cam.cx, cam.cy = bx and (rx + bx) / 2 or rx, by and (ry + by) / 2 or ry
        end
    end
    cam.zoom = run.fitZoom * zk
    run.camDirty = true
    UpdateCamUi()
end
local function DefaultView()
    if run.scene then ResetCamera(true) end
end
local function Zoom(dir)
    if not run.scene then return end
    local z = cam.zoom * (dir > 0 and ZOOM_STEP or 1 / ZOOM_STEP)
    cam.zoom = Clamp(z, run.fitZoom * ZOOM_MIN, run.fitZoom * ZOOM_MAX)
    run.camDirty = true
    SaveCamera()
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
        UpdateCamUi()
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
IsoCam.SetPreset = SetPreset
IsoCam.Preset = Preset
IsoCam.SetFlat = SetFlat
IsoCam.Turn = Turn
IsoCam.Hover = Hover
IsoCam.Drag = Drag
IsoCam.ResetCamera = ResetCamera
IsoCam.DefaultView = DefaultView
IsoCam.ViewKey = ViewKey
IsoCam.VIEW_TILT, IsoCam.VIEW_ZOOM = VIEW_TILT, VIEW_ZOOM
IsoCam.Zoom = Zoom
IsoCam.Wheel = Wheel
IsoCam.ViewDown = ViewDown
IsoCam.ViewUp = ViewUp
