local ADDON, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi
local PAD = 12
local FEED_W = 220
local LEFT = PAD + FEED_W + PAD
local HEAD = 30
local BAR_GAP = 8
local PLAYER_H = ns.ReplayBar.ROW_H
local BARS_GAP = 4
local FOOT = 22
local TITLE_BTNS = 70
local STATUS_GRIP = 24
local STATUS_PERIOD = 0.5
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local BASE_MODEL = "Character\\Human\\Male\\HumanMale.m2"
local ICONS = {
    left = "Interface\\Buttons\\UI-RotationLeft-Button-Up",
    right = "Interface\\Buttons\\UI-RotationRight-Button-Up",
    more = "Interface\\Buttons\\UI-PlusButton-Up",
    less = "Interface\\Buttons\\UI-MinusButton-Up",
    zoomin = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up",
    zoomout = "Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up",
    help = "Interface\\TutorialFrame\\TutorialFrame-QuestionMark",
    low = "Interface\\Buttons\\Arrow-Down-Up",
    high = "Interface\\Buttons\\Arrow-Up-Up",
    reset = "Interface\\TimeManager\\ResetButton",
    needle = "Interface\\Minimap\\MinimapArrow",
    north = "Interface\\Minimap\\CompassNorthTag",
}
local SEQ_STAND = 0
local SEQ_DEATH = 1
local SEQ_WALK = 4
local SEQ_RUN = 5
local SEQ_LEN = { [0] = 2667, [1] = 2000, [4] = 1000, [5] = 667 }
local DEATH_HOLD = 1950
local MODEL_HOLD = 3
local FACE_EPS = 0.03
local ICON = 18
local SHADOW = 22
local LIFT = 9
local MODEL_W = 34
local MODEL_H = 54
local DEPTH_K = 0.12
local DEPTH_FADE = 0.2
local FIG_MIN = 0.6
local FIG_MAX = 2.4
local SCALE_MIN = 0.35
local SCALE_MAX = 3
local LABEL_MIN = 0.8
local LABEL_MAX = 1.5
local FOCUS_DIM = 0.4
local CLICK_PX = 4
local DEATH_POOL = 64
local DOT_POOL = 320
local DOT = 3
local TURN = 0.01
local TURN_STEP = pi / 12
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
local NAV_TOP = 8
local NAV_RIGHT = 8
local NAV = {
    { "zoomin", "iso.tip.zoomin", 6 }, { "zoomout", "iso.tip.zoomout", 4 },
    { "left", "iso.tip.left", 10 }, { "right", "iso.tip.right", 4 },
    { "more", "iso.tip.tiltmore", 10 }, { "less", "iso.tip.tiltless", 4 },
    { "mode", "iso.tip.to2d", 10 },
    { "low", "iso.tip.low", 10 }, { "high", "iso.tip.high", 4 }, { "reset", "iso.tip.reset", 4 },
    { "help", "iso.tip.help", 10 },
}
local VIEW_LOW = 0.35
local VIEW_HIGH = 0.8
local NAV_BTN = 24
local NAV_ICON = 18
local COMPASS = 34
local NEEDLE = 26
local NORTH_TAG = 10
local NORTH_RIM = 12
local SPIN_H = 0.35
local LEGEND_W = 330
local MODEL_LEVEL = 3
local HOVER_PX = 14
local FOG_FAR = 1
local HUGE = 1e9
local START = -HUGE
local STALE_ALPHA = 0.35
local Iso = { dev = false }
ns.ReplayIso = Iso
local Replay = ns.Replay
local Kit = ns.Kit
local Size = ns.ReplaySize
local Tour = ns.ReplayTour
local dim = { viewW = Size.MIN_W, viewH = Size.MIN_H, k = 1 }
dim.sideH = dim.viewH + BAR_GAP + PLAYER_H
dim.barsH = floor(dim.sideH / 3)
dim.h = HEAD + dim.sideH + FOOT
local ui = {}
local run = {
    t = 0, playing = false, speed = 1, mode = "none", camDirty = true, fitZoom = 1, bossDrawn = false,
    focusA = {}, roles = {}, focusHeal = false,
    figScale = 1, fogFar = FOG_FAR, faceSign = 1, deathShown = -1,
    marksDirty = true, stripUsed = 0, labelScale = 1,
    tilt3 = START_TILT, persp3 = START_PERSP, flat = false, loading = false,
    msSum = 0, msN = 0, msMax = 0, acc = 0, models = 0, shown = 0, levelBase = 0,
    lastClock = -1, hover = nil, figCount = 0, hasTex = false, gapKind = "", gapSince = -1, gapLevel = -1,
}
local cam = { angle = START_ANGLE, tilt = START_TILT, persp = START_PERSP, zoom = 1, lift = 0, r = 1, a = 0,
              cx = 0, cy = 0, w = dim.viewW, h = dim.viewH, c = 1, s = 0 }
local strips, stripData, dots, figs, deathTex = {}, {}, {}, {}, {}
local Bar = ns.ReplayBar
local ViewMenu = ns.ReplayViewMenu
local LayersView = ns.ReplayLayersView
local Models = ns.ReplayModels
local Follow = ns.ReplayFollow
local Figs = ns.ReplayFigs
local Shield = ns.ReplayShield
local Geo = ns.ReplayGeo
local order, depth = {}, {}
local afigs, all = {}, {}
local addList = { x = {}, y = {}, icon = {}, chase = {} }
local addState = { dead = false, hp = 1, stale = false, speed = 0, vis = true }
local ADD_K = 0.85
Figs.BindAdds(afigs)
local picked
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Num(v, default)
    if type(v) == "number" and v == v then return v end
    return default
