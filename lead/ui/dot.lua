local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local SIZE = 10
local BLINK = 1.2
local dot
local function tipText()
    local n, size = ns.Session.Count()
    local c, left = ns.Spam.Next()
    if not ns.Spam.Fits() then
        return ns.T("dotTooLong", n, size)
    end
    return ns.T("dotTip", n, size, math.ceil(left or 0))
end
local function build()
    local host = ChatFrame1 or UIParent
    dot = ns.NewFrame("Button", "RaidLeadSpamDot", UIParent)
    dot:SetSize(SIZE + 6, SIZE + 6)
    dot:SetFrameStrata("MEDIUM")
    dot:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 6)
    dot.edge = dot:CreateTexture(nil, "BACKGROUND")
    dot.edge:SetTexture(ns.DOT_TEX)
    dot.edge:SetVertexColor(0, 0, 0, 0.85)
    dot.edge:SetPoint("CENTER", dot, "CENTER", 0, 0)
    dot.edge:SetSize(SIZE + 3, SIZE + 3)
    dot.core = dot:CreateTexture(nil, "ARTWORK")
    dot.core:SetTexture(ns.DOT_TEX)
    dot.core:SetPoint("CENTER", dot, "CENTER", 0, 0)
    dot.core:SetSize(SIZE, SIZE)
    dot:RegisterForClicks("LeftButtonUp")
    dot:SetScript("OnClick", function() ns.Spam.Stop() end)
    dot:SetScript("OnEnter", function(self)
        self.tipTitle = ns.T("appTitle")
        self.tip = tipText()
        self.tipDim = ns.T("dotClick")
        self.tipAnchor = "ANCHOR_TOPRIGHT"
        ns.TipShow(self)
    end)
    dot:SetScript("OnLeave", ns.TipHide)
    local t = 0
    dot:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        local a = 0.55 + 0.45 * math.abs(math.sin(t * math.pi / BLINK))
        if ns.Spam.Fits() then
            self.core:SetVertexColor(0.95, 0.15, 0.12, a)
        else
            self.core:SetVertexColor(1, 0.55, 0.1, 1)
        end
        if GameTooltip:IsOwned(self) then
            GameTooltip:ClearLines()
            ns.TipShow(self)
        end
    end)
    dot:Hide()
end
local function sync()
    if not dot then build() end
    if ns.Spam.Running() then dot:Show() else dot:Hide() end
end
ns.Session.OnChange(sync)
