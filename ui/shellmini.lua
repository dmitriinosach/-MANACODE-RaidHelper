local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Kit = ns.Kit
local W, H = 290, 214
local MIN_W, MIN_H = 230, 120
local MAX_W, MAX_H = 520, 560
local PAD = 6
local HEADH = 18
local TITLEH = 16
local ROWH = 14
local GAP = 3
local FOOT = 8
local GRIP = 14
local CLOSE = 22
local LEADW = 30
local PCTW = 32
local VIEWGAP = 2
local VIEWPAD = 12
local BAR_A = 0.38
local TICK = 1
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local VIEWS = { "dps", "targets", "info" }
local CHAT_ICON = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\spam.tga"
local CHAT_SIZE = 12
local VIEW_LABEL = { dps = "mini.view.dps", targets = "mini.view.targets", info = "mini.view.info" }
local Mini = {}
ns.ShellMini = Mini
local frame, titleText, subText, head, restore, close, grip, chat
local viewBtns = {}
local rows = {}
local list = {}
local offset = 0
local shownN = 0
local acc = 0
local dirty = true
local live = false
local scanning = false
local fight
local asked
local classes = {}
local function Saved()
    local s = ns.GetDB().settings
    if type(s.shell) ~= "table" then s.shell = {} end
    if type(s.shell.minwin) ~= "table" then s.shell.minwin = {} end
    return s.shell.minwin
end
local function View()
    local v = Saved().view
    if v ~= "targets" and v ~= "info" then v = "dps" end
    return v
end
local function Num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end
local function Put(fs, text)
    if fs.miniText ~= text then
        fs.miniText = text
        fs:SetText(text)
    end
end
local function ClassOf(who)
    local c = classes[who]
    if c == nil then
        local _, token = UnitClass(who)
        c = token or (ns.Encounters and ns.Encounters.ClassOf(who)) or false
        classes[who] = c
    end
    return c or nil
end
local function Calm()
    return not ((ns.Meter and ns.Meter.Fighting()) or UnitAffectingCombat("player"))
end
local function Visible()
    if not frame then return 0 end
    local h = frame:GetHeight() - PAD * 2 - HEADH - GAP - TITLEH - GAP - FOOT
    return max(1, floor(h / ROWH))
end
local function OpenFull(f, who, t)
    if not ns.Shell then return end
    ns.Shell.Open("log")
    if not f then return end
    if ns.Timeline and ns.Timeline.ShowFight then ns.Timeline.ShowFight(f) end
    if who and ns.TimelineLinks then ns.TimelineLinks.Focus(who, t) end
end
local function RowEnter(self)
    local e = self.e
    if not e or not ns.Tip then return end
    local lines = e.lines or (e.tip and e.tip(e.a, e.b, e.c, e.d))
    if not lines or #lines == 0 then return end
    ns.Tip.Show(self, lines)
end
local function TipHide()
    if ns.Tip then ns.Tip.Hide() end
end
local function RowClick(self)
    local e = self.e
    if not e or e.kind == "note" then return end
    if live then
        OpenFull(nil)
    elseif View() == "targets" then
        OpenFull(fight)
    else
        OpenFull(fight, e.who, e.t)
    end
