local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local ceil = math.ceil
local floor = math.floor
local ICON = 14
local GAP = 4
local HEAD_PAD = 6
local HEAD_Y = -19
local PAD = 8
local ROW = 22
local HEAD = 20
local CAP = 18
local POP_MIN = 220
local CHECK = 22
local LABEL_PAD = 30
local PIC_GAP = 4
local LABEL_MAX = 320
local LABEL_MIN = 60
local LABEL_GROW = 14
local RESET_H = 20
local BTN_PAD = 24
local COL_GAP = 16
local EDGE = 6
local BAR_ROOM = 10
local ZONE_OTHER = "?"
local RAID = ns.RaidModel and ns.RaidModel.HIDE or "#raid"
local ALL = "*"
local Hide = {}
ns.SumHide = Hide
Hide.ALL = ALL
local Kit = ns.Kit
local T = ns.T
local cache = {}
local byKey = {}
local allSet = {}
local cacheLang
local gear, catcher, pop
local cols = {}
local popBoss
local watchers = {}
local function Store(make)
    local db = ns.GetDB and ns.GetDB()
    local s = db and db.settings
    if type(s) ~= "table" then return nil end
    if type(s.ui) ~= "table" then
        if not make then return nil end
        s.ui = {}
    end
    if type(s.ui.hide) ~= "table" then
        if not make then return nil end
        s.ui.hide = {}
    end
    return s.ui.hide
end
function Hide.Key(def)
    if def.key then return def.key end
    local base = def.tip or def.label or def.kind
    if def.spell then return base .. "/" .. def.spell end
    return base
end
local function Collect(out, list, kind, raid)
    local from = #out + 1
    local seen = {}
    local kinds = ns.sumAll and ns.sumAll.kinds or {}
    for i = 1, #(list or {}) do
        local def = list[i]
        local text = T(kind == "block" and def.label or def.tip)
        local key = Hide.Key(def)
        local all = def.all
        if not raid then all = kind == "block" and kinds[def.kind] or key end
        out[#out + 1] = { key = key, label = text, kind = kind, off = def.off == true, spell = def.spell, def = def,
                          all = all }
        seen[text] = (seen[text] or 0) + 1
    end
    for i = from, #out do
        local it = out[i]
        if seen[it.label] > 1 and it.spell then it.label = format("%s (%s)", it.label, ns.SpellName(it.spell)) end
        it.spell = nil
    end
