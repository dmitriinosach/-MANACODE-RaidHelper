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
local SPEED_GAP = 2
local SPEED_PAD = 4
local CLOCK_CHARS = 13
local CLOCK_K = 0.6
local GAP = 8
local THUMB_W = 2
local PHASE_GAP = 1
local LABEL_PAD = 4
local PHASE_ICON = 14
local CHAR_K = 0.62
local ICON = 20
local ICON_GAP = 2
local LANE_PAD = 6
local LANE_H = ICON + LANE_PAD
local LANES_TOP = 3
local RIM = 1
local DEATH_W = 2
local DEATH_BIG = 4
local DEATH_WAVE = 2
local DEATH_MANY = 3
local POOL = 64
local PHASE_POOL = 16
local MINUTE_POOL = 30
local MINUTE_STEPS = { 60, 120, 300, 600 }
local MINUTE_H = 4
local LABEL_POOL = 16
local MARK_PT = 9
local NAMES_MAX = 5
local TIP_LINES = 10
local SEEK_STEP = 2
local SPEEDS = { 0.5, 1, 2, 4, 8 }
local PLAY_TEX = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local PAUSE_TEX = "Interface\\TimeManager\\PauseButton"
local LANES = {
    { key = "boss", label = "rep.lane.boss" },
    { key = "tank", label = "rep.lane.tank" },
    { key = "heal", label = "rep.lane.heal" },
    { key = "dps", label = "rep.lane.dps" },
}
local LANE_OF = { tank = 2, heal = 3 }
local L_DPS = 4
local PHASE_TONE = { t1 = "trans", t2 = "trans", fury = "hot", frenzy = "hot", dream = "hot", away = "away", air = "away",
                     storm = "hot", valanar = "a", taldaram = "b", keleseth = "c" }
local PHASE_CYCLE = { "a", "b", "c" }
local Bar = { ROW_H = ROW_H, SEEK_STEP = SEEK_STEP, SPEEDS = SPEEDS, ICON = ICON }
ns.ReplayBar = Bar
local Kit = ns.Kit
local RD = ns.ReplayDraw
local MK = ns.ReplayMarks
local st = { width = 0, scrubW = 0, tiers = { {}, {}, {}, {} }, shown = {}, laneY = {}, rects = {}, deaths = 0,
             deathGroups = {}, deathAt = {}, scrubX = 0, phases = {}, hover = false, labelsW = 0, labelR = 0, col = 0, pad = 0 }
