local ADDON, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local pi = math.pi
local PAD = 8
local GAP = 8
local FEED_W = 220
local STATUS_W = 360
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local ICONS = {
    left = "Interface\\Buttons\\UI-RotationLeft-Button-Up",
    right = "Interface\\Buttons\\UI-RotationRight-Button-Up",
    tiltmore = ART .. "tiltdown",
    tiltless = ART .. "tiltup",
    help = "Interface\\TutorialFrame\\TutorialFrame-QuestionMark",
    reset = ART .. "camreset",
    needle = "Interface\\Minimap\\MinimapArrow",
    north = "Interface\\Minimap\\CompassNorthTag",
    throne = "Interface\\Icons\\Achievement_Boss_LichKing",
    soul = "Interface\\Icons\\INV_Sword_122",
    view = ns.Kit.GEAR_TEX,
}
local TURN_STEP = pi / 12
local TILT_STEP = ns.ReplayIsoCam.TILT_STEP
local NAV_TOP = 8
local NAV_RIGHT = 8
local NAV_BTN = 28
local NAV_ICON = 18
local NAV_GAP = 0
local NAV_SEP = 3
local NAV_PARTPAD = 3
local NAV_W = NAV_BTN + NAV_RIGHT * 2
local NAV = {
    { "left", "iso.tip.left", sep = true }, { "right", "iso.tip.right" },
    { "tiltmore", "iso.tip.tiltmore", sep = true }, { "tiltless", "iso.tip.tiltless" },
    { "mode", "iso.tip.to2d", sep = true, act = "iso.tip.to2d.act" },
    { "reset", "iso.tip.reset", sep = true },
    { "scene", "iso.tip.scene.auto", sep = true, act = "iso.tip.scene.auto.act" },
    { "view", "iso.view.tip", sep = true },
    { "help", "iso.tip.help", sep = true },
}
local SCENE = { fade = 0.15 }
local NEEDLE = 22
local NORTH_TAG = 8
local LEGEND_W = 330
local FIG_LEVEL = 12
local FOCUS_GAP = 4
local IsoBuild = { SCENE = SCENE, NAV_W = NAV_W, NAV_BTN = NAV_BTN, ICONS = ICONS }
ns.ReplayIsoBuild = IsoBuild
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Size = ns.ReplaySize
local Tour = ns.ReplayTour
local Bar = ns.ReplayBar
local ViewMenu = ns.ReplayViewMenu
local Follow = ns.ReplayFollow
local Figs = ns.ReplayFigs
local Geo = ns.ReplayGeo
local IsoCam = ns.ReplayIsoCam
local IsoFigs = ns.ReplayIsoFigs
local figs = IsoFigs.figs
local Turn, SetView, SetFlat = IsoCam.Turn, IsoCam.SetView, IsoCam.SetFlat
local ResetCamera, Reframe, Saved = IsoCam.ResetCamera, IsoCam.Reframe, IsoCam.Saved
local LoadCamera, UpdateCamUi = IsoCam.LoadCamera, IsoCam.UpdateCamUi
local dim = { viewW = Size.MIN_W, viewH = Size.MIN_H, k = 1 }
dim.sideH = dim.viewH
dim.barsH = floor(dim.sideH / 3)
dim.h = PAD + dim.sideH + GAP + Bar.ROW_H + PAD
IsoBuild.dim = dim
local ui
local run
local cam
local Iso
local Tick
local SetFocus
local SetHeal
local UpdateSceneBtn
local StepFight
local m = { feedW = FEED_W, k = 1, line = 18 }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true), Kit.FontScale("GameFontNormalSmall", true))
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    m.k = k
    m.feedW = ceil(FEED_W * k)
    m.line = max(18, ceil(pt * 1.2))
    Bar.Measure()
end
local Box = {}
function Box.Rim()
    return Size.Rim()
end
function Box.SideX()
    return Box.Rim() + PAD
end
function Box.LeftX()
    return Box.SideX() + m.feedW + PAD
end
function Box.HeadH()
    local notice = ns.ReplayNoPatchView.Height()
    return Box.Rim() + Size.HeadH() + (notice > 0 and PAD + notice + PAD or 0)
end
function Box.FootH()
    return PAD + Box.Rim()
end
local Clamp = RD.Clamp
local function Around()
    local rim = Box.Rim()
    return (run.narrow and rim * 2 or Box.LeftX() + rim), Box.HeadH() + GAP + Bar.ROW_H + Box.FootH()
