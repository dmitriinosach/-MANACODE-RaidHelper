local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local Kit = ns.Kit
local WIDTH = 240
local GUTTER = 10
local COLW = WIDTH - GUTTER
local BARGAP = 2
local RAIDH = 36
local ENCH = 20
local ENCX = 0
local ENCNAME = 5
local WIPEH = 15
local WIPEX = 8
local HEADH = 16
local LISTGAP = 8
local PHEADH = 16
local PROW = 15
local TREEMIN = 3
local PCOLS = 2
local PCOLW = floor(COLW / PCOLS)
local WHEEL = 2
local ICON = 26
local ICONX = 5
local HCW = 11
local HCH = 12
local FOLDSZ = 8
local FOLDHIT = 16
local FOLDX = ICONX + ICON + 3
local TEXTX = FOLDX + FOLDSZ + 2
local TEXTTOP = -5
local INFOTOP = -19
local RAIDR = 7
local OKSZ = 11
local TIPMAX = 10
local OKX = -6
local DOT = 4
local DOTGAP = 2
local DOTS = 5
local DOTX = 22
local NAVBTN = 18
local NAVGAP = 4
local PLAYSZ = 10
local PLAYW = PLAYSZ + 4
local LFG = "Interface\\LFGFrame\\LFGIcon-"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local READY = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local NOTREADY = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local INST_ICON = {
    ["Цитадель Ледяной Короны"] = LFG .. "IcecrownCitadel",
    ["Рубиновое святилище"] = LFG .. "RubySanctum",
    ["Ульдуар"] = LFG .. "Ulduar",
    ["Испытание крестоносца"] = LFG .. "ArgentRaid",
    ["Испытание великого крестоносца"] = LFG .. "ArgentRaid",
    ["Наксрамас"] = LFG .. "Naxxramas",
    ["Око Вечности"] = LFG .. "Malygos",
    ["Обсидиановое святилище"] = LFG .. "ChamberOfAspects",
    ["Логово Ониксии"] = LFG .. "OnyxiaEncounter",
}
local STEP = { raid = RAIDH + 2, enc = ENCH + 1, wipe = WIPEH + 1 }
local FL = {}
ns.FightList = FL
FL.WIDTH = WIDTH
local side, treeBox, treeBar, playerHead, playerCtx, playerBox
local pools = { raid = {}, enc = {}, wipe = {} }
local used = { raid = 0, enc = 0, wipe = 0 }
local cells = {}
local lines = {}
local treeOffset = 0
local rowW = COLW
local treeH, playerLines, sideH = 0, 0, 0
local fight, player
local nav, navPrev, navNext, navNo, navOut
local faults, faultsFor, faultsSum, asked
local openEnc
local Tips = {}
local Del = {}
local gone = setmetatable({}, { __mode = "k" })
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
local function Hour(t)
    return date("%H:%M", t)
end
local function When(raid)
    local day = date("%d.%m", raid.from)
    local tail = date("%d.%m", raid.to) == day and Hour(raid.to) or date("%d.%m %H:%M", raid.to)
    return format(ns.T("fl.when"), day, Hour(raid.from), tail)
end
local function Skulls(n)
    if n <= 0 then return "" end
    return format("|T%s:0|t%d", SKULL, n)
end
local function Line(text, token, gap)
    if not token then return { text, "tip.title", gap } end
    local r, g, b = Kit.Color(token)
    return { text, r, g, b, gap }
end
function FL.Fit(fs, text, width)
    fs:SetWidth(width)
    fs:SetText(text)
    if fs:GetStringWidth() <= width then return end
    local cut = text
    while #cut > 1 do
        local i = #cut
        while i > 1 do
            local b = cut:byte(i)
            if b < 128 or b >= 192 then break end
            i = i - 1
        end
        cut = cut:sub(1, i - 1)
        fs:SetText(cut .. "…")
        if fs:GetStringWidth() <= width then return end
    end
    fs:SetText("…")
