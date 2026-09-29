local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local TILES = 12
local MapDraw = {}
ns.MapDraw = MapDraw
MapDraw.TILES = TILES
function MapDraw.Fit(room, boxW, boxH)
    local aspect = 4 / 3
    if room then
        local wide = (room.r - room.l) * 4
        local tall = (room.b - room.t) * 3
        if wide > 0 and tall > 0 then aspect = wide / tall end
    end
    local w = boxW
    local h = w / aspect
    if h > boxH then
        h = boxH
        w = h * aspect
    end
    return max(1, floor(w)), max(1, floor(h))
end
local function TileBase(room)
    local level = room.floor or 0
    if ns.mapTerrain and ns.mapTerrain[room.area] then level = level - 1 end
    return "Interface\\WorldMap\\" .. room.area .. "\\" .. room.area
        .. ((level > 0) and (level .. "_") or "")
end
function MapDraw.Tiles(tiles, anchor, room, w, h, ox, oy)
    for i = 1, TILES do tiles[i]:Hide() end
    if not room or not room.area then return false end
    local l, r, t, b = room.l, room.r, room.t, room.b
    local cropW, cropH = r - l, b - t
    if cropW <= 0 or cropH <= 0 then return false end
    ox, oy = ox or 0, oy or 0
    local base = TileBase(room)
    local ok = true
    for row = 0, 2 do
        for col = 0, 3 do
            local i = row * 4 + col + 1
            local tileL, tileT = col / 4, row / 3
            local pieceL = max(tileL, l)
            local pieceR = min((col + 1) / 4, r)
            local pieceT = max(tileT, t)
            local pieceB = min((row + 1) / 3, b)
            if pieceL < pieceR and pieceT < pieceB then
                local tex = tiles[i]
                if tex:SetTexture(base .. i) == false then
                    ok = false
                else
                    if room.flip then
                        tex:SetTexCoord((pieceR - tileL) * 4, (pieceL - tileL) * 4,
                            (pieceB - tileT) * 3, (pieceT - tileT) * 3)
                    else
                        tex:SetTexCoord((pieceL - tileL) * 4, (pieceR - tileL) * 4,
                            (pieceT - tileT) * 3, (pieceB - tileT) * 3)
                    end
                    tex:SetWidth((pieceR - pieceL) / cropW * w)
                    tex:SetHeight((pieceB - pieceT) / cropH * h)
                    tex:ClearAllPoints()
                    local offX = room.flip and (r - pieceR) or (pieceL - l)
                    local offY = room.flip and (b - pieceB) or (pieceT - t)
                    tex:SetPoint("TOPLEFT", anchor, "TOPLEFT",
                        ox + offX / cropW * w, -(oy + offY / cropH * h))
                    tex:Show()
                end
            end
        end
    end
    if not ok then
        for i = 1, TILES do tiles[i]:Hide() end
    end
    return ok
end
function MapDraw.Project(room, x, y, w, h)
    if not room then return nil, nil end
    local l, r, t, b = room.l, room.r, room.t, room.b
    if x < l or x > r or y < t or y > b then return nil, nil end
    if room.flip then
        x = r + l - x
        y = b + t - y
    end
    return (x - l) / (r - l) * w, (y - t) / (b - t) * h
end
