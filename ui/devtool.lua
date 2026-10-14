local _, ns = ...
local format = string.format
local concat = table.concat
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
local CUSTOM_BTN = 130
local View = { btn = {} }
ns.DevTool = View
local frame
local recText
local outText
local outBar
local edit
local lines = {}
local offset = 0
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
local function LangMissing(out)
    local miss = ns.langMissing or {}
    if #miss == 0 then
        out[#out + 1] = T("dev.lang.ok")
        return
    end
    out[#out + 1] = format(T("dev.lang.miss"), #miss)
    for i = 1, #miss do out[#out + 1] = "  " .. miss[i] end
end
local function Auto()
    if ns.AutoRec then ns.AutoRec.DevState() end
    local out = { T("dev.out.chat") }
    LangMissing(out)
    Out(out)
end
local function Lock()
    if ns.Raid and ns.Raid.DevLock then ns.Raid.DevLock() end
    Out({ T("dev.out.chat") })
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
    for i = 1, #list do
        local d = list[i]
        local b = Btn(frame, T(d.label), T("dev.mark.tip"), Mark, d.key)
        local wide = i == #list and i % 2 == 1
        Put(b, pad + ((i - 1) % 2) * (half + gap), y - floor((i - 1) / 2) * ROW, wide and inner or half)
        View.btn[d.key] = b
    end
    y = y - floor((#list + 1) / 2) * ROW
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
        { "map", Map }, { "auto", Auto }, { "lock", Lock }, { "cpu", Cpu },
        { "cpulast", CpuLast }, { "dummy", Dummy }, { "spec", Spec }, { "loot", LootDemo },
    }
    local half = floor((inner - gap) / 2)
    for i = 1, #checks do
        local key = checks[i][1]
        local text = key == "dummy" and DummyLabel() or key == "spec" and SpecLabel()
            or key == "loot" and LootLabel() or T("dev.chk." .. key)
        local b = Btn(frame, text, T("dev.chk." .. key .. ".tip"), checks[i][2])
        Put(b, pad + ((i - 1) % 2) * (half + gap), y - floor((i - 1) / 2) * ROW, half)
        View.btn[key] = b
    end
    return y - floor((#checks + 1) / 2) * ROW - 4
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
    local close = Kit.CloseButton(frame, View.Hide)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    local inner = W - Kit.Space.pad * 2
    local y = BuildMarks(-36, inner)
    y = BuildChecks(y, inner)
    y = BuildOut(y, inner)
    frame:SetHeight(-y)
    Kit.Window(frame)
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
