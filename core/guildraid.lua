local _, ns = ...
local format = string.format
local type = type
local D = ns.guildLocks
local GuildRaid = {}
ns.GuildRaid = GuildRaid
local byKey = {}
for i = 1, #D.raids do byKey[D.raids[i].key] = D.raids[i] end
function GuildRaid.List()
    return D.raids
end
function GuildRaid.Get(key)
    return key and byKey[key] or nil
end
function GuildRaid.Label(r)
    return ns.T("gl.raid." .. r.short) .. " " .. format(ns.T(r.heroic and "cd.size.h" or "cd.size.n"), r.size)
end
local function Settings()
    local db = ns.GetDB()
    local s = type(db) == "table" and db.settings
    return type(s) == "table" and s or nil
end
function GuildRaid.LeadTemplate()
    local L = ns.Lead
    local S = L and L.Session
    if not S or not S.Template then return nil end
    return S.Template()
end
function GuildRaid.ForTemplate(tpl)
    if type(tpl) ~= "table" then return nil end
    local base = D.tplRaid[tpl.base or ""] or D.tplRaid[tpl.key or ""]
    if not base then return nil end
    for i = 1, #D.raids do
        local r = D.raids[i]
        if r.short == base.short and r.size == tpl.size and (r.heroic and true or false) == (base.heroic and true or false) then
            return r.key
        end
    end
    return nil
end
function GuildRaid.Pick()
    local s = Settings()
    local key = s and s.glRaid
    if byKey[key or ""] then return key end
    return GuildRaid.ForTemplate(GuildRaid.LeadTemplate()) or D.defaultRaid
end
function GuildRaid.SetPick(key)
    local s = Settings()
    if s and byKey[key] then s.glRaid = key end
end
function GuildRaid.OnlineOnly()
    local s = Settings()
    return s and s.glOnline and true or false
end
function GuildRaid.SetOnlineOnly(on)
    local s = Settings()
    if s then s.glOnline = on and true or nil end
end
function GuildRaid.RoleOn(group)
    local s = Settings()
    return s and type(s.glRoles) == "table" and s.glRoles[group] == true or false
end
function GuildRaid.SetRole(group, on)
    local s = Settings()
    if not s then return end
    if type(s.glRoles) ~= "table" then s.glRoles = {} end
    s.glRoles[group] = on and true or nil
    if next(s.glRoles) == nil then s.glRoles = nil end
end
local function OwnId(q)
    local GL = ns.GuildLocks
    local locks = ns.Raid.Locks()
    for i = 1, #locks do
        local l = locks[i]
        local s = GL.Norm({ name = l.name, size = l.size, diff = l.diff, id = l.id, ends = l.to }, "own")
        if s and GL.Same(s, q) then return l.id end
    end
    return nil
end
function GuildRaid.Query(r)
    local q = { map = r.map, size = r.size, heroic = r.heroic }
    q.id = OwnId(q)
    return q
end
function GuildRaid.Template(r)
    local cur = GuildRaid.LeadTemplate()
    if type(cur) == "table" and cur.size == r.size and type(cur.slots) == "table" then return cur end
    local list = ns.Lead and ns.Lead.TEMPLATES or {}
    local any = nil
    for i = 1, #list do
        local t = list[i]
        if t.size == r.size then
            if GuildRaid.ForTemplate(t) == r.key then return t end
            any = any or t
        end
    end
    return any
end
function GuildRaid.Target(tpl)
    local key = GuildRaid.ForTemplate(tpl)
    if not key then
        local cur = ns.Raid.Current()
        if cur then
            local map = ns.GuildLocks.MapOf(cur.name)
            for i = 1, #D.raids do
                local r = D.raids[i]
                if r.map == map and r.size == cur.size and (not r.heroic) == (not cur.heroic) then key = r.key end
            end
            if not key then
                return { name = cur.name, size = cur.size, heroic = cur.heroic, id = cur.id },
                    cur.name .. " " .. format(ns.T(cur.heroic and "cd.size.h" or "cd.size.n"), cur.size)
            end
        end
    end
    local r = byKey[key or GuildRaid.Pick()]
    return GuildRaid.Query(r), GuildRaid.Label(r)
end
