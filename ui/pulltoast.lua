local _, ns = ...
local Kit = ns.Kit
local floor = math.floor
local max = math.max
local min = math.min
local W, PAD, ICON, GAP = 360, 10, 32, 3
local IN_T, OUT_T, SLIDE, TOP_Y = 0.2, 0.4, 16, -40
local ICON_TEX = "Interface\\Icons\\Ability_Warrior_Charge"
local TITLE, SMALL = "GameFontNormal", "GameFontHighlightSmall"
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
    frame.title:SetWidth(room)
    frame.text:SetWidth(room)
    local th = frame.title:GetHeight() or 0
    if frame.text:IsShown() then th = th + GAP + (frame.text:GetHeight() or 0) end
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
local function Build()
    frame = CreateFrame("Frame", "ManaCodeRaidHelperPullToast", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
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
    frame:Hide()
end
Kit.OnFont(function()
    if frame and frame:IsShown() then Layout() end
end)
function Toast.Show(title, text)
    if not frame then Build() end
    frame.title:SetText(title)
    frame.text:SetText(text or "")
    if text then frame.text:Show() else frame.text:Hide() end
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
    if not frame then return nil, nil end
    return frame.title:GetText(), frame.text:IsShown() and frame.text:GetText() or nil
end
