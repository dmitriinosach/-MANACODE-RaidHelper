local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Kit = ns.Kit
local W, H = 290, 214
local MIN_W, MIN_H = 250, 120
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
local PICK_ICON = 10
local PICK_MAX = 20
local BAR_A = 0.38
local TICK = 1
local TOP = PAD + HEADH + GAP + TITLEH + GAP
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local VIEWS = { "faults", "dps", "hps", "targets" }
local KNOWN = { faults = true, dps = true, hps = true, targets = true }
local RATE = { dps = true, hps = true }
local CHAT_ICON = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\spam.tga"
local CHAT_SIZE = 12
local Mini = {}
ns.ShellMini = Mini
local frame, titleText, subText, head, restore, close, grip, chat, give, pickBtn
local ft
local viewBtns = {}
local rows = {}
local list = {}
local offset = 0
local acc = 0
local dirty = true
local live = false
local scanning = false
local fight
local model
local asked
local pickKey
local fullSeen
local seenTop
local wasCombat = false
local phase = 0
local manualPhase = -1
local titleBy
local classes = {}
local function Saved()
    local s = ns.GetDB().settings
    if type(s.shell) ~= "table" then s.shell = {} end
    if type(s.shell.minwin) ~= "table" then s.shell.minwin = {} end
    return s.shell.minwin
end
local function View()
    local v = Saved().view
    if not KNOWN[v or ""] then v = "dps" end
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
local function Key(f)
    return tostring(f.boss) .. "|" .. floor(f.from or 0)
end
local function Find(fights, key)
    for i = 1, #fights do
        if Key(fights[i]) == key then return fights[i] end
    end
    return nil
end
local function Faults()
    return View() == "faults" and model ~= nil
end
local function Slots()
    if not frame then return 1 end
    if Faults() then
        local L = ns.GPList.MINI
        return max(1, floor((frame:GetHeight() - TOP - FOOT - L.headh) / L.rowh))
    end
    return max(1, floor((frame:GetHeight() - TOP - FOOT) / ROWH))
end
local function Count()
    if Faults() then return #ns.FaultTable.Rows(model, ft and ft.filter or "all") end
    return #list
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
        OpenFull(fight, e.who)
    end
end
local function Wheel(_, delta)
    local most = max(0, Count() - Slots())
    local want = max(0, min(most, offset - delta))
    if want ~= offset then
        offset = want
        Mini.Draw()
    end
end
local function NewRow(k)
    local r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROWH)
    local y = -(TOP + (k - 1) * ROWH)
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
local function HideRows()
    for k = 1, #rows do
        rows[k].e = nil
        rows[k]:Hide()
    end
end
local function DrawFaults()
    if not ft then
        ft = ns.GPList.New(frame, "HTP_FailWatchShellMiniFault", ns.GPList.MINI)
        ft:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP)
        ft.onWheel = function(delta) Wheel(nil, delta) end
    end
    ft:Draw(fight, model, frame:GetWidth() - PAD * 2, offset, Slots())
    ft:Show()
end
local function PaintGive()
    local on = Faults()
    local by = on and "give" or "sub"
    if titleBy ~= by then
        titleBy = by
        titleText:SetPoint("RIGHT", on and give or subText, "LEFT", -6, 0)
    end
    if not on then
        give:Hide()
        return
    end
    local unit = ns.Ledger and ns.Ledger.Unit() or ""
    give.tip = format(ns.T("gpmini.all.tip"), model.pending, unit, model.ready)
    if model.pending > 0 then give:Enable() else give:Disable() end
    give:Show()
end
function Mini.Draw()
    if not frame then return end
    PaintGive()
    local n = Slots()
    offset = max(0, min(offset, Count() - n))
    if Faults() then
        HideRows()
        DrawFaults()
        return
    end
    if ft then ft:Hide() end
    for k = #rows + 1, n do NewRow(k) end
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
local function Outcome(f)
    return Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.T(f.killed and "fl.win" or "fl.wipe") .. "|r"
end
local function FightTitle(f)
    local clock = ns.MiniRows.Clock(max(0, f.to - f.from))
    local spot = ns.FightTree and ns.FightTree.Spot(f)
    if spot and spot.n then return format(ns.T("mini.title"), ns.EncName(f.boss), spot.n, Outcome(f), clock) end
    return format(ns.T("mini.title1"), ns.EncName(f.boss), Outcome(f), clock)
