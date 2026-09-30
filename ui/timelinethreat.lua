local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local PAD = 3
local PULLW = 3
local NOTEW = 260
local NOTEH = 14
local D = ns.threatData
local TT = {}
ns.TimelineThreat = TT
local state = { fight = nil, who = nil, model = nil, p = nil, busy = false }
local drawing = false
local function Want(fight, who)
    if state.fight == fight and state.who == who then return end
    state.fight, state.who, state.model, state.p, state.busy = fight, who, nil, nil, true
    ns.Threat.Player(fight, who, function(model, p)
        if state.fight ~= fight or state.who ~= who then return end
        state.model, state.p, state.busy = model, p, false
        if not drawing and ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
    end)
end
local function Place(tex, x, y, w, h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", tex:GetParent(), "TOPLEFT", x, -y)
    tex:SetWidth(max(1, w))
    tex:SetHeight(max(1, h))
end
local function Note(GetBlock, x, y, text)
    local b = GetBlock()
    b.tip, b.tip2, b.spellId, b.jumpTo = nil, nil, nil, nil
    b.icon:Hide()
    ns.Kit.Shade(b.tex, "surface.clear")
    ns.Kit.Tone(b.label, "text.secondary")
    b.label:SetText(text)
    Place(b, x, y, NOTEW, NOTEH)
end
function TT.Draw(bound, folded, fight, who, GetBlock, GetBar, XOf, from, to)
    if folded or not bound or not fight or not who then return end
    drawing = true
    Want(fight, who)
    drawing = false
    local top, hh = bound.y + PAD, bound.h - PAD * 2
    if hh < 4 then return end
    local x0, x1 = XOf(from), XOf(to)
    if state.busy then
        Note(GetBlock, x0 + 4, top, ns.T("thr.track.loading"))
        return
    end
    if not (state.model and state.model.any) then
        Note(GetBlock, x0 + 4, top, ns.T("thr.track.old"))
        return
    end
    local scale = D.scale
    local base = top + hh
    local y100 = base - 100 / scale * hh
    local zone = GetBar()
    ns.Kit.Shade(zone, "sem.threat.zone")
    Place(zone, x0, top, x1 - x0, y100 - top)
    local line = GetBar()
    ns.Kit.Shade(line, "sem.threat.line")
    Place(line, x0, y100, x1 - x0, 1)
    local p = state.p
    local list = p and p.samples or {}
    for i = 1, #list do
        local s = list[i]
        local v, token = nil, nil
        if s.raw then
            v, token = s.raw, s.raw > 100 and "sem.threat.hot" or "sem.threat.ok"
        elseif s.ceil then
            v, token = s.ceil, "sem.threat.below"
        end
        if v and v > 0 and s.to > from and s.from < to then
            local xa, xb = XOf(max(s.from, from)), XOf(min(s.to, to))
            local h = min(v, scale) / scale * hh
            local bar = GetBar()
            ns.Kit.Shade(bar, token)
            Place(bar, xa, base - h, xb - xa, h)
        end
    end
    local pulls = p and p.pulls or {}
    for i = 1, #pulls do
        local pl = pulls[i]
        if pl.t >= from and pl.t <= to then
            local b = GetBlock()
            b.icon:Hide()
            b.label:SetText("")
            b.spellId, b.jumpTo = nil, nil
            ns.Kit.Shade(b.tex, "sem.threat.pull")
            b.tip = format(ns.T("thr.track.pull"), pl.mob.name)
            b.tip2 = format(ns.T("thr.track.prev"), pl.prev)
            b.at = pl.t
            Place(b, XOf(pl.t) - floor(PULLW / 2), top, PULLW, hh)
        end
    end
end
function TT.Readout(fight, who, t)
    if not fight or state.fight ~= fight or state.who ~= who or not state.p then return nil end
    local s = ns.Threat.SampleAt(state.p.samples, t)
    if not s or not s.mob then return nil end
    if s.raw then return format(ns.T("thr.read"), s.raw, s.mob.name) end
    if s.ceil then return format(ns.T("thr.read.below"), s.ceil, s.mob.name) end
    return nil
end
function TT.State()
    return state
end