end
local function FrameWidth()
    ui.frame:SetWidth(Around() + dim.viewW)
    Size.Place()
end
local function PlaceNotice()
    local side = Box.SideX()
    ns.ReplayNoPatchView.Place(side, Box.Rim() + Size.HeadH() + PAD, Around() + dim.viewW - side * 2)
end
local function PlacePage()
    local rim = Box.Rim()
    ui.page:ClearAllPoints()
    ui.page:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", rim, -rim)
    ui.page:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -rim, rim)
    local y = Box.HeadH() + dim.viewH + floor(GAP / 2)
    ui.rule:ClearAllPoints()
    ui.rule:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", run.narrow and rim or Box.SideX(), -y)
    ui.rule:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -rim, -y)
end
local function PlaceBody()
    PlaceNotice()
    ui.side:ClearAllPoints()
    ui.side:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.SideX(), -(Box.HeadH() + PAD))
    ui.view:ClearAllPoints()
    if run.narrow then
        ui.side:Hide()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.Rim(), -Box.HeadH())
    else
        ui.side:Show()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.LeftX(), -Box.HeadH())
    end
    PlacePage()
end
local function PlaceBar()
    local col = not run.narrow and Box.LeftX() - Box.SideX() or nil
    ui.bar:ClearAllPoints()
    ui.bar:SetPoint("TOPLEFT", ui.view, "BOTTOMLEFT", col and -col or PAD, -GAP)
    Bar.Resize(dim.viewW + (col or -PAD), col)
end
local function FrameHeight()
    dim.h = Box.HeadH() + dim.viewH + GAP + Bar.ROW_H + Box.FootH()
    ui.frame:SetHeight(dim.h)
    PlacePage()
end
local function Narrow(narrow)
    if run.narrow == narrow then return end
    run.narrow = narrow
    PlaceBody()
    PlaceBar()
    Bar.Use(run.base)
    FrameHeight()
    FrameWidth()
    Size.Refit()
end
local function Relayout()
    local bars = ui.bars ~= nil and ui.bars:IsShown()
    ns.ReplayFeed.Fit(m.feedW, bars and dim.sideH - dim.barsH - GAP or dim.sideH)
    Narrow(not (run.feedHas or bars))
end
local function LayoutNav()
    if not ui.nav then return end
    ui.navRects = {}
    local th = Kit.Theme()
    local g = ui.navGroup
    Kit.Backdrop(g, { backdrop = th.window.backdrop, bg = th.tab.fill.color, border = th.window.border })
    local inner = max(0, th.tab.rim - NAV_PARTPAD)
    local x = dim.viewW - NAV_RIGHT - inner - NAV_BTN
    local y = inner
    local function Place(b, name)
        b:SetWidth(NAV_BTN)
        b:SetHeight(NAV_BTN)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", g, "TOPLEFT", inner, -y)
        ui.navRects[#ui.navRects + 1] = { name = name, x = x, y = NAV_TOP + y, w = NAV_BTN, h = NAV_BTN,
                                          right = NAV_RIGHT + inner }
        y = y + NAV_BTN
    end
    Place(ui.compass, "north")
    for i = 1, #NAV do
        local d = NAV[i]
        local b = ui.nav[d[1]]
        local shown = d[1] ~= "scene" or (run.base ~= nil and run.base.alt ~= nil)
        if shown then
            if d.sep then
                y = y + NAV_SEP
                b.sep:ClearAllPoints()
                b.sep:SetPoint("TOPLEFT", g, "TOPLEFT", inner, -y)
                b.sep:Show()
                y = y + 1 + NAV_SEP
            else
                y = y + NAV_GAP
            end
            Place(b, d[1])
        elseif b.sep then
            b.sep:Hide()
        end
    end
    g:SetWidth(NAV_BTN + inner * 2)
    g:SetHeight(y + inner)
    g:ClearAllPoints()
    g:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -NAV_RIGHT, -NAV_TOP)
    IsoBuild.NAV_W = NAV_BTN + inner * 2 + NAV_RIGHT * 2
end
IsoBuild.LayoutNav = LayoutNav
local function FitLegend()
    local f = ui.legend
    if not f then return end
    local w = ceil(LEGEND_W * m.k)
    f:SetWidth(w)
    ui.legendText:SetWidth(w - 20)
    f:SetHeight(max(120, ui.legendText:GetStringHeight() + 16))
