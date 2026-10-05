local _, ns = ...
local band = bit.band
local format = string.format
local find = string.find
local max = math.max
local min = math.min
local concat = table.concat
local tsort = table.sort
local F_BY_PLAYER = 0x100
local ENTER_GAP = 5
local OOZE_SLOTS = { "rt", "gt", "ov", "gv" }
local ABOM_SLOTS = { "slow", "eat" }
local ONLY = { ov = "green", gv = "red" }
local Putri = {}
ns.Putri = Putri
local function Fill(set, list)
    for i = 1, #(list or {}) do set[ns.NpcKeyOf(list[i])] = true end
end
function Putri.Begin(s, fight, pets)
    local st
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        local kind = b.def.kind
        if kind == "oozes" or kind == "abom" then
            st = st or { from = fight.from, to = fight.to, byName = s.byName, pets = pets or {}, aura = {},
                         spells = {}, npcs = {}, open = {}, guids = {}, order = {} }
            b.ids = {}
            if kind == "oozes" then
                st.oz = b
                b.abom, b.eps = {}, {}
                for k, spell in pairs(b.def.auras or {}) do
                    st.aura[ns.SpellKey(spell)] = k
                    st.spells[ns.SpellKey(spell)] = true
                end
            else
                st.ab = b
                b.drv, b.hsp, b.heals = {}, {}, {}
                st.npcKey = ns.NpcKeyOf(b.def.npc)
                st.enter, st.slow, st.eat = ns.SpellKey(b.def.enter), ns.SpellKey(b.def.slow), ns.SpellKey(b.def.eat)
                st.npcs[st.npcKey] = true
                st.spells[st.enter] = true
                st.targets = {}
                Fill(st.targets, b.def.names)
            end
        end
    end
    return st