end
local Fit = FL.Fit
local function Label(parent, font, h, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetHeight(h)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end
local function Tone(fs, token)
    local r, g, b = Kit.Color(token)
    fs:SetTextColor(r, g, b)
end
local function Fill(tex, token, a)
    local r, g, b, ca = Kit.Color(token)
    tex:SetTexture(r, g, b, a or ca)
end
local function RaidName(raid)
    return raid.name or ns.T("raid.none")
end
local function Folds()
    local ui = ns.GetDB().settings.ui
    if type(ui.raidFold) ~= "table" then ui.raidFold = {} end
    return ui.raidFold
end
local function Folded(raid, index)
    local v = Folds()[raid.key]
    if v == nil then return index > 1 end
    return v
end
function FL.Title(f)
    if not f then return "" end
    return f.boss
end
local function TryTitle(f)
    if not f then return "" end
    local spot = ns.FightTree.Spot(f)
    if not spot then return f.boss end
    return format(ns.T("fl.try.title"), f.boss, spot.n)
end
local function Outcome(f)
    return format(ns.T(f.killed and "fl.tip.try.win" or "fl.tip.try.wipe"), Clock(f.to - f.from))
end
local function OnEnter(self)
    self.hover:Show()
    if self.mark then self.mark:Show() end
    local build = Tips[self.kind]
    if build then ns.Tip.Show(self, build(self)) end
end
local function OnLeave(self)
    self.hover:Hide()
    if self.mark and not self.picked then self.mark:Hide() end
    ns.Tip.Hide()
end
local function OnClick(self, button)
    ns.Tip.Hide()
    if self.onClick then self.onClick(self, button) end
end
local function NewRow(parent, kind, w, h)
    local r = CreateFrame("Button", nil, parent)
    r:SetWidth(w)
    r:SetHeight(h)
    r.kind = kind
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hover = r:CreateTexture(nil, "BORDER")
    r.hover:SetAllPoints()
    Kit.Paint(r.hover, "row.bgHover")
    r.hover:Hide()
    r:SetScript("OnEnter", OnEnter)
    r:SetScript("OnLeave", OnLeave)
    r:SetScript("OnClick", OnClick)
    return r
end
local Redraw, Toggle
local function Open(f)
    if ns.Timeline and ns.Timeline.ShowFight then ns.Timeline.ShowFight(f) end
end
local function WipesEnter(self)
    local row = self.row
    row.hover:Show()
    local enc = row.line.enc
    local key = openEnc == enc.key and "fl.tip.wipes.fold" or "fl.tip.wipes.open"
    ns.Tip.Show(self, { Line(format(ns.T(key), ns.FightTree.Wipes(enc))) })
end
local function WipesLeave(self)
    self.row.hover:Hide()
    ns.Tip.Hide()
end
local function WipesClick(self)
    ns.Tip.Hide()
    Toggle(self.row)
end
local function OnWipe(row, button)
    if button == "RightButton" then
        Del.WipeMenu(row)
        return
    end
    Open(row.line.fight)
end
local function RaidShown(raid)
    local view = ns.RaidSummaryView
    return view ~= nil and view.ShownKey() == raid.key
end
local function FoldKey(raid, index)
    Folds()[raid.key] = not Folded(raid, index)
    Redraw()
end
local function FoldRaid(row)
    FoldKey(row.line.raid, row.line.index)
end
local function OnRaid(row, button)
    local line = row.line
    local show = ns.Timeline and ns.Timeline.ShowRaid
    if button == "RightButton" then
        Del.RaidMenu(row)
        return
    end
    if not show then
        FoldRaid(row)
        return
    end
    if RaidShown(line.raid) then return end
    Folds()[line.raid.key] = false
    show(line.raid)
end
local function FoldClick(self)
    ns.Tip.Hide()
    FoldRaid(self.row)
end
local function FoldEnter(self)
    self.row.hover:Show()
    local line = self.row.line
    ns.Tip.Show(self, { Line(ns.T(Folded(line.raid, line.index) and "fl.tip.raid.open" or "fl.tip.raid.fold")) })
end
local function FoldLeave(self)
    self.row.hover:Hide()
    ns.Tip.Hide()
end
local function OnEnc(row, button)
    if button == "RightButton" then
        Del.EncMenu(row)
        return
    end
    Open(ns.FightTree.Decisive(row.line.enc))
end
local function RaidRow()
    local r = NewRow(treeBox, "raid", COLW, RAIDH)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetWidth(3)
    r.mark:SetPoint("TOPLEFT", 0, -3)
    r.mark:SetPoint("BOTTOMLEFT", 0, 3)
    Kit.Paint(r.mark, "text.accent")
    r.mark:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(ICON)
    r.icon:SetHeight(ICON)
    r.icon:SetPoint("LEFT", ICONX, 0)
    r.hc = r:CreateTexture(nil, "OVERLAY")
    r.hc:SetWidth(HCW)
    r.hc:SetHeight(HCH)
    r.hc:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -2, 2)
    Kit.Icon.Heroic(r.hc)
    r.size = r:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    r.size:SetJustifyH("RIGHT")
    r.size:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -1)
    r.size:SetShadowOffset(1, -1)
    r.size:SetShadowColor(Kit.Color("text.shadow"))
    Kit.Text(r.size, "text.primary")
    r.foldBtn = CreateFrame("Button", nil, r)
    r.foldBtn:SetWidth(FOLDHIT)
    r.foldBtn:SetHeight(FOLDHIT)
    r.foldBtn:SetPoint("BOTTOMRIGHT", -RAIDR + 4, 2)
    r.foldBtn:RegisterForClicks("LeftButtonUp")
    r.foldBtn.row = r
    r.foldBtn:SetScript("OnClick", FoldClick)
    r.foldBtn:SetScript("OnEnter", FoldEnter)
    r.foldBtn:SetScript("OnLeave", FoldLeave)
    r.fold = r.foldBtn:CreateTexture(nil, "ARTWORK")
    r.fold:SetWidth(FOLDSZ + 2)
    r.fold:SetHeight(FOLDSZ + 2)
    r.fold:SetPoint("CENTER")
    Kit.Tint(r.fold, "text.title")
    r.name = Label(r, "GameFontNormalSmall", 12)
    r.name:SetPoint("TOPLEFT", FOLDX, TEXTTOP)
    Kit.Text(r.name, "text.title")
    r.score = Label(r, "GameFontHighlightSmall", 12, "RIGHT")
    r.score:SetPoint("TOPRIGHT", -RAIDR, TEXTTOP)
    r.info = Label(r, "GameFontHighlightSmall", 12)
    r.info:SetPoint("TOPLEFT", FOLDX, INFOTOP)
    Kit.Text(r.info, "text.primary")
    r.onClick = OnRaid
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return r
end
local function EncRow()
    local r = NewRow(treeBox, "enc", COLW - ENCX, ENCH)
    Kit.Paint(r.bg, "sem.enc")
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", 0, 0)
    r.stripe:SetPoint("BOTTOMLEFT", 0, 0)
    r.name = Label(r, "GameFontHighlightSmall", 12)
    r.name:SetPoint("LEFT", ENCNAME, 0)
    r.count = Label(r, "GameFontHighlightSmall", 12, "RIGHT")
    Kit.Text(r.count, "sem.wipe")
    r.dots = {}
    for i = 1, DOTS do
        local d = r:CreateTexture(nil, "ARTWORK")
        d:SetWidth(DOT)
        d:SetHeight(DOT)
        d:SetPoint("RIGHT", -(DOTX + (i - 1) * (DOT + DOTGAP)), 0)
        Kit.Paint(d, "sem.wipe")
        r.dots[i] = d
    end
    r.ok = r:CreateTexture(nil, "ARTWORK")
    r.ok:SetWidth(OKSZ)
    r.ok:SetHeight(OKSZ)
    r.ok:SetPoint("RIGHT", OKX, 0)
    local w = CreateFrame("Button", nil, r)
    w:SetHeight(ENCH)
    w:RegisterForClicks("LeftButtonUp")
    w.row = r
    w:SetScript("OnEnter", WipesEnter)
    w:SetScript("OnLeave", WipesLeave)
    w:SetScript("OnClick", WipesClick)
    r.wipes = w
    r.wipeOn = r:CreateTexture(nil, "BORDER")
    r.wipeOn:SetAllPoints(w)
    r.play = ns.ReplayLink.Mini(r, PLAYSZ)
    r.onClick = OnEnc
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return r
end
local function WipeRow()
    local r = NewRow(treeBox, "wipe", COLW - WIPEX, WIPEH)
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", 0, 0)
    r.stripe:SetPoint("BOTTOMLEFT", 0, 0)
    r.name = Label(r, "GameFontHighlightSmall", 12)
    r.name:SetPoint("LEFT", ENCNAME, 0)
    r.play = ns.ReplayLink.Mini(r, PLAYSZ)
    r.play:SetPoint("RIGHT", -2, 0)
    r.onClick = OnWipe
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return r
end
local MAKE = { raid = RaidRow, enc = EncRow, wipe = WipeRow }
local function Take(kind)
    local n = used[kind] + 1
    used[kind] = n
    local pool = pools[kind]
    local r = pool[n]
    if not r then
        r = MAKE[kind]()
        pool[n] = r
    end
    r:Show()
    return r
