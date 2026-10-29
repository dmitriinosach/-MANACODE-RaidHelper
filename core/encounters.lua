local _, ns = ...
local tinsert = table.insert
local tsort = table.sort
local max = math.max
local min = math.min
local floor = math.floor
local sqrt = math.sqrt
local band = bit.band
local find = string.find
local NpcKey = ns.NpcKey
local SubKind = ns.SubKind
local IDLE_GAP = 15
local RESUME_GAP = 180
local MIN_FIGHT = 20
local MIN_DUMMY = 3
local FX_VERSION = 5
local SCAN_VERSION = 16
local CLS_VERSION = 1
local CAST_WINDOW = 3
local REVIVE_GAP = 2
local PROGRESS_EVERY = 512
local SCAN_KEY = {}
local TL_KEY = {}
local POS_KEY = {}
local F_PLAYER = ns.F.PLAYER
local F_HOSTILE = ns.F.HOSTILE
local F_FRIENDLY = ns.F.FRIENDLY
local F_BY_PLAYER = ns.F.BY_PLAYER
local HP_TAIL = 5
local function HpKilled(f)
    local db = ns.GetDB()
    local list = f.segs or { f.seg }
    for k = 1, #list do
        local seg = db.segments[list[k]]
        if seg and seg.hp then
            for key in pairs(seg.hp) do
                if key:byte(1) == 35 and NpcKey("0x" .. key:sub(2)) == f.boss then
                    local last
                    for t, hp, top in ns.Decode.Hp(seg, key, f.from, f.to + HP_TAIL) do
                        if t > f.to + HP_TAIL then break end
                        if t >= f.from and top > 0 then last = hp / top end
                    end
                    if last and last <= 0 then return true end
                end
            end
        end
    end
    return false
end
local BOSS_SUBS = {
    SPELL_CAST_SUCCESS = true,
    SPELL_CAST_START = true,
    SPELL_SUMMON = true,
    SPELL_AURA_APPLIED = true,
}
local MISSED_SUBS = {
    SWING_MISSED = true,
    SPELL_MISSED = true,
    RANGE_MISSED = true,
    SPELL_PERIODIC_MISSED = true,
    SPELL_BUILDING_MISSED = true,
}
local Encounters = {}
ns.Encounters = Encounters
Encounters.BOSS_SUBS = BOSS_SUBS
local fights = nil
local stale = false
local pressed = {}
local dummyRec = false
local function EncounterIn(guid, name, auto, alias, dummy)
    local key = NpcKey(guid)
    if key == nil or ns.trashBosses[key] then return nil end
    local enc = ns.bosses[key] or (alias ~= nil and alias[key]) or nil
    if enc then return enc end
    if dummy and ns.dummies[key] then return ns.ENC.dummy end
    if auto and name and auto[name] then
        ns.NoteNpcKey(key, name)
        return key
    end
    return nil
end
local function Yielded(guid, flags, seen)
    local key = NpcKey(guid)
    local enc = key ~= nil and ns.bosses[key] or nil
    if enc == nil or flags == nil or not (ns.bossYield and ns.bossYield[enc]) then return nil end
    if band(flags, F_HOSTILE) > 0 then
        if seen then seen[key] = true end
        return nil
    end
    if band(flags, F_FRIENDLY) > 0 and (seen == nil or seen[key]) then return enc end
    return nil
end
local function EndOf(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, auto, alias, seen)
    if sub == "UNIT_DIED" or sub == "PARTY_KILL" then
        local key = NpcKey(dstGUID)
        if key == nil or (ns.bossParts and ns.bossParts[key]) then return nil, nil, false end
        local enc = EncounterIn(dstGUID, dstName, auto, alias)
        if enc == nil then return nil, nil, false end
        local last = ns.bossLast and ns.bossLast[enc]
        if last ~= nil and not last[key] then return nil, nil, false end
        return enc, key, true
    end
    local enc = Yielded(srcGUID, srcFlags, seen)
    if enc then return enc, NpcKey(srcGUID), false end
    enc = Yielded(dstGUID, dstFlags, seen)
    if enc then return enc, NpcKey(dstGUID), false end
    if srcGUID == nil or spellId == nil or sub == "SPELL_CAST_START" then return nil, nil, false end
    enc = EncounterIn(srcGUID, srcName, auto, alias)
    local win = enc and ns.bossWin[enc]
    if win ~= nil and win[ns.SpellKey(spellId)] then return enc, NpcKey(srcGUID), false end
    return nil, nil, false
end
function Encounters.Of(guid, name, auto)
    return EncounterIn(guid, name, auto, nil, dummyRec)
end
function Encounters.SetDummy(on)
    dummyRec = on and true or false
end
function Encounters.Dummy()
    return dummyRec
end
local function MinFight(f)
    return f.boss == ns.ENC.dummy and MIN_DUMMY or MIN_FIGHT
end
function Encounters.IsDummy(key)
    return dummyRec and key ~= nil and ns.dummies[key] == true
end
function Encounters.Ending(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, auto, seen)
    local enc, who, died = EndOf(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, auto, nil,
        seen)
    if enc == nil then return nil, nil, false end
    return enc, who, not died or ns.bosses[who] ~= nil
end
local IsBossOf = ns.IsBossOf
local RAID_MAPS = {
    IcecrownCitadel = true, Ulduar = true, TheArgentColiseum = true, TheRubySanctum = true, Naxxramas = true,
    TheObsidianSanctum = true, TheEyeofEternity = true, OnyxiasLair = true, VaultofArchavon = true,
}
function Encounters.MapOf(seg)
    if not seg then return nil end
    local raid = seg.raid
    if raid and raid.map and RAID_MAPS[raid.map] then return raid.map end
    local maps = seg.maps
    if type(maps) == "table" then maps = table.concat(maps, ";") end
    if type(maps) ~= "string" then return nil end
    for name in string.gmatch(maps, "%-?%d+:%d+:(%a+)") do
        if RAID_MAPS[name] then
            if raid then raid.map = name end
            return name
        end
    end
    return nil
