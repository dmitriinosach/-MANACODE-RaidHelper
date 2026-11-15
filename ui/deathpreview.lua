local ADDON, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local Kit = ns.Kit
local K = {}
K.PAD = 5
K.GUTTER = 15
K.TLW = 236
K.BOSSH = 15
K.AURAH = 13
K.FLOWUP = 16
K.FLOWDN = 24
K.HPH = 14
K.AXISH = 12
K.GAP = 3
K.ICON = 13
K.AURAICON = 12
K.DEFICON = 14
K.LABELH = 10
K.LABEL_SEP = 3
K.SUM_GAP = 4
K.STACK = 3
K.TEXMAX = 170
K.ICONMAX = 18
K.FONTMAX = 24
K.TAGMAX = 12
K.TAG_ALPHA = 0.8
K.BIG_SHARE = 0.2
K.FLOW_SHARE = 0.4
K.NUM_SHARE = 0.12
K.NUM_FALLBACK = 0.25
K.DMG_LABELS = 3
K.HEAL_LABELS = 2
K.LOW_HP = 0.35
K.TICK = 5
K.FONT_SIZE = 9
K.ROW_UP, K.ROW_DN, K.ROW_AXIS, K.ROW_HP, K.ROW_KILL = 1, 2, 3, 4, 5
K.MAP = 104
K.MAPGAP = 5
K.MAPTEXMAX = 120
K.NB_DOT = 4
K.ADD_DOT = 5
K.ME_DOT = 7
K.TRAIL_DOT = 3
K.TRAIL_STEP = 3
K.TRAIL_DOTS = 48
K.TRAIL_FADE = 0.2
K.BOSS_RING = 13
K.BOSS_SKULL = 10
K.CROSS = 10
K.STRIPMAX = 40
K.GRID_DOT = 2
K.ISO_ANGLE = math.pi / 4
K.NOTE_PAD = 3
K.LOAD_DOTS = 3
K.LOAD_DOT = 5
K.LOAD_GAP = 4
K.LOAD_PERIOD = 0.9
K.LOAD_LOW = 0.25
K.ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
K.CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
K.RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local View = {}
ns.DeathPreviewView = View
local DP = ns.DeathPreview
local Replay = ns.Replay
local Short = ns.Short
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
local mapBox, mapBg, noteLayer, noteBg, noteFs
local loadGraph, loadMap = {}, {}
local mapStrips, stripData, mapPool = {}, {}, {}
local usedMap, usedStrips = 0, 0
local cam = { angle = K.ISO_ANGLE, tilt = 1, persp = 0, zoom = 1, lift = 0, r = 1, a = 0, cx = 0, cy = 0,
              w = K.MAP, h = K.MAP, c = 1, s = 0 }
