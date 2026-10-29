local _, ns = ...
local HUGE = math.huge
local abs = math.abs
local min = math.min
local tsort = table.sort
local NEAR = 2
local LATE = 3
local SPLIT = 1
local SP = {}
ns.SummaryPull = SP
local SUBS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true, SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true,
               SPELL_DAMAGE = true, SPELL_MISSED = true, DAMAGE_SPLIT = true }
function SP.Begin(s, fight, def)
    local pd = def.pull
    local C = ns.covers
    if not (pd and C and C.raid) then return nil end
    local st = { s = s, def = pd, from = fight.from, to = fight.to, keys = {}, raid = {}, ids = {}, order = {}, classes = {},
                 auraKeys = {}, frost = ns.SpellKey(pd.aura), hits = {}, casts = {}, spans = {}, split = {}, auras = {},
                 subs = SUBS }
    for q = 1, #pd.spells do st.keys[ns.SpellKey(pd.spells[q])] = true end
    for id, rc in pairs(C.raid) do
        local key = ns.SpellKey(id)
        st.raid[key], st.ids[key] = rc, id
        st.order[#st.order + 1] = id
        st.classes[rc.class] = true
    end
    tsort(st.order)
    for q = 1, #(C.auras or {}) do st.auraKeys[ns.SpellKey(C.auras[q])] = true end
    local i = #s.badges + 1
    s.badges[i] = { kind = "pullin", id = pd.id, tip = pd.tip, rule = pd.rule, pull = pd }
    for j = 1, #s.players do
        s.players[j].badges[i] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
    end
    st.i = i
    return st
end
local function Add(map, name, e)
    local l = map[name]
    if not l then
        l = {}
        map[name] = l
    end
    l[#l + 1] = e
end
local function Hit(st, ts, sub, dstName, a4)
    local l = st.hits
    local h = l[#l]
    local lead = st.def.lead or 5
    if sub == "SPELL_CAST_START" then
        if not (h and not h.te and ts - h.t0 < 1) then l[#l + 1] = { t0 = ts, dmg = 0, n = 0 } end
        return
    end
    if sub ~= "SPELL_DAMAGE" and sub ~= "SPELL_MISSED" then return end
    if not (dstName and st.s.byName[dstName]) then return end
    if not h or (h.te and ts - h.te > 1) or (not h.te and ts - h.t0 > lead + LATE) then
        h = { t0 = ts - lead, dmg = 0, n = 0 }
        l[#l + 1] = h
    end
    h.te = h.te or ts
    h.n = h.n + 1
    if sub == "SPELL_DAMAGE" then h.dmg = h.dmg + (tonumber(a4) or 0) end
end
function SP.Feed(st, ts, sub, srcName, dstName, a1, a4)
    if ts > st.to + LATE then return end
    local id = tonumber(a1)
    local key = id and ns.SpellKey(id)
    if not key then return end
    if st.keys[key] then
        Hit(st, ts, sub, dstName, a4)
        return
    end
    local by = st.s.byName
    local rc = st.raid[key]
    if rc and sub == "DAMAGE_SPLIT" then
        if rc.split and dstName and by[dstName] then Add(st.split, dstName, { t = ts, amount = tonumber(a4) or 0 }) end
        return
    end
    local p = srcName and by[srcName]
    if not p then return end
    if rc then
        if p.class ~= rc.class then return end
        if sub == "SPELL_CAST_SUCCESS" then
            Add(st.casts, srcName, { id = id, t = ts })
        elseif dstName == srcName and sub == "SPELL_AURA_APPLIED" then
            Add(st.spans, srcName, { a = ts, b = HUGE, key = key })
        elseif dstName == srcName and sub == "SPELL_AURA_REMOVED" then
            local l = st.spans[srcName]
            for q = l and #l or 0, 1, -1 do
                if l[q].b == HUGE and l[q].key == key then
                    l[q].b = ts
                    return
                end
            end
        end
    elseif st.auraKeys[key] then
        local l = st.auras[srcName]
        local last = l and l[#l]
        if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_CAST_SUCCESS" then
            if not (last and last.key == key) then Add(st.auras, srcName, { t = ts, key = key }) end
        elseif sub == "SPELL_AURA_REMOVED" and dstName == srcName and last and last.key == key then
            Add(st.auras, srcName, { t = ts, key = false })
        end
    end
end
local function AuraAt(st, name, t)
    local l = st.auras[name]
    for q = l and #l or 0, 1, -1 do
        if l[q].t <= t then return l[q].key, l[q].t end
    end
    return nil, nil
end
local function Use(st, name, c, rc, te)
    local from = st.from
    local u = { id = c.id, t = c.t - from }
    local b = c.t + rc.dur
    if rc.aura then
        local key = ns.SpellKey(c.id)
        local l = st.spans[name]
        local a = c.t
        for q = l and #l or 0, 1, -1 do
            local sp = l[q]
            if sp.key == key and abs(sp.a - c.t) <= 1 then
                a, b = sp.a, min(sp.b, c.t + rc.dur)
                break
            end
        end
        u.a, u.b = a - from, b - from
    end
    if c.t > te then
        u.why = "late"
        return u
    end
    if b < te then
        u.why = "early"
        return u
    end
    if rc.aura then
        local atCast = AuraAt(st, name, c.t)
        local atHit, since = AuraAt(st, name, te)
        if atCast ~= nil and atCast ~= st.frost then
            u.why, u.aura = "wrong", atCast
        elseif atHit ~= nil and atHit ~= st.frost then
            u.why, u.off = "ended", (since or te) - from
        else
            u.ok = true
            u.since = since and since - from or nil
        end
        return u
    end
    u.ok = true
    if rc.split then
        local sum = 0
        local l = st.split[name]
        for q = 1, l and #l or 0 do
            if abs(l[q].t - te) <= SPLIT then sum = sum + l[q].amount end
        end
        u.took = sum
    end
    return u
end
local function LastPress(st, name, key, te)
    local last
    local reg = ns.Encounters and ns.Encounters.Pressed and ns.Encounters.Pressed(name)
    for q = 1, reg and #reg or 0, 2 do
        local at = reg[q]
        if at < te and ns.SpellKey(reg[q + 1]) == key and (not last or at > last) then last = at end
    end
    local l = st.casts[name]
    for q = 1, l and #l or 0 do
        local c = l[q]
        if c.t < te and ns.SpellKey(c.id) == key and (not last or c.t > last) then last = c.t end
    end
    return last
end
local function Died(s, keys, te, after)
    local out = {}
    for k = 1, #s.players do
        local p = s.players[k]
        for q = 1, #(p.deathInfo or {}) do
            local d = p.deathInfo[q]
            local kl = d.killer
            if kl and kl.key and keys[kl.key] and d.t >= te - 1 and d.t <= te + after and not d.tail then
                out[#out + 1] = p.name
                break
            end
        end
    end
    tsort(out)
    return out
end
local function Judge(st, p, h, te, died)
    local from = st.from
    local name = p.name
    local ep = { t0 = h.t0 - from, te = te - from, dmg = h.dmg, hits = h.n, died = died, uses = {}, ready = {}, cd = {},
                 never = {} }
    local used = {}
    local casts = st.casts[name]
    for k = 1, casts and #casts or 0 do
        local c = casts[k]
        local key = ns.SpellKey(c.id)
        local rc = st.raid[key]
        if rc and c.t >= h.t0 - NEAR and c.t <= te + LATE then
            local u = Use(st, name, c, rc, te)
            ep.uses[#ep.uses + 1] = u
            used[key] = true
            if u.ok then ep.given = true end
        end
    end
    for q = 1, #st.order do
        local id = st.order[q]
        local key = ns.SpellKey(id)
        local rc = st.raid[key]
        if not used[key] and rc.class == p.class then
            local last = LastPress(st, name, key, te)
            if not last then
                ep.never[#ep.never + 1] = id
            elseif te - last >= rc.cd then
                ep.ready[#ep.ready + 1] = id
            else
                ep.cd[#ep.cd + 1] = { id = id, at = last + rc.cd - from }
            end
        end
    end
    local c = p.badges[st.i]
    c.n = c.n + 1
    c.times[c.n] = ep.t0
    c.eps = c.eps or {}
    c.grades = c.grades or {}
    c.eps[c.n] = ep
    local g = "none"
    if ep.given then
        g = "green"
        c.hits = c.hits + 1
        for q = 1, #ep.uses do c.amount = c.amount + (ep.uses[q].took or 0) end
    elseif #ep.ready > 0 and #died > 0 then
        g = "yellow"
    end
    c.grades[c.n] = g
    if g == "yellow" then
        c.grade = "yellow"
    elseif g == "green" and c.grade ~= "yellow" then
        c.grade = "green"
    end
end
function SP.Finish(st)
    local s = st.s
    local lead, after = st.def.lead or 5, st.def.after or 3
    tsort(st.hits, function(a, b) return a.t0 < b.t0 end)
    for q = 1, #st.hits do
        local h = st.hits[q]
        if h.t0 >= s.lead and h.t0 <= st.to then
            local te = h.te or h.t0 + lead
            local died = Died(s, st.keys, te, after)
            for k = 1, #s.players do
                local p = s.players[k]
                if st.classes[p.class or ""] then Judge(st, p, h, te, died) end
            end
        end
    end
    local blk
    for k = 1, #s.blocks do
        if s.blocks[k].def.kind == "pullins" then blk = s.blocks[k] end
    end
    for k = 1, #s.players do
        local p = s.players[k]
        local c = p.badges[st.i]
        if c.n > 0 then
            s.icons[st.i] = s.icons[st.i] or st.def.id
            if blk then
                blk.by[p.name] = c.hits
                blk.total = c.n
                blk.pull = blk.pull or {}
                blk.pull[p.name] = c.grade or false
            end
        end
    end
end
