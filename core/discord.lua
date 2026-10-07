local _, ns = ...
local floor = math.floor
local min = math.min
local format = string.format
local tsort = table.sort
local tremove = table.remove
local VERSION = 1
local KEEP = 5
local TOP = 25
local DEATHS = 5
local Discord = {}
ns.Discord = Discord
Discord.VERSION, Discord.KEEP, Discord.TOP = VERSION, KEEP, TOP
local function Round(n)
    return floor(n + 0.5)
end
function Discord.Id(res)
    return format("%d-%d-%d", floor(res.from or 0), res.tries or 0, floor(res.to or 0))
end
local function Rows(s)
    local sec = ns.Totals.Time(s)
    local list, total = {}, 0
    for k = 1, #s.players do
        local p = s.players[k]
        local dmg = p.dmg or 0
        total = total + dmg
        if p.role ~= "heal" and dmg > 0 then list[#list + 1] = p end
    end
    tsort(list, function(a, b)
        if a.dmg ~= b.dmg then return a.dmg > b.dmg end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, min(TOP, #list) do
        local p = list[i]
        out[i] = { name = p.name, class = p.class, spec = p.tree, dps = Round(p.dmg / sec), dmg = Round(p.dmg) }
    end
    return out, total / sec
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
        local rows, dps = Rows(e.s)
        out[i] = { name = ns.EncName(b.boss), kill = b.kill ~= nil, time = Round(ns.Totals.Time(e.s)),
                   tries = b.tries, wipes = b.wipes, deaths = e.s.deaths or 0, dps = Round(dps), rows = rows }
    end
    return out
end
local function Deaths(res)
    local list, total = {}, 0
    for k = 1, #res.players do
        local p = res.players[k]
        if p.deaths > 0 then
            list[#list + 1] = p
            total = total + p.deaths
        end
    end
    tsort(list, function(a, b)
        if a.deaths ~= b.deaths then return a.deaths > b.deaths end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, min(DEATHS, #list) do
        out[i] = { name = list[i].name, class = list[i].class, n = list[i].deaths }
    end
    return out, total
end
function Discord.Build(res)
    local deaths, dead = Deaths(res)
    return {
        id = Discord.Id(res), raid = res.name or ns.T("raid.none"), size = res.size, heroic = res.heroic and true or false,
        date = date("%d.%m.%Y", floor(res.from)), from = floor(res.from), to = floor(res.to), busy = Round(res.busy),
        tries = res.tries or 0, wipes = res.wipes or 0, passed = res.passed or 0, known = res.known,
        players = #res.players, bosses = Bosses(res), deaths = deaths, dead = dead, made = time(),
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
