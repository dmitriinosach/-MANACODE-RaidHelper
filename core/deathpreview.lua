local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local find = string.find
local match = string.match
local band = bit.band
local BEFORE = 8
local AFTER = 1
local SPOT_BEFORE = 4
local SPOT_AFTER = 4
local BIN = 0.5
local LOOK = 15
local SUM_SPAN = 5
local AURA_ROWS = 3
local CAST_GAP = 3
local CAST_MAX = 16
local OWN_MAX = 24
local BIG_MAX = 3
local DEATH_BACK = 1
local DEATH_AHEAD = 8
local KILL_SLACK = 0.3
local HP_BACK = 3
local KILL_WINDOW = 3
local LOCK_SLACK = 1
local HP_STEP = 0.01
local HP_CUT = 0.05
local F_PLAYER = 0x400
local TRAIL_STEP = 0.25
local TRAIL_MIN_YD = 0.1
local ADD_HOLD = 4
local NEAR_YD = 20
local BOSS_NEAR_YD = 35
local FRAME_MIN_YD = 15
local FRAME_PAD_YD = 4
local FRAME_PASSES = 3
local SCENE_KEY = {}
local ENEMY_CASTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }
local PREVIEW_KINDS = { skull = true, death = true, killer = true, hit = true, aura = true, ticks = true,
                        stack = true, chased = true, blast = true, emote = true }
local DP = {}
ns.DeathPreview = DP
DP.BEFORE, DP.AFTER, DP.BIN = BEFORE, AFTER, BIN
function DP.Wants(kind)
    return kind ~= nil and PREVIEW_KINDS[kind] == true
end
local cache = setmetatable({}, { __mode = "k" })
local warmKeys = setmetatable({}, { __mode = "k" })
local warmed = setmetatable({}, { __mode = "k" })
local sceneFight = nil
local sceneReady = nil
local function New(who, at, death)
    local before = death and ns.Tune("preview") or SPOT_BEFORE
    local after = death and AFTER or SPOT_AFTER
    local n = ceil((before + after) / BIN)
    local pv = { who = who, at = at, death = death, before = before, after = after,
                 from = at - before, to = at + after, bin = BIN, n = n,
                 dmg = {}, abs = {}, heal = {}, over = {}, hpT = {}, hpV = {}, hpMax = 0,
                 bigT = {}, bigV = {}, bigId = {}, bigLabel = {}, kbV = 0, kbOver = 0,
                 auraId = {}, auraLabel = {}, auraMax = {}, auraCover = {}, auraLive = {}, auraSrc = {}, rows = {}, extra = 0,
                 spanAura = {}, spanFrom = {}, spanTo = {}, spanStack = {},
                 castT = {}, castId = {}, castLabel = {}, castSrc = {}, ownT = {},
                 defT = {}, defId = {}, defLabel = {},
                 dmgSum = 0, healSum = 0, lines = 0, ms = 0 }
    if death then
        pv.sumFrom, pv.sumTo, pv.sumSpan = at - SUM_SPAN, at, SUM_SPAN
    else
        pv.sumFrom, pv.sumTo, pv.sumSpan = pv.from, pv.to, before + after
    end
    for b = 1, n do
        pv.dmg[b], pv.abs[b], pv.heal[b], pv.over[b] = 0, 0, 0, 0
    end
    return pv
end
function DP.BinOf(pv, ts)
    local b = ceil((ts - pv.from) / pv.bin - 1e-6)
    if b < 1 then return 1 end
    if b > pv.n then return pv.n end
    return b
end
local function Big(pv, ts, amount, id, label)
    local list = pv.bigV
    local slot = #list + 1
    if slot > BIG_MAX then
        if amount <= list[BIG_MAX] then return end
        slot = BIG_MAX
    end
    while slot > 1 and list[slot - 1] < amount do
        pv.bigT[slot], pv.bigV[slot] = pv.bigT[slot - 1], list[slot - 1]
        pv.bigId[slot], pv.bigLabel[slot] = pv.bigId[slot - 1], pv.bigLabel[slot - 1]
        slot = slot - 1
    end
    pv.bigT[slot], pv.bigV[slot], pv.bigId[slot], pv.bigLabel[slot] = ts, amount, id or false, label
