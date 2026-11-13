local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Kit = ns.Kit
local W, H = 280, 240
local MIN_W, MIN_H = 180, 120
local MAX_W, MAX_H = 560, 600
local PAD = 8
local TITLEH = 20
local ROWH = 18
local GAP = 3
local WIDE_W = 400
local FRESH = 180
local FOOT = 8
local GRIP = 14
local LEADW = 30
local PCTW = 32
local VIEWPAD = 12
local PICK_ICON = 10
local PICK_MAX = 10
local BAR_A = 0.38
local TICK = 1
local RETRY = 3
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local VIEWS = { "faults", "dps", "hps", "deaths", "targets", "rolls" }
local KNOWN = { faults = true, dps = true, hps = true, deaths = true, targets = true, rolls = true }
local RATE = { dps = true, hps = true }
local VIEW_ICON = { faults = "gp", dps = "dps", hps = "hps", deaths = "death", targets = "target", rolls = "dice" }
local RAID = "raid"
local MORE_W = 260
local NAME_MIN = 64
local CHAT_SIZE = 18
local TAB = 24
local TABGAP = 4
local CORNER = 18
local CORNERGAP = 3
local TOP0 = PAD + TAB + GAP
local NAMEGAP = 6
local CHAINGAP = 4
local TITLE_MIN = 60
local PENS_PART = 0.5
local Mini = {}
ns.ShellMini = Mini
local frame, titleText, subText, head, restore, close, grip, chat, give, pickBtn, clearBtn, prevBtn, nextBtn
local bar
local titleh, rowh, leadw, pctw = TITLEH, ROWH, LEADW, PCTW
local headY
local rowTop = TOP0 + TITLEH + GAP
local seatTop
local chainMask
local older, newer
local navFight, navPick, navList, navN, navLive
local ft
local fts = {}
local rollSeen = 0
local viewBtns = {}
local rows
local pool
local list = {}
local acc = 0
local dirty = true
local live = false
local scanning = false
local fight
local model
local asked
local tries = 0
local pickKey
local pickRef
local raidShown, raidSum
local fullSeen
local seenTop
local wasCombat = false
local phase = 0
local manualPhase = -1
local rollPens
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
local function TopStamp(f)
    local state = f.killed and "killed" or (f.wipe and "wipe" or "open")
    return Key(f) .. "|" .. state
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
        local sl = ft and ft.L or ns.GPList.MINI
        return max(1, floor((frame:GetHeight() - rowTop - FOOT - sl.headh) / sl.rowh))
    end
    return max(1, floor((frame:GetHeight() - rowTop - FOOT) / rowh))
end
local function Count()
    if Faults() then return #ns.FaultTable.Rows(model, ft and ft.filter or "all") end
    return #list
end
local function OpenNow(f, who, t)
    ns.Shell.Open("log")
    if not f then return end
    if ns.Timeline and ns.Timeline.ShowFight then ns.Timeline.ShowFight(f) end
    if who and ns.TimelineLinks then ns.TimelineLinks.Focus(who, t) end
end
local function OpenRaid()
    local raid = raidShown
    if not (ns.Shell and raid) then return end
    local function Go()
        ns.Shell.Open("log")
        if ns.Timeline and ns.Timeline.ShowRaid then ns.Timeline.ShowRaid(raid) end
    end
    if ns.ShellNav then ns.ShellNav.Run(Go) else Go() end
end
local function OpenFull(f, who, t)
    if not ns.Shell then return end
    if ns.ShellNav then ns.ShellNav.Run(OpenNow, f, who, t) else OpenNow(f, who, t) end
end
local function RowEnter(self)
    local e = self.e
    if not e or not ns.Tip then return end
    local lines = e.lines or (e.tip and e.tip(e.a, e.b, e.c, e.d))
    if lines and #lines > 0 then ns.Tip.Show(self, lines) end
    local f = e.fight
    if not (e.at and f and ns.DeathPreviewView) or (ns.Store and ns.Store.Bare and ns.Store.Bare(f)) then return end
    self.fight, self.at, self.who, self.preview = f, e.at, e.who, true
    ns.DeathPreviewView.Enter(self)
