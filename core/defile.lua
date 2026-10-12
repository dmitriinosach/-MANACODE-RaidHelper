local _, ns = ...
local tsort = table.sort
local concat = table.concat
local WIN = 2.5
local BEFORE = 0.5
local AFTER = 1.5
local SUMMON_GAP = 4
local FIRST_TICK = 1
local SUBS = { SPELL_CAST_START = true, SPELL_SUMMON = true, SPELL_DAMAGE = true, SPELL_MISSED = true,
               FW_BTGT = true }
local Defile = {}
ns.Defile = Defile
function Defile.Begin(s, fight)
    local st
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "defile" then
            st = st or { s = s, byName = s.byName, from = fight.from, to = fight.to, sk = ns.SpellKey(bd.spell),
                         npc = ns.NpcKeyOf(bd.npc), win = bd.win or WIN, subs = SUBS, casts = {}, pools = {} }
            if bd.part == "carry" then st.carry, st.hurt = i, bd.hurt or 1 else st.stood = i end
        end
    end
    return st
end
local function Unpooled(st, ts)
    for i = #st.casts, 1, -1 do
        local c = st.casts[i]
        if ts - c.t > SUMMON_GAP then return nil end
        if not c.ts then return c end
    end
    return nil
end
function Defile.Feed(st, ts, sub, sk, srcGUID, dstGUID, dstName, a1, a4)
    if sub == "FW_BTGT" then
        if not srcGUID then return end
        local who = dstName and st.byName[dstName] and dstName or nil
        local last = st.casts[#st.casts]
        if who and last and last.boss == srcGUID and not last.tgt and ts >= last.t - BEFORE and ts - last.t <= AFTER then
            last.tgt = who
        end
        return
    end
    if sk ~= st.sk or ts < st.from or ts > st.to then return end
    if sub == "SPELL_CAST_START" then
        if not ns.NpcKey(srcGUID) then return end
        st.casts[#st.casts + 1] = { t = ts, boss = srcGUID, hits = {} }
    elseif sub == "SPELL_SUMMON" then
        local c = dstGUID and Unpooled(st, ts)
        if c then
            c.ts = ts
            st.pools[dstGUID] = c
        end
    elseif srcGUID and dstName and st.byName[dstName] then
        local c = st.pools[srcGUID]
        if not c then
            if st.npc and ns.NpcKey(srcGUID) ~= st.npc then return end
            c = Unpooled(st, ts)
            if not c then return end
            c.ts = ts - FIRST_TICK
            st.pools[srcGUID] = c
        end
        c.hits[#c.hits + 1] = { t = ts, who = dstName, amount = sub == "SPELL_DAMAGE" and (tonumber(a4) or 0) or 0 }
        st.icon = st.icon or tonumber(a1)
    end
end
local function Carry(st, c)
    local seen, names, dmg, grow = {}, {}, 0, 0
    for k = 1, #c.hits do
        local h = c.hits[k]
        if h.t - c.ts <= st.win then
            grow = grow + 1
            if h.who ~= c.tgt then
                dmg = dmg + h.amount
                if not seen[h.who] then
                    seen[h.who] = true
                    names[#names + 1] = h.who
                end
            end
        end
    end
    if #names < st.hurt then return end
    tsort(names)
    local b = st.byName[c.tgt].badges[st.carry]
    local n = b.n + 1
    b.n, b.hits, b.amount = n, b.hits + #names, b.amount + dmg
    b.times[n], b.notes[n] = c.t - st.from, concat(names, ", ")
    b.cnt, b.grow, b.size = b.cnt or {}, b.grow or {}, b.size or {}
    b.cnt[n], b.grow[n], b.size[n] = #names, grow, #c.hits
    b.grade = "yellow"
    st.s.icons[st.carry] = st.s.icons[st.carry] or tonumber(st.s.badges[st.carry].id)
end
local function Stood(st, c)
    local ticks, dmg, at, order = {}, {}, {}, {}
    for k = 1, #c.hits do
        local h = c.hits[k]
        if h.t - c.ts > st.win then
            if not ticks[h.who] then
                order[#order + 1] = h.who
                ticks[h.who], dmg[h.who], at[h.who] = 0, 0, h.t
            end
            ticks[h.who] = ticks[h.who] + 1
            dmg[h.who] = dmg[h.who] + h.amount
        end
    end
    for k = 1, #order do
        local who = order[k]
        local b = st.byName[who].badges[st.stood]
        local n = b.n + 1
        b.n, b.hits, b.amount = n, b.hits + ticks[who], b.amount + dmg[who]
        b.times[n] = at[who] - st.from
        b.ticks, b.dmgs = b.ticks or {}, b.dmgs or {}
        b.ticks[n], b.dmgs[n] = ticks[who], dmg[who]
        if ticks[who] > 1 then b.grade = "red" elseif b.grade ~= "red" then b.grade = "yellow" end
        st.s.icons[st.stood] = st.s.icons[st.stood] or st.icon
    end
end
function Defile.Finish(st)
    for i = 1, #st.casts do
        local c = st.casts[i]
        if c.ts then
            if st.carry and c.tgt then Carry(st, c) end
            if st.stood then Stood(st, c) end
        end
    end
end
