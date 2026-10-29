local _, ns = ...
local format = string.format
local floor = math.floor
local concat = table.concat
local Panel = ns.Panel
local MAX_LINES = 12
local NAMES = 6
local ICON = 14
local ICON_TEX = "Interface\\Icons\\Spell_Holy_WordFortitude"
local parts = {}
local function Nick(class, name)
    local r, g, b = ns.Kit.ClassColor(class)
    return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), name)
end
local function Names(who, colored)
    local n = #who
    for i = #parts, 1, -1 do parts[i] = nil end
    for i = 1, n < NAMES and n or NAMES do
        local m = who[i]
        parts[i] = colored and Nick(m.class, m.name) or m.name
    end
    local s = concat(parts, ", ")
    if n > NAMES then s = s .. " +" .. (n - NAMES) end
    return s
end
local function Title(id)
    local name, _, tex = GetSpellInfo(id)
    local icon = tex and ("|T" .. tex .. ":" .. ICON .. "|t ") or ""
    return icon .. (name or ("#" .. id))
end
local function Pots()
    local F = ns.FlaskReady
    if not F then return nil, 0, {}, {} end
    local _, total, known = F.Counts()
    if not known then return nil, total, {}, {} end
    local list, pot, noPot, noFood = F.Members(), 0, {}, {}
    for i = 1, total do
        local m = list[i]
        if not m.why then
            local p, food = F.Has(m)
            if p then pot = pot + 1 else noPot[#noPot + 1] = m end
            if not food then noFood[#noFood + 1] = m end
        end
    end
    return pot, total, noPot, noFood
end
local function Refresh(row)
    if not Panel.Ctx().group then
        Panel.Empty(row, "nogroup")
        return
    end
    local RB = ns.RaidBuffs
    RB.Tick()
    if ns.FlaskReady then ns.FlaskReady.Tick() end
    local lack, _, _, known = RB.Counts()
    if not known then
        Panel.Empty(row, "none")
        return
    end
    local pot, total = Pots()
    local text = lack > 0 and format(ns.T("buffrow.lack"), lack) or ns.T("buffrow.all")
    local tone = lack > 0 and "warn" or "good"
    if pot and total > 0 then
        text = text .. format(ns.T("buffrow.pots"), pot, total)
        if pot < total and tone == "good" then tone = "normal" end
    end
    Panel.Value(row, text, tone)
end
local function CanCheck()
    local L = ns.Lead
    return L ~= nil and L.ReadyUI ~= nil and L.ReadyUI.Check ~= nil
end
local function Section(lines, title, who)
    if #who == 0 then return false end
    lines[#lines + 1] = { kind = "row", left = title, right = tostring(#who), tone = "bad" }
    lines[#lines + 1] = { kind = "sub", left = Names(who, true) }
    return true
end
local function Tip(row)
    Refresh(row)
    if not Panel.Ctx().group then
        return { { kind = "head", left = ns.T("set.panel.row.buffs"), right = Panel.EmptyText("nogroup") },
            { kind = "foot", left = ns.T("buffrow.click") } }
    end
    local RB = ns.RaidBuffs
    local lack, _, none, known = RB.Counts()
    local lines = { { kind = "head", left = ns.T("set.panel.row.buffs"),
        right = known and (lack > 0 and format(ns.T("buffrow.lack.head"), lack) or ns.T("buffrow.all.head")) or nil } }
    if not known then
        lines[2] = { kind = "note", left = ns.T("flaskrow.never") }
        lines[3] = { kind = "foot", left = ns.T("buffrow.click") }
        return lines
    end
    local miss = RB.Missing()
    local _, _, noPot, noFood = Pots()
    local sections = #miss + (#noPot > 0 and 1 or 0) + (#noFood > 0 and 1 or 0)
    local shown = 0
    local function Add(title, who)
        if #lines + 2 > MAX_LINES then return end
        if Section(lines, title, who) then shown = shown + 1 end
    end
    for i = 1, #miss do Add(Title(miss[i].id), miss[i].who) end
    Add(ns.T("flaskrow.nopot"), noPot)
    Add(ns.T("flaskrow.nofood"), noFood)
    if sections > shown then
        lines[#lines + 1] = { kind = "note", left = format(ns.T("flaskrow.more"), sections - shown) }
    end
    if none > 0 then
        local who, list = {}, RB.Members()
        for i = 1, #list do
            if list[i].why then who[#who + 1] = list[i] end
        end
        lines[#lines + 1] = { kind = "note", left = format(ns.T("buffrow.nodata"), Names(who, false)) }
    end
    lines[#lines + 1] = { kind = "note", left = format(ns.T("buffrow.age"), ns.Clock(RB.Age() or 0)) }
    lines[#lines + 1] = { kind = "foot", left = ns.T("buffrow.click") }
    return lines
end
Panel.Widget({
    key = "buffs",
    order = 35,
    label = "set.panel.row.buffs",
    rate = ns.RaidBuffs.EVERY,
    Live = function(on) ns.RaidBuffs.Watch(on) end,
    Build = function(row)
        Panel.Line(row, ICON_TEX, ns.T("panel.line.buffs"))
        Panel.Reserve(row, format(ns.T("buffrow.lack"), 9) .. format(ns.T("buffrow.pots"), 25, 25))
        Panel.Empty(row, "nogroup")
    end,
    Update = Refresh,
    Tip = Tip,
    Click = function(row, button)
        if button ~= "LeftButton" then return end
        if CanCheck() then
            ns.Lead.ReadyUI.Check()
        elseif ns.Shell then
            ns.Shell.Open("raid")
        end
    end,
})
