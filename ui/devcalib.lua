local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local tsort = table.sort
local T = ns.T
local Kit = ns.Kit
local W = 336
local SIZE = 300
local SIDE = 512
local AREA_W = 1002
local AREA_H = 668
local TICK = 0.2
local ROW = 26
local ME = 12
local PAIR = 7
local PAIRS_SHOWN = 40
local STEP_YD = 0.5
local STEP_BIG = 2
local STEP_SCALE = 0.005
local STEP_ROT = 0.5
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local View = { btn = {} }
ns.DevCalib = View
local Replay = ns.Replay
local frame, box, pic, me, roomText, whereText, pairText, fixText
local pool = {}
local auto = true
local keys = {}
local ki = 1
local roomKey
local work = { dx = 0, dy = 0, scale = 1, rot = 0 }
local dirty = false
local wait = 0
local mapX, mapY, onMap = 0, 0, false
local area, level = "?", 0
local function DB()
    local db = ManaCodeRaidHelperDB
    if type(db) ~= "table" then db = ns.GetDB() end
    return db
end
local function Bag(name)
    local db = DB()
    if type(db[name]) ~= "table" then db[name] = {} end
    return db[name]
end
local function Room()
    return roomKey and Replay.ROOMS[roomKey] or nil
end
local function Copy(f)
    f = type(f) == "table" and f or {}
    return { dx = tonumber(f.dx) or 0, dy = tonumber(f.dy) or 0, scale = tonumber(f.scale) or 1, rot = tonumber(f.rot) or 0 }
end
local function Pairs()
    local room = Room()
    if not room then return {} end
    local all = Bag("calib")
    if type(all[room.tex]) ~= "table" then all[room.tex] = {} end
    return all[room.tex]
end
local function ToBox(room, x, y)
    local fx, fy = Replay.FixPoint(room, x, y)
    local span = room.r / Replay.RIM
    return ((fx - room.cx) / span + 0.5) * SIZE, ((fy - room.cy) / span + 0.5) * SIZE
end
local function Place(tex, sx, sy, d)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", box, "TOPLEFT", sx, -sy)
    tex:SetWidth(d)
    tex:SetHeight(d)
end
local function Dot(i)
    local t = pool[i]
    if not t then
        t = box:CreateTexture(nil, "OVERLAY")
        t:SetTexture(CIRCLE)
        pool[i] = t
    end
    return t
