local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local Kit = ns.Kit
local K = {}
K.WIDTH = 240
K.GUTTER = 10
K.COLW = K.WIDTH - K.GUTTER
K.BARGAP = 2
K.RAIDH = 40
K.ENCH = 20
K.ENCX = 0
K.ENCNAME = 5
K.WIPEH = 17
K.WIPEX = 8
K.HEADH = 16
K.LISTGAP = 8
K.PHEADH = 16
K.PROW = 15
K.LINE = 12
K.TREEMIN = 3
K.PCOLS = 2
K.PCOLW = floor(K.COLW / K.PCOLS)
K.WHEEL = 2
K.ICONPAD = 5
K.ICON = K.RAIDH - K.ICONPAD * 2
K.ICONX = 1
K.ICONIN = 1
K.TEXTGAP = 7
K.TEXTX = K.ICONX + K.ICON + K.TEXTGAP
K.TEXTTOP = -5
K.INFOTOP = -19
K.DAY = 86400
K.FITKEY = nil
K.OKSZ = 13
K.TIPMAX = 10
K.OKX = -6
K.UBSZ = 12
K.UBGAP = 3
K.DOT = 7
K.DOTGAP = 3
K.DOTS = 5
K.DOTX = 21
K.DOTPAD = 2
K.NAVBTN = ns.Kit.Space.tool
K.NAVGAP = 4
K.PLAYSZ = 13
K.PLAYW = K.PLAYSZ + 4
K.DELSZ = 12
K.DELHIT = 14
K.DELR = -K.OKX + K.OKSZ / 2 - K.DELHIT / 2
K.FOLD_TEX = "Interface\\Buttons\\UI-SortArrow"
K.FOLDSZ = 8
K.SCORER = K.DELR + K.DELHIT + 2
K.SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
K.READY = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
K.NOTREADY = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
K.CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
K.DEL_TEX = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\del"
local MAP_INST = {
    IcecrownCitadel = "icc",
    TheRubySanctum = "rs",
    Ulduar = "uld",
    TheArgentColiseum = "toc",
    TrialoftheGrandCrusader = "toc",
    Naxxramas = "naxx",
    TheEyeofEternity = "eoe",
    TheObsidianSanctum = "os",
    OnyxiasLair = "ony",
    VaultofArchavon = "voa",
}
local NAME_INST = {
    ["Цитадель Ледяной Короны"] = "icc",
    ["Рубиновое святилище"] = "rs",
    ["Ульдуар"] = "uld",
    ["Испытание крестоносца"] = "toc",
    ["Испытание великого крестоносца"] = "toc",
    ["Наксрамас"] = "naxx",
    ["Око Вечности"] = "eoe",
    ["Обсидиановое святилище"] = "os",
    ["Логово Ониксии"] = "ony",
    ["Склеп Аркавона"] = "voa",
    ["Ciudadela de la Corona de Hielo"] = "icc",
    ["El Sagrario Rubí"] = "rs",
    ["Prueba del Cruzado"] = "toc",
    ["Prueba del Gran Cruzado"] = "toc",
    ["El Ojo de la Eternidad"] = "eoe",
    ["El Sagrario Obsidiana"] = "os",
    ["Guarida de Onyxia"] = "ony",
    ["La Cámara de Archavon"] = "voa",
    ["Icecrown Citadel"] = "icc",
    ["The Ruby Sanctum"] = "rs",
    ["Ulduar"] = "uld",
    ["Trial of the Crusader"] = "toc",
    ["Trial of the Grand Crusader"] = "toc",
    ["Naxxramas"] = "naxx",
    ["The Eye of Eternity"] = "eoe",
    ["The Obsidian Sanctum"] = "os",
    ["Onyxia's Lair"] = "ony",
    ["Vault of Archavon"] = "voa",
}
local SCREEN = "Interface\\Glues\\LoadingScreens\\LoadScreen"
local BACK = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-"
local INST_ART = {
    icc = { file = SCREEN .. "IcecrownCitadel", l = 0.04, r = 0.96, y = 0.47 },
    rs = { file = SCREEN .. "RubySanctum", l = 0.04, r = 0.96, y = 0.6 },
    uld = { file = SCREEN .. "UlduarRaid", l = 0.04, r = 0.96, y = 0.6 },
    toc = { file = SCREEN .. "ArgentRaid", l = 0.04, r = 0.96, y = 0.6 },
    naxx = { file = SCREEN .. "Naxxramas", l = 0.04, r = 0.96, y = 0.6 },
    eoe = { file = SCREEN .. "Malygos", l = 0.04, r = 0.96, y = 0.6 },
    os = { file = BACK .. "ChamberOfAspects", l = 0, r = 1, y = 0.5, wide = 2 },
    voa = { file = BACK .. "VaultOfArchavon", l = 0, r = 1, y = 0.5, wide = 2 },
}
local STEP = { raid = K.RAIDH + 2, enc = K.ENCH + 1, wipe = K.WIPEH + 1 }
local FL = {}
ns.FightList = FL
FL.WIDTH = K.WIDTH
local side, treeBox, treeBar, playerHead, playerCtx, playerBox, headLabel, headHint
local playerArea
local pools = { raid = {}, enc = {}, wipe = {} }
local used = { raid = 0, enc = 0, wipe = 0 }
local cells = {}
local lines = {}
local treeOffset = 0
local rowW = K.COLW
local treeH, playerLines, sideH = 0, 0, 0
local fight, player
local nav, navPrev, navNext, navNo, navOut
local headTitle
local tools
local faults, faultsFor, faultsSum, asked
local openEnc
local Tips = {}
local Del = {}
local gone = setmetatable({}, { __mode = "k" })
local Clock = ns.Clock
local function Hour(t)
    return date("%H:%M", t)
