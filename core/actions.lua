local _, ns = ...
local band = bit.band
local abs = math.abs
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local F_HOSTILE = 0x40
local F_BY_PLAYER = 0x100
local DUP_WINDOW = 10
local DEATH_NEAR = 1.5
local CAST_MAX = 10
local LATE = 1.5
local PEND = 1
local WRATH_NEAR = 1.5
local SUNDER_BOSSES = 3
local Acts = {}
ns.Actions = Acts
local SUBS = { UNIT_DIED = true, SPELL_RESURRECT = true, SPELL_INTERRUPT = true, SPELL_CAST_START = true,
               SPELL_CAST_SUCCESS = true }
local function Fill(set, all, list)
    for i = 1, #(list or {}) do
        local k = ns.SpellKey(list[i])
        set[k] = true
        all[k] = true
    end
end
function Acts.Begin(s, fight)
    local data = ns.actions
    if not data then return nil end
    local st = { s = s, byName = s.byName, from = fight.from, to = fight.to, boss = fight.boss,
                 fam = {}, kicks = {}, selfRez = {},
                 stone = data.stone, stoneId = data.stoneId, ccSet = {}, wrathSet = {}, spells = {}, subs = SUBS,
                 dead = {}, stoneT = {}, rez = {}, rezzes = {}, rezWho = {}, lostT = {}, lostSp = {}, spellId = {},
                 castT = {}, castSp = {}, kickT = {}, kickBy = {}, pendI = {}, pendK = {}, pendT = {},
                 rebuff = ns.Tune("rebuff") }
    for fam, list in pairs(data.rebuffs) do
        for i = 1, #list do
            local k = ns.SpellKey(list[i])
            st.fam[k] = fam
            st.spells[k] = true
        end
    end
    Fill(st.kicks, st.spells, data.kicks)
    Fill(st.selfRez, st.spells, data.selfRez)
    st.stone = ns.SpellKey(data.stone)
    st.spells[st.stone] = true
    for i = 1, #data.badges do
        local bd = data.badges[i]
        if not bd.boss or bd.boss == fight.boss then
            local k = #s.badges + 1
            s.badges[k] = bd
            for j = 1, #s.players do
                s.players[j].badges[k] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
            end
            st[bd.kind] = k
            if bd.kind == "cc" then Fill(st.ccSet, st.spells, bd.spells) end
            if bd.kind == "wrath" then Fill(st.wrathSet, st.spells, bd.spells) end
            if bd.kind == "sunder" and data.sunder then
                local sd = data.sunder
                local su = { aura = ns.SpellKey(sd.aura), casts = {}, expose = {}, names = {}, need = sd.need,
                             match = sd.match, units = {}, order = {} }
                Fill(su.casts, su.names, sd.casts)
                Fill(su.expose, su.names, sd.expose)
                su.names[su.aura] = true
                for key in pairs(su.names) do st.spells[key] = true end
                st.sun = su
            end
        end
    end
    return st
end
local function IsBoss(st, guid)
    local key = ns.NpcKey(guid)
    if not key then return false end
    return key == st.boss or (ns.bosses[key] == st.boss and not (ns.bossParts and ns.bossParts[key]))
end
local function Span(st, a, b)
    return max(0, min(b, st.to) - max(a, st.from))
end
local function Stacks(st, su, u, ts, n)
    if u.n >= su.need and n < su.need and u.at5 then
        u.up = u.up + Span(st, u.at5, ts)
        u.at5 = nil
    elseif u.n < su.need and n >= su.need then
        u.at5 = ts
    end
    u.n = n
end
local function Exposed(st, u, ts, on, by)
    if on then
        u.exOn = u.exOn or ts
        if by then u.exBy[by] = (u.exBy[by] or 0) + 1 end
    elseif u.exOn then
        u.ex = u.ex + Span(st, u.exOn, ts)
        u.exOn = nil
    end
end
local function SunderAura(st, su, u, ts, sub, who, srcName, a5)
    if sub == "SPELL_AURA_REMOVED" then
        Stacks(st, su, u, ts, 0)
        return
    elseif sub == "SPELL_AURA_REMOVED_DOSE" then
        Stacks(st, su, u, ts, tonumber(a5) or max(0, u.n - 1))
        return
    end
    local n
    if sub == "SPELL_AURA_APPLIED" then
        n = 1
    elseif sub == "SPELL_AURA_APPLIED_DOSE" then
        n = tonumber(a5) or u.n + 1
    elseif sub == "SPELL_AURA_REFRESH" then
        n = max(u.n, 1)
    else
        return
    end
    local by
    if u.last and ts - u.lastT <= su.match then
        by, u.last = u.last, nil
    elseif who and srcName == who then
        by = who
    end
    local was = u.n
    Stacks(st, su, u, ts, n)
    u.seen = true
    local five = was < su.need and n >= su.need
    if five and not u.five then u.five, u.fiveBy = ts, by or false end
    local p = by and st.byName[by]
    if not p then return end
    local i = st.sunder
    local c = p.badges[i]
    c.n = c.n + 1
    if was >= su.need then c.hits = c.hits + 1 end
    if five then c.made = (c.made or 0) + 1 end
    if #c.times == 0 then c.times[1] = ts - st.from end
    st.s.icons[i] = st.s.icons[i] or st.s.badges[i].id
