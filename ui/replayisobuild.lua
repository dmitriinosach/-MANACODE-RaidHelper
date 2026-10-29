local ADDON, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local pi = math.pi
local PAD = 12
local FEED_W = 220
local HEAD = 30
local BAR_GAP = 8
local BARS_GAP = 4
local FOOT = 22
local STATUS_GRIP = 24
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
}
local TURN_STEP = pi / 12
local TILT_STEP = ns.ReplayIsoCam.TILT_STEP
local NAV_TOP = 8
local NAV_RIGHT = 8
local NAV_BTN = 28
local NAV_ICON = 18
local NAV_GAP = 2
local NAV_SEP = 4
local NAV_W = NAV_BTN + NAV_RIGHT * 2
local NAV = {
    { "left", "iso.tip.left", sep = true }, { "right", "iso.tip.right" },
    { "tiltmore", "iso.tip.tiltmore", sep = true }, { "tiltless", "iso.tip.tiltless" },
    { "mode", "iso.tip.to2d", sep = true },
    { "reset", "iso.tip.reset", sep = true },
    { "scene", "iso.tip.scene.auto", sep = true },
    { "help", "iso.tip.help", sep = true },
}
local SCENE = { fade = 0.15 }
local NEEDLE = 22
local NORTH_TAG = 8
local LEGEND_W = 330
local FIG_LEVEL = 12
local HOVER_PAD = 6
local HOVER_H = 18
local FOCUS_GAP = 4
local NAV_BTN_W = 20
local IsoBuild = { SCENE = SCENE, NAV_W = NAV_W, NAV_BTN = NAV_BTN, ICONS = ICONS }
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
local Turn, SetView, SetFlat = IsoCam.Turn, IsoCam.SetView, IsoCam.SetFlat
local ResetCamera, Reframe, Saved = IsoCam.ResetCamera, IsoCam.Reframe, IsoCam.Saved
local LoadCamera, UpdateCamUi = IsoCam.LoadCamera, IsoCam.UpdateCamUi
local dim = { viewW = Size.MIN_W, viewH = Size.MIN_H, k = 1 }
dim.sideH = dim.viewH + BAR_GAP + Bar.ROW_H
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
local StepFight
local m = { feedW = FEED_W, head = HEAD, foot = FOOT, k = 1, line = 18 }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true), Kit.FontScale("GameFontNormalSmall", true))
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    m.k = k
    m.feedW = ceil(FEED_W * k)
    m.head = max(HEAD, ceil(Kit.FontSize("GameFontNormal", true) * 1.15) + 12)
    m.foot = max(FOOT, ceil(pt * 1.15) + 8)
    m.line = max(18, ceil(pt * 1.2))
    Bar.Measure()
end
local Box = {}
function Box.SideX()
    return PAD + Size.Edge()
end
function Box.LeftX()
    return Box.SideX() + m.feedW + PAD
end
function Box.HeadH()
    return m.head + Size.Edge() + ns.ReplayNoPatchView.Height()
end
function Box.FootH()
    return m.foot + Size.Edge()
end
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Around()
    local side = Box.SideX()
    return (run.narrow and side * 2 or Box.LeftX() + side), Box.HeadH() + BAR_GAP + Bar.ROW_H + Box.FootH()
end
local function FrameWidth()
    ui.frame:SetWidth(Around() + dim.viewW)
end
local function PlaceNotice()
    local side = Box.SideX()
    ns.ReplayNoPatchView.Place(side, m.head + Size.Edge(), Around() + dim.viewW - side * 2)
end
local function PlaceBody()
    PlaceNotice()
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
    ns.ReplayFeed.Fit(m.feedW, bars and dim.sideH - dim.barsH - BARS_GAP or dim.sideH)
    Narrow(not (run.feedHas or bars))
