local _, ns = ...
local band = bit.band
local max = math.max
local F_PLAYER = 0x400
local IDLE = 10
local MELEE = 6603
local MELEE_KEY = "#melee"
local Totals = {}
ns.Totals = Totals
Totals.MELEE = MELEE
Totals.MELEE_KEY = MELEE_KEY
function Totals.Begin(byName, owners, pets, fight, lines)
    return { m = ns.Absorbs.New(lines), byName = byName, owners = owners, pets = pets,
             from = fight.from, to = fight.to, last = fight.from, idle = 0, gaps = {} }
end
local function Caster(t, guid, name, flags)
    if name and t.byName[name] and flags and band(flags, F_PLAYER) > 0 then return name end
    local owner = guid and (t.owners[guid] or t.pets[guid])
    if owner and t.byName[owner] then return owner end
    return nil
end
function Totals.Aura(t, ts, sub, srcGUID, srcName, srcFlags, dstName, id, spell)
    if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REFRESH" and sub ~= "SPELL_AURA_REMOVED" then return end
    if not dstName or not t.byName[dstName] then return end
    local sid = tonumber(id)
    if not ns.Absorbs.Known(sid) then return end
    local caster = Caster(t, srcGUID, srcName, srcFlags)
    if not caster then return end
    ns.Absorbs.Aura(t.m, ts, sub == "SPELL_AURA_REMOVED", caster, dstName, sid, type(spell) == "string" and spell or nil)
end
function Totals.Absorbed(t, ts, dstName, school, amount, absorbed)
    if absorbed > 0 then ns.Absorbs.Hit(t.m, ts, dstName, tonumber(school) or 1, amount, absorbed) end
end
function Totals.Healed(t, ts, srcName, dstName, amount)
    if srcName then ns.Absorbs.Heal(t.m, ts, srcName, dstName, tonumber(amount) or 0) end
end
function Totals.Act(t, ts, sub)
    if sub == "SPELL_PERIODIC_DAMAGE" then return end
    t.seen = true
    local gap = ts - t.last
    if gap > IDLE then
        t.idle = t.idle + gap
        local g = t.gaps
        g[#g + 1] = t.last - t.from
        g[#g + 1] = ts - t.from
    end
    if ts > t.last then t.last = ts end
end
local function Row(list, key, id)
    local r = list[key]
    if not r then
        r = { id = id, a = 0, n = 0, c = 0 }
        list[key] = r
    end
    return r
end
function Totals.Damage(p, pet, srcName, swing, id, spell, amount, crit)
    local r
    if pet then
        r = Row(p.petBy, srcName or "?", swing and MELEE or tonumber(id))
        if r.id == MELEE and not swing then r.id = tonumber(id) end
    elseif swing then
        r = Row(p.dmgBy, MELEE_KEY, MELEE)
    else
        r = Row(p.dmgBy, type(spell) == "string" and spell or tostring(id), tonumber(id))
    end
    r.a = r.a + amount
    r.n = r.n + 1
    if crit then r.c = r.c + 1 end
end
function Totals.Heal(p, id, spell, amount, crit)
    local r = Row(p.healBy, type(spell) == "string" and spell or tostring(id), tonumber(id))
    if amount > 0 then r.a = r.a + amount end
    r.n = r.n + 1
    if crit then r.c = r.c + 1 end
end
function Totals.Finish(t, s)
    local m = t.m
    for src, amount in pairs(m.by) do
        local p = t.byName[src]
        if p then
            p.absorb = p.absorb + amount
            p.heal = p.heal + amount
            for id, c in pairs(m.spells[src] or {}) do
                local r = Row(p.healBy, ns.Absorbs.Name(m, id), id)
                r.a = r.a + c.a
                r.n = r.n + c.n
            end
        end
    end
    local tail = t.to - t.last
    local idle = t.idle
    if not t.seen then
        idle, tail = 0, 0
    end
    if tail > IDLE then
        idle = idle + tail
        t.gaps[#t.gaps + 1] = t.last - t.from
        t.gaps[#t.gaps + 1] = t.to - t.from
    end
    s.idle = t.gaps
    s.combat = max(1, (t.to - t.from) - idle)
end
function Totals.Time(s)
    return s.dur
end
function Totals.Active(s)
    return s.combat or s.dur
end
