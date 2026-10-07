local _, ns = ...
local format = string.format
local floor = math.floor
local tsort = table.sort
local concat = table.concat
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GPList = {}
ns.GPList = GPList
GPList.WIDE = { rowh = 22, headh = 18, whenw = 44, mainw = 92, proofw = 30, hotw = 48, checkw = 0, namew = 120,
    icon = 16, iconw = 36 }
GPList.PAGE = { rowh = 22, headh = 18, whenw = 44, mainw = 92, proofw = 30, hotw = 48, checkw = 24, namew = 120,
    icon = 16, iconw = 36 }
GPList.COMPACT = { rowh = 20, headh = 16, whenw = 0, mainw = 52, proofw = 22, hotw = 38, checkw = 0, namew = 78,
    icon = 13, iconw = 28, small = true }
GPList.MINI = { rowh = 18, headh = 14, whenw = 0, mainw = 46, proofw = 18, hotw = 0, checkw = 0, namew = 74,
    icon = 12, iconw = 24, small = true }
local listeners = {}
function GPList.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function GPList.Changed()
    for i = 1, #listeners do listeners[i]() end
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
GPList.Clock = Clock
function GPList.Icon(id)
    if type(id) == "string" then return id end
    return id and ns.Effects and ns.Effects.IconById(id) or UNKNOWN_ICON