end
local function LayoutNav()
    if not ui.nav then return end
    ui.navRects = {}
    local x = dim.viewW - NAV_RIGHT - NAV_BTN
    local y = NAV_TOP
    local function Place(b, name)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -NAV_RIGHT, -y)
        ui.navRects[#ui.navRects + 1] = { name = name, x = x, y = y, w = NAV_BTN, h = NAV_BTN, right = NAV_RIGHT }
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
                b.sep:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -NAV_RIGHT, -y)
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
    Size.Head(m.head)
    dim.viewW, dim.viewH = vw, vh
    dim.sideH = vh + BAR_GAP + Bar.ROW_H
    dim.barsH = floor(dim.sideH / 3)
    dim.h = Box.HeadH() + dim.sideH + Box.FootH()
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
    Bar.Resize(vw)
    Bar.Use(run.base)
    ui.status:SetWidth(vw - STATUS_GRIP)
    ui.frame:SetHeight(dim.h)
    FrameWidth()
    PlaceNotice()
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
local function BuildCompass(top)
    local b = NavButton(top, nil, "iso.tip.north")
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
    BuildCompass(top)
    local act = {
        left = function() Turn(-TURN_STEP) end,
        right = function() Turn(TURN_STEP) end,
        tiltmore = function() SetView(run.tilt3 - TILT_STEP) end,
        tiltless = function() SetView(run.tilt3 + TILT_STEP) end,
        mode = function() SetFlat(not run.flat) end,
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
    for i = 1, #NAV do
        local d = NAV[i]
        local name = d[1]
        local b = NavButton(top, name == "scene" and ICONS.throne or ICONS[name], d[2])
        if d.sep then
            b.sep = top:CreateTexture(nil, "ARTWORK")
            b.sep:SetWidth(NAV_BTN)
            b.sep:SetHeight(1)
            Kit.Paint(b.sep, "window.border", 0.35)
        end
        b.onClick = act[name]
        ui.nav[name] = b
    end
    Kit.Tint(ui.nav.reset.icon, "text.title")
    Kit.Tint(ui.nav.tiltmore.icon, "text.title")
    Kit.Tint(ui.nav.tiltless.icon, "text.title")
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
local function BuildHover(top)
    local box = CreateFrame("Frame", nil, top)
    box:SetWidth(60)
    box:SetHeight(HOVER_H)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    Kit.Paint(bg, "sem.rep.plate")
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", box, "CENTER", 0, 0)
    local path, size = text:GetFont()
    if path then text:SetFont(path, size or 10, "OUTLINE") end
    box:Hide()
    ui.hoverBox, ui.hoverText = box, text
end
function IsoBuild.HoverName(name)
    if not name then
        ui.hoverBox:Hide()
        return
    end
    ui.hoverText:SetText(name)
    ui.hoverBox:SetWidth(ceil((ui.hoverText:GetStringWidth() or 0) + HOVER_PAD * 2))
    ui.hoverBox:Show()
end
local function BuildView(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetWidth(m.feedW)
    side:SetHeight(dim.sideH)
    side:SetPoint("TOPLEFT", frame, "TOPLEFT", Box.SideX(), -Box.HeadH())
    local sideBg = side:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints(side)
    Kit.Paint(sideBg, "surface.page", 0.5)
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
    BuildHover(top)
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
    ui.bar:SetPoint("TOPLEFT", ui.view, "BOTTOMLEFT", 0, -BAR_GAP)
    ViewMenu.Build(ui, run, {
        SetHeal = SetHeal,
        Heal = function() return run.focusHeal end,
        SetGeo = function(on) Iso.SetGeo(on, true) end,
        Room = function() return run.scene and run.scene.room end,
    })
    Figs.Load()
end
local function BuildFightNav(frame)
    local prev = Kit.ToolButton(frame)
    prev:SetWidth(NAV_BTN_W)
    prev.text:SetText("<")
    prev.tipTitle = ns.T("fl.nav.prev")
    prev.onClick = function() StepFight(-1) end
    local nxt = Kit.ToolButton(frame)
    nxt:SetWidth(NAV_BTN_W)
    nxt.text:SetText(">")
    nxt.tipTitle = ns.T("fl.nav.next")
    nxt.onClick = function() StepFight(1) end
    ui.prevBtn, ui.nextBtn = prev, nxt
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
    ui.title = Kit.Str(frame, "GameFontNormal")
    ui.title:SetJustifyH("LEFT")
    ui.title:SetWordWrap(false)
    Kit.Title(ui.title)
    local close = Kit.CloseButton(frame, function() Iso.Hide() end)
    ui.nav = {}
    BuildView(frame)
    BuildFightNav(frame)
    ns.ReplayNoPatchView.Build(frame, Refit)
    PlaceNotice()
    LoadCamera()
    BuildBottom()
    Follow.Bind(ui, run, cam, figs, SetFocus)
    ui.status = Kit.Str(frame, "GameFontHighlightSmall")
    Kit.Text(ui.status, "text.bright")
    ui.status:SetPoint("TOPLEFT", ui.bar, "BOTTOMLEFT", 0, -4)
    ui.status:SetWidth(dim.viewW - STATUS_GRIP)
    ui.status:SetJustifyH("LEFT")
    IsoFigs.BuildPools()
    UpdateCamUi()
    run.narrow = false
    Tour.Bind(ui, { Saved = Saved, Figure = NearFigure })
    Size.Bind(frame, close, m.head, Resize, Around, ui.title, { ui.prevBtn, ui.nextBtn })
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
Kit.OnFont(function()
    if not ui or not ui.frame then return end
    Resize(dim.viewW, dim.viewH)
    Size.Place()
    PlaceBody()
    Size.Refit()
    Kit.ApplyDecor(ui.frame)
end)
function IsoBuild.Bind(s)
    ui, run, cam, Iso, Tick = s.ui, s.run, s.cam, s.Iso, s.Tick
    SetFocus, SetHeal, UpdateSceneBtn, StepFight = s.SetFocus, s.SetHeal, s.UpdateSceneBtn, s.StepFight
end
IsoBuild.Around = Around
IsoBuild.Relayout = Relayout
IsoBuild.Refit = Refit
IsoBuild.Build = Build
