local ADDON, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local Kit = ns.Kit
local C = Kit.C
local PAD = 5
local GUTTER = 15
local TLW = 236
local BOSSH = 15
local AURAH = 13
local FLOWUP = 16
local FLOWDN = 24
local HPH = 14
local AXISH = 12
local GAP = 3
local ICON = 13
local AURAICON = 12
local DEFICON = 14
local LABELH = 10
local LABEL_SEP = 3
local DELAY = 0.15
local STACK = 3
local TEXMAX = 170
local ICONMAX = 18
local FONTMAX = 24
local TAGMAX = 12
local TAG_ALPHA = 0.8
local BIG_SHARE = 0.2
local FLOW_SHARE = 0.4
local NUM_SHARE = 0.12
local NUM_FALLBACK = 0.25
local DMG_LABELS = 3
local HEAL_LABELS = 2
local LOW_HP = 0.35
local TICK = 5
local FONT_SIZE = 9
local ROW_UP, ROW_DN, ROW_AXIS, ROW_HP, ROW_KILL = 1, 2, 3, 4, 5
local MAP = 104
local MAPGAP = 5
local MAPTEXMAX = 120
local NB_DOT = 4
local ADD_DOT = 5
local ME_DOT = 7
local TRAIL_DOT = 3
local TRAIL_STEP = 3
local TRAIL_DOTS = 48
local TRAIL_FADE = 0.2
local BOSS_RING = 13
local BOSS_SKULL = 10
local CROSS = 10
local STRIPMAX = 40
local GRID_DOT = 2
local ISO_ANGLE = math.pi / 4
local MAP_WAIT = 0.5
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local View = {}
ns.DeathPreviewView = View
local DP = ns.DeathPreview
local Replay = ns.Replay
local Short = ns.BadgeTips.Short
local frame, pump, anchorLine, sumText, font, probe, tagLayer
local tagBg, tagFs = {}, {}
local usedTag = 0
local texPool, iconPool, fontPool = {}, {}, {}
local usedTex, usedIcon, usedFont = 0, 0, 0
local xFrom, xScale, xLeft, xRight = 0, 1, 0, 1
local spanL, spanR, spanRow = {}, {}, {}
local spanN = 0
local picked = {}
local want
local mapBox, mapBg
local mapStrips, stripData, mapPool = {}, {}, {}
local usedMap, usedStrips = 0, 0
local cam = { angle = ISO_ANGLE, tilt = 1, persp = 0, zoom = 1, lift = 0, r = 1, a = 0, cx = 0, cy = 0,
              w = MAP, h = MAP, c = 1, s = 0 }
local function Build()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)
    Kit.Skin(frame, "tip")
    frame:Hide()
    font = CreateFont("HTP_FailWatchPrevFont")
    font:SetFontObject(GameFontHighlightSmall)
    local path, _, flags = GameFontHighlightSmall:GetFont()
    if path then font:SetFont(path, FONT_SIZE, flags or "") end
    probe = frame:CreateFontString(nil, "OVERLAY")
    probe:SetFontObject(font)
    probe:Hide()
    tagLayer = CreateFrame("Frame", nil, frame)
    tagLayer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    tagLayer:SetWidth(1)
    tagLayer:SetHeight(1)
    anchorLine = frame:CreateTexture(nil, "OVERLAY")
    anchorLine:SetWidth(1)
    sumText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sumText:SetJustifyH("LEFT")
    sumText:SetPoint("TOPLEFT", PAD, 0)
    pump = CreateFrame("Frame")
    pump:Hide()
    mapBox = CreateFrame("Frame", nil, frame)
    mapBox:SetWidth(MAP)
    mapBox:SetHeight(MAP)
    mapBg = mapBox:CreateTexture(nil, "BACKGROUND")
    mapBg:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 0, 0)
    mapBg:SetWidth(MAP)
    mapBg:SetHeight(MAP)
    for i = 1, STRIPMAX do
        mapStrips[i] = mapBox:CreateTexture(nil, "BORDER")
        mapStrips[i]:Hide()
    end
    mapBox:Hide()
