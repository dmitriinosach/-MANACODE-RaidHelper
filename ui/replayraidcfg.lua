local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local format = string.format
local W = 300
local PAD = 10
local GAP = 2
local SEC = 6
local ROW = 22
local ROWS = 6
local BAR_W = 6
local COUNT_W = 28
local OPTS = { "mana", "cast", "state" }
local C = {}
ns.ReplayRaidCfg = C
local Kit = ns.Kit
local RR = ns.ReplayRaid
local st = {}
local V = function() return ns.ReplayRaidView end
local function AuraRow(f, k)
    local c = Kit.Check(f)
    Kit.Bind(c.label, "GameFontHighlightSmall")
    c.count = Kit.Str(f, "GameFontHighlightSmall")
    c.count:SetJustifyH("RIGHT")
    Kit.Text(c.count, "text.secondary")
    c.tipTitle = false
    c.label:SetWordWrap(false)
    c.label:SetJustifyH("LEFT")
    c:HookScript("OnShow", function(self) self.count:Show() end)
    c:HookScript("OnHide", function(self) self.count:Hide() end)
    c.slot = k
    return c
end
local function FillAura(c, a)
    local scene, _, want = V().Scene()
    c.aura = a
    c.label:SetText(V().IconText(a.id))
    c.count:SetText(tostring(a.n))
    c:SetChecked(want ~= nil and want[a.key] ~= nil)
    c.tip = format(ns.T("iso.raidauras.who"), a.n)
    c.onToggle = function(on)
        if not scene then return end
        RR.SetPick(a.key, on, scene.fight.boss)
        V().Rewant()
    end
end
local function Head(f, text)
    local fs = Kit.Str(f, "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(ns.T(text))
    Kit.Text(fs, "text.secondary")
    f.heads[#f.heads + 1] = fs
    return fs
end
local function Check(f, key, on)
    local c = Kit.Check(f)
    Kit.Bind(c.label, "GameFontHighlightSmall")
    c.label:SetWordWrap(false)
    c.label:SetJustifyH("LEFT")
    c.label:SetText(ns.T(key))
    c.tip = ns.T(key .. ".tip")
    c.tipTitle = false
    c.onToggle = on
    return c
end
local function Marks(f)
    for i = 1, #f.opts do f.opts[i]:SetChecked(V().Opt(OPTS[i])) end
    local off = RR.GroupsOff()
    local groups = ns.replayRaid.groups
    for i = 1, #f.groups do f.groups[i]:SetChecked(off[groups[i].key] ~= false) end
end
local Draw
local function Place(f)
    local k = max(1, Kit.Grow().wk)
    local row = max(ROW, ceil(Kit.FontSize("GameFontHighlightSmall", true) * 1.3) + 6)
    local strip = max(14, ceil(Kit.FontSize("GameFontNormalSmall", true) + 4))
    local w = ceil(W * k)
    local inner = w - PAD * 2
    f:SetWidth(w)
    f.rects = {}
    local function Rect(name, x, y, rw, rh) f.rects[#f.rects + 1] = { name = name, x = x, y = y, w = rw, h = rh } end
    f.title:ClearAllPoints()
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
    f.title:SetWidth(inner - strip - GAP)
    f.title:SetHeight(strip)
    f.close:SetWidth(strip)
    f.close:SetHeight(strip)
    f.close:ClearAllPoints()
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -PAD)
    local y = PAD + strip + SEC
    local function HeadAt(fs)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
        fs:SetWidth(inner)
        fs:SetHeight(strip)
        y = y + strip
    end
    local function CheckAt(c, labelW)
        c:SetWidth(row - 4)
        c:SetHeight(row - 4)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + 2))
        c.label:SetWidth(labelW)
        Rect("check", PAD, y, inner, row)
        y = y + row
    end
    HeadAt(f.heads[1])
    for i = 1, #f.opts do CheckAt(f.opts[i], inner - row) end
    y = y + SEC
    HeadAt(f.heads[2])
    for i = 1, #f.groups do CheckAt(f.groups[i], inner - row) end
    y = y + SEC
    HeadAt(f.heads[3])
    local listY = y
    local cw = ceil(COUNT_W * k)
    for i = 1, #f.kl.rows do
        local c = f.kl.rows[i]
        local ry = listY + (i - 1) * row
        c:SetWidth(row - 4)
        c:SetHeight(row - 4)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(ry + 2))
        c.count:ClearAllPoints()
        c.count:SetPoint("RIGHT", f, "TOPRIGHT", -(PAD + BAR_W + GAP * 2), -(ry + row / 2))
        c.count:SetWidth(cw)
        c.label:SetWidth(inner - row - cw - BAR_W - GAP * 3)
    end
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -listY)
    f.bar:SetHeight(ROWS * row)
    f.empty:ClearAllPoints()
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(listY + 4))
    f.empty:SetWidth(inner)
    y = listY + ROWS * row + SEC
    local bh = Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
    f.reset:SetWidth(inner)
    f.reset:SetHeight(bh)
    f.reset:ClearAllPoints()
    f.reset:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
    f:SetHeight(y + bh + PAD)