end
local function When(raid)
    local tail = raid.to - raid.from < K.DAY and Hour(raid.to) or ns.Date(raid.to, "dayTime")
    return format(ns.T("fl.when"), ns.Date(raid.from), Hour(raid.from), tail)
end
local function Skulls(n)
    if n <= 0 then return "" end
    return format("|T%s:0|t%d", K.SKULL, n)
end
local function Line(text, token, gap)
    if not token then return { text, "tip.title", gap } end
    local r, g, b = Kit.Color(token)
    return { text, r, g, b, gap }
end
FL.Fit = ns.FitText
local Fit = FL.Fit
local function Label(parent, font, h, justify)
    local fs = Kit.Str(parent, font)
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
    return ns.Raid.Title(raid)
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
    return ns.EncName(f.boss)
end
local function TryTitle(f)
    if not f then return "" end
    local spot = ns.FightTree.Spot(f)
    if not spot then return ns.EncName(f.boss) end
    return format(ns.T("fl.try.title"), ns.EncName(f.boss), spot.n)
end
local function Outcome(f)
    return format(ns.T(f.killed and "fl.tip.try.win" or "fl.tip.try.wipe"), Clock(f.to - f.from))
end
local function DelShade(row, over)
    if not row.del then return end
    row.del:SetAlpha((over or (row.picked and row.kind ~= "raid")) and 1 or 0)
end
local function OnEnter(self)
    self.hover:Show()
    DelShade(self, true)
    local build = Tips[self.kind]
    if build then ns.Tip.Show(self, build(self)) end
end
local function OnLeave(self)
    self.hover:Hide()
    DelShade(self, false)
    ns.Tip.Hide()
end
local function OnClick(self, button)
    ns.Tip.Hide()
    if self.onClick then self.onClick(self, button) end
end
local function Measure()
    local m = ns.Kit.Grow()
    local key = m.g .. ":" .. m.wk
    if key == K.FITKEY then return false end
    K.FITKEY = key
    local g = m.g
    K.LINE = 12 + g
    K.WIDTH = floor(FL.WIDTH * m.wk + 0.5)
    K.COLW = K.WIDTH - K.GUTTER
    K.PCOLW = floor(K.COLW / K.PCOLS)
    K.RAIDH, K.ENCH, K.WIPEH = 40 + 2 * g, 20 + g, 17 + g
    K.HEADH, K.PHEADH, K.PROW = 16 + g, 16 + g, 15 + g
    K.ICON = K.RAIDH - K.ICONPAD * 2
    K.TEXTX = K.ICONX + K.ICON + K.TEXTGAP
    K.TEXTTOP = -floor((K.RAIDH - K.LINE * 2 - 2) / 2 + 0.5)
    K.INFOTOP = K.TEXTTOP - K.LINE - 2
    STEP.raid, STEP.enc, STEP.wipe = K.RAIDH + 2, K.ENCH + 1, K.WIPEH + 1
    return true
end
local function NewRow(parent, kind, w, h)
    local r = CreateFrame("Button", nil, parent)
    r:SetWidth(w)
    r:SetHeight(h)
    r.kind = kind
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.tint = r:CreateTexture(nil, "BACKGROUND")
    r.tint:SetDrawLayer("BACKGROUND", 1)
    r.tint:SetAllPoints()
    r.tint:Hide()
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
    DelShade(row, true)
    local enc = row.line.enc
    local key = openEnc == enc.key and "fl.tip.wipes.fold" or "fl.tip.wipes.open"
    ns.Tip.Show(self, { Line(format(ns.T(key), ns.FightTree.Wipes(enc))) })
end
local function WipesLeave(self)
    self.row.hover:Hide()
    DelShade(self.row, false)
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
local function FoldRaid(row)
    local line = row.line
    Folds()[line.raid.key] = not Folded(line.raid, line.index)
    Redraw()
end
local function OnRaid(row)
    local line = row.line
    local show = ns.Timeline and ns.Timeline.ShowRaid
    if line.raid.party or not show or RaidShown(line.raid) then
        FoldRaid(row)
        return
    end
    Folds()[line.raid.key] = false
    show(line.raid)
end
local function OnEnc(row, button)
    if button == "RightButton" then
        Del.EncMenu(row)
        return
    end
    Open(ns.FightTree.Decisive(row.line.enc))
end
local function DelEnter(self)
    self.row.hover:Show()
    self:SetAlpha(1)
    Kit.Tint(self.tex, "text.primary")
    ns.Tip.Show(self, { Line(ns.T("fl.del.tip")) })
end
local function DelLeave(self)
    self.row.hover:Hide()
    Kit.Tint(self.tex, "text.bad")
    DelShade(self.row, false)
    ns.Tip.Hide()
end
local function DelClick(self)
    ns.Tip.Hide()
    local line = self.row.line
    if line.kind == "raid" then
        Del.AskRaid(line.raid)
    elseif line.kind == "enc" then
        Del.AskEnc(line.enc)
    elseif line.fight then
        Del.AskTry(line.fight, line.n)
    end