end
local function PaintRaid(r, line)
    local raid = line.raid
    Kit.Fill(r.bg, Kit.Theme().row.raid)
    r.icon:SetTexture(INST_ICON[raid.name or ""] or (LFG .. "Raid"))
    r.size:SetText(raid.size and tostring(raid.size) or "")
    if raid.heroic then r.hc:Show() else r.hc:Hide() end
    Kit.Icon.Fold(r.fold, not Folded(raid, line.index))
    local on = RaidShown(raid)
    r.picked = on
    if on then r.mark:Show() else r.mark:Hide() end
    Kit.Text(r.name, on and "sem.pick" or "text.title")
    r.score:SetText(format("%d/%d", raid.passed, raid.total))
    Tone(r.score, raid.passed > 0 and "sem.win" or "sem.wipe")
    Fit(r.name, RaidName(raid), rowW - TEXTX - RAIDR - r.score:GetStringWidth() - 6)
    Fit(r.info, When(raid), rowW - FOLDX - RAIDR)
end
local function PaintEnc(r, line, spot)
    local enc = line.enc
    local on = spot and spot.enc == enc
    Fill(r.stripe, enc.passed and "sem.win" or "sem.wipe")
    r.ok:SetTexture(enc.passed and READY or NOTREADY)
    if on then Kit.Paint(r.bg, "sem.pick", 0.14) else Kit.Paint(r.bg, "sem.enc") end
    local wipes = ns.FightTree.Wipes(enc)
    local dots = wipes > DOTS and 1 or wipes
    for i = 1, DOTS do
        if i <= dots then r.dots[i]:Show() else r.dots[i]:Hide() end
    end
    local right = DOTX + dots * (DOT + DOTGAP)
    r.count:ClearAllPoints()
    if wipes > DOTS then
        r.count:SetText(tostring(wipes))
        r.count:SetPoint("RIGHT", -right, 0)
        right = right + r.count:GetStringWidth() + DOTGAP
    else
        r.count:SetText("")
    end
    local w = r.wipes
    if wipes > 0 then
        w:ClearAllPoints()
        w:SetPoint("RIGHT", -(DOTX - DOTGAP), 0)
        w:SetWidth(right - DOTX + DOTGAP * 2)
        w:Show()
    else
        w:Hide()
    end
    if wipes > 0 and openEnc == enc.key then Fill(r.wipeOn, "row.bgOn") else Fill(r.wipeOn, "surface.clear") end
    r.play:ClearAllPoints()
    r.play:SetPoint("RIGHT", -(right + DOTGAP), 0)
    r.play.fight = ns.FightTree.Decisive(enc)
    Fit(r.name, enc.boss, rowW - ENCX - ENCNAME - right - DOTGAP - PLAYW)
    Tone(r.name, on and "sem.pick" or "text.primary")
