local _, ns = ...
local Kit = ns.Kit
local max = math.max
local min = math.min
local floor = math.floor
local WIDTH = 6
local MINTHUMB = 16
function Kit.ScrollBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(WIDTH)
    bar:SetHeight(height)
    bar:EnableMouse(true)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    Kit.Paint(track, "scroll.trackIdle")
    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(WIDTH)
    thumb:EnableMouse(true)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    Kit.Paint(thumbTex, "scroll.thumb")
    bar.offset, bar.visible, bar.total = 0, 1, 1
    local overBar, overThumb, dragging = false, false, false
    local grab = 0
    local function Tall()
        local top, bottom = bar:GetTop(), bar:GetBottom()
        if top and bottom and top > bottom then return top - bottom end
        return bar:GetHeight()
    end
    local function Sizes(h)
        local th = max(MINTHUMB, min(h, floor(h * bar.visible / bar.total)))
        return th, max(0, h - th)
    end
    local function Highlight()
        local hot = dragging or overBar or overThumb
        Kit.Paint(thumbTex, hot and "scroll.thumbHot" or "scroll.thumb")
    end
    local function Apply()
        local h = Tall()
        if bar.total <= bar.visible or h <= MINTHUMB then
            thumb:Hide()
            Kit.Paint(track, "scroll.trackIdle")
            return
        end
        Kit.Paint(track, "scroll.track")
        local th, room = Sizes(h)
        local pos = max(0, min(1, bar.offset / (bar.total - bar.visible)))
        thumb:SetHeight(th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", bar, "TOP", 0, -floor(room * pos))
        thumb:Show()
        Highlight()
    end
    function bar:SetState(offset, visible, total)
        self.offset, self.visible, self.total = offset, visible, total
        Apply()
    end
    local function SeekTo(y, at)
        local h = Tall()
        local top = bar:GetTop()
        if not top or h <= 0 or bar.total <= bar.visible then return end
        local th, room = Sizes(h)
        if room <= 0 then return end
        local share = max(0, min(1, (top - y - at) / room))
        local steps = max(0, bar.total - bar.visible)
        local want = floor(share * steps + 0.5)
        if bar.onScroll and want ~= bar.offset then
            bar.onScroll(want)
        end
    end
    thumb:SetScript("OnEnter", function()
        overThumb = true
        Highlight()
    end)
    thumb:SetScript("OnLeave", function()
        overThumb = false
        Highlight()
    end)
    thumb:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        local tt = self:GetTop()
        grab = tt and max(0, tt - y / self:GetEffectiveScale()) or 0
        dragging = true
        Highlight()
    end)
    thumb:SetScript("OnMouseUp", function()
        dragging = false
        Highlight()
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not dragging then return end
        if not IsMouseButtonDown("LeftButton") then
            dragging = false
            Highlight()
            return
        end
        local _, y = GetCursorPosition()
        SeekTo(y / self:GetEffectiveScale(), grab)
    end)
    bar:SetScript("OnSizeChanged", Apply)
    bar:SetScript("OnEnter", function()
        overBar = true
        Highlight()
    end)
    bar:SetScript("OnLeave", function()
        overBar = false
        Highlight()
    end)
    bar:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        SeekTo(y / self:GetEffectiveScale(), (Sizes(Tall())) / 2)
    end)
    return bar
end