end
local function AuraRow(pv, open, key, id, label, src)
    local row = open[key]
    if row then return row end
    row = #pv.auraLabel + 1
    pv.auraId[row], pv.auraLabel[row], pv.auraMax[row], pv.auraCover[row] = id or false, label, 0, 0
    pv.auraLive[row] = false
    pv.auraSrc[row] = src or ""
    open[key] = row
    return row
end
local function OpenSpan(pv, live, row, ts, stack)
    local k = #pv.spanAura + 1
    pv.spanAura[k], pv.spanFrom[k], pv.spanTo[k], pv.spanStack[k] = row, max(ts, pv.from), pv.to, stack
    live[row] = k
    if stack > pv.auraMax[row] then pv.auraMax[row] = stack end
end
local function CloseSpan(pv, live, row, ts)
    local k = live[row]
    if not k then return end
    pv.spanTo[k] = min(max(ts, pv.from), pv.to)
    live[row] = nil
end
local function IsAuraSub(sub)
    return sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_REMOVED"
        or sub == "SPELL_AURA_APPLIED_DOSE" or sub == "SPELL_AURA_REMOVED_DOSE"
end
local function FromEnemy(fight, who, srcName, srcFlags, id)
    if srcName == who then
        return not (id and ((ns.lockouts or {})[id] or (ns.debuffNoise or {})[id]))
    end
    if srcName == nil then return true end
    if fight.players[srcName] then return false end
    return srcFlags == nil or band(srcFlags, F_PLAYER) == 0
end
local function Lockout(pv, st, ts, sub, id, name)
    if sub == "SPELL_AURA_REMOVED" then
        if ts < pv.at - LOCK_SLACK then
            st.locks[id] = false
        elseif st.locks[id] == nil then
            st.locks[id] = tostring(name or id)
        end
    elseif ts <= pv.at then
        st.locks[id] = tostring(name or id)
    end
end
local function Materialize(pv, st)
    if st.started then return end
    st.started = true
    for key, a in pairs(st.pre) do
        local row = AuraRow(pv, st.open, key, a.id, a.label, a.src)
        OpenSpan(pv, st.live, row, pv.from, a.stack)
    end
end
local function Aura(pv, st, ts, sub, src, a1, a2, a5)
    local key = tostring(a2 or a1)
    local id = tonumber(a1)
    if ts < pv.from then
        local cur = st.pre[key]
        if sub == "SPELL_AURA_REMOVED" then
            st.pre[key] = nil
        elseif not cur then
            st.pre[key] = { id = id, label = key, src = src, stack = tonumber(a5) or 1 }
        elseif sub ~= "SPELL_AURA_REFRESH" and sub ~= "SPELL_AURA_APPLIED" then
            cur.stack = tonumber(a5) or cur.stack
        end
        return
    end
    Materialize(pv, st)
    local row = AuraRow(pv, st.open, key, id, key, src)
    local k = st.live[row]
    if sub == "SPELL_AURA_REMOVED" then
        if not k then OpenSpan(pv, st.live, row, pv.from, 1) end
        CloseSpan(pv, st.live, row, ts)
    elseif sub == "SPELL_AURA_APPLIED_DOSE" or sub == "SPELL_AURA_REMOVED_DOSE" then
        CloseSpan(pv, st.live, row, ts)
        OpenSpan(pv, st.live, row, k and ts or pv.from, tonumber(a5) or 1)
    elseif not k then
        OpenSpan(pv, st.live, row, ts, 1)
    end
end
local function EnemyCast(pv, st, ts, id, label, src)
    local last = st.seen[label]
    if last and ts - last < CAST_GAP then return end
    st.seen[label] = ts
    local k = #pv.castT + 1
    if k > CAST_MAX then return end
    pv.castT[k], pv.castId[k], pv.castLabel[k], pv.castSrc[k] = ts, id or false, label, src or ""
