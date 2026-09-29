local _, ns = ...
local abs = math.abs
local SAME = 0.05
local Shades = {}
ns.Shades = Shades
local function New(st, s, fight, def)
    if st then return st end
    return { s = s, byName = s.byName, from = fight.from, to = fight.to, npc = def.src, spell = def.spell,
             summoned = 0, vic = {}, at = {}, order = {}, hitG = {}, hitW = {}, hitA = {} }
end
function Shades.Begin(s, fight)
    local st
    for i = 1, #s.badges do
        if s.badges[i].kind == "blast" then
            st = New(st, s, fight, s.badges[i])
            st.blast = i
        end
    end
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "shades" then
            st = New(st, s, fight, b.def)
            st.block = b
            b.summoned, b.caught, b.hit = 0, 0, 0
            b.hits, b.at, b.vic, b.cnt, b.dmg = {}, {}, {}, {}, {}
        end
    end
    if not st then return nil end
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "chased" and bd.npc == st.npc then st.chased = i end
    end
    return st
end
local function Mark(st, guid, ts)
    if st.at[guid] then return end
    st.at[guid] = ts
    st.order[#st.order + 1] = guid
end
function Shades.Feed(st, ts, sub, srcGUID, srcName, dstName, a1, a2, a4)
    if ts < st.from or ts > st.to then return end
    if sub == "SPELL_SUMMON" then
        if dstName == st.npc then st.summoned = st.summoned + 1 end
        return
    end
    if srcName ~= st.npc or not srcGUID or not dstName or not st.byName[dstName] then return end
    if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
        if not st.vic[srcGUID] then
            st.vic[srcGUID] = dstName
            Mark(st, srcGUID, ts)
        end
    elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and a2 == st.spell then
        Mark(st, srcGUID, ts)
        local n = #st.hitG + 1
        st.hitG[n], st.hitW[n] = srcGUID, dstName
        st.hitA[n] = sub == "SPELL_DAMAGE" and (tonumber(a4) or 0) or 0
        st.icon = st.icon or tonumber(a1)
    end
end
local function Blasted(st, who, t, vic, amount)
    local i = st.blast
    local c = st.byName[who].badges[i]
    local n = c.n + 1
    c.n = n
    c.hits = c.hits + 1
    c.amount = c.amount + amount
    c.times[n], c.notes[n] = t, vic or "?"
    c.dmgs = c.dmgs or {}
    c.dmgs[n] = amount
    st.s.icons[i] = st.s.icons[i] or st.icon
end
local function Caught(st, vic, t, cnt, dmg)
    local c = st.byName[vic].badges[st.chased]
    for k = 1, c.n do
        if abs(c.times[k] - t) <= SAME then
            c.cnt, c.dmgs = c.cnt or {}, c.dmgs or {}
            c.cnt[k], c.dmgs[k] = cnt, dmg
            return
        end
    end
end
function Shades.Finish(st)
    local b = st.block
    if b then b.summoned = st.summoned end
    for k = 1, #st.order do
        local g = st.order[k]
        local vic = st.vic[g] or false
        local t = st.at[g] - st.from
        local cnt, dmg = 0, 0
        for h = 1, #st.hitG do
            if st.hitG[h] == g then
                dmg = dmg + st.hitA[h]
                if st.hitW[h] ~= vic then
                    cnt = cnt + 1
                    if st.blast then Blasted(st, st.hitW[h], t, vic, st.hitA[h]) end
                end
            end
        end
        if vic and st.chased then Caught(st, vic, t, cnt, dmg) end
        if b then
            b.at[k], b.vic[k], b.cnt[k], b.dmg[k] = t, vic, cnt, dmg
            b.total = b.total + dmg
            b.hit = b.hit + cnt
            if vic then
                b.caught = b.caught + 1
                b.by[vic] = (b.by[vic] or 0) + dmg
                b.hits[vic] = (b.hits[vic] or 0) + 1
            end
        end
    end
end