end
local function Open(st, who, k, ts, id)
    local oz = st.oz
    local open = st.open[who]
    if not open then
        open = {}
        st.open[who] = open
    end
    if open[k] then return end
    local ep = { k = k, a = max(ts, st.from) - st.from }
    open[k] = ep
    local list = oz.eps[who]
    if not list then
        list = {}
        oz.eps[who] = list
    end
    list[#list + 1] = ep
    oz.ids[k] = oz.ids[k] or tonumber(id)
    if ONLY[k] then oz.vars = true end
end
local function Close(st, who, k, ts)
    local open = st.open[who]
    if not open then return end
    for key, ep in pairs(open) do
        if not k or key == k then
            ep.z = min(ts, st.to) - st.from
            open[key] = nil
        end
    end
end
local function AddDmg(b, who, target, tkey, amount)
    b.total = b.total + amount
    b.by[who] = (b.by[who] or 0) + amount
    local sp = b.split[who]
    if not sp then
        sp = {}
        b.split[who] = sp
    end
    sp[target] = (sp[target] or 0) + amount
    ns.Summary.Color(b, who, tkey, amount)
end
local function Stint(st, g, ts)
    local d = st.guids[g]
    if d then return d end
    local who = st.pets[g]
    if not (who and st.byName[who]) then
        who = st.pend and st.pendT and ts - st.pendT <= ENTER_GAP and st.pend or "?"
    end
    local a = max(ts, st.from)
    d = { who = who, a = a, z = a, slows = 0, casts = 0, eats = 0, energy = 0, dmg = 0, heal = {}, egive = {}, eby = {} }
    st.guids[g] = d
    st.order[#st.order + 1] = g
    return d
end
local function Abom(st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, a1, a2, a4, a5, who, sk)
    local ab = st.ab
    if sk and sk == st.enter and sub == "SPELL_AURA_REMOVED" and dstName and st.byName[dstName] then
        st.pend, st.pendT = dstName, ts
        return
    end
    local npc = st.npcKey
    local srcKey, dstKey = ns.NpcKey(srcGUID), ns.NpcKey(dstGUID)
    local g = (srcKey == npc and srcGUID) or (dstKey == npc and dstGUID) or nil
    if not g then return end
    local d = Stint(st, g, ts)
    local selfPower = dstKey == npc and (sub == "SPELL_ENERGIZE" or sub == "SPELL_PERIODIC_ENERGIZE")
    if srcKey == npc and not selfPower then
        local driven = srcFlags ~= nil and band(srcFlags, F_BY_PLAYER) > 0
        if driven and ts > d.z then d.z = min(ts, st.to) end
        if sk and sk == st.slow and sub == "SPELL_AURA_APPLIED" and dstKey and st.targets[dstKey] then
            d.slows = d.slows + 1
            ab.ids.slow = ab.ids.slow or tonumber(a1)
        elseif sk and sk == st.slow and sub == "SPELL_CAST_SUCCESS" then
            d.casts = d.casts + 1
        elseif sk and sk == st.eat and sub == "SPELL_CAST_SUCCESS" then
            d.eats = d.eats + 1
            ab.ids.eat = ab.ids.eat or tonumber(a1)
        end
        local oz = st.oz
        if driven and oz and dstKey and oz.names[dstKey] and find(sub, "_DAMAGE", 1, true) then
            local amount = tonumber(sub == "SWING_DAMAGE" and a1 or a4) or 0
            d.dmg = d.dmg + amount
            if d.who ~= "?" then
                oz.abom[d.who] = (oz.abom[d.who] or 0) + amount
                if not who then
                    AddDmg(oz, d.who, dstName, dstKey, amount)
                    local swing = sub == "SWING_DAMAGE"
                    ns.Summary.Ab(oz, d.who, swing and "#swing" or tostring(a2), amount, nil, swing and 6603 or a1)
                end
            end
        end
    elseif dstKey == npc then
        if sub == "SPELL_ENERGIZE" or sub == "SPELL_PERIODIC_ENERGIZE" then
            local amount = tonumber(a4) or 0
            d.energy = d.energy + amount
            ab.power = true
            local key = (who or srcName or "?") .. " — " .. tostring(a2 or "?")
            d.egive[key] = (d.egive[key] or 0) + amount
            if who and who ~= d.who then
                local by = d.eby[who]
                if not by then
                    by = {}
                    d.eby[who] = by
                end
                local sp = tostring(a2 or "?")
                by[sp] = (by[sp] or 0) + amount
            end
        elseif find(sub, "_HEAL", 1, true) and who and st.byName[who] then
            local eff = (tonumber(a4) or 0) - (tonumber(a5) or 0)
            if eff > 0 then
                d.heal[who] = (d.heal[who] or 0) + eff
                local sp = ab.hsp[who]
                if not sp then
                    sp = {}
                    ab.hsp[who] = sp
                end
                local key = tostring(a2)
                sp[key] = (sp[key] or 0) + eff
            end
        end
    end
end
function Putri.Feed(st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, a1, a2, a4, a5, who)
    if ts < st.from or ts > st.to then return end
    if sub == "UNIT_DIED" then
        if dstName and st.open[dstName] then Close(st, dstName, nil, ts) end
        return
    end
    local sk = ns.SpellOf(sub, a1)
    local k = st.oz and sk and st.aura[sk]
    if k and dstName and st.byName[dstName] then
        if sub == "SPELL_AURA_APPLIED" then
            Open(st, dstName, k, ts, a1)
        elseif sub == "SPELL_AURA_REMOVED" then
            Close(st, dstName, k, ts)
        end
        return
    end
    if st.ab then Abom(st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, a1, a2, a4, a5, who, sk) end
end
function Putri.Finish(st)
    for who in pairs(st.open) do Close(st, who, nil, st.to) end
    local ab = st.ab
    if not ab then return end
    for i = 1, #st.order do
        local d = st.guids[st.order[i]]
        d.a, d.z = d.a - st.from, d.z - st.from
        ab.drv[#ab.drv + 1] = d
        for healer, v in pairs(d.heal) do
            ab.total = ab.total + v
            ab.heals[healer] = (ab.heals[healer] or 0) + v
        end
    end
    tsort(ab.drv, function(x, y) return x.a < y.a end)
end
local function T(key)
    return ns.T(key)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Short(v)
    return ns.BadgeTips.Short(v)
end
local function Span(a, z)
    local Clock = ns.BadgeTips.Clock
    return format("%s–%s", Clock(a), z and Clock(z) or "…")
end
local function Cell(v)
    return v > 0 and Short(v) or "—"
end
local function Of(eps, k)
    local out = {}
    for i = 1, #eps do
        if eps[i].k == k then out[#out + 1] = eps[i] end
    end
    return out
end
local function Periods(out, eps, k)
    local list = Of(eps, k)
    if #list == 0 then return end
    Put(out, "row", T("sum.oz." .. k), format("x%d", #list))
    local parts = {}
    for i = 1, #list do parts[i] = Span(list[i].a, list[i].z) end
    Put(out, "sub", concat(parts, ", "), nil, nil, "dim")
end
local function Could(out, eps)
    local list = {}
    for i = 1, #eps do
        if ONLY[eps[i].k] then list[#list + 1] = eps[i] end
    end
    if #list == 0 then
        Put(out, "row", T("sum.oz.can"), T("sum.oz.canboth"))
        return
    end
    tsort(list, function(x, y) return x.a < y.a end)
    Put(out, "row", T("sum.oz.can"), nil, nil, "dim")
    for i = 1, #list do
        Put(out, "sub", Span(list[i].a, list[i].z), T("sum.oz.can" .. ONLY[list[i].k]))
    end
    Put(out, "sub", T("sum.oz.rest"), T("sum.oz.canboth"), nil, "dim")
end
local function OozeTip(b, who, eps, class)
    local out = {}
    local sp = b.col and b.col[who] or {}
    out[1] = { kind = "head", left = who, right = Short(b.by[who] or 0), class = class }
    Put(out, "row", T("sum.oz.colgreen"), Short(sp[ns.NpcKeyOf(b.def.green)] or 0))
    Put(out, "row", T("sum.oz.colred"), Short(sp[ns.NpcKeyOf(b.def.red)] or 0))
    if (b.abom[who] or 0) > 0 then Put(out, "sub", T("sum.oz.fromabom"), Short(b.abom[who]), nil, "dim") end
    ns.BadgeTips.Abil(out, b.ab and b.ab[who], true)
    if b.vars then
        Put(out, "sep")
        Could(out, eps)
    end
    if #eps > 0 then Put(out, "sep") end
    for i = 1, #OOZE_SLOTS do Periods(out, eps, OOZE_SLOTS[i]) end
    return out
end
local function Heads(b, slots, fallback)
    local out = {}
    for i = 1, #slots do out[i] = b.ids[slots[i]] or (fallback and fallback[slots[i]]) or false end
    return out
end
local function OozeView(b, classOf)
    local names, seen = {}, {}
    for who in pairs(b.by) do
        seen[who] = true
        names[#names + 1] = who
    end
    for who in pairs(b.eps) do
        if not seen[who] then names[#names + 1] = who end
    end
    tsort(names, function(x, y)
        local vx, vy = b.by[x] or 0, b.by[y] or 0
        if vx ~= vy then return vx > vy end
        return x < y
    end)
    local slots, used = {}, {}
    for i = 1, #names do
        local eps = b.eps[names[i]] or {}
        for k = 1, #eps do used[eps[k].k] = true end
    end
    for i = 1, #OOZE_SLOTS do
        local k = OOZE_SLOTS[i]
        if used[k] or not ONLY[k] then slots[#slots + 1] = k end
    end
    local rows = {}
    for i = 1, #names do
        local who = names[i]
        local sp = b.col and b.col[who] or {}
        local eps = b.eps[who] or {}
        local marks = {}
        for k = 1, #slots do
            local n = #Of(eps, slots[k])
            marks[k] = n > 0 and { id = b.ids[slots[k]] or (b.def.icons and b.def.icons[slots[k]]), n = n } or false
        end
        local class = classOf and classOf(who) or nil
        rows[i] = { who = who, class = class, marks = marks,
                    cells = { Cell(b.by[who] or 0), Cell(sp[ns.NpcKeyOf(b.def.green)] or 0),
                              Cell(sp[ns.NpcKeyOf(b.def.red)] or 0) },
                    lines = OozeTip(b, who, eps, class) }
    end
    local tip = { { kind = "head", left = T(b.def.label), right = Short(b.total) } }
    return { title = format(T("sum.k.title"), T(b.def.label), Short(b.total)),
             cols = { T("sum.oz.colall"), T("sum.oz.colgreen"), T("sum.oz.colred") },
             heads = Heads(b, slots, b.def.icons), rows = rows, tip = tip, span = 1 }
end
local function Drivers(b)
    local by, list = {}, {}
    for i = 1, #b.drv do
        local d = b.drv[i]
        local r = by[d.who]
        if not r then
            r = { who = d.who, secs = 0, slows = 0, casts = 0, eats = 0, energy = 0, dmg = 0, heal = {}, got = 0,
                  stints = {}, egive = {}, eby = {} }
            by[d.who] = r
            list[#list + 1] = r
        end
        r.secs = r.secs + max(0, d.z - d.a)
        r.slows, r.casts, r.eats = r.slows + d.slows, r.casts + d.casts, r.eats + d.eats
        r.energy, r.dmg = r.energy + d.energy, r.dmg + d.dmg
        for k, v in pairs(d.egive or {}) do r.egive[k] = (r.egive[k] or 0) + v end
        for giver, sp in pairs(d.eby or {}) do
            local to = r.eby[giver]
            if not to then
                to = {}
                r.eby[giver] = to
            end
            for k, v in pairs(sp) do to[k] = (to[k] or 0) + v end
        end
        for healer, v in pairs(d.heal) do
            r.heal[healer] = (r.heal[healer] or 0) + v
            r.got = r.got + v
        end
        r.stints[#r.stints + 1] = d
    end
    tsort(list, function(x, y) return x.secs > y.secs end)
    return list
end
local function DriverTip(b, r, class)
    local out = { { kind = "head", left = r.who, right = ns.BadgeTips.Clock(r.secs), class = class } }
    local parts = {}
    for i = 1, #r.stints do parts[i] = Span(r.stints[i].a, r.stints[i].z) end
    Put(out, "row", T("sum.ab.drove"), concat(parts, ", "))
    Put(out, "row", T("sum.ab.slows"), format("x%d", r.slows), format(T("sum.ab.casts"), r.casts))
    Put(out, "row", T("sum.ab.eats"), format("x%d", r.eats))
    if b.power then
        Put(out, "row", T("sum.ab.energy"), tostring(r.energy))
        local es = {}
        for k, v in pairs(r.egive) do es[#es + 1] = { k = k, v = v } end
        tsort(es, function(x, y) return x.v > y.v end)
        for i = 1, #es do Put(out, "sub", es[i].k, "+" .. es[i].v) end
    else
        Put(out, "row", T("sum.ab.energy"), T("sum.ab.nopower"), nil, "dim")
    end
    if r.dmg > 0 then Put(out, "row", T("sum.ab.dmg"), Short(r.dmg)) end
    Put(out, "sep")
    Put(out, "row", T("sum.ab.healed"), Short(r.got))
    local hs = {}
    for healer, v in pairs(r.heal) do hs[#hs + 1] = { k = healer, v = v } end
    tsort(hs, function(x, y) return x.v > y.v end)
    for i = 1, #hs do Put(out, "sub", hs[i].k, Short(hs[i].v)) end
    return out
end
local function HealerTip(b, healer, v, class, energy)
    local out = { { kind = "head", left = healer, right = v > 0 and Short(v) or nil, class = class } }
    if energy then
        local es, sum = {}, 0
        for spell, x in pairs(energy) do
            es[#es + 1] = { k = spell, v = x }
            sum = sum + x
        end
        tsort(es, function(x, y) return x.v > y.v end)
        Put(out, "row", T("sum.ab.energy.gave"), tostring(sum))
        for i = 1, #es do Put(out, "sub", es[i].k, "+" .. es[i].v) end
        if v <= 0 then return out end
        Put(out, "sep")
    end
    Put(out, "row", T("sum.ab.healrow"), Short(b.heals[healer] or v))
    local parts = {}
    for spell, x in pairs(b.hsp[healer] or {}) do parts[#parts + 1] = { k = spell, v = x } end
    tsort(parts, function(x, y) return x.v > y.v end)
    for i = 1, #parts do Put(out, "sub", parts[i].k, Short(parts[i].v)) end
    return out
end
local function AbomView(b, classOf)
    local rows = {}
    local list = Drivers(b)
    for i = 1, #list do
        local r = list[i]
        local class = classOf and r.who ~= "?" and classOf(r.who) or nil
        rows[#rows + 1] = {
            who = r.who, class = class,
            cells = b.power and { ns.BadgeTips.Clock(r.secs), tostring(r.energy), Cell(r.got) }
                or { ns.BadgeTips.Clock(r.secs), Cell(r.got) },
            marks = { r.slows > 0 and { id = b.ids.slow or b.def.icons.slow, n = r.slows } or false,
                      r.eats > 0 and { id = b.ids.eat or b.def.icons.eat, n = r.eats } or false },
            lines = DriverTip(b, r, class),
        }
        local hs, seen = {}, {}
        for healer, v in pairs(r.heal) do
            hs[#hs + 1] = { k = healer, v = v, e = 0 }
            seen[healer] = hs[#hs]
        end
        for giver, sp in pairs(r.eby or {}) do
            local e = 0
            for _, x in pairs(sp) do e = e + x end
            local h = seen[giver]
            if not h then
                h = { k = giver, v = 0, e = 0 }
                hs[#hs + 1] = h
            end
            h.e = e
        end
        tsort(hs, function(x, y)
            if x.v ~= y.v then return x.v > y.v end
            return x.e > y.e
        end)
        for k = 1, #hs do
            local h = hs[k]
            local hc = classOf and classOf(h.k) or nil
            local heal = h.v > 0 and Short(h.v) or ""
            rows[#rows + 1] = { who = h.k, class = hc, sub = true,
                                cells = b.power and { "", h.e > 0 and tostring(h.e) or "", heal } or { "", heal },
                                marks = { false, false }, lines = HealerTip(b, h.k, h.v, hc, h.e > 0 and r.eby[h.k] or nil) }
        end
    end
    local tip = { { kind = "head", left = T(b.def.label), right = Short(b.total) } }
    return { title = format(T("sum.ab.title"), T(b.def.label), #list, Short(b.total)),
             cols = b.power and { T("sum.ab.coltime"), T("sum.ab.colenergy"), T("sum.ab.colheal") }
                 or { T("sum.ab.coltime"), T("sum.ab.colheal") },
             heads = Heads(b, ABOM_SLOTS, b.def.icons), rows = rows, tip = tip, span = 1 }
end
function Putri.View(b, classOf)
    local kind = b.def.kind
    if kind == "oozes" and b.eps then return OozeView(b, classOf) end
    if kind == "abom" and b.drv then return AbomView(b, classOf) end
    return nil
end
