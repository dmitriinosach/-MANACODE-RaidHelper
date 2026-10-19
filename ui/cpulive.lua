local _, ns = ...
local format = string.format
local concat = table.concat
local T = ns.T
local Kit = ns.Kit
local Live = ns.CpuLive
local W = 420
local LINE = 14
local CAP = 20
local CHECK = 20
local N_ADDONS = 10
local N_SPIKES = 5
local N_FRAMES = 8
local N_EVENTS = 6
local VALUE_W = 70
local FLASH = 2
local View = {}
ns.CpuLiveView = View
local frame, status, enable, check
local heads = {}
local rows = { addons = {}, frames = {}, events = {} }
local spikeLines = {}
local function Set(fs, text)
    if fs.txt ~= text then
        fs.txt = text
        fs:SetText(text)
    end
end
local function Tone(fs, token)
    if fs.tok ~= token then
        fs.tok = token
        Kit.Text(fs, token)
    end
end
local function Ms(v)
    return ns.Dec(format(v >= 10 and "%.0f" or "%.1f", v))
end
local SMALL = "GameFontHighlightSmall"
local steps = {}
local function Wide()
    return math.floor(W * Kit.FontScale(SMALL, true) + 0.5)
end
local function LineH()
    return Kit.GrowH(LINE, SMALL)
end
local function Head(key)
    local fs = Kit.Str(frame, "GameFontNormalSmall")
    fs:SetText(T(key))
    Kit.Text(fs, "text.title")
    heads[key] = fs
    steps[#steps + 1] = function(y)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", Kit.Space.pad, y)
        return y - Kit.GrowH(CAP, "GameFontNormalSmall")
    end
end
local function Rows(list, n)
    for i = 1, n do
        local l = Kit.Str(frame, SMALL)
        l:SetJustifyH("LEFT")
        local r = Kit.Str(frame, SMALL)
        r:SetJustifyH("RIGHT")
        Tone(l, "text.secondary")
        Tone(r, "text.secondary")
        list[i] = { l = l, r = r }
    end
    steps[#steps + 1] = function(y)
        local pad = Kit.Space.pad
        local line = LineH()
        local vw = math.floor(VALUE_W * Kit.FontScale(SMALL, true) + 0.5)
        for i = 1, n do
            local row = list[i]
            row.l:ClearAllPoints()
            row.l:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 8, y - (i - 1) * line)
            row.l:SetWidth(Wide() - pad * 2 - 8 - vw)
            row.r:ClearAllPoints()
            row.r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, y - (i - 1) * line)
            row.r:SetWidth(vw)
        end
        return y - n * line - 6
    end
end
local function Fill(list, data, hot, empty)
    for i = 1, #list do
        local e = data[i]
        local row = list[i]
        if e then
            Set(row.l, e.name)
            Set(row.r, Ms(e.ms))
            local tok = hot and hot[e.name] and "text.bad" or "text.secondary"
            Tone(row.l, tok)
            Tone(row.r, tok)
        else
            Set(row.l, i == 1 and empty or "")
            Set(row.r, "")
            Tone(row.l, "text.muted")
        end
    end
end
local function SpikeText(sp)
    local parts = {}
    for i = 1, #sp.addons do parts[#parts + 1] = format("%s +%s", sp.addons[i].name, Ms(sp.addons[i].ms)) end
    for i = 1, #sp.frames do parts[#parts + 1] = format(T("cpulive.frame"), sp.frames[i].name, Ms(sp.frames[i].ms)) end
    local who = #parts > 0 and concat(parts, ", ") or T("cpulive.nolua")
    return format(T("cpulive.spike"), date("%H:%M:%S"), Ms(sp.ms), who)
end
local function Render()
    if not (frame and frame:IsShown()) then return end
    local prof = Live.Profiled()
    if prof then
        enable:Hide()
        Set(status, format(T("cpulive.status"), Ms(Live.cost), Live.Frames() and Live.nFrames or 0))
    else
        enable:Show()
        Set(status, T("cpulive.noprof"))
    end
    local sp = Live.spikes[1]
    local fresh = sp and GetTime() - sp.at < FLASH
    local hot = {}
    if fresh then
        for i = 1, #sp.addons do hot[sp.addons[i].name] = true end
    end
    Fill(rows.addons, Live.addons, hot, T(prof and "cpulive.calm" or "cpulive.dash"))
    Tone(heads["cpulive.h.spikes"], fresh and "text.bad" or "text.title")
    for i = 1, N_SPIKES do
        local s = Live.spikes[i]
        local fs = spikeLines[i]
        if s then
            if not s.text then s.text = SpikeText(s) end
            Set(fs, s.text)
            Tone(fs, i == 1 and fresh and "text.bad" or "text.secondary")
        else
            Set(fs, i == 1 and T("cpulive.nospike") or "")
            Tone(fs, "text.muted")
        end
    end
    Fill(rows.frames, Live.frames, nil, T(Live.Frames() and "cpulive.calm" or "cpulive.frames.off"))
    Fill(rows.events, Live.events, nil, T(prof and "cpulive.calm" or "cpulive.dash"))
