local _, ns = ...
local band = bit.band
local find = string.find
local match = string.match
local tsort = table.sort
local F_PLAYER = 0x400
local TAIL = 3
local LATE = 60
local LEAD = 30
local FRESH = 10
local HIT_WINDOW = 1.5
local BIG_RAID = 12
local MAX_TAIL = 6
local SKIP_HP = { "FW_HP" }
local HP_ENTRY = "^%d+%.(%d+):%d+:%d+:(%d+):%d+"
local Ach = {}
ns.Achievements = Ach
local cache = setmetatable({}, { __mode = "k" })
local byBoss = {}
local byKey = nil
local raidKeys = setmetatable({}, { __mode = "k" })
local fightKeys = setmetatable({}, { __mode = "k" })
local function Set(list)
    local set = {}
    for i = 1, #(list or {}) do set[ns.NpcKeyOf(list[i])] = true end
    return set
end
local function IsBoss(fight, guid)
    return ns.IsBossOf(fight, guid)
end
local function Same(key, boss)
    key = ns.NpcKeyOf(key)
    return key == boss or ns.bosses[key] == boss
end
local function Matches(entry, boss)
    if type(entry) ~= "table" then return Same(entry, boss) end
    for i = 1, #entry do
        if Same(entry[i], boss) then return true end
    end
    return false
end
function Ach.SizeOf(fight)
    local raid = fight.raid
    if raid and raid.size then return raid.size end
    local n = 0
    for _ in pairs(fight.players or {}) do n = n + 1 end
    return n > BIG_RAID and 25 or 10
end
local function BySize(v, size)
    if type(v) == "table" then return v[size] or v[25] or v[10] end
    return v