local function Build()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(Kit.TIP_INNER_LEVEL or 20)
    frame:SetClampedToScreen(true)
    Kit.Skin(frame, "tip")
    frame:Hide()
    font = CreateFont("HTP_FailWatchPrevFont")
    font:SetFontObject(GameFontHighlightSmall)
    local path, _, flags = GameFontHighlightSmall:GetFont()
    if path then font:SetFont(path, K.FONT_SIZE, flags or "") end
    probe = frame:CreateFontString(nil, "OVERLAY")
    probe:SetFontObject(font)
    probe:Hide()
    tagLayer = CreateFrame("Frame", nil, frame)
    tagLayer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    tagLayer:SetWidth(1)
    tagLayer:SetHeight(1)
    anchorLine = frame:CreateTexture(nil, "OVERLAY")
    anchorLine:SetWidth(1)
    sumText = Kit.Str(frame, "GameFontHighlightSmall")
    sumText:SetJustifyH("LEFT")
    sumText:SetPoint("TOPLEFT", K.PAD, 0)
    pump = CreateFrame("Frame")
    pump:Hide()
    mapBox = CreateFrame("Frame", nil, frame)
    mapBox:SetWidth(K.MAP)
    mapBox:SetHeight(K.MAP)
    mapBg = mapBox:CreateTexture(nil, "BACKGROUND")
    mapBg:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 0, 0)
    mapBg:SetWidth(K.MAP)
    mapBg:SetHeight(K.MAP)
    for i = 1, K.STRIPMAX do
        mapStrips[i] = mapBox:CreateTexture(nil, "BORDER")
        mapStrips[i]:Hide()
    end
    noteLayer = CreateFrame("Frame", nil, mapBox)
    noteLayer:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 0, 0)
    noteLayer:SetWidth(K.MAP)
    noteLayer:SetHeight(K.MAP)
    noteBg = noteLayer:CreateTexture(nil, "BACKGROUND")
    noteFs = noteLayer:CreateFontString(nil, "OVERLAY")
    noteFs:SetFontObject(font)
    noteFs:SetJustifyH("CENTER")
    noteFs:SetWidth(K.MAP - K.NOTE_PAD * 2)
    for i = 1, K.LOAD_DOTS do
        loadGraph[i] = frame:CreateTexture(nil, "OVERLAY")
        loadMap[i] = noteLayer:CreateTexture(nil, "OVERLAY")
    end
    for _, list in ipairs({ loadGraph, loadMap }) do
        for i = 1, K.LOAD_DOTS do
            local t = list[i]
            t:SetTexture(K.CIRCLE)
            t:SetWidth(K.LOAD_DOT)
            t:SetHeight(K.LOAD_DOT)
            t:Hide()
        end
    end
    mapBox:Hide()
end
local Rgba = Kit.Color
local function Tex(x, y, w, h, token, a)
    if usedTex >= K.TEXMAX or w <= 0 or h <= 0 then return nil end
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
    if not path or usedIcon >= K.ICONMAX then return end
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
    if usedFont >= K.FONTMAX then return nil end
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
        if spanRow[k] == row and l < spanR[k] + K.LABEL_SEP and r > spanL[k] - K.LABEL_SEP then return false end
    end
    return true
end
local function Take(row, l, r)
    spanN = spanN + 1
    spanL[spanN], spanR[spanN], spanRow[spanN] = l, r, row
end
local function Boxed(text, l, y, w, token)
    if usedTag >= K.TAGMAX then return end
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
    bg:SetTexture(r, g, b, K.TAG_ALPHA)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", tagLayer, "TOPLEFT", floor(l) - 1, y)
    bg:SetWidth(w + 2)
    bg:SetHeight(K.LABELH)
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
    if l < K.PAD then l, x, justify = K.PAD, K.PAD, "LEFT" end
    if l + w > xRight + K.PAD then l, x, justify = xRight + K.PAD - w, xRight + K.PAD, "RIGHT" end
    if not force and not Free(row, l, l + w) then return false end
    Take(row, l, l + w)
    if plain then Label(text, x, y, token, justify, w) else Boxed(text, l, y, w, token) end
    return true
end
local function XOf(t)
    return xLeft + (t - xFrom) * xScale
end
local boxL, boxR, boxTop, boxBot = {}, {}, {}, {}
local boxN = 0
local function Reserve(l, top, size)
    boxN = boxN + 1
    boxL[boxN], boxR[boxN], boxTop[boxN], boxBot[boxN] = l, l + size, top, top - size
end
local function OnIcon(l, r, top)
    for k = 1, boxN do
        if l < boxR[k] and r > boxL[k] and top > boxBot[k] and top - K.LABELH < boxTop[k] then return true end
    end
    return false
end
local function DrawBoss(pv, y)
    if #pv.castT == 0 then return y end
    local lastIcon = -K.ICON
    for k = 1, #pv.castT do
        local x = floor(XOf(pv.castT[k]))
        Tex(x, y, 1, K.BOSSH, "sem.lane.boss")
        if x - lastIcon > K.ICON + 1 then
            Icon(pv.castId[k], x + 1, y - 1, K.ICON)
            lastIcon = x
        end
    end
    return y - K.BOSSH - K.GAP
