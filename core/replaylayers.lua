local _, ns = ...
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local tsort = table.sort
local cos = math.cos
local sin = math.sin
local rad = math.rad
local band = bit.band
local SpellKey = ns.SpellKey
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
local ADD_HP_RAMP = 3
local BOSS_HP_BODIES = 8
local BOSS_HP_LEAD = 6
local BOSS_HP_HOLD = 9
local POOL_LIMIT = 600
local POOL_JOIN = 3
local POOL_CENTER_HITS = 6
local HIT_GAP = 1.5
local HIT_LIMIT = 600
local CONE_LIMIT = 300
local AIM_WINDOW = 5
local ADD_AIM = 2
local STATE_LIMIT = 4000
local TANK_SHARE = 0.15
local BLAST_JOIN = 0.5
local BLAST_LIMIT = 500
local VICTIM_LIMIT = 2000
local BTGT = "FW_BTGT"
local THR = "FW_THR"
local THR_HOLD = 6
local HOLDER_KEEP = 30
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
    for i = 1, #D.states do idx[ns.SpellKey(D.states[i].name)] = i end
    stateOf[D] = idx
    return idx
end
function Layers.StateFor(D, spell, boss)
    local s = spell and StateIndex(D)[spell]
    if not s then return nil end
    local only = D.states[s].boss
    if only and only ~= boss then return nil end
    return s
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
        bTone = {}, cnTone = {},
        adds = {}, addHp = 0, fdT = {}, fdIcon = {}, fdText = {}, fdImp = {}, fdKind = {}, fdTip = {}, nf = 0,
        feedRaw = 0, feedMs = 0,
        tanks = {}, hitbox = 0, bossMoved = false, targets = 0, targetSrc = "", ms = 0,
        switchRaw = 0, switchSmooth = 0, taunts = 0,
        bcT = {}, bcD = {}, nbc = 0, bsT = {},
        pfQuake = {}, pfWinter = {}, pfMarkT = {}, pfMarkK = {},
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
local function OnAura(c, ts, sub, src, dst, spell)
    local k = dst and c.byK[dst]
    local s = k and Layers.StateFor(c.D, spell, c.boss)
    if not s then return end
    local def = c.D.states[s]
    if def.cast or (def.self and src ~= dst) then return end
    local seen = c.seen[k]
    local was = seen[s]
    seen[s] = true
    local pre = (def.pre or def.focus) and not was and not c.open[k][s]
    if sub == "SPELL_AURA_APPLIED" then
        Open(c, k, s, ts)
    elseif sub == "SPELL_AURA_REFRESH" then
        if pre then Open(c, k, s, c.from) end
    elseif REMOVED[sub] then
        if pre then Open(c, k, s, c.from) end
        Close(c, k, s, ts)
    end
end
local function OnOwn(c, ts, sub, src, spell)
    local k = src and c.byK[src]
    local s = k and Layers.StateFor(c.D, spell, c.boss)
    if not s then return end
    local def = c.D.states[s]
    if def.cast and sub == "SPELL_CAST_SUCCESS" and c.L.ns < STATE_LIMIT then
        local n = c.L.ns + 1
        c.L.ns = n
        c.L.stK[n], c.L.stS[n], c.L.stFrom[n], c.L.stTo[n] = k, s, ts, min(ts + def.cast, c.to)
    elseif def.proof and DAMAGE[sub] and not c.seen[k][s] then
        c.seen[k][s] = true
        Open(c, k, s, c.from)
    end
end
local function OnSnap(c, ts, id, on)
    local s = type(on) == "string" and Layers.StateFor(c.D, SpellKey(id), c.boss)
    if not s then return end
    for name in on:gmatch("[^,]+") do
        local k = c.byK[name]
        if k and not c.seen[k][s] then
            c.seen[k][s] = true
            Open(c, k, s, min(ts, c.from))
        end
    end