end
local function DelButton(r)
    local b = CreateFrame("Button", nil, r)
    b:SetWidth(K.DELHIT)
    b:SetHeight(K.DELHIT)
    b:RegisterForClicks("LeftButtonUp")
    b.row = r
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetWidth(K.DELSZ)
    b.tex:SetHeight(K.DELSZ)
    b.tex:SetPoint("CENTER")
    b.tex:SetTexture(K.DEL_TEX)
    Kit.Tint(b.tex, "text.bad")
    b:SetScript("OnEnter", DelEnter)
    b:SetScript("OnLeave", DelLeave)
    b:SetScript("OnClick", DelClick)
    b:SetAlpha(0)
    r.del = b
    return b
end
local function FoldButton(r)
    local b = CreateFrame("Button", nil, r)
    b:SetWidth(K.DELHIT)
    b:SetHeight(K.DELHIT)
    b:RegisterForClicks("LeftButtonUp")
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetWidth(K.FOLDSZ)
    b.tex:SetHeight(K.FOLDSZ)
    b.tex:SetPoint("CENTER")
    b.tex:SetTexture(K.FOLD_TEX)
    Kit.Tint(b.tex, "text.secondary")
    b:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) Kit.Tint(self.tex, "text.title") end)
    b:SetScript("OnLeave", function(self) Kit.Tint(self.tex, "text.secondary") end)
    b:SetScript("OnClick", function() FoldRaid(r) end)
    r.fold = b
    return b
end
local function CardInner(w)
    local n = Kit.Theme().row.raid.inset or 0
    return n, w - n, n, K.RAIDH - n
end
local function RaidGeom(r)
    r:SetHeight(K.RAIDH)
    local left, right, top, bottom = CardInner(rowW)
    K.ICONX = max(0, math.ceil(left))
    K.TEXTX = K.ICONX + K.ICON + K.TEXTGAP
    r.tint:ClearAllPoints()
    r.tint:SetPoint("TOPLEFT", r, "TOPLEFT", left, -top)
    r.tint:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", right - rowW, K.RAIDH - bottom)
    r.name:SetHeight(K.LINE)
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", K.TEXTX, K.TEXTTOP)
    r.score:SetHeight(K.LINE)
    r.score:ClearAllPoints()
    r.score:SetPoint("TOPRIGHT", -K.SCORER, K.TEXTTOP)
    r.info:SetHeight(K.LINE)
    r.info:ClearAllPoints()
    r.info:SetPoint("TOPLEFT", K.TEXTX, K.INFOTOP)
    r.del:ClearAllPoints()
    r.del:SetPoint("RIGHT", r, "TOPRIGHT", -K.DELR, K.INFOTOP - K.LINE / 2)
    r.fold:ClearAllPoints()
    r.fold:SetPoint("RIGHT", r, "TOPRIGHT", -K.DELR, K.TEXTTOP - K.LINE / 2)
    r.tile:ClearAllPoints()
    r.tile:SetPoint("TOPLEFT", K.ICONX, -K.ICONPAD)
end
local function RaidRow()
    local r = NewRow(treeBox, "raid", K.COLW, K.RAIDH)
    r.on = r:CreateTexture(nil, "BORDER")
    r.on:SetDrawLayer("BORDER", 1)
    r.on:SetAllPoints(r.bg)
    r.on:Hide()
    r.hover:ClearAllPoints()
    r.hover:SetAllPoints(r.bg)
    r.art = r:CreateTexture(nil, "BACKGROUND")
    r.art:SetDrawLayer("BACKGROUND", -3)
    r.art:SetAllPoints(r.bg)
    r.glow = r:CreateTexture(nil, "BACKGROUND")
    r.glow:SetDrawLayer("BACKGROUND", -2)
    r.glow:SetAllPoints(r.bg)
    r.glow:SetBlendMode("ADD")
    r.fade = r:CreateTexture(nil, "BACKGROUND")
    r.fade:SetDrawLayer("BACKGROUND", -1)
    r.fade:SetPoint("TOPLEFT", r.bg, "TOPLEFT", 0, 0)
    r.fade:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT", 0, 0)
    r.tile = CreateFrame("Frame", nil, r)
    r.tile:EnableMouse(false)
    r.size = Kit.Str(r.tile, "GameFontNormalLarge")
    Kit.Text(r.size, "text.primary")
    r.hc = r.tile:CreateTexture(nil, "OVERLAY")
    r.hc:SetPoint("TOP", r.tile, "TOP", 0, -K.ICONIN)
    r.name = Label(r, "GameFontNormalSmall", K.LINE)
    Kit.Text(r.name, "text.title")
    r.score = Label(r, "GameFontHighlightSmall", K.LINE, "RIGHT")
    r.info = Label(r, "GameFontHighlightSmall", K.LINE)
    Kit.Text(r.info, "text.primary")
    DelButton(r)
    FoldButton(r)
    RaidGeom(r)
    r.onClick = OnRaid
    return r
end
local function EncGeom(r)
    r:SetHeight(K.ENCH)
    r.name:SetHeight(K.LINE)
    r.count:SetHeight(K.LINE)
    r.wipes:SetHeight(K.ENCH)
