local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local S = {}
ns.Session = S
local ROSTER_TTL = 1
local listeners = {}
local deferred = false
local rosterCache, rosterAt, rosterIndex
function S.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function S.Changed()
    if InCombatLockdown() then
        deferred = true
        return
    end
    deferred = false
    for _, fn in ipairs(listeners) do fn() end
end
function S.Flush()
    if deferred then S.Changed() end
end
function S.Invalidate()
    rosterCache = nil
end
local function gather()
    local ch = ns.Store.Char()
    local g = ch.gather
    if not g then
        g = { active = false, tpl = ns.TEMPLATES[1].key, assign = {}, text = 1 }
        ch.gather = g
    end
    g.assign = g.assign or {}
    g.fields = g.fields or { prog = "", reqKind = "none", req = "", loot = "none", time = "" }
    if not ns.Tpl.Exists(g.tpl) then g.tpl = ns.TEMPLATES[1].key end
    return g
end
function S.State()
    return gather()
end
function S.Active()
    return gather().active
end
function S.Template()
    return ns.Tpl.Get(gather().tpl)
end
function S.SetTemplate(key)
    local g = gather()
    if g.active or not ns.Tpl.Exists(key) or g.tpl == key then return end
    g.tpl = key
    g.text = 1
    S.Invalidate()
    S.Changed()
end
function S.TryConvert()
    if not gather().active or ns.Test.Active() then return end
    local raid, party = ns.Compat.GroupSize()
    if raid == 0 and party > 0 and IsPartyLeader() then ConvertToRaid() end
end
function S.Start()
    local g = gather()
    g.active = true
    g.assign = {}
    g.waiting = {}
    S.TryConvert()
    S.Changed()
end
function S.Finish()
    local g = gather()
    g.active = false
    g.assign = {}
    g.waiting = {}
    g.pins = {}
    if ns.Spam then ns.Spam.Stop() end
    S.Changed()
end
function S.Field(k)
    return gather().fields[k]
end
function S.SetField(k, v)
    local f = gather().fields
    if f[k] == v then return end
    f[k] = v
    S.Changed()
end
local function checks()
    local db = ns.Store.DB()
    if not db.checks then
        db.checks = {}
        S.ResetChecks(true)
    end
    return db.checks
end
function S.Checked(key)
    return checks()[key] and true or false
end
function S.SetChecked(key, on)
    checks()[key] = on and true or nil
    S.Changed()
end
function S.ClassChecked(token)
    return not checks()["-" .. token]
end
function S.SetClassChecked(token, on)
    checks()["-" .. token] = (not on) and true or nil
    S.Changed()
end
function S.ResetChecks(silent)
    local db = ns.Store.DB()
    db.checks = {}
    for key, sp in pairs(ns.SPEC) do
        if sp.on then db.checks[key] = true end
    end
    if not silent then S.Changed() end
end
function S.ChecksAreDefault()
    local c = checks()
    for key, sp in pairs(ns.SPEC) do
        if (c[key] and true or false) ~= (sp.on and true or false) then return false end
    end
    for _, cls in ipairs(ns.CLASSES) do
        if c["-" .. cls.token] then return false end
    end
    return true
end
function S.Roster()
    if rosterCache and GetTime() - rosterAt < ROSTER_TTL then return rosterCache end
    local out = {}
    local tpl = S.Template()
    local work = math.floor(tpl.size / 5)
    local raid, party = ns.Compat.GroupSize()
    local here = GetRealZoneText()
    local test = ns.Test and ns.Test.Roster()
    if test then
        for _, m in ipairs(test) do
            out[#out + 1] = { name = m.name, class = m.class, sub = m.sub, index = m.index,
                work = m.sub <= work, online = m.online, dead = m.dead, rank = m.rank,
                role = m.role, ml = m.ml, mark = m.mark, fake = true }
        end
    elseif raid > 0 then
        for i = 1, raid do
            local name, rank, sub, _, _, token, zone, online, dead, role, isML = GetRaidRosterInfo(i)
            if not name or name == UNKNOWNOBJECT then
                out.unknown = true
            else
                out[#out + 1] = { name = name, class = token, sub = sub, unit = "raid" .. i, index = i,
                    work = sub <= work, online = online and true or false, dead = dead and true or false,
                    rank = rank or 0, role = role, ml = isML and true or false,
                    away = online and zone ~= nil and zone ~= here or false }
            end
        end
    else
        local _, token = UnitClass("player")
        out[1] = { name = UnitName("player"), class = token, sub = 1, unit = "player", work = true,
            online = true, rank = IsPartyLeader() and 2 or 0 }
        for i = 1, party do
            local unit = "party" .. i
            local _, t = UnitClass(unit)
            out[#out + 1] = { name = UnitName(unit), class = t, sub = 1, unit = unit, work = true,
                online = UnitIsConnected(unit) and true or false, rank = 0 }
        end
    end
    rosterCache, rosterAt = out, GetTime()
    rosterIndex = {}
    for _, p in ipairs(out) do
        if p.name then rosterIndex[p.name] = p end
    end
    return out
end
function S.Member(name)
    S.Roster()
    return rosterIndex[name]
end
function S.Player(name)
    local db = ns.Store.DB()
    local p = db.players[name]
    if not p then
        p = {}
        db.players[name] = p
    end
    return p