end
local function Rgba(token)
    local c = C[token]
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4] or 1
end
local function Tex(x, y, w, h, token, a)
    if usedTex >= TEXMAX or w <= 0 or h <= 0 then return nil end
    usedTex = usedTex + 1
    local t = texPool[usedTex]
    if not t then
        t = frame:CreateTexture(nil, "ARTWORK")
        texPool[usedTex] = t
    end
    local r, g, b, ca = Rgba(token)
    t:SetTexture(r, g, b, a or ca)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    t:SetWidth(w)
    t:SetHeight(h)
    t:Show()
    return t
end
local function Icon(id, x, y, size)
    local path = id and ns.Effects.IconById(id)
    if not path or usedIcon >= ICONMAX then return end
    usedIcon = usedIcon + 1
    local t = iconPool[usedIcon]
    if not t then
        t = frame:CreateTexture(nil, "OVERLAY")
        iconPool[usedIcon] = t
    end
    t:SetTexture(path)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    t:SetWidth(size)
    t:SetHeight(size)
    t:Show()
end
local function Measure(text)
    probe:SetText(text)
    return ceil(probe:GetStringWidth() or 0) + 2
end
local function Label(text, x, y, token, justify, w)
    if usedFont >= FONTMAX then return nil end
    usedFont = usedFont + 1
    local fs = fontPool[usedFont]
    if not fs then
        fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(font)
        fontPool[usedFont] = fs
    end
    fs:SetWidth(w or Measure(text))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text)
    fs:SetTextColor(Rgba(token))
    fs:ClearAllPoints()
    local point = justify == "RIGHT" and "TOPRIGHT" or (justify == "CENTER" and "TOP" or "TOPLEFT")
    fs:SetPoint(point, frame, "TOPLEFT", x, y)
    fs:Show()
    return fs
end
local function Free(row, l, r)
    for k = 1, spanN do
        if spanRow[k] == row and l < spanR[k] + LABEL_SEP and r > spanL[k] - LABEL_SEP then return false end
    end
    return true
end
local function Take(row, l, r)
    spanN = spanN + 1
    spanL[spanN], spanR[spanN], spanRow[spanN] = l, r, row
end
local function Boxed(text, l, y, w, token)
    if usedTag >= TAGMAX then return end
    usedTag = usedTag + 1
    local bg, fs = tagBg[usedTag], tagFs[usedTag]
    if not bg then
        bg = tagLayer:CreateTexture(nil, "BACKGROUND")
        fs = tagLayer:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(font)
        fs:SetJustifyH("CENTER")
        tagBg[usedTag], tagFs[usedTag] = bg, fs
    end
    local r, g, b = Rgba("tip.bg")
    bg:SetTexture(r, g, b, TAG_ALPHA)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", tagLayer, "TOPLEFT", floor(l) - 1, y)
    bg:SetWidth(w + 2)
    bg:SetHeight(LABELH)
    bg:Show()
    fs:SetWidth(w)
    fs:SetText(text)
    fs:SetTextColor(Rgba(token))
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", tagLayer, "TOPLEFT", floor(l), y)
    fs:Show()
end
local function Tag(row, text, x, y, token, justify, force, plain)
    local w = Measure(text)
    local l = x
    if justify == "RIGHT" then l = x - w elseif justify == "CENTER" then l = x - w / 2 end
    if l < PAD then l, x, justify = PAD, PAD, "LEFT" end
    if l + w > xRight + PAD then l, x, justify = xRight + PAD - w, xRight + PAD, "RIGHT" end
    if not force and not Free(row, l, l + w) then return false end
    Take(row, l, l + w)
    if plain then Label(text, x, y, token, justify, w) else Boxed(text, l, y, w, token) end
    return true
end
local function XOf(t)
    return xLeft + (t - xFrom) * xScale
end
local function DrawBoss(pv, y)
    if #pv.castT == 0 then return y end
    local lastIcon = -ICON
    for k = 1, #pv.castT do
        local x = floor(XOf(pv.castT[k]))
        Tex(x, y, 1, BOSSH, "sem.lane.boss")
        if x - lastIcon > ICON + 1 then
            Icon(pv.castId[k], x + 1, y - 1, ICON)
            lastIcon = x
        end
    end
    return y - BOSSH - GAP