end
local function MinSec(sec)
    sec = max(0, floor(sec))
    return floor(sec / 60), sec % 60
end
local function ModelShow(m)
    pcall(m.SetModel, m, BASE_MODEL)
    m.ready = nil
    m.hold = MODEL_HOLD
    m.facing = nil
    m.fogKey = nil
    m.seq = nil
    if run.camIndex then pcall(m.SetCamera, m, run.camIndex) end
end
local function EnsureModel(fig)
    if fig.model then return true end
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, fig)
    if not ok or not m or not m.SetModel or not m.SetSequenceTime or not m.SetFacing then return false end
    m:SetWidth(MODEL_W)
    m:SetHeight(MODEL_H)
    m:SetPoint("BOTTOM", fig, "CENTER", 0, 0)
    m.hold = 0
    m:EnableMouse(false)
    m:SetScript("OnShow", ModelShow)
    m:Hide()
    fig.model = m
    return true
end
local function NewFigure(parent)
    local fig = CreateFrame("Frame", nil, parent)
    fig:SetWidth(SHADOW)
    fig:SetHeight(SHADOW * START_TILT)
    Figs.Build(fig)
    fig.shown = false
    fig.sx, fig.sy, fig.scale, fig.kz = 0, 0, 1, 1
    LayersView.Attach(fig)
    Follow.Attach(fig)
    fig:Hide()
    return fig
end
local function ConfigFigure(fig, tr, scene)
    fig.isBoss = tr == nil
    fig.sQ, fig.mQ, fig.rank, fig.sDead = nil, nil, nil, nil
    if tr then
        fig.name = tr.name
        fig.cr, fig.cg, fig.cb = Kit.ClassColor(tr.class)
        LayersView.Role(fig, tr.class, run.roles[tr.name])
        Figs.Config(fig, tr.class, run.roles[tr.name])
    else
        LayersView.Clear(fig)
        fig.name = format(ns.T("iso.boss"), scene.bossName or ns.EncName(scene.fight.boss))
        fig.cr, fig.cg, fig.cb = Kit.Color("sem.lane.boss")
        Figs.Config(fig, nil, "boss")
    end
    if fig.model and fig.model:IsShown() then ModelShow(fig.model) end
end
local function ApplyFog(m, fig, dead)
    local key = (dead and -1 or 1) * (run.fogFar + 1)
    if m.fogKey == key and m.hold <= 0 then return end
    m.fogKey = key
    if run.fogFar <= 0 then
        m:ClearFog()
        return
    end
    if dead then
        m:SetFogColor(Kit.RGB("sem.rep.fog"))
    else
        m:SetFogColor(fig.cr, fig.cg, fig.cb)
    end
    m:SetFogNear(0)
    m:SetFogFar(run.fogFar)
end
local Parts = Figs.Parts
local function Motion(s, k)
    if s.dead then
        return SEQ_DEATH, min(s.deadFor * 1000, DEATH_HOLD)
    end
    local seq = SEQ_STAND
    if s.speed >= Replay.RUN_YPS then
        seq = SEQ_RUN
    elseif s.speed >= Replay.MOVE_YPS then
        seq = SEQ_WALK
    end
    return seq, (run.t * 1000 + k * 137) % SEQ_LEN[seq]
end
local function ModelSize(scale)
    return MODEL_W * scale, MODEL_H * scale
end
local function DrawModel(fig, s, scale, elapsed, k)
    local m = fig.model
    local w, h = ModelSize(scale)
    local q = floor(w + 0.5)
    if fig.mQ ~= q then
        fig.mQ = q
        m:SetWidth(w)
        m:SetHeight(h)
    end
    if m.hold > 0 then
        m.hold = m.hold - elapsed
        m.facing = nil
    end
    if not m.ready then
        local ok, path = pcall(m.GetModel, m)
        if not ok or type(path) ~= "string" or path == "" then return end
        m.ready = true
    end
    local face = run.faceSign * Replay.Facing(cam, s.hx, s.hy)
    if face ~= face then return end
    if not m.facing or abs(face - m.facing) > FACE_EPS then
        m:SetFacing(face)
        m.facing = face
    end
    ApplyFog(m, fig, s.dead)
    local seq, ms = Motion(s, k)
    m:SetSequenceTime(seq, ms)
end
local function ModelFits(fig, s, sx, sy, scale)
    local m = fig.model
    if not m or fig.isBoss then return false end
    if run.mode ~= "all" and (run.mode ~= "picked" or fig.name ~= run.focus) then
        return false
    end
    local w, h = ModelSize(scale)
    local hw = w / 2
    local top = sy - h
    return sx - hw >= -cam.w / 2 and sx + hw <= cam.w / 2 and top >= -cam.h / 2 and sy <= cam.h / 2
