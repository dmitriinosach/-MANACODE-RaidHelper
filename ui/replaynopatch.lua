local _, ns = ...
local max = math.max
local ceil = math.ceil
local format = string.format
local gsub = string.gsub
local GAP = 2
local LINE_H = 18
local FIELD_H = 20
local NoPatch = {}
ns.ReplayNoPatchView = NoPatch
local Kit = ns.Kit
local m = { line = LINE_H, field = FIELD_H }
local st = { text = nil, x = 0, y = 0, width = 0 }
local row
local fix
local onChange
local function Metrics()
    m.line = max(LINE_H, ceil(Kit.FontSize("GameFontHighlightSmall", true) * 1.2))
    m.field = Kit.GrowH(FIELD_H, "GameFontHighlightSmall")
end
local function FixText()
    local loc = GetLocale and GetLocale() or "enUS"
    return (gsub(ns.T("iso.nopatch.fix"), "{loc}", function() return loc end))
end
local function PlaceFix()
    if not fix then return end
    local inset = Kit.Space.inset
    fix:ClearAllPoints()
    fix:SetPoint("TOPLEFT", fix:GetParent(), "TOPLEFT", st.x, -(st.y + m.line + GAP))
    fix:SetWidth(st.width)
    fix.body:ClearAllPoints()
    fix.body:SetPoint("TOPLEFT", fix, "TOPLEFT", inset, -Kit.Space.cap)
    fix.body:SetWidth(st.width - inset * 2)
    fix.link:ClearAllPoints()
    fix.link:SetPoint("TOPLEFT", fix.body, "BOTTOMLEFT", 0, -Kit.Space.row)
    fix.link:SetPoint("RIGHT", fix, "RIGHT", -inset, 0)
    fix.link:SetHeight(m.field)
    fix.close:ClearAllPoints()
    fix.close:SetPoint("TOPRIGHT", fix, "TOPRIGHT", -6, -6)
    fix:SetHeight(Kit.Space.cap + fix.body:GetStringHeight() + Kit.Space.row + m.field + inset)
end
function NoPatch.Shown()
    return st.text ~= nil
end
function NoPatch.FixShown()
    return fix ~= nil and fix:IsShown() and true or false
end
function NoPatch.Fix(open)
    if not fix then return end
    if open == nil then open = not NoPatch.FixShown() end
    if open and st.text then
        fix.body:SetText(FixText())
        PlaceFix()
        fix:Show()
    else
        fix:Hide()
    end
end
function NoPatch.Height()
    if not st.text then return 0 end
    return m.line + GAP
end
function NoPatch.Place(x, y, width)
    if not row then return end
    Metrics()
    st.x, st.y, st.width = x, y, width
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", x, -y)
    row:SetWidth(width)
    row:SetHeight(m.line)
    row.more:ClearAllPoints()
    row.more:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.text:SetWidth(width - 18 - row.more:GetStringWidth())
    if NoPatch.FixShown() then PlaceFix() end
end
function NoPatch.Use(scene)
    local np = scene and scene.lkNoPatch
    local was = st.text
    st.text = nil
    NoPatch.Fix(false)
    if np and row then
        st.text = format(ns.T("iso.nopatch"), np.who or ns.T("iso.nopatch.who"))
        row.text:SetText(st.text)
        row.tipTitle = st.text
        row.tip = format(ns.T("iso.nopatch.at"), ns.Clock(np.at - scene.pull)) .. "\n\n" .. ns.T("iso.nopatch.tip")
        row:Show()
    elseif row then
        row:Hide()
    end
    if was ~= st.text and onChange then onChange() end
end
function NoPatch.Build(parent, changed)
    onChange = changed
    Metrics()
    row = Kit.Row(parent, 100)
    row.text:SetWordWrap(false)
    Kit.Text(row.text, "text.warn")
    row.more = Kit.Str(row, "GameFontHighlightSmall")
    row.more:SetText(ns.T("iso.nopatch.more"))
    Kit.Text(row.more, "text.title")
    row.onClick = function() NoPatch.Fix() end
    row:SetFrameLevel(parent:GetFrameLevel() + 6)
    row:Hide()
    fix = Kit.Panel(parent, ns.T("iso.nopatch.fix.cap"))
    fix:SetFrameLevel(parent:GetFrameLevel() + 8)
    fix:EnableMouse(true)
    fix.body = Kit.Str(fix, "GameFontHighlightSmall")
    fix.body:SetJustifyH("LEFT")
    fix.body:SetJustifyV("TOP")
    Kit.Text(fix.body, "text.primary")
    fix.link = ns.About.LinkField(fix, ns.About.DATA.release, m.field, ns.T("iso.nopatch.link"), nil)
    fix.close = Kit.CloseButton(fix, function() NoPatch.Fix(false) end)
    fix:Hide()
end
Kit.OnFont(function()
    if not row then return end
    Metrics()
    NoPatch.Place(st.x, st.y, st.width)
end)
function NoPatch.Probe()
    return { row = row, text = st.text, h = NoPatch.Height(), fix = fix, open = NoPatch.FixShown(),
             body = fix and fix.body:GetText() or nil }
end
