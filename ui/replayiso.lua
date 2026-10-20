local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local STATUS_PERIOD = 0.5
local STILL = { after = 0.5, step = 0.1 }
local FOCUS_DIM = 0.4
local HUGE = 1e9
local START = -HUGE
local Iso = { dev = false }
ns.ReplayIso = Iso
local Replay = ns.Replay
local Size = ns.ReplaySize
local Tour = ns.ReplayTour
local IsoCam = ns.ReplayIsoCam
local IsoFigs = ns.ReplayIsoFigs
local IsoBuild = ns.ReplayIsoBuild
local START_ANGLE, START_TILT, START_PERSP = IsoCam.START_ANGLE, IsoCam.START_TILT, IsoCam.START_PERSP
local SCENE = IsoBuild.SCENE
local dim = IsoBuild.dim
local ui = {}
local run = {
    t = 0, playing = false, speed = 1, camDirty = true, fitZoom = 1,
    focusA = {}, roles = {}, focusHeal = false,
    figScale = 1, deathShown = -1,
    marksDirty = true, stripUsed = 0, labelScale = 1,
    tilt3 = START_TILT, persp3 = START_PERSP, flat = false, loading = false,
    msSum = 0, msN = 0, msMax = 0, acc = 0, shown = 0, levelBase = 0,
    lastClock = -1, hover = nil, figCount = 0, hasTex = false, gapKind = "", gapSince = -1, gapLevel = -1,
    fadeA = 0, snapScene = false,
}
local cam = { angle = START_ANGLE, tilt = START_TILT, persp = START_PERSP, zoom = 1, lift = 0, r = 1, a = 0,
              cx = 0, cy = 0, w = dim.viewW, h = dim.viewH, c = 1, s = 0 }
local figs, afigs, order, strips, dots = IsoFigs.figs, IsoFigs.afigs, IsoFigs.order, IsoFigs.strips, IsoFigs.dots
local Bar = ns.ReplayBar
local ViewMenu = ns.ReplayViewMenu
local LayersView = ns.ReplayLayersView
local Follow = ns.ReplayFollow
local Figs = ns.ReplayFigs
local Geo = ns.ReplayGeo
local Sky = ns.ReplaySky
local Realm = ns.ReplayRealmView
local Soul = ns.ReplaySoulView
local NewFigure, ConfigFigure, HideFigure = IsoFigs.NewFigure, IsoFigs.ConfigFigure, IsoFigs.HideFigure
local PlaceFigures, PlaceFloor, PlaceDeaths = IsoFigs.PlaceFigures, IsoFigs.PlaceFloor, IsoFigs.PlaceDeaths
local UseFloor = IsoFigs.UseFloor
local ApplyCamera, UpdateCamUi, Saved = IsoCam.ApplyCamera, IsoCam.UpdateCamUi, IsoCam.Saved
local SaveCamera, Reframe, ResetCamera = IsoCam.SaveCamera, IsoCam.Reframe, IsoCam.ResetCamera
local Hover, Drag = IsoCam.Hover, IsoCam.Drag
local Around, Relayout, Build = IsoBuild.Around, IsoBuild.Relayout, IsoBuild.Build
local picked
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function MinSec(sec)
    sec = max(0, floor(sec))
    return floor(sec / 60), sec % 60
end
local UpdatePlay = Bar.UpdatePlay
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
    ui.status:SetText(format(ns.T("iso.status"), run.msSum / n, run.msMax, run.shown, GetFramerate(), run.speed) .. " "
        .. format(ns.T("iso.status.layers"), st.badges, st.pools, st.cones, st.blasts, st.adds))
    run.msSum, run.msN, run.msMax = 0, 0, 0
end
local SwapScene
local function WantScene()
    local base = run.base
    local alt = base and base.alt
    if not alt then return base end
    if run.pin then return run.pin == "alt" and alt or base end
    if run.focus and Follow.On() then return Replay.InsideOne(base, run.focus, run.t) and alt or base end
    return Replay.AltAt(base, run.t) and alt or base
