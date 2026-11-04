local _, ns = ...
local Kit = ns.Kit
local About = {}
ns.About = About
local ABOUT = {
    titleKey = "about.title",
    lineKeys = { "about.line1", "about.line3" },
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
local ART = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground"
local ICONS = {
    release = "Interface\\Icons\\INV_Crate_02",
    tool = "Interface\\Icons\\INV_Gizmo_02",
    discord = "Interface\\Icons\\INV_Misc_GroupLooking",
    site = "Interface\\Icons\\INV_Misc_Map_01",
    mirror = "Interface\\Icons\\INV_Misc_Book_09",
}
local PAD = 20
local GAP = 10
local BTN_GAP = 6
local BTN_PAD = 12
local ICON_GAP = 5
local CARD_IN = 11
local CARD_GAP = 10
local SMALL = "GameFontHighlightSmall"
local BTN_FONT = "GameFontNormalSmall"
local TITLE_FONT = "GameFontNormalHuge"
local NAME_FONT = "GameFontNormal"
local CHAR_FONT = "GameFontHighlight"
local D = { W = 520, BTN_H = 24, FIELD_H = 24, ICON = 14, CHAR = 16, KEY_W = 46, CARD_W = 240 }
local function Dims()
    local k = Kit.FontScale(SMALL, true)
    D.W = math.floor(520 * k + 0.5)
    D.KEY_W = math.floor(46 * k + 0.5)
    D.BTN_H = Kit.GrowH(24, BTN_FONT)
    D.FIELD_H = Kit.GrowH(24, SMALL)
    D.ICON = Kit.FontGrow(14, BTN_FONT)
    D.CHAR = Kit.FontGrow(16, CHAR_FONT)
    D.CARD_W = math.floor((D.W - PAD * 2 - CARD_GAP) / 2)
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
local function SetLink(e, url, tipTitle, tipKey)
    e.url = url
    e.tipTitle = tipTitle
    e.tip = ns.T(tipKey or "about.tip.link")
    e:SetValue(url)
    e:SetCursorPosition(0)
end
local function LinkField(parent, url, height, tipTitle, tipKey)
    local e = Kit.Edit(parent)
    Kit.Bind(e, SMALL)
    Kit.AutoH(e, SMALL)
    e:SetHeight(height)
    SetLink(e, url, tipTitle, tipKey)
    e.onChange = function()
        if e:GetText() ~= e.url then e:SetValue(e.url) end
    end
    e:HookScript("OnEditFocusGained", Select)
    e:HookScript("OnEditFocusLost", Unselect)
    local key = Kit.Str(e, "GameFontNormalSmall")
    key:SetPoint("RIGHT", e, "RIGHT", -7, 0)
    key:SetText(ns.T("about.copy"))
    Kit.Text(key, "text.muted")
    e.key = key
    return e
end
About.LinkField = LinkField
local function Pick(link, focus)
    frame.pick = link
    SetLink(frame.field, link.url, link.label, link.tipKey)
    for _, r in ipairs(frame.rows) do r.button:SetActive(r == link) end
    for _, t in ipairs(frame.tiles) do
        t.lit = t.link == link
        t.paint(t)
    end
    if focus then frame.field:SetFocus() end
end
About.Pick = Pick
local function LinkClick(self)
    Pick(self.link, true)
end
local function Loc(a)
    return a[ns.lang] or a.enUS or a.ruRU or ""
end
function About.Installed(folder)
    local _, _, _, _, _, reason = GetAddOnInfo(folder)
    return reason ~= "MISSING"
end
local function PaintTile(t)
    local g = Kit.Theme().about.card
    Kit.Backdrop(t.plate, g, t.lit and g.borderOn or t.hover and g.borderHover or g.border)
end
local function TileEnter(self)
    self.tile.hover = true
    PaintTile(self.tile)
    Kit.TipShow(self)
end
local function TileLeave(self)
    self.tile.hover = nil
    PaintTile(self.tile)
    Kit.TipHide()
end
local function TileClick(self)
    Kit.Sound()
    Pick(self.tile.link, true)
end
local function MakeTile(a)
    local p = CreateFrame("Button", nil, frame)
    local t = { addon = a, plate = p, paint = PaintTile }
    p.tile = t
    p.tipTitle = Loc(a.name)
    p.tip = a.url
    p:SetScript("OnEnter", TileEnter)
    p:SetScript("OnLeave", TileLeave)
    p:SetScript("OnClick", TileClick)
    t.state = Kit.Str(p, SMALL)
    t.state:SetJustifyH("RIGHT")
    t.state:SetWordWrap(false)
    t.name = Kit.Str(p, NAME_FONT)
    t.name:SetJustifyH("LEFT")
    t.name:SetWordWrap(false)
    t.name:SetText(Loc(a.name))
    Kit.Text(t.name, "text.title")
    t.desc = Kit.Str(p, SMALL)
    t.desc:SetJustifyH("LEFT")
    t.desc:SetJustifyV("TOP")
    t.desc:SetText(Loc(a.desc))
    Kit.Text(t.desc, "text.secondary")
    t.link = { label = Loc(a.name), url = a.url, tile = t }
    PaintTile(t)
    return t
end
local function Header(y)
    local w = D.W - PAD * 2
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.title:SetWidth(w - 24)
    y = y + Kit.GrowH(24, TITLE_FONT)
    frame.ver:ClearAllPoints()
    frame.ver:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.ver:SetWidth(w)
    y = y + frame.ver:GetStringHeight() + GAP + 2
    for i, fs in ipairs(frame.lines) do
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        fs:SetWidth(w)
        y = y + fs:GetStringHeight() + (i < #frame.lines and 4 or 0)
    end
    y = y + GAP + 4
    frame.rule:ClearAllPoints()
    frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.rule:SetWidth(w)
    return y + 1 + GAP + 4
end
local function LinkRows(y)
    local room = D.W - PAD * 2
    local want = {}
    for i, r in ipairs(frame.rows) do
        local b = r.button
        b.icon:SetWidth(D.ICON)
        b.icon:SetHeight(D.ICON)
        b.text:ClearAllPoints()
        b.text:SetPoint("CENTER", b, "CENTER", (D.ICON + ICON_GAP) / 2, 0)
        b:SetHeight(D.BTN_H)
        want[i] = math.ceil(b.text:GetStringWidth() or 0) + D.ICON + ICON_GAP + BTN_PAD * 2
    end
    local i, n = 1, #frame.rows
    while i <= n do
        local k, used = i, want[i]
        while k < n and used + BTN_GAP + want[k + 1] <= room do
            k = k + 1
            used = used + BTN_GAP + want[k]
        end
        local extra = (room - used) / (k - i + 1)
        local x = PAD
        for j = i, k do
            local b = frame.rows[j].button
            local bw = math.floor(want[j] + extra)
            if j == k then bw = PAD + room - x end
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
            x = x + bw + BTN_GAP
        end
        y = y + D.BTN_H + BTN_GAP
        i = k + 1
    end
    local e = frame.field
    e:SetTextInsets(8, D.KEY_W, 3, 3)
    e:SetHeight(D.FIELD_H)
    e:SetWidth(room)
    e:ClearAllPoints()
    e:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + 2))
    return y + 2 + D.FIELD_H + GAP * 2