end
local function DrawAuras(pv, y)
    local rows = #pv.rows
    if rows == 0 then return y end
    for k = 1, rows do
        local row = pv.rows[k]
        Icon(pv.auraId[row], PAD, y, AURAICON)
        for s = 1, #pv.spanAura do
            if pv.spanAura[s] == row then
                local x0 = XOf(pv.spanFrom[s])
                local x1 = XOf(pv.spanTo[s])
                local stack = pv.spanStack[s]
                Tex(floor(x0), y - 2, max(1, floor(x1 - x0)), AURAH - 4, "sem.lane.auras", min(0.95, 0.45 + stack * 0.08))
                if stack > 1 and x1 - x0 >= 8 then Label(tostring(stack), x0 + 2, y, "text.primary") end
            end
        end
        y = y - AURAH
    end
    if pv.extra > 0 then
        Label(format(ns.T("prev.more"), pv.extra), xRight, y + AURAH, "tip.dim", "RIGHT")
    end
    return y - GAP
end
local function Scale(pv)
    if pv.hpMax > 0 then return pv.hpMax * FLOW_SHARE end
    local top = 1
    for b = 1, pv.n do top = max(top, pv.dmg[b] + pv.abs[b], pv.heal[b] + pv.over[b]) end
    return top
end
local function KillBin(pv, b)
    return pv.kbT ~= nil and DP.BinOf(pv, pv.kbT) == b
end
local function BigIn(pv, b)
    for k = 1, #pv.bigV do
        if DP.BinOf(pv, pv.bigT[k]) == b and pv.bigV[k] >= pv.hpMax * BIG_SHARE then return pv.bigId[k] end
    end
    return nil
end
local function KillTag(pv, mid)
    local x = floor(XOf(pv.at)) + 2
    Tag(ROW_KILL, Short(pv.kbV), x, mid - 2, "text.bad", "LEFT", true)
    if pv.kbOver > 0 then
        Tag(ROW_KILL, format(ns.T("prev.kb"), Short(pv.kbOver)), x, mid - 2 - LABELH, "text.warn", "LEFT", true)
    end
end
local function Top(pv, list, least)
    local best
    for b = 1, pv.n do
        if not picked[b] and list[b] >= least and (not best or list[b] > list[best]) then best = b end
    end
    return best
end
local function FlowNumbers(pv, mid, scale)
    local least = pv.hpMax > 0 and pv.hpMax * NUM_SHARE or scale * NUM_FALLBACK
    local floorY = mid - FLOWDN - GAP + LABELH
    for pass = 1, 2 do
        for b = 1, pv.n do picked[b] = nil end
        if pass == 1 and pv.kbT then picked[DP.BinOf(pv, pv.kbT)] = true end
        local list = pass == 1 and pv.dmg or pv.heal
        local shown = 0
        local limit = pass == 1 and DMG_LABELS or HEAL_LABELS
        for _ = 1, pv.n do
            if shown >= limit then break end
            local b = Top(pv, list, least)
            if not b then break end
            picked[b] = true
            local cx = XOf(pv.from + (b - 0.5) * pv.bin)
            local text = Short(list[b])
            if pass == 1 then
                local dh = min(FLOWDN, list[b] / scale * FLOWDN)
                local icon = BigIn(pv, b)
                local top = max(mid - 2 - dh, floorY)
                if icon then top = min(top, mid - ICON - 2) end
                if Tag(ROW_DN, text, cx, top, "text.bad", "CENTER") then
                    shown = shown + 1
                    if icon then Icon(icon, floor(cx - ICON / 2), mid - 1, ICON) end
                end
            else
                local hh = min(FLOWUP, (list[b] + pv.over[b]) / scale * FLOWUP)
                local top = min(mid + hh + 1 + LABELH, mid + FLOWUP + 1)
                if Tag(ROW_UP, text, cx, top, "text.good", "CENTER") then shown = shown + 1 end
            end
        end
    end
