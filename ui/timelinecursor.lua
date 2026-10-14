local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local READOUTW = 110
local DOTMIN = 4
local DOTMAX = 12
local DOTSHARE = 0.14
local TC = {}
ns.TimelineCursor = TC
local cursorLine, cursorLabel, cursorBg, hpDot, rowGlow
local readouts = {}
local hov = {}
function TC.LastBefore(items, t)
    local found = nil
    for i = 1, items and #items or 0 do
        if items[i].t <= t then found = items[i] else break end
    end
    return found
end
local LastBefore = TC.LastBefore
function TC.Build(canvas, overlay, n)
    cursorLine = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(cursorLine, "sem.cursor")
    cursorLine:SetWidth(1)
    cursorLine:Hide()
    cursorBg = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(cursorBg, "surface.shade")
    cursorBg:Hide()
    cursorLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(cursorLabel, "sem.cursorText")
    cursorLabel:Hide()
    hpDot = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(hpDot, "sem.cursorDot")
    hpDot:SetWidth(DOTMIN)
    hpDot:SetHeight(DOTMIN)
    hpDot:Hide()
    rowGlow = canvas:CreateTexture(nil, "BACKGROUND")
    ns.Kit.Paint(rowGlow, "surface.line")
    rowGlow:Hide()
    for i = 1, n do
        local fs = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ns.Kit.Text(fs, "sem.readout")
        fs:Hide()
        readouts[i] = fs
    end
end
function TC.Reset()
    hov.x = nil
end
local function ClockMs(sec)
    local sign = sec < 0 and "-" or ""
    local abs = sec < 0 and -sec or sec
    local m = floor(abs / 60)
    local s = abs - m * 60
    return format("%s%d:%02d.%03d", sign, m, floor(s), floor((s - floor(s)) * 1000))
end
local function ShowReadouts(c, t)
    local data = c.data
    if not data then
        for i = 1, #readouts do readouts[i]:Hide() end
        return
    end
    if ns.TimelineBrief and ns.TimelineBrief.On() then return ns.TimelineBrief.Readouts(t, readouts, hpDot) end
    local bounds = c.Bounds()
    local overlay = c.overlay
    local x = c.XOf(t)
    local flip = (c.canvas:GetWidth() - x) < READOUTW
    local text = {}
    local b = LastBefore(data.boss, t)
    text[1] = b and b.label or nil
    local cast = LastBefore(data.casts, t)
    text[2] = cast and (ns.TimelineCast and ns.TimelineCast.Readout(cast) or cast.label) or nil
    local active = 0
    local auraRows = c.auraRows
    for slot = 1, #auraRows do
        local list = auraRows[slot].items
        for j = 1, (list and #list or 0) do
            local a = list[j]
            if a.t <= t and (a.to or a.t) >= t then active = active + 1 break end
        end
    end
    text[3] = active > 0 and format(ns.T("tl.read.auras"), active) or nil
    local heal = LastBefore(data.healed, t)
    text[4] = heal and (t - heal.t) < 3 and format("%s: +%d", heal.label, heal.amount) or nil
    local d = LastBefore(data.taken, t)
    text[5] = d and (t - d.t) < 3 and (d.miss and format("%s: %s", d.label, ns.TimelineRows.MissText(d))
        or format("%s: %d", d.label, d.amount)) or nil
    local h = LastBefore(data.hp, t)
    if h then
        text[6] = h.hp and format("%d%%  (%d)", floor(h.pct * 100 + 0.5), h.hp)
            or format("%d%%", floor(h.pct * 100 + 0.5))
    end
    text[7] = ns.TimelineThreat and ns.TimelineThreat.Readout(c.fight, c.player, t) or nil
    if h and hpDot and not c.Folded("hp") then
        local hb = bounds[6]
        local top = hb.y + 4
        local hh = hb.h - 8
        local dot = max(DOTMIN, min(DOTMAX, floor(hh * DOTSHARE)))
        hpDot:SetWidth(dot)
        hpDot:SetHeight(dot)
        hpDot:ClearAllPoints()
        hpDot:SetPoint("CENTER", overlay, "TOPLEFT", x, -(top + hh - h.pct * hh))
        hpDot:Show()
    elseif hpDot then
        hpDot:Hide()
    end
    for i = 1, #readouts do
        local fs = readouts[i]
        if text[i] and not c.Folded(c.tracks[i].key) then
            local ty = bounds[i].y + 2
            fs:ClearAllPoints()
            if flip then
                fs:SetPoint("TOPRIGHT", overlay, "TOPLEFT", x - 4, -ty)
                fs:SetJustifyH("RIGHT")
            else
                fs:SetPoint("TOPLEFT", overlay, "TOPLEFT", x + 4, -ty)
                fs:SetJustifyH("LEFT")
            end
            fs:SetText(text[i])
            fs:Show()
        else
            fs:Hide()
        end
    end
end
local function HideReadouts()
    for i = 1, #readouts do readouts[i]:Hide() end
    if hpDot then hpDot:Hide() end
end
function TC.Hover(self, c, cursor)
    local x = cursor - self:GetLeft()
    local over = self:IsMouseOver() and x >= c.gutter and x <= self:GetWidth()
    local _, rawY = GetCursorPosition()
    if over and hov.x == x and hov.y == rawY and hov.from == c.from and hov.to == c.to
        and hov.scroll == c.scroll and hov.fight == c.fight then
        return
    end
    if not over and hov.out then return end
    hov.x, hov.y, hov.from, hov.to, hov.scroll, hov.fight = over and x or nil, rawY, c.from, c.to,
        c.scroll, c.fight
    hov.out = not over
    if over then
        local overlay = c.overlay
        local t = c.from + (x - c.gutter) / (self:GetWidth() - c.gutter) * (c.to - c.from)
        cursorLine:ClearAllPoints()
        cursorLine:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
        cursorLine:SetHeight(self:GetHeight())
        cursorLine:Show()
        cursorLabel:SetText(ClockMs(t - c.fight.from))
        cursorBg:SetWidth(cursorLabel:GetStringWidth() + 8)
        cursorBg:SetHeight(cursorLabel:GetStringHeight() + 4)
        cursorBg:ClearAllPoints()
        cursorBg:SetPoint("TOPLEFT", overlay, "TOPLEFT", x + 2, -2)
        cursorBg:Show()
        cursorLabel:ClearAllPoints()
        cursorLabel:SetPoint("LEFT", cursorBg, "LEFT", 4, 0)
        cursorLabel:Show()
        ShowReadouts(c, t)
        if ns.MapView then ns.MapView.ShowAt(t, c.player) end
        local _, cy = GetCursorPosition()
        local top = self:GetTop()
        if rowGlow and top then
            local gy, gh = c.Glow(top - cy / self:GetEffectiveScale())
            if gy then
                rowGlow:ClearAllPoints()
                rowGlow:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -gy)
                rowGlow:SetWidth(self:GetWidth())
                rowGlow:SetHeight(gh)
                rowGlow:Show()
            elseif gy == nil then
                rowGlow:Hide()
            end
        end
    else
        cursorLine:Hide()
        cursorBg:Hide()
        cursorLabel:Hide()
        if rowGlow then rowGlow:Hide() end
        HideReadouts()
    end
end
