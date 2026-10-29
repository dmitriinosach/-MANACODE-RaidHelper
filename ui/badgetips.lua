local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local concat = table.concat
local tsort = table.sort
local TIMES = 8
local LOST = { "dead", "veh", "mc" }
local ABIL_TOP = 10
local BLOCK_TOP = 5
local REST_KEY = "#rest"
local GLYPH = "|T%s:14:14:0:0:64:64:5:59:5:59|t "
local MELEE_ICON = "Interface\\Icons\\INV_Sword_04"
local Tips = {}
ns.BadgeTips = Tips
local function T(key)
    return ns.T(key)
end
local Short = ns.Short
function Tips.Mechanic(b)
    local d = b.def
    local label = T(b.label or d.label)
    local spells, seen = {}, {}
    local ids = d.spells or (d.spell and { d.spell }) or {}
    for i = 1, #ids do
        local id = tonumber(ids[i])
        local key = id and ns.SpellKey(id)
        if key and not seen[key] then
            spells[#spells + 1], seen[key] = id, true
        end
    end
    local id = spells[1]
    local name = id and ns.SpellName(id)
    local known = name and name:sub(1, 1) ~= "#"
    local spellLink = id and GetSpellLink(id)
    if #spells == 1 and known and (d.kind == "taken" or d.kind == "friendly") then
        label = format(T("sum.k.damagefrom"), spellLink or name)
    elseif #spells == 1 and known and d.kind == "dispels" then
        label = format(T("sum.k.dispelspell"), spellLink or name)
    end
    local npc = d.npc or d.src or (d.names and d.names[1])
    local icon = npc and ns.npcPortraits and ns.npcPortraits[npc]
    local add = npc and ns.replayData and ns.replayData.adds[npc]
    icon = icon or ns.SpellIcon(id or (type(add) == "number" and add or nil))
    if #spells == 1 and not npc then
        return { label = label, icon = icon, link = "spell:" .. id }
    end
    local lines = { { kind = "head", left = label } }
    for i = 1, #spells do
        local spell = spells[i]
        local link = GetSpellLink(spell)
        lines[#lines + 1] = { kind = "row", left = link or ns.SpellName(spell) }
    end
    if npc then
        local names = {}
        for i = 1, #(d.names or { npc }) do
            local name = ns.NpcName(d.names and d.names[i] or npc)
            if name ~= "" and name:sub(1, 1) ~= "#" and not names[name] then
                lines[#lines + 1] = { kind = "row", left = name }
                names[name] = true
            end
        end
    end
    return { label = label, icon = icon, tip = lines, link = #spells == 1 and ("spell:" .. id) or nil }
end
function Tips.Rate(n)
    if n >= 1e3 then return ns.Dec(format("%.2f", n / 1e3)) .. ns.T("num.k") end
    return tostring(floor(n + 0.5))
end
local Clock = ns.Clock
local function Rate(n, dur)
    return format(T("sum.tt.rate"), Short(n / max(1, dur)))
end
local function Inline(id)
    local icon = id and ns.Effects and ns.Effects.IconById(id)
    return icon and format("|T%s:14|t ", icon) or ""
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Head(out, text, right, class)
    out[#out + 1] = { kind = "head", left = text, right = right, class = class }
end
local function Times(out, n, times, base)
    local parts = {}
    for k = 1, min(TIMES, #times) do parts[k] = Clock(times[k] - base) end
    if #parts == 0 then
        Put(out, "row", T("sum.tt.count"), tostring(n))
        return
    end
    local text = concat(parts, ", ") .. (#times > TIMES and format(T("sum.tip.more"), #times - TIMES) or "")
    if n > 1 or #times > 1 then text = format(T("sum.tt.times"), max(n, #times), text) end
    Put(out, "row", text)
end
local function Names(out, names)
    if #names > 0 then Put(out, "sub", concat(names, ", ")) end
end
local function Dec(v, digits)
    return ns.Dec(format("%." .. digits .. "f", v))
end
Tips.Dec = Dec
local USE_NAMES = 3
function Tips.Uses(out, st, of)
    local list = st.keys and ns.Actions and ns.Actions.Uses(st) or {}
    for k = 1, #list do
        local u = list[k]
        local id = u.id or nil
        local whom = #u.tg <= USE_NAMES and concat(u.tg, ", ") or format(T("sum.tt.ntargets"), #u.tg)
        Put(out, "row", Inline(id) .. (u.name or ns.SpellName(id)),
            of and format(T("sum.tt.of"), u.ok, u.n) or format("x%d", u.n), whom ~= "" and whom or nil)
    end
end
local VERDICT = { red = "sum.mc.on", green = "sum.mc.off", yellow = "sum.mc.maybe" }
local TONE = { red = "bad", green = "good" }
local function Drained(out, c)
    local list = c.drain
    if not list then return end
    local used, ready = {}, {}
    for i = 1, #list do
        local d = list[i]
        if d.used then
            local text = ns.SpellName(d.id or d.spell)
            if d.dmg > 0 then
                text = text .. " " .. format(T("sum.mc.drain.dmg"), Short(d.dmg))
            elseif d.allies > 0 then
                text = text .. " " .. format(T("sum.mc.drain.allies"), d.allies)
            end
            used[#used + 1] = text
        end
        if d.ready then ready[#ready + 1] = format(T("sum.mc.drain.one"), ns.SpellName(d.id or d.spell)) end
    end
    if #used > 0 then
        Put(out, "sub", format(T("sum.mc.drain.used"), concat(used, ", ")), nil, nil, c.miss and "warn" or nil)
    end
    if #ready > 0 then
        Put(out, "sub", format(T("sum.mc.drain.ready"), concat(ready, ", ")), nil, nil, "warn")
    else
        Put(out, "sub", T("sum.mc.drain.cd"), nil, nil, "good")
    end
end
local function Control(out, c, base)
    local key = VERDICT[c.verdict or ""] or (c.checked and "sum.mc.nodata" or "sum.mc.skip")
    local tone = c.verdict and TONE[c.verdict] or (not c.verdict and "dim" or nil)
    if c.miss and tone ~= "bad" then tone = "warn" end
    Put(out, "row", T(key), Clock(c.t - base), nil, tone)
    if c.to then Put(out, "sub", format(T("sum.mc.long"), floor(c.to - c.t + 0.5))) end
    if c.checked then
        if c.ratio then Put(out, "sub", format(T("sum.mc.hits"), Dec(c.ratio, 2))) end
        Put(out, "sub", format(T("sum.mc.count"), #c.hits))
        if c.tempo and not c.dual then Put(out, "sub", format(T("sum.mc.tempo"), Dec(c.tempo, 2))) end
        if c.procs > 0 then Put(out, "sub", format(T("sum.mc.procs"), c.procs)) end
        if c.by == "poison" then Put(out, "sub", format(T("sum.mc.poison"), #c.hits, ns.Plural(#c.hits, T("tl.w.hit")))) end
        if c.wpn == "none" then
            Put(out, "sub", format(T("sum.mc.slots.none"), T("sum.mc.why." .. (c.why or "wait"))))
        elseif c.wpn then
            Put(out, "sub", T("sum.mc.slots." .. c.wpn))
        end
    end
    if c.swing + c.abil > 0 then Put(out, "sub", format(T("sum.mc.dmg"), Short(c.swing), Short(c.abil))) end
    if #c.kills > 0 then Put(out, "sub", format(T("sum.mc.kills"), concat(c.kills, ", "))) end
    Drained(out, c)
end
local function Victim(out, d, base)
    local mc = d.mc
    local v = mc.ctl.verdict
    local who = mc.by
    if mc.dot then
        who = format(T("sum.mc.died.dot"), who)
    elseif v == "green" then
        who = format(T("sum.mc.died.unarmed"), who)
    end
    Put(out, "row", format(T(v == "red" and "sum.mc.died.armed" or "sum.mc.died.ctl"), who), Clock(d.t - base),
        nil, mc.grade == "green" and "good" or nil)
    if mc.spell then
        local name = mc.spell == "#melee" and T("sum.cat.melee") or mc.spell
        Put(out, "sub", name .. " " .. Short(mc.amount or 0))
    end
    local react = T("sum.mc.react.one")
    if not mc.one then
        react = format(T(mc.grade == "green" and "sum.mc.react.fast" or "sum.mc.react.slow"), Dec(mc.gap, 1))
    end
    Put(out, "sub", react)
end
function Tips.Control(p, fight)
    local out = {}
    local list = p.ctl or {}
    Head(out, T("sum.mc.head"), format("x%d", #list))
    local melee = false
    for i = 1, #list do
        Control(out, list[i], fight.from)
        melee = melee or list[i].checked == true
    end
    return out
end
local function Glyph(id)
    local icon = id and ns.Effects and ns.Effects.IconById(id)
    return icon and format(GLYPH, icon) or ""
end
local function ByAmount(a, b)
    if a.r.a ~= b.r.a then return a.r.a > b.r.a end
    return a.key < b.key
end
local function Abilities(out, own, pets, total, rest)
    local list = {}
    for key, r in pairs(own or {}) do
        if r.a > 0 then list[#list + 1] = { key = key, r = r } end
    end
    for key, r in pairs(pets or {}) do
        if r.a > 0 then list[#list + 1] = { key = key, r = r, pet = true } end
    end
    if #list == 0 then return end
    tsort(list, ByAmount)
    for k = 1, min(ABIL_TOP, #list) do
        local e, r = list[k], list[k].r
        local name = e.key == ns.Totals.MELEE_KEY and T("sum.ab.melee") or e.key
        if e.pet then name = format(T("sum.ab.pet"), name) end
        local share = format(T("sum.ab.share"), Short(r.a), floor(r.a * 100 / max(1, total) + 0.5))
        local hits = r.c > 0 and format(T("sum.ab.crit"), r.n, floor(r.c * 100 / max(1, r.n) + 0.5))
            or format(T("sum.ab.hits"), r.n)
        Put(out, "sub", Glyph(r.id) .. name, hits, share)
    end
    local more = max(0, #list - ABIL_TOP) + (rest and rest.n or 0)
    if more > 0 then Put(out, "sub", format(T("sum.ab.more"), more), nil, nil, "dim") end
end
function Tips.Combat(s, title, value, amount)
    local out = {}
    Head(out, title, value)
    Put(out, "row", T("sum.tt.dur"), Clock(s.dur))
    local act = ns.Totals.Active(s)
    if s.dur - act >= 1 then
        Put(out, "sub", T("sum.tt.combat"), Clock(act))
        Put(out, "sub", T("sum.tt.idle"), Clock(s.dur - act))
        if amount then Put(out, "sub", T("sum.tt.noidle"), Rate(amount, act)) end
    end
    return out
end
local function NoIdle(out, n, s)
    local act = ns.Totals.Active(s)
    if s.dur - act >= 1 then Put(out, "sub", T("sum.tt.noidle"), Rate(n, act), nil, "dim") end
end
local function Effective(out, p, s)
    if not p.eff then return end
    Put(out, "row", T("sum.tt.eff"), format(T("sum.tt.ofs"), Clock(p.eff), Clock(s.dur)))
    local parts = {}
    for k = 1, #LOST do
        local v = p.lost and p.lost[LOST[k]]
        if v then parts[#parts + 1] = format(T("sum.tt.lost." .. LOST[k]), Clock(v)) end
    end
    if #parts > 0 then Put(out, "sub", concat(parts, ", "), nil, nil, "dim") end
end
function Tips.Player(p, s)
    local out = {}
    local sec = ns.Totals.Time(s)
    Head(out, p.name, T("sum.tt.role." .. p.role), p.class)
    if p.deaths > 0 then Put(out, "row", T("sum.tt.deaths"), tostring(p.deaths), nil, "bad") end
    if p.interrupts > 0 then Put(out, "row", T("sum.tt.kicks"), tostring(p.interrupts)) end
    if p.tree and p.class and p.treeBy then
        Put(out, "row", T("sum.tt.spec"), T("spec." .. p.class .. "." .. p.tree))
        if p.treeBy == "insp" then Put(out, "sub", T("sum.tt.spec.insp"), nil, nil, "dim") end
    end
    Effective(out, p, s)
    if p.role == "heal" then
        Put(out, "row", T("sum.tt.heal"), Rate(p.heal, sec), Short(p.heal))
        NoIdle(out, p.heal, s)
        Abilities(out, p.healBy, nil, p.heal, p.abRest)
    else
        Put(out, "row", T("sum.tt.dmg"), Rate(p.dmg, sec), Short(p.dmg))
        Put(out, "sub", T("sum.tt.boss"), Rate(p.bossDmg, sec), Short(p.bossDmg))
        NoIdle(out, p.dmg, s)
        if (p.ride or 0) > 0 then
            Put(out, "sub", format(T("sum.tt.ride"), p.rideName or "?"), Short(p.ride), nil, "dim")
        end
        Abilities(out, p.dmgBy, p.petBy, p.dmg, p.abRest)
        if p.role == "tank" and p.heal > 0 then Put(out, "row", T("sum.tt.heal"), Rate(p.heal, sec), Short(p.heal)) end
    end
    Put(out, "foot", T("sum.tt.foot"))
    return out
end
local function Signed(sec)
    if sec <= -1 then return "-" .. Clock(-sec) end
    return Clock(max(0, sec))
end
local function Buffs(st, def)
    local out = {}
    Head(out, format(T(def.tip), ns.SpellName(def.spells[1])), format("x%d", st.n))
    local fate = st.fate
    for _, kind in ipairs(fate and { "over", "under", "cut", "miss" } or {}) do
        if (st[kind] or 0) > 0 then
            Put(out, "row", T("sum.b.clash." .. kind), tostring(st[kind]), nil, kind == "over" and "warn" or nil)
        end
    end
    local function Sec(x)
        return x % 1 == 0 and format("%d", x) or ns.Fixed(x)
    end
    local function Fate(k)
        local f = fate and fate[k]
        if not f then return nil end
        local at = f.h and ns.Dec(ns.Clock(f.h, true, true))
        local sec, full = Sec(f.s), ns.SummaryShed.Buffed.Clash.FULL
        local tone = f.over and "warn" or nil
        if f.cut then return format(T("sum.b.clash.cutAt"), ns.SpellName(f.id), at, sec), tone end
        if f.miss and at then return format(T("sum.b.clash.missAt"), ns.SpellName(f.id), at), tone end
        if f.u then return format(T("sum.b.clash.with"), sec, full, ns.SpellName(f.uid), Sec(f.u)), tone end
        return format(T("sum.b.clash.held"), sec, full), nil
    end
    local enc = ns.Encounters
    local function Class(who)
        return who and enc and enc.ClassOf and enc.ClassOf(who) or nil
    end
    local by, order = {}, {}
    for k = 1, st.n do
        local who = st.notes[k] or "?"
        if not by[who] then
            by[who] = {}
            order[#order + 1] = who
        end
        local list = by[who]
        list[#list + 1] = k
    end
    local shown = 0
    for o = 1, #order do
        local who = order[o]
        local list = by[who]
        if #list == 1 then
            local k = list[1]
            local pull = st.pulled ~= nil and st.pulled[k] == true
            out[#out + 1] = { kind = "row", left = who, right = Signed(st.times[k]),
                              mid = pull and T("sum.tt.pull") or nil, tone = pull and "good" or nil, class = Class(who) }
            local text, tone = Fate(k)
            if text then Put(out, "sub", text, nil, nil, tone) end
            shown = shown + 1
        else
            out[#out + 1] = { kind = "row", left = who, right = #order > 1 and format("x%d", #list) or nil,
                              class = Class(who) }
            for j = 1, #list do
                if shown >= TIMES then break end
                local k = list[j]
                local pull = st.pulled ~= nil and st.pulled[k] == true
                local text, tone = Fate(k)
                if text then
                    Put(out, "sub", Signed(st.times[k]), text, nil, tone)
                else
                    Put(out, "sub", Signed(st.times[k]), pull and T("sum.tt.pull") or nil, nil, pull and "good" or nil)
                end
                shown = shown + 1
            end
        end
    end
    if shown < st.n then Put(out, "sub", (format(T("sum.tip.more"), st.n - shown):gsub("^%s+", ""))) end
    return out
end
function Tips.Cons(list)
    local out = {}
    local e = list[1]
    local name = e.id and GetItemInfo and GetItemInfo(e.id) or e.item
    Head(out, name or "?", format("x%d", #list))
    for k = 1, min(TIMES, #list) do
        Put(out, "sub", Signed(list[k].t))
    end
    if #list > TIMES then Put(out, "sub", (format(T("sum.tip.more"), #list - TIMES):gsub("^%s+", ""))) end
    return out
end
local function Cure(out, h, at)
    local cure = h.cure
    if not cure then return end
    local defs = ns.defensives or {}
    local ready, names = {}, {}
    for k = 1, #cure do
        local c = cure[k]
        names[k] = Inline(c.id) .. (defs[c.id] and ns.SpellName(c.id) or "?")
        if c.left <= 0 then ready[#ready + 1] = names[k] end
    end
    local pre = at and (at .. "  ") or ""
    if #ready > 0 then return Put(out, "sub", pre .. format(T("sum.tt.cure.could"), concat(ready, ", ")), nil, nil, "bad") end
    Put(out, "sub", pre .. T("sum.tt.cure.none"), nil, nil, "dim")
    for k = 1, #cure do
        local c = cure[k]
        local left = Clock(math.ceil(c.left))
        Put(out, "sub", c.lock and format(T("sum.tt.cure.lock"), names[k], ns.SpellName(c.lock), left)
            or format(T("sum.tt.cure.cd"), names[k], left), nil, nil, "dim")
    end
end
local SHED_TONE = {
    hit = { shed = "warn", full = "bad" },
    shed = { shed = "good", full = "warn" },
    full = { shed = "bad", full = "good" },
}
local function Shed(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "text", ns.Penalties.ShedText(st.hangs, true))
    for k = 1, min(TIMES, #st.hangs) do
        local h = st.hangs[k]
        local how = T("sum.tt.shed." .. tostring(h.off))
        if h.off == "shed" and h.by then
            how = how .. ": " .. ns.Penalties.ShedName(h.by) .. (h.who and format(" (%s)", h.who) or "")
        end
        local tone = SHED_TONE[def.want or "hit"][h.off] or "dim"
        Put(out, "sub", Clock(max(0, h.t)), format(T("sum.tt.shed.sec"), floor(h.dur + 0.5), h.full), how, tone)
        Cure(out, h)
    end
    if #st.hangs > TIMES then Put(out, "sub", (format(T("sum.tip.more"), #st.hangs - TIMES):gsub("^%s+", ""))) end
    return out
end
function Tips.Badge(st, def)
    local kind = def.kind
    if kind == "given" or kind == "got" then return Buffs(st, def) end
    if kind == "pullin" and ns.PullTips then return ns.PullTips.Badge(st, def) end
    if def.shed and st.hangs and ns.Penalties then return Shed(st, def) end
    if kind == "stack" and st.eps and st.eps[1] and ns.StackTips then return ns.StackTips.Badge(st, def) end
    if kind == "lost" and st.lost and ns.StackTips then return ns.StackTips.Lost(st, def) end
    if ns.ActionTips and ns.ActionTips[kind] then return ns.ActionTips[kind](st, def) end
    local out = {}
    Head(out, T(def.tip))
    if def.low then
        Put(out, "row", T("sum.uld.min"), st.min and tostring(st.min) or "—")
        Put(out, "row", T("sum.uld.fin"), st.fin and tostring(st.fin) or "—")
        return out
    end
    if kind == "dmgto" then
        Put(out, "row", T("sum.tt.dmg"), Short(st.amount))
        if def.soak then
            Put(out, "row", T("sum.tt.hits"), tostring(st.hits))
        end
        return out
    end
    if kind == "vehicle" and st.outs then
        Put(out, "row", T("sum.tt.count"), tostring(st.n))
    else
        Times(out, max(st.n, st.removed or 0), st.times, 0)
    end
    if kind == "applied" then Tips.Uses(out, st) end
    if kind == "stack" and st.max > 0 then Put(out, "row", T("sum.tt.stackmax"), tostring(st.max)) end
    if kind == "hit" then
        Put(out, "row", T("sum.tt.hits"), tostring(st.hits))
        Put(out, "row", T("sum.tt.dmg"), Short(st.amount))
    end
    if kind == "vehicle" and st.outs then
        Put(out, "row", T("sum.tt.seated"), format(T("sum.tt.sec"), floor(st.sec or 0)))
        if st.waves then
            Put(out, "row", T("sum.tt.rides"), nil, nil, "dim")
            for k = 1, min(TIMES, #st.times) do
                local w = st.waves[k] or 0
                Put(out, "sub", w > 0 and format(T("sum.tt.wave"), w) or T("sum.tt.nowave"),
                    Clock(st.times[k]) .. "–" .. Clock(st.outs[k] or st.times[k]))
            end
            if #st.times > TIMES then Put(out, "sub", (format(T("sum.tip.more"), #st.times - TIMES):gsub("^%s+", ""))) end
            return out
        end
        local spans = {}
        for k = 1, min(TIMES, #st.times) do spans[k] = Clock(st.times[k]) .. "–" .. Clock(st.outs[k] or st.times[k]) end
        local more = #st.times > TIMES and format(T("sum.tip.more"), #st.times - TIMES) or ""
        Put(out, "row", T("sum.tt.rides"), concat(spans, ", ") .. more, nil, "dim")
        return out
    end
    if st.cleansed > 0 then
        Put(out, "row", T("sum.tt.cleansed"), tostring(st.cleansed), nil, "bad")
        Names(out, st.notes)
    end
    if kind == "killer" and #st.notes > 0 then
        Put(out, "row", T("sum.tt.victims"), tostring(#st.notes), nil, "bad")
        Names(out, st.notes)
    end
    if kind == "applied" and not def.names and #st.notes > 0 then
        Put(out, "row", T("sum.tt.targets"), tostring(#st.notes))
        Names(out, st.notes)
    end
    if kind == "stack" and st.max == 0 then
        Put(out, "sep")
        Put(out, "note", T("sum.tip.stackunknown"))
    end
    return out
end
local Body = Tips.Badge
local function Locked(out, st)
    local shown = false
    for k = 1, min(TIMES, #st.times) do
        local h = st.held[k]
        if h then
            if not shown then Put(out, "sep") end
            shown = true
            local kind = T(h.k == "mc" and "sum.tt.shadewhy.ctlk" or "sum.tt.shadewhy." .. h.k)
            Put(out, "sub", Clock(st.times[k]) .. " " .. format(T("sum.tt.locked"), kind, h.sp or "?", Clock(h.t)),
                nil, nil, "good")
        end
    end
end
function Tips.Badge(st, def)
    local out = Body(st, def)
    if st.held then Locked(out, st) end
    return out
end
function Tips.Dispel(d)
    local out = {}
    Head(out, d.name or "?", d.n and format("x%d", d.n) or nil)
    local list = d.list or {}
    if #list > 0 then
        for k = 1, min(TIMES, #list) do
            local e = list[k]
            local whom = e.self and T("sum.tip.curedself") or format(T("sum.tip.curedfrom"), e.who or "?")
            local what = Inline(e.id) .. (e.label and T(e.label) or e.name or "?")
            Put(out, "sub", Signed(e.t), whom, what, e.purge and "dim" or nil)
        end
        if #list <= TIMES then
            return out
        end
        Put(out, "sub", (format(T("sum.tip.more"), #list - TIMES):gsub("^%s+", "")))
        Put(out, "sep")
    end
    local cleanse, purge = {}, {}
    for _, w in pairs(d.what) do
        if w.purge then purge[#purge + 1] = w else cleanse[#cleanse + 1] = w end
    end
    local function Add(list, key)
        if #list == 0 then return end
        tsort(list, function(a, b) return a.n > b.n end)
        local total = 0
        for k = 1, #list do total = total + list[k].n end
        Put(out, "row", T(key), tostring(total))
        for k = 1, #list do
            local w = list[k]
            Put(out, "sub", Inline(w.id) .. (w.name or "?"), format("x%d", w.n))
        end
    end
    Add(cleanse, "sum.tt.cleanse")
    Add(purge, "sum.tt.purge")
    return out
end
function Tips.Kick(k)
    if k.all and ns.ActionTips then return ns.ActionTips.Kick(k) end
    local out = {}
    Head(out, k.name or "?", format("x%d", k.n))
    local list = {}
    for _, w in pairs(k.what) do list[#list + 1] = w end
    tsort(list, function(a, b) return a.n > b.n end)
    for i = 1, #list do
        local w = list[i]
        Put(out, "sub", Inline(w.id) .. (w.name or "?"), format("x%d", w.n), w.target or "?")
    end
    return out
end
local GUARD_WINDOW = 10
local function Guards(out, p, d, base)
    local list = ns.defensives or {}
    local near, last, order, fresh = {}, {}, {}, {}
    for k = 1, #(p.guardT or {}) do
        local t, id = p.guardT[k], p.guardId[k]
        local def = list[id]
        if def and t <= d.t and d.t - t <= GUARD_WINDOW then
            near[#near + 1] = format(T("sum.tt.guardago"), ns.SpellName(id), Dec(d.t - t, 1))
            fresh[id] = true
        elseif def and t < d.t then
            if not last[id] then order[#order + 1] = id end
            last[id] = t
        end
    end
    Put(out, "sub", T("sum.tt.guard10"), #near > 0 and concat(near, ", ") or T("sum.tt.guardnone"))
    tsort(order, function(a, c) return last[a] < last[c] end)
    for k = 1, #order do
        local id = order[k]
        if not fresh[id] then
            local ready = last[id] + list[id].cd <= d.t
            Put(out, "sub", ns.SpellName(id), T(ready and "sum.tt.guardready" or "sum.tt.guardcd"), Clock(last[id] - base),
                "dim")
        end
    end
end
local GRADE_TONE = { red = "bad", yellow = "warn", green = "good", gray = "dim" }
local WHY_PLAIN = { tail = true, intent = true, rule = true, horror = true, frenzy = true, must = true, wave = true,
                    waverule = true, slow = true, nodmg = true }
local WHY_BY = { ally = true, link = true, mc = true }
local WHY_REACT = { fast = true, wavefast = true }
local function GuardName(id)
    local def = id and ns.defensives and ns.defensives[id]
    return def and ns.SpellName(id) or nil
end
local function ReadyName(d)
    local name = GuardName(d.ready)
    if name and d.readyN then name = format(T("sum.dg.more"), name, d.readyN) end
    return name
end
function Tips.Verdict(d)
    local why = d.why or "nodmg"
    local key = "sum.dg." .. why
    local react = Dec(d.react or 0, 1)
    local text
    if WHY_PLAIN[why] then
        text = T(key)
    elseif WHY_BY[why] then
        text = format(T(key), d.by or "?")
    elseif WHY_REACT[why] then
        text = format(T(key), react)
    elseif why == "noheal" then
        text = format(T(key), Dec(d.gap or 0, 1), Short(d.gapHeal or 0))
    elseif why == "oneshot" then
        text = format(T(key), Short(d.oneHp or 0), Short(d.oneMax or 0))
    elseif why == "rose" then
        text = format(T(key), Dec(d.rose or 0, 1))
    elseif why == "used" then
        text = format(T(key), GuardName(d.used) or "?")
    elseif why == "ready" then
        text = format(T(key), ReadyName(d) or "?")
    elseif why == "late" then
        text = format(T(key), react, ReadyName(d) or "?")
    elseif why == "dep" and ns.DeathDeps then
        text = ns.DeathDeps.Text(d)
    elseif d.ruleN then
        text = format(T(key), d.ruleN)
    else
        text = T("sum.dg.nodmg")
    end
    if d.ready and why ~= "ready" and why ~= "late" then
        text = text .. format(T(d.late and "sum.dg.alsolate" or "sum.dg.also"), ReadyName(d))
    end
    if d.mass and why ~= "wave" and why ~= "wavefast" and why ~= "waverule" then text = text .. T("sum.dg.massmark") end
    if d.dep and why ~= "dep" and why ~= "mc" and ns.DeathDeps then text = text .. "; " .. ns.DeathDeps.Text(d) end
    return text
end
function Tips.Death(p, fight)
    local out = {}
    local counted = ns.DeathGrade.Skull(p)
    Head(out, T("sum.b.death"), format("x%d", counted))
    if p.deaths > counted then Put(out, "row", T("sum.dg.tailn"), tostring(p.deaths - counted), nil, "dim") end
    for k = 1, min(TIMES, #p.deathInfo) do
        local d = p.deathInfo[k]
        local killer = d.killer
        local what = T("sum.tt.nokiller")
        if killer then
            what = killer.spell == "#melee" and T("tl.swing") or tostring(killer.spell)
            if killer.src then what = format(T("sum.tt.killedby"), what, killer.src) end
        end
        Put(out, "row", Clock(d.t - fight.from), what)
        Put(out, "sub", Tips.Verdict(d), nil, nil, d.tail and "dim" or GRADE_TONE[d.grade or ""])
        if p.role == "tank" then Guards(out, p, d, fight.from) end
    end
    if #p.deathInfo > TIMES then
        Put(out, "sub", (format(T("sum.tip.more"), #p.deathInfo - TIMES):gsub("^%s+", "")))
    end
    local mcN = 0
    for k = 1, #p.deathInfo do
        if p.deathInfo[k].mc then
            if mcN == 0 then Put(out, "sep") end
            mcN = mcN + 1
            Victim(out, p.deathInfo[k], fight.from)
        end
    end
    return out
end
function Tips.Ready(r, fight)
    local out = {}
    Head(out, GuardName(r.id) or "?", T("sum.dg.readyhead"))
    Times(out, r.n, r.times, fight.from)
    return out
end
function Tips.EarlyPull(v, pullAt)
    local out = {}
    Head(out, T("sum.pt.head"))
    Put(out, "row", T("sum.pt.early"), format(T("sum.pt.sec"), Dec(v.early, 1)), nil, "warn")
    Put(out, "row", T("sum.pt.timer"), format(T("sum.pt.by"), v.sec, v.who), nil, "dim")
    Put(out, "row", T("sum.pt.set"), Clock(max(0, pullAt - v.t)), nil, "dim")
    return out
end
function Tips.Blame(p, fight)
    local out = {}
    Head(out, T("sum.dg.blamehead"))
    for k = 1, min(TIMES, #p.blame) do
        local b = p.blame[k]
        Put(out, "sub", Clock(b.t - fight.from), format(T("sum.dg.blame." .. b.grade), b.victim), nil,
            GRADE_TONE[b.grade])
    end
    return out
end
function Tips.Caused(list, fight)
    local out = {}
    Head(out, T("sum.dd.head"))
    for k = 1, min(TIMES, #list) do
        local c = list[k]
        Put(out, "sub", Clock(c.t - fight.from), format(T("sum.dd.row"), c.victim, ns.DeathDeps.What(c.dep)))
    end
    return out
end
function Tips.Duty(reason, have, need)
    local out = {}
    Head(out, reason, T("sum.tt.kind.duty"))
    Put(out, "row", T("sum.tt.done"), format(T("sum.tt.of"), have, need), nil, have < need and "bad" or "good")
    return out
end
local function PartName(name)
    local head = name:sub(1, 1)
    if head == "#" then return T("sum.cat." .. name:sub(2)) end
    if head == "@" then return format(T("sum.ab.petof"), name:sub(2)) end
    return name
end
local function AbHits(r)
    local c = r.c or 0
    if c > 0 then return format(T("sum.ab.crit"), r.n, floor(c * 100 / max(1, r.n) + 0.5)) end
    return format(T("sum.ab.hits"), r.n)
end
local function Amount(v, total)
    if not total then return Short(v) end
    return format(T("sum.ab.share"), Short(v), floor(v * 100 / max(1, total) + 0.5))
end
local function Split(map, out, counts, top, total)
    local parts = {}
    local rest = map and map[REST_KEY]
    for name, x in pairs(map or {}) do
        local r = type(x) == "table" and x or nil
        if name ~= REST_KEY then parts[#parts + 1] = { name = name, v = r and r.a or x, r = r } end
    end
    local extra = rest and rest.k or 0
    if #parts + extra < (total and 1 or 2) then return false end
    tsort(parts, function(a, c)
        if a.v ~= c.v then return a.v > c.v end
        return a.name < c.name
    end)
    local shown = min(top or TIMES, #parts)
    for k = 1, shown do
        local e = parts[k]
        if e.r then
            Put(out, "sub", Glyph(e.r.id) .. PartName(e.name), AbHits(e.r), Amount(e.v, total))
        else
            Put(out, "sub", PartName(e.name), counts and format("x%d", e.v) or Short(e.v))
        end
    end
    local n, sum, hits = extra + #parts - shown, rest and rest.a or 0, rest and rest.n or 0
    if n <= 0 then return true end
    local more = (format(T("sum.tip.more"), n):gsub("^%s+", ""))
    if not parts[1].r then
        Put(out, "sub", more)
        return true
    end
    for k = shown + 1, #parts do sum, hits = sum + parts[k].v, hits + parts[k].r.n end
    Put(out, "sub", more, format(T("sum.ab.hits"), hits), Amount(sum, total), "dim")
    return true
end
function Tips.Abil(out, ab, head, total)
    if not ab then return false end
    local list = {}
    if not Split(ab, list, false, BLOCK_TOP, total) then return false end
    if head then
        Put(out, "sep")
        Put(out, "row", T("sum.tt.abil"), nil, nil, "dim")
    end
    for k = 1, #list do out[#out + 1] = list[k] end
    return true
end
function Tips.Row(b, who, v, class)
    local out = {}
    local kind = b.def.kind
    local share = format("%.1f%%", v * 100 / max(1, b.total))
    Head(out, who, share, class)
    if kind == "parries" and b.parry and b.parry[who] and ns.ActionTips then
        ns.ActionTips.ParryBody(out, b.parry[who])
        return out
    end
    if kind == "dispels" then
        Put(out, "row", T("sum.tt.removed"), tostring(v))
        local totem = b.split[who] and b.split[who]["#totem"]
        if totem then
            Put(out, "sub", T("sum.tt.totem"), tostring(totem))
        end
    elseif kind == "casts" or kind == "removed" then
        Put(out, "row", T(kind == "casts" and "sum.tt.kicked" or "sum.tt.removed"), tostring(v))
        Split(b.split[who], out, true)
    elseif kind == "taken" then
        Put(out, "row", T("sum.tt.taken"), Short(v), format("x%d", b.hits[who] or 0))
        Split(b.split[who], out, false)
        if b.peak then Put(out, "row", T("sum.tt.stackmax"), tostring(b.peak[who] or 0)) end
    elseif kind == "usefulTo" then
        Put(out, "row", T(b.normal and "sum.tt.total" or "sum.tt.useful"), Short(v))
        local waves = b.waves and b.waves[who] or {}
        local list = {}
        for w = 1, #(b.waveList or {}) do
            if waves[w] then list[#list + 1] = { format(T("sum.tt.wave"), w), Short(waves[w]) } end
        end
        if waves[0] then list[#list + 1] = { T("sum.tt.nowave"), Short(waves[0]) } end
        for k = 1, #list > 1 and min(TIMES, #list) or 0 do Put(out, "sub", list[k][1], list[k][2]) end
        Tips.Abil(out, b.ab and b.ab[who], #list > 1)
    elseif kind == "cannons" then
        Put(out, "row", T("sum.tt.ship"), Short(v), format("x%d", b.hits[who] or 0))
        Put(out, "row", T("sum.tt.gunsec"), format(T("sum.tt.sec"), floor(b.secs[who] or 0)))
        if (b.kills[who] or 0) > 0 then Put(out, "row", T("sum.tt.gunkills"), tostring(b.kills[who])) end
        if (b.all[who] or 0) > 0 then
            Put(out, "sep")
            Put(out, "row", T("sum.tt.gunall"), Short(b.all[who]), nil, "dim")
        end
    else
        Put(out, "row", T("sum.tt.total"), Short(v), b.def.soak and format("x%d", b.hits[who] or 0) or nil)
        local ab = b.ab and b.ab[who]
        if kind == "friendly" and ab then
            Tips.Abil(out, ab, false)
        else
            Tips.Abil(out, ab, Split(b.split[who], out, false))
        end
    end
    return out
end
function Tips.Missed(b)
    local out = {}
    Head(out, T(b.def.label))
    Put(out, "row", T("sum.tt.notkicked"), format(T("sum.tt.of"), b.casts - b.total, b.casts), nil, "bad")
    Put(out, "row", T("sum.tt.raiddmg"), Short(b.missDmg))
    Put(out, "sub", T("sum.tt.hits"), tostring(b.missHits))
    return out
end
function Tips.McHurt(out, m, from)
    Put(out, "row", Clock(m.t - from) .. " " .. tostring(m.who), Short(m.n), nil, "bad")
    for i = 1, #(m.top or {}) do
        local e = m.top[i]
        local name = e.sp == "#melee" and T("sum.ab.melee") or ns.SpellName(e.sp)
        Put(out, "sub", name, Short(e.n))
    end
end
function Tips.AwayBody(out, st, lim)
    local share = ns.Away and ns.Away.Share(st, lim) or 0
    Put(out, "row", T("sum.tt.limit"), format(T("sum.tt.yd"), Dec(lim, 0)), nil, "dim")
    Put(out, "text", format(T("sum.tt.away"), Dec(st.avg or 0, 1), floor(share * 100 + 0.5), Dec(st.peak or 0, 1),
        Clock(st.peakT or 0)), nil, nil, st.avg > lim and "warn" or nil)
end
function Tips.TombSum(out, st, lim)
    local _, pts = ns.TombBreak.Shown(st, lim)
    Put(out, "row", T("sum.tt.tb.pts"), format(T("sum.tt.tb.of"), Dec(pts, 0), Dec(lim, 0)), nil, "warn")
end
function Tips.TombBody(out, st, k, many)
    local dead = st.dead[k] or 0
    local before = format(T("sum.tt.tb.before"), Dec(st.before[k] or 0, 1))
    if many then
        Put(out, "row", format(T("sum.tt.tb.tomb"), st.notes[k] or "?"), Dec(st.pts[k] or 0, 1), before, "warn")
    else
        Put(out, "row", format(T("sum.tt.tb.tomb"), st.notes[k] or "?"), before, nil, "warn")
    end
    Put(out, "row", T("sum.tt.tb.dead"), dead > 0 and st.dn[k] or T("sum.tt.tb.nodead"), nil, dead > 0 and "bad" or "good")
    if st.src[k] == "land" then
        Put(out, "note", T("sum.tt.tb.src.land"))
    elseif st.src[k] == "def" then
        Put(out, "note", T("sum.tt.tb.src.def"))
    end
    local acts = st.acts[k] or {}
    if #acts == 0 then return end
    Put(out, "sub", T("sum.tt.tb.col.ab"), T("sum.tt.tb.col.pts"), T("sum.tt.tb.col.hp"), "dim")
    for i = 1, #acts do
        local a = acts[i]
        local name
        if a.id == -1 then
            name = T("sum.tt.tb.rest")
        else
            name = a.id == 0 and (format(GLYPH, MELEE_ICON) .. T("sum.ab.melee")) or (Glyph(a.id) .. ns.SpellName(a.id))
        end
        if a.kind == "dot" then
            name = format(T("sum.tt.tb.dot"), name)
        elseif a.kind == "series" then
            name = format(T("sum.tt.tb.series"), name)
        end
        if a.n > 1 then name = format(T("sum.tt.tb.times"), name, a.n) end
        Put(out, "sub", name, Dec(a.pts, 1), format(T("sum.tt.tb.hp"), floor(a.h * 100 + 0.5), Short(a.hp)),
            a.h < 0.1 and "bad" or "warn")
    end
end
function Tips.Spared(sp)
    local out = {}
    Head(out, ns.Penalties.Reason(sp.rule))
    Put(out, "row", T("sum.tt.needdps"), format(T("sum.tt.ofs"), Short(sp.amount), Short(sp.need)))
    Put(out, "row", T("sum.tt.healer"), nil, nil, "good")
    if sp.spec and sp.class then Put(out, "sub", T("sum.tt.healspec"), T("spec." .. sp.class .. "." .. sp.spec)) end
    if #sp.bosses > 0 then Put(out, "sub", T("sum.tt.healedon"), concat(sp.bosses, ", ")) end
    return out
end
function Tips.Hit(fight, hit, reason)
    local out = {}
    Head(out, reason)
    local sum = 0
    for k = 1, #hit.events do sum = sum + hit.events[k].n end
    Put(out, "row", T("sum.tt.fine"), format(T("sum.tt.gp"), sum, ns.Ledger and ns.Ledger.Unit() or T("led.unit.gp")), format("x%d", #hit.events))
    local info = hit.events[1] and hit.events[1].info
    local rule = hit.rule
    if info and info.missing then
        Put(out, "row", T("sum.tt.done"), format(T("sum.tt.of"), info.have or 0, rule.min or 1), nil, "bad")
    elseif info and info.need then
        local key = info.melee == nil and "sum.tt.needdps" or (info.melee and "sum.tt.needmelee" or "sum.tt.needranged")
        Put(out, "row", T(key), format(T("sum.tt.ofs"), Short(info.amount or 0), Short(info.need)), nil, "bad")
    elseif info and info.tomb then
        Tips.TombSum(out, info.tomb, info.limit or 0)
        for k = 1, min(3, #hit.events) do
            local e = hit.events[k].info
            if e and e.tomb then Tips.TombBody(out, e.tomb, e.k, e.tomb.n > 1) end
        end
    elseif info and info.mcd then
        Put(out, "row", T("sum.tt.limit"), Short(info.limit or 0), nil, "dim")
        for k = 1, min(TIMES, #hit.events) do
            local m = hit.events[k].info and hit.events[k].info.mcd
            if m then Tips.McHurt(out, m, fight.from) end
        end
    elseif info and info.away then
        Tips.AwayBody(out, info.away, info.limit or 0)
    elseif info and info.early then
        Put(out, "row", T("sum.pt.early"), format(T("sum.pt.sec"), Dec(info.early, 1)), nil, "warn")
        Put(out, "row", T("sum.pt.timer"), format(T("sum.pt.by"), info.sec, info.setter or "?"), nil, "dim")
    elseif info and info.nova then
        for k = 1, min(TIMES, #hit.events) do
            local e, nv = hit.events[k], hit.events[k].info and hit.events[k].info.nova
            if nv then
                Put(out, "row", Clock((e.t or fight.from) - fight.from),
                    format(T("sum.tt.nova.yd"), tostring(nv.with or "?"), Dec(nv.yd or 0, 1)), nil, "warn")
            end
        end
    elseif info and info.rune then
        for k = 1, min(TIMES, #hit.events) do
            local e, r = hit.events[k], hit.events[k].info and hit.events[k].info.rune
            if r then
                Put(out, "row", Clock((e.t or fight.from) - fight.from) .. " " .. tostring(r.on or "?"),
                    format(T("sum.tt.rune.ep"), Dec(r.sec or 0, 1), r.hits or 0, Short(r.heal or 0)), nil, "warn")
            end
        end
    elseif info and (info.hurt or info.ticks) then
        for k = 1, min(TIMES, #hit.events) do
            local e = hit.events[k]
            local d = e.info or {}
            if d.hurt then
                Put(out, "sub", Clock((e.t or fight.from) - fight.from), d.names, format(T("sum.tt.defcnt"), d.hurt), "warn")
            elseif d.ticks then
                Put(out, "sub", Clock((e.t or fight.from) - fight.from), nil, format(T("sum.tt.defticks.n"), d.ticks),
                    d.ticks > 1 and "bad" or "warn")
            end
        end
    end
    local parts = {}
    for k = 1, min(TIMES, #hit.events) do
        local t = hit.events[k].t
        parts[#parts + 1] = t and Clock(t - fight.from) or T("sum.gp.whole")
    end
    if #parts > 0 then Put(out, "row", T("sum.tt.when"), concat(parts, ", "), nil, "dim") end
    for k = 1, rule.kind == "caused" and min(TIMES, #hit.events) or 0 do
        local e = hit.events[k]
        local dep = e.info and e.info.dep
        if dep and ns.DeathDeps then
            Put(out, "sub", Clock(e.t - fight.from), format(T("sum.dd.row"), e.info.victim or "?", ns.DeathDeps.What(dep)))
        end
    end
    for k = 1, #(hit.shed or {}) do
        local sh = hit.shed[k]
        Put(out, "text", (#hit.shed > 1 and (sh.spell .. ": ") or "") .. ns.Penalties.ShedText(sh.hangs, true))
        for j = 1, #sh.hangs do
            local h = sh.hangs[j]
            if h.off ~= "shed" then Cure(out, h, #sh.hangs > 1 and Clock(max(0, h.t)) or nil) end
        end
    end
    local ctl = info and info.ctl
    for k = 1, ctl and #hit.events or 0 do
        local c = hit.events[k].info and hit.events[k].info.ctl
        if c then Control(out, c, fight.from) end
    end
    local yellow = info and info.early and info.grade == "yellow"
    if rule.unverified then Put(out, "sep") end
    if rule.unverified then Put(out, "note", T("sum.gp.unverified")) end
    Put(out, "foot", T("sum.tt.foothit"))
    return out
end
function Tips.GPRow(item, reasonOf)
    local out = {}
    local unit = ns.Ledger and ns.Ledger.Unit(item.sys) or T("led.unit.gp")
    Head(out, item.name, nil, item.class)
    for i = 1, #item.hits do
        local hit = item.hits[i]
        local sum = 0
        for k = 1, #hit.events do sum = sum + hit.events[k].n end
        Put(out, "row", reasonOf(hit.rule), format(T("sum.tt.gp"), sum, unit), format("x%d", #hit.events))
        for k = 1, #(hit.shed or {}) do
            Put(out, "sub", ns.Penalties.ShedText(hit.shed[k].hangs, true), nil, nil,
                ns.Penalties.Grade(hit) == "yellow" and "warn" or nil)
        end
    end
    Put(out, "sep")
    Put(out, "row", T("sum.tt.gptotal"), format(T("sum.tt.gp"), item.total, unit))
    Put(out, "row", T("sum.tt.gppending"), format(T("sum.tt.gp"), item.pending, unit), nil,
        item.pending > 0 and "bad" or "good")
    Put(out, "foot", T("sum.tt.footrow"))
    return out
end