end
local function DrawFlow(pv, y)
    local scale = Scale(pv)
    local mid = y - FLOWUP
    local bw = pv.bin * xScale
    local barW = max(1, floor(bw) - 1)
    Tex(xLeft, mid, floor(xRight - xLeft), 1, "text.muted", 0.35)
    local big = pv.hpMax * BIG_SHARE
    for b = 1, pv.n do
        local x = floor(XOf(pv.from + (b - 1) * pv.bin)) + 1
        local hh = min(FLOWUP, pv.heal[b] / scale * FLOWUP)
        local oh = min(FLOWUP - hh, pv.over[b] / scale * FLOWUP)
        if hh >= 1 then Tex(x, floor(mid + hh), barW, floor(hh), "sem.lane.healed") end
        if oh >= 1 then Tex(x, floor(mid + hh + oh), barW, floor(oh), "sem.lane.healed", 0.3) end
        local dh = min(FLOWDN, pv.dmg[b] / scale * FLOWDN)
        local ah = min(FLOWDN - dh, pv.abs[b] / scale * FLOWDN)
        local token = KillBin(pv, b) and "sem.death" or (pv.dmg[b] >= big and big > 0 and "text.bad" or "sem.lane.taken")
        if dh >= 1 then Tex(x, mid - 1, barW, floor(dh), token) end
        if ah >= 1 then Tex(x, floor(mid - 1 - dh), barW, floor(ah), "sem.lane.taken", 0.3) end
        if KillBin(pv, b) then
            Icon(pv.kbId, x + floor((barW - ICON) / 2), mid - 1, ICON)
        end
    end
    if pv.kbT then KillTag(pv, mid) end
    FlowNumbers(pv, mid, scale)
    return mid - FLOWDN - GAP
end
local function Pct(v)
    return format("%d%%", floor(v * 100 + 0.5))
end
local function DrawHp(pv, y)
    Tex(xLeft, y, floor(xRight - xLeft), HPH, "surface.alt")
    local n = #pv.hpT
    if n == 0 then
        Tag(ROW_HP, ns.T("prev.hp.none"), (xLeft + xRight) / 2, y - 2, "tip.dim", "CENTER", true, true)
        return y - HPH - GAP
    end
    for k = 1, n do
        local pct = pv.hpV[k]
        local x0 = floor(XOf(pv.hpT[k]))
        local x1 = k < n and floor(XOf(pv.hpT[k + 1])) or floor(xRight)
        if x1 > x0 then
            if pct <= 0 then
                Tex(x0, y - HPH + 2, x1 - x0, 2, "sem.death")
            else
                local h = max(1, floor(pct * HPH))
                Tex(x0, y - HPH + h, x1 - x0, h, pct < LOW_HP and "text.warn" or "sem.lane.hp", 0.85)
            end
        end
    end
    if pv.hpStart then Tag(ROW_HP, Pct(pv.hpStart), xLeft + 2, y - 2, "text.primary", "LEFT", true) end
    if pv.hpAt then
        local ax = floor(XOf(pv.at))
        if not Tag(ROW_HP, Pct(pv.hpAt), ax - 2, y - 2, "text.primary", "RIGHT") then
            Tag(ROW_HP, Pct(pv.hpAt), ax + 2, y - 2, "text.primary", "LEFT")
        end
    end
    return y - HPH - GAP
end
local function Sec(v, unit)
    if v == 0 then return "0" end
    return format(ns.T(unit and "prev.axis" or "prev.axis.bare"), v)
end
local function Tick(pv, y, v, force)
    local x = floor(XOf(pv.at + v))
    local justify = v == -pv.before and "LEFT" or (v == pv.after and "RIGHT" or "CENTER")
    if Tag(ROW_AXIS, Sec(v, v == -pv.before), x, y - 6, "tip.dim", justify, force, true) then Tex(x, y - 4, 1, 3, "surface.edge") end
