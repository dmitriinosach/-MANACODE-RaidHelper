local _, ns = ...
local floor = math.floor
local abs = math.abs
local LINK = 0.5
local END_SLACK = 1
local DEATH_NEAR = 2
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
        local key = ns.SpellKey(e.spell)
        for i = 1, s.own do
            local bd = s.badges[i]
            if key and bd.kind == "stack" and ns.SpellKey(bd.spell) == key and not idx[key] then
                idx[key] = i
                any = true
            end
        end
        if key then over[key] = e.over end
    end
    if not any then return nil end
    local lost = {}
    for i = 1, s.own do
        local bd = s.badges[i]
        local key = bd.kind == "lost" and ns.SpellKey(bd.spell)
        if key and idx[key] then lost[key] = i end
    end
    return { from = fight.from, to = fight.to, idx = idx, over = over, lap = list.lap, byName = s.byName,
             open = {}, last = {}, immune = {}, eps = {}, subs = StackEps.subs, lost = lost, orphan = {} }
end
local function Orphan(r, ts, who, spell)
    local key = who .. SEP .. spell
    local c = r.last[key]
    if c and abs(ts - c.t) <= LINK then return end
    local list = r.orphan[key]
    if not list then
        list = {}
        r.orphan[key] = list
    end
    local prev = list[#list]
    if prev and ts - prev <= LINK then return end
    list[#list + 1] = ts
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
    elseif r.lost[spell] then
        Orphan(r, ts, who, spell)
    end
end
local function Died(r, ts, who)
    Relabel(r, ts, who, nil, "died")
    for sp in pairs(r.idx) do Close(r, ts, who, sp, "died") end
end
function StackEps.Feed(r, ts, sub, src, dst, a1, a2, a5, sk, a4)
    if ts < r.from or ts > r.to then return end
    if AURA[sub] then
        if not dst or not r.byName[dst] or not sk then return end
        if r.idx[sk] then
            Aura(r, ts, sub, dst, sk, tonumber(a5))
        elseif sub == "SPELL_AURA_APPLIED" and ns.immunities and ns.immunities[sk] then
            local im = { t = ts, spell = a2, by = src }
            r.immune[dst] = im
            local how, by = ImmuneHow(im, dst)
            Relabel(r, ts, dst, nil, how, by)
        end
    elseif sub == "FW_STACK" then
        local fk = ns.StackKey(a1)
        if src and fk and r.idx[fk] and r.byName[src] then Set(r, ts, src, fk, tonumber(a2) or 0) end
    elseif sub == "SPELL_DISPEL" or sub == "SPELL_STOLEN" then
        local xk = ns.SpellKey(a4)
        if dst and xk and r.idx[xk] and r.byName[dst] then
            local key = dst .. SEP .. xk
            if r.open[key] then
                Close(r, ts, dst, xk, "disp", src)
            else
                Relabel(r, ts, dst, xk, "disp", src)
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
        if who and o then Close(r, r.to, who, tonumber(spell) or spell, "end") end
    end
    local res = s.phases
    for key, list in pairs(r.eps) do
        local who, spell = key:match("^(.-)" .. SEP .. "(.*)$")
        spell = spell and (tonumber(spell) or spell)
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
    if next(r.lost) then StackEps.Lost(r, s) end
end
local function NearDeath(p, t)
    for k = 1, #(p.deathInfo or {}) do
        if abs(p.deathInfo[k].t - t) <= DEATH_NEAR then return true end
    end
    return false
end
function StackEps.Lost(r, s)
    local found = {}
    for key, list in pairs(r.eps) do
        local who, spell = key:match("^(.-)" .. SEP .. "(.*)$")
        spell = spell and (tonumber(spell) or spell)
        if spell and r.lost[spell] then
            for k = 1, #list do
                local ep = list[k]
                if ep.e == "fade" then found[#found + 1] = { who = who, spell = spell, t = ep.t + ep.d, n = ep.pk } end
            end
        end
    end
    for key, list in pairs(r.orphan) do
        local who, spell = key:match("^(.-)" .. SEP .. "(.*)$")
        spell = spell and (tonumber(spell) or spell)
        for k = 1, #list do found[#found + 1] = { who = who, spell = spell, t = Round(list[k] - r.from), n = 0 } end
    end
    table.sort(found, function(a, b) return a.t < b.t end)
    local cut = {}
    for spell, i in pairs(r.lost) do
        local c = r.to - r.from - END_SLACK
        local stop = s.badges[i].stop
        for k = 1, #((s.phases and s.phases.spans) or {}) do
            local sp = s.phases.spans[k]
            if stop and sp.label == stop and sp.from < c then c = sp.from end
        end
        cut[spell] = c
        if s.icons then s.icons[i] = s.icons[i] or s.badges[i].id end
    end
    for k = 1, #found do
        local f = found[k]
        local i = r.lost[f.spell]
        local p = r.byName[f.who]
        local st = p and p.badges[i]
        if st and f.t < cut[f.spell] and not NearDeath(p, r.from + f.t) then
            st.n = st.n + 1
            st.times[#st.times + 1] = f.t
            st.lost = st.lost or {}
            st.lost[#st.lost + 1] = { t = f.t, n = f.n }
        end
    end
end
