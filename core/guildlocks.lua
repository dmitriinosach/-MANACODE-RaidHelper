local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local tsort = table.sort
local tonumber = tonumber
local type = type
local VERSION = 1
local WEEK = 7 * 86400
local DAY = 86400
local KILL_AGE = 600
local COLLECT_GAP = 10
local CHAR_WEIGHT = 8
local D = ns.guildLocks
local N = ns.guildNotes
local GuildLocks = {}
ns.GuildLocks = GuildLocks
GuildLocks.VERSION = VERSION
local MAPS = {}
do
    local Lower = ns.GuildNotes.Lower
    for _, tbl in ipairs({ ns.L, ns.LEN, ns.LES }) do
        for k, v in pairs(tbl or {}) do
            local map = type(k) == "string" and k:match("^zone%.(.+)$")
            if map and type(v) == "string" then
                MAPS[Lower(v)] = map
                MAPS[Lower(map)] = map
            end
        end
    end
end
local collectedAt = -1e9
local lastKill = nil
local owners = nil
local ownerSrc = nil
local function Store()
    local db = ns.GetDB()
    if type(db) ~= "table" then return nil end
    local st = db.guildLocks
    if type(st) ~= "table" or st.v ~= VERSION then
        st = { v = VERSION, ids = {}, peers = {} }
        db.guildLocks = st
    end
    if type(st.ids) ~= "table" then st.ids = {} end
    if type(st.peers) ~= "table" then st.peers = {} end
    return st
end
GuildLocks.Store = Store
function GuildLocks.MapOf(name)
    if type(name) ~= "string" or name == "" then return nil end
    local low = ns.GuildNotes.Lower(name)
    return MAPS[low] or low
end
local MapOf = GuildLocks.MapOf
function GuildLocks.Same(save, raid)
    local key = MapOf(raid.map) or MapOf(raid.name)
    if not key or save.key ~= key or save.size ~= raid.size then return false end
    if D.sharedDiff[key] then return true end
    return (save.heroic and true or false) == (raid.heroic and true or false)
end
function GuildLocks.NextReset(t)
    local st = Store()
    local a = st and st.reset
    if a then
        local r = a + ceil((t - a) / WEEK) * WEEK
        if r <= t then r = r + WEEK end
        return r
    end
    local left = GetQuestResetTime and tonumber(GetQuestResetTime()) or 0
    local daily = time() + max(0, left)
    local c = daily + ceil((t - daily) / DAY) * DAY
    if c <= t then c = c + DAY end
    for _ = 1, 7 do
        if date("*t", c).wday == D.resetWday then return c end
        c = c + DAY
    end
    return c
end
local function NoteReset(locks)
    local st = Store()
    if not st then return end
    for i = 1, #locks do
        if not locks[i].extended then st.reset = floor(locks[i].to + 0.5) end
    end
end
local function EndsOf(id, at, locks)
    for i = 1, #locks do
        if locks[i].id == id then return floor(locks[i].to + 0.5) end
    end
    return GuildLocks.NextReset(at)
end
local function Mark(st, raid, boss, at, names, locks)
    local key = tostring(raid.id)
    local e = st.ids[key]
    if not e then
        local ends = EndsOf(raid.id, at, locks)
        if ends <= time() then return end
        e = { id = raid.id, key = MapOf(raid.map) or MapOf(raid.name) or "?", name = raid.name, size = raid.size or 0,
            heroic = raid.heroic and true or nil, ends = ends, bosses = {}, who = {} }
        st.ids[key] = e
    end
    if boss ~= nil then e.bosses[tonumber(boss) or boss] = true end
    local members = ns.GuildNotes.Members()
    for name in pairs(names) do
        if members[name] then e.who[name] = max(e.who[name] or 0, at) end
    end
end
local function Take(st, seg, locks)
    local raid, scan = seg.raid, seg.scan
    if type(raid) ~= "table" or not raid.id or type(scan) ~= "table" or type(scan.fights) ~= "table" then return end
    for i = 1, #scan.fights do
        local f = scan.fights[i]
        if f.killed and f.boss and type(f.players) == "table" then
            Mark(st, raid, f.boss, f.to or seg.t1 or 0, f.players, locks)
        end
    end
end
local function Expire(st)
    local now = time()
    for key, e in pairs(st.ids) do
        if type(e) ~= "table" or (e.ends or 0) <= now then st.ids[key] = nil end
    end
end
local function LiveKill(st, locks)
    local rec = ns.Recorder
    if not rec or not rec.LastClose then return end
    local why, enc, at = rec.LastClose()
    if why ~= "kill" or not at or at == lastKill or time() - at > KILL_AGE then return end
    local raid = ns.Raid.Current()
    if not raid or not raid.id then return end
    lastKill = at
    local here = GetRealZoneText and GetRealZoneText()
    local names = {}
    for i = 1, GetNumRaidMembers() do
        local n, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
        if n and online and not (here and zone and zone ~= here) then names[n] = true end
    end
    Mark(st, raid, enc, at, names, locks)
