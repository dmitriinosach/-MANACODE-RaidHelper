local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local concat = table.concat
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROW_H = 30
local BTN = 24
local PLAY_ICON = 18
local SPEED_W = 30
local SPEED_GAP = 2
local CLOCK_W = 76
local GAP = 4
local GAP_WIDE = 8
local FLAG_LINE = 2
local FLAG_MIN_W = 28
local WAVE_MIN_W = 10
local FLAG_MAX_W = 110
local TRACK_H = 8
local HIT_H = 16
local THUMB_H = 18
local ICON = 16
local LANE_PAD = 4
local LANE_H = ICON + LANE_PAD
local LANES_TOP = 6
local LANE_BG = 0.35
local RIM = 1
local DEATH_W = 2
local DEATH_BIG = 4
local DEATH_WAVE = 2
local DEATH_MANY = 3
local MERGE_GAP = 2
local FLAG_PX = 6
local POOL = 64
local LABEL_POOL = 16
local MARK_PT = 9
local NAMES_MAX = 5
local SEEK_STEP = 2
local SPEEDS = { 0.5, 1, 2, 4, 8 }
local PLAY_TEX = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local PAUSE_TEX = "Interface\\TimeManager\\PauseButton"
local GEAR_ICON = 18
local T_FLAG, T_BOSS = 1, 2
local LANES = {
    { key = "boss", label = "rep.lane.boss" },
    { key = "tank", label = "rep.lane.tank" },
    { key = "heal", label = "rep.lane.heal" },
    { key = "dps", label = "rep.lane.dps" },
}
local LANE_OF = { tank = 2, heal = 3 }
local L_DPS = 4
local Bar = { ROW_H = ROW_H, SEEK_STEP = SEEK_STEP, SPEEDS = SPEEDS, ICON = ICON, FLAG_DX = FLAG_LINE + 1 }
ns.ReplayBar = Bar
local Kit = ns.Kit
local MK = ns.ReplayMarks
local st = { width = 0, scrubW = 0, tiers = { {}, {}, {}, {}, {} }, shown = {}, laneY = {}, rects = {}, deaths = 0,
             deathGroups = {}, deathAt = {}, scrubX = 0 }
