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
local TOOLS = {}
SERVER = "about.server"
TOOLS[1] = { key = "about.tool", tip = "about.tip.tool", url = "https://github.com/dmitriinosach/-MANACODE-Update/releases" }
About.DATA = ABOUT
About.TOOLS = TOOLS
About.MIRRORS = MIRRORS
About.CHARS = CHARS
About.ADDONS = ns.otherAddons or {}
local PAD = 16
local ROW_GAP = 6
local ICON = 16
local TILE_GAP = 8
local TILE_IN = 8
local SMALL = "GameFontHighlightSmall"
local D = { W = 460, ROW_H = 22, ROW_X = 110, KEY_W = 46, TILE_W = 212, TILE_H = 76, NAME_H = 15, DESC_H = 24, FIELD_H = 20 }
local function Dims()
    local k = Kit.FontScale(SMALL, true)
    D.W = math.floor(460 * k + 0.5)
    D.ROW_X = math.floor(110 * k + 0.5)
    D.KEY_W = math.floor(46 * k + 0.5)
    D.ROW_H = Kit.GrowH(22, SMALL)
    D.NAME_H = Kit.GrowH(15, SMALL)
    D.DESC_H = Kit.GrowH(24, SMALL)
    D.FIELD_H = Kit.GrowH(20, SMALL)
    D.TILE_W = (D.W - PAD * 2 - TILE_GAP) / 2
    D.TILE_H = 7 + D.NAME_H + D.DESC_H + D.FIELD_H + 6 + 4
end
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
local function LinkField(parent, url, height, tipTitle, tipKey)
    local e = Kit.Edit(parent)
    Kit.Bind(e, SMALL)
    Kit.AutoH(e, SMALL)
    e:SetHeight(height)
    e:SetValue(url)
    e:SetCursorPosition(0)
    e.url = url
    e.tipTitle = tipTitle
    e.tip = ns.T(tipKey or "about.tip.link")
    e.onChange = function()
        if e:GetText() ~= url then e:SetValue(url) end
    end
    e:HookScript("OnEditFocusGained", Select)
    e:HookScript("OnEditFocusLost", Unselect)
    local key = Kit.Str(e, "GameFontNormalSmall")
    key:SetPoint("RIGHT", e, "RIGHT", -7, 0)
    key:SetText(ns.T("about.copy"))
    Kit.Text(key, "text.muted")
    return e
end
local function Part(id, make)
    local p = frame.parts[id]
    if not p then
        p = make()
        frame.parts[id] = p
    end
    return p
end
local function CopyRow(id, label, url, tipKey, y)
    if not url or url == "" then return y end
    local p = Part(id, function()
        local fs = Kit.Str(frame, "GameFontNormalSmall")
        fs:SetText(label)
        Kit.Text(fs, "text.title")
        local e = LinkField(frame, url, 22, label, tipKey)
        frame.rows[#frame.rows + 1] = { label = label, url = url, edit = e }
        return { fs = fs, e = e }
    end)
    p.fs:ClearAllPoints()
    p.fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y - 5 - (D.ROW_H - 22) / 2)
    p.e:SetTextInsets(6, D.KEY_W, 3, 3)
    p.e:SetWidth(D.W - D.ROW_X - PAD)
    p.e:ClearAllPoints()
    p.e:SetPoint("TOPLEFT", frame, "TOPLEFT", D.ROW_X, -y)
    return y + D.ROW_H + ROW_GAP
end
local function Line(id, text, token, font, y)
    local p = Part(id, function()
        local fs = Kit.Str(frame, font)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        Kit.Text(fs, token)
        return { fs = fs }
    end)
    local fs = p.fs
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    fs:SetWidth(D.W - PAD * 2)
    return fs, y + (fs:GetStringHeight() or 12) + ROW_GAP
end
local function Loc(t)
    return t[ns.lang] or t.enUS or t.ruRU or ""
end
function About.Installed(folder)
    local _, _, _, _, _, reason = GetAddOnInfo(folder)
    return reason ~= "MISSING"
end
local function MakeTile(a)
    local p = Kit.Plate(frame)
    local state = Kit.Str(p, SMALL)
    state:SetJustifyH("RIGHT")
    local name = Kit.Str(p, "GameFontNormalSmall")
    name:SetJustifyH("LEFT")
    name:SetText(Loc(a.name))
    Kit.Text(name, "text.title")
    local desc = Kit.Str(p, SMALL)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetText(Loc(a.desc))
    Kit.Text(desc, "text.secondary")
    local e = LinkField(p, a.url, 20, Loc(a.name), nil)
    return { addon = a, plate = p, name = name, desc = desc, state = state, edit = e }
