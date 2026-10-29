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
    local function Drop(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        Highlight()
    end
    local function Drag(self)
        if not IsMouseButtonDown("LeftButton") then
            Drop(self)
            return
        end
        local _, y = GetCursorPosition()
        SeekTo(y / self:GetEffectiveScale(), grab)
    end
    thumb:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        local tt = self:GetTop()
        grab = tt and max(0, tt - y / self:GetEffectiveScale()) or 0
        dragging = true
        self:SetScript("OnUpdate", Drag)
        Highlight()
    end)
    thumb:SetScript("OnMouseUp", Drop)
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
local DECK_W = 8
local DECK_LEVEL = 40
local function PageSync(p)
    if p.bar then p.bar:SetState(p.offset, p.view:GetHeight(), p.content:GetHeight()) end
end
local function PageScrollTo(p, want)
    local was = p.offset
    p.offset = max(0, min(max(0, p.content:GetHeight() - p.view:GetHeight()), want))
    p.scroll:SetVerticalScroll(p.offset)
    PageSync(p)
    if p.onScroll and p.offset ~= was then p.onScroll() end
end
local function PageRescroll(p)
    if p.scroll.UpdateScrollChildRect then p.scroll:UpdateScrollChildRect() end
    PageScrollTo(p, p.offset)
end
local function PageWheel(p, delta)
    local was = p.offset
    PageScrollTo(p, p.offset - delta * p.wheel)
    return p.offset ~= was
end
local function PageLaid(p)
    p.laidW = floor(p.view:GetWidth())
end
local function PageRelayout(p)
    if not p.pump then return end
    p.relayoutAt = GetTime() + p.delay
    p.pump:Show()
end
function Kit.ScrollPage(parent, spec)
    spec = spec or {}
    local p = { offset = 0, laidW = 0, wheel = spec.wheel or 40, delay = spec.delay or 0.15, onScroll = spec.onScroll }
    p.Wheel, p.ScrollTo, p.Rescroll, p.Sync = PageWheel, PageScrollTo, PageRescroll, PageSync
    p.Laid, p.Relayout = PageLaid, PageRelayout
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    if spec.fill then scroll:SetAllPoints() end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) PageWheel(p, delta) end)
    p.scroll, p.content = scroll, content
    p.view = spec.fill and parent or scroll
    local bar
    if spec.bar == "deck" then
        local inset = spec.inset or 0
        local deck = CreateFrame("Frame", nil, parent)
        deck:SetFrameLevel(parent:GetFrameLevel() + DECK_LEVEL)
        deck:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -inset)
        deck:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, inset)
        deck:SetWidth(DECK_W)
        bar = Kit.ScrollBar(deck, 1)
        bar:SetPoint("TOPRIGHT", deck, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", deck, "BOTTOMRIGHT", 0, 0)
    elseif spec.bar == "edge" then
        bar = Kit.ScrollBar(parent, 1)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end
    if bar then
        bar.onScroll = function(want) PageScrollTo(p, want) end
        p.bar = bar
    end
    local relayout = spec.relayout
    if relayout then
        local pump = CreateFrame("Frame")
        pump:Hide()
        local function Tick(self)
            if GetTime() < p.relayoutAt then return end
            self:Hide()
            if floor(p.view:GetWidth()) ~= p.laidW then relayout() else PageRescroll(p) end
        end
        pump:SetScript("OnUpdate", spec.prof and ns.Prof.Wrap(spec.prof, Tick) or Tick)
        p.pump, p.relayoutAt = pump, 0
        p.view:HookScript("OnSizeChanged", function() PageRelayout(p) end)
    end
    return p
end
local function ListClamp(l, total, slots)
    l.total, l.slots = total, slots
    l.offset = max(0, min(l.offset, total - slots))
    return l.offset
end
local function ListHide(l)
    for k = 1, #l.rows do
        local r = l.rows[k]
        if l.clear then l.clear(r) end
        r:Hide()
    end
end
local function ListDraw(l, items, slots, total)
    local get = type(items) == "function" and items or nil
    ListClamp(l, total or #items, slots)
    local rows = l.rows
    for k = #rows + 1, slots do rows[k] = l.make(k) end
    for k = 1, #rows do
        local i = k + l.offset
        local item
        if k <= slots and i <= l.total then
            if get then item = get(i) else item = items[i] end
        end
        local r = rows[k]
        if item ~= nil then
            l.fill(r, item, k)
            r:Show()
        else
            if l.clear then l.clear(r) end
            r:Hide()
        end
    end
end
local function ListWheel(l, delta)
    local was = l.offset
    l.offset = max(0, min(max(0, l.total - l.slots), l.offset - delta * l.step))
    return l.offset ~= was
end
function Kit.List(make, fill, spec)
    spec = spec or {}
    local l = { rows = {}, offset = 0, slots = 0, total = 0, step = spec.step or 1, make = make, fill = fill,
                clear = spec.clear }
    l.Clamp, l.Draw, l.Wheel, l.Hide = ListClamp, ListDraw, ListWheel, ListHide
    return l
end
