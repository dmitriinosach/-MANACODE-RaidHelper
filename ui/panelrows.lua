local _, ns = ...
local format = string.format
local ceil = math.ceil
local max = math.max
local Panel = ns.Panel
local Acts = ns.PanelActs
local Kit = ns.Kit
local FETCH = 5
local RATE = 0.5
local CHECK_GAP = 4
local STAT_GAP = 6
local INSET = 1
local ORDER = 80
local PREFIX = "act:"
local CLOCK_PROBE = "00:00"
local LABEL_GAP = 8
local ICONS = "Interface\\Icons\\"
local PICS = {
    ["break"] = ICONS .. "Spell_Holy_BorrowedTime",
    pull = ICONS .. "Ability_Warrior_Charge",
    raid = "Interface\\RaidFrame\\ReadyCheck-Ready",
    marks = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    diff = ICONS .. "Ability_Warrior_RallyingCry",
    flasks = ICONS .. "INV_Alchemy_EndlessFlask_06",
    server = ICONS .. "INV_Shirt_GuildTabard_01",
}
local PIC = ICONS .. "INV_Misc_Note_01"
local LEVELS = {
    { pad = 6, gap = 4, sep = 8, label = true },
    { pad = 4, gap = 3, sep = 6, label = true },
    { pad = 3, gap = 2, sep = 4, label = false },
}
local function CtlH()
    return Panel.RowH() - INSET * 2
end
local function TextMin()
    return math.floor(24 * Kit.FontScale("GameFontHighlightSmall", true) + 0.5)
end
local Rows = {}
ns.PanelRows = Rows
local byId = {}
local defs = {}
local registered = 0
local fetchedAt
local gen = 0
local Register
local function Fetch(force)
    local now = GetTime()
    if not force and fetchedAt and now - fetchedAt < FETCH then return end
    fetchedAt = now
    gen = gen + 1
    for k in pairs(byId) do byId[k] = nil end
    if not ns.Shell or not ns.Shell.ActionRows then return end
    local rows = ns.Shell.ActionRows()
    for i = 1, #rows do
        local r = rows[i]
        if r.id then
            byId[r.id] = r
            Register(r)
        end
    end
end
local function Put(v, it, sep)
    local n = v.n + 1
    v.n = n
    v.items[n] = it
    v.seps[n] = sep
end
local function Collect(v)
    v.n = 0
    local row = byId[v.def.rowId]
    if row then
        for i = 1, #row.items do Put(v, row.items[i], false) end
    end
    for i = v.n + 1, #v.items do v.items[i], v.seps[i] = nil, nil end
    return row
end
local function Title(row)
    if not row then return "" end
    return row.short or row.title or row.id or ""
end
local function Label(it)
    return it.short or it.label or ""
end
local function Sig(v)
    local parts = {}
    for i = 1, v.n do
        local it = v.items[i]
        parts[i] = (it.id or "") .. "=" .. (it.check and "c" or (it.icon and "i" or Label(it)))
    end
    return table.concat(parts, "|")
end
local function DressAll(self)
    local v = self:GetParent()
    for i = 1, v.n do
        local c = v.ctl[i]
        if c and c:IsShown() then Acts.Dress(c) end
    end
end
local function ButtonClick(b, button)
    if Acts.Fire(b, button) then DressAll(b) end
end
local function CheckToggle(c)
    Acts.Fire(c, "LeftButton")
    DressAll(c)
end
local function Button(v, k)
    local b = v.btns[k]
    if b then return b end
    b = ns.Kit.Button(v)
    Kit.RoundButton(b)
    b.text:SetWordWrap(false)
    b:SetHeight(CtlH())
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.onClick = ButtonClick
    b.pic = b:CreateTexture(nil, "OVERLAY")
    b.pic:SetPoint("CENTER", b, "CENTER", 0, 0)
    v.btns[k] = b
    return b
end
local function Check(v, k)
    local c = v.checks[k]
    if c then return c end
    c = ns.Kit.Check(v)
    c:SetWidth(CtlH())
    c:SetHeight(CtlH())
    c.onToggle = function() CheckToggle(c) end
    v.checks[k] = c
    return c