end
local function EncRow()
    local r = NewRow(treeBox, "enc", K.COLW - K.ENCX, K.ENCH)
    Kit.Paint(r.bg, "sem.enc")
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", 0, 0)
    r.stripe:SetPoint("BOTTOMLEFT", 0, 0)
    r.name = Label(r, "GameFontHighlightSmall", K.LINE)
    r.name:SetPoint("LEFT", K.ENCNAME, 0)
    r.count = Label(r, "GameFontHighlightSmall", K.LINE, "RIGHT")
    Kit.Text(r.count, "sem.wipe")
    r.dots = {}
    for i = 1, K.DOTS do
        local d = r:CreateTexture(nil, "ARTWORK")
        d:SetWidth(K.DOT)
        d:SetHeight(K.DOT)
        d:SetPoint("RIGHT", -(K.DOTX + (i - 1) * (K.DOT + K.DOTGAP)), 0)
        Kit.Paint(d, "sem.wipe")
        r.dots[i] = d
    end
    r.ok = r:CreateTexture(nil, "ARTWORK")
    r.ok:SetWidth(K.OKSZ)
    r.ok:SetHeight(K.OKSZ)
    r.ok:SetPoint("RIGHT", K.OKX, 0)
    r.play = ns.ReplayLink.Mini(r, K.PLAYSZ)
    r.play:SetPoint("RIGHT", r.ok, "LEFT", K.OKSZ - K.OKX - K.DOTX, 0)
    r.play.pick = Open
    DelButton(r):SetPoint("RIGHT", r.play, "LEFT", 0, 0)
    r.ub = Kit.Unbuff(r, K.UBSZ)
    r.ub:SetPoint("RIGHT", r.del, "LEFT", -K.UBGAP, 0)
    local w = CreateFrame("Button", nil, r)
    w:SetHeight(K.ENCH)
    w:RegisterForClicks("LeftButtonUp")
    w.row = r
    w:SetScript("OnEnter", WipesEnter)
    w:SetScript("OnLeave", WipesLeave)
    w:SetScript("OnClick", WipesClick)
    r.wipes = w
    r.wipeOn = r:CreateTexture(nil, "BORDER")
    r.wipeOn:SetAllPoints(w)
    EncGeom(r)
    r.onClick = OnEnc
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return r
end
local function WipeRow()
    local r = NewRow(treeBox, "wipe", K.COLW - K.WIPEX, K.WIPEH)
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", 0, 0)
    r.stripe:SetPoint("BOTTOMLEFT", 0, 0)
    r.name = Label(r, "GameFontHighlightSmall", K.LINE)
    r.name:SetPoint("LEFT", K.ENCNAME, 0)
    r.play = ns.ReplayLink.Mini(r, K.PLAYSZ)
    r.play:SetPoint("RIGHT", -2, 0)
    r.play.pick = Open
    DelButton(r):SetPoint("RIGHT", r.play, "LEFT", 0, 0)
    r.onClick = OnWipe
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return r
end
local MAKE = { raid = RaidRow, enc = EncRow, wipe = WipeRow }
local function WipeGeom(r)
    r:SetHeight(K.WIPEH)
    r.name:SetHeight(K.LINE)
end
local GEOM = { raid = RaidGeom, enc = EncGeom, wipe = WipeGeom }
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
local function PaintArt(r, inst, a, inset, alpha)
    local pic = inst and INST_ART[inst]
    if not pic then
        r.art:Hide()
        r.glow:Hide()
        r.fade:Hide()
        return
    end
    local w, h = max(1, rowW - inset * 2), max(1, K.RAIDH - inset * 2)
    local half = (pic.r - pic.l) * h / w * (pic.wide or 1) / 2
    local top, bottom = pic.y - half, pic.y + half
    r.art:SetTexture(pic.file)
    r.art:SetTexCoord(pic.l, pic.r, top, bottom)
    r.art:SetAlpha(alpha)
    r.glow:SetTexture(pic.file)
    r.glow:SetTexCoord(pic.l, pic.r, top, bottom)
    r.glow:SetAlpha(a.glow)
    Kit.Fill(r.fade, a.fade)
    r.fade:SetWidth(w * a.fadeTo)
    r.art:Show()
    if a.glow > 0 then r.glow:Show() else r.glow:Hide() end
    r.fade:Show()
end
local function PaintRaid(r, line)
    local raid = line.raid
    local d, sel = Kit.Theme().row.raid, Kit.Theme().row.raidOn
    local on = RaidShown(raid)
    local cr, cg, cb
    if line.inst then
        cr, cg, cb = Kit.Color("sem.inst." .. line.inst)
    else
        cr, cg, cb = d.border[1], d.border[2], d.border[3]
    end
    local lift = on and sel.lift or d.lift
    local edge = r.edge or {}
    r.edge = edge
    edge[1], edge[2], edge[3], edge[4] = cr + (1 - cr) * lift, cg + (1 - cg) * lift, cb + (1 - cb) * lift, 1
    Kit.Backdrop(r, d, edge)
    Kit.Fill(r.bg, d.shade)
    r.bg:ClearAllPoints()
    r.bg:SetPoint("TOPLEFT", r, "TOPLEFT", d.inset, -d.inset)
    r.bg:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -d.inset, d.inset)
    PaintArt(r, line.inst, d.art, d.inset, on and sel.art or d.art.alpha)
    r.tile:SetWidth(K.ICON)
    r.tile:SetHeight(K.ICON)
    r.size:SetText(raid.size and tostring(raid.size) or "")
    Kit.Icon.Flag(r.hc, K.ICON)
    if raid.heroic then r.hc:Show() else r.hc:Hide() end
    r.size:ClearAllPoints()
    if raid.heroic then
        r.size:SetPoint("BOTTOM", r.tile, "BOTTOM", 0, K.ICONIN)
    else
        r.size:SetPoint("CENTER", r.tile, "CENTER", 0, 0)
    end
    r.picked = on
    DelShade(r)
    if on then
        local glow = r.glowFill or { grad = { dir = "VERTICAL", from = {}, to = {} }, blend = "ADD" }
        r.glowFill = glow
        local lo, hi = glow.grad.from, glow.grad.to
        lo[1], lo[2], lo[3], lo[4] = cr, cg, cb, sel.glow[1]
        hi[1], hi[2], hi[3], hi[4] = cr, cg, cb, sel.glow[2]
        Kit.Fill(r.on, glow)
        r.on:Show()
    else
        r.on:Hide()
    end
    Kit.Text(r.name, on and "sem.pick" or "text.title")
    r.score:SetText(format("%d/%d", raid.passed, raid.total))
    Tone(r.score, raid.passed > 0 and "sem.win" or "sem.wipe")
    Fit(r.name, RaidName(raid), rowW - K.TEXTX - K.SCORER - r.score:GetStringWidth() - 6)
    if Folded(raid, line.index) then
        r.fold.tex:SetTexCoord(0.5625, 0, 0, 0, 0.5625, 1, 0, 1)
    else
        r.fold.tex:SetTexCoord(0, 0.5625, 0, 1)
    end
    Fit(r.info, When(raid), rowW - K.TEXTX - K.DELR - K.DELHIT - 4)