end
local function Resize(vw, vh)
    Metrics()
    dim.viewW, dim.viewH = vw, vh
    dim.sideH = vh - PAD
    dim.barsH = floor(dim.sideH / 3)
    dim.k = min(vw / Size.MIN_W, vh / Size.MIN_H)
    cam.w, cam.h = vw, vh
    ui.view:SetWidth(vw)
    ui.view:SetHeight(vh)
    ui.side:SetWidth(m.feedW)
    ui.side:SetHeight(dim.sideH)
    ui.bars:SetWidth(m.feedW)
    ui.bars:SetHeight(dim.barsH)
    if ns.ReplayBarsView then ns.ReplayBarsView.Fit() end
    ui.hint:SetWidth(vw - 120)
    ui.gap:SetWidth(vw - 120)
    ui.focus:SetWidth(vw - 180)
    LayoutNav()
    FitLegend()
    if ns.ReplayRaidView then ns.ReplayRaidView.Layout() end
    PlaceBar()
    Bar.Use(run.base)
    ui.status:SetWidth(min(STATUS_W, vw - NAV_W * 2))
    FrameHeight()
    FrameWidth()
    PlaceNotice()
    Relayout()
    Reframe()
    run.marksDirty = true
end
local function NavButton(parent, icon, tip, act)
    local b = Kit.TabPart(parent, nil, icon, NAV_ICON)
    b:SetWidth(NAV_BTN)
    b:SetHeight(NAV_BTN)
    b.tip = ns.T(tip)
    b.tipClick = act and ns.T(act) or nil
    b.tipTitle = false
    b.tipAnchor = "ANCHOR_LEFT"
    return b
end
local function BuildCompass(top)
    local b = NavButton(ui.navGroup, nil, "iso.tip.north", "iso.tip.north.act")
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
    ui.nav.north = b
end
local function BuildLegend(top)
    local f = CreateFrame("Button", nil, top)
    f:SetWidth(LEGEND_W)
    f:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -(NAV_W + NAV_RIGHT), -NAV_TOP)
    f:SetFrameLevel(top:GetFrameLevel() + 6)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    Kit.Paint(bg, "surface.bg", 0.94)
    local text = Kit.Str(f, "GameFontHighlightSmall")
    Kit.Text(text, "text.bright")
    text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    text:SetWidth(LEGEND_W - 20)
    text:SetJustifyH("LEFT")
    text:SetText(ns.T("iso.legend"))
    f:SetHeight(max(120, text:GetStringHeight() + 16))
    ui.legendText = text
    f:SetScript("OnClick", function(self) self:Hide() end)
    f:Hide()
    ui.legend = f
end
local function BuildNav(top)
    ui.navRects = {}
    ui.navGroup = CreateFrame("Frame", nil, top)
    BuildCompass(top)
    local act = {
        left = function() Turn(-TURN_STEP) end,
        right = function() Turn(TURN_STEP) end,
        tiltmore = function() SetView(run.tilt3 - TILT_STEP) end,
        tiltless = function() SetView(run.tilt3 + TILT_STEP) end,
        mode = function() SetFlat(not run.flat) end,
        reset = function() IsoCam.DefaultView() end,
        help = function()
            if ui.legend:IsShown() then ui.legend:Hide() else ui.legend:Show() end
        end,
        scene = function()
            if not (run.base and run.base.alt) then return end
            if run.pin then
                run.pin = nil
            else
                run.pin = run.scene == run.base and "alt" or "base"
            end
            UpdateSceneBtn()
            Iso.Wake()
        end,
    }
    for i = 1, #NAV do
        local d = NAV[i]
        local name = d[1]
        local b = NavButton(ui.navGroup, name == "scene" and ICONS.throne or ICONS[name], d[2], d.act)
        if d.sep then
            b.sep = ui.navGroup:CreateTexture(nil, "ARTWORK")
            b.sep:SetWidth(NAV_BTN)
            b.sep:SetHeight(1)
            Kit.Paint(b.sep, "surface.edge")
        end
        b.onClick = act[name]
        ui.nav[name] = b
    end
    ui.nav.view.tipTitle = ns.T("iso.view")
    ui.gearBtn = ui.nav.view
    ui.nav.scene.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ui.modeBtn = ui.nav.mode
    Kit.Bind(ui.modeBtn.text, "GameFontNormalSmall")
    ui.nav.scene:Hide()
    LayoutNav()
    BuildLegend(top)
