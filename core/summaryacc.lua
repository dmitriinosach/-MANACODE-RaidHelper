local _, ns = ...
local Acc = {}
ns.SummaryAcc = Acc
local tsort = table.sort
local SpellKey = ns.SpellKey
local NpcKeyOf = ns.NpcKeyOf
local RIDE_BOUNCE = 1
local CAPTURE_WINDOW = 10
local CAPTOR_GAP = 5
local AOE_WINDOW = 0.4
local ABIL_KEEP = 8
local SWING_KEY = "#swing"
local REST_KEY = "#rest"
local badgeSets = setmetatable({}, { __mode = "k" })
local function BadgeSets(bd)
    local d = badgeSets[bd]
    if d then return d end
    d = { set = {} }
    if bd.kind == "applied" then
        ns.SpellSet(bd.spells, d.set)
        if bd.names then
            d.targets = {}
            ns.NpcSet(bd.names, d.targets)
        end
    else
        ns.NpcSet(bd.names, d.set)
    end
    badgeSets[bd] = d
    return d
end
local function AppliedHit(bd, sk, dstKey, other)
    local d = BadgeSets(bd)
    if not d.set[sk] then return false end
    if d.targets then return dstKey ~= nil and d.targets[dstKey] == true end
    return other
end
local derived = setmetatable({}, { __mode = "k" })
local function Keys(bd)
    local k = derived[bd]
    if not k then
        k = { sk = bd.spell and SpellKey(bd.spell) or nil, src = bd.src and NpcKeyOf(bd.src) or nil,
              npc = bd.npc and NpcKeyOf(bd.npc) or nil }
        derived[bd] = k
    end
    return k
end
local function Add(b, who, key, amount)
    b.total = b.total + amount
    b.by[who] = (b.by[who] or 0) + amount
    local sp = b.split[who]
    if not sp then
        sp = {}
        b.split[who] = sp
    end
    sp[key] = (sp[key] or 0) + amount
end
local function Ab(t, who, key, amount, crit, id)
    local ab = t.ab
    if not ab then
        ab = {}
        t.ab = ab
    end
    local m = ab[who]
    if not m then
        m = {}
        ab[who] = m
    end
    local r = m[key]
    if not r then
        r = { a = 0, n = 0, id = tonumber(id) }
        m[key] = r
    end
    r.a = r.a + amount
    r.n = r.n + 1
    if crit then r.c = (r.c or 0) + 1 end
end
local function Color(b, who, tkey, amount)
    if not tkey then return end
    local col = b.col
    if not col then
        col = {}
        b.col = col
    end
    local c = col[who]
    if not c then
        c = {}
        col[who] = c
    end
    c[tkey] = (c[tkey] or 0) + amount
end
local function AbKey(s, swing, src, who, spell, srcKey)
    if src ~= who and not (srcKey and s.rides[srcKey]) then return "@" .. tostring(src or "?") end
    if swing then return SWING_KEY end
    return tostring(spell)
