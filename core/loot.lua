local _, ns = ...
local format = string.format
local floor = math.floor
local tsort = table.sort
local MIN_QUALITY = 4
local WINDOW = 1800
local KEEP_DAYS = 30
local MAX_ROWS = 3000
local DUP = 1
local QUALITY = { ffa335ee = 4, ffff8000 = 5, ffe6cc80 = 6 }
local SKIP = {
    [49426] = true, [47241] = true, [45624] = true, [40753] = true, [40752] = true,
    [34057] = true,
}
local Loot = {}
ns.Loot = Loot
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%d%$", "%%"):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local OTHER = { Pattern(LOOT_ITEM_MULTIPLE), Pattern(LOOT_ITEM) }
local SELF = { Pattern(LOOT_ITEM_SELF_MULTIPLE), Pattern(LOOT_ITEM_SELF) }
local function Store()
    local db = ns.GetDB()
    if type(db.loot) ~= "table" then db.loot = {} end
    return db.loot
end
function Loot.Parse(msg)
    for i = 1, #OTHER do
        local p = OTHER[i]
        if p then
            local who, link, n = msg:match(p)
            if who and link and link:find("|Hitem:", 1, true) then return who, link, tonumber(n) or 1 end
        end
    end
    for i = 1, #SELF do
        local p = SELF[i]
        if p then
            local link, n = msg:match(p)
            if link and link:find("|Hitem:", 1, true) then return UnitName("player"), link, tonumber(n) or 1 end
        end
    end
    return nil, nil, 1
end
function Loot.Item(link)
    local id = tonumber(link:match("|Hitem:(%d+)"))
    local name = link:match("|h%[(.-)%]|h") or "?"
    local color = link:match("|c(%x%x%x%x%x%x%x%x)")
    return id, name, color and QUALITY[color:lower()] or 0
end
function Loot.OnChat(msg)
    if type(msg) ~= "string" or ns.RecLock() then return end
    local R = ns.Recorder
    if not (R and R.IsOn() and R.InZone()) then return end
    local who, link, n = Loot.Parse(msg)
    if not who then return end
    local id, name, q = Loot.Item(link)
    if not id or q < MIN_QUALITY or SKIP[id] then return end
    who = who:match("^([^%-]+)") or who
    local t = R.Now()
    local list = Store()
    local last = list[#list]
    if last and last.who == who and last.id == id and t - last.t < DUP then return end
    list[#list + 1] = { t = t, who = who, id = id, n = n, name = name, q = q, inst = (GetInstanceInfo()) or "" }
    if #list > MAX_ROWS then table.remove(list, 1) end
end
function Loot.Prune()
    local list = Store()
    local edge = time() - KEEP_DAYS * 86400
    local keep = {}
    for i = 1, #list do
        if (list[i].t or 0) >= edge then keep[#keep + 1] = list[i] end
    end
    ns.GetDB().loot = keep
end
function Loot.ForFight(fight)
    local out = {}
    if not (fight and fight.killed) then return out end
    local inst = fight.raid and fight.raid.name
    local stop = fight.to + WINDOW
    local fights = ns.Encounters.Fights() or {}
    for i = 1, #fights do
        local f = fights[i]
        if f ~= fight and f.from > fight.to and f.from < stop
            and (not inst or not f.raid or f.raid.name == inst) then
            stop = f.from
        end
    end
    local list = Store()
    for i = 1, #list do
        local e = list[i]
        if e.t >= fight.to and e.t < stop and (not inst or e.inst == inst) then out[#out + 1] = e end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    return out
end
local function Hex(q)
    if q >= 6 then return "ffe6cc80" end
    if q >= 5 then return "ffff8000" end
    return "ffa335ee"
end
local function Row(e, boss)
    local class = ns.Encounters.ClassOf and ns.Encounters.ClassOf(e.who) or nil
    local name = format("|c%s%s|r", Hex(e.q), e.name) .. (e.n > 1 and format(" x%d", e.n) or "")
    local lines = { { kind = "head", left = format("|c%s%s|r", Hex(e.q), e.name), right = e.n > 1 and format("x%d", e.n) or nil },
                    { kind = "row", left = ns.T("loot.tt.who"), right = e.who },
                    { kind = "sub", left = ns.T("loot.tt.when"), right = date("%H:%M", floor(e.t)) } }
    if boss then lines[#lines + 1] = { kind = "sub", left = ns.T("loot.tt.boss"), right = boss } end
    return { who = name, icon = GetItemIcon and GetItemIcon(e.id) or nil, text = e.who, class = class, v = e.t,
             note = boss, noteLit = false, lines = lines }
end
function Loot.FightDetail(fight)
    local list = Loot.ForFight(fight)
    if #list == 0 then return nil end
    local rows = {}
    for i = 1, #list do rows[i] = Row(list[i], nil) end
    return { title = format(ns.T("loot.title.n"), #list), rows = rows, empty = ns.T("loot.none") }
end
function Loot.RaidDetail(raid)
    local rows = {}
    for _, enc in ipairs(raid and raid.encs or {}) do
        for _, f in ipairs(enc.fights or {}) do
            if f.killed then
                local boss = ns.EncName(f.boss)
                local list = Loot.ForFight(f)
                for i = 1, #list do rows[#rows + 1] = Row(list[i], boss) end
            end
        end
    end
    if #rows == 0 then return nil end
    tsort(rows, function(a, b) return a.v < b.v end)
    return { key = "loot", title = format(ns.T("loot.title.n"), #rows), rows = rows, empty = ns.T("loot.none") }
end
local DEMO = {
    { id = 50274, name = "Осколок Темной Скорби", q = 5, n = 2 },
    { id = 49908, name = "Первозданный саронит", q = 4, n = 1 },
    { id = 50415, name = "Бринтролл, Костяной арбитр", q = 4, n = 1 },
    { id = 50363, name = "Воля Смертоносного", q = 4, n = 1 },
}
function Loot.HasDemo()
    local list = Store()
    for i = 1, #list do
        if list[i].demo then return true end
    end
    return false
end
function Loot.ClearDemo()
    local list, keep, n = Store(), {}, 0
    for i = 1, #list do
        if list[i].demo then n = n + 1 else keep[#keep + 1] = list[i] end
    end
    ns.GetDB().loot = keep
    return n
end
function Loot.Demo()
    Loot.ClearDemo()
    local fights = ns.Encounters.Fights() or {}
    local kill
    for i = 1, #fights do
        local f = fights[i]
        if f.killed and (not kill or f.to > kill.to) then kill = f end
    end
    if not kill then return nil end
    local names = {}
    for name in pairs(kill.players or {}) do names[#names + 1] = name end
    tsort(names)
    if #names == 0 then names[1] = UnitName("player") end
    local list = Store()
    for i = 1, #DEMO do
        local d = DEMO[i]
        local name = GetItemInfo and GetItemInfo(d.id) or d.name
        list[#list + 1] = { t = kill.to + 10 * i, who = names[(i - 1) % #names + 1], id = d.id, n = d.n,
                            name = name, q = d.q, inst = kill.raid and kill.raid.name or "", demo = true }
    end
    return kill
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, msg)
    if event == "PLAYER_LOGIN" then
        Loot.Prune()
    else
        Loot.OnChat(msg)
    end
end)
