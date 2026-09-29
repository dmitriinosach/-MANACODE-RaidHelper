local _, ns = ...
local ICONSZ = 20
local NUDGEX = 16
local NUDGEY = -24
local Drag = {}
ns.FxDrag = Drag
local ghost, ghostIcon, ghostText, driver
local active, blocked = false, false
local dragId, hovered
local targetsFn
local highlightFn
local phaseFn
local function Over(frame)
    if not frame or not frame:IsVisible() then return false end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return false end
    local scale = frame:GetEffectiveScale()
    if not scale or scale <= 0 then return false end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    return x >= left and x <= left + frame:GetWidth()
        and y >= bottom and y <= bottom + frame:GetHeight()
end
local function Aim()
    local list = targetsFn and targetsFn() or nil
    if not list then return nil end
    for i = 1, #list do
        if Over(list[i].frame) then return list[i].cat end
    end
    return nil
end
local function Follow()
    local scale = ghost:GetEffectiveScale()
    if not scale or scale <= 0 then return end
    local x, y = GetCursorPosition()
    ghost:ClearAllPoints()
    ghost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
        x / scale + NUDGEX, y / scale + NUDGEY)
end
local function Build()
    if ghost then return end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetWidth(ICONSZ)
    ghost:SetHeight(ICONSZ)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:Hide()
    ghostIcon = ghost:CreateTexture(nil, "ARTWORK")
    ghostIcon:SetAllPoints()
    ghostIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ghostText = ghost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ghostText:SetPoint("LEFT", ghost, "RIGHT", 4, 0)
    ghostText:SetJustifyH("LEFT")
    ns.Kit.Text(ghostText, "sem.readout")
    driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    driver:SetScript("OnUpdate", function()
        if not active then return end
        if not IsMouseButtonDown("LeftButton") then
            Drag.Stop()
            return
        end
        Follow()
        local cat = Aim()
        if cat ~= hovered then
            hovered = cat
            if highlightFn then highlightFn(cat) end
        end
    end)
end
function Drag.SetTargets(fn)
    targetsFn = fn
end
function Drag.SetHighlight(fn)
    highlightFn = fn
end
function Drag.SetPhase(fn)
    phaseFn = fn
end
local function Repaint()
    if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
end
function Drag.Start(id, name, icon)
    if not id then return end
    Build()
    dragId = id
    active, blocked, hovered = true, false, nil
    if icon then
        ghostIcon:SetTexture(icon)
        ghostIcon:Show()
    else
        ghostIcon:Hide()
    end
    ghostText:SetText(name or ns.Effects.Name(id))
    Follow()
    ghost:Show()
    driver:Show()
    if phaseFn then phaseFn(true) end
    Repaint()
end
function Drag.Stop()
    if not active then return end
    active, blocked = false, true
    driver:Hide()
    ghost:Hide()
    local cat, id = hovered, dragId
    hovered, dragId = nil, nil
    if cat and id then
        local bind = cat:match("^row:(%d+)$")
        local track, shelf = cat:match("^(healed):(%a+)$")
        if not track then track, shelf = cat:match("^(taken):(%a+)$") end
        if bind then
            ns.Effects.SetGlue(id, tonumber(bind))
            ns.Effects.Set(id, "on")
        elseif track then
            ns.Effects.SetRowCat(id, track, shelf)
        elseif cat == "healed" or cat == "taken" then
            ns.Effects.SetRowCat(id, cat, "root")
        else
            local base = cat:match("^(.+):off$")
            ns.Effects.SetGlue(id, nil)
            ns.Effects.SetCategory(id, base or cat)
            ns.Effects.Set(id, base and "off" or "on")
        end
        if ns.EffectPanel and ns.EffectPanel.Refresh then ns.EffectPanel.Refresh() end
    end
    if phaseFn then phaseFn(false) end
    Repaint()
end
function Drag.Clear()
    blocked = false
end
function Drag.Busy()
    return active or blocked
end
