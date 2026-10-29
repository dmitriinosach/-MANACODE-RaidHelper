local _, ns = ...
local floor = math.floor
local format = string.format
local max = math.max
local min = math.min
local tsort = table.sort
local Kit = ns.Kit
local W, H = 1180, 652
local MIN_W, MIN_H = 860, 572
local TABGAP = 2
local TABPAD = 12
local TABMIN = 56
local TABTIGHT = 44
local ICONTAB = 40
local ICON = 18
local ACTPAD = 2
local GROUPGAP = 8
local PARTW = 24
local PARTH = 22
local PARTPAD = 3
local ICONPART = ICON + 12
local INSET = 6
local GRIP = 16
local MAX_EDGE = 8
local TABLEVEL = 6
local DEFAULT = "log"
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.70, 1.30, 0.05
local SCALE_EPS = 0.001
local Shell = {}
ns.Shell = Shell
local entries = {}
local order = {}
local commands = {}
local frame, strip, close, grip, pageBg, zoomOut, zoomIn, about, fold, maxBtn
local winGroup, pageGroup, viewGroup
local current
local moving
local sizer
local clampRight = 0
local rightW = 0
local note = { token = "text.warn", x = 0 }
local placed = {}
local function Placed()
    for i = 1, #placed do placed[i]() end
end
local function Saved()
    local s = ns.GetDB().settings
    if type(s.shell) ~= "table" then s.shell = {} end
    return s.shell
end
local function Label(e)
    local l = e.def.label
    if type(l) == "function" then return l() end
    return ns.T(l)
end
local function Pad()
    return Kit.Theme().window.pad or 0
end
local function TabLook()
    return Kit.Theme().tab
end
local function TabH()
    return Kit.GrowH(TabLook().h, "GameFontNormalSmall")
end
local function PartW()
    return floor(PARTW * Kit.FontScale("GameFontNormal", true) + 0.5)
end
local function Line()
    local tt = TabLook()
    return (TabH() - tt.rim) / 2
end
local function Pin()
    local l, t = frame:GetLeft(), frame:GetTop()
    if not l or not t then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
end
local function SavePlace()
    local s = Saved()
    local l, t = frame:GetLeft(), frame:GetTop()
    if l and t then
        s.point, s.rel, s.x, s.y = "TOPLEFT", "BOTTOMLEFT", l, t
    end
    s.w = floor(frame:GetWidth() + 0.5)
    s.h = floor(frame:GetHeight() + 0.5)
end
local function Clamp()
    frame:SetClampRectInsets(0, clampRight, TabH(), 0)
end
local function PageSize()
    local p = INSET + Pad()
    return frame:GetWidth() - p * 2, frame:GetHeight() - p * 2
end
local function SizePage(e)
    local w, h = PageSize()
    e.page:SetWidth(w)
    e.page:SetHeight(h)
    if e.laidW == w and e.laidH == h then return end
    e.laidW, e.laidH = w, h
    if e.def.OnSize then e.def.OnSize(e.page, w, h) end
end
local function Backing(e)
    if e.def.bare then pageBg:Hide() else pageBg:Show() end
end
local function PlaceTab(e)
    local tt = TabLook()
    local on = e.key == current or (e.def.lit ~= nil and e.def.lit == current)
    local top = TabH()
    local below = on and (INSET + Pad()) or tt.seat
    local tab = e.tab
    tab:SetHeight(top + below)
    tab:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL + (on and 1 or 0))
    tab:ClearAllPoints()
    if e.def.right then
        tab:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -e.x, -below)
    else
        tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", e.x, -below)
    end
    tab.active = on
    tab:Seat(below, (below - tt.rim) / 2, top + below)
end
local function PaintTabs()
    for i = 1, #order do
        local e = order[i]
        if e.tab then PlaceTab(e) end
        if e.part then e.part:SetActive(e.key == current or (e.def.lit ~= nil and e.def.lit == current)) end
    end
