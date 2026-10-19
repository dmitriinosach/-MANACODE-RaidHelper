local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local HANDLEH = 7
local TRACKMAX = 600
local TT = {}
ns.TimelineTracks = TT
local canvas, tracks, folded
local heads, handles = {}, {}
local resize
function TT.FoldMark(label, fold)
    return (fold and "+ " or "- ") .. label
end
local function SetHeight(key, height)
    local ui = ns.GetDB().settings.ui
    if type(ui.trackH) ~= "table" then ui.trackH = {} end
    ui.trackH[key] = height
    ns.Timeline.Redraw()
end
local function PlaceHandle(index, bound)
    local track = tracks[index]
    local h = handles[index]
    if not h then
        h = CreateFrame("Frame", nil, canvas)
        h:SetHeight(HANDLEH)
        h:EnableMouse(true)
        h:SetFrameLevel(canvas:GetFrameLevel() + 6)
        h.tex = h:CreateTexture(nil, "OVERLAY")
        h.tex:SetAllPoints()
        h:SetScript("OnEnter", function(self)
            ns.Kit.Shade(self.tex, "surface.handle")
            self.tipTitle, self.tipAnchor = ns.T("tl.track.size"), "ANCHOR_CURSOR"
            ns.Kit.TipShow(self)
        end)
        h:SetScript("OnLeave", function(self)
            if not resize then ns.Kit.Shade(self.tex, "surface.clear") end
            ns.Kit.TipHide()
        end)
        h:SetScript("OnMouseDown", function(self, button)
            if button == "RightButton" then
                SetHeight(self.key, nil)
                return
            end
            resize = { key = self.key, min = self.min, h = self.h0,
                       y = GetCursorPosition() / self:GetEffectiveScale() }
        end)
        h:SetScript("OnMouseUp", function() resize = nil end)
        handles[index] = h
    end
    h.key = track.key
    h.min = track.min or (18 + ns.Kit.Grow().g)
    h.h0 = bound.h
    if not resize or resize.key ~= track.key then
        ns.Kit.Shade(h.tex, "surface.clear")
    end
    h:SetWidth(canvas:GetWidth())
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0,
        -(bound.hy + bound.full - floor(HANDLEH / 2)))
    h:Show()
end
function TT.PlaceHandles(bounds)
    for i = 1, #tracks do
        local track = tracks[i]
        local fits = bounds[i].hy + bounds[i].full < canvas:GetHeight()
        if track.rows or folded(track.key) or not fits then
            if handles[i] then handles[i]:Hide() end
        else
            PlaceHandle(i, bounds[i])
        end
    end
end
function TT.HideHandles()
    for _, h in pairs(handles) do h:Hide() end
end
function TT.Drag(self)
    if not resize then return false end
    if not IsMouseButtonDown("LeftButton") then
        resize = nil
        return true
    end
    local y = GetCursorPosition() / self:GetEffectiveScale()
    local hh = max(resize.min, min(TRACKMAX, floor(resize.h + resize.y - y)))
    local ui = ns.GetDB().settings.ui
    if type(ui.trackH) ~= "table" then ui.trackH = {} end
    if ui.trackH[resize.key] ~= hh then
        ui.trackH[resize.key] = hh
        return true, true
    end
    return true
end
function TT.Build(host, list, isFolded, onFold)
    canvas, tracks, folded = host, list, isFolded
    for i = 1, #tracks do
        local h = CreateFrame("Button", nil, canvas)
        h:SetHeight(14 + ns.Kit.Grow().g - 1)
        h:SetFrameLevel(canvas:GetFrameLevel() + 10)
        h.key = tracks[i].key
        h.bg = h:CreateTexture(nil, "BACKGROUND")
        h.bg:SetAllPoints()
        ns.Kit.Paint(h.bg, "surface.laneHead")
        h.text = ns.Kit.Str(h, "GameFontHighlightSmall")
        h.text:SetJustifyH("LEFT")
        ns.Kit.Text(h.text, "surface.laneText")
        h:SetScript("OnEnter", function(self)
            ns.Kit.Paint(self.bg, "surface.laneHeadHover")
            self.tipTitle, self.tip, self.tipTone = ns.T("tl.track." .. self.key), ns.T("tl.track.fold"), "text.secondary"
            ns.Kit.TipShow(self)
        end)
        h:SetScript("OnLeave", function(self)
            ns.Kit.Paint(self.bg, "surface.laneHeadIdle")
            ns.Kit.TipHide()
        end)
        h:SetScript("OnMouseDown", function()
            if ns.FxDrag then ns.FxDrag.Clear() end
        end)
        h:SetScript("OnClick", function(self)
            onFold(self.key)
        end)
        h:Hide()
        heads[i] = h
    end
end
function TT.HideHeads()
    for i = 1, #heads do heads[i]:Hide() end
end
function TT.PlaceHeads(bounds, gutter, targets)
    local view = canvas:GetHeight()
    for i = 1, #tracks do
        local head = heads[i]
        local key = tracks[i].key
        local fold = folded(key)
        local top = max(0, bounds[i].hy)
        local room = min(view, bounds[i].hy + bounds[i].full) - top
        if room < 8 then
            head:Hide()
        else
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", canvas, "TOPLEFT", 1, -(top + 1))
            head:SetWidth(max(24, gutter - 2))
            head:SetHeight(min(room, 14 + ns.Kit.Grow().g - 1))
            head.text:ClearAllPoints()
            head.text:SetPoint("LEFT", 3, 0)
            head.text:SetWidth(max(10, gutter - 7))
            head.text:SetText(TT.FoldMark(ns.T("tl.track." .. key), fold))
            head:Show()
            if not fold and (key == "auras" or key == "healed" or key == "taken") then
                targets[#targets + 1] = { frame = head, tex = head.bg,
                                          cat = key == "auras" and ns.Effects.ROOT or key }
            end
        end
    end
end