end
local function DrawFigure(fig, s, sx, sy, scale, flat, elapsed, k)
    scale = scale * Figs.Grow(fig, elapsed)
    Figs.Sprite(fig, s, scale, flat, elapsed)
    fig.baseA = (s.stale and STALE_ALPHA or 1) * (run.focusA[k] or 1)
    fig:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
    fig.sx, fig.sy, fig.scale = sx, sy, scale
    if not fig.shown then
        fig.shown = true
        fig:Show()
    end
    if fig.isBoss and run.bossDrawn then
        Parts(fig, false, false, false)
        return false
    end
    if ModelFits(fig, s, sx, sy, scale) then
        Parts(fig, false, false, true)
        DrawModel(fig, s, scale, elapsed, k)
        return true
    end
    Parts(fig, true, not s.dead, false)
    return false
end
local function HideFigure(fig)
    if fig.shown then
        fig.shown = false
        fig:Hide()
    end
end
local function SortFigures(count)
    for i = 2, count do
        local v = order[i]
        local d = depth[v]
        local j = i - 1
        while j >= 1 and depth[order[j]] > d do
            order[j + 1] = order[j]
            j = j - 1
        end
        order[j + 1] = v
    end
    local base = run.levelBase
    for r = 1, count do
        local fig = all[order[r]]
        if fig.rank ~= r then
            fig.rank = r
            fig:SetFrameLevel(base + r * 2)
            if fig.model then fig.model:SetFrameLevel(base + r * 2 + 1) end
        end
    end
end
local function DepthScale(sy, k)
    local fade = run.flat and 0 or max(0, 1 - cam.persp / DEPTH_FADE)
    local lean = 1 + DEPTH_K * fade * Clamp(sy / (cam.h / 2), -1, 1)
    return Clamp(run.figScale * k * lean, SCALE_MIN, SCALE_MAX)
