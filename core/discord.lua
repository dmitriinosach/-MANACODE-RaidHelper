local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local tsort = table.sort
local tremove = table.remove
local concat = table.concat
local VERSION = 2
local KEEP = 5
local TOP = 10
local HEALERS = 6
local TABLES = 2
local ROWS = 10
local BADGE_TOP = 5
local PARTS = 3
local ZONE = {
    IcecrownCitadel = "icc", TheRubySanctum = "rs", TheArgentColiseum = "toc", Ulduar = "uld",
    Naxxramas = "naxx", TheEyeofEternity = "eoe", OnyxiasLair = "ony", TheObsidianSanctum = "os",
}
local PACK = { icc = "ICC", rs = "RS", toc = "TOC", uld = "ULD" }
local Discord = {}
ns.Discord = Discord
Discord.VERSION, Discord.KEEP, Discord.TOP, Discord.HEALERS = VERSION, KEEP, TOP, HEALERS
Discord.TABLES, Discord.ROWS = TABLES, ROWS
local function Round(n)
    return floor(n + 0.5)
end
local function ByV(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.n < b.n
end
local function ByRaw(a, b)
    if a.raw ~= b.raw then return a.raw > b.raw end
    return a.n < b.n
end
function Discord.Id(res)
    return tostring(res.key)
end
local function Zone(res)
    local map = res.map
    local first = res.sums[1]
    if not (map and ZONE[map]) and first and ns.encRaid then map = ns.encRaid[first.fight.boss] or map end
    return map and ZONE[map] or nil
end
local function RaidName(res, zone)
    local name = zone and PACK[zone] and ns.T("pack." .. PACK[zone]) or ns.Raid.Title(res)
    if not res.size then return name end
    return format(ns.T("dc.raid"), name, res.size, res.heroic and ns.T("dc.hc") or "")
end
local function Cut(list, top)
    tsort(list, ByRaw)
    for k = #list, top + 1, -1 do list[k] = nil end
    for k = 1, #list do list[k].raw = nil end
end
local function Rates(s)
    local sec = max(1, ns.Totals.Time(s))
    local dmg, heal, total = {}, {}, 0
    for k = 1, #s.players do
        local p = s.players[k]
        local d, h = p.dmg or 0, p.heal or 0
        total = total + d
        if p.role ~= "heal" and d > 0 then
            dmg[#dmg + 1] = { n = p.name, c = p.class, v = Round(d / sec), t = Round(d), raw = d }
        end
        if p.role == "heal" and h > 0 then
            heal[#heal + 1] = { n = p.name, c = p.class, v = Round(h / sec), t = Round(h), raw = h }
        end
    end
    Cut(dmg, #dmg)
    Cut(heal, HEALERS)
    return dmg, heal, Round(total)
end
local function BlockTable(s, b)
    local R = ns.MiniRows
    local title = ns.T(b.label or b.def.label)
    local cols, cells, keep = R.Cells(b, s)
    if cols then title = format("%s: %s", title, cols) end
    local hits = R.HasHits(b)
    local list = R.ByWho(b)
    local rows = {}
    for k = 1, min(ROWS, #list) do
        local e = list[k]
        local r = cells[e.who]
        local note = (r and #keep > 0 and R.Pick(r, keep)) or (hits and format("x%d", b.hits[e.who] or 0)) or nil
        rows[k] = { n = e.who, c = R.ClassOf(e.who, s), v = Round(e.v), s = note }
    end
    return { title = title, unit = R.IsCount(b) and "count" or "dmg", rows = rows }
end
local function StackTable(s, i, over)
    local R = ns.MiniRows
    local list = R.Over(s, i)
    local rows = {}
    for k = 1, min(ROWS, #list) do
        local e = list[k]
        rows[k] = { n = e.who, c = e.p.class or R.ClassOf(e.who, s), v = e.v, s = format(ns.T("mini.peak"), e.peak) }
    end
    return { title = format(ns.T("mini.over"), ns.T(s.badges[i].tip or ""), over), unit = "count", rows = rows }
end
local function Targets(f, s)
    local out = {}
    local R = ns.MiniRows
    if not (R and R.Important) then return out end
    local list = R.Important(f, s)
    for k = 1, #list do
        if #out >= TABLES then break end
        local e = list[k]
        local t = e.b and BlockTable(s, e.b) or StackTable(s, e.i, e.over)
        if #t.rows > 0 then out[#out + 1] = t end
    end
    return out
end
local function Bosses(res)
    local order, by = {}, {}
    for k = 1, #res.sums do
        local e = res.sums[k]
        local key = e.fight.boss
        local b = by[key]
        if not b then
            b = { boss = key, tries = 0, wipes = 0 }
            by[key] = b
            order[#order + 1] = b
        end
        b.tries = b.tries + 1
        if e.fight.killed then
            if not b.kill then b.kill = e end
        else
            b.wipes = b.wipes + 1
        end
        b.last = e
    end
    local out = {}
    for i = 1, #order do
        local b = order[i]
        local e = b.kill or b.last
        local dps, hps, damage = Rates(e.s)
        out[i] = { name = ns.EncName(b.boss), kill = b.kill ~= nil, tries = b.tries, wipes = b.wipes,
                   time = Round(ns.Totals.Time(e.s)), start = floor(e.fight.from), damage = damage,
                   deaths = e.s.deaths or 0, dps = dps, hps = hps, targets = Targets(e.fight, e.s),
                   unbuffed = (b.kill and ns.ZoneBuff and b.kill.s.zoneBuff == ns.ZoneBuff.OFF) or nil }
    end
    return out
end
local function Top(res)
    local dmg, sec = {}, {}
    for i = 1, #res.sums do
        local s = res.sums[i].s
        local t = ns.Totals.Time(s)
        for k = 1, #s.players do
            local p = s.players[k]
            dmg[p.name] = (dmg[p.name] or 0) + (p.dmg or 0)
            sec[p.name] = (sec[p.name] or 0) + t
        end
    end
    local list = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if (p.all or 0) > 0 then
            list[#list + 1] = { n = p.name, c = p.class, v = Round((dmg[p.name] or 0) / max(1, sec[p.name] or 0)),
                                t = Round(p.all), raw = p.all }
        end
    end
    Cut(list, TOP)
    return list
end
local function Sum(res, key)
    local n = 0
    for i = 1, #res.players do n = n + (res.players[i][key] or 0) end
    return n
end
local function Immortal(res)
    local out = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if p.deaths == 0 and p.tries > 0 then out[#out + 1] = { n = p.name, c = p.class, tries = p.tries, v = p.tries } end
    end
    tsort(out, ByV)
    for k = 1, #out do out[k].v = nil end
    return out
end
local function Parts(map)
    local list = {}
    for id, e in pairs(map) do
        local n = type(e) == "table" and e.n or e
        if n > 0 then list[#list + 1] = { n = ns.SpellName(id) or tostring(id), v = n } end
    end
    tsort(list, ByV)
    local out = {}
    for k = 1, min(PARTS, #list) do out[k] = format("%s %d", list[k].n, list[k].v) end
    return #out > 0 and concat(out, ", ") or nil
end
local function Badge(res, key, by)
    local list = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if (p[key] or 0) > 0 then list[#list + 1] = { n = p.name, c = p.class, v = p[key], p = p } end
    end
    tsort(list, ByV)
    local out = {}
    for k = 1, min(BADGE_TOP, #list) do
        local e = list[k]
        out[k] = { n = e.n, c = e.c, v = e.v, s = Parts(e.p[by]) }
    end
    return out
end
local function Sniff(res)
    local list = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if (p.jopo or 0) > 0 then
            local by = {}
            for k = 1, #p.jopoBy do
                local name = ns.EncName(p.jopoBy[k].boss)
                by[name] = (by[name] or 0) + 1
            end
            local parts = {}
            for name, n in pairs(by) do parts[#parts + 1] = { n = name, v = n } end
            tsort(parts, ByV)
            local out = {}
            for k = 1, min(PARTS, #parts) do out[k] = format("%s %d", parts[k].n, parts[k].v) end
            list[#list + 1] = { n = p.name, c = p.class, v = p.jopo, k = p.jopoKill > 0 and p.jopoKill or nil,
                                s = concat(out, ", "), w = p.jopoKill * 1000 + p.jopo }
        end
    end
    tsort(list, function(a, b)
        if a.w ~= b.w then return a.w > b.w end
        return a.n < b.n
    end)
    for k = 1, #list do list[k].w = nil end
    return list
end
local function Top5(res)
    local list = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if (p.boss or 0) > 0 then list[#list + 1] = { n = p.name, c = p.class, v = Round(p.boss), raw = p.boss } end
    end
    Cut(list, BADGE_TOP)
    return list
end
local function IconName(tex)
    if type(tex) ~= "string" then return nil end
    local name = (tex:match("([^\\/]+)$") or tex):gsub("%.%w+$", "")
    return name ~= "" and name or nil
end
local function Consumables(res)
    local out = {}
    local groups = ns.RaidModel.SpentGroups(res)
    for i = 1, #groups do
        local g = groups[i]
        local items = {}
        for k = 1, #g.items do
            local e = g.items[k]
            items[k] = { icon = IconName(e.icon), name = e.name, v = e.n, cost = e.cost and Round(e.cost) or nil }
        end
        out[i] = { k = g.cat, label = ns.T("rsum.grp." .. g.cat), v = g.n, cost = g.cost and Round(g.cost) or nil,
                   items = items }
    end
    return out
end
local function Cost(res)
    local c = ns.RaidModel and ns.RaidModel.Cost(res)
    return c and Round(c) or nil
end
function Discord.Build(res)
    local zone = Zone(res)
    local t = res.time or {}
    return {
        id = Discord.Id(res), raid = RaidName(res, zone), zone = zone, size = res.size,
        heroic = res.heroic and true or false, start = floor(res.from), finish = floor(res.to),
        combat = Round(t.combat or 0), idle = Round(t.idle or 0), deaths = Sum(res, "deaths"),
        damage = Round(Sum(res, "all")), healed = Round(Sum(res, "heal")), top = Top(res), bosses = Bosses(res),
        immortal = Immortal(res), rod = Badge(res, "rod", "rodBy"), buffed = Badge(res, "buffN", "buffBy"),
        jopo = Sniff(res), top5 = Top5(res),
        consumables = Consumables(res), cost = Cost(res),
    }
end
local function Box()
    local db = type(ManaCodeRaidHelperDB) == "table" and ManaCodeRaidHelperDB or ns.GetDB()
    local box = db.discord
    if type(box) ~= "table" or box.v ~= VERSION or type(box.posts) ~= "table" then
        box = { v = VERSION, posts = {} }
        db.discord = box
    end
    return box
end
function Discord.Queue(res)
    local post = Discord.Build(res)
    local posts = Box().posts
    for i = #posts, 1, -1 do
        if type(posts[i]) ~= "table" or posts[i].id == post.id then tremove(posts, i) end
    end
    posts[#posts + 1] = post
    while #posts > KEEP do tremove(posts, 1) end
    return post
end
function Discord.Posts()
    return Box().posts
end
