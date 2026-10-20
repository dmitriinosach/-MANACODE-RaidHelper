local _, ns = ...
local concat = table.concat
local pairs = pairs
local tonumber = tonumber
local TREES = 3
local CAST = "SPELL_CAST_SUCCESS"
local AURA = "SPELL_AURA_APPLIED"
local SNAP = "FW_BUFFSNAP"
local INSPECT_SUB = "FW_SPEC"
local SpecSign = {}
ns.SpecSign = SpecSign
SpecSign.SIGN = "sign"
SpecSign.INSPECT = "insp"
SpecSign.SUBS = { [CAST] = true, SPELL_CAST_START = true, [AURA] = true, [SNAP] = true, [INSPECT_SUB] = true }
local byClass
local swaps = {}
local snaps = {}
local function Build()
    byClass = {}
    swaps = ns.IdSet(ns.specSwap)
    snaps = ns.IdSet(ns.specSignSnap)
    for cls, trees in pairs(ns.specSigns or {}) do
        local map = {}
        for t = 1, #trees do
            for _, list in pairs(trees[t]) do
                for i = 1, #list do map[list[i]] = t end
            end
        end
        byClass[cls] = map
    end
end
function SpecSign.Begin(byName, to)
    if not byClass then Build() end
    return { byName = byName, to = to, seen = {}, insp = {}, swap = {} }
end
function SpecSign.TreeOf(class, id)
    if not byClass then Build() end
    local map = class and byClass[class]
    return map and map[tonumber(id) or 0] or nil
end
local function Mark(st, name, id)
    local p = st.byName[name]
    local t = p and SpecSign.TreeOf(p.class, id)
    if not t then return end
    local seen = st.seen[name]
    if not seen then
        seen = {}
        st.seen[name] = seen
    end
    seen[t] = (seen[t] or 0) + 1
end
local function Inspected(st, ts, a1, a2, a3)
    local trees, ages = ns.Specs.Parse(a1, a2, a3)
    for name, t in pairs(trees) do
        if st.byName[name] then
            local age = ages[name]
            st.insp[name] = { t = t, at = age and ts - age or nil }
        end
    end
end
function SpecSign.Feed(st, ts, sub, srcName, dstName, a1, a2, a3)
    if ts > st.to then return end
    if sub == INSPECT_SUB then
        Inspected(st, ts, a1, a2, a3)
        return
    end
    local id = tonumber(a1)
    if not id then return end
    if sub == SNAP then
        if not snaps[id] then return end
        local names = ns.BuffSnap.Names(a2)
        for i = 1, #names do Mark(st, names[i], id) end
        return
    end
    if not srcName or not st.byName[srcName] then return end
    if sub == AURA then
        if srcName == dstName then Mark(st, srcName, id) end
        return
    end
    if sub == CAST and swaps[id] then
        st.swap[srcName] = ts
        st.seen[srcName] = nil
        return
    end
    Mark(st, srcName, id)
end
function SpecSign.Finish(st, players)
    for i = 1, #players do
        local p = players[i]
        local name = p.name
        p.tree, p.treeBy, p.treeClash = nil, nil, nil
        local seen = st.seen[name]
        local list = {}
        for t = 1, TREES do
            if seen and seen[t] then list[#list + 1] = t end
        end
        if #list > 1 then
            p.treeClash = concat(list, "/")
        elseif #list == 1 then
            p.tree, p.treeBy = list[1], SpecSign.SIGN
        else
            local ins, sw = st.insp[name], st.swap[name]
            if ins and not (sw and (not ins.at or sw > ins.at)) then p.tree, p.treeBy = ins.t, SpecSign.INSPECT end
        end
    end
end