end
local function PlaceAdds(scene, base, elapsed)
    local na = LayersView.Adds(scene, run.t, addList)
    local hw, hh = cam.w / 2, cam.h / 2
    local total, hidden = base, 0
    for j = 1, max(na, #afigs) do
        local fig = afigs[j]
        if not fig and j <= na then
            fig = NewFigure(ui.view)
            afigs[j] = fig
        end
        if fig then
            total = total + 1
            all[total] = fig
            local sx, sy, kz = 0, 0, 0
            if j <= na then
                local x, y, lift = Geo.Where(cam, scene, addList.x[j], addList.y[j])
                sx, sy, kz = Replay.Project(cam, x, y)
                sy = sy - lift
                Figs.ConfigAdd(fig, addList.icon[j])
                addState.stale = addList.chase[j]
            end
            local scale = kz > 0 and DepthScale(sy, kz) * ADD_K or 0
            if j <= na and kz > 0 and sx > -hw + 2 and sx < hw - 2 and sy < hh - 2 and sy - (ICON + LIFT) * scale > -hh then
                fig.kz = kz
                DrawFigure(fig, addState, sx, sy, scale, min(1, cam.tilt * kz), elapsed, total)
                depth[total] = sy
            else
                HideFigure(fig)
                depth[total] = -HUGE
                hidden = hidden + 1
            end
        end
    end
    run.addHidden = hidden
    LayersView.stats.adds = na
    return total
end
local function PlaceFigures(elapsed)
    local scene = run.scene
    local n = #scene.tracks
    local hw, hh = cam.w / 2, cam.h / 2
    local models, shown = 0, 0
    for k = 1, n + 1 do
        local fig = figs[k]
        all[k] = fig
        local s = k <= n and scene.states[k] or scene.bossState
        local sx, sy, kz = 0, 0, 0
        if s.vis then
            local x, y, lift = Geo.Where(cam, scene, s.x, s.y)
            sx, sy, kz = Replay.Project(cam, x, y)
            sy = sy - lift
        end
        local scale = kz > 0 and DepthScale(sy, kz) or 0
        if kz > 0 and sx > -hw + 2 and sx < hw - 2 and sy < hh - 2 and sy - (ICON + LIFT) * scale > -hh then
            fig.kz = kz
            if DrawFigure(fig, s, sx, sy, scale, min(1, cam.tilt * kz), elapsed, k) then models = models + 1 end
            Shield.Place(fig, elapsed)
            shown = shown + 1
            depth[k] = sy
        else
            HideFigure(fig)
            depth[k] = -HUGE
        end
    end
    local total = PlaceAdds(scene, n + 1, elapsed)
    if run.orderN ~= total then
        run.orderN = total
        for k = 1, total do order[k] = k end
        for k = total + 1, #order do order[k] = nil end
    end
    SortFigures(total)
    Figs.Alpha(all, order, total)
    run.models, run.shown = models, shown + (total - n - 1 - run.addHidden)
end
local function PlaceFloor()
    local scene = run.scene
    if Geo.Place(cam, scene.room, scene.ppy) then
        for k = 1, run.stripUsed do strips[k]:Hide() end
        run.stripUsed = 0
        for i = 1, #dots do dots[i]:Hide() end
        return
    end
    local used = 0
    if scene.room and run.hasTex then
        used = Replay.Strips(cam, scene.room, stripData)
        for k = 1, used do
            local tex, d = strips[k], stripData[k]
            tex:SetPoint("TOPLEFT", ui.view, "CENTER", d.l, -d.t)
            tex:SetWidth(d.w)
            tex:SetHeight(d.h)
            tex:SetTexCoord(d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])
            tex:Show()
        end
    end
    for k = used + 1, run.stripUsed do strips[k]:Hide() end
    run.stripUsed = used
    local shown = 0
    if not (scene.room and run.hasTex) then
        local hw, hh = cam.w / 2, cam.h / 2
        for i = 1, min(#scene.gx, DOT_POOL) do
            local sx, sy, k = Replay.Project(cam, scene.gx[i], scene.gy[i])
            if k > 0 and sx > -hw and sx < hw and sy > -hh and sy < hh then
                shown = shown + 1
                local dot = dots[shown]
                dot:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
                dot:Show()
            end
        end
    end
    for i = shown + 1, #dots do dots[i]:Hide() end
end
local function PlaceDeaths()
    local list = run.scene.deaths
    local t = run.t
    local count = 0
    while count < #list and list[count + 1].t <= t do count = count + 1 end
    count = min(count, DEATH_POOL)
    if count == run.deathShown and not run.marksDirty then return end
    run.deathShown = count
    local hw, hh = cam.w / 2, cam.h / 2
    for i = 1, count do
        local d = list[i]
        local tex = deathTex[i]
        local sx, sy, k = Replay.Project(cam, d.x, d.y)
        if k > 0 and sx > -hw and sx < hw and sy > -hh and sy < hh then
            local size = Clamp(12 * run.figScale * k, 8, 40)
            tex:SetWidth(size)
            tex:SetHeight(size)
            tex:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
            tex:Show()
        else
            tex:Hide()
        end
    end
    for i = count + 1, #deathTex do deathTex[i]:Hide() end
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
local UpdatePlay = Bar.UpdatePlay
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
    run.mode = (saved.models == "all" or saved.models == "picked") and saved.models or "none"
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
local function UpdateGap()
    local scene = run.scene
    local kind, since, level = Replay.GapAt(scene, run.t)
    if kind == run.gapKind and since == run.gapSince and level == run.gapLevel then return end
    run.gapKind, run.gapSince, run.gapLevel = kind, since, level
    if not kind then
        ui.gap:Hide()
        return
    end
    local text
    if kind == "lost" then
        text = format(ns.T("iso.gap.lost"), MinSec(since - scene.pull))
    else
        local note = ns.Encounters.FloorNote(scene.fight.boss, level)
        text = note and ns.T("map.note." .. note) or format(ns.T("iso.gap.away"), level)
    end
    ui.gap:SetText(text)
    ui.gap:Show()
end
local function Status()
    if not (ns.Prof.on or Iso.dev) then
        ui.status:SetText("")
        return
    end
    local n = max(1, run.msN)
    local st = LayersView.stats
    ui.status:SetText(format(ns.T("iso.status"), run.msSum / n, run.msMax, run.models + Models.stats.models, run.shown,
        GetFramerate(), run.speed) .. " " .. format(ns.T("iso.status.layers"), st.badges, st.pools, st.cones,
        st.blasts, st.adds))
    run.msSum, run.msN, run.msMax = 0, 0, 0
end
local function Tick(self, elapsed)
    local scene = run.scene
    if not scene then return end
    local p0 = debugprofilestop()
    if run.playing then
        run.t = run.t + elapsed * run.speed
        if run.t >= scene.to then
            run.t = scene.to
            run.playing = false
            UpdatePlay()
        end
    end
    Bar.Step()
    if run.drag then Drag() end
    local turned, snapped = Geo.Step(cam, elapsed)
    if snapped then
        run.tilt3, run.persp3, run.flat = cam.tilt, 0, false
        Reframe()
        SaveCamera()
    elseif turned then
        run.camDirty = true
    end
    Follow.Step(elapsed)
    if Geo.Time(scene, run.t) and not run.camDirty and not run.flat then PlaceFloor() end
    if run.camDirty then ApplyCamera() end
    Replay.Sample(scene, run.t)
    run.bossDrawn = Models.Place(cam, run.t, run.figScale, run.faceSign, elapsed)
    LayersView.Place(scene, cam, run.t, figs)
    PlaceFigures(elapsed)
    ns.ReplayFeed.Update(run.t - scene.pull)
    PlaceDeaths()
    run.marksDirty = false
    Bar.UpdateScrub()
    UpdateGap()
    Hover()
    Follow.Place(elapsed)
    local ms = debugprofilestop() - p0
    run.msSum = run.msSum + ms
    run.msN = run.msN + 1
    if ms > run.msMax then run.msMax = ms end
    if ns.Prof.on then ns.Prof.Add("iso.frame", ms, run.models) end
    run.acc = run.acc + elapsed
    if run.acc >= STATUS_PERIOD then
        run.acc = 0
        Status()
    end
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
local function WantsModel(fig)
    if fig.isBoss then return false end
    return run.mode == "all" or (run.mode == "picked" and fig.name == run.focus)
end
local function SyncModels()
    local ok = true
    for k = 1, run.figCount do
        local fig = figs[k]
        fig.rank = nil
        if WantsModel(fig) then
            if not EnsureModel(fig) then ok = false end
        elseif fig.model then
            fig.model:Hide()
            fig.modelOn = false
        end
    end
    if not ok then ns.Print(ns.T("iso.nomodel")) end
end
local function SetMode(mode)
    run.mode = (mode == "all" or mode == "picked") and mode or "none"
    Saved().models = run.mode
    SyncModels()
    ViewMenu.Refresh()
end
local function ApplyFocus()
    local scene = run.scene
    local A = run.focusA
    for k = 1, #A do A[k] = nil end
    if scene and run.focus then
        for k = 1, #scene.tracks do
            local name = scene.tracks[k].name
            local role = run.roles[name]
            local keep = name == run.focus or role == "tank" or (run.focusHeal and role == "heal")
            A[k] = keep and 1 or FOCUS_DIM
        end
    end
    for k = 1, run.figCount do figs[k].alpha = nil end
    if run.focus then
        ui.focus:SetText(format(ns.T("iso.focus"), run.focus))
        ui.focus:Show()
    else
        ui.focus:Hide()
    end
    SyncModels()
    Follow.Apply()
end
local function SetFocus(name)
    local scene = run.scene
    if name and scene and not scene.fight.players[name] then name = nil end
    run.focus = name
    ApplyFocus()
end
local function FindRoles(scene)
    local roles = run.roles
    for name in pairs(roles) do roles[name] = nil end
    local s = ns.Summary and ns.Summary.Peek(scene.fight)
    if s and s.byName then
        for name, p in pairs(s.byName) do
            if p.role == "tank" or p.role == "heal" then roles[name] = p.role end
        end
    end
    local L = scene.layers
    if L and next(roles) == nil then
        for name in pairs(L.tanks) do roles[name] = "tank" end
    end
end
local function SetHeal(on)
    run.focusHeal = on and true or false
    Saved().focusHeal = run.focusHeal
    ApplyFocus()
end
local function ApplySeek()
    local scene = run.scene
    if not scene or not run.seek then return end
    run.t = Clamp(scene.pull + run.seek, scene.from, scene.to)
    run.seek = nil
    run.playing = run.t < scene.to
    run.marksDirty = true
    UpdatePlay()
end
local function Resume()
    local scene = run.scene
    if run.t >= scene.to then run.t = scene.from end
    run.playing = true
    run.marksDirty = true
    UpdatePlay()
end
local function Around()
    return (run.narrow and PAD * 2 or LEFT + PAD), HEAD + BAR_GAP + PLAYER_H + FOOT
end
local function FrameWidth()
    local w = Around() + dim.viewW
    ui.frame:SetWidth(w)
    ui.title:SetWidth(w - TITLE_BTNS)
end
local function Narrow(narrow)
    if run.narrow == narrow then return end
    run.narrow = narrow
    ui.view:ClearAllPoints()
    if narrow then
        ui.side:Hide()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", PAD, -HEAD)
    else
        ui.side:Show()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", LEFT, -HEAD)
    end
    FrameWidth()
    Size.Refit()
end
local function Relayout()
    local bars = ui.bars ~= nil and ui.bars:IsShown()
    ns.ReplayFeed.SetHeight(bars and dim.sideH - dim.barsH - BARS_GAP or dim.sideH)
    Narrow(not (run.feedHas or bars))
end
local function Resize(vw, vh)
    dim.viewW, dim.viewH = vw, vh
    dim.sideH = vh + BAR_GAP + PLAYER_H
    dim.barsH = floor(dim.sideH / 3)
    dim.h = HEAD + dim.sideH + FOOT
    dim.k = min(vw / Size.MIN_W, vh / Size.MIN_H)
    cam.w, cam.h = vw, vh
    ui.view:SetWidth(vw)
    ui.view:SetHeight(vh)
    ui.side:SetHeight(dim.sideH)
    ui.bars:SetHeight(dim.barsH)
    if ns.ReplayBarsView then ns.ReplayBarsView.Fit() end
    ui.hint:SetWidth(vw - 120)
    ui.gap:SetWidth(vw - 120)
    ui.focus:SetWidth(vw - 180)
    for i = 1, #ui.navRects do
        local r = ui.navRects[i]
        r.x = vw - r.right - r.w
    end
    Bar.Resize(vw)
    Bar.Use(run.scene)
    ui.status:SetWidth(vw - STATUS_GRIP)
    ui.frame:SetHeight(dim.h)
    FrameWidth()
    Relayout()
    Reframe()
    run.marksDirty = true
end
local function UseScene(scene)
    run.scene = scene
    run.t = scene.from
    run.playing = false
    run.deathShown, run.lastClock = -1, -1
    run.gapKind, run.gapSince, run.gapLevel = "", -1, -1
    Figs.Bind(figs, ui.view)
    FindRoles(scene)
    LayersView.Use(scene)
    Models.Use(scene)
    run.feedHas = ns.ReplayFeed.Use(scene.layers)
    Relayout()
    local n = #scene.tracks
    for k = #figs + 1, n + 1 do figs[k] = NewFigure(ui.view) end
    for k = 1, #figs do HideFigure(figs[k]) end
    for k = 1, n do ConfigFigure(figs[k], scene.tracks[k], scene) end
    ConfigFigure(figs[n + 1], nil, scene)
    run.figCount = n + 1
    for k = 1, n + 1 do order[k] = k end
    for k = n + 2, #order do order[k] = nil end
    run.hasTex = false
    if scene.room then
        local path = ROOM_PATH .. scene.room.tex
        run.hasTex = true
        for k = 1, #strips do
            if not strips[k]:SetTexture(path) then run.hasTex = false end
        end
    end
    Geo.Use(scene.room)
    if not scene.room then
        ui.hint:SetText(ns.T("iso.notex"))
        ui.hint:Show()
    elseif not run.hasTex then
        ui.hint:SetText(ns.T("iso.notexfile"))
        ui.hint:Show()
    else
        ui.hint:Hide()
    end
    ResetCamera(false)
    Bar.Use(scene)
    UpdatePlay()
    ApplySeek()
    SetFocus(run.want)
    Tour.Auto()
end
local function NavButton(parent, icon, tip)
    local b = Kit.Button(parent)
    b:SetWidth(NAV_BTN)
    b:SetHeight(NAV_BTN)
    if icon then
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetTexture(icon)
        b.icon:SetWidth(NAV_ICON)
        b.icon:SetHeight(NAV_ICON)
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    b.tip = ns.T(tip)
    b.tipTitle = false
    b.tipAnchor = "ANCHOR_LEFT"
    return b
end
local function BuildPools()
    local view = ui.view
    for k = 1, Replay.STRIPS do
        local tex = view:CreateTexture(nil, "BORDER")
        tex:Hide()
        strips[k] = tex
    end
    for i = 1, DOT_POOL do
        local dot = view:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(CIRCLE)
        Kit.Tint(dot, "sem.rep.tick")
        dot:SetWidth(DOT)
        dot:SetHeight(DOT)
        dot:Hide()
        dots[i] = dot
    end
    LayersView.Build(view, ui.marks)
    for i = 1, DEATH_POOL do
        local tex = ui.marks:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(MARKS)
        tex:SetTexCoord(0.5, 0.75, 0.25, 0.5)
        tex:Hide()
        deathTex[i] = tex
    end
    for k = 1, 26 do figs[k] = NewFigure(view) end
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
local function NavPlace(b, name, y, w, h)
    local right = NAV_RIGHT + (COMPASS - w) / 2
    b:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -right, -y)
    ui.navRects[#ui.navRects + 1] = { name = name, x = dim.viewW - right - w, y = y, w = w, h = h, right = right }
    return y + h
end
local function BuildCompass(top)
    local b = NavButton(top, nil, "iso.tip.north")
    b:SetWidth(COMPASS)
    b:SetHeight(COMPASS)
    NavPlace(b, "north", NAV_TOP, COMPASS, COMPASS)
    b.onClick = function() Turn(-cam.angle) end
    ui.needle = b:CreateTexture(nil, "OVERLAY")
    ui.needle:SetTexture(ICONS.needle)
    ui.needle:SetWidth(NEEDLE)
    ui.needle:SetHeight(NEEDLE)
    ui.needle:SetPoint("CENTER", b, "CENTER", 0, 0)
    ui.northTag = b:CreateTexture(nil, "OVERLAY")
    ui.northTag:SetTexture(ICONS.north)
    ui.northTag:SetWidth(NORTH_TAG)
    ui.northTag:SetHeight(NORTH_TAG)
    ui.compass = b
end
local function BuildLegend(top)
    local f = CreateFrame("Button", nil, top)
    f:SetWidth(LEGEND_W)
    f:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -(COMPASS + NAV_RIGHT * 2), -NAV_TOP)
    f:SetFrameLevel(top:GetFrameLevel() + 6)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    Kit.Paint(bg, "surface.bg", 0.94)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    text:SetWidth(LEGEND_W - 20)
    text:SetJustifyH("LEFT")
    text:SetText(ns.T("iso.legend"))
    f:SetHeight(max(120, text:GetStringHeight() + 16))
    f:SetScript("OnClick", function(self) self:Hide() end)
    f:Hide()
    ui.legend = f
