local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local ceil = math.ceil
local MIN_W = 696
local MIN_H = 406
local MARGIN = 24
local GRIP = 16
local MAX_EDGE = 8
local STRIP_W = 320
local BTN_LEVEL = 4
local HEAD_H = 28
local HEAD_PAD = 8
local GROUPGAP = 8
local PARTW = 24
local PARTH = 22
local PART_INSET = 3
local HEADLEVEL = 6
local TOOL_PAD = 8
local TOOL_GAP = 4
local Size = { MIN_W = MIN_W, MIN_H = MIN_H, MARGIN = MARGIN, MAX_EDGE = MAX_EDGE }
ns.ReplaySize = Size
local Kit = ns.Kit
local st = { vw = MIN_W, vh = MIN_H, tools = {} }
local function Num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end
local function Saved()
    local iso = ns.ReplayDraw.Saved()
    if type(iso.win) ~= "table" then iso.win = {} end
    return iso.win
end
local function Screen()
    return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
end
function Size.Rim()
    return Kit.Theme().tab.join or 0
end
function Size.HeadH()
    return Kit.GrowH(HEAD_H, "GameFontNormal")
end
function Size.Edge()
    return Kit.Theme().window.pad or 0
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
    Size.Place()
end
local function Sizing()
    return st.sizer ~= nil and st.sizer:IsActive()
end
local function SizeLimits()
    local mw, mh = Limit(st.frame:GetLeft(), st.frame:GetTop())
    local ew, eh = st.extra()
    return MIN_W + ew, MIN_H + eh, mw + ew, mh + eh
end
local function ApplySize(w, h)
    local ew, eh = st.extra()
    Apply(max(w - ew, MIN_W), max(h - eh, MIN_H))
    local s = Saved()
    s.max = false
    s.w, s.h = st.vw, st.vh
    SavePlace()
    Decor()
end
local function StartSizing(_, button)
    if ns.Web or button ~= "LeftButton" or Sizing() then return end
    local s = Saved()
    if s.max then
        s.max = false
        s.w, s.h = st.vw, st.vh
        MaxLook()
    end
    Pin()
    st.sizer:Start()
end
local function StartMove()
    if ns.Web or Sizing() then return end
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
    st.sizer = ns.Sizer.New(frame, {
        limits = SizeLimits,
        apply = ApplySize,
        size = function()
            local ew, eh = st.extra()
            return st.vw + ew, st.vh + eh
        end,
        paint = function(tex, role) Kit.Paint(tex, role == "fill" and "window.gripGlow" or "window.grip", role == "fill" and 0.08 or nil) end,
        text = function(fs) Kit.Text(fs, "text.title") end,
    })
    grip.onDown = StartSizing
    grip.onUp = function() st.sizer:Finish() end
    grip:HookScript("OnHide", function() st.sizer:Cancel() end)
    st.grip = grip
    if ns.Web then grip:Hide() end
end
local function SeatParts(parts, x, w, h)
    local bar = st.title
    for i = #parts, 1, -1 do
        local b = parts[i]
        b:SetWidth(w)
        b:SetHeight(h)
        b:SetFrameLevel(bar:GetFrameLevel() + 1)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", bar, "RIGHT", -x, 0)
        x = x + w
    end
    return x
end
local function SeatTools(x, h)
    local tools = st.tools
    local seated = 0
    for i = #tools, 1, -1 do
        local b = tools[i]
        if b:IsShown() then
            local w = ceil((b.text:GetStringWidth() or 0) + TOOL_PAD * 2)
            b:SetWidth(w)
            b:SetHeight(h)
            b:SetFrameLevel(st.title:GetFrameLevel() + 1)
            b:ClearAllPoints()
            b:SetPoint("RIGHT", st.title, "RIGHT", -x, 0)
            x = x + w + (b.toolJoin and 0 or TOOL_GAP)
            seated = seated + 1
        end
    end
    return x - (seated > 0 and TOOL_GAP or 0)
end
local function Squeeze(squeezed)
    local sq = st.squeeze
    if not sq then return end
    for i = 1, #sq.list do
        if squeezed then sq.list[i]:Hide() else sq.list[i]:Show() end
    end
    if squeezed then sq.one:Show() else sq.one:Hide() end
    sq.on = squeezed
