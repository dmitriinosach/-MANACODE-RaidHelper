local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local W = 270
local PADX = 8
local PADY = 7
local ROWS = 5
local HEADH = 18
local FOOTH = 18
local GAP = 4
local ARROW = 18
local ICONBTN = 18
local ALLW = 92
local OPENW = 100
local BAR = 3
local RETRY = 1
local RETRY_MAX = 60
local GEAR = "Interface\\Icons\\INV_Misc_Gear_01"
local BACK = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local Mini = {}
ns.GPMini = Mini
local frame, titleText, prevBtn, nextBtn, list, busyText, allBtn, openBtn, cfgBtn, backBtn, track, thumb
local current, model
local follow = true
local offset = 0
local waiter = CreateFrame("Frame")
waiter:Hide()
local due, tries = 0, 0
local function Saved()
    local s = ns.GetDB().settings
    if type(s.gpmini) ~= "table" then s.gpmini = {} end
    return s.gpmini
end
local function RaidKey(f)
    return ns.Raid and ns.Raid.Key(f.raid) or "solo"
end
local function RaidFights()
    local all = ns.Encounters and ns.Encounters.Fights() or {}
    local out = {}
    if not all[1] then return out end
    local key = RaidKey(current or all[1])
    for i = 1, #all do
        if RaidKey(all[i]) == key then out[#out + 1] = all[i] end
    end
    return out
end
local function IndexOf(fights, f)
    for i = 1, #fights do
        if fights[i] == f then return i end
    end
    return 0
end
local function TryNumber(fights, f)
    local n, total = 0, 0
    for i = 1, #fights do
        if fights[i].boss == f.boss then
            total = total + 1
            if fights[i].from <= f.from then n = n + 1 end
        end
    end
    return n, total
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
local function Outcome(f)
    return ns.Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.T(f.killed and "fl.win" or "fl.wipe") .. "|r"
end
local function Tip(owner, lines)
    if ns.Tip then ns.Tip.Show(owner, lines) end
end
local function HideTip()
    if ns.Tip then ns.Tip.Hide() end
end
local function Hint(b, title, body)
    b:SetScript("OnEnter", function(self)
        local text = type(body) == "function" and body() or body
        local lines = { { ns.T(title), "tip.body" } }
        if text then lines[2] = { text, "tip.title", true } end
        Tip(self, lines)
    end)
    b:SetScript("OnLeave", HideTip)
end
local function TitleTip()
    if not current then return end
    local fights = RaidFights()
    local n, total = TryNumber(fights, current)
    local lines = { { current.boss, "tip.body" } }
    lines[#lines + 1] = { format(ns.T("gpmini.tip.try"), n, total, Outcome(current), Clock(current.to - current.from)),
        "tip.title" }
    lines[#lines + 1] = { format(ns.T("sum.gp.preset"), ns.Penalties.Label(ns.Penalties.Active())), "text.secondary" }
    if model then
        lines[#lines + 1] = { format(ns.T("gpmini.tip.gp"), #model.items, model.pending), "tip.title" }
    end
    lines[#lines + 1] = { ns.T("gpmini.tip.help"), "tip.dim", true }
    Tip(titleText.hit, lines)
end
local function Wheel(delta)
    if not model then return end
    local most = max(0, #model.items - ROWS)
    local was = offset
    offset = max(0, min(most, offset - delta))
    if offset ~= was then Mini.Refresh() end
end
local function PaintBar(total)
    if total <= ROWS then
        track:Hide()
        thumb:Hide()
        return
    end
    local h = ROWS * ns.GPList.COMPACT.rowh
    local th = max(8, floor(h * ROWS / total))
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", BAR + 2, -floor((h - th) * offset / (total - ROWS)))
    track:Show()
    thumb:Show()
end
local function Step(step)
    local fights = RaidFights()
    local i = IndexOf(fights, current) + step
    if fights[i] then
        current = fights[i]
        follow = i == 1
        offset = 0
        Mini.Refresh()
    end
end
local function OpenSummary()
    if not current then return end
    local f = current
    if not ns.Shell then return end
    ns.Shell.Open("log")
    if ns.Timeline and ns.Timeline.ShowFight then ns.Timeline.ShowFight(f) end
end
local function Back()
    ns.GetDB().gp.mini = false
    local f = current
    frame:Hide()
    ns.GPList.Changed()
    if f then OpenSummary() end
end
local function SmallButton(name, width, label, icon)
    local b = ns.MakeButton(frame, name)
    b:SetWidth(width)
    b:SetHeight(FOOTH)
    ns.GPList.Small(b)
    if label then b.text:SetText(ns.T(label)) end
    if icon then
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetWidth(width - 6)
        t:SetHeight(FOOTH - 6)
        t:SetPoint("CENTER", 0, 0)
        t:SetTexture(icon)
        t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        b.icon = t
    end
    return b
end
local function SavePlace()
    local s = Saved()
    local point, _, _, x, y = frame:GetPoint()
    s.point, s.x, s.y = point, x, y
end
local function Build()
    local s = Saved()
    frame = CreateFrame("Frame", "HTP_FailWatchGPMini", UIParent)
    frame:SetWidth(W)
    frame:SetHeight(PADY * 2 + HEADH + GAP + ROWS * ns.GPList.COMPACT.rowh + GAP + FOOTH)
    frame:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 300, s.y or 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePlace()
    end)
    ns.Kit.Skin(frame, "float")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    frame:Hide()
    tinsert(UISpecialFrames, "HTP_FailWatchGPMini")
    prevBtn = SmallButton("HTP_FailWatchGPMiniPrev", ARROW, nil, nil)
    prevBtn:SetHeight(HEADH)
    prevBtn.text:SetText("<")
    prevBtn:SetPoint("TOPLEFT", PADX, -PADY)
    prevBtn.onClick = function() Step(1) end
    Hint(prevBtn, "gpmini.prev")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetWidth(22)
    close:SetHeight(22)
    close:SetPoint("TOPRIGHT", 0, -2)
    nextBtn = SmallButton("HTP_FailWatchGPMiniNext", ARROW, nil, nil)
    nextBtn:SetHeight(HEADH)
    nextBtn.text:SetText(">")
    nextBtn:SetPoint("TOPRIGHT", -(PADX + 16), -PADY)
    nextBtn.onClick = function() Step(-1) end
    Hint(nextBtn, "gpmini.next")
    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    titleText:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    titleText:SetHeight(HEADH)
    titleText:SetJustifyH("CENTER")
    local hit = CreateFrame("Frame", nil, frame)
    hit:SetAllPoints(titleText)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", TitleTip)
    hit:SetScript("OnLeave", HideTip)
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() frame:StartMoving() end)
    hit:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePlace()
    end)
    titleText.hit = hit
    list = ns.GPList.New(frame, "HTP_FailWatchGPMiniRow", ns.GPList.COMPACT)
    list:SetPoint("TOPLEFT", PADX, -(PADY + HEADH + GAP))
    list.onWheel = Wheel
    track = frame:CreateTexture(nil, "ARTWORK")
    track:SetWidth(BAR)
    track:SetHeight(ROWS * ns.GPList.COMPACT.rowh)
    track:SetPoint("TOPRIGHT", list, "TOPRIGHT", BAR + 2, 0)
    ns.Kit.Paint(track, "scroll.mini")
    thumb = frame:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(BAR)
    ns.Kit.Paint(thumb, "scroll.miniThumb")
    busyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    busyText:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4)
    busyText:SetWidth(W - PADX * 2 - 8)
    busyText:SetJustifyH("LEFT")
    allBtn = SmallButton("HTP_FailWatchGPMiniAll", ALLW, "gpmini.all", nil)
    allBtn:SetPoint("BOTTOMLEFT", PADX, PADY)
    allBtn.onClick = function()
        if current and model then ns.GPList.Issue(current, model.all) end
    end
    Hint(allBtn, "gpmini.all", function()
        return model and format(ns.T("gpmini.all.tip"), model.pending, #model.items) or nil
    end)
    openBtn = SmallButton("HTP_FailWatchGPMiniOpen", OPENW, "gpmini.open", nil)
    openBtn:SetPoint("LEFT", allBtn, "RIGHT", GAP, 0)
    openBtn.onClick = OpenSummary
    Hint(openBtn, "gpmini.open", ns.T("gpmini.open.tip"))
    cfgBtn = SmallButton("HTP_FailWatchGPMiniCfg", ICONBTN, nil, GEAR)
    cfgBtn:SetPoint("BOTTOMRIGHT", -PADX, PADY)
    cfgBtn.onClick = function()
        if ns.Shell then ns.Shell.Open("gp") end
    end
    Hint(cfgBtn, "gpmini.cfg", ns.T("gpmini.cfg.tip"))
    backBtn = SmallButton("HTP_FailWatchGPMiniBack", ICONBTN, nil, BACK)
    backBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -GAP, 0)
    backBtn.onClick = Back
    Hint(backBtn, "gpmini.back", ns.T("gpmini.back.tip"))
end
local function PaintHead(fights)
    local i = IndexOf(fights, current)
    if fights[i + 1] then prevBtn:Enable() else prevBtn:Disable() end
    if i > 1 then nextBtn:Enable() else nextBtn:Disable() end
    if not current then
        titleText:SetText(ns.T("gpmini.nofight"))
        return
    end
    local n = TryNumber(fights, current)
    titleText:SetText(format(ns.T("gpmini.title"), n, Outcome(current), current.boss))
end
local function PaintList()
    local width = W - PADX * 2 - BAR - 4
    if not current then
        model = nil
        list:Hide()
        busyText:SetText(ns.T("gpmini.none"))
        busyText:Show()
        PaintBar(0)
        allBtn:Disable()
        openBtn:Disable()
        return
    end
    openBtn:Enable()
    local summary = ns.Summary.Get(current)
    if not summary then
        model = nil
        list:Hide()
        busyText:SetText(ns.T("sum.busy"))
        busyText:Show()
        PaintBar(0)
        allBtn:Disable()
        local f = current
        ns.Summary.Compute(f, function()
            if frame:IsShown() and current == f then Mini.Refresh() end
        end)
        return
    end
    busyText:Hide()
    model = ns.GPList.Build(current, summary)
    offset = max(0, min(offset, #model.items - ROWS))
    list:Draw(current, model, width, offset, ROWS)
    list:Show()
    PaintBar(#model.items)
    if model.pending > 0 then allBtn:Enable() else allBtn:Disable() end
end
function Mini.Refresh()
    if not frame or not frame:IsShown() then return end
    local fights = RaidFights()
    if current and IndexOf(fights, current) == 0 then current = nil end
    if follow or not current then
        current = fights[1]
        follow = true
    end
    PaintHead(fights)
    PaintList()
    if ns.GetDB().gp.mini then backBtn:Show() else backBtn:Hide() end
end
local function Opened()
    if ns.Panel and ns.Panel.SetAlert then ns.Panel.SetAlert("gp", false) end
    if ns.Encounters.Ready() then
        Mini.Refresh()
        return
    end
    titleText:SetText(ns.T("tl.scanning"))
    list:Hide()
    busyText:SetText(ns.T("tl.scanning"))
    busyText:Show()
    ns.Encounters.Scan(function() Mini.Refresh() end)
end
function Mini.Show()
    if not frame then Build() end
    frame:Show()
    Opened()
end
function Mini.ShowFight(f)
    if not frame then Build() end
    local fights = ns.Encounters.Fights()
    current = f
    follow = f == nil or f == fights[1]
    offset = 0
    frame:Show()
    Opened()
end
function Mini.Hide()
    if frame then frame:Hide() end
end
function Mini.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end
function Mini.Toggle()
    if Mini.IsShown() then Mini.Hide() else Mini.Show() end
end
local function LastSegment()
    local last, seg
    for i, s in ns.Store.Segments() do last, seg = i, s end
    if seg and seg.bosses and next(seg.bosses) then return last end
    return nil
end
local function LastSegOf(f)
    return f.segs and f.segs[#f.segs] or f.seg
end
local function Announce(f, s)
    local m = ns.GPList.Build(f, s)
    if #m.items == 0 or m.pending <= 0 then
        if Mini.IsShown() and follow then Mini.Refresh() end
        return
    end
    if ns.Panel and ns.Panel.SetAlert and not Mini.IsShown() then ns.Panel.SetAlert("gp", true) end
    if not ns.Raid.IsLead() then
        if Mini.IsShown() and follow then Mini.Refresh() end
        return
    end
    ns.Print(format(ns.T("gp.signal"), #m.items, ns.Plural(#m.items, ns.T("gp.players")), m.pending, f.boss))
    if Mini.IsShown() and follow then Mini.Refresh() end
end
local function Check(seg)
    local f = ns.Encounters.Fights()[1]
    if not f or LastSegOf(f) ~= seg then return end
    local key = format("%s|%d", ns.Penalties.FightKey(f), floor(f.to))
    local gp = ns.GetDB().gp
    if gp.signaled == key then return end
    gp.signaled = key
    ns.Summary.Compute(f, function(s) Announce(f, s) end)
end
waiter:SetScript("OnUpdate", function(self)
    if GetTime() < due then return end
    due = GetTime() + RETRY
    tries = tries + 1
    if tries > RETRY_MAX then
        self:Hide()
        return
    end
    local seg = LastSegment()
    if not seg then
        self:Hide()
        return
    end
    local started = ns.Encounters.Scan(function()
        self:Hide()
        Check(seg)
    end)
    if not started and not ns.Encounters.Ready() then return end
    if started then self:Hide() end
end)
local function OnInvalidate()
    due = GetTime()
    tries = 0
    waiter:Show()
end
if ns.Encounters and ns.Store and ns.Summary and ns.Penalties then
    hooksecurefunc(ns.Encounters, "Invalidate", OnInvalidate)
end
if ns.GPList then ns.GPList.OnChange(function() Mini.Refresh() end) end
