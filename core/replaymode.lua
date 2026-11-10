local _, ns = ...
local floor = math.floor
local tonumber = tonumber
local format = string.format
local tsort = table.sort
local huge = math.huge
local SWING_ICON = 6603
local MO = {}
ns.ReplayMode = MO
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local DMG = { SWING_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true }
MO.SUBS = { SPELL_CAST_SUCCESS = true }
for sub in pairs(HEAL) do MO.SUBS[sub] = true end
for sub in pairs(DMG) do MO.SUBS[sub] = true end
local function List()
    return { T = {}, K = {}, I = {}, A = {}, S = {}, F = {}, i = 1 }
end
local function Push(l, t, k, id, a, s, f)
    local n = #l.T + 1
    l.T[n], l.K[n], l.I[n], l.A[n], l.S[n], l.F[n] = t, k, id, a, s or false, f or false
end
local function Of(map, k)
    local l = map[k]
    if not l then
        l = List()
        map[k] = l
    end
    return l
end
function MO.New(scene)
    local D = ns.replayModes
    return { names = ns.Replay.ByK(scene), heal = {}, hit = {}, act = {}, big = List(),
             hitMin = D.hitMin, bigHit = D.bigHit }
end
function MO.Event(c, ts, sub, src, dst, a1, a2, a4, a5)
    local names = c.names
    if HEAL[sub] then
        local k, d = src and names[src], dst and names[dst]
        if not (k and d) then return end
        local a = (tonumber(a4) or 0) - (tonumber(a5) or 0)
        if a > 0 then Push(Of(c.heal, k), ts, d, tonumber(a1) or 0, a, a2) end
    elseif DMG[sub] then
        local d = dst and names[dst]
        if not d or (src and names[src]) then return end
        local swing = sub == "SWING_DAMAGE"
        local a = tonumber(swing and a1 or a4) or 0
        if a < c.hitMin then return end
        local id = swing and 0 or tonumber(a1) or 0
        local name = not swing and a2 or false
        Push(Of(c.hit, d), ts, 0, id, a, name, src)
        if a >= c.bigHit then Push(c.big, ts, d, id, a, name, src) end
    elseif sub == "SPELL_CAST_SUCCESS" then
        local k = src and names[src]
        if k then Push(Of(c.act, k), ts, dst and names[dst] or 0, tonumber(a1) or 0, 0, a2, dst) end
    end
end
function MO.Done(c, L)
    local out = { heal = c.heal, hit = c.hit, act = c.act, big = c.big }
    L.mode = out
    return out
end
function MO.Def(key)
    local D = ns.replayModes
    return D.modes[key or ""] or D.modes.normal
end
function MO.Role(roles, name)
    local r = roles[name]
    if r == "tank" or r == "heal" then return r end
    return "dd"
end
function MO.Active(def, focus, roles)
    return def.pick ~= nil and focus ~= nil and MO.Role(roles, focus) == def.pick
end
local function Seek(l, t)
    local T = l.T
    local n = #T
    if n == 0 or t < T[1] then return 0 end
    local i = l.i
    if i < 1 or i > n then i = 1 end
    if T[i] <= t and (i == n or T[i + 1] > t) then return i end
    if i < n and T[i + 1] <= t and (i + 1 == n or T[i + 2] > t) then
        l.i = i + 1
        return i + 1
    end
    local lo, hi = 1, n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if T[mid] <= t then lo = mid else hi = mid - 1 end
    end
    l.i = lo
    return lo
end
MO.Seek = Seek
function MO.Healed(M, k, t, win, out)
    for d in pairs(out) do out[d] = nil end
    local l = M and M.heal[k]
    if not l then return 0 end
    local n = 0
    local lo = t - win
    for i = Seek(l, t), 1, -1 do
        if l.T[i] <= lo then break end
        local d = l.K[i]
        if not out[d] then
            out[d] = true
            n = n + 1
        end
    end
    return n
end
function MO.Alpha(def, scene, roles, fk, healed, A)
    local alpha = def.alpha or {}
    local tracks = scene.tracks
    for k = 1, #tracks do
        local a
        if k == fk then
            a = alpha.focus
        elseif healed[k] then
            a = alpha.healed
        end
        a = a or alpha[MO.Role(roles, tracks[k].name)] or 1
        A[k] = a
    end
end
local function Rows(rows, l, from, kind, merge, Text)
    local T, I, K, A, S = l.T, l.I, l.K, l.A, l.S
    local open, cnt, sum = nil, 0, 0
    local function Flush()
        if not open then return end
        local text, who, imp = Text(open, cnt, sum)
        rows[#rows + 1] = { t = T[open] - from, kind = kind, icon = I[open] == 0 and SWING_ICON or I[open], text = text,
                            tip = text, who = who, imp = imp }
    end
    for i = 1, #T do
        if open and I[i] == I[open] and K[i] == K[open] and S[i] == S[open] and T[i] - T[open] <= merge then
            cnt, sum = cnt + 1, sum + A[i]
        else
            Flush()
            open, cnt, sum = i, 1, A[i]
        end
    end
    Flush()
