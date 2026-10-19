local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local ceil = math.ceil
local ROWS = 5
local PAD = 6
local GAP = 2
local TIP_EPISODES = 5
local LINE_H = 18
local Pos = {}
ns.ReplayPosView = Pos
local Kit = ns.Kit
local m = { line = LINE_H, row = LINE_H * 2 + 4 }
local st = { eps = {}, tot = nil, text = nil, scene = nil, open = false, top = 1, width = 0, x = 0, y = 0 }
local lineRow, panel, onSeek, onChange
local rows = {}
local function Metrics()
    local pt = Kit.FontSize("GameFontHighlightSmall", true)
    m.line = max(LINE_H, ceil(pt * 1.2))
    m.row = m.line * 2 + 4
end
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
local function Dev()
    local iso = ns.ReplayIso
    if iso and iso.dev then return true end
    local dev = ns.DevTool
    return dev ~= nil and dev.IsShown ~= nil and dev.IsShown() == true
end
function Pos.On()
    return Saved().pos ~= false
end
function Pos.SetOn(on)
    Saved().pos = on and true or false
    Pos.Apply()
end
function Pos.Shown()
    return st.text ~= nil and Pos.On()
end
function Pos.Height()
    if not Pos.Shown() then return 0 end
    return m.line + GAP
end
local function Ctx()
    local raid = st.scene and st.scene.fight and st.scene.fight.raid
    return { raid = raid and raid.name or nil }
end
local function TailAt(fight)
    local s = fight and ns.Summary and ns.Summary.Peek(fight)
    if not (s and s.players) then return nil end
    local at
    for i = 1, #s.players do
        local info = s.players[i].deathInfo
        for k = 1, info and #info or 0 do
            local d = info[k]
            if d.tail and (not at or d.t < at) then at = d.t end
        end
    end
    return at
end
local function RowClick(self)
    local ep = self.idx and st.eps[self.idx]
    if ep and st.scene and onSeek then onSeek(ep.lost - st.scene.pull) end
end
local function NewRow(w)
    local row = Kit.Row(panel, w)
    row.text:SetWordWrap(true)
    row.text:SetJustifyV("TOP")
    row.onClick = RowClick
    row:Hide()
    return row
end
local function PlaceRows()
    local w = st.width - PAD * 2
    for r = 1, #rows do
        local row = rows[r]
        row:SetWidth(w)
        row:SetHeight(m.row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(PAD + (r - 1) * m.row))
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
        row.text:SetWidth(w - 8)
        row.text:SetHeight(m.row - 4)
    end
end
local function Draw()
    if not panel then return end
    local n = #st.eps
    local shown = min(ROWS, n)
    st.top = max(1, min(st.top, n - ROWS + 1))
    local ctx = Ctx()
    for r = 1, #rows do
        local row = rows[r]
        local i = st.top + r - 1
        local ep = r <= shown and st.eps[i] or nil
        if ep then
            row.idx = i
            row.text:SetText(ns.PosFix.EpisodeText(ep, ctx))
            Kit.Text(row.text, ep.noise and "text.muted" or ((ep.kind == "fixed") and "text.primary" or "text.warn"))
            row.tip = ns.PosFix.EpisodeText(ep, ctx) .. "\n\n" .. ns.PosFix.EpisodeTip(ep, ctx)
            row.on = false
            Kit.StyleRow(row)
            row:Show()
        else
            row.idx = nil
            row:Hide()
        end
    end
    panel:SetWidth(st.width)
    panel:SetHeight(PAD * 2 + shown * m.row)
end
local function Wheel(_, delta)
    if #st.eps <= ROWS then return end
    st.top = max(1, min(#st.eps - ROWS + 1, st.top - delta))
    Draw()
end
local function LineTip()
    local ctx = Ctx()
    local out, n = {}, 0
    for i = 1, #st.eps do
        local ep = st.eps[i]
        if not ep.noise then
            n = n + 1
            if n <= TIP_EPISODES then
                out[#out + 1] = ns.PosFix.EpisodeText(ep, ctx) .. "\n" .. ns.PosFix.EpisodeTip(ep, ctx)
            end
        end
    end
    if n > TIP_EPISODES then out[#out + 1] = string.format(ns.T("iso.pos.more"), n - TIP_EPISODES) end
    out[#out + 1] = ns.T("iso.pos.click")
    lineRow.tipTitle = ns.PosFix.TotalLine(st.tot)
    lineRow.tip = table.concat(out, "\n\n")
end
local function Close()
    st.open = false
    if panel then panel:Hide() end
end
local function Toggle()
    if st.open then
        Close()
        return
    end
    if #st.eps == 0 then return end
    st.open = true
    Draw()
    panel:Show()
end
function Pos.Place(x, y, width)
    if not lineRow then return end
    Metrics()
    st.x, st.y, st.width = x, y, width
    lineRow:ClearAllPoints()
    lineRow:SetPoint("TOPLEFT", lineRow:GetParent(), "TOPLEFT", x, -y)
    lineRow:SetWidth(width)
    lineRow:SetHeight(m.line)
    lineRow.text:ClearAllPoints()
    lineRow.text:SetPoint("LEFT", lineRow, "LEFT", 6, 0)
    lineRow.text:SetWidth(width - 12)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", lineRow, "BOTTOMLEFT", 0, -1)
    PlaceRows()
    if st.open then Draw() end
end
function Pos.Apply()
    if not lineRow then return end
    if st.text and Pos.On() then
        lineRow.text:SetText(st.text)
        LineTip()
        lineRow:Show()
    else
        lineRow:Hide()
        Close()
    end
    if onChange then onChange() end
end
function Pos.Use(scene)
    st.scene, st.eps, st.tot, st.text = scene, {}, nil, nil
    Close()
    if scene and scene.layers and ns.PosFix then
        st.eps = ns.PosFix.Episodes(scene.layers, scene.pull, TailAt(scene.fight))
        st.tot = ns.PosFix.Totals(st.eps)
        st.text = ns.PosFix.Line(st.eps, Dev())
    end
    st.top = 1
    Pos.Apply()
end
function Pos.Build(parent, seek, changed)
    onSeek, onChange = seek, changed
    Metrics()
    lineRow = Kit.Row(parent, 100)
    lineRow.text:SetWordWrap(false)
    lineRow.onClick = Toggle
    lineRow:SetFrameLevel(parent:GetFrameLevel() + 6)
    lineRow:Hide()
    panel = CreateFrame("Frame", nil, parent)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", Wheel)
    Kit.Skin(panel, "list")
    panel:SetWidth(100)
    panel:SetHeight(PAD * 2 + m.row)
    for r = 1, ROWS do rows[r] = NewRow(100) end
    panel:Hide()
end
Kit.OnFont(function()
    if not lineRow then return end
    Metrics()
    Pos.Place(st.x, st.y, st.width)
end)
function Pos.Probe()
    return { line = lineRow, panel = panel, rows = rows, eps = st.eps, tot = st.tot, text = st.text, open = st.open,
             h = Pos.Height() }
end