end
local function Busy(open, ts)
    local best = nil
    for _, f in pairs(open) do
        if ts - f.last <= IDLE_GAP and (not best or f.last > best.last) then
            best = f
        end
    end
    return best
end
local function SegsOf(fight)
    local want = {}
    if fight.segs then
        for k = 1, #fight.segs do want[fight.segs[k]] = true end
    elseif fight.seg then
        want[fight.seg] = true
    end
    local out = {}
    for i, s in ns.Store.Segments() do
        if want[i] then out[#out + 1] = s end
    end
    return out
end
Encounters.Segs = SegsOf
local function Resumable(found, enc, ts)
    if enc == ns.ENC.dummy or not (ns.scriptedKills and ns.scriptedKills[enc]) then return nil end
    for k = #found, 1, -1 do
        local f = found[k]
        if f.boss == enc then
            if not f.killed and not f.wipe and ts - f.to <= RESUME_GAP then return f end
            return nil
        end
    end
    return nil
end
local function StatOf(stats, id, name)
    local s = stats[id]
    if not s then
        s = { name = name, n = 0, debuff = 0, hostile = 0, mine = 0, cast = 0,
              tg = {}, tn = 0 }
        stats[id] = s
    end
    return s
end
local function NoteClasses(seg)
    local info = GetPlayerInfoByGUID
    local classes = ns.GetDB().classes
    if not info or not classes then return end
    local actors = ns.Decode.Tables(seg).actors
    for k = 1, #actors do
        local g, n, f = string.match(actors[k], "^([^\31]*)\31([^\31]*)\31(%-?%d*)$")
        if g and n and n ~= "" and not classes[n] and band(tonumber(f) or 0, F_PLAYER) > 0 then
            local _, cls = info(g)
            if cls then classes[n] = cls end
        end
    end
end
local function AbsorbSaved(seg)
    if type(seg.fx) ~= "string" then return false end
    local stats, ok = ns.Codec.Decode(seg.fx, nil)
    if not ok or type(stats) ~= "table" then return false end
    ns.Effects.Absorb(stats)
    return true
end
local function PackFx(stats)
    local out = {}
    for id, s in pairs(stats) do
        out[id] = { name = s.name, n = s.n, debuff = s.debuff, hostile = s.hostile, mine = s.mine, cast = s.cast, tn = s.tn }
    end
    return ns.Codec.Encode(out, nil, nil)
end
local function Pressed(log)
    for name, list in pairs(log or {}) do
        local all = pressed[name]
        if not all then
            all = {}
            pressed[name] = all
        end
        for k = 1, #list do all[#all + 1] = list[k] end
    end
end
function Encounters.Pressed(name)
    return pressed[name]
end
local function Wiped(f)
    local list = f.dts
    if not list or #list == 0 then return false end
    local n, down = 0, 0
    for _ in pairs(f.players) do n = n + 1 end
    for _ in pairs(f.down or {}) do down = down + 1 end
    return ns.Deaths.Wiped(list, n, f.last or f.to, down)
end
local ALIVE_SRC = { SPELL_CAST_SUCCESS = true, SPELL_CAST_START = true, SWING_DAMAGE = true, SWING_MISSED = true,
                    RANGE_DAMAGE = true, RANGE_MISSED = true }
local GROUP_MATE = 0x06
local function ConfirmProgress(group, boss, proof)
    if group.done[boss] then return end
    group.done[boss] = true
    local last = group.last[boss]
    if boss ~= proof.boss and last and not last.killed and last.to < proof.from then
        last.progress = proof.boss
        if not last.wipe then last.killed, last.byProgress = true, true end
    end
    local required = ns.bossRequires and ns.bossRequires[boss]
    if not required then return end
    for i = 1, #required do ConfirmProgress(group, required[i], proof) end
end
local function RecheckProgress(list)
    local groups = {}
    local was = {}
    for i = 1, #list do
        local f = list[i]
        was[i] = f.killed
        if f.byProgress then f.killed, f.byProgress = false, nil end
        f.progress = nil
    end
    for i = #list, 1, -1 do
        local f = list[i]
        local r = f.raid
        if r and r.id and r.id > 0 and r.size and r.map == "IcecrownCitadel" and f.mates ~= false then
            local key = tostring(r.id) .. ":" .. tostring(r.size)
            local group = groups[key]
            if not group then
                group = { last = {}, done = {} }
                groups[key] = group
            end
            if f.killed then
                ConfirmProgress(group, f.boss, f)
            else
                group.last[f.boss] = f
            end
        end
    end
    for i = 1, #list do
        if was[i] ~= list[i].killed then
            if ns.Summary then ns.Summary.Reset() end
            if ns.RaidSummary then ns.RaidSummary.Reset() end
            break
        end
    end
end
local function ScanAll()
    local found = {}
    local listed = {}
    local alias = {}
    local segIndex = 0
    local Deaths = ns.Deaths
    local hitAt, hitSeg, hitS, hitPos, hitGen, hitSub, quiet = {}, {}, {}, {}, {}, {}, {}
    local function HitId(who)
        local sub = hitSub[who]
        if not sub then return nil end
        if SubKind[sub].swing then return false end
        return (ns.Decode.Tail(hitSeg[who], hitS[who], hitPos[who], hitGen[who], sub, 1))
    end
    local function Settle(f)
        local list = quiet[f]
        if not list then return end
        local n = 0
        for _ in pairs(f.players) do n = n + 1 end
        Deaths.MarkWaves(list, n)
        for k = 1, #list do
            local d = list[k]
            if d.scripted and not d.gone then
                d.gone = true
                f.deaths = f.deaths - 1
                f.players[d.who] = f.players[d.who] - 1
            end
        end
    end
    local function Push(f)
        f.down = nil
        if ns.trashBosses[f.boss] then return end
        local home = f.seg and f.seg > 0 and ns.GetDB().segments[f.seg]
        if home and ns.Digest and ns.Digest.Frozen(home) then return end
        Settle(f)
        ns.NoteNpcKey(f.boss, f.title)
        if listed[f] then return end
        listed[f] = true
        if not f.killed and not f.hpSeen and not (ns.bossSurvive and ns.bossSurvive[f.boss]) then
            f.hpSeen = true
            if HpKilled(f) then
                f.killed, f.wipe, f.byHp = true, nil, true
            end
        end
        if not f.killed and ns.bossSurvive and ns.bossSurvive[f.boss] then
            local n = 0
            for _ in pairs(f.players) do n = n + 1 end
            f.killed = n > 0 and f.deaths * 2 < n
        end
        tinsert(found, f)
    end
    local db = ns.GetDB()
    if db.fxVersion ~= FX_VERSION then
        ns.Effects.ResetCounts()
        for _, seg in ns.Store.Segments() do
            seg.fxNoted = nil
        end
        db.fxVersion = FX_VERSION
    end
    local segTotal = #db.segments
    local defensives = ns.defensives or {}
    local raidCovers = ns.covers and ns.covers.raid or {}
    pressed = {}
    ns.Jobs.Label("job.scan", true)
    for i, seg in ns.Store.Segments() do
        segIndex = i
        ns.Jobs.Progress(i - 1, segTotal)
        local noteEffects = seg.fxNoted ~= FX_VERSION
        if seg.clsNoted ~= CLS_VERSION then
            NoteClasses(seg)
            seg.clsNoted = CLS_VERSION
        end
        local cached = seg.scan
        if cached and (seg.bare or cached.v == SCAN_VERSION) and (not noteEffects or seg.bare or AbsorbSaved(seg)) then
            seg.fxNoted = FX_VERSION
            for k = 1, #cached.fights do
                local f = cached.fights[k]
                f.seg = i
                f.raid = seg.raid
                Push(f)
            end
            if cached.alias then
                for name, enc in pairs(cached.alias) do alias[name] = enc end
            end
            Pressed(cached.guards)
            ns.Jobs.Yield()
        else
        local auto = seg.bosses
        local full = ns.fullRegistry and ns.fullRegistry[Encounters.MapOf(seg) or ""]
        local own = not full and auto or nil
        local dummy = seg.dummy == true or dummyRec
        local bossSeen = {}
        local segAlias = {}
        local open = {}
        local openCount = 0
        local fxStats, castAt = {}, {}
        local Tail = ns.Decode.Tail
        local guards = {}
        local seen, perEvent = 0, 1 / max(1, tonumber(seg.n) or 1)
        for s, pos, gen, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags in ns.Decode.Scan(seg) do
            ns.Jobs.Step()
            seen = seen + 1
            if seen % PROGRESS_EVERY == 0 then ns.Jobs.Progress(i - 1 + seen * perEvent, segTotal) end
            if srcName and (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_START") then
                local id = tonumber((Tail(seg, s, pos, gen, sub, 1)))
                if id then
                    castAt[srcName .. "\0" .. id] = ts
                    if sub == "SPELL_CAST_SUCCESS" and srcFlags and bit.band(srcFlags, F_PLAYER) > 0
                        and (defensives[id] or raidCovers[id]) then
                        local list = guards[srcName]
                        if not list then
                            list = {}
                            guards[srcName] = list
                        end
                        list[#list + 1] = ts
                        list[#list + 1] = id
                    end
                end
            elseif srcName and sub == "SPELL_AURA_APPLIED" and dstFlags and bit.band(dstFlags, F_PLAYER) > 0 then
                local a1, a2, _, a4 = Tail(seg, s, pos, gen, sub, 4)
                local id = tonumber(a1)
                if id then
                    local st = StatOf(fxStats, id, a2)
                    st.n = st.n + 1
                    if a4 == "DEBUFF" then st.debuff = st.debuff + 1 end
                    if srcFlags and bit.band(srcFlags, F_HOSTILE) > 0 then
                        st.hostile = st.hostile + 1
                    end
                    if srcName == dstName then st.mine = st.mine + 1 end
                    local at = castAt[srcName .. "\0" .. id]
                    if at and ts - at <= CAST_WINDOW then st.cast = st.cast + 1 end
                    if dstName and not st.tg[dstName] then
                        st.tg[dstName] = true
                        st.tn = st.tn + 1
                    end
                end
            end
            local asSrc = EncounterIn(srcGUID, srcName, own, alias, dummy)
            local asDst = EncounterIn(dstGUID, dstName, own, alias, dummy)
            local K = SubKind[sub]
            local hurt = K.dmg
            local touched = hurt or K.heal
            if (hurt or sub == "SPELL_INSTAKILL") and dstName and dstFlags
                and bit.band(dstFlags, F_PLAYER) > 0 then
                hitAt[dstName] = ts
                hitSeg[dstName], hitS[dstName], hitPos[dstName], hitGen[dstName], hitSub[dstName] = seg, s, pos, gen, sub
            end
            local byPlayer = touched and srcFlags ~= nil
                and bit.band(srcFlags, F_BY_PLAYER) > 0
            local dstKey = byPlayer and auto ~= nil and dstName ~= nil and auto[dstName] and NpcKey(dstGUID)
            if dstKey and not ns.bosses[dstKey] and not ns.trashBosses[dstKey] and not alias[dstKey] and not open[dstKey] then
                local host = Busy(open, ts)
                if host then
                    alias[dstKey] = host.boss
                    segAlias[dstKey] = host.boss
                    host.names = host.names or {}
                    host.names[dstKey] = true
                    asDst = host.boss
                end
            end
            local enc = asDst or asSrc
            if enc then
                local f = open[enc]
                local pulled = asDst ~= nil and byPlayer
                    and not (ns.bossYield and ns.bossYield[asDst] and dstFlags ~= nil
                        and bit.band(dstFlags, F_FRIENDLY) > 0)
                local stale = f ~= nil
                    and (ts - f.last > (f.killed and IDLE_GAP or RESUME_GAP)
                        or (not f.killed and ts - f.last > IDLE_GAP and Wiped(f)))
                if pulled and (not f or stale) then
                    if f and f.to - f.from >= MinFight(f) then
                        f.wipe = (not f.killed and Wiped(f)) or nil
                        Push(f)
                    end
                    if not open[enc] then openCount = openCount + 1 end
                    f = not f and Resumable(found, enc, ts) or nil
                    if f then
                        f.segs = f.segs or { f.seg }
                        f.segs[#f.segs + 1] = segIndex
                        f.last = ts
                    else
                        f = { boss = enc, from = ts, to = ts, last = ts, killed = false,
                              deaths = 0, seg = segIndex, players = {}, raid = seg.raid, title = dstName,
                              mates = false }
                    end
                    open[enc] = f
                end
                if f and (pulled or not stale) and not (f.won and ns.bossYield and ns.bossYield[enc]) then
                    f.last = ts
                    f.to = ts
                    if pulled and enc == ns.ENC.dummy then
                        f.names = f.names or {}
                        f.names[NpcKey(dstGUID)] = true
                    end
                    if f.killed and pulled and not f.won
                        and ts - (f.diedAt or ts) > REVIVE_GAP then
                        f.killed = false
                    end
                    local a1 = nil
                    if asSrc and ns.bossWin[asSrc] and sub ~= "UNIT_DIED" and sub ~= "PARTY_KILL"
                        and sub ~= "SPELL_CAST_START" then
                        a1 = Tail(seg, s, pos, gen, sub, 1)
                    end
                    local ended, _, died = EndOf(sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                        a1, own, alias, bossSeen)
                    if ended == enc then
                        f.killed = true
                        if died then f.diedAt = ts else f.won = true end
                    end
                end
            end
            if openCount > 0 then
                for _, f in pairs(open) do
                    if ts - f.last <= IDLE_GAP then
                        if srcFlags and bit.band(srcFlags, F_PLAYER) > 0 and srcName then
                            f.players[srcName] = f.players[srcName] or 0
                            if bit.band(srcFlags, GROUP_MATE) > 0 then f.mates = true end
                            if f.down and ALIVE_SRC[sub] then f.down[srcName] = nil end
                        end
                        if dstFlags and bit.band(dstFlags, F_PLAYER) > 0 and dstName then
                            f.players[dstName] = (f.players[dstName] or 0)
                            if bit.band(dstFlags, GROUP_MATE) > 0 then f.mates = true end
                            if f.down and sub == "SPELL_RESURRECT" then f.down[dstName] = nil end
                            if sub == "UNIT_DIED" then
                                local at = hitAt[dstName]
                                local hit = at ~= nil and ts - at <= Deaths.KILL_WINDOW
                                if not (hit and Deaths.ByScript(f.boss, HitId(dstName))) then
                                    f.players[dstName] = f.players[dstName] + 1
                                    f.deaths = f.deaths + 1
                                    local dts = f.dts or {}
                                    f.dts = dts
                                    dts[#dts + 1] = ts
                                    f.down = f.down or {}
                                    f.down[dstName] = true
                                    if not hit then
                                        local list = quiet[f] or {}
                                        quiet[f] = list
                                        list[#list + 1] = { t = ts, who = dstName }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        for _, f in pairs(open) do
            f.wipe = (not f.killed and Wiped(f)) or nil
            f.dts = nil
            f.down = nil
            if f.to - f.from >= MinFight(f) then
                Push(f)
            end
        end
        ns.Effects.Absorb(fxStats)
        seg.fx = PackFx(fxStats)
        seg.fxNoted = FX_VERSION
        local mine = {}
        for k = 1, #found do
            if found[k].seg == i then
                local f = found[k]
                f.last = nil
                f.diedAt = nil
                f.won = nil
                f.dts = nil
                mine[#mine + 1] = f
            end
        end
        seg.scan = { v = SCAN_VERSION, fights = mine, alias = segAlias, guards = guards }
        Pressed(guards)
        end
    end
    ns.Jobs.Progress(segTotal, segTotal)
    local kept = {}
    for k = 1, #found do
        local f = found[k]
        local seg = db.segments[f.seg]
        if not (seg and seg.cut and seg.cut[Encounters.Key(f)]) then kept[#kept + 1] = f end
    end
    tsort(kept, function(a, b) return a.from > b.from end)
    RecheckProgress(kept)
    return kept
end
function Encounters.Ready()
    return fights ~= nil and not stale
end
function Encounters.Fights()
    return fights or {}
end
function Encounters.Reset()
    ns.Jobs.Cancel(SCAN_KEY)
    fights = nil
end
function Encounters.Invalidate()
    stale = true
end
local function Shifted(k, at, removed)
    if k < at then return k end
    if k >= at + removed then return k - removed end
    return nil
end
local function ShiftList(list, at, removed)
    if not list then return nil end
    local out = {}
    for k = 1, #list do
        local n = Shifted(list[k], at, removed)
        if n then out[#out + 1] = n end
    end
    return #out > 0 and out or nil
end
function Encounters.Key(fight)
    return string.format("%s|%.0f", fight.boss, floor(fight.from * 1000 + 0.5))
end
function Encounters.Dropped(dropped, at)
    if dropped then
        local removed = #dropped
        at = at or 1
        for i = 1, removed do
            local scan = dropped[i].scan
            for k = 1, (scan and scan.fights and #scan.fights or 0) do
                scan.fights[k].seg = 0
                scan.fights[k].segs = nil
            end
        end
        for _, seg in ns.Store.Segments() do
            local scan = seg.scan
            for k = 1, (scan and scan.fights and #scan.fights or 0) do
                local f = scan.fights[k]
                f.seg = Shifted(f.seg or 0, at, removed) or 0
                f.segs = ShiftList(f.segs, at, removed)
            end
        end
    elseif ns.Summary then
        ns.Summary.Reset()
    end
    stale = true
    if ns.Index then ns.Index.Reset() end
end
function Encounters.ResetCache()
    if ns.Jobs.Busy(SCAN_KEY) then return false end
    for _, seg in ns.Store.Segments() do
        if not seg.bare then
            seg.scan = nil
            seg.fxNoted = nil
            seg.clsNoted = nil
        end
    end
    ns.GetDB().fxVersion = nil
    fights = nil
    stale = false
    return true
end
function Encounters.Scan(onDone)
    if stale and not ns.Jobs.Busy(SCAN_KEY) then
        stale = false
        fights = nil
    end
    if fights then
        onDone()
        return false
    end
    return ns.Jobs.Run(SCAN_KEY, function()
        local list = ScanAll()
        ns.Effects.Migrate()
        return list
    end, function(list)
        fights = list or {}
        if ns.FightTree then ns.FightTree.Lend(fights) end
        onDone()
    end, "scan.frame")
end
local LEAD = ns.PULL_LEAD
local TAIL = 20
function Encounters.Lead(fight)
    local lead = fight.from - LEAD
    local list = fights or {}
    for i = 1, #list do
        local f = list[i]
        if f ~= fight and f.seg == fight.seg and f.to < fight.from and f.to > lead then
            lead = f.to
        end
    end
    for i, s in ns.Store.Segments() do
        if i == fight.seg and s.t0 and lead < s.t0 then lead = s.t0 end
    end
    return lead
end
function Encounters.Tail(fight)
    local tail = fight.to + TAIL
    local list = fights or {}
    for i = 1, #list do
        local f = list[i]
        if f ~= fight and f.seg == fight.seg and f.from > fight.to and f.from < tail then
            tail = f.from
        end
    end
    local last = fight.segs and fight.segs[#fight.segs] or fight.seg
    for i, s in ns.Store.Segments() do
        if i == last and s.t1 and tail > s.t1 then tail = s.t1 end
    end
    return tail
end
local CLASS_ORDER = ns.CLASS_ORDER
function Encounters.ClassOf(name)
    return ns.GetDB().classes[name]
end
function Encounters.Players(fight)
    local list = {}
    for name, deaths in pairs(fight.players) do
        list[#list + 1] = { name = name, deaths = deaths or 0,
                            class = Encounters.ClassOf(name) }
    end
    tsort(list, function(a, b)
        local ca = a.class and CLASS_ORDER[a.class] or 99
        local cb = b.class and CLASS_ORDER[b.class] or 99
        if ca ~= cb then return ca < cb end
        return a.name < b.name
    end)
    return list
end
local SWING_WINDOW = 2
local POS_HOLD = 5
local SPREAD_LIMIT = 20
local BOSS_WITNESSES = 2
local ADD_WITNESSES = 1
local NPC_LIMIT = 16
local sortX, sortY = {}, {}
local function MedianXY(n)
    for i = 2, n do
        local vx, vy = sortX[i], sortY[i]
        local j = i - 1
        while j >= 1 and sortX[j] > vx do
            sortX[j + 1], sortY[j + 1] = sortX[j], sortY[j]
            j = j - 1
        end
        sortX[j + 1], sortY[j + 1] = vx, vy
    end
    local half = floor((n + 1) / 2)
    local mx = sortX[half]
    for i = 2, n do
        local v = sortY[i]
        local j = i - 1
        while j >= 1 and sortY[j] > v do
            sortY[j + 1] = sortY[j]
            j = j - 1
        end
        sortY[j + 1] = v
    end
    return mx, sortY[half]
end
local function YardSize(area, floor)
    local byArea = area and ns.mapScale and ns.mapScale[area]
    local size = byArea and byArea[floor]
    if not size then return nil, nil end
    return size.w, size.h
end
local function InferNpcs(frames, swings, count, fight, known)
    if count == 0 then return end
    local slotOf, slotName, slotWho, slotGuid = {}, {}, {}, {}
    local lo, hi = 1, 1
    local total = #frames
    for i = 1, total do
        ns.Jobs.Step(4)
        ns.Jobs.Progress(i, total)
        local frame = frames[i]
        while lo <= count and swings[lo].t < frame.t - SWING_WINDOW do lo = lo + 1 end
        while hi <= count and swings[hi].t <= frame.t + SWING_WINDOW do hi = hi + 1 end
        local slots = 0
        for k = lo, hi - 1 do
            local swing = swings[k]
            local slot = slotOf[swing.id]
            if not slot then
                slots = slots + 1
                slot = slots
                slotOf[swing.id] = slot
                slotName[slot] = swing.name
                slotGuid[slot] = swing.id
                slotWho[slot] = slotWho[slot] or {}
                wipe(slotWho[slot])
            end
            slotWho[slot][swing.who] = true
        end
        if slots > 0 then
            local area = (known and known.area) or frame.map
                or (ns.mapAreas and ns.mapAreas[frame.area])
            local yardW, yardH = YardSize(area, frame.floor)
            local marks = {}
            for slot = 1, slots do
                local witnesses = 0
                for who in pairs(slotWho[slot]) do
                    local p = frame.units[who]
                    if p and p.hp > 0 and not p.stale and (p.x > 0 or p.y > 0) then
                        witnesses = witnesses + 1
                        sortX[witnesses], sortY[witnesses] = p.x, p.y
                    end
                end
                local isBoss = IsBossOf(fight, slotGuid[slot])
                local need = isBoss and BOSS_WITNESSES or ADD_WITNESSES
                if witnesses >= need then
                    local mx, my = MedianXY(witnesses)
                    local spread = 0
                    if yardW then
                        local dx = max(mx - sortX[1], sortX[witnesses] - mx) * yardW
                        local dy = max(my - sortY[1], sortY[witnesses] - my) * yardH
                        spread = sqrt(dx * dx + dy * dy)
                    end
                    if spread <= SPREAD_LIMIT and #marks < NPC_LIMIT then
                        marks[#marks + 1] = { name = slotName[slot], x = mx, y = my,
                                              n = witnesses, boss = isBoss }
                    end
                end
            end
            if #marks > 0 then frame.npcs = marks end
        end
        wipe(slotOf)
    end
end
local function ReadSwings(fight, idx, from, to)
    local swings, count = {}, 0
    local npcFlag = COMBATLOG_OBJECT_TYPE_NPC
    local hostileFlag = COMBATLOG_OBJECT_REACTION_HOSTILE
    local list = idx.swings
    local total = #list
    from, to = max(from or fight.from, fight.from), min(to or fight.to, fight.to)
    for k = from > fight.from and ns.Index.Seek(idx, list, from) or 1, total do
        ns.Jobs.Step()
        ns.Jobs.Progress(k, total)
        local ts, sub, _, srcName, srcFlags, dstGUID, dstName, dstFlags = ns.Index.Read(idx, list, k, 0)
        if ts and ts > to then break end
        if ts and ts >= from
            and srcName and dstGUID and dstName and sub and find(sub, "SWING", 1, true) == 1
            and srcFlags and band(srcFlags, F_PLAYER) > 0
            and dstFlags and band(dstFlags, npcFlag) > 0
            and band(dstFlags, hostileFlag) > 0 then
            count = count + 1
            swings[count] = { t = ts, who = srcName, id = dstGUID, name = dstName }
        end
    end
    return swings, count
end
local function BuildPositions(fight, idx)
    local out = {}
    if #idx.segs == 0 then return out, {} end
    ns.Jobs.Label("job.map")
    ns.Jobs.Band(0, 0.6)
    ns.Streams.Frames(idx.segs, out, fight.from, fight.to)
    ns.Jobs.Band(0.6, 0.8)
    local swings, count = ReadSwings(fight, idx)
    ns.Jobs.Band(0.8, 0.95)
    InferNpcs(out, swings, count, fight, ns.maps and ns.maps[fight.boss])
    ns.Jobs.Band(0.95, 1)
    if #out == 0 then return out, {} end
    return out, Encounters.Rooms(fight, out)
end
function Encounters.PosWindow(fight, idx, from, to)
    local out = {}
    if #idx.segs == 0 then return out end
    ns.Streams.Frames(idx.segs, out, max(from - POS_HOLD, fight.from), min(to, fight.to))
    local swings, count = ReadSwings(fight, idx, from - POS_HOLD - SWING_WINDOW, to + SWING_WINDOW)
    InferNpcs(out, swings, count, fight, ns.maps and ns.maps[fight.boss])
    return out
end
local posReq = nil
function Encounters.CancelPositions()
    posReq = nil
    ns.Jobs.Cancel(POS_KEY)
end
function Encounters.Positions(fight, onDone)
    local req = {}
    posReq = req
    ns.Jobs.Cancel(POS_KEY)
    ns.Index.Get(fight, function(idx)
        if posReq ~= req then return end
        if not idx then
            onDone(nil, nil)
            return
        end
        ns.Jobs.Run(POS_KEY, function() return BuildPositions(fight, idx) end, function(frames, rooms)
            if posReq == req then onDone(frames, rooms) end
        end, "map.data", true)
    end, true)
end
local FIT_PAD = 0.08
local MIN_YARDS = 50
local function Widen(room, x, y)
    if x < room.seenL then room.seenL = x end
    if x > room.seenR then room.seenR = x end
    if y < room.seenT then room.seenT = y end
    if y > room.seenB then room.seenB = y end
end
function Encounters.FloorNote(boss, level)
    local known = ns.maps and ns.maps[boss]
    local preset = known and known.rooms and known.rooms[level]
    return preset and preset.note
end
function Encounters.Rooms(fight, frames)
    local known = ns.maps and ns.maps[fight.boss]
    local rooms = {}
    for i = 1, #frames do
        ns.Jobs.Step(4)
        local frame = frames[i]
        local room = rooms[frame.floor]
        if not room then
            local preset = known and known.rooms and known.rooms[frame.floor]
            local crop = preset and preset.crop
            room = {
                area = (known and known.area) or frame.map
                    or (ns.mapAreas and ns.mapAreas[frame.area]),
                floor = frame.floor,
                flip = preset and preset.flip,
                l = crop and crop[1], r = crop and crop[2],
                t = crop and crop[3], b = crop and crop[4],
                seenL = 1, seenR = 0, seenT = 1, seenB = 0,
            }
            rooms[frame.floor] = room
        end
        for _, p in pairs(frame.units) do
            if not p.stale and (p.x > 0 or p.y > 0) then Widen(room, p.x, p.y) end
        end
        if frame.npcs then
            for k = 1, #frame.npcs do
                Widen(room, frame.npcs[k].x, frame.npcs[k].y)
            end
        end
    end
    for level, room in pairs(rooms) do
        if room.seenL > room.seenR then
            rooms[level] = nil
        else
            local padX = max((room.seenR - room.seenL) * FIT_PAD, 0.002)
            local padY = max((room.seenB - room.seenT) * FIT_PAD, 0.002)
            room.l = min(room.l or 1, room.seenL - padX)
            room.r = max(room.r or 0, room.seenR + padX)
            room.t = min(room.t or 1, room.seenT - padY)
            room.b = max(room.b or 0, room.seenB + padY)
            local yardW, yardH = YardSize(room.area, level)
            local minX = yardW and (MIN_YARDS / yardW) or 0.03
            local minY = yardH and (MIN_YARDS / yardH) or 0.03
            if room.r - room.l < minX then
                local cx = (room.l + room.r) / 2
                room.l, room.r = cx - minX / 2, cx + minX / 2
            end
            if room.b - room.t < minY then
                local cy = (room.t + room.b) / 2
                room.t, room.b = cy - minY / 2, cy + minY / 2
            end
            room.l = max(0, room.l)
            room.t = max(0, room.t)
            room.r = min(1, room.r)
            room.b = min(1, room.b)
            room.seenL, room.seenR, room.seenT, room.seenB = nil, nil, nil, nil
        end
    end
    return rooms
end
function Encounters.RealDeath(fight, who, t)
    return ns.Streams.Real(SegsOf(fight), who, t)
end
local function SwingLabel(srcName)
    if not srcName then return ns.T("tl.swing") end
    return string.format(ns.T("tl.swing.src"), srcName)
end
local function ByMc(fight, srcName, srcFlags)
    return srcName ~= nil and fight.players[srcName] ~= nil and srcFlags ~= nil and band(srcFlags, F_PLAYER) == 0
end
local function BuildTimeline(fight, who, idx)
    local out = { boss = {}, casts = {}, auras = {}, taken = {}, healed = {},
                  hp = {}, deaths = {}, marks = {}, dmgDone = 0, healDone = 0 }
    if #idx.segs == 0 then return out end
    local from = Encounters.Lead(fight)
    local to = Encounters.Tail(fight)
    out.lead, out.tail = from, to
    local openAura = {}
    local bossSeen = {}
    local fixates = ns.fixates or {}
    local chasers = {}
    local owners = {}
    local cast = ns.CastResult.New(who)
    local starts = ns.CastGcd.New(who)
    local mine = idx.who[who] or {}
    local common = idx.common
    local mineT, commonT = ns.Index.Times(idx, mine), ns.Index.Times(idx, common)
    local i, j = 1, 1
    while true do
        local a, b = mine[i], common[j]
        local key, kt
        if a and (not b or a <= b) then
            key, kt = a, mineT[i]
            i = i + 1
            if a == b then j = j + 1 end
        elseif b then
            key, kt = b, commonT[j]
            j = j + 1
        else
            break
        end
        ns.Jobs.Step()
        local ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, _, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
            = ns.Index.ReadKey(idx, key, kt, 10)
        if ts and ts >= from and ts <= to then
            if sub == "FW_MARK" and ns.DevMarks then
                out.marks[#out.marks + 1] = { t = ts, label = ns.DevMarks.Line(a1, a2) }
            end
            local done = ns.CastGcd.Feed(starts, ts, sub, srcName, dstName, a1, a2)
            if done then
                ns.CastGcd.Insert(out.casts, done)
                ns.CastResult.Cast(cast, done, dstName)
            end
            ns.CastResult.Feed(cast, ts, sub, srcName, dstGUID, dstName, a1, a2, a4, a5, a7, a10)
            if sub == "SPELL_SUMMON" and dstName and dstGUID and fixates[NpcKey(dstGUID) or 0] then
                chasers[dstGUID] = { t = ts, id = tonumber(a1), name = dstName, key = NpcKey(dstGUID) }
            elseif srcGUID and chasers[srcGUID] and fixates[NpcKey(srcGUID) or 0] then
                local c = chasers[srcGUID]
                if sub:find("SWING", 1, true) then
                    if not c.victim then
                        c.victim = dstName
                        c.hit = c.hit or ts
                    end
                elseif sub:find("_DAMAGE", 1, true) then
                    c.hit = c.hit or ts
                    c.n = (c.n or 0) + 1
                    c.sum = (c.sum or 0) + (tonumber(a4) or 0)
                end
            end
            ns.NoteOwner(owners, sub, srcFlags, srcName, dstGUID)
            if IsBossOf(fight, srcGUID) and BOSS_SUBS[sub] then
                local label = tostring(a2 or a1)
                if not bossSeen[label] or ts - bossSeen[label] > 3 then
                    bossSeen[label] = ts
                    out.boss[#out.boss + 1] = { t = ts, label = label, kind = "cast", id = a1 }
                end
            elseif srcName == who then
                if sub == "SPELL_CAST_SUCCESS" then
                    local it = { t = ts, label = tostring(a2 or a1), kind = "cast", id = a1 }
                    out.casts[#out.casts + 1] = it
                    ns.CastResult.Cast(cast, it, dstName)
                    ns.CastGcd.Success(starts, it)
                end
            end
            if srcName == who and ts >= fight.from and ts <= fight.to then
                local swing = sub:find("SWING", 1, true) ~= nil
                if sub:find("_DAMAGE", 1, true) then
                    out.dmgDone = out.dmgDone + (tonumber(swing and a1 or a4) or 0)
                elseif sub:find("_HEAL", 1, true) then
                    local amount = tonumber(a4) or 0
                    local over = tonumber(a5) or 0
                    out.healDone = out.healDone + max(0, amount - over)
                end
            end
            if dstName == who then
                local swing = sub:find("SWING", 1, true) ~= nil
                if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
                    local key2 = tostring(a2 or a1)
                    if not openAura[key2] then
                        openAura[key2] = { t = ts, label = key2, id = a1, src = srcName,
                                           kind = a4 == "DEBUFF" and "debuff" or "buff" }
                    end
                elseif sub == "SPELL_AURA_REMOVED" then
                    local key2 = tostring(a2 or a1)
                    local open = openAura[key2]
                    if open then
                        open.to = ts
                        out.auras[#out.auras + 1] = open
                        openAura[key2] = nil
                    end
                elseif sub == "ENVIRONMENTAL_DAMAGE" then
                    out.taken[#out.taken + 1] = { t = ts, label = ns.EnvName(a1), amount = tonumber(a2) or 0,
                                                  over = tonumber(a3) or 0, absorbed = tonumber(a7) or 0,
                                                  kind = "hit" }
                elseif swing and srcGUID and chasers[srcGUID] then
                    local hit = sub == "SWING_DAMAGE"
                    out.taken[#out.taken + 1] = { t = ts, label = string.format(ns.T("tl.caught"), srcName),
                                                  amount = hit and tonumber(a1) or 0,
                                                  over = hit and tonumber(a2) or 0,
                                                  absorbed = tonumber(hit and a6 or a2) or 0,
                                                  miss = (not hit) and tostring(a1) or nil,
                                                  missN = (not hit) and (tonumber(a2) or 0) or nil,
                                                  kind = "hit", src = srcName, id = chasers[srcGUID].id,
                                                  chaser = srcGUID }
                elseif sub:find("_DAMAGE", 1, true) then
                    out.taken[#out.taken + 1] = { t = ts,
                                                  label = swing and SwingLabel(srcName) or tostring(a2 or a1),
                                                  swing = swing,
                                                  amount = tonumber(swing and a1 or a4) or 0,
                                                  over = tonumber(swing and a2 or a5) or 0,
                                                  absorbed = tonumber(swing and a6 or a9) or 0,
                                                  kind = "hit", src = srcName,
                                                  tick = sub:find("PERIODIC", 1, true) ~= nil,
                                                  id = (not swing) and a1 or nil,
                                                  chaser = fixates[NpcKey(srcGUID) or 0] and srcGUID or nil,
                                                  boss = IsBossOf(fight, srcGUID) or nil,
                                                  mc = ByMc(fight, srcName, srcFlags) }
                elseif MISSED_SUBS[sub] then
                    local how = tostring((swing and a1 or a4) or "MISS")
                    local n = tonumber(swing and a2 or a5) or 0
                    out.taken[#out.taken + 1] = { t = ts,
                                                  label = swing and SwingLabel(srcName) or tostring(a2 or a1),
                                                  swing = swing, amount = 0, over = 0,
                                                  absorbed = how == "ABSORB" and n or 0,
                                                  miss = how, missN = n,
                                                  kind = "hit", src = srcName,
                                                  tick = sub:find("PERIODIC", 1, true) ~= nil,
                                                  id = (not swing) and a1 or nil,
                                                  chaser = fixates[NpcKey(srcGUID) or 0] and srcGUID or nil,
                                                  boss = IsBossOf(fight, srcGUID) or nil,
                                                  mc = ByMc(fight, srcName, srcFlags) }
                elseif sub:find("_HEAL", 1, true) then
                    local amount = tonumber(a4) or 0
                    local over = tonumber(a5) or 0
                    out.healed[#out.healed + 1] = { t = ts, label = tostring(a2 or a1),
                                                    amount = amount, over = over,
                                                    absorbed = tonumber(a6) or 0,
                                                    tick = sub:find("PERIODIC", 1, true) ~= nil,
                                                    kind = "heal", src = srcName, id = a1 }
                elseif sub == "UNIT_DIED" then
                    out.deaths[#out.deaths + 1] = ts
                end
            end
        end
    end
    for _, open in pairs(openAura) do
        open.to = to
        out.auras[#out.auras + 1] = open
    end
    ns.CastResult.Finish(cast, idx)
    out.cuts = ns.CastGcd.Finish(starts, to, out.casts)
    for k = 1, #out.taken do
        local hit = out.taken[k]
        local c = hit.chaser and chasers[hit.chaser]
        if c then
            hit.victim = c.victim
            hit.chaseFor = (c.hit or c.t) - c.t
            hit.chaseN = c.n or 0
            hit.chaseSum = c.sum or 0
        end
    end
    for _, c in pairs(chasers) do
        if c.victim == who and c.id then
            local label = ns.T(fixates[c.key])
            ns.Effects.Synthetic(c.id, label, "debuff")
            out.auras[#out.auras + 1] = { t = c.t, to = c.hit or c.t, label = label,
                                          id = c.id, src = c.name, kind = "debuff" }
        end
    end
    if idx.pull then
        local seg, s, at = ns.Index.Line(idx, idx.pull)
        local ts, sub, srcGUID, srcName, srcFlags, _, _, _, a1, a2 = ns.Store.Decode(seg, s, at, 2)
        local swing = sub:find("SWING", 1, true) ~= nil
        out.pull = { t = ts, src = srcName,
                     spell = (not swing) and tostring(a2 or a1) or nil,
                     pet = band(srcFlags, F_PLAYER) == 0,
                     owner = srcGUID and owners[srcGUID] or nil }
    end
    out.hp = ns.Streams.HpList(idx.segs, who, from, to)
    out.mana = ns.Streams.ManaList(idx.segs, who, from, to)
    local real = {}
    for k = 1, #out.deaths do
        if ns.Streams.Real(idx.segs, who, out.deaths[k]) then real[#real + 1] = out.deaths[k] end
    end
    out.deaths = real
    out.phases = ns.Phases and ns.Phases.Get(fight) or nil
    return out
end
local function ByTotal(a, b)
    if a.total ~= b.total then return a.total > b.total end
    if a.hits ~= b.hits then return a.hits > b.hits end
    if a.misses ~= b.misses then return a.misses > b.misses end
    return a.label < b.label
end
function Encounters.GroupRows(items)
    local rows, index = {}, {}
    if not items then return rows end
    for i = 1, #items do
        local it = items[i]
        local row = index[it.label]
        if not row then
            row = { label = it.label, id = it.id, items = {}, total = 0, hits = 0, misses = 0, swing = it.swing }
            index[it.label] = row
            rows[#rows + 1] = row
        end
        row.items[#row.items + 1] = it
        row.total = row.total + (it.amount or 0)
        if it.miss then row.misses = row.misses + 1 else row.hits = row.hits + 1 end
        if it.tick then row.hot = true end
    end
    tsort(rows, ByTotal)
    return rows
end
local tlReq = nil
function Encounters.Timeline(fight, who, onDone)
    local req = {}
    tlReq = req
    ns.Jobs.Cancel(TL_KEY)
    ns.Index.Get(fight, function(idx)
        if tlReq ~= req then return end
        if not idx then
            onDone(nil)
            return
        end
        ns.Jobs.Run(TL_KEY, function() return BuildTimeline(fight, who, idx) end, function(data)
            if tlReq == req then onDone(data) end
        end, "tl.data", true)
    end, true)
end
