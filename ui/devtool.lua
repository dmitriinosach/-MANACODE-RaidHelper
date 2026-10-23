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
local function Mark()
    local ok, msg = ns.DevMarks.Write(edit:GetText())
    ns.Print(msg)
    Out({ msg })
    if ok then edit:SetValue("") end
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
local function LagLabel()
    return T(ns.LagFind and ns.LagFind.Running() and "dev.chk.lag.stop" or "dev.chk.lag")
end
local function LagRelabel()
    local b = View.btn.lag
    if b then
        b:SetText(LagLabel())
        b.tipTitle = LagLabel()
    end
end
local function Lag()
    local LF = ns.LagFind
    if not LF then return end
    if LF.Running() then
        LF.Stop()
    else
        LF.Start(function(lines)
            Out(lines, true)
            LagRelabel()
        end)
        local prof = ns.CpuMeter and ns.CpuMeter.Profiled()
        Out({ format(T("dev.lag.out.on"), LF.DUR), T(prof and "dev.lag.out.prof" or "lag.noprof") })
    end
    LagRelabel()
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
local SMALL = "GameFontHighlightSmall"
local parts = { caps = {}, checks = {} }
local function Group(text)
    local cap = Kit.Caption(frame, text, 100)
    parts.caps[#parts.caps + 1] = cap
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
local CHECKS = {
    { "map", Map }, { "auto", Auto }, { "lock", Lock }, { "cpu", Cpu },
    { "cpulast", CpuLast }, { "spec", Spec }, { "lag", Lag },
    { "cpulive", function() if ns.CpuLiveView then ns.CpuLiveView.Toggle() end end },
    { "ver", function() if ns.VerToast then ns.VerToast.Demo() end end },
}
local function BuildParts()
    parts.title = Kit.Str(frame, "GameFontNormal")
    parts.title:SetText(T("dev.title"))
    Kit.Title(parts.title)
    parts.close = Kit.CloseButton(frame, View.Hide)
    parts.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    Group(T("dev.g.marks"))
    recText = Kit.Str(frame, SMALL)
    recText:SetJustifyH("LEFT")
    edit = Kit.Edit(frame)
    edit:SetMaxLetters(60)
    edit.tipTitle = T("dev.mark.custom")
    edit.tip = T("dev.mark.edit.tip")
    parts.custom = Btn(frame, T("dev.mark.custom"), T("dev.mark.custom.tip"), Mark)
    View.btn.custom = parts.custom
    View.edit = edit
    Group(T("dev.g.checks"))
    for i = 1, #CHECKS do
        local key = CHECKS[i][1]
        local text = key == "spec" and SpecLabel() or key == "lag" and LagLabel() or T("dev.chk." .. key)
        local b = Btn(frame, text, T("dev.chk." .. key .. ".tip"), CHECKS[i][2])
        parts.checks[i] = b
        View.btn[key] = b
    end
    Group(T("dev.g.out"))
    local box = CreateFrame("Frame", nil, frame)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", Wheel)
    outText = Kit.Str(box, SMALL)
    outText:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    outText:SetJustifyH("LEFT")
    outText:SetJustifyV("TOP")
    outText:SetNonSpaceWrap(true)
    Kit.Text(outText, "text.secondary")
    outBar = Kit.ScrollBar(box, OUT_ROWS * OUT_LINE)
    outBar:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    outBar.onScroll = BarScroll
    parts.box = box
end
local function Layout()
    local pad, gap = Kit.Space.pad, Kit.Space.row
    local k = Kit.FontScale(SMALL, true)
    local w = floor(W * k + 0.5)
    local row, cap = Kit.GrowH(ROW, SMALL), Kit.GrowH(CAP, "GameFontNormal")
    local line = Kit.GrowH(OUT_LINE, SMALL)
    local custom = floor(CUSTOM_BTN * k + 0.5)
    local inner = w - pad * 2
    frame:SetWidth(w)
    parts.title:ClearAllPoints()
    parts.title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -12)
    local y = -Kit.GrowH(36, "GameFontNormal")
    local function Caption(i)
        local c = parts.caps[i]
        Kit.CaptionWidth(c, inner)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        y = y - cap
    end
    Caption(1)
    recText:ClearAllPoints()
    recText:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    recText:SetWidth(inner)
    y = y - Kit.GrowH(18, SMALL)
    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    edit:SetWidth(inner - custom - gap)
    Put(parts.custom, pad + inner - custom, y, custom)
    y = y - row - 4
    Caption(2)
    local half = floor((inner - gap) / 2)
    local n = #parts.checks
    for i = 1, n do
        local alone = i == n and n % 2 == 1
        Put(parts.checks[i], pad + ((i - 1) % 2) * (half + gap), y - floor((i - 1) / 2) * row, alone and inner or half)
    end
    y = y - floor((#parts.checks + 1) / 2) * row - 4
    Caption(3)
    local h = OUT_ROWS * line
    parts.box:ClearAllPoints()
    parts.box:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
    parts.box:SetWidth(inner)
    parts.box:SetHeight(h)
    outText:SetWidth(inner - 12)
    outText:SetHeight(h)
    outBar:SetHeight(h)
    y = y - h - pad
    frame:SetHeight(-y)
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchDevTool", UIParent)
    frame:SetWidth(W)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame.sized = true
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetScript("OnShow", RecState)
    local ui = ns.GetDB().settings.ui
    frame:SetPoint(ui.devPoint or "CENTER", UIParent, ui.devPoint or "CENTER", ui.devX or 0, ui.devY or 0)
    tinsert(UISpecialFrames, "HTP_FailWatchDevTool")
    BuildParts()
    Layout()
    Kit.Window(frame)
    Render()
    RecState()
    frame:Hide()
end
Kit.OnFont(function()
    if frame then
        Layout()
        Render()
    end
end)
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