end
local function PaintWipe(r, line)
    local f = line.fight
    local on = f == fight
    if on then Kit.Paint(r.bg, "sem.pick", 0.14) else Kit.Paint(r.bg, "sem.enc") end
    Fill(r.stripe, "sem.wipe")
    r.play.fight = f
    Fit(r.name, format(ns.T("fl.wipe.row"), line.n, ns.T("fl.wipe"), Clock(f.to - f.from), f.deaths or 0,
        Hour(f.from)), rowW - WIPEX - ENCNAME - 4 - PLAYW)
    Tone(r.name, on and "sem.pick" or "text.secondary")
end
local function AddWipes(out, enc)
    for n = 1, #enc.fights do
        local f = enc.fights[n]
        if not f.killed then out[#out + 1] = { kind = "wipe", enc = enc, fight = f, n = n } end
    end
end
local function Flatten()
    local out = {}
    local raids = ns.FightTree.Get()
    for i = 1, #raids do
        local raid = raids[i]
        out[#out + 1] = { kind = "raid", raid = raid, index = i }
        if not Folded(raid, i) then
            for k = 1, #raid.encs do
                local enc = raid.encs[k]
                out[#out + 1] = { kind = "enc", enc = enc }
                if enc.key == openEnc then AddWipes(out, enc) end
            end
        end
    end
    return out
end
local function MaxOffset()
    local h, count = 0, 0
    for i = #lines, 1, -1 do
        h = h + STEP[lines[i].kind]
        if h > treeH + 2 then break end
        count = count + 1
    end
    return max(0, #lines - count)
end
local function DrawTree()
    for kind, pool in pairs(pools) do
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
    lines = Flatten()
    local maxOff = MaxOffset()
    treeOffset = max(0, min(treeOffset, maxOff))
    rowW = COLW
    if treeBar and maxOff > 0 then
        rowW = COLW - treeBar:GetWidth() - BARGAP
        treeBar:Show()
    elseif treeBar then
        treeBar:Hide()
    end
    local spot = ns.FightTree.Spot(fight)
    local y = 0
    for i = treeOffset + 1, #lines do
        local line = lines[i]
        local step = STEP[line.kind]
        if y + step > treeH + 2 then break end
        local r = Take(line.kind)
        r.line = line
        local x = 0
        if line.kind == "raid" then
            PaintRaid(r, line)
        elseif line.kind == "enc" then
            x = ENCX
            PaintEnc(r, line, spot)
        else
            x = WIPEX
            PaintWipe(r, line)
        end
        r:SetWidth(rowW - x)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", treeBox, "TOPLEFT", x, -y)
        y = y + step
    end
    if treeBar then treeBar:SetState(treeOffset, #lines - maxOff, #lines) end
end
Toggle = function(row)
    local key = row.line.enc.key
    if openEnc == key then
        openEnc = nil
        DrawTree()
        return
    end
    openEnc = key
    lines = Flatten()
    for i = 1, #lines do
        local line = lines[i]
        if line.kind == "enc" and line.enc.key == key then
            local last, h = i, 0
            while lines[last + 1] and lines[last + 1].kind == "wipe" do last = last + 1 end
            for k = treeOffset + 1, last do h = h + STEP[lines[k].kind] end
            if i <= treeOffset or h > treeH then treeOffset = i - 1 end
            break
        end
    end
    DrawTree()
end
local function Reveal(f)
    local spot = ns.FightTree.Spot(f)
    if not spot then return end
    Folds()[spot.raid.key] = false
    lines = Flatten()
    local at, raidAt = nil, nil
    for i = 1, #lines do
        local line = lines[i]
        if line.raid == spot.raid then raidAt = i end
        if line.enc == spot.enc then at = i break end
    end
    if not at then return end
    local h = 0
    for i = treeOffset + 1, at do
        h = h + STEP[lines[i].kind]
    end
    if at > treeOffset and h <= treeH then return end
    local top = raidAt or at
    h = 0
    for i = top, at do h = h + STEP[lines[i].kind] end
    if h > treeH then top = at end
    treeOffset = top - 1
end
local function Faults(f)
    if not (ns.Summary and ns.Penalties) then return nil end
    local s = ns.Summary.Get(f)
    if not s then
        if asked ~= f then
            asked = f
            ns.Summary.Compute(f, function()
                asked = nil
                if fight == f and side then FL.DrawPlayers() end
            end)
        end
        return nil
    end
    if faultsFor == f and faultsSum == s then return faults end
    local hits = ns.Penalties.Evaluate(s, f)
    local out = {}
    for name, list in pairs(hits) do
        local n = 0
        for i = 1, #list do n = n + #list[i].events end
        out[name] = n
    end
    faults, faultsFor, faultsSum = out, f, s
    return out
end
local function ByBlame(a, b)
    if a.faults ~= b.faults then return a.faults > b.faults end
    if a.deaths ~= b.deaths then return a.deaths > b.deaths end
    return a.order < b.order
end
function FL.Participants(f)
    local list = ns.Encounters.Players(f)
    local counts = Faults(f)
    for i = 1, #list do
        local p = list[i]
        p.order = i
        p.faults = counts and counts[p.name] or 0
    end
    tsort(list, ByBlame)
    return list, counts ~= nil
end
local function OnPlayer(row)
    if row.who and ns.Timeline and ns.Timeline.SelectPlayer then
        ns.Timeline.SelectPlayer(row.who)
    end
end
local function Cell(index)
    local c = cells[index]
    if c then return c end
    c = NewRow(playerBox, "player", PCOLW - 2, PROW)
    local col = (index - 1) % PCOLS
    local line = floor((index - 1) / PCOLS)
    c:SetPoint("TOPLEFT", col * PCOLW, -(line * PROW))
    c.cls = c:CreateTexture(nil, "ARTWORK")
    c.cls:SetWidth(PROW - 3)
    c.cls:SetHeight(PROW - 3)
    c.cls:SetPoint("LEFT", 2, 0)
    c.cls:SetTexture(CLASS_TEX)
    c.name = Label(c, "GameFontHighlightSmall", 12)
    c.name:SetPoint("LEFT", c.cls, "RIGHT", 3, 0)
    c.plate = CreateFrame("Frame", nil, c)
    c.plate:SetHeight(12)
    c.plate:SetPoint("RIGHT", -1, 0)
    c.plate.edge = c.plate:CreateTexture(nil, "BACKGROUND")
    c.plate.edge:SetAllPoints()
    Kit.Paint(c.plate.edge, "sem.wipe")
    c.plate.fill = c.plate:CreateTexture(nil, "BORDER")
    c.plate.fill:SetPoint("TOPLEFT", 1, -1)
    c.plate.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    Kit.Paint(c.plate.fill, "sem.fault")
    c.plate.text = Label(c.plate, "GameFontHighlightSmall", 12, "CENTER")
    c.plate.text:SetPoint("CENTER", 0, 0)
    c.dead = Label(c, "GameFontHighlightSmall", 12, "RIGHT")
    c.onClick = OnPlayer
    cells[index] = c
    return c
end
local function PaintCell(c, p)
    local tc = p.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[p.class]
    if tc then
        c.cls:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        c.cls:Show()
    else
        c.cls:Hide()
    end
    local right = 1
    if p.faults > 0 then
        c.plate.text:SetText(tostring(p.faults))
        local w = max(13, floor(c.plate.text:GetStringWidth() + 5))
        c.plate:SetWidth(w)
        c.plate.text:SetWidth(w)
        c.plate:Show()
        right = right + w + 2
    else
        c.plate:Hide()
    end
    c.dead:ClearAllPoints()
    if p.deaths > 0 then
        c.dead:SetText(Skulls(p.deaths))
        local w = floor(c.dead:GetStringWidth() + 2)
        c.dead:SetWidth(w)
        c.dead:SetPoint("RIGHT", -right, 0)
        c.dead:Show()
        right = right + w + 1
    else
        c.dead:Hide()
    end
    Fit(c.name, p.name, PCOLW - 2 - PROW - 4 - right)
    local r, g, b = Kit.ClassColor(p.class)
    if not (p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]) then
        r, g, b = Kit.Color("badge.noClass")
    end
    c.name:SetTextColor(r, g, b)
    c.who = p.name
    c.person = p
    if p.name == player then Fill(c.bg, "row.bgOn") else Fill(c.bg, "surface.clear") end
end
local function Need(f)
    if not f then return 0 end
    local n = 0
    for _ in pairs(f.players or {}) do n = n + 1 end
    return floor((n + PCOLS - 1) / PCOLS)
end
local function Place(n, force)
    local h = max(TREEMIN * STEP.enc, sideH - HEADH - LISTGAP - PHEADH - n * PROW)
    if not force and n == playerLines and h == treeH then return false end
    playerLines, treeH = n, h
    treeBox:SetHeight(treeH)
    playerHead:ClearAllPoints()
    playerHead:SetPoint("TOPLEFT", 0, -(HEADH + treeH + LISTGAP))
    playerBox:ClearAllPoints()
    playerBox:SetPoint("TOPLEFT", 0, -(HEADH + treeH + LISTGAP + PHEADH))
    playerBox:SetHeight(max(1, n * PROW))
    if treeBar then treeBar:SetHeight(treeH) end
    return true
end
function FL.DrawPlayers(skipTree)
    if not side then return end
    local list, counted = {}, false
    if fight then list, counted = FL.Participants(fight) end
    FL.counted = counted
    local need = floor((#list + PCOLS - 1) / PCOLS)
    if Place(need) and not skipTree then DrawTree() end
    local shown = playerLines * PCOLS
    for i = 1, shown do
        local c = Cell(i)
        local p = list[i]
        if p then
            PaintCell(c, p)
            c:Show()
        else
            c:Hide()
        end
    end
    for i = shown + 1, #cells do cells[i]:Hide() end
    Fit(playerCtx, TryTitle(fight), COLW - playerHead:GetStringWidth() - 6)
end
local function NavTip(b, f, n)
    if f then
        b:Enable()
        b.tip = format(ns.T("fl.nav.try"), n, Outcome(f), Hour(f.from))
    else
        b:Disable()
        b.tip = nil
    end
end
local function DrawNav()
    if not nav then return end
    ns.ReplayLink.SetFight(fight)
    local spot = ns.FightTree.Spot(fight)
    if not spot then
        nav:SetWidth(1)
        nav:Hide()
        return
    end
    local total = #spot.enc.fights
    navNo:SetText(format("%d/%d", spot.n, total))
    navNo:SetWidth(navNo:GetStringWidth() + 2)
    NavTip(navPrev, spot.enc.fights[spot.n - 1], spot.n - 1)
    NavTip(navNext, spot.enc.fights[spot.n + 1], spot.n + 1)
    navOut:SetText(format("%s %s", ns.T(fight.killed and "fl.win" or "fl.wipe"), Clock(fight.to - fight.from)))
    Tone(navOut, fight.killed and "sem.win" or "sem.wipe")
    nav:SetWidth(NAVBTN * 2 + NAVGAP * 4 + navNo:GetWidth() + navOut:GetStringWidth())
    nav:Show()
end
Redraw = function()
    if not side then return end
    FL.DrawPlayers(true)
    DrawTree()
    DrawNav()
end
local function Step(step)
    local f = ns.FightTree.Near(fight, step)
    if f then Open(f) end
end
local function NavButton(label, tip, step)
    local b = Kit.Button(nav)
    b:SetWidth(NAVBTN)
    b:SetHeight(NAVBTN)
    b.text:SetText(label)
    b.tipTitle = ns.T(tip)
    b.onClick = function() Step(step) end
    return b
end
local function AttachNav(host, title, status)
    nav = CreateFrame("Frame", nil, host)
    nav:SetHeight(NAVBTN)
    nav:SetWidth(1)
    nav:SetPoint("LEFT", title, "RIGHT", NAVGAP * 2, 0)
    navPrev = NavButton("<", "fl.nav.prev", -1)
    navPrev:SetPoint("LEFT", 0, 0)
    navNo = Label(nav, "GameFontHighlightSmall", 12, "CENTER")
    navNo:SetPoint("LEFT", navPrev, "RIGHT", NAVGAP, 0)
    navNext = NavButton(">", "fl.nav.next", 1)
    navNext:SetPoint("LEFT", navNo, "RIGHT", NAVGAP, 0)
    navOut = Label(nav, "GameFontHighlightSmall", 12)
    navOut:SetPoint("LEFT", navNext, "RIGHT", NAVGAP * 2, 0)
    nav:Hide()
    local play = ns.ReplayLink.Head(host, nav)
    if ns.ShareView then ns.ShareView.Head(host) end
    if status then status:SetPoint("LEFT", play, "RIGHT", NAVGAP * 2, 0) end
end
Tips.raid = function(r)
    local raid = r.line.raid
    local out = { Line(RaidName(raid)) }
    if raid.size then
        out[#out + 1] = Line(format(ns.T("fl.tip.size"), raid.size), "tip.dim")
        out[#out + 1] = Line(format(ns.T("fl.tip.diff"), ns.T(raid.heroic and "fl.diff.hc" or "fl.diff.nm")),
            raid.heroic and "tip.body" or "tip.dim")
    end
    out[#out + 1] = Line(format(ns.T("fl.tip.when"), date("%d.%m %H:%M", raid.from), date("%d.%m %H:%M", raid.to)),
        "tip.dim")
    out[#out + 1] = Line(raid.id and format(ns.T("fl.tip.lock"), raid.id) or ns.T("fl.tip.nolock"), "tip.dim")
    out[#out + 1] = Line(format(ns.T("fl.tip.passed"), raid.passed, raid.total, raid.tries,
        raid.deaths))
    local fold = Folded(raid, r.line.index)
    out[#out + 1] = Line(ns.T(fold and "fl.tip.raid.open" or "fl.tip.raid.fold"), "tip.body", true)
    if ns.Timeline and ns.Timeline.ShowRaid and not RaidShown(raid) then
        out[#out + 1] = Line(ns.T("rsum.fl.tip.open"), "tip.body", true)
    end
    out[#out + 1] = Line(ns.T("fl.tip.raid.menu"), "tip.body")
    return out
end
Tips.enc = function(r)
    local enc = r.line.enc
    local n = #enc.fights
    local out = {
        Line(enc.boss),
        Line(format(ns.T(enc.passed and "fl.tip.enc.pass" or "fl.tip.enc.fail"), n, ns.FightTree.Wipes(enc)),
            enc.passed and "sem.win" or "sem.wipe"),
    }
    local from = max(1, n - TIPMAX + 1)
    if from > 1 then out[#out + 1] = Line(format(ns.T("fl.tip.more"), from - 1), "tip.dim") end
    for i = from, n do
        local f = enc.fights[i]
        local token = f == fight and "sem.pick" or (f.killed and "sem.win" or "tip.dim")
        out[#out + 1] = Line(format(ns.T("fl.tip.enc.line"), i, ns.T(f.killed and "fl.win" or "fl.wipe"),
            Clock(f.to - f.from), f.deaths or 0, Hour(f.from)), token)
    end
    out[#out + 1] = Line(ns.T(enc.passed and "fl.tip.enc.kill" or "fl.tip.enc.last"), "tip.body", true)
    if ns.FightTree.Wipes(enc) > 0 then out[#out + 1] = Line(ns.T("fl.tip.enc.wipes"), "tip.body") end
    out[#out + 1] = Line(ns.T("fl.tip.enc.nav"), "tip.body")
    out[#out + 1] = Line(ns.T("fl.tip.enc.menu"), "tip.body")
    return out
end
Tips.wipe = function(r)
    local f, n = r.line.fight, r.line.n
    return {
        Line(format(ns.T("fl.try.title"), f.boss, n)),
        Line(format(ns.T("fl.tip.enc.line"), n, ns.T("fl.wipe"), Clock(f.to - f.from), f.deaths or 0,
            Hour(f.from)), "sem.wipe"),
        Line(ns.T("fl.tip.wipe.open"), "tip.body", true),
        Line(ns.T("fl.tip.wipe.menu"), "tip.body"),
    }
end
function Del.Land(key, lost)
    local TL = ns.Timeline
    local view = ns.RaidSummaryView
    if key and view and TL and TL.ShowRaid then
        local raids = ns.FightTree.Get()
        for i = 1, #raids do
            if raids[i].key == key then
                TL.ShowRaid(raids[i])
                return
            end
        end
    end
    if (key or lost) and view then view.Land(nil) end
    if TL and TL.RefreshLists then TL.RefreshLists() else Redraw() end
end
function Del.Run(doomed, extra)
    local plan, why = ns.FightTree.Plan(doomed, extra)
    if not plan then
        ns.Print(ns.T("fl.del." .. tostring(why)))
        return
    end
    local lost = fight ~= nil and plan.gone[fight] == true
    local view = ns.RaidSummaryView
    local key = view and view.ShownKey() or nil
    for f in pairs(plan.gone) do gone[f] = true end
    local removed = ns.FightTree.Drop(plan)
    ns.Print(format(ns.T("fl.del.done"), #plan.fights, removed))
    if plan.kept > 0 then ns.Print(format(ns.T("fl.del.kept"), plan.kept)) end
    if lost then
        fight = nil
        if ns.SummaryView then ns.SummaryView.Hide() end
    end
    if key and view then view.Hide() end
    ns.Encounters.Scan(function() Del.Land(key, lost) end)
end
function Del.Ask(text, doomed, extra)
    if #doomed == 0 then return end
    if ns.FightTree.Busy() then
        ns.Print(ns.T("fl.del.busy"))
        return
    end
    if not (ns.GPList and ns.GPList.Confirm) then return end
    ns.GPList.Confirm(text, ns.T("fl.del.yes"), function() Del.Run(doomed, extra) end)
end
function Del.RaidSegs(raid)
    local out = {}
    if ns.RaidSummary and ns.RaidSummary.Segments then
        local refs = ns.RaidSummary.Segments(raid)
        for i = 1, #refs do out[i] = refs[i].i end
    end
    return out
end
function Del.Last(raid, list)
    if not raid or raid.tries > #list then return nil end
    return Del.RaidSegs(raid)
end
function Del.AskTry(f, n)
    local spot = ns.FightTree.Spot(f)
    Del.Ask(format(ns.T("fl.del.try.ask"), n, f.boss, ns.T(f.killed and "fl.win" or "fl.wipe"), Clock(f.to - f.from),
        date("%d.%m %H:%M", f.from)), { f }, Del.Last(spot and spot.raid, { f }))
end
function Del.AskEnc(enc)
    local list = {}
    for i = 1, #enc.fights do list[i] = enc.fights[i] end
    Del.Ask(format(ns.T("fl.del.enc.ask"), enc.boss, #list), list, Del.Last(enc.raid, list))
end
function Del.AskRaid(raid)
    Del.Ask(format(ns.T("fl.del.raid.ask"), RaidName(raid), date("%d.%m", raid.from), raid.tries),
        ns.FightTree.RaidFights(raid), Del.RaidSegs(raid))
end
function Del.RaidMenu(row)
    local raid, index = row.line.raid, row.line.index
    ns.Tip.Hide()
    Kit.Menu({
        { text = RaidName(raid), isTitle = true },
        { text = ns.T(Folded(raid, index) and "fl.menu.open" or "fl.menu.fold"),
          func = function() FoldKey(raid, index) end },
        { text = ns.T("fl.menu.raid.del"), func = function() Del.AskRaid(raid) end },
    }, row)
end
function Del.EncMenu(row)
    local enc = row.line.enc
    ns.Tip.Hide()
    Kit.Menu({
        { text = enc.boss, isTitle = true },
        { text = ns.T("fl.menu.enc.del"), func = function() Del.AskEnc(enc) end },
    }, row)
end
function Del.WipeMenu(row)
    local f, n = row.line.fight, row.line.n
    ns.Tip.Hide()
    Kit.Menu({
        { text = format(ns.T("fl.try.title"), f.boss, n), isTitle = true },
        { text = ns.T("fl.menu.wipe.del"), func = function() Del.AskTry(f, n) end },
    }, row)
end
FL.Del = Del
Tips.head = function()
    return {
        Line(ns.T("fl.raids")),
        Line(format(ns.T("fl.tip.found"), #ns.Encounters.Fights()), "tip.dim"),
    }
end
Tips.player = function(c)
    local p = c.person
    local out = { Line(p.name) }
    if p.deaths > 0 then out[#out + 1] = Line(format(ns.T("fl.tip.deaths"), p.deaths), "sem.wipe") end
    if p.faults > 0 then out[#out + 1] = Line(format(ns.T("fl.tip.faults"), p.faults), "sem.wipe") end
    if not FL.counted then
        out[#out + 1] = Line(ns.T("fl.tip.wait"), "tip.dim")
    elseif p.deaths == 0 and p.faults == 0 then
        out[#out + 1] = Line(ns.T("fl.tip.clean"), "sem.win")
    end
    out[#out + 1] = Line(ns.T("fl.tip.player"), "tip.body", true)
    return out
end
local function Wheel(frame, bar, move)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) move(delta) end)
    if bar then bar.onScroll = function(offset) move(nil, offset) end end
end
function FL.Attach(parent, x, y, title, status)
    if title then AttachNav(parent, title, status) end
    side = CreateFrame("Frame", nil, parent)
    side:SetWidth(COLW)
    side:SetPoint("TOPLEFT", x, -y)
    local head = Label(side, "GameFontNormalSmall", 12)
    head:SetPoint("TOPLEFT", 0, -2)
    head:SetText(ns.T("fl.raids"))
    local hint = NewRow(side, "head", WIDTH / 2, HEADH)
    hint:SetPoint("TOPLEFT", 0, 0)
    hint.hover:SetAlpha(0)
    treeBox = CreateFrame("Frame", nil, side)
    treeBox:SetPoint("TOPLEFT", 0, -HEADH)
    treeBox:SetWidth(COLW)
    if ns.MakeScrollBar then
        treeBar = ns.MakeScrollBar(side, TREEMIN * STEP.enc)
        treeBar:SetPoint("TOPRIGHT", treeBox, "TOPRIGHT", 0, 0)
    end
    Wheel(treeBox, treeBar, function(delta, offset)
        treeOffset = offset or (treeOffset - delta * WHEEL)
        DrawTree()
    end)
    playerHead = Label(side, "GameFontNormalSmall", 12)
    playerHead:SetText(ns.T("tl.players"))
    playerCtx = Label(side, "GameFontHighlightSmall", 12)
    playerCtx:SetPoint("LEFT", playerHead, "RIGHT", 6, 0)
    playerBox = CreateFrame("Frame", nil, side)
    playerBox:SetWidth(COLW)
end
function FL.Layout(height)
    if not side then return end
    sideH = max(HEADH + LISTGAP + PHEADH + TREEMIN * STEP.enc, height)
    side:SetHeight(sideH)
    Place(Need(fight), true)
end
function FL.Refresh(f, who)
    if not side then return end
    if f and gone[f] then f = nil end
    if f ~= fight then
        local was = ns.FightTree.Spot(fight)
        local now = ns.FightTree.Spot(f)
        fight = f
        Place(Need(f))
        if now and not (was and was.enc == now.enc) then Reveal(f) end
    end
    player = who
    Redraw()
end
if ns.GPList and ns.GPList.OnChange then
    ns.GPList.OnChange(function()
        faultsFor = nil
        if side and side:IsVisible() then FL.DrawPlayers() end
    end)
end
Kit.OnTheme(function()
    if side then Redraw() end
end)