end
local function Hit(pv, ts, sub, swing, srcName, a1, a2, a3, a4, a5, a6, a7, a9)
    local amount, over, absorbed, id, label
    if sub == "ENVIRONMENTAL_DAMAGE" then
        amount, over, absorbed, label = tonumber(a2) or 0, tonumber(a3) or 0, tonumber(a7) or 0, ns.EnvName(a1)
    elseif swing then
        amount, over, absorbed, label = tonumber(a1) or 0, tonumber(a2) or 0, tonumber(a6) or 0, ns.T("tl.swing")
    else
        amount, over, absorbed = tonumber(a4) or 0, tonumber(a5) or 0, tonumber(a9) or 0
        id, label = tonumber(a1), tostring(a2 or a1)
    end
    if over < 0 then over = 0 end
    local b = DP.BinOf(pv, ts)
    pv.dmg[b] = pv.dmg[b] + amount
    pv.abs[b] = pv.abs[b] + absorbed
    if ts <= pv.sumTo and ts > pv.sumFrom then pv.dmgSum = pv.dmgSum + amount - over + absorbed end
    if amount > 0 then Big(pv, ts, amount, id, label) end
    if pv.death and ts <= pv.at + KILL_SLACK and (over > 0 or pv.kbOver == 0) then
        pv.kbT, pv.kbV, pv.kbOver, pv.kbId, pv.kbLabel, pv.kbSrc = ts, amount, over, id, label, srcName
    end
end
local function Soaked(pv, ts, amount)
    if amount <= 0 then return end
    local b = DP.BinOf(pv, ts)
    pv.abs[b] = pv.abs[b] + amount
    if ts <= pv.sumTo and ts > pv.sumFrom then pv.dmgSum = pv.dmgSum + amount end
end
local function Healed(pv, ts, a4, a5)
    local amount = tonumber(a4) or 0
    local over = tonumber(a5) or 0
    local eff = max(0, amount - over)
    local b = DP.BinOf(pv, ts)
    pv.heal[b] = pv.heal[b] + eff
    pv.over[b] = pv.over[b] + min(amount, over)
    if ts <= pv.sumTo and ts > pv.sumFrom then pv.healSum = pv.healSum + eff end
end
local function ScanMine(fight, idx, pv, st)
    local who = pv.who
    local mine = idx.who[who] or {}
    local defensives = ns.defensives or {}
    local i = ns.Index.Seek(idx, mine, pv.from - LOOK - 1)
    while mine[i] do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, mine[i])
        i = i + 1
        local ts, sub, _, srcName, srcFlags, _, dstName, _, a1, a2, a3, a4, a5, a6, a7, _, a9
            = ns.Store.Decode(seg, s, at, 9)
        if ts and ts > pv.to then break end
        if ts and sub then
            pv.lines = pv.lines + 1
            if dstName == who and IsAuraSub(sub) then
                local id = tonumber(a1)
                if a4 == "DEBUFF" and FromEnemy(fight, who, srcName, srcFlags, id) then
                    Aura(pv, st, ts, sub, srcName, a1, a2, a5)
                elseif id and (ns.lockouts or {})[id] then
                    Lockout(pv, st, ts, sub, id, a2)
                end
            elseif ts >= pv.from then
                Materialize(pv, st)
                local swing = find(sub, "SWING", 1, true) ~= nil
                if dstName == who and find(sub, "_DAMAGE", 1, true) then
                    Hit(pv, ts, sub, swing, srcName, a1, a2, a3, a4, a5, a6, a7, a9)
                elseif dstName == who and find(sub, "_MISSED", 1, true) then
                    if (swing and a1 or a4) == "ABSORB" then Soaked(pv, ts, tonumber(swing and a2 or a5) or 0) end
                elseif dstName == who and find(sub, "_HEAL", 1, true) then
                    Healed(pv, ts, a4, a5)
                elseif srcName == who and sub == "SPELL_CAST_SUCCESS" then
                    local id = tonumber(a1)
                    if id and defensives[id] then
                        local k = #pv.defT + 1
                        pv.defT[k], pv.defId[k], pv.defLabel[k] = ts, id, tostring(a2 or a1)
                    elseif #pv.ownT < OWN_MAX then
                        pv.ownT[#pv.ownT + 1] = ts
                    end
                elseif ENEMY_CASTS[sub] and srcName ~= who and srcFlags and band(srcFlags, F_PLAYER) == 0
                    and not fight.players[srcName or ""] then
                    EnemyCast(pv, st, ts, tonumber(a1), tostring(a2 or a1), srcName)
                end
            end
        end
    end
    Materialize(pv, st)
end
local function ScanCommon(idx, pv, st)
    local common = idx.common
    local i = ns.Index.Seek(idx, common, pv.from)
    while common[i] do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, common[i])
        i = i + 1
        local ts, sub, _, srcName, _, _, _, _, a1, a2 = ns.Store.Decode(seg, s, at, 2)
        if ts and ts > pv.to then break end
        if ts and ENEMY_CASTS[sub] then
            pv.lines = pv.lines + 1
            EnemyCast(pv, st, ts, tonumber(a1), tostring(a2 or a1), srcName)
        end
    end
