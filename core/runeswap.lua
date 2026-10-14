local _, ns = ...
local floor = math.floor
local abs = math.abs
local RS = {}
ns.RuneSwap = RS
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_MISSED = true, SPELL_DAMAGE = true,
               SPELL_HEAL = true, SWING_DAMAGE = true, SWING_MISSED = true, UNIT_DIED = true }
local SAME = 0.05
function RS.Begin(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "runeswap" then
            local hitIds = ns.SpellSet(bd.hits, nil, true)
            return { s = s, from = fight.from, to = fight.to, i = i, late = bd.late or 3, aura = bd.id,
                     hitIds = hitIds, eps = {}, healAmt = 0, subs = SUBS }
        end
    end
    return nil
end
local function Close(st, r, ts)
    local ep = r and r.ep
    if not ep then return end
    r.ep = nil
    ep.b = ts
    if ep.who and ts - ep.a > st.late then
        ep.on = r.who
        st.eps[#st.eps + 1] = ep
    end
end
local function Open(r, ts, who)
    r.ep = { a = ts, who = who, hits = 0, heal = 0 }
end
local function Target(st, ts, name)
    local r = st.cur
    if not name or not r or not r.live then
        st.on = name
        return
    end
    if name == r.who then
        if not r.ep and st.on ~= r.who then Open(r, ts, st.on) end
    elseif r.ep then
        if r.first then r.ep.who = name end
        r.first = false
        Close(st, r, ts)
    end
    st.on = name
end
local function Healed(ep, amt)
    if ep then ep.heal = ep.heal + amt end
end
local function Hit(st, ts, sub, dstName, a4, a5)
    if sub == "SPELL_DAMAGE" then
        local r = st.cur
        local ep = r and r.who == dstName and r.ep or nil
        if not ep then
            local pre = st.pre
            if not (pre and pre.who == dstName and ts - pre.a <= SAME) then
                pre = { a = ts, who = dstName, hits = 0, heal = 0 }
                st.pre = pre
            end
            ep = pre
        end
        ep.hits = ep.hits + 1
        st.hitAt, st.hitEp = ts, ep
        if st.healAt and abs(ts - st.healAt) <= SAME then
            Healed(ep, st.healAmt)
            st.healAt, st.hitAt = nil, nil
        end
        return
    end
    local amt = (tonumber(a4) or 0) - (tonumber(a5) or 0)
    if amt < 0 then amt = 0 end
    if st.hitAt and abs(ts - st.hitAt) <= SAME then
        Healed(st.hitEp, amt)
        st.hitAt, st.healAt = nil, nil
    else
        st.healAt, st.healAmt = ts, amt
    end
end
function RS.Feed(st, ts, sub, srcGUID, srcName, dstGUID, dstName, a1, a4, a5)
    if ts < st.from or ts > st.to then return end
    local id = tonumber(a1)
    if id == st.aura and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_MISSED") and srcGUID then
        st.boss = srcGUID
        if not dstName then return end
        local prev = st.cur
        Close(st, prev, ts)
        local r = { who = dstName, prev = prev and prev.who ~= dstName and prev.who or nil, live = sub ~= "SPELL_MISSED",
                    first = true }
        st.cur = r
        if r.live then
            Open(r, ts, r.prev)
            st.on = dstName
            local pre = st.pre
            if pre and pre.who == dstName and ts - pre.a <= SAME then
                r.ep.hits, r.ep.heal = pre.hits, pre.heal
                if st.hitEp == pre then st.hitEp = r.ep end
            end
        end
        st.pre = nil
        return
    end
    if id == st.aura and sub == "SPELL_AURA_REMOVED" then
        local r = st.cur
        if r and r.who == dstName then
            Close(st, r, ts)
            r.live = false
        end
        return
    end
    if sub == "UNIT_DIED" then
        local r = st.cur
        if r and r.who == dstName then Close(st, r, ts) end
        return
    end
    if id and st.hitIds[id] and srcGUID and (sub == "SPELL_DAMAGE" or sub == "SPELL_HEAL") then
        st.boss = st.boss or srcGUID
        if srcGUID == st.boss then Hit(st, ts, sub, dstName, a4, a5) end
        return
    end
    if not st.boss then return end
    if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
        if srcGUID == st.boss then Target(st, ts, dstName) end
        return
    end
    if sub == "SPELL_AURA_APPLIED" then
        if dstGUID == st.boss and id and ns.taunts and ns.taunts[id] then
            Target(st, ts, srcName)
        end
        return
    end
end
local function Tenth(v)
    return floor(v * 10 + 0.5) / 10
end
function RS.Finish(st)
    Close(st, st.cur, st.to)
    local s, i = st.s, st.i
    for k = 1, #st.eps do
        local ep = st.eps[k]
        local p = s.byName[ep.who]
        local c = p and p.badges[i]
        if c then
            local n = c.n + 1
            c.n = n
            c.times[n] = Tenth(ep.a - st.from)
            c.dur = c.dur or {}
            c.rh = c.rh or {}
            c.heal = c.heal or {}
            c.bearer = c.bearer or {}
            c.dur[n], c.rh[n], c.heal[n], c.bearer[n] = Tenth(ep.b - ep.a), ep.hits, floor(ep.heal + 0.5), ep.on
            c.hits = c.hits + ep.hits
            c.amount = c.amount + floor(ep.heal + 0.5)
            c.grade = "yellow"
            c.lim = st.late
            s.icons[i] = s.icons[i] or s.badges[i].id
        end
    end
end
function RS.StatOf(s, p)
    for i = 1, #s.badges do
        if s.badges[i].kind == "runeswap" then return p.badges[i] end
    end
    return nil
end
