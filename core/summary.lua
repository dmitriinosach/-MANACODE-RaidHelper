local _, ns = ...
local band = bit.band
local tsort = table.sort
local F_PLAYER = 0x400
local F_BY_PLAYER = 0x100
local F_HOSTILE = 0x40
local SKIP_HP = { "FW_HP" }
local MAX_TAIL = 10
local PROGRESS_EVERY = 256
local LEAD = 35
local SHIELD_LEAD = 60
local TAIL = 5
local TANK_SHARE = 0.15
local TAUNT_TAKEN_SHARE = 0.08
local TANK_CASTS = 5
local TANK_TAUNTS = 2
local IMMUNE_WINDOW = 1.5
local SHED_FULL = 20
local SHED_RELINK = 0.3
local SHED_SLACK = 1
local SHED_DEATH = 1
local HIT_GAP = 2
local TOTEM_DISPEL_WINDOW = 0.5
local RECENT = 10
local RIDE_BOUNCE = 1
local SEAT_NEAR = 2
local CAPTURE_WINDOW = 10
local CAPTOR_GAP = 5
local AOE_WINDOW = 0.4
local BIG_RAID = 12
local KEEP = 20
local BURST = 1
local LIVE = { aura = true, ticks = true, stack = true, hit = true, chased = true, applied = true }
local Summary = {}
ns.Summary = Summary
local cache = {}
local order = {}
local running = setmetatable({}, { __mode = "k" })
local function Whole(s)
    return s ~= nil and (s.ach ~= nil or not ns.Achievements)
end
function Summary.Get(fight)
    local s = cache[fight]
    if Whole(s) then return s end
    return Summary.Load(fight)
end
function Summary.Peek(fight)
    return cache[fight]
end
local function Touch(fight)
    for i = 1, #order do
        if order[i] == fight then
            table.remove(order, i)
            break
        end
    end
    table.insert(order, 1, fight)
    while #order > KEEP do
        cache[table.remove(order)] = nil
    end
end
function Summary.Keep(fight, s)
    cache[fight] = s
    Touch(fight)
    return s
end
local function Fill(set, list)
    if not list then return end
    for i = 1, #list do set[list[i]] = true end
end
local function IsBoss(fight, name)
    if not name then return false end
    return name == fight.boss or ns.bosses[name] == fight.boss
        or (fight.names ~= nil and fight.names[name] == true)
