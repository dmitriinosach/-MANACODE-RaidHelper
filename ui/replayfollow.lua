local ADDON, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin
local exp = math.exp
local sqrt = math.sqrt
local pi = math.pi
local RIM = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\rim"
local CATCHER = "HTP_FailWatchReplayFocus"
local PULSE_HZ = 1.2
local PIN_PAD = 5
local PIN_SWING = 4
local PIN_ALPHA = 0.55
local RING_SWING = 3
local FOLLOW_RATE = 5
local FOLLOW_EPS = 0.02
local LABEL_GAP = 8
local ICON_LIFT = 27
local Follow = {}
ns.ReplayFollow = Follow
local Kit = ns.Kit
local Replay = ns.Replay
local st = { phase = 0, quiet = false }
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function Follow.On()
    return Saved().follow ~= false
end
function Follow.SetOn(on)
    Saved().follow = on and true or false
end
function Follow.Attach(fig)
    local pin = fig:CreateTexture(nil, "BORDER")
    pin:SetTexture(RIM)
    Kit.Tint(pin, "sem.rep.focus")
    pin:Hide()
    fig.pin = pin
end
local function Release(fig)
    fig.pin:Hide()
    ns.ReplayFigs.Rim(fig, false)
    fig.sQ = nil
end
local function Grab(fig)
    ns.ReplayFigs.Rim(fig, "sem.rep.focus")
    fig.pin:SetAlpha(PIN_ALPHA)
    fig.pin:Show()
end
local function CatcherHide()
    if st.quiet then return end
    local run = st.run
    if run and run.focus and st.ui.frame:IsShown() and st.clear then st.clear() end
end
local function WindowShow()
    local run = st.run
    if run and run.focus and st.catcher then st.catcher:Show() end
end
local function WindowHide()
    st.quiet = true
    if st.catcher then st.catcher:Hide() end
    st.quiet = false
end
function Follow.Threat()
    local run = st.run
    local f = run and run.fight
    if not (f and ns.ThreatView) then return end
    local t = run.scene and run.t or f.from
    if ns.ReplayIso then ns.ReplayIso.Hide() end
    ns.ThreatView.OpenAt(f, t)
end
function Follow.Bind(ui, run, cam, figs, clear)
    st.ui, st.run, st.cam, st.figs, st.clear = ui, run, cam, figs, clear
    local label = ui.top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Kit.Text(label, "sem.rep.focus")
    label:Hide()
    st.label = label
    local catcher = CreateFrame("Frame", CATCHER, UIParent)
    catcher:Hide()
    catcher:SetScript("OnHide", CatcherHide)
    if type(UIMenus) == "table" then tinsert(UIMenus, CATCHER) end
    st.catcher = catcher
    ui.frame:HookScript("OnShow", WindowShow)
    ui.frame:HookScript("OnHide", WindowHide)
end
function Follow.Apply()
    local run = st.run
    if not run then return end
    local scene = run.scene
    local fig, k
    if scene and run.focus then
        for i = 1, #scene.tracks do
            if scene.tracks[i].name == run.focus then k = i end
        end
        fig = k and st.figs[k]
    end
    if st.fig and st.fig ~= fig then Release(st.fig) end
    if fig and st.fig ~= fig then Grab(fig) end
    st.fig, st.k = fig, k
    if not fig then st.label:Hide() end
    if ns.ReplayFeed.SetFocus then ns.ReplayFeed.SetFocus(run.focus) end
    st.quiet = true
    if run.focus and st.ui.frame:IsShown() then st.catcher:Show() else st.catcher:Hide() end
    st.quiet = false
end
function Follow.Step(elapsed)
    local run, cam = st.run, st.cam
    if not (st.k and run.scene and Follow.On()) or run.drag == "RightButton" then return end
    local s = run.scene.states[st.k]
    if not (s and s.vis) then return end
    local ux, uy, k = Replay.Unproject(cam, 0, 0)
    if k <= 0 then ux, uy = cam.cx, cam.cy end
    local dx, dy = s.x - ux, s.y - uy
    if dx * dx + dy * dy < FOLLOW_EPS * FOLLOW_EPS then return end
    local a = 1 - exp(-FOLLOW_RATE * max(0, elapsed))
    cam.cx, cam.cy = cam.cx + dx * a, cam.cy + dy * a
    run.camDirty = true
end
function Follow.Place(elapsed)
    local fig, run, ui = st.fig, st.run, st.ui
    if not fig then return end
    if not fig.shown then
        st.label:Hide()
        return
    end
    st.phase = (st.phase + max(0, elapsed) * PULSE_HZ) % 1
    local wave = (sin(st.phase * 2 * pi) + 1) / 2
    local d = PIN_PAD + PIN_SWING * wave
    local flat = min(1, st.cam.tilt * (fig.kz or 1))
    fig.pin:ClearAllPoints()
    fig.pin:SetPoint("TOPLEFT", fig, "TOPLEFT", -d, d * flat)
    fig.pin:SetPoint("BOTTOMRIGHT", fig, "BOTTOMRIGHT", d, -d * flat)
    fig.pin:SetAlpha(PIN_ALPHA + (1 - PIN_ALPHA) * wave)
    if fig.ringOn then ns.ReplayFigs.Pulse(fig, RING_SWING * wave) end
    st.label:SetText(fig.name)
    st.label:ClearAllPoints()
    st.label:SetPoint("BOTTOM", ui.view, "CENTER", fig.sx, -fig.sy + (fig.top or ICON_LIFT * fig.scale) + LABEL_GAP * fig.scale)
    st.label:Show()
    if run.hover == st.k then ui.hoverText:Hide() end
end
function Follow.Pick(fight, name)
    local run = st.run
    if not (run and name and st.ui.frame:IsShown()) then return false end
    if fight and run.fight ~= fight then return false end
    local f = run.fight
    if not (f and f.players and f.players[name]) then return false end
    if run.scene then
        ns.ReplayIso.Focus(name)
    else
        run.want = name
    end
    return true
end
function Follow.Probe()
    local run, cam = st.run, st.cam
    local out = { focus = run and run.focus, follow = Follow.On(), esc = st.catcher and st.catcher:IsShown() or false,
                  full = 0, dim = 0 }
    if not (run and run.scene) then return out end
    local n = #run.scene.tracks
    for i = 1, n do
        local a = run.focusA[i] or 1
        if a < 1 then out.dim = out.dim + 1 else out.full = out.full + 1 end
    end
    local s = st.k and run.scene.states[st.k]
    if s and s.vis then
        local sx, sy = Replay.Project(cam, s.x, s.y)
        out.dist = sqrt(sx * sx + sy * sy)
    end
    if st.fig then
        out.fx, out.fy, out.scale = floor(st.fig.sx + 0.5), floor(st.fig.sy + 0.5), st.fig.scale
        out.label = st.label:IsShown() and st.fig.name or nil
    end
    return out
end
