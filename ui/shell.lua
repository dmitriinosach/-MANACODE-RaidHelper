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
local ICONPAD = 4
local TABMIN = 72
local ICONTAB = 40
local ICON = 18
local CLOSE = 28
local CLOSE_EDGE = 5
local INSET = 6
local GRIP = 16
local TABLEVEL = 6
local DEFAULT = "log"
local ZOOM = 22
local ZOOMGAP = 3
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.70, 1.30, 0.05
local SCALE_EPS = 0.001
local Shell = {}
ns.Shell = Shell
local entries = {}
local order = {}
local commands = {}
local frame, strip, close, grip, pageBg, zoomOut, zoomIn, about, fold
local current
local sizing, sizedW, sizedH, moving
local sizeX, sizeY, sizeW, sizeH, sizeMaxW, sizeMaxH
local clampRight = 0
local zoomX = 0
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
local function Line()
    local tt = TabLook()
    return (tt.h - tt.rim) / 2
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
    frame:SetClampRectInsets(0, clampRight, TabLook().h, 0)
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
    local top = tt.h
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
local function TabWidth(e)
    local tab = e.tab
    if e.def.icon then
        tab.text:SetText("")
        tab.tipTitle = Label(e)
        return max(ICONTAB, ICON + (TabLook().rim + ICONPAD) * 2)
    end
    tab.tipTitle = false
    tab.text:SetText(Label(e))
    return max(TABMIN, floor(tab.text:GetStringWidth() + (TabLook().rim + TABPAD) * 2))
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
    return max(MIN_W, floor(sw - clampRight)), max(MIN_H, floor(sh - TabLook().h))
end
local function KeepOnScreen()
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local sw, sh = Screen()
    if not (l and r and t and b and sw) then return end
    local dx, dy = 0, 0
    if r + clampRight > sw then dx = sw - r - clampRight end
    if l + dx < 0 then dx = -l end
    if b < 0 then dy = -b end
    if t + TabLook().h + dy > sh then dy = sh - t - TabLook().h end
    if dx == 0 and dy == 0 then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dx, b + dy)
end
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
end
local function Fit()
    local mw, mh = MaxSize()
    if mw < math.huge then frame:SetMaxResize(mw, mh) end
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
local function MakeZoom(label, tip, delta, font)
    local b = Kit.Button(frame)
    b:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL)
    b.text:SetFontObject(font or "GameFontNormal")
    b:SetText(ns.T(label))
    b.tip = ns.T(tip)
    b.onClick = function() SetScale(Scale() + delta) end
    Kit.StyleButton(b)
    return b
end
local function ZoomSize()
    local tt = TabLook()
    return min(ZOOM, tt.h - tt.rim + 2)
end
local function PlaceZoom()
    if not zoomOut then return end
    local tt = TabLook()
    local size = ZoomSize()
    fold:SetWidth(size)
    fold:SetHeight(size)
    fold:ClearAllPoints()
    fold:SetPoint("RIGHT", frame, "TOPRIGHT", -(tt.x - CLOSE_EDGE + CLOSE + TABGAP), Line())
    zoomIn:SetWidth(size)
    zoomIn:SetHeight(size)
    zoomOut:SetWidth(size)
    zoomOut:SetHeight(size)
    zoomIn:ClearAllPoints()
    zoomIn:SetPoint("RIGHT", frame, "TOPRIGHT", -zoomX, Line())
    zoomOut:ClearAllPoints()
    zoomOut:SetPoint("RIGHT", zoomIn, "LEFT", -ZOOMGAP, 0)
    about:SetWidth(size)
    about:SetHeight(size)
    about:ClearAllPoints()
    about:SetPoint("RIGHT", zoomOut, "LEFT", -ZOOMGAP * 3, 0)
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
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    b:SetHeight(TabLook().h - TabLook().rim)
    b:ClearAllPoints()
    b:SetPoint("LEFT", frame, "TOPLEFT", note.x + TABPAD, Line())
    if about then b:SetPoint("RIGHT", about, "LEFT", -TABPAD, 0) end
    b:Show()
end
local function LayoutTabs()
    tsort(order, TabOrder)
    local tt = TabLook()
    local x = tt.x
    local rx = tt.x - CLOSE_EDGE + CLOSE + TABGAP + ZoomSize() + TABGAP
    local textW = TABMIN
    for i = 1, #order do
        local e = order[i]
        if not e.tab and not e.def.tabless then
            e.tab = Kit.Tab(frame, e.def.icon, ICON)
            local key, go = e.key, e.def.go
            e.tab.onClick = function()
                if go then
                    go()
                elseif current ~= key then
                    Select(key)
                end
            end
        end
        if e.tab then
            e.w = TabWidth(e)
            if not e.def.icon then textW = max(textW, e.w) end
        end
    end
    for i = 1, #order do
        local e = order[i]
        if e.tab then
            local w = e.def.icon and e.w or textW
            e.tab:SetWidth(w)
            if e.def.right then
                e.x = rx
                rx = rx + w + TABGAP
            else
                e.x = x
                x = x + w + TABGAP
            end
        end
    end
    zoomX = rx + TABGAP
    note.x = x
    PlaceZoom()
    PlaceNote()
    PaintTabs()