end
local function DrawAxis(pv, y)
    Tex(xLeft, y - 4, floor(xRight - xLeft), 1, "surface.edge")
    for k = 1, #pv.ownT do
        Tex(floor(XOf(pv.ownT[k])), y - 1, 1, 3, "text.muted", 0.8)
    end
    Tick(pv, y, 0, true)
    Tick(pv, y, -pv.before)
    Tick(pv, y, pv.after)
    for v = -pv.before + 1, pv.after - 1 do
        if v ~= 0 and v % TICK == 0 then Tick(pv, y, v) end
    end
    for k = 1, #pv.defT do
        Icon(pv.defId[k], floor(XOf(pv.defT[k]) - DEFICON / 2), y + 3, DEFICON)
    end
    return y - AXISH - 4
end
local function MapPiece(path, x, y, w, h, token, a, layer)
    if usedMap >= MAPTEXMAX or w <= 0 or h <= 0 then return nil end
    usedMap = usedMap + 1
    local t = mapPool[usedMap]
    if not t then
        t = mapBox:CreateTexture(nil, layer)
        mapPool[usedMap] = t
    end
    t:SetDrawLayer(layer)
    local r, g, b, ca = Rgba(token)
    if path then
        t:SetTexture(path)
        t:SetTexCoord(0, 1, 0, 1)
        t:SetVertexColor(r, g, b, a or ca)
    else
        t:SetTexture(r, g, b, a or ca)
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", mapBox, "TOPLEFT", x, -y)
    t:SetWidth(w)
    t:SetHeight(h)
    t:Show()
    return t
end
local function Spot(x, y)
    local sx, sy, k = Replay.Project(cam, x, y)
    if k <= 0 then return nil, nil end
    local px, py = MAP / 2 + sx, MAP / 2 + sy
    if px < 0 or px > MAP or py < 0 or py > MAP then return nil, nil end
    return px, py
end
local function Dot(path, x, y, size, token, a, layer)
    local cx, cy = Spot(x, y)
    if not cx then return nil end
    return MapPiece(path, floor(cx - size / 2 + 0.5), floor(cy - size / 2 + 0.5), size, size, token, a, layer)
end
local function DrawTrail(pv, m)
    local n = #m.trX
    local left = TRAIL_DOTS
    local span = max(0.1, pv.at - pv.from)
    local lastX, lastY
    for k = n, 1, -1 do
        local cx, cy = Spot(m.trX[k], m.trY[k])
        if cx and left > 0 then
            local age = min(1, max(0, (m.trT[k] - pv.from) / span))
            local a = TRAIL_FADE + (1 - TRAIL_FADE) * age
            local steps = 1
            if lastX then
                local dist = math.sqrt((lastX - cx) ^ 2 + (lastY - cy) ^ 2)
                steps = max(1, ceil(dist / TRAIL_STEP))
            end
            for j = steps, 1, -1 do
                if left > 0 then
                    local f = lastX and (j - 1) / steps or 0
                    local x = cx + ((lastX or cx) - cx) * f
                    local y = cy + ((lastY or cy) - cy) * f
                    if j == 1 or not lastX then
                        MapPiece(CIRCLE, floor(x - TRAIL_DOT / 2 + 0.5), floor(y - TRAIL_DOT / 2 + 0.5), TRAIL_DOT, TRAIL_DOT, "sem.pick", a, "ARTWORK")
                    else
                        MapPiece(CIRCLE, floor(x - 1 + 0.5), floor(y - 1 + 0.5), 2, 2, "sem.pick", a * 0.7, "ARTWORK")
                    end
                    left = left - 1
                end
            end
            lastX, lastY = cx, cy
        end
    end
end
local function DrawMarks(pv, m)
    if m.bossX then
        Dot(CIRCLE, m.bossX, m.bossY, BOSS_RING, "progress.ring", nil, "ARTWORK")
        local t = Dot(RAID_ICONS, m.bossX, m.bossY, BOSS_SKULL, "text.primary", nil, "OVERLAY")
        if t then t:SetTexCoord(0.75, 1, 0.25, 0.5) end
    end
    if m.endX then
        if pv.death then
            local t = Dot(RAID_ICONS, m.endX, m.endY, CROSS, "text.primary", nil, "OVERLAY")
            if t then t:SetTexCoord(0.5, 0.75, 0.25, 0.5) end
        else
            Dot(CIRCLE, m.endX, m.endY, ME_DOT, "sem.pick", nil, "OVERLAY")
        end
    end
    DrawTrail(pv, m)
    for k = 1, #m.nbX do
        local a = m.nbDead[k] and 0.35 or (m.nbStale[k] and 0.5 or 0.9)
        Dot(CIRCLE, m.nbX[k], m.nbY[k], NB_DOT, "sem.offline", a, "ARTWORK")
    end
    for k = 1, #m.addX do
        Dot(CIRCLE, m.addX[k], m.addY[k], ADD_DOT, "sem.lane.boss", nil, "ARTWORK")
    end
