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
local STRIP_H = 28
local STRIP_PAD = 10
local STRIP_GAP = 4
local STRIP_ICON = 12
local STRIP_CLOSE = 26
local STRIP_TEXT_H = 14
local ARROW_TEX = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ARROW_A, ARROW_B = 0.125, 0.875
function Kit.Arrow(tex, up)
    local a, b = ARROW_A, ARROW_B
    tex:SetTexture(ARROW_TEX)
    if up then
        tex:SetTexCoord(b, b, a, b, b, a, a, a)
    else
        tex:SetTexCoord(a, b, b, b, a, a, b, a)
    end
end
function Kit.FoldButton(parent, up)
    local b = Kit.IconButton(parent, ARROW_TEX, STRIP_ICON)
    Kit.Arrow(b.icon, up)
    local T = ns.T or tostring
    b.tipTitle = T(up and "kit.strip.restore" or "kit.strip.fold")
    b.tip = T(up and "kit.strip.restore.tip" or "kit.strip.fold.tip")
    b.tipAnchor = "ANCHOR_TOP"
    return b
end
local function Num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end
local function StripLayout(s)
    s.shut:ClearAllPoints()
    s.shut:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    s.restore:ClearAllPoints()
    s.restore:SetPoint("RIGHT", s.shut, "LEFT", 0, 0)
    local anchor = s.restore
    for i = #s.btns, 1, -1 do
        local b = s.btns[i]
        b:ClearAllPoints()
        b:SetPoint("RIGHT", anchor, "LEFT", -STRIP_GAP, 0)
        anchor = b
    end
    s.value:ClearAllPoints()
    s.value:SetPoint("RIGHT", anchor, "LEFT", -STRIP_GAP * 2, 0)
    s.label:ClearAllPoints()
    s.label:SetPoint("LEFT", s, "LEFT", STRIP_PAD, 0)
    s.label:SetPoint("RIGHT", s.value, "LEFT", -STRIP_GAP * 2, 0)
end
local function StripStop(s)
    s:StopMovingOrSizing()
    s:SetUserPlaced(false)
    local l, t = s:GetLeft(), s:GetTop()
    if not (l and t) then return end
    local p = s.spec.place()
    p.x, p.y = floor(l + 0.5), floor(t + 0.5)
end
function Kit.Strip(spec)
    local s = CreateFrame("Button", spec.name, UIParent)
    s.spec = spec
    s.btns = {}
    s:SetWidth(spec.width)
    s:SetHeight(STRIP_H)
    s:SetFrameStrata(spec.strata or "HIGH")
    s:SetToplevel(true)
    s:SetMovable(true)
    s:SetClampedToScreen(true)
    s:EnableMouse(true)
    s:RegisterForDrag("LeftButton")
    s:SetScript("OnDragStart", function(self) self:StartMoving() end)
    s:SetScript("OnDragStop", StripStop)
    s:SetScript("OnDoubleClick", function() spec.onRestore() end)
    s:Hide()
    Kit.Window(s)
    s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s.label:SetHeight(STRIP_TEXT_H)
    s.label:SetJustifyH("LEFT")
    Kit.Title(s.label)
    s.value = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.value:SetHeight(STRIP_TEXT_H)
    s.value:SetJustifyH("RIGHT")
    Kit.Text(s.value, "text.secondary")
    s.restore = Kit.FoldButton(s, true)
    s.restore.onClick = function() spec.onRestore() end
    s.shut = CreateFrame("Button", nil, s, "UIPanelCloseButton")
    s.shut:SetWidth(STRIP_CLOSE)
    s.shut:SetHeight(STRIP_CLOSE)
    s.shut:SetScript("OnClick", function() spec.onClose() end)
    StripLayout(s)
    return s
end
function Kit.StripButton(s, tex)
    local b = Kit.IconButton(s, tex, STRIP_ICON + 4)
    b.tipAnchor = "ANCHOR_TOP"
    s.btns[#s.btns + 1] = b
    StripLayout(s)
    return b
end
function Kit.StripValue(s, text, token)
    s.value:SetText(text or "")
    Kit.Text(s.value, token or "text.secondary")
end
function Kit.StripShow(s, x, y)
    local p = s.spec.place()
    x, y = Num(p.x) or x, Num(p.y) or y
    s:ClearAllPoints()
    if x and y then
        s:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        s:SetPoint("TOP", UIParent, "TOP", 0, -STRIP_H * 4)
    end
    s:Show()
end
function Kit.TopLeftOf(f, lift)
    local l, t = f:GetLeft(), f:GetTop()
    local fe, pe = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (l and t and fe and pe) or pe <= 0 then return nil, nil end
    local k = fe / pe
    return floor(l * k + 0.5), floor((t + (lift or 0)) * k + 0.5)
end
Kit.OnTheme(function()
    for i = 1, #windows do PaintWindow(windows[i]) end
end)