end
local function BuildNav(top)
    ui.navRects = {}
    BuildCompass(top)
    local act = {
        zoomin = function() Zoom(1) end,
        zoomout = function() Zoom(-1) end,
        left = function() Turn(-TURN_STEP) end,
        right = function() Turn(TURN_STEP) end,
        more = function() SetView(run.tilt3 - TILT_STEP) end,
        less = function() SetView(run.tilt3 + TILT_STEP) end,
        mode = function() SetFlat(not run.flat) end,
        low = function() SetView(VIEW_LOW) end,
        high = function() SetView(VIEW_HIGH) end,
        reset = function() if run.scene then ResetCamera(true) end end,
        help = function()
            if ui.legend:IsShown() then ui.legend:Hide() else ui.legend:Show() end
        end,
    }
    local y = NAV_TOP + COMPASS
    for i = 1, #NAV do
        local d = NAV[i]
        local name = d[1]
        local b = NavButton(top, ICONS[name], d[2])
        local w = name == "mode" and COMPASS or NAV_BTN
        b:SetWidth(w)
        y = NavPlace(b, name, y + d[3], w, NAV_BTN)
        b.onClick = act[name]
        ui.nav[name] = b
    end
    ui.modeBtn = ui.nav.mode
    BuildLegend(top)
end
local function BuildBars(side)
    local bars = CreateFrame("Frame", nil, side)
    bars:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 0, 0)
    bars:SetWidth(FEED_W)
    bars:SetHeight(dim.barsH)
    bars:Hide()
    bars:SetScript("OnShow", Relayout)
    bars:SetScript("OnHide", Relayout)
    ui.bars = bars