end
local function Addons(y)
    if #About.ADDONS == 0 then return y end
    local w = D.W - PAD * 2
    Kit.CaptionWidth(frame.addonsHead, w)
    frame.addonsHead:ClearAllPoints()
    frame.addonsHead:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    y = y + Kit.GrowH(18, NAME_FONT) + GAP - 2
    local inner = D.CARD_W - CARD_IN * 2
    local nameH = Kit.GrowH(16, NAME_FONT)
    local descH = 0
    for _, t in ipairs(frame.tiles) do
        t.desc:SetHeight(0)
        t.desc:SetWidth(inner)
        descH = math.max(descH, t.desc:GetStringHeight() or 0)
    end
    local cardH = math.ceil(CARD_IN + nameH + 5 + descH + CARD_IN)
    for i, t in ipairs(frame.tiles) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local p = t.plate
        p:SetWidth(D.CARD_W)
        p:SetHeight(cardH)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (D.CARD_W + CARD_GAP), -(y + row * (cardH + CARD_GAP)))
        t.state:ClearAllPoints()
        t.state:SetPoint("TOPRIGHT", p, "TOPRIGHT", -CARD_IN, -CARD_IN - 2)
        t.name:ClearAllPoints()
        t.name:SetPoint("TOPLEFT", p, "TOPLEFT", CARD_IN, -CARD_IN)
        t.name:SetPoint("RIGHT", t.state, "LEFT", -8, 0)
        t.name:SetHeight(nameH)
        t.desc:ClearAllPoints()
        t.desc:SetPoint("TOPLEFT", p, "TOPLEFT", CARD_IN, -(CARD_IN + nameH + 5))
        t.desc:SetHeight(descH)
    end
    return y + math.ceil(#frame.tiles / 2) * (cardH + CARD_GAP) - CARD_GAP + GAP * 2
end
local function Footer(y)
    local ins = Kit.Theme().window.backdrop.insets
    frame.foot:ClearAllPoints()
    frame.foot:SetPoint("TOPLEFT", frame, "TOPLEFT", ins.left, -y)
    frame.foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ins.right, ins.bottom)
    frame.footLine:ClearAllPoints()
    frame.footLine:SetPoint("TOPLEFT", frame.foot, "TOPLEFT", 0, 0)
    frame.footLine:SetPoint("TOPRIGHT", frame.foot, "TOPRIGHT", 0, 0)
    local rowH = math.max(D.CHAR, Kit.GrowH(16, CHAR_FONT))
    local top = y + GAP + 2
    local mid = top + rowH / 2
    local head = frame.charsHead
    head:ClearAllPoints()
    head:SetPoint("LEFT", frame, "TOPLEFT", PAD, -mid)
    local x = PAD + math.ceil(head:GetStringWidth() or 0) + 10
    for _, ch in ipairs(frame.chars) do
        ch.icon:SetWidth(D.CHAR)
        ch.icon:SetHeight(D.CHAR)
        ch.icon:ClearAllPoints()
        ch.icon:SetPoint("LEFT", frame, "TOPLEFT", x, -mid)
        x = x + D.CHAR + 4 + math.ceil(ch.text:GetStringWidth() or 0) + 14
    end
    local bottom = top + rowH
    local server = frame.server
    if server then
        local sw = math.ceil(server:GetStringWidth() or 0)
        server:ClearAllPoints()
        if x - 14 + GAP * 2 + sw <= D.W - PAD then
            server:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD, -mid)
        else
            server:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(bottom + 4))
            bottom = bottom + 4 + server:GetStringHeight()
        end
    end
    return bottom + GAP + 2 + ins.bottom