end
local function Bind(v)
    local nb, nc = 0, 0
    for i = 1, v.n do
        local it = v.items[i]
        local c
        if it.check then
            nc = nc + 1
            c = Check(v, nc)
        else
            nb = nb + 1
            c = Button(v, nb)
            if it.icon then
                c:SetText("")
                it.icon(c.pic)
                c.pic:Show()
            else
                c.pic:Hide()
                c:SetText(Label(it))
            end
        end
        c.item = it
        v.ctl[i] = c
    end
    for i = v.n + 1, #v.ctl do v.ctl[i] = nil end
    for k = nb + 1, #v.btns do
        v.btns[k].item = nil
        v.btns[k]:Hide()
    end
    for k = nc + 1, #v.checks do
        v.checks[k].item = nil
        v.checks[k]:Hide()
    end
end
local function Natural(v, i, lv)
    local it, c = v.items[i], v.ctl[i]
    local h = CtlH()
    if it.check then
        if not lv.label or (it.label or "") == "" then return h end
        c.label:SetText(it.label)
        return h + CHECK_GAP + (c.label:GetStringWidth() or 0)
    end
    if it.icon then return h end
    return max(h, (c.text:GetStringWidth() or 0) + lv.pad * 2)
end
local function Measure(v, lv, w)
    local sum = 0
    for i = 1, v.n do
        w[i] = Natural(v, i, lv)
        sum = sum + w[i]
        if i > 1 then sum = sum + (v.seps[i] and lv.sep or lv.gap) end
    end
    return sum
end
local function Squeeze(v, w, excess)
    while excess > 0 do
        local at, widest = nil, TextMin()
        for i = 1, v.n do
            local it = v.items[i]
            if not it.check and not it.icon and w[i] > widest then at, widest = i, w[i] end
        end
        if not at then return excess end
        local next = TextMin()
        for i = 1, v.n do
            local it = v.items[i]
            if i ~= at and not it.check and not it.icon and w[i] < widest and w[i] > next then next = w[i] end
        end
        local cut = math.min(excess, max(1, widest - next))
        w[at] = widest - cut
        excess = excess - cut
    end
    return 0
end
local function StatWidth(v)
    if v.statText == "" then return 0 end
    if v.def.clock then
        local was = v.stat:GetText()
        v.stat:SetText(CLOCK_PROBE)
        local w = v.stat:GetStringWidth() or 0
        v.stat:SetText(was)
        return max(w, v.stat:GetStringWidth() or 0)
    end
    return v.stat:GetStringWidth() or 0
end
local widths = {}
local function Start(v)
    return v.lx + (v.label:GetStringWidth() or 0) + LABEL_GAP
end
local function Lay(v)
    for i = 1, v.n do
        local it = v.items[i]
        if not it.check and not it.icon then v.ctl[i].text:SetWidth(0) end
    end
    v.stat:SetWidth(0)
    v.stat:SetText(v.statText)
    local sw = StatWidth(v)
    local x0 = Start(v)
    local ROOM = Panel.RowRoom() - x0
    local lv, sum
    for k = 1, #LEVELS do
        lv = LEVELS[k]
        sum = Measure(v, lv, widths)
        if sum + (sw > 0 and STAT_GAP + sw or 0) <= ROOM then break end
    end
    v.statShown = sw > 0
    if v.statShown and sum + STAT_GAP + sw > ROOM and not v.def.clock then v.statShown = false end
    local room = ROOM - (v.statShown and STAT_GAP + sw or 0)
    local left = Squeeze(v, widths, sum - room)
    local last = v.n
    while left > 0 and last > 0 do
        left = left - widths[last] - (last > 1 and (v.seps[last] and lv.sep or lv.gap) or 0)
        last = last - 1
    end
    v.hidden = v.n - last
    local x, h = x0, CtlH()
    for i = 1, v.n do
        local it, c = v.items[i], v.ctl[i]
        if i > last then
            c:Hide()
        else
            if i > 1 then x = x + (v.seps[i] and lv.sep or lv.gap) end
            local w = widths[i]
            c:ClearAllPoints()
            c:SetPoint("LEFT", v, "LEFT", x, 0)
            if it.check then
                c:SetWidth(h)
                c:SetHeight(h)
                c.label:SetText(lv.label and it.label or "")
            else
                c:SetWidth(w)
                if it.icon then
                    c.pic:SetWidth(w - 2)
                    c.pic:SetHeight(w - 2)
                    c.wantH = nil
                    c.rawSetHeight(c, w)
                else
                    c:SetHeight(h)
                    c.text:SetWidth(max(1, w - 2))
                end
            end
            c:Show()
            x = x + w
        end
    end
    if v.statShown then
        v.stat:ClearAllPoints()
        v.stat:SetPoint("LEFT", v, "LEFT", x + STAT_GAP, 0)
        v.stat:SetWidth(sw + 1)
        v.stat:Show()
        x = x + STAT_GAP + sw
    else
        v.stat:Hide()
    end
    v.need = max(1, x)