end
local function PutHp(pv, st, ts, hpNow, hpMax)
    pv.lines = pv.lines + 1
    local pct = hpNow / hpMax
    pv.hpMax = hpMax
    local k = #pv.hpT
    if ts <= pv.from and k > 0 then
        pv.hpT[k], pv.hpV[k] = pv.from, pct
        st.last = pct
    elseif k == 0 or math.abs(pct - st.last) >= HP_STEP or (pct == 0) ~= (st.last == 0) then
        pv.hpT[k + 1], pv.hpV[k + 1] = max(ts, pv.from), pct
        st.last = pct
    end
end
local function ScanHpStreams(idx, pv, st)
    local from = pv.from - HP_BACK
    local held, any = nil, false
    for _, seg in ipairs(idx.segs) do
        if ns.Store.IsNew(seg) then
            for ts, hpNow, hpMax in ns.Decode.Hp(seg, pv.who, from, pv.to) do
                ns.Jobs.Step()
                if ts > pv.to then break end
                if hpMax > 0 then
                    if ts < from then
                        held = held or {}
                        held[1], held[2] = hpNow, hpMax
                    else
                        if held and not any then PutHp(pv, st, from, held[1], held[2]) end
                        any = true
                        PutHp(pv, st, ts, hpNow, hpMax)
                    end
                end
            end
        end
    end
    if held and not any then PutHp(pv, st, from, held[1], held[2]) end
end
local function ScanHp(idx, pv)
    local st = { last = -1 }
    if ns.Streams.Any(idx.segs) then
        ScanHpStreams(idx, pv, st)
        return
    end
    local snaps = idx.snaps
    local needles = {}
    local i = ns.Index.Seek(idx, snaps, pv.from - HP_BACK)
    while snaps[i] do
        ns.Jobs.Step()
        local seg, s, at = ns.Index.Line(idx, snaps[i])
        i = i + 1
        local ts = seg.t0 + tonumber(match(s, "^(%d+)", at)) / 1000
        if ts > pv.to then break end
        local needle = needles[seg]
        if needle == nil then
            local id = ns.Store.IdOf(seg, pv.who)
            needle = id and ("." .. id .. ":") or false
            needles[seg] = needle
        end
        if needle then
            local stop = find(s, "\n", at, true)
            local p = find(s, needle, at, true)
            if p and (not stop or p < stop) then
                local cur, top = match(s, "^%.%d+:(%d+):(%d+)", p)
                local hpNow, hpMax = tonumber(cur), tonumber(top)
                if hpNow and hpMax and hpMax > 0 then PutHp(pv, st, ts, hpNow, hpMax) end
            end
        end
    end