end
local function PaintInst(r, line)
    if line.inst and line.kind == "raid" then
        Kit.Paint(r.tint, "sem.inst." .. line.inst)
        r.tint:Show()
    else
        r.tint:Hide()
    end
end
local function PaintEnc(r, line, spot)
    local enc = line.enc
    local on = spot and spot.enc == enc
    r.picked = on and true or false
    DelShade(r)
    Fill(r.stripe, enc.passed and "sem.win" or "sem.wipe")
    r.ok:SetTexture(enc.passed and K.READY or K.NOTREADY)
    if on then Kit.Paint(r.bg, "sem.pick", 0.14) else Kit.Paint(r.bg, "sem.enc") end
    local unbuff = enc.passed and ns.ZoneBuff and ns.ZoneBuff.Unbuffed(ns.FightTree.Decisive(enc))
    if unbuff then r.ub:Show() else r.ub:Hide() end
    local base = K.DOTX + K.PLAYW + K.DELHIT + K.DOTPAD + (unbuff and K.UBSZ + K.UBGAP or 0)
    local wipes = ns.FightTree.Wipes(enc)
    local dots = wipes > K.DOTS and 1 or wipes
    for i = 1, K.DOTS do
        local d = r.dots[i]
        d:ClearAllPoints()
        d:SetPoint("RIGHT", -(base + (i - 1) * (K.DOT + K.DOTGAP)), 0)
        if i <= dots then d:Show() else d:Hide() end
    end
    local right = base + dots * (K.DOT + K.DOTGAP)
    r.count:ClearAllPoints()
    if wipes > K.DOTS then
        r.count:SetText(tostring(wipes))
        r.count:SetPoint("RIGHT", -right, 0)
        right = right + r.count:GetStringWidth() + K.DOTGAP
    else
        r.count:SetText("")
    end
    local w = r.wipes
    if wipes > 0 then
        w:ClearAllPoints()
        w:SetPoint("RIGHT", -(base - K.DOTPAD), 0)
        w:SetWidth(right - K.DOTGAP - base + K.DOTPAD * 2)
        w:Show()
    else
        w:Hide()
    end
    if wipes > 0 and openEnc == enc.key then Fill(r.wipeOn, "row.bgOn") else Fill(r.wipeOn, "surface.clear") end
    ns.ReplayLink.MiniFight(r.play, ns.FightTree.Decisive(enc))
    Fit(r.name, ns.EncName(enc.boss), rowW - K.ENCX - K.ENCNAME - right - K.DOTGAP)
    Tone(r.name, on and "sem.pick" or "text.primary")
end
local function PaintWipe(r, line)
    local f = line.fight
    local on = f == fight
    r.picked = on
    DelShade(r)
    if on then Kit.Paint(r.bg, "sem.pick", 0.14) else Kit.Paint(r.bg, "sem.enc") end
    Fill(r.stripe, "sem.wipe")
    ns.ReplayLink.MiniFight(r.play, f)
    Fit(r.name, format(ns.T("fl.wipe.row"), line.n, ns.T("fl.wipe"), Clock(f.to - f.from), f.deaths or 0,
        Hour(f.from)), rowW - K.WIPEX - K.ENCNAME - 4 - K.PLAYW - K.DELHIT)
    Tone(r.name, on and "sem.pick" or "text.secondary")
