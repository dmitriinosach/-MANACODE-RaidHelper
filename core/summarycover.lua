local _, ns = ...
local HUGE = math.huge
local tsort = table.sort
local SC = {}
ns.SummaryCover = SC
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_CAST_SUCCESS = true,
               SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true }
function SC.Begin(s, fight, def)
    local list = def.cover
    local C = ns.covers
    if not (list and C) then return nil end
    local st = { s = s, from = fight.from, to = fight.to, defs = {}, keys = {}, own = {}, cast = C.cast or {},
                 spans = {}, hits = {}, subs = SUBS }
    for k = 1, #list do
        local bd = { kind = "cover", id = list[k].id, tip = list[k].tip, rule = list[k].rule, cover = list[k] }
        local i = #s.badges + 1
        s.badges[i] = bd
        for j = 1, #s.players do
            s.players[j].badges[i] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
        end
        st.defs[k] = { def = list[k], key = ns.SpellKey(list[k].spells[1]), i = i }
        for q = 1, #list[k].spells do st.keys[ns.SpellKey(list[k].spells[q])] = k end
    end
    for _, ids in pairs(C.own) do
        for q = 1, #ids do st.own[ns.SpellKey(ids[q])] = true end
    end
    for q = 1, #(C.ext or {}) do st.own[ns.SpellKey(C.ext[q])] = true end
    return st
end
local function Spans(st, name)
    local l = st.spans[name]
    if not l then
        l = {}
        st.spans[name] = l
    end
    return l
end
function SC.Feed(st, ts, sub, srcName, dstName, a1, a4)
    if ts > st.to + 10 then return end
    local id = tonumber(a1)
    local key = id and ns.SpellKey(id)
    if not key then return end
    local by = st.s.byName
    local d = st.keys[key]
    if d then
        if not (dstName and by[dstName]) then return end
        local l = st.hits[dstName]
        if not l then
            l = {}
            st.hits[dstName] = l
        end
        local h = l[#l]
        local open = h and not h.te
        if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_CAST_SUCCESS" then
            if not (open and ts - h.t0 < 1) then
                if open then h.te = math.min(ts, h.t0 + (st.defs[h.d].def.lead or 5)) end
                l[#l + 1] = { t0 = ts, dmg = 0, d = d }
            end
        elseif (sub == "SPELL_PERIODIC_DAMAGE" or sub == "SPELL_PERIODIC_MISSED") and h and not h.te then
            h.te, h.dmg = ts, sub == "SPELL_PERIODIC_DAMAGE" and (tonumber(a4) or 0) or 0
        elseif sub == "SPELL_AURA_REMOVED" and h and not h.te then
            h.te, h.gone = ts, true
        end
        return
    end
    if not st.own[key] and not st.cast[id] then return end
    if sub == "SPELL_CAST_SUCCESS" then
        local dur = st.cast[id]
        if dur and srcName and by[srcName] then
            local l = Spans(st, srcName)
            l[#l + 1] = { a = ts, b = ts + dur, id = id }
        end
        return
    end
    if not (dstName and by[dstName]) then return end
    local l = Spans(st, dstName)
    if sub == "SPELL_AURA_APPLIED" then
        l[#l + 1] = { a = ts, b = HUGE, id = id }
    elseif sub == "SPELL_AURA_REMOVED" then
        for q = #l, 1, -1 do
            if l[q].b == HUGE and ns.SpellKey(l[q].id) == key then
                l[q].b = ts
                return
            end
        end
        l[#l + 1] = { a = -HUGE, b = ts, id = id }
    end
end
local function Covered(list, te, late)
    for q = 1, list and #list or 0 do
        local sp = list[q]
        if sp.a <= te + late and sp.b >= te then return sp.id end
    end
    return nil
end
local function Ready(p, te, noReset)
    local DG = ns.DeathGrade
    local ids = p.class and ns.covers.own[p.class]
    local out = {}
    if not (DG and ids) then return out end
    local seen = DG.Seen(p, te)
    for q = 1, #ids do
        local id = ids[q]
        if seen.has[id] and DG.Left(seen, id, te, noReset) == 0 then out[#out + 1] = id end
    end
    tsort(out)
    return out
end
local function DiedIn(p, a, b)
    for q = 1, #(p.deathInfo or {}) do
        local d = p.deathInfo[q]
        if d.t >= a and d.t <= b and not d.tail then return true end
    end
    return false
end
function SC.Finish(st)
    local s = st.s
    local late = ns.covers.late or 2
    local noReset = ns.DeathGrade and ns.DeathGrade.NoReset and ns.DeathGrade.NoReset(s) or {}
    for name, list in pairs(st.hits) do
        local p = s.byName[name]
        for q = 1, #list do
            local h = list[q]
            local dd = st.defs[h.d]
            local te = h.te or st.to
            if h.t0 >= s.lead and h.t0 <= st.to and not Covered(st.spans[name], te, late) then
                local ready = Ready(p, te, noReset[name])
                if #ready > 0 then
                    local c = p.badges[dd.i]
                    local died = DiedIn(p, h.t0, te + (dd.def.after or 5))
                    c.n = c.n + 1
                    c.times[c.n] = h.t0 - st.from
                    c.eps = c.eps or {}
                    c.eps[c.n] = { te = te - st.from, dmg = h.dmg, ready = ready, died = died or nil }
                    c.grades = c.grades or {}
                    c.grades[c.n] = died and "red" or "yellow"
                    if died or c.grade ~= "red" then c.grade = died and "red" or "yellow" end
                    s.icons[dd.i] = s.icons[dd.i] or dd.def.id
                end
            end
        end
    end
end