end
local function Art(h)
    local ins = Kit.Theme().window.backdrop.insets
    local art = frame.art
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", ins.left, -ins.top)
    art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ins.right, ins.bottom)
    local w, hh = D.W - ins.left - ins.right, h - ins.top - ins.bottom
    if w <= 0 or hh <= 0 then return end
    if w < hh then
        art:SetTexCoord(0, w / hh, 0, 1)
    else
        art:SetTexCoord(0, 1, 0, hh / w)
    end
end
local function Layout()
    Dims()
    frame:SetWidth(D.W)
    local y = Header(PAD - 2)
    y = LinkRows(y)
    y = Addons(y)
    local h = Footer(y)
    frame:SetHeight(h)
    Art(h)
    Kit.ApplyDecor(frame)
end
local function AddLink(id, label, url, tipKey, icon)
    if not url or url == "" then return end
    local b = Kit.Button(frame)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetTexture(icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetText(label)
    b.icon:SetPoint("RIGHT", b.text, "LEFT", -ICON_GAP, 0)
    b.tipTitle = label
    b.tip = tipKey and ns.T(tipKey) or nil
    b.tipDim = url
    b.onClick = LinkClick
    local link = { id = id, label = label, url = url, tipKey = tipKey, button = b }
    b.link = link
    frame.rows[#frame.rows + 1] = link
end
local function Text(font, token, text)
    local fs = Kit.Str(frame, font)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    Kit.Text(fs, token)
    return fs
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
    frame.rows, frame.chars, frame.tiles, frame.lines = {}, {}, {}, {}
    frame.art = frame:CreateTexture(nil, "BORDER")
    frame.art:SetTexture(ART)
    Kit.Tint(frame.art, "about.art")
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetHeight(1)
    Kit.Paint(frame.rule, "about.line")
    frame.foot = frame:CreateTexture(nil, "ARTWORK")
    Kit.Paint(frame.foot, "about.foot")
    frame.footLine = frame:CreateTexture(nil, "OVERLAY")
    frame.footLine:SetHeight(1)
    Kit.Paint(frame.footLine, "about.line")
    local close = Kit.CloseButton(frame, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.title = Kit.Str(frame, TITLE_FONT)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.title:SetText(ns.T(ABOUT.titleKey))
    Kit.Title(frame.title)
    frame.ver = Kit.Str(frame, SMALL)
    frame.ver:SetJustifyH("LEFT")
    Kit.Text(frame.ver, "text.muted")
    frame.lines[1] = Text(CHAR_FONT, "text.primary", ns.T(ABOUT.lineKeys[1]))
    frame.lines[2] = Text(SMALL, "text.secondary", ns.T(ABOUT.lineKeys[2]))
    AddLink("release", ns.T("about.release"), ABOUT.release, "about.tip.release", ICONS.release)
    for i, t in ipairs(TOOLS) do AddLink("tool" .. i, ns.T(t.key), t.url, t.tip, ICONS.tool) end
    AddLink("discord", "Discord", ABOUT.discord, "about.tip.discord", ICONS.discord)
    AddLink("site", ns.T("about.site"), About.Site(), "about.tip.others", ICONS.site)
    for i, m in ipairs(MIRRORS) do AddLink("mirror" .. i, m.label, m.url, nil, ICONS.mirror) end
    frame.field = LinkField(frame, ABOUT.release, D.FIELD_H, ns.T("about.release"), nil)
    if #About.ADDONS > 0 then frame.addonsHead = Kit.Caption(frame, ns.T("about.others"), D.W - PAD * 2) end
    for i, a in ipairs(About.ADDONS) do frame.tiles[i] = MakeTile(a) end
    frame.charsHead = Text(SMALL, "text.muted", ns.T("about.chars"))
    for i, c in ipairs(CHARS) do
        local icon = frame:CreateTexture(nil, "OVERLAY")
        Kit.Icon.Class(icon, c.class)
        local fs = Kit.Str(frame, CHAR_FONT)
        fs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        fs:SetText(c.name)
        Kit.ClassText(fs, c.class)
        frame.chars[i] = { name = c.name, class = c.class, text = fs, icon = icon }
    end
    local server = About.Server()
    if server then frame.server = Text(SMALL, "text.muted", server) end
    Layout()
    frame:Hide()
end
Kit.OnFont(function()
    if frame then Layout() end
end)
Kit.OnTheme(function()
    if not frame then return end
    for _, t in ipairs(frame.tiles) do PaintTile(t) end
    Layout()
end)
local function Refresh()
    for _, t in ipairs(frame.tiles) do
        local folder = t.addon.folder
        local on = folder and About.Installed(folder)
        t.on = on
        t.state:SetText(folder and ns.T(on and "about.addon.on" or "about.addon.off") or "")
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
    Pick(frame.rows[1])
    Layout()
end
function About.Frame()
    return frame
end
function About.Show()
    if not frame then Build() end
    Kit.TipHide()
    Kit.Tip.Hide()
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