end
Draw = function()
    local f = st.f
    if not (f and f:IsShown()) then return end
    Marks(f)
    f.kl:Draw(f.items, ROWS)
    Place(f)
    f.bar:SetState(f.kl.offset, ROWS, max(ROWS, #f.items))
    if #f.items == 0 then f.empty:Show() else f.empty:Hide() end
end
local function Reset()
    local picks = RR.Picks()
    for key in pairs(picks) do picks[key] = nil end
    local off = RR.GroupsOff()
    for key in pairs(off) do off[key] = nil end
    local s = RR.Saved()
    for i = 1, #OPTS do s[OPTS[i]] = nil end
    V().SetOpt("mana", true)
    V().Rewant()
    local _, R, want = V().Scene()
    if st.f then st.f.items = R and RR.Seen(R, want or {}) or {} end
    Draw()
end
local function Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(parent:GetFrameLevel() + 20)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    Kit.Skin(f, "list")
    f.title = Kit.Str(f, "GameFontNormalSmall")
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.title:SetText(ns.T("iso.raidcfg"))
    Kit.Text(f.title, "text.title")
    f.close = Kit.TabPart(f, "close")
    f.close.tipTitle = ns.T("iso.raidauras.close")
    f.close.tip = ns.T("iso.raidauras.close.tip")
    f.close.onClick = function() f:Hide() end
    f.heads, f.opts, f.groups = {}, {}, {}
    Head(f, "iso.raidcfg.cell")
    Head(f, "iso.raidcfg.groups")
    Head(f, "iso.raidauras")
    for i = 1, #OPTS do
        local key = OPTS[i]
        f.opts[i] = Check(f, "iso.raidcfg." .. key, function(on) V().SetOpt(key, on) end)
    end
    local groups = ns.replayRaid.groups
    for i = 1, #groups do
        local gk = groups[i].key
        f.groups[i] = Check(f, "iso.raidcfg.g." .. gk, function(on)
            if on then RR.GroupsOff()[gk] = nil else RR.GroupsOff()[gk] = false end
            V().Rewant()
            Draw()
        end)
    end
    f.empty = Kit.Str(f, "GameFontHighlightSmall")
    f.empty:SetJustifyH("LEFT")
    f.empty:SetText(ns.T("iso.raidauras.empty"))
    Kit.Text(f.empty, "text.secondary")
    f.bar = Kit.ScrollBar(f, ROWS * ROW)
    f.bar.onScroll = function(offset)
        f.kl.offset = floor(offset + 0.5)
        Draw()
    end
    f.kl = Kit.List(function(k) return AuraRow(f, k) end, function(row, item) FillAura(row, item) end)
    f.reset = Kit.Button(f)
    Kit.ExactSize(f.reset)
    Kit.Bind(f.reset.text, "GameFontNormalSmall")
    f.reset.text:SetText(ns.T("iso.raidauras.reset"))
    f.reset.tip = ns.T("iso.raidauras.reset.tip")
    f.reset.onClick = Reset
    f:SetScript("OnMouseWheel", function(_, delta)
        if f.kl:Wheel(delta) then Draw() end
    end)
    f.items = {}
    f:Hide()
    st.f = f
end
local function Anchor(f, host)
    f.host = host
    f:ClearAllPoints()
    local left = host:GetLeft() or 0
    if left >= (f:GetWidth() or W) + GAP * 2 then
        f:SetPoint("RIGHT", host, "LEFT", -GAP * 2, 0)
    else
        f:SetPoint("LEFT", host, "RIGHT", GAP * 2, 0)
    end
end
function C.Toggle(host)
    if not st.f then Build(ns.ReplayIso.ViewFrame():GetParent()) end
    local f = st.f
    if f:IsShown() then
        f:Hide()
        return
    end
    local _, R, want = V().Scene()
    f.items = R and RR.Seen(R, want or {}) or {}
    f.kl.offset = 0
    f:Show()
    Draw()
    Anchor(f, host)
end
function C.Refresh(host)
    local f = st.f
    if not (f and f:IsShown()) then return end
    if not (host and host:IsShown()) then
        f:Hide()
        return
    end
    Kit.Skin(f, "list")
    Draw()
    Anchor(f, host)
end
function C.Hide()
    if st.f then st.f:Hide() end
end
function C.Probe()
    return { f = st.f }
end
