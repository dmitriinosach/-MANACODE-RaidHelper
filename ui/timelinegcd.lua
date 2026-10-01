local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local WMAX = 400
local WIDE_AT = 4
local SUBSHARE = 0.35
local SUBMIN = 8
local SUBMAX = 14
local ICONMIN = 10
local ICONMAX = 20
local ICONSHARE = 0.6
local TICK = 2
local LABEL_GAP = 3
local LABEL_PAD = 3
local LABEL_MIN = 8
local TG = {}
ns.TimelineGcd = TG
local plan = nil
local planCasts, planCuts, planWho = nil, nil, nil
local widthPps, widthMin = nil, nil
local function Clock(sec)
    local sign = sec < 0 and "-" or ""
    local a = abs(sec)
    local m = floor(a / 60)
    return format("%s%d:%04.1f", sign, m, a - m * 60)
end
local function Sec(v)
    return ns.Dec(format("%.1f", max(0, v)))
end
local function PlanOf(data, who)
    if plan and planCasts == data.casts and planCuts == data.cuts and planWho == who then return plan end
    local enc = ns.Encounters
    local class = who and enc and enc.ClassOf and enc.ClassOf(who) or nil
    plan = ns.CastGcd.Plan(data.casts, data.cuts, class, data.auras)
    planCasts, planCuts, planWho = data.casts, data.cuts, who
    widthPps, widthMin = nil, nil
    return plan
end
local function Fits(fs, text, width)
    if not text then return false end
    fs:SetText(text)
    return fs:GetStringWidth() <= width
end
local function Caption(b, it, left, room)
    local width = room - left - LABEL_PAD
    if width < LABEL_MIN then return end
    local text, tone
    if it.cut then
        text, tone = ns.T(it.cut == "kick" and "tl.cast.s.kicked" or "tl.cast.s.cut"), "text.bad"
    elseif ns.TimelineCast then
        text, tone = ns.TimelineCast.Short(it)
    end
    local tagged = text and (ns.Kit.Hex(tone or "text.secondary") .. text .. "|r") or nil
    b.label:SetPoint("LEFT", left, 0)
    b.label:SetWidth(width)
    b.castLabel = true
    if Fits(b.label, tagged and format(ns.T("tl.cast.both"), tagged, it.label), width) then return end
    if Fits(b.label, tagged, width) then return end
    if Fits(b.label, it.label, width) then return end
    b.label:SetText("")
end
local function Fill(b, slot, from)
    local it = slot.it
    b.tip, b.at = it.label, it.t
    b.jumpTo = nil
    b.spellId = tonumber(it.id)
    b.cast = (not it.cut) and it or nil
    if slot.dur > 0 then
        b.tip2 = format(ns.T("tl.cast.span"), Clock(it.start - from), Clock(it.t - from), Sec(slot.dur))
    else
        b.tip2 = Clock(it.t - from)
    end
    if it.cut == "kick" then
        b.tip3 = format(ns.T("tl.cast.cut.kick"), it.by or "?")
    elseif it.cut then
        b.tip3 = ns.T("tl.cast.cut.stop")
    elseif slot.off then
        b.tip3 = ns.T("tl.cast.offgcd")
    end
end
local function Main(slot, x, g, GetBlock, GetBar, XOf, stop)
    local it = slot.it
    local bar
    if slot.dur > 0 then
        local x0, x1 = max(x, g.left), min(XOf(it.t), g.right, stop)
        if x1 > x0 then
            bar = GetBar()
            ns.Kit.Shade(bar, it.cut and "sem.castCut" or "sem.castBar")
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", bar:GetParent(), "TOPLEFT", x0, -g.mainTop)
            bar:SetWidth(x1 - x0)
            bar:SetHeight(g.mainH)
        end
    end
    local bx = max(x, g.left)
    local bw = slot.w - (bx - x)
    if bw < 2 then return x + slot.w end
    local b = GetBlock()
    b:SetWidth(bw)
    b:SetHeight(g.mainH)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", bx, -g.mainTop)
    ns.Kit.Shade(b.tex, slot.dur > 0 and "surface.clear" or "sem.castGcd")
    local icon = it.id and ns.Effects.IconById(it.id)
    local isz = 0
    if icon then
        isz = min(g.mainH, bw)
        b.icon:SetWidth(isz)
        b.icon:SetHeight(isz)
        b.icon:SetTexture(icon)
        b.icon:SetDesaturated(it.cut ~= nil)
        b.icon:Show()
    else
        b.icon:Hide()
    end
    b.label:SetText("")
    Caption(b, it, isz + LABEL_GAP, bw)
    Fill(b, slot, g.from)
    b.wide, b.wideBar, b.wideSub = it, bar, false
    return bx + bw
end
local function Off(slot, x, lastX, g, GetBlock)
    local it = slot.it
    local b = GetBlock()
    local icon = (x - lastX >= g.subH + 1) and it.id and ns.Effects.IconById(it.id) or nil
    local w = icon and g.subH or TICK
    b:SetWidth(w)
    b:SetHeight(g.subH)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", x, -g.top)
    if icon then
        ns.Kit.Shade(b.tex, "surface.clear")
        b.icon:SetWidth(w)
        b.icon:SetHeight(w)
        b.icon:SetTexture(icon)
        b.icon:Show()
    else
        ns.Kit.Shade(b.tex, g.color, 0.95)
        b.icon:Hide()
    end
    b.label:SetText("")
    Fill(b, slot, g.from)
    b.wide, b.wideBar, b.wideSub = it, nil, true
    return icon and (x + w) or x
end
function TG.Draw(data, bound, color, GetBlock, GetBar, XOf, from, to)
    if not (data and data.casts and ns.CastGcd and ns.castGcd) or to <= from then return false end
    local fight, who = ns.Timeline.View()
    if not fight then return false end
    local hh = bound.h - 6
    local icon0 = min(hh, max(ICONMIN, min(ICONMAX, floor(hh * ICONSHARE))))
    local pps = XOf(from + 1) - XOf(from)
    local p = PlanOf(data, who)
    if pps * p.short < icon0 + WIDE_AT then return false end
    if not widthPps or abs(widthPps - pps) > pps * 1e-6 or widthMin ~= icon0 then
        ns.CastGcd.Widths(p, pps, icon0, WMAX)
        widthPps, widthMin = pps, icon0
    end
    local subH = max(SUBMIN, min(SUBMAX, floor(hh * SUBSHARE)))
    local g = { top = bound.y + 3, subH = subH, mainTop = bound.y + 3 + subH + 1, mainH = max(1, hh - subH - 1),
                left = XOf(from), right = XOf(to), color = color, from = fight.from }
    local lastEnd = -math.huge
    for k = 1, #p.on do
        local slot = p.on[k]
        local x = XOf(slot.at)
        local tail = max(slot.w, slot.dur * pps)
        if x <= g.right and x + tail >= g.left then
            local nx = p.on[k + 1]
            lastEnd = Main(slot, max(x, lastEnd), g, GetBlock, GetBar, XOf, nx and (XOf(nx.at) - 1) or math.huge)
        end
    end
    local lastX = -100
    for k = 1, #p.off do
        local slot = p.off[k]
        if slot.at >= from and slot.at <= to then
            local x = XOf(slot.at)
            if x - lastX >= 2 then lastX = Off(slot, x, lastX, g, GetBlock) end
        end
    end
    return true
end
function TG.MaxWidth()
    return WMAX
end
