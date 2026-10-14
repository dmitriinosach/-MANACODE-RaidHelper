local _, ns = ...
local band = bit.band
local max = math.max
local find = string.find
local tsort = table.sort
local F_PLAYER = ns.F.PLAYER
local F_BY_PLAYER = ns.F.BY_PLAYER
local F_HOSTILE = ns.F.HOSTILE
local FEIGN = 5384
local FEIGN_WINDOW = 2
local COMBAT_GAP = 5
local PREPOT = 5
local MINE = { potion = true, other = true, stone = true }
local AB_KEEP = 8
local PET = "p|"
local OWN = "s|"
local RaidPart = {}
ns.RaidPart = RaidPart
function RaidPart.New(fight, pets, known)
    return { rows = {}, use = {}, got = {}, owners = {}, pets = pets, fight = fight,
             from = fight and fight.from or nil, to = fight and fight.to or nil,
             fightAt = 0, total = 0, feign = {}, died = {}, ivs = {}, known = known or (fight and fight.players) or {},
             shields = not fight and ns.Absorbs.New() or nil }
end
function RaidPart.Interval(st, upto)
    local all = {}
    st.ivs[#st.ivs + 1] = { to = upto, all = all }
    st.cutBy = all
end
local function Row(st, name)
    local r = st.rows[name]
    if not r then
        r = { all = 0, boss = 0, heal = 0, ab = {}, hb = {} }
        st.rows[name] = r
    end
    return r
end
RaidPart.Row = Row
local IsBoss = ns.IsBossOf
local function Ab(map, key, id)
    local e = map[key]
    if not e then
        e = { i = id, a = 0 }
        map[key] = e
    end
    return e
end
local function AddAb(r, pet, swing, id, spell, amount, boss)
    local melee = ns.Totals.MELEE
    local e
    if pet then
        e = Ab(r.ab, PET .. pet, swing and melee or tonumber(id))
    elseif swing then
        e = Ab(r.ab, OWN .. ns.Totals.MELEE_KEY, melee)
    else
        e = Ab(r.ab, OWN .. (type(spell) == "string" and spell or tostring(id)), tonumber(id))
    end
    e.a = e.a + amount
    if boss then e.b = (e.b or 0) + amount end
end
RaidPart.PET, RaidPart.OWN = PET, OWN
local function Use(st, name, c, spell)
    local u = st.use[c.item]
    if not u then
        u = { item = c.item, id = c.id, cat = c.cat, free = c.free, spell = spell, by = {} }
        st.use[c.item] = u
    end
    u.by[name] = (u.by[name] or 0) + 1
end
local function IsPlayer(flags)
    return flags ~= nil and band(flags, F_PLAYER) > 0
end
function RaidPart.Hit(st, who, dstGUID, dstFlags, amount, pet, swing, id, spell)
    if amount <= 0 or IsPlayer(dstFlags) then return end
    local r = Row(st, who)
    r.all = r.all + amount
    local boss = IsBoss(st.fight, dstGUID)
    if boss then r.boss = r.boss + amount end
    AddAb(r, pet, swing, id, spell, amount, boss)
end
local function Which(sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    if sub == "SPELL_AURA_APPLIED" then
        local c = ns.consumeAura[tonumber(a1) or 0]
        if c and dstName and IsPlayer(dstFlags) and (not srcName or srcName == dstName) then
            return dstName, c, tonumber(a1)
        end
    elseif sub == "SPELL_CAST_SUCCESS" then
        local c = ns.consumeCast[tonumber(a1) or 0]
        if c and who and srcName == who then return who, c, tonumber(a1) end
    elseif sub == "SPELL_CREATE" then
        local c = ns.consumeCreate[tonumber(a1) or 0]
        if c and srcName and IsPlayer(srcFlags) then return srcName, c, nil end
    elseif sub == "ENCHANT_APPLIED" then
        local c = ns.consumeEnchant[tonumber(a2) or 0]
        if c and srcName and IsPlayer(srcFlags) then return srcName, c, nil end
    end
    return nil, nil, nil
end
function RaidPart.Consume(st, sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    local name, c, spell = Which(sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    if name then Use(st, name, c, spell) end
end
function RaidPart.Mine(byName, fight, ts, sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    if ts < fight.from - PREPOT or ts > fight.to then return end
    local name, c, spell = Which(sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    local p = name and byName[name]
    if not (p and c.id and MINE[c.cat]) then return end
    local list = p.cons
    if not list then
        list = {}
        p.cons = list
    end
    list[#list + 1] = { id = c.id, item = c.item, spell = spell, t = ts - fight.from }
end
function RaidPart.Got(st, id, name, ts)
    if not id or not name then return end
    local g = st.got[id]
    if not g then
        g = {}
        st.got[id] = g
    end
    if not g[name] then g[name] = ts end
end
function RaidPart.Feed(st, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5, a6, a7, a9)
    if sub == "SPELL_SUMMON" then
        ns.NoteOwner(st.owners, sub, srcFlags, srcName, dstGUID)
        return
    end
    local f = st.fight
    if f and (ts < st.from or ts > st.to) then return end
    local who = ns.WhoOf(srcFlags, srcGUID, srcName, st.owners, st.pets)
    local dst = dstName ~= nil and (IsPlayer(dstFlags) or st.known[dstName] ~= nil)
    if find(sub, "_DAMAGE", 1, true) then
        local swing = find(sub, "SWING", 1, true) ~= nil
        if who and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 and sub ~= "ENVIRONMENTAL_DAMAGE" then
            local amount = (tonumber(swing and a1 or a4) or 0) - max(0, tonumber(swing and a2 or a5) or 0)
            if amount > 0 then
                local r = Row(st, who)
                r.all = r.all + amount
                local boss = f ~= nil and IsBoss(f, dstGUID)
                AddAb(r, srcName ~= who and srcName or nil, swing, a1, a2, amount, boss)
                if f then
                    if boss then r.boss = r.boss + amount end
                else
                    st.total = st.total + amount
                    local cut = st.cutBy
                    if cut then cut[who] = (cut[who] or 0) + amount end
                end
            end
            st.fightAt = ts
        end
        if dst then
            local env = sub == "ENVIRONMENTAL_DAMAGE"
            if not env and not who and srcFlags and band(srcFlags, F_HOSTILE) > 0 then st.fightAt = ts end
            local absorbed = st.shields and (tonumber(swing and a6 or env and a7 or a9) or 0) or 0
            if absorbed > 0 then
                ns.Absorbs.Hit(st.shields, ts, dstName, tonumber(swing and 1 or env and a4 or a3) or 1,
                    tonumber(swing and a1 or env and a2 or a4) or 0, absorbed)
            end
        end
    elseif find(sub, "_MISSED", 1, true) then
        local swing = find(sub, "SWING", 1, true) ~= nil
        if dst and st.shields and (swing and a1 or a4) == "ABSORB" then
            local absorbed = tonumber(swing and a2 or a5) or 0
            if absorbed > 0 then ns.Absorbs.Hit(st.shields, ts, dstName, tonumber(swing and 1 or a3) or 1, 0, absorbed) end
        end
    elseif find(sub, "_HEAL", 1, true) then
        if dst and srcName and st.shields then ns.Absorbs.Heal(st.shields, ts, srcName, dstName, tonumber(a4) or 0) end
        if who and dstFlags and band(dstFlags, F_HOSTILE) == 0 and (f or ts - st.fightAt <= COMBAT_GAP) then
            local eff = (tonumber(a4) or 0) - (tonumber(a5) or 0)
            if eff > 0 then
                local r = Row(st, who)
                r.heal = r.heal + eff
                local e = Ab(r.hb, OWN .. (type(a2) == "string" and a2 or tostring(a1)), tonumber(a1))
                e.a = e.a + eff
            end
        end
    elseif sub == "FW_ACH" then
        RaidPart.Got(st, tonumber(a1), srcName, ts)
    elseif sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CREATE" or sub == "ENCHANT_APPLIED"
        or sub == "SPELL_AURA_APPLIED" then
        RaidPart.Consume(st, sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
        if sub == "SPELL_CAST_SUCCESS" and tonumber(a1) == FEIGN and srcName and IsPlayer(srcFlags) then
            st.feign[srcName] = ts
        end
    elseif sub == "UNIT_DIED" then
        if dst and not f and not (st.feign[dstName] and ts - st.feign[dstName] <= FEIGN_WINDOW) then
            st.died[#st.died + 1] = { who = dstName, t = ts }
        end
    end
    if dst and st.shields and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_REMOVED")
        and ns.Absorbs.Known(tonumber(a1)) then
        local caster = (srcName and IsPlayer(srcFlags)) and srcName
            or (srcGUID and (st.owners[srcGUID] or st.pets[srcGUID]))
        if caster then
            ns.Absorbs.Aura(st.shields, ts, sub == "SPELL_AURA_REMOVED", caster, dstName, tonumber(a1),
                type(a2) == "string" and a2 or nil)
        end
    end
end
local function ByA(a, b)
    if a.e.a ~= b.e.a then return a.e.a > b.e.a end
    return a.k < b.k
end
local function ByB(a, b)
    local x, y = a.e.b or 0, b.e.b or 0
    if x ~= y then return x > y end
    return a.k < b.k
end
local function Trim(map, boss)
    local list = {}
    for k, e in pairs(map) do list[#list + 1] = { k = k, e = e } end
    if #list <= AB_KEEP then return map end
    local keep = {}
    tsort(list, ByA)
    for n = 1, AB_KEEP do keep[list[n].k] = list[n].e end
    if boss then
        tsort(list, ByB)
        for n = 1, AB_KEEP do
            if (list[n].e.b or 0) > 0 then keep[list[n].k] = list[n].e end
        end
    end
    return keep
end
function RaidPart.Close(st, players)
    local m = st.shields
    for src, amount in pairs(m and m.by or {}) do
        if amount > 0 then
            local r = Row(st, src)
            r.heal = r.heal + amount
            for id, c in pairs(m.spells[src] or {}) do
                local e = Ab(r.hb, OWN .. ns.Absorbs.Name(m, id), id)
                e.a = e.a + c.a
            end
        end
    end
    for i = 1, players and #players or 0 do
        local p = players[i]
        if p.heal > 0 then
            local r = Row(st, p.name)
            r.heal = p.heal
            local hb = {}
            for key, e in pairs(p.healBy or {}) do
                if e.a > 0 then hb[OWN .. key] = { i = e.id, a = e.a } end
            end
            r.hb = hb
        end
    end
    for _, r in pairs(st.rows) do
        r.ab = Trim(r.ab, true)
        r.hb = Trim(r.hb, false)
    end
    local piece = { rows = st.rows, use = st.use, got = st.got }
    if not st.fight then piece.total, piece.ivs = st.total, st.ivs end
    return piece
end