end
local function DrawAuras(pv, y)
    local rows = #pv.rows
    if rows == 0 then return y end
    for k = 1, rows do
        local row = pv.rows[k]
        Icon(pv.auraId[row], K.PAD, y, K.AURAICON)
        for s = 1, #pv.spanAura do
            if pv.spanAura[s] == row then
                local x0 = XOf(pv.spanFrom[s])
                local x1 = XOf(pv.spanTo[s])
                local stack = pv.spanStack[s]
                Tex(floor(x0), y - 2, max(1, floor(x1 - x0)), K.AURAH - 4, "sem.lane.auras", min(0.95, 0.45 + stack * 0.08))
                if stack > 1 and x1 - x0 >= 8 then Label(tostring(stack), x0 + 2, y, "text.primary") end
            end
        end
        y = y - K.AURAH
    end
    if pv.extra > 0 then
        Label(format(ns.T("prev.more"), pv.extra), xRight, y + K.AURAH, "tip.dim", "RIGHT")
    end
    return y - K.GAP
end
local function Scale(pv)
    if pv.hpMax > 0 then return pv.hpMax * K.FLOW_SHARE end
    local top = 1
    for b = 1, pv.n do top = max(top, pv.dmg[b] + pv.abs[b], pv.heal[b] + pv.over[b]) end
    return top
end
local function KillBin(pv, b)
    return pv.kbT ~= nil and DP.BinOf(pv, pv.kbT) == b
end
local function BigIn(pv, b)
    for k = 1, #pv.bigV do
        if DP.BinOf(pv, pv.bigT[k]) == b and pv.bigV[k] >= pv.hpMax * K.BIG_SHARE then return pv.bigId[k] end
    end
    return nil
end
local function KillTag(pv, mid)
    local x = floor(XOf(pv.at)) + 2
    Tag(K.ROW_KILL, Short(pv.kbV), x, mid - 2, "text.bad", "LEFT", true)
    if pv.kbOver > 0 then
        Tag(K.ROW_KILL, format(ns.T("prev.kb"), Short(pv.kbOver)), x, mid - 2 - K.LABELH, "text.warn", "LEFT", true)
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
    local least = pv.hpMax > 0 and pv.hpMax * K.NUM_SHARE or scale * K.NUM_FALLBACK
    local floorY = mid - K.FLOWDN - K.GAP + K.LABELH
    for b = 1, pv.n do
        if pv.dmg[b] >= least and BigIn(pv, b) then
            Reserve(floor(XOf(pv.from + (b - 0.5) * pv.bin) - K.ICON / 2), mid - 1, K.ICON)
        end
    end
    for pass = 1, 2 do
        for b = 1, pv.n do picked[b] = nil end
        if pass == 1 and pv.kbT then picked[DP.BinOf(pv, pv.kbT)] = true end
        local list = pass == 1 and pv.dmg or pv.heal
        local shown = 0
        local limit = pass == 1 and K.DMG_LABELS or K.HEAL_LABELS
        for _ = 1, pv.n do
            if shown >= limit then break end
            local b = Top(pv, list, least)
            if not b then break end
            picked[b] = true
            local cx = XOf(pv.from + (b - 0.5) * pv.bin)
            local text = Short(list[b])
            if pass == 1 then
                local dh = min(K.FLOWDN, list[b] / scale * K.FLOWDN)
                local icon = BigIn(pv, b)
                local top = max(mid - 2 - dh, floorY)
                if icon then top = min(top, mid - K.ICON - 2) end
                local w = Measure(text)
                local l = max(K.PAD, min(cx - w / 2, xRight + K.PAD - w))
                if OnIcon(l, l + w, top) then top = mid - K.ICON - 2 end
                if not OnIcon(l, l + w, top) and Tag(K.ROW_DN, text, cx, top, "text.bad", "CENTER") then
                    shown = shown + 1
                    if icon then Icon(icon, floor(cx - K.ICON / 2), mid - 1, K.ICON) end
                end
            else
                local hh = min(K.FLOWUP, (list[b] + pv.over[b]) / scale * K.FLOWUP)
                local top = min(mid + hh + 1 + K.LABELH, mid + K.FLOWUP + 1)
                if Tag(K.ROW_UP, text, cx, top, "text.good", "CENTER") then shown = shown + 1 end
            end
        end
    end
