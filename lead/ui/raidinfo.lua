local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local ICON = 20
local CELL = 23
local WIDE = 52
local LINE = 24
local CAP_W = 62
local BAR_W = 6
local NUM_H = 10
local HILITE = "Interface\\Buttons\\ButtonHilight-Square"
local area, bar
local cells, caps = {}, {}
local lines = {}
local offset, visible = 0, 0
local width, height = 0, 0
local built = false
local function named(list)
    local out = {}
    for k, m in ipairs(list) do out[k] = ns.RaidPane.ColoredName(m) end
    return table.concat(out, ", ")
end
local function treeName(cls, tree)
    local s = ns.T("cls_" .. cls)
    if tree then s = s .. ": " .. ns.T("tree_" .. cls .. tree) end
    return s
end
local function buffTip(c, it)
    local def = it.def
    c.tipTitle = ns.T("rb_" .. def.key)
    local out = {}
    if def.fx then out[#out + 1] = ns.T("rbFx_" .. def.key) end
    for _, s in ipairs(it.src) do
        local name = ns.Compat.SpellName(ns.Buffs.SpellOf(s.def)) or "?"
        local who = #s.who > 0 and named(s.who) or (ns.Hex("text.muted") .. ns.T("rbNone") .. "|r")
        out[#out + 1] = ns.T("rbSrc", name, treeName(s.def.cls, s.def.tree), who)
    end
    if #it.unsure > 0 then out[#out + 1] = ns.T("rbUnsure", named(it.unsure)) end
    if def.bless then out[#out + 1] = ns.T("rbPals", it.pals) end
    c.tip = table.concat(out, "\n")
    c.tipDim = nil
end
local function specList(specs)
    local out = {}
    for k, s in ipairs(specs) do out[k] = ns.T("spec_" .. s) end
    return table.concat(out, ", ")
end
local function reqTip(c, r)
    c.tipTitle = r.specs and specList(r.specs) or ns.T("rbAny", ns.T("slot_" .. r.role))
    local out = { ns.T("rbReqHave", r.have, r.need) }
    if #r.who > 0 then
        local list = {}
        for k, name in ipairs(r.who) do
            local m = ns.Session.Member(name)
            list[k] = m and ns.RaidPane.ColoredName(m) or name
        end
        out[#out + 1] = table.concat(list, ", ")
    end
    if r.need > r.have then out[#out + 1] = ns.T("rbReqMiss", r.need - r.have) end
    c.tip = table.concat(out, "\n")
    c.tipDim = nil
end
local function newCell(i)
    local c = ns.NewFrame("Button", nil, area)
    c:SetSize(CELL, CELL)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("LEFT", c, "LEFT", 1, 0)
    c.box = ns.Fill(c, "OVERLAY")
    ns.PaintToken(c.box, "surface.shade")
    c.box:SetHeight(NUM_H)
    c.box:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 0, 0)
    c.num = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.num:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 0, 0)
    c.num:SetJustifyH("RIGHT")
    c.side = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.side:SetPoint("LEFT", c.icon, "RIGHT", 3, 0)
    c.side:SetJustifyH("LEFT")
    c:SetHighlightTexture(HILITE, "ADD")
    c:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    c:SetScript("OnLeave", ns.TipHide)
    cells[i] = c
    return c
end
local function newCap(i)
    local fs = area:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetWidth(CAP_W - 4)
    fs:SetJustifyH("LEFT")
    ns.PaintText(fs, "text.secondary")
    caps[i] = fs
    return fs
end
local function setCount(c, text, token)
    c.side:Hide()
    if not text then
        c.num:Hide()
        c.box:Hide()
        return
    end
    c.num:SetText(text)
    ns.PaintText(c.num, token)
    c.num:Show()
    c.box:SetWidth((c.num:GetStringWidth() or 6) + 2)
    c.box:Show()
end
local function setSide(c, text, token)
    c.num:Hide()
    c.box:Hide()
    c.side:SetText(text)
    ns.PaintText(c.side, token)
    c.side:Show()
end
local function dim(c, on, alpha)
    c.icon:SetDesaturated(on)
    c.icon:SetAlpha(alpha)
end
local function fillBuff(c, it)
    ns.Kit.Icon.Spell(c.icon, ns.Buffs.SpellOf(it.def.src[1]))
    if it.have > 0 then
        dim(c, false, 1)
        setCount(c, tostring(it.have), "text.primary")
    elseif #it.unsure > 0 then
        dim(c, true, 0.7)
        setCount(c, "?", "text.warn")
    else
        dim(c, true, 0.35)
        setCount(c, nil)
    end
    buffTip(c, it)
end
local function fillReq(c, r)
    if r.specs and #r.specs == 1 then
        ns.Icon.Spec(c.icon, r.specs[1])
    else
        ns.Icon.Role(c.icon, ns.ROLE_GROUP[r.role])
    end
    dim(c, r.have == 0, r.have == 0 and 0.6 or 1)
    setSide(c, r.have .. "/" .. r.need, r.have >= r.need and "sem.ready" or "sem.notReady")
    reqTip(c, r)
end
local function fillSpec(c, s)
    ns.Icon.Spec(c.icon, s.key)
    dim(c, false, 1)
    setSide(c, tostring(#s.who), "text.primary")
    c.tipTitle = ns.T("specFull_" .. s.key)
    c.tip = named(s.who)
    c.tipDim = nil
end
local function fillUnknown(c, list)
    c.icon:SetTexture(ns.QMARK)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    dim(c, false, 1)
    setSide(c, tostring(#list), "text.warn")
    c.tipTitle = ns.T("rbUnknown")
    c.tip = named(list)
    c.tipDim = nil
end
local function addRow(cap, list, w, fill)
    local room = width - CAP_W - BAR_W - 4
    local line = { cap = cap, items = {} }
    lines[#lines + 1] = line
    local x = 0
    for _, v in ipairs(list) do
        if x + w > room and #line.items > 0 then
            line = { items = {} }
            lines[#lines + 1] = line
            x = 0
        end
        line.items[#line.items + 1] = { v = v, w = w, fill = fill }
        x = x + w
    end
    return line
end
local function collect()
    for i = #lines, 1, -1 do lines[i] = nil end
    local list = ns.Buffs.Members()
    for _, row in ipairs(ns.Buffs.Rows(list)) do
        addRow(ns.T("rbRow_" .. row.key), row.items, CELL, fillBuff)
    end
    local comp = ns.Buffs.Comp(list)
    addRow(ns.T("rbRowTpl"), comp.reqs, WIDE, fillReq)
    local last = addRow(ns.T("rbRowRaid"), comp.specs, WIDE, fillSpec)
    if #comp.unknown > 0 then
        last = lines[#lines]
        last.items[#last.items + 1] = { v = comp.unknown, w = WIDE, fill = fillUnknown }
    end
end
local function draw()
    visible = math.max(1, math.floor(height / LINE))
    local maxOff = math.max(0, #lines - visible)
    if offset > maxOff then offset = maxOff end
    if offset < 0 then offset = 0 end
    local used, capUsed = 0, 0
    for n = 1, visible do
        local line = lines[offset + n]
        if not line then break end
        local y = -(n - 1) * LINE
        if line.cap then
            capUsed = capUsed + 1
            local fs = caps[capUsed] or newCap(capUsed)
            fs:SetText(line.cap)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", area, "TOPLEFT", 0, y - 6)
            fs:Show()
        end
        local x = CAP_W
        for _, e in ipairs(line.items) do
            used = used + 1
            local c = cells[used] or newCell(used)
            c:SetWidth(e.w)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", area, "TOPLEFT", x, y)
            e.fill(c, e.v)
            c:Show()
            x = x + e.w
        end
    end
    for i = used + 1, #cells do cells[i]:Hide() end
    for i = capUsed + 1, #caps do caps[i]:Hide() end
    bar:SetHeight(visible * LINE)
    bar:SetState(offset, visible, #lines)
end
local function refresh()
    if not built or not area:IsVisible() then return end
    collect()
    draw()
end
local function scrollTo(v)
    offset = v
    if built then draw() end
end
local function onWheel(_, delta)
    scrollTo(offset - delta)
end
local function build(pane)
    area = ns.NewFrame("Frame", nil, pane)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", onWheel)
    bar = ns.Kit.ScrollBar(area, LINE)
    bar:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
    bar.onScroll = scrollTo
    built = true
end
local function place(pane, top, w, h)
    if not built then build(pane) end
    width, height = w, math.max(LINE, h)
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    area:SetSize(w, height)
end
ns.RaidInfo = {
    Place = place,
    Refresh = refresh,
    Lines = function() return lines end,
    Cells = function() return cells end,
    Scroll = scrollTo,
    Offset = function() return offset end,
}
