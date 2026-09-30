local _, ns = ...
local Kit = ns.Kit
local C = Kit.C
local max = math.max
local min = math.min
local ceil = math.ceil
local TIP_PAD = 8
local TIP_GAP = 10
local TIP_LINE = 3
local TIP_SECTION = 6
local TIP_ICON = 18
local BLOCK_STACK = 3
local SIDES = { "LEFT", "RIGHT", "TOP", "BOTTOM" }
local function OwnText(f)
    if f.isSelect and f.caption then return f.caption end
    if f.text and f.text.GetText then return f.text:GetText() end
    if f.label and f.label.GetText then return f.label:GetText() end
    if f.GetText then return f:GetText() end
    return nil
end
local first = true
local function Line(text, c)
    if first then
        GameTooltip:SetText(text, c[1], c[2], c[3], 1, true)
        first = false
    else
        GameTooltip:AddLine(text, c[1], c[2], c[3], true)
    end
end
function Kit.TipShow(f)
    local body = f.tip
    local title = f.tipTitle
    if title == nil then title = OwnText(f) end
    if title == false or title == "" then title = nil end
    if title and body and title == body then body = nil end
    if not title and not body and not f.tipDim then return end
    GameTooltip:SetOwner(f, f.tipAnchor or "ANCHOR_RIGHT")
    first = true
    if title then Line(title, f.tipColor or C["tip.title"]) end
    if body then Line(body, f.tipBodyColor or C["tip.body"]) end
    if f.tipDim then Line(f.tipDim, C["tip.dim"]) end
    GameTooltip:Show()
end
function Kit.TipHide()
    GameTooltip:Hide()