end
local function AllBosses()
    local out, listed = {}, {}
    local zones = ns.summaryZones or {}
    for i = 1, #zones do
        local z = zones[i]
        for k = 1, #z.bosses do
            local b = z.bosses[k]
            if ns.summaries and ns.summaries[b] and not listed[b] then
                listed[b] = true
                out[#out + 1] = b
            end
        end
    end
    local rest = {}
    for b in pairs(ns.summaries or {}) do
        if not listed[b] then rest[#rest + 1] = b end
    end
    table.sort(rest, function(a, b) return tostring(a) < tostring(b) end)
    for i = 1, #rest do out[#out + 1] = rest[i] end
    return out
end
local function BuildAll()
    local list = {}
    allSet = {}
    local common = ns.sumAll and ns.sumAll.common or {}
    for i = 1, #common do
        local c = common[i]
        list[#list + 1] = { key = c.key, label = T(c.label), kind = "common", off = false, def = c, icon = c.icon or false }
        allSet[c.key] = true
    end
    local bosses = AllBosses()
    local count, first, order = {}, {}, {}
    for i = 1, #bosses do
        local items = Hide.Items(bosses[i])
        local seen = {}
        for k = 1, #items do
            local it = items[k]
            local g = it.all
            if g and not seen[g] then
                seen[g] = true
                count[g] = (count[g] or 0) + 1
                if not first[g] then
                    first[g] = { boss = bosses[i], it = it }
                    order[#order + 1] = g
                end
            end
        end
    end
    local kinds = ns.sumAll and ns.sumAll.kinds or {}
    for _, kind in ipairs({ "block", "badge" }) do
        for i = 1, #order do
            local g = order[i]
            local f = first[g]
            if count[g] > 1 and f.it.kind == kind then
                local byKind = kind == "block" and kinds[f.it.def.kind] == g
                list[#list + 1] = { key = g, label = byKind and T(g) or f.it.label, kind = kind, off = false,
                                    def = f.it.def, src = f }
                allSet[g] = true
            end
        end
    end
    return list
end
function Hide.Items(boss)
    if not boss then return {} end
    if cacheLang ~= ns.lang then
        cache, byKey = {}, {}
        cacheLang = ns.lang
    end
    local list = cache[boss]
    if list then return list end
    list = {}
    if boss == ALL then
        list = BuildAll()
    elseif boss == RAID then
        Collect(list, ns.RaidModel and ns.RaidModel.DEFS, "block", true)
    else
        local def = ns.summaries and ns.summaries[boss]
        if not def then return list end
        Collect(list, def.blocks, "block")
        Collect(list, def.badges, "badge")
        Collect(list, def.cover, "badge")
        if def.pull then Collect(list, { def.pull }, "badge") end
    end
    local map = {}
    for i = 1, #list do map[list[i].key] = list[i] end
    cache[boss], byKey[boss] = list, map
    return list
end
local function Find(boss, key)
    Hide.Items(boss)
    local map = byKey[boss]
    return map and map[key]
end
function Hide.Icon(boss, it)
    if it.icon ~= nil then return it.icon or nil end
    if it.src then
        local tex = Hide.Icon(it.src.boss, it.src.it)
        it.icon = tex or false
        return tex
    end
    local def, tex = it.def, nil
    if boss == RAID then
        local id = def.award and ns.awardIcons and ns.awardIcons[def.key]
        tex = def.icon or (id and ns.SpellIcon(id))
    elseif it.kind == "block" then
        tex = ns.BadgeTips and ns.BadgeTips.Mechanic({ def = def }).icon
    else
        local id = def.id or def.spell or (def.spells and def.spells[1])
        tex = id and ns.SpellIcon(id)
        local npc = not tex and (def.npc or def.src or (def.names and def.names[1]))
        tex = tex or (npc and ns.npcPortraits and ns.npcPortraits[npc]) or (ns.kindIcons and ns.kindIcons[def.kind]) or nil
    end
    it.icon = tex or false
    return tex
end
function Hide.Name(boss)
    if boss == RAID then return T("set.show.raid") end
    if boss == ALL then return T("sum.hide.all") end
    return ns.EncName(boss)
end
function Hide.Label(boss, key)
    local it = Find(boss, key)
    return it and it.label or key
end
local function Default(boss, key)
    local it = Find(boss, key)
    return it ~= nil and it.off
end
function Hide.AllOff(key)
    local st = Store(false)
    local mine = st and st[ALL]
    if not (mine and mine[key]) then return false end
    Hide.Items(ALL)
    return allSet[key] == true
end
local function Own(boss, key)
    if boss == ALL then return Hide.AllOff(key) end
    local st = Store(false)
    local v = st and st[boss] and st[boss][key]
    if v == nil then return Default(boss, key) end
    return v == true
end
function Hide.Blocked(boss, key)
    if not boss or boss == ALL then return false end
    local it = Find(boss, key)
    return it ~= nil and it.all ~= nil and Hide.AllOff(it.all)
end
function Hide.IsHidden(boss, key)
    if not boss then return false end
    return Hide.Blocked(boss, key) or Own(boss, key)
end
function Hide.Hidden(boss, def)
    return Hide.IsHidden(boss, Hide.Key(def))
end
function Hide.Shows(key)
    return not Hide.AllOff(key)
end
local function Changed()
    local SV = ns.SummaryView
    if SV and SV.IsShown and SV.IsShown() then SV.Refresh() end
    local RV = ns.RaidSummaryView
    if RV and RV.IsShown and RV.IsShown() then RV.Refresh() end
    for i = 1, #watchers do watchers[i]() end
end
function Hide.Set(boss, key, hidden)
    local st = Store(true)
    if not st then return end
    local mine = st[boss] or {}
    if hidden == Default(boss, key) then mine[key] = nil else mine[key] = hidden end
    st[boss] = next(mine) and mine or nil
    Changed()
end
function Hide.Reset(boss)
    local st = Store(false)
    if not st then return end
    if boss then
        st[boss] = nil
    else
        for k in pairs(st) do st[k] = nil end
    end
    Changed()
end
function Hide.IsDefault(boss)
    local st = Store(false)
    if not st then return true end
    if boss then return st[boss] == nil end
    return next(st) == nil
end
function Hide.OnChange(fn)
    watchers[#watchers + 1] = fn
end
function Hide.Zones()
    local out = {}
    local zones = ns.summaryZones or {}
    for i = 1, #zones do out[i] = zones[i].zone end
    return out
end
function Hide.Bosses(zone)
    if zone == RAID or zone == ALL then return { zone } end
    local zones = ns.summaryZones or {}
    local out, listed = {}, {}
    for i = 1, #zones do
        local z = zones[i]
        for k = 1, #z.bosses do
            local b = z.bosses[k]
            listed[b] = true
            if z.zone == zone and #Hide.Items(b) > 0 then out[#out + 1] = b end
        end
    end
    if zone == ZONE_OTHER then
        for b in pairs(ns.summaries or {}) do
            if not listed[b] and #Hide.Items(b) > 0 then out[#out + 1] = b end
        end
        table.sort(out)
    end
    return out
end
local function RootOf(f)
    while f do
        local p = f:GetParent()
        if not p or p == UIParent then return f end
        f = p
    end
    return UIParent
end
function Hide.Close()
    if catcher then catcher:Hide() end
    popBoss = nil
    if gear then
        gear.active = false
        Kit.StyleButton(gear)
    end
end
local function Check(col, i)
    local c = col.checks[i]
    if c then return c end
    c = Kit.Check(col.frame)
    Kit.Bind(c.label, "GameFontNormalSmall")
    c:SetWidth(CHECK)
    c:SetHeight(CHECK)
    c.tipTitle = false
    c.pic = c:CreateTexture(nil, "ARTWORK")
    c.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.pic:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.label:ClearAllPoints()
    c.label:SetPoint("LEFT", c.pic, "RIGHT", PIC_GAP, 0)
    c.label:SetJustifyH("LEFT")
    c.label:SetWordWrap(false)
    c.onToggle = function(on)
        if col.scope and c.hideKey then Hide.Set(col.scope, c.hideKey, not on) end
    end
    col.checks[i] = c
    return c
end
local function Cap(col, i)
    local fs = col.caps[i]
    if fs then return fs end
    fs = Kit.Str(col.frame, "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    Kit.Text(fs, "text.secondary")
    col.caps[i] = fs
    return fs
end
local function PaintPop()
    if pop then Kit.Backdrop(pop, Kit.Theme().list) end
end
local function Column(n)
    local col = cols[n]
    if col then return col end
    col = { checks = {}, caps = {}, used = 0 }
    col.frame = CreateFrame("Frame", nil, pop.page.content)
    col.title = Kit.Str(col.frame, "GameFontNormalSmall")
    col.title:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 2, 0)
    col.title:SetJustifyH("LEFT")
    col.title:SetWordWrap(false)
    Kit.Text(col.title, "list.head")
    col.reset = Kit.Button(col.frame)
    col.reset:SetHeight(RESET_H)
    col.reset:SetText(T("set.adv.reset"))
    col.reset:SetWidth(max(80, col.reset.text:GetStringWidth() + BTN_PAD))
    col.reset.tipTitle = false
    col.reset.tip = T(n == 1 and "sum.hide.reset.tip" or "sum.hide.all.reset.tip")
    col.reset.onClick = function()
        if col.scope then Hide.Reset(col.scope) end
    end
    cols[n] = col
    return col
end
local function BuildPop()
    catcher = CreateFrame("Frame", nil, RootOf(gear))
    catcher:SetAllPoints(catcher:GetParent())
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", Hide.Close)
    catcher:Hide()
    pop = CreateFrame("Frame", nil, catcher)
    pop:SetFrameLevel(catcher:GetFrameLevel() + 10)
    pop:EnableMouse(true)
    pop:SetClampedToScreen(true)
    pop.page = Kit.ScrollPage(pop, { bar = "deck", inset = EDGE, wheel = ROW * 3 })
    pop.page.scroll:SetPoint("TOPLEFT", pop, "TOPLEFT", PAD, -PAD)
    pop.page.scroll:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -PAD, PAD)
    local one, all = Column(1), Column(2)
    pop.title, pop.reset = one.title, one.reset
    pop.allTitle, pop.allReset = all.title, all.reset
    PaintPop()
    Kit.OnTheme(PaintPop)
end
local function FillCol(col, scope, title, cap)
    local list = Hide.Items(scope)
    local pic = ROW - 6
    col.scope = scope
    col.title:SetWidth(0)
    col.title:SetText(title)
    local tw = col.title:GetStringWidth()
    local most = cap + pic + PIC_GAP + LABEL_PAD
    col.title:SetWidth(ceil(min(tw, most)))
    local w = max(min(POP_MIN, most), min(tw, most) + 4)
    local y = HEAD
    local used, capN, kind = 0, 0, nil
    for i = 1, #list do
        local it = list[i]
        if it.kind ~= kind then
            kind = it.kind
            capN = capN + 1
            local fs = Cap(col, capN)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 2, -(y + 3))
            fs:SetText(T((kind == "common" and "sum.hide.common") or (kind == "block" and "sum.hide.blocks")
                or "sum.hide.badges"))
            fs:Show()
            y = y + CAP
        end
        used = used + 1
        local c = Check(col, used)
        c.hideKey = it.key
        local tex = Hide.Icon(scope, it)
        c.pic:SetWidth(pic)
        c.pic:SetHeight(pic)
        c.pic:SetTexture(tex)
        if tex then c.pic:Show() else c.pic:Hide() end
        c.label:SetWidth(0)
        c.label:SetText(it.label)
        local lw = c.label:GetStringWidth()
        local shown = ceil(min(lw, cap))
        c.label:SetWidth(shown)
        local blocked = Hide.Blocked(scope, it.key)
        local tip = lw > cap and it.label or nil
        if blocked then tip = tip and (tip .. "\n" .. T("sum.hide.all.off")) or T("sum.hide.all.off") end
        c.tip = tip
        c:SetHitRectInsets(0, -(2 + pic + PIC_GAP + shown), 0, 0)
        c:SetChecked(not Own(scope, it.key))
        if blocked then c:Disable() else c:Enable() end
        Kit.Text(c.label, blocked and "text.off" or "check.label")
        c.pic:SetDesaturated(blocked)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 0, -y)
        c:Show()
        w = max(w, shown + pic + PIC_GAP + LABEL_PAD)
        y = y + ROW
    end
    for i = used + 1, #col.checks do
        col.checks[i]:Hide()
        col.checks[i].hideKey = nil
    end
    for i = capN + 1, #col.caps do col.caps[i]:Hide() end
    col.used = used
    y = y + GAP
    col.reset:ClearAllPoints()
    col.reset:SetPoint("TOPRIGHT", col.frame, "TOPRIGHT", 0, -y)
    if Hide.IsDefault(scope) then col.reset:Disable() else col.reset:Enable() end
    y = y + RESET_H
    w = ceil(max(w, col.reset:GetWidth()))
    col.frame:SetWidth(w)
    col.frame:SetHeight(y)
    col.frame:Show()
    return w, y
end
local function Room()
    local root = catcher:GetParent()
    local gb, rb = gear:GetBottom(), root:GetBottom()
    local gr, rl, rr = gear:GetRight(), root:GetLeft(), root:GetRight()
    if gr and rr then gr = min(gr, rr) end
    local h = (gb and rb and gb > rb) and (gb - rb - 2 - EDGE) or 2000
    local w = (gr and rl and gr > rl) and (gr - rl - EDGE) or 2000
    return floor(w), floor(h)
end
local function Fill()
    local boss = popBoss
    if not boss or not pop then return end
    local g = Kit.Grow().g
    ROW, HEAD, CAP = 22 + g, 20 + g, 18 + g
    local roomW, roomH = Room()
    local cap = LABEL_MAX + g * LABEL_GROW
    local one, all = cols[1], cols[2]
    local title = format(T("sum.hide.title"), Hide.Name(boss))
    local w1, h1 = FillCol(one, boss, title, cap)
    local w2, h2 = FillCol(all, ALL, T("sum.hide.all"), cap)
    local side = w1 + COL_GAP + w2 + PAD * 2 + (max(h1, h2) + PAD * 2 > roomH and BAR_ROOM or 0) <= roomW
    if not side then
        local fit = roomW - PAD * 2 - BAR_ROOM - (ROW - 6) - PIC_GAP - LABEL_PAD
        if max(w1, w2) + PAD * 2 + BAR_ROOM > roomW and fit < cap then
            cap = max(LABEL_MIN, fit)
            w1, h1 = FillCol(one, boss, title, cap)
            w2, h2 = FillCol(all, ALL, T("sum.hide.all"), cap)
        end
    end
    local cw, ch
    one.frame:ClearAllPoints()
    one.frame:SetPoint("TOPLEFT", pop.page.content, "TOPLEFT", 0, 0)
    all.frame:ClearAllPoints()
    if side then
        all.frame:SetPoint("TOPLEFT", pop.page.content, "TOPLEFT", w1 + COL_GAP, 0)
        cw, ch = w1 + COL_GAP + w2, max(h1, h2)
    else
        all.frame:SetPoint("TOPLEFT", pop.page.content, "TOPLEFT", 0, -(h1 + COL_GAP))
        cw, ch = max(w1, w2), h1 + COL_GAP + h2
    end
    local scroll = ch + PAD * 2 > roomH
    local bar = pop.page.bar
    local deck = bar and bar:GetParent()
    if deck then
        if scroll then deck:Show() else deck:Hide() end
    end
    local room = scroll and BAR_ROOM or 0
    pop.page.content:SetWidth(cw)
    pop.page.content:SetHeight(ch)
    pop.page.scroll:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -(PAD + room), PAD)
    pop:SetWidth(ceil(cw + PAD * 2 + room))
    pop:SetHeight(ceil(scroll and max(ROW * 4, roomH) or (ch + PAD * 2)))
    pop.side, pop.scrolls = side, scroll
    local gr, rr = gear:GetRight(), catcher:GetParent():GetRight()
    pop:ClearAllPoints()
    pop:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", (gr and rr and gr > rr) and floor(rr - gr - EDGE) or 0, -2)
    pop.page:Rescroll()
end
function Hide.Open(boss)
    if not gear then return end
    if not catcher then BuildPop() end
    popBoss = boss
    catcher:Show()
    pop.page:ScrollTo(0)
    Fill()
    gear.active = true
    Kit.StyleButton(gear)
end
function Hide.IsOpen()
    return catcher ~= nil and catcher:IsShown() and true or false
end
function Hide.PopFrame()
    return pop
end
function Hide.PopChecks(scope)
    local out = {}
    local col = cols[scope == ALL and 2 or 1]
    if not col then return out end
    for i = 1, #col.checks do
        if col.checks[i]:IsShown() then out[#out + 1] = col.checks[i] end
    end
    return out
end
local function GearClick(b)
    if Hide.IsOpen() then
        Hide.Close()
    elseif b.boss then
        Hide.Open(b.boss)
    end
end
local function SetBoss(boss)
    if not gear then return end
    gear.boss = boss and #Hide.Items(boss) > 0 and boss or nil
    if gear.boss then gear:Show() else gear:Hide() end
    if Hide.IsOpen() and popBoss ~= gear.boss then Hide.Close() end
end
function Hide.SetFight(f)
    SetBoss(f and f.boss)
end
local function Sync()
    local RV, SV = ns.RaidSummaryView, ns.SummaryView
    if RV and RV.IsShown and RV.IsShown() then return SetBoss(RAID) end
    local f = SV and SV.IsShown and SV.IsShown() and SV.Fight and SV.Fight() or nil
    SetBoss(f and f.boss)
end
function Hide.Head(host)
    local b = Kit.ToolButton(host, nil, Kit.GEAR_TEX)
    b:SetPoint("RIGHT", host, "TOPRIGHT", -HEAD_PAD, HEAD_Y)
    b.icon:SetWidth(ICON)
    b.icon:SetHeight(ICON)
    b.tipTitle = T("sum.hide.btn")
    b.tip = T("sum.hide.btn.tip")
    b.onClick = GearClick
    gear = b
    Sync()
    return b
end
function Hide.HeadFrame()
    return gear
end
Hide.OnChange(function()
    if Hide.IsOpen() then Fill() end
end)
if ns.SummaryView then
    hooksecurefunc(ns.SummaryView, "Show", Sync)
    hooksecurefunc(ns.SummaryView, "Hide", function()
        Hide.Close()
        Sync()
    end)
end
if ns.RaidSummaryView then
    hooksecurefunc(ns.RaidSummaryView, "Show", Sync)
    hooksecurefunc(ns.RaidSummaryView, "Hide", function()
        Hide.Close()
        Sync()
    end)
end
local S = ns.Settings
if not S then return end
local zone, boss
local function AllZones()
    local out = Hide.Zones()
    if #Hide.Bosses(ZONE_OTHER) > 0 then out[#out + 1] = ZONE_OTHER end
    out[#out + 1] = RAID
    out[#out + 1] = ALL
    return out
end
local function Zone()
    local list = AllZones()
    for i = 1, #list do
        if list[i] == zone then return zone end
    end
    return list[1]
end
local function Boss()
    local list = Hide.Bosses(Zone())
    for i = 1, #list do
        if list[i] == boss then return boss end
    end
    return list[1]
end
local function ZoneOptions()
    local out, list = {}, AllZones()
    for i = 1, #list do
        local z = list[i]
        out[i] = { key = z, label = (z == ZONE_OTHER and "set.show.other") or (z == RAID and "set.show.raid")
            or (z == ALL and "sum.hide.all") or z }
    end
    return out
end
local function BossOptions()
    local out, list = {}, Hide.Bosses(Zone())
    for i = 1, #list do
        local key = list[i]
        out[i] = { key = key, label = function() return Hide.Name(key) end }
    end
    return out
end
local items = {
    { kind = "text", key = "about", text = "set.show.text", token = "text.secondary", order = 0 },
    { kind = "choice", key = "zone", label = "set.show.zone", options = ZoneOptions, order = 1,
      get = Zone, set = function(k) zone, boss = k, nil end },
    { kind = "choice", key = "boss", label = "set.show.boss", options = BossOptions, order = 2,
      get = Boss, set = function(k) boss = k end },
    { kind = "button", key = "reset", label = "set.adv.reset", tip = "set.show.reset.tip", order = 10000,
      enabled = function() return not Hide.IsDefault(nil) end,
      run = function() Hide.Reset(nil) end },
}
local function BossItems(name, order)
    local list = Hide.Items(name)
    local kind
    local function Mine() return Boss() == name end
    for i = 1, #list do
        local it = list[i]
        if it.kind ~= kind then
            kind = it.kind
            order = order + 1
            items[#items + 1] = { kind = "text", key = name .. "|" .. kind, order = order, shown = Mine,
                text = (kind == "common" and "sum.hide.common") or (kind == "block" and "sum.hide.blocks")
                    or "sum.hide.badges", token = "text.title" }
        end
        order = order + 1
        items[#items + 1] = { kind = "check", key = name .. "|" .. it.key, order = order, shown = Mine,
            label = function() return Hide.Label(name, it.key) end, default = not it.off,
            enabled = function() return not Hide.Blocked(name, it.key) end,
            get = function() return not Own(name, it.key) end,
            set = function(on) Hide.Set(name, it.key, not on) end }
    end
    return order
end
do
    local order = 10
    local names = {}
    for name in pairs(ns.summaries or {}) do names[#names + 1] = name end
    table.sort(names)
    names[#names + 1] = RAID
    names[#names + 1] = ALL
    for n = 1, #names do order = BossItems(names[n], order) end
end
S.Section("parse", "show", {
    label = "set.show",
    order = 5,
    items = items,
})
Hide.OnChange(function() S.Refresh() end)
