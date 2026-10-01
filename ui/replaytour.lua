local _, ns = ...
local max = math.max
local min = math.min
local sin = math.sin
local pi = math.pi
local format = string.format
local STEPS = {
    { key = "zoom", target = "view" },
    { key = "turn", target = "view" },
    { key = "tilt", target = "view" },
    { key = "seek", target = "scrub" },
    { key = "pick", target = "fig" },
    { key = "menu", target = "gear" },
}
local TURN_MIN = 0.35
local TILT_MIN = 0.08
local DONE_HOLD = 0.9
local RETARGET = 0.5
local W = 380
local PAD = 10
local LINE_H = 14
local BTN_W = 100
local BTN_H = 20
local GAP = 8
local LIFT = 34
local EDGE = 2
local GLOW_OUT = 4
local GLOW_IN = -3
local PULSE_HZ = 1.5
local GLOW_LOW = 0.35
local LEVEL = 8
local Tour = {}
ns.ReplayTour = Tour
local Kit = ns.Kit
local st = { step = 0, up = false, down = false, retarget = 0, phase = 0 }
local box, text, count, ok, skip, nextBtn, glow
local function Glow(f, inner)
    st.target = f
    if not f then
        glow:Hide()
        return
    end
    local d = inner and GLOW_IN or GLOW_OUT
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", f, "TOPLEFT", -d, d)
    glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", d, -d)
    glow:Show()
end
local function Retarget()
    local def = STEPS[st.step]
    local ui = st.ui
    if def.target == "view" then
        Glow(ui.view, true)
    elseif def.target == "scrub" then
        Glow(ui.scrub, false)
    elseif def.target == "gear" then
        Glow(ui.gearBtn, false)
    else
        Glow(st.api.Figure(), false)
    end
    st.retarget = 0
end
local function ShowStep()
    local n = #STEPS
    st.doneT, st.up, st.down = nil, false, false
    count:SetText(format(ns.T("iso.tour.count"), st.step, n))
    text:SetText(ns.T("iso.tour." .. st.step))
    ok:Hide()
    nextBtn.text:SetText(ns.T(st.step >= n and "iso.tour.finish" or "iso.tour.next"))
    box:SetHeight(PAD + LINE_H + GAP / 2 + max(LINE_H, text:GetStringHeight() or LINE_H) + GAP + BTN_H + PAD)
    box:Show()
    Retarget()
end
local function Close(save)
    if save and st.api then st.api.Saved().tour = true end
    st.step, st.doneT, st.target = 0, nil, nil
    if box then box:Hide() end
    if glow then glow:Hide() end
end
local function Next()
    if st.step == 0 then return end
    if st.step >= #STEPS then
        Close(true)
        return
    end
    st.step = st.step + 1
    ShowStep()
end
local function Tick(self, elapsed)
    if st.step == 0 then return end
    st.phase = (st.phase + max(0, elapsed) * PULSE_HZ) % 1
    glow:SetAlpha(GLOW_LOW + (1 - GLOW_LOW) * (sin(st.phase * 2 * pi) + 1) / 2)
    if st.doneT then
        st.doneT = st.doneT + max(0, elapsed)
        if st.doneT >= DONE_HOLD then Next() end
        return
    end
    st.retarget = st.retarget + max(0, elapsed)
    if STEPS[st.step].target == "fig" and st.retarget >= RETARGET then
        if not (st.target and st.target:IsShown()) then Retarget() else st.retarget = 0 end
    end
end
local function Btn(parent, key)
    local b = Kit.Button(parent)
    b:SetWidth(BTN_W)
    b:SetHeight(BTN_H)
    b.text:SetText(ns.T(key))
    return b
end
local function BuildGlow(ui)
    glow = CreateFrame("Frame", nil, ui.top)
    glow:SetFrameLevel(min(127, ui.top:GetFrameLevel() + LEVEL - 1))
    local spec = {
        { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
    }
    for i = 1, #spec do
        local s = spec[i]
        local e = glow:CreateTexture(nil, "OVERLAY")
        e:SetPoint(s[1], glow, s[1], 0, 0)
        e:SetPoint(s[2], glow, s[2], 0, 0)
        if s[3] then e:SetHeight(EDGE) else e:SetWidth(EDGE) end
        Kit.Paint(e, "sem.pick")
    end
    glow:Hide()
end
function Tour.Bind(ui, api)
    st.ui, st.api = ui, api
    box = CreateFrame("Frame", nil, ui.top)
    box:SetWidth(W)
    box:SetPoint("BOTTOM", ui.view, "BOTTOM", 0, LIFT)
    box:SetFrameLevel(min(127, ui.top:GetFrameLevel() + LEVEL))
    box:EnableMouse(true)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    Kit.Paint(bg, "surface.shade")
    local line = box:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    line:SetHeight(EDGE)
    Kit.Paint(line, "sem.pick")
    count = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -PAD)
    Kit.Text(count, "text.title")
    ok = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ok:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -PAD)
    ok:SetText(ns.T("iso.tour.ok"))
    Kit.Text(ok, "text.good")
    ok:Hide()
    text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -(PAD + LINE_H + GAP / 2))
    text:SetWidth(W - PAD * 2)
    text:SetJustifyH("LEFT")
    Kit.Text(text, "text.primary")
    skip = Btn(box, "iso.tour.skip")
    skip:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", PAD, PAD)
    skip.onClick = function() Close(true) end
    nextBtn = Btn(box, "iso.tour.next")
    nextBtn:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -PAD, PAD)
    nextBtn.onClick = Next
    box:SetScript("OnUpdate", Tick)
    box:Hide()
    BuildGlow(ui)
end
function Tour.Start()
    if not box then return end
    st.step = 1
    ShowStep()
end
function Tour.Auto()
    if st.step == 0 and st.api and st.api.Saved().tour ~= true then Tour.Start() end
end
function Tour.Stop()
    Close(false)
end
function Tour.Note(kind, v)
    if st.step == 0 or st.doneT or STEPS[st.step].key ~= kind then return end
    if kind == "zoom" then
        if (v or 0) > 0 then st.up = true else st.down = true end
        if not (st.up and st.down) then return end
    elseif kind == "turn" and (v or 0) < TURN_MIN then
        return
    elseif kind == "tilt" and (v or 0) < TILT_MIN then
        return
    end
    st.doneT = 0
    ok:Show()
end
function Tour.Probe()
    return { step = st.step, steps = #STEPS, shown = box ~= nil and box:IsShown(), done = st.doneT ~= nil,
             key = STEPS[st.step] and STEPS[st.step].key, target = st.target,
             glow = glow ~= nil and glow:IsShown(), skip = skip, next = nextBtn, box = box, w = W }
end