end
local function HasSpots(m)
    return m ~= nil and not m.none and (#m.trX > 0 or #m.nbX > 0 or m.endX ~= nil)
end
local function MapNote(m)
    if not m then return ns.T("prev.map.wait") end
    if m.note then return ns.T("prev.map.note." .. m.note) end
    if m.away then return format(ns.T("prev.map.away"), m.away) end
    if m.lost then
        local sec = max(0, floor(m.lost))
        return format(ns.T("prev.map.lost"), floor(sec / 60), sec % 60)
    end
    if not HasSpots(m) then return ns.T("prev.map.none") end
    return ""
end
local function Angle()
    local db = ns.GetDB and ns.GetDB()
    local iso = type(db) == "table" and type(db.settings) == "table" and db.settings.iso
    return type(iso) == "table" and tonumber(iso.angle) or ISO_ANGLE
end
local function DrawRoom(room)
    local path = ROOM_PATH .. room.tex
    local n = min(STRIPMAX, Replay.Strips(cam, room, stripData))
    for k = 1, n do
        local tex, d = mapStrips[k], stripData[k]
        if not tex:SetTexture(path) then
            usedStrips = 0
            return false
        end
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", mapBox, "TOPLEFT", MAP / 2 + d.l, -(MAP / 2 + d.t))
        tex:SetWidth(d.w)
        tex:SetHeight(d.h)
        tex:SetTexCoord(d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])
        tex:Show()
    end
    usedStrips = n
    return true
end
local function DrawGrid(m)
    for i = 1, #(m.gx or {}) do
        if usedMap >= MAPTEXMAX / 2 then return end
        Dot(CIRCLE, m.gx[i], m.gy[i], GRID_DOT, "sem.rep.tick", nil, "BORDER")
    end
end
local function DrawMap(pv, x0, y0)
    local p0 = debugprofilestop()
    usedMap, usedStrips = 0, 0
    local m = pv.map
    local shown = HasSpots(m)
    if shown then
        mapBox:ClearAllPoints()
        mapBox:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y0)
        mapBg:SetTexture(Rgba("surface.page"))
        cam.angle, cam.cx, cam.cy, cam.r = Angle(), m.cx, m.cy, m.half
        cam.zoom = MAP / (2 * max(1, m.half))
        Replay.Aim(cam)
        if not (m.room and DrawRoom(m.room)) then DrawGrid(m) end
        DrawMarks(pv, m)
    end
    for i = usedStrips + 1, STRIPMAX do mapStrips[i]:Hide() end
    for i = usedMap + 1, #mapPool do mapPool[i]:Hide() end
    if shown then mapBox:Show() else mapBox:Hide() end
    local ms = debugprofilestop() - p0
    View.lastMapMs = ms
    if ns.Prof.on then ns.Prof.Add("prev.map", ms, usedMap + usedStrips) end
    return shown
end
local function SumLine(pv)
    local out = format(ns.T("prev.sum"), Short(pv.dmgSum), pv.sumSpan, Short(pv.healSum))
    if pv.death then
        if pv.kbT then
            local src = pv.kbSrc and pv.kbSrc ~= pv.who and format(ns.T("prev.from"), pv.kbSrc) or ""
            out = out .. " " .. format(ns.T("prev.kill"), tostring(pv.kbLabel), src, Short(pv.kbV), Short(pv.kbOver))
        else
            out = out .. " " .. ns.T("prev.nokill")
        end
        if pv.lockLabel then
            out = out .. " " .. format(ns.T("prev.lock"), pv.lockLabel)
        elseif #pv.defT == 0 then
            out = out .. " " .. ns.T("prev.nodef")
        end
    end
    local note = MapNote(pv.map)
    if note ~= "" then out = out .. " " .. note end
    return out
