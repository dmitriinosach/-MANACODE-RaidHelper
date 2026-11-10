local _, ns = ...
local max = math.max
local min = math.min
local abs = math.abs
local floor = math.floor
local tsort = table.sort
local DMG = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true, SWING_DAMAGE = true,
              DAMAGE_SHIELD = true, SPELL_BUILDING_DAMAGE = true }
local SPLASH = { SPELL_DAMAGE = true, RANGE_DAMAGE = true }
local BURST = 0.3
local REMOVED = { SPELL_AURA_REMOVED = true, SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true }
local FROM_TOMB = { SPELL_AURA_APPLIED = true, SPELL_PERIODIC_DAMAGE = true, SPELL_DAMAGE = true }
local MELEE = 0
local MATCH = 0.3
local EARLY = 1
local RULE_T = 0.5
local T = {}
ns.ReplayTomb = T
function T.New(fight)
    local def = ns.replayTomb and ns.replayTomb[fight.boss]
    if not def then return nil end
    local aura = {}
    for i = 1, #def.aura do aura[def.aura[i]] = true end
    local series = {}
    local sum = ns.summaries and ns.summaries[fight.boss]
    for _, bd in ipairs(sum and sum.badges or {}) do
        if bd.kind == "tombbreak" then
            for id in pairs(bd.series or {}) do series[id] = true end
        end
    end
    return { fight = fight, def = def, npc = ns.NpcKeyOf(def.npc), aura = aura, players = fight.players or {},
             owners = {}, pets = ns.GetDB().pets or {}, tombs = {}, order = {}, jail = {}, series = series, burst = {},
             cnt = {} }