end
local function Only(text, tone)
    list[#list + 1] = { kind = "note", left = text, tone = tone or "text.note" }
end
local function Again()
    dirty = true
end
local function GPChanged()
    dirty = true
    if frame and frame:IsShown() and View() == "faults" then Mini.Rebuild() end
end
local function Invalidated()
    asked = nil
    dirty = true
end
local function Fights()
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
    return E.Fights()
end
local function Adopt(fights)
    local sv = ns.SummaryView
    local f = sv and sv.Fight and sv.Fight()
    if f == fullSeen then return end
    fullSeen = f
    if not f then return end
    if fights[1] and Key(fights[1]) == Key(f) then
        pickKey = nil
    else
        pickKey = Key(f)
    end
end
local function Chosen(fights)
    Adopt(fights)
    if pickKey then
        local f = Find(fights, pickKey)
        if f then return f end
        pickKey = nil
    end
    return fights[1]
end
local function LiveRows(heal)
    local M = ns.Meter
    if not (M and next(heal and M.heals or M.who)) then return false end
    local sec, rate = ns.MiniRows.Live(list, ClassOf, heal)
    Title(format(ns.T("mini.live"), ns.MiniRows.Clock(sec)), ns.BadgeTips.Short(rate))
    return true
end
local function FightRows(f, s)
    local view = View()
    local sub
    if RATE[view] then
        sub = ns.BadgeTips.Short(ns.MiniRows.Dps(list, s, view == "hps"))
    elseif view == "targets" then
        ns.MiniRows.Targets(list, f, s)
    else
        model = ns.GPList and ns.GPList.Build(f, s) or nil
        if not model then Only(ns.T("gpmini.none")) end
    end
    Title(FightTitle(f), sub)
end
local function WantLive()
    local M = ns.Meter
    return RATE[View()] and pickKey == nil and M ~= nil and M.Fighting() or false
end
function Mini.Rebuild()
    if not frame then return end
    dirty = false
    wipe(list)
    model = nil
    live = WantLive() and LiveRows(View() == "hps")
    if live then
        fight = nil
        Mini.Draw()
        return
    end
    local fights = Fights()
    local f = fights and Chosen(fights)
    fight = f
    local rate = RATE[View()]
    if not f then
        Title(ns.T(scanning and "tl.scanning" or "gpmini.nofight"))
        if not (rate and LiveRows(View() == "hps")) then Only(ns.T(scanning and "tl.scanning" or "gpmini.none")) end
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
        if not (rate and pickKey == nil and LiveRows(View() == "hps")) then
            Title(FightTitle(f))
            Only(ns.T("sum.busy"))
        end
    end
    Mini.Draw()
end
local function SetView(key, auto)
    if not auto then manualPhase = phase end
    Saved().view = key
    offset = 0
    for i = 1, #VIEWS do viewBtns[VIEWS[i]]:SetActive(VIEWS[i] == key) end
    if RATE[key] then
        chat.tip = ns.T(key == "hps" and "report.tip.heal" or "report.tip")
        chat:Show()
    else
        chat:Hide()
    end
    Mini.Rebuild()
end
local function Watch()
    local combat = UnitAffectingCombat("player") and true or false
    if combat ~= wasCombat then
        wasCombat = combat
        phase = phase + 1
        if combat then
            pickKey = nil
            if View() ~= "dps" then SetView("dps", true) end
            dirty = true
        end
    end
    local E = ns.Encounters
    local top = E and E.Ready() and E.Fights()[1]
    if not top then return end
    local k = Key(top)
    if seenTop == nil then seenTop = k end
    if combat or k == seenTop then return end
    if not ns.Summary.Get(top) then
        if asked ~= top and Calm() and not ns.Summary.Busy(top) then
            asked = top
            ns.Summary.Compute(top, Again)
        end
        if not ns.Summary.Get(top) then return end
    end
    seenTop = k
    if manualPhase == phase then return end
    pickKey = nil
    SetView("faults", true)
end
local function Tick(self, elapsed)
    acc = acc + elapsed
    if acc < TICK then return end
    acc = 0
    Watch()
    local M = ns.Meter
    if WantLive() and next(View() == "hps" and M.heals or M.who) then
        Mini.Rebuild()
        return
    end
    if live then dirty = true end
    if dirty then Mini.Rebuild() end
end
local function Choose(f)
    pickKey = f and Key(f) or nil
    manualPhase = phase
    offset, asked = 0, nil
    Mini.Rebuild()
end
local function PickLabel(f)
    local spot = ns.FightTree and ns.FightTree.Spot(f)
    local when = date("%H:%M", f.from)
    local tail = Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.MiniRows.Clock(max(0, f.to - f.from)) .. "|r"
    if spot and spot.n then return format(ns.T("mini.pick.row"), spot.n, ns.EncName(f.boss), when, tail) end
    return format(ns.T("mini.pick.row1"), ns.EncName(f.boss), when, tail)
end
local function PickMenu(self)
    local E = ns.Encounters
    local fights = E and E.Ready() and E.Fights() or {}
    local ref = fight or fights[1]
    local spot = ref and ns.FightTree and ns.FightTree.Spot(ref)
    local raid = spot and spot.raid
    local items = { { text = ns.T("mini.pick"), isTitle = true } }
    items[2] = { text = ns.T("mini.current"), checked = pickKey == nil, func = function() Choose(nil) end }
    local n = 0
    for i = 1, #fights do
        local f = fights[i]
        local sp = raid and ns.FightTree.Spot(f)
        if not raid or (sp and sp.raid == raid) then
            n = n + 1
            if n > PICK_MAX then break end
            items[#items + 1] = { text = PickLabel(f), checked = pickKey == Key(f), func = function() Choose(f) end }
        end
    end
    TipHide()
    Kit.Menu(items, self)
end
local function ReportLines(n)
    local heal = View() == "hps"
    if live then return ns.ChatReport.Live(n, heal) end
    local s = fight and ns.Summary.Get(fight)
    if not s then return {} end
    return ns.ChatReport.Summary(fight, s, n, heal)
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
local function BuildTabs()
    local x = PAD
    for i = 1, #VIEWS do
        local key = VIEWS[i]
        local label = "mini.view." .. key
        local b = Kit.Button(frame, nil, "quiet")
        b:SetHeight(HEADH)
        b.text:SetText(ns.T(label))
        b:SetWidth(floor(b.text:GetStringWidth() + VIEWPAD + 0.5))
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -PAD)
        x = x + b:GetWidth() + VIEWGAP
        b.tipTitle = ns.T(label)
        b.tip = ns.T(label .. ".tip")
        b.tipAnchor = "ANCHOR_TOP"
        b.onClick = function() SetView(key) end
        viewBtns[key] = b
    end
end
local function BuildHead()
    BuildTabs()
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
    chat.onClick = function(self)
        if ns.ProofView then
            ns.ProofView.ReportMenu(self, ReportLines, View() == "hps" and "report.menu.heal" or nil)
        end
    end
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
    pickBtn = Kit.IconButton(frame, nil, PICK_ICON)
    Kit.Arrow(pickBtn.icon, false)
    pickBtn:SetPoint("LEFT", head, "LEFT", 0, 0)
    pickBtn:SetFrameLevel(head:GetFrameLevel() + 2)
    pickBtn.tipTitle = ns.T("mini.pick")
    pickBtn.tip = ns.T("mini.pick.tip")
    pickBtn.tipAnchor = "ANCHOR_TOP"
    pickBtn.onClick = PickMenu
    give = Kit.Button(frame, nil, "main")
    give:SetHeight(TITLEH)
    give.text:SetText(ns.T("gpmini.all"))
    give:SetWidth(floor(give.text:GetStringWidth() + VIEWPAD + 0.5))
    give:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    give:SetFrameLevel(head:GetFrameLevel() + 2)
    give.tipTitle = ns.T("gpmini.all")
    give.tipAnchor = "ANCHOR_TOP"
    give.onClick = function()
        if fight and model then ns.GPList.Issue(fight, model.all) end
    end
    give:Hide()
    subText = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    subText:SetJustifyH("RIGHT")
    Kit.Text(subText, "sem.stat.dps")
    titleText = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Kit.Text(titleText, "text.title")
    titleText:SetPoint("LEFT", pickBtn, "RIGHT", 2, 0)
    titleText:SetPoint("RIGHT", subText, "LEFT", -6, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleBy = "sub"
end
local function BuildGrip()
    grip = Kit.Grip(frame, GRIP)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 5)
    grip.tipTitle = ns.T("iso.tip.grip")
    grip.onDown = function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end
    grip.onUp = function() Mini.SavePlace() end
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
    local v = View()
    for i = 1, #VIEWS do viewBtns[VIEWS[i]]:SetActive(VIEWS[i] == v) end
    if RATE[v] then chat.tip = ns.T(v == "hps" and "report.tip.heal" or "report.tip") else chat:Hide() end
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
    offset, asked, seenTop = 0, nil, nil
    wasCombat = UnitAffectingCombat("player") and true or false
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
             grip = grip, head = head, title = titleText, sub = subText, live = live, fight = fight, chat = chat,
             give = give, pick = pickBtn, faults = ft, model = model, pickKey = pickKey }
end
if ns.Encounters and ns.Encounters.Invalidate then hooksecurefunc(ns.Encounters, "Invalidate", Invalidated) end
if ns.GPList and ns.GPList.OnChange then ns.GPList.OnChange(GPChanged) end
Kit.OnTheme(function()
    if frame and frame:IsShown() then Mini.Draw() end
end)
