local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local REVIVE_GAP = 0.5
local SAME_DEATH = 0.01
local Eff = {}
ns.EffTime = Eff
function Eff.Begin(byName, fight)
    return { byName = byName, from = fight.from, to = fight.to, open = {}, spans = {} }
end
local function Span(st, name, a, z)
    local list = st.spans[name]
    if not list then
        list = {}
        st.spans[name] = list
    end
    list[#list + 1] = a
    list[#list + 1] = z
end
function Eff.Feed(st, ts, sub, srcName, dstName)
    if ts < st.from or ts > st.to then return end
    if sub == "UNIT_DIED" then
        if not dstName or not st.byName[dstName] then return end
        local was = st.open[dstName]
        if was then Span(st, dstName, was, ts) end
        st.open[dstName] = ts
    elseif sub == "SPELL_RESURRECT" then
        local was = dstName and st.open[dstName]
        if was and ts > was then
            Span(st, dstName, was, ts)
            st.open[dstName] = nil
        end
    elseif sub == "SPELL_CAST_SUCCESS" then
        local was = srcName and st.open[srcName]
        if was and ts - was > REVIVE_GAP then
            Span(st, srcName, was, ts)
            st.open[srcName] = nil
        end
    end
end
local function Merge(list)
    local n = #list / 2
    local idx = {}
    for k = 1, n do idx[k] = k end
    tsort(idx, function(a, b) return list[a * 2 - 1] < list[b * 2 - 1] end)
    local out = {}
    for k = 1, n do
        local a, z = list[idx[k] * 2 - 1], list[idx[k] * 2]
        local m = #out
        if m > 0 and a <= out[m] then
            out[m] = max(out[m], z)
        else
            out[m + 1] = a
            out[m + 2] = z
        end
    end
    return out
end
local function Outside(spans, cut)
    local sum = 0
    for k = 1, #spans, 2 do
        local a, z = spans[k], spans[k + 1]
        local left = z - a
        for j = 1, #cut, 2 do
            local x, y = max(a, cut[j]), min(z, cut[j + 1])
            if y > x then left = left - (y - x) end
        end
        sum = sum + max(0, left)
    end
    return sum
end
local function Clip(list, from, to)
    local out = {}
    for k = 1, #list, 2 do
        local a, z = max(from, list[k]), min(to, list[k + 1])
        if z > a then
            out[#out + 1] = a
            out[#out + 1] = z
        end
    end
    return Merge(out)
end
local function Dead(st, p)
    local raw = st.spans[p.name] or {}
    local open = st.open[p.name]
    local list = {}
    for k = 1, #p.deathAt do
        local t = p.deathAt[k]
        local till
        for j = 1, #raw, 2 do
            if math.abs(raw[j] - t) < SAME_DEATH then till = raw[j + 1] end
        end
        if not till and open and math.abs(open - t) < SAME_DEATH then till = st.to end
        list[#list + 1] = t
        list[#list + 1] = till or st.to
    end
    return list
end
local function Carried(s, p, from)
    local list = {}
    for i = 1, #s.badges do
        local bd = s.badges[i]
        local stat = bd.kind == "vehicle" and bd.carry and p.badges[i]
        if stat and stat.outs then
            for k = 1, #stat.times do
                list[#list + 1] = from + stat.times[k]
                list[#list + 1] = from + (stat.outs[k] or stat.times[k])
            end
        end
    end
    return list
end
local function Controlled(p)
    local list = {}
    for k = 1, #(p.ctl or {}) do
        local c = p.ctl[k]
        list[#list + 1] = c.t
        list[#list + 1] = c.to or c.t
    end
    return list
end
local function Union(a, b)
    local list = {}
    for k = 1, #a do list[#list + 1] = a[k] end
    for k = 1, #b do list[#list + 1] = b[k] end
    return Merge(list)
end
local function Sec(v)
    local r = floor(v + 0.5)
    return r > 0 and r or nil
end
function Eff.Finish(st, s)
    local from, to = st.from, st.to
    for i = 1, #s.players do
        local p = s.players[i]
        local dead = Clip(Dead(st, p), from, to)
        local veh = Clip(Carried(s, p, from), from, to)
        local mc = Clip(Controlled(p), from, to)
        local lost = { dead = Sec(Outside(dead, {})), veh = Sec(Outside(veh, dead)), mc = Sec(Outside(mc, Union(dead, veh))) }
        local all = (lost.dead or 0) + (lost.veh or 0) + (lost.mc or 0)
        p.eff = max(0, floor(to - from + 0.5) - all)
        p.lost = all > 0 and lost or nil
    end
end