end
local function SelectNow(key)
    local e = entries[key]
    if not e then return end
    local old = current and entries[current]
    local switching = old and old ~= e and old.page and old.page:IsShown()
    if old and old ~= e and old.page then
        old.page:Hide()
        if old.def.OnHide then old.def.OnHide(old.page) end
    end
    current = key
    Saved().tab = key
    PaintTabs()
    Backing(e)
    if not e.page then
        local p = INSET + Pad()
        e.page = CreateFrame("Frame", nil, frame)
        e.page:SetPoint("TOPLEFT", p, -p)
        local w, h = PageSize()
        e.page:SetWidth(w)
        e.page:SetHeight(h)
        e.laidW, e.laidH = w, h
        e.stale = nil
        e.def.build(e.page)
    end
    e.page:Show()
    if e.stale then
        e.stale = nil
        if e.def.OnTheme then e.def.OnTheme(e.page) end
    end
    if e.def.OnShow then e.def.OnShow(e.page) end
    SizePage(e)
    if switching then Kit.FadeIn(e.page) end
end
local Select = ns.Prof.Wrap("ui.page", SelectNow)
local function TabOrder(a, b)
    if (a.def.right and true or false) ~= (b.def.right and true or false) then
        return not a.def.right
    end
    return (a.def.order or 0) < (b.def.order or 0)
end
local function SquareW()
    return max(ICONTAB, ICON + (TabLook().rim + ACTPAD) * 2)
end
local function TabWidth(e)
    local tab = e.tab
    if e.def.icon then
        tab.text:SetText("")
        tab.tipTitle = Label(e)
        return SquareW()
    end
    tab.tipTitle = false
    tab.text:SetText(Label(e))
    return max(floor(TABMIN * Kit.FontScale("GameFontNormalSmall", true) + 0.5),
        floor(tab.text:GetStringWidth() + (TabLook().rim + TABPAD) * 2))
end
local function Scale()
    local v = tonumber(Saved().scale) or 1
    if v < SCALE_MIN then return SCALE_MIN end
    if v > SCALE_MAX then return SCALE_MAX end
    return v
end
local function Screen()
    local fe, pe = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    if not (fe and pe and pw and ph) or fe <= 0 or pe <= 0 or pw <= 0 or ph <= 0 then return nil, nil end
    local k = fe / pe
    return pw / k, ph / k
end
local function MaxSize()
    local sw, sh = Screen()
    if not sw then return math.huge, math.huge end
    return max(MIN_W, floor(sw - clampRight)), max(MIN_H, floor(sh - TabH()))
end
local function KeepOnScreen()
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local sw, sh = Screen()
    if not (l and r and t and b and sw) then return end
    local dx, dy = 0, 0
    if r + clampRight > sw then dx = sw - r - clampRight end
    if l + dx < 0 then dx = -l end
    if b < 0 then dy = -b end
    if t + TabH() + dy > sh then dy = sh - t - TabH() end
    if dx == 0 and dy == 0 then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dx, b + dy)
end
local LayoutTabs
local function OnSizing()
    local e = current and entries[current]
    for _, other in pairs(entries) do
        if other.page and other ~= e then
            local w, h = PageSize()
            other.page:SetWidth(w)
            other.page:SetHeight(h)
        end
    end
    if e and e.page then SizePage(e) end
    LayoutTabs()
end
local function Maximize()
    local sw, sh = Screen()
    if not sw then return end
    local th = TabH()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", MAX_EDGE, sh - MAX_EDGE - th)
    frame:SetWidth(max(MIN_W, floor(sw - clampRight - MAX_EDGE * 2)))
    frame:SetHeight(max(MIN_H, floor(sh - th - MAX_EDGE * 2)))
    OnSizing()
    Kit.ApplyDecor(frame)
end
local function MaxLook()
    if maxBtn then Kit.MaxLook(maxBtn, Saved().max == true) end
end
local function DropMax()
    local s = Saved()
    if not s.max then return end
    s.max, s.norm = nil, nil
    MaxLook()