end
local function AbTrim(ab)
    for _, m in pairs(ab or {}) do
        local list = {}
        for key, r in pairs(m) do list[#list + 1] = { key = key, a = r.a, id = r.id or 0 } end
        if #list > ABIL_KEEP then
            tsort(list, function(x, y)
                if x.a ~= y.a then return x.a > y.a end
                if x.id ~= y.id then return x.id < y.id end
                return x.key < y.key
            end)
            local rest = { a = 0, n = 0, k = 0 }
            for k = ABIL_KEEP + 1, #list do
                local r = m[list[k].key]
                m[list[k].key] = nil
                rest.a, rest.n, rest.k = rest.a + r.a, rest.n + r.n, rest.k + 1
            end
            m[REST_KEY] = rest
        end
    end
end
local function DamageTo(s, p, who, target, tkey, amount, src, swing, spell, crit, id, srcKey, guid)
    if not tkey then return end
    local badges = s.badges
    for i = 1, s.own do
        local bd = badges[i]
        if bd.kind == "dmgto" and BadgeSets(bd).set[tkey] then
            local st = p.badges[i]
            st.n = 1
            st.amount = st.amount + amount
            st.hits = st.hits + 1
            s.icons[i] = bd.id
        end
    end
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "targets" then
            ns.Targets.Hit(b, who, target, guid, tkey, amount, AbKey(s, swing, src, who, spell, srcKey), crit, id)
        elseif b.names[tkey] and (b.def.kind == "damageTo" or b.def.kind == "oozes") then
            Add(b, who, target, amount)
            if b.def.kind == "oozes" then Color(b, who, tkey, amount) end
            Ab(b, who, AbKey(s, swing, src, who, spell, srcKey), amount, crit, id)
            if b.def.soak then b.hits[who] = (b.hits[who] or 0) + 1 end
        end
    end
end
local function Bounce(s, p, tkey, key, at)
    local badges = s.badges
    for i = 1, s.own do
        local bd = badges[i]
        if bd.kind == "bounce" and BadgeSets(bd).set[tkey] then
            local st = p.badges[i]
            st.n = st.n + 1
            if st.n == 1 then st.times[1] = at end
            st.by = st.by or {}
            st.by[key] = (st.by[key] or 0) + 1
            s.icons[i] = bd.id
        end
    end
end
local function Listed(b, sk, srcKey)
    return b.spells ~= nil and sk ~= nil and b.spells[sk] == true
        and (not b.srcs or (srcKey ~= nil and b.srcs[srcKey] == true))
end
local function HealTo(s, who, tkey, spell, amount)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "healTo" and b.names[tkey] then Add(b, who, spell, amount) end
    end
end
local function Guard(p, ts, id)
    local t = p.guardT
    if not t then
        t = {}
        p.guardT, p.guardId = t, {}
    end
    local n = #t + 1
    t[n], p.guardId[n] = ts, id
end
local function Hurt(s, victim, sk, spell, srcKey, amount, absorbed)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if Listed(b, sk, srcKey) and (not absorbed or (b.def.kind == "taken" and b.def.absorbed)) then
            if b.def.kind == "taken" then
                Add(b, victim, spell, amount)
                b.hits[victim] = (b.hits[victim] or 0) + 1
            elseif b.def.kind == "casts" then
                b.missDmg = b.missDmg + amount
                b.missHits = b.missHits + 1
            end
        end
    end
end
local function Peak(s, victim, sk, stacks)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.peak and b.spells[sk] and stacks > (b.peak[victim] or 0) then b.peak[victim] = stacks end
    end
end
local function EnemyCast(s, sk, srcKey, started)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" and Listed(b, sk, srcKey) then
            if started then b.starts = b.starts + 1 else b.done = b.done + 1 end
        end
    end
end
local function Kicked(s, who, sk, srcKey, kick)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" and Listed(b, sk, srcKey) then Add(b, who, kick, 1) end
    end
end
local function Cured(s, who, sk, debuff)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "removed" and Listed(b, sk, nil) then Add(b, who, debuff, 1) end
    end
end
local function Unit(b, guid)
    local v = b.units[guid]
    if not v then
        v = { wave = b.wave, hp = b.hpMax, done = false }
        b.units[guid] = v
    end
    return v
end
local function Credit(t, who, key, wave, amount, hit)
    Add(t, who, key, amount)
    Ab(t, who, hit.key, amount, hit.crit, hit.id)
    local w = t.waves[who]
    if not w then
        w = {}
        t.waves[who] = w
    end
    w[wave] = (w[wave] or 0) + amount
end
local function UsefulWatch(s, b, ts, sub, srcKey, dstGUID, dstKey, sk)
    if sk and sk == SpellKey(b.def.heroic) and srcKey and b.names[srcKey] then
        b.heroic = true
    elseif sub == "SPELL_SUMMON" and dstGUID and dstKey and b.names[dstKey] then
        local w = s.track and b.def.wave and ns.Phases.Count(s.track, b.def.wave) or 0
        local v = Unit(b, dstGUID)
        v.wave = w
        if w < 1 then return end
        local list = b.waveList[w]
        if not list then
            list = { t = ts }
            b.waveList[w] = list
        end
        b.wave = w
        list[#list + 1] = v
    elseif sub == "UNIT_DIED" and dstGUID then
        local v = b.units[dstGUID]
        if v and v.capAt and not v.freeAt then v.freeAt = ts end
    end
end
local function Captive(b, who, ts, on)
    for w = b.wave, math.max(1, b.wave - 1), -1 do
        local list = b.waveList[w]
        for k = 1, #list do
            local v = list[k]
            if v.captive == who then
                if not on and not v.freeAt then
                    v.freeAt = ts
                    b.freed[who] = true
                    return
                elseif on and (not v.freeAt or ts - v.freeAt <= RIDE_BOUNCE) then
                    v.freeAt = nil
                    return
                end
            end
        end
    end
    local list = b.waveList[b.wave]
    if not on or not list or ts - list.t > CAPTURE_WINDOW then return end
    for k = 1, #list do
        if not list[k].captive then
            list[k].captive = who
            list[k].capAt = ts
            b.bound = true
            return
        end
    end
end
local function Caught(s, p)
    local i = s.captor
    local st = p.badges[i]
    local ts = p.capT
    if not st.last or ts - st.last > CAPTOR_GAP then
        st.n = st.n + 1
        st.times[#st.times + 1] = ts - s.from
    end
    st.last = ts
    st.hits = st.hits + 1
    st.amount = st.amount + p.capAmount
    s.icons[i] = s.badges[i].id
    p.capT = nil
end
local function Captor(s, p, ts, guid, key, amount, mine)
    local cap = p.capT
    if cap and ts - cap > AOE_WINDOW then
        Caught(s, p)
    elseif cap and key == p.capKey and guid ~= p.capGuid then
        p.capT = nil
    end
    local aoe = p.hitT and key == p.hitKey and guid ~= p.hitGuid and ts - p.hitT <= AOE_WINDOW
    if mine and not aoe then
        if p.capT then Caught(s, p) end
        p.capT, p.capKey, p.capGuid, p.capAmount = ts, key, guid, amount
    end
    p.hitT, p.hitKey, p.hitGuid = ts, key, guid
end
local function UsefulHit(s, b, p, who, own, ts, guid, tkey, amount, over, key, dot, hit)
    local v = tkey and b.names[tkey] and Unit(b, guid) or nil
    if v then
        local cut = over > 0 and amount - over or amount
        local got = cut
        if b.limit then
            got = math.max(0, math.min(cut, v.hp - b.limit))
            v.hp = v.hp - cut
            if not v.done and v.hp <= b.limit then v.done = true end
        end
        local phase = b.def.phase
        local held = v.capAt ~= nil and not v.freeAt
            and (not phase or (s.track ~= nil and s.track.key == phase))
        if p then
            Credit(b.full, who, key, v.wave, amount, hit)
            if b.limit and got > 0 then Credit(b.hp50, who, key, v.wave, got, hit) end
            if held and got > 0 then Credit(b, who, key, v.wave, got, hit) end
        end
    end
    if p and own and not dot and s.captor then
        Captor(s, p, ts, guid, key, amount, v ~= nil and v.done and v.captive == who
            and v.freeAt ~= nil and ts >= v.freeAt)
    end
end
local function UsefulEnd(s)
    local b = s.useful
    if not b then return end
    for k = 1, s.captor and #s.players or 0 do
        if s.players[k].capT then Caught(s, s.players[k]) end
    end
    local heroic = b.heroic == true
    if heroic and b.bound then
        b.rule = "hold"
    else
        local f = (heroic and b.limit) and b.hp50 or b.full
        b.total, b.by, b.split, b.waves, b.ab = f.total, f.by, f.split, f.waves, f.ab
        b.rule = f == b.hp50 and "hp" or "full"
    end
    b.full.ab, b.hp50.ab = nil, nil
    if b.rule == "full" then
        b.normal = true
        b.label = b.def.plain
    end
    if heroic and b.limit then return end
    local i = s.captor
    for k = 1, i and #s.players or 0 do
        local st = s.players[k].badges[i]
        st.n, st.times, st.hits, st.amount = 0, {}, 0, 0
    end
    if i then s.icons[i] = nil end
end
Acc.RIDE_BOUNCE = RIDE_BOUNCE
Acc.SWING_KEY = SWING_KEY
Acc.BadgeSets = BadgeSets
Acc.AppliedHit = AppliedHit
Acc.Keys = Keys
Acc.Ab = Ab
Acc.Color = Color
Acc.AbKey = AbKey
Acc.AbTrim = AbTrim
Acc.DamageTo = DamageTo
Acc.Bounce = Bounce
Acc.HealTo = HealTo
Acc.Guard = Guard
Acc.Hurt = Hurt
Acc.Peak = Peak
Acc.EnemyCast = EnemyCast
Acc.Kicked = Kicked
Acc.Cured = Cured
Acc.UsefulWatch = UsefulWatch
Acc.Captive = Captive
Acc.UsefulHit = UsefulHit
Acc.UsefulEnd = UsefulEnd
