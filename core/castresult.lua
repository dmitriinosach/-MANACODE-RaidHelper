local _, ns = ...
local WINDOW = 1.5
local EARLY = 0.3
local FOLLOW = 6
local FOLLOW_MAX = 20
local FOLLOW_MOBS = 3
local DMG, HEAL, MISS, APPLY, REFRESH, REMOVE, DISPEL, KICK = 1, 2, 3, 4, 5, 6, 7, 8
local KIND = {
    SPELL_DAMAGE = DMG, SPELL_PERIODIC_DAMAGE = DMG, RANGE_DAMAGE = DMG,
    SPELL_HEAL = HEAL, SPELL_PERIODIC_HEAL = HEAL,
    SPELL_MISSED = MISS, SPELL_PERIODIC_MISSED = MISS, RANGE_MISSED = MISS,
    SPELL_AURA_APPLIED = APPLY, SPELL_AURA_REFRESH = REFRESH, SPELL_AURA_APPLIED_DOSE = REFRESH,
    SPELL_AURA_REMOVED = REMOVE, SPELL_AURA_BROKEN = REMOVE, SPELL_AURA_BROKEN_SPELL = REMOVE,
    SPELL_DISPEL = DISPEL, SPELL_STOLEN = DISPEL,
    SPELL_INTERRUPT = KICK,
}
local CastResult = {}
ns.CastResult = CastResult
CastResult.WINDOW = WINDOW
CastResult.FOLLOW = FOLLOW
function CastResult.New(who)
    local data = ns.replayData
    return { who = who, taunts = data and data.taunts or {}, last = {}, early = {}, open = {}, tauntList = {} }
end
local function TargetOf(res, guid, dst)
    local key = guid or dst or "?"
    local tg = res.by[key]
    if not tg then
        tg = { name = dst, guid = guid, dmg = 0, heal = 0, over = 0, n = 0, crit = 0 }
        res.by[key] = tg
        res.list[#res.list + 1] = tg
    end
    return tg
end
local function Apply(c, it, t, kind, guid, dst, a4, a5, crit)
    local res = it.res
    if not res then
        res = { list = {}, by = {} }
        it.res = res
    end
    local tg = TargetOf(res, guid, dst)
    if kind == DMG then
        tg.dmg = tg.dmg + (tonumber(a4) or 0)
        tg.n = tg.n + 1
        if crit then tg.crit = tg.crit + 1 end
    elseif kind == HEAL then
        tg.heal = tg.heal + (tonumber(a4) or 0)
        tg.over = tg.over + (tonumber(a5) or 0)
        tg.n = tg.n + 1
        if crit then tg.crit = tg.crit + 1 end
    elseif kind == MISS then
        local miss = tg.miss or {}
        tg.miss = miss
        local how = tostring(a4 or "MISS")
        miss[how] = (miss[how] or 0) + 1
    elseif kind == APPLY or (kind == REFRESH and not tg.aura) then
        tg.aura, tg.auraAt, tg.auraTo = it.label, t, nil
        tg.refresh = kind == REFRESH or nil
        local byName = c.open[it.label]
        if not byName then
            byName = {}
            c.open[it.label] = byName
        end
        local slot = guid or dst or "?"
        local old = byName[slot]
        if old and old ~= tg and not old.auraTo then old.auraTo = t end
        byName[slot] = tg
    elseif kind == DISPEL then
        tg.dispel = a5 and tostring(a5) or tg.dispel
    elseif kind == KICK then
        tg.kick = a5 and tostring(a5) or tg.kick
    end
end
local function Yes(v)
    return v ~= nil and v ~= false and v ~= 0 and v ~= "nil"
end
function CastResult.Cast(c, it, dst)
    local key = it.label
    it.dst = dst
    c.last[key] = it
    if c.taunts[key] then
        it.taunt = true
        c.tauntList[#c.tauntList + 1] = it
    end
    local early = c.early[key]
    if not early then return end
    for i = 1, #early do
        local e = early[i]
        if it.t - e.t <= EARLY then Apply(c, it, e.t, e.kind, e.guid, e.dst, e.a4, e.a5, e.crit) end
    end
    c.early[key] = nil
end
function CastResult.Feed(c, ts, sub, srcName, dstGUID, dstName, a1, a2, a4, a5, a7, a10)
    local kind = KIND[sub]
    if not kind then return end
    local key = tostring(a2 or a1)
    if kind == REMOVE then
        local byName = c.open[key]
        local slot = dstGUID or dstName or "?"
        local tg = byName and byName[slot]
        if tg then
            tg.auraTo = ts
            byName[slot] = nil
        end
        return
    end
    if srcName ~= c.who then return end
    local crit = (kind == DMG and Yes(a10)) or (kind == HEAL and Yes(a7))
    local it = c.last[key]
    if it and ts - it.t <= WINDOW and ts >= it.t - EARLY then
        Apply(c, it, ts, kind, dstGUID, dstName, a4, a5, crit)
        return
    end
    local early = c.early[key]
    if not early then
        early = {}
        c.early[key] = early
    end
    local n = #early
    if n > 0 and ts - early[1].t > EARLY then
        local keep = 0
        for i = 1, n do
            if ts - early[i].t <= EARLY then
                keep = keep + 1
                early[keep] = early[i]
            end
        end
        for i = keep + 1, n do early[i] = nil end
        n = keep
    end
    early[n + 1] = { t = ts, kind = kind, guid = dstGUID, dst = dstName, a4 = a4, a5 = a5, crit = crit }
end
local function Follow(idx, guid, who, t0, off)
    local stop = math.min(t0 + FOLLOW_MAX, math.max(t0, off or t0) + FOLLOW)
    local out = { stop = stop - t0 }
    local list = idx.swings
    local total = #list
    local k = ns.Index.Seek(idx, list, t0)
    while k <= total do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, list[k])
        local ts, sub, srcGUID, _, _, _, dstName, _, a1 = ns.Store.Decode(seg, s, at, 1)
        if ts and ts > stop then break end
        if ts and srcGUID == guid then
            local hit = { who = dstName, dt = ts - t0 }
            if sub == "SWING_DAMAGE" then hit.amount = tonumber(a1) or 0 else hit.miss = tostring(a1 or "MISS") end
            if not out.first then out.first = hit end
            if dstName ~= who then
                out.away = hit
                break
            end
        end
        k = k + 1
    end
    return out
end
function CastResult.Finish(c, idx)
    c.open, c.early, c.last = {}, {}, {}
    if not (idx and idx.swings) then return end
    for i = 1, #c.tauntList do
        local it = c.tauntList[i]
        local res = it.res
        local mobs = 0
        for k = 1, res and #res.list or 0 do
            local tg = res.list[k]
            if mobs < FOLLOW_MOBS and tg.guid and (tg.aura or tg.miss) then
                mobs = mobs + 1
                tg.follow = Follow(idx, tg.guid, c.who, it.t, tg.auraTo)
            end
        end
    end
end
