local _, ns = ...
local band = bit.band
local find = string.find
local ceil = math.ceil
local floor = math.floor
local tsort = table.sort
local F_PLAYER = 0x400
local F_HOSTILE = 0x40
local F_BY_PLAYER = 0x100
local F_PETS = 0x3000
local F_OURS = 0x7
local AFTER = 10
local SHARE_WINDOW = 5
local SHARE = 0.5
local REACT = 2
local WPN_LATE = 3
local MIN_OWN = 20
local HI = 1.3
local LO = 0.8
local GAP_MIN = 0.5
local GAP_MAX = 4
local DUAL_GAP = 1
local SLOW_GAP = 1.6
local SLOW_TEMPO = 0.8
local DUAL_HITS = 4
local TOL = 0.05
local RANK = { red = 3, yellow = 2, green = 1 }
local GAINED = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_APPLIED_DOSE = true }
local Ctl = {}
ns.MindCtl = Ctl
local function On(v)
    return v ~= nil and v ~= false and v ~= 0
end
local function Pick(list, q)
    local n = #list
    if n == 0 then return nil end
    local copy = {}
    for i = 1, n do copy[i] = list[i] end
    tsort(copy)
    if q == 0.5 then
        local mid = floor((n + 1) / 2)
        if n % 2 == 0 then return (copy[mid] + copy[mid + 1]) / 2 end
        return copy[mid]
    end
    return copy[math.max(1, ceil(n * q))]