end
function Ach.Defs(boss)
    local list = byBoss[boss]
    if list then return list end
    list = {}
    local all = ns.achDefs and ns.achDefs.fight or {}
    for i = 1, #all do
        local def = all[i]
        for k = 1, #def.bosses do
            if Matches(def.bosses[k], boss) then
                list[#list + 1] = def
                break
            end
        end
    end
    byBoss[boss] = list
    return list
end
function Ach.Def(key)
    if not byKey then
        byKey = {}
        local d = ns.achDefs or { fight = {}, raid = {} }
        for i = 1, #d.fight do byKey[d.fight[i].key] = d.fight[i] end
        for i = 1, #d.raid do byKey[d.raid[i].key] = d.raid[i] end
    end
    return byKey[key]
end
function Ach.Info(id)
    local _, name, points, desc, icon
    if GetAchievementInfo then _, name, points, _, _, _, _, desc, _, icon = GetAchievementInfo(id) end
    return name or ("#" .. tostring(id)), desc, icon, tonumber(points) or 0
end
local function Blame(st, name, t, v, note)
    local key = name or "#"
    local e = st.mark[key]
    if not e then
        e = { name = name, t = t, v = v, n = 1, note = note }
        st.mark[key] = e
        st.who[#st.who + 1] = e
        return e
    end
    e.n = e.n + 1
    if v and (not e.v or v > e.v) then
        e.v = v
        if note then e.note = note end
    end
    return e
end
local function IsPlayer(flags)
    return flags ~= nil and band(flags, F_PLAYER) > 0
end
local function OnLonger(st, ctx, ts, sub, _, _, _, _, dstName, dstFlags)
    if not dstName or not IsPlayer(dstFlags) then return end
    if sub == "SPELL_AURA_APPLIED" then
        st.on[dstName] = ts
    elseif sub == "SPELL_AURA_REMOVED" then
        local on = st.on[dstName]
        if not on then return end
        st.on[dstName] = nil
        local d = ts - on
        if d > st.value then st.value = d end
        if d > st.limit then Blame(st, dstName, on - ctx.from, d) end
    end
end
local function OnStack(st, ctx, ts, sub, _, _, _, _, dstName, dstFlags, _, _, _, _, a5)
    if not dstName or IsPlayer(dstFlags) == (st.def.npc == true) then return end
    local c
    if sub == "SPELL_AURA_APPLIED" then
        c = 1
    elseif sub == "SPELL_AURA_APPLIED_DOSE" then
        c = tonumber(a5) or 0
    else
        return
    end
    if c > st.value then
        st.value = c
        st.top = dstName
    end
    if st.limit and c > st.limit then Blame(st, dstName, ts - ctx.from, c) end
end
local function OnCount(st, ctx, ts, sub, srcGUID, _, _, _, dstName, dstFlags)
    if sub ~= "SPELL_AURA_APPLIED" or not dstName or not IsPlayer(dstFlags) then return end
    if st.def.src and ns.NpcKey(srcGUID) ~= ns.NpcKeyOf(st.def.src) then return end
    st.value = st.value + 1
    if st.value > st.limit then Blame(st, dstName, ts - ctx.from, st.value) end
end
local function OnCast(st, ctx, ts, sub, srcGUID, _, srcFlags)
    if sub ~= "SPELL_CAST_SUCCESS" or IsPlayer(srcFlags) then return end
    if st.def.src and ns.NpcKey(srcGUID) ~= ns.NpcKeyOf(st.def.src) then return end
    st.value = st.value + 1
    Blame(st, st.rider, ts - ctx.from, nil)
end
local function OnRider(st, _, _ts, sub, _, _, _, _, dstName, dstFlags)
    if not dstName or not IsPlayer(dstFlags) then return end
    if sub == "SPELL_AURA_APPLIED" then st.rider = dstName end
end
local function OnHit(st, ctx, ts, sub, srcGUID, srcName, srcFlags, _, dstName, dstFlags, _, _, _, a4)
    if not dstName or not IsPlayer(dstFlags) or IsPlayer(srcFlags) then return end
    if not find(sub, "_DAMAGE", 1, true) then return end
    if st.srcs and not (srcName and st.srcs[ns.NpcKey(srcGUID) or 0]) then return end
    st.value = st.value + 1
    Blame(st, dstName, ts - ctx.from, tonumber(a4))
end
local function OnLethal(st, _, ts, sub, _, _, _, _, dstName, dstFlags)
    if dstName and IsPlayer(dstFlags) and find(sub, "_DAMAGE", 1, true) then st.on[dstName] = ts end
end
local function OnVampire(st, ctx, ts, sub, _, _, _, _, dstName, dstFlags)
    if sub ~= "SPELL_AURA_APPLIED" or not dstName or not IsPlayer(dstFlags) then return end
    if not st.personal[dstName] then
        st.personal[dstName] = ts - ctx.from
        st.value = st.value + 1
    end
end
local function OnBigHit(st, ctx, ts, sub, _, srcName, srcFlags, _, dstName, dstFlags, _, a2, a3, a4)
    if sub ~= "SPELL_DAMAGE" and sub ~= "RANGE_DAMAGE" then return end
    if not dstName or not IsPlayer(dstFlags) or IsPlayer(srcFlags) or not srcName then return end
    if tonumber(a3) == 1 then return end
    local amount = tonumber(a4) or 0
    if amount > st.value then st.value = amount end
    if amount > st.limit then Blame(st, dstName, ts - ctx.from, amount, type(a2) == "string" and a2 or nil) end
end
local function OnDied(st, ctx, ts, dstName, dstFlags, dstGUID)
    local kind = st.kind
    if kind == "deathBy" then
        local at = dstName and IsPlayer(dstFlags) and st.on[dstName]
        if at and ts - at <= HIT_WINDOW then
            st.value = st.value + 1
            Blame(st, dstName, ts - ctx.from, nil)
            st.on[dstName] = nil
        end
        return
    end
    if kind == "aliveAt" then
        if not st.at and IsBoss(ctx.fight, dstGUID) then
            local seen, n = {}, 0
            for guid, u in pairs(st.units) do
                if not u.dead and ts - u.t <= FRESH then
                    local key = st.def.count == "types" and u.name or guid
                    if not seen[key] then
                        seen[key] = true
                        n = n + 1
                    end
                end
            end
            st.at, st.value = ts, n
            local alive = {}
            for key in pairs(seen) do
                if st.def.count == "types" then alive[#alive + 1] = key end
            end
            tsort(alive)
            st.alive = alive
        end
        return
    end
    local key = ns.NpcKey(dstGUID)
    if not dstName or not key or not st.names[key] then return end
    st.value = st.value + 1
    if kind == "noKill" then
        Blame(st, dstName, ts - ctx.from, nil)
    elseif kind == "lastDied" then
        st.last = key
        st.dead[key] = true
    elseif kind == "killSpan" then
        st.first = st.first or ts
        st.lastT = ts
        st.dead[key] = true
    end
end
local function Touch(st, guid, name, ts, died)
    local u = st.units[guid]
    if not u then
        if not (name and st.names[ns.NpcKey(guid) or 0]) then return end
        u = { name = name, t = ts }
        st.units[guid] = u
    end
    if died then
        u.dead, u.deadName, u.t = true, u.name, ts
        return
    end
    if u.dead then
        if not name or name == u.deadName then return end
        u.dead = false
    end
    if name then u.name = name end
    u.t = ts
end
local function OnSide(st, ctx, ts, name, x)
    if x <= 0 or ctx.fight.players[name] == nil then return end
    local hi, lo = st.def.split + st.def.band, st.def.split - st.def.band
    local side = (x > hi and 2) or (x < lo and 1) or nil
    local u = st.units[name]
    if not u then
        u = { side = 0, [1] = 0, [2] = 0, s1 = 0, s2 = 0, t = ts, at1 = {}, at2 = {} }
        st.units[name] = u
    end
    if u.side == 1 then u.s1 = u.s1 + ts - u.t elseif u.side == 2 then u.s2 = u.s2 + ts - u.t end
    u.t = ts
    if side and side ~= u.side then
        u.side = side
        u[side] = u[side] + 1
        local at = side == 2 and u.at2 or u.at1
        at[#at + 1] = ts - ctx.from
    end
end
local function OnHp(st, ctx, ts, body)
    if type(body) ~= "string" or not ctx.seg then return end
    local dict = ctx.seg.dict
    local p = 1
    while p do
        local nameId, x = match(body, HP_ENTRY, p)
        local name = nameId and dict[tonumber(nameId)]
        if name then OnSide(st, ctx, ts, name, (tonumber(x) or 0) / 10000) end
        local nx = find(body, ";", p, true)
        p = nx and nx + 1 or nil
    end
end
local function OnStreams(st, ctx, seg)
    local fight = ctx.fight
    for name in pairs(fight.players) do
        for ts, x in ns.Decode.Pos(seg, name, fight.from, fight.to) do
            if ts > fight.to then break end
            if ts >= fight.from then OnSide(st, ctx, ts, name, x / 10000) end
        end
    end
end
local function VisitsEnd(st)
    local n1, n2 = 0, 0
    for _, u in pairs(st.units) do
        local stop = st.endT or u.t
        if u.side == 1 then u.s1 = u.s1 + stop - u.t elseif u.side == 2 then u.s2 = u.s2 + stop - u.t end
        u.t = stop
        n1 = n1 + u.s1
        n2 = n2 + u.s2
    end
    local enemy = n2 <= n1 and 2 or 1
    for name, u in pairs(st.units) do
        local v = u[enemy]
        if v > st.value then st.value = v end
        if v > st.limit then
            local at = enemy == 2 and u.at2 or u.at1
            local e = Blame(st, name, at[1] or 0, v)
            e.times = at
        end
    end
end
local function Close(st, fight)
    local kind, kill = st.kind, fight.killed
    if kind == "auraLonger" then
        for name, on in pairs(st.on) do
            local d = fight.to - on
            if d > st.value then st.value = d end
            if d > st.limit then Blame(st, name, on - fight.from, d) end
        end
    elseif kind == "visits" then
        VisitsEnd(st)
    end
    local status
    if kind == "nodata" then
        status = "nodata"
    elseif kind == "vampire" then
        status = "open"
    elseif kind == "reachStack" then
        status = (kill and st.value >= st.need and "done") or (kill and "short") or "open"
    elseif kind == "killed" then
        status = (kill and st.value > 0 and "done") or (kill and "short") or "open"
    elseif kind == "aliveAt" then
        if not st.at then
            status = kill and "nodata" or "open"
        elseif st.value >= st.need then
            status = kill and "done" or "open"
        else
            status = st.def.short and "short" or "fail"
        end
    elseif kind == "lastDied" then
        local all = true
        for i = 1, #st.def.names do
            if not st.dead[ns.NpcKeyOf(st.def.names[i])] then all = false end
        end
        if not all then
            status = "open"
        else
            status = st.last == ns.NpcKeyOf(st.def.last) and "done" or "fail"
        end
    elseif kind == "killSpan" then
        local all = true
        for i = 1, #st.def.names do
            if not st.dead[ns.NpcKeyOf(st.def.names[i])] then all = false end
        end
        st.value = st.first and (st.lastT - st.first) or 0
        if st.first and st.value > st.limit then
            status = "fail"
        elseif all then
            status = "done"
        else
            status = "open"
        end
    elseif kind == "timeLimit" then
        st.value = fight.to - fight.from
        status = (st.value > st.limit and "fail") or (kill and "done") or "open"
    else
        status = (#st.who > 0 and "fail") or (kill and "done") or "open"
    end
    tsort(st.who, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return tostring(a.name) < tostring(b.name)
    end)
    return {
        def = st.def, id = st.id, status = status, value = st.value, limit = st.limit, need = st.need,
        who = st.who, alive = st.alive, last = st.last, personal = st.def.kind == "vampire" and st.personal or nil,
    }
end
local function NewState(def, size)
    return {
        def = def, kind = def.kind, id = def.id[size], limit = BySize(def.limit, size), need = BySize(def.need, size),
        value = 0, who = {}, mark = {}, on = {}, units = {}, dead = {}, personal = {},
        names = Set(def.names), srcs = def.srcs and Set(def.srcs) or nil,
    }
end
local function Watch(index, spell, st, fn, pre)
    spell = ns.SpellKey(spell)
    local list = index[spell]
    if not list then
        list = {}
        index[spell] = list
    end
    list[#list + 1] = { st = st, fn = fn, pre = pre }
end
local SPELL_FN = {
    auraLonger = OnLonger,
    maxStack = OnStack,
    reachStack = OnStack,
    auraCount = OnCount,
    casts = OnCast,
    hitBy = OnHit,
    deathBy = OnLethal,
    vampire = OnVampire,
}
local DIES = { deathBy = true, aliveAt = true, noKill = true, killed = true, lastDied = true, killSpan = true }
local function Build(fight)
    local defs = Ach.Defs(fight.boss)
    local size = Ach.SizeOf(fight)
    local states, bySpell, died, big, hp, track = {}, {}, {}, {}, {}, {}
    local late, early = false, false
    for i = 1, #defs do
        local def = defs[i]
        if def.id[size] then
            local st = NewState(def, size)
            states[#states + 1] = st
            local fn = SPELL_FN[def.kind]
            if fn then
                if def.spell then Watch(bySpell, def.spell, st, fn) end
                for k = 1, #(def.spells or {}) do Watch(bySpell, def.spells[k], st, fn) end
            end
            if def.rider then
                Watch(bySpell, def.rider, st, OnRider, true)
                early = true
            end
            if DIES[def.kind] then died[#died + 1] = st end
            if def.kind == "hitOver" then big[#big + 1] = st end
            if def.kind == "visits" then
                hp[#hp + 1] = st
                st.endT = fight.to
            end
            if def.kind == "aliveAt" then track[#track + 1] = st end
            if def.kind == "lastDied" or def.kind == "killSpan" then late = true end
        end
    end
    local out = {}
    if #states == 0 then return out end
    local ctx = { fight = fight, from = fight.from }
    local to = fight.to + (late and LATE or TAIL)
    local from = fight.from - (early and LEAD or 0)
    local skip = #hp == 0 and SKIP_HP or nil
    local segs = ns.Encounters.Segs(fight)
    for si = 1, #segs do
        local seg = segs[si]
        ctx.seg = seg
        if ns.Store.IsNew(seg) then
            for k = 1, #hp do OnStreams(hp[k], ctx, seg) end
        end
        for ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5
            in ns.Store.Events(seg, from, to, skip, MAX_TAIL) do
            ns.Jobs.Step()
            local sk = ns.SpellOf(sub, a1)
            local list = sk and bySpell[sk]
            local live = ts >= fight.from
            if list then
                for k = 1, #list do
                    local e = list[k]
                    if live or e.pre then
                        e.fn(e.st, ctx, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                            a1, a2, a3, a4, a5)
                    end
                end
            end
            if live then
                for k = 1, #track do
                    local st = track[k]
                    if srcGUID then Touch(st, srcGUID, srcName, ts, false) end
                    if dstGUID then Touch(st, dstGUID, dstName, ts, sub == "UNIT_DIED") end
                end
                if sub == "UNIT_DIED" then
                    for k = 1, #died do OnDied(died[k], ctx, ts, dstName, dstFlags, dstGUID) end
                elseif sub == "FW_HP" then
                    if ts <= fight.to then
                        for k = 1, #hp do OnHp(hp[k], ctx, ts, a1) end
                    end
                elseif #big > 0 then
                    for k = 1, #big do
                        OnBigHit(big[k], ctx, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                            a1, a2, a3, a4)
                    end
                end
            end
        end
    end
    for i = 1, #states do out[#out + 1] = Close(states[i], fight) end
    return out
end
function Ach.Build(fight)
    local r = cache[fight]
    if r then return r end
    r = Build(fight)
    cache[fight] = r
    return r
end
function Ach.Get(fight)
    return cache[fight]
end
function Ach.Keep(fight, list)
    cache[fight] = list
end
function Ach.Compute(fight, onDone)
    if cache[fight] then
        onDone(cache[fight])
        return
    end
    local key = fightKeys[fight] or {}
    fightKeys[fight] = key
    ns.Jobs.Run(key, function()
        ns.Jobs.Label("job.ach")
        return Ach.Build(fight)
    end, function(list)
        if list then onDone(list) end
    end, "ach.frame", true)
end
function Ach.Reset()
    for k in pairs(cache) do cache[k] = nil end
end
local RANK = { done = 1, fail = 2, short = 3, open = 4, nodata = 5 }
local function Label(entry)
    if type(entry) ~= "table" then return ns.EncName(ns.NpcKeyOf(entry)) end
    return ns.EncName(ns.NpcKeyOf(entry[1]))
end
local function FightsOf(fights, entry, heroic)
    local kills, all = {}, {}
    for i = 1, #fights do
        local f = fights[i]
        if Matches(entry, f.boss) then
            all[#all + 1] = f
            if f.killed and (not heroic or (f.raid and f.raid.heroic)) then kills[#kills + 1] = f end
        end
    end
    return kills, all
end
local function RaidFights(raid)
    local out = {}
    for i = 1, #(raid.encs or {}) do
        local enc = raid.encs[i]
        for k = 1, #enc.fights do out[#out + 1] = enc.fights[k] end
    end
    tsort(out, function(a, b) return a.from < b.from end)
    return out
end
local function Touches(def, fights)
    for i = 1, #def.bosses do
        for k = 1, #fights do
            if Matches(def.bosses[i], fights[k].boss) then return true end
        end
    end
    return false
end
local function RaidRow(def, fights, size)
    local have, missing = 0, {}
    for i = 1, #def.bosses do
        local entry = def.bosses[i]
        local kills, all = FightsOf(fights, entry, def.heroic)
        local ok = #kills > 0
        if ok and def.kind == "cleanKills" then
            ok = false
            for k = 1, #kills do
                if (kills[k].deaths or 0) == 0 then ok = true end
            end
        elseif ok and def.kind == "noDeaths" then
            for k = 1, #all do
                if (all[k].deaths or 0) > 0 then ok = false end
            end
        end
        if ok then have = have + 1 else missing[#missing + 1] = Label(entry) end
    end
    local need = #def.bosses
    return { def = def, id = def.id[size], scope = "raid", have = have, need = need, missing = missing,
             status = have >= need and "done" or "short" }
end
local function Merge(rows, got)
    for i = 1, #(got or {}) do
        local e = got[i]
        local row
        for k = 1, #rows do
            if rows[k].id == e.id then row = rows[k] end
        end
        if row then
            row.got = e
            row.status = "done"
        else
            rows[#rows + 1] = { id = e.id, scope = "chat", status = "done", got = e }
        end
    end
end
local function Finish(rows, size)
    for i = 1, #rows do
        local row = rows[i]
        row.order = i
        row.name, row.desc, row.icon, row.points = Ach.Info(row.id)
        row.size = size
    end
    tsort(rows, function(a, b)
        local ra, rb = RANK[a.status] or 9, RANK[b.status] or 9
        if ra ~= rb then return ra < rb end
        return a.order < b.order
    end)
    return rows
end
function Ach.FightRows(fight, list, got)
    local rows = {}
    for i = 1, #(list or {}) do
        local r = list[i]
        rows[#rows + 1] = { def = r.def, id = r.id, scope = "encounter", status = r.status, result = r, fight = fight }
    end
    Merge(rows, got)
    return Finish(rows, Ach.SizeOf(fight))
end
function Ach.ForRaid(raid, onDone, got)
    local fights = RaidFights(raid)
    local size = raid.size or (fights[1] and Ach.SizeOf(fights[1])) or 25
    local pending = {}
    local best, bestFight, order = {}, {}, {}
    for i = 1, #fights do
        local f = fights[i]
        if #Ach.Defs(f.boss) > 0 then
            local list = cache[f]
            if not list then
                pending[#pending + 1] = f
            else
                for k = 1, #list do
                    local r = list[k]
                    local key = r.def.key
                    if not best[key] then order[#order + 1] = key end
                    local cur = best[key]
                    local better = not cur or RANK[r.status] < RANK[cur.status]
                        or (r.status == cur.status and bestFight[key] and f.killed and not bestFight[key].killed)
                    if better then
                        best[key] = r
                        bestFight[key] = f
                    end
                end
            end
        end
    end
    local rows, zones = {}, {}
    local all = ns.achDefs and ns.achDefs.raid or {}
    for i = 1, #all do
        local def = all[i]
        if def.kind ~= "meta" and def.id[size] and (not def.heroic or raid.heroic) and Touches(def, fights) then
            rows[#rows + 1] = RaidRow(def, fights, size)
            zones[def.zone] = true
        end
    end
    local done = {}
    for i = 1, #rows do
        if rows[i].status == "done" then done[rows[i].def.key] = true end
    end
    for i = 1, #order do
        local r = best[order[i]]
        rows[#rows + 1] = { def = r.def, id = r.id, scope = "encounter", status = r.status, result = r,
                            fight = bestFight[order[i]] }
        if r.status == "done" and not r.def.personal then done[r.def.key] = true end
    end
    for i = 1, #all do
        local def = all[i]
        if zones[def.zone] and def.kind == "meta" and def.id[size] then
            local have, missing = 0, {}
            for k = 1, #def.parts do
                local part = def.parts[k]
                if done[part] then
                    have = have + 1
                else
                    missing[#missing + 1] = part
                end
            end
            rows[#rows + 1] = { def = def, id = def.id[size], scope = "meta", have = have, need = #def.parts,
                                missing = missing, status = have >= #def.parts and "done" or "short" }
        end
    end
    Merge(rows, got)
    Finish(rows, size)
    if onDone and #pending > 0 then
        local key = raidKeys[raid] or {}
        raidKeys[raid] = key
        ns.Jobs.Run(key, function()
            ns.Jobs.Label("job.ach")
            for i = 1, #pending do
                ns.Jobs.Progress(i - 1, #pending)
                Ach.Build(pending[i])
            end
            return true
        end, function(ok)
            if ok then onDone(Ach.ForRaid(raid, nil, got)) end
        end, "ach.raid")
    end
    return rows, #pending
end
