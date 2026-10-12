local _, ns = ...
local tsort = table.sort
local SKIP_HP = { "FW_HP" }
local MAX_TAIL = 5
local STATE_PRIO = 55
local BD = {}
ns.TimelineBriefData = BD
local feeds = setmetatable({}, { __mode = "k" })
local faults = setmetatable({}, { __mode = "k" })
local asked = setmetatable({}, { __mode = "k" })
local feedAsk = setmetatable({}, { __mode = "k" })
local pick
local function Pick()
    if pick then return pick end
    pick = {}
    local D = ns.replayData
    if not D then return pick end
    for i = 1, #(D.control and D.control.ids or {}) do pick[ns.SpellKey(D.control.ids[i])] = "ctl" end
    for i = 1, #(D.states or {}) do
        local st = D.states[i]
        local key = ns.SpellKey(st.name)
        if key and not st.focus and not st.grow and (st.imp or st.prio >= STATE_PRIO) and not pick[key] then
            pick[key] = st.mc and "ctl" or st.boss or "any"
        end
    end
    return pick
end
function BD.Feed(fight, fn)
    local have = feeds[fight]
    if have or not ns.ReplayFeedCore or feedAsk[fight] then return have end
    feedAsk[fight] = true
    ns.Jobs.Run("tl.brief.feed", function()
        local FC = ns.ReplayFeedCore
        local fc = FC.New(fight)
        local ph = not ns.Phases.Get(fight) and ns.Phases.New(fight) or nil
        local segs = ns.Encounters.Segs(fight)
        for o = 1, #segs do
            for ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, _, a4, a5
                in ns.Store.Events(segs[o], fight.from, fight.to, SKIP_HP, MAX_TAIL) do
                ns.Jobs.Step()
                if ph then ns.Phases.Feed(ph, ts, sub, a1) end
                FC.Event(fc, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4, a5)
            end
        end
        local res = ph and ns.Phases.Done(fight, ph) or ns.Phases.Get(fight)
        local L = { tanks = {} }
        FC.Done(fc, L, res)
        return { n = L.nf or 0, t = L.fdT, icon = L.fdIcon, text = L.fdText, tip = L.fdTip, imp = L.fdImp,
                 kind = L.fdKind, who = L.fdWho, all = L.fdAll or {} }
    end, function(f)
        feedAsk[fight] = nil
        if not f then return end
        feeds[fight] = f
        fn(f)
    end, "tl.brief", true)
    return nil
end
local function Mine(f, i, who)
    if f.who[i] == who then return true end
    local all = f.all[i]
    for k = 1, all and #all or 0 do
        if all[k] == who then return true end
    end
    return false
end
function BD.FeedFor(f, who)
    local out = {}
    for i = 1, f.n do
        local kind = f.kind[i]
        if kind == "phase" or kind == "hero" or Mine(f, i, who) then out[#out + 1] = i end
    end
    return out
end
function BD.Faults(fight, who, fn)
    local s = ns.Summary and ns.Summary.Get(fight)
    if not s then
        if ns.Summary and asked[fight] == nil then
            asked[fight] = true
            ns.Summary.Compute(fight, function()
                asked[fight] = false
                fn()
            end)
        end
        return nil
    end
    local c = faults[fight]
    if not c or c.s ~= s then
        c = { s = s, by = ns.Penalties.Evaluate(s, fight) }
        faults[fight] = c
    end
    local out = {}
    local list = c.by[who] or {}
    for i = 1, #list do
        local hit = list[i]
        for k = 1, #hit.events do
            local ev = hit.events[k]
            out[#out + 1] = { t = ev.t, hit = hit, grade = ev.grade == "yellow" and "yellow" or "red" }
        end
    end
    tsort(out, function(a, b)
        if (a.t == nil) ~= (b.t == nil) then return a.t == nil end
        return (a.t or 0) < (b.t or 0)
    end)
    return out
end
function BD.States(data, fight)
    local P = Pick()
    local rows, index = {}, {}
    local auras = data and data.auras or {}
    for i = 1, #auras do
        local a = auras[i]
        local id = tonumber(a.id)
        local key = id and ns.SpellKey(id)
        local mark = key and P[key]
        if mark and mark ~= "ctl" and mark ~= "any" and mark ~= fight.boss then mark = nil end
        local enemy = a.kind == "debuff" and a.src and not fight.players[a.src]
        if key and (mark or enemy) then
            local row = index[key]
            if not row then
                local kind = mark == "ctl" and "ctl" or (a.kind == "debuff" and "bad" or "good")
                row = { id = id, label = ns.Effects.Name(key) or a.label, kind = kind, items = {} }
                index[key] = row
                rows[#rows + 1] = row
            end
            row.items[#row.items + 1] = a
        end
    end
    local rank = { ctl = 1, bad = 2, good = 3 }
    tsort(rows, function(a, b)
        if a.kind ~= b.kind then return rank[a.kind] < rank[b.kind] end
        return a.items[1].t < b.items[1].t
    end)
    return rows
end
local acts
local function Acts()
    if acts then return acts end
    acts = {}
    for id in pairs(ns.defensives or {}) do acts[ns.SpellKey(id)] = true end
    local help = ns.replayFeed and ns.replayFeed.help or {}
    for id in pairs(help) do acts[ns.SpellKey(id)] = true end
    local A = ns.actions or {}
    for i = 1, #(A.kicks or {}) do acts[ns.SpellKey(A.kicks[i])] = true end
    for i = 1, #(A.selfRez or {}) do acts[ns.SpellKey(A.selfRez[i])] = true end
    if A.stone then acts[ns.SpellKey(A.stone)] = true end
    local P = Pick()
    for key, mark in pairs(P) do
        if mark ~= "ctl" then acts[key] = true end
    end
    return acts
end
function BD.Acts(data)
    local A = Acts()
    local out = {}
    local casts = data and data.casts or {}
    for i = 1, #casts do
        local c = casts[i]
        local key = ns.SpellKey(c.id)
        if key and A[key] then out[#out + 1] = c end
    end
    return out
end
function BD.Reset()
    pick, acts = nil, nil
    for k in pairs(feeds) do feeds[k] = nil end
    for k in pairs(faults) do faults[k] = nil end
end
