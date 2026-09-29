local _, ns = ...
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local gmatch, format = string.gmatch, string.format
local tsort, concat = table.sort, table.concat
local HOUR = 3600
local ALCH_DUR = 7000
local EVENING = 8 * HOUR
local RECENT = 12 * HOUR
local PICK = 3
local MELEE_SHARE = 0.15
local AURAS = 40
local DEF = { hours = 3, limit = 2, gap = 50, own = "warn", whisper = false, auto = true }
local Flasks = {}
ns.Flasks = Flasks
Flasks.DEF = DEF
Flasks.HOUR = HOUR
local on = false
local listeners = {}
local sources = {}
local hasSource
local byId
local byKey
local byAura
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
function Flasks.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Opt()
    local s = ns.GetDB().settings
    local o = s.flasks
    if type(o) ~= "table" then
        o = {}
        s.flasks = o
    end
    if type(o.kinds) ~= "table" then o.kinds = {} end
    if type(o.alch) ~= "table" then o.alch = {} end
    for k, v in pairs(DEF) do
        if type(o[k]) ~= type(v) then o[k] = v end
    end
    return o
end
function Flasks.Get(key)
    return Opt()[key]
end
function Flasks.Set(key, v)
    if DEF[key] == nil or type(v) ~= type(DEF[key]) then return end
    Opt()[key] = v
    Notify()
end
local function Index()
    if byId then return end
    byId, byKey = {}, {}
    for i = 1, #ns.flaskItems do
        local it = ns.flaskItems[i]
        byId[it.id] = it
        byKey[it.key] = it
    end
end
function Flasks.ByKey(key)
    Index()
    return byKey[key]
end
function Flasks.ById(id)
    Index()
    return byId[id]
end
function Flasks.Item(kind)
    local key = Opt().kinds[kind]
    return Flasks.ByKey(key or "") or Flasks.ByKey(ns.flaskDefault[kind] or "")
end
function Flasks.ItemKey(kind)
    local it = Flasks.Item(kind)
    return it and it.key or ""
end
function Flasks.SetItem(kind, key)
    if not Flasks.ByKey(key) or not ns.flaskDefault[kind] then return end
    Opt().kinds[kind] = key ~= ns.flaskDefault[kind] and key or nil
    Notify()
end
function Flasks.ItemName(it)
    if not it then return "?" end
    local name = GetItemInfo and GetItemInfo(it.id)
    return name or it.name
end
local function Same(a, b)
    if not a or not b then return false end
    if a.id and b.id then return a.id == b.id end
    return a.name == b.name and a.size == b.size
end
Flasks.Same = Same
local function RaidNow()
    local r = ns.Raid and ns.Raid.Current()
    if not r then return nil end
    return { name = r.name, size = r.size, id = r.id }
end
local function Fresh(now, raid)
    local j = { from = now, last = now, list = {}, hand = {}, raid = raid }
    ns.GetDB().flaskLog = j
    return j
end
function Flasks.Journal(now)
    now = now or time()
    local db = ns.GetDB()
    local j = db.flaskLog
    if type(j) ~= "table" or type(j.list) ~= "table" or type(j.hand) ~= "table" then return Fresh(now, RaidNow()) end
    if now - (j.last or 0) >= EVENING then return Fresh(now, RaidNow()) end
    local raid = RaidNow()
    if raid then
        if not j.raid then
            j.raid = raid
        elseif not Same(j.raid, raid) then
            return Fresh(now, raid)
        elseif raid.id and not j.raid.id then
            j.raid.id = raid.id
        end
    end
    return j
end
function Flasks.Reset(now)
    Fresh(now or time(), RaidNow())
    Notify()
end
local function Count(j, name)
    local n, last = 0, nil
    for i = 1, #j.list do
        local e = j.list[i]
        if e.n == name then
            n = n + (e.c or 1)
            if not last or e.t > last then last = e.t end
        end
    end
    return n, last
end
function Flasks.KindOf(role, class)
    if role == "tank" or role == "sp" or role == "ap" then return role end
    if role == "heal" then return "sp" end
    if role == "melee" then return "ap" end
    if role == "ranged" then return class == "HUNTER" and "ap" or "sp" end
    return nil
