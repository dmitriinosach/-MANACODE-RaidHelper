local _, ns = ...
local BLAST_WIN = 1
local OFF_SLACK = 0.5
local HIT = { SPELL_DAMAGE = true, SPELL_MISSED = true }
local Caught = {}
ns.Caught = Caught
function Caught.Begin(s, fight)
    local st
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "caught" then
            st = st or { s = s, from = fight.from, to = fight.to, defs = {}, spells = {}, on = {}, blasts = {} }
            local d = { i = i, sk = ns.SpellKey(bd.spell), ak = ns.SpellKey(bd.aura) }
            st.defs[#st.defs + 1] = d
            st.spells[d.sk], st.spells[d.ak] = true, true
            st.on[d.ak] = st.on[d.ak] or {}
            st.blasts[d.sk] = st.blasts[d.sk] or {}
        end
    end
    return st
end
local function Carrier(st, ak, ts)
    local best, bestT = false, nil
    for name, a in pairs(st.on[ak]) do
        if a.t <= ts and (not a.off or a.off >= ts - OFF_SLACK) and (not bestT or a.t > bestT) then
            best, bestT = name, a.t
        end
    end
    return best
end
function Caught.Feed(st, ts, sub, srcGUID, dstName, sk, a1)
    local p = dstName and st.s.byName[dstName]
    if not p then return end
    local on = st.on[sk]
    if on then
        if sub == "SPELL_AURA_APPLIED" then
            on[dstName] = { t = ts }
        elseif sub == "SPELL_AURA_REMOVED" and on[dstName] then
            on[dstName].off = ts
        end
    end
    local list = st.blasts[sk]
    if not list or not HIT[sub] or ts < st.from or ts > st.to then return end
    local b
    for k = #list, 1, -1 do
        if list[k].src == srcGUID and ts - list[k].t <= BLAST_WIN then
            b = list[k]
            break
        end
    end
    if not b then
        local ak
        for k = 1, #st.defs do
            if st.defs[k].sk == sk then ak = st.defs[k].ak end
        end
        b = { t = ts, src = srcGUID, by = Carrier(st, ak, ts), hits = {} }
        list[#list + 1] = b
        st.s.spellIds[sk] = st.s.spellIds[sk] or tonumber(a1)
    end
    b.hits[#b.hits + 1] = { t = ts, who = dstName }
end
function Caught.Finish(st)
    local s = st.s
    local chase = s.dd and s.dd.chase
    for k = 1, #st.defs do
        local d = st.defs[k]
        local list = st.blasts[d.sk]
        for j = 1, #list do
            local b = list[j]
            local hurt = 0
            for h = 1, #b.hits do
                if b.hits[h].who ~= b.by then hurt = hurt + 1 end
                if chase then chase[#chase + 1] = { t = b.hits[h].t, who = b.hits[h].who, by = b.by } end
            end
            local p = b.by and s.byName[b.by]
            if p then
                local c = p.badges[d.i]
                c.n = c.n + 1
                c.times[c.n] = b.t - st.from
                c.hits = c.hits + hurt
                c.notes[c.n] = tostring(hurt)
                s.icons[d.i] = s.icons[d.i] or s.spellIds[d.sk]
                p.caught = p.caught or {}
                local mine = p.caught[d.sk] or {}
                p.caught[d.sk] = mine
                mine[#mine + 1] = b.t
            end
        end
    end
end