end
local function Fit()
    local mw, mh = MaxSize()
    if mw < math.huge then frame:SetMaxResize(mw, mh) end
    if Saved().max then
        Maximize()
        Placed()
        return
    end
    local w, h = frame:GetWidth(), frame:GetHeight()
    local nw, nh = min(max(w, MIN_W), mw), min(max(h, MIN_H), mh)
    local changed = nw ~= w or nh ~= h
    if changed then
        frame:SetWidth(nw)
        frame:SetHeight(nh)
    end
    KeepOnScreen()
    if changed then OnSizing() end
    Placed()
end
local function PaintZoom()
    if not zoomOut then return end
    local v = Scale()
    local title = format(ns.T("shell.scale.tip"), floor(v * 100 + 0.5))
    zoomOut.tipTitle, zoomIn.tipTitle = title, title
    if v <= SCALE_MIN + SCALE_EPS then zoomOut:Disable() else zoomOut:Enable() end
    if v >= SCALE_MAX - SCALE_EPS then zoomIn:Disable() else zoomIn:Enable() end
    if zoomOut.hovered then Kit.TipShow(zoomOut) end
    if zoomIn.hovered then Kit.TipShow(zoomIn) end
end
local function SetScale(v)
    v = floor(v * 100 + 0.5) / 100
    if v < SCALE_MIN then v = SCALE_MIN elseif v > SCALE_MAX then v = SCALE_MAX end
    local old = frame:GetScale() or 1
    local l, t = frame:GetLeft(), frame:GetTop()
    Saved().scale = v
    frame:SetScale(v)
    if l and t and v > 0 then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * old / v, t * old / v - frame:GetHeight())
        Fit()
        SavePlace()
    end
    PaintZoom()
    if ns.Settings and ns.Settings.Refresh then ns.Settings.Refresh() end
end
local function MakeGroup()
    local g = Kit.Tab(frame)
    g:EnableMouse(false)
    g.parts = {}
    return g
end
local function MakeAct(g, label, tip, delta, base)
    local b = Kit.TabPart(g)
    Kit.ButtonFont(b, base or "GameFontNormalLarge")
    b:SetText(ns.T(label))
    b.tip = tip and ns.T(tip) or nil
    b.onClick = function() SetScale(Scale() + delta) end
    return b
end
local fontLess
local fontMore
local function PaintFont()
    if not fontLess then return end
    local d, lo, hi = Kit.FontDelta()
    local title = format(ns.T("shell.font.tip"), d > 0 and ("+" .. d) or tostring(d))
    fontLess.tipTitle, fontMore.tipTitle = title, title
    if d <= lo then fontLess:Disable() else fontLess:Enable() end
    if d >= hi then fontMore:Disable() else fontMore:Enable() end
    if fontLess.hovered then Kit.TipShow(fontLess) end
    if fontMore.hovered then Kit.TipShow(fontMore) end
end
local function FontButtons()
    fontLess = MakeAct(viewGroup, "shell.font.less", "shell.font.less.tip", 0, "GameFontNormal")
    fontMore = MakeAct(viewGroup, "shell.font.more", "shell.font.more.tip", 0)
    fontLess.onClick = function() Kit.SetFontDelta(Kit.FontDelta() - 1) end
    fontMore.onClick = function() Kit.SetFontDelta(Kit.FontDelta() + 1) end
    Kit.OnFont(function()
        PaintFont()
        if ns.Settings and ns.Settings.Refresh then ns.Settings.Refresh() end
    end)
    PaintFont()
end
local function SeatGroup(g, x)
    local tt = TabLook()
    local inner = max(0, tt.rim - PARTPAD)
    local pw = PartW()
    local lift = (tt.seat - tt.rim) / 2
    local h = min(Kit.GrowH(PARTH, "GameFontNormal"), TabH() - tt.rim + 2)
    local px = inner
    for _, b in ipairs(g.parts) do
        local bw = b.icon and not b.glyph and max(pw, ICONPART) or pw
        b:SetWidth(bw)
        b:SetHeight(h)
        b:ClearAllPoints()
        b:SetPoint("LEFT", g, "LEFT", px, lift)
        px = px + bw
    end
    local w = px + inner
    g:SetWidth(w)
    g:SetHeight(TabH() + tt.seat)
    g:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL)
    for _, b in ipairs(g.parts) do b:SetFrameLevel(g:GetFrameLevel() + 1) end
    g:ClearAllPoints()
    g:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -x, -tt.seat)
    g:Seat(tt.seat, lift, TabH() + tt.seat)
    return x + w + TABGAP
