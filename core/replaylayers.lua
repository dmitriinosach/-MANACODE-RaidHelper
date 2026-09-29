local _, ns = ...
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local rad = math.rad
local band = bit.band
local SKIP_HP = { "FW_HP" }
local MAX_TAIL = 5
local F_PLAYER = 0x400
local F_NPC = 0x800
local F_HOSTILE = 0x40
local TARGET_HOLD = 3
local TARGET_AHEAD = 0.5
local BOSS_STEP = 0.5
local BOSS_MIN_SWINGS = 5
local WITNESS_HOLD = 3
local BOSS_HOLD = 20
local SMOOTH_WINDOW = 4
local SWITCH_MARGIN = 2
local SWITCH_HOLD = 2
local TARGET_LOSE = 6
local TAUNT_LOCK = 3
local BOSS_SPEED = 7
local ADD_STEP = 0.5
local ADD_LIMIT = 160
local ADD_TAIL = 3
local POOL_LIMIT = 600
local POOL_JOIN = 3
local POOL_CENTER_HITS = 6
local HIT_GAP = 1.5
local HIT_LIMIT = 600
local CONE_LIMIT = 300
local AIM_WINDOW = 5
local STATE_LIMIT = 4000
local TANK_SHARE = 0.15
local BLAST_JOIN = 0.5
local BLAST_LIMIT = 500
local VICTIM_LIMIT = 2000
local BTGT = "FW_BTGT"
local CAST_LIMIT = 2000
local CAST_SHOW = 2
local CAST_INSTANT = 0.8
local REMOVED = { SPELL_AURA_REMOVED = true, SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true }
local DAMAGE = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }
local CASTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }
local SWING = { SWING_DAMAGE = true, SWING_MISSED = true }
local Layers = {}
ns.ReplayLayers = Layers
local stateOf = setmetatable({}, { __mode = "k" })
local function StateIndex(D)
    local idx = stateOf[D]
    if idx then return idx end
    idx = {}
    for i = 1, #D.states do idx[D.states[i].name] = i end
    stateOf[D] = idx
    return idx
end
function Layers.State(i)
    local D = ns.replayData
    if i == 0 then return D.valkyr end
    return D.states[i]
end
function Layers.Hitbox(boss)
    local hb = ns.replayData.hitbox
    local r = hb[boss]
    if r == nil then r = hb.default end
    return r
end
local function NewLayers()
    return {
        stK = {}, stS = {}, stFrom = {}, stTo = {}, ns = 0,
        plX = {}, plY = {}, plFrom = {}, plTo = {}, plLast = {}, plR0 = {}, plR1 = {}, plN = {}, plDef = {}, np = 0,
        hiT = {}, hiX = {}, hiY = {}, nh = 0,
        cnT = {}, cnTo = {}, cnX = {}, cnY = {}, cnHx = {}, cnHy = {}, cnLen = {}, cnDeg = {}, nc = 0,
        bT = {}, bX = {}, bY = {}, bR = {}, bN = {}, bS = {}, nb = 0, vT = {}, vK = {}, nv = 0, cnS = {},
        adds = {}, fdT = {}, fdIcon = {}, fdText = {}, fdImp = {}, fdKind = {}, fdTip = {}, nf = 0,
        feedRaw = 0, feedMs = 0,
        tanks = {}, hitbox = 0, bossMoved = false, targets = 0, targetSrc = "", ms = 0,
        switchRaw = 0, switchSmooth = 0, taunts = 0,
        bcT = {}, bcD = {}, nbc = 0, bsT = {},
    }
end
local function Pos(c, name, ts)
    local k = name and c.byK[name]
    if not k then return nil, 0 end
    local x, y = ns.Replay.PosAtTime(c.tracks[k], ts)
    if x < 0 then return nil, 0 end
    return x, y