end
function Size.Place()
    local f = st.frame
    if not f then return end
    local rim, head = Size.Rim(), Size.HeadH()
    local bar = st.title
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", rim, -rim)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rim, -rim)
    bar:SetHeight(head)
    bar:SetFrameLevel(f:GetFrameLevel() + HEADLEVEL)
    local w = floor(PARTW * Kit.FontScale("GameFontNormal", true) + 0.5)
    local h = min(Kit.GrowH(PARTH, "GameFontNormal"), head - PART_INSET * 2)
    local x = SeatParts(st.winParts, PART_INSET, w, h)
    if st.prev:IsShown() then x = SeatParts(st.navParts, x + GROUPGAP, w, h) end
    local x0 = x
    if #st.tools > 0 then
        Squeeze(false)
        x = SeatTools(x0 + GROUPGAP, h)
        local room = (f:GetWidth() or 0) - rim * 2 - HEAD_PAD - x - GROUPGAP
        if st.squeeze and room < (st.caption:GetStringWidth() or 0) then
            Squeeze(true)
            x = SeatTools(x0 + GROUPGAP, h)
        end
    end
    local fs = st.caption
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", bar, "LEFT", HEAD_PAD, 0)
    fs:SetPoint("RIGHT", bar, "RIGHT", -(x + GROUPGAP), 0)
    st.rule:ClearAllPoints()
    st.rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    st.rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    st.grip:ClearAllPoints()
    st.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(4 + Size.Edge()), 4 + Size.Edge())
end
function Size.SetTitle(text)
    st.caption:SetText(text)
    Size.Place()
end
function Size.TitleText()
    return st.caption
end
function Size.Nav()
    return st.prev, st.next
end
local function NavPart(bar, label, tip, fn)
    local b = Kit.TabPart(bar)
    Kit.ButtonFont(b, "GameFontNormal")
    b:SetText(label)
    b.tipTitle = ns.T(tip)
    b.onClick = fn
    return b
end
local function BuildHead(frame, onClose, onStep)
    local bar = CreateFrame("Button", nil, frame)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", StartMove)
    bar:SetScript("OnDragStop", StopMove)
    bar:SetScript("OnDoubleClick", function() Size.Toggle() end)
    st.title = bar
    local fs = Kit.Str(bar, "GameFontNormal")
    Kit.OneLine(fs)
    Kit.Title(fs)
    st.caption = fs
    local rule = bar:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    Kit.Paint(rule, "surface.edge")
    st.rule = rule
    local fold = Kit.TabPart(bar, "fold")
    fold.tipTitle = ns.T("kit.strip.fold")
    fold.tip = ns.T("kit.strip.fold.tip")
    fold.onClick = function() Size.Fold() end
    local mx = Kit.TabPart(bar, "max")
    mx.onClick = function() Size.Toggle() end
    local close = Kit.TabPart(bar, "close")
    close.tipTitle = ns.T("kit.win.close")
    close.tip = ns.T("kit.win.close.tip")
    close.onClick = function() onClose() end
    st.winParts = { fold, mx, close }
    if ns.Web then
        mx:Hide()
        st.winParts = { fold, close }
    end
    st.foldBtn, st.maxBtn, st.close = fold, mx, close
    st.prev = NavPart(bar, "<", "fl.nav.prev", function() onStep(-1) end)
    st.next = NavPart(bar, ">", "fl.nav.next", function() onStep(1) end)
    st.navParts = { st.prev, st.next }
    MaxLook()
end
function Size.Tool(label, title, tip, fn, join)
    local b = Kit.TabPart(st.title)
    b.toolJoin = join and true or nil
    Kit.ButtonFont(b, "GameFontNormal")
    b:SetText(label)
    b.tipTitle = title
    b.tip = tip
    b.onClick = fn
    st.tools[#st.tools + 1] = b
    Size.Place()
    return b
end
function Size.Squeeze(list, one)
    st.squeeze = { list = list, one = one, on = false }
    Size.Place()
end
function Size.Bind(frame, onClose, apply, extra, onStep)
    st.frame, st.apply, st.extra = frame, apply, extra
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    BuildGrip(frame)
    BuildHead(frame, onClose, onStep or function() end)
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
    if not f or not f:IsShown() or Sizing() or not (Iso and Iso.Scene()) then return end
    if not st.strip then BuildStrip() end
    local _, playing = Iso.Now()
    local x, y = Kit.TopLeftOf(f)
    f:Hide()
    Iso.SetPlaying(playing)
    st.strip.label:SetText(ns.ReplayBar.Title(Iso.Scene().fight, true))
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
    if ns.Web or not st.frame or Sizing() then return end
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
             maxW = mw, maxH = mh, sizing = Sizing(), sizer = st.sizer, foldBtn = st.foldBtn, strip = st.strip, play = st.play,
             headH = Size.HeadH(), rim = Size.Rim(), caption = st.caption, rule = st.rule, close = st.close,
             prev = st.prev, next = st.next, winParts = st.winParts, navParts = st.navParts, tools = st.tools,
             squeezed = st.squeeze and st.squeeze.on or false }
end
