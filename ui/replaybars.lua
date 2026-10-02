local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROWS_MAX = 14
local BAR_H = 18
local PAD = 4
local GAP = 2
local ICON_GAP = 2
local TEXT_PAD = 4
local TIME_W = 34
local DEF_W = 220
local DEF_H = 150
local MIN_FILL = 0.5
local ALERT_FADE = 0.5
local ALERT_Y = 70
local ALERT_LINE = 26
local ALERT_SIZE = 20
local ALERT_W = 600
local ALERT_LEVEL = 120
local FONT = "Fonts\\FRIZQT__.TTF"
local SOUND = "igMainMenuOptionCheckBoxOn"
local SOUND_GAP = 2.5
local SEEK_MAX = 1
local DECIMAL = 10
local MINUTE = 60
local NAMES_SHOWN = 6
local View = {}
ns.ReplayBarsView = View
local RB = ns.ReplayBars
local Kit = ns.Kit
local st = { rows = {}, lines = {}, list = {}, alerts = {}, lineA = {}, rowH = 0, rowW = 0, barW = 0, sounds = 0,
             shown = 0, active = 0, cap = 1, w = 0, h = 0 }
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function View.Sound()
    return Saved().barSound ~= false
end
function View.SetSound(on)
    Saved().barSound = on and true or false
end
function View.Color(kind, k)
    local r0, g0, b0 = Kit.RGB("sem.rep.bar." .. kind)
    local r1, g1, b1 = Kit.RGB("sem.rep.bar." .. kind .. "End")
    k = max(0, min(1, k))
    return r0 + (r1 - r0) * k, g0 + (g1 - g0) * k, b0 + (b1 - b0) * k
end
function View.Clock(left)
    if left < DECIMAL then return format("%.1f", left) end
    if left < MINUTE then return format("%d", floor(left)) end
    local s = floor(left)
    return format("%d:%02d", floor(s / MINUTE), s % MINUTE)
end
local function PlaceRow(row, i)
    local h = st.rowH
    row:SetHeight(h)
    row:SetWidth(st.rowW)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", st.bars, "TOPLEFT", PAD, -(PAD + (i - 1) * (h + GAP)))
    row.icon:SetWidth(h)
    row.icon:SetHeight(h)
    row.bg:ClearAllPoints()
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", h + ICON_GAP, 0)
    row.bg:SetWidth(st.barW)
    row.bg:SetHeight(h)
    row.fill:SetHeight(h)
end
local function NewRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    Kit.Paint(row.bg, "sem.rep.bar.bg")
    row.fill = row:CreateTexture(nil, "BORDER")
    row.fill:SetTexture(BAR_TEX)
    row.fill:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 0, 0)
    PlaceRow(row, i)
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.time:SetPoint("RIGHT", row.bg, "RIGHT", -TEXT_PAD, 0)
    row.time:SetWidth(TIME_W)
    row.time:SetJustifyH("RIGHT")
    Kit.Text(row.time, "sem.rep.bar.text")
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.bg, "LEFT", TEXT_PAD, 0)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -TEXT_PAD, 0)
    row.name:SetJustifyH("LEFT")
    Kit.Text(row.name, "sem.rep.bar.text")
    row:Hide()
    return row
end
local function BuildAlert(view)
    local f = CreateFrame("Frame", nil, view)
    f:SetAllPoints(view)
    f:SetFrameLevel(max(view:GetFrameLevel() + 1, ALERT_LEVEL))
    for i = 1, RB.ALERT_MAX do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        fs:SetFont(STANDARD_TEXT_FONT or FONT, ALERT_SIZE, "THICKOUTLINE")
        fs:SetPoint("CENTER", f, "CENTER", 0, ALERT_Y - (i - 1) * ALERT_LINE)
        fs:SetWidth(ALERT_W)
        fs:SetJustifyH("CENTER")
        fs:Hide()
        st.lines[i] = fs
    end
    st.alert = f
end
function View.Build(bars, view)
    if st.bars then return end
    st.bars = bars
    View.Fit()
    for i = 1, ROWS_MAX do st.rows[i] = NewRow(bars, i) end
    bars:HookScript("OnSizeChanged", View.Fit)
    if view then BuildAlert(view) end
end
function View.Fit()
    local bars = st.bars
    if not bars then return end
    local h = bars:GetHeight()
    if not h or h <= 0 then
        local lay = ns.ReplayIso.Layout and ns.ReplayIso.Layout()
        h = lay and lay.barsH or DEF_H
    end
    local w = bars:GetWidth()
    if not w or w <= 0 then w = DEF_W end
    st.w, st.h = w, h
    st.rowH = BAR_H
    st.rowW = w - PAD * 2
    st.barW = max(1, st.rowW - BAR_H - ICON_GAP)
    st.cap = max(1, min(ROWS_MAX, floor((h - PAD * 2 + GAP) / (BAR_H + GAP))))
    for i = 1, #st.rows do
        PlaceRow(st.rows[i], i)
        if i > st.cap and st.rows[i].tr then
            st.rows[i].tr = nil
            st.rows[i]:Hide()
        end
    end