end
local function Sunder(st, ts, sub, who, srcName, dstGUID, dstName, a2, a5)
    local su = st.sun
    if not dstGUID or ts > st.to or not IsBoss(st, dstGUID) then return end
    local u = su.units[dstGUID]
    if not u then
        u = { name = dstName, npc = ns.NpcKey(dstGUID) or 0, n = 0, up = 0, ex = 0, exBy = {} }
        su.units[dstGUID] = u
        su.order[#su.order + 1] = dstGUID
    end
    if sub == "SPELL_CAST_SUCCESS" then
        if su.casts[a2] and who and srcName == who and st.byName[who] then u.last, u.lastT = who, ts end
    elseif su.expose[a2] then
        if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
            Exposed(st, u, ts, true, who and st.byName[who] and who or nil)
        elseif sub == "SPELL_AURA_REMOVED" then
            Exposed(st, u, ts, false)
        end
    elseif a2 == su.aura then
        SunderAura(st, su, u, ts, sub, who, srcName, a5)
    end
end
local function SunderStop(st, u, ts)
    Stacks(st, st.sun, u, ts, 0)
    Exposed(st, u, ts, false)
end
local function Most(map)
    local best, top = false, 0
    for name, n in pairs(map) do
        if n > top or (n == top and best and name < best) then best, top = name, n end
    end
    return best
end
local function ByUptime(a, b)
    if a.up + a.ex ~= b.up + b.ex then return a.up + a.ex > b.up + b.ex end
    if a.npc ~= b.npc then return a.npc < b.npc end
    return a.name < b.name
end
local function SunderEnd(st)
    local su = st.sun
    if not su then return end
    local list, byName = {}, {}
    for k = 1, #su.order do
        local u = su.units[su.order[k]]
        local stop = min(st.to, u.dead or st.to)
        SunderStop(st, u, stop)
        if u.seen or u.ex > 0 then
            local life = max(1, stop - st.from)
            local e = { name = u.name, npc = u.npc, up = u.up / life, ex = u.ex / life, five = u.five and u.five - st.from or false,
                        by = u.fiveBy or false, exBy = Most(u.exBy) }
            local old = byName[u.name]
            if not old then
                byName[u.name] = e
                list[#list + 1] = e
            elseif ByUptime(e, old) then
                for key, v in pairs(e) do old[key] = v end
            end
        end
    end
    tsort(list, ByUptime)
    for k = #list, SUNDER_BOSSES + 1, -1 do list[k] = nil end
    if #list == 0 then return end
    local s = st.s
    for k = 1, #s.players do
        local c = s.players[k].badges[st.sunder]
        if c.n > 0 then c.bosses = list end
    end
end
local function Rez(st, name, ts, by, spell, id, dead)
    local r = { t = ts, dead = dead, by = by, spell = spell, id = id, back = {}, lastT = {}, lastBy = {},
                n = 0, at = {}, giver = {}, sp = {}, ids = {}, dup = {} }
    st.rez[name] = r
    st.dead[name] = nil
    local k = #st.rezzes + 1
    st.rezzes[k], st.rezWho[k] = r, name
end
local function Buff(st, ts, sub, who, srcName, dstName, a1, a2, sk)
    local fam = st.fam[sk]
    if sub == "SPELL_AURA_REMOVED" then
        local lt = st.lostT[dstName]
        if not lt then
            lt = {}
            st.lostT[dstName], st.lostSp[dstName] = lt, {}
        end
        lt[fam] = ts
        st.lostSp[dstName][fam] = a2
        st.spellId[a2] = st.spellId[a2] or tonumber(a1)
        return
    end
    if sub ~= "SPELL_AURA_APPLIED" then return end
    local r = st.rez[dstName]
    if not r or ts < r.t or ts - r.t > st.rebuff or ts > st.to then return end
    if not who or srcName ~= who or not st.byName[who] then return end
    local last, lastBy = r.lastT[fam], r.lastBy[fam]
    local dup = last and lastBy ~= who and ts - last <= DUP_WINDOW and lastBy or nil
    local first = not r.back[fam]
    r.back[fam] = true
    r.lastT[fam], r.lastBy[fam] = ts, who
    if not dup and (not first or who == dstName) then return end
    local n = r.n + 1
    r.n = n
    r.at[n], r.giver[n], r.sp[n], r.ids[n], r.dup[n] = ts, who, a2, tonumber(a1) or false, dup or false
end
local function Kick(p, a1, a2)
    local key = tostring(a2 or a1)
    local k = p.kick[key]
    if not k then
        k = { id = tonumber(a1), name = a2, n = 0, what = {} }
        p.kick[key] = k
    end
    if not k.all then k.all, k.at, k.tgt, k.res, k.sp = 0, {}, {}, {}, {} end
    return k
end
local function KickRow(st, k, ts, dstName)
    local i = k.all + 1
    k.all = i
    k.at[i], k.tgt[i] = ts - st.from, dstName or "?"
    return i
end
local function KickCast(st, p, who, ts, dstGUID, dstName, a1, a2)
    local k = Kick(p, a1, a2)
    local i = KickRow(st, k, ts, dstName)
    local ct = dstGUID and st.castT[dstGUID]
    local kt = dstGUID and st.kickT[dstGUID]
    if ct and ts - ct <= CAST_MAX then
        k.res[i], k.sp[i] = "fail", st.castSp[dstGUID] or false
    elseif kt and ts - kt <= LATE and st.kickBy[dstGUID] ~= who then
        k.res[i], k.sp[i] = "late", st.kickBy[dstGUID] or false
    else
        k.res[i], k.sp[i] = "idle", false
    end
    st.pendI[who], st.pendK[who], st.pendT[who] = i, k, ts
end
local function Pending(st, k, who, ts)
    if st.pendK[who] ~= k or ts - st.pendT[who] > PEND then return nil end
    st.pendK[who] = nil
    return st.pendI[who]
end
local function KickEnd(st, p, who, ts, dstName, a1, a2, res, what)
    local k = Kick(p, a1, a2)
    local i = Pending(st, k, who, ts)
    if not i then
        if res ~= "ok" then return end
        i = KickRow(st, k, ts, dstName)
    end
    k.res[i], k.sp[i] = res, type(what) == "string" and what or false
end
local function Cc(st, p, ts, sub, dstName, a1, a2, a4, sk)
    local i = st.cc
    local c = p.badges[i]
    if sub == "SPELL_AURA_REMOVED" then
        local k = c.open and c.open[dstName]
        if k then
            c.outs[k] = ts - st.from - c.times[k]
            c.open[dstName] = nil
        end
        return
    end
    local ok = sub == "SPELL_AURA_APPLIED"
    if not ok and sub ~= "SPELL_MISSED" and sub ~= "DAMAGE_SHIELD_MISSED" then return end
    local n = c.n + 1
    c.n = n
    c.times[n], c.notes[n] = ts - st.from, dstName
    c.spells = c.spells or {}
    c.keys = c.keys or {}
    c.res = c.res or {}
    c.outs = c.outs or {}
    c.open = c.open or {}
    c.ids = c.ids or {}
    c.spells[n], c.keys[n], c.res[n], c.outs[n] = a2, sk, ok and "ok" or tostring(a4), false
    c.ids[n] = tonumber(a1) or false
    if ok then
        c.hits = c.hits + 1
        c.open[dstName] = n
    end
    st.s.icons[i] = st.s.icons[i] or st.s.badges[i].id
end
local function Wrath(st, p, ts, sub)
    local i = st.wrath
    local w = p.badges[i]
    if sub == "SPELL_CAST_SUCCESS" then
        local n = w.n + 1
        w.n = n
        w.times[n] = ts - st.from
        w.cnt = w.cnt or {}
        w.hitn = w.hitn or {}
        w.cnt[n], w.hitn[n] = 0, 0
        w.last = ts
        st.s.icons[i] = st.s.icons[i] or st.s.badges[i].id
        return
    end
    if not w.last or ts - w.last > WRATH_NEAR then return end
    local n = w.n
    if sub == "SPELL_AURA_APPLIED" then
        w.cnt[n] = w.cnt[n] + 1
        w.amount = w.amount + 1
        if w.cnt[n] == 1 then w.hits = w.hits + 1 end
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED" then
        w.hitn[n] = w.hitn[n] + 1
    end
end
function Acts.Feed(st, ts, sub, who, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5)
    local byName = st.byName
    local p = who and byName[who]
    local inFight = ts >= st.from and ts <= st.to
    local enemy = srcGUID ~= nil and srcFlags ~= nil and band(srcFlags, F_HOSTILE) > 0
        and band(srcFlags, F_BY_PLAYER) == 0
    local sk = ns.SpellOf(sub, a1)
    if st.sun and sk and st.sun.names[sk] then
        Sunder(st, ts, sub, who, srcName, dstGUID, dstName, sk, a5)
        return
    end
    if sub == "SPELL_CAST_START" then
        if enemy then st.castT[srcGUID], st.castSp[srcGUID] = ts, a2 end
        return
    elseif sub == "UNIT_DIED" then
        if inFight and dstName and byName[dstName] then st.dead[dstName], st.rez[dstName] = ts, nil end
        local u = st.sun and dstGUID and st.sun.units[dstGUID]
        if u and not u.dead and ts >= st.from then
            SunderStop(st, u, ts)
            u.dead = ts
        end
        return
    elseif sub == "SPELL_RESURRECT" then
        local d = dstName and st.dead[dstName]
        if d and ts >= d and ts <= st.to then Rez(st, dstName, ts, srcName or "?", a2, tonumber(a1), d) end
        return
    elseif sub == "SPELL_INTERRUPT" then
        if dstGUID then st.castT[dstGUID], st.kickT[dstGUID], st.kickBy[dstGUID] = nil, ts, who or srcName end
        if p and inFight and sk and st.kicks[sk] then KickEnd(st, p, who, ts, dstName, a1, a2, "ok", a5) end
        return
    elseif sub == "SPELL_CAST_SUCCESS" then
        if enemy then
            st.castT[srcGUID] = nil
            return
        end
        if not p then return end
        local d = srcName == who and st.dead[who]
        local own = sk and st.selfRez[sk]
        if d and ts <= st.to and (own or (st.stoneT[who] and abs(st.stoneT[who] - d) <= DEATH_NEAR)) then
            if own then
                Rez(st, who, ts, who, a2, tonumber(a1), d)
            else
                Rez(st, who, ts, who, ns.SpellName(st.stoneId), st.stoneId, d)
            end
        end
        if not inFight or not sk or type(a2) ~= "string" then return end
        if st.kicks[sk] and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
            KickCast(st, p, who, ts, dstGUID, dstName, a1, a2)
        elseif st.wrath and st.wrathSet[sk] and srcName == who then
            Wrath(st, p, ts, sub)
        end
        return
    end
    if not sk or type(a2) ~= "string" then return end
    if st.fam[sk] then
        if dstName and byName[dstName] then Buff(st, ts, sub, who, srcName, dstName, a1, a2, sk) end
        return
    end
    if sk == st.stone then
        if sub == "SPELL_AURA_REMOVED" and dstName and byName[dstName] then st.stoneT[dstName] = ts end
        return
    end
    if not p or not inFight then return end
    if st.kicks[sk] then
        if sub == "SPELL_MISSED" or sub == "DAMAGE_SHIELD_MISSED" then
            KickEnd(st, p, who, ts, dstName, a1, a2, "miss", a4)
        end
    elseif st.cc and st.ccSet[sk] then
        if srcName == who and dstName and byName[dstName] then Cc(st, p, ts, sub, dstName, a1, a2, a4, sk) end
    elseif st.wrath and st.wrathSet[sk] then
        if srcName == who and ns.NpcKey(dstGUID) ~= st.boss and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
            Wrath(st, p, ts, sub)
        end
    end
end
local function Real(p, t)
    for k = 1, #p.deathAt do
        if p.deathAt[k] == t then return true end
    end
    return false
end
local function Missing(st, name, r)
    local lt, ls = st.lostT[name], st.lostSp[name]
    if not lt then return false, false end
    local out
    for fam, t in pairs(lt) do
        if abs(t - r.dead) <= DEATH_NEAR and not r.back[fam] then
            out = out or {}
            out[#out + 1] = ls[fam]
        end
    end
    if not out then return false, false end
    local sid = st.spellId
    tsort(out, function(a, b)
        local ia, ib = sid[a] or 0, sid[b] or 0
        if ia ~= ib then return ia < ib end
        return a < b
    end)
    local ids = {}
    for k = 1, #out do ids[k] = sid[out[k]] or false end
    return concat(out, ", "), ids
end
local function Recipient(st, p, r, name)
    local i = st.rebuffed
    if not i then return end
    local c = p.badges[i]
    local n = c.n + 1
    c.n = n
    c.times[n] = r.t - st.from
    c.rezBy, c.rezSp, c.miss = c.rezBy or {}, c.rezSp or {}, c.miss or {}
    c.rezId, c.missId, c.ri = c.rezId or {}, c.missId or {}, c.ri or {}
    c.rt, c.rg, c.rs, c.rd, c.rk = c.rt or {}, c.rg or {}, c.rs or {}, c.rd or {}, c.rk or {}
    c.rezBy[n], c.rezSp[n], c.rezId[n] = r.by, r.spell or false, r.id or false
    c.miss[n], c.missId[n] = Missing(st, name, r)
    for e = 1, r.n do
        local m = #c.rt + 1
        c.rt[m], c.rg[m], c.rs[m], c.rd[m], c.rk[m] = r.at[e] - st.from, r.giver[e], r.sp[e], r.dup[e], n
        c.ri[m] = r.ids[e]
        c.notes[#c.notes + 1] = r.giver[e]
    end
    c.icon = c.icon or r.id
    st.s.icons[i] = st.s.icons[i] or c.icon or st.s.badges[i].id
end
local function Giver(st, r, e, name)
    local i = st.rebuff
    local g = i and st.byName[r.giver[e]]
    if not g then return end
    local c = g.badges[i]
    local n = c.n + 1
    c.n = n
    c.times[n], c.notes[n] = r.at[e] - st.from, name
    c.spells, c.after, c.dups, c.ids = c.spells or {}, c.after or {}, c.dups or {}, c.ids or {}
    c.ids[n] = r.ids[e]
    c.spells[n], c.after[n], c.dups[n] = r.sp[e], r.at[e] - r.t, r.dup[e]
    if r.dup[e] then c.grade = "yellow" end
    c.icon = c.icon or r.ids[e] or nil
    st.s.icons[i] = st.s.icons[i] or c.icon or st.s.badges[i].id
end
local function CcCasts(st)
    local i = st.cc
    if not i then return end
    local s = st.s
    for k = 1, #s.players do
        local p = s.players[k]
        local c = p.badges[i]
        local tries = {}
        for n = 1, c.n do
            local sk = c.keys and c.keys[n] or c.spells[n]
            tries[sk] = (tries[sk] or 0) + 1
        end
        for sp, v in pairs(tries) do p.casts[sp] = math.max(p.casts[sp] or 0, v) end
    end
end
local function ByUse(a, b)
    if a.ok ~= b.ok then return a.ok > b.ok end
    if a.n ~= b.n then return a.n > b.n end
    return tostring(a.key) < tostring(b.key)
end
function Acts.Uses(st)
    local list, by = {}, {}
    local keys, ids, tg, res = st.keys or {}, st.ids or {}, st.tg or st.notes or {}, st.res
    for n = 1, #keys do
        local k = keys[n]
        local u = by[k]
        if not u then
            u = { key = k, id = ids[n], name = st.spells and st.spells[n] or nil, n = 0, ok = 0, tg = {}, seen = {} }
            by[k] = u
            list[#list + 1] = u
        end
        u.n = u.n + 1
        if not res or res[n] == "ok" then u.ok = u.ok + 1 end
        local who = tg[n]
        if who and not u.seen[who] then
            u.seen[who] = true
            u.tg[#u.tg + 1] = who
        end
    end
    tsort(list, ByUse)
    return list
end
local function UseIcons(st)
    local s = st.s
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "cc" or (bd.kind == "applied" and bd.spells and #bd.spells > 1) then
            for k = 1, #s.players do
                local c = s.players[k].badges[i]
                local top = c and c.keys and Acts.Uses(c)[1]
                if top and top.id then c.icon = top.id end
            end
        end
    end
end
function Acts.Finish(st)
    for k = 1, #st.rezzes do
        local r, name = st.rezzes[k], st.rezWho[k]
        local p = st.byName[name]
        if p and Real(p, r.dead) then
            Recipient(st, p, r, name)
            for e = 1, r.n do Giver(st, r, e, name) end
        end
    end
    CcCasts(st)
    UseIcons(st)
    SunderEnd(st)
end
function Acts.Grade(n, hits, forced)
    if hits == 0 and (n > 0 or forced) then return "red" end
    return nil
end
function Acts.Covers(s, p, d)
    local duty = d.rule.by and p.class and d.rule.by[p.class]
    if not duty then return nil end
    if d.rule.what == "dispel" then
        if d.n < d.need then return nil end
        for k = 1, #p.dispList do
            if p.dispList[k].id == duty.id then return true end
        end
        return nil
    end
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if (bd.kind == "cc" or bd.kind == "wrath") and bd.spells then
            for k = 1, #bd.spells do
                if bd.spells[k] == duty.spell then return i end
            end
        end
    end
    return nil
end