end
local function BuildView(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetWidth(FEED_W)
    side:SetHeight(dim.sideH)
    side:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEAD)
    local sideBg = side:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints(side)
    Kit.Paint(sideBg, "surface.page", 0.5)
    ui.side = side
    ns.ReplayFeed.Build(side, FEED_W, dim.sideH, function(sec, who)
        if not run.scene then return end
        run.t = Clamp(run.scene.pull + sec, run.scene.from, run.scene.to)
        run.marksDirty = true
        if who and run.scene.fight.players[who] then SetFocus(who) end
    end)
    BuildBars(side)
    local view = CreateFrame("Frame", nil, frame)
    view:SetWidth(dim.viewW)
    view:SetHeight(dim.viewH)
    view:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -HEAD)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseDown", ViewDown)
    view:SetScript("OnMouseUp", ViewUp)
    view:SetScript("OnMouseWheel", Wheel)
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(view)
    Kit.Paint(bg, "surface.page")
    ui.view = view
    ui.marks = CreateFrame("Frame", nil, view)
    ui.marks:SetAllPoints(view)
    ui.marks:SetFrameLevel(view:GetFrameLevel() + 2)
    Models.Build(view, view:GetFrameLevel() + MODEL_LEVEL)
    run.levelBase = view:GetFrameLevel() + MODEL_LEVEL + Models.Levels()
    Geo.Build(view, min(117, run.levelBase + 2 * 42 + 2))
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(min(118, run.levelBase + 2 * 42 + 4))
    ui.top = top
    ui.hoverBox = CreateFrame("Frame", nil, top)
    ui.hoverBox:SetWidth(240)
    ui.hoverBox:SetHeight(16)
    ui.hoverText = ui.hoverBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.hoverText:SetPoint("BOTTOM", ui.hoverBox, "BOTTOM", 0, 0)
    ui.hoverText:Hide()
    ui.hint = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.hint:SetPoint("TOP", view, "TOP", 0, -8)
    ui.hint:SetWidth(dim.viewW - 120)
    Kit.Text(ui.hint, "text.secondary")
    ui.gap = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.gap:SetPoint("BOTTOM", view, "BOTTOM", 0, 8)
    ui.gap:SetWidth(dim.viewW - 120)
    Kit.Text(ui.gap, "text.warn")
    ui.focus = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.focus:SetPoint("TOPLEFT", view, "TOPLEFT", 8, -8)
    ui.focus:SetWidth(dim.viewW - 180)
    ui.focus:SetJustifyH("LEFT")
    Kit.Text(ui.focus, "text.title")
    ui.focus:Hide()
    BuildNav(top)