end
local function Wheel(_, delta)
    local most = max(0, #list - Visible())
    local want = max(0, min(most, offset - delta))
    if want ~= offset then
        offset = want
        Mini.Draw()
    end
end
local function NewRow(k)
    local r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROWH)
    local y = -(PAD + HEADH + GAP + TITLEH + GAP + (k - 1) * ROWH)
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", TipHide)
    r:SetScript("OnClick", RowClick)
    r:SetScript("OnMouseWheel", Wheel)
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function() frame:StartMoving() end)
    r:SetScript("OnDragStop", function() Mini.SavePlace() end)
    r.bar = r:CreateTexture(nil, "BORDER")
    r.bar:SetTexture(WHITE8)
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)
    r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 1)
    r.bar:SetAlpha(BAR_A)
    r.lead = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.lead:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.lead:SetWidth(LEADW)
    r.lead:SetJustifyH("LEFT")
    r.pct = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.pct:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.pct:SetWidth(PCTW)
    r.pct:SetJustifyH("RIGHT")
    r.val = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.val:SetPoint("RIGHT", r.pct, "LEFT", -4, 0)
    r.val:SetJustifyH("RIGHT")
    r.val:SetWordWrap(false)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.lead, "RIGHT", 0, 0)
    r.name:SetPoint("RIGHT", r.val, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    rows[k] = r
    return r
end
local function PaintRow(r, e)
    r.e = e
    local note = e.kind == "note"
    Put(r.lead, e.lead or "")
    Kit.Text(r.lead, "text.note")
    if r.laid ~= e.kind then
        r.laid = e.kind
        r.name:ClearAllPoints()
        if note or e.kind == "head" then
            r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
        else
            r.name:SetPoint("LEFT", r.lead, "RIGHT", 0, 0)
        end
        r.name:SetPoint("RIGHT", note and r or r.val, note and "RIGHT" or "LEFT", -4, 0)
    end
    Put(r.name, e.left or "")
    if e.kind == "head" then
        Kit.Text(r.name, "text.title")
    elseif e.class then
        Kit.ClassText(r.name, e.class)
    else
        Kit.Text(r.name, e.tone or "text.primary")
    end
    Put(r.val, e.val or "")
    Kit.Text(r.val, e.kind == "head" and "text.title" or (e.valTone or "text.secondary"))
    Put(r.pct, e.pct or "")
    Kit.Text(r.pct, "text.note")
    local fill = e.fill or 0
    if fill > 0 then
        r.bar:SetVertexColor(ns.GPList.ClassRGB(e.class))
        r.bar:SetWidth(max(1, (frame:GetWidth() - PAD * 2) * min(1, fill)))
        r.bar:Show()
    else
        r.bar:Hide()
    end
    r:Show()
end
function Mini.Draw()
    if not frame then return end
    local n = Visible()
    for k = #rows + 1, n do NewRow(k) end
    shownN = n
    offset = max(0, min(offset, #list - n))
    for k = 1, #rows do
        local e = k <= n and list[k + offset]
        if e then
            PaintRow(rows[k], e)
        else
            rows[k].e = nil
            rows[k]:Hide()
        end
    end
end
local function Title(text, sub)
    Put(titleText, text)
    Put(subText, sub or "")
end
local function FightTitle(f)
    local outcome = Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.T(f.killed and "fl.win" or "fl.wipe") .. "|r"
    local clock = ns.MiniRows.Clock(max(0, f.to - f.from))
    local spot = ns.FightTree and ns.FightTree.Spot(f)
    if spot and spot.n then return format(ns.T("mini.title"), ns.EncName(f.boss), spot.n, outcome, clock) end
    return format(ns.T("mini.title1"), ns.EncName(f.boss), outcome, clock)
end
local function Only(text, tone)
    list[#list + 1] = { kind = "note", left = text, tone = tone or "text.note" }
end
local function Again()
    dirty = true
end
local function Invalidated()
    asked = nil
    dirty = true
end
local function LastFight()
    local E = ns.Encounters
    if not E then return nil end
    if not E.Ready() then
        if not scanning and Calm() then
            scanning = true
            E.Scan(function()
                scanning = false
                dirty = true
            end)
        end
        dirty = true
        return nil
    end
    return E.Fights()[1]
end
local function LiveRows()
    local M = ns.Meter
    if not (M and next(M.who)) then return false end
    local sec, dps = ns.MiniRows.Live(list, ClassOf)
    Title(format(ns.T("mini.live"), ns.MiniRows.Clock(sec)), ns.BadgeTips.Short(dps))
    return true
end
local function FightRows(f, s)
    local view = View()
    local sub
    if view == "dps" then
        sub = ns.BadgeTips.Short(ns.MiniRows.Dps(list, s))
    elseif view == "targets" then
        ns.MiniRows.Targets(list, f, s)
    else
        local model = ns.GPList and ns.GPList.Build(f, s) or nil
        ns.MiniRows.Important(list, f, s, model)
    end
    Title(FightTitle(f), sub)
end
function Mini.Rebuild()
    if not frame then return end
    dirty = false
    wipe(list)
    local M = ns.Meter
    live = View() == "dps" and M ~= nil and M.Fighting() and LiveRows()
    if live then
        fight = nil
        Mini.Draw()
        return
    end
    local f = LastFight()
    fight = f
    if not f then
        Title(ns.T(scanning and "tl.scanning" or "gpmini.nofight"))
        if not (View() == "dps" and LiveRows()) then Only(ns.T(scanning and "tl.scanning" or "gpmini.none")) end
        Mini.Draw()
        return
    end
    local s = ns.Summary.Get(f)
    if not s and asked ~= f and Calm() and not ns.Summary.Busy(f) then
        asked = f
        ns.Summary.Compute(f, Again)
        s = ns.Summary.Get(f)
        if s then dirty = false end
    end
    if s then
        FightRows(f, s)
    else
        if asked ~= f or ns.Summary.Busy(f) then dirty = true end
        if not (View() == "dps" and LiveRows()) then
            Title(FightTitle(f))
            Only(ns.T("sum.busy"))
        end
    end
    Mini.Draw()
end
local function Tick(self, elapsed)
    acc = acc + elapsed
    if acc < TICK then return end
    acc = 0
    local M = ns.Meter
    if View() == "dps" and M and M.Fighting() and next(M.who) then
        Mini.Rebuild()
        return
    end
    if live then dirty = true end
    if dirty then Mini.Rebuild() end
end
local function SetView(key)
    Saved().view = key
    offset = 0
    for i = 1, #VIEWS do viewBtns[VIEWS[i]]:SetActive(VIEWS[i] == key) end
    if key == "dps" then chat:Show() else chat:Hide() end
    Mini.Rebuild()
end
local function ReportLines(n)
    if live then return ns.ChatReport.Live(n) end
    local s = fight and ns.Summary.Get(fight)
    if not s then return {} end
    return ns.ChatReport.Summary(fight, s, n)
end
function Mini.SavePlace()
    if not frame then return end
    frame:StopMovingOrSizing()
    local l, t = frame:GetLeft(), frame:GetTop()
    local p = Saved()
    if l and t then
        p.x, p.y = floor(l + 0.5), floor(t + 0.5)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    end
    p.w, p.h = floor(frame:GetWidth() + 0.5), floor(frame:GetHeight() + 0.5)
end
local function HeadEnter(self)
    if not ns.Tip then return end
    local lines = { { kind = "head", left = titleText.miniText or "" } }
    lines[2] = { kind = "text", left = ns.T(live and "mini.head.live" or "mini.head.tip") }
    ns.Tip.Show(self, lines)
end
local function BuildHead()
    local x = PAD
    for i = 1, #VIEWS do
        local key = VIEWS[i]
        local b = Kit.Button(frame, nil, "quiet")
        b:SetHeight(HEADH)
        b.text:SetText(ns.T(VIEW_LABEL[key]))
        b:SetWidth(floor(b.text:GetStringWidth() + VIEWPAD + 0.5))
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -PAD)
        x = x + b:GetWidth() + VIEWGAP
        b.tipTitle = ns.T(VIEW_LABEL[key])
        b.tip = ns.T(VIEW_LABEL[key] .. ".tip")
        b.tipAnchor = "ANCHOR_TOP"
        b.onClick = function() SetView(key) end
        viewBtns[key] = b
    end
    close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetWidth(CLOSE)
    close:SetHeight(CLOSE)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -2)
    close:SetScript("OnClick", function()
        if ns.Shell then ns.Shell.Hide() else frame:Hide() end
    end)
    restore = Kit.FoldButton(frame, true)
    restore:SetPoint("RIGHT", close, "LEFT", 0, 0)
    restore.tip = ns.T("mini.restore.tip")
    restore.onClick = function() if ns.Shell then ns.Shell.Open() end end
    chat = Kit.IconButton(frame, CHAT_ICON, CHAT_SIZE)
    chat:SetPoint("RIGHT", restore, "LEFT", -2, 0)
    chat.tipTitle = ns.T("report.btn")
    chat.tip = ns.T("report.tip")
    chat.tipAnchor = "ANCHOR_TOP"
    chat.onClick = function(self) if ns.ProofView then ns.ProofView.ReportMenu(self, ReportLines) end end
    head = CreateFrame("Button", nil, frame)
    head:SetHeight(TITLEH)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + HEADH + GAP))
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD + HEADH + GAP))
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() frame:StartMoving() end)
    head:SetScript("OnDragStop", function() Mini.SavePlace() end)
    head:SetScript("OnEnter", HeadEnter)
    head:SetScript("OnLeave", TipHide)
    head:SetScript("OnClick", function() OpenFull(not live and fight or nil) end)
    subText = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    subText:SetJustifyH("RIGHT")
    Kit.Text(subText, "sem.stat.dps")
    titleText = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", head, "LEFT", 2, 0)
    titleText:SetPoint("RIGHT", subText, "LEFT", -6, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
end
local function BuildGrip()
    grip = CreateFrame("Button", nil, frame)
    grip:SetWidth(GRIP)
    grip:SetHeight(GRIP)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 5)
    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(Kit.Theme().window.gripTex)
    Kit.Tint(tex, "window.grip")
    grip.tex = tex
    grip.tipTitle = ns.T("iso.tip.grip")
    grip:SetScript("OnEnter", function(self) Kit.TipShow(self) end)
    grip:SetScript("OnLeave", function() Kit.TipHide() end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function() Mini.SavePlace() end)