end
local TipHide = Kit.HideLines
local function RowLeave()
    TipHide()
    if ns.DeathPreviewView then ns.DeathPreviewView.Leave() end
end
local function RowClick(self, button)
    local e = self.e
    if not e or e.kind == "note" or e.kind == "roll" then return end
    local f = e.fight or fight
    local whole = raidSum ~= nil
    if button == "RightButton" then
        local one = e.at ~= nil or (RATE[View()] and not whole)
        if not live and f and e.who and one and ns.GPList then ns.GPList.ManualMenu(f, e.who) end
        return
    end
    if live then
        OpenFull(nil)
    elseif e.at then
        if not (ns.ReplayLink and ns.ReplayLink.Click(f, e.at, e.who, button)) then OpenFull(f, e.who, e.at) end
    elseif whole then
        if e.fight then OpenFull(e.fight) else OpenRaid() end
    elseif View() == "targets" then
        OpenFull(fight)
    else
        OpenFull(fight, e.who)
    end
end
local function Wheel(_, delta)
    pool:Clamp(Count(), Slots())
    if pool:Wheel(delta) then Mini.Draw() end
end
local function SeatRow(r, k)
    r:SetHeight(rowh)
    local y = -(rowTop + (k - 1) * rowh)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
    r.lead:SetWidth(leadw)
    r.pct:SetWidth(pctw)
    r.laid = nil
