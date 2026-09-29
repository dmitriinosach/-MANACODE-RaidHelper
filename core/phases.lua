local _, ns = ...
local SKIP_HP = { "FW_HP" }
local MAX_TAIL = 1
local WAVE_GAP = 5
local SETTLE = 2
local BIG_RAID = 12
local Phases = {}
ns.Phases = Phases
local indexes = setmetatable({}, { __mode = "k" })
local cache = setmetatable({}, { __mode = "k" })
local function Hook(idx, trig, hook)
    hook.sub = trig[1]
    idx.subs[hook.sub] = true
    for k = 2, #trig do
        local list = idx.hooks[trig[k]]
        if not list then
            list = {}
            idx.hooks[trig[k]] = list
        end
        list[#list + 1] = hook
    end
end
local function Index(def)
    local idx = indexes[def]
    if idx then return idx end
    idx = { subs = {}, hooks = {} }
    local steps = def.steps
    for j = 2, #steps do
        local on = steps[j].on or {}
        for k = 1, #on do Hook(idx, on[k], { j = j, delay = on[k].delay }) end
    end
    for kind, w in pairs(def.waves or {}) do
        Hook(idx, w.on, { kind = kind })
        if w.stop then Hook(idx, w.stop, { kind = kind, stop = true }) end
    end
    indexes[def] = idx
    return idx
end
local function SizeOf(fight)
    if fight.raid and fight.raid.size then return fight.raid.size end
    local n = 0
    for _ in pairs(fight.players or {}) do n = n + 1 end
    return n > BIG_RAID and 25 or 10
end
function Phases.New(fight)
    local def = ns.bossPhases and ns.bossPhases[fight.boss]
    if not def or not def.steps or not def.steps[1] then return nil end
    local first = def.steps[1]
    local tr = {
        def = def, idx = Index(def), from = fight.from, to = fight.to, size = SizeOf(fight),
        cur = 1, key = first.key, waveAt = {},
        res = { spans = { { key = first.key, label = first.label, from = 0, to = fight.to - fight.from } },
                waves = {}, ends = {} },
    }
    for kind in pairs(def.waves or {}) do
        tr.res.waves[kind] = {}
        tr.res.ends[kind] = {}
    end
    return tr
end
local function Enter(tr, j, ts)
    local spans = tr.res.spans
    local sec = ts - tr.from
    spans[#spans].to = sec
    local st = tr.def.steps[j]
    spans[#spans + 1] = { key = st.key, label = st.label, from = sec, to = tr.to - tr.from }
    tr.cur, tr.key, tr.moved = j, st.key, ts
    tr.due, tr.dueStep = nil, nil
end
local function Step(tr, hook, ts)
    if hook.j <= tr.cur or (tr.dueStep and hook.j <= tr.dueStep) then return false end
    if tr.moved and ts - tr.moved < SETTLE then return false end
    local delay = hook.delay
    if type(delay) == "table" then delay = delay[tr.size] or delay[25] end
    if delay and delay > 0 then
        tr.due, tr.dueStep = ts + delay, hook.j
        return false
    end
    Enter(tr, hook.j, ts)
    return true
end
local function Wave(tr, hook, ts)
    local kind = hook.kind
    local times, ends = tr.res.waves[kind], tr.res.ends[kind]
    if hook.stop then
        if #times > #ends then ends[#times] = ts - tr.from end
        return
    end
    local start = tr.waveAt[kind]
    if start and ts - start <= (tr.def.waves[kind].gap or WAVE_GAP) then return end
    tr.waveAt[kind] = ts
    if tr.def.waves[kind].stop and #ends < #times then ends[#times] = ts - tr.from end
    times[#times + 1] = ts - tr.from
end
function Phases.Feed(tr, ts, sub, id)
    if ts < tr.from or ts > tr.to then return false end
    local changed = false
    if tr.due and ts >= tr.due then
        Enter(tr, tr.dueStep, tr.due)
        changed = true
    end
    if not tr.idx.subs[sub] then return changed end
    local n = tonumber(id)
    local list = n and tr.idx.hooks[n]
    if not list then return changed end
    local stepped = false
    for k = 1, #list do
        local hook = list[k]
        if hook.sub == sub then
            if hook.kind then
                Wave(tr, hook, ts)
            elseif not stepped then
                stepped = Step(tr, hook, ts)
            end
        end
    end
    return changed or stepped
end
function Phases.Count(tr, kind)
    local times = tr.res.waves[kind]
    return times and #times or 0
end
function Phases.WaveAt(res, kind, sec)
    local times = res.waves[kind]
    local n = 0
    for k = 1, times and #times or 0 do
        if times[k] <= sec then n = k end
    end
    return n
end
function Phases.At(res, sec)
    local spans = res.spans
    for k = #spans, 1, -1 do
        if spans[k].from <= sec then return spans[k].key end
    end
    return nil
end
function Phases.Span(res, key)
    local spans = res.spans
    for k = 1, #spans do
        if spans[k].key == key then return spans[k].from, spans[k].to end
    end
    return nil, nil
end
function Phases.Done(fight, tr)
    if tr.due and tr.due <= tr.to then Enter(tr, tr.dueStep, tr.due) end
    for kind, w in pairs(tr.def.waves or {}) do
        local times, ends = tr.res.waves[kind], tr.res.ends[kind]
        if w.stop and #ends < #times then ends[#times] = tr.to - tr.from end
    end
    cache[fight] = tr.res
    return tr.res
end
function Phases.Get(fight)
    return cache[fight]
end
function Phases.Scan(fight)
    if cache[fight] then return cache[fight] end
    local tr = Phases.New(fight)
    if not tr then return nil end
    local segs = ns.Encounters.Segs(fight)
    for si = 1, #segs do
        for ts, sub, _, _, _, _, _, _, a1 in ns.Store.Events(segs[si], fight.from, fight.to, SKIP_HP, MAX_TAIL) do
            ns.Jobs.Step()
            Phases.Feed(tr, ts, sub, a1)
        end
    end
    return Phases.Done(fight, tr)
end