end
local function Gaps(times, lo, hi)
    local out = {}
    for i = 2, #times do
        local d = times[i] - times[i - 1]
        if d > lo and d <= hi then out[#out + 1] = d end
    end
    return out
end
local function Norm(amount, resisted, blocked, absorbed, crit)
    local v = (tonumber(amount) or 0) + (tonumber(resisted) or 0) + (tonumber(blocked) or 0)
        + (tonumber(absorbed) or 0)
    if On(crit) then v = v / 2 end
    return v
end
function Ctl.Begin(rule, byName, owners, pets)
    return { rule = rule, aura = tonumber(rule.aura), byName = byName, owners = owners, pets = pets,
             who = {}, procOf = {}, open = 0, lastEnd = -AFTER - 1, n = 0,
             lt = {}, ld = {}, lm = {}, la = {}, lsp = {} }
end
local function Who(st, name)
    local w = st.who[name]
    if not w then
        w = { own = {}, ownT = {}, list = {}, dots = {} }
        st.who[name] = w
    end
    return w
end
local function IsProc(st, spell)
    local v = st.procOf[spell]
    if v == nil then
        v = false
        local list = st.rule.procs or {}
        for i = 1, #list do
            if find(spell, list[i], 1, true) then
                v = true
                break
            end
        end
        st.procOf[spell] = v
    end
    return v
end
local function Toggle(st, ts, name, on)
    local w = Who(st, name)
    if on and not w.cur then
        local c = { t = ts, hits = {}, ht = {}, kills = {}, procs = 0, swing = 0, abil = 0 }
        w.list[#w.list + 1] = c
        w.cur = c
        w.dots = {}
        st.open = st.open + 1
    elseif not on and w.cur then
        w.cur.to = ts
        w.cur = nil
        st.open = st.open - 1
        st.lastEnd = ts
    end
end
local function Weapon(st, ts, name, mh, oh, why)
    local w = name and st.who[name]
    local c = w and (w.cur or w.list[#w.list])
    if not c or c.wpn or (c.to and ts - c.to > WPN_LATE) then return end
    if why == nil and mh ~= nil then
        c.wpn = ((tonumber(mh) or 0) > 0 or (tonumber(oh) or 0) > 0) and "on" or "off"
    else
        c.wpn, c.why = "none", why and tostring(why) or nil
    end
end
local function Struck(st, c, w, ts, sub, swing, hurt, a1, a2, a4, a5, a6, a7)
    if swing then
        c.ht[#c.ht + 1] = ts
        if hurt then
            c.hits[#c.hits + 1] = Norm(a1, a4, a5, a6, a7)
            c.swing = c.swing + (tonumber(a1) or 0)
        elseif a1 == "ABSORB" then
            c.hits[#c.hits + 1] = tonumber(a2) or 0
        end
        return
    end
    if hurt then c.abil = c.abil + (tonumber(a4) or 0) end
    if type(a2) ~= "string" or not (hurt or GAINED[sub]) then return end
    if IsProc(st, a2) then c.procs = c.procs + 1 end
    if GAINED[sub] then w.dots[a2] = true end
end
function Ctl.Feed(st, ts, sub, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5, a6, a7, a8)
    local byName = st.byName
    if sub == "FW_WPN" then
        Weapon(st, ts, srcName, a1, a2, a4)
        return
    end
    local dst = dstName and byName[dstName]
    if dst and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED") and tonumber(a1) == st.aura then
        Toggle(st, ts, dstName, sub == "SPELL_AURA_APPLIED")
        return
    end
    local w = srcName and st.who[srcName]
    local c = w and w.cur
    local swing = find(sub, "SWING", 1, true) == 1
    local hurt = find(sub, "_DAMAGE", 1, true) ~= nil
    local ally = dst or (dstGUID ~= nil and (st.owners[dstGUID] or st.pets[dstGUID]) ~= nil)
        or (dstFlags ~= nil and band(dstFlags, F_PETS) > 0 and band(dstFlags, F_BY_PLAYER) > 0
            and band(dstFlags, F_OURS) > 0)
    if c and ally and dstName ~= srcName then
        Struck(st, c, w, ts, sub, swing, hurt, a1, a2, a4, a5, a6, a7)
    elseif c and dstName == srcName and GAINED[sub] and type(a2) == "string" and IsProc(st, a2) then
        c.procs = c.procs + 1
    elseif swing and not c and not ally and srcName and byName[srcName] and srcFlags
        and band(srcFlags, F_PLAYER) > 0 and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
        local me = Who(st, srcName)
        me.ownT[#me.ownT + 1] = ts
        if hurt and not On(a8) then me.own[#me.own + 1] = Norm(a1, a4, a5, a6, a7) end
    end
    if not (dst and hurt) or (st.open == 0 and ts - st.lastEnd > AFTER) then return end
    local mc = false
    if c and srcName ~= dstName then
        mc = srcName
    elseif w and not swing and type(a2) == "string" and w.dots[a2] and #w.list > 0
        and ts - (w.list[#w.list].to or ts) <= AFTER then
        mc = srcName
    end
    local n = st.n + 1
    st.n = n
    st.lt[n] = ts
    st.ld[n] = dstName
    st.lm[n] = mc
    st.la[n] = tonumber(swing and a1 or a4) or 0
    st.lsp[n] = swing and "#melee" or (type(a2) == "string" and a2) or false
end
local function Judge(st, c, base, dual, own, class)
    local n = #c.hits
    if n > 0 and base and base > 0 then c.ratio = Pick(c.hits, 0.5) / base end
    local tempo = Pick(Gaps(c.ht, GAP_MIN, GAP_MAX), 0.5)
    if tempo and own and own > 0 then c.tempo = tempo / own end
    c.dual = dual
    if not c.checked then return end
    local rule = st.rule
    if c.wpn == "on" then
        c.verdict, c.by = "red", "slots"
    elseif c.wpn == "off" then
        c.verdict, c.by = "green", "slots"
    elseif c.procs > 0 then
        c.verdict, c.by = "red", "procs"
    elseif n < 2 or not c.ratio then
        return
    elseif not dual and own and own >= SLOW_GAP and c.tempo and c.tempo < SLOW_TEMPO then
        c.verdict, c.by = "green", "tempo"
    elseif dual and class == "ROGUE" and n >= DUAL_HITS then
        c.verdict, c.by = "green", "poison"
    elseif c.ratio >= (rule.hi or HI) then
        c.verdict, c.by = "red", "hits"
    elseif c.ratio >= (rule.lo or LO) then
        c.verdict, c.by = "yellow", "hits"
    else
        c.verdict, c.by = "green", "hits"
    end
end
local function Upper(lt, n, t)
    local lo, hi = 1, n + 1
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if lt[mid] <= t then lo = mid + 1 else hi = mid end
    end
    return lo - 1
end
local function Blame(st, victim, t)
    local lt, ld, lm, la = st.lt, st.ld, st.lm, st.la
    local top = Upper(lt, st.n, t + TOL)
    local total, last, sums = 0, nil, nil
    for i = top, 1, -1 do
        if lt[i] < t - SHARE_WINDOW then break end
        if ld[i] == victim then
            total = total + la[i]
            last = last or i
            local m = lm[i]
            if m then
                sums = sums or {}
                sums[m] = (sums[m] or 0) + la[i]
            end
        end
    end
    if not sums then return nil end
    local by
    if last and lm[last] and t - lt[last] <= ns.Deaths.KILL_WINDOW then
        by = lm[last]
    else
        local best = 0
        for m, v in pairs(sums) do
            if v > best and v >= total * SHARE then by, best = m, v end
        end
    end
    local w = by and st.who[by]
    if not w then return nil end
    local c
    for i = 1, #w.list do
        local x = w.list[i]
        if x.t <= t + TOL and t <= x.to + AFTER then c = x end
    end
    if not c then return nil end
    local first, hits = nil, 0
    for i = Upper(lt, st.n, c.t - TOL) + 1, top do
        if ld[i] == victim and lm[i] == by then
            first = first or lt[i]
            hits = hits + 1
        end
    end
    if not first then return nil end
    local kill = last ~= nil and lm[last] == by and last or nil
    local gap = t - first
    c.kills[#c.kills + 1] = victim
    return { by = by, ctl = c, gap = gap, hits = hits, one = hits == 1, share = (sums[by] or 0) / math.max(1, total),
             grade = (gap < REACT or hits == 1) and "green" or "yellow",
             spell = kill and st.lsp[kill] or nil, amount = kill and la[kill] or nil, dot = t > c.to }
end
function Ctl.Finish(st, s, till)
    local classes = {}
    for _, cls in ipairs(st.rule.classes or {}) do classes[cls] = true end
    for name, w in pairs(st.who) do
        local p = st.byName[name]
        if p and #w.list > 0 then
            local dual = (Pick(Gaps(w.ownT, 0, GAP_MAX), 0.5) or GAP_MAX) < DUAL_GAP
            local base = Pick(w.own, dual and 0.75 or 0.5)
            local own = Pick(Gaps(w.ownT, GAP_MIN, GAP_MAX), 0.5)
            local checked = classes[p.class or ""] == true and #w.own >= (st.rule.minOwn or MIN_OWN)
            for i = 1, #w.list do
                local c = w.list[i]
                c.to = c.to or till
                c.checked = checked
                Judge(st, c, base, dual, own, p.class)
            end
            p.ctl = w.list
        end
    end
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            d.mc = Blame(st, p.name, d.t)
        end
    end
end
function Ctl.Deaths(p)
    local n, worst = 0, nil
    for k = 1, #(p.deathInfo or {}) do
        local mc = p.deathInfo[k].mc
        if mc then
            n = n + 1
            if worst ~= "yellow" then worst = mc.grade end
        end
    end
    return n, worst
end
function Ctl.Mark(p)
    local list = p.ctl
    if not list then return nil end
    local worst, bad, kills = nil, { red = 0, yellow = 0, green = 0 }, {}
    for i = 1, #list do
        local c = list[i]
        local v = c.verdict
        if v then
            bad[v] = bad[v] + 1
            if not worst or RANK[v] > RANK[worst] then worst = v end
        end
        for k = 1, #c.kills do kills[#kills + 1] = c.kills[k] end
    end
    if bad.red + bad.yellow == 0 and #kills == 0 then return nil end
    local count = bad.red > 0 and bad.red or (bad.yellow > 0 and bad.yellow or #kills)
    return { count = count, verdict = worst, armed = worst ~= nil, kills = kills }
end
