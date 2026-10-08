local _, ns = ...
local format = string.format
local max = math.max
local ceil = math.ceil
local BTN = 18
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
local RESET_H = 20
local BTN_PAD = 24
local ZONE_OTHER = "?"
local RAID = ns.RaidModel and ns.RaidModel.HIDE or "#raid"
local Hide = {}
ns.SumHide = Hide
local Kit = ns.Kit
local T = ns.T
local cache = {}
local cacheLang
local gear, catcher, pop
local checks, caps = {}, {}
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
local function Collect(out, list, kind)
    local from = #out + 1
    local seen = {}
    for i = 1, #(list or {}) do
        local def = list[i]
        local text = T(kind == "block" and def.label or def.tip)
        out[#out + 1] = { key = Hide.Key(def), label = text, kind = kind, off = def.off == true, spell = def.spell }
        seen[text] = (seen[text] or 0) + 1
    end
    for i = from, #out do
        local it = out[i]
        if seen[it.label] > 1 and it.spell then it.label = format("%s (%s)", it.label, ns.SpellName(it.spell)) end
        it.spell = nil
    end
end
function Hide.Items(boss)
    if not boss then return {} end
    if cacheLang ~= ns.lang then
        cache = {}
        cacheLang = ns.lang
    end
    local list = cache[boss]
    if list then return list end
    list = {}
    if boss == RAID then
        Collect(list, ns.RaidModel and ns.RaidModel.DEFS, "block")
        cache[boss] = list
        return list
    end
    local def = ns.summaries and ns.summaries[boss]
    if not def then return list end
    Collect(list, def.blocks, "block")
    Collect(list, def.badges, "badge")
    cache[boss] = list
    return list
end
function Hide.Name(boss)
    if boss == RAID then return T("set.show.raid") end
    return ns.EncName(boss)
end
function Hide.Label(boss, key)
    local list = Hide.Items(boss)
    for i = 1, #list do
        if list[i].key == key then return list[i].label end
    end
    return key
end
local function Default(boss, key)
    local list = Hide.Items(boss)
    for i = 1, #list do
        if list[i].key == key then return list[i].off end
    end
    return false
end
function Hide.IsHidden(boss, key)
    if not boss then return false end
    local st = Store(false)
    local v = st and st[boss] and st[boss][key]
    if v == nil then return Default(boss, key) end
    return v == true
end
function Hide.Hidden(boss, def)
    return Hide.IsHidden(boss, Hide.Key(def))
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
    if zone == RAID then return { RAID } end
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
local function Check(i)
    local c = checks[i]
    if c then return c end
    c = Kit.Check(pop)
    c:SetWidth(CHECK)
    c:SetHeight(CHECK)
    c.tipTitle = false
    c.onToggle = function(on)
        if popBoss and c.hideKey then Hide.Set(popBoss, c.hideKey, not on) end
    end
    checks[i] = c
    return c
end
local function Cap(i)
    local fs = caps[i]
    if fs then return fs end
    fs = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, "text.secondary")
    caps[i] = fs
    return fs
end
local function PaintPop()
    if pop then Kit.Backdrop(pop, Kit.Theme().list) end
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
    pop.title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pop.title:SetPoint("TOPLEFT", pop, "TOPLEFT", PAD + 2, -PAD)
    pop.title:SetJustifyH("LEFT")
    Kit.Text(pop.title, "list.head")
    pop.reset = Kit.Button(pop)
    pop.reset:SetHeight(RESET_H)
    pop.reset:SetText(T("set.adv.reset"))
    pop.reset:SetWidth(max(80, pop.reset.text:GetStringWidth() + BTN_PAD))
    pop.reset.tipTitle = false
    pop.reset.tip = T("sum.hide.reset.tip")
    pop.reset.onClick = function()
        if popBoss then Hide.Reset(popBoss) end
    end
    PaintPop()
    Kit.OnTheme(PaintPop)
