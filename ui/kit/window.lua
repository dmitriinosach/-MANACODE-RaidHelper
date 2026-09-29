local _, ns = ...
local Kit = ns.Kit
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local LAYERS = { "BACKGROUND", "BORDER", "ARTWORK" }
local MAX_TILES = 60
local MAX_STRIPS = 40
local windows = {}
function Kit.Back(f)
    local b = f.kitBack
    if not b then
        b = CreateFrame("Frame", nil, f)
        b:SetAllPoints(f)
        b:SetFrameLevel(f:GetFrameLevel())
        f.kitBack = b
    end
    return b
end
local function Take(f, layer)
    local pool = f.kitDecor
    local n = f.kitDecorN + 1
    f.kitDecorN = n
    local tx = pool[n]
    if not tx then
        tx = f:CreateTexture(nil, layer)
        pool[n] = tx
    end
    tx:ClearAllPoints()
    return tx
end
local function Tiles(f, d, layer, w, h)
    local pad = d.inset or 0
    local cell = d.tile
    local aw, ah = w - pad * 2, h - pad * 2
    local cols, rows = max(1, ceil(aw / cell)), max(1, ceil(ah / cell))
    if cols * rows > MAX_TILES then rows = max(1, floor(MAX_TILES / cols)) end
    local c = d.coord or { 0, 1, 0, 1 }
    for ky = 0, rows - 1 do
        local hh = min(cell, ah - ky * cell)
        for kx = 0, cols - 1 do
            local ww = min(cell, aw - kx * cell)
            if ww > 0 and hh > 0 then
                local tx = Take(f, layer)
                Kit.Fill(tx, d)
                tx:SetDrawLayer(layer)
                tx:SetTexCoord(c[1], c[1] + (c[2] - c[1]) * ww / cell, c[3], c[3] + (c[4] - c[3]) * hh / cell)
                tx:SetWidth(ww)
                tx:SetHeight(hh)
                tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad + kx * cell, -(pad + ky * cell))
                tx:Show()
            end
        end
    end
end
local function Strips(f, d, layer, w, h)
    local pad = d.inset or 0
    local band = d.tileY
    local avail = h - pad * 2
    local rows = min(MAX_STRIPS, max(1, ceil(avail / band)))
    local c = d.coord or { 0, 1, 0, 1 }
    for k = 0, rows - 1 do
        local hh = min(band, avail - k * band)
        if hh > 0 then
            local tx = Take(f, layer)
            Kit.Fill(tx, d)
            tx:SetDrawLayer(layer)
            tx:SetTexCoord(c[1], c[2], c[3], c[3] + (c[4] - c[3]) * hh / band)
            tx:SetWidth(w - pad * 2)
            tx:SetHeight(hh)
            tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(pad + k * band))
            tx:Show()
        end
    end
end
local function Weave(f, d)
    local b = Kit.Back(f)
    local pad = d.inset or 0
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
    b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
    local bd = f.kitWeave
    if not bd or bd.bgFile ~= d.bgFile or bd.tileSize ~= d.tileSize then
        bd = { bgFile = d.bgFile, tile = true, tileSize = d.tileSize or 64 }
        f.kitWeave = bd
    end
    if b.kitBd ~= bd then
        b:SetBackdrop(bd)
        b.kitBd = bd
    end
    local c = d.color or { 1, 1, 1, 1 }
    b:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
end
function Kit.ApplyDecor(f, list)
    list = list or Kit.Theme().window.decor or {}
    if not f.kitDecor then f.kitDecor = {} end
    f.kitDecorN = 0
    local woven = false
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    for i = 1, #list do
        local d = list[i]
        local layer = d.layer or LAYERS[i] or "ARTWORK"
        if d.kind == "backdrop" then
            Weave(f, d)
            woven = true
        elseif d.tile then
            Tiles(f, d, layer, w, h)
        elseif d.tileY then
            Strips(f, d, layer, w, h)
        else
            local tx = Take(f, layer)
            Kit.Fill(tx, d)
            tx:SetDrawLayer(layer)
            local pad = d.inset or 0
            if d.h then
                tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(d.y or pad))
                tx:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -(d.y or pad))
                tx:SetHeight(d.h)
            else
                tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
                tx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
            end
            tx:Show()
        end
    end
    local pool = f.kitDecor
    for i = f.kitDecorN + 1, #pool do pool[i]:Hide() end
    if not woven and f.kitBack and f.kitBack.kitBd then
        f.kitBack:SetBackdrop(nil)
        f.kitBack.kitBd = nil
        f.kitBack:ClearAllPoints()
        f.kitBack:SetAllPoints(f)
    end
end
local function PaintWindow(f)
    Kit.Backdrop(f, Kit.Theme().window)
    Kit.ApplyDecor(f)
end
function Kit.Window(f)
    if not f.kitWindow then
        f.kitWindow = true
        windows[#windows + 1] = f
        Kit.Back(f)
    end
    PaintWindow(f)
    return f
end
function Kit.Panel(parent, caption)
    local p = CreateFrame("Frame", nil, parent)
    Kit.Skin(p, "panel")
    if caption then
        p.cap = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        p.cap:SetPoint("TOPLEFT", p, "TOPLEFT", Kit.Space.inset, -10)
        p.cap:SetText(caption)
        Kit.Title(p.cap)
        p.rule = p:CreateTexture(nil, "ARTWORK")
        Kit.Paint(p.rule, "text.title", 0.4)
        p.rule:SetHeight(1)
        p.rule:SetPoint("LEFT", p.cap, "RIGHT", 6, 0)
        p.rule:SetPoint("RIGHT", p, "RIGHT", -Kit.Space.inset, 0)
    end
    return p
end
function Kit.Plate(parent)
    local p = CreateFrame("Frame", nil, parent)
    Kit.Skin(p, "plate")
    return p
end
function Kit.Caption(parent, text, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    Kit.Title(fs)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    Kit.Paint(rule, "text.title", 0.4)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    rule:SetWidth(max(1, (width or 100) - fs:GetStringWidth() - 6))
    fs.rule = rule
    return fs
end
Kit.OnTheme(function()
    for i = 1, #windows do PaintWindow(windows[i]) end
end)
