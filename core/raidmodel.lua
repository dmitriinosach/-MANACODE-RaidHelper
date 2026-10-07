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
local function SpName(sp)
    local name = sp.id and GetItemInfo and GetItemInfo(sp.id)
    if name then return name end
    if sp.spell and GetLocale() ~= "ruRU" and GetSpellInfo then
        name = GetSpellInfo(sp.spell)
        if name then return name end
    end
    return sp.item
end
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
            tip[#tip + 1] = { kind = "row", left = Inline(sp.id, ICON_TIP, sp.spell) .. " " .. SpName(sp),
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
    local tip = { { kind = "head", left = SpName(sp), right = T("rsum.cat." .. sp.cat) } }
    Put(tip, "note", sp.free and T("rsum.tt.free") or PriceNote(sp, each))
    Put(tip, "sep")
    local by = Pairs(sp.by)
    for k = 1, #by do
        local p = res.byName[by[k].k]
        tip[#tip + 1] = { kind = "row", left = by[k].k, mid = format("x%d", by[k].v),
                          right = each and ns.RaidCost.Gold(each * by[k].v) or nil, class = p and p.class }
    end
    local note = (cost and ns.RaidCost.Amount(cost)) or (sp.free and T("rsum.free")) or T("rsum.noprice")
    return { who = SpName(sp), icon = ns.RaidCost.Icon(sp.id, sp.spell), text = format("x%d", sp.n), note = note,
             noteIcon = cost and ns.RaidCost.GOLD_ICON or nil, noteLit = cost ~= nil, v = sp.n, lines = tip }, cost
end
function Model.Cost(res)
    local pr = Prices(res)
    local gold = 0
    for i = 1, #res.spent do
        local sp = res.spent[i]
        local each = not sp.free and pr.c[sp.item]
        if each then gold = gold + each * sp.n end
    end
    return gold > 0 and gold or nil
end
local function Groups(res)
    local total = 0
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
    tsort(order, function(a, b)
        local ca, cb = ns.RaidCost.CatOrder(a.cat), ns.RaidCost.CatOrder(b.cat)
        if ca ~= cb then return ca < cb end
        return a.cat < b.cat
    end)
    return order, total
end
function Model.SpentGroups(res)
    local pr = Prices(res)
    local order = Groups(res)
    local out = {}
    for i = 1, #order do
        local g = order[i]
        local items, sum = {}, 0
        for k = 1, #g.list do
            local sp = g.list[k]
            local each = not sp.free and pr.c[sp.item] or nil
            local cost = each and each * sp.n or nil
            if cost then sum = sum + cost end
            items[k] = { name = SpName(sp), icon = ns.RaidCost.Icon(sp.id, sp.spell), n = sp.n, cost = cost }
        end
        out[i] = { cat = g.cat, n = g.n, cost = sum > 0 and sum or nil, items = items }
    end
    return out
end
local function Spent(res, pr)
    local rows = {}
    local gold = 0
    local order, total = Groups(res)
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
local function Int(v)
    return format("%d", v)
end
local function Dur(sec)
    sec = floor(max(0, sec) + 0.5)
    if sec >= HOUR then return format(T("rsum.dur.h"), floor(sec / HOUR), floor(sec % HOUR / 60)) end
    if sec >= 60 then return format(T("rsum.dur.m"), floor(sec / 60), sec % 60) end
    return format(T("rsum.dur.s"), sec)
end
local function Pct(part, whole)
    return format("%.0f%%", part / max(1, whole) * 100)
end
local function Pl(n, key)
    local forms = T(key)
    local one, few, many = forms:match("^([^|]*)|([^|]*)|([^|]*)$")
    if not one then return forms end
    return ns.PluralPick(n, one, few, many)
end
local function Count(n, key, fmt)
    return format(T(fmt), n, Pl(n, key))
end
local function PartName(e)
    return format("%s (%s)", T(e.label), ns.EncName(e.boss))
end
local function PartLines(tip, by, hits)
    local list = {}
    for _, e in pairs(by) do list[#list + 1] = { e = e, s = PartName(e) } end
    tsort(list, function(a, b)
        if a.e.v ~= b.e.v then return a.e.v > b.e.v end
        return a.s < b.s
    end)
    for k = 1, #list do
        local e = list[k].e
        tip[#tip + 1] = { kind = "row", left = list[k].s, mid = hits and e.hits > 0 and format("x%d", e.hits) or nil,
                          right = Short(e.v) }
    end
end
local function Parts(res, key, label)
    local list = Ranked(res, key)
    local total = Sum(res, key)
    local rows = {}
    for i = 1, #list do
        local p = list[i]
        local share = Pct(p[key], total)
        local tip = { { kind = "head", left = p.name, class = p.class } }
        Put(tip, "row", T("rsum.tt.dmg"), Short(p[key]))
        Put(tip, "row", T("rsum.tt.share"), share)
        if key == "bad" then Put(tip, "row", T("rsum.tt.hits"), Int(p.badHits)) end
        Put(tip, "sep")
        PartLines(tip, p[key .. "By"], key == "bad")
        local note = key == "bad" and Count(p.badHits, "rsum.w.hits", "rsum.n.word") or share
        rows[i] = { who = p.name, class = p.class, text = Short(p[key]), note = note, v = p[key], lines = tip }
    end
    return { key = key == "bad" and "puddles" or key, title = format(T("rsum.title.sum"), T(label), Short(total)),
             rows = rows, empty = T("rsum.none") }
end
local function ByV(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.who < b.who
end
local function Saver(res)
    local rows, total = {}, 0
    for i = 1, #res.players do
        local p = res.players[i]
        local v = p.kicks + p.cures + p.purges
        if v > 0 then
            total = total + v
            local tip = { { kind = "head", left = p.name, class = p.class } }
            Put(tip, "row", T("rsum.tt.kicks"), Int(p.kicks))
            Put(tip, "row", T("rsum.tt.cures"), Int(p.cures))
            Put(tip, "row", T("rsum.tt.purges"), Int(p.purges))
            local parts = {}
            if p.kicks > 0 then parts[#parts + 1] = format(T("rsum.saver.kicks"), p.kicks) end
            if p.cures + p.purges > 0 then parts[#parts + 1] = format(T("rsum.saver.cures"), p.cures + p.purges) end
            rows[#rows + 1] = { who = p.name, class = p.class, text = concat(parts, ", "), v = v, lines = tip }
        end
    end
    tsort(rows, ByV)
    return { key = "saver", title = format(T("rsum.title.sum"), T("rsum.d.saver"), Int(total)), rows = rows,
             empty = T("rsum.none") }
end
local function Alive(res)
    local rows = {}
    for i = 1, #res.players do
        local p = res.players[i]
        if p.deaths == 0 and p.tries > 0 then
            local tip = { { kind = "head", left = p.name, class = p.class } }
            Put(tip, "row", T("rsum.tt.tries"), Int(p.tries))
            Put(tip, "row", T("rsum.tt.deaths"), "0")
            rows[#rows + 1] = { who = p.name, class = p.class, text = Count(p.tries, "rsum.w.tries.acc", "rsum.alive.n"),
                                v = p.tries, lines = tip }
        end
    end
    tsort(rows, ByV)
    return { key = "alive", title = format(T("rsum.title.sum"), T("rsum.d.alive"), Int(#rows)), rows = rows,
             empty = T(#res.players > 0 and "rsum.noalive" or "rsum.none") }
end
local function First(res)
    local list = Ranked(res, "first")
    local rows = {}
    for i = 1, #list do
        local p = list[i]
        local tip = { { kind = "head", left = p.name, class = p.class } }
        Put(tip, "row", T("rsum.tt.first"), Int(p.first))
        Put(tip, "row", T("rsum.tt.tries"), Int(p.tries))
        Put(tip, "row", T("rsum.tt.deaths"), Int(p.deaths))
        Put(tip, "sep")
        local by = Pairs(p.firstBy)
        for k = 1, #by do Put(tip, "row", by[k].s, Int(by[k].v)) end
        rows[i] = { who = p.name, class = p.class,
                    text = format(T("rsum.first.n"), p.first, p.tries, Pl(p.tries, "rsum.w.tries.gen")), v = p.first,
                    lines = tip }
    end
    return { key = "first", title = T("rsum.d.first"), rows = rows,
             empty = T(#res.players > 0 and "rsum.nodeaths" or "rsum.none") }
end
local FAULT_WHO = 10
local function RuleName(rule)
    local text = ns.Penalties.Reason(rule)
    if rule.boss == nil or rule.boss == ns.penaltyAny then return text end
    return format("%s: %s", ns.EncName(rule.boss), text)
end
local function FaultTip(res, fl)
    local tip = { { kind = "head", left = RuleName(fl.rule) } }
    Put(tip, "row", T("rsum.tt.faults"), Int(fl.n))
    Put(tip, "row", T("rsum.tt.red"), Int(fl.red))
    Put(tip, "row", T("rsum.tt.yellow"), Int(fl.n - fl.red))
    Put(tip, "row", T("rsum.tt.offer"), Int(fl.gp))
    local tries = 0
    for _ in pairs(fl.tries) do tries = tries + 1 end
    Put(tip, "row", T("rsum.tt.ftries"), Int(tries))
    Put(tip, "sep")
    local by = Pairs(fl.by)
    for k = 1, min(#by, FAULT_WHO) do
        local p = res.byName[by[k].k]
        tip[#tip + 1] = { kind = "row", left = by[k].k, right = format("x%d", by[k].v), class = p and p.class }
    end
    if #by > FAULT_WHO then Put(tip, "note", format(T("rsum.tt.more"), #by - FAULT_WHO)) end
    return tip
end
local function Fault(res)
    local faults = ns.Penalties and ns.RaidSummary.Faults(res)
    if not faults then return { key = "fault", title = T("rsum.d.fault"), rows = {}, empty = T("rsum.none") } end
    local rows = {}
    for i = 1, #faults do
        local fl = faults[i]
        rows[i] = { who = RuleName(fl.rule), text = Count(fl.n, "rsum.w.times", "rsum.n.word"),
                    note = fl.gp > 0 and format(T("rsum.gp.n"), fl.gp) or nil, v = fl.n, lines = FaultTip(res, fl) }
    end
    local title = faults[1] and format(T("rsum.title.fault"), ns.Penalties.Short(faults[1].rule)) or T("rsum.d.fault")
    return { key = "fault", title = title, rows = rows, empty = T("rsum.nogpyet") }
end
local function FightName(f)
    return format("%s %s, %s", ns.EncName(f.boss), date("%H:%M", f.from),
        T(f.killed and "rsum.tt.killed" or "rsum.tt.wiped"))
end
local function TimeRows(res, t, whole)
    local tip = { { kind = "head", left = T("rsum.time.combat"), right = Dur(t.combat) } }
    Put(tip, "row", T("rsum.tt.tries"), Int(res.tries))
    Put(tip, "row", T("rsum.tt.kills"), Int(res.tries - res.wipes))
    if t.long then
        Put(tip, "row", T("rsum.tt.longtry"), FightName(t.long) .. " — " .. Dur(t.long.to - t.long.from))
    end
    Put(tip, "row", T("rsum.tt.ofall"), Pct(t.combat, whole))
    local combat = { who = T("rsum.time.combat"), text = Dur(t.combat),
                     note = format(T("rsum.time.share"), Pct(t.combat, whole)), v = t.combat, lines = tip }
    tip = { { kind = "head", left = T("rsum.time.idle"), right = Dur(t.idle) } }
    Put(tip, "row", T("rsum.tt.gaps"), Int(t.gaps))
    if t.gaps > 0 then Put(tip, "row", T("rsum.tt.avg"), Dur(t.idle / t.gaps)) end
    Put(tip, "row", T("rsum.tt.ofall"), Pct(t.idle, whole))
    return combat, { who = T("rsum.time.idle"), text = Dur(t.idle),
                     note = format(T("rsum.time.share"), Pct(t.idle, whole)), v = t.idle, lines = tip }
end
local function Time(res)
    local t = res.time
    local rows = {}
    if t and t.combat > 0 then
        rows[1], rows[2] = TimeRows(res, t, t.combat + t.idle)
        local tip = { { kind = "head", left = T("rsum.time.wipe"), right = Dur(t.wipe) } }
        Put(tip, "row", T("rsum.t.wipes"), Int(res.wipes))
        Put(tip, "row", T("rsum.tt.ofcombat"), Pct(t.wipe, t.combat))
        rows[3] = { who = T("rsum.time.wipe"), text = Dur(t.wipe), note = format(T("rsum.time.wipes"), res.wipes),
                    v = t.wipe, lines = tip }
        local g = t.longest
        if g then
            tip = { { kind = "head", left = T("rsum.time.longest"), right = Dur(g.dur) } }
            Put(tip, "row", T("rsum.tt.from"), date("%H:%M:%S", g.from))
            Put(tip, "row", T("rsum.tt.to"), date("%H:%M:%S", g.to))
            Put(tip, "row", T("rsum.tt.after"), FightName(g.after))
            Put(tip, "row", T("rsum.tt.before"), FightName(g.before))
            rows[4] = { who = T("rsum.time.longest"), text = Dur(g.dur),
                        note = format("%s–%s", date("%H:%M", g.from), date("%H:%M", g.to)), v = g.dur, lines = tip }
        end
    end
    return { key = "time", title = T("rsum.d.time"), rows = rows, empty = T("rsum.none") }
end
local function BySpell(map, field)
    local list = {}
    for k, e in pairs(map) do list[#list + 1] = { k = k, v = field and e[field] or e, e = e, s = ns.SpellName(k) } end
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.s < b.s
    end)
    return list
end
local function Buffed(res)
    local list = Ranked(res, "buffN")
    local rows = {}
    for i = 1, #list do
        local p = list[i]
        local tip = { { kind = "head", left = p.name, class = p.class } }
        Put(tip, "row", T("rsum.tt.buffs"), Int(p.buffN))
        Put(tip, "row", T("rsum.tt.buffsec"), Dur(p.buffSec))
        local by = BySpell(p.buffBy, "n")
        local parts = {}
        for k = 1, #by do
            local e = by[k].e
            parts[#parts + 1] = Inline(nil, ICON_ROW, by[k].k) .. Int(e.n)
            Put(tip, "sep")
            tip[#tip + 1] = { kind = "row", left = Inline(nil, ICON_TIP, by[k].k) .. " " .. by[k].s,
                              mid = format("x%d", e.n), right = Dur(e.sec) }
            local givers = Pairs(e.by)
            for g = 1, #givers do
                local gp = res.byName[givers[g].k]
                tip[#tip + 1] = { kind = "row", left = "  " .. givers[g].k, right = format("x%d", givers[g].v),
                                  class = gp and gp.class }
            end
        end
        rows[i] = { who = p.name, class = p.class, text = concat(parts, "  "), v = p.buffN, lines = tip }
    end
    local n = Sum(res, "buffN")
    return { key = "buffed", title = format(T("rsum.title.buffed"), T("rsum.d.buffed"), n, Pl(n, "rsum.w.buffs")),
             rows = rows, empty = T("rsum.none") }
end
local ROD_TOP = 5
local function Rod(res)
    local list = Ranked(res, "rod")
    local rows = {}
    for i = 1, min(ROD_TOP, #list) do
        local p = list[i]
        local tip = { { kind = "head", left = p.name, class = p.class } }
        Put(tip, "row", T("rsum.tt.rod"), Int(p.rod))
        Put(tip, "sep")
        local by = BySpell(p.rodBy)
        for k = 1, #by do Put(tip, "row", by[k].s, Int(by[k].v)) end
        rows[i] = { who = p.name, class = p.class, text = Count(p.rod, "rsum.w.times", "rsum.rod.n"), v = p.rod,
                    lines = tip }
    end
    return { key = "rod", title = T("rsum.d.rod"), rows = rows, empty = T("rsum.none") }
end
Model.HIDE = "#raid"
Model.DEFS = {
    { key = "all", label = "rsum.d.all" },
    { key = "enc", label = "rsum.d.enc" },
    { key = "boss", label = "rsum.d.boss" },
    { key = "cut", label = "rsum.d.cut" },
    { key = "prio", label = "rsum.d.prio" },
    { key = "heal", label = "rsum.d.heal" },
    { key = "saver", label = "rsum.d.saver" },
    { key = "deaths", label = "rsum.d.deaths" },
    { key = "alive", label = "rsum.d.alive" },
    { key = "first", label = "rsum.d.first" },
    { key = "fault", label = "rsum.d.fault" },
    { key = "puddles", label = "rsum.d.puddles" },
    { key = "rod", label = "rsum.d.rod" },
    { key = "buffed", label = "rsum.d.buffed" },
    { key = "time", label = "rsum.d.time" },
    { key = "gp", label = "rsum.d.gp" },
    { key = "drunk", label = "rsum.title.drunk" },
    { key = "spent", label = "rsum.d.spent" },
}
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
    list[#list + 1] = Parts(res, "prio", "rsum.d.prio")
    list[#list + 1] = Heal(res)
    list[#list + 1] = Saver(res)
    list[#list + 1] = Deaths(res)
    list[#list + 1] = Alive(res)
    list[#list + 1] = First(res)
    list[#list + 1] = Fault(res)
    list[#list + 1] = Parts(res, "bad", "rsum.d.puddles")
    list[#list + 1] = Rod(res)
    list[#list + 1] = Buffed(res)
    list[#list + 1] = Time(res)
    list[#list + 1] = GP(res)
    list[#list + 1] = Drunk(res, pr)
    list[#list + 1] = Spent(res, pr)
    local byKey = {}
    for i = 1, #list do byKey[list[i].key] = list[i] end
    local Hide = ns.SumHide
    local details = {}
    for i = 1, #Model.DEFS do
        local key = Model.DEFS[i].key
        local d = byKey[key]
        if d and not NoData(d) and not (Hide and Hide.IsHidden(Model.HIDE, key)) then details[#details + 1] = d end
    end
    return { totals = Totals(res), details = details }
end