end
local function DrawFlow(pv, y)
    local scale = Scale(pv)
    local mid = y - K.FLOWUP
    local bw = pv.bin * xScale
    local barW = max(1, floor(bw) - 1)
    Tex(xLeft, mid, floor(xRight - xLeft), 1, "text.muted", 0.35)
    local big = pv.hpMax * K.BIG_SHARE
    for b = 1, pv.n do
        local x = floor(XOf(pv.from + (b - 1) * pv.bin)) + 1
        local hh = min(K.FLOWUP, pv.heal[b] / scale * K.FLOWUP)
        local oh = min(K.FLOWUP - hh, pv.over[b] / scale * K.FLOWUP)
        if hh >= 1 then Tex(x, floor(mid + hh), barW, floor(hh), "sem.lane.healed") end
        if oh >= 1 then Tex(x, floor(mid + hh + oh), barW, floor(oh), "sem.lane.healed", 0.3) end
        local dh = min(K.FLOWDN, pv.dmg[b] / scale * K.FLOWDN)
        local ah = min(K.FLOWDN - dh, pv.abs[b] / scale * K.FLOWDN)
        local token = KillBin(pv, b) and "sem.death" or (pv.dmg[b] >= big and big > 0 and "text.bad" or "sem.lane.taken")
        if dh >= 1 then Tex(x, mid - 1, barW, floor(dh), token) end
        if ah >= 1 then Tex(x, floor(mid - 1 - dh), barW, floor(ah), "sem.lane.taken", 0.3) end
        if KillBin(pv, b) then
            Icon(pv.kbId, x + floor((barW - K.ICON) / 2), mid - 1, K.ICON)
            Reserve(x + floor((barW - K.ICON) / 2), mid - 1, K.ICON)
        end
    end
    if pv.kbT then KillTag(pv, mid) end
    FlowNumbers(pv, mid, scale)
    return mid - K.FLOWDN - K.GAP
end
local function Pct(v)
    return format("%d%%", floor(v * 100 + 0.5))
end
local function DrawHp(pv, y)
    Tex(xLeft, y, floor(xRight - xLeft), K.HPH, "surface.alt")
    local n = #pv.hpT
    if n == 0 then
        Tag(K.ROW_HP, ns.T("prev.hp.none"), (xLeft + xRight) / 2, y - 2, "tip.dim", "CENTER", true, true)
        return y - K.HPH - K.GAP
    end
    for k = 1, n do
        local pct = pv.hpV[k]
        local x0 = floor(XOf(pv.hpT[k]))
        local x1 = k < n and floor(XOf(pv.hpT[k + 1])) or floor(xRight)
        if x1 > x0 then
            if pct <= 0 then
                Tex(x0, y - K.HPH + 2, x1 - x0, 2, "sem.death")
            else
                local h = max(1, floor(pct * K.HPH))
                Tex(x0, y - K.HPH + h, x1 - x0, h, pct < K.LOW_HP and "text.warn" or "sem.lane.hp", 0.85)
            end
        end
    end
    if pv.hpStart then Tag(K.ROW_HP, Pct(pv.hpStart), xLeft + 2, y - 2, "text.primary", "LEFT", true) end
    if pv.hpAt then
        local ax = floor(XOf(pv.at))
        if not Tag(K.ROW_HP, Pct(pv.hpAt), ax - 2, y - 2, "text.primary", "RIGHT") then
            Tag(K.ROW_HP, Pct(pv.hpAt), ax + 2, y - 2, "text.primary", "LEFT")
        end
    end
    return y - K.HPH - K.GAP
end
local function Sec(v, unit)
    if v == 0 then return "0" end
    return format(ns.T(unit and "prev.axis" or "prev.axis.bare"), v)