end
local function Thin(rows, limit)
    local n = #rows
    if n <= limit then return end
    local must = 0
    for r = 1, n do
        if rows[r].src or rows[r].imp then must = must + 1 end
    end
    local rest = n - must
    local room = limit - must
    local step = room > 0 and rest / room or huge
    local w, seen, next = 0, 0, 0
    for r = 1, n do
        local row = rows[r]
        local keep = row.src or row.imp
        if not keep then
            seen = seen + 1
            if seen > next then
                keep = true
                next = next + step
            end
        end
        if keep and w < limit then
            w = w + 1
            rows[w] = row
        end
    end
    for r = w + 1, n do rows[r] = nil end
end
local function Spell(id, s)
    if id == 0 then return ns.T("rep.mode.melee") end
    return s or ns.SpellName(id) or tostring(id)
end
local function Times(base, n)
    if n > 1 then return format(ns.T("rep.mode.times"), base, n) end
    return base
end
function MO.Feed(L, def, scene, roles, focus)
    local D = ns.replayModes
    local fe = def.feed or { kinds = {} }
    local M = L.mode
    local from = scene.fight.from
    local tracks = scene.tracks
    local fk = 0
    for k = 1, #tracks do
        if tracks[k].name == focus then fk = k end
    end
    local rows = {}
    for i = 1, L.nf or 0 do
        local want = fe.kinds[L.fdKind[i] or "boss"]
        local who = L.fdWho[i]
        if want == "tank" then want = who and MO.Role(roles, who) == "tank" or false end
        if want then rows[#rows + 1] = { src = i, t = L.fdT[i] } end
    end
    local merge = D.merge
    local Short = ns.Short
    local function Name(k) return k > 0 and tracks[k] and tracks[k].name or "?" end
    if M and fe.heals and M.heal[fk] then
        local l = M.heal[fk]
        Rows(rows, l, from, "mheal", merge, function(i, n, sum)
            return format(ns.T("rep.mode.heal"), Times(Spell(l.I[i], l.S[i]), n), Name(l.K[i]), Short(sum)), focus, false
        end)
    end
    if M and fe.big then
        local l = M.big
        Rows(rows, l, from, "mbig", merge, function(i, n, sum)
            return format(ns.T("rep.mode.heal"), Times(Spell(l.I[i], l.S[i]), n), Name(l.K[i]), Short(sum)), Name(l.K[i]), true
        end)
    end
    if M and fe.own and M.act[fk] then
        local l = M.act[fk]
        Rows(rows, l, from, "mown", merge, function(i, n)
            local base = Times(Spell(l.I[i], l.S[i]), n)
            local to = l.F[i]
            if to and to ~= focus then return format(ns.T("rep.f.on"), base, to), focus, false end
            return base, focus, false
        end)
    end
    if M and fe.taken and M.hit[fk] then
        local l = M.hit[fk]
        local big = D.bigHit
        Rows(rows, l, from, "mtaken", merge, function(i, n, sum)
            return format(ns.T("rep.mode.taken"), Times(Spell(l.I[i], l.S[i]), n), Short(sum)), focus, sum >= big
        end)
    end
    tsort(rows, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return (a.src or 1e9) < (b.src or 1e9)
    end)
    Thin(rows, D.rows)
    local out = { fdT = {}, fdIcon = {}, fdText = {}, fdImp = {}, fdKind = {}, fdTip = {}, fdWho = {}, fdLane = {},
                  fdAll = {}, fdAction = {}, mode = def.key }
    local n = 0
    for r = 1, #rows do
        n = n + 1
        local row = rows[r]
        local i = row.src
        if i then
            out.fdT[n], out.fdIcon[n], out.fdText[n], out.fdImp[n], out.fdKind[n] = L.fdT[i], L.fdIcon[i], L.fdText[i],
                L.fdImp[i], L.fdKind[i]
            out.fdTip[n], out.fdWho[n], out.fdLane[n] = L.fdTip and L.fdTip[i] or L.fdText[i], L.fdWho[i], L.fdLane[i]
            if L.fdAll and L.fdAll[i] then out.fdAll[n] = L.fdAll[i] end
            if L.fdAction and L.fdAction[i] then out.fdAction[n] = L.fdAction[i] end
        else
            out.fdT[n], out.fdIcon[n], out.fdText[n], out.fdImp[n], out.fdKind[n] = row.t, row.icon, row.text, row.imp,
                row.kind
            out.fdTip[n], out.fdWho[n], out.fdLane[n] = row.tip, row.who, row.who
        end
    end
    out.nf = n
    return out
end