end
local function DragStop(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    local ui = ns.GetDB().settings.ui
    ui.cpuPoint, ui.cpuX, ui.cpuY = point, x, y
end
local titleFs
local function Layout()
    local pad = Kit.Space.pad
    local w = Wide()
    frame:SetWidth(w)
    titleFs:ClearAllPoints()
    titleFs:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -12)
    local sy = Kit.GrowH(34, "GameFontNormal")
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -sy)
    status:SetWidth(w - pad * 2)
    local ey = sy + Kit.GrowH(16, SMALL)
    enable:SetWidth(math.floor(200 * Kit.FontScale(SMALL, true) + 0.5))
    enable:ClearAllPoints()
    enable:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -ey)
    local y = -(ey + enable:GetHeight() + 4)
    for i = 1, #steps do y = steps[i](y) end
    frame:SetHeight(-y + pad)
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchCpuLive", UIParent)
    frame:SetWidth(W)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame.sized = true
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", DragStop)
    local ui = ns.GetDB().settings.ui
    frame:SetPoint(ui.cpuPoint or "CENTER", UIParent, ui.cpuPoint or "CENTER", ui.cpuX or 0, ui.cpuY or 0)
    tinsert(UISpecialFrames, "HTP_FailWatchCpuLive")
    titleFs = Kit.Str(frame, "GameFontNormal")
    titleFs:SetText(T("cpulive.title"))
    Kit.Title(titleFs)
    local close = Kit.CloseButton(frame, View.Hide)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    status = Kit.Str(frame, SMALL)
    status:SetJustifyH("LEFT")
    Kit.Text(status, "text.muted")
    enable = Kit.Button(frame)
    enable:SetHeight(20)
    enable.text:SetText(T("cpulive.enable"))
    enable.tip = T("cpulive.enable.tip")
    enable.onClick = function() if ns.CpuMeter then ns.CpuMeter.Set(true) end end
    Head("cpulive.h.addons")
    Rows(rows.addons, N_ADDONS)
    Head("cpulive.h.spikes")
    for i = 1, N_SPIKES do
        local fs = Kit.Str(frame, SMALL)
        fs:SetJustifyH("LEFT")
        spikeLines[i] = fs
    end
    steps[#steps + 1] = function(y)
        local pad = Kit.Space.pad
        local line = LineH()
        for i = 1, N_SPIKES do
            spikeLines[i]:ClearAllPoints()
            spikeLines[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 8, y - (i - 1) * line)
            spikeLines[i]:SetWidth(Wide() - pad * 2 - 8)
        end
        return y - N_SPIKES * line - 6
    end
    check = Kit.Check(frame)
    check:SetWidth(CHECK)
    check:SetHeight(CHECK)
    check.label:SetText(T("cpulive.frames"))
    check.tip = T("cpulive.frames.tip")
    check.tipTitle = false
    check.onToggle = function(on)
        Live.SetFrames(on)
        Render()
    end
    steps[#steps + 1] = function(y)
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", frame, "TOPLEFT", Kit.Space.pad, y)
        return y - Kit.GrowH(CHECK, SMALL) - 4
    end
    Head("cpulive.h.frames")
    Rows(rows.frames, N_FRAMES)
    Head("cpulive.h.events")
    Rows(rows.events, N_EVENTS)
    Layout()
    Kit.Window(frame)
    frame:SetScript("OnShow", function()
        Live.Start()
        Render()
    end)
    frame:SetScript("OnHide", function() Live.Stop() end)
    Live.onTick = Render
    frame:Hide()
end
Kit.OnFont(function()
    if frame then Layout() end
end)
function View.Show()
    if not frame then Build() end
    frame:Show()
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
function View.Texts()
    local out = { addons = {}, spikes = {}, frames = {}, events = {}, status = status and status.txt or "" }
    for _, k in ipairs({ "addons", "frames", "events" }) do
        for i = 1, #rows[k] do out[k][i] = (rows[k][i].l.txt or "") .. "|" .. (rows[k][i].r.txt or "") end
    end
    for i = 1, #spikeLines do out.spikes[i] = spikeLines[i].txt or "" end
    out.spikeTok = spikeLines[1] and spikeLines[1].tok
    out.addonTok = rows.addons[1] and rows.addons[1].l.tok
    return out
end
