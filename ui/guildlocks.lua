local _, ns = ...
local format = string.format
local max = math.max
local concat = table.concat
local tsort = table.sort
local Kit = ns.Kit
local GL = ns.GuildLocks
local GR = ns.GuildRaid
local GN = ns.GuildNotes
local N = ns.guildNotes
local D = ns.guildLocks
local MARGIN = 12
local CAP_H = 22
local CTRL_H = 28
local SLOT_H = 22
local MAIN_H = 20
local ALT_H = 18
local NOTE_H = 18
local TEXT_X = 8
local FOLD = 14
local NAME_X = 22
local INDENT = 16
local NAME_W = 140
local ON_W = 150
local GS_W = 56
local SPEC_W = 170
local ALTS_W = 40
local STATE_W = 150
local SEL_W = 150
local CHECK_W = 130
local REBUILD_GAP = 5
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local View = {}
ns.GuildLockView = View
local content
local caption, sel, gsFs, check, ticker
local rerender
local pools = { slot = {}, main = {}, alt = {}, note = {} }
local used = { slot = 0, main = 0, alt = 0, note = 0 }
local open = {}
local cache = nil
local builtAt = -1e9
local dirty = true
local function Make(kind)
    local row = Kit.Row(content, 100)
    local n = (kind == "main" and 6) or (kind == "alt" and 5) or 1
    row.cols = {}
    for i = 1, n do
        local fs = row:CreateFontString(nil, "OVERLAY", kind == "main" and "GameFontNormal" or "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetHeight(14)
        Kit.Text(fs, "text.primary")
        row.cols[i] = fs
    end
    row.text:Hide()
    if kind == "main" then
        row.fold = row:CreateTexture(nil, "ARTWORK")
        row.fold:SetWidth(FOLD)
        row.fold:SetHeight(FOLD)
        row.fold:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.onClick = function(r)
            local p = r.person
            if p and #p.chars > 1 then
                open[p.name] = not open[p.name] or nil
                if rerender then rerender() end
            end
        end
    end
    row:SetHeight((kind == "main" and MAIN_H) or (kind == "alt" and ALT_H) or (kind == "slot" and SLOT_H) or NOTE_H)
    return row
end
local function Take(kind, y, w)
    used[kind] = used[kind] + 1
    local pool = pools[kind]
    local row = pool[used[kind]]
    if not row then
        row = Make(kind)
        pool[used[kind]] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    row:SetWidth(w)
    row.tipTitle, row.tip, row.tipLines, row.person = false, nil, nil, nil
    row:Show()
    return row
end
local function HideAll()
    for kind, pool in pairs(pools) do
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
end
local function Put(fs, x, width, text, token, right)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", fs:GetParent(), "LEFT", x, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(right and "RIGHT" or "LEFT")
    fs:SetText(text)
    if token then Kit.Text(fs, token) end
    fs:Show()
end
local function Src(src)
    local key = "gl.src." .. tostring(src or "other")
    local s = ns.T(key)
    if s == key then return ns.T("gl.src.other") end
    return s
end
local function SpecName(spec, class)
    local sp = N.specs[spec]
    class = class or (sp and sp.class)
    local trees = class and N.trees[class]
    if not trees then return nil end
    local want = (spec == "bear" or spec == "cat") and "feral" or spec
    for i = 1, #trees do
        if trees[i] == want then return ns.T("spec." .. class .. "." .. i) end
    end
    return nil
end
local function SlotLabel(slot)
    local L = ns.Lead
    local cap = L and L.Tpl and L.Tpl.Cap and L.Tpl.Cap(slot)
    local base = cap or ns.T("gl.role." .. tostring(slot.role or "dd"))
    if type(slot.specs) ~= "table" or not slot.specs[1] then return base end
    local names, seen = {}, {}
    for i = 1, #slot.specs do
        local s = SpecName(slot.specs[i])
        if s and not seen[s] then
            seen[s] = true
            names[#names + 1] = s
        end
    end
    if #names == 0 then return base end
    return base .. " (" .. concat(names, "/") .. ")"
end
local function TplName(tpl)
    local L = ns.Lead
    if L and L.Tpl and L.Tpl.Name then return L.Tpl.Name(tpl) end
    return tostring(tpl.name or tpl.key or "?")
end
local function Order(a, b)
    if (a.online ~= nil) ~= (b.online ~= nil) then return a.online ~= nil end
    return a.name < b.name
end
local function Rebuild()
    builtAt, dirty = GetTime(), false
    local r = GR.Get(GR.Pick())
    local q = GR.Query(r)
    local gsMin = GL.GsMin(q)
    local people = GL.Available(q, gsMin, true)
    local onl = {}
    for i = 1, #people do
        if people[i].online then onl[#onl + 1] = people[i] end
    end
    tsort(people, Order)
    local tpl = GR.Template(r)
    cache = { raid = r, q = q, gsMin = gsMin, people = people, online = #onl, tpl = tpl,
        slots = tpl and GL.Slots(tpl, onl) or nil }
end
local function Schedule()
    if ticker and not ticker:IsShown() then ticker:Show() end
end
local function State(c)
    if (c.level or 0) < D.level then return format(ns.T("cd.level"), c.level or 0), "text.off" end
    if c.saved == true then return format(ns.T("gl.state.saved"), ns.Date(c.save and c.save.ends)), "text.bad" end
    if c.saved == false then return ns.T("gl.state.free"), "text.good" end
    return ns.T("gl.state.unknown"), "text.off"
end
local function SpecText(c)
    local s = c.spec and SpecName(c.spec, c.class)
    if s then return s end
    if c.role then return ns.T("gl.role." .. c.role) end
    return "—"
end
local function CharLines(c, main)
    local lines = {}
    if main then lines[#lines + 1] = format(ns.T("gl.tip.main"), main, Src(c.link)) end
    lines[#lines + 1] = ns.T(c.online and "gl.tip.on" or "gl.tip.off")
    lines[#lines + 1] = format(ns.T("gl.tip.level"), c.level or 0)
    if c.gs then
        lines[#lines + 1] = format(ns.T("gl.tip.gs"), c.gs, Src(c.gsSrc))
        if c.gsOk == false then lines[#lines + 1] = format(ns.T("gl.tip.gs.low"), cache and cache.gsMin or 0) end
    else
        lines[#lines + 1] = ns.T("gl.tip.gs.none")
    end
    local s = c.spec and SpecName(c.spec, c.class)
    if s then
        lines[#lines + 1] = format(ns.T("gl.tip.spec"), s, Src(c.roleSrc))
    elseif c.role then
        lines[#lines + 1] = format(ns.T("gl.tip.role"), ns.T("gl.role." .. c.role), Src(c.roleSrc))
    else
        lines[#lines + 1] = ns.T("gl.tip.role.none")
    end
    local label = cache and GR.Label(cache.raid) or ""
    local v = c.save
    if c.saved == true and v then
        lines[#lines + 1] = format(ns.T("gl.tip.save"), label, v.id, ns.Date(v.ends, "dayTime"), Src(v.src))
    elseif c.saved == false and v then
        lines[#lines + 1] = format(ns.T("gl.tip.same"), label, v.id)
    elseif c.saved == false then
        lines[#lines + 1] = format(ns.T("gl.tip.free"), label)
    else
        lines[#lines + 1] = format(ns.T("gl.tip.unknown"), label)
    end
    return lines
end
local function FillChar(row, c, x, w)
    local cols = row.cols
    Put(cols[1], x, NAME_W - (x - NAME_X), c.name)
    Kit.ClassText(cols[1], c.class)
    Put(cols[3], NAME_X + NAME_W + ON_W, GS_W, c.gs and tostring(c.gs) or "—",
        c.gsOk == false and "text.warn" or "text.secondary")
    Put(cols[4], NAME_X + NAME_W + ON_W + GS_W, SPEC_W, SpecText(c), "text.secondary")
    local state, token = State(c)
    Put(cols[5], w - STATE_W - 6, STATE_W, state, token, true)
end
local function Split(p)
    local main, alts = nil, {}
    for i = 1, #p.chars do
        local c = p.chars[i]
        if c.name == p.name then main = c else alts[#alts + 1] = c end
    end
    return main, alts
end
local function DrawPerson(p, y, w)
    local row = Take("main", y, w)
    row.person = p
    local main, alts = Split(p)
    local cols = row.cols
    if main then
        FillChar(row, main, NAME_X, w)
        row.tipLines = CharLines(main, nil)
    else
        Put(cols[1], NAME_X, NAME_W, p.name, "text.primary")
        for i = 3, 5 do cols[i]:SetText("") end
        row.tipLines = {}
    end
    local on, token = ns.T("gl.off"), "text.off"
    if p.online == p.name then
        on, token = ns.T("gl.on"), "text.good"
    elseif p.online then
        on, token = format(ns.T("gl.on.alt"), p.online), "text.good"
    end
    Put(cols[2], NAME_X + NAME_W, ON_W, on, token)
    Put(cols[6], NAME_X + NAME_W + ON_W + GS_W + SPEC_W, ALTS_W, #alts > 0 and format(ns.T("gl.alts"), #alts) or "",
        "text.muted")
    if #alts > 0 then
        row.fold:SetTexture(open[p.name] and MINUS or PLUS)
        row.fold:Show()
        local names = {}
        for i = 1, #alts do names[i] = alts[i].name end
        row.tipLines[#row.tipLines + 1] = format(ns.T("gl.tip.alts"), concat(names, ", "))
    else
        row.fold:Hide()
    end
    row.tipTitle = p.name
    y = y + MAIN_H
    if open[p.name] then
        for i = 1, #alts do
            local c = alts[i]
            local r = Take("alt", y, w)
            FillChar(r, c, NAME_X + INDENT, w)
            Put(r.cols[2], NAME_X + NAME_W, ON_W, ns.T(c.online and "gl.on" or "gl.off"), c.online and "text.good" or "text.off")
            r.tipTitle = c.name
            r.tipLines = CharLines(c, p.name)
            y = y + ALT_H
        end
    end
    return y
end
local function DrawSlots(y, w)
    local row = Take("slot", y, w)
    local c = cache
    if not c or not c.tpl or not c.slots then
        Put(row.cols[1], TEXT_X, w - TEXT_X, format(ns.T("gl.slots.notpl"), c and c.raid.size or 0), "text.muted")
        return y + SLOT_H
    end
    local s = c.slots
    Put(row.cols[1], TEXT_X, w - TEXT_X, format(ns.T("gl.slots"), s.filled, s.total, s.have.tank, s.need.tank,
        s.have.heal, s.need.heal, s.have.dd, s.need.dd), s.filled >= s.total and "text.good" or "text.primary")
    row.tipTitle = format(ns.T("gl.slots.tipTitle"), GR.Label(c.raid), TplName(c.tpl))
    local lines = { format(ns.T("gl.slots.tip.online"), c.online), format(ns.T("gl.gs"), c.gsMin) }
    local took = {}
    if #s.picks > 0 then lines[#lines + 1] = ns.T("gl.slots.tip.picks") end
    for i = 1, #s.picks do
        local pk = s.picks[i]
        took[pk.slot] = true
        local who = pk.char == pk.person and pk.person or format("%s (%s)", pk.person, pk.char)
        lines[#lines + 1] = format(ns.T("gl.slots.tip.pick"), SlotLabel(c.tpl.slots[pk.slot]), who)
    end
    if s.filled < s.total then lines[#lines + 1] = ns.T("gl.slots.tip.lack") end
    for i = 1, #c.tpl.slots do
        if not took[i] then lines[#lines + 1] = "  " .. SlotLabel(c.tpl.slots[i]) end
    end
    row.tipLines = lines
    return y + SLOT_H
end
local function DrawNote(text, y, w)
    local row = Take("note", y, w)
    Put(row.cols[1], TEXT_X, max(60, w - TEXT_X - 4), text, "text.muted")
    return y + NOTE_H
end
local function Options()
    local list = GR.List()
    local out = {}
    for i = 1, #list do out[i] = { key = list[i].key, label = GR.Label(list[i]) } end
    return out
end
function View.Draw(y, w)
    HideAll()
    if not content then return y end
    caption:ClearAllPoints()
    caption:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    caption.rule:SetWidth(max(1, w - caption:GetStringWidth() - 6))
    y = y + CAP_H
    sel:ClearAllPoints()
    sel:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN + TEXT_X, -y)
    sel:SetOptions(Options(), GR.Pick())
    check:ClearAllPoints()
    check:SetPoint("TOPRIGHT", content, "TOPLEFT", MARGIN + w - CHECK_W, -y + 2)
    check:SetChecked(GR.OnlineOnly())
    gsFs:ClearAllPoints()
    gsFs:SetPoint("LEFT", sel, "RIGHT", 10, 0)
    y = y + CTRL_H
    if not (IsInGuild and IsInGuild()) then
        gsFs:SetText("")
        return DrawNote(ns.T("gl.noguild"), y, w)
    end
    if not GN.Loaded() then
        GN.Ask()
        gsFs:SetText("")
        return DrawNote(ns.T("gl.loading"), y, w)
    end
    if not cache or (dirty and GetTime() - builtAt >= REBUILD_GAP) then
        Rebuild()
    elseif dirty then
        Schedule()
    end
    gsFs:SetText(format(ns.T("gl.gs"), cache.gsMin))
    y = DrawSlots(y, w)
    local only = GR.OnlineOnly()
    local shown = 0
    for i = 1, #cache.people do
        local p = cache.people[i]
        if p.online or not only then
            y = DrawPerson(p, y, w)
            shown = shown + 1
        end
    end
    if shown == 0 then y = DrawNote(ns.T(only and "gl.empty.online" or "gl.empty"), y, w) end
    return y
end
function View.Opened()
    dirty = true
    GN.Ask()
end
function View.Build(parent, redraw)
    content, rerender = parent, redraw
    caption = Kit.Caption(content, ns.T("gl.title"), 200)
    sel = Kit.Select(content)
    sel:SetWidth(SEL_W)
    sel:SetHeight(20)
    sel.tipTitle = ns.T("gl.raid")
    sel.onPick = function(key)
        GR.SetPick(key)
        Rebuild()
        redraw()
    end
    gsFs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsFs:SetJustifyH("LEFT")
    Kit.Text(gsFs, "text.muted")
    check = Kit.Check(content)
    check.label:SetText(ns.T("gl.online"))
    check.tipTitle = ns.T("gl.online")
    check.onToggle = function(on)
        GR.SetOnlineOnly(on)
        redraw()
    end
    ticker = CreateFrame("Frame", nil, content)
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self)
        if GetTime() - builtAt < REBUILD_GAP then return end
        self:Hide()
        if dirty and content:IsVisible() then redraw() end
    end)
end
function View.Probe()
    return { pools = pools, used = used, open = open, sel = sel, check = check, gsFs = gsFs, caption = caption,
        cache = function() return cache end, ticker = ticker }
end
GL.OnChange(function()
    dirty = true
    if content and content:IsVisible() then Schedule() end
end)