end
local function BuildBars(side)
    local bars = CreateFrame("Frame", nil, side)
    bars:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 0, 0)
    bars:SetWidth(m.feedW)
    bars:SetHeight(dim.barsH)
    bars:Hide()
    bars:SetScript("OnShow", Relayout)
    bars:SetScript("OnHide", Relayout)
    ui.bars = bars
end
local function BuildView(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetWidth(m.feedW)
    side:SetHeight(dim.sideH)
    side:SetPoint("TOPLEFT", frame, "TOPLEFT", Box.SideX(), -Box.HeadH())
    ui.side = side
    ns.ReplayFeed.Build(side, m.feedW, dim.sideH, function(sec, who)
        if not run.scene then return end
        run.t = Clamp(run.scene.pull + sec, run.scene.from, run.scene.to)
        run.marksDirty = true
        if who and run.scene.fight.players[who] then SetFocus(who) end
    end)
    BuildBars(side)
    local view = CreateFrame("Frame", nil, frame)
    view:SetWidth(dim.viewW)
    view:SetHeight(dim.viewH)
    view:SetPoint("TOPLEFT", frame, "TOPLEFT", Box.LeftX(), -Box.HeadH())
    local sky = CreateFrame("Frame", nil, frame)
    sky:SetAllPoints(view)
    sky:SetFrameLevel(view:GetFrameLevel())
    view:SetFrameLevel(view:GetFrameLevel() + 1)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseDown", IsoCam.ViewDown)
    view:SetScript("OnMouseUp", IsoCam.ViewUp)
    view:SetScript("OnMouseWheel", IsoCam.Wheel)
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(view)
    Kit.Paint(bg, "surface.page")
    ns.ReplaySky.Build(sky, bg)
    ui.view = view
    ui.marks = CreateFrame("Frame", nil, view)
    ui.marks:SetAllPoints(view)
    ui.marks:SetFrameLevel(view:GetFrameLevel() + (ns.ReplayLive and ns.ReplayLive.COL_MAX or 4) + 1)
    ui.focusLayer = CreateFrame("Frame", nil, view)
    ui.focusLayer:SetAllPoints(view)
    run.levelBase = view:GetFrameLevel() + FIG_LEVEL
    Geo.Build(view, min(117, run.levelBase + 2 * 42 + 2))
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(min(118, run.levelBase + 2 * 42 + 4))
    ui.top = top
    ui.fade = top:CreateTexture(nil, "BACKGROUND")
    ui.fade:SetAllPoints(view)
    Kit.Paint(ui.fade, "surface.solid")
    ui.fade:Hide()
    ui.hint = Kit.Str(top, "GameFontHighlightSmall")
    ui.hint:SetPoint("TOP", view, "TOP", 0, -8)
    ui.hint:SetWidth(dim.viewW - 120)
    Kit.Text(ui.hint, "text.secondary")
    ui.gap = Kit.Str(top, "GameFontHighlightSmall")
    ui.gap:SetPoint("BOTTOM", view, "BOTTOM", 0, 8)
    ui.gap:SetWidth(dim.viewW - 120)
    Kit.Text(ui.gap, "text.warn")
    ui.focus = Kit.Str(top, "GameFontHighlightSmall")
    ui.focus:SetPoint("TOPLEFT", view, "TOPLEFT", 8, -8)
    ui.focus:SetWidth(dim.viewW - 180)
    ui.focus:SetJustifyH("LEFT")
    Kit.Text(ui.focus, "text.title")
    ui.focus:Hide()
    ui.focusX = Kit.CloseButton(top, function() SetFocus(nil) end)
    ui.focusX.tipTitle = ns.T("iso.focus.clear")
    ui.focusX:Hide()
    BuildNav(top)
end
function IsoBuild.ShowFocus(name)
    if not name then
        ui.focus:Hide()
        ui.focusX:Hide()
        return
    end
    ui.focus:SetText(string.format(ns.T("iso.focus"), name))
    ui.focus:Show()
    ui.focusX:ClearAllPoints()
    ui.focusX:SetPoint("LEFT", ui.focus, "LEFT", ceil((ui.focus:GetStringWidth() or 0) + FOCUS_GAP), 0)
    ui.focusX:Show()
end
local function BuildBottom()
    Bar.Build(ui, run, dim.viewW)
    PlaceBar()
    ViewMenu.Build(ui, run, {
        SetHeal = SetHeal,
        Heal = function() return run.focusHeal end,
        SetGeo = function(on) Iso.SetGeo(on, true) end,
        Room = function() return run.scene and run.scene.room end,
    })
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
local function Refit()
    if not (ui and ui.frame) then return end
    PlaceBody()
    Resize(dim.viewW, dim.viewH)
    Size.Refit()
end
local function Build()
    Metrics()
    local frame = CreateFrame("Frame", "HTP_FailWatchReplayIso", UIParent)
    frame.sized = true
    frame:SetWidth(Box.LeftX() + dim.viewW + Box.SideX())
    frame:SetHeight(dim.h)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    Kit.Window(frame)
    local level = frame:GetFrameLevel()
    frame:SetFrameLevel(level + 1)
    if frame.kitBack then frame.kitBack:SetFrameLevel(level + 1) end
    local under = CreateFrame("Frame", nil, frame)
    under:SetFrameLevel(level)
    under:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    under:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    local fill = under:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    Kit.Paint(fill, "window.base", 1)
    frame:Hide()
    tinsert(UISpecialFrames, "HTP_FailWatchReplayIso")
    ui.frame = frame
    ui.page = frame:CreateTexture(nil, "BORDER")
    Kit.Paint(ui.page, "surface.page")
    ui.rule = frame:CreateTexture(nil, "ARTWORK")
    ui.rule:SetHeight(1)
    Kit.Paint(ui.rule, "surface.edge")
    ui.nav = {}
    BuildView(frame)
    ns.ReplayNoPatchView.Build(frame, Refit)
    PlaceNotice()
    LoadCamera()
    BuildBottom()
    Follow.Bind(ui, run, cam, figs, SetFocus)
    ui.status = Kit.Str(ui.top, "GameFontHighlightSmall")
    Kit.Text(ui.status, "text.bright")
    ui.status:SetPoint("BOTTOMLEFT", ui.view, "BOTTOMLEFT", GAP, GAP)
    ui.status:SetWidth(min(STATUS_W, dim.viewW - NAV_W * 2))
    ui.status:SetJustifyH("LEFT")
    IsoFigs.BuildPools()
    UpdateCamUi()
    run.narrow = false
    Tour.Bind(ui, { Saved = Saved, Figure = NearFigure })
    Size.Bind(frame, function() Iso.Hide() end, Resize, Around, function(step) StepFight(step) end)
    if ns.ReplayModeView then ns.ReplayModeView.Build(ui) end
    if ns.ReplayRaidView then ns.ReplayRaidView.Build(ui) end
    ui.title = Size.TitleText()
    ui.prevBtn, ui.nextBtn = Size.Nav()
    Size.Restore()
    frame:SetScript("OnUpdate", ns.Prof.Wrap("ui.iso", Tick))
    frame:SetScript("OnShow", function()
        if ns.CpuMeter then ns.CpuMeter.WinCheck() end
        Size.Refit()
        if not run.scene then return end
        Geo.Use(run.scene.room)
        run.camDirty = true
    end)
    frame:SetScript("OnHide", function()
        if ns.CpuMeter then ns.CpuMeter.WinCheck() end
        Geo.Release()
        ViewMenu.Hide()
        Tour.Stop()
        run.playing = false
        run.drag = nil
        run.scrubbing = false
    end)
end
local function Restyle()
    if not ui or not ui.frame then return end
    Resize(dim.viewW, dim.viewH)
    PlaceBody()
    Size.Refit()
    Kit.ApplyDecor(ui.frame)
    if run.fight then Size.SetTitle(Bar.Head(run.fight)) else Size.Place() end
end
Kit.OnTheme(Restyle)
Kit.OnFont(Restyle)
function IsoBuild.Bind(s)
    ui, run, cam, Iso, Tick = s.ui, s.run, s.cam, s.Iso, s.Tick
    SetFocus, SetHeal, UpdateSceneBtn, StepFight = s.SetFocus, s.SetHeal, s.UpdateSceneBtn, s.StepFight
end
function IsoBuild.Box()
    local aw = Around()
    return { pad = PAD, gap = GAP, rim = Box.Rim(), side = Box.SideX(), left = Box.LeftX(), head = Box.HeadH(),
             foot = Box.FootH(), aroundW = aw }
end
IsoBuild.Around = Around
IsoBuild.Relayout = Relayout
IsoBuild.Refit = Refit
IsoBuild.Narrow = Narrow
IsoBuild.Build = Build
