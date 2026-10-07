local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local concat = table.concat
local ROW_H = 30
local BTN = 24
local PLAY_ICON = 18
local SPEED_W = 30
local SPEED_GAP = 2
local CLOCK_W = 76
local GAP = 4
local GAP_WIDE = 8
local TRACK_Y = 8
local TRACK_H = 8
local HIT_Y = 4
local HIT_H = 14
local THUMB_H = 18
local ICON = 12
local ICON_Y = 18
local DEATH_W = 2
local DEATH_Y = 3
local DEATH_H = 15
local MERGE_PX = ICON + 2
local GROUP_POOL = 64
local DEATH_POOL = 64
local NAMES_MAX = 5
local SEEK_STEP = 2
local SPEEDS = { 0.5, 1, 2, 4, 8 }
local PLAY_TEX = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local PAUSE_TEX = "Interface\\TimeManager\\PauseButton"
local GEAR_ICON = 18
local Bar = { ROW_H = ROW_H, SEEK_STEP = SEEK_STEP, SPEEDS = SPEEDS }
ns.ReplayBar = Bar
local Kit = ns.Kit
local MK = ns.ReplayMarks
local st = { width = 0, scrubW = 0, groups = {}, rects = {}, deaths = 0 }
local pool, ticks = {}, {}
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
local function SeekTo(t)
    local run = st.run
    local scene = run and run.scene
    if not scene then return end
    run.t = Clamp(t, scene.from, scene.to)
    run.marksDirty = true
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
function Bar.StepSpeed(dir)
    local run = st.run
    local at = 1
    for i = 1, #SPEEDS do
        if SPEEDS[i] == run.speed then at = i end
    end
    run.speed = SPEEDS[(at - 1 + dir) % #SPEEDS + 1]
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
    if m.kind == "spell" and not m.label then
        local name = GetSpellInfo(m.id)
        return name or ("#" .. tostring(m.id))
    end
    return ns.T(m.label)
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
function Bar.TipOf(g)
    local rows, byName = {}, {}
    for i = 1, #g.items do
        local m = g.items[i]
        if m.phase then Collect(rows, byName, ns.T(m.phase), { t = m.t, n = 1, who = {} }) end
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
    local body = #lines > 1 and concat(lines, "\n", 2) or nil
    return lines[1], body
end
local function GroupClick(self)
    local run = st.run
    if not (self.group and run and run.scene) then return end
    SeekTo(run.scene.pull + self.group.t)
end
local function GroupBtn(i)
    local b = pool[i]
    if b then return b end
    local ui = st.ui
    b = CreateFrame("Button", nil, ui.bar)
    b:SetWidth(ICON)
    b:SetHeight(ICON)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.line = ui.bar:CreateTexture(nil, "ARTWORK")
    b.line:SetWidth(1)
    b.line:SetHeight(ICON_Y - TRACK_Y)
    b.tipAnchor = "ANCHOR_TOP"
    b:SetScript("OnEnter", Kit.TipShow)
    b:SetScript("OnLeave", Kit.TipHide)
    b:SetScript("OnClick", GroupClick)
    pool[i] = b
    return b
end
local function DrawGroup(b, g)
    local lead = g.lead
    if lead.kind == "spell" then
        Kit.Icon.Spell(b.icon, lead.id)
    elseif lead.kind == "death" then
        Kit.Icon.Mark(b.icon, 7)
    else
        Kit.Icon.Heroic(b.icon)
    end
    local x = st.scrubX + g.x
    b:ClearAllPoints()
    b:SetPoint("TOP", st.ui.bar, "TOPLEFT", x, -ICON_Y)
    b.line:ClearAllPoints()
    b.line:SetPoint("TOP", st.ui.bar, "TOPLEFT", x, -TRACK_Y)
    if lead.kind == "death" then
        b.line:Hide()
    else
        Kit.Paint(b.line, lead.kind == "spell" and "sem.rep.important" or "sem.phase", 0.8)
        b.line:Show()
    end
    b.group = g
    b.tipTitle, b.tip = Bar.TipOf(g)
    b:Show()
end
function Bar.Use(scene)
    local ui = st.ui
    if not ui then return end
    local groups = {}
    local list = {}
    if scene then
        local L = scene.layers
        list = MK.Merge(L and L.marks or {}, MK.Deaths(scene.deaths, scene.pull))
        groups = MK.Cluster(list, scene.from - scene.pull, scene.to - scene.pull, st.scrubW, MERGE_PX)
    end
    st.groups = groups
    local n = min(#groups, GROUP_POOL)
    for i = 1, n do DrawGroup(GroupBtn(i), groups[i]) end
    for i = n + 1, #pool do
        pool[i]:Hide()
        pool[i].line:Hide()
        pool[i].group = nil
    end
    local d = 0
    if scene then
        local dur = max(0.001, scene.to - scene.from)
        for i = 1, #scene.deaths do
            if d < DEATH_POOL then
                d = d + 1
                local tick = ticks[d]
                local x = st.scrubW * Clamp((scene.deaths[i].t - scene.from) / dur, 0, 1)
                tick:ClearAllPoints()
                tick:SetPoint("TOP", ui.bar, "TOPLEFT", st.scrubX + x, -DEATH_Y)
                tick:Show()
            end
        end
    end
    for i = d + 1, #ticks do ticks[i]:Hide() end
    st.deaths = d
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
    for i = 1, DEATH_POOL do
        local tick = ui.bar:CreateTexture(nil, "ARTWORK")
        Kit.Paint(tick, "sem.death")
        tick:SetWidth(DEATH_W)
        tick:SetHeight(DEATH_H)
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
    st.width = width
    st.rects = {}
    ui.bar:SetWidth(width)
    local x = 0
    At(ui.playBtn, x, 0)
    Rect("play", x, BTN)
    x = x + BTN + GAP
    local speedW = #ui.speedBtns * SPEED_W + (#ui.speedBtns - 1) * SPEED_GAP
    for i = 1, #ui.speedBtns do At(ui.speedBtns[i], x + (i - 1) * (SPEED_W + SPEED_GAP), 0) end
    Rect("speed", x, speedW)
    x = x + speedW + GAP_WIDE
    st.scrubX = x
    st.scrubW = max(1, width - x - GAP_WIDE - CLOCK_W - GAP - BTN)
    At(ui.track, x, -TRACK_Y)
    ui.track:SetWidth(st.scrubW)
    At(ui.scrub, x, -HIT_Y)
    ui.scrub:SetWidth(st.scrubW)
    Rect("scrub", x, st.scrubW)
    x = x + st.scrubW + GAP_WIDE
    ui.clock:ClearAllPoints()
    ui.clock:SetPoint("LEFT", ui.bar, "TOPLEFT", x, -(TRACK_Y + TRACK_H / 2))
    Rect("clock", x, CLOCK_W)
    x = x + CLOCK_W + GAP
    At(ui.gearBtn, x, 0)
    Rect("gear", x, BTN)
end
function Bar.Build(ui, run, width)
    st.ui, st.run = ui, run
    local bar = CreateFrame("Frame", nil, ui.frame)
    bar:SetHeight(ROW_H)
    ui.bar = bar
    BuildPlay(ui)
    BuildSpeed(ui)
    BuildScrub(ui)
    ui.clock = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.clock:SetWidth(CLOCK_W)
    ui.clock:SetJustifyH("RIGHT")
    BuildGear(ui)
    Bar.Resize(width)
    Bar.UpdatePlay()
    return ROW_H
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
function Bar.Probe()
    local shown = {}
    for i = 1, #pool do
        if pool[i]:IsShown() and pool[i].group then shown[#shown + 1] = pool[i] end
    end
    return { rects = st.rects, width = st.width, scrubX = st.scrubX, scrubW = st.scrubW, groups = st.groups,
             buttons = shown, deaths = st.deaths, icon = ICON, scrub = st.ui and st.ui.scrub, ui = st.ui }
end
