local _, ns = ...
local floor = math.floor
local format = string.format
local max = math.max
local min = math.min
local MIN_W = 696
local MIN_H = 420
local MARGIN = 24
local GRIP = 16
local MAX_EDGE = 8
local BTN = 20
local CLOSE = 28
local CLOSE_EDGE = 5
local SIDE = 12
local BTN_GAP = 2
local CAPTION_GAP = 8
local STRIP_W = 320
local TITLE_LEVEL = 2
local BTN_LEVEL = 4
local Size = { MIN_W = MIN_W, MIN_H = MIN_H, MARGIN = MARGIN, MAX_EDGE = MAX_EDGE }
ns.ReplaySize = Size
local Kit = ns.Kit
local st = { vw = MIN_W, vh = MIN_H, sizing = false, head = 0 }
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
local function Limit(left, top, edge)
    edge = edge or MARGIN
    local pw, ph = Screen()
    local ew, eh = st.extra()
    local w = pw - edge - (left or edge) - ew
    local h = (top or (ph - edge)) - edge - eh
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
    Kit.MaxLook(b, Saved().max == true)
end
local function SavePlace()
    local s = Saved()
    if s.max then return end
    local f = st.frame
    s.x, s.y = f:GetLeft(), f:GetTop()
end
local function Maximize()
    local vw, vh = Limit(nil, nil, MAX_EDGE)
    Apply(vw, vh)
    local f = st.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", MAX_EDGE, -MAX_EDGE)
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
    local s = Saved()
    if s.max then
        s.max = false
        s.w, s.h = st.vw, st.vh
        MaxLook()
    end
    st.frame:StartMoving()
end
local function StopMove()
    local f = st.frame
    f:StopMovingOrSizing()
    f:SetUserPlaced(false)
    SavePlace()
end
local function BuildGrip(frame)
    local grip = Kit.Grip(frame, GRIP)
    grip:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    grip.tip = ns.T("iso.tip.grip")
    grip.tipTitle = false
    grip.tipAnchor = "ANCHOR_TOP"
    grip.onDown = StartSizing
    grip.onUp = function(self)
        if not st.sizing then return end
        Sizing(self)
        if st.sizing then StopSizing() end
    end
    grip:SetScript("OnUpdate", ns.Prof.Wrap("ui.iso", Sizing))
    st.grip = grip
end
function Size.Edge()
    return Kit.Theme().window.pad or 0
end
function Size.Place()
    local f = st.frame
    if not f then return end
    local e = Size.Edge()
    local y = -(e + st.head / 2)
    st.close:ClearAllPoints()
    st.close:SetPoint("RIGHT", f, "TOPRIGHT", -(e + SIDE - CLOSE_EDGE), y)
    st.maxBtn:ClearAllPoints()
    st.maxBtn:SetPoint("RIGHT", st.close, "LEFT", -BTN_GAP, 0)
    st.foldBtn:ClearAllPoints()
    st.foldBtn:SetPoint("RIGHT", st.maxBtn, "LEFT", -BTN_GAP, 0)
    st.title:SetHeight(st.head + e)
    if st.caption then
        st.caption:ClearAllPoints()
        st.caption:SetPoint("LEFT", f, "TOPLEFT", e + SIDE, y)
        st.caption:SetPoint("RIGHT", st.foldBtn, "LEFT", -CAPTION_GAP, 0)
    end
    st.grip:ClearAllPoints()
    st.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(4 + e), 4 + e)
end
local function BuildTitle(frame, close)
    close:SetWidth(CLOSE)
    close:SetHeight(CLOSE)
    close:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    st.close = close
    local b = Kit.MaxButton(frame)
    b:SetWidth(BTN)
    b:SetHeight(BTN)
    b:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    b.onClick = function() Size.Toggle() end
    st.maxBtn = b
    local fold = Kit.FoldButton(frame, false)
    fold:SetWidth(BTN)
    fold:SetHeight(BTN)
    fold:SetFrameLevel(frame:GetFrameLevel() + BTN_LEVEL)
    fold.onClick = function() Size.Fold() end
    st.foldBtn = fold
    local title = CreateFrame("Button", nil, frame)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", fold, "LEFT", 0, 0)
    title:SetFrameLevel(frame:GetFrameLevel() + TITLE_LEVEL)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", StartMove)
    title:SetScript("OnDragStop", StopMove)
    title:SetScript("OnDoubleClick", function() Size.Toggle() end)
    st.title = title
    MaxLook()
end
function Size.Bind(frame, close, head, apply, extra, caption)
    st.frame, st.apply, st.extra = frame, apply, extra
    st.head, st.caption = head, caption
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    BuildGrip(frame)
    BuildTitle(frame, close)
    Size.Place()
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
local function StripPlace()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    if type(settings.iso.strip) ~= "table" then settings.iso.strip = {} end
    return settings.iso.strip
end
local function PaintStrip()
    local s = st.strip
    local playing, sec = ns.ReplayBar.Now()
    if playing == nil then
        Kit.StripValue(s, "")
        st.shownSec, st.shownPlay = nil, nil
        return
    end
    if sec ~= st.shownSec then
        st.shownSec = sec
        Kit.StripValue(s, ns.ReplayBar.ClockText(sec))
    end
    if playing ~= st.shownPlay then
        st.shownPlay = playing
        local tex, tip = ns.ReplayBar.PlayLook(playing)
        st.play.icon:SetTexture(tex)
        st.play.tipTitle = tip
        if st.play.hovered then Kit.TipShow(st.play) end
    end
end
local function StripTick(_, elapsed)
    ns.ReplayBar.Advance(elapsed)
    PaintStrip()
end
local function DropStrip()
    if st.strip then st.strip:Hide() end
end
local function BuildStrip()
    local s = Kit.Strip({
        name = "HTP_FailWatchReplayIsoBar",
        width = STRIP_W,
        strata = "DIALOG",
        place = StripPlace,
        onRestore = function() Size.Unfold() end,
        onClose = function()
            DropStrip()
            ns.ReplayIso.Hide()
        end,
    })
    st.play = Kit.StripButton(s, ns.ReplayBar.PlayLook(false))
    st.play.onClick = function()
        ns.ReplayBar.TogglePlay()
        PaintStrip()
    end
    s:SetScript("OnUpdate", ns.Prof.Wrap("ui.iso", StripTick))
    st.strip = s
end
function Size.Fold()
    local f = st.frame
    local Iso = ns.ReplayIso
    if not f or not f:IsShown() or st.sizing or not (Iso and Iso.Scene()) then return end
    if not st.strip then BuildStrip() end
    local _, playing = Iso.Now()
    local x, y = Kit.TopLeftOf(f)
    f:Hide()
    Iso.SetPlaying(playing)
    local fight = Iso.Scene().fight
    st.strip.label:SetText(format(ns.T("iso.strip"), ns.FightList and ns.FightList.Title(fight) or ns.EncName(fight.boss)))
    st.shownSec, st.shownPlay = nil, nil
    PaintStrip()
    Kit.StripShow(st.strip, x, y)
end
function Size.Unfold()
    DropStrip()
    local Iso = ns.ReplayIso
    if Iso.Shown() then st.frame:Show() else Iso.Show() end
end
function Size.IsFolded()
    return st.strip ~= nil and st.strip:IsShown() and true or false
end
function Size.Refit()
    if not st.frame then return end
    if st.frame:IsShown() then DropStrip() end
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
             maxW = mw, maxH = mh, sizing = st.sizing, foldBtn = st.foldBtn, strip = st.strip, play = st.play }
end