end
local function Open(c, k, s, ts)
    local open = c.open[k]
    if open[s] then return end
    local L = c.L
    if L.ns >= STATE_LIMIT then return end
    local n = L.ns + 1
    L.ns = n
    L.stK[n], L.stS[n], L.stFrom[n], L.stTo[n] = k, s, ts, c.to
    open[s] = n
end
local function Close(c, k, s, ts)
    local open = c.open[k]
    local n = open[s]
    if not n then return end
    c.L.stTo[n] = ts
    open[s] = nil
end
local function OnAura(c, ts, sub, dst, spell)
    local k = dst and c.byK[dst]
    local s = k and spell and c.stateIdx[spell]
    if not s then return end
    if sub == "SPELL_AURA_APPLIED" then
        Open(c, k, s, ts)
    elseif REMOVED[sub] then
        Close(c, k, s, ts)
    end
end
local function OnVehicle(c, ts, src, on)
    local k = src and c.byK[src]
    if not k or not c.valkyr then return end
    if on then
        Open(c, k, 0, ts)
    else
        Close(c, k, 0, ts)
    end
end
local function AddOf(c, guid, name, ts)
    local add = c.addBy[guid]
    if add then return add end
    local icon = c.D.adds[name]
    if icon == false or c.bosses[name] or c.addN >= ADD_LIMIT then return nil end
    add = ns.Replay.NewTrack(name)
    add.icon = icon or c.D.addDefault
    add.npc = ns.Replay.NpcOf(guid)
    add.from = ts
    add.last = -1e9
    c.addN = c.addN + 1
    c.addBy[guid] = add
    c.L.adds[c.addN] = add
    return add
end
local function AddSeen(c, guid, name, ts, x, y)
    local add = AddOf(c, guid, name, ts)
    if not add or add.to or ts - add.last < ADD_STEP then return end
    add.last = ts
    ns.Replay.Push(add, ts, x, y, 1, 0)
end
local function OnSwing(c, ts, srcGUID, src, srcFlags, dstGUID, dst, dstFlags)
    local kd = dst and c.byK[dst]
    if src and c.bosses[src] then
        if kd then
            local n = #c.swT + 1
            c.swT[n], c.swK[n] = ts, kd
            c.tankHits[kd] = (c.tankHits[kd] or 0) + 1
        end
        return
    end
    if kd and srcGUID and srcFlags and band(srcFlags, F_NPC) > 0 and band(srcFlags, F_HOSTILE) > 0 then
        local x, y = Pos(c, dst, ts)
        if not x then return end
        local add = AddOf(c, srcGUID, src, ts)
        if add and add.n == 0 and not add.chaseK and c.born[srcGUID] and c.born[srcGUID] < ts then
            add.chaseK, add.chaseTo, add.from = kd, ts, c.born[srcGUID]
        end
        AddSeen(c, srcGUID, src, ts, x, y)
        return
    end
    local ks = src and c.byK[src]
    if ks and dstGUID and dst and dstFlags and band(dstFlags, F_NPC) > 0 and band(dstFlags, F_HOSTILE) > 0
        and not c.bosses[dst] then
        local x, y = Pos(c, src, ts)
        if x then AddSeen(c, dstGUID, dst, ts, x, y) end
    end
end
local function OpenPools(c, def, key)
    local byKey = c.pools[def]
    if not byKey then
        byKey = {}
        c.pools[def] = byKey
    end
    local list = byKey[key]
    if not list then
        list = {}
        byKey[key] = list
    end
    return list
