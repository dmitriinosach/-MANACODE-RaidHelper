local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local PAD = 5
local STRIP = 22
local MIN_SIDE = 140
local MAX_SIDE = 900
local LEVEL = 80
local DOT = 6
local MINE = 10
local NPC = 7
local BOSS_RING = 18
local BOSS_SKULL = 14
local HIT = 16
local STALE_ALPHA = 0.35
local HYST = 8
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local Map = {}
ns.MapView = Map
local frame, canvas, plate, hint, floorTex
local host, area, cover
local onTimeline = false
local docked = true
local peek = false
local free = { x = 0, y = 0, w = 0 }
local seenFight, seenWho
local aspect = 1
local replayRoom
local coords = {}
local cam = { angle = 0, tilt = 1, persp = 0, zoom = 1, lift = 0, r = 1, a = 0, cx = 0, cy = 0, w = 1, h = 1,
              c = 1, s = 0 }
local sizing
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
    local body = format(ns.T("map.tip.derived"), mark.witnesses or 0)
    if (mark.witnesses or 0) < 2 then body = body .. "\n" .. ns.T("map.tip.rough") end
    mark.tipTitle = format(ns.T(mark.isBoss and "map.tip.boss" or "map.tip.npc"), mark.who or "")
    mark.tip, mark.tipTone = body, "text.secondary"
    ns.Kit.TipShow(mark)
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
        mark:SetScript("OnLeave", ns.Kit.TipHide)
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
local function Project(x, y)
    local w, h = plate:GetWidth(), plate:GetHeight()
    if not replayRoom then return ns.MapDraw.Project(room, x, y, w, h) end
    local Replay = ns.Replay
    local sx, sy = Replay.Project(cam, x * Replay.AREA_W, y * Replay.AREA_H)
    local px, py = w / 2 + sx, h / 2 + sy
    if px < 0 or px > w or py < 0 or py > h then return nil, nil end
    return px, py
end
local function TileAspect(view)
    if not view then return aspect end
    local wide, tall = (view.r - view.l) * 4, (view.b - view.t) * 3
    if wide > 0 and tall > 0 then return wide / tall end
    return 4 / 3
end
local Place, Layout
local function ApplyRoom(rr, view)
    local want = rr and 1 or TileAspect(view)
    if want ~= aspect and not sizing then
        aspect = want
        Place()
        Layout()
        return false
    end
    local w = floor(plate:GetWidth())
    local h = floor(plate:GetHeight())
    if rr == replayRoom and view == room and w == boxW and h == boxH then return end
    boxW, boxH = w, h
    replayRoom, room = rr, view
    local shown
    if rr then
        for i = 1, #tiles do tiles[i]:Hide() end
        local half = ns.Replay.FlatCoords(rr, coords)
        cam.cx, cam.cy, cam.r, cam.w, cam.h = rr.cx, rr.cy, rr.r, w, h
        cam.zoom = w / (2 * half)
        ns.Replay.Aim(cam)
        shown = floorTex:SetTexture(ROOM_PATH .. rr.tex) ~= false
        floorTex:SetTexCoord(coords[1], coords[2], coords[3], coords[4], coords[5], coords[6], coords[7], coords[8])
        if shown then floorTex:Show() else floorTex:Hide() end
    else
        floorTex:Hide()
        shown = ns.MapDraw.Tiles(tiles, plate, view, w, h)
    end
    hasTiles = shown
    if not rr and not view then
        hint:SetText(ns.T("map.offmap"))
        hint:Show()
    elseif not shown then
        hint:SetText(ns.T("map.notex"))
        hint:Show()
    else
        hint:Hide()
    end
end
local function Render(t, who)
    lastT, lastWho = t, who
    local snap = FrameAt(t)
    local rr = snap and loadedFight and ns.Replay and ns.Replay.RoomOf(loadedFight.boss, snap.floor) or nil
    if ApplyRoom(rr, snap and rooms[snap.floor] or nil) == false then return end
    local shown, marked = 0, 0
    if snap and (room or replayRoom) then
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
end
function Layout()
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", PAD, -PAD)
    local cw, ch = max(1, frame:GetWidth() - PAD - STRIP), max(1, frame:GetHeight() - PAD * 2)
    canvas:SetWidth(cw)
    canvas:SetHeight(ch)
    if docked then cw, ch = max(1, floor(min(cw, ch * aspect))), max(1, floor(min(ch, cw / aspect))) end
    plate:ClearAllPoints()
    plate:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    plate:SetWidth(cw)
    plate:SetHeight(ch)
    hint:SetWidth(max(1, frame:GetWidth() - PAD - STRIP - 12))
    boxW, boxH = nil, nil
    if lastT then
        Render(lastT, lastWho)
    elseif #posFrames > 0 then
        Render(posFrames[1].t, nil)
    else
        ApplyRoom(nil, nil)
        hint:SetText(ns.T("map.nodata"))
        hint:Show()
    end
end
local function Fit(w)
    local hw, hh = host:GetWidth() or 0, host:GetHeight() or 0
    local most = MAX_SIDE
    if hw > 0 then most = min(most, hw - PAD - STRIP) end
    if hh > 0 then most = min(most, (hh - PAD * 2) * aspect) end
    local side = max(MIN_SIDE, min(max(MIN_SIDE, most), w - PAD - STRIP))
    return floor(side + PAD + STRIP + 0.5), floor(side / aspect + PAD * 2 + 0.5)
