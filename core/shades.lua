local _, ns = ...
local abs = math.abs
local huge = math.huge
local SAME = 0.05
local EX_WIN = 3
local EX_AURA = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_REMOVED = true }
local EX_HIT = { SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_CAST_SUCCESS = true }
local NONE = {}
local Shades = {}
ns.Shades = Shades
local function New(st, s, fight, def)
    if st then return st end
    return { s = s, byName = s.byName, from = fight.from, to = fight.to, npc = ns.NpcKeyOf(def.src),
             spell = ns.SpellKey(def.spell), summoned = 0, vic = {}, at = {}, order = {}, hitG = {}, hitW = {},
             hitA = {}, ex = {}, ev = {}, open = {}, exAuras = {}, exMoved = {} }
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
        if bd.kind == "chased" and ns.NpcKeyOf(bd.npc) == st.npc then
            st.chased = i
            local ex = bd.excuse
            if ex then
                st.exDef = ex
                st.exMc = ns.SpellKey(ex.mc)
                st.ex[st.exMc] = true
                for id, kind in pairs(ex.auras or NONE) do
                    st.ex[ns.SpellKey(id)] = true
                    st.exAuras[ns.SpellKey(id)] = kind
                end
                for id, kind in pairs(ex.moved or NONE) do
                    st.ex[ns.SpellKey(id)] = true
                    st.exMoved[ns.SpellKey(id)] = kind
                end
            end
        end
    end
    return st
end
local function Mark(st, guid, ts)
    if st.at[guid] then return end
    st.at[guid] = ts
    st.order[#st.order + 1] = guid
end
local function Excuse(st, ts, sub, srcName, dstName, sk, spell, mc)
    local list = st.ev[dstName]
    if not list then
        list = {}
        st.ev[dstName] = list
    end
    mc = mc or (srcName ~= nil and st.open[srcName .. "|" .. st.exMc] ~= nil)
    local kind = sk == st.exMc and "mc" or st.exAuras[sk]
    if kind and EX_AURA[sub] then
        local key = dstName .. "|" .. sk
        local cur = st.open[key]
        if sub == "SPELL_AURA_REMOVED" then
            if cur then
                cur.to = ts
                st.open[key] = nil
            end
        elseif not cur then
            cur = { t = ts, kind = kind, spell = spell, src = srcName, mc = mc or nil }
            list[#list + 1] = cur
            st.open[key] = cur
        end
        return
    end
    kind = st.exMoved[sk]
    if kind and EX_HIT[sub] then
        list[#list + 1] = { t = ts, to = ts, kind = kind, spell = spell, src = srcName, mc = mc or nil }
    end
end
function Shades.Feed(st, ts, sub, srcGUID, srcName, dstGUID, dstName, a1, a2, a4, mc)
    if ts < st.from or ts > st.to then return end
    local sk = ns.SpellOf(sub, a1)
    if sk and st.ex[sk] and dstName and st.byName[dstName] then
        Excuse(st, ts, sub, srcName, dstName, sk, a2, mc == true)
        return
    end
    if sub == "SPELL_SUMMON" then
        if ns.NpcKey(dstGUID) == st.npc then st.summoned = st.summoned + 1 end
        return
    end
    if ns.NpcKey(srcGUID) ~= st.npc or not srcGUID or not dstName or not st.byName[dstName] then return end
    if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
        if not st.vic[srcGUID] then
            st.vic[srcGUID] = dstName
            Mark(st, srcGUID, ts)
        end
    elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and sk == st.spell then
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
local function Why(st, vic, ts)
    local def = st.exDef
    if not def then return false end
    local win = def.sec or EX_WIN
    local best
    local list = st.ev[vic] or NONE
    for i = 1, #list do
        local e = list[i]
        local to = e.to or huge
        if e.t <= ts + SAME and to >= ts - win and (not best or e.t > best.t) then best = e end
    end
    if not best then return false end
    local to = best.to or huge
    return { k = best.kind, sp = best.spell, src = best.kind ~= "mc" and best.src or nil, mc = best.mc,
             at = best.t - st.from, gap = ts - best.t, left = to < ts - SAME and ts - to or nil }
end
local function Caught(st, vic, t, cnt, dmg, hurt, why)
    local c = st.byName[vic].badges[st.chased]
    for i = 1, #hurt do
        local seen = false
        c.blasted = c.blasted or {}
        for j = 1, #c.blasted do seen = seen or c.blasted[j] == hurt[i] end
        if not seen then c.blasted[#c.blasted + 1] = hurt[i] end
    end
    for k = 1, c.n do
        if abs(c.times[k] - t) <= SAME then
            c.cnt, c.dmgs = c.cnt or {}, c.dmgs or {}
            c.cnt[k], c.dmgs[k] = cnt, dmg
            if st.exDef then
                c.why = c.why or {}
                for j = #c.why + 1, c.n do c.why[j] = false end
                c.why[k] = why
            end
            return
        end
    end
end
local function Grade(st)
    for _, p in pairs(st.byName) do
        local c = p.badges[st.chased]
        if c and c.n > 0 and c.why then
            local all = true
            for k = 1, c.n do all = all and c.why[k] ~= nil and c.why[k] ~= false end
            if all then c.grade = "green" end
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
        local cnt, dmg, hurt = 0, 0, {}
        for h = 1, #st.hitG do
            if st.hitG[h] == g then
                dmg = dmg + st.hitA[h]
                if st.hitW[h] ~= vic then
                    cnt = cnt + 1
                    hurt[#hurt + 1] = st.hitW[h]
                    if st.blast then Blasted(st, st.hitW[h], t, vic, st.hitA[h]) end
                end
            end
        end
        if vic and st.chased then Caught(st, vic, t, cnt, dmg, hurt, Why(st, vic, st.at[g])) end
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
    if st.chased and st.exDef then Grade(st) end
end
function Shades.Excused(s, p, npc, t)
    local want = ns.NpcKeyOf(npc)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        local c = bd.kind == "chased" and ns.NpcKeyOf(bd.npc) == want and p.badges[i]
        if c and c.why then
            for k = 1, c.n do
                if c.why[k] and abs(c.times[k] - t) <= SAME then return c.why[k] end
            end
        end
    end
    return nil
end
