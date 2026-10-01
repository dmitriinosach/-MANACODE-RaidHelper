local _, ns = ...
local Kit = ns.Kit
local About = {}
ns.About = About
local ABOUT = {
    titleKey = "about.title",
    lineKeys = { "about.line1", "about.line2", "about.line3" },
    site = "https://wow-addons.manacode.su",
    sitePage = { ruRU = "/", other = "/en/" },
    discord = "https://discord.gg/CYnxS6R9qY",
    release = "https://github.com/dmitriinosach/-MANACODE-RaidHelper/releases",
}
local MIRRORS = {
    { label = "CurseForge", url = "" },
    { label = "WoWInterface", url = "" },
}
local CHARS = {
    { name = "Futex", class = "PRIEST" },
    { name = "Syncpool", class = "PALADIN" },
}
local SERVER = nil
SERVER = "about.server"
About.DATA = ABOUT
About.MIRRORS = MIRRORS
About.CHARS = CHARS
local W = 460
local PAD = 16
local ROW_H = 22
local ROW_X = 110
local ROW_GAP = 6
local KEY_W = 46
local ICON = 16
local frame
function About.Site()
    local page = ABOUT.sitePage[GetLocale and GetLocale() or ""] or ABOUT.sitePage.other
    return ABOUT.site .. page
end
function About.Server()
    return SERVER and ns.T(SERVER) or nil
end
local function Select(self)
    self:HighlightText()
end
local function Unselect(self)
    self:HighlightText(0, 0)
    self:SetCursorPosition(0)
end
local function CopyRow(label, url, tipKey, y)
    if not url or url == "" then return y end
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y - 5)
    fs:SetText(label)
    Kit.Text(fs, "text.title")
    local e = Kit.Edit(frame)
    e:SetFontObject(GameFontHighlightSmall)
    e:SetTextInsets(6, KEY_W, 3, 3)
    e:SetWidth(W - ROW_X - PAD)
    e:SetHeight(ROW_H)
    e:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_X, -y)
    e:SetValue(url)
    e:SetCursorPosition(0)
    e.url = url
    e.tipTitle = label
    e.tip = ns.T(tipKey or "about.tip.link")
    e.onChange = function()
        if e:GetText() ~= url then e:SetValue(url) end
    end
    e:HookScript("OnEditFocusGained", Select)
    e:HookScript("OnEditFocusLost", Unselect)
    local key = e:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    key:SetPoint("RIGHT", e, "RIGHT", -7, 0)
    key:SetText(ns.T("about.copy"))
    Kit.Text(key, "text.muted")
    frame.rows[#frame.rows + 1] = { label = label, url = url, edit = e }
    return y + ROW_H + ROW_GAP
end
local function Line(text, token, font, y)
    local fs = frame:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    fs:SetWidth(W - PAD * 2)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    Kit.Text(fs, token)
    return fs, y + (fs:GetStringHeight() or 12) + ROW_GAP
end
local function Chars(y)
    local head
    head, y = Line(ns.T("about.chars"), "text.title", "GameFontNormal", y + ROW_GAP)
    frame.charsHead = head
    local x = PAD
    for _, c in ipairs(CHARS) do
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(ICON)
        icon:SetHeight(ICON)
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
        Kit.Icon.Class(icon, c.class)
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        fs:SetText(c.name)
        Kit.ClassText(fs, c.class)
        frame.chars[#frame.chars + 1] = { name = c.name, class = c.class, text = fs, icon = icon }
        x = x + ICON + 4 + (fs:GetStringWidth() or 0) + 18
    end
    y = y + ICON + ROW_GAP
    local server = About.Server()
    if server then
        frame.server, y = Line(server, "text.secondary", "GameFontHighlightSmall", y)
    end
    return y
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchAbout", UIParent)
    frame:SetWidth(W)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    Kit.Window(frame)
    tinsert(UISpecialFrames, "HTP_FailWatchAbout")
    frame.rows, frame.chars = {}, {}
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)
    local y = 16
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.title:SetText(ns.T(ABOUT.titleKey))
    Kit.Title(frame.title)
    y = y + 28
    for _, key in ipairs(ABOUT.lineKeys) do
        local _
        _, y = Line(ns.T(key), "text.primary", "GameFontHighlightSmall", y)
    end
    y = y + 8
    frame.ver = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.ver:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.ver:SetWidth(W - PAD * 2)
    frame.ver:SetJustifyH("LEFT")
    Kit.Text(frame.ver, "text.secondary")
    y = y + 22
    y = CopyRow(ns.T("about.release"), ABOUT.release, "about.tip.release", y)
    y = CopyRow("Discord", ABOUT.discord, "about.tip.discord", y)
    y = CopyRow(ns.T("about.others"), About.Site(), "about.tip.others", y)
    for _, m in ipairs(MIRRORS) do
        if m.url and m.url ~= "" then
            if not frame.mirrors then
                frame.mirrors, y = Line(ns.T("about.mirrors"), "text.title", "GameFontNormal", y + ROW_GAP)
            end
            y = CopyRow(m.label, m.url, nil, y)
        end
    end
    y = Chars(y)
    frame:SetHeight(y + 14)
    frame:Hide()
end
local function Refresh()
    if not frame then return end
    local mine = ns.AddonVersion and ns.AddonVersion() or "?"
    local new = ns.Version and ns.Version.Newest and ns.Version.Newest()
    local newer = new and ns.Version.Compare and ns.Version.Compare(new, mine) == 1
    if newer then
        frame.ver:SetText(string.format(ns.T("about.ver.old"), mine, Kit.Hex("text.title") .. new .. "|r"))
    else
        frame.ver:SetText(string.format(ns.T("about.ver"), mine))
    end
end
function About.Frame()
    return frame
end
function About.Show()
    if not frame then Build() end
    Refresh()
    frame:Show()
end
function About.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        About.Show()
    end
end