end
local function PlaceNote()
    if not frame then return end
    local b = note.b
    if not note.text then
        if b then b:Hide() end
        return
    end
    if not b then
        b = CreateFrame("Button", nil, frame)
        b:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL)
        b.label = Kit.Str(b, "GameFontNormalSmall")
        b.label:SetAllPoints()
        b.label:SetJustifyH("LEFT")
        b:SetScript("OnEnter", Kit.TipShow)
        b:SetScript("OnLeave", Kit.TipHide)
        note.b = b
    end
    b.label:SetText(note.text)
    Kit.Text(b.label, note.token)
    b.tipTitle = note.text
    b.tip = note.tip
    b:SetHeight(TabH() - TabLook().rim)
    b:ClearAllPoints()
    b:SetPoint("LEFT", frame, "TOPLEFT", note.x + TABPAD, Line())
    b:SetPoint("RIGHT", frame, "TOPRIGHT", -(rightW + TABPAD), Line())
    b:Show()
end
function LayoutTabs()
    tsort(order, TabOrder)
    local tt = TabLook()
    local x = tt.x
    local rx = tt.x
    if winGroup then rx = SeatGroup(winGroup, rx) + GROUPGAP end
    local pages = {}
    for i = #order, 1, -1 do
        local e = order[i]
        local key, go = e.key, e.def.go
        local function Click()
            if go then
                go()
            elseif current ~= key then
                Select(key)
            end
        end
        if e.def.right and e.def.icon and not e.def.tabless then
            if not e.part then
                e.part = Kit.TabPart(pageGroup, nil, e.def.icon, ICON)
                e.part.onClick = Click
            end
            e.part.tipTitle = Label(e)
            pages[#pages + 1] = e.part
        elseif not e.tab and not e.def.tabless then
            e.tab = Kit.Tab(frame, e.def.icon, ICON)
            e.tab.onClick = Click
        end
        if e.tab then e.w = TabWidth(e) end
    end
    pageGroup.parts = pages
    if #pages > 0 then
        rx = SeatGroup(pageGroup, rx) + GROUPGAP
        pageGroup:Show()
    else
        pageGroup:Hide()
    end
    local leftIcons, leftTexts, texts = 0, 0, {}
    local tail = rx
    for i = 1, #order do
        local e = order[i]
        if e.tab and e.def.right then
            e.tab:SetWidth(e.w)
            e.x = rx
            rx = rx + e.w + TABGAP
        elseif e.tab then
            if e.def.icon then
                leftIcons = leftIcons + e.w + TABGAP
            else
                leftTexts = leftTexts + 1
                texts[#texts + 1] = e.w
            end
        end
    end
    if rx ~= tail then rx = rx - TABGAP + GROUPGAP end
    rx = SeatGroup(viewGroup, rx)
    local cap = math.huge
    local frameW = frame:GetWidth() or 0
    if leftTexts > 0 and frameW > 0 then
        local room = floor(frameW - x - rx - GROUPGAP - leftIcons - leftTexts * TABGAP)
        tsort(texts)
        local used = 0
        for k = 1, #texts do
            local share = floor((room - used) / (#texts - k + 1))
            if texts[k] > share then
                cap = max(TABTIGHT, share)
                break
            end
            used = used + texts[k]
        end
    end
    for i = 1, #order do
        local e = order[i]
        if e.tab and not e.def.right then
            local w = e.def.icon and e.w or min(e.w, cap)
            e.tab:SetWidth(w)
            if not e.def.icon then
                e.tab.text:SetWidth(max(1, w - TabLook().rim * 2 - 4))
                e.tab.text:SetWordWrap(false)
            end
            e.x = x
            x = x + w + TABGAP
        end
    end
    rightW = rx
    note.x = x
    PlaceNote()
    PaintTabs()
end
local function Sizing()
    return sizer ~= nil and sizer:IsActive()
end
local function SizeLimits()
    local mw, mh = MaxSize()
    local sw = Screen()
    local l, t = frame:GetLeft(), frame:GetTop()
    if sw and l then mw = min(mw, floor(sw - clampRight - l)) end
    if t then mh = min(mh, floor(t)) end
    return MIN_W, MIN_H, max(MIN_W, mw), max(MIN_H, mh)
end
local function ApplySize(w, h)
    frame:SetWidth(w)
    frame:SetHeight(h)
    Fit()
    Pin()
    SavePlace()
    OnSizing()
    Kit.ApplyDecor(frame)
end
local function StartSizing(button)
    if button and button ~= "LeftButton" then return end
    if Sizing() then return end
    if moving then
        moving = false
        frame:StopMovingOrSizing()
    end
    DropMax()
    Pin()
    SavePlace()
    sizer:Start()
end
local function StartMove()
    if Sizing() or moving then return end
    DropMax()
    moving = true
    frame:StartMoving()
end
local function StopMove()
    if not moving then return end
    moving = false
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
    Pin()
    SavePlace()
    Placed()
end
local function ToggleMax()
    if not frame or Sizing() then return end
    local s = Saved()
    if s.max then
        local n = s.norm
        s.max, s.norm = nil, nil
        if type(n) == "table" and n.w and n.h then
            frame:SetWidth(n.w)
            frame:SetHeight(n.h)
            if n.x and n.y then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", n.x, n.y)
            end
        end
        Fit()
        OnSizing()
        Kit.ApplyDecor(frame)
    else
        Pin()
        s.norm = { x = frame:GetLeft(), y = frame:GetTop(),
                   w = floor(frame:GetWidth() + 0.5), h = floor(frame:GetHeight() + 0.5) }
        s.max = true
        Fit()
    end
    SavePlace()
    MaxLook()
end
local function Place()
    local p = INSET + Pad()
    local tt = TabLook()
    strip:SetHeight(TabH())
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(4 + Pad()), 4 + Pad())
    pageBg:ClearAllPoints()
    pageBg:SetPoint("TOPLEFT", frame, "TOPLEFT", p, -p)
    pageBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -p, p)
    for _, e in pairs(entries) do
        if e.page then
            e.page:ClearAllPoints()
            e.page:SetPoint("TOPLEFT", p, -p)
        end
    end
    Clamp()
end
local function BuildGrip()
    grip = Kit.Grip(frame, GRIP)
    grip:SetFrameLevel(frame:GetFrameLevel() + 70)
    sizer = ns.Sizer.New(frame, {
        limits = SizeLimits,
        apply = ApplySize,
        paint = function(tex, role) Kit.Paint(tex, role == "fill" and "window.gripGlow" or "window.grip", role == "fill" and 0.08 or nil) end,
        text = function(fs) Kit.Text(fs, "text.title") end,
    })
    grip.onDown = function(_, button) StartSizing(button) end
    grip.onUp = function() sizer:Finish() end
end
local function Unfold()
    Saved().mini = nil
    if ns.ShellMini then ns.ShellMini.Hide() end
end
local function Fold(x, y)
    if not ns.ShellMini then return end
    if frame and frame:IsShown() then
        x, y = Kit.TopLeftOf(frame, TabH())
        frame:Hide()
    end
    Saved().mini = true
    ns.ShellMini.Show(x, y)
end
local function BuildStrip()
    winGroup = MakeGroup()
    fold = Kit.TabPart(winGroup, "fold")
    fold.tipTitle = ns.T("kit.strip.fold")
    fold.tip = ns.T("mini.fold.tip")
    fold.onClick = function() Fold() end
    maxBtn = Kit.TabPart(winGroup, "max")
    maxBtn.onClick = function() ToggleMax() end
    MaxLook()
    close = Kit.TabPart(winGroup, "close")
    close.tipTitle = ns.T("kit.win.close")
    close.tip = ns.T("kit.win.close.tip")
    close.onClick = function() frame:Hide() end
    winGroup.parts = { fold, maxBtn, close }
    strip = CreateFrame("Button", nil, frame)
    strip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    strip:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL - 1)
    strip:EnableMouse(true)
    strip:RegisterForDrag("LeftButton")
    strip:SetScript("OnDragStart", StartMove)
    strip:SetScript("OnDragStop", StopMove)
    strip:SetScript("OnDoubleClick", function() ToggleMax() end)
    pageGroup = MakeGroup()
    viewGroup = MakeGroup()
    about = MakeAct(viewGroup, "shell.about", nil, 0)
    about.tipTitle = ns.T("shell.about.tip")
    FontButtons()
    zoomOut = MakeAct(viewGroup, "shell.scale.less", "shell.scale.less.tip", -SCALE_STEP)
    zoomIn = MakeAct(viewGroup, "shell.scale.more", "shell.scale.more.tip", SCALE_STEP)
    viewGroup.parts = { about, fontLess, fontMore, zoomOut, zoomIn }
    about.onClick = function() if ns.About then ns.About.Toggle() end end
    PaintZoom()
end
local function OnTheme()
    if not frame then return end
    Place()
    LayoutTabs()
    OnSizing()
    local shown = frame:IsShown()
    for _, e in pairs(entries) do
        if e.page then
            if shown and e.key == current and e.def.OnTheme then
                e.stale = nil
                e.def.OnTheme(e.page)
            else
                e.stale = true
            end
        end
    end
end
local function Build()
    local s = Saved()
    frame = CreateFrame("Frame", "HTP_FailWatchShell", UIParent)
    frame:SetWidth(max(MIN_W, s.w or W))
    frame:SetHeight(max(MIN_H, s.h or H))
    frame:SetScale(Scale())
    frame:SetPoint(s.point or "CENTER", UIParent, s.rel or s.point or "CENTER", s.x or 0, s.y or 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame.sized = true
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetMinResize(MIN_W, MIN_H)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:SetScript("OnEvent", function()
        if frame:IsShown() and not Sizing() then
            Fit()
            SavePlace()
        end
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "HTP_FailWatchShell")
    Kit.Window(frame)
    pageBg = frame:CreateTexture(nil, "BORDER")
    Kit.Paint(pageBg, "surface.page")
    Kit.Tip.SetArea(function() return frame, pageBg end)
    BuildStrip()
    BuildGrip()
    Place()
    frame:SetScript("OnShow", function()
        Unfold()
        if ns.CpuMeter then ns.CpuMeter.WinCheck() end
    end)
    frame:SetScript("OnHide", function()
        if ns.CpuMeter then ns.CpuMeter.WinCheck() end
        StopMove()
        if sizer then sizer:Cancel() end
        local e = current and entries[current]
        if e and e.page and e.def.OnHide then e.def.OnHide(e.page) end
    end)
    LayoutTabs()
end
function Shell.Register(key, def)
    if entries[key] then return end
    local e = { key = key, def = def }
    entries[key] = e
    order[#order + 1] = e
    if frame then LayoutTabs() end
end
function Shell.Open(key)
    if not frame then Build() end
    key = key or current or Saved().tab
    if not key or not entries[key] then key = DEFAULT end
    if not entries[key] then return end
    if entries[key].def.go then
        entries[key].def.go()
        return
    end
    local was = frame:IsShown()
    if not was then
        local prev = current and entries[current]
        current = nil
        if prev and prev.key ~= key and prev.page then prev.page:Hide() end
        frame:Show()
        Fit()
        Select(key)
    elseif key ~= current then
        Select(key)
    end
end
function Shell.Hide()
    if frame then frame:Hide() end
    Unfold()
end
function Shell.Fold()
    if Shell.IsFolded() then return end
    if frame and frame:IsShown() then Fold() end
end
function Shell.FoldTo(view)
    if not ns.ShellMini then return end
    if not Shell.IsFolded() then Fold() end
    ns.ShellMini.SetView(view)
end
function Shell.Probe()
    return { frame = frame, strip = strip, maxBtn = maxBtn, fold = fold, grip = grip, sizer = sizer, close = close,
             groups = { winGroup, pageGroup, viewGroup },
             acts = { winGroup, pageGroup, viewGroup, about, fontLess, fontMore, zoomOut, zoomIn, fold, maxBtn, close } }
end
function Shell.IsFolded()
    return ns.ShellMini ~= nil and ns.ShellMini.IsShown()
end
function Shell.IsOpen(key)
    if not frame or not frame:IsShown() then return false end
    return key == nil or key == current
end
function Shell.Toggle(key)
    if Shell.IsOpen(key) then Shell.Hide() else Shell.Open(key) end
end
function Shell.Current()
    return current
end
function Shell.Frame()
    if not frame then Build() end
    return frame
end
function Shell.OnPlace(fn)
    placed[#placed + 1] = fn
end
function Shell.Room()
    if not frame then return nil, nil end
    local sw = Screen()
    local l, r = frame:GetLeft(), frame:GetRight()
    if not (sw and l and r) then return nil, nil end
    return l, sw - r
end
function Shell.ClampRight(px)
    clampRight = px or 0
    if not frame then return end
    Clamp()
    if frame:IsShown() and not Sizing() and not moving then Fit() end
end
function Shell.Scale()
    return Scale(), SCALE_MIN, SCALE_MAX, SCALE_STEP
end
function Shell.SetScale(v)
    if frame then
        SetScale(v)
        return
    end
    v = floor(v * 100 + 0.5) / 100
    Saved().scale = min(SCALE_MAX, max(SCALE_MIN, v))
end
function Shell.Handle(region)
    region:RegisterForDrag("LeftButton")
    region:HookScript("OnDragStart", StartMove)
    region:HookScript("OnDragStop", StopMove)
end
function Shell.Command(name, run, help)
    commands[name] = { run = run, help = help }
end
function Shell.RunCommand(name, arg)
    local c = commands[name]
    if not c then return false end
    c.run(arg or "")
    return true
end
function Shell.CommandHelp()
    local out = {}
    for _, c in pairs(commands) do
        if c.help then out[#out + 1] = c.help() end
    end
    tsort(out)
    return out
end
local actionSources = {}
function Shell.Actions(source, order)
    actionSources[#actionSources + 1] = { fn = source, order = order or 0 }
    tsort(actionSources, function(x, y) return x.order < y.order end)
end
function Shell.ActionRows()
    local out, at, copied = {}, {}, {}
    for i = 1, #actionSources do
        local rows = actionSources[i].fn() or {}
        for k = 1, #rows do
            local r = rows[k]
            local n = r.id and at[r.id]
            if n then
                local m = out[n]
                if not copied[n] then
                    local c = {}
                    for f, v in pairs(m) do c[f] = v end
                    c.items = {}
                    for j = 1, #m.items do c.items[j] = m.items[j] end
                    out[n], copied[n], m = c, true, c
                end
                for j = 1, #r.items do m.items[#m.items + 1] = r.items[j] end
            else
                out[#out + 1] = r
                if r.id then at[r.id] = #out end
            end
        end
    end
    return out
end
function Shell.TogglePanel()
    if ns.Panel then ns.Panel.Toggle() end
end
function Shell.SetNote(text, tip, token)
    note.text = text ~= "" and text or nil
    note.tip = tip
    note.token = token or "text.warn"
    PlaceNote()
end
function Shell.Note()
    return note.text
end
Kit.OnTheme(OnTheme)
Kit.OnFont(function()
    if not frame then return end
    Place()
    LayoutTabs()
    OnSizing()
end)
if ns.OnReady then
    ns.OnReady(function()
        if Saved().mini then Fold() end
    end)
end