end
local function Cursor()
    local x, y = GetCursorPosition()
    local s = frame:GetEffectiveScale()
    if not s or s <= 0 then return x, y end
    return x / s, y / s
end
local function StopSizing()
    sizing = false
    Fit()
    Pin()
    SavePlace()
    OnSizing()
    Kit.ApplyDecor(frame)
end
local function StartSizing(button)
    if button and button ~= "LeftButton" then return end
    if sizing then return end
    if moving then
        moving = false
        frame:StopMovingOrSizing()
    end
    Pin()
    sizeX, sizeY = Cursor()
    sizeW, sizeH = frame:GetWidth(), frame:GetHeight()
    sizedW, sizedH = sizeW, sizeH
    local mw, mh = MaxSize()
    local sw = Screen()
    local l, t = frame:GetLeft(), frame:GetTop()
    if sw and l then mw = min(mw, floor(sw - clampRight - l)) end
    if t then mh = min(mh, floor(t)) end
    sizeMaxW, sizeMaxH = max(MIN_W, mw), max(MIN_H, mh)
    sizing = true
end
local function Sizing()
    if not sizing then return end
    if not IsMouseButtonDown("LeftButton") then
        StopSizing()
        return
    end
    local x, y = Cursor()
    local w = min(max(floor(sizeW + x - sizeX + 0.5), MIN_W), sizeMaxW)
    local h = min(max(floor(sizeH + sizeY - y + 0.5), MIN_H), sizeMaxH)
    if w == sizedW and h == sizedH then return end
    sizedW, sizedH = w, h
    frame:SetWidth(w)
    frame:SetHeight(h)
    OnSizing()
end
local function StartMove()
    if sizing or moving then return end
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
local function Place()
    local p = INSET + Pad()
    local tt = TabLook()
    close:ClearAllPoints()
    close:SetPoint("RIGHT", frame, "TOPRIGHT", CLOSE_EDGE - tt.x, Line())
    strip:SetHeight(tt.h)
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
    grip = CreateFrame("Button", nil, frame)
    grip:SetWidth(GRIP)
    grip:SetHeight(GRIP)
    grip:SetFrameLevel(frame:GetFrameLevel() + 70)
    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(Kit.Theme().window.gripTex)
    Kit.Tint(tex, "window.grip")
    grip:SetScript("OnMouseDown", function(_, button) StartSizing(button) end)
    grip:SetScript("OnMouseUp", function()
        if not sizing then return end
        Sizing()
        if sizing then StopSizing() end
    end)
    grip:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", Sizing))
end
local function Unfold()
    Saved().mini = nil
    if ns.ShellMini then ns.ShellMini.Hide() end
end
local function Fold(x, y)
    if not ns.ShellMini then return end
    if frame and frame:IsShown() then
        x, y = Kit.TopLeftOf(frame, TabLook().h)
        Saved().mini = true
        frame:Hide()
    end
    ns.ShellMini.Show(x, y)
end
local function BuildStrip()
    fold = Kit.FoldButton(frame, false)
    fold:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL)
    fold.tip = ns.T("mini.fold.tip")
    fold.onClick = function() Fold() end
    strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    strip:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL - 1)
    strip:EnableMouse(true)
    strip:RegisterForDrag("LeftButton")
    strip:SetScript("OnDragStart", StartMove)
    strip:SetScript("OnDragStop", StopMove)
    close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetWidth(CLOSE)
    close:SetHeight(CLOSE)
    close:SetFrameLevel(frame:GetFrameLevel() + TABLEVEL)
    close:SetScript("OnClick", function() frame:Hide() end)
    zoomOut = MakeZoom("shell.scale.less", "shell.scale.less.tip", -SCALE_STEP)
    zoomIn = MakeZoom("shell.scale.more", "shell.scale.more.tip", SCALE_STEP)
    about = MakeZoom("shell.about", "shell.about.tip", 0)
    about.tipTitle, about.tip = ns.T("shell.about.tip"), nil
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
        if frame:IsShown() and not sizing then
            Fit()
            SavePlace()
        end
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "HTP_FailWatchShell")
    Kit.Window(frame)
    pageBg = frame:CreateTexture(nil, "BORDER")
    Kit.Paint(pageBg, "surface.page")
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
        if sizing then StopSizing() end
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
    if frame:IsShown() and not sizing and not moving then Fit() end
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
    local out = {}
    for i = 1, #actionSources do
        local rows = actionSources[i].fn() or {}
        for k = 1, #rows do out[#out + 1] = rows[k] end
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
if ns.OnReady then
    ns.OnReady(function()
        if Saved().mini then Fold() end
    end)
end