end
local function Build()
    local p = Saved()
    frame = CreateFrame("Frame", "HTP_FailWatchShellMini", UIParent)
    frame:SetWidth(min(MAX_W, max(MIN_W, Num(p.w) or W)))
    frame:SetHeight(min(MAX_H, max(MIN_H, Num(p.h) or H)))
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetMinResize(MIN_W, MIN_H)
    frame:SetMaxResize(MAX_W, MAX_H)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function() Mini.SavePlace() end)
    frame:SetScript("OnMouseWheel", Wheel)
    frame:SetScript("OnSizeChanged", function() Mini.Draw() end)
    frame:SetScript("OnShow", function()
        if ns.Meter then
            ns.Meter.Want("mini", true)
            ns.Meter.Split(true)
        end
    end)
    frame:SetScript("OnHide", function()
        Mini.SavePlace()
        TipHide()
        if ns.Meter then
            ns.Meter.Split(false)
            ns.Meter.Want("mini", false)
        end
    end)
    frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", Tick))
    frame:Hide()
    Kit.Skin(frame, "float")
    BuildHead()
    BuildGrip()
    for i = 1, #VIEWS do viewBtns[VIEWS[i]]:SetActive(VIEWS[i] == View()) end
    if View() == "dps" then chat:Show() else chat:Hide() end
end
function Mini.Show(x, y)
    if not frame then Build() end
    local p = Saved()
    x, y = Num(p.x) or x, Num(p.y) or y
    frame:ClearAllPoints()
    if x and y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    offset, asked = 0, nil
    frame:Show()
    Mini.Rebuild()
end
function Mini.Hide()
    if frame and frame:IsShown() then frame:Hide() end
end
function Mini.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end
function Mini.Probe()
    if not frame then return nil end
    return { frame = frame, rows = rows, list = list, views = viewBtns, restore = restore, close = close,
             grip = grip, head = head, title = titleText, sub = subText, live = live, fight = fight, chat = chat }
end
if ns.Encounters and ns.Encounters.Invalidate then hooksecurefunc(ns.Encounters, "Invalidate", Invalidated) end
if ns.GPList and ns.GPList.OnChange then ns.GPList.OnChange(Again) end
Kit.OnTheme(function()
    if frame and frame:IsShown() then Mini.Draw() end
end)