end
local function Use(B)
    st.data = B
    st.lastT = nil
    for i = 1, #st.rows do
        st.rows[i].tr = nil
        st.rows[i]:Hide()
    end
    for i = 1, #st.lines do
        st.lineA[i] = nil
        st.lines[i]:Hide()
    end
    if B and B.has then st.bars:Show() else st.bars:Hide() end
end
local function DrawRow(row, tr)
    if row.tr ~= tr then
        row.tr = tr
        local name, icon = RB.Spell(tr.def)
        row.clock = nil
        row.name:SetText(name)
        row.icon:SetTexture(icon or WHITE)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row:Show()
    end
    local k = tr.total > 0 and max(0, min(1, tr.left / tr.total)) or 0
    row.fill:SetWidth(max(MIN_FILL, st.barW * k))
    row.k = k
    local r, g, b = View.Color(tr.def.kind, 1 - k)
    row.fill:SetVertexColor(r, g, b)
    local clock = View.Clock(tr.left)
    if row.clock ~= clock then
        row.clock = clock
        row.time:SetText(clock)
    end
end
local function DrawBars(t)
    local n, active = RB.Bars(st.data, t, st.list, st.cap)
    st.shown, st.active = n, active
    for i = 1, #st.rows do
        local tr = st.list[i]
        local row = st.rows[i]
        if tr then
            DrawRow(row, tr)
        elseif row.tr then
            row.tr = nil
            row:Hide()
        end
    end
end
local function AlertText(a)
    local tr = st.data.tracks[a.k]
    local name = RB.Spell(tr.def)
    local who = a.who
    if not (tr.def.target and who and #who > 0) then return name end
    if #who == 1 then return format(ns.T("rep.bars.on"), name, who[1]) end
    local list = who
    if #who > NAMES_SHOWN then
        list = {}
        for i = 1, NAMES_SHOWN do list[i] = who[i] end
        list[#list + 1] = format(ns.T("rep.bars.more"), #who - NAMES_SHOWN)
    end
    return format(ns.T("rep.bars.list"), name, table.concat(list, ", "))
end
local function DrawAlerts(t, playing)
    if not st.alert then return end
    local n = RB.Alerts(st.data, t, st.alerts)
    for i = 1, #st.lines do
        local fs, a = st.lines[i], st.alerts[i]
        if a then
            if st.lineA[i] ~= a then
                st.lineA[i] = a
                fs:SetText(AlertText(a))
                fs:Show()
            end
            local r, g, b = View.Color(st.data.tracks[a.k].def.kind, 0)
            fs:SetTextColor(r, g, b, min(1, (RB.ALERT_FOR - (t - a.t)) / ALERT_FADE))
        elseif st.lineA[i] then
            st.lineA[i] = nil
            fs:Hide()
        end
    end
    local last = st.lastT
    if playing and n > 0 and last and t > last and t - last < SEEK_MAX and st.alerts[1].t > last and View.Sound() then
        local now = GetTime()
        if not st.soundAt or now - st.soundAt >= SOUND_GAP then
            st.soundAt = now
            st.sounds = st.sounds + 1
            PlaySound(SOUND)
        end
    end
end
function View.Step()
    if not st.bars then return end
    local Iso = ns.ReplayIso
    local scene = Iso.Scene()
    if scene ~= st.scene or (scene and scene.layers and scene.layers.bars) ~= st.data then
        st.scene = scene
        Use(scene and scene.layers and scene.layers.bars or nil)
    end
    if not st.data then return end
    local w, h = st.bars:GetWidth(), st.bars:GetHeight()
    if (w and w > 0 and w ~= st.w) or (h and h > 0 and h ~= st.h) then View.Fit() end
    local t, playing = Iso.Now()
    DrawBars(t)
    DrawAlerts(t, playing)
    st.lastT = t
end
local function Root(f)
    while f and f:GetParent() and f:GetParent() ~= UIParent do f = f:GetParent() end
    return f
end
function View.Attach()
    if st.bars then return end
    local Iso = ns.ReplayIso
    local bars = Iso.BarsFrame()
    if not bars then return end
    View.Build(bars, Iso.ViewFrame and Iso.ViewFrame() or nil)
    local root = Root(bars)
    if root then root:HookScript("OnUpdate", ns.Prof.Wrap("ui.iso", View.Step)) end
end
function View.Probe()
    return { rows = st.rows, lines = st.lines, shown = st.shown, active = st.active, sounds = st.sounds,
             data = st.data, rowH = st.rowH, barW = st.barW, list = st.list, cap = st.cap }
end
if ns.ReplayIso then
    hooksecurefunc(ns.ReplayIso, "Show", View.Attach)
    hooksecurefunc(ns.ReplayIso, "Open", View.Attach)
end
