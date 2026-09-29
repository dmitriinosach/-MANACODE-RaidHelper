local _, ns = ...
local band = bit.band
local floor = math.floor
local min = math.min
local abs = math.abs
local find = string.find
local match = string.match
local sub = string.sub
local LEVEL_CAP = 80 * 125
local AEGIS_SHARE = 0.3
local KINGS_SHARE = 0.15
local KINGS_CAP = 20000
local HEAL_FRESH = 0.2
local GONE = 0.1
local MAX_HP_GUESS = 45000
local DEFAULT_AMOUNT = 1000
local HP_BACK = 64
local LOW_HP = 36
local SHARE_TOL = 0.01
local HINTS = 2
local PASSIVE_DUR = 86400
local UNRANKED = 1000
local SOUL_LINK = 25228
local KINGS = 64413
local SHELL = 48707
local ZONE = 51052
local STOICISM = 70845
local NECROPOLIS = 52286
local DEFLECTION = 49497
local SAVAGE = 62606
local ARDENT = 66233
local CHEAT = 31230
local LIGHT_ESSENCE = 65686
local DARK_ESSENCE = 65684
local S_PHYSICAL = 0x01
local S_FIRE = 0x04
local S_FROST = 0x10
local S_SHADOW = 0x20
local Absorbs = {}
ns.Absorbs = Absorbs
local SPELLS = ns.shieldSpells or {}
local PASSIVE = ns.shieldPassive or {}
local EAT = {}
for rank, ids in ipairs(ns.shieldEat or {}) do
    for k = 1, #ids do EAT[ids[k]] = rank end
end
local AEGIS = EAT[47509] or -1
local FROST_WARD = EAT[43012] or -1
local FIRE_WARD = EAT[43010] or -1
local SHADOW_WARD = EAT[47891] or -1
local pSh, pId, pSrc, pAt, pAmount = {}, {}, {}, {}, {}
local order = {}
function Absorbs.Known(id)
    return id ~= nil and SPELLS[id] ~= nil
end
function Absorbs.New(lines)
    return { shields = {}, heals = {}, learned = {}, queued = {}, passive = {}, hints = {}, by = {}, spells = {},
             names = {}, lines = lines, hp = {} }
end
local function HpIn(s, at, needle)
    local stop = find(s, "\n", at, true)
    local line = sub(s, at, stop and stop - 1 or nil)
    local p = find(line, needle, 1, true)
    if not p then return nil, nil end
    local cur, top = match(line, "^%.%d+:(%d+):(%d+)", p)
    local hp, hpMax = tonumber(cur), tonumber(top)
    if hp and hpMax and hpMax > 0 then return hp, hpMax end
    return nil, nil
