local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local HANDLE = 12
local HANDLEPAD = 2
local TRACKMAX = 600
local ROWMAX = 72
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
local function HandleDown(self, button)
    if button == "RightButton" then
        SetHeight(self.key, nil)
        return
    end
    local _, y = GetCursorPosition()
    resize = { key = self.key, min = self.min, h = self.h0, per = self.per, y = y / self:GetEffectiveScale() }
end
local function PlaceHandle(index, spot, gutter, size)
    local h = handles[index]
    if not h then
        h = ns.Kit.Grip(canvas, size, "v")
        h:SetFrameLevel(canvas:GetFrameLevel() + 12)
        h.tipTitle = ns.T("tl.track.size")
        h.onDown = HandleDown
        h.onUp = function() resize = nil end
        handles[index] = h
    end
    h:SetWidth(size)
    h:SetHeight(size)
    h.key, h.min, h.h0, h.per = spot.key, spot.min or (18 + ns.Kit.Grow().g), spot.h0, spot.per
    h:ClearAllPoints()
    h:SetPoint("BOTTOMRIGHT", canvas, "TOPLEFT", gutter - HANDLEPAD - 1, -(spot.bottom - HANDLEPAD))
    h:Show()
end
function TT.PlaceHandles(spots, gutter)
    local size = HANDLE + ns.Kit.Grow().g
    local used = 0
    for i = 1, #spots do
        local s = spots[i]
        if s.bottom <= canvas:GetHeight() and s.bottom >= size + HANDLEPAD and s.bottom - s.top >= size then
            used = used + 1
            PlaceHandle(used, s, gutter, size)
        end
    end
    for i = used + 1, #handles do handles[i]:Hide() end
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
    local _, cy = GetCursorPosition()
    local y = cy / self:GetEffectiveScale()
    local hh = max(resize.min, min(resize.per and ROWMAX * resize.per or TRACKMAX, floor(resize.h + resize.y - y)))
    if resize.per then hh = floor(hh / resize.per) end
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
            self.tipTitle, self.tipClick = ns.T("tl.track." .. self.key), ns.T("tl.track.fold")
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
