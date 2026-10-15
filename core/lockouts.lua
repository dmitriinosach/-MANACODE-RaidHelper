local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local tsort = table.sort
local VERSION = 1
local WEEK = 7 * 86400
local TOP_LEVEL = 80
local LFG = "Interface\\LFGFrame\\LFGIcon-"
local ICON = {
    IcecrownCitadel = "IcecrownCitadel",
    TheRubySanctum = "RubySanctum",
    Ulduar = "Ulduar",
    TheArgentColiseum = "ArgentRaid",
    TrialoftheGrandCrusader = "ArgentRaid",
    Naxxramas = "Naxxramas",
    TheEyeofEternity = "Malygos",
    TheObsidianSanctum = "ChamberOfAspects",
    OnyxiasLair = "OnyxiaEncounter",
    VaultofArchavon = "VaultOfArchavon",
}
local Lockouts = {}
ns.Lockouts = Lockouts
Lockouts.TOP_LEVEL = TOP_LEVEL
local listeners = {}
local function Store()
    local db = ns.GetDB()
    if type(db) ~= "table" then return nil end
    local s = db.lockouts
    if type(s) ~= "table" or s.v ~= VERSION or type(s.chars) ~= "table" then
        s = { v = VERSION, chars = {} }
        db.lockouts = s
    end
    return s
end
function Lockouts.Key(name, realm)
    return name .. "-" .. realm
end
function Lockouts.MyKey()
    local name = UnitName("player")
    if not name then return nil end
    return Lockouts.Key(name, GetRealmName and GetRealmName() or "")
end
local function SaveOf(lock)
    local raid = lock.raid and true or nil
    local heroic
    if raid then heroic = lock.diff == 3 or lock.diff == 4 else heroic = lock.diff == 2 end
    return {
        name = lock.name,
        map = ns.zoneByName and ns.zoneByName[lock.name] or nil,
        id = lock.id,
        diff = lock.diff,
        size = lock.size,
        heroic = heroic or nil,
        raid = raid,
        to = floor(lock.to),
        extended = lock.extended,
    }
end
local function Changed()
    for i = 1, #listeners do listeners[i]() end
end
local function Prune(s, now)
    for _, c in pairs(s.chars) do
        local keep = {}
        for i = 1, #(c.saves or {}) do
            local v = c.saves[i]
            if (v.to or 0) > now then keep[#keep + 1] = v end
        end
        c.saves = keep
    end
end
function Lockouts.Snapshot()
    local s = Store()
    local name = UnitName("player")
    if not s or not name or not ns.Raid then return nil end
    local realm = GetRealmName and GetRealmName() or ""
    local _, class = UnitClass("player")
    local now = time()
    local c = {
        name = name,
        realm = realm,
        class = class,
        level = UnitLevel("player") or 0,
        at = now,
        saves = {},
    }
    local locks = ns.Raid.Locks(true)
    for i = 1, #locks do
        local v = SaveOf(locks[i])
        c.saves[#c.saves + 1] = v
        if v.raid and (not s.reset or v.to < s.reset or s.reset <= now) then s.reset = v.to end
    end
    s.chars[Lockouts.Key(name, realm)] = c
    Prune(s, now)
    Changed()
    return c
end
function Lockouts.Refresh()
    if RequestRaidInfo then RequestRaidInfo() end
    if ns.Raid and ns.Raid.LocksKnown() then Lockouts.Snapshot() end
end
function Lockouts.LastReset(now)
    local s = Store()
    local r = s and s.reset
    if not r then return nil end
    if r <= now then r = r + ceil((now - r + 1) / WEEK) * WEEK end
    return r - WEEK
end
function Lockouts.Remove(key)
    local s = Store()
    if not s or key == Lockouts.MyKey() then return end
    s.chars[key] = nil
    Changed()
end
function Lockouts.Chars(now)
    local s = Store()
    if not s then return {} end
    now = now or time()
    Prune(s, now)
    local mine, last = Lockouts.MyKey(), Lockouts.LastReset(now)
    local out = {}
    for key, c in pairs(s.chars) do
        out[#out + 1] = { key = key, char = c, current = key == mine, stale = last ~= nil and (c.at or 0) < last }
    end
    tsort(out, function(a, b)
        if a.current ~= b.current then return a.current end
        local la, lb = a.char.level or 0, b.char.level or 0
        if la ~= lb then return la > lb end
        return a.key < b.key
    end)
    return out
end
function Lockouts.Saves(c)
    local out = {}
    for i = 1, #(c.saves or {}) do out[#out + 1] = c.saves[i] end
    tsort(out, function(a, b)
        if (a.raid and true or false) ~= (b.raid and true or false) then return a.raid and true or false end
        if a.name ~= b.name then return a.name < b.name end
        if a.size ~= b.size then return a.size < b.size end
        return (a.heroic and 1 or 0) < (b.heroic and 1 or 0)
    end)
    return out
end
function Lockouts.Summary(map, sizes, now)
    local out = {}
    for i = 1, #sizes do out[sizes[i]] = { free = {}, normal = {}, heroic = {} } end
    local rows = Lockouts.Chars(now)
    for i = 1, #rows do
        local c = rows[i].char
        local taken = {}
        for k = 1, #c.saves do
            local v = c.saves[k]
            local cell = v.map == map and out[v.size]
            if cell and not taken[v.size] then
                taken[v.size] = true
                local list = v.heroic and cell.heroic or cell.normal
                list[#list + 1] = c.name
            end
        end
        if (c.level or 0) >= TOP_LEVEL then
            for size, cell in pairs(out) do
                if not taken[size] then cell.free[#cell.free + 1] = c.name end
            end
        end
    end
    return out
end
function Lockouts.Kills(rows)
    local want = {}
    for i = 1, #rows do
        local c = rows[i].char
        for k = 1, #c.saves do
            local id = c.saves[k].id
            want[id] = want[id] or {}
            want[id][c.name] = {}
        end
    end
    local out = {}
    if not ns.Store or not next(want) then return out end
    for _, seg in ns.Store.Segments() do
        local id = seg.raid and tonumber(seg.raid.id)
        local names = id and want[id]
        local fights = names and seg.scan and seg.scan.fights
        for f = 1, (fights and #fights or 0) do
            local fight = fights[f]
            if fight.killed and fight.players then
                for name, seen in pairs(names) do
                    if fight.players[name] ~= nil and not seen[fight.boss] then
                        seen[fight.boss] = true
                        out[id] = out[id] or {}
                        local list = out[id][name] or {}
                        out[id][name] = list
                        list[#list + 1] = fight.boss
                    end
                end
            end
        end
    end
    return out
end
function Lockouts.Icon(v)
    local key = v.map and ICON[v.map]
    if key then return LFG .. key end
    return LFG .. (v.raid and "Raid" or "Dungeon")
end
function Lockouts.Title(v)
    return v.map and rawget(ns.L, "zone." .. v.map) or v.name
end
function Lockouts.Left(sec)
    if sec < 60 then sec = 60 end
    local d = floor(sec / 86400)
    local h = floor((sec % 86400) / 3600)
    local m = floor((sec % 3600) / 60)
    if d > 0 then return string.format(ns.T("cd.left.dh"), d, h) end
    if h > 0 then return string.format(ns.T("cd.left.hm"), h, m) end
    return string.format(ns.T("cd.left.m"), m)
end
function Lockouts.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UPDATE_INSTANCE_INFO")
watcher:SetScript("OnEvent", ns.Prof.Wrap("bg.lockouts", function()
    Lockouts.Snapshot()
end))
