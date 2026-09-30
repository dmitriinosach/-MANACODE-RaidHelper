local _, ns = ...
local max = math.max
local min = math.min
local tsort = table.sort
local tinsert = table.insert
local tremove = table.remove
local HUGE = math.huge
local CG = {}
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
    st.cuts[#st.cuts + 1] = { t = max(p.t, to), start = p.t, label = p.label, kind = "cast", id = p.id,
                              cut = how, by = by }
end
local function Guess(st, p, cap)
    return min(cap, p.nextAt or HUGE, p.t + (st.dur[p.id] or D().cutShow))
end
local function Stale(st, ts)
    local q, d = st.queue, D()
    local k = 1
    while k <= #q do
        local p = q[k]
        if ts > (p.nextAt and (p.nextAt + d.fly) or (p.t + d.castMax)) then
            Cut(st, k, Guess(st, p, ts), "stop")
        else
            k = k + 1
        end
    end
end
function CG.New(who)
    return { who = who, queue = {}, cuts = {}, dur = {} }
end
function CG.Feed(st, ts, sub, srcName, dstName, a1, a2)
    local q = st.queue
    if #q > 0 then Stale(st, ts) end
    if sub == "SPELL_INTERRUPT" then
        if dstName == st.who and #q > 0 then Cut(st, #q, ts, "kick", srcName) end
        return nil
    end
    if srcName ~= st.who then return nil end
    if sub == "SPELL_CAST_START" then
        for k = 1, #q do
            if not q[k].nextAt then q[k].nextAt = ts end
        end
        q[#q + 1] = { t = ts, id = a1, label = tostring(a2 or a1) }
        return nil
    end
    if #q == 0 or not OUTCOME[sub] then return nil end
    local label = tostring(a2 or a1)
    for k = 1, #q do
        local p = q[k]
        if p.id == a1 or p.label == label then
            tremove(q, k)
            local to = min(ts, p.nextAt or ts)
            st.dur[p.id] = to - p.t
            return { t = to, start = p.t, label = p.label, kind = "cast", id = p.id }
        end
    end
    return nil
end
function CG.Finish(st, to)
    while #st.queue > 0 do
        Cut(st, 1, Guess(st, st.queue[1], to), "stop")
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
        local list = ns.actions and ns.actions.kicks or {}
        for i = 1, #list do kicks[list[i]] = true end
    end
    return kicks[it.label] == true or D().offGcd[it.label] == true
end
local function ByAt(a, b)
    if a.at ~= b.at then return a.at < b.at end
    return a.it.t < b.it.t
end
function CG.Plan(casts, cuts, class, auras)
    local d = D()
    local forms = {}
    for i = 1, auras and #auras or 0 do
        local a = auras[i]
        local g = d.forms[a.label]
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
            list[#list + 1] = { it = it, at = at, gcd = g, dur = it.start and max(0, it.t - it.start) or 0,
                                off = false }
        end
    end
    tsort(list, ByAt)
    local on, off = {}, {}
    local lastOn
    for i = 1, #list do
        local slot = list[i]
        if not slot.it.start and (Listed(slot.it) or (lastOn and slot.at - lastOn < d.pair)) then
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
