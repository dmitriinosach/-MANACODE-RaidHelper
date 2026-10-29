local _, ns = ...
local band = bit.band
local tsort = table.sort
local SpellKey = ns.SpellKey
local SpellOf = ns.SpellOf
local SS = ns.SpecSign
local NpcKey = ns.NpcKey
local NpcKeyOf = ns.NpcKeyOf
local TR = ns.TankRole
local Acc = ns.SummaryAcc
local Deaths = ns.SummaryDeaths
local Shed = ns.SummaryShed
local Veh = ns.SummaryVeh
local Keys, IsBossKey = Acc.Keys, ns.IsBossKey
local Buffed = Shed.Buffed
local SubKind = ns.SubKind
local F_PLAYER = ns.F.PLAYER
local F_BY_PLAYER = ns.F.BY_PLAYER
local F_HOSTILE = ns.F.HOSTILE
local MAX_TAIL = 10
local PROGRESS_EVERY = 256
local WALK_SHARE = 0.95
local FINISH_STEPS = 5
local LEAD = ns.PULL_LEAD
local SHIELD_LEAD = 60
local TAIL = 5
local HIT_GAP = 2
local TOTEM_DISPEL_WINDOW = 0.5
local RECENT = 10
local KEEP = 20
local BURST = 1
local SWING_KEY = Acc.SWING_KEY
local MELEE_ID = 6603
local LIVE = { aura = true, ticks = true, stack = true, hit = true, chased = true, applied = true }
local LOW_END = 3
local ET_SUBS = { UNIT_DIED = true, SPELL_RESURRECT = true, SPELL_CAST_SUCCESS = true }
local Summary = {}
ns.Summary = Summary
local cache = {}
local order = {}
local running = setmetatable({}, { __mode = "k" })
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
local function Keep(fight, s)
    cache[fight] = s
    Touch(fight)
    return s
end
function Summary.Peek(fight)
    local s = cache[fight]
    if s then return s end
    s = ns.Digest and ns.Digest.Load(fight)
    if not s then return nil end
    if s.phases and ns.Phases then ns.Phases.Keep(fight, s.phases) end
    if ns.Achievements then s.ach = s.ach or {} end
    return Keep(fight, s)
