local _, ns = ...
local band = bit.band
local max = math.max
local find = string.find
local F_PLAYER = 0x400
local F_BY_PLAYER = 0x100
local F_HOSTILE = 0x40
local FEIGN = 5384
local FEIGN_WINDOW = 2
local COMBAT_GAP = 5
local RaidPart = {}
ns.RaidPart = RaidPart
function RaidPart.New(fight, pets, hp, known)
    return { rows = {}, use = {}, got = {}, owners = {}, pets = pets, fight = fight,
             from = fight and fight.from or nil, to = fight and fight.to or nil,
             fightAt = 0, total = 0, feign = {}, died = {}, ivs = {}, known = known or (fight and fight.players) or {},
             shields = not fight and ns.Absorbs.New(hp) or nil }
end
function RaidPart.Interval(st, upto)
    local all = {}
    st.ivs[#st.ivs + 1] = { to = upto, all = all }
    st.cutBy = all
end
local function Row(st, name)
    local r = st.rows[name]
    if not r then
        r = { all = 0, boss = 0, heal = 0 }
        st.rows[name] = r
    end
    return r
end
RaidPart.Row = Row
local function IsBoss(fight, guid)
    return ns.IsBossOf(fight, guid)
end
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
function RaidPart.Hit(st, who, dstGUID, dstFlags, amount)
    if amount <= 0 or IsPlayer(dstFlags) then return end
    local r = Row(st, who)
    r.all = r.all + amount
    if IsBoss(st.fight, dstGUID) then r.boss = r.boss + amount end
end
function RaidPart.Consume(st, sub, who, srcName, srcFlags, a1, dstName, dstFlags, a2)
    if sub == "SPELL_AURA_APPLIED" then
        local c = ns.consumeAura[tonumber(a1) or 0]
        if c and dstName and IsPlayer(dstFlags) and (not srcName or srcName == dstName) then
            Use(st, dstName, c, tonumber(a1))
        end
    elseif sub == "SPELL_CAST_SUCCESS" then
        local c = ns.consumeCast[tonumber(a1) or 0]
        if c and who and srcName == who then Use(st, who, c, tonumber(a1)) end
    elseif sub == "SPELL_CREATE" then
        local c = ns.consumeCreate[tonumber(a1) or 0]
        if c and srcName and IsPlayer(srcFlags) then Use(st, srcName, c) end
    elseif sub == "ENCHANT_APPLIED" then
        local c = ns.consumeEnchant[tonumber(a2) or 0]
        if c and srcName and IsPlayer(srcFlags) then Use(st, srcName, c) end
    end
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
        if IsPlayer(srcFlags) and dstGUID then st.owners[dstGUID] = srcName end
        return
    end
    local f = st.fight
    if f and (ts < st.from or ts > st.to) then return end
    local who
    if srcFlags and band(srcFlags, F_BY_PLAYER) > 0 then
        if band(srcFlags, F_PLAYER) > 0 then
            who = srcName
        elseif srcGUID then
            who = st.owners[srcGUID] or st.pets[srcGUID]
        end
    end
    local dst = dstName ~= nil and (IsPlayer(dstFlags) or st.known[dstName] ~= nil)
    if find(sub, "_DAMAGE", 1, true) then
        local swing = find(sub, "SWING", 1, true) ~= nil
        if who and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 and sub ~= "ENVIRONMENTAL_DAMAGE" then
            local amount = (tonumber(swing and a1 or a4) or 0) - max(0, tonumber(swing and a2 or a5) or 0)
            if amount > 0 then
                local r = Row(st, who)
                r.all = r.all + amount
                if f then
                    if IsBoss(f, dstGUID) then r.boss = r.boss + amount end
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
function RaidPart.Close(st, players)
    for src, amount in pairs(st.shields and st.shields.by or {}) do
        if amount > 0 then
            local r = Row(st, src)
            r.heal = r.heal + amount
        end
    end
    for i = 1, players and #players or 0 do
        local p = players[i]
        if p.heal > 0 then Row(st, p.name).heal = p.heal end
    end
    local piece = { rows = st.rows, use = st.use, got = st.got }
    if not st.fight then piece.total, piece.ivs = st.total, st.ivs end
    return piece
end
