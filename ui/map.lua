local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local SIZE = 320
local PAD = 8
local HEAD = 26
local FOOT = 22
local MIN_W = 220
local MIN_H = 200
local DOT = 6
local MINE = 10
local NPC = 7
local BOSS_RING = 18
local BOSS_SKULL = 14
local HIT = 16
local STALE_ALPHA = 0.35
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local Map = {}
ns.MapView = Map
local frame, canvas, plate, hint, titleText, footText
local tiles = {}
local dots = {}
local marks = {}
local posFrames = {}
local rooms = {}
local room, boxW, boxH, hasTiles
local lastT, lastWho
local wantFight, loadedFight
local function GetDot(index)
    local dot = dots[index]
    if not dot then
        dot = plate:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(CIRCLE)
        dots[index] = dot
    end
    return dot
end
local function MarkTip(mark)
    GameTooltip:SetOwner(mark, "ANCHOR_RIGHT")
    GameTooltip:AddLine(format(ns.T(mark.isBoss and "map.tip.boss" or "map.tip.npc"),
        mark.who or ""))
    ns.Kit.TipAdd(format(ns.T("map.tip.derived"), mark.witnesses or 0), "text.secondary")
    if (mark.witnesses or 0) < 2 then
        ns.Kit.TipAdd(ns.T("map.tip.rough"), "text.secondary")
    end
    GameTooltip:Show()
end
local function GetMark(index)
    local mark = marks[index]
    if not mark then
        mark = CreateFrame("Frame", nil, plate)
        mark:SetWidth(HIT)
        mark:SetHeight(HIT)
        mark:EnableMouse(true)
        mark.ring = mark:CreateTexture(nil, "OVERLAY")
        mark.ring:SetTexture(CIRCLE)
        mark.ring:SetPoint("CENTER")
        mark.skull = mark:CreateTexture(nil, "OVERLAY")
        mark.skull:SetTexture(SKULL)
        mark.skull:SetTexCoord(0.75, 1, 0.25, 0.5)
        ns.Kit.Tint(mark.skull, "sem.map.skull")
        mark.skull:SetPoint("CENTER")
        mark:SetScript("OnEnter", MarkTip)
        mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
        marks[index] = mark
    end
    return mark
end
local function FrameAt(t)
    local best = nil
    for i = 1, #posFrames do
        if posFrames[i].t <= t then best = posFrames[i] else break end
    end
    return best or posFrames[1]
end
local function FitPlate()
    local w, h = ns.MapDraw.Fit(room, canvas:GetWidth(), canvas:GetHeight())
    plate:SetWidth(w)
    plate:SetHeight(h)
end
local function SetTiles()
    return ns.MapDraw.Tiles(tiles, plate, room, plate:GetWidth(), plate:GetHeight())
end
local function Project(x, y)
    return ns.MapDraw.Project(room, x, y, plate:GetWidth(), plate:GetHeight())
end
local function ApplyRoom(view)
    local w = floor(canvas:GetWidth())
    local h = floor(canvas:GetHeight())
    if view == room and w == boxW and h == boxH then return end
    boxW, boxH = w, h
    room = view
    FitPlate()
    hasTiles = SetTiles()
    if not room then
        hint:SetText(ns.T("map.offmap"))
        hint:Show()
    elseif not hasTiles then
        hint:SetText(ns.T("map.notex"))
        hint:Show()
    else
        hint:Hide()
    end
end
local function Render(t, who)
    lastT, lastWho = t, who
    local snap = FrameAt(t)
    ApplyRoom(snap and rooms[snap.floor] or nil)
    local shown, marked, bossSeen = 0, 0, 0
    if snap and room then
        for name, p in pairs(snap.units) do
            if p.x > 0 or p.y > 0 then
                local px, py = Project(p.x, p.y)
                if px then
                    shown = shown + 1
                    local dot = GetDot(shown)
                    local isMe = (name == who)
                    local size = isMe and MINE or DOT
                    dot:SetWidth(size)
                    dot:SetHeight(size)
                    local a = p.stale and STALE_ALPHA or 1
                    if isMe then
                        ns.Kit.Hue(dot, "sem.map.me", a)
                    elseif p.hp == 0 then
                        ns.Kit.Hue(dot, "sem.map.dead", ns.Kit.C["sem.map.dead"][4] * a)
                    else
                        ns.Kit.Hue(dot, "sem.map.unit", a)
                    end
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", plate, "TOPLEFT", px, -py)
                    dot:Show()
                end
            end
        end
        local list = snap.npcs
        for i = 1, list and #list or 0 do
            local npc = list[i]
            local px, py = Project(npc.x, npc.y)
            if px then
                marked = marked + 1
                local mark = GetMark(marked)
                mark.who = npc.name
                mark.isBoss = npc.boss
                mark.witnesses = npc.n
                local ring = npc.boss and BOSS_RING or NPC
                mark:SetWidth(max(HIT, ring))
                mark:SetHeight(max(HIT, ring))
                mark.ring:SetWidth(ring)
                mark.ring:SetHeight(ring)
                if npc.boss then
                    bossSeen = npc.n
                    ns.Kit.Hue(mark.ring, "sem.map.boss")
                    mark.skull:SetWidth(BOSS_SKULL)
                    mark.skull:SetHeight(BOSS_SKULL)
                    mark.skull:Show()
                else
                    ns.Kit.Hue(mark.ring, "sem.map.npc")
                    mark.skull:Hide()
                end
                mark:ClearAllPoints()
                mark:SetPoint("CENTER", plate, "TOPLEFT", px, -py)
                mark:Show()
            end
        end
    end
    for i = shown + 1, #dots do dots[i]:Hide() end
    for i = marked + 1, #marks do marks[i]:Hide() end
    titleText:SetText(format(ns.T("map.title"), shown))
    local note = snap and loadedFight and ns.Encounters.FloorNote(loadedFight.boss, snap.floor)
    if snap and snap.lost then
        local sec = max(0, floor(snap.lost - (loadedFight and loadedFight.from or snap.lost)))
        footText:SetText(format(ns.T("map.lost"), floor(sec / 60), sec % 60))
    elseif note then
        footText:SetText(ns.T("map.note." .. note))
    elseif bossSeen > 0 then
        footText:SetText(format(ns.T("map.boss.yes"), bossSeen))
    else
        footText:SetText(ns.T("map.boss.no"))
    end
