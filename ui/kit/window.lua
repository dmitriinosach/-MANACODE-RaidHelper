local ADDON, ns = ...
local Kit = ns.Kit
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local LAYERS = { "BACKGROUND", "BORDER", "ARTWORK" }
local MAX_TILES = 60
local MAX_STRIPS = 40
local MIN_MARK = 0.5
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
            local shown = true
            if d.at then
                local dw, dh = d.w or 64, d.h or 64
                local k = min(1, (w - 2 * (d.x or 0)) / dw, (h - 2 * (d.y or 0)) / dh)
                tx:SetPoint(d.at, f, d.at, d.x or 0, d.y or 0)
                tx:SetWidth(max(1, dw * k))
                tx:SetHeight(max(1, dh * k))
                shown = k >= MIN_MARK
            elseif d.h then
                tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(d.y or pad))
                tx:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -(d.y or pad))
                tx:SetHeight(d.h)
            else
                tx:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
                tx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
            end
            if shown then tx:Show() else tx:Hide() end
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
local function Box(list, x, y, w, h, top)
    list[#list + 1] = { x, y, w, top }
    list[#list + 1] = { x, y + h - 1, w, 1 }
    list[#list + 1] = { x, y, 1, h }
    list[#list + 1] = { x + w - 1, y, 1, h }
    return list
end
local GLYPHS = {
    fold = Box({ { 5, 5, 6, 5 } }, 0, 1, 12, 10, 1),
    unfold = Box({}, 0, 1, 12, 10, 3),
    max = Box({}, 0, 0, 12, 12, 2),
    unmax = Box({ { 3, 0, 9, 2 }, { 11, 0, 1, 8 }, { 3, 0, 1, 4 }, { 9, 7, 3, 1 } }, 0, 4, 9, 8, 2),
}
local function GlyphStyle(b)
    Kit.StyleButton(b)
    local token = "window.glyph"
    if b.btnDisabled then
        token = "window.glyphOff"
    elseif b.hovered or b.pressed then
        token = "window.glyphLit"
    end
    for i = 1, #b.glyph do Kit.Paint(b.glyph[i], token) end
    local d = b.pressed and 1 or 0
    b.icon:ClearAllPoints()
    b.icon:SetPoint("CENTER", b, "CENTER", d, -d)
end
function Kit.Glyph(b, key)
    local list = GLYPHS[key]
    b.glyphKey = key
    for i = 1, #list do
        local g = list[i]
        local t = b.glyph[i]
        if not t then
            t = b:CreateTexture(nil, "OVERLAY")
            b.glyph[i] = t
        end
        t:ClearAllPoints()
        t:SetWidth(g[3])
        t:SetHeight(g[4])
        t:SetPoint("TOPLEFT", b.icon, "TOPLEFT", g[1], -g[2])
        t:Show()
    end
    for i = #list + 1, #b.glyph do b.glyph[i]:Hide() end
    GlyphStyle(b)
end
function Kit.GlyphButton(parent, key)
    local b = Kit.IconButton(parent, nil, STRIP_ICON)
    b.icon:SetTexture(nil)
    b.glyph = {}
    b.kitStyle = GlyphStyle
    b.tipAnchor = "ANCHOR_TOP"
    Kit.Glyph(b, key)
    return b
end
function Kit.FoldButton(parent, up)
    local b = Kit.GlyphButton(parent, up and "unfold" or "fold")
    local T = ns.T or tostring
    b.tipTitle = T(up and "kit.strip.restore" or "kit.strip.fold")
    b.tip = T(up and "kit.strip.restore.tip" or "kit.strip.fold.tip")
    return b
end
function Kit.MaxLook(b, on)
    local T = ns.T or tostring
    Kit.Glyph(b, on and "unmax" or "max")
    b.tipTitle = T(on and "kit.win.unmax" or "kit.win.max")
    b.tip = T(on and "kit.win.unmax.tip" or "kit.win.max.tip")
    if b.hovered then Kit.TipShow(b) end
end
function Kit.MaxButton(parent)
    local b = Kit.GlyphButton(parent, "max")
    Kit.MaxLook(b, false)
    return b
end
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\kit\\"
local GRIP_TEX = ART .. "grip"
local GRIP_CURSOR = ART .. "grip_cursor"
local GRIP_BLANK = ART .. "blank"
local GRIP_BADGE = 24
local GRIP_ARROW = 25 / 32
local badge
local badgeOwner
local function BadgeFollow(self)
    local u = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / u, y / u)
    SetCursor(GRIP_BLANK)
end
local function Badge()
    if badge then return badge end
    badge = CreateFrame("Frame", nil, UIParent)
    badge:SetFrameStrata("TOOLTIP")
    badge:SetWidth(GRIP_BADGE)
    badge:SetHeight(GRIP_BADGE)
    badge:Hide()
    local arrow = badge:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(GRIP_CURSOR)
    arrow:SetTexCoord(0, GRIP_ARROW, 0, GRIP_ARROW)
    arrow:SetAllPoints(badge)
    badge:SetScript("OnUpdate", BadgeFollow)
    badge:SetScript("OnHide", function() ResetCursor() end)
    return badge
end
local function BadgeShow(g)
    local f = Badge()
    badgeOwner = g
    BadgeFollow(f)
    f:Show()
end
local function BadgeHide(g)
    if badgeOwner ~= g then return end
    badgeOwner = nil
    Badge():Hide()
end
local function GripDown(self, button)
    if button == "LeftButton" then
        self.held = true
        Kit.Tint(self.tex, "window.gripPress")
    end
    if self.onDown then self.onDown(self, button) end
end
local function GripUp(self, button)
    local over = self:IsMouseOver()
    self.held = nil
    Kit.Tint(self.tex, over and "window.gripLit" or "window.grip")
    if not over then BadgeHide(self) end
    if self.onUp then self.onUp(self, button) end
end
local function GripEnter(self)
    BadgeShow(self)
    if not self.held then Kit.Tint(self.tex, "window.gripLit") end
    Kit.TipShow(self)
end
local function GripLeave(self)
    Kit.TipHide()
    if self.held then return end
    Kit.Tint(self.tex, "window.grip")
    BadgeHide(self)
end
local function GripHide(self)
    self.held = nil
    Kit.Tint(self.tex, "window.grip")
    BadgeHide(self)
end
function Kit.Grip(parent, size)
    local g = CreateFrame("Button", nil, parent)
    g:SetWidth(size)
    g:SetHeight(size)
    g.tex = g:CreateTexture(nil, "ARTWORK")
    g.tex:SetTexture(GRIP_TEX)
    g.tex:SetAllPoints(g)
    Kit.Tint(g.tex, "window.grip")
    local hi = g:CreateTexture(nil, "HIGHLIGHT")
    hi:SetTexture(GRIP_TEX)
    hi:SetAllPoints(g)
    hi:SetBlendMode("ADD")
    Kit.Tint(hi, "window.gripGlow")
    g:SetScript("OnMouseDown", GripDown)
    g:SetScript("OnMouseUp", GripUp)
    g:SetScript("OnEnter", GripEnter)
    g:SetScript("OnLeave", GripLeave)
    g:SetScript("OnHide", GripHide)
    Badge()
    return g
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