end
local function HpMarks(pv)
    local n = #pv.hpT
    if n == 0 then return end
    pv.hpStart = pv.hpV[1]
    local cut = pv.death and pv.at - HP_CUT or pv.at
    for k = 1, n do
        if pv.hpT[k] <= cut and (not pv.death or pv.hpV[k] > 0) then pv.hpAt = pv.hpV[k] end
    end
    if not pv.hpAt then pv.hpAt = pv.hpV[1] end
end
local function TrackOf(scene, who)
    local tracks = scene.tracks
    for k = 1, #tracks do
        if tracks[k].name == who then return k end
    end
    return 0
end
local function Trail(m, tr, from, to)
    local R = ns.Replay
    local near = TRAIL_MIN_YD * m.ppy
    local n = 0
    local t = from
    while t <= to + 1e-6 do
        local x, y = R.PosAtTime(tr, t)
        if x >= 0 then
            if n > 0 and math.abs(m.trX[n] - x) < near and math.abs(m.trY[n] - y) < near then
                m.trT[n] = t
            else
                n = n + 1
                m.trX[n], m.trY[n], m.trT[n] = x, y, t
            end
        end
        t = t + TRAIL_STEP
    end
end
local function Around(m, scene, k, t)
    local R = ns.Replay
    R.Sample(scene, t)
    local states = scene.states
    for j = 1, #states do
        local st = states[j]
        if st.vis then
            if j == k then
                m.endX, m.endY, m.endDead = st.x, st.y, st.dead
            else
                local n = #m.nbX + 1
                m.nbX[n], m.nbY[n], m.nbDead[n], m.nbStale[n] = st.x, st.y, st.dead, st.stale
            end
        end
    end
    local boss = scene.bossState
    if boss.vis then m.bossX, m.bossY, m.bossName = boss.x, boss.y, scene.bossName or scene.fight.boss end
    local adds = scene.layers and scene.layers.adds or {}
    for i = 1, #adds do
        local a = adds[i]
        if a.from <= t and (a.to or t) > t then
            local x, y
            if a.chaseK and a.chaseTo and t < a.chaseTo then
                x, y = R.PosAtTime(scene.tracks[a.chaseK], t)
            else
                x, y = R.PosHold(a, t, ADD_HOLD)
            end
            if x >= 0 then m.addX[#m.addX + 1], m.addY[#m.addY + 1] = x, y end
        end
    end
end
local function Reach(m, cx, cy, px, py)
    local far = 0
    for i = 1, #px do
        local dx, dy = px[i] - cx, py[i] - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d > far then far = d end
    end
    return far + FRAME_PAD_YD * m.ppy
end
local function Near(m, px, py, x, y, fx, fy, lim)
    local dx, dy = x - fx, y - fy
    if dx * dx + dy * dy <= lim * lim then px[#px + 1], py[#py + 1] = x, y end
end
local function Frame(m)
    local ppy = m.ppy
    local fx, fy = m.endX, m.endY
    if not fx and #m.trX > 0 then fx, fy = m.trX[#m.trX], m.trY[#m.trY] end
    if not fx then
        m.cx, m.cy, m.half = m.dcx, m.dcy, m.dr
        return
    end
    local px, py = { fx }, { fy }
    for i = 1, #m.trX do px[#px + 1], py[#py + 1] = m.trX[i], m.trY[i] end
    for i = 1, #m.nbX do Near(m, px, py, m.nbX[i], m.nbY[i], fx, fy, NEAR_YD * ppy) end
    for i = 1, #m.addX do Near(m, px, py, m.addX[i], m.addY[i], fx, fy, NEAR_YD * ppy) end
    if m.bossX then Near(m, px, py, m.bossX, m.bossY, fx, fy, BOSS_NEAR_YD * ppy) end
    local l, r, t, b = fx, fx, fy, fy
    for i = 1, #px do
        l, r, t, b = min(l, px[i]), max(r, px[i]), min(t, py[i]), max(b, py[i])
    end
    local cx, cy = (l + r) / 2, (t + b) / 2
    local half = max(FRAME_MIN_YD * ppy, Reach(m, cx, cy, px, py))
    local ox, oy = fx - m.dcx, fy - m.dcy
    local inside = ox * ox + oy * oy <= m.dr * m.dr
    for _ = 1, FRAME_PASSES do
        if not inside then break end
        if half >= m.dr then
            cx, cy, half = m.dcx, m.dcy, m.dr
            break
        end
        local dx, dy = cx - m.dcx, cy - m.dcy
        local d = math.sqrt(dx * dx + dy * dy)
        local lim = m.dr - half
        if d <= lim then break end
        cx, cy = m.dcx + dx / d * lim, m.dcy + dy / d * lim
        half = max(half, Reach(m, cx, cy, px, py))
    end
    m.cx, m.cy, m.half = cx, cy, half
end
local function FillMap(fight, pv, scene)
    local p0 = debugprofilestop()
    local m = { level = 0, ppy = 1, dcx = 0, dcy = 0, dr = 1, cx = 0, cy = 0, half = 1,
                trX = {}, trY = {}, trT = {}, nbX = {}, nbY = {}, nbDead = {}, nbStale = {},
                addX = {}, addY = {}, endDead = false, tracks = 0, ms = 0 }
    pv.map = m
    if not scene then
        m.none = true
        m.ms = debugprofilestop() - p0
        return
    end
    m.room, m.level, m.ppy, m.tracks = scene.room, scene.floor, scene.ppy, #scene.tracks
    if m.room then
        m.dcx, m.dcy, m.dr = m.room.cx, m.room.cy, m.room.r
    else
        m.dcx, m.dcy, m.dr = scene.cx, scene.cy, scene.r
        m.gx, m.gy = scene.gx, scene.gy
    end
    local k = TrackOf(scene, pv.who)
    if k > 0 then Trail(m, scene.tracks[k], pv.from, pv.death and pv.at or pv.to) end
    Around(m, scene, k, pv.at)
    local kind, since, level = ns.Replay.GapAt(scene, pv.at)
    if kind == "away" then
        m.note = ns.Encounters.FloorNote(fight.boss, level)
        m.away = level
    elseif kind == "lost" then
        m.lost = since - fight.from
    end
    Frame(m)
    m.ms = debugprofilestop() - p0
end
function DP.Scene(fight, onDone, urgent)
    if sceneFight == fight and sceneReady ~= nil then return onDone(sceneReady) end
    if sceneFight ~= fight then
        ns.Jobs.Cancel(SCENE_KEY)
        sceneFight, sceneReady = fight, nil
    end
    ns.Index.Get(fight, function(idx)
        if sceneFight ~= fight then return end
        if not idx then
            sceneReady = false
            return onDone(false)
        end
        ns.Jobs.Run(SCENE_KEY, function()
            local frames = ns.Encounters.PosWindow(fight, idx, fight.from, fight.to)
            if #frames == 0 then return false end
            local scene = ns.Replay.Build(fight, frames)
            if ns.ReplayLayers then ns.ReplayLayers.Build(scene) end
            return scene
        end, function(scene)
            if sceneFight == fight then sceneReady = scene or false end
            onDone(scene or false)
        end, "prev.map", urgent)
    end, urgent)
end
function DP.Map(fight, pv, onDone)
    if pv.map then return onDone(pv) end
    DP.Scene(fight, function(scene)
        if not pv.map then FillMap(fight, pv, scene) end
        onDone(pv)
    end, true)
end
local function PickRows(pv)
    local cover = pv.auraCover
    for k = 1, #pv.spanAura do
        local row = pv.spanAura[k]
        cover[row] = cover[row] + (pv.spanTo[k] - pv.spanFrom[k])
        if pv.spanFrom[k] <= pv.at and pv.spanTo[k] >= pv.at - pv.bin then pv.auraLive[row] = true end
    end
    local order = {}
    for row = 1, #pv.auraLabel do
        if cover[row] > 0 then order[#order + 1] = row end
    end
    table.sort(order, function(a, b)
        if pv.auraLive[a] ~= pv.auraLive[b] then return pv.auraLive[a] end
        if pv.auraMax[a] ~= pv.auraMax[b] then return pv.auraMax[a] > pv.auraMax[b] end
        return cover[a] > cover[b]
    end)
    for k = 1, min(AURA_ROWS, #order) do pv.rows[k] = order[k] end
    pv.extra = max(0, #order - AURA_ROWS)
end
local function SortCasts(pv)
    local n = #pv.castT
    local order = {}
    for k = 1, n do order[k] = k end
    table.sort(order, function(a, b) return pv.castT[a] < pv.castT[b] end)
    local t, id, label, src = {}, {}, {}, {}
    for k = 1, n do
        local o = order[k]
        t[k], id[k], label[k], src[k] = pv.castT[o], pv.castId[o], pv.castLabel[o], pv.castSrc[o]
    end
    pv.castT, pv.castId, pv.castLabel, pv.castSrc = t, id, label, src
end
function DP.Build(fight, idx, who, at, death)
    local p0 = debugprofilestop()
    local pv = New(who, at, death)
    local st = { pre = {}, open = {}, live = {}, seen = {}, started = false, locks = {} }
    ScanMine(fight, idx, pv, st)
    ScanCommon(idx, pv, st)
    ScanHp(idx, pv)
    HpMarks(pv)
    PickRows(pv)
    SortCasts(pv)
    for id, label in pairs(st.locks) do
        if label then pv.lockId, pv.lockLabel = id, label end
    end
    if pv.kbT and pv.at - pv.kbT > KILL_WINDOW then pv.kbT = nil end
    pv.ms = debugprofilestop() - p0
    return pv
end
local function KeyOf(who, at)
    return who .. "@" .. floor(at * 10 + 0.5)
end
function DP.Anchor(fight, who, at)
    local s = ns.Summary and ns.Summary.Get(fight)
    local p = s and s.byName and s.byName[who]
    local best
    for k = 1, #(p and p.deathInfo or {}) do
        local t = p.deathInfo[k].t
        if t >= at - DEATH_BACK and t <= at + DEATH_AHEAD and (not best or t < best) then best = t end
    end
    if best then return best, true end
    return at, false
end
function DP.Peek(fight, who, at)
    local list = cache[fight]
    return list and list[KeyOf(who, at)] or nil
end
local function Keep(fight, pv)
    local list = cache[fight]
    if not list then
        list = {}
        cache[fight] = list
    end
    list[KeyOf(pv.who, pv.at)] = pv
end
function DP.Request(fight, who, at, death, onDone)
    local ready = DP.Peek(fight, who, at)
    if ready then return onDone(ready) end
    ns.Index.Get(fight, function(idx)
        if not idx then return onDone(nil) end
        ns.Jobs.Run("prev:" .. KeyOf(who, at), function()
            local pv = DP.Peek(fight, who, at) or DP.Build(fight, idx, who, at, death)
            Keep(fight, pv)
            return pv
        end, onDone, "prev.data", true)
        DP.Warm(fight)
    end, true)
end
function DP.Warm(fight)
    if ns.Store.Bare(fight) then return end
    local key = warmKeys[fight]
    if not key then
        key = {}
        warmKeys[fight] = key
    end
    if warmed[fight] or ns.Jobs.Busy(key) or not ns.Index.Peek(fight) then return end
    ns.Summary.Compute(fight, function(s)
        ns.Index.Get(fight, function(idx)
            if not idx then return end
            ns.Jobs.Run(key, function()
                for i = 1, #s.players do
                    local p = s.players[i]
                    for d = 1, #p.deathInfo do
                        local t = p.deathInfo[d].t
                        if not DP.Peek(fight, p.name, t) then Keep(fight, DP.Build(fight, idx, p.name, t, true)) end
                    end
                end
                warmed[fight] = true
            end, function() DP.Scene(fight, function() end) end, "prev.data")
        end)
    end)
end
function DP.Reset()
    for k in pairs(cache) do cache[k] = nil end
    for k in pairs(warmed) do warmed[k] = nil end
    ns.Jobs.Cancel(SCENE_KEY)
    sceneFight, sceneReady = nil, nil
end