end
local function Layout()
    canvas:SetWidth(max(1, frame:GetWidth() - PAD * 2))
    canvas:SetHeight(max(1, frame:GetHeight() - HEAD - FOOT))
    footText:SetWidth(max(1, frame:GetWidth() - PAD * 2))
    hint:SetWidth(max(1, frame:GetWidth() - PAD * 2 - 12))
    boxW, boxH = nil, nil
    if lastT then
        Render(lastT, lastWho)
    elseif #posFrames > 0 then
        Render(posFrames[1].t, nil)
    else
        ApplyRoom(nil)
        hint:SetText(ns.T("map.nodata"))
        hint:Show()
        footText:SetText("")
        titleText:SetText(format(ns.T("map.title"), 0))
    end
end
function Map.ShowAt(t, who)
    if not frame or not frame:IsShown() then return end
    Render(t, who)
end
local function ShowEmpty(key)
    hint:SetText(ns.T(key))
    hint:Show()
    footText:SetText("")
    for i = 1, 12 do tiles[i]:Hide() end
    for i = 1, #dots do dots[i]:Hide() end
    for i = 1, #marks do marks[i]:Hide() end
    titleText:SetText(format(ns.T("map.title"), 0))
end
local function LoadFight()
    local fight = wantFight
    loadedFight = fight
    posFrames, rooms = {}, {}
    room, boxW, boxH, lastT, lastWho = nil, nil, nil, nil, nil
    if not frame then return end
    if not fight then
        ShowEmpty("map.nodata")
        return
    end
    ShowEmpty("map.loading")
    ns.Encounters.Positions(fight, function(list, found)
        if loadedFight ~= fight then return end
        posFrames, rooms = list or {}, found or {}
        room, boxW, boxH, lastT, lastWho = nil, nil, nil, nil, nil
        if #posFrames == 0 then
            ShowEmpty(ns.Store.Bare(fight) and "rec.bare" or "map.nodata")
        else
            Render(posFrames[1].t, nil)
        end
    end)
end
function Map.SetFight(fight)
    wantFight = fight
    if frame and frame:IsShown() and loadedFight ~= fight then LoadFight() end
end
local function Build()
    local ui = ns.GetDB().settings.ui
    frame = CreateFrame("Frame", "HTP_FailWatchMap", UIParent)
    frame:SetWidth(max(MIN_W, ui.mapW or (SIZE + PAD * 2)))
    frame:SetHeight(max(MIN_H, ui.mapH or (SIZE + HEAD + FOOT)))
    ns.Kit.Window(frame)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetMinResize(MIN_W, MIN_H)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local db = ns.GetDB().settings.ui
        db.mapPoint, db.mapX, db.mapY = point, x, y
    end)
    frame:SetPoint(ui.mapPoint or "CENTER", UIParent, ui.mapPoint or "CENTER",
        ui.mapX or 320, ui.mapY or 0)
    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOPLEFT", 10, -8)
    ns.Kit.Title(titleText)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() Map.Hide() end)
    canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("TOPLEFT", PAD, -HEAD)
    local bg = canvas:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "plate.bg")
    plate = CreateFrame("Frame", nil, canvas)
    plate:SetPoint("CENTER")
    for i = 1, 12 do
        tiles[i] = plate:CreateTexture(nil, "ARTWORK")
        tiles[i]:Hide()
    end
    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(hint, "text.bright")
    hint:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    hint:Hide()
    footText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footText:SetPoint("BOTTOMLEFT", PAD + 2, 6)
    footText:SetJustifyH("LEFT")
    ns.Kit.Text(footText, "text.secondary")
    local grip = ns.Kit.Grip(frame, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip.onDown = function() frame:StartSizing("BOTTOMRIGHT") end
    grip.onUp = function()
        frame:StopMovingOrSizing()
        local db = ns.GetDB().settings.ui
        db.mapW, db.mapH = frame:GetWidth(), frame:GetHeight()
        local point, _, _, x, y = frame:GetPoint()
        db.mapPoint, db.mapX, db.mapY = point, x, y
        Layout()
    end
    Layout()
end
function Map.Show()
    if not frame then Build() end
    frame:Show()
    ns.GetDB().settings.ui.mapHidden = false
    if loadedFight ~= wantFight then LoadFight() end
end
function Map.Hide()
    if frame then frame:Hide() end
    if loadedFight then
        loadedFight = nil
        ns.Encounters.CancelPositions()
    end
    ns.GetDB().settings.ui.mapHidden = true
end
function Map.Toggle()
    if frame and frame:IsShown() then Map.Hide() else Map.Show() end
end
