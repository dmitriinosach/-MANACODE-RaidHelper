local _, ns = ...
local Kit = ns.Kit
local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local W, PAD, ICON, GAP = 360, 10, 40, 2
local IN_T, OUT_T, SLIDE, TOP_Y = 0.2, 0.4, 16, -40
local BIG, SMALL = "GameFontNormalLarge", "GameFontHighlightSmall"
local Toast = {}
ns.PullToast = Toast
local frame
local phase, t, left = nil, 0, 0
local function Place(dy)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, TOP_Y + floor(dy + 0.5))
end
local function Layout()
    local k = Kit.FontScale(SMALL, true)
    local w = floor(W * k + 0.5)
    local icon = floor(ICON * k + 0.5)
    frame:SetWidth(w)
    frame.icon:SetWidth(icon)
    frame.icon:SetHeight(icon)
    frame.back:SetWidth(icon + 2)
    frame.back:SetHeight(icon + 2)
    local room = w - PAD * 3 - icon
    frame.who:SetWidth(room)
    frame.how:SetWidth(room)
    frame.timer:SetWidth(room)
    local th = (frame.who:GetHeight() or 0) + GAP + (frame.how:GetHeight() or 0)
    if frame.timer:IsShown() then th = th + GAP + (frame.timer:GetHeight() or 0) end
    local h = max(icon, th)
    frame:SetHeight(h + PAD * 2)
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD - floor((h - icon) / 2 + 0.5))
    frame.who:ClearAllPoints()
    frame.who:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD * 2 + icon, -PAD - floor((h - th) / 2 + 0.5))
end
local function Step(self, dt)
    if phase == "in" then
        t = t + dt
        local k = min(1, t / IN_T)
        local e = 1 - (1 - k) * (1 - k)
        self:SetAlpha(e)
        Place(SLIDE * (1 - e))
        if k >= 1 then phase = "hold" end
    elseif phase == "hold" then
        left = left - dt
        if left <= 0 then phase, t = "out", 0 end
    else
        t = t + dt
        local k = min(1, t / OUT_T)
        self:SetAlpha(1 - k)
        Place(SLIDE * k)
        if k >= 1 then
            phase = nil
            self:Hide()
        end
    end
end
local function Line(parent, base)
    local fs = Kit.Str(parent, base)
    fs:SetJustifyH("LEFT")
    return fs
end
local function Build()
    frame = CreateFrame("Frame", "ManaCodeRaidHelperPullToast", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    Kit.Window(frame)
    frame.back = frame:CreateTexture(nil, "BORDER")
    Kit.Paint(frame.back, "surface.shade")
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.back:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
    frame.who = Line(frame, BIG)
    Kit.OneLine(frame.who)
    frame.how = Line(frame, SMALL)
    Kit.Text(frame.how, "text.secondary")
    frame.how:SetPoint("TOPLEFT", frame.who, "BOTTOMLEFT", 0, -GAP)
    frame.timer = Line(frame, SMALL)
    Kit.Text(frame.timer, "text.secondary")
    frame.timer:SetPoint("TOPLEFT", frame.how, "BOTTOMLEFT", 0, -GAP)
    frame:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", Step))
    frame:Hide()
end
Kit.OnFont(function()
    if frame and frame:IsShown() then Layout() end
end)
function Toast.TimerLine(m)
    if not m.timer then return nil end
    if not m.early then return m.timer end
    return format(ns.T("sum.pull.line"), m.timer, Kit.Hex("text.warn") .. m.early .. "|r")
end
function Toast.Show(m)
    if not frame then Build() end
    frame.icon:SetTexture(m.icon or Kit.QMARK)
    frame.who:SetText(m.who)
    if m.class then Kit.ClassText(frame.who, m.class) else Kit.Title(frame.who) end
    frame.how:SetText(m.how)
    local timer = Toast.TimerLine(m)
    frame.timer:SetText(timer or "")
    if timer then frame.timer:Show() else frame.timer:Hide() end
    Layout()
    phase, t, left = "in", 0, ns.pullWho.toast
    frame:SetAlpha(0)
    Place(SLIDE)
    frame:Show()
end
function Toast.Shown()
    return frame ~= nil and frame:IsShown() and true or false
end
function Toast.Lines()
    if not frame then return nil, nil, nil, nil end
    return frame.who:GetText(), frame.how:GetText(), frame.timer:IsShown() and frame.timer:GetText() or nil,
        frame.icon:GetTexture()
end