end
local function NewRow(k)
    local r = CreateFrame("Button", nil, frame)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
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
    r.lead = Kit.Str(r, "GameFontHighlightSmall")
    r.lead:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.lead:SetJustifyH("LEFT")
    r.pct = Kit.Str(r, "GameFontHighlightSmall")
    r.pct:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.pct:SetJustifyH("RIGHT")
    r.val = Kit.Str(r, "GameFontHighlightSmall")
    r.val:SetPoint("RIGHT", r.pct, "LEFT", -4, 0)
    r.val:SetJustifyH("RIGHT")
    r.val:SetWordWrap(false)
    r.name = Kit.Str(r, "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.lead, "RIGHT", 0, 0)
    r.name:SetPoint("RIGHT", r.val, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    SeatRow(r, k)
    return r
end
local function RoundEnter(b)
    b.hovered = true
    Kit.RoundTint(b, true)
    Kit.TipShow(b)
end
local function RoundLeave(b)
    b.hovered = false
    Kit.RoundTint(b, b.active)
    Kit.TipHide()
end
local function RoundClick(b)
    Kit.TipHide()
    if b.onClick then b.onClick(b) end
end
local function Round(parent, file, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    Kit.RoundIcon(b, file)
    b.tipAnchor = "ANCHOR_TOP"
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", RoundEnter)
    b:SetScript("OnLeave", RoundLeave)
    b:SetScript("OnClick", RoundClick)
    return b
end
local function RowChat(r)
    local b = Kit.ChatButton(r, CHAT_SIZE)
    b:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    b.onClick = function(self)
        local c = r.e and r.e.chat
        local R = ns.ChatReport
        if not (c and R and ns.ProofView) then return end
        local ctx = fight and R.FightCtx(fight, ns.Summary.Peek(fight)) or nil
        ns.ProofView.ReportMenu(self, function(n) return R.Detail(c.title, ctx, c.rows, n) end, "report.menu.detail", true)
    end
    r.chat = b
    return b
end
local function PaintRow(r, e)
    r.e = e
    local note = e.kind == "note"
    Put(r.lead, e.lead or "")
    Kit.Text(r.lead, "text.note")
    if r.laid ~= e.kind then
        r.laid = e.kind
        r.name:ClearAllPoints()
        if note or e.kind == "head" or e.kind == "roll" then
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
    local wide = frame:GetWidth()
    local val = e.val or ""
    if e.more and wide >= MORE_W then val = val .. " " .. e.more end
    Put(r.val, val)
    local vw = 0
    if e.at then
        if r.valW ~= 0 then r.val:SetWidth(0) end
        local room = wide - PAD * 2 - leadw - pctw - 8 - NAME_MIN
        if r.val:GetStringWidth() > room then vw = max(40, floor(room)) end
    end
    if r.valW ~= vw then
        r.valW = vw
        r.val:SetWidth(vw)
    end
    Kit.Text(r.val, e.kind == "head" and "text.title" or (e.valTone or "text.secondary"))
    Put(r.pct, e.pct or "")
    Kit.Text(r.pct, e.pctTone or "text.note")
    if e.chat then
        local b = r.chat or RowChat(r)
        Kit.PlateSize(b, min(rowh - 2, CHAT_SIZE))
        b:Show()
    elseif r.chat then
        r.chat:Hide()
    end
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
pool = Kit.List(NewRow, PaintRow, { clear = function(r) r.e = nil end })
rows = pool.rows
local function DrawFaults()
    local wide = frame:GetWidth() >= WIDE_W
    local key = wide and "wide" or "mini"
    local t = fts[key]
    if not t then
        t = ns.GPList.New(frame, wide and "HTP_FailWatchShellMiniFaultWide" or "HTP_FailWatchShellMiniFault",
            wide and ns.GPList.COMPACT or ns.GPList.MINI, true)
        t.onWheel = function(delta) Wheel(nil, delta) end
        fts[key] = t
    end
    if ft and ft ~= t then ft:Hide() end
    ft = t
    ft:ClearAllPoints()
    ft:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -rowTop)
    ft:Draw(fight, model, frame:GetWidth() - PAD * 2, pool.offset, Slots())
    ft:Show()
end
local function PickLabel(f)
    local spot = ns.FightTree and ns.FightTree.Spot(f)
    local when = date("%H:%M", f.from)
    local tail = Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.Clock(max(0, f.to - f.from)) .. "|r"
    if spot and spot.n then return format(ns.T("mini.pick.row"), spot.n, ns.EncName(f.boss), when, tail) end
    return format(ns.T("mini.pick.row1"), ns.EncName(f.boss), when, tail)
end
local function Shown(w, on)
    if on then w:Show() else w:Hide() end
end
local function Neighbors()
    local E = ns.Encounters
    local fights = E and E.Ready() and E.Fights() or nil
    local n = fights and #fights or 0
    if navFight == fight and navPick == pickKey and navList == fights and navN == n and navLive == live then return end
    navFight, navPick, navList, navN, navLive = fight, pickKey, fights, n, live
    local was1, was2 = older, newer
    older, newer = nil, nil
    if pickKey == RAID then
        prevBtn.tip, nextBtn.tip = nil, ns.T("mini.current")
        return
    end
    if n == 0 then return end
    local idx = 0
    if fight then
        for i = 1, n do
            if fights[i] == fight then idx = i break end
        end
    end
    local spot = ns.FightTree and ns.FightTree.Spot(fight or fights[1])
    local raid = spot and spot.raid
    for i = idx + 1, n do
        local sp = raid and ns.FightTree.Spot(fights[i])
        if not raid or (sp and sp.raid == raid) then older = fights[i] break end
    end
    if pickKey ~= nil then
        for i = idx - 1, 1, -1 do
            local sp = raid and ns.FightTree.Spot(fights[i])
            if not raid or (sp and sp.raid == raid) then newer = fights[i] break end
        end
    end
    if older ~= was1 then prevBtn.tip = older and PickLabel(older) or nil end
    if newer ~= was2 or not newer then nextBtn.tip = newer and PickLabel(newer) or (pickKey and ns.T("mini.current")) or nil end
end
local function Chain()
    local mask = (give:IsShown() and 1 or 0) + (clearBtn:IsShown() and 2 or 0) + (chat:IsShown() and 4 or 0)
        + (subText:IsShown() and 8 or 0) + (nextBtn:IsShown() and 16 or 0) + (pickBtn:IsShown() and 32 or 0)
    if mask == chainMask then return end
    chainMask = mask
    local items = { give, clearBtn, chat, subText, nextBtn, prevBtn }
    local prev
    for i = 1, #items do
        local it = items[i]
        if it:IsShown() then
            it:ClearAllPoints()
            if prev then
                it:SetPoint("RIGHT", prev, "LEFT", it == prevBtn and 0 or -CHAINGAP, 0)
            else
                it:SetPoint("RIGHT", head, "RIGHT", 0, 0)
            end
            prev = it
        end
    end
    titleText:ClearAllPoints()
    if pickBtn:IsShown() then
        titleText:SetPoint("LEFT", pickBtn, "RIGHT", 2, 0)
    else
        titleText:SetPoint("LEFT", head, "LEFT", 2, 0)
    end
    if prev then
        titleText:SetPoint("RIGHT", prev, "LEFT", -NAMEGAP, 0)
    else
        titleText:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    end
end
local function PaintHead()
    local view = View()
    local on = Faults() and model.pending > 0
    local rolls = view == "rolls"
    if rolls then
        if ns.RollPen.Count() > 0 then clearBtn:Enable() else clearBtn:Disable() end
    end
    Shown(clearBtn, rolls)
    Shown(chat, RATE[view] or rolls)
    Shown(subText, (RATE[view] or view == "deaths") and (subText.miniText or "") ~= "")
    Shown(pickBtn, not rolls)
    Shown(prevBtn, not rolls)
    Shown(nextBtn, not rolls)
    if on then
        give.text:SetText(ns.GPList.AllText(model))
        give:SetWidth(floor(give.text:GetStringWidth() + VIEWPAD + 0.5))
        give.tip = format(ns.T("gpmini.all.tip"), ns.GPList.SumText(model.by), model.ready)
            .. ((model.raid or 0) > 0 and format(ns.T("sum.gp.title.roll"), model.raid) or "")
    end
    Shown(give, on)
    if not rolls then
        Neighbors()
        if older then prevBtn:Enable() else prevBtn:Disable() end
        if pickKey ~= nil then nextBtn:Enable() else nextBtn:Disable() end
    end
    Chain()
end
local function PlaceHead(y)
    if y ~= headY then
        headY = y
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    end
    rowTop = y + titleh + GAP
    if seatTop ~= rowTop then
        seatTop = rowTop
        for k = 1, #rows do SeatRow(rows[k], k) end
    end
end
local function PlaceRolls()
    if not rollPens then rollPens = ns.Badges.Detail(frame, nil, true) end
    local h = frame:GetHeight()
    local room = min(floor((h - TOP0 - FOOT) * PENS_PART), h - TOP0 - FOOT - titleh - GAP * 2 - rowh * 2)
    local offset = rollPens.offset or 0
    local raid, alt = ns.RollPen.Here()
    if rollPens.raid ~= raid or rollPens.alt ~= alt then offset = 0 end
    rollPens.raid, rollPens.alt = raid, alt
    rollPens.fixed = ns.Badges.Reach(rollPens, room)
    rollPens:SetModel(ns.FaultsRoll.SummaryModel(raid, alt))
    rollPens.offset = offset
    rollPens:ClearAllPoints()
    rollPens:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP0)
    local used = rollPens:Layout(frame:GetWidth() - PAD * 2)
    rollPens:Redraw()
    rollPens:Show()
    return TOP0 + used + GAP
end
function Mini.Draw()
    if not frame then return end
    if View() == "rolls" then
        PlaceHead(PlaceRolls())
    else
        if rollPens then rollPens:Hide() end
        PlaceHead(TOP0)
    end
    PaintHead()
    local n = Slots()
    pool:Clamp(Count(), n)
    if Faults() then
        pool:Hide()
        DrawFaults()
        return
    end
    if ft then ft:Hide() end
    pool:Draw(list, n)
end
local function Title(text, sub)
    Put(titleText, text)
    Put(subText, sub or "")
end
local function Outcome(f)
    return Kit.Hex(f.killed and "sem.win" or "sem.wipe") .. ns.T(f.killed and "fl.win" or "fl.wipe") .. "|r"
end
local function FightTitle(f)
    local clock = ns.Clock(max(0, f.to - f.from))
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
    if frame and frame:IsShown() and (View() == "faults" or View() == "rolls") then Mini.Rebuild() end
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
local function Pending()
    local live = ns.Store and ns.Store.Live()
    return live ~= nil and live.pull ~= nil
end
local function Ask(f)
    local S = ns.Summary
    local s = S.Peek(f)
    if s then return s, false end
    if not Calm() or S.Busy(f) then return nil, true end
    if asked == f then
        if tries >= RETRY or (S.Failed and S.Failed(f)) then return nil, false end
        tries = tries + 1
    else
        asked, tries = f, 0
    end
    S.Of(f, Again)
    s = S.Peek(f)
    return s, s == nil
end
local function Chosen(fights)
    Adopt(fights)
    if pickKey == RAID then return (pickRef and Find(fights, pickRef)) or fights[1] end
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
    Title(format(ns.T("mini.live"), ns.Clock(sec)), ns.Rate(rate))
    return true
end
local function FightRows(f, s)
    local view = View()
    local sub
    if RATE[view] then
        sub = ns.Rate(ns.MiniRows.Dps(list, s, view == "hps"))
    elseif view == "deaths" then
        sub = ns.MiniRows.Deaths(list, f, s)
    elseif view == "targets" then
        ns.MiniRows.Targets(list, f, s)
    else
        model = ns.GPList and ns.GPList.Build(f, s) or nil
        if not model then Only(ns.T("gpmini.none")) end
    end
    Title(FightTitle(f), sub)
end
local function RaidRows(ref)
    local spot = ns.FightTree and ns.FightTree.Spot(ref)
    local raid = spot and spot.raid
    if not raid then return false end
    local R = ns.MiniRows
    local sum = R.Raid(ns.FightTree.RaidFights(raid), ns.Summary.Peek)
    raidShown, raidSum = raid, sum
    local view = View()
    local sub
    if RATE[view] then
        sub = ns.Rate(R.Dps(list, sum, view == "hps"))
    elseif view == "deaths" then
        sub = R.RaidDeaths(list, sum, FightTitle)
    else
        Only(ns.T("mini.raid.only"))
    end
    if sum.miss > 0 then Only(format(ns.T("mini.raid.miss"), sum.miss)) end
    Title(format(ns.T("mini.raid.title"), sum.n, ns.Clock(sum.dur)), sub)
    return true
end
local function RollRows()
    local R, FR = ns.RollPen, ns.FaultsRoll
    local throws, best = R.Throws(), R.Best()
    for i = 1, #throws do
        local t = throws[i]
        local val = FR.Range(t)
        if t.pen > 0 then val = val .. " " .. Kit.Hex("text.bad") .. FR.Minus(t.pen) .. "|r" end
        list[#list + 1] = { kind = "roll", who = t.who, left = FR.Who(t.who), class = ClassOf(t.who), val = val,
            valTone = "text.bright", pct = tostring(t.net), pctTone = t.net == best and "text.good" or "text.bright",
            lines = FR.SoftTip(t.who) }
    end
    if not throws[1] then Only(ns.T("roll.throws.empty")) end
    Title(format(ns.T("roll.throws"), #throws))
end
local function WantLive()
    local M = ns.Meter
    return RATE[View()] and pickKey == nil and M ~= nil and M.Fighting() or false
end
function Mini.Rebuild()
    if not frame then return end
    dirty = false
    wipe(list)
    model, raidSum = nil, nil
    if View() == "rolls" then
        live = false
        RollRows()
        Mini.Draw()
        return
    end
    live = WantLive() and LiveRows(View() == "hps")
    if live then
        fight = nil
        Mini.Draw()
        return
    end
    local fights = Fights()
    local f = fights and Chosen(fights)
    local wait = f ~= nil and pickKey == nil and Pending()
    if wait then
        f = nil
        dirty = true
    end
    fight = f
    local rate = RATE[View()]
    if not f then
        local key = scanning and "tl.scanning" or (wait and "sum.busy" or "gpmini.nofight")
        Title(ns.T(key))
        if not (rate and LiveRows(View() == "hps")) and not wait then
            Only(ns.T(scanning and "tl.scanning" or "gpmini.none"))
        end
        Mini.Draw()
        return
    end
    if pickKey == RAID then
        if RaidRows(f) then
            Mini.Draw()
            return
        end
        pickKey = nil
    end
    local s, more = Ask(f)
    if s then
        FightRows(f, s)
    else
        if more then dirty = true end
        if not (rate and pickKey == nil and LiveRows(View() == "hps")) then
            Title(FightTitle(f))
            Only(ns.T("sum.busy"))
        end
    end
    Mini.Draw()
end
local function SetOn(b, on)
    b.active = on
    Kit.RoundTint(b, on or b.hovered)
end
local function PaintTabs(key)
    for i = 1, #VIEWS do SetOn(viewBtns[VIEWS[i]], VIEWS[i] == key) end
    if RATE[key] or key == "rolls" then
        chat.tip = ns.T(key == "rolls" and "roll.report.tip" or (key == "hps" and "report.tip.heal" or "report.tip"))
    end
end
local function SetView(key, auto)
    if not auto then manualPhase = phase end
    Saved().view = key
    pool.offset = 0
    PaintTabs(key)
    if key == "faults" and ns.Panel and ns.Panel.SetAlert then ns.Panel.SetAlert("gp", false) end
    Mini.Rebuild()
end
function Mini.SetView(key)
    if frame and frame:IsShown() and KNOWN[key] then SetView(key, key == View()) end
end
function Mini.View()
    return View()
end
local function Fighting()
    local M = ns.Meter
    if M then return M.Fighting() and true or false end
    return UnitAffectingCombat("player") and true or false
end
local function Watch()
    local combat = Fighting()
    if combat ~= wasCombat then
        wasCombat = combat
        phase = phase + 1
        if combat then
            pickKey = nil
            if not RATE[View()] then SetView("dps", true) end
            dirty = true
        end
    end
    local E = ns.Encounters
    local top = E and E.Ready() and E.Fights()[1]
    if not top then return end
    local k = TopStamp(top)
    if seenTop == nil then seenTop = (time() - (top.to or 0) > FRESH) and k or false end
    if combat or k == seenTop then return end
    if not (GetNumRaidMembers() > 0 and ns.Raid.IsLead()) then
        seenTop = k
        return
    end
    local s = pickKey and ns.Summary.Peek(top) or (not pickKey and Ask(top))
    if not s then return end
    seenTop = k
    if manualPhase == phase then return end
    local m = ns.GPList and ns.GPList.Build(top, s)
    if not (m and m.pending > 0) then return end
    pickKey = nil
    SetView("faults", true)
end
local function Rolled()
    local n = ns.RollPen.Count()
    local grew = n > rollSeen
    rollSeen = n
    if not (frame and frame:IsShown()) then return end
    if View() == "rolls" then
        Mini.Rebuild()
    elseif grew and Calm() and manualPhase ~= phase then
        SetView("rolls", true)
    end
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
    pool.offset, asked = 0, nil
    Mini.Rebuild()
end
local function ChooseRaid(ref)
    pickKey, pickRef = RAID, ref and Key(ref) or nil
    manualPhase = phase
    pool.offset, asked = 0, nil
    Mini.Rebuild()
end
function Mini.Pick(f)
    if not frame then return end
    local E = ns.Encounters
    local top = E and E.Ready() and E.Fights()[1]
    Choose((f and top and Key(f) ~= Key(top)) and f or nil)
end
local function Step(step)
    local E = ns.Encounters
    local fights = E and E.Ready() and E.Fights()
    if not fights then return end
    if step < 0 then
        if older then Choose(older) end
    elseif pickKey ~= nil then
        if newer == fights[1] then newer = nil end
        Choose(newer)
    end
end
local function PickMenu(self)
    local E = ns.Encounters
    local fights = E and E.Ready() and E.Fights() or {}
    local ref = fight or fights[1]
    local spot = ref and ns.FightTree and ns.FightTree.Spot(ref)
    local raid = spot and spot.raid
    local items = { { text = ns.T("mini.pick"), isTitle = true } }
    items[2] = { text = ns.T("mini.current"), checked = pickKey == nil, func = function() Choose(nil) end }
    if raid then
        items[3] = { text = ns.T("mini.raid"), checked = pickKey == RAID, func = function() ChooseRaid(ref) end }
    end
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
    if raidSum then
        local rows = {}
        for i = 1, #raidSum.players do
            local p = raidSum.players[i]
            local v = heal and p.heal or p.goodDmg
            if v > 0 then rows[#rows + 1] = { who = p.name, v = v } end
        end
        local head = format(ns.T(heal and "report.head.raid.heal" or "report.head.raid"), raidSum.n, ns.Clock(raidSum.dur))
        return ns.ChatReport.Lines(head, ns.Totals.Time(raidSum), rows, n)
    end
    local s = fight and ns.Summary.Peek(fight)
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
    if live then lines[#lines + 1] = { kind = "text", left = ns.T("mini.head.live") } end
    lines[#lines + 1] = { kind = "foot", key = "lmb", left = ns.T(live and "mini.head.live.act" or "mini.head.tip") }
    ns.Tip.Show(self, lines)
end
local function RowButton(kind)
    local b = Kit.Button(frame, nil, kind)
    Kit.RoundButton(b)
    Kit.ExactSize(b)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b.tipAnchor = "ANCHOR_TOP"
    return b
end
local function Dims()
    titleh, rowh = Kit.FontGrow(TITLEH), Kit.FontGrow(ROWH)
    leadw, pctw = Kit.FontGrow(LEADW), Kit.FontGrow(PCTW)
    headY, seatTop, chainMask = nil, nil, nil
end
local function Size(b, w)
    b:SetWidth(w or floor(b.text:GetStringWidth() + VIEWPAD + 0.5))
    b:SetHeight(titleh)
end
local function Seat()
    for i = 1, #VIEWS do
        local b = viewBtns[VIEWS[i]]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * (TAB + TABGAP), -PAD)
    end
    local cy = -(PAD + (TAB - CORNER) / 2)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, cy)
    restore:ClearAllPoints()
    restore:SetPoint("RIGHT", close, "LEFT", -CORNERGAP, 0)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", viewBtns[VIEWS[#VIEWS]], "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", restore, "BOTTOMLEFT", 0, -(TAB - CORNER) / 2)
    head:SetHeight(titleh)
    Size(give)
    Size(clearBtn)
    Size(prevBtn, titleh)
    Size(nextBtn, titleh)
    local cs = min(titleh, Kit.FontGrow(CHAT_SIZE))
    Kit.PlateSize(chat, cs)
    local ps = Kit.FontGrow(PICK_ICON)
    pickBtn.icon:SetWidth(ps)
    pickBtn.icon:SetHeight(ps)
    pickBtn:SetWidth(ps + 6)
    pickBtn:SetHeight(ps + 6)
    local topW = PAD * 2 + #VIEWS * TAB + (#VIEWS - 1) * TABGAP + NAMEGAP + CORNER * 2 + CORNERGAP
    local rowW = PAD * 2 + pickBtn:GetWidth() + TITLE_MIN + NAMEGAP + prevBtn:GetWidth() * 2
        + max(give:GetWidth(), clearBtn:GetWidth() + chat:GetWidth()) + CHAINGAP * 2
    local minW = min(MAX_W, max(MIN_W, topW, rowW))
    local minH = min(MAX_H, max(MIN_H, TOP0 + titleh + GAP + FOOT + rowh * 4 + 14))
    frame:SetMinResize(minW, minH)
    if frame:GetWidth() < minW then frame:SetWidth(minW) end
    if frame:GetHeight() < minH then frame:SetHeight(minH) end
end
local function BuildTabs()
    for i = 1, #VIEWS do
        local key = VIEWS[i]
        local label = "mini.view." .. key
        local b = Round(frame, VIEW_ICON[key], TAB)
        b.tipTitle = ns.T(label)
        b.tip = ns.T(label .. ".tip")
        b.onClick = function() SetView(key) end
        viewBtns[key] = b
    end
end
local function BuildWin()
    close = Round(frame, "close", CORNER)
    close.tipTitle = ns.T("kit.win.close")
    close.onClick = function()
        if ns.Shell then ns.Shell.Hide() else frame:Hide() end
    end
    restore = Round(frame, "expand", CORNER)
    restore.tipTitle = ns.T("kit.strip.restore")
    restore.tip = ns.T("mini.restore.tip")
    restore.onClick = function() if ns.Shell then ns.Shell.Open() end end
    bar = CreateFrame("Button", nil, frame)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() Mini.SavePlace() end)
    bar:SetScript("OnDoubleClick", function() restore.onClick(restore) end)
end
local function NavButton(label, tip, step)
    local b = RowButton("quiet")
    b.text:SetText(label)
    b.tipTitle = ns.T(tip)
    b.onClick = function() Step(step) end
    return b
end
local function BuildHead()
    BuildTabs()
    BuildWin()
    head = CreateFrame("Button", nil, frame)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() frame:StartMoving() end)
    head:SetScript("OnDragStop", function() Mini.SavePlace() end)
    head:SetScript("OnEnter", HeadEnter)
    head:SetScript("OnLeave", TipHide)
    head:SetScript("OnClick", function()
        if raidSum then OpenRaid() else OpenFull(not live and fight or nil) end
    end)
    local level = head:GetFrameLevel() + 2
    chat = Kit.ChatButton(frame, CHAT_SIZE)
    chat:SetFrameLevel(level)
    chat.tip = ns.T("report.tip")
    chat.onClick = function(self)
        if View() == "rolls" then
            ns.RollPen.Report()
        elseif ns.ProofView then
            local heal = View() == "hps"
            ns.ProofView.ReportMenu(self, ReportLines, heal and "report.menu.heal" or nil, nil, heal and "report.none.heal" or nil)
        end
    end
    pickBtn = Kit.IconButton(frame, nil, PICK_ICON)
    Kit.Arrow(pickBtn.icon, false)
    pickBtn:SetPoint("LEFT", head, "LEFT", 0, 0)
    pickBtn:SetFrameLevel(level)
    pickBtn.tipTitle = ns.T("mini.pick")
    pickBtn.tip = ns.T("mini.pick.tip")
    pickBtn.tipAnchor = "ANCHOR_TOP"
    pickBtn.onClick = PickMenu
    prevBtn = NavButton("<", "fl.nav.prev", -1)
    nextBtn = NavButton(">", "fl.nav.next", 1)
    prevBtn:SetFrameLevel(level)
    nextBtn:SetFrameLevel(level)
    give = RowButton("main")
    give.text:SetText(ns.T("gpmini.all"))
    give:SetFrameLevel(level)
    give.tipTitle = ns.T("gpmini.all")
    give.onClick = function()
        if fight and model then ns.GPList.Issue(fight, model.all) end
    end
    give:Hide()
    clearBtn = RowButton("quiet")
    clearBtn.text:SetText(ns.T("roll.clear"))
    clearBtn:SetFrameLevel(level)
    clearBtn.tipTitle = ns.T("roll.clear")
    clearBtn.tip = ns.T("roll.clear.tip")
    clearBtn.onClick = function() ns.RollPen.Clear() end
    clearBtn:Hide()
    subText = Kit.Str(head, "GameFontHighlightSmall")
    subText:SetJustifyH("RIGHT")
    Kit.Text(subText, "sem.stat.dps")
    titleText = Kit.Str(head, "GameFontNormalSmall")
    Kit.Text(titleText, "text.title")
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
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
        Kit.SelectClose()
        if ns.Meter then
            ns.Meter.Split(false)
            ns.Meter.Want("mini", false)
        end
    end)
    frame:SetScript("OnUpdate", ns.Prof.Wrap("hot.panel", Tick))
    frame:Hide()
    frame.sized = true
    Kit.Skin(frame, "float")
    Dims()
    BuildHead()
    BuildGrip()
    Seat()
    PaintTabs(View())
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
    pool.offset, asked, seenTop = 0, nil, nil
    rollSeen = ns.RollPen.Count()
    wasCombat = Fighting()
    frame:Show()
    if View() == "faults" and ns.Panel and ns.Panel.SetAlert then ns.Panel.SetAlert("gp", false) end
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
             give = give, pick = pickBtn, faults = ft, model = model, pickKey = pickKey, clear = clearBtn, rollPens = rollPens,
             prev = prevBtn, next = nextBtn, bar = bar, headY = headY, rowTop = rowTop, raid = raidSum }
end
if ns.Encounters and ns.Encounters.Invalidate then hooksecurefunc(ns.Encounters, "Invalidate", Invalidated) end
if ns.GPList and ns.GPList.OnChange then ns.GPList.OnChange(GPChanged) end
if ns.RollPen then ns.RollPen.OnChange(Rolled) end
Kit.OnTheme(function()
    if not frame then return end
    Seat()
    if frame:IsShown() then Mini.Draw() end
end)
Kit.OnFont(function()
    if not frame then return end
    Dims()
    Seat()
    for k = 1, #rows do rows[k].laid = nil end
    if frame:IsShown() then Mini.Draw() end
end)