end
local function Tick(pv, y, v, force)
    local x = floor(XOf(pv.at + v))
    local justify = v == -pv.before and "LEFT" or (v == pv.after and "RIGHT" or "CENTER")
    if Tag(K.ROW_AXIS, Sec(v, v == -pv.before), x, y - 6, "tip.dim", justify, force, true) then Tex(x, y - 4, 1, 3, "surface.edge") end
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
        if v ~= 0 and v % K.TICK == 0 then Tick(pv, y, v) end
    end
    for k = 1, #pv.defT do
        Icon(pv.defId[k], floor(XOf(pv.defT[k]) - K.DEFICON / 2), y + 3, K.DEFICON)
    end
    return y - K.AXISH - 4
end
local function MapPiece(path, x, y, w, h, token, a, layer)
    if usedMap >= K.MAPTEXMAX or w <= 0 or h <= 0 then return nil end
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
    local px, py = K.MAP / 2 + sx, K.MAP / 2 + sy
    if px < 0 or px > K.MAP or py < 0 or py > K.MAP then return nil, nil end
    return px, py
end
local function Dot(path, x, y, size, token, a, layer)
    local cx, cy = Spot(x, y)
    if not cx then return nil end
    return MapPiece(path, floor(cx - size / 2 + 0.5), floor(cy - size / 2 + 0.5), size, size, token, a, layer)
end
local function DrawTrail(pv, m)
    local n = #m.trX
    local left = K.TRAIL_DOTS
    local span = max(0.1, pv.at - pv.from)
    local lastX, lastY
    for k = n, 1, -1 do
        local cx, cy = Spot(m.trX[k], m.trY[k])
        if cx and left > 0 then
            local age = min(1, max(0, (m.trT[k] - pv.from) / span))
            local a = K.TRAIL_FADE + (1 - K.TRAIL_FADE) * age
            local steps = 1
            if lastX then
                local dist = math.sqrt((lastX - cx) ^ 2 + (lastY - cy) ^ 2)
                steps = max(1, ceil(dist / K.TRAIL_STEP))
            end
            for j = steps, 1, -1 do
                if left > 0 then
                    local f = lastX and (j - 1) / steps or 0
                    local x = cx + ((lastX or cx) - cx) * f
                    local y = cy + ((lastY or cy) - cy) * f
                    if j == 1 or not lastX then
                        MapPiece(K.CIRCLE, floor(x - K.TRAIL_DOT / 2 + 0.5), floor(y - K.TRAIL_DOT / 2 + 0.5), K.TRAIL_DOT, K.TRAIL_DOT, "sem.pick", a, "ARTWORK")
                    else
                        MapPiece(K.CIRCLE, floor(x - 1 + 0.5), floor(y - 1 + 0.5), 2, 2, "sem.pick", a * 0.7, "ARTWORK")
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
        Dot(K.CIRCLE, m.bossX, m.bossY, K.BOSS_RING, "progress.ring", nil, "ARTWORK")
        local t = Dot(K.RAID_ICONS, m.bossX, m.bossY, K.BOSS_SKULL, "text.primary", nil, "OVERLAY")
        if t then t:SetTexCoord(0.75, 1, 0.25, 0.5) end
    end
    if m.endX then
        if pv.death then
            local t = Dot(K.RAID_ICONS, m.endX, m.endY, K.CROSS, "text.primary", nil, "OVERLAY")
            if t then t:SetTexCoord(0.5, 0.75, 0.25, 0.5) end
        else
            Dot(K.CIRCLE, m.endX, m.endY, K.ME_DOT, "sem.pick", nil, "OVERLAY")
        end
    end
    DrawTrail(pv, m)
    for k = 1, #m.nbX do
        local a = m.nbDead[k] and 0.35 or (m.nbStale[k] and 0.5 or 0.9)
        Dot(K.CIRCLE, m.nbX[k], m.nbY[k], K.NB_DOT, "sem.offline", a, "ARTWORK")
    end
    for k = 1, #m.addX do
        Dot(K.CIRCLE, m.addX[k], m.addY[k], K.ADD_DOT, "sem.lane.boss", nil, "ARTWORK")
    end
