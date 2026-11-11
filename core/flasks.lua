local _, ns = ...
local max, min, floor = math.max, math.min, math.floor
local gmatch, format = string.gmatch, string.format
local tsort, concat = table.sort, table.concat
local HOUR = 3600
local ALCH_DUR = 7000
local EVENING = 8 * HOUR
local TOUCH = 600
local RECENT = 12 * HOUR
local PICK = 3
local AURAS = 40
local KIT_ITEMS = 6
local KIT_MAX = 40
local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEF = { own = "warn", whisper = false, auto = true }
local ALCHEMY = { flask = true, elixir = true, potion = true }
local CAT_ORDER = { flask = 1, elixir = 2, potion = 3, food = 4, other = 5 }
local Flasks = {}
ns.Flasks = Flasks
Flasks.DEF = DEF
Flasks.HOUR = HOUR
Flasks.KIT_ITEMS = KIT_ITEMS
Flasks.KIT_MAX = KIT_MAX
local on = false
local listeners = {}
local sources = {}
local byId
local byKey
local byAura
local kindAt = {}
for i = 1, #ns.flaskKinds do kindAt[ns.flaskKinds[i]] = i end
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
function Flasks.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function CopyKit(src, name)
    local roles = {}
    for i = 1, #ns.flaskKinds do
        local kind = ns.flaskKinds[i]
        local list, out = src.roles and src.roles[kind] or {}, {}
        for k = 1, #list do out[k] = { id = list[k].id, n = list[k].n } end
        roles[kind] = out
    end
    return { name = name, roles = roles }
end
local function KitsOf(o)
    local k = o.kits
    if type(k) ~= "table" or type(k.list) ~= "table" or #k.list == 0 then
        k = { list = { CopyKit(ns.flaskKit, ns.T("flask.kit.def")) }, cur = 1 }
        o.kits = k
    end
    if type(k.cur) ~= "number" or not k.list[k.cur] then k.cur = 1 end
end
local function Opt()
    local s = ns.GetDB().settings
    local o = s.flasks
    if type(o) ~= "table" then
        o = {}
        s.flasks = o
    end
    o.kinds, o.hours, o.limit, o.gap = nil, nil, nil, nil
    if type(o.alch) ~= "table" then o.alch = {} end
    for k, v in pairs(DEF) do
        if type(o[k]) ~= type(v) then o[k] = v end
    end
    KitsOf(o)
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
function Flasks.IsKind(kind)
    return kind ~= nil and kindAt[kind] ~= nil
end
function Flasks.Kits()
    return Opt().kits
end
function Flasks.Kit()
    local k = Opt().kits
    return k.list[k.cur]
end
function Flasks.KitItems(kind)
    local kit = Flasks.Kit()
    if type(kit.roles) ~= "table" then kit.roles = {} end
    local list = kit.roles[kind]
    if type(list) ~= "table" then
        list = {}
        kit.roles[kind] = list
    end
    return list
end
function Flasks.KitIds()
    local out, seen = {}, {}
    for i = 1, #ns.flaskKinds do
        local list = Flasks.KitItems(ns.flaskKinds[i])
        for k = 1, #list do
            local id = list[k].id
            if not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    return out
end
function Flasks.Known(id)
    if Flasks.ById(id) then return true end
    local ids = Flasks.KitIds()
    for i = 1, #ids do
        if ids[i] == id then return true end
    end
    return false
end
function Flasks.Norm(kind, id)
    if not Flasks.IsKind(kind) then return 0 end
    local list = Flasks.KitItems(kind)
    for i = 1, #list do
        if list[i].id == id then return list[i].n end
    end
    return 0
end
function Flasks.KitPick(i)
    local k = Opt().kits
    if not k.list[i] or k.cur == i then return end
    k.cur = i
    Notify()
end
local function AddKit(name, from)
    local k = Opt().kits
    local n = #k.list + 1
    k.list[n] = CopyKit(from, name or format(ns.T("flask.kit.new"), n))
    k.cur = n
    Notify()
end
function Flasks.KitNew()
    AddKit(nil, { roles = {} })
end
function Flasks.KitCopy()
    local kit = Flasks.Kit()
    AddKit(format(ns.T("flask.kit.copy"), kit.name or ""), kit)