end
function Place()
    frame:ClearAllPoints()
    if docked then
        frame:SetWidth(max(1, area:GetWidth() or 0))
        frame:SetHeight(max(1, area:GetHeight() or 0))
        frame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
        return
    end
    local w, h = Fit(free.w)
    local x, y = free.x, free.y
    local hw, hh = host:GetWidth() or 0, host:GetHeight() or 0
    if hw > w then x = max(0, min(hw - w, x)) end
    if hh > h then y = max(0, min(hh - h, y)) end
    frame:SetWidth(w)
    frame:SetHeight(h)
    frame:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", x, y)
end
local function Remember()
    local l, bt, hl, hb = frame:GetLeft(), frame:GetBottom(), host:GetLeft(), host:GetBottom()
    if l and bt and hl and hb then free.x, free.y = floor(l - hl + 0.5), floor(bt - hb + 0.5) end
    free.w = floor(frame:GetWidth() + 0.5)
end
local Apply
local function Undock()
    if not docked then return end
    Remember()
    docked = false
    Apply()
end
local function Sizing(self)
    if not sizing then return end
    local s = self:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / s, cy / s
    local dw, dh = cx - sizing.x, (sizing.y - cy) * aspect
    local w, h = Fit(sizing.w + (math.abs(dw) >= math.abs(dh) and dw or dh))
    if w ~= floor(self:GetWidth() + 0.5) or h ~= floor(self:GetHeight() + 0.5) then
        self:SetWidth(w)
        self:SetHeight(h)
        Layout()
    end
end
local function SizeStart()
    Undock()
    local s = frame:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    sizing = { x = cx / s, y = cy / s, w = frame:GetWidth(), h = frame:GetHeight() }
    local l, t, hl, ht = frame:GetLeft(), frame:GetTop(), host:GetLeft(), host:GetTop()
    if l and t and hl and ht then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", l - hl, t - ht)
    end
    frame:SetScript("OnUpdate", Sizing)
end
local function SizeStop()
    if not sizing then return end
    Sizing(frame)
    sizing = nil
    frame:SetScript("OnUpdate", nil)
    Remember()
    Place()
    Layout()
end
function Map.ShowAt(t, who)
    if not frame or not frame:IsShown() then return end
    Render(t, who)
end
local function ShowEmpty(key)
    hint:SetText(ns.T(key))
    hint:Show()
    for i = 1, 12 do tiles[i]:Hide() end
    for i = 1, #dots do dots[i]:Hide() end
    for i = 1, #marks do marks[i]:Hide() end
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
    frame = CreateFrame("Frame", nil, host)
    ns.Kit.Skin(frame, "plate")
    frame.sized = true
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:SetFrameLevel(host:GetFrameLevel() + LEVEL)
    frame:SetScript("OnDragStart", function(self)
        Undock()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Remember()
        Place()
    end)
    Place()
    canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("TOPLEFT", PAD, -PAD)
    local bg = canvas:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "plate.bg")
    plate = CreateFrame("Frame", nil, canvas)
    plate:SetPoint("TOPLEFT")
    floorTex = plate:CreateTexture(nil, "ARTWORK")
    floorTex:SetAllPoints(plate)
    floorTex:Hide()
    for i = 1, 12 do
        tiles[i] = plate:CreateTexture(nil, "ARTWORK")
        tiles[i]:Hide()
    end
    hint = ns.Kit.Str(frame, "GameFontHighlightSmall")
    ns.Kit.Text(hint, "text.bright")
    hint:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    hint:Hide()
    local close = ns.Kit.CloseButton(frame, function() Map.Toggle() end)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetFrameLevel(frame:GetFrameLevel() + 10)
    local grip = ns.Kit.Grip(frame, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip.onDown = SizeStart
    grip.onUp = SizeStop
    Layout()
end
ns.Kit.OnFont(function()
    if frame then Layout() end
end)
function Map.IsOn()
    return ns.GetDB().settings.ui.mapOn ~= false
end
function Apply()
    if not host or not area then return end
    local on = onTimeline and Map.IsOn()
    local show = on and (peek or not docked)
    if show then
        if not frame then Build() end
        Place()
        Layout()
        frame:Show()
        if loadedFight ~= wantFight then LoadFight() end
    elseif frame then
        frame:Hide()
        if not on and loadedFight then
            loadedFight = nil
            ns.Encounters.CancelPositions()
        end
    end
    if cover then cover(show and docked) end
end
function Map.SetHost(parent, playerArea, onCover)
    host, area, cover = parent, playerArea, onCover
end
function Map.SetTimeline(on)
    onTimeline = on and true or false
    if not onTimeline then seenFight, seenWho, peek = nil, nil, false end
    Apply()
end
function Map.SetPlayer(fight, who)
    if fight == seenFight and who == seenWho then return end
    seenFight, seenWho = fight, who
    docked, peek = true, false
    Apply()
end
function Map.Track(x, y, line, over)
    if not docked or not area or not onTimeline or sizing or not Map.IsOn() then return end
    local want = peek
    if over and x >= line then
        want = true
    elseif peek and x < line - HYST then
        local top, bottom = area:GetTop(), area:GetBottom()
        if top and bottom and y <= top + HYST and y >= bottom - HYST and not frame:IsMouseOver() then
            want = false
        end
    end
    if want ~= peek then
        peek = want
        Apply()
    elseif peek and (math.abs(frame:GetWidth() - max(1, area:GetWidth() or 0)) > 0.5
        or math.abs(frame:GetHeight() - max(1, area:GetHeight() or 0)) > 0.5) then
        Place()
        Layout()
    end
end
function Map.Toggle()
    local ui = ns.GetDB().settings.ui
    ui.mapOn = not Map.IsOn()
    peek = ui.mapOn
    Apply()
end
function Map.Docked()
    return docked
end
function Map.Frame()
    return frame
end
