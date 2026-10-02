local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local MIN_W = 696
local MIN_H = 420
local MARGIN = 24
local GRIP = 16
local MAX_BTN = 32
local TITLE_LEVEL = 2
local BTN_LEVEL = 4
local BIGGER = "Interface\\Buttons\\UI-Panel-BiggerButton-"
local SMALLER = "Interface\\Buttons\\UI-Panel-SmallerButton-"
local HILITE = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"
local Size = { MIN_W = MIN_W, MIN_H = MIN_H, MARGIN = MARGIN }
ns.ReplaySize = Size
local Kit = ns.Kit
local st = { vw = MIN_W, vh = MIN_H, sizing = false }
local function Num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    if type(settings.iso.win) ~= "table" then settings.iso.win = {} end
    return settings.iso.win
end
local function Cursor()
    local x, y = GetCursorPosition()
    local k = st.frame:GetEffectiveScale()
    return x / k, y / k
end
local function Screen()
    return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
end
local function Limit(left, top)
    local pw, ph = Screen()
    local ew, eh = st.extra()
    local w = pw - MARGIN - (left or MARGIN) - ew
    local h = (top or (ph - MARGIN)) - MARGIN - eh
    return max(MIN_W, floor(w)), max(MIN_H, floor(h))
end
local function Apply(vw, vh)
    st.vw, st.vh = vw, vh
    st.apply(vw, vh)
end
local function Pin()
    local f = st.frame
    local l, t = f:GetLeft(), f:GetTop()
    if l and t then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    end
    return l, t
end
local function MaxLook()
    local b = st.maxBtn
    if not b then return end
    local on = Saved().max == true
    local base = on and SMALLER or BIGGER
    b:SetNormalTexture(base .. "Up")
    b:SetPushedTexture(base .. "Down")
    b.tip = ns.T(on and "iso.tip.restore" or "iso.tip.max")
end
local function SavePlace()
    local s = Saved()
    if s.max then return end
    local f = st.frame
    s.x, s.y = f:GetLeft(), f:GetTop()
end
local function Maximize()
    local vw, vh = Limit(nil, nil)
    Apply(vw, vh)
    local f = st.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", MARGIN, -MARGIN)
end
local function Decor()
    Kit.ApplyDecor(st.frame)
    MaxLook()
end
local function StopSizing()
    st.sizing = false
    local s = Saved()
    s.max = false
    s.w, s.h = st.vw, st.vh
    SavePlace()
    Decor()
end
local function Sizing(self)
    if not st.sizing then return end
    if not IsMouseButtonDown("LeftButton") then
        StopSizing()
        return
    end
    local x, y = Cursor()
    local vw = min(max(floor(self.w0 + x - self.x0 + 0.5), MIN_W), self.mw)
    local vh = min(max(floor(self.h0 + self.y0 - y + 0.5), MIN_H), self.mh)
    if vw ~= st.vw or vh ~= st.vh then Apply(vw, vh) end
end
local function StartSizing(self, button)
    if button ~= "LeftButton" or st.sizing then return end
    local l, t = Pin()
    self.x0, self.y0 = Cursor()
    self.w0, self.h0 = st.vw, st.vh
    self.mw, self.mh = Limit(l, t)
    st.sizing = true
end
local function StartMove()
    if st.sizing then return end
    st.frame:StartMoving()
end
local function StopMove()
    local f = st.frame
    f:StopMovingOrSizing()
    f:SetUserPlaced(false)
    SavePlace()
end
local function BuildGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetWidth(GRIP)
    grip:SetHeight(GRIP)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(grip)
    tex:SetTexture(Kit.Theme().window.gripTex)
    Kit.Tint(tex, "window.grip")
    grip.tip = ns.T("iso.tip.grip")
    grip.tipTitle = false
    grip.tipAnchor = "ANCHOR_TOP"
    grip:SetScript("OnEnter", Kit.TipShow)
    grip:SetScript("OnLeave", Kit.TipHide)
    grip:SetScript("OnMouseDown", StartSizing)
    grip:SetScript("OnMouseUp", function(self)
        if not st.sizing then return end
        Sizing(self)
        if st.sizing then StopSizing() end
    end)
    grip:SetScript("OnUpdate", ns.Prof.Wrap("ui.iso", Sizing))
    st.grip = grip
end
local function BuildTitle(frame, close, head)
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(MAX_BTN)
    b:SetHeight(MAX_BTN)
    b:SetPoint("RIGHT", close, "LEFT", 8, 0)
    b:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    b:SetHighlightTexture(HILITE, "ADD")
    b.tipTitle = false
    b.tipAnchor = "ANCHOR_TOP"
    b:SetScript("OnEnter", Kit.TipShow)
    b:SetScript("OnLeave", Kit.TipHide)
    b:SetScript("OnClick", function() Size.Toggle() end)
    st.maxBtn = b
    local title = CreateFrame("Button", nil, frame)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", b, "LEFT", 0, 0)
    title:SetHeight(head)
    title:SetFrameLevel(frame:GetFrameLevel() + TITLE_LEVEL)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", StartMove)
    title:SetScript("OnDragStop", StopMove)
    title:SetScript("OnDoubleClick", function() Size.Toggle() end)
    st.title = title
    close:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    MaxLook()
end
function Size.Bind(frame, close, head, apply, extra)
    st.frame, st.apply, st.extra = frame, apply, extra
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    BuildGrip(frame)
    BuildTitle(frame, close, head)
end
function Size.Restore()
    local s = Saved()
    if s.max then
        Maximize()
    else
        local x, y = Num(s.x), Num(s.y)
        local mw, mh = Limit(x, y)
        Apply(min(max(floor(Num(s.w) or MIN_W), MIN_W), mw), min(max(floor(Num(s.h) or MIN_H), MIN_H), mh))
        local f = st.frame
        f:ClearAllPoints()
        if x and y then
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    Decor()
end
function Size.Refit()
    if not st.frame then return end
    if Saved().max then
        Maximize()
        Decor()
        return
    end
    local mw, mh = Limit(nil, nil)
    if st.vw > mw or st.vh > mh then
        Apply(min(st.vw, mw), min(st.vh, mh))
        Decor()
    end
end
function Size.Toggle()
    if not st.frame or st.sizing then return end
    local s = Saved()
    if s.max then
        s.max = false
        Size.Restore()
        return
    end
    s.w, s.h = st.vw, st.vh
    SavePlace()
    s.max = true
    Maximize()
    Decor()
end
function Size.Probe()
    local s = Saved()
    local mw, mh = Limit(nil, nil)
    return { grip = st.grip, maxBtn = st.maxBtn, title = st.title, max = s.max == true, vw = st.vw, vh = st.vh,
             maxW = mw, maxH = mh, sizing = st.sizing }
end
