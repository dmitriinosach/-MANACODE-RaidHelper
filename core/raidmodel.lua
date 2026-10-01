local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local TOP = 5
local HOUR = 3600
local Model = {}
ns.RaidModel = Model
local function T(key)
    return ns.T(key)
end
function Model.Short(n)
    if n >= 1e6 then return format("%.2f", n / 1e6) .. ns.T("num.m") end
    if n >= 1e5 then return format("%.0f", n / 1e3) .. ns.T("num.k") end
    if n >= 1e3 then return format("%.1f", n / 1e3) .. ns.T("num.k") end
    return tostring(floor(n + 0.5))
end
local Short = Model.Short
local function Dec(v, digits)
    return ns.Dec(format("%." .. digits .. "f", v))
end
local function Stamp(t)
    return date("%d.%m %H:%M", t)
end
function Model.Span(res)
    local d0, d1 = date("%d.%m", res.from), date("%d.%m", res.to)
    if d0 == d1 then return format(T("rsum.span.day"), d0, date("%H:%M", res.from), date("%H:%M", res.to)) end
    return format(T("rsum.span.days"), Stamp(res.from), Stamp(res.to))
end
local function Put(out, kind, left, right, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, tone = tone }
end
local function Sum(res, key)
    local n = 0
    for i = 1, #res.players do n = n + (res.players[i][key] or 0) end
    return n
end
local function TrashDeaths(res)
    local n = 0
    for i = 1, #res.players do n = n + (res.players[i].deathBy[ns.RaidSummary.TRASH] or 0) end
    return n
end
local function Totals(res)
    local deaths, heal = Sum(res, "deaths"), Sum(res, "heal")
    local hours = Dec(res.busy / HOUR, 1)
    local timeTip = {
        { kind = "head", left = T("rsum.t.time") },
    }
    Put(timeTip, "row", T("rsum.tt.from"), Stamp(res.from))
    Put(timeTip, "row", T("rsum.tt.to"), Stamp(res.to))
    Put(timeTip, "row", T("rsum.tt.busy"), format(T("rsum.hours"), hours))
    Put(timeTip, "row", T("rsum.tt.sessions"), tostring(res.sessions))
    local sub = Model.Span(res)
    if res.sessions > 1 then sub = format(T("rsum.t.sessions"), sub, res.sessions) end
    local encTip = { { kind = "head", left = T("rsum.t.encs") } }
    Put(encTip, "row", T("rsum.tt.passed"), tostring(res.passed))
    Put(encTip, "row", T("rsum.tt.tried"), tostring(res.encs))
    if res.known then Put(encTip, "row", T("rsum.tt.known"), tostring(res.known)) end
    return {
        { title = T("rsum.t.time"), value = format(T("rsum.hours"), hours), sub = sub, color = "text.accent",
          lines = timeTip },
        { title = T("rsum.t.wipes"), value = tostring(res.wipes), sub = format(T("rsum.t.tries"), res.tries),
          color = "sem.wipe" },
        { title = T("rsum.t.encs"), value = format("%d/%d", res.passed, max(res.known or 0, res.encs)),
          sub = T("rsum.t.killed"), color = "sem.win", lines = encTip },
        { title = T("rsum.t.deaths"), value = tostring(deaths),
          sub = res.trash > 0 and format(T("rsum.t.trashdeaths"), TrashDeaths(res)) or nil, color = "sem.death" },
        { title = T("rsum.t.heal"), value = Short(heal), color = "sem.heal" },
    }