end
local function ByCount(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return (a.id or 0) < (b.id or 0)
end
Summary.Ab = Acc.Ab
Summary.Color = Acc.Color
Summary.Unseated = Deaths.Unseated
Summary.DeathFits = Deaths.DeathFits
Summary.PoolGrade = Deaths.PoolGrade
local function NewSummary(fight, def)
    local s = {
        dur = math.max(1, fight.to - fight.from),
        combat = math.max(1, fight.to - fight.from),
        from = fight.from,
        lead = math.max(fight.from - LEAD, ns.Encounters.Lead and ns.Encounters.Lead(fight) or 0),
        dmg = 0, bossDmg = 0, goodDmg = 0, heal = 0, deaths = 0, dispels = 0, interrupts = 0,
        players = {}, blocks = {}, badges = {}, icons = {}, extra = {},
        spellIds = {}, soaked = {}, given = {}, earned = {}, rides = {}, apart = {},
    }
    for key in pairs(ns.vehicles or {}) do s.rides[key] = true end
    local own, common = def.badges or {}, ns.buffsGiven or {}
    for i = 1, #own do s.badges[i] = own[i] end
    s.own = #own
    for i = 1, #common do s.badges[#s.badges + 1] = common[i] end
    local stats = def.stats or {}
    for i = 1, #stats do
        local set = {}
        ns.SpellSet(stats[i].spells, set)
        s.extra[i] = { def = stats[i], set = set, times = {}, n = 0 }
    end
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "dmgto" and bd.soak then ns.NpcSet(bd.names, s.soaked) end
        if bd.kind == "bounce" then
            ns.NpcSet(bd.names, Acc.BadgeSets(bd).set)
            s.bounce = s.bounce or {}
            ns.NpcSet(bd.names, s.bounce)
        end
        if bd.kind == "captor" then s.captor = i end
        if bd.kind == "given" then
            for k = 1, #bd.spells do s.given[SpellKey(bd.spells[k])] = i end
        end
        if bd.kind == "got" then
            s.got = s.got or {}
            for k = 1, #bd.spells do s.got[SpellKey(bd.spells[k])] = i end
        end
    end
    s.live = {}
    for i = 1, s.own do
        if LIVE[s.badges[i].kind] then s.live[#s.live + 1] = i end
    end
    local byName = {}
    for name in pairs(fight.players) do
        local p = { name = name, class = ns.Encounters.ClassOf(name), dmg = 0, bossDmg = 0, goodDmg = 0,
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
        ns.NpcSet(bd.names, b.names)
        if bd.npc and bd.kind == "abom" then
            s.rides[NpcKeyOf(bd.npc)] = true
            s.apart[NpcKeyOf(bd.npc)] = true
        end
        if bd.soak then
            b.hits = {}
            ns.NpcSet(bd.names, s.soaked)
        end
        if bd.kind == "taken" or bd.kind == "casts" or bd.kind == "removed" then
            b.spells = {}
            ns.SpellSet(bd.spells, b.spells)
            if bd.srcs then
                b.srcs = {}
                ns.NpcSet(bd.srcs, b.srcs)
            end
            b.hits, b.starts, b.done, b.casts, b.missDmg, b.missHits = {}, 0, 0, 0, 0, 0
            ns.SpellSet(bd.spells, bd.kind == "removed" and s.cureSet or s.hurt)
            if bd.kind == "casts" then ns.SpellSet(bd.spells, s.castSet) end
            if bd.kind == "taken" and bd.stacks then
                b.peak = {}
                s.stacked = s.stacked or {}
                ns.SpellSet(bd.spells, s.stacked)
            end
        end
        if bd.kind == "cannons" then
            b.ships, b.hits, b.kills, b.secs, b.all = {}, {}, {}, {}, {}
            ns.NpcSet(bd.ships, b.ships)
            s.gun, s.guns, s.gunOpen, s.gunEps = b, {}, {}, {}
            s.seatT, s.seatWho, s.seatGun = {}, {}, {}
            for key, enc in pairs(ns.vehicles or {}) do
                if enc == fight.boss then s.guns[key] = true end
            end
        end
        if bd.kind == "healTo" then
            s.healTo = s.healTo or {}
            ns.NpcSet(bd.names, s.healTo)
        end
        if bd.kind == "usefulTo" then
            local size = ns.RaidSize(fight)
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
local function LiveIndex(s)
    local bySk, byNpc, applied = {}, {}, {}
    for j = 1, #s.live do
        local i = s.live[j]
        local bd = s.badges[i]
        local bk = Keys(bd)
        if bd.kind == "chased" then
            if bk.npc then
                local l = byNpc[bk.npc] or {}
                byNpc[bk.npc] = l
                l[#l + 1] = i
            end
        elseif bd.kind == "applied" then
            applied[#applied + 1] = i
        elseif bk.sk then
            local l = bySk[bk.sk] or {}
            bySk[bk.sk] = l
            l[#l + 1] = i
        end
    end
    return bySk, byNpc, applied
end
local function Finish(s, fight)
    Shed.Close(s, fight)
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if b.def.kind == "casts" then b.casts = math.max(b.starts, b.done + b.total) end
    end
    Acc.UsefulEnd(s)
    Deaths.DropScripted(s, fight.boss)
    TR.Roles(s)
    Shed.Sniffed(s, fight)
    ns.DeathGrade.Run(s, fight)
    Deaths.DeathBadges(s)
    for i = 1, #s.extra do
        local x = s.extra[i]
        if x.def.kind == "deaths" then
            for k = 1, #s.players do
                local p = s.players[k]
                for d = 1, #p.deathInfo do
                    local killer = p.deathInfo[d].killer
                    if killer and killer.key and x.set[killer.key] then x.n = x.n + 1 end
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
        Buffed.End(p, fight)
        Buffed.Clash.End(p, fight)
        s.dmg = s.dmg + p.dmg
        s.bossDmg = s.bossDmg + p.bossDmg
        s.goodDmg = s.goodDmg + p.goodDmg
        s.interrupts = s.interrupts + p.interrupts
        s.heal = s.heal + p.heal
        s.deaths = s.deaths + p.deaths
        s.dispels = s.dispels + p.dispels
    end
    for i = 1, #s.players do
        local p = s.players[i]
        for _, d in pairs(p.disp) do p.dispList[#p.dispList + 1] = d end
        tsort(p.dispList, ByCount)
        for _, k in pairs(p.kick) do p.kickList[#p.kickList + 1] = k end
        tsort(p.kickList, ByCount)
    end
    tsort(s.players, function(a, b)
        if a.role ~= b.role then return a.role < b.role end
        local va = a.role == "heal" and a.heal or a.dmg
        local vb = b.role == "heal" and b.heal or b.dmg
        if va ~= vb then return va > vb end
        return a.name < b.name
    end)
end
local function Given(s, fight, p, dst, sk, id, ts)
    if ts < s.lead or ts > fight.to then return end
    local i = s.given[sk]
    local bd = s.badges[i]
    local st = p.badges[i]
    local pull = bd.pull == true and not s.pull
    st.n = st.n + 1
    st.times[st.n] = ts - fight.from
    st.notes[st.n] = dst.name
    if bd.id == Buffed.Clash.SPELL then Buffed.Clash.Cast(st, st.n, dst, ts, fight) end
    if pull then
        st.pulled = st.pulled or {}
        st.pulled[st.n] = true
    end
    s.icons[i] = s.icons[i] or bd.id or id
    local g = dst ~= p and s.got and s.got[sk]
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
local function GuidWindow(g, seg, fight)
    g.t0 = seg.t0
    g.lo = (fight.from - seg.t0) * 1000 - 1
    g.hi = (fight.to - seg.t0) * 1000 + 1
end
local function GuidSeen(g, guids, ts, name, guid)
    local m = math.floor((ts - g.t0) * 1000 + 0.5)
    if m >= g.lo and m <= g.hi then guids[name] = guid end
end
local function Build(fight)
    local def = ns.summaries and ns.summaries[fight.boss] or {}
    local s, byName = NewSummary(fight, def)
    local acts = ns.Actions and ns.Actions.Begin(s, fight)
    local rf = ns.RFury and ns.RFury.Begin(s, fight)
    local cv = ns.SummaryCover and ns.SummaryCover.Begin(s, fight, def)
    local pl = ns.SummaryPull and ns.SummaryPull.Begin(s, fight, def)
    local rs = ns.RuneSwap and ns.RuneSwap.Begin(s, fight)
    local bn = ns.BloodNova and ns.BloodNova.Begin(s, fight)
    local zb = ns.ZoneBuff and ns.ZoneBuff.Begin(fight)
    local sg = SS.Begin(byName, fight.to)
    local shades = ns.Shades and ns.Shades.Begin(s, fight)
    local hc = ns.Control and ns.Control.Begin(s, fight, def)
    local cg = ns.Caught and ns.Caught.Begin(s, fight)
    local df = ns.Defile and ns.Defile.Begin(s, fight)
    local lm = ns.LichMech and ns.LichMech.Begin(s, fight)
    local tp = ns.TombPull and ns.TombPull.Begin(s, fight)
    local tb = ns.TombBreak and ns.TombBreak.Begin(s, fight)
    local pa =ns.Parry and ns.Parry.Begin(s, fight)
    local mech = ns.ReplayMech and ns.ReplayMech.Begin(s, fight)
    local pu = ns.Putri and ns.Putri.Begin(s, fight, ns.GetDB().pets or {})
    local badges = s.badges
    local track = s.track
    local phHooks = track and track.idx.hooks
    local mechWant = mech and mech.want
    local guns = s.guns
    local useful = s.useful
    local bossOnly = ns.dpsModel ~= nil and ns.dpsModel[fight.boss] == "boss"
    local liveSk, liveNpc, liveApplied = LiveIndex(s)
    local gw = s.gw
    local dd = ns.DeathDeps and ns.DeathDeps.Begin(fight, def, s)
    s.dd = dd
    local stk = ns.StackEps and ns.StackEps.Begin(fight, def, s)
    local immune = ns.immunities or {}
    local owners, lastImmune, chasers, shields, blasts = {}, {}, {}, {}, {}
    local totemNames, cleared = {}, {}
    local totemWins, removals, dispelled = {}, {}, {}
    for i = 1, #(def.blocks or {}) do
        local b = def.blocks[i]
        if b.kind == "dispels" and b.totems then
            ns.NpcSet(b.totems, totemNames)
            cleared[SpellKey(b.spell)] = true
        end
    end
    local fixates = ns.fixates or {}
    local taunts = ns.taunts or {}
    local tankSpells = ns.tankSpells or {}
    local defensives = ns.defensives or {}
    local friendlySpells = {}
    local abHit = { key = SWING_KEY }
    for i = 1, #(def.blocks or {}) do
        local b = def.blocks[i]
        if b.kind == "friendly" then ns.SpellSet(b.spells, friendlySpells) end
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
        local d = { t = ts, killer = killer, recent = copy, rose = p.rezAt and ts - p.rezAt or nil }
        ns.DeathGrade.Snap(p, d)
        p.deathInfo[#p.deathInfo + 1] = d
    end
    local function Friendly(who, what, amount, crit, id)
        for i = 1, #s.blocks do
            local b = s.blocks[i]
            if b.def.kind == "friendly" then
                Acc.Ab(b, who, what == "#melee" and SWING_KEY or what, amount, crit, id)
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
    local ctl = watch.ctl and ns.MindCtl.Begin(watch.ctl, byName, owners, pets, def.mcDrain)
    local from, to = fight.from - LEAD, fight.to + TAIL
    local scan = fight.from - SHIELD_LEAD
    local segs = ns.Encounters.Segs(fight)
    local tt = ns.Totals.Begin(byName, owners, pets, fight)
    local et = ns.EffTime and ns.EffTime.Begin(byName, fight)
    local rp = ns.RaidPart.New(fight, pets)
    local ach = ns.Achievements and ns.Achievements.Begin(fight)
    local FC = ns.ReplayFeedCore
    local fc = FC and FC.New(fight)
    local guids, gwin = {}, {}
    s.guids = guids
    local seen, read0, span = 0, ns.Store.Read(), 0
    for si = 1, #segs do span = span + ns.Store.Span(segs[si], scan, to) end
    ns.Jobs.Label("job.summary")
    ns.Jobs.Part(0, WALK_SHARE)
    for si = 1, #segs do
    if ach then ns.Achievements.Seg(ach, segs[si]) end
    GuidWindow(gwin, segs[si], fight)
    for ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
        in ns.Store.Events(segs[si], scan, to, MAX_TAIL) do
        ns.Jobs.Step()
        seen = seen + 1
        if seen % PROGRESS_EVERY == 0 then ns.Jobs.Progress(ns.Store.Read() - read0, span) end
        local sk = SpellOf(sub, a1)
        local K = SubKind[sub]
        local id = tonumber(a1)
        if ach then
            ns.Achievements.Feed(ach, ts, sub, sk, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5)
        end
        if srcName and srcGUID and not guids[srcName] and byName[srcName] and srcFlags and band(srcFlags, F_PLAYER) > 0 then
            GuidSeen(gwin, guids, ts, srcName, srcGUID)
        end
        local srcKey, dstKey = NpcKey(srcGUID), NpcKey(dstGUID)
        local srcBoss, dstBoss = IsBossKey(fight, srcKey), IsBossKey(fight, dstKey)
        ns.NoteOwner(owners, sub, srcFlags, srcName, dstGUID)
        if dstName and K.aura then
            ns.Totals.Aura(tt, ts, sub, srcGUID, srcName, srcFlags, dstName, a1, a2)
        end
        if sub == "FW_PULLT" then ns.PullTimer.Feed(s, ts, srcName, a1, a2) end
        if SS.SUBS[sub] then SS.Feed(sg, ts, sub, srcName, dstName, a1, a2, a3) end
        if sub == "FW_MARK" and ts >= s.lead and ts <= to then
            s.marks = s.marks or {}
            s.marks[#s.marks + 1] = { t = ts, key = a1, text = a2 }
        end
        if rf and (rf.subs[sub] or rf.dead[srcName or ""]) then ns.RFury.Feed(rf, ts, sub, srcName, dstName, a1, a2, a3) end
        if cv and cv.subs[sub] then ns.SummaryCover.Feed(cv, ts, sub, srcName, dstName, a1, a4) end
        if pl and pl.subs[sub] then ns.SummaryPull.Feed(pl, ts, sub, srcName, dstName, a1, a4) end
        if rs and rs.subs[sub] then ns.RuneSwap.Feed(rs, ts, sub, srcGUID, srcName, dstGUID, dstName, a1, a4, a5) end
        if bn and bn.subs[sub] then ns.BloodNova.Feed(bn, ts, dstName, sk) end
        if zb and zb.subs[sub] then ns.ZoneBuff.Feed(zb, ts, sub, a1, a2) end
        if TR.SUBS[sub] and ts >= from and ts <= fight.to then TR.Feed(s, byName, fight.boss, ts, sub, dstName, a1, a2, a3, a4, a5, a6, a7) end
        if sub == "FW_ACH" and ts >= fight.from and ts <= to then
            Earned(s, byName, id, srcName, ts)
            if ts <= fight.to then ns.RaidPart.Got(rp, id, srcName, ts) end
        end
        if ts >= from and ts <= to then
            if et and ET_SUBS[sub] then ns.EffTime.Feed(et, ts, sub, srcName, dstName) end
            if track and (track.due or (id and phHooks[id])) then ns.Phases.Feed(track, ts, sub, a1) end
            if sk and gw.names[sk] and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED") then
                ns.DeathGrade.Aura(gw, byName, ts, sub, dstGUID, dstName, sk)
            end
            if dd and dd.subs[sub] then ns.DeathDeps.Feed(dd, ts, sub, srcKey, srcName, dstName, a1, sk, a4) end
            if stk and stk.subs[sub] then ns.StackEps.Feed(stk, ts, sub, srcName, dstName, a1, a2, a5, sk, a4) end
            if df and df.subs[sub] then ns.Defile.Feed(df, ts, sub, sk, srcGUID, dstGUID, dstName, a1, a4) end
            if lm and ((srcKey and lm.npcs[srcKey]) or (dstKey and lm.npcs[dstKey])) then
                ns.LichMech.Feed(lm, ts, sub, sk, srcKey, dstKey, srcGUID, srcName, dstGUID, dstName, a1, a4)
            end
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
            if sub == "FW_STACK" and ts >= fight.from and ts <= fight.to and a1 ~= nil then
                local sp = srcName and byName[srcName]
                local c = tonumber(a2) or 0
                if sp then
                    for i = 1, s.own do
                        local bd = badges[i]
                        if bd.kind == "stack" and Keys(bd).sk == ns.StackKey(a1) then
                            local st = sp.badges[i]
                            if c > 0 and (st.cur or 0) == 0 then
                                st.n = st.n + 1
                                st.times[#st.times + 1] = ts - fight.from
                            end
                            st.cur = c
                            if c > st.max then st.max = c end
                            if bd.low and ts <= fight.to - LOW_END then
                                st.fin = c
                                if not st.min or c < st.min then st.min = c end
                            end
                            s.icons[i] = s.icons[i] or bd.id
                        end
                    end
                end
            end
            if sub == "FW_VEH" then
                local vp = srcName and byName[srcName]
                if vp then Veh.Ride(s, fight, vp, ts, id == 1, type(a2) == "string" and a2 or nil) end
            end
            if useful and ts >= fight.from and ts <= fight.to
                and (sub == "SPELL_SUMMON" or sub == "UNIT_DIED" or (sk and sk == SpellKey(useful.def.heroic))) then
                Acc.UsefulWatch(s, useful, ts, sub, srcKey, dstGUID, dstKey, sk)
            end
            local inFightWindow = ts >= fight.from and ts <= fight.to
            if sub == "SPELL_SUMMON" and srcFlags and band(srcFlags, F_PLAYER) > 0 and dstGUID then
                if dstKey and totemNames[dstKey] then
                    totemWins[#totemWins + 1] = { guid = dstGUID, owner = srcName, from = ts, to = ts + 300 }
                end
            end
            if sub == "UNIT_DIED" and dstGUID and #totemWins > 0 then
                for k = 1, #totemWins do
                    if totemWins[k].guid == dstGUID then totemWins[k].to = ts end
                end
            end
            if inFightWindow and sub == "SPELL_AURA_REMOVED" and sk and cleared[sk] and dstName and byName[dstName] then
                removals[#removals + 1] = { t = ts, who = dstName, key = sk }
            end
            if sub == "SPELL_DISPEL" and a4 and cleared[SpellKey(a4) or 0] and dstName then
                dispelled[#dispelled + 1] = { t = ts, who = dstName }
            end
            if dstName and sub == "SPELL_SUMMON" and dstGUID then
                chasers[dstGUID] = { name = dstName, id = id, key = dstKey }
            end
            local who = ns.WhoOf(srcFlags, srcGUID, srcName, owners, pets)
            local rwho = who
            if guns and ((srcKey and guns[srcKey]) or (dstKey and guns[dstKey]) or sub == "PARTY_KILL")
                and Veh.Gun(s, fight, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a4, a5) then
                who = nil
            end
            local p = who and byName[who]
            local dst = dstName and byName[dstName]
            local inFight = ts >= fight.from and ts <= fight.to
            local mcSrc = srcName and byName[srcName] and srcFlags and band(srcFlags, F_PLAYER) == 0
                and band(srcFlags, F_BY_PLAYER) == 0 and srcName or nil
            if not s.pull and srcFlags and band(srcFlags, F_BY_PLAYER) > 0
                and (K.dmg or K.miss) and dstBoss then
                local swing = K.swing
                s.pull = { t = ts, src = srcName, spell = (not swing) and a2 or nil,
                           pet = band(srcFlags, F_PLAYER) == 0,
                           owner = srcGUID and owners[srcGUID] or nil }
            end
            if sub == "SPELL_CAST_SUCCESS" and p and dst and sk and srcName == who
                and s.given[sk] and (dstName ~= who or s.badges[s.given[sk]].self) then
                Given(s, fight, p, dst, sk, id, ts)
            end
            if dst and sk and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_REMOVED") then
                Buffed.Event(s, fight, sub, ts, id, sk, srcName and byName[srcName], dst)
                Buffed.Clash.Aura(fight, sub, ts, sk, id, dst)
            end
            if dst and sk and srcFlags and band(srcFlags, F_BY_PLAYER) == 0 and not (srcName and byName[srcName])
                and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_CAST_START") then
                Buffed.Rod(fight, sub, ts, sk, dst)
            end
            if acts and (acts.subs[sub] or (sk and acts.spells[sk])) then
                ns.Actions.Feed(acts, ts, sub, who, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5)
            end
            if mech and (not mechWant or (id and mechWant[id]) or sub == "FW_BTGT" or sub == "UNIT_DIED") then
                ns.ReplayMech.Event(mech, ts, sub, srcGUID, srcName, dstGUID, dstName, a1, a4, id)
            end
            if tp and tp.subs[sub] then ns.TombPull.Feed(tp, ts, sub, dstName, a1) end
            if tb and sub == "UNIT_DIED" then
                ns.TombBreak.Died(tb, ts, dstGUID)
            elseif tb and tb.subs[sub] then
                ns.TombBreak.Feed(tb, ts, sub, srcGUID, srcName, who, dstGUID, dstName, srcBoss, a1, a2, a4, a5)
            end
            if pa and pa.subs[sub] then ns.Parry.Feed(pa, ts, sub, srcName, dstKey, a1, a4) end
            if shades and ((srcKey and srcKey == shades.npc) or (dstKey and dstKey == shades.npc)
                or (dst and sk and shades.ex[sk])) then
                ns.Shades.Feed(shades, ts, sub, srcGUID, srcName, dstGUID, dstName, a1, a2, a4, mcSrc ~= nil)
            end
            if hc and dst and sk and hc.set[sk] then
                ns.Control.Feed(hc.c, ts, sub, srcName, dstName, sk, a2, mcSrc ~= nil)
            end
            if cg and dst and sk and cg.spells[sk] then ns.Caught.Feed(cg, ts, sub, srcGUID, dstName, sk, a1) end
            if pu and ((sk and pu.spells[sk]) or (srcKey and pu.npcs[srcKey]) or (dstKey and pu.npcs[dstKey])
                or sub == "UNIT_DIED") then
                ns.Putri.Feed(pu, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, a1, a2, a4, a5, who)
            end
            if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED" then
                ns.RaidPart.Mine(byName, fight, ts, sub, rwho, srcName, srcFlags, a1, dstName, dstFlags, a2)
            end
            if inFight then
                if fc then FC.Event(fc, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5, sk or false) end
                if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CREATE" or sub == "ENCHANT_APPLIED"
                    or sub == "SPELL_AURA_APPLIED" or sub == "FW_FLASK" then
                    ns.RaidPart.Consume(rp, sub, rwho, srcName, srcFlags, a1, dstName, dstFlags, a2)
                end
                if ctl then
                    ns.MindCtl.Feed(ctl, ts, sub, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a4, a5, a6, a7, a8)
                end
                local swing = K.swing
                if p and not dst and dstKey and s.bounce and s.bounce[dstKey]
                    and (K.dmg or (K.miss and (swing and a1 or a4) == "ABSORB")) then
                    Acc.Bounce(s, p, dstKey, swing and "#swing" or tostring(a2), ts - fight.from)
                end
                if K.dmg then
                    local env = K.env
                    local amount = tonumber(swing and a1 or env and a2 or a4) or 0
                    local apart = srcKey ~= nil and s.apart[srcKey] == true
                    if who and not apart and not env and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        ns.RaidPart.Hit(rp, rwho, dstGUID, dstFlags, amount - math.max(0, tonumber(swing and a2 or a5) or 0),
                            srcName ~= rwho and srcName or nil, swing, a1, a2)
                    end
                    if useful and dstName and ((dstKey and useful.names[dstKey]) or (who and useful.freed[who]))
                        and not dst and dstGUID and srcFlags and band(srcFlags, F_BY_PLAYER) > 0
                        and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        if p then
                            abHit.key = Acc.AbKey(s, swing, srcName, who, a2, srcKey)
                            abHit.crit, abHit.id = swing and a7 or a10, swing and MELEE_ID or a1
                        end
                        Acc.UsefulHit(s, useful, p, who, srcName == who, ts, dstGUID, dstKey, amount,
                            tonumber(swing and a2 or a5) or 0, swing and "#swing" or tostring(a2),
                            sub == "SPELL_PERIODIC_DAMAGE", abHit)
                    end
                    if apart and p and not dst and dstFlags and band(dstFlags, F_HOSTILE) > 0 then
                        p.ride = (p.ride or 0) + amount
                        p.rideName = p.rideName or srcName
                    elseif p and not dst and dstFlags and (band(dstFlags, F_HOSTILE) > 0
                        or (fight.boss == ns.ENC.dummy and dstBoss)) then
                        p.dmg = p.dmg + amount
                        ns.Totals.Act(tt, ts, sub)
                        ns.Totals.Damage(p, srcName ~= who, srcName, swing, a1, a2, amount, swing and a7 or a10)
                        Acc.DamageTo(s, p, who, dstName, dstKey, amount, srcName, swing, a2, swing and a7 or a10,
                            swing and MELEE_ID or a1, srcKey, dstGUID)
                        if dstBoss then p.bossDmg = p.bossDmg + amount end
                        if dstBoss or not bossOnly then
                            p.goodDmg = p.goodDmg + amount - math.max(0, tonumber(swing and a2 or a5) or 0)
                        end
                        if dstKey and watch.targets[dstKey] then
                            p.targetDmg[dstKey] = (p.targetDmg[dstKey] or 0) + amount
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
                        if swing and srcBoss then dst.bossMelee = dst.bossMelee + 1 end
                        if swing then Shed.SniffHit(fight, dst, ts, srcKey) end
                    end
                    if dst then
                        ns.Totals.Absorbed(tt, ts, dstName, swing and 1 or env and a4 or a3, amount,
                            tonumber(swing and a6 or env and a7 or a9) or 0)
                        local hit = { t = ts, spell = swing and "#melee" or env and ns.EnvName(a1) or a2,
                                      key = swing and "#melee" or env and ns.EnvKey(a1) or sk,
                                      src = srcName, srcKey = srcKey, mc = mcSrc,
                                      id = not swing and not env and id or nil,
                                      amount = amount, over = tonumber(swing and a2 or env and a3 or a5) }
                        if gw.npc and srcKey == gw.npc then ns.DeathGrade.Host(gw, hit, srcGUID) end
                        Remember(dst, hit)
                        if ts - dst.hurtT >= BURST then
                            dst.burstT, dst.burstGap, dst.burstHeal = ts, ts - dst.hurtT, dst.healIn
                        end
                        dst.hurtT, dst.healIn = ts, 0
                        if not swing and not env and sk and s.hurt[sk] and srcFlags and band(srcFlags, F_BY_PLAYER) == 0
                            and not (srcName and byName[srcName]) then
                            Acc.Hurt(s, dstName, sk, a2, srcKey, amount, false)
                        end
                        if sk and watch.hit[sk] then
                            dst.hits[sk] = dst.hits[sk] or {}
                            local list = dst.hits[sk]
                            list[#list + 1] = ts
                            s.spellIds[sk] = s.spellIds[sk] or id
                        end
                    end
                    if dst and srcName and byName[srcName] and srcName ~= dstName and srcFlags
                        and band(srcFlags, F_PLAYER) == 0 and band(srcFlags, F_BY_PLAYER) == 0 then
                        Friendly(srcName, swing and "#melee" or tostring(a2), amount, swing and a7 or a10,
                            swing and MELEE_ID or a1)
                    elseif dst and srcGUID and srcKey and fixates[srcKey] and not swing then
                        blasts[srcGUID] = (blasts[srcGUID] or 0) + amount
                    elseif dst and sk and friendlySpells[sk] and srcName and byName[srcName]
                        and srcName ~= dstName then
                        Friendly(srcName, tostring(a2), amount, a10, a1)
                    end
                elseif K.miss then
                    if dst and (swing and a1 or a4) == "ABSORB" then
                        ns.Totals.Absorbed(tt, ts, dstName, swing and 1 or a3, 0, tonumber(swing and a2 or a5) or 0)
                    end
                    if dst and swing and srcBoss then dst.bossMelee = dst.bossMelee + 1 end
                    if dst and swing then Shed.SniffHit(fight, dst, ts, srcKey) end
                    if p and not dst and dstKey and s.soaked[dstKey] and (swing and a1 or a4) == "ABSORB" then
                        Acc.DamageTo(s, p, who, dstName, dstKey, tonumber(swing and a2 or a5) or 0, srcName, swing, a2, nil,
                            swing and MELEE_ID or a1, srcKey)
                    end
                    if dst and not swing and sk and s.hurt[sk] and a4 == "ABSORB" and srcFlags
                        and band(srcFlags, F_BY_PLAYER) == 0 and not (srcName and byName[srcName]) then
                        Acc.Hurt(s, dstName, sk, a2, srcKey, tonumber(a5) or 0, true)
                    end
                elseif K.heal then
                    if dst then
                        ns.Totals.Healed(tt, ts, srcName, dstName, a4)
                        dst.healIn = dst.healIn + math.max(0, (tonumber(a4) or 0) - (tonumber(a5) or 0))
                    end
                    if p and dstFlags and band(dstFlags, F_HOSTILE) == 0 then
                        local eff = (tonumber(a4) or 0) - (tonumber(a5) or 0)
                        if eff > 0 then p.heal = p.heal + eff end
                        ns.Totals.Heal(p, a1, a2, eff, a7)
                        if eff > 0 and s.healTo and dstKey and s.healTo[dstKey] then
                            Acc.HealTo(s, who, dstKey, tostring(a2), eff)
                        end
                    end
                elseif (sub == "SPELL_DISPEL" or sub == "SPELL_STOLEN") and p then
                    p.dispels = p.dispels + 1
                    local dk = tostring(a2 or a1)
                    local d = p.disp[dk]
                    if not d then
                        d = { id = id, name = a2, n = 0, what = {} }
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
                    local xk = SpellKey(a4)
                    for i = 1, #s.blocks do
                        local b = s.blocks[i]
                        if b.def.kind == "dispels" and xk and SpellKey(b.def.spell) == xk then
                            b.total = b.total + 1
                            b.by[who] = (b.by[who] or 0) + 1
                        end
                    end
                    if sub == "SPELL_DISPEL" and dst and xk and s.cureSet[xk] then Acc.Cured(s, who, xk, a5) end
                    local ev = d.list or {}
                    d.list = ev
                    ev[#ev + 1] = { t = ts - fight.from, who = dstName, self = dstName == who or nil,
                        id = tonumber(a4), name = a5, purge = purge or nil,
                        label = def.cureLabels and xk and def.cureLabels[xk] or nil }
                elseif sub == "SPELL_INTERRUPT" and p then
                    p.interrupts = p.interrupts + 1
                    local kk = tostring(a2 or a1)
                    local k = p.kick[kk]
                    if not k then
                        k = { id = id, name = a2, n = 0, what = {} }
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
                    local xk = SpellKey(a4)
                    if xk and s.castSet[xk] then Acc.Kicked(s, who, xk, dstKey, tostring(a2)) end
                elseif sub == "SPELL_INSTAKILL" and dst then
                    Remember(dst, { t = ts, spell = a2, key = sk, src = srcName, srcKey = srcKey, id = id })
                elseif sub == "UNIT_DIED" and dst then
                    Died(dst, ts)
                elseif sub == "SPELL_RESURRECT" and dst then
                    dst.rezAt = ts
                elseif sub == "SPELL_CAST_SUCCESS" then
                    if p and srcName == who and sk and taunts[sk] then p.taunts = p.taunts + 1 end
                    if p and srcName == who and sk and tankSpells[sk] then p.tankCasts = p.tankCasts + 1 end
                    if p and srcName == who and id and defensives[id] then Acc.Guard(p, ts, id) end
                    if p and srcName == who and gw.tranq and sk == gw.tranq then ns.DeathGrade.Tranq(p, ts) end
                    if p and srcName == who and sk and watch.casts[sk] then
                        p.casts[sk] = (p.casts[sk] or 0) + 1
                    end
                    if mcSrc and sk and watch.mc[sk] then
                        local mp = byName[mcSrc]
                        mp.mcCasts[#mp.mcCasts + 1] = { t = ts, spell = sk }
                        s.spellIds[sk] = s.spellIds[sk] or id
                    end
                end
                if (sub == "SPELL_CAST_START" or sub == "SPELL_CAST_SUCCESS") and sk and s.castSet[sk]
                    and srcFlags and band(srcFlags, F_BY_PLAYER) == 0 then
                    Acc.EnemyCast(s, sk, srcKey, sub == "SPELL_CAST_START")
                end
                if dst and sub == "SPELL_AURA_APPLIED" and sk then
                    for i = 1, #s.extra do
                        local x = s.extra[i]
                        if x.def.kind == "auras" and x.set[sk] then x.times[#x.times + 1] = ts end
                    end
                end
                if dst and sub == "SPELL_AURA_APPLIED" and sk and watch.hit[sk] then
                    dst.hits[sk] = dst.hits[sk] or {}
                    local list = dst.hits[sk]
                    list[#list + 1] = ts
                    s.spellIds[sk] = s.spellIds[sk] or id
                end
                if dst and sk and s.stacked and s.stacked[sk]
                    and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_APPLIED_DOSE") then
                    Acc.Peak(s, dstName, sk, sub == "SPELL_AURA_APPLIED" and 1 or tonumber(a5) or 0)
                end
                if dst and sub == "SPELL_AURA_APPLIED" and sk and immune[sk] then
                    local who = srcName ~= dstName and byName[srcName or ""] and srcName or nil
                    lastImmune[dstName] = { t = ts, key = sk, who = who }
                    Shed.By(dst, badges, ts, sk, who)
                end
                if swing and dst and srcKey and srcGUID and chasers[srcGUID] == nil and ns.Shades then
                    ns.Shades.Chaser(chasers, s, watch.npcs, srcGUID, srcName, srcKey)
                end
                local ch = swing and dst and srcGUID and chasers[srcGUID]
                if ch and not ch.victim then
                    ch.victim = dstName
                    if ch.key and watch.npcs[ch.key] then
                        dst.chased[ch.key] = dst.chased[ch.key] or {}
                        local list = dst.chased[ch.key]
                        list[#list + 1] = ts
                        s.spellIds[ch.key] = s.spellIds[ch.key] or ch.id
                    end
                end
                local lst = dst and sk and liveSk[sk]
                for j = 1, lst and #lst or 0 do
                    local i = lst[j]
                    local bd = badges[i]
                    local bk = Keys(bd)
                    if bd.kind == "aura" and not (bd.exact and not bd.shed[id or 0]) then
                        local st = dst.badges[i]
                        local new = sub == "SPELL_AURA_APPLIED"
                        if bd.shed then
                            new = Shed.Aura(st, bd, sub, ts, id, fight.from, lastImmune[dstName])
                            if new then
                                local h = st.hangs[#st.hangs]
                                h.lockId, h.lockOn = ns.DeathGrade.LockAt(dst, ts)
                            end
                        end
                        if new then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                            s.icons[i] = s.icons[i] or id
                        end
                    elseif bd.kind == "ticks" and K.periodic then
                        local st = dst.badges[i]
                        st.ticks = st.ticks or {}
                        st.ticks[#st.ticks + 1] = ts
                        s.icons[i] = s.icons[i] or bd.id or id
                    elseif bd.kind == "stack" then
                        local st = dst.badges[i]
                        if sub == "SPELL_AURA_APPLIED" and st.times[#st.times] ~= ts - fight.from then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                            if st.max < 1 then st.max = 1 end
                            s.icons[i] = s.icons[i] or id
                        elseif sub == "SPELL_AURA_APPLIED_DOSE" or (bd.low and sub == "SPELL_AURA_REMOVED_DOSE") then
                            local stacks = tonumber(a5) or 0
                            if stacks > st.max then st.max = stacks end
                            if bd.low and ts <= fight.to - LOW_END then
                                st.fin = stacks
                                if not st.min or stacks < st.min then st.min = stacks end
                            end
                        elseif sub == "SPELL_AURA_REMOVED" and st.rmAt ~= ts and not (bd.low and ts > fight.to - LOW_END) then
                            st.rmAt = ts
                            st.removed = (st.removed or 0) + 1
                            if bd.low then st.fin, st.min = 0, 0 end
                            s.icons[i] = s.icons[i] or bd.id or id
                        end
                    elseif bd.kind == "hit" and (K.dmg or (bd.ticks and K.miss))
                        and (not bk.src or bk.src == srcKey)
                        and (not bd.min or (tonumber(a4) or 0) > bd.min)
                        and not (bd.alive and (tonumber(a5) or 0) > 0) then
                        local st = dst.badges[i]
                        st.hits = st.hits + 1
                        st.amount = st.amount + (tonumber(a4) or 0)
                        if not st.last or ts - st.last > (bd.gap or HIT_GAP) then st.run, st.from = 0, ts end
                        st.run = st.run + 1
                        if st.run > (st.peak or 0) then st.peak = st.run end
                        if st.run == (bd.ticks or 1) then
                            st.n = st.n + 1
                            st.times[#st.times + 1] = st.from - fight.from
                        end
                        st.last = ts
                        s.icons[i] = s.icons[i] or id
                    end
                end
                lst = swing and dst and srcKey and srcGUID and liveNpc[srcKey]
                local ch2 = lst and chasers[srcGUID]
                if ch2 and not ch2.counted then
                    ch2.counted = true
                    local i = lst[1]
                    local st = dst.badges[i]
                    st.n = st.n + 1
                    st.times[#st.times + 1] = ts - fight.from
                    s.icons[i] = s.icons[i] or ch2.id or badges[i].id
                end
                if p and sub == "SPELL_AURA_APPLIED" and sk then
                    for j = 1, #liveApplied do
                        local i = liveApplied[j]
                        local bd = badges[i]
                        if Acc.AppliedHit(bd, sk, dstKey, dst ~= nil and dstName ~= who) then
                            local st = p.badges[i]
                            st.n = st.n + 1
                            st.times[#st.times + 1] = ts - fight.from
                            if dst then st.notes[#st.notes + 1] = dstName end
                            if #bd.spells > 1 then
                                st.keys, st.ids = st.keys or {}, st.ids or {}
                                st.keys[st.n], st.ids[st.n] = sk, id or false
                                if bd.names then
                                    st.tg = st.tg or {}
                                    st.tg[st.n] = dstName or "?"
                                end
                            end
                            s.icons[i] = s.icons[i] or bd.id or id
                        end
                    end
                end
            end
        end
    end
    if ach then ns.Achievements.Tail(ach, segs[si], to) end
    end
    ns.Jobs.Part(WALK_SHARE, 1)
    SS.Finish(sg, s.players)
    if ns.Achievements then s.ach = ach and ns.Achievements.Finish(ach) or {} end
    for guid, amount in pairs(blasts) do
        local ch = chasers[guid]
        if ch and ch.victim and byName[ch.victim] then Friendly(ch.victim, "#shade", amount, nil, ch.id) end
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
                if b.def.kind == "dispels" and SpellKey(b.def.spell) == rm.key and b.def.totems then
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
    Deaths.DropFake(s, fight)
    ns.Jobs.Progress(1, FINISH_STEPS)
    if acts then ns.Actions.Finish(acts) end
    if shades then ns.Shades.Finish(shades) end
    if cg then ns.Caught.Finish(cg) end
    if df then ns.Defile.Finish(df) end
    if lm then ns.LichMech.Finish(lm) end
    if tp then ns.TombPull.Finish(tp) end
    if tb then ns.TombBreak.Finish(tb) end
    if mech then ns.ReplayMech.Finish(mech) end
    if pu then ns.Putri.Finish(pu) end
    Veh.RideEnd(s, fight)
    Veh.GunEnd(s, fight)
    if track then s.phases = ns.Phases.Done(fight, track) end
    if stk then ns.StackEps.Finish(stk, s) end
    if ctl then ns.MindCtl.Finish(ctl, s, fight.to) end
    if ns.PullTimer then ns.PullTimer.Judge(s) end
    ns.Totals.Finish(tt, s)
    Finish(s, fight)
    ns.Jobs.Progress(2, FINISH_STEPS)
    if fc then
        if mech then ns.ReplayMech.FeedRows(mech, fc) end
        local L = { tanks = {} }
        for i = 1, #s.players do
            if s.players[i].role == "tank" then L.tanks[s.players[i].name] = true end
        end
        FC.Done(fc, L, s.phases)
        s.feed = FC.Pack(L)
    end
    ns.Jobs.Progress(3, FINISH_STEPS)
    if pa then ns.Parry.Finish(pa) end
    if hc then ns.Control.Finish(hc) end
    if rf then ns.RFury.Finish(rf) end
    if cv then ns.SummaryCover.Finish(cv) end
    if pl then ns.SummaryPull.Finish(pl) end
    if rs then ns.RuneSwap.Finish(rs) end
    if bn then ns.BloodNova.Finish(bn) end
    if ns.Away then ns.Away.Run(s, fight) end
    if zb then s.zoneBuff = ns.ZoneBuff.Finish(zb) end
    if et then ns.EffTime.Finish(et, s) end
    s.rp = ns.RaidPart.Close(rp, s.players)
    for i = 1, #s.blocks do
        Acc.AbTrim(s.blocks[i].ab)
        for _, h in pairs(s.blocks[i].gab or {}) do Acc.AbTrim(h.ab) end
    end
    return s
end
Summary.Build = Build
Summary.Sniff = { Hit = Shed.SniffHit, Done = Shed.Sniffed }
Summary.Shed = { Aura = Shed.Aura, By = Shed.By, Close = Shed.Close }
local function JobKey(fight)
    local key = running[fight]
    if not key then
        key = {}
        running[fight] = key
    end
    return key
end
function Summary.Now(fight)
    local s = Summary.Peek(fight)
    if s then return s end
    s = Summary.Build(fight)
    ns.Jobs.Progress(FINISH_STEPS - 1, FINISH_STEPS)
    if ns.Digest then ns.Digest.Save(fight, s) end
    return Keep(fight, s)
end
function Summary.Busy(fight)
    local key = running[fight]
    return key ~= nil and ns.Jobs.Busy(key)
end
function Summary.Failed(fight)
    local key = running[fight]
    return key ~= nil and ns.Jobs.Failed(key) or nil
end
function Summary.Of(fight, onDone)
    local have = Summary.Peek(fight)
    if have then
        Touch(fight)
        onDone(have)
        return
    end
    for other, key in pairs(running) do
        if other ~= fight then ns.Jobs.Cancel(key) end
    end
    ns.Jobs.Run(JobKey(fight), function()
        return Summary.Now(fight)
    end, function(s)
        if s then onDone(s) end
    end, "sum.frame", true)
end
function Summary.Reset()
    for k in pairs(cache) do cache[k] = nil end
    for i = #order, 1, -1 do order[i] = nil end
end