end
local function HasSpots(m)
    return m ~= nil and not m.none and (#m.trX > 0 or #m.nbX > 0 or m.endX ~= nil)
end
local function MapNote(m)
    if not m or m.none then return ns.T("prev.map.none") end
    if m.note then return ns.T("prev.map.note." .. m.note) end
    if m.away then return format(ns.T("prev.map.away"), m.away) end
    if m.lost then
        local sec = max(0, floor(m.lost))
        return format(ns.T("prev.map.lost"), floor(sec / 60), sec % 60)
    end
    if not HasSpots(m) then return ns.T("prev.map.none") end
    return ""
end
local function Angle(room)
    local db = ns.GetDB and ns.GetDB()
    local iso = type(db) == "table" and type(db.settings) == "table" and db.settings.iso
    local views = type(iso) == "table" and iso.views
    local v = room and room.tex and type(views) == "table" and views[room.tex]
    return type(v) == "table" and tonumber(v.a) or K.ISO_ANGLE
end
local function DrawRoom(room)
    local path = K.ROOM_PATH .. room.tex
    local n = min(K.STRIPMAX, Replay.Strips(cam, room, stripData))
    for k = 1, n do
        local tex, d = mapStrips[k], stripData[k]
        if not tex:SetTexture(path) then
            usedStrips = 0
            return false
        end
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", mapBox, "TOPLEFT", K.MAP / 2 + d.l, -(K.MAP / 2 + d.t))
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
        if usedMap >= K.MAPTEXMAX / 2 then return end
        Dot(K.CIRCLE, m.gx[i], m.gy[i], K.GRID_DOT, "sem.rep.tick", nil, "BORDER")
    end
end
local function MapText(text, spots)
    if text == "" then
        noteFs:Hide()
        noteBg:Hide()
        return
    end
    noteFs:SetText(text)
    noteFs:SetTextColor(Rgba("tip.dim"))
    local h = noteFs:GetHeight() or K.LABELH
    noteFs:ClearAllPoints()
    if spots then
        noteFs:SetPoint("BOTTOMLEFT", noteLayer, "BOTTOMLEFT", K.NOTE_PAD, K.NOTE_PAD)
        local r, g, b = Rgba("tip.bg")
        noteBg:SetTexture(r, g, b, K.TAG_ALPHA)
        noteBg:ClearAllPoints()
        noteBg:SetPoint("BOTTOMLEFT", noteLayer, "BOTTOMLEFT", 0, 0)
        noteBg:SetWidth(K.MAP)
        noteBg:SetHeight(h + K.NOTE_PAD * 2)
        noteBg:Show()
    else
        noteFs:SetPoint("LEFT", noteLayer, "LEFT", K.NOTE_PAD, 0)
        noteBg:Hide()
    end
    noteFs:Show()
end
local function DrawMap(pv, x0, y0)
    local p0 = debugprofilestop()
    usedMap, usedStrips = 0, 0
    local m = pv and pv.map
    local shown = HasSpots(m)
    mapBox:ClearAllPoints()
    mapBox:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y0)
    mapBg:SetTexture(Rgba("surface.page"))
    if shown then
        cam.angle, cam.cx, cam.cy, cam.r = Angle(m.room), m.cx, m.cy, m.half
        cam.zoom = K.MAP / (2 * max(1, m.half))
        Replay.Aim(cam)
        if not (m.room and DrawRoom(m.room)) then DrawGrid(m) end
        DrawMarks(pv, m)
    end
    for i = usedStrips + 1, K.STRIPMAX do mapStrips[i]:Hide() end
    for i = usedMap + 1, #mapPool do mapPool[i]:Hide() end
    MapText(m and MapNote(m) or "", shown)
    mapBox:Show()
    local ms = debugprofilestop() - p0
    View.lastMapMs = ms
    View.lastAngle = shown and m.room and cam.angle or nil
    if ns.Prof.on then ns.Prof.Add("prev.map", ms, usedMap + usedStrips) end
