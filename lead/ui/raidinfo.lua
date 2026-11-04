local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local ICON = 22
local CELL = 27
local WIDE = 52
local LINE = 30
local CAP_W = 96
local BAR_W = 6
local NUM_H = 10
local GAP = 22
local HEAD_PAD = 6
local ROW_GAP = 6
local HILITE = "Interface\\Buttons\\ButtonHilight-Square"
local BASE = "GameFontHighlightSmall"
local CAPF = "GameFontNormalSmall"
local function lineH()
    return ns.Fit(BASE, LINE, 6)
end
local function capW()
    return ns.Wide(CAPF, CAP_W)
end
local function wideW()
    return ns.Wide(BASE, WIDE)
end
local function numH()
    return ns.Fit(BASE, NUM_H, -2)
end
local area, bar, meter
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
local FX_ROWS = { buff = true, debuff = true }
local function srcName(s)
    return ns.Compat.SpellName(ns.Buffs.SpellOf(s.def)) or "?"
end
local function givers(it)
    local out, seen = {}, {}
    for _, s in ipairs(it.src) do
        for _, m in ipairs(s.who) do
            if not seen[m.name] then
                seen[m.name] = true
                out[#out + 1] = m
            end
        end
    end
    return out
end
local function buffTip(c, it)
    local key = it.def.key
    c.tipTitle = ns.T("eff_" .. key)
    local out = {}
    if FX_ROWS[it.row] then out[#out + 1] = ns.Hex("text.muted") .. ns.T("effFx_" .. key) .. "|r" end
    local here, gone = {}, {}
    for _, s in ipairs(it.src) do
        if #s.who > 0 then
            local line = ns.T("effSrc", srcName(s), named(s.who))
            if s.def.party then line = line .. ns.Hex("text.muted") .. ns.T("effParty") .. "|r" end
            here[#here + 1] = "  " .. line
        elseif not it.short then
            gone[#gone + 1] = "  " .. ns.T("effSrc", srcName(s), treeName(s.def.cls, s.def.tree))
        end
    end
    if #here > 0 then
        out[#out + 1] = ns.T("effHave")
        for _, l in ipairs(here) do out[#out + 1] = l end
    end
    if it.short then out[#out + 1] = ns.Hex("text.warn") .. ns.T("effPalShort", it.short) .. "|r" end
    if #gone > 0 then
        out[#out + 1] = ns.Hex("text.muted") .. ns.T("effCan") .. "|r"
        for _, l in ipairs(gone) do out[#out + 1] = ns.Hex("text.muted") .. l .. "|r" end
    end
    if #it.unsure > 0 then out[#out + 1] = ns.T("effUnsure", named(it.unsure)) end
    if it.pals then out[#out + 1] = ns.Hex("text.muted") .. ns.T("effPals", it.pals) .. "|r" end
    c.tip = table.concat(out, "\n")
    c.tipDim = nil
end
local function headTip(c, g)
    c.tipTitle = ns.T("effGrp_" .. g.key) .. "  " .. g.have .. "/" .. g.total
    local out = {}
    for _, it in ipairs(g.items) do
        local name = ns.T("eff_" .. it.def.key)
        local state = ns.Buffs.State(it)
        if state == "full" then
            out[#out + 1] = ns.T("effSrc", name, named(givers(it)))
        elseif state == "unsure" then
            out[#out + 1] = ns.Hex("text.warn") .. ns.T("effSrc", name, "?") .. "|r"
        else
            out[#out + 1] = ns.Hex("text.muted") .. ns.T("effSrc", name, ns.T("effNone")) .. "|r"
        end
    end
    c.tip = table.concat(out, "\n")
    c.tipDim = nil
end
local function specList(specs)
    local out = {}
    for k, s in ipairs(specs) do out[k] = ns.T("spec_" .. s) end
    return table.concat(out, ", ")
end
local function reqTip(c, r)
    c.tipTitle = r.specs and specList(r.specs) or ns.T("tplAny", ns.T("slot_" .. r.role))
    local out = { ns.T("tplHave", r.have, r.need) }
    if #r.who > 0 then
        local list = {}
        for k, name in ipairs(r.who) do
            local m = ns.Session.Member(name)
            list[k] = m and ns.RaidPane.ColoredName(m) or name
        end
        out[#out + 1] = table.concat(list, ", ")
    end
    if r.need > r.have then out[#out + 1] = ns.T("tplMiss", r.need - r.have) end
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
    c.box:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 0, 0)
    c.num = ns.Str(c, BASE)
    c.num:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 0, 0)
    c.num:SetJustifyH("RIGHT")
    c.side = ns.Str(c, BASE)
    c.side:SetPoint("LEFT", c.icon, "RIGHT", 3, 0)
    c.side:SetJustifyH("LEFT")
    c.cap = ns.Str(c, CAPF)
    c.cap:SetPoint("LEFT", c, "LEFT", 0, 0)
    c.cap:SetJustifyH("LEFT")
    c.cap:SetWordWrap(false)
    ns.PaintText(c.cap, "text.secondary")
    c.cnt = ns.Str(c, CAPF)
    c.cnt:SetPoint("LEFT", c.cap, "RIGHT", 4, 0)
    c.cnt:SetJustifyH("LEFT")
    c:SetHighlightTexture(HILITE, "ADD")
    c:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    c:SetScript("OnLeave", ns.TipHide)
    cells[i] = c
    return c
end
local function newCap(i)
    local fs = ns.Str(area, CAPF)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    ns.PaintText(fs, "text.secondary")
    caps[i] = fs
    return fs
end
local function asHead(c, on)
    if on then
        c.icon:Hide()
        c.num:Hide()
        c.box:Hide()
        c.side:Hide()
        c.cap:Show()
        c.cnt:Show()
    else
        c.icon:Show()
        c.cap:Hide()
        c.cnt:Hide()
    end
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
    c.box:SetHeight(numH())
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
    asHead(c, false)
    ns.Kit.Icon.Spell(c.icon, ns.Buffs.SpellOf(it.def.src[1]))
    local state = ns.Buffs.State(it)
    if state == "full" then
        dim(c, false, 1)
        setCount(c, it.count and tostring(it.have) or nil, "text.primary")
    elseif state == "unsure" then
        dim(c, true, 0.7)
        setCount(c, "?", "text.warn")
    else
        dim(c, true, 0.35)
        setCount(c, nil)
    end
    buffTip(c, it)
end
local function headToken(g)
    if g.have >= g.total then return "sem.ready" end
    if g.have > 0 then return "text.warn" end
    return "sem.notReady"
end
local function fillHead(c, g)
    asHead(c, true)
    c.cap:SetText(ns.T("effGrp_" .. g.key))
    c.cnt:SetText(g.have .. "/" .. g.total)
    ns.PaintText(c.cnt, headToken(g))
    headTip(c, g)
end
local function fillReq(c, r)
    asHead(c, false)
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
    asHead(c, false)
    ns.Icon.Spec(c.icon, s.key)
    dim(c, false, 1)
    setSide(c, tostring(#s.who), "text.primary")
    c.tipTitle = ns.T("specFull_" .. s.key)
    c.tip = named(s.who)
    c.tipDim = nil
end
local function fillUnknown(c, list)
    asHead(c, false)
    c.icon:SetTexture(ns.QMARK)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    dim(c, false, 1)
    setSide(c, tostring(#list), "text.warn")
    c.tipTitle = ns.T("specUnknown")
    c.tip = named(list)
    c.tipDim = nil
end
local function textW(s)
    meter:SetText(s)
    return math.ceil(meter:GetStringWidth() or 0)
end
local function headW(g)
    return textW(ns.T("effGrp_" .. g.key)) + 4 + textW(g.have .. "/" .. g.total) + HEAD_PAD
end
local function room()
    return width - capW() - BAR_W - 4
end
local function newLine(cap)
    local line = { cap = cap, items = {} }
    lines[#lines + 1] = line
    return line
end
local function addRow(cap, list, w, fill)
    local line, x = newLine(cap), 0
    for _, v in ipairs(list) do
        if x + w > room() and #line.items > 0 then
            line, x = newLine(), 0
        end
        line.items[#line.items + 1] = { v = v, w = w, fill = fill, gap = 0 }
        x = x + w
    end
    return line
end
local function addGroups(cap, row)
    local cell = ns.Wide(BASE, CELL)
    local line, x = newLine(cap), 0
    for _, g in ipairs(row.groups) do
        local hw = headW(g)
        local gap = x > 0 and GAP or 0
        if x > 0 and x + gap + hw + #g.items * cell > room() then
            line, x, gap = newLine(), 0, 0
        end
        line.items[#line.items + 1] = { v = g, w = hw, fill = fillHead, gap = gap, head = true }
        x = x + gap + hw
        for _, it in ipairs(g.items) do
            if x + cell > room() and #line.items > 0 then line, x = newLine(), 0 end
            it.count = row.count
            line.items[#line.items + 1] = { v = it, w = cell, fill = fillBuff, gap = 0 }
            x = x + cell
        end
    end
end
local function collect()
    for i = #lines, 1, -1 do lines[i] = nil end
    local list = ns.Buffs.Members()
    if #list == 0 then return end
    for _, row in ipairs(ns.Buffs.Rows(list)) do
        addGroups(ns.T("effRow_" .. row.key), row)
    end
    local comp = ns.Buffs.Comp(list)
    addRow(ns.T("effRowTpl"), comp.reqs, wideW(), fillReq)
    local last = addRow(ns.T("effRowSpecs"), comp.specs, wideW(), fillSpec)
    if #comp.unknown > 0 then
        last = lines[#lines]
        last.items[#last.items + 1] = { v = comp.unknown, w = wideW(), fill = fillUnknown }
    end
end
local function fitFrom(from)
    local LINE = lineH()
    local y, n = 0, 0
    for k = from + 1, #lines do
        local pad = (n > 0 and lines[k].cap) and ROW_GAP or 0
        if y + pad + LINE > height then break end
        y, n = y + pad + LINE, n + 1
    end
    return n, y
end
local function draw()
    local LINE = lineH()
    local maxOff = 0
    while maxOff < #lines and maxOff + fitFrom(maxOff) < #lines do maxOff = maxOff + 1 end
    if offset > maxOff then offset = maxOff end
    if offset < 0 then offset = 0 end
    local shown, usedH = fitFrom(offset)
    visible = math.max(1, shown)
    local used, capUsed = 0, 0
    local y = 0
    for n = 1, shown do
        local line = lines[offset + n]
        if n > 1 and line.cap then y = y - ROW_GAP end
        if line.cap then
            capUsed = capUsed + 1
            local fs = caps[capUsed] or newCap(capUsed)
            fs:SetText(line.cap)
            fs:SetWidth(capW() - 4)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", area, "TOPLEFT", 0, y - math.max(0, math.floor((LINE - ns.LineH(CAPF)) / 2)))
            fs:Show()
        end
        local x = capW()
        for _, e in ipairs(line.items) do
            x = x + (e.gap or 0)
            used = used + 1
            local c = cells[used] or newCell(used)
            c:SetSize(e.w, LINE)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", area, "TOPLEFT", x, y)
            e.fill(c, e.v)
            c:Show()
            x = x + e.w
        end
        y = y - LINE
    end
    for i = used + 1, #cells do cells[i]:Hide() end
    for i = capUsed + 1, #caps do caps[i]:Hide() end
    bar:SetHeight(math.max(LINE, usedH))
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
    meter = ns.Str(area, CAPF)
    meter:Hide()
    bar = ns.Kit.ScrollBar(area, lineH())
    bar:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
    bar.onScroll = scrollTo
    built = true
end
local function place(pane, top, w, h)
    if not built then build(pane) end
    width, height = w, math.max(lineH(), h)
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
