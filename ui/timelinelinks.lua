local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local FOCUS_SPAN = 40
local LINE_W = 2
local BAND_W = 11
local Links = {}
ns.TimelineLinks = Links
local focus
local line
local band
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
function Links.Culprit(it, player)
    local who = it.victim or it.src
    if who == nil or who == player then return nil end
    return who
end
function Links.Window(from, to, lead, tail, t, keep)
    local span = to - from
    if keep and t >= from and t <= to then return from, to end
    if not keep then span = min(span, FOCUS_SPAN) end
    span = min(span, tail - lead)
    local left = max(lead, min(tail - span, t - span / 2))
    return left, left + span
end
function Links.Focus(name, t, keep)
    local TL = ns.Timeline
    if not (TL and TL.View) then return false end
    local fight = TL.View()
    if not (fight and fight.players[name]) then return false end
    focus = t and { fight = fight, who = name, t = t } or nil
    TL.SelectPlayer(name)
    if t then
        local _, _, from, to, lead, tail = TL.View()
        local a, b = Links.Window(from, to, lead, tail, t, keep)
        if a ~= from or b ~= to then TL.SetView(a, b) end
    end
    return true
end
function Links.Focused()
    return focus
end
local function Build(host)
    band = host:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(band, "sem.linkBand")
    band:SetWidth(BAND_W)
    line = host:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(line, "sem.link")
    line:SetWidth(LINE_W)
end
local function HideMarker()
    if line then line:Hide() end
    if band then band:Hide() end
end
function Links.Paint()
    local TL = ns.Timeline
    if not (TL and TL.View and TL.Overlay) then return end
    local fight, who, from, to = TL.View()
    if focus and (focus.fight ~= fight or focus.who ~= who) then focus = nil end
    local host = TL.Overlay()
    if not host then return end
    if not line then Build(host) end
    if not focus or focus.t < from or focus.t > to then
        HideMarker()
        return
    end
    local x = floor(TL.XOf(focus.t))
    local h = host:GetHeight()
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", host, "TOPLEFT", x - floor(BAND_W / 2), 0)
    band:SetHeight(h)
    band:Show()
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", host, "TOPLEFT", x - floor(LINE_W / 2), 0)
    line:SetHeight(h)
    line:Show()
end
function Links.Tag(lines, fight, t)
    if not (fight and t) then return lines end
    local key = ns.ReplayIso and "tl.mark.click" or "tl.mark.click.bare"
    lines[#lines + 1] = { kind = "foot", left = format(ns.T(key), Clock(max(0, t - fight.from))) }
    return lines
end
function Links.OpenMark(mark, button)
    if button and button ~= "LeftButton" then return false end
    local who = mark.who
    if not who then return false end
    ns.Tip.Hide()
    if ns.DeathPreviewView then ns.DeathPreviewView.Leave() end
    if ns.Badges then ns.Badges.Unhighlight() end
    return Links.Focus(who, mark.at)
end
