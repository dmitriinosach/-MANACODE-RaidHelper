local _, ns = ...
local format = string.format
local ceil = math.ceil
local max = math.max
local min = math.min
local BODY = 64
local PAD = 7
local ICON = 40
local FRAME = 52
local GAP = 9
local BAR_H = 22
local TITLE_TOP = 6
local DESC_TOP = 27
local WHO_TOP = 44
local WHO_GAP = 3
local WHO_SEP = 12
local SHIELD = 16
local ART = "Interface\\AchievementFrame\\UI-Achievement-"
local TITLE_BAR = ART .. "Title"
local ICON_FRAME = ART .. "IconFrame"
local TINY_SHIELD = ART .. "TinyShield"
local BAR_COORD = { 0, 0.9765625, 0, 0.3125 }
local FRAME_COORD = { 0, 0.5625, 0, 0.5625 }
local TINY_COORD = { 0, 0.625, 0, 0.625 }
local Kit = ns.Kit
local Badges = ns.Badges
local View = {}
ns.AwardView = View
View.HEAD_H = 20
local function ShowLines(self)
    if self.lines then ns.Tip.Dock(self, self.lines, self.tipIcon) end
end
local function HideTip()
    ns.Tip.Hide()
end
local function Hover(f)
    f:EnableMouse(true)
    f:SetScript("OnEnter", ShowLines)
    f:SetScript("OnLeave", HideTip)
end
local function OneLine(fs)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
end
local function Coord(tex, c)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
local function Fit(fs, text, room)
    fs:SetWidth(0)
    fs:SetText(text)
    local w = min(ceil(fs:GetStringWidth() or 0) + 2, max(1, room))
    fs:SetWidth(w)
    return w
end
local function Nick(body)
    local b = CreateFrame("Frame", nil, body)
    b:SetHeight(14)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", 0, 0)
    OneLine(b.name)
    b.val = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.val:SetPoint("LEFT", b.name, "RIGHT", WHO_GAP, 0)
    OneLine(b.val)
    Kit.Text(b.val, "text.muted")
    Hover(b)
    return b
end
local function TipLines(a)
    local out = {}
    for i = 1, #(a.lines or {}) do out[i] = a.lines[i] end
    if #a.who <= a.tile then return out end
    out[#out + 1] = { kind = "head", left = format(ns.T("rsum.aw.more"), #a.who - a.tile, "") }
    for k = a.tile + 1, #a.who do
        local w = a.who[k]
        out[#out + 1] = { kind = "row", left = w.name, right = w.text, class = w.class }
    end
    return out
end
function View.Tile(parent)
    local f = CreateFrame("Frame", nil, parent)
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", 0, 0)
    body:SetHeight(BODY)
    Badges.Skin(body, Badges.style.detail)
    Hover(body)
    f.body = body
    f.frame = body:CreateTexture(nil, "OVERLAY")
    f.frame:SetTexture(ICON_FRAME)
    Coord(f.frame, FRAME_COORD)
    Kit.Tint(f.frame, "ach.art")
    f.frame:SetWidth(FRAME)
    f.frame:SetHeight(FRAME)
    f.frame:SetPoint("LEFT", body, "LEFT", PAD + (ICON - FRAME) / 2, 0)
    f.icon = body:CreateTexture(nil, "ARTWORK")
    f.icon:SetWidth(ICON)
    f.icon:SetHeight(ICON)
    f.icon:SetPoint("CENTER", f.frame, "CENTER", 0, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local left = PAD + ICON + GAP
    f.bar = body:CreateTexture(nil, "BORDER")
    f.bar:SetTexture(TITLE_BAR)
    Coord(f.bar, BAR_COORD)
    Kit.Tint(f.bar, "ach.bar")
    f.bar:SetPoint("TOPLEFT", body, "TOPLEFT", left - 4, -(TITLE_TOP - 3))
    f.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -3, -(TITLE_TOP - 3))
    f.bar:SetHeight(BAR_H)
    f.shield = CreateFrame("Frame", nil, body)
    f.shield:SetWidth(SHIELD)
    f.shield:SetHeight(SHIELD)
    f.shield:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -(TITLE_TOP + 1))
    f.shield.tex = f.shield:CreateTexture(nil, "ARTWORK")
    f.shield.tex:SetAllPoints()
    f.shield.tex:SetTexture(TINY_SHIELD)
    Coord(f.shield.tex, TINY_COORD)
    f.shield.num = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.shield.num:SetPoint("RIGHT", f.shield, "LEFT", -2, 0)
    Kit.Text(f.shield.num, "ach.points")
    f.title = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOPLEFT", body, "TOPLEFT", left, -TITLE_TOP - 2)
    OneLine(f.title)
    Kit.Text(f.title, "ach.name")
    f.desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.desc:SetPoint("TOPLEFT", body, "TOPLEFT", left, -DESC_TOP)
    OneLine(f.desc)
    Kit.Text(f.desc, "text.muted")
    f.nicks = {}
    for k = 1, ns.RaidModel.AWARD_TILE do f.nicks[k] = Nick(body) end
    f.rest = CreateFrame("Frame", nil, f)
    f.rest.text = f.rest:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.rest:Hide()
    function f.SetModel(self, a)
        self.model = a
        self.body.lines = TipLines(a)
        self.body.tipIcon = a.icon
        self.icon:SetTexture(a.icon or Kit.QMARK)
        self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        self.title:SetText(a.title)
        self.desc:SetText(a.desc)
        self.shield.num:SetText(a.badge)
        for k = 1, #self.nicks do
            local b, w = self.nicks[k], a.who[k]
            if w and k <= a.tile then
                b.name:SetText(w.name)
                Kit.ClassText(b.name, w.class)
                b.val:SetText(w.text or "")
                b.lines = w.lines
                b:Show()
            else
                b.lines = nil
                b:Hide()
            end
        end
    end
    function f.Layout(self, width)
        self:SetWidth(width)
        local a = self.model
        if not a then return BODY end
        local left = PAD + ICON + GAP
        local numW = Fit(self.shield.num, a.badge or "", width / 3)
        Fit(self.title, a.title, width - left - PAD - SHIELD - numW - 8)
        local room = max(1, width - left - PAD)
        Fit(self.desc, a.desc, room)
        local x = left
        for k = 1, #self.nicks do
            local b = self.nicks[k]
            if b:IsShown() then
                local free = max(1, left + room - x)
                if free < 30 then b:Hide() end
                local nw = Fit(b.name, b.name:GetText() or "", free)
                local vw = Fit(b.val, b.val:GetText() or "", max(1, free - nw - WHO_GAP))
                local bw = min(free, nw + ((b.val:GetText() or "") ~= "" and WHO_GAP + vw or 0))
                b:SetWidth(bw)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.body, "TOPLEFT", x, -WHO_TOP)
                x = x + bw + WHO_SEP
            end
        end
        return BODY
    end
    return f
end
function View.Head(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneLine(fs)
    Kit.Title(fs)
    fs:SetText(ns.T("rsum.awards"))
    return fs
end
