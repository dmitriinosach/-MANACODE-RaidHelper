local _, ns = ...
local Kit = ns.Kit
local floor = math.floor
local max = math.max
local format = string.format
local BAR_H = 16
local TRACK_H = 6
local THUMB_W, THUMB_H = 10, 16
local VALUE_W = 64
local LABEL_W = 200
local GAP = 10
local EPS = 0.0001
local function Snap(s, v)
    v = tonumber(v) or s.lo
    if v < s.lo then v = s.lo elseif v > s.hi then v = s.hi end
    local k = floor((v - s.lo) / s.step + 0.5)
    v = s.lo + k * s.step
    if v > s.hi then v = s.hi end
    return floor(v * 1000 + 0.5) / 1000
end
local function Show(s, v)
    local f = s.fmt
    if type(f) == "function" then return f(v) end
    if type(f) == "string" then return format(f, v) end
    if math.abs(v - floor(v)) < EPS then return format("%d", v) end
    return format("%.1f", v)
end
local function PaintThumb(s)
    local token = "slider.thumb"
    if s.off then
        token = "slider.thumbOff"
    elseif s.hot or s.dragging then
        token = "slider.thumbHot"
    end
    Kit.Paint(s.thumb, token)
end
local function Commit(s)
    if s.cur == s.committed then return end
    s.committed = s.cur
    if s.onCommit then s.onCommit(s.cur) end
end
local function OnValue(bar, raw)
    local s = bar.owner
    local v = Snap(s, raw)
    s.value:SetText(Show(s, v))
    if s.quiet or v == s.cur then return end
    s.cur = v
    if s.onChange then s.onChange(v) end
    if not s.dragging then Commit(s) end
end
local function OnDown(bar)
    local s = bar.owner
    if s.off then return end
    s.dragging = true
    PaintThumb(s)
end
local function OnUp(bar)
    local s = bar.owner
    s.dragging = nil
    PaintThumb(s)
    Commit(s)
end
local function OnEnter(f)
    local s = f.owner or f
    s.hot = true
    PaintThumb(s)
    Kit.TipShow(s)
end
local function OnLeave(f)
    local s = f.owner or f
    s.hot = nil
    PaintThumb(s)
    Kit.TipHide()
end
local function SetValue(self, v)
    v = Snap(self, v)
    self.quiet = true
    self.bar:SetValue(v)
    self.quiet = nil
    self.cur, self.committed = v, v
    self.value:SetText(Show(self, v))
end
local function GetValue(self)
    return self.cur
end
local function SetRange(self, lo, hi, step)
    self.lo, self.hi = lo, max(lo, hi)
    self.step = (step and step > 0) and step or 1
    self.quiet = true
    self.bar:SetMinMaxValues(self.lo, self.hi)
    self.bar:SetValueStep(self.step)
    self.quiet = nil
    SetValue(self, self.cur or lo)
end
local function Enable(self)
    self.off = nil
    self.bar:Enable()
    Kit.Text(self.label, "text.primary")
    Kit.Text(self.value, "text.primary")
    PaintThumb(self)
end
local function Disable(self)
    self.off = true
    self.dragging = nil
    self.bar:Disable()
    Kit.Text(self.label, "text.off")
    Kit.Text(self.value, "text.off")
    PaintThumb(self)
end
local function SetLabelWidth(self, w)
    self.label:SetWidth(w)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("LEFT", self, "LEFT", w + GAP, 0)
    self.bar:SetPoint("RIGHT", self.value, "LEFT", -GAP, 0)
end
function Kit.Slider(parent, spec)
    local s = CreateFrame("Frame", nil, parent)
    s:SetHeight(Kit.Space.ctl)
    s:EnableMouse(true)
    s:SetScript("OnEnter", OnEnter)
    s:SetScript("OnLeave", OnLeave)
    s.label = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.label:SetPoint("LEFT", s, "LEFT", 0, 0)
    s.label:SetJustifyH("LEFT")
    s.value = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.value:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    s.value:SetWidth(spec.valueW or VALUE_W)
    s.value:SetJustifyH("RIGHT")
    local bar = CreateFrame("Slider", nil, s)
    bar.owner = s
    bar:SetOrientation("HORIZONTAL")
    bar:SetHeight(BAR_H)
    bar:EnableMouseWheel(false)
    s.bar = bar
    s.track = bar:CreateTexture(nil, "BACKGROUND")
    s.track:SetHeight(TRACK_H)
    s.track:SetPoint("LEFT", bar, "LEFT", 0, 0)
    s.track:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    Kit.Paint(s.track, "slider.track")
    s.thumb = bar:CreateTexture(nil, "OVERLAY")
    s.thumb:SetWidth(THUMB_W)
    s.thumb:SetHeight(THUMB_H)
    bar:SetThumbTexture(s.thumb)
    s.fill = bar:CreateTexture(nil, "ARTWORK")
    s.fill:SetHeight(TRACK_H)
    s.fill:SetPoint("LEFT", s.track, "LEFT", 0, 0)
    s.fill:SetPoint("RIGHT", s.thumb, "CENTER", 0, 0)
    Kit.Paint(s.fill, "slider.fill")
    bar:SetScript("OnValueChanged", OnValue)
    bar:SetScript("OnMouseDown", OnDown)
    bar:SetScript("OnMouseUp", OnUp)
    bar:SetScript("OnEnter", OnEnter)
    bar:SetScript("OnLeave", OnLeave)
    s.fmt = spec.fmt
    s.cur = spec.min
    s.SetValue = SetValue
    s.GetValue = GetValue
    s.SetRange = SetRange
    s.Enable = Enable
    s.Disable = Disable
    s.SetLabelWidth = SetLabelWidth
    SetLabelWidth(s, spec.labelW or LABEL_W)
    SetRange(s, spec.min, spec.max, spec.step)
    Enable(s)
    return s
end
function Kit.SliderSnap(s, v)
    return Snap(s, v)
end
