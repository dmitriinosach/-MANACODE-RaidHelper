local _, ns = ...
local band = bit.band
local abs = math.abs
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
local Acts = {}
ns.Actions = Acts
local SUBS = { UNIT_DIED = true, SPELL_RESURRECT = true, SPELL_INTERRUPT = true, SPELL_CAST_START = true,
               SPELL_CAST_SUCCESS = true }
local function Fill(set, all, list)
    for i = 1, #(list or {}) do
        set[list[i]] = true
        all[list[i]] = true
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
            st.fam[list[i]] = fam
            st.spells[list[i]] = true
        end
    end
    Fill(st.kicks, st.spells, data.kicks)
    Fill(st.selfRez, st.spells, data.selfRez)
    st.spells[data.stone] = true
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
        end
    end
    return st
end
local function Rez(st, name, ts, by, spell, id, dead)
    local r = { t = ts, dead = dead, by = by, spell = spell, id = id, back = {}, lastT = {}, lastBy = {},
                n = 0, at = {}, giver = {}, sp = {}, ids = {}, dup = {} }
    st.rez[name] = r
    st.dead[name] = nil
    local k = #st.rezzes + 1
    st.rezzes[k], st.rezWho[k] = r, name
end
local function Buff(st, ts, sub, who, srcName, dstName, a1, a2)
    local fam = st.fam[a2]
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
local function Cc(st, p, ts, sub, dstName, a2, a4)
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
    c.res = c.res or {}
    c.outs = c.outs or {}
    c.open = c.open or {}
    c.spells[n], c.res[n], c.outs[n] = a2, ok and "ok" or tostring(a4), false
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
    if sub == "SPELL_CAST_START" then
        if enemy then st.castT[srcGUID], st.castSp[srcGUID] = ts, a2 end
        return
    elseif sub == "UNIT_DIED" then
        if inFight and dstName and byName[dstName] then st.dead[dstName], st.rez[dstName] = ts, nil end
        return
    elseif sub == "SPELL_RESURRECT" then
        local d = dstName and st.dead[dstName]
        if d and ts >= d and ts <= st.to then Rez(st, dstName, ts, srcName or "?", a2, tonumber(a1), d) end
        return
    elseif sub == "SPELL_INTERRUPT" then
        if dstGUID then st.castT[dstGUID], st.kickT[dstGUID], st.kickBy[dstGUID] = nil, ts, who or srcName end
        if p and inFight and st.kicks[a2] then KickEnd(st, p, who, ts, dstName, a1, a2, "ok", a5) end
        return
    elseif sub == "SPELL_CAST_SUCCESS" then
        if enemy then
            st.castT[srcGUID] = nil
            return
        end
        if not p then return end
        local d = srcName == who and st.dead[who]
        if d and ts <= st.to and (st.selfRez[a2] or (st.stoneT[who] and abs(st.stoneT[who] - d) <= DEATH_NEAR)) then
            if st.selfRez[a2] then
                Rez(st, who, ts, who, a2, tonumber(a1), d)
            else
                Rez(st, who, ts, who, st.stone, st.stoneId, d)
            end
        end
        if not inFight or type(a2) ~= "string" then return end
        if st.kicks[a2] and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
            KickCast(st, p, who, ts, dstGUID, dstName, a1, a2)
        elseif st.wrath and st.wrathSet[a2] and srcName == who then
            Wrath(st, p, ts, sub)
        end
        return
    end
    if type(a2) ~= "string" then return end
    if st.fam[a2] then
        if dstName and byName[dstName] then Buff(st, ts, sub, who, srcName, dstName, a1, a2) end
        return
    end
    if a2 == st.stone then
        if sub == "SPELL_AURA_REMOVED" and dstName and byName[dstName] then st.stoneT[dstName] = ts end
        return
    end
    if not p or not inFight then return end
    if st.kicks[a2] then
        if sub == "SPELL_MISSED" or sub == "DAMAGE_SHIELD_MISSED" then
            KickEnd(st, p, who, ts, dstName, a1, a2, "miss", a4)
        end
    elseif st.cc and st.ccSet[a2] then
        if srcName == who and dstName and byName[dstName] then Cc(st, p, ts, sub, dstName, a2, a4) end
    elseif st.wrath and st.wrathSet[a2] then
        if srcName == who and dstName ~= st.boss and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
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
    tsort(out)
    local ids = {}
    for k = 1, #out do ids[k] = st.spellId[out[k]] or false end
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
        for n = 1, c.n do tries[c.spells[n]] = (tries[c.spells[n]] or 0) + 1 end
        for sp, v in pairs(tries) do p.casts[sp] = math.max(p.casts[sp] or 0, v) end
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