end
local function PlaceTile(t, x, y)
    local p = t.plate
    p:SetWidth(D.TILE_W)
    p:SetHeight(D.TILE_H)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    t.state:ClearAllPoints()
    t.state:SetPoint("TOPRIGHT", p, "TOPRIGHT", -TILE_IN, -7)
    t.name:ClearAllPoints()
    t.name:SetPoint("TOPLEFT", p, "TOPLEFT", TILE_IN, -7)
    t.name:SetPoint("RIGHT", t.state, "LEFT", -6, 0)
    t.desc:ClearAllPoints()
    t.desc:SetPoint("TOPLEFT", p, "TOPLEFT", TILE_IN, -(7 + D.NAME_H))
    t.desc:SetWidth(D.TILE_W - TILE_IN * 2)
    t.desc:SetHeight(D.DESC_H)
    t.edit:SetTextInsets(6, D.KEY_W, 3, 3)
    t.edit:SetWidth(D.TILE_W - 12)
    t.edit:ClearAllPoints()
    t.edit:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 6, 6)
end
local function Addons(y)
    if #About.ADDONS == 0 then return y end
    if not frame.addonsHead then
        frame.addonsHead = Kit.Caption(frame, ns.T("about.others"), D.W - PAD * 2)
    end
    Kit.CaptionWidth(frame.addonsHead, D.W - PAD * 2)
    frame.addonsHead:ClearAllPoints()
    frame.addonsHead:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y - ROW_GAP)
    y = y + ROW_GAP + Kit.GrowH(20, "GameFontNormal")
    for i, a in ipairs(About.ADDONS) do
        if not frame.tiles[i] then frame.tiles[i] = MakeTile(a) end
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        PlaceTile(frame.tiles[i], PAD + col * (D.TILE_W + TILE_GAP), y + row * (D.TILE_H + TILE_GAP))
    end
    return y + math.ceil(#About.ADDONS / 2) * (D.TILE_H + TILE_GAP) - TILE_GAP + ROW_GAP
end
local function Chars(y)
    local head
    head, y = Line("chars", ns.T("about.chars"), "text.title", "GameFontNormal", y + ROW_GAP)
    frame.charsHead = head
    local x = PAD
    for i, c in ipairs(CHARS) do
        local ch = frame.chars[i]
        if not ch then
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(ICON)
            icon:SetHeight(ICON)
            Kit.Icon.Class(icon, c.class)
            local fs = Kit.Str(frame, "GameFontHighlight")
            fs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            fs:SetText(c.name)
            Kit.ClassText(fs, c.class)
            ch = { name = c.name, class = c.class, text = fs, icon = icon }
            frame.chars[i] = ch
        end
        ch.icon:ClearAllPoints()
        ch.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
        x = x + ICON + 4 + (ch.text:GetStringWidth() or 0) + 18
    end
    y = y + math.max(ICON, Kit.GrowH(ICON, "GameFontHighlight")) + ROW_GAP
    local server = About.Server()
    if server then
        frame.server, y = Line("server", server, "text.secondary", SMALL, y)
    end
    return y
end
local function Layout()
    Dims()
    frame:SetWidth(D.W)
    local y = 16
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    y = y + Kit.GrowH(28, "GameFontNormalLarge")
    for i, key in ipairs(ABOUT.lineKeys) do
        local _
        _, y = Line("line" .. i, ns.T(key), "text.primary", SMALL, y)
    end
    y = y + 8
    frame.ver:ClearAllPoints()
    frame.ver:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.ver:SetWidth(D.W - PAD * 2)
    y = y + Kit.GrowH(22, SMALL)
    y = CopyRow("release", ns.T("about.release"), ABOUT.release, "about.tip.release", y)
    for i, t in ipairs(TOOLS) do y = CopyRow("tool" .. i, ns.T(t.key), t.url, t.tip, y) end
    y = CopyRow("discord", "Discord", ABOUT.discord, "about.tip.discord", y)
    y = CopyRow("site", ns.T("about.site"), About.Site(), "about.tip.others", y)
    local headed = false
    for i, m in ipairs(MIRRORS) do
        if m.url and m.url ~= "" then
            if not headed then
                headed = true
                frame.mirrors, y = Line("mirrors", ns.T("about.mirrors"), "text.title", "GameFontNormal", y + ROW_GAP)
            end
            y = CopyRow("mirror" .. i, m.label, m.url, nil, y)
        end
    end
    y = Addons(y)
    y = Chars(y)
    frame:SetHeight(y + 14)
end
local function Build()
    frame = CreateFrame("Frame", "HTP_FailWatchAbout", UIParent)
    frame:SetWidth(D.W)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.sized = true
    Kit.Window(frame)
    tinsert(UISpecialFrames, "HTP_FailWatchAbout")
    frame.rows, frame.chars, frame.tiles, frame.parts = {}, {}, {}, {}
    local close = Kit.CloseButton(frame, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.title = Kit.Str(frame, "GameFontNormalLarge")
    frame.title:SetText(ns.T(ABOUT.titleKey))
    Kit.Title(frame.title)
    frame.ver = Kit.Str(frame, SMALL)
    frame.ver:SetJustifyH("LEFT")
    Kit.Text(frame.ver, "text.secondary")
    Layout()
    frame:Hide()
end
Kit.OnFont(function()
    if frame then Layout() end
end)
local function Refresh()
    if not frame then return end
    for _, t in ipairs(frame.tiles) do
        local on = About.Installed(t.addon.folder)
        t.on = on
        t.state:SetText(ns.T(on and "about.addon.on" or "about.addon.off"))
        Kit.Text(t.state, on and "text.good" or "text.muted")
    end
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