end
local function Ranked(res, key)
    local list = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if (p[key] or 0) > 0 then list[#list + 1] = p end
    end
    tsort(list, function(a, b)
        if a[key] ~= b[key] then return a[key] > b[key] end
        return a.name < b.name
    end)
    return list
end
local function DamageTip(res, p, share)
    local out = { { kind = "head", left = p.name, right = share, class = p.class } }
    Put(out, "row", T("rsum.d.all"), Short(p.all))
    if res.cut then Put(out, "row", T("rsum.d.cut"), Short(p.cut)) end
    Put(out, "row", T("rsum.d.enc"), Short(p.enc))
    Put(out, "row", T("rsum.d.boss"), Short(p.boss))
    return out
end
local function Damage(res, key, label)
    local list = Ranked(res, key)
    local total = Sum(res, key)
    local rows = {}
    for i = 1, min(TOP, #list) do
        local p = list[i]
        local share = format("%.1f%%", p[key] / max(1, total) * 100)
        rows[i] = { who = p.name, class = p.class, text = Short(p[key]), note = share, v = p[key],
                    lines = DamageTip(res, p, share) }
    end
    return { key = key, title = format(T("rsum.title.sum"), T(label), Short(total)), rows = rows,
             empty = T("rsum.none") }
end
local function Heal(res)
    local list = Ranked(res, "heal")
    local rows = {}
    for i = 1, min(TOP, #list) do
        local p = list[i]
        local tip = { { kind = "head", left = p.name, class = p.class } }
        Put(tip, "row", T("rsum.tt.heal"), Short(p.heal))
        rows[i] = { who = p.name, class = p.class, text = Short(p.heal), v = p.heal, lines = tip }
    end
    return { key = "heal", title = format(T("rsum.title.sum"), T("rsum.d.heal"), Short(Sum(res, "heal"))),
             rows = rows, empty = T("rsum.none") }
end
local function Pairs(map)
    local list = {}
    for k, v in pairs(map) do
        list[#list + 1] = { k = k, v = v, s = type(k) == "number" and ns.EncName(k) or tostring(k) }
    end
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.s < b.s
    end)
    return list
end
local function Deaths(res)
    local list = Ranked(res, "deaths")
    local rows = {}
    for i = 1, #list do
        local p = list[i]
        local tip = { { kind = "head", left = p.name, right = tostring(p.deaths), class = p.class } }
        local by = Pairs(p.deathBy)
        for k = 1, #by do
            local where = by[k].k == ns.RaidSummary.TRASH and T("rsum.trash") or by[k].s
            Put(tip, "row", where, tostring(by[k].v))
        end
        rows[i] = { who = p.name, class = p.class, text = tostring(p.deaths), v = p.deaths, lines = tip }
    end
    return { key = "deaths", title = format(T("rsum.title.sum"), T("rsum.d.deaths"), tostring(Sum(res, "deaths"))),
             rows = rows, empty = T("rsum.nodeaths") }
end
local function GP(res)
    local by, offer, issued = ns.RaidSummary.GP(res)
    if not by then
        return { key = "gp", title = T("rsum.d.gp"), rows = {}, empty = T("rsum.nogp") }
    end
    local rows = {}
    for name, g in pairs(by) do
        if g.offer > 0 then
            local p = res.byName[name]
            local tip = { { kind = "head", left = name, class = p and p.class } }
            Put(tip, "row", T("rsum.tt.offer"), tostring(g.offer))
            Put(tip, "row", T("rsum.tt.issued"), tostring(g.issued))
            Put(tip, "row", T("rsum.tt.faults"), tostring(g.n))
            rows[#rows + 1] = { who = name, class = p and p.class, text = tostring(g.offer), v = g.offer,
                                note = g.issued > 0 and format(T("rsum.issued"), g.issued) or nil, lines = tip }
        end
    end
    tsort(rows, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.who < b.who
    end)
    return { key = "gp", title = format(T("rsum.title.gp"), offer, issued), rows = rows, empty = T("rsum.nogpyet") }
end
local DRUNK = { flask = true, elixir = true, potion = true }
local ICON_ROW = 15
local ICON_TIP = 14
local function Inline(id, size, spell)
    local tex = ns.RaidCost.Icon(id, spell)
    if not tex then return "" end
    return format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tex, size, size)
end
local function Prices(res)
    local out = { by = {}, c = {} }
    for i = 1, #res.spent do
        local sp = res.spent[i]
        out.by[sp.item] = sp
        out.c[sp.item] = (not sp.free and ns.RaidCost.Price(sp.item)) or false
    end
    return out
end
local function PlayerCost(pr, p)
    local c, miss = 0, 0
    for item, n in pairs(p.used) do
        local sp = pr.by[item]
        if sp and not sp.free and DRUNK[sp.cat] then
            local each = pr.c[item]
            if each then c = c + each * n else miss = miss + n end
        end
    end
    return c, miss
end
local function CostLines(tip, pr, p)
    local c, miss = PlayerCost(pr, p)
    if c <= 0 and miss <= 0 then return end
    Put(tip, "sep")
    Put(tip, "row", T("rsum.tt.cost"), c > 0 and ns.RaidCost.Gold(c) or T("rsum.noprice"))
    if miss > 0 then Put(tip, "note", format(T("rsum.tt.unpriced"), miss)) end
end
local function UseTip(res, pr, p)
    local tip = { { kind = "head", left = p.name, class = p.class } }
    local list = Pairs(p.used)
    local any = false
    for k = 1, #list do
        local sp = pr.by[list[k].k]
        if sp and DRUNK[sp.cat] then
            any = true
            tip[#tip + 1] = { kind = "row", left = Inline(sp.id, ICON_TIP, sp.spell) .. " " .. list[k].k,
                              right = format("x%d", list[k].v) }
        end
    end
    if not any then Put(tip, "note", T("rsum.tt.nodrunk")) end
    CostLines(tip, pr, p)
    return tip
end
local function Drunk(res, pr)
    local rows = {}
    local flasks, potions = 0, 0
    for i = 1, #res.players do
        local p = res.players[i]
        local fl, po = p.flask + p.elixir, p.potion
        flasks, potions = flasks + fl, potions + po
        local parts, list = {}, Pairs(p.used)
        for k = 1, #list do
            local sp = pr.by[list[k].k]
            if sp then parts[#parts + 1] = Inline(sp.id, ICON_ROW, sp.spell) .. list[k].v end
        end
        rows[#rows + 1] = { who = p.name, class = p.class, text = concat(parts, "  "),
                            v = fl * 1000 + po, lines = UseTip(res, pr, p) }
    end
    tsort(rows, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.who < b.who
    end)
    return { key = "drunk", title = T("rsum.title.drunk"), rows = rows,
             empty = T("rsum.none") }
end
local function PriceNote(sp, each)
    if not each then return T("rsum.tt.noprice") end
    local _, source, stamp = ns.RaidCost.Price(sp.item)
    if source == "scan" then
        return format(T("rsum.tt.price.scan"), ns.RaidCost.Gold(each), ns.RaidCost.Stamp(stamp))
    end
    return format(T(source == "ah" and "rsum.tt.price.ah" or "rsum.tt.price.manual"), ns.RaidCost.Gold(each),
        ns.RaidCost.Date(stamp))
end
local function SpentRow(res, pr, sp)
    local each = not sp.free and pr.c[sp.item] or nil
    local cost = each and each * sp.n or nil
    local tip = { { kind = "head", left = ns.ItemName(sp.id, sp.item), right = T("rsum.cat." .. sp.cat) } }
    Put(tip, "note", sp.free and T("rsum.tt.free") or PriceNote(sp, each))
    Put(tip, "sep")
    local by = Pairs(sp.by)
    for k = 1, #by do
        local p = res.byName[by[k].k]
        tip[#tip + 1] = { kind = "row", left = by[k].k, mid = format("x%d", by[k].v),
                          right = each and ns.RaidCost.Gold(each * by[k].v) or nil, class = p and p.class }
    end
    local note = (cost and ns.RaidCost.Amount(cost)) or (sp.free and T("rsum.free")) or T("rsum.noprice")
    return { who = ns.ItemName(sp.id, sp.item), icon = ns.RaidCost.Icon(sp.id, sp.spell), text = format("x%d", sp.n), note = note,
             noteIcon = cost and ns.RaidCost.GOLD_ICON or nil, noteLit = cost ~= nil, v = sp.n, lines = tip }, cost
end
local function Spent(res, pr)
    local rows = {}
    local total, gold = 0, 0
    local groups, order = {}, {}
    for i = 1, #res.spent do
        local sp = res.spent[i]
        local g = groups[sp.cat]
        if not g then
            g = { cat = sp.cat, n = 0, list = {} }
            groups[sp.cat] = g
            order[#order + 1] = g
        end
        g.n = g.n + sp.n
        g.list[#g.list + 1] = sp
        if not sp.free then total = total + sp.n end
    end
    tsort(order, function(a, b) return ns.RaidCost.CatOrder(a.cat) < ns.RaidCost.CatOrder(b.cat) end)
    local head = ns.Kit and ns.Kit.Hex("text.title") or ""
    for i = 1, #order do
        local g = order[i]
        local at = #rows + 1
        rows[at] = { who = head .. T("rsum.grp." .. g.cat) .. (head ~= "" and "|r" or ""), text = format("x%d", g.n),
                     v = g.n }
        local sum = 0
        for k = 1, #g.list do
            local row, cost = SpentRow(res, pr, g.list[k])
            rows[#rows + 1] = row
            if cost then sum = sum + cost end
        end
        gold = gold + sum
        if sum > 0 then
            rows[at].note, rows[at].noteIcon, rows[at].noteLit = ns.RaidCost.Amount(sum), ns.RaidCost.GOLD_ICON, true
        end
    end
    local title = gold > 0 and format(T("rsum.title.spentgold"), total, ns.RaidCost.GoldIcon(gold))
        or format(T("rsum.title.spent"), total)
    return { key = "spent", title = title, rows = rows, empty = T("rsum.nospent") }
end
local function Tip(d, text)
    local out = { { kind = "head", left = d.title } }
    Put(out, "sep")
    Put(out, "note", text)
    d.tip = out
    return d
end
local function NoData(d)
    return #d.rows == 0 and d.empty == T("rsum.none")
end
function Model.Build(res)
    local pr = Prices(res)
    local all = Damage(res, "all", "rsum.d.all")
    local list = { all }
    if Sum(res, "all") == Sum(res, "enc") then
        Tip(all, T("rsum.note.notrash"))
    else
        list[#list + 1] = Damage(res, "enc", "rsum.d.enc")
    end
    list[#list + 1] = Damage(res, "boss", "rsum.d.boss")
    if res.cut then
        list[#list + 1] = Tip(Damage(res, "cut", "rsum.d.cut"),
            format(T("rsum.note.cut"), ns.EncName(res.cut), date("%H:%M", res.cutAt)))
    end
    list[#list + 1] = Heal(res)
    list[#list + 1] = Deaths(res)
    list[#list + 1] = GP(res)
    list[#list + 1] = Drunk(res, pr)
    list[#list + 1] = Spent(res, pr)
    local details = {}
    for i = 1, #list do
        if not NoData(list[i]) then details[#details + 1] = list[i] end
    end
    return { totals = Totals(res), details = details }
end