end
local function SortStates(L)
    local idx = {}
    for i = 1, L.ns do idx[i] = i end
    local F = L.stFrom
    tsort(idx, function(a, b)
        if F[a] ~= F[b] then return F[a] < F[b] end
        return a < b
    end)
    local k, s, f, t = {}, {}, {}, {}
    for i = 1, L.ns do
        local j = idx[i]
        k[i], s[i], f[i], t[i] = L.stK[j], L.stS[j], F[j], L.stTo[j]
    end
    L.stK, L.stS, L.stFrom, L.stTo = k, s, f, t
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
    local key = ns.NpcKey(guid) or 0
    local icon = c.adds[key]
    if icon == false or c.bosses[key] or c.addN >= ADD_LIMIT then return nil end
    add = ns.Replay.NewTrack(name)
    add.icon = icon or c.D.addDefault
    add.npc = ns.Replay.NpcOf(guid)
    add.guid = guid
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
local function OnSwing(c, ts, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, srcKey, dstKey)
    local kd = dst and c.byK[dst]
    if srcKey and c.bosses[srcKey] then
        if kd then
            local n = #c.swT + 1
            c.swT[n], c.swK[n], c.swG[n] = ts, kd, srcGUID
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
        and not c.bosses[dstKey or 0] then
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
        if SpellKey(def.spell) == spell and not def.follow
            and (not def.src or ns.NpcKey(srcGUID) == ns.NpcKeyOf(def.src)) then
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
local function OnBlast(c, ts, srcGUID, src, dst, spell, amount, srcFlags, srcKey)
    local defs = c.blastDefs
    local k = dst and c.byK[dst]
    if not defs or not spell or not k then return end
    local npc = srcFlags and band(srcFlags, F_NPC) > 0 and band(srcFlags, F_PLAYER) == 0
    for i = 1, #defs do
        local def = defs[i]
        if SpellKey(def.spell) == spell then
            local x, y = Pos(c, dst, ts)
            if not x then return end
            local L = c.L
            if L.nv < VICTIM_LIMIT then
                L.nv = L.nv + 1
                L.vT[L.nv], L.vK[L.nv] = ts, k
            end
            local key = (srcGUID and src ~= dst and not c.bosses[srcKey or 0]) and srcGUID or spell
            local j = c.blastOpen[key]
            local far = j and def.near and (x - L.bX[j]) ^ 2 + (y - L.bY[j]) ^ 2 > (def.near * c.ppy) ^ 2
            if j and ts - L.bT[j] <= BLAST_JOIN and not far then
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
            L.bTone[j] = def.tone
            c.blastMax[j] = amount or 0
            c.blastOpen[key] = j
            return
        end
    end
end
local function OnMelee(c, ts, srcGUID, srcKey, dst, spell)
    local kd = dst and c.byK[dst]
    if not kd or not spell or not c.melee or not c.melee[spell] or not srcKey or not c.bosses[srcKey] then return end
    local n = #c.swT + 1
    c.swT[n], c.swK[n], c.swG[n] = ts, kd, srcGUID
    c.tankHits[kd] = (c.tankHits[kd] or 0) + 1
end
local function OnTaunt(c, ts, src, dstKey, spell)
    local ks = src and c.byK[src]
    if not ks or not dstKey or not c.bosses[dstKey] or not spell or not c.taunts[spell] then return end
    local n = #c.tauT + 1
    c.tauT[n], c.tauK[n] = ts, ks
end
local function OnTarget(c, ts, srcGUID, dst)
    local n = #c.btT + 1
    c.btT[n], c.btK[n], c.btG[n] = ts, dst and c.byK[dst] or 0, srcGUID
end
local function OnThreat(c, ts, srcGUID, srcKey, who)
    if not srcKey or not c.bosses[srcKey] then return end
    local n = #c.thT + 1
    c.thT[n], c.thK[n], c.thG[n] = ts, who and c.byK[who] or 0, srcGUID
end
local function OnActive(c, ts, dstGUID, dstKey, spell)
    if not c.active or not spell or not c.active[spell] or not dstKey or not c.bosses[dstKey] then return end
    local n = #c.actT + 1
    c.actT[n], c.actG[n] = ts, dstGUID