end
local function ClockOf(d)
    local P = ns.PullTimer
    if not d.clock or not (P and P.Clock) then return nil, nil end
    local kind, left, who = P.Clock()
    if kind ~= d.clock then return nil, nil end
    return left, who
end
local function StatusOf(v, row)
    if v.def.clock then
        local left = ClockOf(v.def)
        if not left then return "", nil end
        return ns.Clock(ceil(left)), v.def.clock == "pull" and "text.warn" or "text.secondary"
    end
    if row and row.status then return row.status() or "", nil end
    return "", nil
end
local function Sync(v, force)
    Fetch()
    local relay = force
    local row
    if v.gen ~= gen or force then
        v.gen = gen
        row = Collect(v)
        local title = Title(row)
        if v.label:GetText() ~= title then
            v.label:SetText(title)
            relay = true
        end
        local sig = Sig(v)
        if sig ~= v.sig or force then
            v.sig = sig
            relay = true
            Bind(v)
        else
            for i = 1, v.n do v.ctl[i].item = v.items[i] end
        end
    else
        row = byId[v.def.rowId]
    end
    local text, token = StatusOf(v, row)
    if text ~= v.statText then
        local was = v.statText
        v.statText = text
        if v.def.clock and was ~= "" and text ~= "" and not relay then
            v.stat:SetText(text)
        else
            relay = true
        end
    end
    if token ~= v.statToken then
        v.statToken = token
        ns.Kit.Text(v.stat, token or "text.muted")
    end
    if relay then Lay(v) end
    for i = 1, v.n do
        local c = v.ctl[i]
        if c:IsShown() then Acts.Dress(c) end
    end
end
local built = {}
local function Build(v)
    v.items, v.seps, v.ctl, v.btns, v.checks = {}, {}, {}, {}, {}
    v.n, v.hidden, v.gen, v.statText = 0, 0, -1, ""
    Fetch()
    local id = v.def.rowId
    Panel.Line(v, PICS[id] or PIC, Title(byId[id]))
    v.stat = Kit.Str(v, "GameFontHighlightSmall")
    v.stat:SetJustifyH("LEFT")
    ns.Kit.Text(v.stat, "text.muted")
    built[#built + 1] = v
    Sync(v, true)
end
Kit.OnFont(function()
    for i = 1, #built do Sync(built[i], true) end
end)
local function Update(v)
    Sync(v)
end
local function Tip(v)
    Sync(v)
    local d = v.def
    local lines = { { kind = "head", left = byId[d.rowId] and byId[d.rowId].title or "" } }
    if d.clock then
        local left, who = ClockOf(d)
        if left then
            lines[#lines + 1] = { kind = "row", left = ns.T(d.clock == "pull" and "panel.timers.pull" or "panel.timers.break"), right = ns.Clock(ceil(left)) }
            if who then lines[#lines + 1] = { kind = "note", left = format(ns.T("panel.timers.who"), who) } end
        end
    elseif v.statText ~= "" then
        lines[#lines + 1] = { kind = "row", left = v.statText }
    end
    if v.hidden > 0 then
        local names = {}
        for i = v.n - v.hidden + 1, v.n do names[#names + 1] = v.items[i].title or Label(v.items[i]) end
        lines[#lines + 1] = { kind = "note", left = format(ns.T("panel.act.more"), table.concat(names, ", ")) }
    end
    return lines
end
local function Has(d)
    Fetch()
    local r = byId[d.rowId]
    return r ~= nil and #r.items > 0
end
function Register(r)
    local d = defs[r.id]
    if d then
        d.label = format(ns.T("panel.act.label"), r.title or r.id)
        return
    end
    registered = registered + 1
    d = {
        key = PREFIX .. r.id,
        order = ORDER + registered,
        label = format(ns.T("panel.act.label"), r.title or r.id),
        rate = RATE,
        rowId = r.id,
        clock = (r.id == "pull" or r.id == "break") and r.id or nil,
        Build = Build,
        Update = Update,
        Tip = Tip,
    }
    d.Shown = function() return Has(d) end
    defs[r.id] = d
    Panel.Widget(d)
end
function Rows.Sync()
    Fetch(true)
end
function Rows.Keys()
    local out = {}
    for _, d in pairs(defs) do out[#out + 1] = d end
    table.sort(out, function(a, b) return a.order < b.order end)
    for i = 1, #out do out[i] = out[i].key end
    return out
end
if ns.OnReady then ns.OnReady(Rows.Sync) end