end
function Flasks.KitRename(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or name == Flasks.Kit().name then return end
    Flasks.Kit().name = name
    Notify()
end
function Flasks.KitDelete()
    local k = Opt().kits
    if #k.list < 2 then return false end
    table.remove(k.list, k.cur)
    k.cur = min(k.cur, #k.list)
    Notify()
    return true
end
function Flasks.KitAdd(kind, id)
    if not Flasks.IsKind(kind) or type(id) ~= "number" then return false end
    local list = Flasks.KitItems(kind)
    if #list >= KIT_ITEMS then return false end
    for i = 1, #list do
        if list[i].id == id then return false end
    end
    list[#list + 1] = { id = id, n = 1 }
    Notify()
    return true
end
function Flasks.KitCount(kind, i, n)
    local e = Flasks.KitItems(kind)[i]
    if not e then return end
    n = max(1, min(KIT_MAX, floor(n)))
    if e.n == n then return end
    e.n = n
    Notify()
end
function Flasks.KitRemove(kind, i)
    local list = Flasks.KitItems(kind)
    if not list[i] then return end
    table.remove(list, i)
    Notify()
end
function Flasks.Name(id)
    local name = GetItemInfo(id)
    if name then return name end
    local c = ns.consumeItems and ns.consumeItems[id]
    if c then return c.craft and GetSpellInfo(c.craft) or c.item end
    local it = Flasks.ById(id)
    local spell = it and GetSpellInfo(it.spell)
    return spell or ("#" .. tostring(id))
end
function Flasks.Icon(id)
    local tex = GetItemIcon and GetItemIcon(id)
    if tex then return tex end
    local _, _, _, _, _, _, _, _, _, t = GetItemInfo(id)
    if t then return t end
    local c = ns.consumeItems and ns.consumeItems[id]
    local _, _, craft = GetSpellInfo(c and c.craft or 0)
    return craft or QMARK
end
function Flasks.IconText(id, size)
    return format("|T%s:%d|t", Flasks.Icon(id), size or 0)
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
local function Count(j, name, id)
    local n = 0
    for i = 1, #j.list do
        local e = j.list[i]
        if e.n == name and (not id or e.i == id) then n = n + (e.c or 1) end
    end
    return n
end
function Flasks.Count(name, id)
    return Count(Flasks.Journal(), name, id)
end
function Flasks.KindOf(role, class)
    if Flasks.IsKind(role) then return role end
    if role == "melee" then return "ap" end
    if role == "ranged" then return class == "HUNTER" and "ap" or "caster" end
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
    tsort(sources, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
end
function Flasks.Role(name)
    local j = Flasks.Journal()
    local hand = j.hand[name]
    if Flasks.IsKind(hand) then return hand, "hand" end
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
    if kind and not Flasks.IsKind(kind) then return end
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
    local melee = ns.IsMelee(p.class and p or { class = class, tree = p.tree, dmg = p.dmg, swingDmg = p.swingDmg })
    if melee == nil then return nil end
    return melee and "melee" or "ranged"
end
local function FromRecord(name, class)
    local E, S = ns.Encounters, ns.Summary
    if not (E and S and E.Ready and E.Ready() and S.Peek) then return nil end
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
        local s = S.Peek(picked[i])
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
        byAura[ns.SpellKey(it.spell)] = it
    end
    for id in pairs(ns.flaskAlchemy) do byAura[ns.SpellKey(id)] = true end
end
function Flasks.ScanAura(name)
    AuraIndex()
    local unit = Flasks.UnitOf(name)
    for i = 1, AURAS do
        local aura, _, _, _, _, dur, _, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then break end
        local hit = id and byAura[ns.SpellKey(id)]
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
function Flasks.Has(name)
    local ok, n = pcall(RaidInfoHas, name)
    if ok and type(n) == "number" then return n end
    return nil
end
function Flasks.Decide(name, now, stock, force)
    now = now or time()
    local j = Flasks.Journal(now)
    local plan = { name = name, give = false, rows = {}, list = {}, short = {}, n = 0, norm = 0,
                   alch = Flasks.IsAlchemist(name) }
    plan.kind, plan.src = Flasks.Role(name)
    if not plan.kind then
        plan.why = "role"
        return plan
    end
    local items, left = Flasks.KitItems(plan.kind), 0
    for i = 1, #items do
        local e = items[i]
        local got = Count(j, name, e.id)
        local row = { id = e.id, norm = e.n, got = got, need = max(0, e.n - got), put = 0,
                      own = Flasks.ById(e.id) ~= nil or nil }
        plan.rows[i] = row
        plan.n, plan.norm, left = plan.n + min(got, e.n), plan.norm + e.n, left + row.need
    end
    if left == 0 then
        plan.why = "norm"
        return plan
    end
    plan.has = Flasks.Has(name)
    local rule = Opt().own
    local theirs = plan.has ~= nil and plan.has > 0
    for i = 1, #plan.rows do
        local row = plan.rows[i]
        if row.need > 0 then
            if row.own and theirs and rule == "skip" and not force then
                row.skip = "own"
                plan.skips = true
            else
                if row.own and theirs and rule ~= "ignore" then plan.warn = "own" end
                row.put = stock and min(row.need, max(0, stock(row.id) or 0)) or row.need
                if row.put > 0 then plan.list[#plan.list + 1] = row end
                if row.put < row.need then plan.short[#plan.short + 1] = row end
            end
        end
    end
    if plan.skips and not plan.warn then plan.warn = "skip" end
    if #plan.list == 0 then
        plan.why = #plan.short > 0 and "bags" or "own"
        return plan
    end
    plan.give = true
    return plan
end
function Flasks.Record(name, id, kind, now, forced, count, manual)
    now = now or time()
    local j = Flasks.Journal(now)
    local c = count and count > 1 and count or nil
    j.list[#j.list + 1] = { n = name, i = id, k = kind, t = now, f = forced or nil, c = c, m = manual or nil }
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
function Flasks.Total()
    local j = Flasks.Journal()
    local n = 0
    for i = 1, #j.list do n = n + (j.list[i].c or 1) end
    return n
end
function Flasks.Rows()
    local j = Flasks.Journal()
    local rows, byName = {}, {}
    for i = 1, #j.list do
        local e = j.list[i]
        local r = byName[e.n]
        if not r then
            r = { name = e.n, n = 0, hand = 0, items = {}, last = 0 }
            byName[e.n] = r
            rows[#rows + 1] = r
        end
        local c = e.c or 1
        r.n = r.n + c
        if e.m then r.hand = r.hand + c end
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
function Flasks.Members()
    local out, me = {}, UnitName("player")
    local n = GetNumRaidMembers() or 0
    if n > 0 then
        for i = 1, n do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if name and name ~= me then out[#out + 1] = { name = name, class = class } end
        end
        return out
    end
    for i = 1, GetNumPartyMembers() or 0 do
        local unit = "party" .. i
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        if name then out[#out + 1] = { name = name, class = class } end
    end
    return out
end
function Flasks.Others(except)
    local j, out = Flasks.Journal(), {}
    local list = Flasks.Members()
    for i = 1, #list do
        local name = list[i].name
        local kind = name ~= except and Flasks.Role(name)
        if kind then
            local items = Flasks.KitItems(kind)
            for k = 1, #items do
                local e = items[k]
                local need = max(0, e.n - Count(j, name, e.id))
                if need > 0 then out[e.id] = (out[e.id] or 0) + need end
            end
        end
    end
    return out
end
local function TableOrder(a, b)
    if a.here ~= b.here then return a.here end
    local ka, kb = kindAt[a.kind or ""] or 9, kindAt[b.kind or ""] or 9
    if ka ~= kb then return ka < kb end
    return a.name < b.name
end
local function TableAdd(rows, byName, name, class, here)
    local r = byName[name]
    if r then
        r.here = r.here or here
        return
    end
    r = { name = name, class = class, here = here, cells = {}, got = 0, norm = 0, short = 0 }
    byName[name] = r
    rows[#rows + 1] = r
end
function Flasks.Table()
    local j = Flasks.Journal()
    local ids = Flasks.KitIds()
    local rows, byName = {}, {}
    local list = Flasks.Members()
    for i = 1, #list do TableAdd(rows, byName, list[i].name, list[i].class, true) end
    for i = 1, #j.list do TableAdd(rows, byName, j.list[i].n, nil, false) end
    for name in pairs(j.hand) do TableAdd(rows, byName, name, nil, false) end
    local t = { ids = ids, rows = rows, given = 0, people = 0, short = 0, miss = 0 }
    t.given, t.people = Flasks.Stats()
    for i = 1, #rows do
        local r = rows[i]
        r.class = r.class or Flasks.ClassOf(r.name)
        r.kind, r.src = Flasks.Role(r.name)
        for k = 1, #ids do
            local id = ids[k]
            local cell = { got = Count(j, r.name, id), norm = Flasks.Norm(r.kind, id) }
            r.cells[id] = cell
            r.got, r.norm = r.got + cell.got, r.norm + cell.norm
            r.short = r.short + max(0, cell.norm - cell.got)
        end
        if r.here and r.short > 0 then
            t.short, t.miss = t.short + 1, t.miss + r.short
        end
    end
    tsort(rows, TableOrder)
    return t
end
function Flasks.InGroup()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end
function Flasks.IsOn()
    return on
end
local function Leader()
    local n = GetNumRaidMembers() or 0
    for i = 1, n do
        local name, rank = GetRaidRosterInfo(i)
        if rank == 2 then return name end
    end
    if n > 0 or (GetNumPartyMembers() or 0) == 0 then return nil end
    local li = GetPartyLeaderIndex() or 0
    if li > 0 then return UnitName("party" .. li) end
    return UnitName("player")
end
local function Save(force)
    local db = ns.GetDB()
    if not on then
        db.flaskOn = nil
        return
    end
    local s, now, key = db.flaskOn, time(), Leader()
    if not force and type(s) == "table" and s.key == (key or s.key) and now - (s.t or 0) < TOUCH then return end
    db.flaskOn = { t = now, key = key or (type(s) == "table" and s.key or nil) }
end
function Flasks.SetOn(v)
    if v and not Flasks.InGroup() then return false, "group" end
    local was = on
    on = v and true or false
    Save(true)
    if was ~= on then Notify() end
    return true, nil
end
function Flasks.Sync()
    local grp = Flasks.InGroup()
    if on then
        if grp then Save(false) else Flasks.SetOn(false) end
        return
    end
    local db = ns.GetDB()
    local s = db.flaskOn
    if type(s) ~= "table" then return end
    if time() - (s.t or 0) >= EVENING then
        db.flaskOn = nil
        return
    end
    if not grp then return end
    local key = Leader()
    if s.key and key and s.key ~= key then
        db.flaskOn = nil
        return
    end
    on = true
    Save(false)
    Notify()
end
function Flasks.Bags()
    local ids, out = Flasks.KitIds(), {}
    for i = 1, #ids do out[i] = { id = ids[i], n = GetItemCount(ids[i]) or 0 } end
    return out
end
local alchIds
local function AlchIds()
    if alchIds then return alchIds end
    alchIds = {}
    for i = 1, #ns.flaskItems do alchIds[ns.flaskItems[i].id] = "flask" end
    for _, c in pairs(ns.consumeCast or {}) do
        if c.id and ALCHEMY[c.cat] then alchIds[c.id] = c.cat end
    end
    return alchIds
end
local function KnownCat(id)
    local c = ns.consumeItems and ns.consumeItems[id]
    return c and c.cat or AlchIds()[id]
end
local function AlchKinds()
    local out = {}
    for i = 1, #ns.flaskAnchor do
        local id = ns.flaskAnchor[i]
        local name, _, _, _, _, class, sub = GetItemInfo(id)
        local cat = KnownCat(id)
        if name and class and sub and cat then out[class .. "/" .. sub] = cat end
    end
    return out
end
function Flasks.Cat(id, kinds)
    local cat = KnownCat(id)
    if cat then return cat end
    local name, _, _, _, _, class, sub = GetItemInfo(id)
    if not (name and class and sub) then return nil end
    return (kinds or AlchKinds())[class .. "/" .. sub]
end
function Flasks.Fits(id, kinds)
    return Flasks.Cat(id, kinds) ~= nil
end
local function AddOrder(a, b)
    if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
    local ca, cb = CAT_ORDER[a.cat] or 9, CAT_ORDER[b.cat] or 9
    if ca ~= cb then return ca < cb end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end
function Flasks.AddList(kind)
    local kinds, out, seen = AlchKinds(), {}, {}
    local list = Flasks.KitItems(kind)
    for i = 1, #list do seen[list[i].id] = true end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            local id = link and tonumber(link:match("item:(%d+)"))
            if id and not seen[id] then
                seen[id] = true
                local cat = Flasks.Cat(id, kinds)
                if cat then out[#out + 1] = { id = id, n = GetItemCount(id) or 0, name = Flasks.Name(id), cat = cat } end
            end
        end
    end
    for id, c in pairs(ns.consumeItems or {}) do
        if not seen[id] then out[#out + 1] = { id = id, n = GetItemCount(id) or 0, name = Flasks.Name(id), cat = c.cat } end
    end
    tsort(out, AddOrder)
    return out
end