end
local function OnFollow(c, ts, sub, src, dst, spell, srcKey)
    local defs = c.poolDefs
    if not defs or not src or src ~= dst or not c.bosses[srcKey or 0] then return end
    for i = 1, #defs do
        local def = defs[i]
        if def.follow and SpellKey(def.spell) == spell then
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
local function OnCone(c, ts, sub, src, dst, spell, srcKey, srcGUID)
    local defs = c.coneDefs
    if not defs or not spell or not src then return end
    for i = 1, #defs do
        local def = defs[i]
        if SpellKey(def.spell) == spell and def.sub == sub
            and ((def.src and ns.NpcKeyOf(def.src) == srcKey) or (not def.src and c.bosses[srcKey or 0])) then
            local L = c.L
            if L.nc >= CONE_LIMIT then return end
            local n = L.nc + 1
            L.nc = n
            L.cnT[n], L.cnTo[n], L.cnLen[n], L.cnDeg[n], L.cnS[n] = ts, ts + def.dur, def.len, def.deg, spell
            L.cnTone[n] = def.tone
            L.cnX[n], L.cnY[n], L.cnHx[n], L.cnHy[n] = -1, -1, 0, 1
            c.coneTo[n] = dst and c.byK[dst] or 0
            c.coneDef[n] = def
            c.coneG[n] = def.src and srcGUID or nil
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
        if ts - c.L.cnT[n] > (c.coneDef[n].win or AIM_WINDOW) then
            table.remove(list, w)
        else
            c.aimX[n], c.aimY[n], c.aimN[n] = c.aimX[n] + x, c.aimY[n] + y, c.aimN[n] + 1
            w = w + 1
        end
    end
end
local function OnCast(c, ts, sub, src, dst, spell, srcKey, srcGUID)
    OnCone(c, ts, sub, src, dst, spell, srcKey, srcGUID)
    local L = c.L
    if srcKey and c.bosses[srcKey] and L.nbc < CAST_LIMIT then
        local n = L.nbc + 1
        L.nbc = n
        L.bcT[n], L.bcD[n] = ts, sub == "SPELL_CAST_START" and CAST_SHOW or CAST_INSTANT
    end
end
local function OnGone(c, ts, sub, srcKey, id)
    local defs = c.goneDefs
    if not defs or not srcKey or not c.bosses[srcKey] then return end
    local n = tonumber(id)
    for i = 1, #defs do
        local def = defs[i]
        if def.sub == sub then
            for j = 1, #def.ids do
                if def.ids[j] == n then
                    local list = c.goneAt[i]
                    if #list == 0 or ts - list[#list] > def.min then list[#list + 1] = ts end
                    return
                end
            end
        end
    end
end
local function OnPlatform(c, ts, sub, srcKey, id)
    local def = c.platform
    if not def or not srcKey or not c.bosses[srcKey] then return end
    local kind = ns.ReplayPlatform.Match(def, id)
    if kind == "quake" then
        ns.ReplayPlatform.Add(c.L.pfQuake, def.quake, ts, sub == "SPELL_CAST_SUCCESS")
    elseif kind == "winter" then
        ns.ReplayPlatform.Add(c.L.pfWinter, def.winter, ts, sub == "SPELL_CAST_SUCCESS")
    end
