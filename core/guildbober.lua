local _, ns = ...
local tonumber, type, ipairs = tonumber, type, ipairs
local strsub, strmatch, format = string.sub, string.match, string.format
local WEEK = 7 * 86400
local D = ns.guildLocks
local GB = {}
ns.GuildBober = GB
local SHORT = {}
for i = 1, #D.raids do SHORT[D.raids[i].map] = D.raids[i].short end
function GB.Warm(fn)
    local b = ns.Bober
    if b and b.Ready() then b.WhenIndexed(fn) end
end
local function RecOf(name)
    local b = ns.Bober
    if type(name) ~= "string" or not b or not b.Indexed() then return nil end
    local id = b.FindId(name)
    return id and b.Get(id) or nil
end
function GB.Rec(name)
    if type(name) ~= "string" or not ns.GuildNotes.Members()[name] then return nil end
    return RecOf(name)
end
function GB.Modes(raid)
    local GL = ns.GuildLocks
    local key = raid and (GL.MapOf(raid.map) or GL.MapOf(raid.name))
    local short = key and SHORT[key]
    local b = ns.Bober
    if not short or not b or not b.ZONES[short] then return {} end
    local size = tostring(raid.size or 25)
    if D.sharedDiff[key] then return { short .. size .. "h", short .. size .. "n" } end
    return { short .. size .. (raid.heroic and "h" or "n") }
end
local function WeekStart()
    local d = date("*t", ns.GuildLocks.NextReset(time()) - WEEK)
    return format("%02d%02d%02d", d.year % 100, d.month, d.day)
end
function GB.Time(ymd)
    local y, m, d = strmatch(ymd or "", "^(%d%d)(%d%d)(%d%d)$")
    if not y then return nil end
    return time({ year = 2000 + tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end
local function Mine(rid, modes)
    local rec = rid and RecOf(UnitName("player"))
    if not rec then return false end
    local list = ns.Bober.RaidsIn(rec, modes)
    for i = 1, #list do
        if list[i].rid == rid then return true end
    end
    return false
end
function GB.Save(name, raid)
    local rec = GB.Rec(name)
    if not rec then return nil, false end
    local modes = GB.Modes(raid)
    if #modes == 0 then return nil, false end
    local since = WeekStart()
    local list = ns.Bober.RaidsIn(rec, modes)
    for i = 1, #list do
        local r = list[i]
        if r.date < since then break end
        if (r.killed or 0) > 0 then
            local GL = ns.GuildLocks
            local save = { key = GL.MapOf(raid.map) or GL.MapOf(raid.name), size = raid.size,
                heroic = strsub(r.mode, -1) == "h" or nil, id = 0, ends = GL.NextReset(time()), src = "bober", raid = r }
            return save, Mine(r.rid, modes)
        end
    end
    return nil, false
end
function GB.LeadGuild(r)
    local lead = r.lead
    if not lead then return nil end
    if ns.GuildNotes.Members()[lead] then return GetGuildInfo and GetGuildInfo("player") or nil end
    local b = ns.Bober
    local id = b and b.Indexed() and b.FindId(lead)
    local e = id and type(PlayerRaidsGuilds) == "table" and PlayerRaidsGuilds[id]
    local g = type(e) == "table" and e.cur
    return type(g) == "string" and g ~= "" and g or nil
end
function GB.Outside(r)
    local mine = GetGuildInfo and GetGuildInfo("player")
    if not mine then return true end
    return r.guild ~= mine and GB.LeadGuild(r) ~= mine
end
function GB.Specs(name, class)
    local out = {}
    local rec = GB.Rec(name)
    if not rec then return out end
    class = class or rec.class
    local trees = D.boberTrees[class or ""] or {}
    for _, sp in ipairs(ns.Bober.Specs(rec)) do
        local tree = D.boberAlias[sp.tree] or sp.tree
        local label = sp.tree
        for i = 1, #trees do
            if trees[i] == tree then
                label = ns.T("spec." .. class .. "." .. i)
                break
            end
        end
        out[#out + 1] = { role = D.boberRole[sp.role] or "dd", label = label, n = sp.n }
    end
    return out
end
function GB.Roles(c)
    local out = {}
    for _, sp in ipairs(c.specs or {}) do out[sp.role] = true end
    if c.role and c.role ~= "hybrid" then out[D.roleGroup[c.role] or "dd"] = true end
    return out
end