end
local function Fill()
    local boss = popBoss
    if not boss or not pop then return end
    local list = Hide.Items(boss)
    pop.title:SetText(format(T("sum.hide.title"), Hide.Name(boss)))
    local w = max(POP_MIN, pop.title:GetStringWidth() + PAD * 2 + 4)
    local y = PAD + HEAD
    local used, capN, kind = 0, 0, nil
    for i = 1, #list do
        local it = list[i]
        if it.kind ~= kind then
            kind = it.kind
            capN = capN + 1
            local fs = Cap(capN)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", pop, "TOPLEFT", PAD + 2, -(y + 3))
            fs:SetText(T(kind == "block" and "sum.hide.blocks" or "sum.hide.badges"))
            fs:Show()
            y = y + CAP
        end
        used = used + 1
        local c = Check(used)
        c.hideKey = it.key
        c.label:SetText(it.label)
        c:SetChecked(not Hide.IsHidden(boss, it.key))
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", pop, "TOPLEFT", PAD, -y)
        c:Show()
        w = max(w, c.label:GetStringWidth() + LABEL_PAD + PAD * 2)
        y = y + ROW
    end
    for i = used + 1, #checks do
        checks[i]:Hide()
        checks[i].hideKey = nil
    end
    for i = capN + 1, #caps do caps[i]:Hide() end
    y = y + GAP
    pop.reset:ClearAllPoints()
    pop.reset:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -PAD, -y)
    if Hide.IsDefault(boss) then pop.reset:Disable() else pop.reset:Enable() end
    y = y + RESET_H + PAD
    pop:SetWidth(ceil(w))
    pop:SetHeight(y)
end
function Hide.Open(boss)
    if not gear then return end
    if not catcher then BuildPop() end
    popBoss = boss
    Fill()
    pop:ClearAllPoints()
    pop:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -2)
    catcher:Show()
    gear.active = true
    Kit.StyleButton(gear)
end
function Hide.IsOpen()
    return catcher ~= nil and catcher:IsShown() and true or false
end
function Hide.PopFrame()
    return pop
end
function Hide.PopChecks()
    local out = {}
    for i = 1, #checks do
        if checks[i]:IsShown() then out[#out + 1] = checks[i] end
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
    local b = Kit.Button(host)
    b:SetWidth(BTN)
    b:SetHeight(BTN)
    b:SetPoint("RIGHT", host, "TOPRIGHT", -HEAD_PAD, HEAD_Y)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetWidth(ICON)
    b.icon:SetHeight(ICON)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetTexture(Kit.GEAR_TEX)
    Kit.Tint(b.icon, "text.title")
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
        out[i] = { key = z, label = (z == ZONE_OTHER and "set.show.other") or (z == RAID and "set.show.raid") or z }
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
do
    local order = 10
    local names = {}
    for name in pairs(ns.summaries or {}) do names[#names + 1] = name end
    table.sort(names)
    names[#names + 1] = RAID
    for n = 1, #names do
        local name = names[n]
        local list = Hide.Items(name)
        local kind
        for i = 1, #list do
            local it = list[i]
            local function Mine() return Boss() == name end
            if it.kind ~= kind then
                kind = it.kind
                order = order + 1
                items[#items + 1] = { kind = "text", key = name .. "|" .. kind, order = order, shown = Mine,
                    text = kind == "block" and "sum.hide.blocks" or "sum.hide.badges", token = "text.title" }
            end
            order = order + 1
            items[#items + 1] = { kind = "check", key = name .. "|" .. it.key, order = order, shown = Mine,
                label = function() return Hide.Label(name, it.key) end, default = not it.off,
                get = function() return not Hide.IsHidden(name, it.key) end,
                set = function(on) Hide.Set(name, it.key, not on) end }
        end
    end
end
S.Section("parse", "show", {
    label = "set.show",
    order = 5,
    items = items,
})
Hide.OnChange(function() S.Refresh() end)