end
local function OnMark(c, ts, key)
    local def = c.platform
    if not def then return end
    local k = tostring(key)
    if k ~= def.markFall and k ~= def.markBack then return end
    local L = c.L
    L.pfMarkT[#L.pfMarkT + 1], L.pfMarkK[#L.pfMarkK + 1] = ts, k
end
local function OnDied(c, ts, dstGUID, dst, dstKey)
    local k = dst and c.byK[dst]
    if k then
        for s in pairs(c.open[k]) do Close(c, k, s, ts) end
        c.diedK[#c.diedK + 1], c.diedT[#c.diedT + 1] = k, ts
        return
    end
    if dstKey and c.bosses[dstKey] then c.L.bossDied = ts end
    local add = dstGUID and c.addBy[dstGUID]
    if add and not add.to then add.to = ts end
end
local function OnSummon(c, ts, srcKey, dstGUID, dst)
    if not dstGUID or not dst then return end
    c.born[dstGUID] = ts
    if srcKey and c.bosses[srcKey] then AddOf(c, dstGUID, dst, ts) end
end
local function BossSeen(c, guid)
    if not guid then return end
    local n = c.bossN[guid]
    if n then
        c.bossN[guid] = n + 1
        return
    end
    c.bossN[guid] = 1
    c.bossG[#c.bossG + 1] = guid
end
local function Dispatch(c, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2, a4)
    local srcKey, dstKey = ns.NpcKey(srcGUID), ns.NpcKey(dstGUID)
    local sk = ns.SpellOf(sub, a1)
    if srcKey and c.bosses[srcKey] then BossSeen(c, srcGUID) end
    if dstKey and c.bosses[dstKey] then BossSeen(c, dstGUID) end
    if srcKey and c.npcOf[srcKey] == nil and c.bosses[srcKey] then
        c.npcOf[srcKey] = ns.NpcEntry(srcGUID) or false
        if c.npcOf[srcKey] and not c.firstNpc then c.firstNpc = c.npcOf[srcKey] end
    end
    if SWING[sub] then
        OnSwing(c, ts, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, srcKey, dstKey)
    elseif sub == "SPELL_AURA_APPLIED" or REMOVED[sub] then
        OnAura(c, ts, sub, src, dst, sk)
        OnFollow(c, ts, sub, src, dst, sk, srcKey)
        if sub == "SPELL_AURA_APPLIED" then
            OnPool(c, ts, sub, srcGUID, src, dst, sk)
            OnTaunt(c, ts, src, dstKey, sk)
            OnActive(c, ts, dstGUID, dstKey, sk)
        end
    elseif sub == "SPELL_AURA_REFRESH" then
        OnAura(c, ts, sub, src, dst, sk)
    elseif DAMAGE[sub] then
        OnOwn(c, ts, sub, src, sk)
        OnPool(c, ts, sub, srcGUID, src, dst, sk)
        if sub == "SPELL_DAMAGE" then OnAim(c, ts, dst, sk) end
        OnBlast(c, ts, srcGUID, src, dst, sk, tonumber(a4), srcFlags, srcKey)
        OnMelee(c, ts, srcGUID, srcKey, dst, sk)
    elseif sub == BTGT then
        OnTarget(c, ts, srcGUID, dst)
    elseif sub == THR then
        OnThreat(c, ts, srcGUID, srcKey, dst)
    elseif CASTS[sub] then
        OnCast(c, ts, sub, src, dst, sk, srcKey, srcGUID)
        OnOwn(c, ts, sub, src, sk)
        OnGone(c, ts, sub, srcKey, a1)
        OnPlatform(c, ts, sub, srcKey, a1)
        if sub == "SPELL_CAST_SUCCESS" then OnMelee(c, ts, srcGUID, srcKey, dst, sk) end
    elseif sub == "SPELL_MISSED" then
        OnAim(c, ts, dst, sk)
        OnMelee(c, ts, srcGUID, srcKey, dst, sk)
    elseif sub == "UNIT_DIED" then
        OnDied(c, ts, dstGUID, dst, dstKey)
    elseif sub == "SPELL_SUMMON" then
        OnSummon(c, ts, srcKey, dstGUID, dst)
    elseif sub == "FW_VEH" then
        OnVehicle(c, ts, src, tonumber(a1) == 1)
    elseif sub == "FW_MARK" then
        OnMark(c, ts, a1)
    elseif sub == "FW_BUFFSNAP" then
        OnSnap(c, ts, a1, a2)
    end
end
local function NewContext(scene)
    local fight = scene.fight
    local D = ns.replayData
    local byK = {}
    for k = 1, #scene.tracks do byK[scene.tracks[k].name] = k end
    local open, seen = {}, {}
    for k = 1, #scene.tracks do open[k], seen[k] = {}, {} end
    local aimSpells = {}
    local cones = D.cones[fight.boss]
    for i = 1, cones and #cones or 0 do
        for _, id in ipairs(cones[i].aim or {}) do aimSpells[SpellKey(id)] = true end
    end
    local melee, taunts, adds = nil, {}, {}
    if D.melee[fight.boss] then
        melee = {}
        for id in pairs(D.melee[fight.boss]) do melee[SpellKey(id)] = true end
    end
    for id in pairs(D.taunts) do taunts[SpellKey(id)] = true end
    for id, icon in pairs(D.adds) do adds[ns.NpcKeyOf(id)] = icon end
    local active = nil
    for _, id in ipairs(D.active[fight.boss] or {}) do
        active = active or {}
        active[SpellKey(id)] = true
    end
    local goneDefs = D.gone[fight.boss]
    local goneAt = {}
    for i = 1, goneDefs and #goneDefs or 0 do goneAt[i] = {} end
    return {
        goneDefs = goneDefs, goneAt = goneAt, home = D.home[fight.boss], platform = ns.ReplayPlatform.Def(fight.boss),
        L = NewLayers(), D = D, byK = byK, tracks = scene.tracks, open = open, seen = seen, from = fight.from, to = fight.to,
        ppy = scene.ppy, bosses = ns.Index.BossKeys(fight),
        poolDefs = D.pools[fight.boss], coneDefs = cones, taunts = taunts, adds = adds,
        blastDefs = D.blasts[fight.boss], blastOpen = {}, blastMax = {}, melee = melee,
        valkyr = D.valkyr.boss == fight.boss, boss = fight.boss,
        swT = {}, swK = {}, swG = {}, btT = {}, btK = {}, btG = {}, tgT = {}, tgK = {}, hold = TARGET_HOLD, tauT = {}, tauK = {},
        thT = {}, thK = {}, thG = {}, active = active, actT = {}, actG = {}, holders = {},
        tankHits = {}, addBy = {}, addN = 0, pools = {}, born = {}, follow = {},
        hitAt = {}, coneTo = {}, coneDef = {}, coneG = {}, aimX = {}, aimY = {}, aimN = {}, aimOpen = {}, aimSpells = aimSpells,
        npcOf = {}, diedK = {}, diedT = {}, bossN = {}, bossG = {},
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
local function Smooth(c, swT, swK)
    local tauT, tauK = c.tauT, c.tauK
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
        c.tgT, c.tgK, L.switchRaw = Smooth(c, c.swT, c.swK)
        c.hold = BOSS_STEP * 1.5
        L.targetSrc = "swing"
        L.switchSmooth = Switches(c.tgK)
        L.targets = raw
    end
    L.taunts = #c.tauT
    L.thrRows = #c.thT
end
local function OfBody(T, K, G, guid)
    if not guid then return T, K end
    local oT, oK = {}, {}
    for i = 1, #T do
        if G[i] == guid then
            oT[#oT + 1], oK[#oK + 1] = T[i], K[i]
        end
    end
    return oT, oK
end
local function Alive(c, k, t)
    local tr = c.tracks[k]
    local i = tr and ns.Replay.IndexAt(tr, t) or 0
    return i > 0 and tr.dz[i] == 0
end
local function Holders(c, guid)
    local h = c.holders[guid or ""]
    if h then return h end
    local bT, bK = OfBody(c.btT, c.btK, c.btG, guid)
    local hT, hK = OfBody(c.thT, c.thK, c.thG, guid)
    local sT, sK = OfBody(c.swT, c.swK, c.swG, guid)
    local _, smK = Smooth(c, sT, sK)
    local K, S = {}, {}
    local bi, hi, last, lastT = 0, 0, 0, -1e9
    local i, t = 0, c.from
    while t <= c.to do
        ns.Jobs.Step(2)
        i = i + 1
        while bi < #bT and bT[bi + 1] <= t + TARGET_AHEAD do bi = bi + 1 end
        while hi < #hT and hT[hi + 1] <= t + TARGET_AHEAD do hi = hi + 1 end
        local k, src = 0, nil
        if bi > 0 and bK[bi] > 0 and Alive(c, bK[bi], t) then
            k, src = bK[bi], "target"
        elseif hi > 0 and hK[hi] > 0 and t - hT[hi] <= THR_HOLD and Alive(c, hK[hi], t) then
            k, src = hK[hi], "threat"
        elseif (smK[i] or 0) > 0 and Alive(c, smK[i], t) then
            k, src = smK[i], "swing"
        elseif last > 0 and t - lastT <= HOLDER_KEEP and Alive(c, last, t) then
            k, src = last, "kept"
        end
        if src and src ~= "kept" then last, lastT = k, t end
        K[i], S[i] = k, src or false
        t = t + BOSS_STEP
    end
    h = { K = K, S = S }
    c.holders[guid or ""] = h
    return h
end
function Layers.HolderAt(c, guid, t)
    local h = Holders(c, guid)
    local i = floor((t - c.from) / BOSS_STEP + 0.5) + 1
    local k = h.K[i]
    if not k or k == 0 then return 0, nil end
    return k, h.S[i]
end
function Layers.HasHolders(c)
    return (c.btT and #c.btT or 0) + (c.thT and #c.thT or 0) + (c.swT and #c.swT or 0) > 0
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
local function Anyone(c, t)
    local tracks = c.tracks
    for k = 1, #tracks do
        local tr = tracks[k]
        local i = ns.Replay.IndexAt(tr, t)
        if i > 0 and tr.x[i] >= 0 and tr.dz[i] == 0 then return true end
    end
    return false
end
local function GoneSpan(c, at, def)
    local swT = c.swT
    local last, first = nil, nil
    for i = 1, #swT do
        local s = swT[i]
        if s <= at and s >= at - def.look then last = s end
        if not first and s >= at + def.min and s <= at + def.max then first = s end
    end
    return max(c.from, last or (at - def.lead)), first or (at + def.land)
end
local function AddFixed(c, kind, from, to)
    local fx = c.fixed
    local n = fx.n + 1
    fx.n = n
    fx.kind[n], fx.from[n], fx.to[n], fx.empty[n] = kind, from, to, false
    return n
end
local function PinPoint(room, at, ppy)
    if not at then return room.cx, room.cy end
    return room.cx + at[1] * ppy, room.cy + at[2] * ppy
end
local function FeedRow(rows, label, sec)
    rows[#rows + 1] = { key = "gone", label = label, from = sec, to = sec }
end
local function FixSpans(scene, c, res)
    local fx = { n = 0, kind = {}, from = {}, to = {}, empty = {}, x = {}, y = {}, glide = {}, sx = {}, sy = {} }
    c.fixed = fx
    c.L.fixed = fx
    local rows = nil
    local room = scene.room
    local defs = c.goneDefs
    for i = 1, defs and #defs or 0 do
        local def, list = defs[i], c.goneAt[i]
        for j = 1, #list do
            local from, to = GoneSpan(c, list[j], def)
            local air = def.at and room
            local n = AddFixed(c, air and "pin" or "gone", from, min(to, c.to))
            fx.empty[n] = def.empty == true
            if air then
                fx.x[n], fx.y[n] = PinPoint(room, def.at, c.ppy)
                fx.glide[n] = def.glide or 0
            end
            if def.feed then
                rows = rows or {}
                FeedRow(rows, "rep.f.takeoff", from - c.from)
                if to < c.to then FeedRow(rows, "rep.f.landing", to - c.from) end
            end
        end
    end
    local pin = c.D.pin[scene.fight.boss]
    if pin and room and res then
        local px, py = PinPoint(room, pin.at, c.ppy)
        for k = 1, #res.spans do
            local sp = res.spans[k]
            if pin.phases and pin.phases[sp.key] then
                local n = AddFixed(c, "pin", c.from + sp.from, min(c.to, c.from + sp.to + pin.tail))
                fx.x[n], fx.y[n], fx.glide[n] = px, py, pin.glide
            end
        end
        for kind in pairs(pin.waves or {}) do
            local times, ends = res.waves[kind] or {}, res.ends[kind] or {}
            for j = 1, #times do
                if ends[j] then
                    local n = AddFixed(c, "pin", c.from + times[j], min(c.to, c.from + ends[j] + pin.tail))
                    fx.x[n], fx.y[n], fx.glide[n] = px, py, pin.glide
                end
            end
        end
    end
    if not rows then return res end
    local spans = { res and res.spans[1] or { key = "fight", label = "ph.fight", from = 0, to = c.to - c.from } }
    for k = 2, res and #res.spans or 0 do spans[#spans + 1] = res.spans[k] end
    for k = 1, #rows do spans[#spans + 1] = rows[k] end
    return { spans = spans, waves = res and res.waves or {}, ends = res and res.ends or {} }
end
function Layers.Fixed(c, t, ax, ay)
    local fx = c.fixed
    if not fx then return nil, 0, 0, 0 end
    for i = 1, fx.n do
        if t >= fx.from[i] and t < fx.to[i] then
            if fx.kind[i] == "pin" then
                local x, y = fx.x[i], fx.y[i]
                if not fx.sx[i] then fx.sx[i], fx.sy[i] = ax or x, ax and ay or y end
                local k = fx.glide[i] > 0 and min(1, (t - fx.from[i]) / fx.glide[i]) or 1
                return "pin", fx.sx[i] + (x - fx.sx[i]) * k, fx.sy[i] + (y - fx.sy[i]) * k, fx.from[i]
            end
            if not fx.empty[i] or not Anyone(c, t) then return "gone", 0, 0, fx.from[i] end
        end
    end
    return nil, 0, 0, 0
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
        local fixed, px, py, fixFrom = Layers.Fixed(c, t, ax, ay)
        if fixed == "gone" then
            ax, lastX = nil, nil
            if tr.n > 0 and tr.x[tr.n] >= 0 then
                ns.Replay.Push(tr, max(fixFrom, tr.t[tr.n]), -1, -1, 1, 0)
                tr.fx[tr.n], tr.fy[tr.n] = 0, 1
            end
        elseif fixed == "pin" then
            cx, cy = px, py
            lastX, lastY, lastT = px, py, t
            ax, ay, at = px, py, t
        elseif tx >= 0 then
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
        local def = c.coneDef[n]
        local org = boss
        if def.src then org = c.addBy[c.coneG[n] or ""] end
        local ox, oy = -1, -1
        if org then ox, oy = ns.Replay.PosHold(org, ts, WITNESS_HOLD) end
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
                if d > (def.src and ADD_AIM * ppy or 0.01) then hx, hy = dx / d, dy / d end
            end
            if hx == 0 and hy == 0 and not def.src and boss.fx then
                local i = ns.Replay.IndexAt(boss, ts)
                if i > 0 then hx, hy = boss.fx[i] or 0, boss.fy[i] or 0 end
            end
            if hx ~= 0 or hy ~= 0 then
                if def.back then hx, hy = -hx, -hy end
                L.cnX[n], L.cnY[n], L.cnHx[n], L.cnHy[n] = ox, oy, hx, hy
                L.cnLen[n] = (L.cnLen[n] + (def.src and 0 or L.hitbox)) * ppy
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
local function FinishAddHp(c, segs, to)
    local adds = c.L.adds
    local n = 0
    for i = 1, #adds do
        local add = adds[i]
        local ts, ps = ns.Streams.NpcHp(segs, add.guid, to)
        if ts then
            add.hpT, add.hpV, add.hpI = ts, ps, 1
            n = n + 1
        end
    end
    c.L.addHp = n
end
local function FinishBossHp(c, segs, to, first, realms)
    local bodies = {}
    local guids, count = c.bossG, c.bossN
    for i = 1, #guids do
        local guid = guids[i]
        local ts, ps = ns.Streams.NpcHp(segs, guid, to)
        if ts then
            local npc = ns.Replay.NpcOf(guid)
            bodies[#bodies + 1] = {
                guid = guid, npc = npc, world = realms and npc and realms.rd.boss[npc] or nil,
                hpT = ts, hpV = ps, hpI = 1,
            }
        end
    end
    tsort(bodies, function(a, b)
        if (a.guid == first) ~= (b.guid == first) then return a.guid == first end
        local na, nb = count[a.guid], count[b.guid]
        if na ~= nb then return na > nb end
        return a.guid < b.guid
    end)
    for i = #bodies, BOSS_HP_BODIES + 1, -1 do bodies[i] = nil end
    c.L.bossBodies = #bodies > 0 and bodies or nil
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
    local MK = ns.ReplayMarks
    local mc = MK.New(fight)
    local RB = ns.ReplayBars
    local rb = RB and RB.New(fight)
    local RM = ns.ReplayMech
    local rm = RM and RM.New(fight)
    local RR = ns.ReplayRealm
    local rr = RR and RR.New(fight)
    local SP = ns.ReplaySpread
    local sp = SP and SP.New(fight)
    local SW = ns.ReplaySwarm
    local sw = SW and SW.New(fight)
    local CL = ns.ReplayClass
    local cl = CL and CL.New(fight)
    local CU = ns.ReplayCue
    local cu = CU and CU.New(fight)
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
            MK.Event(mc, ts, sub, src, dst, a1)
            if rb then RB.Event(rb, ts, sub, src, dst, a1) end
            if rm then RM.Event(rm, ts, sub, srcGUID, src, dstGUID, dst, a1, a4) end
            if rr then RR.Event(rr, ts, sub, srcGUID, src, dstGUID, dst, a1, a2) end
            if sp then SP.Event(sp, ts, sub, src, dst, a1) end
            if sw then SW.Event(sw, ts, sub, src, dst, a1) end
            if cl then CL.Event(cl, ts, sub, srcGUID, src, dstGUID, dst, a1) end
            if cu then CU.Event(cu, ts, sub, srcGUID, src, dst, a1) end
            if np then ns.NpcPos.Feed(np, ts, sub, srcGUID, src, srcFlags, dstGUID, dst, dstFlags, a1, a2) end
        end
    end
    local res = ph and ns.Phases.Done(fight, ph) or ns.Phases.Get(fight)
    SortStates(c.L)
    ns.Replay.SnapDeaths(scene, c.diedK, c.diedT)
    FinishPools(c)
    FinishAdds(c)
    FinishAddHp(c, segs, fight.to)
    Tanks(c)
    local feedRes = FixSpans(scene, c, res)
    local f0 = debugprofilestop()
    if rm then RM.Done(rm, c.L, function(name, t) return Pos(c, name, t) end, c.ppy, fc, c.byK) end
    if rr then RR.Done(rr, c.L, function(name, t) return Pos(c, name, t) end, c.ppy) end
    if sp then SP.Done(sp, c.L, scene) end
    if sw then SW.Done(sw, c.L, scene) end
    if cu then CU.Done(cu, c.L, scene) end
    FC.Done(fc, c.L, feedRes)
    MK.Done(mc, c.L, feedRes)
    if rm and #rm.marks > 0 then c.L.marks = MK.Merge(c.L.marks, rm.marks) end
    if rb then RB.Done(rb, c.L, feedRes, fight) end
    c.L.feedMs = debugprofilestop() - f0
    PickTargets(c)
    if not (np and ns.NpcPos.Place(np, Layers.HolderAt)) then PlaceBoss(scene, c) end
    FinishBossHp(c, segs, fight.to, np and np.stats.guid, rr)
    PlaceCones(scene, c)
    if cl then CL.Done(cl, c.L, scene, c.bosses) end
    c.L.bsT = c.swT
    c.L.bossNpc = c.npcOf[fight.boss] or c.firstNpc
    c.L.ms = debugprofilestop() - p0
    scene.layers = c.L
    return c.L
end
function Layers.AddHp(add, t)
    local T = add.hpT
    if not T then return nil end
    local V = add.hpV
    local n = #T
    local i = add.hpI or 1
    if i > n then i = n end
    while i > 1 and T[i] > t do i = i - 1 end
    while i < n and T[i + 1] <= t do i = i + 1 end
    add.hpI = i
    local v = V[i]
    if i == n or T[i] > t then return v end
    local ramp = min(T[i + 1] - T[i], ADD_HP_RAMP)
    local from = T[i + 1] - ramp
    if t <= from then return v end
    return v + (V[i + 1] - v) * (t - from) / ramp
end
function Layers.BossHp(scene, t)
    local L = scene.layers
    local bodies = L and L.bossBodies
    if not bodies then return nil end
    local world = nil
    local R = L.realm
    if R then world = (ns.ReplayRealm.In(R.boss[1], t) and 1) or (ns.ReplayRealm.In(R.boss[2], t) and 2) or 1 end
    local last, lastT = nil, nil
    for i = 1, #bodies do
        local b = bodies[i]
        local T = b.hpT
        if (not world or not b.world or b.world == world) and T[1] - BOSS_HP_LEAD <= t then
            local tail = T[#T]
            if t <= tail + BOSS_HP_HOLD then return Layers.AddHp(b, t) end
            if not lastT or tail > lastT then last, lastT = b, tail end
        end
    end
    return last and Layers.AddHp(last, t) or nil
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
