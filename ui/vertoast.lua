local _, ns = ...
local Kit = ns.Kit
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local W, PAD, ICON, GAP = 360, 10, 36, 3
local LIFE, IN_T, OUT_T, SLIDE, TOP_Y = 12, 0.25, 0.4, 16, -40
local DAY = 86400
local ICON_TEX = "Interface\\Icons\\INV_Crate_04"
local TITLE, SMALL = "GameFontNormal", "GameFontHighlightSmall"
local Toast = {}
ns.VerToast = Toast
local frame
local phase, t, left = nil, 0, 0
local hover = false
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
    frame.title:SetWidth(room)
    frame.text:SetWidth(room)
    local th = (frame.title:GetHeight() or 0) + GAP + (frame.text:GetHeight() or 0)
    frame:SetHeight(max(icon, th) + PAD * 2)
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
        if hover then return end
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
local function OnClick()
    Kit.Sound("click")
    Toast.Hide()
    if ns.About then ns.About.Show() end
end
local function Build()
    frame = CreateFrame("Button", "HTP_FailWatchVerToast", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Kit.Window(frame)
    frame.back = frame:CreateTexture(nil, "BORDER")
    Kit.Paint(frame.back, "surface.shade")
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture(ICON_TEX)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.icon:SetPoint("LEFT", frame, "LEFT", PAD, 0)
    frame.back:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
    frame.title = Kit.Str(frame, TITLE)
    Kit.Title(frame.title)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", PAD, 0)
    frame.text = Kit.Str(frame, SMALL)
    Kit.Text(frame.text, "text.secondary")
    frame.text:SetJustifyH("LEFT")
    frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -GAP)
    frame:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", Step))
    frame:SetScript("OnEnter", function() hover = true end)
    frame:SetScript("OnLeave", function() hover = false end)
    frame:SetScript("OnClick", OnClick)
    frame:Hide()
end
Kit.OnFont(function()
    if frame and frame:IsShown() then Layout() end
end)
function Toast.Show(v, mine)
    if not frame then Build() end
    frame.title:SetText(format(ns.T("ver.toast.title"), v))
    frame.text:SetText(format(ns.T("ver.toast.text"), mine or "?"))
    Layout()
    phase, t, left, hover = "in", 0, LIFE, false
    frame:SetAlpha(0)
    Place(SLIDE)
    frame:Show()
    Kit.Sound("open")
end
function Toast.Hide()
    if frame and frame:IsShown() and phase ~= "out" then phase, t = "out", 0 end
end
function Toast.OnNew(v, mine)
    local s = ns.GetDB().settings
    local last, now = s.verToast, time()
    if type(last) == "table" and last.v == v and now - (tonumber(last.at) or 0) < DAY then return end
    s.verToast = { v = v, at = now }
    Toast.Show(v, mine)
end
function Toast.Demo()
    local mine = ns.Version.Mine()
    local p = mine and ns.Version.Parse(mine)
    local v = p and format("%d.%d.%d", p.major, p.minor, p.patch + 1) or "9.9.9"
    Toast.Show(v, mine)
end
function Toast.Frame()
    return frame
end
ns.Version.OnNew(Toast.OnNew)