local pools = { {}, {}, {}, {} }
local ticks, dlabels, bands, phs, mins = {}, {}, {}, {}, {}
local markFont
local m = { btn = BTN, row = ROW_H, track = BTN, name = 12, pt = 10, clockW = 80, lane = LANE_H, icon = ICON, top = 0 }
local function Metrics()
    local pt = max(Kit.FontSize("GameFontNormalSmall", true), Kit.FontSize("GameFontHighlightSmall", true))
    m.btn = max(BTN, ceil(pt * 1.15) + 8)
    m.name = ceil(pt * 1.15)
    m.pt = pt
    m.track = max(m.btn + 4, m.name + ceil(MARK_PT * 1.15) + 6)
    m.lane = max(LANE_H, ceil(pt * 1.15) + 10)
    m.icon = m.lane - LANE_PAD
    m.top = m.track + LANES_TOP
    m.row = max(ROW_H, m.top + max(1, #st.shown) * m.lane)
    m.clockW = ceil(CLOCK_CHARS * Kit.FontSize("GameFontHighlight", true) * CLOCK_K)
    Bar.ROW_H = m.row
end
local Clamp = RD.Clamp
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
local function CursorX()
    local scrub = st.ui.scrub
    local left = scrub:GetLeft()
    if not left or st.scrubW <= 0 then return nil end
    return GetCursorPosition() / scrub:GetEffectiveScale() - left
end
local function Scale(scene)
    local folds = scene.layers and scene.layers.folds
    if st.scaleOf ~= scene or st.scaleFolds ~= folds then
        st.scaleOf, st.scaleFolds = scene, folds
        st.scale = MK.Scale(scene.from - scene.pull, scene.to - scene.pull, folds)
    end
    return st.scale
end
local function XAt(scene, sec)
    return MK.Frac(Scale(scene), sec) * st.scrubW
end
local function SeekToCursor()
    local x = CursorX()
    if not x then return end
    local scene = st.run.scene
    SeekTo(scene.pull + MK.TimeAt(Scale(scene), Clamp(x / st.scrubW, 0, 1)))
end
function Bar.UpdatePlay()
    local ui, run = st.ui, st.run
    if not ui then return end
    Kit.Glyph(ui.playBtn, run.playing and "pause" or "play")
    ui.playBtn.tipTitle = ns.T(run.playing and "iso.pause" or "iso.play")
    if ui.playBtn.hovered then Kit.TipShow(ui.playBtn) end
    for i = 1, #ui.speedBtns do
        local b = ui.speedBtns[i]
        b:SetActive(b.speed == run.speed)
    end
end
function Bar.SetSpeed(v)
    if not st.run then return end
    st.run.speed = v
    Bar.UpdatePlay()
end
function Bar.TogglePlay()
    local run = st.run
    local scene = run and run.scene
    if not scene then return end
    if not run.playing and run.t >= scene.to then run.t = scene.from end
    run.playing = not run.playing
    Bar.UpdatePlay()
end
local function PhaseAt(x)
    local list = st.phases
    for k = #list, 1, -1 do
        if x >= list[k].x then return k end
    end
    return 0
end
local function HoverPhase()
    local x = CursorX()
    if not x then return end
    local k = PhaseAt(x)
    if k == st.hoverK then return end
    st.hoverK = k
    local scrub = st.ui.scrub
    local p = st.phases[k]
    if p then
        scrub.tipTitle, scrub.tip = p.title, p.tip
    else
        local scene = st.run.scene
        scrub.tipTitle = ns.T("rep.ph.pre")
        scrub.tip = scene and format(ns.T("rep.ph.time"), Clock(scene.from - scene.pull), Clock(0),
            Clock(scene.pull - scene.from)) or nil
    end
    Kit.TipShow(scrub)
end
function Bar.Step()
    if st.run.scrubbing then SeekToCursor() end
    if st.hover then HoverPhase() end
end
function Bar.UpdateScrub()
    local ui, run = st.ui, st.run
    local scene = run.scene
    local frac = MK.Frac(Scale(scene), run.t - scene.pull)
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
local function MarkName(mk)
    if mk.id and not mk.label then
        local name = GetSpellInfo(mk.id)
        return name or ("#" .. tostring(mk.id))
    end
    if mk.label then return ns.T(mk.label) end
    return mk.text or "?"
end
local function Names(who)
    if #who == 0 then return nil end
    if #who <= NAMES_MAX then return concat(who, ", ") end
    local out = {}
    for i = 1, NAMES_MAX do out[i] = who[i] end
    return format(ns.T("rep.f.more"), concat(out, ", "), #who - NAMES_MAX)
end
local Who = ns.ReplayWho
local function UseRow(mk, own)
    local name = MarkName(mk)
    local text
    if mk.kind == "event" and mk.by then
        text = Who.Use(mk.by, mk.who, mk.by)
    elseif mk.kind == "event" and #mk.who == 0 and mk.text and mk.key:sub(1, 1) ~= "r" then
        text = mk.text
        local head = name .. ": "
        if text:sub(1, #head) == head then text = text:sub(#head + 1) end
    else
        text = Who.List(mk.who)
    end
    if not own then text = text and format(ns.T("rep.mk.other"), name, text) or name end
    local icon = mk.id and ns.SpellIcon(mk.id)
    if icon then text = format("|T%s:0|t %s", icon, text or name) end
    return Who.Row(text or name, Clock(mk.t))
end
function Bar.TipLines(g)
    local lines = { { kind = "head", left = MarkName(g.lead), right = g.n > 1 and format(ns.T("rep.mk.times"), g.n) or nil } }
    for i = 1, min(#g.items, TIP_LINES) do lines[#lines + 1] = UseRow(g.items[i], g.items[i].key == g.key) end
    if #g.items > TIP_LINES then
        lines[#lines + 1] = { kind = "note", left = format(ns.T("rep.mk.rest"), #g.items - TIP_LINES) }
    end
    return lines
end
local function GroupClick(self)
    local run = st.run
    if not (self.group and run and run.scene) then return end
    SeekTo(run.scene.pull + self.group.t)
end
local function GroupBtn(tier, i)
    local pool = pools[tier]
    local b = pool[i]
    if b then return b end
    b = CreateFrame("Button", nil, st.ui.bar)
    b.tier = tier
    b.tipAnchor = "ANCHOR_TOP"
    b.rim = b:CreateTexture(nil, "BACKGROUND")
    b.rim:SetTexture(WHITE)
    b.rim:SetPoint("TOPLEFT", b, "TOPLEFT", -RIM, RIM)
    b.rim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", RIM, -RIM)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.badge = b:CreateFontString(nil, "OVERLAY")
    b.badge:SetFontObject(MarkFont())
    b.badge:SetJustifyH("RIGHT")
    b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
    Kit.Text(b.badge, "text.bright")
    b.badge:Hide()
    b.more = b:CreateFontString(nil, "OVERLAY")
    b.more:SetFontObject(MarkFont())
    b.more:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2)
    b.more:SetText(ns.T("rep.mk.more"))
    Kit.Text(b.more, "text.bright")
    b.more:Hide()
    b:SetScript("OnEnter", Kit.ShowLines)
    b:SetScript("OnLeave", Kit.HideLines)
    b:SetScript("OnClick", GroupClick)
    pool[i] = b
    return b
end
local function DrawGroup(tier, i, g)
    local b = GroupBtn(tier, i)
    local lead = g.lead
    Kit.Icon.Spell(b.icon, lead.id)
    b:SetWidth(m.icon)
    b:SetHeight(m.icon)
    b:ClearAllPoints()
    b:SetPoint("TOP", st.ui.bar, "TOPLEFT", st.scrubX + g.x, -(st.laneY[tier] + (m.lane - m.icon) / 2))
    if lead.class then
        local r, gg, bb = Kit.ClassColor(lead.class)
        b.rim:SetVertexColor(r, gg, bb, 0.9)
        b.rim:Show()
    else
        b.rim:Hide()
    end
    if g.n >= 2 then
        b.badge:SetText(format(ns.T("rep.mk.times"), g.n))
        b.badge:Show()
    else
        b.badge:Hide()
    end
    if g.mixed then b.more:Show() else b.more:Hide() end
    b.group = g
    b.lines = Bar.TipLines(g)
    b:Show()
end
local function HideRest(tier, n)
    local pool = pools[tier]
    for i = n + 1, #pool do
        pool[i]:Hide()
        pool[i].group = nil
    end
end
local function LaneOf(name)
    local roles = st.run and st.run.roles
    return name and roles and LANE_OF[roles[name] or ""] or L_DPS
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
    local top = st.laneY[lane]
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
            local half = (many and DEATH_BIG or DEATH_W) / 2
            local x = Clamp(XAt(scene, list[k].t - scene.pull), half, st.scrubW - half)
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
                    if x + DEATH_BIG + (fs:GetStringWidth() or 0) > st.scrubW then
                        fs:SetPoint("RIGHT", ui.bar, "TOPLEFT", st.scrubX + x - DEATH_BIG, -(top + m.lane / 2))
                    else
                        fs:SetPoint("LEFT", ui.bar, "TOPLEFT", st.scrubX + x + DEATH_BIG, -(top + m.lane / 2))
                    end
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
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", ui.bar, "TOPLEFT", st.labelR, -(y + m.lane / 2))
    fs:SetWidth(st.labelsW)
    fs:SetHeight(m.lane)
    fs:Show()
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", ui.bar, "TOPLEFT", st.scrubX - st.pad, -y)
    band:SetWidth(st.scrubW + 2 * st.pad)
    band:SetHeight(m.lane - 1)
    band:Show()
end
local function PhaseTone(key, k)
    return "sem.rep.ph." .. (PHASE_TONE[key] or PHASE_CYCLE[(k - 1) % #PHASE_CYCLE + 1])
end
local function PhaseSeg(i)
    local p = phs[i]
    if p then return p end
    local ui = st.ui
    p = { tex = ui.bar:CreateTexture(nil, "BORDER") }
    p.icon = ui.bar:CreateTexture(nil, "ARTWORK")
    p.icon:SetWidth(PHASE_ICON)
    p.icon:SetHeight(PHASE_ICON)
    p.label = Kit.Str(ui.bar, "GameFontHighlightSmall")
    p.label:SetJustifyH("LEFT")
    p.label:SetWordWrap(false)
    Kit.Text(p.label, "sem.rep.ph.text")
    p.dur = ui.bar:CreateFontString(nil, "OVERLAY")
    p.dur:SetFontObject(MarkFont())
    p.dur:SetJustifyH("LEFT")
    p.dur:SetWordWrap(false)
    Kit.Text(p.dur, "sem.rep.ph.dur")
    phs[i] = p
    return p
end
local function PhaseText(p, at, x, icon)
    local w = at.w
    at.iconFit = icon ~= nil and w >= PHASE_ICON + LABEL_PAD * 2
    local tx = LABEL_PAD + (at.iconFit and PHASE_ICON + 3 or 0)
    local room = w - tx - LABEL_PAD
    p.label:SetText(at.title)
    p.dur:SetText(at.dur)
    at.fit = (p.label:GetStringWidth() or 0) <= room
    at.durFit = (p.dur:GetStringWidth() or 0) <= room
    local durH = ceil(MARK_PT * 1.15)
    local both = at.fit and at.durFit
    local top = floor((m.track - (both and m.name + durH or 0)) / 2)
    if at.iconFit then
        Kit.Icon.Spell(p.icon, icon)
        p.icon:ClearAllPoints()
        p.icon:SetPoint("LEFT", st.ui.bar, "TOPLEFT", x + LABEL_PAD, -m.track / 2)
        p.icon:Show()
    else
        p.icon:Hide()
    end
    p.label:ClearAllPoints()
    p.dur:ClearAllPoints()
    if both then
        p.label:SetPoint("TOPLEFT", st.ui.bar, "TOPLEFT", x + tx, -top)
        p.dur:SetPoint("TOPLEFT", st.ui.bar, "TOPLEFT", x + tx, -(top + m.name))
    else
        p.label:SetPoint("LEFT", st.ui.bar, "TOPLEFT", x + tx, -m.track / 2)
        p.dur:SetPoint("LEFT", st.ui.bar, "TOPLEFT", x + tx, -m.track / 2)
    end
    p.label:SetWidth(max(1, room))
    p.dur:SetWidth(max(1, room))
    if at.fit then p.label:Show() else p.label:Hide() end
    at.durFit = at.durFit and (both or not at.fit)
    if at.durFit then p.dur:Show() else p.dur:Hide() end
end
local function PhaseTip(scene, ph)
    local L = scene.layers
    local from, to = ph.from, ph.to
    local lines = { format(ns.T("rep.ph.time"), Clock(from), Clock(to), Clock(to - from)) }
    for _, w in ipairs(L and L.waves or {}) do
        local at = {}
        for i = 1, #w.times do
            if w.times[i] >= from and w.times[i] < to then at[#at + 1] = Clock(w.times[i]) end
        end
        if #at > 0 then lines[#lines + 1] = format(ns.T("rep.ph.wave"), ns.T(w.label), #at, concat(at, ", ")) end
    end
    local count, order = {}, {}
    for _, mk in ipairs(L and L.marks or {}) do
        if mk.t >= from and mk.t < to then
            local name = MarkName(mk)
            if not count[name] then order[#order + 1] = name end
            count[name] = (count[name] or 0) + 1
        end
    end
    if #order > 0 then
        local parts = {}
        for i = 1, #order do
            local n = count[order[i]]
            parts[i] = n > 1 and format(ns.T("rep.mk.many"), order[i], n) or order[i]
        end
        lines[#lines + 1] = format(ns.T("rep.ph.boss"), concat(parts, ", "))
    end
    local dead = {}
    for _, d in ipairs(scene.deaths) do
        local t = d.t - scene.pull
        if t >= from and t < to then dead[#dead + 1] = d.name end
    end
    if #dead > 0 then lines[#lines + 1] = format(ns.T("rep.ph.deaths"), #dead, Names(dead)) end
    local title = ns.T(ph.label)
    if ph.fold then title = format(ns.T("rep.ph.fold"), title, Clock(to - from)) end
    return title, concat(lines, "\n")
end
local function DrawMinutes(scene)
    local n = 0
    if scene then
        local len = scene.to - scene.pull
        local step = MINUTE_STEPS[#MINUTE_STEPS]
        for i = 1, #MINUTE_STEPS do
            if len / MINUTE_STEPS[i] <= MINUTE_POOL then
                step = MINUTE_STEPS[i]
                break
            end
        end
        for t = step, len, step do
            if n >= MINUTE_POOL then break end
            n = n + 1
            local tex = mins[n]
            if not tex then
                tex = st.ui.bar:CreateTexture(nil, "ARTWORK")
                Kit.Paint(tex, "sem.rep.ph.tick")
                tex:SetWidth(1)
                mins[n] = tex
            end
            tex:SetHeight(MINUTE_H)
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOM", st.ui.bar, "TOPLEFT", st.scrubX + XAt(scene, t), -m.track)
            tex:Show()
        end
    end
    st.minutes = n
    for k = n + 1, #mins do mins[k]:Hide() end
end
local function DrawPhases(scene)
    local ui = st.ui
    st.phases, st.hoverK = {}, nil
    local list = scene and scene.layers and scene.layers.phases or {}
    local n, plain = 0, 0
    if scene then
        for k = 1, min(#list, PHASE_POOL) do
            local ph = list[k]
            if not PHASE_TONE[ph.key] then plain = plain + 1 end
            local x0, x1 = XAt(scene, ph.from), XAt(scene, ph.to)
            if x1 - x0 >= 1 then
                n = n + 1
                local p = PhaseSeg(n)
                local w = max(1, x1 - x0 - (k < #list and PHASE_GAP or 0))
                local tone = PhaseTone(ph.fold and "away" or ph.key, plain)
                p.tex:ClearAllPoints()
                p.tex:SetPoint("TOPLEFT", ui.bar, "TOPLEFT", st.scrubX + x0, 0)
                p.tex:SetWidth(w)
                p.tex:SetHeight(m.track)
                Kit.Paint(p.tex, tone)
                p.tex:Show()
                local title, tip = PhaseTip(scene, ph)
                local at = { x = x0, w = w, title = title, tip = tip, tone = tone, dur = Clock(ph.to - ph.from),
                             icon = ph.icon, label = p.label, durFs = p.dur, iconTex = p.icon, tex = p.tex }
                PhaseText(p, at, st.scrubX + x0, ph.icon)
                st.phases[n] = at
            end
        end
    end
    for k = n + 1, #phs do
        phs[k].tex:Hide()
        phs[k].icon:Hide()
        phs[k].label:Hide()
        phs[k].dur:Hide()
    end
    DrawMinutes(scene)
end
local function Split(scene)
    local tiers, deaths = { {}, {}, {}, {} }, { {}, {}, {}, {} }
    if not scene then return tiers, deaths end
    local lists = MK.Lanes(scene.layers, LaneOf)
    local from, to = scene.from - scene.pull, scene.to - scene.pull
    local sc = Scale(scene)
    for lane = 1, #LANES do tiers[lane] = MK.Pack(lists[lane], from, to, st.scrubW, m.icon + ICON_GAP, nil, sc) end
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
        for lane = 1, #LANES do
            if #tiers[lane] > 0 or #deaths[lane] > 0 then shown[#shown + 1] = lane end
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
        for i = 1, n do DrawGroup(tier, i, groups[i]) end
        HideRest(tier, n)
        DrawLane(tier)
    end
    local acc = { used = 0, labels = 0 }
    st.deathGroups, st.deathAt = {}, {}
    for lane = 2, #LANES do
        if scene and st.laneY[lane] then DrawDeaths(scene, lane, deaths[lane], acc) end
    end
    for k = acc.used + 1, #ticks do ticks[k]:Hide() end
    for k = acc.labels + 1, #dlabels do dlabels[k]:Hide() end
    st.deaths = acc.used
    DrawPhases(scene)
    if m.row == row then return false end
    ui.bar:SetHeight(m.row)
    return true
end
local function Rect(name, x, w, y, h)
    st.rects[#st.rects + 1] = { name = name, x = x, w = w, y = y or 0, h = h or m.btn }
end
local function At(f, x, y)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", st.ui.bar, "TOPLEFT", x, y)
end
local function BuildPlay(ui)
    local b = Kit.GlyphButton(ui.bar, "play")
    Kit.ExactSize(b)
    b.tipAnchor = "ANCHOR_TOP"
    b.onClick = Bar.TogglePlay
    ui.playBtn = b
end
local function BuildSpeed(ui)
    ui.speedBtns = {}
    for i = 1, #SPEEDS do
        local b = Kit.Button(ui.bar)
        Kit.ExactSize(b)
        Kit.Bind(b.text, "GameFontNormalSmall")
        b.speed = SPEEDS[i]
        b.text:SetText(SpeedText(b.speed))
        b.tipTitle = ns.T("iso.speed.title")
        b.tipAnchor = "ANCHOR_TOP"
        b.onClick = function(self) Bar.SetSpeed(self.speed) end
        ui.speedBtns[i] = b
    end
end
local function BuildScrub(ui)
    local track = ui.bar:CreateTexture(nil, "BACKGROUND")
    Kit.Paint(track, "surface.bg")
    ui.track = track
    ui.fill = ui.bar:CreateTexture(nil, "ARTWORK")
    ui.fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    Kit.Paint(ui.fill, "sem.rep.ph.played")
    local scrub = CreateFrame("Button", nil, ui.bar)
    scrub:EnableMouseWheel(true)
    scrub:SetScript("OnMouseDown", function() st.run.scrubbing = true end)
    scrub:SetScript("OnMouseUp", function() st.run.scrubbing = false end)
    scrub:SetScript("OnMouseWheel", function(_, delta) Bar.Seek(delta * SEEK_STEP) end)
    scrub:SetScript("OnEnter", function()
        st.hover, st.hoverK = true, nil
        HoverPhase()
    end)
    scrub:SetScript("OnLeave", function()
        st.hover, st.hoverK = false, nil
        Kit.TipHide()
    end)
    scrub.tipAnchor = "ANCHOR_TOP"
    ui.scrub = scrub
    ui.thumb = ui.bar:CreateTexture(nil, "OVERLAY")
    ui.thumb:SetWidth(THUMB_W)
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
local function TextW(fs, text)
    local chars = #text:gsub("[\128-\191]", "")
    return max(ceil(fs:GetStringWidth() or 0), ceil(chars * m.pt * CHAR_K))
end
local function LabelsW()
    local w = 0
    for tier = 1, #LANES do w = max(w, TextW(st.ui.laneLabels[tier], ns.T(LANES[tier].label))) end
    return w
end
local function SpeedMin()
    local w = 0
    for i = 1, #SPEEDS do
        local chars = #SpeedText(SPEEDS[i])
        w = max(w, ceil(chars * m.pt * CHAR_K))
    end
    return w + SPEED_PAD * 2
end
local function ColumnW()
    local top = m.btn + GAP + #SPEEDS * SpeedMin() + (#SPEEDS - 1) * SPEED_GAP
    local lane = m.clockW + GAP + st.labelsW + GAP
    return max(top, lane) + GAP
end
function Bar.Resize(width, col)
    local ui = st.ui
    Metrics()
    st.width = width
    st.rects = {}
    st.labelsW = LabelsW()
    ui.bar:SetWidth(width)
    ui.bar:SetHeight(m.row)
    local btn = m.btn
    local by = floor((m.track - btn) / 2)
    local x = max(col or 0, ColumnW())
    st.col = x
    local pad = ceil(m.icon / 2) + RIM
    st.pad = pad
    st.scrubX = x + pad
    st.labelR = x - GAP
    ui.playBtn:SetWidth(btn)
    ui.playBtn:SetHeight(btn)
    At(ui.playBtn, 0, -by)
    Rect("play", 0, btn, by)
    local n = #ui.speedBtns
    local x0 = btn + GAP
    local room = x + pad - GAP - x0
    local sw = floor((room - (n - 1) * SPEED_GAP) / n)
    for i = 1, n do
        local b = ui.speedBtns[i]
        local bx = x0 + (i - 1) * (sw + SPEED_GAP)
        local w = i == n and x0 + room - bx or sw
        b:SetWidth(w)
        b:SetHeight(btn)
        At(b, bx, -by)
        Rect("speed" .. i, bx, w, by, btn)
    end
    local cw = st.labelR - st.labelsW - GAP
    ui.clock:SetWidth(cw)
    ui.clock:SetHeight(m.lane)
    At(ui.clock, 0, -m.top)
    Rect("clock", 0, cw, m.top, m.lane)
    st.scrubW = max(1, width - x - 2 * pad)
    x = x + pad
    At(ui.track, x, 0)
    ui.track:SetWidth(st.scrubW)
    ui.track:SetHeight(m.track)
    ui.fill:SetHeight(m.track)
    At(ui.scrub, x, 0)
    ui.scrub:SetWidth(st.scrubW)
    ui.scrub:SetHeight(m.track)
    ui.thumb:SetHeight(m.track)
    Rect("scrub", x, st.scrubW, 0, m.track)
end
function Bar.Build(ui, run, width, col)
    st.ui, st.run = ui, run
    Metrics()
    local bar = CreateFrame("Frame", nil, ui.frame)
    bar:SetHeight(m.row)
    ui.bar = bar
    BuildPlay(ui)
    BuildSpeed(ui)
    BuildScrub(ui)
    ui.laneLabels = {}
    for tier = 1, #LANES do
        local fs = Kit.Str(bar, "GameFontNormalSmall")
        Kit.Text(fs, "text.muted")
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(false)
        fs:SetText(ns.T(LANES[tier].label))
        fs:Hide()
        ui.laneLabels[tier] = fs
        local band = bar:CreateTexture(nil, "BACKGROUND")
        Kit.Paint(band, "surface.laneHead")
        band:Hide()
        bands[tier] = band
    end
    ui.clock = Kit.Str(bar, "GameFontHighlight")
    Kit.Text(ui.clock, "text.bright")
    ui.clock:SetJustifyH("LEFT")
    ui.clock:SetWordWrap(false)
    Bar.Resize(width, col)
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
function Bar.Head(fight)
    local name = Kit.Hex("text.title") .. ns.EncName(fight.boss) .. "|r"
    local outcome = Kit.Hex(fight.killed and "sem.win" or "sem.wipe")
        .. format(ns.T(fight.killed and "iso.title.win" or "iso.title.wipe"), Clock((fight.to or fight.from) - fight.from)) .. "|r"
    local day = Kit.Hex("text.muted") .. ns.Date(fight.from, "dayTime") .. "|r"
    local spot = ns.FightTree and ns.FightTree.Spot(fight)
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
    local trackY = 0
    local tierRects = { { name = "track", y = trackY, h = m.track } }
    local lanes = {}
    for v = 1, #st.shown do
        local tier = st.shown[v]
        local key = LANES[tier].key
        local r = { name = key, key = key, tier = tier, y = st.laneY[tier], h = m.lane, x = st.scrubX, w = st.scrubW,
                    label = st.ui and st.ui.laneLabels[tier], band = bands[tier], groups = #st.tiers[tier] }
        tierRects[#tierRects + 1] = r
        lanes[#lanes + 1] = r
    end
    local boxes = {}
    for i = 1, #st.rects do
        local r = st.rects[i]
        if r.name ~= "scrub" then boxes[#boxes + 1] = { name = r.name, x = r.x, w = r.w, y = r.y, h = r.h } end
    end
    return { rects = st.rects, width = st.width, col = st.col, pad = st.pad, scrubX = st.scrubX, labelR = st.labelR, labelsW = st.labelsW, scrubW = st.scrubW, groups = groups, tiers = st.tiers,
             buttons = shown, deaths = st.deaths, deathGroups = st.deathGroups, deathAt = st.deathAt, icon = m.icon, rowH = m.row,
             tierRects = tierRects, lanes = lanes, boxes = boxes, laneH = m.lane, scrub = st.ui and st.ui.scrub, ui = st.ui,
             ticks = ticks, phases = st.phases, minutes = st.minutes or 0, minuteTex = mins, track = { y = trackY, h = m.track }, step = m.icon + ICON_GAP,
             laneOf = function(name) return LANES[LaneOf(name)].key end }
end
