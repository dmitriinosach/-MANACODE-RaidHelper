local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local PAD = 12
local FEED_W = 220
local HEAD = 30
local BAR_GAP = 8
local PLAYER_H = ns.ReplayBar.ROW_H
local BARS_GAP = 4
local FOOT = 22
local STATUS_GRIP = 24
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
local TURN_STEP = pi / 12
local TILT_STEP = ns.ReplayIsoCam.TILT_STEP
local NAV_TOP = 8
local NAV_RIGHT = 8
local NAV = {
    { "zoomin", "iso.tip.zoomin", 6 }, { "zoomout", "iso.tip.zoomout", 4 },
    { "left", "iso.tip.left", 10 }, { "right", "iso.tip.right", 4 },
    { "more", "iso.tip.tiltmore", 10 }, { "less", "iso.tip.tiltless", 4 },
    { "mode", "iso.tip.to2d", 10 },
    { "low", "iso.tip.low", 10 }, { "high", "iso.tip.high", 4 }, { "reset", "iso.tip.reset", 4 },
    { "help", "iso.tip.help", 10 },
    { "scene", "iso.tip.scene.auto", 10 },
}
local SCENE = { w = 46, fade = 0.15 }
local VIEW_LOW = 0.35
local VIEW_HIGH = 0.8
local NAV_BTN = 24
local NAV_ICON = 18
local COMPASS = 34
local NEEDLE = 26
local NORTH_TAG = 10
local LEGEND_W = 330
local FIG_LEVEL = 12
local IsoBuild = { SCENE = SCENE }
ns.ReplayIsoBuild = IsoBuild
local Kit = ns.Kit
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
local Turn, Zoom, SetView, SetFlat = IsoCam.Turn, IsoCam.Zoom, IsoCam.SetView, IsoCam.SetFlat
local ResetCamera, Reframe, Saved = IsoCam.ResetCamera, IsoCam.Reframe, IsoCam.Saved
local LoadCamera, UpdateCamUi = IsoCam.LoadCamera, IsoCam.UpdateCamUi
local dim = { viewW = Size.MIN_W, viewH = Size.MIN_H, k = 1 }
dim.sideH = dim.viewH + BAR_GAP + PLAYER_H
dim.barsH = floor(dim.sideH / 3)
dim.h = HEAD + dim.sideH + FOOT
IsoBuild.dim = dim
local ui
local run
local cam
local Iso
local Tick
local SetFocus
local SetHeal
local UpdateSceneBtn
local Box = {}
function Box.SideX()
    return PAD + Size.Edge()
end
function Box.LeftX()
    return Box.SideX() + FEED_W + PAD
end
function Box.HeadH()
    return HEAD + Size.Edge()
end
function Box.FootH()
    return FOOT + Size.Edge()
end
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Around()
    local side = Box.SideX()
    return (run.narrow and side * 2 or Box.LeftX() + side), Box.HeadH() + BAR_GAP + PLAYER_H + Box.FootH()
end
local function FrameWidth()
    ui.frame:SetWidth(Around() + dim.viewW)
end
local function PlaceBody()
    ui.side:ClearAllPoints()
    ui.side:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.SideX(), -Box.HeadH())
    ui.view:ClearAllPoints()
    if run.narrow then
        ui.side:Hide()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.SideX(), -Box.HeadH())
    else
        ui.side:Show()
        ui.view:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Box.LeftX(), -Box.HeadH())
    end
end
local function Narrow(narrow)
    if run.narrow == narrow then return end
    run.narrow = narrow
    PlaceBody()
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
    dim.h = Box.HeadH() + dim.sideH + Box.FootH()
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
    Bar.Use(run.base)
    ui.status:SetWidth(vw - STATUS_GRIP)
    ui.frame:SetHeight(dim.h)
    FrameWidth()
    Relayout()
    Reframe()
    run.marksDirty = true
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
    Kit.Text(text, "text.bright")
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
    local y = NAV_TOP + COMPASS
    for i = 1, #NAV do
        local d = NAV[i]
        local name = d[1]
        local b = NavButton(top, ICONS[name], d[2])
        local w = (name == "mode" and COMPASS) or (name == "scene" and SCENE.w) or NAV_BTN
        b:SetWidth(w)
        y = NavPlace(b, name, y + d[3], w, NAV_BTN)
        b.onClick = act[name]
        ui.nav[name] = b
    end
    ui.modeBtn = ui.nav.mode
    ui.nav.scene:Hide()
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
    side:SetPoint("TOPLEFT", frame, "TOPLEFT", Box.SideX(), -Box.HeadH())
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
    ui.marks:SetFrameLevel(view:GetFrameLevel() + 2)
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
local function Build()
    local frame = CreateFrame("Frame", "HTP_FailWatchReplayIso", UIParent)
    frame:SetWidth(Box.LeftX() + dim.viewW + Box.SideX())
    frame:SetHeight(dim.h)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
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
    ui.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.title:SetJustifyH("LEFT")
    ui.title:SetWordWrap(false)
    Kit.Title(ui.title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetScript("OnClick", function() Iso.Hide() end)
    ui.nav = {}
    BuildView(frame)
    LoadCamera()
    BuildBottom()
    Follow.Bind(ui, run, cam, figs, SetFocus)
    ui.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Kit.Text(ui.status, "text.bright")
    ui.status:SetPoint("TOPLEFT", ui.bar, "BOTTOMLEFT", 0, -4)
    ui.status:SetWidth(dim.viewW - STATUS_GRIP)
    ui.status:SetJustifyH("LEFT")
    IsoFigs.BuildPools()
    UpdateCamUi()
    run.narrow = false
    Tour.Bind(ui, { Saved = Saved, Figure = NearFigure })
    Size.Bind(frame, close, HEAD, Resize, Around, ui.title)
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
Kit.OnTheme(function()
    if not ui or not ui.frame then return end
    Size.Place()
    PlaceBody()
    Resize(dim.viewW, dim.viewH)
    Size.Refit()
    Kit.ApplyDecor(ui.frame)
end)
function IsoBuild.Bind(s)
    ui, run, cam, Iso, Tick = s.ui, s.run, s.cam, s.Iso, s.Tick
    SetFocus, SetHeal, UpdateSceneBtn = s.SetFocus, s.SetHeal, s.UpdateSceneBtn
end
IsoBuild.Around = Around
IsoBuild.Relayout = Relayout
IsoBuild.Build = Build