end
function Flasks.UnitOf(name)
    for i = 1, GetNumRaidMembers() or 0 do
        local unit = "raid" .. i
        if UnitName(unit) == name then return unit end
    end
    for i = 1, GetNumPartyMembers() or 0 do
        local unit = "party" .. i
        if UnitName(unit) == name then return unit end
    end
    if UnitName("npc") == name then return "npc" end
    return name
end
function Flasks.ClassOf(name)
    local _, token = UnitClass(name)
    if token then return token end
    return ns.Encounters and ns.Encounters.ClassOf and ns.Encounters.ClassOf(name) or nil
end
function Flasks.RoleSource(key, fn, order)
    for i = #sources, 1, -1 do
        if sources[i].key == key then table.remove(sources, i) end
    end
    sources[#sources + 1] = { key = key, fn = fn, order = order or 50 }
    tsort(sources, function(a, b) return a.order < b.order end)
end
function Flasks.Role(name)
    local j = Flasks.Journal()
    local hand = j.hand[name]
    if hand then return hand, "hand" end
    local class = Flasks.ClassOf(name)
    local fixed = class and ns.flaskClass[class]
    if fixed then return fixed, "class" end
    for i = 1, #sources do
        local ok, role, cls = pcall(sources[i].fn, name, class)
        local kind = ok and Flasks.KindOf(role, cls or class)
        if kind then return kind, sources[i].key end
    end
    return nil, nil
end
function Flasks.SetHand(name, kind)
    if kind and not ns.flaskDefault[kind] then return end
    local j = Flasks.Journal()
    j.hand[name] = kind
    Notify()
end
local function MainTank(name, class)
    if not ns.flaskTankClass[class or ""] then return nil end
    for i = 1, GetNumRaidMembers() do
        local n, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(i)
        if n == name then return role == "MAINTANK" and "tank" or nil end
    end
    return nil
end
local function SummaryRole(p, class)
    if p.role == "tank" or p.role == "heal" then return p.role end
    if class and ns.flaskDpsClass[class] then return "melee" end
    local dmg = tonumber(p.dmg) or 0
    if dmg <= 0 then return nil end
    local by = type(p.dmgBy) == "table" and p.dmgBy["#melee"]
    local melee = type(by) == "table" and tonumber(by.a) or 0
    return melee / dmg >= MELEE_SHARE and "melee" or "ranged"
end
local function FromRecord(name, class)
    local E, S = ns.Encounters, ns.Summary
    if not (E and S and E.Ready and E.Ready() and S.Load) then return nil end
    local j = Flasks.Journal()
    local now = time()
    local fights = E.Fights()
    local picked = {}
    for i = 1, #fights do
        local f = fights[i]
        if f.players and f.players[name] and now - (f.from or 0) < RECENT
            and (not j.raid or Same(f.raid, j.raid)) then
            picked[#picked + 1] = f
        end
    end
    tsort(picked, function(a, b) return a.from > b.from end)
    for i = 1, min(PICK, #picked) do
        local s = S.Load(picked[i])
        local p = s and s.byName and s.byName[name]
        local role = p and SummaryRole(p, class or p.class)
        if role then return role, class or p.class end
    end
    return nil
end
Flasks.RoleSource("mt", MainTank, 10)
Flasks.RoleSource("rec", FromRecord, 30)
function Flasks.IsAlchemist(name)
    return Opt().alch[name] == true
end
function Flasks.SetAlchemist(name, yes)
    if not name or name == "" then return end
    Opt().alch[name] = yes and true or nil
    Notify()
end
function Flasks.AlchemistText()
    local list = {}
    for name in pairs(Opt().alch) do list[#list + 1] = name end
    tsort(list)
    return concat(list, ", ")
end
function Flasks.SetAlchemistText(text)
    local set = {}
    for name in gmatch(text or "", "[^,;%s]+") do set[name] = true end
    Opt().alch = set
    Notify()
end
local function AuraIndex()
    if byAura then return end
    byAura = {}
    for i = 1, #ns.flaskItems do
        local it = ns.flaskItems[i]
        local name = GetSpellInfo and GetSpellInfo(it.spell)
        byAura[name or it.name] = it
    end
    for id in pairs(ns.flaskAlchemy) do
        local name = GetSpellInfo and GetSpellInfo(id)
        if name then byAura[name] = true end
    end
end
function Flasks.ScanAura(name)
    AuraIndex()
    local unit = Flasks.UnitOf(name)
    for i = 1, AURAS do
        local aura, _, _, _, _, dur, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then break end
        local hit = byAura[aura]
        if (id and ns.flaskAlchemy[id]) or hit == true or (hit and dur and dur >= ALCH_DUR) then
            if not Flasks.IsAlchemist(name) then Flasks.SetAlchemist(name, true) end
            return true
        end
    end
    return false
end
local function RaidInfoHas(name)
    local bags = PlayerRaidsBags
    if type(bags) ~= "table" or not ns.Bober then return nil end
    local guid = UnitGUID(name)
    local id = guid and ns.Bober.IdFromGuid(guid)
    local raw = id and bags[id]
    if type(raw) ~= "string" then return nil end
    Index()
    local n = 0
    for item, count in gmatch(raw, "(%d+):(%d+)") do
        if byId[tonumber(item)] then n = n + tonumber(count) end
    end
    return n
end
function Flasks.HasSource(fn)
    hasSource = fn
end
function Flasks.Has(name)
    local ok, n = pcall(hasSource or RaidInfoHas, name)
    if ok and type(n) == "number" then return n end
    return nil
end
function Flasks.Norm(name)
    local o = Opt()
    local dur = Flasks.IsAlchemist(name) and 2 or 1
    local norm = min(o.limit, ceil(o.hours / dur - 1e-9))
    return max(1, norm), dur
end
function Flasks.Decide(name, now, stock)
    now = now or time()
    local j = Flasks.Journal(now)
    local n, last = Count(j, name)
    local norm, dur = Flasks.Norm(name)
    local plan = { name = name, give = false, n = n, norm = norm, limit = Opt().limit, dur = dur, alch = dur > 1 }
    plan.kind, plan.src = Flasks.Role(name)
    if plan.kind then plan.item = Flasks.Item(plan.kind) end
    if n >= norm then
        plan.why = "norm"
        return plan
    end
    local gap = Opt().gap * 60 * dur
    if last and now - last < gap then
        plan.why, plan.wait = "gap", gap - (now - last)
        return plan
    end
    plan.has = Flasks.Has(name)
    if plan.has and plan.has > 0 then
        local own = Opt().own
        if own == "skip" then
            plan.why = "own"
            return plan
        end
        if own == "warn" then plan.warn = "own" end
    end
    if not plan.item then
        plan.why = "role"
        return plan
    end
    if stock and (stock(plan.item.id) or 0) < 1 then
        plan.why = "bags"
        return plan
    end
    plan.give = true
    return plan
end
function Flasks.Record(name, item, kind, now, forced, count)
    now = now or time()
    local j = Flasks.Journal(now)
    local c = count and count > 1 and count or nil
    j.list[#j.list + 1] = { n = name, i = item.id, k = kind, t = now, f = forced or nil, c = c }
    j.last = now
    Notify()
end
function Flasks.Stats()
    local j = Flasks.Journal()
    local seen, people, n = {}, 0, 0
    for i = 1, #j.list do
        local who = j.list[i].n
        n = n + (j.list[i].c or 1)
        if not seen[who] then
            seen[who] = true
            people = people + 1
        end
    end
    return n, people
end
function Flasks.Rows()
    local j = Flasks.Journal()
    local rows, byName = {}, {}
    for i = 1, #j.list do
        local e = j.list[i]
        local r = byName[e.n]
        if not r then
            r = { name = e.n, n = 0, items = {}, last = 0 }
            byName[e.n] = r
            rows[#rows + 1] = r
        end
        local c = e.c or 1
        r.n = r.n + c
        r.items[e.i] = (r.items[e.i] or 0) + c
        r.last = max(r.last, e.t)
    end
    tsort(rows, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    return rows
end
function Flasks.Given(raid)
    local j = Flasks.Journal()
    local out = {}
    if raid and not Same(j.raid, raid) then return out end
    for i = 1, #j.list do
        local id = j.list[i].i
        out[id] = (out[id] or 0) + (j.list[i].c or 1)
    end
    return out
end
function Flasks.Minutes(secs)
    return format("%d", max(1, floor(secs / 60 + 0.5)))
end
function Flasks.InGroup()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end
function Flasks.IsOn()
    return on
end
function Flasks.SetOn(v)
    if v and not Flasks.InGroup() then return false, "group" end
    local was = on
    on = v and true or false
    if was ~= on then Notify() end
    return true, nil
end
