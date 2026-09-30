local _, ns = ...
local RF = {}
ns.RFury = RF
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true, UNIT_DIED = true,
               FW_BUFFSNAP = true }
local AURA_KIND = { SPELL_AURA_APPLIED = "app", SPELL_AURA_REMOVED = "rem", SPELL_AURA_REFRESH = "re" }
local ALIVE = { SPELL_CAST_SUCCESS = true, SPELL_CAST_START = true }
local STATE = { app = true, re = true, son = true, rem = false, soff = false }
local BEFORE = { app = false, re = true, son = true, rem = true, soff = false }
local SNAP = { son = true, soff = true }
function RF.Begin(s, fight)
    local data = ns.actions and ns.actions.rfury
    if not data then return nil end
    local units, any = {}, false
    for i = 1, #s.players do
        local p = s.players[i]
        if p.class == data.class then
            units[p.name] = { mt = {}, mk = {}, listed = false }
            any = true
        end
    end
    if not any then return nil end
    local st = { s = s, from = fight.from, to = fight.to, id = data.id, aura = data.aura, red = data.red,
                 minGap = data.minGap, units = units, dead = {}, subs = SUBS }
    for k = 1, #data.badges do
        local bd = data.badges[k]
        local i = #s.badges + 1
        s.badges[i] = bd
        for j = 1, #s.players do
            s.players[j].badges[i] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
        end
        st[bd.kind] = i
    end
    return st
end
local function Mark(u, ts, kind)
    local n = #u.mt + 1
    u.mt[n], u.mk[n] = ts, kind
end
local function Listed(st, ts, list, kind)
    local names = ns.BuffSnap.Names(list)
    for k = 1, #names do
        local u = st.units[names[k]]
        if u then
            u.listed = true
            Mark(u, ts, kind)
        end
    end
end
function RF.Feed(st, ts, sub, srcName, dstName, a1, a2, a3)
    if ts > st.to then return end
    local w = srcName and st.dead[srcName]
    if w and ALIVE[sub] then
        st.dead[srcName] = nil
        Mark(w, ts, "alive")
        return
    end
    if sub == "FW_BUFFSNAP" then
        if tonumber(a1) ~= st.id then return end
        Listed(st, ts, a2, "son")
        Listed(st, ts, a3, "soff")
        return
    end
    local u = dstName and st.units[dstName]
    if not u then return end
    if sub == "UNIT_DIED" then
        st.dead[dstName] = u
        Mark(u, ts, "dead")
        return
    end
    local kind = AURA_KIND[sub]
    if not kind or (tonumber(a1) ~= st.id and a2 ~= st.aura) then return end
    if st.dead[dstName] and kind ~= "rem" then
        st.dead[dstName] = nil
        Mark(u, ts, "alive")
    end
    Mark(u, ts, kind)
end
local function Emit(out, a, b, on, sure, alive)
    if b <= a or not alive or on == nil then return end
    local last = out[#out]
    if last and last.b == a and last.on == on and last.sure == sure then
        last.b = b
        return
    end
    out[#out + 1] = { a = a, b = b, on = on, sure = sure }
end
local function Guess(u, i)
    for j = i, #u.mk do
        local k = u.mk[j]
        if k == "dead" then return nil, false end
        if STATE[k] ~= nil then return BEFORE[k], u.listed or SNAP[k] == true end
    end
    return nil, false
end
local function Walk(st, u)
    local from, to = st.from, st.to
    local mt, mk = u.mt, u.mk
    local on, sure, alive = nil, false, true
    local i = 1
    while mt[i] and mt[i] <= from do
        local k = mk[i]
        if k == "dead" then
            alive, on, sure = false, false, true
        elseif k == "alive" then
            alive = true
        else
            on, sure = STATE[k], true
        end
        i = i + 1
    end
    if on == nil then on, sure = Guess(u, i) end
    local out, t = {}, from
    for j = i, #mt do
        local ts = mt[j]
        if ts > to then break end
        Emit(out, t - from, ts - from, on, sure, alive)
        local k = mk[j]
        if k == "dead" then
            alive, on, sure = false, false, true
        elseif k == "alive" then
            alive = true
        else
            on, sure = STATE[k], true
        end
        t = ts
    end
    Emit(out, t - from, to - from, on, sure, alive)
    return out
end
local function Add(c, e)
    local n = c.n
    if e.sure then c.amount = c.amount + e.b - e.a end
    if n > 0 and e.on and c.till[n] == e.a then
        c.till[n] = e.b
        return
    end
    n = n + 1
    c.n = n
    c.times[n] = e.a
    c.till = c.till or {}
    c.unsure = c.unsure or {}
    c.till[n], c.unsure[n] = e.b, not e.sure
end
local function Judge(st, p, list, tank)
    local i = tank and st.rfuryoff or st.rfuryon
    local c = p.badges[i]
    for k = 1, #list do
        local e = list[k]
        local long = e.b - e.a >= st.minGap
        if tank and e.on == false and long then
            Add(c, e)
            if e.sure then
                local g = e.b - e.a > st.red and "red" or "yellow"
                if c.grade ~= "red" then c.grade = g end
            end
        elseif not tank and e.on == true and long then
            Add(c, e)
            c.grade = "yellow"
        end
    end
    if c.n == 0 then return end
    c.lim = st.red
    st.s.icons[i] = st.s.icons[i] or st.s.badges[i].id
end
function RF.Finish(st)
    local s = st.s
    for i = 1, #s.players do
        local p = s.players[i]
        local u = st.units[p.name]
        if u then Judge(st, p, Walk(st, u), p.role == "tank") end
    end
end