end
local function Health(m, name)
    local lines = m.lines
    local list = lines and lines.list
    local own = list and list[#list]
    if not own then return ns.Streams.HealthAt(m, name, m.now) end
    local memo = m.hp[name]
    if not memo then
        memo = { i = 0 }
        m.hp[name] = memo
    end
    if memo.own == own then
        if memo.needle then
            for i = memo.i + 1, #own.t do
                local hp, top = HpIn(own.s[i], own.at[i], memo.needle)
                if hp then memo.hp, memo.top = hp, top end
            end
        end
        memo.i = #own.t
        return memo.hp, memo.top
    end
    local id = ns.Store.IdOf(own.seg, name)
    memo.own, memo.i, memo.needle, memo.hp, memo.top = own, #own.t, id and ("." .. id .. ":") or nil, nil, nil
    local left = HP_BACK
    for k = #list, 1, -1 do
        local o = list[k]
        local oid = o == own and id or ns.Store.IdOf(o.seg, name)
        if oid then
            local needle = "." .. oid .. ":"
            for i = #o.t, 1, -1 do
                local hp, top = HpIn(o.s[i], o.at[i], needle)
                if hp then
                    memo.hp, memo.top = hp, top
                    return hp, top
                end
                left = left - 1
                if left <= 0 then return nil, nil end
            end
        end
    end
    return nil, nil
end
local function MaxHp(m, name)
    local _, top = Health(m, name)
    return top or MAX_HP_GUESS
end
local function Slot(m, dst, id, src)
    local byDst = m.shields[dst]
    if not byDst then
        byDst = {}
        m.shields[dst] = byDst
    end
    local byId = byDst[id]
    if not byId then
        byId = {}
        byDst[id] = byId
    end
    local sh = byId[src]
    if not sh then
        sh = { amount = 0, ts = -1, at = 0 }
        byId[src] = sh
    end
    return sh
end
function Absorbs.Aura(m, ts, removed, src, dst, id, name)
    m.now = ts
    local S = SPELLS[id]
    if not S then return end
    if name and not m.names[id] then m.names[id] = name end
    if removed then
        local byDst = m.shields[dst]
        local sh = byDst and byDst[id] and byDst[id][src]
        if sh then sh.ts = ts + GONE end
        return
    end
    local sh = Slot(m, dst, id, src)
    local amount = 0
    local aegis = EAT[id] == AEGIS
    if (aegis or id == KINGS) and ts < sh.ts then amount = sh.amount end
    local byDst = m.heals[dst]
    local h = byDst and byDst[src]
    local fresh = h ~= nil and h.ts > ts - HEAL_FRESH
    if aegis then
        amount = fresh and min(LEVEL_CAP, amount + h.amount * AEGIS_SHARE) or (S.cap or DEFAULT_AMOUNT)
    elseif id == KINGS then
        amount = fresh and min(KINGS_CAP, amount + h.amount * KINGS_SHARE) or (S.cap or DEFAULT_AMOUNT)
    elseif id == SHELL or id == ZONE then
        amount = MaxHp(m, dst) * 0.5
    elseif id == STOICISM then
        amount = MaxHp(m, dst) * 0.2
    elseif S.cap or S.avg then
        local l = m.learned[src] and m.learned[src][id]
        if l then
            sh.amount, sh.ts, sh.at, sh.full = l, ts + S.dur + GONE, ts + GONE, true
            return
        end
        amount = S.avg or S.cap
    else
        amount = DEFAULT_AMOUNT
    end
    sh.amount, sh.ts, sh.at, sh.full = floor(amount), ts + S.dur + GONE, ts + GONE, true
end
function Absorbs.Heal(m, ts, src, dst, amount)
    m.now = ts
    local byDst = m.heals[dst]
    if not byDst then
        byDst = {}
        m.heals[dst] = byDst
    end
    local h = byDst[src]
    if not h then
        h = { ts = ts, amount = amount }
        byDst[src] = h
    else
        h.ts, h.amount = ts, amount
    end
end
local function Credit(m, src, id, amount)
    if amount <= 0 then return end
    m.by[src] = (m.by[src] or 0) + amount
    local list = m.spells[src]
    if not list then
        list = {}
        m.spells[src] = list
    end
    local c = list[id]
    if not c then
        c = { a = 0, n = 0 }
        list[id] = c
    end
    c.a = c.a + amount
    c.n = c.n + 1
end
local function Take(m, dst, v)
    local q = m.queued[dst]
    if q then
        m.queued[dst] = nil
        return v + q
    end
    return v
end
local function Evidence(m, dst, amountHit, absorbed)
    if m.passive[dst] or amountHit <= 0 then return false end
    local class = ns.Encounters.ClassOf(dst)
    local def = class and PASSIVE[class]
    if not def then return false end
    local share = absorbed / (amountHit + absorbed)
    local match = false
    for k = 1, #def.shares do
        if abs(share - def.shares[k]) <= SHARE_TOL then match = true end
    end
    if not match then return false end
    local n = (m.hints[dst] or 0) + 1
    m.hints[dst] = n
    if n < HINTS then return false end
    m.passive[dst] = true
    for id, points in pairs(def.ids) do
        local sh = Slot(m, dst, id, dst)
        sh.amount, sh.ts, sh.at, sh.full = DEFAULT_AMOUNT, math.huge, 0, true
        sh.points = points > 0 and points or nil
    end
    return true
end
local function Skips(id, school)
    local rank = EAT[id]
    if rank == FROST_WARD then return band(school, S_FROST) ~= school end
    if rank == FIRE_WARD then return band(school, S_FIRE) ~= school end
    if rank == SHADOW_WARD then return band(school, S_SHADOW) ~= school end
    if id == SHELL or id == DEFLECTION or id == SAVAGE then return band(school, S_PHYSICAL) == school end
    return false
end
local function Popped(m, byDst, ts, school)
    local n = 0
    for id, sources in pairs(byDst) do
        for src, sh in pairs(sources) do
            if sh.ts > ts then
                if id == LIGHT_ESSENCE and band(school, S_FIRE) == school then return -1 end
                if id == DARK_ESSENCE and band(school, S_SHADOW) == school then return -1 end
                if not Skips(id, school) then
                    n = n + 1
                    pSh[n], pId[n], pSrc[n], pAt[n], pAmount[n] = sh, id, src, sh.at, sh.amount
                end
            end
        end
    end
    return n
end
local function Before(a, b)
    local ra, rb = EAT[pId[a]] or UNRANKED, EAT[pId[b]] or UNRANKED
    if ra ~= rb then return ra < rb end
    return pAt[a] < pAt[b]
end
local function Sort(n)
    for i = 1, n do order[i] = i end
    for i = 2, n do
        local v = order[i]
        local j = i - 1
        while j >= 1 and Before(v, order[j]) do
            order[j + 1] = order[j]
            j = j - 1
        end
        order[j + 1] = v
    end
end
local function Estimate(m, dst, n, total)
    local learned = m.learned
    for i = 1, n do
        local id, src, sh = pId[i], pSrc[i], pSh[i]
        local l = learned[src] and learned[src][id]
        if sh.full and l then
            pAmount[i] = l
        elseif id == NECROPOLIS and sh.points then
            local hp, top = Health(m, dst)
            pAmount[i] = (hp and top and hp * 100 / top <= LOW_HP) and floor(total * 0.05 * sh.points) or 0
        elseif id == DEFLECTION and sh.points then
            pAmount[i] = floor(total * 0.15 * sh.points)
        elseif id == ARDENT and sh.points then
            local hp, top = Health(m, dst)
            pAmount[i] = (hp and top and hp * 100 / top <= LOW_HP) and floor(total * 0.0667 * sh.points) or 0
        elseif id == CHEAT and sh.points then
            pAmount[i] = floor(MaxHp(m, dst) * 0.1)
        elseif id == SOUL_LINK then
            pAmount[i] = floor(total * 0.2)
        end
    end
end
function Absorbs.Hit(m, ts, dst, school, amountHit, absorbed)
    m.now = ts
    if absorbed <= 0 then return end
    local byDst = m.shields[dst]
    local n = byDst and Popped(m, byDst, ts, school) or 0
    if n < 0 then return end
    if n == 0 and Evidence(m, dst, amountHit, absorbed) then
        byDst = m.shields[dst]
        n = Popped(m, byDst, ts, school)
        if n < 0 then return end
    end
    if not byDst then return end
    if n == 0 then
        m.queued[dst] = (m.queued[dst] or 0) + absorbed
        return
    end
    if n == 1 and amountHit > absorbed and pSh[1].full then
        local S = SPELLS[pId[1]]
        if S.cap then
            local src = pSrc[1]
            local l = m.learned[src]
            if not l then
                l = {}
                m.learned[src] = l
            end
            if (not l[pId[1]] or l[pId[1]] < absorbed) and absorbed < S.cap then l[pId[1]] = absorbed end
        end
    end
    Estimate(m, dst, n, amountHit + absorbed)
    Sort(n)
    local last
    for k = 1, n do
        local i = order[k]
        last = i
        local sh = pSh[i]
        local amount = pAmount[i]
        if amount >= absorbed then
            sh.amount = amount - absorbed
            sh.full = nil
            Credit(m, pSrc[i], pId[i], Take(m, dst, absorbed))
            absorbed = 0
            break
        end
        if not sh.points and pId[i] ~= SOUL_LINK then
            sh.ts, sh.amount, sh.full = -1, 0, nil
        end
        Credit(m, pSrc[i], pId[i], Take(m, dst, amount))
        absorbed = absorbed - amount
    end
    if absorbed > 0 and last then Credit(m, pSrc[last], pId[last], Take(m, dst, absorbed)) end
    for k = 1, n do pSh[k] = nil end
end
function Absorbs.Name(m, id)
    local name = m.names[id]
    if name then return name end
    name = GetSpellInfo and GetSpellInfo(id) or nil
    return name or tostring(id)
end