local pools = { {}, {}, {}, {}, {} }
local ticks, dlabels, bands = {}, {}, {}
local markFont
local m = { btn = BTN, row = ROW_H, trackY = 0, speedW = SPEED_W, clockW = CLOCK_W, lane = LANE_H, icon = ICON, top = 0 }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontNormalSmall", true), Kit.FontScale("GameFontHighlightSmall", true))
    local pt = max(Kit.FontSize("GameFontNormalSmall", true), Kit.FontSize("GameFontHighlightSmall", true))
    m.btn = max(BTN, ceil(pt * 1.15) + 6)
    m.trackY = floor((m.btn - TRACK_H) / 2)
    m.lane = max(LANE_H, ceil(pt * 1.15) + LANE_PAD + 2)
    m.icon = m.lane - LANE_PAD
    m.top = m.btn + LANES_TOP
    m.row = max(ROW_H, m.btn + 6, m.top + #st.shown * m.lane)
    m.speedW = ceil(SPEED_W * k)
    m.clockW = ceil(CLOCK_W * k)
    Bar.ROW_H = m.row
end
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Clock(sec)
    local neg = sec < 0
    sec = neg and ceil(-sec) or floor(sec)
    return format("%s%d:%02d", neg and "-" or "", floor(sec / 60), sec % 60)
end
local function SpeedText(speed)
    if speed < 1 then return ns.T("iso.speed.half") end
    return format(ns.T("iso.speed"), speed)
end
local function MarkFont()
    if markFont then return markFont end
    markFont = CreateFont("HTP_FailWatchBarMark")
    markFont:SetFontObject(GameFontHighlightSmall)
    local path = GameFontHighlightSmall:GetFont()
    if path then markFont:SetFont(path, MARK_PT, "OUTLINE") end
    return markFont
end
local function SeekTo(t)
    local run = st.run
    local scene = run and run.scene
    if not scene then return end
    run.t = Clamp(t, scene.from, scene.to)
    run.marksDirty = true
end
function Bar.Measure()
    Metrics()
end
function Bar.Seek(delta)
    local run = st.run
    if not (run and run.scene) then return end
    SeekTo(run.t + delta)
end
local function SeekToCursor()
    local scrub = st.ui.scrub
    local x = GetCursorPosition() / scrub:GetEffectiveScale()
    local left = scrub:GetLeft()
    local w = st.scrubW
    if not left or w <= 0 then return end
    local scene = st.run.scene
    SeekTo(scene.from + Clamp((x - left) / w, 0, 1) * (scene.to - scene.from))
end
function Bar.UpdatePlay()
    local ui, run = st.ui, st.run
    if not ui then return end
    ui.playIcon:SetTexture(run.playing and PAUSE_TEX or PLAY_TEX)
    ui.playBtn.tipTitle = ns.T(run.playing and "iso.pause" or "iso.play")
    for i = 1, #ui.speedBtns do
        local b = ui.speedBtns[i]
        b:SetActive(b.speed == run.speed)
    end
end
function Bar.TogglePlay()
    local run = st.run
    local scene = run and run.scene
    if not scene then return end
    if not run.playing and run.t >= scene.to then run.t = scene.from end
    run.playing = not run.playing
    Bar.UpdatePlay()
end
function Bar.Step()
    if st.run.scrubbing then SeekToCursor() end
end
function Bar.UpdateScrub()
    local ui, run = st.ui, st.run
    local scene = run.scene
    local dur = max(0.001, scene.to - scene.from)
    local frac = Clamp((run.t - scene.from) / dur, 0, 1)
    local w = st.scrubW
    ui.fill:SetWidth(max(1, w * frac))
    ui.thumb:SetPoint("CENTER", ui.track, "LEFT", w * frac, 0)
    local d = run.t - scene.pull
    local sec = d >= 0 and floor(d) or -ceil(-d)
    if sec ~= run.lastClock then
        run.lastClock = sec
        ui.clock:SetText(format(ns.T("iso.clock"), Clock(sec), Clock(scene.to - scene.pull)))
    end
end
local function MarkName(m)
    if m.text then return m.text end
    if m.kind == "spell" and not m.label then
        local name = GetSpellInfo(m.id)
        return name or ("#" .. tostring(m.id))
    end
    local name = ns.T(m.label)
    if m.wave then return format(ns.T("rep.f.wave"), name, m.wave) end
    return name
end
local function Names(who)
    if #who == 0 then return nil end
    if #who <= NAMES_MAX then return concat(who, ", ") end
    local out = {}
    for i = 1, NAMES_MAX do out[i] = who[i] end
    return format(ns.T("rep.f.more"), concat(out, ", "), #who - NAMES_MAX)
end
local function Collect(rows, byName, name, m)
    local r = byName[name]
    if not r then
        r = { t = m.t, name = name, n = 0, who = {} }
        byName[name] = r
        rows[#rows + 1] = r
    end
    r.n = r.n + m.n
    for i = 1, #m.who do
        local seen = false
        for k = 1, #r.who do
            if r.who[k] == m.who[i] then seen = true end
        end
        if not seen then r.who[#r.who + 1] = m.who[i] end
    end
end
function Bar.TipOf(g, tier)
    local rows, byName = {}, {}
    for i = 1, #g.items do
        local m = g.items[i]
        Collect(rows, byName, MarkName(m), m)
    end
    local lines = {}
    for i = 1, #rows do
        local r = rows[i]
        local text = r.n > 1 and format(ns.T("rep.mk.many"), r.name, r.n) or r.name
        local who = Names(r.who)
        if who then text = format(ns.T("rep.mk.on"), text, who) end
        lines[i] = format(ns.T("rep.mk.line"), Clock(r.t), text)
    end
    return ns.T(tier == T_FLAG and "rep.k.phase" or LANES[tier - 1].label), concat(lines, "\n")
end
local function GroupClick(self)
    local run = st.run
    if not (self.group and run and run.scene) then return end
    SeekTo(run.scene.pull + self.group.t)
end
local function Badge(b)
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(MarkFont())
    fs:SetJustifyH("RIGHT")
    Kit.Text(fs, "text.bright")
    fs:Hide()
    return fs
end
local function GroupBtn(tier, i)
    local pool = pools[tier]
    local b = pool[i]
    if b then return b end
    local ui = st.ui
    b = CreateFrame("Button", nil, ui.bar)
    b.tier = tier
    b.tipAnchor = "ANCHOR_TOP"
    if tier == T_FLAG then
        b.line = ui.bar:CreateTexture(nil, "ARTWORK")
        b.line:SetWidth(FLAG_LINE)
        b.label = b:CreateFontString(nil, "OVERLAY")
        b.label:SetFontObject(MarkFont())
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)
        b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
        Kit.Text(b.label, "text.bright")
    else
        if tier ~= T_BOSS then
            b.rim = b:CreateTexture(nil, "BACKGROUND")
            b.rim:SetTexture(WHITE)
            b.rim:SetPoint("TOPLEFT", b, "TOPLEFT", -RIM, RIM)
            b.rim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", RIM, -RIM)
        end
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(b)
        b.badge = Badge(b)
        b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
    end
    b:SetScript("OnEnter", Kit.TipShow)
    b:SetScript("OnLeave", Kit.TipHide)
    b:SetScript("OnClick", GroupClick)
    pool[i] = b
    return b
end
local function SetBadge(b, n)
    if n >= 2 then
        b.badge:SetText(format(ns.T("rep.mk.times"), n))
        b.badge:Show()
    else
        b.badge:Hide()
    end
end
local function DrawFlag(b, g, avail)
    local x = st.scrubX + g.x
    local y = st.laneY[T_FLAG]
    local lead = g.lead
    b.line:ClearAllPoints()
    b.line:SetPoint("BOTTOM", st.ui.bar, "TOPLEFT", x, -(y + m.lane - 1))
    b.line:SetHeight(lead.wave and floor(m.lane / 2) or m.lane - 2)
    Kit.Paint(b.line, lead.kind == "pull" and "sem.pick" or "sem.phase", 0.9)
    b.line:Show()
    local w = max(FLAG_PX, min(avail, FLAG_MAX_W))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", st.ui.bar, "TOPLEFT", x + FLAG_LINE + 1, -y)
    b:SetWidth(w)
    b:SetHeight(m.lane)
    local text = lead.kind ~= "pull" and (lead.wave and tostring(lead.wave) or MarkName(lead)) or nil
    if text and #g.items > 1 then text = text .. " " .. format(ns.T("rep.mk.times"), #g.items) end
    if text and avail >= (lead.wave and WAVE_MIN_W or FLAG_MIN_W) then
        b.label:SetWidth(w - 2)
        b.label:SetHeight(m.lane)
        b.label:SetText(text)
        b.label:Show()
    else
        b.label:Hide()
    end
end
local function DrawIcon(b, g, tier)
    local lead = g.lead
    Kit.Icon.Spell(b.icon, lead.id)
    local x = st.scrubX + g.x
    local y = st.laneY[tier] + (m.lane - m.icon) / 2
    b:SetWidth(m.icon)
    b:SetHeight(m.icon)
    b:ClearAllPoints()
    b:SetPoint("TOP", st.ui.bar, "TOPLEFT", x, -y)
    if b.rim then
        local r, gg, bb = Kit.ClassColor(lead.class)
        b.rim:SetVertexColor(r, gg, bb, 0.9)
    end
    SetBadge(b, #g.items)
end
local function DrawGroup(tier, i, g, avail)
    local b = GroupBtn(tier, i)
    if tier == T_FLAG then DrawFlag(b, g, avail) else DrawIcon(b, g, tier) end
    b.group = g
    b.tipTitle, b.tip = Bar.TipOf(g, tier)
    b:Show()
    return b
end
local function HideRest(tier, n)
    local pool = pools[tier]
    for i = n + 1, #pool do
        local b = pool[i]
        b:Hide()
        if b.line then b.line:Hide() end
        b.group = nil
    end
end
local function LaneOf(name)
    local roles = st.run and st.run.roles
    return name and roles and LANE_OF[roles[name] or ""] or L_DPS
end
local function EventMarks(L, lists)
    if not (L and L.fdEv) then return end
    for i = 1, L.nf do
        if L.fdImp[i] and L.fdEv[i] then
            local who = L.fdLane and L.fdLane[i] or L.fdWho[i]
            local id = tonumber(L.fdIcon[i])
            local list = lists[LaneOf(who)]
            list[#list + 1] = { t = L.fdT[i], kind = "event", id = id and id > 0 and id or nil, text = L.fdText[i], n = 1,
                                who = {}, class = who and ns.Encounters.ClassOf(who) or nil }
        end
    end
end
local function Cluster(scene, marks, px)
    return MK.Cluster(marks, scene.from - scene.pull, scene.to - scene.pull, st.scrubW, px)
end
local function DeathLabel(i)
    local fs = dlabels[i]
    if fs then return fs end
    fs = st.ui.bar:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(MarkFont())
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, "sem.death")
    dlabels[i] = fs
    return fs
end
local function DrawDeaths(scene, lane, list, acc)
    local ui = st.ui
    local dur = max(0.001, scene.to - scene.from)
    local top = st.laneY[lane + 1]
    local y = top + 1
    local key = LANES[lane].key
    local i = 1
    while i <= #list and acc.used < POOL do
        local j = i
        while j < #list and list[j + 1].t - list[i].t <= DEATH_WAVE do j = j + 1 end
        local n = j - i + 1
        local many = n >= DEATH_MANY
        local last = many and i or j
        for k = i, last do
            if acc.used >= POOL then break end
            acc.used = acc.used + 1
            local tick = ticks[acc.used]
            local x = st.scrubW * Clamp((list[k].t - scene.from) / dur, 0, 1)
            tick:ClearAllPoints()
            tick:SetPoint("TOP", ui.bar, "TOPLEFT", st.scrubX + x, -y)
            tick:SetWidth(many and DEATH_BIG or DEATH_W)
            tick:SetHeight(m.lane - 2)
            local names = {}
            if many then
                Kit.Paint(tick, "sem.death")
                if acc.labels < LABEL_POOL then
                    acc.labels = acc.labels + 1
                    local fs = DeathLabel(acc.labels)
                    fs:SetText(format(ns.T("rep.mk.times"), n))
                    fs:ClearAllPoints()
                    fs:SetPoint("LEFT", ui.bar, "TOPLEFT", st.scrubX + x + DEATH_BIG, -(top + m.lane / 2))
                    fs:Show()
                end
                for d = i, j do names[#names + 1] = list[d].name end
                st.deathGroups[#st.deathGroups + 1] = { t = list[i].t - scene.pull, n = n, x = x, lane = key }
            else
                local r, g, b = Kit.ClassColor(ns.Encounters.ClassOf(list[k].name))
                tick:SetTexture(WHITE)
                tick:SetVertexColor(r, g, b, 1)
                names[1] = list[k].name
            end
            st.deathAt[#st.deathAt + 1] = { t = list[k].t - scene.pull, lane = key, names = names }
            tick:Show()
        end
        i = j + 1
    end
end
local function DrawLane(tier)
    local ui = st.ui
    local fs, band = ui.laneLabels[tier], bands[tier]
    local y = st.laneY[tier]
    if not y then
        fs:Hide()
        band:Hide()
        return
    end
    local right = st.scrubX - GAP - ceil(m.icon / 2)
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", ui.bar, "TOPLEFT", right, -(y + m.lane / 2))
    fs:SetWidth(max(1, right))
    fs:Show()
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", ui.bar, "TOPLEFT", st.scrubX, -y)
    band:SetWidth(st.scrubW)
    band:SetHeight(m.lane - 1)
    band:Show()
end
local function Split(scene)
    local tiers, deaths = { {}, {}, {}, {}, {} }, { {}, {}, {}, {} }
    if not scene then return tiers, deaths end
    local L = scene.layers
    local marks = L and L.marks or {}
    local phases, lists = {}, { {}, {}, {}, {} }
    for i = 1, #marks do
        local mk = marks[i]
        if mk.kind == "spell" then lists[1][#lists[1] + 1] = mk else phases[#phases + 1] = mk end
    end
    EventMarks(L, lists)
    tiers[T_FLAG] = Cluster(scene, phases, FLAG_PX)
    for lane = 1, #LANES do tiers[lane + 1] = Cluster(scene, lists[lane], m.icon + MERGE_GAP) end
    local list = scene.deaths
    for i = 1, #list do
        local d = deaths[LaneOf(list[i].name)]
        d[#d + 1] = list[i]
    end
    return tiers, deaths
end
function Bar.Use(scene)
    local ui = st.ui
    if not ui then return false end
    local row = m.row
    Metrics()
    local tiers, deaths = Split(scene)
    if scene then
        local shown = {}
        if #tiers[T_FLAG] > 0 then shown[1] = T_FLAG end
        for lane = 1, #LANES do
            if #tiers[lane + 1] > 0 or #deaths[lane] > 0 then shown[#shown + 1] = lane + 1 end
        end
        st.shown = shown
        Metrics()
    end
    st.laneY = {}
    for v = 1, #st.shown do st.laneY[st.shown[v]] = m.top + (v - 1) * m.lane end
    st.tiers = tiers
    for tier = 1, #tiers do
        local groups = tiers[tier]
        local n = st.laneY[tier] and min(#groups, POOL) or 0
        for i = 1, n do
            local nextX = groups[i + 1] and groups[i + 1].x or st.scrubW
            DrawGroup(tier, i, groups[i], nextX - groups[i].x - FLAG_LINE - 2)
        end
        HideRest(tier, n)
        DrawLane(tier)
    end
    local acc = { used = 0, labels = 0 }
    st.deathGroups, st.deathAt = {}, {}
    for lane = 1, #LANES do
        if scene and st.laneY[lane + 1] then DrawDeaths(scene, lane, deaths[lane], acc) end
    end
    for k = acc.used + 1, #ticks do ticks[k]:Hide() end
    for k = acc.labels + 1, #dlabels do dlabels[k]:Hide() end
    st.deaths = acc.used
    if m.row == row then return false end
    ui.bar:SetHeight(m.row)
    return true
end
local function Rect(name, x, w)
    st.rects[#st.rects + 1] = { name = name, x = x, w = w }
end
local function At(f, x, y)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", st.ui.bar, "TOPLEFT", x, y)
end
local function BuildPlay(ui)
    local b = Kit.Button(ui.bar)
    b:SetWidth(BTN)
    b:SetHeight(BTN)
    ui.playIcon = b:CreateTexture(nil, "OVERLAY")
    ui.playIcon:SetWidth(PLAY_ICON)
    ui.playIcon:SetHeight(PLAY_ICON)
    ui.playIcon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.tipAnchor = "ANCHOR_TOP"
    b.onClick = Bar.TogglePlay
    ui.playBtn = b
end
local function BuildSpeed(ui)
    ui.speedBtns = {}
    for i = 1, #SPEEDS do
        local b = Kit.Button(ui.bar)
        b:SetWidth(SPEED_W)
        b:SetHeight(BTN)
        Kit.Bind(b.text, "GameFontNormalSmall")
        b.speed = SPEEDS[i]
        b.text:SetText(SpeedText(b.speed))
        b.tipTitle = ns.T("iso.speed.title")
        b.tipAnchor = "ANCHOR_TOP"
        b.onClick = function(self)
            st.run.speed = self.speed
            Bar.UpdatePlay()
        end
        ui.speedBtns[i] = b
    end
end
local function BuildScrub(ui)
    local track = ui.bar:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(TRACK_H)
    Kit.Paint(track, "surface.bg")
    ui.track = track
    ui.fill = ui.bar:CreateTexture(nil, "BORDER")
    ui.fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    ui.fill:SetHeight(TRACK_H)
    Kit.Paint(ui.fill, "sem.pick", 0.18)
    local scrub = CreateFrame("Button", nil, ui.bar)
    scrub:SetHeight(HIT_H)
    scrub:EnableMouseWheel(true)
    scrub:SetScript("OnMouseDown", function() st.run.scrubbing = true end)
    scrub:SetScript("OnMouseUp", function() st.run.scrubbing = false end)
    scrub:SetScript("OnMouseWheel", function(_, delta) Bar.Seek(delta * SEEK_STEP) end)
    ui.scrub = scrub
    ui.thumb = ui.bar:CreateTexture(nil, "OVERLAY")
    ui.thumb:SetWidth(2)
    ui.thumb:SetHeight(THUMB_H)
    Kit.Paint(ui.thumb, "sem.pick")
    for i = 1, POOL do
        local tick = ui.bar:CreateTexture(nil, "ARTWORK")
        Kit.Paint(tick, "sem.death")
        tick:SetWidth(DEATH_W)
        tick:SetHeight(LANE_H - 2)
        tick:Hide()
        ticks[i] = tick
    end
end
local function BuildGear(ui)
    local b = Kit.Button(ui.bar)
    b:SetWidth(BTN)
    b:SetHeight(BTN)
    local icon = b:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(Kit.GEAR_TEX)
    Kit.Tint(icon, "text.title")
    icon:SetWidth(GEAR_ICON)
    icon:SetHeight(GEAR_ICON)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.tipTitle = ns.T("iso.view")
    b.tip = ns.T("iso.view.tip")
    b.tipAnchor = "ANCHOR_TOP"
    ui.gearBtn = b
end
function Bar.Resize(width)
    local ui = st.ui
    Metrics()
    st.width = width
    st.rects = {}
    ui.bar:SetWidth(width)
    ui.bar:SetHeight(m.row)
    local btn, sw = m.btn, m.speedW
    local x = 0
    ui.playBtn:SetWidth(btn)
    ui.playBtn:SetHeight(btn)
    At(ui.playBtn, x, 0)
    Rect("play", x, btn)
    x = x + btn + GAP
    local speedW = #ui.speedBtns * sw + (#ui.speedBtns - 1) * SPEED_GAP
    for i = 1, #ui.speedBtns do
        local b = ui.speedBtns[i]
        b:SetWidth(sw)
        b:SetHeight(btn)
        At(b, x + (i - 1) * (sw + SPEED_GAP), 0)
    end
    Rect("speed", x, speedW)
    x = x + speedW + GAP_WIDE
    st.scrubX = x
    st.scrubW = max(1, width - x - GAP_WIDE - m.clockW - GAP - btn)
    At(ui.track, x, -m.trackY)
    ui.track:SetWidth(st.scrubW)
    At(ui.scrub, x, -(m.trackY + TRACK_H / 2 - HIT_H / 2))
    ui.scrub:SetWidth(st.scrubW)
    Rect("scrub", x, st.scrubW)
    x = x + st.scrubW + GAP_WIDE
    ui.clock:SetWidth(m.clockW)
    ui.clock:ClearAllPoints()
    ui.clock:SetPoint("LEFT", ui.bar, "TOPLEFT", x, -(m.btn / 2))
    Rect("clock", x, m.clockW)
    x = x + m.clockW + GAP
    ui.gearBtn:SetWidth(btn)
    ui.gearBtn:SetHeight(btn)
    At(ui.gearBtn, x, 0)
    Rect("gear", x, btn)
end
function Bar.Build(ui, run, width)
    st.ui, st.run = ui, run
    Metrics()
    local bar = CreateFrame("Frame", nil, ui.frame)
    bar:SetHeight(m.row)
    ui.bar = bar
    BuildPlay(ui)
    BuildSpeed(ui)
    BuildScrub(ui)
    ui.laneLabels = {}
    for tier = 1, #LANES + 1 do
        local fs = Kit.Str(bar, "GameFontNormalSmall")
        Kit.Text(fs, "text.muted")
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(false)
        fs:SetText(ns.T(tier == T_FLAG and "rep.lane.phase" or LANES[tier - 1].label))
        fs:Hide()
        ui.laneLabels[tier] = fs
        local band = bar:CreateTexture(nil, "BACKGROUND")
        Kit.Paint(band, "surface.bg", LANE_BG)
        band:Hide()
        bands[tier] = band
    end
    ui.clock = Kit.Str(bar, "GameFontHighlightSmall")
    Kit.Text(ui.clock, "text.bright")
    ui.clock:SetWidth(m.clockW)
    ui.clock:SetJustifyH("RIGHT")
    BuildGear(ui)
    Bar.Resize(width)
    Bar.UpdatePlay()
    return m.row
end
function Bar.Advance(elapsed)
    local run = st.run
    local scene = run and run.scene
    if not (scene and run.playing) then return end
    run.t = run.t + elapsed * run.speed
    run.marksDirty = true
    if run.t >= scene.to then
        run.t = scene.to
        run.playing = false
        Bar.UpdatePlay()
    end
end
function Bar.Now()
    local run = st.run
    local scene = run and run.scene
    if not scene then return nil, nil end
    local d = run.t - scene.pull
    return run.playing and true or false, d >= 0 and floor(d) or -ceil(-d)
end
function Bar.PlayLook(playing)
    return playing and PAUSE_TEX or PLAY_TEX, ns.T(playing and "iso.pause" or "iso.play")
end
function Bar.ClockText(sec)
    local scene = st.run and st.run.scene
    if not scene then return "" end
    return format(ns.T("iso.clock"), Clock(sec), Clock(scene.to - scene.pull))
end
function Bar.Title(fight, short)
    local name = ns.EncName(fight.boss)
    local outcome = format(ns.T(fight.killed and "iso.title.win" or "iso.title.wipe"), Clock((fight.to or fight.from) - fight.from))
    local spot = ns.FightTree and ns.FightTree.Spot(fight)
    if short then
        if spot then return format(ns.T("iso.strip"), name, spot.n, outcome) end
        return format(ns.T("iso.strip.nospot"), name, outcome)
    end
    local day = ns.Date(fight.from, "dayTime")
    if spot then return format(ns.T("iso.title"), name, spot.n, outcome, day) end
    return format(ns.T("iso.title.nospot"), name, outcome, day)
end
function Bar.Probe()
    local shown, groups = {}, {}
    for tier = 1, #pools do
        local pool = pools[tier]
        for i = 1, #pool do
            if pool[i]:IsShown() and pool[i].group then shown[#shown + 1] = pool[i] end
        end
        for i = 1, #st.tiers[tier] do groups[#groups + 1] = st.tiers[tier][i] end
    end
    local tierRects = { { name = "track", y = m.trackY, h = TRACK_H } }
    local lanes = {}
    for v = 1, #st.shown do
        local tier = st.shown[v]
        local key = tier == T_FLAG and "phase" or LANES[tier - 1].key
        local r = { name = key, key = key, tier = tier, y = st.laneY[tier], h = m.lane,
                    label = st.ui and st.ui.laneLabels[tier], groups = #st.tiers[tier] }
        tierRects[#tierRects + 1] = r
        if tier ~= T_FLAG then lanes[#lanes + 1] = r end
    end
    local boxes = {}
    for i = 1, #st.rects do
        local r = st.rects[i]
        if r.name ~= "scrub" then boxes[#boxes + 1] = { name = r.name, x = r.x, w = r.w, y = 0, h = m.btn } end
    end
    return { rects = st.rects, width = st.width, scrubX = st.scrubX, scrubW = st.scrubW, groups = groups, tiers = st.tiers,
             buttons = shown, deaths = st.deaths, deathGroups = st.deathGroups, deathAt = st.deathAt, icon = m.icon, rowH = m.row,
             tierRects = tierRects, lanes = lanes, boxes = boxes, laneH = m.lane, scrub = st.ui and st.ui.scrub, ui = st.ui,
             ticks = ticks, laneOf = function(name) return LANES[LaneOf(name)].key end }
end