end
local function BuildBottom()
    Bar.Build(ui, run, dim.viewW)
    ui.bar:SetPoint("TOPLEFT", ui.view, "BOTTOMLEFT", 0, -BAR_GAP)
    ViewMenu.Build(ui, run, {
        SetModels = SetMode,
        Models = function() return run.mode end,
        SetHeal = SetHeal,
        Heal = function() return run.focusHeal end,
        SetGeo = function(on) Iso.SetGeo(on, true) end,
        Room = function() return run.scene and run.scene.room end,
    })
    Models.onChange = function()
        ViewMenu.Refresh()
        if ns.Settings and ns.Settings.Refresh then ns.Settings.Refresh() end
    end
    Figs.Load()
end
local function NearFigure()
    local best, bestD
    for k = 1, run.figCount do
        local fig = figs[k]
        if fig.shown and not fig.isBoss then
            local d = fig.sx * fig.sx + fig.sy * fig.sy
            if not bestD or d < bestD then best, bestD = fig, d end
        end
    end
    return best
end
local function Build()
    local frame = CreateFrame("Frame", "HTP_FailWatchReplayIso", UIParent)
    frame:SetWidth(LEFT + dim.viewW + PAD)
    frame:SetHeight(dim.h)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    Kit.Window(frame)
    frame:Hide()
    tinsert(UISpecialFrames, "HTP_FailWatchReplayIso")
    ui.frame = frame
    ui.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -10)
    ui.title:SetWidth(LEFT + dim.viewW + PAD - TITLE_BTNS)
    ui.title:SetJustifyH("LEFT")
    Kit.Title(ui.title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() Iso.Hide() end)
    ui.nav = {}
    BuildView(frame)
    LoadCamera()
    BuildBottom()
    Follow.Bind(ui, run, cam, figs, SetFocus)
    ui.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.status:SetPoint("TOPLEFT", ui.bar, "BOTTOMLEFT", 0, -4)
    ui.status:SetWidth(dim.viewW - STATUS_GRIP)
    ui.status:SetJustifyH("LEFT")
    BuildPools()
    UpdateCamUi()
    run.narrow = false
    Tour.Bind(ui, { Saved = Saved, Figure = NearFigure })
    Size.Bind(frame, close, HEAD, Resize, Around)
    Size.Restore()
    frame:SetScript("OnUpdate", Tick)
    frame:SetScript("OnShow", function()
        Size.Refit()
        if not run.scene then return end
        Geo.Use(run.scene.room)
        run.camDirty = true
    end)
    frame:SetScript("OnHide", function()
        Geo.Release()
        ViewMenu.Hide()
        Tour.Stop()
        run.playing = false
        run.drag = nil
        run.scrubbing = false
    end)
