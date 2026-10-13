local ADDON, ns = ...
local format = string.format
local concat = table.concat
local tsort = table.sort
local floor = math.floor
local max = math.max
local min = math.min
local T = ns.T
local Kit = ns.Kit
local W = 440
local ROW = 26
local CAP = 24
local OUT_ROWS = 10
local OUT_LINE = 14
local MODEL = 132
local ARROW = 24
local PROBE_WAIT = 1
local SEQ_MAX = 160
local ANIM_RETRY = 0.5
local ANIM_TRIES = 6
local CUSTOM_BTN = 130
local View = { btn = {}, check = {} }
ns.DevTool = View
local frame
local recText
local outText
local outBar
local edit
local model
local bossText
local seqText
local probe
local probeDrive
local lines = {}
local offset = 0
local cache = {}
local anim = {}
local bi, seq = 1, 0
local animLeft, animTries = 0, 0
local qi, waitLeft = 0, 0
local queue = {}
local function Bosses()
    local out = {}
    local models = ns.replayData and ns.replayData.models or {}
    for key, m in pairs(models) do
        if m and tonumber(m.npc) then out[#out + 1] = { name = ns.EncName(key), npc = tonumber(m.npc), seq = m.seq } end
    end
    tsort(out, function(a, b) return a.name < b.name end)
    return out
end
local function Render()
    if not frame then return end
    offset = max(0, min(offset, #lines - OUT_ROWS))
    local last = min(#lines, offset + OUT_ROWS)
    outText:SetText(last > offset and concat(lines, "\n", offset + 1, last) or T("dev.out.empty"))
    outBar:SetState(offset, OUT_ROWS, max(OUT_ROWS, #lines))
end
local function Out(list, chat)
    lines = list
    offset = 0
    Render()
    if chat then
        for i = 1, #list do ns.Print(list[i]) end
    end
end
local function Add(line)
    lines[#lines + 1] = line
    offset = #lines - OUT_ROWS
    Render()
end
local function RecState()
    if not recText then return end
    local R = ns.Recorder
    local on = R and R.IsOn() and not R.IsPaused() and R.InZone()
    recText:SetText(T(on and "dev.rec.on" or "dev.rec.off"))
    Kit.Text(recText, on and "text.good" or "text.muted")
end
local function Mark(key)
    local def = ns.DevMarks.Def(key)
    if def and def.room then
        local text, ex, ey = ns.DevMarks.Here(def)
        local where = not text and T("dev.mark.nopos")
            or ex and format(T("dev.mark.yd"), T(def.label), ex, ey, text)
            or format(T("dev.mark.noroom"), T(def.label), text)
        local ok, msg = ns.DevMarks.Write(key)
        ns.Print(where)
        Out({ where, ok and msg or T("dev.mark.norec") })
        RecState()
        return
    end
    local custom = key == ns.DevMarks.CUSTOM
    local ok, msg = ns.DevMarks.Write(key, custom and edit:GetText() or nil)
    ns.Print(msg)
    Out({ msg })
    if ok and custom then edit:SetValue("") end
    RecState()
end
local Pipes = { btn = {}, at = {} }
View.pipes = Pipes
local PIPE_W, PIPE_H, PIPE_BTN, PIPE_R = 240, 250, 64, 78
local PIPE_AT = { rot_nw = { -0.71, 0.71 }, rot_ne = { 0.71, 0.71 }, rot_sw = { -0.71, -0.71 }, rot_se = { 0.71, -0.71 } }
local function PipeText(b, now)
    local at = Pipes.at[b.arg]
    local sec = at and floor(now - at) or -1
    if b.sec == sec then return end
    b.sec = sec
    b:SetText(sec >= 0 and format(T("dev.pipes.btn"), b.name, sec) or b.name)
end
local function PipeSync()
    local on = ns.DevMarks.on
    local now = GetTime()
    for key, b in pairs(Pipes.btn) do
        local lit = on[key] == true
        if b.lit ~= lit then
            b.lit = lit
            Kit.ButtonKind(b, lit and "main" or nil)
            if lit then b.glow:Show() else b.glow:Hide() end
        end
        PipeText(b, now)
    end
    for key, c in pairs(View.check) do
        local lit = on[key] == true
        if (c:GetChecked() and true or false) ~= lit then c:SetChecked(lit) end
    end
    if Pipes.state then
        local R = ns.Recorder
        local rec = R and R.IsOn() and not R.IsPaused() and R.InZone()
        Pipes.state:SetText(format(T("dev.pipes.state"), T(rec and "dev.dummy.on" or "dev.dummy.off"),
            T(ns.RecFilter and ns.RecFilter.spec and "dev.dummy.on" or "dev.dummy.off")))
        Kit.Text(Pipes.state, rec and "text.good" or "text.bad")
    end
end
local function PipeFlip(key)
    local ok, msg = ns.DevMarks.Toggle(key)
    if ok then Pipes.at[key] = ns.DevMarks.on[key] and GetTime() or nil end
    PipeSync()
    return ok, msg
end
local function PipeClick(key)
    local ok, msg = PipeFlip(key)
    Out({ msg })
    if not ok then ns.Print(msg) end
end
local function PipeBtn(b)
    PipeClick(b.arg)
end
local function PipeTick(self, dt)
    self.wait = (self.wait or 0) - dt
    if self.wait > 0 then return end
    self.wait = 0.2
    local now = GetTime()
    for _, b in pairs(Pipes.btn) do PipeText(b, now) end
end
local function PipeDragStop(self)
    self:StopMovingOrSizing()
    local ui = ns.GetDB().settings.ui
    ui.pipeX, ui.pipeY = floor(self:GetLeft() + 0.5), floor(self:GetTop() + 0.5)
end
local function PipeHide()
    if Pipes.win then Pipes.win:Hide() end
    ns.GetDB().settings.ui.pipeShown = nil
end
local function PipeArt(f, tex, size, y)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\" .. tex)
    t:SetWidth(size)
    t:SetHeight(size)
    t:SetPoint("CENTER", f, "TOP", 0, y)
    return t
end
local function PipeBuild()
    local f = CreateFrame("Frame", "HTP_FailWatchDevPipes", UIParent)
    Pipes.win = f
    f:SetWidth(PIPE_W)
    f:SetHeight(PIPE_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", PipeDragStop)
    f:SetScript("OnUpdate", PipeTick)
    f:SetScript("OnShow", PipeSync)
    local ui = ns.GetDB().settings.ui
    if ui.pipeX then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ui.pipeX, ui.pipeY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", Kit.Space.pad, -12)
    title:SetText(T("dev.mark.rot"))
    Kit.Title(title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", PipeHide)
    local cy = -24 - (PIPE_H - 24 - 22) / 2
    Kit.Tint(PipeArt(f, "ring256", PIPE_R * 2, cy), "text.muted", 0.6)
    Kit.Tint(PipeArt(f, "boss_ooze", 28, cy), "sem.rep.ooze")
    local list = ns.DevMarks.list
    for i = 1, #list do
        local d = list[i]
        local at = PIPE_AT[d.key]
        if d.toggle and at then
            local b = Kit.Button(f)
            b.name = T(d.short)
            b:SetText(b.name)
            b.tipTitle = T(d.label)
            b.tip = T("dev.mark.rot.tip")
            b.arg = d.key
            b.onClick = PipeBtn
            b:SetWidth(PIPE_BTN)
            b:SetHeight(30)
            b:SetPoint("CENTER", f, "TOP", at[1] * PIPE_R, cy + at[2] * PIPE_R)
            b.glow = b:CreateTexture(nil, "BACKGROUND")
            b.glow:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\disc256")
            b.glow:SetWidth(PIPE_BTN + 30)
            b.glow:SetHeight(PIPE_BTN + 30)
            b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
            Kit.Tint(b.glow, "sem.rep.ooze", 0.45)
            b.glow:Hide()
            Pipes.btn[d.key] = b
        end
    end
    Pipes.state = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Pipes.state:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", Kit.Space.pad, 10)
    Pipes.state:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -Kit.Space.pad, 10)
    Pipes.state:SetJustifyH("LEFT")
    Kit.Window(f)
end
function Pipes.Show()
    if not Pipes.win then PipeBuild() end
    Pipes.win:Show()
    ns.GetDB().settings.ui.pipeShown = true
    PipeSync()
end
function Pipes.Toggle()
    if Pipes.win and Pipes.win:IsShown() then PipeHide() else Pipes.Show() end
end
ns.OnReady(function()
    if ns.GetDB().settings.ui.pipeShown then Pipes.Show() end
end)
local function ToggleMark(c, on)
    local ok, msg = PipeFlip(c.key)
    if not ok then c:SetChecked(ns.DevMarks.on[c.key] and true or false) end
    ns.Print(msg)
    Out({ msg })
    RecState()
end
local function Toggler(c)
    return function(on) ToggleMark(c, on) end
end
local function Bucket(b, unit)
    local items = b.items
    for i = 1, #items do
        local v = IsItemInRange(items[i], unit)
        if v == 1 or v == true then return "1" end
        if v == 0 or v == false then return "0" end
    end
    if b.interact then return CheckInteractDistance(unit, b.interact) and "1" or "0" end
    return "nil"
end
local function RangeRow(unit)
    local vals, yds = {}, {}
    local list = ns.rangingData.buckets
    for i = 1, #list do
        vals[i] = Bucket(list[i], unit)
        yds[i] = list[i].yd
    end
    local fork = "?"
    if ns.Ranging and ns.Ranging.Measure then
        local lo, hi = ns.Ranging.Measure(unit)
        fork = hi and format("%d–%d", lo, hi) or format(T("dev.range.far"), lo)
    end
    return format(T("dev.range.row"), unit, UnitName(unit) or "?", concat(vals, "/"), concat(yds, "/"), fork)
end
local function Enemy(unit)
    return UnitExists(unit) and UnitCanAttack("player", unit) and true or false
end
local function Range()
    local out = {}
    if UnitExists("target") then out[1] = RangeRow("target") end
    for i = 1, GetNumRaidMembers() or 0 do
        local unit = "raid" .. i .. "target"
        if Enemy(unit) then
            out[#out + 1] = RangeRow(unit)
            break
        end
    end
    if #out == 0 then out[1] = T("dev.range.none") end
    local st = ns.Ranging and ns.Ranging.Status and ns.Ranging.Status()
    if st then
        out[#out + 1] = format(T("dev.range.status"), st.on and T("dev.range.on") or T("dev.range.off"),
            st.foreign or 0, ns.Ranging.MinClients(), st.sent or 0, st.got or 0)
        local s = st.session
        if s then
            out[#out + 1] = format(T("dev.range.session"), tostring(s.enc), s.count or 0,
                s.active and T("dev.range.on") or T("dev.range.off"), s.sent or 0, s.got or 0)
        end
        local l = st.last
        if l and l.why then
            out[#out + 1] = format(T("dev.range.last"), tostring(l.enc), l.count or 0, tostring(l.why))
        end
        if st.broken then out[#out + 1] = format(T("dev.range.broken"), st.broken) end
        local why = ns.Ranging.Why and ns.Ranging.Why()
        if why then out[#out + 1] = format(T("dev.range.why"), T("dev.range.why." .. why)) end
    end
    Out(out, true)
end
local function RaidOnMap()
    local n, on = GetNumRaidMembers() or 0, 0
    for i = 1, n do
        local px, py = GetPlayerMapPosition("raid" .. i)
        if (px or 0) > 0 or (py or 0) > 0 then on = on + 1 end
    end
    return on, n
end
local function Map()
    local level = GetCurrentMapDungeonLevel() or 0
    local levels = GetNumDungeonMapLevels() or 0
    local good = ns.Recorder and ns.Recorder.MapLevel and ns.Recorder.MapLevel()
    local out = { format(T("dev.map.zone"), GetRealZoneText() or "?", tostring(GetMapInfo() or "?"), level, levels,
        good and tostring(good) or T("dev.no")) }
    local x, y = GetPlayerMapPosition("player")
    out[2] = format(T("dev.map.me"), x or 0, y or 0)
    local on, n = RaidOnMap()
    out[3] = format(T("dev.map.raid"), on, n)
    if WorldMapFrame and WorldMapFrame:IsShown() then out[4] = T("dev.map.world") end
    Out(out, true)
end
local FLOOR_KEEP = 60
local function RaidPoints()
    local pts = {}
    for i = 1, GetNumRaidMembers() or 0 do
        local px, py = GetPlayerMapPosition("raid" .. i)
        if (px or 0) > 0 or (py or 0) > 0 then
            pts[UnitName("raid" .. i) or ("raid" .. i)] = { floor(px * 10000 + 0.5) / 10000, floor(py * 10000 + 0.5) / 10000 }
        end
    end
    return pts
end
local function Floors(quiet)
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if not quiet then Out({ T("dev.floors.world") }, true) end
        return false
    end
    local was, area = GetCurrentMapDungeonLevel() or 0, GetCurrentMapAreaID() or 0
    local levels = GetNumDungeonMapLevels() or 0
    local snap = { at = date("%Y-%m-%d %H:%M:%S"), t = GetTime(), zone = GetRealZoneText(), sub = GetSubZoneText and GetSubZoneText(),
        map = GetMapInfo(), area = area, was = was, levels = levels, combat = UnitAffectingCombat and UnitAffectingCombat("player") and true or nil,
        floors = {} }
    local out = { format(T("dev.floors.head"), GetRealZoneText() or "?", tostring(GetMapInfo() or "?"), area, was,
        levels) }
    for level = 0, levels do
        local ok = pcall(SetDungeonMapLevel, level)
        local now = GetCurrentMapDungeonLevel() or 0
        if not ok or now ~= level then
            out[#out + 1] = format(T("dev.floors.no"), level, now)
            snap.floors[#snap.floors + 1] = { level = level, stuck = now }
        else
            local x, y = GetPlayerMapPosition("player")
            local on, n = RaidOnMap()
            out[#out + 1] = format(T("dev.floors.row"), level, x or 0, y or 0, on, n)
            snap.floors[#snap.floors + 1] = { level = level, me = { x or 0, y or 0 }, on = on, n = n, pts = RaidPoints() }
        end
    end
    if (GetCurrentMapAreaID() or 0) ~= area then SetMapToCurrentZone() end
    if (GetCurrentMapDungeonLevel() or 0) ~= was then
        if was > 0 then SetDungeonMapLevel(was) else SetMapToCurrentZone() end
    end
    out[#out + 1] = format(T("dev.floors.back"), GetCurrentMapDungeonLevel() or 0)
    local db = ns.GetDB()
    db.floorProbes = db.floorProbes or {}
    local list = db.floorProbes
    list[#list + 1] = snap
    while #list > FLOOR_KEEP do table.remove(list, 1) end
    if not quiet then Out(out, true) end
    return true
end
local floatBtn
local function FloatText()
    if not floatBtn then return end
    local list = ns.GetDB().floorProbes
    floatBtn:SetText(format(T("dev.floatfloors.btn"), list and #list or 0))
end
local function MakeFloat()
    local b = Kit.Button(UIParent, "ManaCodeRaidHelperFloorProbe", "main")
    b:SetWidth(110)
    b:SetHeight(24)
    b:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    b:SetFrameStrata("HIGH")
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", b.StartMoving)
    b:SetScript("OnDragStop", b.StopMovingOrSizing)
    b.onClick = function()
        Floors(true)
        FloatText()
    end
    floatBtn = b
end
local function ShowFloat(on)
    if on and not floatBtn then MakeFloat() end
    if floatBtn then
        if on then floatBtn:Show() else floatBtn:Hide() end
    end
    FloatText()
end
local function ToggleFloat()
    local s = ns.GetDB().settings
    s.floorBtn = not s.floorBtn or nil
    ShowFloat(s.floorBtn)
    Out({ T(s.floorBtn and "dev.floatfloors.on" or "dev.floatfloors.off") }, false)
end
ns.OnReady(function()
    if ns.GetDB().settings.floorBtn then ShowFloat(true) end
end)
local function Cmds()
    local out = { T("dev.cmd.head") }
    local C = ns.ServerCmd
    local defs = ns.serverCmds or {}
    for i = 1, #defs do
        local d = defs[i]
        local label = C and C.Label(d.key) or T(d.label)
        local cmd = C and C.Command(d.key) or d.cmd
        out[#out + 1] = format(T("dev.cmd.row"), label, cmd ~= "" and cmd or T("dev.cmd.empty"))
    end
    Out(out, true)
end
local function Auto()
    if ns.AutoRec then ns.AutoRec.DevState() end
    Out({ T("dev.out.chat") })
end
local function Lock()
    if ns.Raid and ns.Raid.DevLock then ns.Raid.DevLock() end
    Out({ T("dev.out.chat") })
end
local function Calib()
    if ns.DevCalib then ns.DevCalib.Toggle() end
end
local function Cpu()
    local C = ns.CpuMeter
    if not C then return end
    local out = C.Set(not C.Wanted())
    out[#out + 1] = C.State()
    Out(out, true)
end
local function CpuLast()
    if ns.CpuMeter then Out(ns.CpuMeter.Report(), true) end
end
local function DummyLabel()
    return format(T("dev.chk.dummy"), T(ns.Encounters.Dummy() and "dev.dummy.on" or "dev.dummy.off"))
end
local function Dummy()
    local on = not ns.Encounters.Dummy()
    ns.Recorder.SetDummy(on)
    local b = View.btn.dummy
    if b then
        b:SetText(DummyLabel())
        b.tipTitle = DummyLabel()
    end
    Out({ T(on and "dev.dummy.out.on" or "dev.dummy.out.off") }, true)
    RecState()
end
local function SpecLabel()
    return format(T("dev.chk.spec"), T(ns.RecFilter.spec and "dev.dummy.on" or "dev.dummy.off"))
end
local function Spec()
    local on = not ns.RecFilter.spec
    ns.Recorder.SetSpec(on)
    local b = View.btn.spec
    if b then
        b:SetText(SpecLabel())
        b.tipTitle = SpecLabel()
    end
    Out({ T(on and "dev.spec.out.on" or "dev.spec.out.off") }, true)
    PipeSync()
    RecState()
end
local function LootLabel()
    return T(ns.Loot and ns.Loot.HasDemo() and "dev.chk.loot.off" or "dev.chk.loot")
end
local function LootDemo()
    local L = ns.Loot
    if not L then
        Out({ T("dev.loot.out.nofile") }, true)
        return
    end
    if L.HasDemo() then
        L.ClearDemo()
        Out({ T("dev.loot.out.off") })
    else
        local f = L.Demo()
        if not f then
            Out({ T("dev.loot.out.none") })
        else
            Out({ format(T("dev.loot.out.on"), ns.EncName(f.boss)) })
            if ns.Shell then ns.Shell.Open("log") end
            if ns.Timeline then ns.Timeline.ShowFight(f) end
        end
    end
    local b = View.btn.loot
    if b then
        b:SetText(LootLabel())
        b.tipTitle = LootLabel()
    end
end
local function FrameProbe()
    local P = ns.DevProbe
    if not P then return end
    if P.Running() then
        Out({ T("dev.probe.busy") })
        return
    end
    P.Start(function(out) Out(out, true) end)
    Out({ format(T("dev.probe.wait"), P.Seconds()) })
end
local function AnimList()
    local out = {}
    local all = Bosses()
    for i = 1, #all do
        if cache[all[i].name] ~= false then out[#out + 1] = all[i] end
    end
    return out
end
local function HasModel(m)
    if not m then return false end
    local ok, p = pcall(m.GetModel, m)
    return ok and type(p) == "string" and p ~= ""
end
local function SeqShow()
    if not seqText then return end
    local b = anim[bi]
    local name = ns.L["dev.seq." .. seq] or T("dev.anim.unknown")
    local ms = b and b.seq and b.seq[seq]
    seqText:SetText(ms and format(T("dev.anim.len"), seq, name, ms / 1000) or format(T("dev.anim.seq"), seq, name))
    if b and HasModel(model) then pcall(model.SetSequence, model, seq) end
    animLeft, animTries = ANIM_RETRY, ANIM_TRIES
end
local function BossShow()
    if not bossText then return end
    local b = anim[bi]
    if not b then
        bossText:SetText(T("dev.anim.none"))
        if model and model.ClearModel then pcall(model.ClearModel, model) end
        return
    end
    bossText:SetText(format(T("dev.anim.boss"), b.name, bi, #anim))
    if model then
        if model.ClearModel then pcall(model.ClearModel, model) end
        pcall(model.SetCreature, model, b.npc)
    end
    SeqShow()
end
local function StepBoss(d)
    anim = AnimList()
    if #anim == 0 then
        bi = 1
    else
        bi = (bi - 1 + d) % #anim + 1
    end
    BossShow()
end
local function StepSeq(d)
    seq = (seq + d) % (SEQ_MAX + 1)
    SeqShow()
end
local function AnimTick(_, elapsed)
    if animTries <= 0 or not anim[bi] then return end
    animLeft = animLeft - elapsed
    if animLeft > 0 then return end
    animLeft = ANIM_RETRY
    if not HasModel(model) then return end
    animTries = animTries - 1
    pcall(model.SetSequence, model, seq)
end
local function ProbeDone()
    probeDrive:Hide()
    probe:Hide()
    local yes, miss = 0, {}
    for i = 1, #queue do
        if cache[queue[i].name] then yes = yes + 1 else miss[#miss + 1] = queue[i].name end
    end
    ns.Print(format(T("dev.models.done"), yes, #queue))
    if #miss > 0 then ns.Print(format(T("dev.models.miss"), concat(miss, ", "))) end
    Add(format(T("dev.models.done"), yes, #queue))
    queue = {}
    StepBoss(0)
end
local function ProbeNext()
    qi = qi + 1
    local b = queue[qi]
    if not b then return ProbeDone() end
    if probe.ClearModel then pcall(probe.ClearModel, probe) end
    pcall(probe.SetCreature, probe, b.npc)
    waitLeft = PROBE_WAIT
end
local function ProbeTick(_, elapsed)
    waitLeft = waitLeft - elapsed
    if waitLeft > 0 then return end
    local b = queue[qi]
    if b then
        local ok, p = pcall(probe.GetModel, probe)
        local has = ok and type(p) == "string" and p ~= ""
        cache[b.name] = has and true or false
        Add(format(T("dev.models.row"), b.name, T(has and "dev.models.yes" or "dev.models.no")))
    end
    ProbeNext()
end
local METHOD_PAT = { "Rotat", "Facing", "Camera", "Pitch", "Yaw", "Roll", "Scale", "Position", "Light", "Zoom", "View", "Target" }
local function Methods()
    local out = {}
    for _, kind in ipairs({ "PlayerModel", "Model" }) do
        local ok, m = pcall(CreateFrame, kind, nil, UIParent)
        local mt = ok and m and getmetatable(m)
        local idx = mt and mt.__index
        local names = {}
        if type(idx) == "table" then
            for name, v in pairs(idx) do
                if type(v) == "function" then
                    for k = 1, #METHOD_PAT do
                        if name:find(METHOD_PAT[k], 1, true) then
                            names[#names + 1] = name
                            break
                        end
                    end
                end
            end
        end
        table.sort(names)
        if m then m:Hide() end
        out[#out + 1] = format(T("dev.methods.head"), kind, #names)
        for i = 1, #names, 4 do
            out[#out + 1] = table.concat(names, "  ", i, math.min(i + 3, #names))
        end
    end
    Out(out)
end
local function Models()
    if #queue > 0 then
        Out({ T("dev.models.busy") })
        return
    end
    if not probe then
        local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok or not m or not m.SetCreature or not m.GetModel then
            Out({ T("dev.models.fail") }, true)
            return
        end
        probe = m
        probe:SetWidth(64)
        probe:SetHeight(64)
        probe:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -10, 0)
        probe:SetAlpha(0)
        probe:EnableMouse(false)
        probeDrive = CreateFrame("Frame", nil, UIParent)
        probeDrive:SetScript("OnUpdate", ProbeTick)
    end
    queue = Bosses()
    qi = 0
    Out({ format(T("dev.models.run"), #queue) })
    ns.Print(format(T("dev.models.run"), #queue))
    probe:Show()
    probeDrive:Show()
    ProbeNext()
end
local function OnBtn(self)
    self.run(self.arg)
end
local function Btn(parent, text, tip, run, arg)
    local b = Kit.Button(parent)
    b:SetHeight(Kit.Space.ctl)
    b:SetText(text)
    b.tipTitle = text
    b.tip = tip
    b.run, b.arg = run, arg
    b.onClick = OnBtn
    return b
end
local function Put(b, x, y, w)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    b:SetWidth(w)
end
local function Group(text, y, inner)
    local cap = Kit.Caption(frame, text, inner)
    cap:SetPoint("TOPLEFT", frame, "TOPLEFT", Kit.Space.pad, y)
end
local function DragStop(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    local ui = ns.GetDB().settings.ui
    ui.devPoint, ui.devX, ui.devY = point, x, y
end
local function Wheel(_, delta)
    offset = offset - delta
    Render()
end
local function BarScroll(v)
    offset = v
    Render()
end
local function BuildMarks(y, inner)
    local pad, gap = Kit.Space.pad, Kit.Space.row
    Group(T("dev.g.marks"), y, inner)
    y = y - CAP
    recText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recText:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    recText:SetWidth(inner)
    recText:SetJustifyH("LEFT")
    y = y - 18
    local half = floor((inner - gap) / 2)
    local list = ns.DevMarks.list
    local n = 0
    for i = 1, #list do
        local d = list[i]
        if not d.toggle then
            local b = Btn(frame, T(d.label), T("dev.mark.tip"), Mark, d.key)
            Put(b, pad + (n % 2) * (half + gap), y - floor(n / 2) * ROW, half)
            n = n + 1
            View.btn[d.key] = b
        end
    end
    y = y - floor((n + 1) / 2) * ROW
    local open = Btn(frame, T("dev.pipes.open"), T("dev.pipes.open.tip"), Pipes.Toggle)
    Put(open, pad, y, 120)
    View.btn.pipes = open
    local quarter = floor((inner - 120 - 3 * gap) / 4)
    local t = 0
    for i = 1, #list do
        local d = list[i]
        if d.toggle then
            local c = Kit.Check(frame)
            c.label:SetText(T(d.short))
            c.tipTitle = T(d.label)
            c.tip = T("dev.mark.rot.tip")
            c.key = d.key
            c.onToggle = Toggler(c)
            c:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 120 + gap + t * (quarter + gap), y)
            t = t + 1
            View.check[d.key] = c
        end
    end
    y = y - ROW
    edit = Kit.Edit(frame)
    edit:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    edit:SetWidth(inner - CUSTOM_BTN - gap)
    edit:SetMaxLetters(60)
    edit.tipTitle = T("dev.mark.custom")
    edit.tip = T("dev.mark.edit.tip")
    local custom = Btn(frame, T("dev.mark.custom"), T("dev.mark.custom.tip"), Mark, ns.DevMarks.CUSTOM)
    Put(custom, pad + inner - CUSTOM_BTN, y, CUSTOM_BTN)
    View.btn.custom = custom
    View.edit = edit
    return y - ROW - 4
end
local function BuildChecks(y, inner)
    local pad, gap = Kit.Space.pad, Kit.Space.row
    Group(T("dev.g.checks"), y, inner)
    y = y - CAP
    local checks = {
        { "range", Range }, { "models", Models }, { "map", Map }, { "floors", function() Floors() end },
        { "floatfloors", ToggleFloat },
        { "cmd", Cmds }, { "auto", Auto }, { "lock", Lock },
        { "calib", Calib }, { "methods", Methods }, { "cpu", Cpu },
        { "cpulast", CpuLast }, { "probe", FrameProbe }, { "dummy", Dummy },
        { "spec", Spec }, { "loot", LootDemo },
    }
    local third = floor((inner - gap * 2) / 3)
    for i = 1, #checks do
        local key = checks[i][1]
        local text = key == "dummy" and DummyLabel() or key == "spec" and SpecLabel()
            or key == "loot" and LootLabel() or T("dev.chk." .. key)
        local b = Btn(frame, text, T("dev.chk." .. key .. ".tip"), checks[i][2])
        local col = (i - 1) % 3
        Put(b, pad + col * (third + gap), y - floor((i - 1) / 3) * ROW, third)
        View.btn[key] = b
    end
    return y - floor((#checks + 2) / 3) * ROW - 4
end
local function BuildAnim(y, inner)
    local pad, gap = Kit.Space.pad, Kit.Space.row
    Group(T("dev.g.anim"), y, inner)
    y = y - CAP
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, frame)
    if ok and m and m.SetCreature and m.SetSequence then
        model = m
        model:SetWidth(MODEL)
        model:SetHeight(MODEL)
        model:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        model:SetScript("OnShow", BossShow)
        model:SetScript("OnUpdate", AnimTick)
    end
    local x = pad + MODEL + gap
    local w = inner - MODEL - gap
    local rows = {
        { "bossPrev", -1, StepBoss }, { "bossNext", 1, StepBoss },
        { "seqPrev", -1, StepSeq }, { "seqNext", 1, StepSeq },
    }
    for i = 1, #rows do
        local r = rows[i]
        local b = Btn(frame, r[2] < 0 and "<" or ">", T("dev.anim.tip"), r[3], r[2])
        local line = floor((i - 1) / 2)
        Put(b, r[2] < 0 and x or (x + w - ARROW), y - 8 - line * (ROW + 16), ARROW)
        View.btn[r[1]] = b
    end
    bossText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Kit.Text(bossText, "text.bright")
    seqText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Kit.Text(seqText, "text.bright")
    for i, fs in ipairs({ bossText, seqText }) do
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x + ARROW + 4, y - 12 - (i - 1) * (ROW + 16))
        fs:SetWidth(w - ARROW * 2 - 8)
        fs:SetJustifyH("CENTER")
        Kit.Text(fs, "text.primary")
    end
    return y - MODEL - 6
end
local function BuildOut(y, inner)
    local pad = Kit.Space.pad
    Group(T("dev.g.out"), y, inner)
    y = y - CAP
    local h = OUT_ROWS * OUT_LINE
    local box = CreateFrame("Frame", nil, frame)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    box:SetWidth(inner)
    box:SetHeight(h)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", Wheel)
    outText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    outText:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    outText:SetWidth(inner - 12)
    outText:SetHeight(h)
    outText:SetJustifyH("LEFT")
    outText:SetJustifyV("TOP")
    outText:SetNonSpaceWrap(true)
    Kit.Text(outText, "text.secondary")
    outBar = Kit.ScrollBar(box, h)
    outBar:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    outBar.onScroll = BarScroll
    return y - h - Kit.Space.pad
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchDevTool", UIParent)
    frame:SetWidth(W)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetScript("OnShow", RecState)
    local ui = ns.GetDB().settings.ui
    frame:SetPoint(ui.devPoint or "CENTER", UIParent, ui.devPoint or "CENTER", ui.devX or 0, ui.devY or 0)
    tinsert(UISpecialFrames, "HTP_FailWatchDevTool")
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", Kit.Space.pad, -12)
    title:SetText(T("dev.title"))
    Kit.Title(title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", View.Hide)
    local inner = W - Kit.Space.pad * 2
    local y = BuildMarks(-36, inner)
    y = BuildChecks(y, inner)
    y = BuildAnim(y, inner)
    y = BuildOut(y, inner)
    frame:SetHeight(-y)
    Kit.Window(frame)
    anim = AnimList()
    BossShow()
    Render()
    RecState()
    frame:Hide()
end
function View.Show()
    if not frame then Build() end
    frame:Show()
    RecState()
end
function View.Hide()
    if frame then frame:Hide() end
    if ns.DevCalib then ns.DevCalib.Hide() end
end
function View.Toggle()
    if frame and frame:IsShown() then View.Hide() else View.Show() end
end
function View.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end
function View.Lines()
    return lines
end
function View.Anim()
    local b = anim[bi]
    return b and b.name, seq
end
function View.Cache()
    return cache
end