end
local function Draw()
    if not frame then return end
    local room = Room()
    local used = 0
    if room then
        pic:SetTexture(ROOM_PATH .. room.tex)
        pic:Show()
        local list = Pairs()
        for i = max(1, #list - PAIRS_SHOWN + 1), #list do
            local p = list[i]
            used = used + 1
            local a = Dot(used)
            Kit.Hue(a, "sem.pick")
            Place(a, p.u / SIDE * SIZE, p.v / SIDE * SIZE, PAIR)
            a:Show()
            used = used + 1
            local b = Dot(used)
            Kit.Hue(b, "text.muted")
            local bx, by = ToBox(room, p.x * AREA_W, p.y * AREA_H)
            Place(b, bx, by, PAIR - 2)
            b:Show()
        end
        if onMap and (mapX > 0 or mapY > 0) then
            local sx, sy = ToBox(room, mapX * AREA_W, mapY * AREA_H)
            View.meX, View.meY = sx, sy
            Place(me, sx, sy, ME)
            me:Show()
        else
            View.meX, View.meY = nil, nil
            me:Hide()
        end
    else
        pic:Hide()
        me:Hide()
        View.meX, View.meY = nil, nil
    end
    for i = used + 1, #pool do pool[i]:Hide() end
end
local function Texts()
    if not frame then return end
    local room = Room()
    if room then
        roomText:SetText(format(T("dev.cal.room"), room.boss, roomKey, room.floor, auto and "" or T("dev.cal.manual")))
    else
        roomText:SetText(T("dev.cal.none"))
    end
    local inside = ""
    if room and onMap then
        local dx, dy = mapX * AREA_W - room.cx, mapY * AREA_H - room.cy
        if sqrt(dx * dx + dy * dy) > room.r then inside = T("dev.cal.off") end
    end
    whereText:SetText(format(T("dev.cal.where"), tostring(area), level, mapX, mapY, inside))
    pairText:SetText(format(T("dev.cal.pairs"), #Pairs()))
    fixText:SetText(format(T("dev.cal.fix"), work.dx, work.dy, work.scale * 100, work.rot,
        dirty and T("dev.cal.unsaved") or ""))
end
local function Use(key)
    if key == roomKey then return end
    roomKey = key
    local room = Room()
    work = Copy(room and Replay.FixOf(room))
    dirty = room ~= nil and Replay.calibLive[room.tex] ~= nil
end
local function Detect()
    local best, bestD
    for key, room in pairs(Replay.ROOMS) do
        if room.floor == level and Replay.AreaOf(room) == area then
            local dx, dy = mapX * AREA_W - room.cx, mapY * AREA_H - room.cy
            local d = sqrt(dx * dx + dy * dy) / max(1, room.r)
            if d > 1 then d = d + 1000 else d = room.r end
            if not bestD or d < bestD or (d == bestD and key < best) then best, bestD = key, d end
        end
    end
    return best
end
local function Sense()
    if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsShown()) then SetMapToCurrentZone() end
    area = GetMapInfo() or "?"
    level = GetCurrentMapDungeonLevel() or 0
    local x, y = GetPlayerMapPosition("player")
    mapX, mapY = x or 0, y or 0
    onMap = mapX > 0 or mapY > 0
    if auto then
        local key = Detect()
        if key then Use(key) end
    end
end
function View.Refresh()
    Sense()
    Draw()
    Texts()
end
local function Tick(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = TICK
    View.Refresh()
end
local function Changed()
    local room = Room()
    if not room then return end
    dirty = true
    Replay.calibLive[room.tex] = Copy(work)
    Draw()
    Texts()
end
function View.ClickAt(sx, sy)
    local room = Room()
    if not room or not onMap then return nil end
    local list = Pairs()
    local p = {
        x = mapX, y = mapY,
        u = floor(sx / SIZE * SIDE + 0.5), v = floor(sy / SIZE * SIDE + 0.5),
        room = roomKey, floor = level, area = area,
        ppy = Replay.PixelsPerYard(Replay.AreaOf(room), room.floor), t = time(),
    }
    list[#list + 1] = p
    ns.Print(format(T("dev.cal.pair"), #list, p.x, p.y, p.u, p.v))
    Draw()
    Texts()
    return p
end
local function OnClickBox(self)
    local x, y = GetCursorPosition()
    local s = self:GetEffectiveScale()
    local l, t = self:GetLeft(), self:GetTop()
    if not (x and l and t) then return end
    local sx, sy = x / s - l, t - y / s
    if sx < 0 or sy < 0 or sx > SIZE or sy > SIZE then return end
    View.ClickAt(sx, sy)
end
local function Pick(d)
    local n = #keys
    if n == 0 then return end
    for i = 1, n do
        if keys[i] == roomKey then ki = i end
    end
    ki = (ki - 1 + d) % n + 1
    auto = false
    Use(keys[ki])
    Draw()
    Texts()
end
local function Auto()
    auto = true
    View.Refresh()
end
local function Move(arg)
    local k = (IsShiftKeyDown and IsShiftKeyDown()) and STEP_BIG or STEP_YD
    work.dx = work.dx + arg[1] * k
    work.dy = work.dy + arg[2] * k
    Changed()
end
local function Scale(d)
    work.scale = work.scale * (1 + d * STEP_SCALE)
    Changed()
end
local function Rotate(d)
    work.rot = work.rot + d * STEP_ROT
    Changed()
end
local function Save()
    local room = Room()
    if not room then return end
    Bag("calibFix")[room.tex] = Copy(work)
    Replay.calibLive[room.tex] = nil
    dirty = false
    ns.Print(format(T("dev.cal.saved"), room.tex))
    Texts()
end
local function Reset()
    local room = Room()
    if not room then return end
    Bag("calibFix")[room.tex] = nil
    Replay.calibLive[room.tex] = nil
    work = Copy(room.fix)
    dirty = false
    Draw()
    Texts()
end
local function Undo()
    local list = Pairs()
    list[#list] = nil
    Draw()
    Texts()
end
local function Clear()
    local room = Room()
    if not room then return end
    Bag("calib")[room.tex] = {}
    Draw()
    Texts()
end
local function OnBtn(self)
    self.run(self.arg)
end
local function Btn(key, text, tip, run, arg, x, y, w)
    local b = Kit.Button(frame)
    b:SetHeight(Kit.Space.ctl)
    b:SetText(text)
    b.tipTitle = text
    b.tip = tip
    b.run, b.arg = run, arg
    b.onClick = OnBtn
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    b:SetWidth(w)
    View.btn[key] = b
    return b
end
local function Line(y, inner)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", Kit.Space.pad, y)
    fs:SetWidth(inner)
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, "text.secondary")
    return fs
end
local function Build()
    for key in pairs(Replay.ROOMS) do keys[#keys + 1] = key end
    tsort(keys)
    frame = CreateFrame("Frame", "HTP_FailWatchDevCalib", UIParent)
    frame:SetWidth(W)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    local dev = _G.HTP_FailWatchDevTool
    if dev then
        frame:SetPoint("TOPLEFT", dev, "TOPRIGHT", 4, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetScript("OnUpdate", Tick)
    local pad, gap = Kit.Space.pad, Kit.Space.row
    local inner = W - pad * 2
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -12)
    title:SetText(T("dev.cal.title"))
    Kit.Title(title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", View.Hide)
    local y = -36
    local a = 24
    local autoW = 56
    Btn("roomPrev", "<", T("dev.cal.pick.tip"), Pick, -1, pad, y, a)
    Btn("roomNext", ">", T("dev.cal.pick.tip"), Pick, 1, pad + inner - autoW - gap - a, y, a)
    Btn("roomAuto", T("dev.cal.auto"), T("dev.cal.auto.tip"), Auto, nil, pad + inner - autoW, y, autoW)
    roomText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roomText:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + a + 4, y - 6)
    roomText:SetWidth(inner - autoW - gap - a * 2 - 8)
    roomText:SetJustifyH("CENTER")
    Kit.Text(roomText, "text.primary")
    y = y - ROW
    whereText = Line(y, inner)
    y = y - 16
    box = CreateFrame("Frame", nil, frame)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + floor((inner - SIZE) / 2), y)
    box:SetWidth(SIZE)
    box:SetHeight(SIZE)
    box:EnableMouse(true)
    box:SetScript("OnMouseUp", OnClickBox)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    Kit.Paint(bg, "surface.page")
    pic = box:CreateTexture(nil, "ARTWORK")
    pic:SetAllPoints(box)
    me = box:CreateTexture(nil, "OVERLAY")
    me:SetTexture(CIRCLE)
    Kit.Tint(me, "sem.rep.focus")
    View.box = box
    y = y - SIZE - 6
    pairText = Line(y, inner)
    y = y - 16
    local n = 8
    local w = floor((inner - gap * (n - 1)) / n)
    local fixBtns = {
        { "left", "<", "dev.cal.move.tip", Move, { -1, 0 } }, { "right", ">", "dev.cal.move.tip", Move, { 1, 0 } },
        { "up", "^", "dev.cal.move.tip", Move, { 0, -1 } }, { "down", "v", "dev.cal.move.tip", Move, { 0, 1 } },
        { "scaleDown", "S-", "dev.cal.scale.tip", Scale, -1 }, { "scaleUp", "S+", "dev.cal.scale.tip", Scale, 1 },
        { "rotLeft", "R-", "dev.cal.rot.tip", Rotate, -1 }, { "rotRight", "R+", "dev.cal.rot.tip", Rotate, 1 },
    }
    for i = 1, #fixBtns do
        local d = fixBtns[i]
        Btn(d[1], d[2], T(d[3]), d[4], d[5], pad + (i - 1) * (w + gap), y, w)
    end
    y = y - ROW
    fixText = Line(y, inner)
    y = y - 18
    local half = floor((inner - gap) / 2)
    Btn("save", T("dev.cal.save"), T("dev.cal.save.tip"), Save, nil, pad, y, half)
    Btn("reset", T("dev.cal.reset"), T("dev.cal.reset.tip"), Reset, nil, pad + half + gap, y, half)
    y = y - ROW
    Btn("undo", T("dev.cal.undo"), T("dev.cal.undo.tip"), Undo, nil, pad, y, half)
    Btn("clear", T("dev.cal.clear"), T("dev.cal.clear.tip"), Clear, nil, pad + half + gap, y, half)
    y = y - ROW - pad
    frame:SetHeight(-y)
    Kit.Window(frame)
    tinsert(UISpecialFrames, "HTP_FailWatchDevCalib")
    frame:Hide()
end
function View.Show()
    if not frame then Build() end
    frame:Show()
    wait = 0
    View.Refresh()
end
function View.Hide()
    if frame then frame:Hide() end
end
function View.Toggle()
    if frame and frame:IsShown() then View.Hide() else View.Show() end
end
function View.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end
function View.State()
    return roomKey, work, dirty
end