end
local function StepScene(elapsed)
    local want = WantScene()
    if want and want ~= run.scene then
        if run.snapScene then
            SwapScene(want)
        else
            run.fadeA = min(1, run.fadeA + elapsed / SCENE.fade)
            if run.fadeA >= 1 then SwapScene(want) end
        end
    elseif run.fadeA > 0 then
        run.fadeA = max(0, run.fadeA - elapsed / SCENE.fade)
    end
    run.snapScene = false
    if run.fadeA > 0 then
        ui.fade:SetAlpha(run.fadeA)
        if not ui.fade:IsShown() then ui.fade:Show() end
        return true
    end
    if ui.fade:IsShown() then ui.fade:Hide() end
    return want ~= run.scene
end
local function Tick(self, elapsed)
    if not run.scene then return end
    local busy = StepScene(elapsed)
    local scene, base = run.scene, run.base
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
    local still = not run.playing and not run.drag and not snapped and not run.camDirty and not busy
        and not run.marksDirty and run.t == run.stillT
        and not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton")
    run.stillT = run.t
    if still then
        run.stillFor = (run.stillFor or 0) + elapsed
        if run.stillFor > STILL.after then
            run.stillAcc = (run.stillAcc or 0) + elapsed
            if run.stillAcc < STILL.step then
                Hover()
                return
            end
            elapsed, run.stillAcc = run.stillAcc, 0
        end
    else
        run.stillFor, run.stillAcc = 0, 0
    end
    Follow.Step(elapsed)
    if Geo.Time(scene, run.t) and not run.camDirty and not run.flat then PlaceFloor() end
    if run.camDirty then ApplyCamera() end
    Sky.Place(cam, scene, run.t, Geo.Shown())
    Replay.Sample(scene, run.t)
    if scene ~= base then Replay.Sample(base, run.t) end
    Realm.Sample(scene, run.t, figs)
    Soul.Sample(base, run.t)
    if scene ~= base then Soul.Fill(scene, run.t) end
    LayersView.Place(scene, cam, run.t, figs)
    Realm.Place(scene, cam, run.t)
    ns.ReplaySwarmView.Place(scene, cam, run.t)
    ns.ReplayOozeView.Place(scene, cam, run.t)
    ns.ReplayClassView.Place(scene, cam, run.t)
    ns.ReplaySpreadView.Place(scene, cam, run.t)
    ns.ReplayCueView.Place(scene, cam, run.t)
    ns.ReplayArrowsView.Place(scene, cam, run.t)
    Soul.Place(base, scene, run.t)
    PlaceFigures(elapsed)
    ns.ReplayUnitsView.Place(scene, run.t, figs, #scene.tracks)
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
    if ns.Prof.on then ns.Prof.Add("iso.frame", ms, run.shown) end
    run.acc = run.acc + elapsed
    if run.acc >= STATUS_PERIOD then
        run.acc = 0
        Status()
    end
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
    LayersView.Focus(run.focus)
    ns.ReplayUnitsView.Focus(run.focus)
    ns.ReplayArrowsView.Focus(run.focus)
    if run.focus then
        ui.focus:SetText(format(ns.T("iso.focus"), run.focus))
        ui.focus:Show()
    else
        ui.focus:Hide()
    end
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
    run.snapScene = true
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
local function UpdateSceneBtn()
    local b = ui.nav and ui.nav.scene
    if not b then return end
    local base = run.base
    if not (base and base.alt) then
        b:Hide()
        return
    end
    b.text:SetText(ns.T(run.scene == base and "iso.scene.base" or "iso.scene.alt"))
    b.tip = ns.T(run.pin and "iso.tip.scene.pin" or "iso.tip.scene.auto")
    b:SetActive(run.pin ~= nil)
    b:Show()
end
SwapScene = function(sc)
    run.scene = sc
    run.deathShown = -1
    run.gapKind, run.gapSince, run.gapLevel = "", -1, -1
    LayersView.Use(sc)
    ns.ReplayClassView.Use(sc)
    ns.ReplaySpreadView.Use(sc)
    ns.ReplayCueView.Use(sc)
    ns.ReplayArrowsView.Use(sc)
    ns.ReplayUnitsView.Use(sc)
    ConfigFigure(figs[#sc.tracks + 1], nil, sc)
    UseFloor(sc.room)
    ResetCamera(false)
    Follow.Apply()
    run.marksDirty = true
    UpdateSceneBtn()
end
local function UseScene(scene)
    Replay.Prep(scene)
    run.scene, run.base, run.fadeA = scene, scene, 0
    ui.fade:Hide()
    run.t = scene.from
    run.playing = false
    run.deathShown, run.lastClock = -1, -1
    run.gapKind, run.gapSince, run.gapLevel = "", -1, -1
    Figs.Bind(figs, ui.view)
    FindRoles(scene)
    LayersView.Use(scene)
    Realm.Use(scene)
    ns.ReplaySwarmView.Use(scene)
    ns.ReplayOozeView.Use(scene)
    ns.ReplayClassView.Use(scene)
    ns.ReplaySpreadView.Use(scene)
    ns.ReplayCueView.Use(scene)
    ns.ReplayArrowsView.Use(scene)
    ns.ReplayUnitsView.Use(scene)
    Soul.Use(scene)
    run.feedHas = ns.ReplayFeed.Use(scene.layers)
    ns.ReplayPosView.Use(scene)
    Relayout()
    local n = #scene.tracks
    for k = #figs + 1, n + 1 do figs[k] = NewFigure(ui.view) end
    for k = 1, #figs do HideFigure(figs[k]) end
    for k = 1, n do ConfigFigure(figs[k], scene.tracks[k], scene) end
    ConfigFigure(figs[n + 1], nil, scene)
    run.figCount = n + 1
    for k = 1, n + 1 do order[k] = k end
    for k = n + 2, #order do order[k] = nil end
    UseFloor(scene.room)
    ResetCamera(false)
    Bar.Use(scene)
    UpdatePlay()
    ApplySeek()
    SetFocus(run.want)
    local want = WantScene()
    if want and want ~= run.scene then SwapScene(want) end
    run.snapScene = false
    UpdateSceneBtn()
    Tour.Auto()
end
local shared = { ui = ui, run = run, cam = cam, dim = dim, figs = figs, Iso = Iso, Tick = Tick, SetFocus = SetFocus,
                 SetHeal = SetHeal, UpdateSceneBtn = UpdateSceneBtn, PlaceFloor = PlaceFloor }
IsoCam.Bind(shared)
IsoFigs.Bind(shared)
IsoBuild.Bind(shared)
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
    run.scene, run.base, run.pin, run.fadeA = nil, nil, nil, 0
    ui.fade:Hide()
    UpdateSceneBtn()
    run.loading = true
    for k = 1, #figs do HideFigure(figs[k]) end
    for k = 1, #afigs do HideFigure(afigs[k]) end
    run.orderN = nil
    for k = 1, #strips do strips[k]:Hide() end
    run.stripUsed = 0
    for k = 1, #dots do dots[k]:Hide() end
    Geo.Use(nil)
    LayersView.Use(nil)
    Realm.Use(nil)
    ns.ReplaySwarmView.Use(nil)
    ns.ReplayOozeView.Use(nil)
    ns.ReplayClassView.Use(nil)
    ns.ReplayUnitsView.Use(nil)
    ns.ReplaySpreadView.Use(nil)
    ns.ReplayCueView.Use(nil)
    ns.ReplayArrowsView.Use(nil)
    Soul.Use(nil)
    ns.ReplayFeed.Use(nil)
    Bar.Use(nil)
    ui.title:SetText(format(ns.T("iso.title"), ns.FightList and ns.FightList.Title(fight) or ns.EncName(fight.boss)))
    ui.hint:SetText(ns.T("iso.loading"))
    ui.hint:Show()
    ui.gap:Hide()
    ns.ReplayPosView.Use(nil)
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
function Iso.Wake()
    run.stillFor, run.stillAcc = 0, 0
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
    return run.base
end
function Iso.Shown()
    return run.scene
end
function Iso.Now()
    return run.t, run.playing
end
function Iso.Toggle()
    if ui.frame and ui.frame:IsShown() then Iso.Hide() else Iso.Show() end
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
             bar = Bar.Probe(), menu = ViewMenu.Probe(), pos = ns.ReplayPosView.Probe(), narrow = run.narrow, zoom = cam.zoom,
             tilt = run.tilt3, flat = run.flat, speed = run.speed, heal = run.focusHeal,
             scene = run.scene and (run.scene == run.base and "base" or "alt") or nil, pin = run.pin, fade = run.fadeA,
             camR = cam.r, camCx = cam.cx, camCy = cam.cy, gap = run.gapKind or nil }
end
if ns.MapView and ns.MapView.SetFight then
    hooksecurefunc(ns.MapView, "SetFight", function(f) picked = f end)
end