end
function GuildLocks.Collect(force)
    local now = GetTime()
    if not force and now - collectedAt < COLLECT_GAP then return end
    collectedAt = now
    owners = nil
    local st = Store()
    if not st or not ns.GuildNotes.Loaded() then return end
    local locks = ns.Raid.Locks()
    NoteReset(locks)
    if not ns.RecLock() then
        for _, seg in ns.Store.Segments() do Take(st, seg, locks) end
        LiveKill(st, locks)
    end
    Expire(st)
end
function GuildLocks.Raids()
    GuildLocks.Collect()
    local st = Store()
    local out = {}
    for _, e in pairs(st and st.ids or {}) do out[#out + 1] = e end
    tsort(out, function(a, b) return a.ends > b.ends or (a.ends == b.ends and a.id < b.id) end)
    return out
end
local function Norm(s, src)
    if type(s) ~= "table" then return nil end
    local id, ends = tonumber(s.id), tonumber(s.ends or s.to)
    local size = tonumber(s.size)
    if not id or not ends or not size then return nil end
    local key = s.key or MapOf(s.map) or MapOf(s.name)
    if not key then return nil end
    local heroic = s.heroic
    if heroic == nil and tonumber(s.diff) then heroic = tonumber(s.diff) >= 3 end
    return { key = key, name = s.name, size = size, heroic = heroic and true or nil, id = id, ends = ends, src = src }
end
GuildLocks.Norm = Norm
function GuildLocks.Account()
    local db = ns.GetDB()
    local lo = type(db) == "table" and db.lockouts
    if type(lo) ~= "table" then return {} end
    local list = type(lo.chars) == "table" and lo.chars or lo
    local realm = GetRealmName and GetRealmName()
    local out = {}
    for _, c in pairs(list) do
        if type(c) == "table" and type(c.name) == "string" and c.name ~= ""
            and (type(c.realm) ~= "string" or not realm or c.realm == realm) then
            out[#out + 1] = c
        end
    end
    return out
end
local function Me()
    return UnitName("player")
end
local function AccountChar(name)
    local list = GuildLocks.Account()
    for i = 1, #list do
        if list[i].name == name then return list[i] end
    end
    return nil
end
function GuildLocks.SavesOf(name)
    GuildLocks.Collect()
    local now = time()
    local out, seen = {}, {}
    local function Add(s)
        if s and s.ends > now and not seen[s.id .. ":" .. s.key] then
            seen[s.id .. ":" .. s.key] = true
            out[#out + 1] = s
        end
    end
    if name == Me() then
        local locks = ns.Raid.Locks()
        for i = 1, #locks do
            local l = locks[i]
            Add(Norm({ name = l.name, size = l.size, diff = l.diff, id = l.id, ends = l.to }, "own"))
        end
    end
    local acc = AccountChar(name)
    for _, s in pairs(type(acc) == "table" and type(acc.saves) == "table" and acc.saves or {}) do Add(Norm(s, "own")) end
    local ch = ns.GuildSync and ns.GuildSync.Char(name)
    for i = 1, #(ch and ch.saves or {}) do Add(Norm(ch.saves[i], "sync")) end
    local st = Store()
    for _, e in pairs(st and st.ids or {}) do
        if e.who[name] then
            local s = Norm(e, "rec")
            if s then
                s.bosses = e.bosses
                Add(s)
            end
        end
    end
    return out
end
local function Full(name)
    if name == Me() then return ns.Raid.LocksKnown() end
    if AccountChar(name) then return true end
    local prev = GuildLocks.NextReset(time()) - WEEK
    local ch = ns.GuildSync and ns.GuildSync.Char(name)
    return ch ~= nil and (ch.at or 0) >= prev
end
function GuildLocks.Saved(name, raid)
    if type(name) ~= "string" or type(raid) ~= "table" then return nil, nil end
    local saves = GuildLocks.SavesOf(name)
    local same = nil
    for i = 1, #saves do
        local s = saves[i]
        if GuildLocks.Same(s, raid) then
            if raid.id and s.id == raid.id then same = s else return true, s end
        end
    end
    if same then return false, same end
    if Full(name) then return false, nil end
    local GB = ns.GuildBober
    local bs, mine = nil, false
    if GB then bs, mine = GB.Save(name, raid) end
    if bs then return not mine, bs end
    return nil, nil
end
local function AddonGs(name)
    local d = _G.GS_Data
    local realm = GetRealmName and GetRealmName()
    local r = type(d) == "table" and realm and d[realm]
    local p = type(r) == "table" and type(r.Players) == "table" and r.Players[name]
    local v = type(p) == "table" and tonumber(p.GearScore)
    if v and v > 0 then return floor(v + 0.5) end
    local fn = _G.GearScore_GetScore
    if name == Me() and type(fn) == "function" then
        local ok, gs = pcall(fn, name, "player")
        gs = ok and tonumber(gs)
        if gs and gs > 0 then return floor(gs + 0.5) end
    end
    return nil
end
function GuildLocks.MyGs()
    local me = Me()
    return me and AddonGs(me) or nil
end
function GuildLocks.GsOf(name)
    local m = ns.GuildNotes.Member(name)
    if m and m.gs then return m.gs, m.gsSrc end
    local ch = ns.GuildSync and ns.GuildSync.Char(name)
    if ch and ch.gs then return ch.gs, "sync" end
    local acc = AccountChar(name)
    if acc and tonumber(acc.gs) then return tonumber(acc.gs), "own" end
    local gs = AddonGs(name)
    if gs then return gs, "gsaddon" end
    return nil, nil
end
function GuildLocks.MySpec()
    local me = Me()
    local _, cls = UnitClass("player")
    local tree = me and ns.Specs and ns.Specs.Of(me)
    local trees = cls and N.trees[cls]
    return trees and tree and trees[tree] or nil
end
local function ByClass(class)
    local trees = class and N.trees[class]
    if not trees then return nil, nil end
    local spec, role, one, same = trees[1], nil, true, true
    for i = 1, #trees do
        if trees[i] ~= spec then one = false end
        local r = N.specs[trees[i]].role
        if i == 1 then role = r elseif r ~= role then same = false end
    end
    if one then return spec, N.specs[spec].role end
    if same then return nil, role end
    return nil, nil
end
function GuildLocks.RoleOf(name, class)
    local m = ns.GuildNotes.Member(name)
    class = class or (m and m.class)
    if m and (m.spec or m.role) then
        local spec = m.spec
        return spec and N.specs[spec].role or m.role, spec, m.specSrc or m.roleSrc
    end
    local ch = ns.GuildSync and ns.GuildSync.Char(name)
    local spec = ch and ch.spec
    if not spec and name == Me() then spec = GuildLocks.MySpec() end
    if spec and N.specs[spec] then return N.specs[spec].role, spec, ch and ch.spec and "sync" or "own" end
    local s, r = ByClass(class)
    if s or r then return r, s, "class" end
    return nil, nil, nil
end
local function Join(group, src)
    local members = ns.GuildNotes.Members()
    local root = nil
    for name in pairs(group) do
        if members[name] then
            local main = ns.GuildNotes.MainOf(name)
            if main ~= name or next(ns.GuildNotes.AltsOf(name)) then
                root = main
                break
            end
        end
    end
    for name in pairs(group) do
        if members[name] and not root then root = name end
    end
    if not root then return end
    root = owners[root] or root
    for name in pairs(group) do
        if members[name] and owners[name] == name and ownerSrc[name] == nil and name ~= root
            and not next(ns.GuildNotes.AltsOf(name)) then
            owners[name], ownerSrc[name] = root, src
        end
    end
end
function GuildLocks.Owners()
    if owners then return owners, ownerSrc end
    owners, ownerSrc = {}, {}
    for name in pairs(ns.GuildNotes.Members()) do
        local main, src = ns.GuildNotes.MainOf(name)
        owners[name], ownerSrc[name] = main, src
    end
    local acc = {}
    local me = Me()
    if me then acc[me] = true end
    local list = GuildLocks.Account()
    for i = 1, #list do acc[list[i].name] = true end
    Join(acc, "own")
    local sync = ns.GuildSync and ns.GuildSync.Accounts() or {}
    for _, group in pairs(sync) do Join(group, "sync") end
    return owners, ownerSrc
end
function GuildLocks.Person(name)
    local own, src = GuildLocks.Owners()
    local main = own[name] or name
    local out = { [main] = "main" }
    for n, m in pairs(own) do
        if m == main and n ~= main then out[n] = src[n] or "?" end
    end
    return main, out
end
function GuildLocks.GsMin(raid)
    local key = tostring(raid and raid.size or 25) .. ((raid and raid.heroic) and "h" or "")
    return D.gsMin[key] or D.gsMin["25"]
end
local function Better(a, b)
    if a.usable ~= b.usable then return a.usable end
    if a.online ~= b.online then return a.online end
    if (a.gs or 0) ~= (b.gs or 0) then return (a.gs or 0) > (b.gs or 0) end
    return a.name < b.name
end
local function Char(name, m, link, raid, gsMin)
    local saved, save = GuildLocks.Saved(name, raid)
    local gs, gsSrc = GuildLocks.GsOf(name)
    local role, spec, roleSrc = GuildLocks.RoleOf(name, m.class)
    local gsOk = nil
    if gs then gsOk = gs >= gsMin end
    local usable = m.level >= D.level and saved ~= true and gsOk ~= false
    local GB = ns.GuildBober
    local c = { name = name, class = m.class, level = m.level, online = m.online, link = link, saved = saved,
        save = save, gs = gs, gsSrc = gsSrc, gsOk = gsOk, role = role, spec = spec, roleSrc = roleSrc,
        usable = usable, specs = GB and GB.Specs(name, m.class) or {}, rat = false }
    c.roles = GB and GB.Roles(c) or {}
    local bs, mine = nil, false
    if GB then bs, mine = GB.Save(name, raid) end
    c.cur = bs and bs.raid or nil
    c.rat = c.cur ~= nil and not mine and GB.Outside(c.cur)
    return c
end
function GuildLocks.Available(raid, gsMin, all, step)
    gsMin = gsMin or GuildLocks.GsMin(raid)
    GuildLocks.Collect()
    local members = ns.GuildNotes.Members()
    local own, src = GuildLocks.Owners()
    local groups = {}
    for name in pairs(members) do
        local main = own[name] or name
        groups[main] = groups[main] or {}
        groups[main][#groups[main] + 1] = name
    end
    local out = {}
    for main, names in pairs(groups) do
        local online = nil
        for i = 1, #names do
            if members[names[i]].online then online = names[i] end
        end
        if online or all then
            local chars = {}
            for i = 1, #names do
                local n = names[i]
                if step then step(CHAR_WEIGHT) end
                chars[#chars + 1] = Char(n, members[n], n ~= main and (src[n] or "?") or nil, raid, gsMin)
            end
            tsort(chars, Better)
            out[#out + 1] = { name = main, online = online, chars = chars }
        end
    end
    tsort(out, function(a, b) return a.name < b.name end)
    return out
end
local function RoleFits(want, role)
    if want == "hybrid" then return true end
    if want == "dd" then return role == "melee" or role == "ranged" or role == "dd" end
    return role ~= nil and want == role
end
function GuildLocks.Fits(slot, c)
    if not c.usable then return false end
    if type(slot.specs) == "table" and slot.specs[1] then
        for i = 1, #slot.specs do
            local k = slot.specs[i]
            if c.spec then
                if k == c.spec or (c.spec == "feral" and (k == "bear" or k == "cat")) then return true end
            else
                local sp = N.specs[k]
                if sp and sp.class == c.class and c.role and sp.role == c.role then return true end
            end
        end
        return false
    end
    return RoleFits(slot.role, c.role)
end
local function BestFor(slot, p)
    for i = 1, #p.chars do
        if GuildLocks.Fits(slot, p.chars[i]) then return p.chars[i] end
    end
    return nil
end
function GuildLocks.Slots(template, people)
    local slots = type(template) == "table" and type(template.slots) == "table" and template.slots or {}
    local res = { need = { tank = 0, heal = 0, dd = 0 }, have = { tank = 0, heal = 0, dd = 0 }, total = #slots,
        filled = 0, picks = {} }
    local adj = {}
    local order = {}
    for i = 1, #slots do
        local list = {}
        for j = 1, #people do
            if BestFor(slots[i], people[j]) then list[#list + 1] = j end
        end
        adj[i] = list
        order[i] = i
        local g = D.roleGroup[slots[i].role] or "dd"
        res.need[g] = res.need[g] + 1
    end
    tsort(order, function(a, b)
        if #adj[a] ~= #adj[b] then return #adj[a] < #adj[b] end
        return a < b
    end)
    local slotOf, personOf = {}, {}
    local seen
    local function Try(i)
        local list = adj[i]
        for k = 1, #list do
            local j = list[k]
            if not seen[j] then
                seen[j] = true
                if not slotOf[j] or Try(slotOf[j]) then
                    slotOf[j], personOf[i] = i, j
                    return true
                end
            end
        end
        return false
    end
    for k = 1, #order do
        seen = {}
        Try(order[k])
    end
    for i = 1, #slots do
        local j = personOf[i]
        if j then
            local c = BestFor(slots[i], people[j])
            local g = D.roleGroup[slots[i].role] or "dd"
            res.have[g] = res.have[g] + 1
            res.filled = res.filled + 1
            res.picks[#res.picks + 1] = { slot = i, person = people[j].name, char = c.name }
        end
    end
    return res
end
local listeners = {}
function GuildLocks.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Changed()
    for i = 1, #listeners do listeners[i]() end
end
function GuildLocks.Invalidate()
    owners = nil
    Changed()
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.guildlocks", function(_, event)
    owners = nil
    if event == "UPDATE_INSTANCE_INFO" then GuildLocks.Collect(true) end
    Changed()
end))