end
local function NewSummary(fight, def)
    local s = {
        dur = math.max(1, fight.to - fight.from),
        combat = math.max(1, fight.to - fight.from),
        from = fight.from,
        lead = math.max(fight.from - LEAD, ns.Encounters.Lead and ns.Encounters.Lead(fight) or 0),
        dmg = 0, bossDmg = 0, heal = 0, deaths = 0, dispels = 0, interrupts = 0,
        players = {}, blocks = {}, badges = {}, icons = {}, extra = {},
        spellIds = {}, soaked = {}, given = {}, earned = {},
    }
    local own, common = def.badges or {}, ns.buffsGiven or {}
    for i = 1, #own do s.badges[i] = own[i] end
    s.own = #own
    for i = 1, #common do s.badges[#s.badges + 1] = common[i] end
    local stats = def.stats or {}
    for i = 1, #stats do
        local set = {}
        Fill(set, stats[i].spells)
        s.extra[i] = { def = stats[i], set = set, times = {}, n = 0 }
    end
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "dmgto" and not bd.set then
            bd.set = {}
            Fill(bd.set, bd.names)
        end
        if bd.kind == "dmgto" and bd.soak then Fill(s.soaked, bd.names) end
        if bd.kind == "captor" then s.captor = i end
        if bd.kind == "applied" and not bd.set then
            bd.set = {}
            Fill(bd.set, bd.spells)
            if bd.names then
                bd.targets = {}
                Fill(bd.targets, bd.names)
            end
        end
        if bd.kind == "given" then
            for k = 1, #bd.spells do s.given[bd.spells[k]] = i end
        end
        if bd.kind == "got" then
            s.got = s.got or {}
            for k = 1, #bd.spells do s.got[bd.spells[k]] = i end
        end
    end
    s.live = {}
    for i = 1, s.own do
        if LIVE[s.badges[i].kind] then s.live[#s.live + 1] = i end
    end
    local byName = {}
    for name in pairs(fight.players) do
        local p = { name = name, class = ns.Encounters.ClassOf(name), dmg = 0, bossDmg = 0,
                    heal = 0, interrupts = 0, kick = {}, kickList = {},
                    bossMelee = 0, deaths = 0, dispels = 0, disp = {}, dispList = {},
                    role = "dps", badges = {}, deathAt = {}, deathInfo = {}, recent = {},
                    hits = {}, mcCasts = {}, swingN = 0, swingDmg = 0,
                    targetDmg = {}, casts = {}, chased = {}, taunts = 0, npcTaken = 0, tankCasts = 0,
                    absorb = 0, dmgBy = {}, healBy = {}, petBy = {}, healIn = 0, hurtT = -1e9 }
        for i = 1, #s.badges do
            p.badges[i] = { n = 0, hits = 0, amount = 0, times = {}, cleansed = 0, notes = {}, max = 0 }
        end
        byName[name] = p
        s.players[#s.players + 1] = p
    end
    local blocks = def.blocks or {}
    s.hurt, s.castSet, s.cureSet = {}, {}, {}
    for i = 1, #blocks do
        local bd = blocks[i]
        local b = { def = bd, total = 0, by = {}, split = {}, names = {} }
        Fill(b.names, bd.names)
        if bd.soak then
            b.hits = {}
            Fill(s.soaked, bd.names)
        end
        if bd.kind == "taken" or bd.kind == "casts" or bd.kind == "removed" then
            b.spells = {}
            Fill(b.spells, bd.spells)
            if bd.srcs then
                b.srcs = {}
                Fill(b.srcs, bd.srcs)
            end
            b.hits, b.starts, b.done, b.casts, b.missDmg, b.missHits = {}, 0, 0, 0, 0, 0
            Fill(bd.kind == "removed" and s.cureSet or s.hurt, bd.spells)
            if bd.kind == "casts" then Fill(s.castSet, bd.spells) end
        end
        if bd.kind == "cannons" then
            b.ships, b.hits, b.kills, b.secs, b.all = {}, {}, {}, {}, {}
            Fill(b.ships, bd.ships)
            s.gun, s.guns, s.gunOpen, s.gunEps = b, {}, {}, {}
            s.seatT, s.seatWho, s.seatGun = {}, {}, {}
            for name, enc in pairs(ns.vehicles or {}) do
                if enc == fight.boss then s.guns[name] = true end
            end
        end
        if bd.kind == "healTo" then
            s.healTo = s.healTo or {}
            Fill(s.healTo, bd.names)
        end
        if bd.kind == "usefulTo" then
            local size = fight.raid and fight.raid.size or (#s.players > BIG_RAID and 25 or 10)
            local hp = bd.hp and bd.hp[size]
            b.units, b.waveList, b.wave, b.waves, b.freed = {}, {}, 0, {}, {}
            b.limit = hp and math.floor(hp * (bd.hpPct or 0.5)) or nil
            b.hpMax = hp or 0
            b.full = { total = 0, by = {}, split = {}, waves = {} }
            b.hp50 = { total = 0, by = {}, split = {}, waves = {} }
            s.useful = b
        end
        s.blocks[i] = b
    end
    s.byName = byName
    s.track = ns.Phases and ns.Phases.New(fight) or nil
    s.gw = ns.DeathGrade.Watch(def)
    return s, byName
end
local function Add(b, who, key, amount)
    b.total = b.total + amount
    b.by[who] = (b.by[who] or 0) + amount
    local sp = b.split[who]
    if not sp then
        sp = {}
        b.split[who] = sp
    end
    sp[key] = (sp[key] or 0) + amount
end
local function DamageTo(s, p, who, target, amount)
    local badges = s.badges
    for i = 1, s.own do
        local bd = badges[i]
        if bd.kind == "dmgto" and bd.set[target] then
            local st = p.badges[i]
            st.n = 1
            st.amount = st.amount + amount
            st.hits = st.hits + 1
            s.icons[i] = bd.id
        end
    end
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.names[target] and b.def.kind == "damageTo" then
            Add(b, who, target, amount)
            if b.def.soak then b.hits[who] = (b.hits[who] or 0) + 1 end
        end
    end
end
local function Listed(b, spell, src)
    return b.spells ~= nil and b.spells[spell] == true
        and (not b.srcs or (src ~= nil and b.srcs[src] == true))
end
local function HealTo(s, who, target, spell, amount)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "healTo" and b.names[target] then Add(b, who, spell, amount) end
    end
end
local function Guard(p, ts, id)
    local t = p.guardT
    if not t then
        t = {}
        p.guardT, p.guardId = t, {}
    end
    local n = #t + 1
    t[n], p.guardId[n] = ts, id
end
local function Hurt(s, victim, spell, src, amount)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if Listed(b, spell, src) then
            if b.def.kind == "taken" then
                Add(b, victim, spell, amount)
                b.hits[victim] = (b.hits[victim] or 0) + 1
            elseif b.def.kind == "casts" then
                b.missDmg = b.missDmg + amount
                b.missHits = b.missHits + 1
            end
        end
    end
end
local function EnemyCast(s, spell, src, started)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" and Listed(b, spell, src) then
            if started then b.starts = b.starts + 1 else b.done = b.done + 1 end
        end
    end
end
local function Kicked(s, who, spell, src, kick)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" and Listed(b, spell, src) then Add(b, who, kick, 1) end
    end
end
local function Cured(s, who, debuff)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "removed" and Listed(b, debuff, nil) then Add(b, who, debuff, 1) end
    end
end
local function Unit(b, guid)
    local v = b.units[guid]
    if not v then
        v = { wave = b.wave, hp = b.hpMax, done = false }
        b.units[guid] = v
    end
    return v
end
local function Credit(t, who, key, wave, amount)
    Add(t, who, key, amount)
    local w = t.waves[who]
    if not w then
        w = {}
        t.waves[who] = w
    end
    w[wave] = (w[wave] or 0) + amount
end
local function UsefulWatch(s, b, ts, sub, srcName, dstGUID, dstName, spell)
    if spell == b.def.heroic and srcName and b.names[srcName] then
        b.heroic = true
    elseif sub == "SPELL_SUMMON" and dstGUID and dstName and b.names[dstName] then
        local w = s.track and b.def.wave and ns.Phases.Count(s.track, b.def.wave) or 0
        local v = Unit(b, dstGUID)
        v.wave = w
        if w < 1 then return end
        local list = b.waveList[w]
        if not list then
            list = { t = ts }
            b.waveList[w] = list
        end
        b.wave = w
        list[#list + 1] = v
    elseif sub == "UNIT_DIED" and dstGUID then
        local v = b.units[dstGUID]
        if v and v.capAt and not v.freeAt then v.freeAt = ts end
    end
end
local function Captive(b, who, ts, on)
    for w = b.wave, math.max(1, b.wave - 1), -1 do
        local list = b.waveList[w]
        for k = 1, #list do
            local v = list[k]
            if v.captive == who then
                if not on and not v.freeAt then
                    v.freeAt = ts
                    b.freed[who] = true
                    return
                elseif on and (not v.freeAt or ts - v.freeAt <= RIDE_BOUNCE) then
                    v.freeAt = nil
                    return
                end
            end
        end
    end
    local list = b.waveList[b.wave]
    if not on or not list or ts - list.t > CAPTURE_WINDOW then return end
    for k = 1, #list do
        if not list[k].captive then
            list[k].captive = who
            list[k].capAt = ts
            b.bound = true
            return
        end
    end
end
local function Caught(s, p)
    local i = s.captor
    local st = p.badges[i]
    local ts = p.capT
    if not st.last or ts - st.last > CAPTOR_GAP then
        st.n = st.n + 1
        st.times[#st.times + 1] = ts - s.from
    end
    st.last = ts
    st.hits = st.hits + 1
    st.amount = st.amount + p.capAmount
    s.icons[i] = s.badges[i].id
    p.capT = nil
end
local function Captor(s, p, ts, guid, key, amount, mine)
    local cap = p.capT
    if cap and ts - cap > AOE_WINDOW then
        Caught(s, p)
    elseif cap and key == p.capKey and guid ~= p.capGuid then
        p.capT = nil
    end
    local aoe = p.hitT and key == p.hitKey and guid ~= p.hitGuid and ts - p.hitT <= AOE_WINDOW
    if mine and not aoe then
        if p.capT then Caught(s, p) end
        p.capT, p.capKey, p.capGuid, p.capAmount = ts, key, guid, amount
    end
    p.hitT, p.hitKey, p.hitGuid = ts, key, guid
end
local function UsefulHit(s, b, p, who, own, ts, guid, name, amount, over, key, dot)
    local v = b.names[name] and Unit(b, guid) or nil
    if v then
        local cut = over > 0 and amount - over or amount
        local got = cut
        if b.limit then
            got = math.max(0, math.min(cut, v.hp - b.limit))
            v.hp = v.hp - cut
            if not v.done and v.hp <= b.limit then v.done = true end
        end
        local phase = b.def.phase
        local held = v.capAt ~= nil and not v.freeAt
            and (not phase or (s.track ~= nil and s.track.key == phase))
        if p then
            Credit(b.full, who, key, v.wave, amount)
            if b.limit and got > 0 then Credit(b.hp50, who, key, v.wave, got) end
            if held and got > 0 then Credit(b, who, key, v.wave, got) end
        end
    end
    if p and own and not dot and s.captor then
        Captor(s, p, ts, guid, key, amount, v ~= nil and v.done and v.captive == who
            and v.freeAt ~= nil and ts >= v.freeAt)
    end
end
local function UsefulEnd(s)
    local b = s.useful
    if not b then return end
    for k = 1, s.captor and #s.players or 0 do
        if s.players[k].capT then Caught(s, s.players[k]) end
    end
    local heroic = b.heroic == true
    if heroic and b.bound then
        b.rule = "hold"
    else
        local f = (heroic and b.limit) and b.hp50 or b.full
        b.total, b.by, b.split, b.waves = f.total, f.by, f.split, f.waves
        b.rule = f == b.hp50 and "hp" or "full"
    end
    if b.rule == "full" then
        b.normal = true
        b.label = b.def.plain
    end
    if heroic and b.limit then return end
    local i = s.captor
    for k = 1, i and #s.players or 0 do
        local st = s.players[k].badges[i]
        st.n, st.times, st.hits, st.amount = 0, {}, 0, 0
    end
    if i then s.icons[i] = nil end
end
local function DropFake(s, fight, hpLines)
    for i = 1, #s.players do
        local p = s.players[i]
        local at, info = {}, {}
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            if ns.Encounters.RealDeathIn(fight, p.name, d.t, hpLines) then
                info[#info + 1] = d
                at[#at + 1] = d.t
            end
        end
        p.deathInfo, p.deathAt = info, at
    end
end
local function DropScripted(s, boss)
    local quiet = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            if not d.killer then
                quiet[#quiet + 1] = d
            elseif ns.Deaths.ByScript(boss, d.killer.id) then
                d.scripted = true
            end
        end
    end
    ns.Deaths.MarkWaves(quiet, #s.players)
    for i = 1, #s.players do
        local p = s.players[i]
        local at, info = {}, {}
        p.scripted = 0
        for k = 1, #p.deathInfo do
            if p.deathInfo[k].scripted then
                p.scripted = p.scripted + 1
            else
                info[#info + 1] = p.deathInfo[k]
                at[#at + 1] = p.deathInfo[k].t
            end
        end
        p.deathInfo, p.deathAt = info, at
    end
end
local function Unseated(s, p, t, win)
    for i = 1, #s.badges do
        local outs = s.badges[i].kind == "vehicle" and p.badges[i].outs
        for k = 1, outs and #outs or 0 do
            local gap = t - (s.from + outs[k])
            if gap >= 0 and gap <= win then return true end
        end
    end
    return false
end
Summary.Unseated = Unseated
local function DeathFits(s, bd, p, d, spells, srcs)
    local killer = d.killer
    if bd.spells or bd.srcs then
        if not (killer and ((killer.spell and spells[killer.spell]) or (killer.src and srcs[killer.src]))) then
            return false
        end
    end
    if bd.phases then
        local key = s.phases and ns.Phases.At(s.phases, d.t - s.from)
        local hit = false
        for k = 1, #bd.phases do
            if bd.phases[k] == key then hit = true end
        end
        if not hit then return false end
    end
    return not (bd.skipRide and Unseated(s, p, d.t, bd.skipRide))
end
Summary.DeathFits = DeathFits
local function DeathBadges(s)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "ticks" then
            for k = 1, #s.players do
                local st = s.players[k].badges[i]
                local last
                for t = 1, #(st.ticks or {}) do
                    local ts = st.ticks[t]
                    if not last or ts - last > (bd.gap or 5) then
                        st.n = st.n + 1
                        st.times[#st.times + 1] = ts - s.from
                    end
                    last = ts
                end
                st.ticks = nil
            end
        end
        if bd.kind == "killer" then
            local spells = {}
            Fill(spells, bd.spells)
            s.icons[i] = bd.id
            for k = 1, #s.players do
                local victim = s.players[k]
                for d = 1, #victim.deathInfo do
                    local killer = victim.deathInfo[d].killer
                    local kp = killer and killer.src and killer.src ~= victim.name
                        and spells[killer.spell] and s.byName[killer.src]
                    if kp then
                        local st = kp.badges[i]
                        st.n = st.n + 1
                        st.times[#st.times + 1] = victim.deathInfo[d].t - s.from
                        st.notes[#st.notes + 1] = victim.name
                    end
                end
            end
        end
        if bd.kind == "death" then
            local spells, srcs = {}, {}
            Fill(spells, bd.spells)
            Fill(srcs, bd.srcs)
            s.icons[i] = bd.id
            for k = 1, #s.players do
                local p = s.players[k]
                local st = p.badges[i]
                for d = 1, #p.deathInfo do
                    local info = p.deathInfo[d]
                    if DeathFits(s, bd, p, info, spells, srcs) then
                        st.n = st.n + 1
                        st.times[#st.times + 1] = info.t - s.from
                        if not info.tail then st.grade = ns.DeathGrade.Worse(st.grade, info.grade) end
                    end
                end
            end
        end
    end
end
local function Roles(s)
    local melee = 0
    local taken = 0
    for i = 1, #s.players do
        melee = melee + s.players[i].bossMelee
        taken = taken + s.players[i].npcTaken
    end
    for i = 1, #s.players do
        local p = s.players[i]
        if (melee > 0 and p.bossMelee / melee >= TANK_SHARE)
            or p.taunts >= TANK_TAUNTS
            or (p.taunts > 0 and ((taken > 0 and p.npcTaken / taken >= TAUNT_TAKEN_SHARE) or p.tankCasts > 0))
            or p.tankCasts >= TANK_CASTS then
            p.role = "tank"
        elseif p.heal > p.dmg then
            p.role = "heal"
        end
    end
end
local function ShedAura(st, bd, sub, ts, id, from, im)
    local list = st.hangs
    local h = list and list[#list]
    if sub == "SPELL_AURA_REMOVED" then
        if h and not h.gone then
            h.gone = ts
            if im and math.abs(ts - im.t) <= IMMUNE_WINDOW then h.by = im.name end
        end
        return false
    end
    if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REFRESH" then return false end
    local full = bd.shed[id or 0] or SHED_FULL
    if h and (not h.gone or ts - h.gone <= SHED_RELINK) then
        h.on, h.gone, h.by, h.full = ts, nil, nil, full
        return false
    end
    if sub ~= "SPELL_AURA_APPLIED" then return false end
    list = list or {}
    st.hangs = list
    list[#list + 1] = { t = ts - from, on = ts, full = full }
    return true
end
local function ShedBy(p, badges, ts, name)
    for i = 1, #badges do
        local list = badges[i].shed and p.badges[i].hangs
        local h = list and list[#list]
        if h and h.gone and not h.by and math.abs(ts - h.gone) <= IMMUNE_WINDOW then h.by = name end
    end
end
local function DiedNear(list, t)
    for i = 1, #list do
        if math.abs(list[i] - t) <= SHED_DEATH then return true end
    end
    return false
end
local function Forgive(list, a, b)
    for i = #(list or {}), 1, -1 do
        if list[i] >= a - SHED_RELINK and list[i] <= b + SHED_RELINK then table.remove(list, i) end
    end
end
local function ShedClose(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        for k = 1, bd.shed and #s.players or 0 do
            local p = s.players[k]
            local list = p.badges[i].hangs or {}
            for j = 1, #list do
                local h = list[j]
                local off = h.gone and h.gone < fight.to - SHED_RELINK and h.gone or nil
                h.dur = math.max(0, (off or fight.to) - (fight.from + h.t))
                if not off then
                    h.off = "end"
                elseif DiedNear(p.deathAt, off) then
                    h.off = "died"
                elseif off < h.on + h.full - SHED_SLACK then
                    h.off = "shed"
                    Forgive(p.hits[bd.spell], fight.from + h.t, off)
                else
                    h.off = "full"
                end
                h.on, h.gone = nil, nil
            end
        end
    end
end
local function Finish(s, fight, hpLines)
    ShedClose(s, fight)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" then b.casts = math.max(b.starts, b.done + b.total) end
    end
    UsefulEnd(s)
    DropScripted(s, fight.boss)
    Roles(s)
    ns.DeathGrade.Run(s, fight, hpLines)
    DeathBadges(s)
    for i = 1, #s.extra do
        local x = s.extra[i]
        if x.def.kind == "deaths" then
            for k = 1, #s.players do
                local p = s.players[k]
                for d = 1, #p.deathInfo do
                    local killer = p.deathInfo[d].killer
                    if killer and killer.spell and x.set[killer.spell] then x.n = x.n + 1 end
                end
            end
        end
        table.sort(x.times)
        local last
        for k = 1, #x.times do
            if not last or x.times[k] - last > (x.def.gap or 5) then x.n = x.n + 1 end
            last = x.times[k]
        end
    end
    for i = 1, #s.players do
        local p = s.players[i]
        p.deaths = #p.deathAt
        p.recent = nil
        s.dmg = s.dmg + p.dmg
        s.bossDmg = s.bossDmg + p.bossDmg
        s.interrupts = s.interrupts + p.interrupts
        s.heal = s.heal + p.heal
        s.deaths = s.deaths + p.deaths
        s.dispels = s.dispels + p.dispels
    end
    for i = 1, #s.players do
        local p = s.players[i]
        for _, d in pairs(p.disp) do p.dispList[#p.dispList + 1] = d end
        tsort(p.dispList, function(a, b) return a.n > b.n end)
        for _, k in pairs(p.kick) do p.kickList[#p.kickList + 1] = k end
        tsort(p.kickList, function(a, b) return a.n > b.n end)
    end
    tsort(s.players, function(a, b)
        if a.role ~= b.role then return a.role < b.role end
        local va = a.role == "heal" and a.heal or a.dmg
        local vb = b.role == "heal" and b.heal or b.dmg
        if va ~= vb then return va > vb end
        return a.name < b.name
    end)
end
local function Stint(s, fight, i, st, from, to)
    local bd = s.badges[i]
    if not st.live or (not bd.prepull and from < fight.from) then return end
    local a, z = math.max(from, fight.from), math.min(to, fight.to)
    if z < a then return end
    st.n = st.n + 1
    st.times[#st.times + 1] = a - fight.from
    st.outs = st.outs or {}
    st.outs[#st.outs + 1] = z - fight.from
    st.sec = (st.sec or 0) + z - a
    if bd.wave and s.track then
        st.waves = st.waves or {}
        st.waves[st.n] = ns.Phases.WaveAt(s.track.res, bd.wave, a - fight.from)
    end
    s.icons[i] = s.icons[i] or bd.id
end
local function Ride(s, fight, p, ts, on, gun)
    local seats = s.seatT
    if on and seats then
        local n = #seats + 1
        seats[n], s.seatWho[n], s.seatGun[n] = ts, p.name, gun or false
    end
    if s.useful then Captive(s.useful, p.name, ts, on) end
    local badges = s.badges
    for i = 1, s.own do
        local bd = badges[i]
        if bd.kind == "vehicle" then
            local st = p.badges[i]
            local first = not st.seen
            st.seen = true
            if on then
                if st.on and st.off and ts - st.off <= RIDE_BOUNCE then
                    st.off = nil
                elseif not st.on or st.off then
                    if st.on then Stint(s, fight, i, st, st.on, st.off) end
                    st.on, st.off = ts, nil
                    st.live = not bd.phase or (s.track ~= nil and s.track.key == bd.phase)
                end
            elseif st.on then
                st.off = st.off or ts
            elseif first and bd.prepull then
                st.live = true
                Stint(s, fight, i, st, fight.from, ts)
            end
        end
    end
end
local function RideEnd(s, fight)
    for i = 1, #s.badges do
        if s.badges[i].kind == "vehicle" then
            for k = 1, #s.players do
                local st = s.players[k].badges[i]
                if st.on then Stint(s, fight, i, st, st.on, st.off or fight.to) end
                st.on, st.off = nil, nil
            end
        end
    end
end
local function Sight(s, guid, flags, ts)
    local ep = s.gunOpen[guid]
    if band(flags, F_BY_PLAYER) == 0 then
        s.gunOpen[guid] = nil
        return nil
    end
    if not ep then
        ep = { guid = guid, from = ts, to = ts, hits = 0, ship = 0, kills = 0, dmg = 0, boss = 0 }
        s.gunOpen[guid] = ep
        s.gunEps[#s.gunEps + 1] = ep
    end
    ep.to = ts
    return ep
end
local function Gun(s, fight, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a4, a5)
    local guns = s.guns
    if sub == "PARTY_KILL" then
        local ep = s.killEp
        if ep and dstGUID == s.killDst and ts == s.killTs and srcName and s.byName[srcName] then
            ep.votes = ep.votes or {}
            ep.votes[srcName] = (ep.votes[srcName] or 0) + 1
        end
        return false
    end
    if dstGUID and dstFlags and dstName and guns[dstName] then Sight(s, dstGUID, dstFlags, ts) end
    if not (srcGUID and srcFlags and srcName and guns[srcName]) then return false end
    local ep = Sight(s, srcGUID, srcFlags, ts)
    if not ep or not sub:find("_DAMAGE", 1, true) then return true end
    local amount = tonumber(a4) or 0
    if dstName and s.gun.ships[dstName] then
        ep.hits = ep.hits + 1
        ep.ship = ep.ship + amount
    elseif dstFlags and band(dstFlags, F_HOSTILE) > 0 and not (dstName and s.byName[dstName]) then
        if ts >= fight.from and ts <= fight.to then
            ep.dmg = ep.dmg + amount
            if IsBoss(fight, dstName) then ep.boss = ep.boss + amount end
        end
        if (tonumber(a5) or 0) > 0 then
            ep.kills = ep.kills + 1
            s.killEp, s.killDst, s.killTs = ep, dstGUID, ts
        end
    end
    return true
end
local function Busy(s, who, ep)
    local eps = s.gunEps
    for k = 1, #eps do
        local o = eps[k]
        if o ~= ep and o.rider == who and o.from <= ep.to and o.to >= ep.from then return true end
    end
    return false
end
local function Seat(s, ep, byGun)
    local best, gap
    for k = 1, #s.seatT do
        local t, g, who = s.seatT[k], s.seatGun[k], s.seatWho[k]
        local d = math.abs(t - ep.from)
        local fits
        if byGun then
            fits = g == ep.guid and t <= ep.to
        else
            fits = not g and d <= SEAT_NEAR and not Busy(s, who, ep)
        end
        if fits and (not gap or d < gap) then best, gap = who, d end
    end
    return best
end
local function Voted(ep)
    local best, n
    for who, c in pairs(ep.votes or {}) do
        if not n or c > n then best, n = who, c end
    end
    return best
end
local function GunEnd(s, fight)
    local b = s.gun
    if not b then return end
    local eps = s.gunEps
    local pets = ns.GetDB().pets or {}
    for k = 1, #eps do eps[k].rider = Seat(s, eps[k], true) or Voted(eps[k]) end
    for k = 1, #eps do
        local ep = eps[k]
        if not ep.rider then ep.rider = Seat(s, ep, false) end
        local owner = pets[ep.guid]
        if not ep.rider and owner and s.byName[owner] and not Busy(s, owner, ep) then ep.rider = owner end
    end
    for k = 1, #eps do
        local ep = eps[k]
        local near, gap
        for j = 1, #eps do
            local o = eps[j]
            local d = math.abs(o.from - ep.from)
            if not ep.rider and o.rider and o.guid == ep.guid and (not gap or d < gap) then near, gap = o.rider, d end
        end
        if near and not Busy(s, near, ep) then ep.rider = near end
    end
    local vi
    for i = 1, #s.badges do
        if not vi and s.badges[i].kind == "vehicle" then vi = i end
    end
    for k = 1, #s.players do
        local st = vi and s.players[k].badges[vi]
        if st and st.seen and (st.sec or 0) > 0 then
            local name = s.players[k].name
            b.secs[name] = st.sec
            b.by[name] = b.by[name] or 0
        end
    end
    local nobody = ns.T("sum.k.nogunner")
    for k = 1, #eps do
        local ep = eps[k]
        local p = ep.rider and s.byName[ep.rider]
        local who = p and ep.rider or nobody
        if p then
            p.dmg = p.dmg + ep.dmg
            p.bossDmg = p.bossDmg + ep.boss
            local st = vi and p.badges[vi]
            if st and not st.seen then
                st.live = true
                Stint(s, fight, vi, st, ep.from, ep.to)
                b.secs[who] = st.sec
            end
        end
        b.total = b.total + ep.ship
        b.by[who] = (b.by[who] or 0) + ep.ship
        b.hits[who] = (b.hits[who] or 0) + ep.hits
        b.kills[who] = (b.kills[who] or 0) + ep.kills
        b.all[who] = (b.all[who] or 0) + ep.dmg
    end
end
local function Given(s, fight, p, dst, spell, id, ts)
    if ts < s.lead or ts > fight.to then return end
    local i = s.given[spell]
    local bd = s.badges[i]
    local st = p.badges[i]
    local pull = bd.pull == true and not s.pull
    st.n = st.n + 1
    st.times[st.n] = ts - fight.from
    st.notes[st.n] = dst.name
    if pull then
        st.pulled = st.pulled or {}
        st.pulled[st.n] = true
    end
    s.icons[i] = s.icons[i] or bd.id or id
    local g = s.got and s.got[spell]
    if not g then return end
    local got = dst.badges[g]
    got.n = got.n + 1
    got.times[got.n] = ts - fight.from
    got.notes[got.n] = p.name
    if pull then
        got.pulled = got.pulled or {}
        got.pulled[got.n] = true
    end
    got.icon = got.icon or bd.id or id
    s.icons[g] = s.icons[g] or got.icon
end
local function Earned(s, byName, id, name, ts)
    if not id or not name or not byName[name] then return end
    local list = s.earned
    local e
    for i = 1, #list do
        if list[i].id == id then e = list[i] end
    end
    if not e then
        e = { id = id, t = ts - s.from, who = {}, n = 0 }
        list[#list + 1] = e
    end
    if e.who[name] then return end
    e.who[name] = ts - s.from
    e.n = e.n + 1
end
local function Build(fight)
    local def = ns.summaries and ns.summaries[fight.boss] or {}
    local s, byName = NewSummary(fight, def)
    local acts = ns.Actions and ns.Actions.Begin(s, fight)
    local shades = ns.Shades and ns.Shades.Begin(s, fight)
    local badges = s.badges
    local track = s.track
    local guns = s.guns
    local useful = s.useful
    local live = s.live
    local gw = s.gw
    local dd = ns.DeathDeps and ns.DeathDeps.Begin(fight, def, s)
    s.dd = dd
    local immune = ns.immunities or {}
    local owners, lastImmune, chasers, shields, blasts = {}, {}, {}, {}, {}
    local totemNames, cleared = {}, {}
    local totemWins, removals, dispelled = {}, {}, {}
    for i = 1, #(def.blocks or {}) do
        local b = def.blocks[i]
        if b.kind == "dispels" and b.totems then
            Fill(totemNames, b.totems)
            cleared[b.spell] = true
        end
    end
    local fixates = ns.fixates or {}
    local taunts = ns.taunts or {}
    local tankSpells = ns.tankSpells or {}
    local defensives = ns.defensives or {}
    local friendlySpells = {}
    for i = 1, #(def.blocks or {}) do
        local b = def.blocks[i]
        if b.kind == "friendly" then Fill(friendlySpells, b.spells) end
    end
    local watch = ns.Penalties and ns.Penalties.Watch(fight.boss)
        or { hit = {}, mc = {}, targets = {}, casts = {}, npcs = {} }
    local function Remember(p, entry)
        local list = p.recent
        list[#list + 1] = entry
        while list[1] and entry.t - list[1].t > RECENT do table.remove(list, 1) end
    end
    local function Died(p, ts)
        local killer
        local last = p.recent[#p.recent]
        if last and ts - last.t <= ns.Deaths.KILL_WINDOW then killer = last end
        local copy = {}
        for k = 1, #p.recent do copy[k] = p.recent[k] end
        p.deathAt[#p.deathAt + 1] = ts
        local d = { t = ts, killer = killer, recent = copy }
        ns.DeathGrade.Snap(p, d)
        p.deathInfo[#p.deathInfo + 1] = d
    end
    local function Friendly(who, what, amount)
        for i = 1, #s.blocks do
            local b = s.blocks[i]
            if b.def.kind == "friendly" then
                b.total = b.total + amount
                b.by[who] = (b.by[who] or 0) + amount
                local sp = b.split[who]
                if not sp then
                    sp = {}
                    b.split[who] = sp
                end
                sp[what] = (sp[what] or 0) + amount
            end
        end
    end
    local pets = ns.GetDB().pets or {}
    local ctl = watch.ctl and ns.MindCtl.Begin(watch.ctl, byName, owners, pets)
    local from, to = fight.from - LEAD, fight.to + TAIL
    local scan = fight.from - SHIELD_LEAD
    local segs = ns.Encounters.Segs(fight)
    local hpLines = ns.Encounters.HpLines(scan, to)
    local tt = ns.Totals.Begin(byName, owners, pets, fight, hpLines)
    local rp = ns.RaidPart.New(fight, pets, nil)
    local seen = 0
    ns.Jobs.Label("job.summary")
    for si = 1, #segs do
    for ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
        in ns.Store.Events(segs[si], scan, to, SKIP_HP, MAX_TAIL, ns.Encounters.KeepHp, hpLines) do
        ns.Jobs.Step()
        seen = seen + 1
        if seen % PROGRESS_EVERY == 0 then ns.Jobs.Progress(ts - scan, to - scan) end
        if sub == "SPELL_SUMMON" and srcFlags and band(srcFlags, F_PLAYER) > 0 and dstGUID then owners[dstGUID] = srcName end
        if dstName and sub:find("SPELL_AURA_", 1, true) then
            ns.Totals.Aura(tt, ts, sub, srcGUID, srcName, srcFlags, dstName, a1, a2)
        end
        if sub == "FW_PULLT" then ns.PullTimer.Feed(s, ts, srcName, a1) end
        if sub == "FW_ACH" and ts >= fight.from and ts <= to then
            Earned(s, byName, tonumber(a1), srcName, ts)
            if ts <= fight.to then ns.RaidPart.Got(rp, tonumber(a1), srcName, ts) end
        end
        if ts >= from and ts <= to and sub ~= "FW_HP" then
            if track then ns.Phases.Feed(track, ts, sub, a1) end
            if gw.names[a2] and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED") then
                ns.DeathGrade.Aura(gw, byName, ts, sub, dstGUID, dstName, a2)
            end
            if dd and dd.subs[sub] then ns.DeathDeps.Feed(dd, ts, sub, srcName, dstName, a1, a2, a5) end
            if sub == "FW_EMOTE" and ts >= fight.from and ts <= fight.to and type(a1) == "string" then
                local ep = dstName and byName[dstName]
                if ep then
                    for i = 1, s.own do
                        local bd = badges[i]
                        if bd.kind == "emote" then
                            for k = 1, #bd.patterns do
                                if a1:find(bd.patterns[k], 1, true) then
                                    local st = ep.badges[i]
                                    st.n = st.n + 1
                                    st.times[#st.times + 1] = ts - fight.from
                                    s.icons[i] = bd.id
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if sub == "FW_STACK" and ts >= fight.from and ts <= fight.to and type(a1) == "string" then
                local sp = srcName and byName[srcName]
                local c = tonumber(a2) or 0
                if sp then
                    for i = 1, s.own do
                        local bd = badges[i]
                        if bd.kind == "stack" and bd.spell == a1 then
                            local st = sp.badges[i]
                            if c > 0 and (st.cur or 0) == 0 then
                                st.n = st.n + 1
                                st.times[#st.times + 1] = ts - fight.from
                            end
                            st.cur = c
                            if c > st.max then st.max = c end
                            s.icons[i] = s.icons[i] or bd.id
                        end
                    end
                end
            end
            if sub == "FW_VEH" then
                local vp = srcName and byName[srcName]
                if vp then Ride(s, fight, vp, ts, tonumber(a1) == 1, type(a2) == "string" and a2 or nil) end
            end
            if useful and ts >= fight.from and ts <= fight.to
                and (sub == "SPELL_SUMMON" or sub == "UNIT_DIED" or a2 == useful.def.heroic) then
                UsefulWatch(s, useful, ts, sub, srcName, dstGUID, dstName, a2)
            end
            local inFightWindow = ts >= fight.from and ts <= fight.to
            if sub == "SPELL_SUMMON" and srcFlags and band(srcFlags, F_PLAYER) > 0 and dstGUID then
                owners[dstGUID] = srcName
                if a2 and totemNames[a2] then
                    totemWins[#totemWins + 1] = { guid = dstGUID, owner = srcName, from = ts, to = ts + 300 }
                end
            end
            if sub == "UNIT_DIED" and dstGUID and #totemWins > 0 then
                for k = 1, #totemWins do
                    if totemWins[k].guid == dstGUID then totemWins[k].to = ts end
                end
            end
            if inFightWindow and sub == "SPELL_AURA_REMOVED" and a2 and cleared[a2] and dstName and byName[dstName] then
                removals[#removals + 1] = { t = ts, who = dstName, spell = a2 }
            end
            if sub == "SPELL_DISPEL" and a5 and cleared[a5] and dstName then
                dispelled[#dispelled + 1] = { t = ts, who = dstName }
            end
            if dstName and sub == "SPELL_SUMMON" and dstGUID then
                chasers[dstGUID] = { name = dstName, id = tonumber(a1) }
            end
            local who
            if srcFlags and band(srcFlags, F_BY_PLAYER) > 0 then
                if band(srcFlags, F_PLAYER) > 0 then
                    who = srcName
                else
                    who = (srcGUID and (owners[srcGUID] or pets[srcGUID])) or nil
                end
            end
            local rwho = who
            if guns and ((srcName and guns[srcName]) or (dstName and guns[dstName]) or sub == "PARTY_KILL")
                and Gun(s, fight, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a4, a5) then
                who = nil
            end
            local p = who and byName[who]
            local dst = dstName and byName[dstName]
            local inFight = ts >= fight.from and ts <= fight.to
            local mcSrc = srcName and byName[srcName] and srcFlags and band(srcFlags, F_PLAYER) == 0
                and band(srcFlags, F_BY_PLAYER) == 0 and srcName or nil
            if not s.pull and srcFlags and band(srcFlags, F_BY_PLAYER) > 0
                and (sub:find("_DAMAGE", 1, true) or sub:find("_MISSED", 1, true))
                and IsBoss(fight, dstName) then
                local swing = sub:find("SWING", 1, true) ~= nil
                s.pull = { t = ts, src = srcName, spell = (not swing) and a2 or nil,
                           pet = band(srcFlags, F_PLAYER) == 0,
                           owner = srcGUID and owners[srcGUID] or nil }
            end
            if sub == "SPELL_CAST_SUCCESS" and p and dst and a2 and srcName == who and dstName ~= who
                and s.given[a2] then
                Given(s, fight, p, dst, a2, tonumber(a1), ts)
            end
            if acts and (acts.subs[sub] or acts.spells[a2]) then
                ns.Actions.Feed(acts, ts, sub, who, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5)
            end
            if shades and (srcName == shades.npc or dstName == shades.npc) then
                ns.Shades.Feed(shades, ts, sub, srcGUID, srcName, dstName, a1, a2, a4)
            end
            if inFight then
                if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CREATE" or sub == "ENCHANT_APPLIED" then
                    ns.RaidPart.Consume(rp, sub, rwho, srcName, srcFlags, a1)
                end
                if ctl then
                    ns.MindCtl.Feed(ctl, ts, sub, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5, a6, a7, a8)
                end
                local swing = sub:find("SWING", 1, true) ~= nil
                if sub:find("_DAMAGE", 1, true) then
                    local env = sub == "ENVIRONMENTAL_DAMAGE"
                    local amount = tonumber(swing and a1 or env and a2 or a4) or 0
                    if rwho and not env and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        ns.RaidPart.Hit(rp, rwho, dstName, dstFlags, amount - math.max(0, tonumber(swing and a2 or a5) or 0))
                    end
                    if useful and dstName and (useful.names[dstName] or (who and useful.freed[who]))
                        and not dst and dstGUID and srcFlags and band(srcFlags, F_BY_PLAYER) > 0
                        and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        UsefulHit(s, useful, p, who, srcName == who, ts, dstGUID, dstName, amount,
                            tonumber(swing and a2 or a5) or 0, swing and "#swing" or tostring(a2),
                            sub == "SPELL_PERIODIC_DAMAGE")
                    end
                    if p and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        p.dmg = p.dmg + amount
                        ns.Totals.Act(tt, ts, sub)
                        ns.Totals.Damage(p, srcName ~= who, srcName, swing, a1, a2, amount, swing and a7 or a10)
                        DamageTo(s, p, who, dstName, amount)
                        if IsBoss(fight, dstName) then p.bossDmg = p.bossDmg + amount end
                        if watch.targets[dstName] then
                            p.targetDmg[dstName] = (p.targetDmg[dstName] or 0) + amount
                        end
                        if swing and srcName == who then
                            p.swingN = p.swingN + 1
                            p.swingDmg = p.swingDmg + amount
                        end
                    end
                    if dst and srcFlags and band(srcFlags, F_BY_PLAYER) == 0
                        and band(srcFlags, F_HOSTILE) > 0 then
                        dst.npcTaken = dst.npcTaken + amount
                        ns.Totals.Act(tt, ts, sub)
                        if swing and IsBoss(fight, srcName) then dst.bossMelee = dst.bossMelee + 1 end
                    end
                    if dst then
                        ns.Totals.Absorbed(tt, ts, dstName, swing and 1 or env and a4 or a3, amount,
                            tonumber(swing and a6 or env and a7 or a9) or 0)
                        local hit = { t = ts, spell = swing and "#melee" or env and ns.EnvName(a1) or a2,
                                      src = srcName, mc = mcSrc,
                                      id = not swing and not env and tonumber(a1) or nil,
                                      amount = amount, over = tonumber(swing and a2 or env and a3 or a5) }
                        if gw.npc and srcName == gw.npc then ns.DeathGrade.Host(gw, hit, srcGUID) end
                        Remember(dst, hit)
                        if ts - dst.hurtT >= BURST then
                            dst.burstT, dst.burstGap, dst.burstHeal = ts, ts - dst.hurtT, dst.healIn
                        end
                        dst.hurtT, dst.healIn = ts, 0
                        if not swing and not env and a2 and s.hurt[a2] and srcFlags and band(srcFlags, F_BY_PLAYER) == 0
                            and not (srcName and byName[srcName]) then
                            Hurt(s, dstName, a2, srcName, amount)
                        end
                        if a2 and watch.hit[a2] then
                            dst.hits[a2] = dst.hits[a2] or {}
                            local list = dst.hits[a2]
                            list[#list + 1] = ts
                            s.spellIds[a2] = s.spellIds[a2] or tonumber(a1)
                        end
                    end
                    if dst and srcName and byName[srcName] and srcName ~= dstName and srcFlags
                        and band(srcFlags, F_PLAYER) == 0 and band(srcFlags, F_BY_PLAYER) == 0 then
                        Friendly(srcName, swing and "#melee" or tostring(a2), amount)
                    elseif dst and srcGUID and srcName and fixates[srcName] and not swing then
                        blasts[srcGUID] = (blasts[srcGUID] or 0) + amount
                    elseif dst and a2 and friendlySpells[a2] and srcName and byName[srcName]
                        and srcName ~= dstName then
                        Friendly(srcName, tostring(a2), amount)
                    end
                elseif sub:find("_MISSED", 1, true) then
                    if dst and (swing and a1 or a4) == "ABSORB" then
                        ns.Totals.Absorbed(tt, ts, dstName, swing and 1 or a3, 0, tonumber(swing and a2 or a5) or 0)
                    end
                    if dst and swing and IsBoss(fight, srcName) then dst.bossMelee = dst.bossMelee + 1 end
                    if p and not dst and dstName and s.soaked[dstName] and (swing and a1 or a4) == "ABSORB" then
                        DamageTo(s, p, who, dstName, tonumber(swing and a2 or a5) or 0)
                    end
                elseif sub:find("_HEAL", 1, true) then
                    if dst then
                        ns.Totals.Healed(tt, ts, srcName, dstName, a4)
                        dst.healIn = dst.healIn + math.max(0, (tonumber(a4) or 0) - (tonumber(a5) or 0))
                    end
                    if p and dstFlags and band(dstFlags, F_HOSTILE) == 0 then
                        local eff = (tonumber(a4) or 0) - (tonumber(a5) or 0)
                        if eff > 0 then p.heal = p.heal + eff end
                        ns.Totals.Heal(p, a1, a2, eff, a7)
                        if eff > 0 and s.healTo and dstName and s.healTo[dstName] then
                            HealTo(s, who, dstName, tostring(a2), eff)
                        end
                    end
                elseif (sub == "SPELL_DISPEL" or sub == "SPELL_STOLEN") and p then
                    p.dispels = p.dispels + 1
                    local dk = tostring(a2 or a1)
                    local d = p.disp[dk]
                    if not d then
                        d = { id = tonumber(a1), name = a2, n = 0, what = {} }
                        p.disp[dk] = d
                    end
                    d.n = d.n + 1
                    local purge = dstFlags ~= nil and band(dstFlags, F_HOSTILE) > 0
                    local key = (purge and "+" or "-") .. tostring(a5)
                    local w = d.what[key]
                    if not w then
                        w = { name = a5, id = tonumber(a4), n = 0, purge = purge }
                        d.what[key] = w
                    end
                    w.n = w.n + 1
                    for i = 1, #s.blocks do
                        local b = s.blocks[i]
                        if b.def.kind == "dispels" and b.def.spell == a5 then
                            b.total = b.total + 1
                            b.by[who] = (b.by[who] or 0) + 1
                        end
                    end
                    if sub == "SPELL_DISPEL" and dst and a5 and s.cureSet[a5] then Cured(s, who, a5) end
                    local ev = d.list or {}
                    d.list = ev
                    ev[#ev + 1] = { t = ts - fight.from, who = dstName, self = dstName == who or nil,
                        id = tonumber(a4), name = a5, purge = purge or nil,
                        label = def.cureLabels and a5 and def.cureLabels[a5] or nil }
                    if def.cureNote and ev[#ev].label then d.note = def.cureNote end
                elseif sub == "SPELL_INTERRUPT" and p then
                    p.interrupts = p.interrupts + 1
                    local kk = tostring(a2 or a1)
                    local k = p.kick[kk]
                    if not k then
                        k = { id = tonumber(a1), name = a2, n = 0, what = {} }
                        p.kick[kk] = k
                    end
                    k.n = k.n + 1
                    local wk = tostring(dstName) .. "|" .. tostring(a5)
                    local w = k.what[wk]
                    if not w then
                        w = { name = a5, id = tonumber(a4), n = 0, target = dstName }
                        k.what[wk] = w
                    end
                    w.n = w.n + 1
                    if a5 and s.castSet[a5] then Kicked(s, who, a5, dstName, tostring(a2)) end
                elseif sub == "SPELL_INSTAKILL" and dst then
                    Remember(dst, { t = ts, spell = a2, src = srcName, id = tonumber(a1) })
                elseif sub == "UNIT_DIED" and dst then
                    Died(dst, ts)
                elseif sub == "SPELL_CAST_SUCCESS" then
                    if p and srcName == who and a2 and taunts[a2] then p.taunts = p.taunts + 1 end
                    if p and srcName == who and a2 and tankSpells[a2] then p.tankCasts = p.tankCasts + 1 end
                    if p and srcName == who and a1 and defensives[tonumber(a1)] then Guard(p, ts, tonumber(a1)) end
                    if p and srcName == who and gw.tranq and a2 == gw.tranq then ns.DeathGrade.Tranq(p, ts) end
                    if p and srcName == who and a2 and watch.casts[a2] then
                        p.casts[a2] = (p.casts[a2] or 0) + 1
                    end
                    if mcSrc and a2 and watch.mc[a2] then
                        local mp = byName[mcSrc]
                        mp.mcCasts[#mp.mcCasts + 1] = { t = ts, spell = a2 }
                        s.spellIds[a2] = s.spellIds[a2] or tonumber(a1)
                    end
                end
                if (sub == "SPELL_CAST_START" or sub == "SPELL_CAST_SUCCESS") and a2 and s.castSet[a2]
                    and srcFlags and band(srcFlags, F_BY_PLAYER) == 0 then
                    EnemyCast(s, a2, srcName, sub == "SPELL_CAST_START")
                end
                if dst and sub == "SPELL_AURA_APPLIED" and a2 then
                    for i = 1, #s.extra do
                        local x = s.extra[i]
                        if x.def.kind == "auras" and x.set[a2] then x.times[#x.times + 1] = ts end
                    end
                end
                if dst and sub == "SPELL_AURA_APPLIED" and a2 and watch.hit[a2] then
                    dst.hits[a2] = dst.hits[a2] or {}
                    local list = dst.hits[a2]
                    list[#list + 1] = ts
                    s.spellIds[a2] = s.spellIds[a2] or tonumber(a1)
                end
                if dst and sub == "SPELL_AURA_APPLIED" and a2 and immune[a2] then
                    lastImmune[dstName] = { t = ts, name = a2 }
                    ShedBy(dst, badges, ts, a2)
                end
                local ch = swing and dst and srcGUID and chasers[srcGUID]
                if ch and not ch.victim then
                    ch.victim = dstName
                    if watch.npcs[ch.name] then
                        dst.chased[ch.name] = dst.chased[ch.name] or {}
                        local list = dst.chased[ch.name]
                        list[#list + 1] = ts
                        s.spellIds[ch.name] = s.spellIds[ch.name] or ch.id
                    end
                end
                for j = 1, #live do
                    local i = live[j]
                    local bd = badges[i]
                    if bd.kind == "aura" and dst and a2 == bd.spell then
                        local st = dst.badges[i]
                        local new = sub == "SPELL_AURA_APPLIED"
                        if bd.shed then
                            new = ShedAura(st, bd, sub, ts, tonumber(a1), fight.from, lastImmune[dstName])
                        end
                        if new then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                            s.icons[i] = s.icons[i] or tonumber(a1)
                        end
                    elseif bd.kind == "ticks" and dst and a2 == bd.spell and sub:find("PERIODIC", 1, true) then
                        local st = dst.badges[i]
                        st.ticks = st.ticks or {}
                        st.ticks[#st.ticks + 1] = ts
                        s.icons[i] = s.icons[i] or bd.id or tonumber(a1)
                    elseif bd.kind == "stack" and dst and a2 == bd.spell then
                        local st = dst.badges[i]
                        if sub == "SPELL_AURA_APPLIED" then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                            if st.max < 1 then st.max = 1 end
                            s.icons[i] = s.icons[i] or tonumber(a1)
                        elseif sub == "SPELL_AURA_APPLIED_DOSE" then
                            local stacks = tonumber(a5) or 0
                            if stacks > st.max then st.max = stacks end
                        elseif sub == "SPELL_AURA_REMOVED" then
                            st.removed = (st.removed or 0) + 1
                            s.icons[i] = s.icons[i] or bd.id or tonumber(a1)
                        end
                    elseif bd.kind == "hit" and dst and a2 == bd.spell
                        and sub:find("_DAMAGE", 1, true)
                        and (not bd.src or bd.src == srcName) then
                        local st = dst.badges[i]
                        st.hits = st.hits + 1
                        st.amount = st.amount + (tonumber(a4) or 0)
                        if not st.last or ts - st.last > (bd.gap or HIT_GAP) then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                        end
                        st.last = ts
                        s.icons[i] = s.icons[i] or tonumber(a1)
                    elseif bd.kind == "chased" and swing and srcName == bd.npc and dst
                        and srcGUID and chasers[srcGUID] and not chasers[srcGUID].counted then
                        chasers[srcGUID].counted = true
                        local st = dst.badges[i]
                        st.n = st.n + 1
                        st.times[#st.times + 1] = ts - fight.from
                        s.icons[i] = s.icons[i] or chasers[srcGUID].id
                    elseif bd.kind == "applied" and p and sub == "SPELL_AURA_APPLIED" and a2 and bd.set[a2]
                        and ((bd.targets and bd.targets[dstName]) or (not bd.targets and dst and dstName ~= who)) then
                        local st = p.badges[i]
                        st.n = st.n + 1
                        st.times[#st.times + 1] = ts - fight.from
                        if dst then st.notes[#st.notes + 1] = dstName end
                        s.icons[i] = s.icons[i] or bd.id or tonumber(a1)
                    end
                end
            end
        end
    end
    end
    for guid, amount in pairs(blasts) do
        local ch = chasers[guid]
        if ch and ch.victim and byName[ch.victim] then Friendly(ch.victim, "#shade", amount) end
    end
    for r = 1, #removals do
        local rm = removals[r]
        local byDispel = false
        for d = 1, #dispelled do
            if dispelled[d].who == rm.who and math.abs(dispelled[d].t - rm.t) <= TOTEM_DISPEL_WINDOW then
                byDispel = true
                break
            end
        end
        local win
        if not byDispel then
            for k = 1, #totemWins do
                local w = totemWins[k]
                if w.from <= rm.t and w.to >= rm.t and (not win or w.from > win.from) then win = w end
            end
        end
        local owner = win and byName[win.owner] and win.owner
        if owner then
            for i = 1, #s.blocks do
                local b = s.blocks[i]
                if b.def.kind == "dispels" and b.def.spell == rm.spell and b.def.totems then
                    b.total = b.total + 1
                    b.by[owner] = (b.by[owner] or 0) + 1
                    local sp = b.split[owner]
                    if not sp then
                        sp = {}
                        b.split[owner] = sp
                    end
                    sp["#totem"] = (sp["#totem"] or 0) + 1
                end
            end
        end
    end
    DropFake(s, fight, hpLines)
    if acts then ns.Actions.Finish(acts) end
    if shades then ns.Shades.Finish(shades) end
    RideEnd(s, fight)
    GunEnd(s, fight)
    if track then s.phases = ns.Phases.Done(fight, track) end
    if ctl then ns.MindCtl.Finish(ctl, s, fight.to) end
    if ns.PullTimer then ns.PullTimer.Judge(s) end
    ns.Totals.Finish(tt, s)
    Finish(s, fight, hpLines)
    s.rp = ns.RaidPart.Close(rp, s.players)
    return s
end
Summary.Build = Build
Summary.Shed = { Aura = ShedAura, By = ShedBy, Close = ShedClose }
local function JobKey(fight)
    local key = running[fight]
    if not key then
        key = {}
        running[fight] = key
    end
    return key
end
function Summary.Load(fight)
    local s = cache[fight]
    if Whole(s) then return s end
    s = ns.Digest and ns.Digest.Load(fight)
    if not s then return nil end
    if ns.Achievements then
        s.ach = s.ach or {}
        ns.Achievements.Keep(fight, s.ach)
    end
    return Summary.Keep(fight, s)
end
function Summary.Full(fight)
    local s = Summary.Load(fight)
    if s then return s end
    s = cache[fight] or Summary.Build(fight)
    if ns.Achievements and not s.ach then s.ach = ns.Achievements.Build(fight) end
    if ns.Digest then ns.Digest.Save(fight, s) end
    return Summary.Keep(fight, s)
end
function Summary.Compute(fight, onDone)
    local have = Summary.Load(fight)
    if have then
        Touch(fight)
        onDone(have)
        return
    end
    for other, key in pairs(running) do
        if other ~= fight then ns.Jobs.Cancel(key) end
    end
    ns.Jobs.Run(JobKey(fight), function()
        return Summary.Full(fight)
    end, function(s)
        if s then onDone(s) end
    end, "sum.frame", true)
end
function Summary.Reset()
    for k in pairs(cache) do cache[k] = nil end
    for i = #order, 1, -1 do order[i] = nil end
end