end
local function PoolHit(c, def, key, ts, x, y)
    local L, ppy = c.L, c.ppy
    local list = OpenPools(c, def, key)
    local best, bestD = nil, nil
    local w = 1
    while list[w] do
        local j = list[w]
        local alive = ts - L.plLast[j] <= def.gap or (def.life and ts - L.plFrom[j] <= def.life)
        if alive then
            local dx, dy = x - L.plX[j], y - L.plY[j]
            local d = sqrt(dx * dx + dy * dy) / ppy
            if d <= L.plR1[j] + POOL_JOIN and (not bestD or d < bestD) then best, bestD = j, d end
            w = w + 1
        else
            table.remove(list, w)
        end
    end
    if best then
        local n = L.plN[best] + 1
        L.plN[best] = n
        if n <= POOL_CENTER_HITS then
            L.plX[best] = L.plX[best] + (x - L.plX[best]) / n
            L.plY[best] = L.plY[best] + (y - L.plY[best]) / n
        end
        L.plLast[best] = ts
        local dx, dy = x - L.plX[best], y - L.plY[best]
        local d = sqrt(dx * dx + dy * dy) / ppy + 1
        if d > L.plR1[best] then L.plR1[best] = min(def.rmax, d) end
        return
    end
    if L.np >= POOL_LIMIT then return end
    local j = L.np + 1
    L.np = j
    local born = key ~= "" and c.born[key] or nil
    L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j] = x, y, born and born <= ts and born or ts, ts
    L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j], L.plTo[j] = def.r0, def.r0, 1, def, ts
    list[#list + 1] = j
end
local function Hit(c, ts, dst, x, y)
    local L = c.L
    local last = c.hitAt[dst]
    if (last and ts - last < HIT_GAP) or L.nh >= HIT_LIMIT then return end
    c.hitAt[dst] = ts
    local n = L.nh + 1
    L.nh = n
    L.hiT[n], L.hiX[n], L.hiY[n] = ts, x, y
end
local function OnPool(c, ts, sub, srcGUID, src, dst, spell)
    local defs = c.poolDefs
    if not defs or not spell or not dst or not c.byK[dst] then return end
    for i = 1, #defs do
        local def = defs[i]
        if def.spell == spell and not def.follow then
            local x, y = Pos(c, dst, ts)
            if not x then return end
            local key = ""
            if def.by == "src" and srcGUID and src ~= dst then key = srcGUID end
            PoolHit(c, def, key, ts, x, y)
            if DAMAGE[sub] then Hit(c, ts, dst, x, y) end
            return
        end
    end
end
local function OnBlast(c, ts, srcGUID, src, dst, spell, amount, srcFlags)
    local defs = c.blastDefs
    local k = dst and c.byK[dst]
    if not defs or not spell or not k then return end
    local npc = srcFlags and band(srcFlags, F_NPC) > 0 and band(srcFlags, F_PLAYER) == 0
    for i = 1, #defs do
        local def = defs[i]
        if def.spell == spell then
            local x, y = Pos(c, dst, ts)
            if not x then return end
            local L = c.L
            if L.nv < VICTIM_LIMIT then
                L.nv = L.nv + 1
                L.vT[L.nv], L.vK[L.nv] = ts, k
            end
            local key = (srcGUID and src ~= dst and not c.bosses[src or ""]) and srcGUID or spell
            local j = c.blastOpen[key]
            if j and ts - L.bT[j] <= BLAST_JOIN then
                local n = L.bN[j] + 1
                L.bN[j] = n
                if def.at == "max" then
                    if (amount or 0) > c.blastMax[j] then L.bX[j], L.bY[j], c.blastMax[j] = x, y, amount or 0 end
                else
                    L.bX[j], L.bY[j] = L.bX[j] + (x - L.bX[j]) / n, L.bY[j] + (y - L.bY[j]) / n
                end
                return
            end
            if key ~= spell and npc then
                local add = AddOf(c, key, src, ts)
                if add and add.n == 0 and not add.chaseK and c.born[key] and c.born[key] < ts then
                    add.chaseK, add.chaseTo, add.from = k, ts, c.born[key]
                end
                AddSeen(c, key, src, ts, x, y)
            end
            if L.nb >= BLAST_LIMIT then return end
            j = L.nb + 1
            L.nb = j
            L.bT[j], L.bX[j], L.bY[j], L.bR[j], L.bN[j], L.bS[j] = ts, x, y, def.r * c.ppy, 1, spell
            c.blastMax[j] = amount or 0
            c.blastOpen[key] = j
            return
        end
    end
end
local function OnMelee(c, ts, src, dst, spell)
    local kd = dst and c.byK[dst]
    if not kd or not spell or not c.melee or not c.melee[spell] or not src or not c.bosses[src] then return end
    local n = #c.swT + 1
    c.swT[n], c.swK[n] = ts, kd
    c.tankHits[kd] = (c.tankHits[kd] or 0) + 1
end
local function OnTaunt(c, ts, src, dst, spell)
    local ks = src and c.byK[src]
    if not ks or not dst or not c.bosses[dst] or not spell or not c.D.taunts[spell] then return end
    local n = #c.tauT + 1
    c.tauT[n], c.tauK[n] = ts, ks
end
local function OnTarget(c, ts, dst)
    local n = #c.btT + 1
    c.btT[n], c.btK[n] = ts, dst and c.byK[dst] or 0
end
local function OnFollow(c, ts, sub, src, dst, spell)
    local defs = c.poolDefs
    if not defs or not src or src ~= dst or not c.bosses[src] then return end
    for i = 1, #defs do
        local def = defs[i]
        if def.follow and def.spell == spell then
            local L = c.L
            if sub == "SPELL_AURA_APPLIED" and L.np < POOL_LIMIT then
                local j = L.np + 1
                L.np = j
                L.plX[j], L.plY[j], L.plFrom[j], L.plLast[j], L.plTo[j] = -1, -1, ts, ts, c.to
                L.plR0[j], L.plR1[j], L.plN[j], L.plDef[j] = def.r0, def.r0, 0, def
                c.follow[def] = j
            elseif REMOVED[sub] and c.follow[def] then
                L.plTo[c.follow[def]] = ts
                L.plLast[c.follow[def]] = ts
                c.follow[def] = nil
            end
        end
    end
end
local function OnCone(c, ts, sub, src, dst, spell)
    local defs = c.coneDefs
    if not defs or not spell or not src then return end
    for i = 1, #defs do
        local def = defs[i]
        if def.spell == spell and def.sub == sub and (def.src == src or (not def.src and c.bosses[src])) then
            local L = c.L
            if L.nc >= CONE_LIMIT then return end
            local n = L.nc + 1
            L.nc = n
            L.cnT[n], L.cnTo[n], L.cnLen[n], L.cnDeg[n], L.cnS[n] = ts, ts + def.dur, def.len, def.deg, spell
            L.cnX[n], L.cnY[n], L.cnHx[n], L.cnHy[n] = -1, -1, 0, 1
            c.coneTo[n] = dst and c.byK[dst] or 0
            c.coneDef[n] = def
            c.aimX[n], c.aimY[n], c.aimN[n] = 0, 0, 0
            if def.aim then c.aimOpen[#c.aimOpen + 1] = n end
            return
        end
    end
end
local function OnAim(c, ts, dst, spell)
    local list = c.aimOpen
    if #list == 0 or not spell or not c.aimSpells[spell] then return end
    local x, y = Pos(c, dst, ts)
    if not x then return end
    local w = 1
    while list[w] do
        local n = list[w]
        if ts - c.L.cnT[n] > AIM_WINDOW then
            table.remove(list, w)
        else
            c.aimX[n], c.aimY[n], c.aimN[n] = c.aimX[n] + x, c.aimY[n] + y, c.aimN[n] + 1
            w = w + 1
        end
    end
end
local function OnCast(c, ts, sub, src, dst, spell)
    OnCone(c, ts, sub, src, dst, spell)
    local L = c.L
    if src and c.bosses[src] and L.nbc < CAST_LIMIT then
        local n = L.nbc + 1
        L.nbc = n
        L.bcT[n], L.bcD[n] = ts, sub == "SPELL_CAST_START" and CAST_SHOW or CAST_INSTANT
    end
end
local function OnDied(c, ts, dstGUID, dst)
    local k = dst and c.byK[dst]
    if k then
        for s in pairs(c.open[k]) do Close(c, k, s, ts) end
        return
    end
    if dst and c.bosses[dst] then c.L.bossDied = ts end
    local add = dstGUID and c.addBy[dstGUID]
    if add and not add.to then add.to = ts end
end
local function OnSummon(c, ts, src, dstGUID, dst)
    if not dstGUID or not dst then return end
    c.born[dstGUID] = ts
    if src and c.bosses[src] then AddOf(c, dstGUID, dst, ts) end
end
local function Dispatch(c, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4)
    if src and srcGUID and c.npcOf[src] == nil and c.bosses[src] then
        c.npcOf[src] = ns.Replay.NpcOf(srcGUID) or false
        if c.npcOf[src] and not c.firstNpc then c.firstNpc = c.npcOf[src] end
    end
    if SWING[sub] then
        OnSwing(c, ts, srcGUID, src, srcFlags, dstGUID, dst, dstFlags)
    elseif sub == "SPELL_AURA_APPLIED" or REMOVED[sub] then
        OnAura(c, ts, sub, dst, a2)
        OnFollow(c, ts, sub, src, dst, a2)
        if sub == "SPELL_AURA_APPLIED" then
            OnPool(c, ts, sub, srcGUID, src, dst, a2)
            OnTaunt(c, ts, src, dst, a2)
        end
    elseif DAMAGE[sub] then
        OnPool(c, ts, sub, srcGUID, src, dst, a2)
        OnAim(c, ts, dst, a2)
        OnBlast(c, ts, srcGUID, src, dst, a2, tonumber(a4), srcFlags)
        OnMelee(c, ts, src, dst, a2)
    elseif sub == BTGT then
        OnTarget(c, ts, dst)
    elseif CASTS[sub] then
        OnCast(c, ts, sub, src, dst, a2)
        if sub == "SPELL_CAST_SUCCESS" then OnMelee(c, ts, src, dst, a2) end
    elseif sub == "SPELL_MISSED" then
        OnMelee(c, ts, src, dst, a2)
    elseif sub == "UNIT_DIED" then
        OnDied(c, ts, dstGUID, dst)
    elseif sub == "SPELL_SUMMON" then
        OnSummon(c, ts, src, dstGUID, dst)
    elseif sub == "FW_VEH" then
        OnVehicle(c, ts, src, tonumber(a1) == 1)
    end
end
local function NewContext(scene)
    local fight = scene.fight
    local D = ns.replayData
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local open = {}
    for k = 1, #scene.tracks do open[k] = {} end
    local aimSpells = {}
    local cones = D.cones[fight.boss]
    for i = 1, cones and #cones or 0 do
        for _, name in ipairs(cones[i].aim or {}) do aimSpells[name] = true end
    end
    return {
        L = NewLayers(), D = D, byK = byK, tracks = scene.tracks, open = open, from = fight.from, to = fight.to,
        ppy = scene.ppy, stateIdx = StateIndex(D), bosses = ns.Index.BossNames(fight),
        poolDefs = D.pools[fight.boss], coneDefs = cones,
        blastDefs = D.blasts[fight.boss], blastOpen = {}, blastMax = {}, melee = D.melee[fight.boss],
        valkyr = D.valkyr.boss == fight.boss,
        swT = {}, swK = {}, btT = {}, btK = {}, tgT = {}, tgK = {}, hold = TARGET_HOLD, tauT = {}, tauK = {},
        tankHits = {}, addBy = {}, addN = 0, pools = {}, born = {}, follow = {},
        hitAt = {}, coneTo = {}, coneDef = {}, aimX = {}, aimY = {}, aimN = {}, aimOpen = {}, aimSpells = aimSpells,
        npcOf = {},
    }
end
local function TargetAt(c, t, lo)
    local tgT = c.tgT
    local n = #tgT
    while lo < n and tgT[lo + 1] <= t + TARGET_AHEAD do lo = lo + 1 end
    if lo >= 1 and tgT[lo] <= t + TARGET_AHEAD and t - tgT[lo] <= c.hold then return c.tgK[lo], lo end
    return 0, lo
end
local function Switches(list)
    local n, prev = 0, 0
    for i = 1, #list do
        local k = list[i]
        if k ~= 0 and k ~= prev then
            if prev ~= 0 then n = n + 1 end
            prev = k
        end
    end
    return n
end
local function Leader(count)
    local best, bestN = 0, 0
    for k, v in pairs(count) do
        if v > bestN then best, bestN = k, v end
    end
    return best, bestN
end
local function Smooth(c)
    local swT, swK, tauT, tauK = c.swT, c.swK, c.tauT, c.tauK
    local n = #swT
    local count, outT, outK, rawK = {}, {}, {}, {}
    local lo, hi, ti = 1, 0, 1
    local cur, cand, candSince, lock = 0, 0, 0, -1e9
    local t = c.from
    while t <= c.to do
        ns.Jobs.Step(2)
        while hi < n and swT[hi + 1] <= t do
            hi = hi + 1
            count[swK[hi]] = (count[swK[hi]] or 0) + 1
        end
        while lo <= hi and swT[lo] < t - SMOOTH_WINDOW do
            count[swK[lo]] = count[swK[lo]] - 1
            lo = lo + 1
        end
        rawK[#rawK + 1] = (hi >= 1 and t - swT[hi] <= TARGET_HOLD) and swK[hi] or 0
        while ti <= #tauT and tauT[ti] <= t do
            cur, lock, cand = tauK[ti], tauT[ti], 0
            ti = ti + 1
        end
        if t - lock > TAUNT_LOCK then
            local best, bestN = Leader(count)
            local curN = count[cur] or 0
            if cur == 0 and bestN > 0 then
                cur, cand = best, 0
            elseif best ~= cur and bestN >= curN + SWITCH_MARGIN then
                if cand ~= best then
                    cand, candSince = best, t
                elseif t - candSince >= SWITCH_HOLD then
                    cur, cand = best, 0
                end
            else
                cand = 0
            end
            if hi < 1 or t - swT[hi] > TARGET_LOSE then cur = 0 end
        end
        outT[#outT + 1], outK[#outK + 1] = t, cur
        t = t + BOSS_STEP
    end
    return outT, outK, Switches(rawK)
end
local function PickTargets(c)
    local L = c.L
    if #c.btT > 0 then
        c.tgT, c.tgK, c.hold = c.btT, c.btK, math.huge
        L.targetSrc = BTGT
        L.switchRaw = Switches(c.btK)
        L.switchSmooth = L.switchRaw
        L.targets = #c.btT
    else
        local raw = #c.swT
        c.tgT, c.tgK, L.switchRaw = Smooth(c)
        c.hold = BOSS_STEP * 1.5
        L.targetSrc = "swing"
        L.switchSmooth = Switches(c.tgK)
        L.targets = raw
    end
    L.taunts = #c.tauT
end
local function RaidMean(c, t)
    local sx, sy, n = 0, 0, 0
    local tracks = c.tracks
    for k = 1, #tracks do
        local x, y = ns.Replay.PosAtTime(tracks[k], t)
        if x >= 0 then sx, sy, n = sx + x, sy + y, n + 1 end
    end
    if n == 0 then return nil, 0 end
    return sx / n, sy / n
end
local function PlaceBoss(scene, c)
    local L = c.L
    if L.targets < BOSS_MIN_SWINGS then return end
    local old = scene.boss
    local R = L.hitbox * scene.ppy
    local stepMax = BOSS_SPEED * scene.ppy * BOSS_STEP
    local tr = ns.Replay.NewTrack(scene.bossName or scene.fight.boss)
    tr.fx, tr.fy = {}, {}
    local lo = 0
    local t = c.from
    local lastX, lastY, lastT = nil, 0, 0
    local ax, ay, at = nil, 0, -1e9
    while t <= c.to do
        ns.Jobs.Step(4)
        local k
        k, lo = TargetAt(c, t, lo)
        local tx, ty = -1, -1
        if k > 0 then tx, ty = ns.Replay.PosAtTime(c.tracks[k], t) end
        local mx, my = -1, -1
        if old then mx, my = ns.Replay.PosHold(old, t, WITNESS_HOLD) end
        local cx, cy = -1, -1
        if tx >= 0 then
            if mx < 0 then mx, my = RaidMean(c, t) end
            cx, cy = tx, ty
            if mx then
                local dx, dy = mx - tx, my - ty
                local d = sqrt(dx * dx + dy * dy)
                if d > 0.01 then
                    local off = min(R, d * 0.5)
                    cx, cy = tx + dx / d * off, ty + dy / d * off
                end
            end
        elseif mx >= 0 then
            cx, cy = mx, my
        elseif lastX and t - lastT <= BOSS_HOLD then
            cx, cy = lastX, lastY
        end
        if cx >= 0 then
            if tx >= 0 or mx >= 0 then lastX, lastY, lastT = cx, cy, t end
            if ax and t - at <= BOSS_STEP * 1.5 then
                local dx, dy = cx - ax, cy - ay
                local d = sqrt(dx * dx + dy * dy)
                if d > stepMax then cx, cy = ax + dx / d * stepMax, ay + dy / d * stepMax end
            end
            ax, ay, at = cx, cy, t
            local fx, fy = tr.fx[tr.n] or 0, tr.fy[tr.n] or 1
            if tx >= 0 then
                local dx, dy = tx - cx, ty - cy
                local d = sqrt(dx * dx + dy * dy)
                if d > 0.01 then fx, fy = dx / d, dy / d end
            end
            ns.Replay.Push(tr, t, cx, cy, 1, 0)
            tr.fx[tr.n], tr.fy[tr.n] = fx, fy
        elseif tr.n > 0 and tr.x[tr.n] >= 0 then
            ns.Replay.Push(tr, t, -1, -1, 1, 0)
            tr.fx[tr.n], tr.fy[tr.n] = 0, 1
        end
        t = t + BOSS_STEP
    end
    if tr.n > 0 then
        scene.boss = tr
        scene.bossName = scene.bossName or scene.fight.boss
        L.bossMoved = true
    end
end
local function PlaceCones(scene, c)
    local L = c.L
    local boss = scene.boss
    local ppy = scene.ppy
    local lo = 0
    for n = 1, L.nc do
        local ts = L.cnT[n]
        local ox, oy = -1, -1
        if boss then ox, oy = ns.Replay.PosHold(boss, ts, WITNESS_HOLD) end
        if ox >= 0 then
            local tx, ty = -1, -1
            if c.aimN[n] > 0 then
                tx, ty = c.aimX[n] / c.aimN[n], c.aimY[n] / c.aimN[n]
            else
                local k = c.coneTo[n]
                if k == 0 then k, lo = TargetAt(c, ts, lo) end
                if k > 0 then tx, ty = ns.Replay.PosAtTime(c.tracks[k], ts) end
            end
            local hx, hy = 0, 0
            if tx >= 0 then
                local dx, dy = tx - ox, ty - oy
                local d = sqrt(dx * dx + dy * dy)
                if d > 0.01 then hx, hy = dx / d, dy / d end
            end
            if hx == 0 and hy == 0 and boss.fx then
                local i = ns.Replay.IndexAt(boss, ts)
                if i > 0 then hx, hy = boss.fx[i] or 0, boss.fy[i] or 0 end
            end
            if hx ~= 0 or hy ~= 0 then
                if c.coneDef[n].back then hx, hy = -hx, -hy end
                L.cnX[n], L.cnY[n], L.cnHx[n], L.cnHy[n] = ox, oy, hx, hy
                L.cnLen[n] = (L.cnLen[n] + L.hitbox) * ppy
            end
        end
    end
end
local function FinishPools(c)
    local L = c.L
    for j = 1, L.np do
        local def = L.plDef[j]
        if not def.follow then
            if def.life then
                L.plTo[j] = min(L.plFrom[j] + def.life, max(L.plLast[j], L.plFrom[j]) + max(def.tail, def.life))
            else
                L.plTo[j] = L.plLast[j] + def.tail
            end
            L.plR0[j] = min(L.plR0[j], L.plR1[j])
        end
    end
end
local function FinishAdds(c)
    local adds = c.L.adds
    for i = 1, #adds do
        local add = adds[i]
        if add.n > 0 then
            if not add.to then add.to = add.t[add.n] + ADD_TAIL end
            if not add.chaseK and add.t[1] > add.from then add.from = add.t[1] end
        else
            add.to = add.from
        end
    end
end
local function Tanks(c)
    local total = 0
    for _, n in pairs(c.tankHits) do total = total + n end
    if total == 0 then return end
    for k, n in pairs(c.tankHits) do
        if n / total >= TANK_SHARE then c.L.tanks[c.tracks[k].name] = true end
    end
end
function Layers.Build(scene)
    local p0 = debugprofilestop()
    local fight = scene.fight
    local c = NewContext(scene)
    c.L.hitbox = Layers.Hitbox(fight.boss)
    local FC = ns.ReplayFeedCore
    local fc = FC.New(fight)
    local np = ns.NpcPos and ns.NpcPos.New(scene, c)
    local ph = ns.Phases.New(fight)
    local segs = ns.Encounters.Segs(fight)
    local span = max(1, fight.to - fight.from)
    for o = 1, #segs do
        for ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, _, a4, a5
            in ns.Store.Events(segs[o], fight.from, fight.to, SKIP_HP, MAX_TAIL) do
            ns.Jobs.Step()
            ns.Jobs.Progress(ts - fight.from, span)
            if ph then ns.Phases.Feed(ph, ts, sub, a1) end
            Dispatch(c, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4)
            FC.Event(fc, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4, a5)
            if np then ns.NpcPos.Feed(np, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2) end
        end
    end
    local res = ph and ns.Phases.Done(fight, ph) or ns.Phases.Get(fight)
    FinishPools(c)
    FinishAdds(c)
    Tanks(c)
    local f0 = debugprofilestop()
    FC.Done(fc, c.L, res)
    c.L.feedMs = debugprofilestop() - f0
    PickTargets(c)
    if not (np and ns.NpcPos.Place(np, TargetAt)) then PlaceBoss(scene, c) end
    PlaceCones(scene, c)
    c.L.bsT = c.swT
    c.L.bossNpc = c.npcOf[scene.bossName or ""] or c.npcOf[fight.boss] or c.firstNpc
    c.L.ms = debugprofilestop() - p0
    scene.layers = c.L
    return c.L
end
function Layers.PoolRadius(L, j, t)
    local from, last = L.plFrom[j], L.plLast[j]
    local r0, r1 = L.plR0[j], L.plR1[j]
    if last <= from or t >= last then return r1 end
    if t <= from then return r0 end
    return r0 + (r1 - r0) * (t - from) / (last - from)
end
function Layers.ConeEdges(deg, hx, hy)
    local a = rad(deg / 2)
    local c, s = cos(a), sin(a)
    return hx * c - hy * s, hx * s + hy * c, hx * c + hy * s, -hx * s + hy * c
end
function Layers.Round(n)
    return floor(n + 0.5)
end