end
local function AddWipes(out, enc, inst)
    for n = 1, #enc.fights do
        local f = enc.fights[n]
        if not f.killed then out[#out + 1] = { kind = "wipe", enc = enc, fight = f, n = n, inst = inst } end
    end
end
local function Flatten()
    local out = {}
    local raids = ns.FightTree.Get()
    for i = 1, #raids do
        local raid = raids[i]
        local inst = MAP_INST[raid.map or ""] or NAME_INST[raid.name or ""]
        out[#out + 1] = { kind = "raid", raid = raid, index = i, inst = inst }
        if not Folded(raid, i) then
            for k = 1, #raid.encs do
                local enc = raid.encs[k]
                out[#out + 1] = { kind = "enc", enc = enc, inst = inst }
                if enc.key == openEnc then AddWipes(out, enc, inst) end
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
    rowW = K.COLW
    if treeBar and maxOff > 0 then
        rowW = K.COLW - treeBar:GetWidth() - K.BARGAP
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
        GEOM[line.kind](r)
        PaintInst(r, line)
        local x = 0
        if line.kind == "raid" then
            PaintRaid(r, line)
        elseif line.kind == "enc" then
            x = K.ENCX
            PaintEnc(r, line, spot)
        else
            x = K.WIPEX
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
    local s = ns.Summary.Peek(f)
    if not s then
        if asked ~= f or not (ns.Summary.Busy and ns.Summary.Busy(f)) then
            asked = f
            ns.Summary.Of(f, function()
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
        for i = 1, #list do
            for k = 1, #list[i].events do
                if list[i].events[k].grade ~= "green" then n = n + 1 end
            end
        end
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
    if row.who and ns.ReplayFollow and ns.ReplayFollow.Pick(fight, row.who) then return end
    if row.who and ns.Timeline and ns.Timeline.SelectPlayer then
        ns.Timeline.SelectPlayer(row.who)
    end
end
local function CellGeom(c)
    local col = (c.index - 1) % K.PCOLS
    local line = floor((c.index - 1) / K.PCOLS)
    c:SetWidth(K.PCOLW - 2)
    c:SetHeight(K.PROW)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", col * K.PCOLW, -(line * K.PROW))
    c.cls:SetWidth(K.PROW - 3)
    c.cls:SetHeight(K.PROW - 3)
    c.name:SetHeight(K.LINE)
    c.plate:SetHeight(K.LINE)
    c.plate.text:SetHeight(K.LINE)
    c.dead:SetHeight(K.LINE)
end
local function Cell(index)
    local c = cells[index]
    if c then return c end
    c = NewRow(playerBox, "player", K.PCOLW - 2, K.PROW)
    c.index = index
    c.cls = c:CreateTexture(nil, "ARTWORK")
    c.cls:SetPoint("LEFT", 2, 0)
    c.cls:SetTexture(K.CLASS_TEX)
    c.name = Label(c, "GameFontHighlightSmall", K.LINE)
    c.name:SetPoint("LEFT", c.cls, "RIGHT", 3, 0)
    c.plate = CreateFrame("Frame", nil, c)
    c.plate:SetPoint("RIGHT", -1, 0)
    c.plate.edge = c.plate:CreateTexture(nil, "BACKGROUND")
    c.plate.edge:SetAllPoints()
    Kit.Paint(c.plate.edge, "sem.wipe")
    c.plate.fill = c.plate:CreateTexture(nil, "BORDER")
    c.plate.fill:SetPoint("TOPLEFT", 1, -1)
    c.plate.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    Kit.Paint(c.plate.fill, "sem.fault")
    c.plate.text = Label(c.plate, "GameFontHighlightSmall", K.LINE, "CENTER")
    Kit.Text(c.plate.text, "text.bright")
    c.plate.text:SetPoint("CENTER", 0, 0)
    c.dead = Label(c, "GameFontHighlightSmall", K.LINE, "RIGHT")
    Kit.Text(c.dead, "text.bright")
    c.onClick = OnPlayer
    CellGeom(c)
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
    Fit(c.name, p.name, K.PCOLW - 2 - K.PROW - 4 - right)
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
    return floor((n + K.PCOLS - 1) / K.PCOLS)
end
local function Place(n, force)
    local h = max(K.TREEMIN * STEP.enc, sideH - K.HEADH - K.LISTGAP - K.PHEADH - n * K.PROW)
    if not force and n == playerLines and h == treeH then return false end
    playerLines, treeH = n, h
    treeBox:SetHeight(treeH)
    playerHead:ClearAllPoints()
    playerHead:SetPoint("TOPLEFT", 0, -(K.HEADH + treeH + K.LISTGAP))
    playerBox:ClearAllPoints()
    playerBox:SetPoint("TOPLEFT", 0, -(K.HEADH + treeH + K.LISTGAP + K.PHEADH))
    playerBox:SetHeight(max(1, n * K.PROW))
    playerArea:ClearAllPoints()
    playerArea:SetPoint("TOPLEFT", 0, -(K.HEADH + treeH + K.LISTGAP))
    playerArea:SetWidth(K.COLW)
    playerArea:SetHeight(K.PHEADH + max(1, n * K.PROW))
    if treeBar then treeBar:SetHeight(treeH) end
    return true
end
function FL.DrawPlayers(skipTree)
    if not side then return end
    local list, counted = {}, false
    if fight then list, counted = FL.Participants(fight) end
    FL.counted = counted
    local need = floor((#list + K.PCOLS - 1) / K.PCOLS)
    if Place(need) and not skipTree then DrawTree() end
    local shown = playerLines * K.PCOLS
    for i = 1, shown do
        local c = Cell(i)
        local p = list[i]
        if p then
            CellGeom(c)
            PaintCell(c, p)
            c:Show()
        else
            c:Hide()
        end
    end
    for i = shown + 1, #cells do cells[i]:Hide() end
    Fit(playerCtx, TryTitle(fight), K.COLW - playerHead:GetStringWidth() - 6)
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
function FL.FitTitle()
    if not headTitle then return end
    local room = K.COLW - (nav:IsShown() and nav:GetWidth() + K.NAVGAP * 2 or 0)
    headTitle:SetWidth(0)
    local w = headTitle:GetStringWidth()
    headTitle:SetWidth(max(1, min(floor(w) + 2, room)))
end
local function DrawNav()
    if not nav then return end
    ns.ReplayLink.SetFight(fight)
    if ns.ThreatView and ns.ThreatView.SetFight then ns.ThreatView.SetFight(fight) end
    local spot = ns.FightTree.Spot(fight)
    if not spot then
        nav:SetWidth(1)
        nav:Hide()
        FL.FitTitle()
        return
    end
    local total = #spot.enc.fights
    navOut:SetText(format("%s %s", ns.T(fight.killed and "fl.win" or "fl.wipe"), Clock(fight.to - fight.from)))
    Tone(navOut, fight.killed and "sem.win" or "sem.wipe")
    navOut:ClearAllPoints()
    if total > 1 then
        navNo:SetText(format("%d/%d", spot.n, total))
        navNo:SetWidth(navNo:GetStringWidth() + 2)
        NavTip(navPrev, spot.enc.fights[spot.n - 1], spot.n - 1)
        NavTip(navNext, spot.enc.fights[spot.n + 1], spot.n + 1)
        navPrev:Show()
        navNo:Show()
        navNext:Show()
        navOut:SetPoint("LEFT", navNext, "RIGHT", K.NAVGAP * 2, 0)
        nav:SetWidth(K.NAVBTN * 2 + K.NAVGAP * 4 + navNo:GetWidth() + navOut:GetStringWidth())
    else
        navPrev:Hide()
        navNo:Hide()
        navNext:Hide()
        navOut:SetPoint("LEFT", nav, "LEFT", 0, 0)
        nav:SetWidth(navOut:GetStringWidth() + 2)
    end
    nav:Show()
    FL.FitTitle()
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
    local b = Kit.ToolButton(nav)
    b.text:SetText(label)
    b.tipTitle = ns.T(tip)
    b.onClick = function() Step(step) end
    return b
end
local function AttachNav(host, title, status)
    nav = CreateFrame("Frame", nil, host)
    nav:SetHeight(K.NAVBTN)
    nav:SetWidth(1)
    navPrev = NavButton("<", "fl.nav.prev", -1)
    navPrev:SetPoint("LEFT", 0, 0)
    navNo = Label(nav, "GameFontHighlightSmall", K.LINE, "CENTER")
    Kit.Text(navNo, "text.bright")
    navNo:SetPoint("LEFT", navPrev, "RIGHT", K.NAVGAP, 0)
    navNext = NavButton(">", "fl.nav.next", 1)
    navNext:SetPoint("LEFT", navNo, "RIGHT", K.NAVGAP, 0)
    navOut = Label(nav, "GameFontHighlightSmall", K.LINE)
    navOut:SetPoint("LEFT", navNext, "RIGHT", K.NAVGAP * 2, 0)
    nav:SetPoint("LEFT", title, "RIGHT", K.NAVGAP * 2, 0)
    nav:Hide()
    headTitle = title
    title:SetWordWrap(false)
    title:SetJustifyH("LEFT")
    tools = Kit.ToolBar(host, "LEFT", title, "LEFT", K.WIDTH, 0)
    tools:Add(ns.ReplayLink.Head(host))
    if not ns.ReadOnly then tools:Add(ns.ReplayLink.SaveHead(host)) end
    if ns.ThreatView then tools:Add(ns.ThreatView.Head(host)) end
    if ns.SumSide then tools:Add(ns.SumSide.Head(host)) end
    if ns.SumHide then ns.SumHide.Head(host) end
    if status then status:SetPoint("LEFT", tools.tail, "RIGHT", K.NAVGAP, 0) end
end
Tips.raid = function(r)
    local raid = r.line.raid
    local kind = ns.T(raid.heroic and "fl.diff.hc" or "fl.diff.nm")
    if raid.size then kind = format(ns.T("fl.tip.kind"), raid.size, kind) end
    local wipes, kills, off = 0, 0, 0
    for i = 1, #raid.encs do
        local enc = raid.encs[i]
        wipes = wipes + ns.FightTree.Wipes(enc)
        if enc.passed then
            kills = kills + 1
            if ns.ZoneBuff and ns.ZoneBuff.Unbuffed(ns.FightTree.Decisive(enc)) then off = off + 1 end
        end
    end
    if off > 0 then kind = kind .. ", " .. format(ns.T("zb.raid"), off, kills) end
    local tail = ns.Date(raid.to) == ns.Date(raid.from) and Hour(raid.to) or ns.Date(raid.to, "dayTime")
    return {
        Line(RaidName(raid)),
        Line(kind, raid.heroic and "tip.body" or "tip.dim"),
        Line(raid.id and format(ns.T("fl.tip.lock"), raid.id) or ns.T("fl.tip.nolock"), "tip.dim"),
        Line(format(ns.T("fl.tip.when"), ns.Date(raid.from, "dayTime"), tail), "tip.dim"),
        Line(format(ns.T("fl.tip.passed"), raid.passed, raid.total, wipes)),
    }
end
Tips.enc = function(r)
    local enc = r.line.enc
    local n = #enc.fights
    local out = {
        Line(ns.EncName(enc.boss)),
        Line(format(ns.T(enc.passed and "fl.tip.enc.pass" or "fl.tip.enc.fail"), n, ns.FightTree.Wipes(enc)),
            enc.passed and "sem.win" or "sem.wipe"),
    }
    if enc.passed and ns.ZoneBuff and ns.ZoneBuff.Unbuffed(ns.FightTree.Decisive(enc)) then
        out[#out + 1] = Line(ns.T("zb.kill"), "tip.body")
    end
    local from = max(1, n - K.TIPMAX + 1)
    if from > 1 then out[#out + 1] = Line(format(ns.T("fl.tip.more"), from - 1, ns.Plural(from - 1, ns.T("rsum.w.tries.nom"))), "tip.dim") end
    for i = from, n do
        local f = enc.fights[i]
        local token = f == fight and "sem.pick" or (f.killed and "sem.win" or "tip.dim")
        out[#out + 1] = Line(format(ns.T("fl.tip.enc.line"), i, ns.T(f.killed and "fl.win" or "fl.wipe"),
            Clock(f.to - f.from), f.deaths or 0, Hour(f.from)), token)
    end
    for i = n, 1, -1 do
        local f = enc.fights[i]
        if f.progress then
            out[#out + 1] = Line(format(ns.T("fl.tip.enc.progress"), ns.EncName(f.progress)), "tip.body")
            break
        end
    end
    out[#out + 1] = Line(ns.T("fl.tip.enc.nav"), "text.primary", true)
    out[#out + 1] = { kind = "foot", key = "lmb", left = ns.T(enc.passed and "fl.tip.enc.kill" or "fl.tip.enc.last") }
    if ns.FightTree.Wipes(enc) > 0 then out[#out + 1] = { kind = "foot", key = "lmb", left = ns.T("fl.tip.enc.wipes") } end
    out[#out + 1] = { kind = "foot", key = "rmb", left = ns.T("fl.tip.enc.menu") }
    return out
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
    Del.Ask(format(ns.T("fl.del.try.ask"), n, ns.EncName(f.boss), ns.T(f.killed and "fl.win" or "fl.wipe"), Clock(f.to - f.from),
        ns.Date(f.from, "dayTime")), { f }, Del.Last(spot and spot.raid, { f }))
end
function Del.AskEnc(enc)
    local list = {}
    for i = 1, #enc.fights do list[i] = enc.fights[i] end
    Del.Ask(format(ns.T("fl.del.enc.ask"), ns.EncName(enc.boss), #list), list, Del.Last(enc.raid, list))
end
function Del.AskRaid(raid)
    Del.Ask(format(ns.T("fl.del.raid.ask"), RaidName(raid), ns.Date(raid.from), raid.tries),
        ns.FightTree.RaidFights(raid), Del.RaidSegs(raid))
end
function Del.EncMenu(row)
    local enc = row.line.enc
    ns.Tip.Hide()
    Kit.Menu({
        { text = ns.EncName(enc.boss), isTitle = true },
        { text = ns.T("fl.menu.enc.del"), func = function() Del.AskEnc(enc) end },
    }, row)
end
function Del.WipeMenu(row)
    local f, n = row.line.fight, row.line.n
    ns.Tip.Hide()
    Kit.Menu({
        { text = format(ns.T("fl.try.title"), ns.EncName(f.boss), n), isTitle = true },
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
    out[#out + 1] = { kind = "foot", key = "lmb", left = ns.T("fl.tip.player") }
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
    side:SetWidth(K.COLW)
    side:SetPoint("TOPLEFT", x, -y)
    headLabel = Label(side, "GameFontNormalSmall", K.LINE)
    Kit.Text(headLabel, "text.title")
    headLabel:SetPoint("TOPLEFT", 0, -2)
    headLabel:SetText(ns.T("fl.raids"))
    headHint = NewRow(side, "head", K.WIDTH / 2, K.HEADH)
    headHint:SetPoint("TOPLEFT", 0, 0)
    headHint.hover:SetAlpha(0)
    treeBox = CreateFrame("Frame", nil, side)
    treeBox:SetPoint("TOPLEFT", 0, -K.HEADH)
    treeBox:SetWidth(K.COLW)
    if ns.MakeScrollBar then
        treeBar = ns.MakeScrollBar(side, K.TREEMIN * STEP.enc)
        treeBar:SetPoint("TOPRIGHT", treeBox, "TOPRIGHT", 0, 0)
    end
    Wheel(treeBox, treeBar, function(delta, offset)
        treeOffset = offset or (treeOffset - delta * K.WHEEL)
        DrawTree()
    end)
    playerHead = Label(side, "GameFontNormalSmall", K.LINE)
    Kit.Text(playerHead, "text.title")
    playerHead:SetText(ns.T("tl.players"))
    playerCtx = Label(side, "GameFontHighlightSmall", K.LINE)
    Kit.Text(playerCtx, "text.bright")
    playerCtx:SetPoint("LEFT", playerHead, "RIGHT", 6, 0)
    playerBox = CreateFrame("Frame", nil, side)
    playerBox:SetWidth(K.COLW)
    playerArea = CreateFrame("Frame", nil, side)
end
function FL.PlayerArea()
    return playerArea
end
function FL.Cover(on)
    if not side then return end
    if on then
        playerHead:Hide()
        playerCtx:Hide()
        playerBox:Hide()
    else
        playerHead:Show()
        playerCtx:Show()
        playerBox:Show()
    end
end
local function Regeom()
    side:SetWidth(K.COLW)
    treeBox:SetWidth(K.COLW)
    treeBox:ClearAllPoints()
    treeBox:SetPoint("TOPLEFT", 0, -K.HEADH)
    playerBox:SetWidth(K.COLW)
    playerArea:SetWidth(K.COLW)
    headLabel:SetHeight(K.LINE)
    headHint:SetWidth(K.WIDTH / 2)
    headHint:SetHeight(K.HEADH)
    playerHead:SetHeight(K.LINE)
    playerCtx:SetHeight(K.LINE)
    if nav then
        navNo:SetHeight(K.LINE)
        navOut:SetHeight(K.LINE)
        tools.x = K.WIDTH
        tools:Layout()
        DrawNav()
    end
    for kind, pool in pairs(pools) do
        for i = 1, #pool do GEOM[kind](pool[i]) end
    end
    for i = 1, #cells do CellGeom(cells[i]) end
end
function FL.Layout(height)
    if not side then return end
    if Measure() then Regeom() end
    sideH = max(K.HEADH + K.LISTGAP + K.PHEADH + K.TREEMIN * STEP.enc, height)
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