end
function S.SetSpec(name, key, src)
    local p = S.Player(name)
    p.spec, p.specSrc = key, key and src or nil
    S.Changed()
end
function S.SetOff(name, key, src)
    local p = S.Player(name)
    p.off, p.offSrc = key, key and src or nil
    S.Changed()
end
function S.SetNote(name, text)
    S.Player(name).note = (text and text ~= "") and text or nil
    S.Changed()
end
function S.AddOffRoll(name, delta, line)
    local p = S.Player(name)
    p.offRolls = math.max(0, (p.offRolls or 0) + delta)
    if delta > 0 and line then
        p.note = p.note and (p.note .. "; " .. line) or line
    end
    S.Changed()
end
function S.SlotOf(name)
    for i, n in pairs(gather().assign) do
        if n == name then return i end
    end
end
function S.SlotPlayer(i)
    return gather().assign[i]
end
function S.Assign(i, name)
    local g = gather()
    for k, n in pairs(g.assign) do
        if n == name then g.assign[k] = nil end
    end
    g.assign[i] = name
    local slot = S.Template().slots[i]
    local p = S.Player(name)
    if slot and slot.specs and not p.spec then
        local m = S.Member(name)
        local only
        for _, k in ipairs(slot.specs) do
            if m and ns.SPEC[k].class == m.class then
                if only then only = false break end
                only = k
            end
        end
        if only then p.spec, p.specSrc = only, "hand" end
    end
    S.Changed()
end
function S.Unassign(name)
    local g = gather()
    for k, n in pairs(g.assign) do
        if n == name then g.assign[k] = nil end
    end
    S.Changed()
end
local function roleFits(want, role)
    if want == "hybrid" then return true end
    if want == "dd" then return role == "melee" or role == "ranged" end
    return want == role
end
function S.SlotFits(slot, m)
    local spec = S.Player(m.name).spec
    if slot.specs then
        for _, k in ipairs(slot.specs) do
            if spec then
                if k == spec then return true end
            elseif ns.SPEC[k].class == m.class then
                return true
            end
        end
        return false
    end
    if spec then return roleFits(slot.role, ns.SPEC[spec].role) end
    for _, cls in ipairs(ns.CLASSES) do
        if cls.token == m.class then
            for _, sp in ipairs(cls.specs) do
                if roleFits(slot.role, sp.role) then return true end
            end
        end
    end
    return false
end
function S.FreeSlotsFor(m, limit)
    local out, seen = {}, {}
    local assign = gather().assign
    for i, slot in ipairs(S.Template().slots) do
        if not assign[i] and S.SlotFits(slot, m) then
            local sig = slot.role .. ":" .. table.concat(slot.specs or {}, ",")
            if not seen[sig] then
                seen[sig] = true
                out[#out + 1] = i
                if limit and #out >= limit then break end
            end
        end
    end
    return out
end
function S.Unassigned()
    local out = {}
    for _, m in ipairs(S.Roster()) do
        if not S.SlotOf(m.name) then out[#out + 1] = m end
    end
    return out
end
function S.Prune()
    local g = gather()
    local raid, party = ns.Compat.GroupSize()
    if raid == 0 and party == 0 and not ns.Test.Active() then return end
    local roster = S.Roster()
    if roster.unknown then return end
    local present = {}
    for _, m in ipairs(roster) do present[m.name] = true end
    for k, n in pairs(g.assign) do
        if not present[n] then g.assign[k] = nil end
    end
end
function S.Count()
    local n = 0
    for _, p in ipairs(S.Roster()) do
        if p.work then n = n + 1 end
    end
    return n, S.Template().size
end
function S.SlotTaken(i)
    local name = gather().assign[i]
    if not name then return false end
    local m = S.Member(name)
    return m and m.work or false
end
function S.Needs()
    local need, total = {}, {}
    for _, grp in ipairs(ns.GROUP_ORDER) do need[grp], total[grp] = 0, 0 end
    for i, slot in ipairs(S.Template().slots) do
        local grp = ns.ROLE_GROUP[slot.role]
        total[grp] = total[grp] + 1
        if not S.SlotTaken(i) then need[grp] = need[grp] + 1 end
    end
    return need, total
end
function S.NeedTotal()
    local need = S.Needs()
    local n = 0
    for _, v in pairs(need) do n = n + v end
    return n
end
local f = ns.NewFrame("Frame")
ns.Listen(f, "RAID_ROSTER_UPDATE")
ns.Listen(f, "PARTY_MEMBERS_CHANGED")
ns.Listen(f, "RAID_TARGET_UPDATE")
ns.Listen(f, "ZONE_CHANGED_NEW_AREA")
ns.Listen(f, "PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        S.Flush()
        return
    end
    S.Invalidate()
    if event == "PARTY_MEMBERS_CHANGED" then S.TryConvert() end
    S.Prune()
    S.Changed()
end)
function S.FlaskRole(name)
    local p = ns.Store.DB().players[name]
    local sp = p and p.spec and ns.SPEC[p.spec]
    if sp then return sp.role, sp.class end
    if not S.Active() then return nil end
    local i = S.SlotOf(name)
    local slot = i and S.Template().slots[i]
    local role = slot and slot.role
    if role == "tank" or role == "heal" or role == "melee" or role == "ranged" then return role end
    return nil
end
if root.Flasks and root.Flasks.RoleSource then root.Flasks.RoleSource("lead", S.FlaskRole, 20) end