end
local function SumLine(pv, caption, slot)
    local lines = {}
    if pv.death then
        local kill
        if pv.kbT then
            local src = pv.kbSrc and pv.kbSrc ~= pv.who and format(ns.T("prev.from"), pv.kbSrc) or ""
            kill = format(ns.T("prev.kill"), tostring(pv.kbLabel), src, Short(pv.kbV), Short(pv.kbOver))
        else
            kill = ns.T("prev.nokill")
        end
        if pv.lockLabel then
            kill = kill .. " " .. format(ns.T("prev.lock"), pv.lockLabel)
        elseif #pv.defT == 0 then
            kill = kill .. " " .. ns.T("prev.nodef")
        end
        lines[#lines + 1] = caption and (caption .. " - " .. kill) or kill
    end
    lines[#lines + 1] = format(ns.T("prev.sum"), Short(pv.dmgSum), pv.sumSpan, Short(pv.healSum))
    if not slot then lines[#lines + 1] = MapNote(pv.map) end
    return table.concat(lines, "\n"), #lines
end
local function LineH()
    sumText:SetWidth(0)
    sumText:SetText("0")
    return max(sumText:GetHeight() or 0, 1)
end
local function LoadHeight(death, slot)
    local lines = (death and 2 or 0) + 1 + (slot and 0 or 1)
    local h = K.PAD + K.BOSSH + K.GAP + DP.AURA_ROWS * K.AURAH + K.GAP + K.FLOWUP + K.FLOWDN + K.GAP + K.HPH + K.GAP + K.AXISH + 4
        + K.SUM_GAP + max(LineH() * lines, 12) + K.PAD
    if slot then h = max(h, K.PAD + K.MAP + K.PAD) end
    return h
end
local function DrawGraph(pv, caption, slot)
    xLeft = K.PAD + K.GUTTER
    xRight = K.TLW - K.PAD
    xFrom = pv.from
    xScale = (xRight - xLeft) / max(0.1, pv.to - pv.from)
    local top = -K.PAD
    local y = DrawBoss(pv, top)
    y = DrawAuras(pv, y)
    y = DrawFlow(pv, y)
    local hpBottom = y - K.HPH
    y = DrawHp(pv, y)
    y = DrawAxis(pv, y)
    anchorLine:ClearAllPoints()
    anchorLine:SetPoint("TOPLEFT", frame, "TOPLEFT", floor(XOf(pv.at)), top)
    anchorLine:SetHeight(top - hpBottom)
    local r, g, b, a = Rgba(pv.death and "sem.death" or "sem.cursor")
    anchorLine:SetTexture(r, g, b, a)
    anchorLine:Show()
    local room = K.TLW - K.PAD * 2
    local text, rows = SumLine(pv, caption, slot)
    sumText:SetWidth(0)
    sumText:SetText(text)
    local sw, one = sumText:GetStringWidth() or 0, sumText:GetHeight() or 0
    one = rows > 1 and one / rows or one
    sumText:SetWidth(room)
    Kit.Text(sumText, "text.secondary")
    sumText:ClearAllPoints()
    sumText:SetPoint("TOPLEFT", frame, "TOPLEFT", K.PAD, y - K.SUM_GAP)
    sumText:Show()
    return y - K.SUM_GAP - max(sumText:GetHeight() or 0, one * (ceil(sw / room) + rows - 1), 12)
end
local function Dots(list, on, parent, cx, cy)
    local r, g, b, a = Rgba("progress.fill")
    for i = 1, K.LOAD_DOTS do
        local t = list[i]
        if on then
            t:SetVertexColor(r, g, b, a)
            t:ClearAllPoints()
            t:SetPoint("CENTER", parent, "TOPLEFT", floor(cx + (i - (K.LOAD_DOTS + 1) / 2) * (K.LOAD_DOT + K.LOAD_GAP)), -floor(cy))
            t:Show()
        else
            t:Hide()
        end
    end
end
local function Pulse(now)
    local phase = now / K.LOAD_PERIOD
    for i = 1, K.LOAD_DOTS do
        local k = K.LOAD_LOW + (1 - K.LOAD_LOW) * (0.5 + 0.5 * math.cos((phase - i / K.LOAD_DOTS) * 2 * math.pi))
        loadGraph[i]:SetAlpha(k)
        loadMap[i]:SetAlpha(k)
    end
end
local function Draw(w)
    usedTex, usedIcon, usedFont, spanN, usedTag, boxN = 0, 0, 0, 0, 0, 0
    local pv = w.pv
    local y = -K.PAD
    if pv then
        y = DrawGraph(pv, w.caption, w.slot)
    else
        anchorLine:Hide()
        sumText:Hide()
    end
    local total = K.TLW
    if w.slot then
        DrawMap(pv, K.TLW - K.PAD + K.MAPGAP, -K.PAD)
        total = K.TLW + K.MAPGAP + K.MAP
        y = min(y, -K.PAD - K.MAP)
    else
        mapBox:Hide()
    end
    for i = usedTex + 1, #texPool do texPool[i]:Hide() end
    for i = usedIcon + 1, #iconPool do iconPool[i]:Hide() end
    for i = usedFont + 1, #fontPool do fontPool[i]:Hide() end
    for i = usedTag + 1, #tagFs do
        tagFs[i]:Hide()
        tagBg[i]:Hide()
    end
    local h = max(-y + K.PAD, w.h or 0)
    frame:SetWidth(total)
    frame:SetHeight(h)
    local mapWait = w.slot and not (pv and pv.map)
    Dots(loadGraph, not pv, frame, K.TLW / 2, h / 2)
    Dots(loadMap, mapWait, noteLayer, K.MAP / 2, K.MAP / 2)
    w.loading = not pv or mapWait
    if w.loading then
        Pulse(GetTime())
        View.loader = true
        pump:Show()
    end
    return total, h
end
local function Place(owner)
    local Tip = ns.Tip
    if Tip and Tip.Around then return Tip.Around(owner, frame) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -K.STACK)
end
local function Present(w)
    local p0 = debugprofilestop()
    local fw, fh = Draw(w)
    if fw ~= w.fw or fh ~= w.fh then
        Place(w.owner)
        w.fw, w.fh = fw, fh
        if not View.firstW then View.firstW, View.firstH = fw, fh end
    end
    frame:Show()
    View.done = not w.loading
    local ms = debugprofilestop() - p0
    View.lastMs, View.lastUsed = ms, usedTex + usedIcon + usedFont + usedTag * 2 + usedMap + usedStrips
    if ns.Prof.on then ns.Prof.Add("prev.draw", ms, View.lastUsed) end
end
local function Pump()
    local w = want
    if not (w and w.loading) then
        pump:Hide()
        return
    end
    Pulse(GetTime())
end
local function MapFor(w)
    if not (w.slot and w.pv and not w.pv.map) then return end
    DP.Map(w.fight, w.pv, function()
        if want == w and w.fw then Present(w) end
    end)
end
function View.Enter(mark)
    local fight, at = mark.fight, mark.at
    local tile = mark:GetParent()
    local who = mark.who or (tile and tile.who)
    if not (mark.preview and fight and at and who and fight.players and fight.players[who]) then return end
    if not frame then
        Build()
        pump:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", Pump))
    end
    local anchor, death = DP.Anchor(fight, who, at)
    local w = { owner = mark, fight = fight, who = who, at = anchor, slot = DP.HasMap(fight),
                pv = DP.Peek(fight, who, anchor) }
    if death and (fight.players[who] or 0) > 1 then w.caption = ns.Clock(max(0, anchor - fight.from)) end
    if not w.pv then w.h = LoadHeight(death, w.slot) end
    want = w
    View.firstW, View.firstH, View.loader, View.done = nil, nil, false, false
    frame:Hide()
    if w.pv then
        MapFor(w)
    else
        DP.Request(fight, who, anchor, death, function(pv)
            if not (want == w and pv and pv.who == who and pv.at == anchor) then return end
            w.pv = pv
            MapFor(w)
            if w.fw then Present(w) end
        end)
    end
    Present(w)
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
