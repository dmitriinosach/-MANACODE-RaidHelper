local _, ns = ...
local floor = math.floor
local abs = math.abs
local LINK = 0.5
local END_SLACK = 1
local SEP = "\31"
local AURA = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true, SPELL_AURA_REMOVED = true,
}
local StackEps = {}
ns.StackEps = StackEps
StackEps.subs = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_REMOVED = true, SPELL_DISPEL = true, SPELL_STOLEN = true, UNIT_DIED = true, FW_STACK = true,
}
local function Round(v)
    return floor(v * 10 + 0.5) / 10
end
function StackEps.Begin(fight, def, s)
    local list = def.stacks
    if type(list) ~= "table" or not list[1] then return nil end
    local idx, over, any = {}, {}, false
    for k = 1, #list do
        local e = list[k]
        for i = 1, s.own do
            local bd = s.badges[i]
            if bd.kind == "stack" and bd.spell == e.spell and not idx[e.spell] then
                idx[e.spell] = i
                any = true
            end
        end
        over[e.spell] = e.over
    end
    if not any then return nil end
    return { from = fight.from, to = fight.to, idx = idx, over = over, lap = list.lap, byName = s.byName,
             open = {}, last = {}, immune = {}, eps = {}, subs = StackEps.subs }
end
local function Close(r, ts, who, spell, how, by)
    local key = who .. SEP .. spell
    local o = r.open[key]
    if not o then return end
    r.open[key] = nil
    if o.cur == o.pk then o.pd = o.pd + (ts - o.since) end
    local ep = { t = Round(o.at - r.from), d = Round(ts - o.at), pk = o.pk, pd = Round(o.pd), e = how, by = by }
    local list = r.eps[key]
    if not list then
        list = {}
        r.eps[key] = list
    end
    list[#list + 1] = ep
    r.last[key] = { ep = ep, t = ts }
end
local function Set(r, ts, who, spell, n)
    if n <= 0 then
        Close(r, ts, who, spell, "fade")
        return
    end
    local key = who .. SEP .. spell
    local o = r.open[key]
    if not o then
        r.open[key] = { at = ts, cur = n, since = ts, pk = n, pd = 0 }
        return
    end
    if o.cur == o.pk then o.pd = o.pd + (ts - o.since) end
    if n > o.pk then o.pk, o.pd = n, 0 end
    o.cur, o.since = n, ts
end
local function Relabel(r, ts, who, spell, how, by)
    for sp in pairs(r.idx) do
        if not spell or sp == spell then
            local c = r.last[who .. SEP .. sp]
            if c and c.ep.e == "fade" and abs(ts - c.t) <= LINK then
                c.ep.e, c.ep.by = how, by
            end
        end
    end
end
local function ImmuneHow(im, who)
    if im.by and im.by ~= who then return "hand", im.by end
    return "self", im.spell
end
local function Aura(r, ts, sub, who, spell, n)
    local o = r.open[who .. SEP .. spell]
    if sub == "SPELL_AURA_APPLIED" then
        Set(r, ts, who, spell, n or 1)
    elseif sub == "SPELL_AURA_APPLIED_DOSE" then
        Set(r, ts, who, spell, n or ((o and o.cur or 0) + 1))
    elseif sub == "SPELL_AURA_REMOVED_DOSE" then
        Set(r, ts, who, spell, n or ((o and o.cur or 1) - 1))
    elseif o then
        local im = r.immune[who]
        if im and abs(ts - im.t) <= LINK then
            local how, by = ImmuneHow(im, who)
            Close(r, ts, who, spell, how, by)
        else
            Close(r, ts, who, spell, "fade")
        end
    end
end
local function Died(r, ts, who)
    Relabel(r, ts, who, nil, "died")
    for sp in pairs(r.idx) do Close(r, ts, who, sp, "died") end
end
function StackEps.Feed(r, ts, sub, src, dst, a1, a2, a5)
    if ts < r.from or ts > r.to then return end
    if AURA[sub] then
        if not dst or not r.byName[dst] then return end
        if r.idx[a2] then
            Aura(r, ts, sub, dst, a2, tonumber(a5))
        elseif sub == "SPELL_AURA_APPLIED" and ns.immunities and ns.immunities[a2] then
            local im = { t = ts, spell = a2, by = src }
            r.immune[dst] = im
            local how, by = ImmuneHow(im, dst)
            Relabel(r, ts, dst, nil, how, by)
        end
    elseif sub == "FW_STACK" then
        if src and r.idx[a1] and r.byName[src] then Set(r, ts, src, a1, tonumber(a2) or 0) end
    elseif sub == "SPELL_DISPEL" or sub == "SPELL_STOLEN" then
        if dst and r.idx[a5] and r.byName[dst] then
            local key = dst .. SEP .. a5
            if r.open[key] then
                Close(r, ts, dst, a5, "disp", src)
            else
                Relabel(r, ts, dst, a5, "disp", src)
            end
        end
    elseif sub == "UNIT_DIED" then
        if dst and r.byName[dst] then Died(r, ts, dst) end
    end
end
local function Lap(res, lap, ep)
    local from, to = ns.Phases.Span(res, lap.phase)
    local times = res.waves and res.waves[lap.wave]
    if not from or not times then return false end
    local n, total = 0, 0
    for k = 1, #times do
        local t = times[k]
        if t >= from and t <= to then
            total = total + 1
            if t <= ep.t then n = n + 1 end
        end
    end
    if total == 0 then return false end
    if n < total then
        ep.ph, ep.lap = lap.before, total > 1 and n + 1 or nil
    else
        ep.ph, ep.lap = lap.after, total > 1 and n or nil
    end
    return true
end
local function Label(r, res, ep)
    if not res or not res.spans then return end
    local key = ns.Phases.At(res, ep.t)
    if r.lap and key == r.lap.phase and Lap(res, r.lap, ep) then return end
    if #res.spans < 2 then return end
    for k = 1, #res.spans do
        if res.spans[k].key == key then ep.ph = res.spans[k].label end
    end
end
function StackEps.Finish(r, s)
    for key, o in pairs(r.open) do
        local who, spell = key:match("^(.-)" .. SEP .. "(.*)$")
        if who and o then Close(r, r.to, who, spell, "end") end
    end
    local res = s.phases
    for key, list in pairs(r.eps) do
        local who, spell = key:match("^(.-)" .. SEP .. "(.*)$")
        local p = who and r.byName[who]
        local i = spell and r.idx[spell]
        if p and i and p.badges[i] then
            table.sort(list, function(a, b) return a.t < b.t end)
            for k = 1, #list do
                local ep = list[k]
                Label(r, res, ep)
                if ep.e == "fade" and r.to - r.from - ep.t - ep.d <= END_SLACK then ep.e = "end" end
            end
            local st = p.badges[i]
            st.eps = list
            st.over = r.over[spell]
        end
    end
end
