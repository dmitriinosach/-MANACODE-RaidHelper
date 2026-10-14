local _, ns = ...
local tsort = table.sort
local concat = table.concat
local floor = math.floor
local SEC = 3
local AGE = 2
local Mech = {}
ns.LichMech = Mech
function Mech.Begin(s, fight)
    local st
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "frenzy" or bd.kind == "spirit" then
            st = st or { s = s, byName = s.byName, from = fight.from, to = fight.to, npcs = {}, fz = {}, sp = {},
                         sec = SEC, age = AGE, open = {}, list = {}, soothers = {}, hold = {}, booms = {},
                         boomList = {} }
            local npc = ns.NpcKeyOf(bd.npc)
            if npc then st.npcs[npc] = true end
            if bd.kind == "frenzy" then
                st.frenzy, st.fzNpc, st.sec = i, npc, bd.sec or SEC
                ns.SpellSet(bd.spells, st.fz)
            else
                st.spirit, st.spNpc, st.age = i, npc, bd.age or AGE
                ns.SpellSet(bd.spells, st.sp)
            end
        end
    end
    if not st then return nil end
    for i = 1, #s.extra do
        if s.extra[i].def.kind == "frenzy" then st.stat = s.extra[i] end
    end
    return st
end
local function Frenzy(st, ts, sub, sk, srcKey, dstKey, srcGUID, srcName, dstGUID, dstName, a1, a4)
    if dstKey ~= st.fzNpc or not dstGUID then return end
    if sub == "SPELL_AURA_APPLIED" and st.fz[sk] then
        local f = { g = dstGUID, t = ts }
        st.open[dstGUID] = f
        st.list[#st.list + 1] = f
    elseif sub == "SPELL_AURA_REMOVED" and st.fz[sk] then
        local f = st.open[dstGUID]
        if f then f.to, st.open[dstGUID] = ts, nil end
    elseif sub == "SPELL_DISPEL" and st.fz[ns.SpellKey(a4) or 0] then
        if srcName and st.byName[srcName] then st.soothers[srcName] = (st.soothers[srcName] or 0) + 1 end
        local f = st.open[dstGUID]
        if f and not f.disp then f.disp = ts end
        st.icon = st.icon or tonumber(a1)
    elseif sub == "UNIT_DIED" then
        local f = st.open[dstGUID]
        if f then f.to, st.open[dstGUID] = ts, nil end
    end
end
local function Spirit(st, ts, sub, sk, srcGUID, dstName, a4)
    if not srcGUID then return end
    if sub == "FW_THR" then
        if dstName and st.byName[dstName] then st.hold[srcGUID] = { who = dstName, t = ts } end
        return
    end
    if not st.sp[sk] or not dstName or not st.byName[dstName] then return end
    if sub ~= "SPELL_DAMAGE" and sub ~= "SPELL_MISSED" then return end
    local b = st.booms[srcGUID]
    if not b then
        local h = st.hold[srcGUID]
        b = { t = ts, who = h and h.who, age = h and ts - h.t, hurt = {}, order = {} }
        st.booms[srcGUID] = b
        st.boomList[#st.boomList + 1] = b
    end
    if not b.hurt[dstName] then
        b.order[#b.order + 1] = dstName
        b.hurt[dstName] = 0
    end
    if sub == "SPELL_DAMAGE" then b.hurt[dstName] = b.hurt[dstName] + (tonumber(a4) or 0) end
end
function Mech.Feed(st, ts, sub, sk, srcKey, dstKey, srcGUID, srcName, dstGUID, dstName, a1, a4)
    if ts < st.from or ts > st.to then return end
    if st.frenzy then Frenzy(st, ts, sub, sk, srcKey, dstKey, srcGUID, srcName, dstGUID, dstName, a1, a4) end
    if st.spirit and srcKey == st.spNpc then Spirit(st, ts, sub, sk, srcGUID, dstName, a4) end
end
local function FrenzyEnd(st)
    local names = {}
    for name in pairs(st.soothers) do names[#names + 1] = name end
    tsort(names)
    for i = 1, #st.list do
        local f = st.list[i]
        local stop = f.disp or f.to or st.to
        local held = stop - f.t
        if held > st.sec and (f.to or st.to) - f.t > st.sec then
            if st.stat then st.stat.times[#st.stat.times + 1] = f.t end
            for k = 1, #names do
                local b = st.byName[names[k]].badges[st.frenzy]
                local n = b.n + 1
                b.n, b.times[n], b.notes[n] = n, f.t - st.from, tostring(floor(held * 10 + 0.5) / 10)
                b.grade = "yellow"
                st.s.icons[st.frenzy] = st.s.icons[st.frenzy] or tonumber(st.s.badges[st.frenzy].id) or st.icon
            end
        end
    end
end
local function SpiritEnd(st)
    for i = 1, #st.boomList do
        local b = st.boomList[i]
        local who = b.who
        if who and b.age and b.age <= st.age and b.hurt[who] then
            local others, dmg = {}, 0
            for k = 1, #b.order do
                local name = b.order[k]
                if name ~= who then
                    others[#others + 1] = name
                    dmg = dmg + b.hurt[name]
                end
            end
            if #others > 0 then
                tsort(others)
                local c = st.byName[who].badges[st.spirit]
                local n = c.n + 1
                c.n, c.hits, c.amount = n, c.hits + #others, c.amount + dmg
                c.times[n], c.notes[n] = b.t - st.from, concat(others, ", ")
                c.cnt, c.dmgs = c.cnt or {}, c.dmgs or {}
                c.cnt[n], c.dmgs[n] = #others, dmg
                c.grade = "yellow"
                st.s.icons[st.spirit] = st.s.icons[st.spirit] or tonumber(st.s.badges[st.spirit].id)
            end
        end
    end
end
function Mech.Finish(st)
    if st.frenzy then FrenzyEnd(st) end
    if st.spirit then SpiritEnd(st) end
end
