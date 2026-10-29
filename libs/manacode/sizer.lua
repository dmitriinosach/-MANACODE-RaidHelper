local _, ns = ...
local floor = math.floor
local format = string.format
local max = math.max
local min = math.min
local EDGE = 2
local LABEL_X = -28
local LABEL_Y = 14
local FILL = { 1, 0.82, 0, 0.08 }
local LINE = { 1, 0.82, 0, 0.9 }
local Sizer = {}
Sizer.__index = Sizer
ns.Sizer = Sizer
local function Solid(tex, c)
    tex:SetTexture(c[1], c[2], c[3], c[4])
end
local function Cursor(self)
    local x, y = GetCursorPosition()
    local k = self.frame:GetEffectiveScale()
    if not k or k <= 0 then return x, y end
    return x / k, y / k
end
local function Measure(self)
    local x, y = Cursor(self)
    local w = min(max(floor(self.w0 + x - self.x0 + 0.5), self.minW), self.maxW)
    local h = min(max(floor(self.h0 + self.y0 - y + 0.5), self.minH), self.maxH)
    if self.opts.snap then w, h = self.opts.snap(w, h) end
    return w, h
end
local function Draw(self, w, h)
    if w == self.w and h == self.h then return end
    self.w, self.h = w, h
    self.outline:SetWidth(w)
    self.outline:SetHeight(h)
    self.label:SetText(self.opts.label and self.opts.label(w, h) or format("%d x %d", w, h))
end
local function Follow(outline)
    local self = outline.mcSizer
    if not IsMouseButtonDown("LeftButton") then
        self:Finish()
        return
    end
    Draw(self, Measure(self))
end
local function Layer(self, layer, role)
    local tex = layer:CreateTexture(nil, role == "fill" and "BACKGROUND" or "BORDER")
    if self.opts.paint then self.opts.paint(tex, role) else Solid(tex, role == "fill" and FILL or LINE) end
    return tex
end
local function Build(self)
    local o = CreateFrame("Frame", nil, self.frame)
    o.mcSizer = self
    o:SetFrameStrata("FULLSCREEN_DIALOG")
    o:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    o:Hide()
    local fill = Layer(self, o, "fill")
    fill:SetAllPoints(o)
    local top, bottom = Layer(self, o, "edge"), Layer(self, o, "edge")
    local left, right = Layer(self, o, "edge"), Layer(self, o, "edge")
    top:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, 0)
    top:SetHeight(EDGE)
    bottom:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(EDGE)
    left:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
    left:SetWidth(EDGE)
    right:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(EDGE)
    local label = o:CreateFontString(nil, "OVERLAY", self.opts.font or "GameFontNormalLarge")
    label:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", LABEL_X, LABEL_Y)
    if self.opts.text then self.opts.text(label) end
    self.outline, self.label = o, label
end
function Sizer.New(frame, opts)
    local self = setmetatable({ frame = frame, opts = opts, active = false }, Sizer)
    Build(self)
    return self
end
function Sizer:Start()
    if self.active then return false end
    self.minW, self.minH, self.maxW, self.maxH = self.opts.limits()
    self.maxW, self.maxH = max(self.minW, self.maxW), max(self.minH, self.maxH)
    self.x0, self.y0 = Cursor(self)
    if self.opts.size then
        self.w0, self.h0 = self.opts.size()
    else
        self.w0, self.h0 = self.frame:GetWidth(), self.frame:GetHeight()
    end
    self.w, self.h = nil, nil
    self.active = true
    Draw(self, Measure(self))
    self.outline:SetScript("OnUpdate", Follow)
    self.outline:Show()
    return true
end
function Sizer:Finish()
    if not self.active then return end
    local w, h = Measure(self)
    self:Cancel()
    if w ~= floor(self.w0 + 0.5) or h ~= floor(self.h0 + 0.5) then self.opts.apply(w, h) end
end
function Sizer:Cancel()
    self.active = false
    self.outline:SetScript("OnUpdate", nil)
    self.outline:Hide()
end
function Sizer:IsActive()
    return self.active
end