end
function GPList.ClassRGB(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return cc.r, cc.g, cc.b end
    local c = ns.Badges.style.noClass
    return c[1], c[2], c[3]
end
function GPList.Small(b)
    if b.kitStyle then return end
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
end
function GPList.Pending(events)
    return ns.Ledger.Pending(events)
end
function GPList.Confirm(text, yes, onYes)
    ns.Kit.Confirm(text, yes, onYes)
end
function GPList.CanGP(n)
    local ok, why = ns.Ledger.Active().Can(n)
    if not ok then ns.Print(ns.T(why or "led.err.noepgp")) end
    return ok
end
function GPList.Issue(fight, batch)
    if not fight or not batch or not GPList.CanGP() then return end
    local total, names = 0, 0
    for k = 1, #batch do
        local n = GPList.Pending(batch[k].events)
        if n > 0 then
            total = total + n
            names = names + 1
        end
    end
    if total == 0 then return end
    local sys = ns.Ledger.Active()
    GPList.Confirm(format(ns.T(sys.ask), total, names), ns.T("sum.gp.yes"), function()
        local res = ns.Ledger.Issue(fight, batch)
        if res.why then ns.Print(ns.T(res.why)) end
        if #res.failed > 0 then ns.Print(format(ns.T("gp.notgiven"), concat(res.failed, ", "))) end
    end)
end
function GPList.IssueKeys(fight, model, keys)
    local batch = {}
    for i = 1, #model.items do
        local item = model.items[i]
        local evs = {}
        for e = 1, #item.events do
            if keys[item.events[e].key] then evs[#evs + 1] = item.events[e] end
        end
        if #evs > 0 then batch[#batch + 1] = { name = item.name, events = evs } end
    end
    GPList.Issue(fight, batch)
end
function GPList.Marked(model, keys)
    local n = 0
    for i = 1, #((model and model.items) or {}) do
        local evs = model.items[i].events
        for e = 1, #evs do
            if keys[evs[e].key] and evs[e].n > 0 and not ns.Ledger.Done(evs[e].key) then n = n + evs[e].n end
        end
    end
    return n
end
function GPList.Hot(fight, name, kind, ev)
    if not fight or not GPList.CanGP() then return end
    local n = ns.Ledger.HotSum(kind)
    local what = ev and format(ns.T("led.hot.of"), ns.Ledger.HotLabel(kind), ev.short or "?") or ns.Ledger.HotLabel(kind)
    GPList.Confirm(format(ns.T("led.hot.ask"), name, what, n, ns.Ledger.Unit()), ns.T("sum.gp.yes"), function()
        local fact, why = ns.Ledger.GiveHot(fight, name, kind, ev)
        if why then ns.Print(ns.T(why)) end
    end)
end
function GPList.Charge(fight, name, ev)
    if not fight or not GPList.CanGP() then return end
    local n = ns.Penalties.Amount(ev.hit.rule, ns.Ledger.Key()) or 0
    if n <= 0 then return end
    ns.Penalties.Bump(ev.key)
    GPList.Changed()
    GPList.Issue(fight, { { name = name, events = { { key = ev.key, n = n, short = ev.short } } } })
end
function GPList.Undo(key)
    local rec = ns.Ledger.Done(key)
    if not rec then return end
    if not ns.Ledger.CanUndo(key) then
        ns.Print(ns.T("led.err.unknown"))
        return
    end
    GPList.Confirm(format(ns.T("led.undo.ask"), rec.who or "?", rec.n, ns.Ledger.Unit(rec.s)), ns.T("led.undo.yes"),
        function()
            local ok, why = ns.Ledger.Undo(key)
            if not ok and why then ns.Print(ns.T(why)) end
        end)
end
local function OpenMenu(menu)
    ns.Tip.Hide()
    ns.Kit.Menu(menu)
end
local function HitEvents(hit, name)
    local reason = ns.Penalties.Reason(hit.rule)
    local short = ns.Penalties.Short(hit.rule)
    local out = {}
    for k = 1, #hit.events do
        local ev = hit.events[k]
        out[k] = { key = ev.key, n = ev.n, reason = reason, short = short, wipe = ev.wipe, t = ev.t,
            bumped = ev.bumped, name = name, manual = ev.info and ev.info.manual or nil, grade = ev.grade,
            hit = hit, src = ev }
    end
    return out
end
GPList.HitEvents = HitEvents
local function HotItems(menu, fight, name, ev)
    local hot = ns.Ledger.HOT
    for i = 1, #hot do
        local kind = hot[i]
        menu[#menu + 1] = {
            text = format(ns.T(ev and "led.menu.hotfault" or "led.menu.hot"), ns.Ledger.HotLabel(kind),
                ns.Ledger.HotSum(kind), ns.Ledger.Unit()),
            notCheckable = true,
            func = function() GPList.Hot(fight, name, kind, ev) end,
        }
    end
end
function GPList.ManualMenu(fight, name)
    if not fight or not ns.Penalties then return end
    local rules = ns.Penalties.Choices(fight.boss)
    local menu = { { text = format(ns.T("sum.gp.add"), name), isTitle = true, notCheckable = true } }
    HotItems(menu, fight, name, nil)
    for i = 1, #rules do
        local r = rules[i]
        menu[#menu + 1] = {
            text = format(ns.T("gp.menu.rule"), ns.Penalties.Reason(r), ns.Penalties.Amount(r, ns.Ledger.Key()) or 0,
                ns.Ledger.Unit()),
            notCheckable = true,
            func = function()
                ns.Penalties.AddManual(fight, name, r.key)
                GPList.Changed()
            end,
        }
    end
    OpenMenu(menu)
end
function GPList.EventMenu(fight, hit, name)
    local rule = hit.rule
    local sys = ns.Ledger.Key()
    local unit = ns.Ledger.Unit()
    local wipe = ns.Penalties.Amount(rule, sys, "wipe")
    local menu = { { text = ns.Penalties.Reason(rule), isTitle = true, notCheckable = true } }
    local events = HitEvents(hit, name)
    for k = 1, #events do
        local ev = events[k]
        local when = ev.t and Clock(ev.t - fight.from) or ns.T("sum.gp.whole")
        local done = ns.Ledger.Done(ev.key)
        if done then
            menu[#menu + 1] = {
                text = done.n and format(ns.T("led.menu.undo"), when, done.n, ns.Ledger.Unit(done.s))
                    or format(ns.T("led.menu.old"), when),
                notCheckable = true,
                disabled = not ns.Ledger.CanUndo(ev.key),
                func = function() GPList.Undo(ev.key) end,
            }
        elseif ev.n > 0 then
            menu[#menu + 1] = {
                text = format(ns.T("sum.gp.item"), when, ev.n, unit),
                notCheckable = true,
                func = function() GPList.Issue(fight, { { name = name, events = { ev } } }) end,
            }
        end
        if ev.grade == "yellow" and not done then
            menu[#menu + 1] = {
                text = ev.bumped and format(ns.T("sum.gp.uncharge"), when)
                    or format(ns.T("sum.gp.charge"), when, ns.Penalties.Amount(rule, sys) or 0, unit),
                notCheckable = true,
                func = function()
                    if ev.bumped then ns.Penalties.Unbump(ev.key) else ns.Penalties.Bump(ev.key) end
                    GPList.Changed()
                end,
            }
        elseif wipe and not ev.bumped and not done then
            menu[#menu + 1] = {
                text = format(ns.T("sum.gp.bump"), when, wipe, unit),
                notCheckable = true,
                func = function()
                    ns.Penalties.Bump(ev.key)
                    GPList.Changed()
                end,
            }
        end
        if k == #events and ev.manual and not done then
            menu[#menu + 1] = {
                text = format(ns.T("gp.menu.unmanual"), when),
                notCheckable = true,
                func = function()
                    ns.Penalties.RemoveManual(fight, name, rule.key, ev.key)
                    GPList.Changed()
                end,
            }
        end
    end
    OpenMenu(menu)
end
function GPList.FirstAt(list)
    return ns.ReplayLink and ns.ReplayLink.First(list, "t") or nil
end
function GPList.HitLines(fight, hit)
    local lines = ns.BadgeTips.Hit(fight, hit, ns.Penalties.Reason(hit.rule))
    if ns.ReplayLink then ns.ReplayLink.Tag(lines, fight, GPList.FirstAt(hit.events)) end
    return lines
end
function GPList.Note(item)
    local list = {}
    for h = 1, #item.hits do
        local hit = item.hits[h]
        for k = 1, #(hit.shed or {}) do list[#list + 1] = { hit = hit, hangs = hit.shed[k].hangs } end
    end
    if #list == 0 then return nil, false end
    local parts, yellow = {}, true
    for i = 1, #list do
        local text = ns.Penalties.ShedText(list[i].hangs)
        parts[i] = #list > 1 and (ns.Penalties.Reason(list[i].hit.rule) .. ": " .. text) or text
        if ns.Penalties.Grade(list[i].hit) ~= "yellow" then yellow = false end
    end
    return concat(parts, "; "), yellow
end
local function Guards(p, hits)
    local out, by = {}, {}
    for h = 1, #hits do
        local kind = hits[h].rule.kind
        for e = 1, (kind == "death" or kind == "anydeath") and #hits[h].events or 0 do
            local t = hits[h].events[e].t
            for k = 1, t and #p.deathInfo or 0 do
                local d = p.deathInfo[k]
                if math.abs(d.t - t) < 0.01 and d.ready and not d.late and not d.tail then
                    local m = by[d.ready]
                    if not m then
                        m = { id = d.ready, n = 0, times = {} }
                        by[d.ready] = m
                        out[#out + 1] = m
                    end
                    m.n = m.n + 1
                    m.times[m.n] = d.t
                end
            end
        end
    end
    return out
end
local function Given(item)
    local n = 0
    for e = 1, #item.events do
        local d = ns.Ledger.Done(item.events[e].key)
        if d and d.n then n = n + d.n end
    end
    for i = 1, #item.hand do n = n + (item.hand[i].done.n or 0) end
    return n
end
function GPList.Build(fight, summary)
    local pens, totals = {}, {}
    if ns.Penalties and summary then pens, totals = ns.Penalties.Evaluate(summary, fight) end
    local hand = {}
    local list = ns.Ledger and ns.Ledger.Hand(fight) or {}
    for i = 1, #list do
        local by = hand[list[i].who] or {}
        hand[list[i].who] = by
        by[#by + 1] = list[i]
    end
    local items, all, pending, ready = {}, {}, 0, 0
    for i = 1, #((summary and summary.players) or {}) do
        local p = summary.players[i]
        local hits = pens[p.name] or {}
        if #hits > 0 or hand[p.name] then
            local events = {}
            for h = 1, #hits do
                local ev = HitEvents(hits[h], p.name)
                for e = 1, #ev do events[#events + 1] = ev[e] end
            end
            local item = { name = p.name, class = p.class, hits = hits, events = events, hand = hand[p.name] or {},
                total = totals[p.name] or 0, pending = GPList.Pending(events), guards = Guards(p, hits) }
            item.given = Given(item)
            items[#items + 1] = item
            pending = pending + item.pending
            if item.pending > 0 then ready = ready + 1 end
        end
    end
    tsort(items, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    for i = 1, #items do all[i] = items[i] end
    return { pens = pens, totals = totals, items = items, pending = pending, ready = ready, all = all }
end
function GPList.New(parent, prefix, layout)
    return ns.FaultTable.New(parent, prefix, layout or GPList.WIDE)
end
