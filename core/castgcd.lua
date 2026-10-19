local _, ns = ...
local max = math.max
local min = math.min
local abs = math.abs
local tsort = table.sort
local tinsert = table.insert
local tremove = table.remove
local HUGE = math.huge
local FW = "FW_CAST"
local K_CAST, K_CHAN, K_MOVED, K_CUT = 1, 2, 3, 0
local CG = { FW = FW }
ns.CastGcd = CG
local OUTCOME = {
    SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_HEAL = true, SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true, SPELL_AURA_APPLIED_DOSE = true, SPELL_SUMMON = true, SPELL_CREATE = true,
    SPELL_RESURRECT = true, SPELL_DISPEL = true, SPELL_INSTAKILL = true,
}
local kicks = nil
local function D()
    return ns.castGcd
end
local function Cut(st, k, to, how, by)
    local p = tremove(st.queue, k)
    local it = { t = max(p.t, to), start = p.t, label = p.label, kind = "cast", id = p.id, cut = how, by = by }
    if how == "cut" and p.to and p.to > it.t then it.left = p.to - it.t end
    st.cuts[#st.cuts + 1] = it
    return it
end
local function Guess(st, p, cap)
    return min(cap, p.nextAt or HUGE, p.to or (p.t + (st.dur[p.id] or D().cutShow)))
end
local function Late(st, k)
    local p = tremove(st.queue, k)
    local to = min(p.to, p.nextAt or p.to)
    st.dur[p.id] = to - p.t
    st.late[#st.late + 1] = { t = to, start = p.t, label = p.label, kind = "cast", id = p.id }
end
local function Stale(st, ts)
    local q, d = st.queue, D()
    local k = 1
    while k <= #q do
        local p = q[k]
        if p.to and ts > p.to + d.fly then
            Late(st, k)
        elseif ts > (p.nextAt and (p.nextAt + d.fly) or (p.t + d.castMax)) then
            Cut(st, k, Guess(st, p, ts), "stop")
        else
            k = k + 1
        end
    end
end
local function Current(st, ts)
    local k = #st.queue
    local p = st.queue[k]
    if not p or p.nextAt then return nil end
    if p.to and ts > p.to + D().late then return nil end
    return k
end
local function Chan(st, it, to)
    it.chan, it.to = true, max(it.t, to)
    st.chan = it
end
local function StopChan(st, it, ts, how, by)
    if how == "cut" and it.to and it.to > ts then it.left = it.to - ts end
    it.cut, it.by, it.to = how, by, max(it.t, ts)
    st.chan = nil
end
local function Kick(st, ts, by)
    local k = Current(st, ts)
    local ch = st.chan
    if ch and (not k or ch.t >= st.queue[k].t) then
        StopChan(st, ch, ts, "kick", by)
    elseif k then
        Cut(st, k, ts, "kick", by)
    else
        local c = st.lastCut
        if c and abs(st.lastCutAt - ts) <= D().match then
            c.cut, c.by, c.left = "kick", by, nil
        end
    end
    st.lastCut = nil
end
local function OnFw(st, ts, kind, left)
    local d = D()
    local k = Current(st, ts)
    local p = k and st.queue[k]
    if kind == K_CAST then
        if p and not p.to and abs(p.t - ts) <= d.match then
            p.to = ts + left
        else
            st.fw = { ts = ts, kind = kind, left = left }
        end
    elseif kind == K_CHAN then
        local s = st.succ
        if s and abs(s.t - ts) <= d.match then
            st.succ = nil
            Chan(st, s, ts + left)
        else
            st.fw = { ts = ts, kind = kind, left = left }
        end
    elseif kind == K_MOVED then
        if p and p.to then
            p.to = ts + left
        elseif st.chan then
            st.chan.to = ts + left
        end
    elseif kind == K_CUT then
        local ch = st.chan
        if ch and (not p or ch.t >= p.t) then
            StopChan(st, ch, ts, "cut")
            st.lastCut, st.lastCutAt = ch, ts
        elseif k then
            st.lastCut, st.lastCutAt = Cut(st, k, ts, "cut"), ts
        end
    end
end
function CG.New(who)
    return { who = who, queue = {}, cuts = {}, late = {}, dur = {} }
end
function CG.Feed(st, ts, sub, srcName, dstName, a1, a2)
    local q = st.queue
    if #q > 0 then Stale(st, ts) end
    local ch = st.chan
    if ch and ts > ch.to + D().match then st.chan = nil end
    if sub == FW then
        if srcName == st.who then OnFw(st, ts, tonumber(a1) or -1, (tonumber(a2) or 0) / 1000) end
        return nil
    end
    if sub == "SPELL_INTERRUPT" then
        if dstName == st.who then Kick(st, ts, srcName) end
        return nil
    end
    if srcName ~= st.who then return nil end
    if sub == "SPELL_CAST_START" then
        for k = 1, #q do
            if not q[k].nextAt then q[k].nextAt = ts end
        end
        local p = { t = ts, id = a1, label = tostring(a2 or a1) }
        local f = st.fw
        if f and f.kind == K_CAST and abs(f.ts - ts) <= D().match then
            p.to = f.ts + f.left
            st.fw = nil
        end
        q[#q + 1] = p
        return nil
    end
    if #q == 0 or not OUTCOME[sub] then return nil end
    local label = tostring(a2 or a1)
    for k = 1, #q do
        local p = q[k]
        if p.id == a1 or p.label == label then
            tremove(q, k)
            local to = min(ts, p.nextAt or ts, p.to or ts)
            st.dur[p.id] = to - p.t
            return { t = to, start = p.t, label = p.label, kind = "cast", id = p.id }
        end
    end
    return nil
end
function CG.Success(st, it)
    local f = st.fw
    if f and f.kind == K_CHAN and abs(f.ts - it.t) <= D().match then
        st.fw = nil
        Chan(st, it, f.ts + f.left)
    else
        st.succ = it
    end
end
function CG.Finish(st, to, casts)
    while #st.queue > 0 do
        local p = st.queue[1]
        if p.to and p.to <= to then
            Late(st, 1)
        else
            Cut(st, 1, Guess(st, p, to), "stop")
        end
    end
    if casts then
        for k = 1, #st.late do CG.Insert(casts, st.late[k]) end
    end
    return st.cuts
end
function CG.Insert(list, it)
    local i = #list
    while i > 0 and list[i].t > it.t do i = i - 1 end
    tinsert(list, i + 1, it)
end
local function Listed(it)
    if it.taunt then return true end
    local id = tonumber(it.id)
    if id and ns.defensives and ns.defensives[id] then return true end
    if not kicks then
        kicks = {}
        ns.SpellSet(ns.actions and ns.actions.kicks, kicks)
        for k in pairs(D().offGcd) do kicks[ns.SpellKey(k)] = true end
    end
    local key = id and ns.SpellKey(id)
    return key ~= nil and kicks[key] == true
end
local function ByAt(a, b)
    if a.at ~= b.at then return a.at < b.at end
    return a.it.t < b.it.t
end
function CG.Plan(casts, cuts, class, auras)
    local d = D()
    local forms = {}
    local byKey = {}
    for k, g in pairs(d.forms) do byKey[ns.SpellKey(k)] = g end
    for i = 1, auras and #auras or 0 do
        local a = auras[i]
        local g = a.id and byKey[ns.SpellKey(a.id) or 0]
        if g then forms[#forms + 1] = { a.t, a.to or a.t, g } end
    end
    local base = d.class[class or ""] or d.base
    local short = base
    for _, g in pairs(d.class) do short = min(short, g) end
    for _, g in pairs(d.forms) do short = min(short, g) end
    local list = {}
    local sources = { casts or {}, cuts or {} }
    for s = 1, 2 do
        local src = sources[s]
        for i = 1, #src do
            local it = src[i]
            local at = it.start or it.t
            local g = base
            for k = 1, #forms do
                if at >= forms[k][1] and at <= forms[k][2] then
                    g = forms[k][3]
                    break
                end
            end
            list[#list + 1] = { it = it, at = at, gcd = g, dur = max(0, (it.to and it.chan and it.to or it.t) - at),
                                off = false }
        end
    end
    tsort(list, ByAt)
    local on, off = {}, {}
    local lastOn
    for i = 1, #list do
        local slot = list[i]
        if not slot.it.start and not slot.it.chan and (Listed(slot.it) or (lastOn and slot.at - lastOn < d.pair)) then
            slot.off = true
            off[#off + 1] = slot
        else
            on[#on + 1] = slot
            lastOn = slot.at
        end
    end
    return { list = list, on = on, off = off, short = short }
end
function CG.Widths(plan, pps, minW, maxW)
    local on = plan.on
    for k = 1, #on do
        local slot = on[k]
        local want = max(min(maxW, pps * slot.gcd), pps * slot.dur)
        local nx = on[k + 1]
        if nx then want = min(want, (nx.at - slot.at) * pps - 1) end
        slot.w = max(minW, want)
    end
end