end
local function SelectedFight()
    local f = ns.SummaryView and ns.SummaryView.Fight and ns.SummaryView.Fight() or picked
    if f then return f, false end
    if not ns.Encounters.Ready() then return nil, false end
    local all = ns.Encounters.Fights()
    local best
    for i = 1, #all do
        if Replay.HasRoom(all[i].boss) and (not best or all[i].from > best.from) then best = all[i] end
    end
    return best, true
end
local function LoadFight(fight)
    run.fight = fight
    run.scene = nil
    run.loading = true
    for k = 1, #figs do HideFigure(figs[k]) end
    for k = 1, #afigs do HideFigure(afigs[k]) end
    run.orderN = nil
    for k = 1, #strips do strips[k]:Hide() end
    run.stripUsed = 0
    for k = 1, #dots do dots[k]:Hide() end
    Geo.Use(nil)
    LayersView.Use(nil)
    Models.Use(nil)
    ns.ReplayFeed.Use(nil)
    Bar.Use(nil)
    ui.title:SetText(format(ns.T("iso.title"), ns.FightList and ns.FightList.Title(fight) or ns.EncName(fight.boss)))
    ui.hint:SetText(ns.T("iso.loading"))
    ui.hint:Show()
    ui.gap:Hide()
    ui.status:SetText("")
    Replay.Load(fight, function(scene)
        if run.fight ~= fight then return end
        run.loading = false
        if not ui.frame:IsShown() then return end
        if not scene or #scene.tracks == 0 then
            ui.hint:SetText(ns.T(ns.Store.Bare(fight) and "rec.bare" or "iso.nodata"))
            ui.hint:Show()
            return
        end
        UseScene(scene)
    end)
end
function Iso.Show()
    local fight, auto = SelectedFight()
    if not fight then
        ns.Print(ns.T("iso.nofight"))
        return
    end
    if not ui.frame then Build() end
    if auto then ns.Print(format(ns.T("iso.auto"), ns.EncName(fight.boss))) end
    run.want = run.focus
    ui.frame:Show()
    if run.fight ~= fight or not run.scene then
        run.seek = START
        LoadFight(fight)
    else
        run.seek = nil
        Resume()
        Tour.Auto()
    end
end
function Iso.Open(fight, t, who)
    if not fight then return end
    if not ui.frame then Build() end
    run.seek = tonumber(t) and max(0, tonumber(t)) or START
    run.want = who
    ui.frame:Show()
    if run.fight ~= fight or (not run.scene and not run.loading) then
        LoadFight(fight)
    elseif run.scene then
        ApplySeek()
        SetFocus(who)
        Tour.Auto()
    end
end
function Iso.IsShown()
    return ui.frame ~= nil and ui.frame:IsShown() and true or false
end
function Iso.Hide()
    if ui.frame then ui.frame:Hide() end
    Replay.Cancel()
    if not run.scene then
        run.loading = false
        run.fight = nil
    end
end
function Iso.Focus(name)
    SetFocus(name)
end
function Iso.Scene()
    return run.scene
end
function Iso.Now()
    return run.t, run.playing
end
function Iso.Toggle()
    if ui.frame and ui.frame:IsShown() then Iso.Hide() else Iso.Show() end
end
function Iso.SetFog(far)
    run.fogFar = max(0, far)
    ns.Print(format(ns.T("iso.fog"), run.fogFar))
end
function Iso.FlipFace()
    run.faceSign = -run.faceSign
    ns.Print(format(ns.T("iso.flip"), run.faceSign))
end
function Iso.SetPlaying(on)
    if not run.scene then return end
    run.playing = on and true or false
    UpdatePlay()
end
function Iso.SetGeo(on, quiet)
    Geo.on = on and true or false
    Saved().geo = Geo.on
    if run.scene then
        if Geo.on then
            Geo.Snap(cam, cam.angle, 0, 0)
        else
            Geo.Cancel()
            run.persp3 = START_PERSP
            Reframe()
        end
    end
    UpdateCamUi()
    if not quiet then ns.Print(ns.T(Geo.on and "iso.geo.on" or "iso.geo.off")) end
end
function Iso.BarsFrame()
    if not ui.frame then Build() end
    return ui.bars
end
function Iso.ViewFrame()
    if not ui.frame then Build() end
    return ui.view
end
function Iso.Layout()
    if not ui.frame then Build() end
    local aw, ah = Around()
    return { w = aw + dim.viewW, h = ah + dim.viewH, viewW = dim.viewW, viewH = dim.viewH, sideH = dim.sideH,
             barsH = dim.barsH, nav = ui.navRects, navBtns = ui.nav, camW = cam.w, camH = cam.h, fitZoom = run.fitZoom,
             figScale = run.figScale, size = Size.Probe(), tour = Tour.Probe(), feedRows = ns.ReplayFeed.Stats().rows,
             bar = Bar.Probe(), menu = ViewMenu.Probe(), narrow = run.narrow, zoom = cam.zoom,
             tilt = run.tilt3, flat = run.flat, speed = run.speed, mode = run.mode, heal = run.focusHeal }
end
function Iso.SetCamera(index)
    run.camIndex = index
    Models.SetCamera(index)
    for k = 1, run.figCount do
        local m = figs[k].model
        if m and figs[k].modelOn then ModelShow(m) end
    end
    ns.Print(format(ns.T("iso.camera"), index or -1))
end
if ns.MapView and ns.MapView.SetFight then
    hooksecurefunc(ns.MapView, "SetFight", function(f) picked = f end)
end