end
local TIP_INDENT = 10
local TIP_COL = 14
local TIP_MAXW = 300
local TIP_SEP = 6
local TIP_HEAD = 3
local KINDS = {
    head = { font = "GameFontNormal", left = "tip.title", right = "tip.dim", small = "GameFontHighlightSmall" },
    row = { font = "GameFontHighlight", left = "tip.body", right = "text.primary" },
    sub = { font = "GameFontHighlightSmall", left = "text.secondary", right = "text.secondary",
            indent = TIP_INDENT, wrap = true },
    text = { font = "GameFontHighlight", left = "tip.body", wrap = true },
    note = { font = "GameFontHighlightSmall", left = "tip.dim", wrap = true },
    foot = { font = "GameFontHighlightSmall", left = "text.primary", wrap = true, gap = TIP_SEP },
}
local TONES = { bad = "text.bad", good = "text.good", warn = "text.warn", dim = "tip.dim" }
local Tip = {}
Kit.Tip = Tip
local tipFrame, tipIcon
local dockSide
local dockOwner
local avoidFn
local tipLines = {}
local tipMids = {}
local tipRights = {}
local function TipFrame()
    if tipFrame then return tipFrame end
    local f = CreateFrame("Frame", "HTP_FailWatchTip", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    Kit.Skin(f, "tip")
    tipIcon = f:CreateTexture(nil, "ARTWORK")
    tipIcon:SetWidth(TIP_ICON)
    tipIcon:SetHeight(TIP_ICON)
    tipIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tipIcon:SetPoint("TOPLEFT", TIP_PAD, -TIP_PAD)
    f:Hide()
    tipFrame = f
    return f
end
local function Pooled(pool, i)
    local fs = pool[i]
    if not fs then
        fs = tipFrame:CreateFontString(nil, "OVERLAY")
        pool[i] = fs
    end
    return fs
end
local function Tone(token)
    local c = C[token]
    if not c then return 1, 1, 1 end
    return c[1], c[2], c[3]
end
local function Fill(fs, text, font, justify, r, g, b)
    fs:SetFontObject(_G[font])
    fs:SetWidth(0)
    fs:SetJustifyH(justify)
    fs:SetText(text)
    fs:SetTextColor(r, g, b)
    fs:ClearAllPoints()
    fs:Show()
    return fs:GetStringWidth() or 0, fs:GetHeight() or 0
end
local function Measure(i, l, lead, w)
    local L, M, R = Pooled(tipLines, i), Pooled(tipMids, i), Pooled(tipRights, i)
    M:Hide()
    R:Hide()
    if l.kind == nil and l.left == nil then
        local font = i == 1 and "GameFontNormal" or "GameFontHighlight"
        if type(l[2]) == "string" then
            local m = { gap = l[3] and TIP_SECTION or 0, indent = 0 }
            local r, g, b = Tone(l[2])
            m.lw, m.h = Fill(L, l[1] or "", font, "LEFT", r, g, b)
            if m.lw + lead > w.wide then w.wide = m.lw + lead end
            return m
        end
        local m = { gap = l[5] and TIP_SECTION or 0, indent = 0 }
        m.lw, m.h = Fill(L, l[1] or "", font, "LEFT",
            l[2] or 1, l[3] or 1, l[4] or 1)
        if m.lw + lead > w.wide then w.wide = m.lw + lead end
        return m
    end
    if l.kind == "sep" then
        L:Hide()
        return { sep = true, gap = 0, indent = 0, h = 0, lw = 0 }
    end
    local spec = KINDS[l.kind] or KINDS.row
    local m = { gap = spec.gap or 0, indent = spec.indent or 0, head = l.kind == "head" }
    local r, g, b
    if l.class then r, g, b = Kit.ClassColor(l.class) else r, g, b = Tone(spec.left) end
    m.lw, m.h = Fill(L, l.left or "", spec.font, "LEFT", r, g, b)
    local right, mid = l.right, l.mid
    if mid and not right then right, mid = mid, nil end
    local lead2 = m.indent + lead
    if not right then
        local room = TIP_MAXW - lead2
        if spec.wrap and m.lw > room then
            local one = m.h
            L:SetWidth(room)
            m.h = max(L:GetHeight() or 0, one * ceil(m.lw / room))
            m.lw = room
        end
        if m.lw + lead2 > w.wide then w.wide = m.lw + lead2 end
        return m
    end
    local token = TONES[l.tone or ""] or spec.right or spec.left
    local font = spec.small or spec.font
    local rw, rh = Fill(R, right, font, "RIGHT", Tone(token))
    m.right = true
    if rh > m.h then m.h = rh end
    if mid then
        local mw, mh = Fill(M, mid, font, "RIGHT", Tone(token))
        m.mid = true
        if mh > m.h then m.h = mh end
        if mw > w.mid then w.mid = mw end
        if rw > w.right then w.right = rw end
    elseif rw > w.span then
        w.span = rw
    end
    if m.lw + lead2 > w.left then w.left = m.lw + lead2 end
    return m
end
local function Layout(lines, icon)
    local f = TipFrame()
    if icon then
        tipIcon:SetTexture(icon)
        tipIcon:Show()
    else
        tipIcon:Hide()
    end
    local n = #lines
    local w = { left = 0, mid = 0, right = 0, span = 0, wide = 0 }
    local list = {}
    for i = 1, n do
        local lead = (i == 1 and icon) and (TIP_ICON + 6) or 0
        local m = Measure(i, lines[i], lead, w)
        if lead > 0 and m.h < TIP_ICON then m.h = TIP_ICON end
        list[i] = m
    end
    for i = n + 1, #tipLines do
        tipLines[i]:Hide()
        tipMids[i]:Hide()
        tipRights[i]:Hide()
    end
    local values = w.span
    if w.mid > 0 and w.mid + TIP_COL + w.right > values then values = w.mid + TIP_COL + w.right end
    local inner = w.wide
    if values > 0 and w.left + TIP_COL + values > inner then inner = w.left + TIP_COL + values end
    local y = -TIP_PAD
    for i = 1, n do
        local m = list[i]
        if m.sep then
            y = y - TIP_SEP
        else
            y = y - m.gap
            local point, base = "BOTTOMRIGHT", y - m.h
            local L = tipLines[i]
            if i == 1 and icon then
                L:SetPoint("LEFT", tipIcon, "RIGHT", 6, 0)
                point, base = "RIGHT", y - TIP_ICON / 2
            else
                L:SetPoint("TOPLEFT", TIP_PAD + m.indent, y)
            end
            if m.right then tipRights[i]:SetPoint(point, f, "TOPRIGHT", -TIP_PAD, base) end
            if m.mid then tipMids[i]:SetPoint(point, f, "TOPRIGHT", -TIP_PAD - w.right - TIP_COL, base) end
            y = y - m.h - TIP_LINE
            if m.head then y = y - TIP_HEAD end
        end
    end
    local width = inner + TIP_PAD * 2
    f:SetWidth(width)
    f:SetHeight(-y + TIP_PAD - TIP_LINE)
    return f, width
end
function Tip.Show(owner, lines, icon)
    local f, width = Layout(lines, icon)
    dockSide = nil
    f:ClearAllPoints()
    local left = owner:GetLeft()
    local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if left and left * scale < width + TIP_GAP then
        f:SetPoint("LEFT", owner, "RIGHT", TIP_GAP, 0)
    else
        f:SetPoint("RIGHT", owner, "LEFT", -TIP_GAP, 0)
    end
    f:Show()
end
function Tip.SetAvoid(fn)
    avoidFn = fn
end
local function Rect(f)
    if not (f and f.GetLeft) then return nil, 0, 0, 0 end
    local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
    if not (l and r and b and t) then return nil, 0, 0, 0 end
    local s = f:GetEffectiveScale() or 1
    return l * s, r * s, b * s, t * s
end
local function Covered(l, r, b, t, f)
    local fl, fr, fb, ft = Rect(f)
    if not fl then return 0 end
    local w = min(r, fr) - max(l, fl)
    local h = min(t, ft) - max(b, fb)
    if w <= 0 or h <= 0 then return 0 end
    return w * h
end
local function Spot(side, o, w1, h1, W, H, g, sw, sh)
    local x, y
    if side == "LEFT" then
        x, y = o[1] - g - W, (o[3] + o[4] + h1) / 2
    elseif side == "RIGHT" then
        x, y = o[2] + g, (o[3] + o[4] + h1) / 2
    elseif side == "TOP" then
        x, y = o[1], o[4] + g + H
    else
        x, y = o[1], o[3] - g
    end
    local fits
    if side == "LEFT" or side == "RIGHT" then
        fits = x >= 0 and x + W <= sw and H <= sh
    else
        fits = y - H >= 0 and y <= sh and W <= sw
    end
    x = max(0, min(x, sw - W))
    y = min(sh, max(y, H))
    return { side = side, x = x, y = y, fits = fits, area = 0 }
end
local function Score(spot, W, H, owner, avoid)
    local l, r, b, t = spot.x, spot.x + W, spot.y - H, spot.y
    local area = Covered(l, r, b, t, owner)
    for k = 1, #avoid do
        if avoid[k] ~= owner and avoid[k]:IsShown() then area = area + Covered(l, r, b, t, avoid[k]) end
    end
    spot.area = area
end
local function Better(a, b)
    if a.fits ~= b.fits then return a.fits end
    return a.area < b.area
end
function Tip.Block(owner, top, under)
    local o1, o2, o3, o4 = Rect(owner)
    top:ClearAllPoints()
    if under then under:ClearAllPoints() end
    if not o1 then
        top:SetPoint("RIGHT", owner, "LEFT", -TIP_GAP, 0)
        if under then under:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, -BLOCK_STACK) end
        return "RIGHT"
    end
    local o = { o1, o2, o3, o4 }
    local s = top:GetEffectiveScale() or 1
    local ui = UIParent:GetEffectiveScale() or 1
    local sw, sh = (UIParent:GetWidth() or 0) * ui, (UIParent:GetHeight() or 0) * ui
    local w1, h1 = (top:GetWidth() or 0) * s, (top:GetHeight() or 0) * s
    local W, H = w1, h1
    if under then
        local u = under:GetEffectiveScale() or 1
        W = max(W, (under:GetWidth() or 0) * u)
        H = H + BLOCK_STACK * s + (under:GetHeight() or 0) * u
    end
    local g = TIP_GAP * s
    local avoid = avoidFn and avoidFn() or {}
    local best
    for i = 1, #SIDES do
        local spot = Spot(SIDES[i], o, w1, h1, W, H, g, sw, sh)
        Score(spot, W, H, owner, avoid)
        if i == 1 and spot.fits and spot.area == 0 then
            best = spot
            break
        end
        if not best or Better(spot, best) then best = spot end
    end
    local edge = best.side == "LEFT" and "RIGHT" or "LEFT"
    local x = edge == "RIGHT" and best.x + W or best.x
    top:SetPoint("TOP" .. edge, UIParent, "BOTTOMLEFT", x / s, best.y / s)
    if under then under:SetPoint("TOP" .. edge, top, "BOTTOM" .. edge, 0, -BLOCK_STACK) end
    return edge
end
function Tip.Dock(owner, lines, icon)
    local f = Layout(lines, icon)
    dockOwner = owner
    dockSide = Tip.Block(owner, f)
    f:Show()
end
function Tip.Around(owner, extra)
    if tipFrame and dockSide and dockOwner == owner and tipFrame:IsShown() then
        dockSide = Tip.Block(owner, tipFrame, extra)
    else
        Tip.Block(owner, extra)
    end
end
function Tip.Docked()
    if tipFrame and dockSide and tipFrame:IsShown() then return tipFrame, dockSide end
    return nil, nil
end
function Tip.Hide()
    dockSide, dockOwner = nil, nil
    if tipFrame then tipFrame:Hide() end
end