end
local function Tomb(c, guid, name, ts)
    local tb = c.tombs[guid]
    if tb then return tb end
    tb = { guid = guid, name = name or "", first = ts, from = ts, to = ts, max = 0, n = 0, t = {}, src = {}, id = {},
           eff = {}, cum = {}, per = {}, bst = {}, how = {} }
    c.tombs[guid] = tb
    c.order[#c.order + 1] = tb
    return tb
end
local function Burst(c, who, id, ts, tomb)
    local S = c.burst[who]
    if not S then
        S = { t = {}, n = {}, b = {} }
        c.burst[who] = S
    end
    local t0 = S.t[id]
    if t0 and ts - t0 <= BURST then
        S.n[id] = S.n[id] + 1
        local b = S.b[id]
        if b then c.cnt[b] = S.n[id] end
    else
        S.t[id], S.n[id], S.b[id] = ts, 1, false
    end
    if not tomb then return 0 end
    local b = S.b[id]
    if not b then
        b = #c.cnt + 1
        c.cnt[b] = S.n[id]
        S.b[id] = b
    end
    return b
end
function T.Event(c, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, a1, a2, a4, a5, id, srcKey, dstKey)
    if sub == "SPELL_SUMMON" then
        ns.NoteOwner(c.owners, sub, srcFlags, src, dstGUID)
        return
    end
    local isTomb = dstKey == c.npc and dstGUID ~= nil
    local bst = 0
    if SPLASH[sub] and id then
        local mine = ns.WhoOf(srcFlags, srcGUID, src, c.owners, c.pets)
        if mine then bst = Burst(c, mine, id, ts, isTomb) end
    end
    if isTomb then
        local tb = Tomb(c, dstGUID, dst, ts)
        local who = ns.WhoOf(srcFlags, srcGUID, src, c.owners, c.pets) or src or "?"
        if DMG[sub] then
            local swing = sub == "SWING_DAMAGE"
            local amount = tonumber(swing and a1 or a4) or 0
            local over = max(0, tonumber(swing and a2 or a5) or 0)
            local n = tb.n + 1
            tb.n = n
            tb.t[n], tb.src[n], tb.id[n] = ts, who, swing and MELEE or (id or 0)
            tb.eff[n] = max(0, amount - over)
            tb.cum[n] = (tb.cum[n - 1] or 0) + tb.eff[n]
            tb.per[n], tb.bst[n] = sub == "SPELL_PERIODIC_DAMAGE", bst
            if over > 0 then tb.killer, tb.killId = who, tb.id[n] end
        elseif sub == "UNIT_DIED" then
            tb.died = tb.died or ts
        elseif sub == "PARTY_KILL" then
            tb.died = tb.died or ts
            tb.party = who
        end
    elseif srcKey == c.npc and srcGUID and dst and c.players[dst] and FROM_TOMB[sub] then
        local tb = Tomb(c, srcGUID, src, ts)
        tb.who = tb.who or dst
    elseif id and c.aura[id] and dst and c.players[dst] then
        if sub == "SPELL_AURA_APPLIED" then
            c.jail[#c.jail + 1] = { who = dst, from = ts }
        elseif REMOVED[sub] then
            for i = #c.jail, 1, -1 do
                local j = c.jail[i]
                if j.who == dst and not j.to then
                    j.to = ts
                    break
                end
            end
        end
    end
end
local function JailFor(c, tb, used, who)
    local best
    for i = 1, #c.jail do
        local j = c.jail[i]
        if not used[i] and (not who or j.who == who) and j.from <= tb.first + EARLY and (j.to or math.huge) >= tb.first
            and (not best or j.from > c.jail[best].from) then
            best = i
        end
    end
    return best
end
local function Prisoners(c)
    local used, bound = {}, {}
    for _, tb in ipairs(c.order) do
        if tb.who then
            local i = JailFor(c, tb, used, tb.who)
            if i then used[i] = true end
            bound[tb] = i or 0
        end
    end
    for _, tb in ipairs(c.order) do
        if not bound[tb] and tb.died then
            local best, bestD
            for i = 1, #c.jail do
                local j = c.jail[i]
                local d = j.to and abs(j.to - tb.died)
                if not used[i] and d and d <= MATCH and (not bestD or d < bestD) then best, bestD = i, d end
            end
            if best then
                used[best] = true
                bound[tb] = best
                tb.who = c.jail[best].who
            end
        end
    end
    local rest = {}
    for _, tb in ipairs(c.order) do
        if not bound[tb] then rest[#rest + 1] = tb end
    end
    tsort(rest, function(a, b) return a.guid < b.guid end)
    local free = {}
    for i = 1, #c.jail do
        if not used[i] then free[#free + 1] = i end
    end
    tsort(free, function(a, b)
        local ja, jb = c.jail[a], c.jail[b]
        if ja.from ~= jb.from then return ja.from < jb.from end
        return ja.who < jb.who
    end)
    for _, tb in ipairs(rest) do
        for f = 1, #free do
            local i = free[f]
            local j = c.jail[i]
            if not used[i] and j.from <= tb.first + EARLY and (j.to or math.huge) >= tb.first then
                used[i] = true
                bound[tb] = i
                tb.who = j.who
                break
            end
        end
    end
    for tb, i in pairs(bound) do
        local j = i > 0 and c.jail[i]
        if j then
            tb.from = min(j.from, tb.first)
            tb.to = j.to or tb.died or c.fight.to
        end
    end
end
local function Stream(segs, tb, to)
    local key = ns.Streams.GuidKey(tb.guid)
    for i = 1, #segs do
        for t, hp, hpMax in ns.Decode.Hp(segs[i], key, nil, to) do
            if t > to then break end
            if hpMax > 0 then
                tb.hT, tb.hV = tb.hT or {}, tb.hV or {}
                tb.hT[#tb.hT + 1], tb.hV[#tb.hV + 1] = t, hp
                if hpMax > tb.max then tb.max = hpMax end
            end
        end
    end
end
function T.Done(c, L, scene, segs)
    if #c.order == 0 then return end
    Prisoners(c)
    local fight = c.fight
    local hp = c.def.hp[ns.Penalties.DiffOf(fight)]
    local top = 0
    for _, tb in ipairs(c.order) do
        if tb.died and tb.n > 0 and tb.cum[tb.n] > top then top = tb.cum[tb.n] end
    end
    local byK, list, of = ns.Replay.ByK(scene), {}, {}
    for _, tb in ipairs(c.order) do
        for i = 1, tb.n do
            local b = tb.bst[i]
            if c.series[tb.id[i]] or (b > 0 and (c.cnt[b] or 1) > 1) then
                tb.how[i] = "aoe"
            else
                tb.how[i] = tb.per[i] and "dot" or "aim"
            end
        end
        tb.per, tb.bst = nil, nil
        Stream(segs, tb, fight.to)
        if tb.max <= 0 then tb.max = hp or top end
        if tb.max <= 0 and tb.n > 0 then tb.max = tb.cum[tb.n] end
        if not tb.who then
            tb.from, tb.to = tb.first, tb.died or fight.to
        end
        if tb.died then tb.to = tb.died end
        if tb.died and not tb.killer then
            local who = tb.party or (tb.n > 0 and tb.src[tb.n]) or nil
            tb.killer = who
            for i = tb.n, 1, -1 do
                if tb.src[i] == who then
                    tb.killId = tb.id[i]
                    break
                end
            end
        end
        tb.k = tb.who and byK[tb.who] or nil
        list[#list + 1] = tb
        if tb.k then
            of[tb.k] = of[tb.k] or {}
            of[tb.k][#of[tb.k] + 1] = tb
        end
    end
    L.tombs, L.tombOf = list, of
end
function T.At(L, k, t, hold)
    local mine = L and L.tombOf and L.tombOf[k]
    if not mine then return nil end
    local held
    for i = 1, #mine do
        local tb = mine[i]
        if t >= tb.from and t <= tb.to then return tb end
        if hold and tb.died and t > tb.to and t <= tb.to + hold then held = tb end
    end
    return held
end
function T.Index(tb, t)
    local lo, hi = 0, tb.n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if tb.t[mid] <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end
function T.Hp(tb, t)
    local i = T.Index(tb, t)
    if tb.died and t >= tb.died then return 0, 0, i end
    local hp = tb.max - (tb.cum[i] or 0)
    local hT = tb.hT
    if hT and hT[1] <= t then
        local lo, hi = 1, #hT
        while lo < hi do
            local mid = floor((lo + hi + 1) / 2)
            if hT[mid] <= t then lo = mid else hi = mid - 1 end
        end
        local j = T.Index(tb, hT[lo])
        hp = tb.hV[lo] - ((tb.cum[i] or 0) - (tb.cum[j] or 0))
    end
    hp = max(0, min(tb.max, hp))
    return hp, tb.max > 0 and hp / tb.max or 0, i
end
function T.Label(tb, t)
    local hp, frac = T.Hp(tb, t)
    return ns.Short(hp) .. ", " .. floor(frac * 100 + 0.5) .. "%"
end
function T.Rule(fight, tb)
    if tb.rule ~= nil then return tb.rule end
    local TB = ns.TombBreak
    local s = TB and ns.Summary and ns.Summary.Peek(fight)
    if not s then return nil end
    local out = {}
    for name, p in pairs(s.byName or {}) do
        local st, def = TB.StatOf(s, p)
        if st and tb.died and #(TB.Shown(st, TB.Limit(def, fight))) > 0 then
            for k = 1, st.n do
                if abs(s.from + (st.times[k] or 0) - tb.died) <= RULE_T then out[name] = st.pts and st.pts[k] or 0 end
            end
        end
    end
    tb.rule = out
    return out
end
local function EndOf(tb, t)
    return tb.died and min(t, tb.died) or t
end
function T.State(tb, t, span)
    local e = EndOf(tb, t)
    local a = max(tb.from, e - span)
    local dmg = 0
    for h = T.Index(tb, e), 1, -1 do
        if tb.t[h] <= a then break end
        dmg = dmg + tb.eff[h]
    end
    local rate = dmg / max(1, e - a)
    local broken = tb.died ~= nil and t >= tb.died
    local hp = T.Hp(tb, t)
    return e - tb.from, rate, (not broken and rate > 0) and hp / rate or nil, broken
end
function T.Who(tb, t, span)
    local e = EndOf(tb, t)
    local a = span and max(tb.from, e - span) or -math.huge
    local by, rows = {}, {}
    for h = T.Index(tb, e), 1, -1 do
        if tb.t[h] <= a then break end
        local who = tb.src[h]
        local r = by[who]
        if not r then
            r = { who = who, sum = 0, aim = 0, dot = 0, aoe = 0, ids = {} }
            by[who] = r
            rows[#rows + 1] = r
        end
        local how, v = tb.how[h], tb.eff[h]
        r.sum, r[how] = r.sum + v, r[how] + v
        if how == "aoe" then r.ids[tb.id[h]] = (r.ids[tb.id[h]] or 0) + v end
    end
    for i = 1, #rows do
        local r = rows[i]
        r.how = (r.aoe > r.aim and r.aoe > r.dot) and "aoe" or (r.dot > r.aim and "dot" or "aim")
        local best = 0
        for id, v in pairs(r.ids) do
            if v > best or (v == best and id < (r.top or id + 1)) then r.top, best = id, v end
        end
        r.aim, r.dot, r.aoe, r.ids = nil, nil, nil, nil
    end
    tsort(rows, function(x, y)
        if x.sum ~= y.sum then return x.sum > y.sum end
        return x.who < y.who
    end)
    return rows
end