end
local function Draw(pv)
    usedTex, usedIcon, usedFont, spanN, usedTag = 0, 0, 0, 0, 0
    xLeft = PAD + GUTTER
    xRight = TLW - PAD
    xFrom = pv.from
    xScale = (xRight - xLeft) / max(0.1, pv.to - pv.from)
    local top = -PAD
    local y = DrawBoss(pv, top)
    y = DrawAuras(pv, y)
    y = DrawFlow(pv, y)
    local hpBottom = y - HPH
    y = DrawHp(pv, y)
    y = DrawAxis(pv, y)
    anchorLine:ClearAllPoints()
    anchorLine:SetPoint("TOPLEFT", frame, "TOPLEFT", floor(XOf(pv.at)), top)
    anchorLine:SetHeight(top - hpBottom)
    local r, g, b, a = Rgba(pv.death and "sem.death" or "sem.cursor")
    anchorLine:SetTexture(r, g, b, a)
    local room = TLW - PAD * 2
    sumText:SetWidth(0)
    sumText:SetText(SumLine(pv))
    local sw, one = sumText:GetStringWidth() or 0, sumText:GetHeight() or 0
    sumText:SetWidth(room)
    Kit.Text(sumText, "tip.body")
    sumText:ClearAllPoints()
    sumText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    y = y - max(sumText:GetHeight() or 0, one * ceil(sw / room), 12)
    local total = TLW
    if DrawMap(pv, TLW - PAD + MAPGAP, -PAD) then
        total = TLW + MAPGAP + MAP
        y = min(y, -PAD - MAP)
    end
    for i = usedTex + 1, #texPool do texPool[i]:Hide() end
    for i = usedIcon + 1, #iconPool do iconPool[i]:Hide() end
    for i = usedFont + 1, #fontPool do fontPool[i]:Hide() end
    for i = usedTag + 1, #tagFs do
        tagFs[i]:Hide()
        tagBg[i]:Hide()
    end
    frame:SetWidth(total)
    frame:SetHeight(-y + PAD)
end
local function Place(owner)
    local Tip = ns.Tip
    if Tip and Tip.Around then return Tip.Around(owner, frame) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -STACK)
end
local function Present(w)
    local p0 = debugprofilestop()
    Draw(w.pv)
    Place(w.owner)
    frame:Show()
    w.drawn = true
    local ms = debugprofilestop() - p0
    View.lastMs, View.lastUsed = ms, usedTex + usedIcon + usedFont + usedTag * 2 + usedMap + usedStrips
    if ns.Prof.on then ns.Prof.Add("prev.draw", ms, View.lastUsed) end
end
local function Pump()
    local w = want
    if not w or w.drawn then
        pump:Hide()
        return
    end
    local now = GetTime()
    if now >= w.showAt and w.pv and (w.mapped or now >= w.showAt + MAP_WAIT) then
        pump:Hide()
        Present(w)
    end
end
function View.Enter(mark)
    local fight, at = mark.fight, mark.at
    local tile = mark:GetParent()
    local who = tile and tile.who
    if not (mark.preview and fight and at and who and fight.players and fight.players[who]) then return end
    if not frame then
        Build()
        pump:SetScript("OnUpdate", Pump)
    end
    local anchor, death = DP.Anchor(fight, who, at)
    local w = { owner = mark, who = who, at = anchor, showAt = GetTime() + DELAY }
    want = w
    frame:Hide()
    pump:Show()
    DP.Request(fight, who, anchor, death, function(pv)
        if not (want == w and pv and pv.who == who and pv.at == anchor) then return end
        w.pv = pv
        DP.Map(fight, pv, function()
            if want ~= w then return end
            w.mapped = true
            if w.drawn then Present(w) end
        end)
    end)
end
function View.Leave()
    want = nil
    if frame then
        frame:Hide()
        pump:Hide()
    end
end
if ns.SummaryView and ns.SummaryView.Show then
    hooksecurefunc(ns.SummaryView, "Show", function(f)
        if f then DP.Warm(f) end
    end)
end
