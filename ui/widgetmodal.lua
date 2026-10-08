local _, ns = ...
local max = math.max
local min = math.min
local MARGIN = 24
local ZOOM = 1.25
local WIDEN = 1.15
local WIDTH_DETAIL = 440
local WIDTH_WIDE = 560
local BAR_R = 5
local CLOSE = 22
local LEVEL = 50
local STRATA = "FULLSCREEN_DIALOG"
local Modal = {}
ns.WidgetModal = Modal
local dim
local panels = {}
local closing = false
local function Shut()
    closing = false
    if dim then dim:Hide() end
end
local function Shown()
    for _, f in pairs(panels) do
        if f:IsShown() then return f end
    end
    return nil
end
local function Close()
    if closing or not (dim and dim:IsShown()) then return end
    closing = true
    local f = Shown()
    if f then ns.Kit.PopOut(f) end
    ns.Kit.FadeOut(dim, Shut)
end
local function OnKey(_, key)
    if key == "ESCAPE" then Close() end
end
local function Build()
    if dim then return dim end
    dim = CreateFrame("Frame", "HTP_FailWatchWidgetModal", UIParent)
    dim:SetFrameStrata(STRATA)
    dim:SetFrameLevel(LEVEL)
    dim:SetAllPoints(UIParent)
    dim:SetToplevel(true)
    dim:EnableMouse(true)
    dim:EnableMouseWheel(true)
    dim:EnableKeyboard(true)
    dim:SetScript("OnMouseWheel", function() end)
    dim:SetScript("OnMouseDown", Close)
    dim:SetScript("OnKeyDown", OnKey)
    dim:SetScript("OnHide", function()
        closing = false
        ns.Tip.Hide()
    end)
    dim:RegisterEvent("PLAYER_REGEN_DISABLED")
    dim:SetScript("OnEvent", Shut)
    local shade = dim:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    ns.Kit.Paint(shade, "surface.shade")
    dim:Hide()
    return dim
end
local function Panel(panel)
    local key = panel.wide and "wide" or "detail"
    local f = panels[key]
    if f then return f end
    f = panel.wide and ns.Badges.Wide(dim, true) or ns.Badges.Detail(dim, true)
    f:EnableMouse(true)
    f:SetFrameStrata(STRATA)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetFrameLevel(f:GetFrameLevel() + 10)
    close:SetWidth(CLOSE)
    close:SetHeight(CLOSE)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", Close)
    local bar = ns.Kit.ScrollBar(f, 100)
    bar:SetFrameLevel(f:GetFrameLevel() + 6)
    bar.onScroll = function(offset)
        f.offset = offset
        f:Redraw()
    end
    f.bar = bar
    f.onDraw = function(self)
        local total = #self.list
        if total > self.lineCount then
            self.bar:Show()
            self.bar:SetState(self.offset or 0, self.lineCount, total)
        else
            self.bar:Hide()
        end
    end
    panels[key] = f
    return f
end
function Modal.Open(source)
    local m = source.model
    if not m then return end
    Build()
    ns.Tip.Hide()
    local f = Panel(source)
    for _, other in pairs(panels) do
        if other ~= f then other:Hide() end
    end
    local shell = ns.Shell and ns.Shell.Frame and ns.Shell.Frame()
    local box = (shell and shell:IsShown()) and shell or UIParent
    local px = box:GetEffectiveScale()
    local boxW, boxH = box:GetWidth() * px, box:GetHeight() * px
    local least = source.wide and WIDTH_WIDE or WIDTH_DETAIL
    local want = max(source:GetWidth(), least) * WIDEN
    local eff = source:GetEffectiveScale() * ZOOM
    if want + MARGIN * 2 > boxW / eff then eff = boxW / (want + MARGIN * 2) end
    f:SetScale(eff / f:GetParent():GetEffectiveScale())
    local lines, top, step = ns.Badges.Reach(f, boxH / eff - MARGIN * 2)
    f.fixed = max(1, min(#(m.rows or {}), lines))
    f:SetModel(m)
    if source.wide then f:Share(source) end
    f:Layout(min(want, boxW / eff - MARGIN * 2))
    if f.fold then top = top + step end
    f:ClearAllPoints()
    f:SetPoint("CENTER", box, "CENTER", 0, 0)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -BAR_R, -top)
    f.bar:SetHeight(f.fixed * step)
    closing = false
    f:Show()
    dim:Show()
    f:Redraw()
    ns.Kit.FadeIn(dim)
    ns.Kit.PopIn(f)
end
function Modal.Current()
    if closing or not (dim and dim:IsShown()) then return nil end
    return Shown()
end
function Modal.Close()
    Shut()
end
