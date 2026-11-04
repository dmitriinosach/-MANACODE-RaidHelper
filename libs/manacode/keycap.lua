local _, ns = ...
local ceil = math.ceil
local max = math.max
local min = math.min
local PAD = 7
local GAP = 8
local MINW = 34
local SIDE = 3
local VPAD = 3
local FACE = { 0.90, 0.88, 0.84 }
local SIDE_RGB = { 0.36, 0.35, 0.33 }
local TEXT = { 0.10, 0.09, 0.08 }
local Keycap = {}
Keycap.__index = Keycap
ns.Keycap = Keycap
local function Color(self, role, dflt)
    if self.opts.color then
        local r, g, b = self.opts.color(role)
        if r then return r, g, b end
    end
    return dflt[1], dflt[2], dflt[3]
end
local function Cross(f, level)
    local h, v = f:CreateTexture(nil, level), f:CreateTexture(nil, level)
    h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
    h:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
    v:SetPoint("TOPLEFT", f, "TOPLEFT", 1, 0)
    v:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 0)
    return { h, v }
end
local function Tone(self, f, r, g, b)
    if f.mcCross then
        for i = 1, #f.mcCross do f.mcCross[i]:SetTexture(r, g, b, 1) end
        return
    end
    local e = self.opts.edge or 1
    f:SetBackdropColor(r, g, b, 1)
    f:SetBackdropBorderColor(min(1, r / e), min(1, g / e), min(1, b / e), 1)
end
local function Build(self)
    local box = CreateFrame("Frame", nil, self.parent)
    local face = CreateFrame("Frame", nil, box)
    local bd = self.opts.backdrop
    if type(bd) == "function" then bd = bd() end
    if bd then
        box:SetBackdrop(bd)
        face:SetBackdrop(bd)
    else
        box.mcCross = Cross(box, "BACKGROUND")
        face.mcCross = Cross(face, "BORDER")
    end
    face:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    face:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, self.opts.side or SIDE)
    return { box = box, face = face, label = face:CreateFontString(nil, "OVERLAY"), w = 0, h = 0, on = false }
end
function Keycap.New(parent, opts)
    opts = opts or {}
    return setmetatable({ parent = parent, opts = opts, gap = opts.gap or GAP, list = {}, top = 0 }, Keycap)
end
function Keycap:Draw(i, text)
    local k = self.list[i]
    if not k then
        k = Build(self)
        self.list[i] = k
        if i > self.top then self.top = i end
    end
    local level = self.parent:GetFrameLevel()
    k.box:SetFrameLevel(level + 1)
    k.face:SetFrameLevel(level + 2)
    Tone(self, k.box, Color(self, "side", SIDE_RGB))
    Tone(self, k.face, Color(self, "face", FACE))
    local fs = k.label
    if self.opts.text then
        self.opts.text(fs, text)
    else
        fs:SetFontObject(GameFontNormalSmall)
        fs:SetText(text)
    end
    fs:SetTextColor(Color(self, "text", TEXT))
    fs:SetShadowOffset(0, 0)
    fs:SetShadowColor(0, 0, 0, 0)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", k.face, "CENTER", 0, 0)
    fs:Show()
    local pad, vpad = self.opts.pad or PAD, self.opts.vpad or VPAD
    k.w = max(self.opts.minW or MINW, ceil(fs:GetStringWidth() or 0) + pad * 2)
    k.h = ceil(fs:GetStringHeight() or 0) + vpad * 2 + (self.opts.side or SIDE)
    k.box:SetWidth(k.w)
    k.box:SetHeight(k.h)
    k.box:Show()
    k.on = true
    return k
end
function Keycap:Hide(i)
    local k = self.list[i]
    if k then
        k.box:Hide()
        k.on = false
    end
end
function Keycap:HideFrom(from)
    for i = from, self.top do self:Hide(i) end
end
function Keycap:Column(n)
    local w = 0
    local last = min(n, self.top)
    for i = 1, last do
        local k = self.list[i]
        if k and k.on and k.w > w then w = k.w end
    end
    for i = 1, last do
        local k = self.list[i]
        if k and k.on then k.box:SetWidth(w) end
    end
    return w
end
