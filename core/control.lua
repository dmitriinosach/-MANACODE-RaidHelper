local _, ns = ...
local huge = math.huge
local min = math.min
local SAME = 0.05
local HELD_SEC = 1
local AURA = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_REMOVED = true }
local HIT = { SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_CAST_SUCCESS = true, SPELL_AURA_APPLIED = true }
local NONE = {}
local Control = {}
ns.Control = Control
function Control.New(def)
    local SK = ns.SpellKey
    local c = { auras = {}, moved = {}, set = {}, ev = {}, open = {}, mcOn = {} }
    local data = ns.lossControl or NONE
    local moved = data.moved or NONE
    for id, kind in pairs(data.ids or NONE) do
        if moved[kind] then c.moved[SK(id)] = kind else c.auras[SK(id)] = kind end
    end
    def = def or NONE
    for id, kind in pairs(def.auras or NONE) do c.auras[SK(id)] = kind end
    for id, kind in pairs(def.moved or NONE) do c.moved[SK(id)] = kind end
    if def.mc then c.auras[SK(def.mc)] = "mc" end
    for k in pairs(c.auras) do c.set[k] = true end
    for k in pairs(c.moved) do c.set[k] = true end
    return c
end
function Control.Feed(c, ts, sub, srcName, dstName, sk, spell, mc)
    local list = c.ev[dstName]
    if not list then
        list = {}
        c.ev[dstName] = list
    end
    mc = mc or (srcName ~= nil and c.mcOn[srcName] ~= nil)
    local kind = c.auras[sk]
    if kind and AURA[sub] then
        local key = dstName .. "|" .. sk
        local cur = c.open[key]
        if sub == "SPELL_AURA_REMOVED" then
            if cur then
                cur.to = ts
                c.open[key] = nil
                if kind == "mc" then c.mcOn[dstName] = nil end
            end
        elseif not cur then
            cur = { t = ts, kind = kind, spell = spell, src = srcName, mc = mc or nil }
            list[#list + 1] = cur
            c.open[key] = cur
            if kind == "mc" then c.mcOn[dstName] = cur end
        end
        return
    end
    kind = c.moved[sk]
    if kind and HIT[sub] then
        list[#list + 1] = { t = ts, to = ts, kind = kind, spell = spell, src = srcName, mc = mc or nil }
    end
end
function Control.Find(c, name, ts, win)
    local best
    local list = c.ev[name] or NONE
    for i = 1, #list do
        local e = list[i]
        local to = e.to or huge
        if e.t <= ts + SAME and to >= ts - win and (not best or e.t > best.t) then best = e end
    end
    return best
end
function Control.Begin(s, fight, def)
    local h = def.held
    if not h then return nil end
    local idx = {}
    for i = 1, #s.badges do
        if s.badges[i].held then idx[#idx + 1] = i end
    end
    local c = Control.New(h)
    return { c = c, set = c.set, s = s, from = fight.from, to = fight.to, sec = h.sec or HELD_SEC, idx = idx }
end
function Control.Held(p, t)
    local best
    local list = p.held or NONE
    for i = 1, #list do
        local e = list[i]
        if e.t <= t + SAME and e.to >= t and (not best or e.t > best.t) then best = e end
    end
    return best
end
function Control.Finish(st)
    local s = st.s
    for name, list in pairs(st.c.ev) do
        local p = s.byName[name]
        local out = {}
        for k = 1, #list do
            local e = list[k]
            local to = min(e.to or st.to, st.to) + st.sec
            if p and to >= st.from and e.t <= st.to then
                out[#out + 1] = { t = e.t - st.from, to = to - st.from, k = e.kind, sp = e.spell, src = e.src }
            end
        end
        if #out > 0 then p.held = out end
    end
    for j = 1, #s.players do
        local p = s.players[j]
        for i = 1, p.held and #st.idx or 0 do
            local c = p.badges[st.idx[i]]
            if c and c.n > 0 then
                local all = true
                c.held = {}
                for k = 1, c.n do
                    local w = Control.Held(p, c.times[k])
                    c.held[k] = w or false
                    all = all and w ~= nil
                end
                if all then c.grade = "green" end
            end
        end
    end
end
