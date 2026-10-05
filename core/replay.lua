local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local max = math.max
local min = math.min
local tsort = table.sort
local select = select
local strsub = string.sub
local strbyte = string.byte
local AREA_W = 1002
local AREA_H = 668
local RIM = 0.45
local STRIPS = 192
local ROWS = 48
local COLS_MAX = 8
local CELL_ERR = 0.8
local ROW_SCREEN = 24
local ROW_DEPTH = 24
local K_STEP = 0.06
local TEX_SAFE = 0.98
local Z_MIN = 0.15
local PERSP_MAX = 0.8
local FIT_SAMPLES = 32
local LERP_GAP = 1.5
local MEND_GAP = 0.5
local DEATH_SNAP = 1
local SNAP = 0.25
local BOSS_GAP = 3
local LEAD_HOLD = 10
local SOUL_HOLD = 2
local PLAN_STEP = 0.5
local PLAN_JOIN = 3
local PLAN_MIN = 3
local PRE_PULL = 5
local LOOK = 0.5
local MOVE_YPS = 1.5
local RUN_YPS = 4
local MELEE_YD = 10
local DEFAULT_PPY = 3
local HEIGHT_ZERO = 35
local HEIGHT_SKIP = 92
local HEIGHT_VOID = 126
local HEIGHT_MIN_W = 0.3
local FIT_LO = 0.01
local FIT_HI = 0.99
local FIT_PAD = 1.15
local OUT_K = 1.1
local OUT_SHARE = 0.1
local MIN_R = 60
local GRID_YD = 10
local SEEK_STEPS = 8
local JOB_KEY = {}
local rowY, rowL, rowR, rowN = {}, {}, {}, {}
local Replay = {}
ns.Replay = Replay
Replay.RIM = RIM
Replay.STRIPS = STRIPS
Replay.PERSP_MAX = PERSP_MAX
Replay.texOut = 0
Replay.RUN_YPS = RUN_YPS
Replay.MOVE_YPS = MOVE_YPS
Replay.ROOMS = {
    lanathel = { boss = ns.ENC.lanathel, floor = 6, tex = "lanathel", cx = 511, cy = 310, r = 160, pack = "ICC" },
    lichking = { boss = ns.ENC.lichking, floor = 7, tex = "lichking", cx = 500, cy = 349, r = 255, pack = "ICC",
                 alias = { [0] = { 41.601306, -28.455828, 41.601233, -27.249835 } } },
    marrowgar = { boss = ns.ENC.marrowgar, floor = 1, tex = "marrowgar", cx = 390, cy = 402, r = 66, pack = "ICC" },
    deathwhisper = { boss = ns.ENC.deathwhisper, floor = 1, tex = "deathwhisper", cx = 390, cy = 540, r = 66, pack = "ICC" },
    gunship = { boss = ns.ENC.gunship, floor = 2, tex = "gunship", cx = 625, cy = 318, r = 100 },
    deathbringer = { boss = ns.ENC.saurfang, floor = 3, tex = "deathbringer", cx = 520, cy = 300, r = 230, pack = "ICC" },
    festergut = { boss = ns.ENC.festergut, floor = 5, tex = "festergut", cx = 199, cy = 440, r = 48, pack = "ICC" },
    rotface = { boss = ns.ENC.rotface, floor = 5, tex = "rotface", cx = 199, cy = 270, r = 48, pack = "ICC" },
    putricide = { boss = ns.ENC.putricide, floor = 5, tex = "putricide", cx = 125, cy = 355, r = 52, pack = "ICC" },
    council = { boss = ns.ENC.council, floor = 5, tex = "council", cx = 518, cy = 95, r = 58, pack = "ICC" },
    valithria = { boss = ns.ENC.valithria, floor = 5, tex = "valithria", cx = 769, cy = 475, r = 85, pack = "ICC" },
    sindragosa = { boss = ns.ENC.sindragosa, floor = 4, tex = "sindragosa", cx = 365, cy = 115, r = 78, pack = "ICC" },
    frostmourne = { boss = ns.ENC.lichking, floor = 8, tex = "frostmourne", cx = 470, cy = 365, r = 130, pack = "ICC" },
    halion = { boss = ns.ENC.halion, floor = 0, tex = "halion", cx = 495, cy = 366, r = 80, pack = "RS" },
    leviathan = { boss = ns.ENC.leviathan, floor = 1, tex = "leviathan", cx = 493, cy = 276, r = 36 },
    razorscale = { boss = ns.ENC.razorscale, floor = 1, tex = "razorscale", cx = 537, cy = 175, r = 14 },
    ignis = { boss = ns.ENC.ignis, floor = 1, tex = "ignis", cx = 387, cy = 173, r = 14 },
    xt002 = { boss = ns.ENC.xt002, floor = 1, tex = "xt002", cx = 487, cy = 97, r = 13 },
    ironcouncil = { boss = ns.ENC.ironcouncil, floor = 2, tex = "ironcouncil", cx = 165, cy = 366, r = 70 },
    kologarn = { boss = ns.ENC.kologarn, floor = 2, tex = "kologarn", cx = 372, cy = 91, r = 48 },
    algalon = { boss = ns.ENC.algalon, floor = 2, tex = "algalon", cx = 796, cy = 307, r = 54 },
    hodir = { boss = ns.ENC.hodir, floor = 3, tex = "hodir", cx = 674, cy = 425, r = 21 },
    auriaya = { boss = ns.ENC.auriaya, floor = 3, tex = "auriaya", cx = 570, cy = 441, r = 25 },
    thorim = { boss = ns.ENC.thorim, floor = 3, tex = "thorim", cx = 691, cy = 322, r = 47 },
    freya = { boss = ns.ENC.freya, floor = 3, tex = "freya", cx = 521, cy = 160, r = 40 },
    vezax = { boss = ns.ENC.vezax, floor = 4, tex = "vezax", cx = 541, cy = 411, r = 68 },
    yogg = { boss = ns.ENC.yogg, floor = 4, tex = "yogg", cx = 694, cy = 294, r = 70 },
    mimiron = { boss = ns.ENC.mimiron, floor = 5, tex = "mimiron", cx = 439, cy = 271, r = 38 },
    tocBeasts = { boss = ns.ENC.beasts, floor = 1, tex = "toc_arena", cx = 505, cy = 356, r = 165, pack = "TOC" },
    tocJaraxxus = { boss = ns.ENC.jaraxxus, floor = 1, tex = "toc_arena", cx = 505, cy = 356, r = 165, pack = "TOC" },
    tocChampions = { boss = ns.ENC.champions, floor = 1, tex = "toc_arena", cx = 505, cy = 356, r = 165, pack = "TOC" },
    tocTwins = { boss = ns.ENC.twins, floor = 1, tex = "toc_arena", cx = 505, cy = 356, r = 165, pack = "TOC" },
    tocAnubarak = { boss = ns.ENC.anubarak, floor = 2, tex = "toc_anubarak", cx = 514, cy = 219, r = 85, pack = "TOC" },
}
function Replay.NpcOf(guid)
    if type(guid) ~= "string" or #guid < 12 or strsub(guid, 1, 2) ~= "0x" then return nil end
    local kind = tonumber(strsub(guid, 3, 5), 16)
    if not kind or (kind % 16 ~= 3 and kind % 16 ~= 5) then return nil end
    local id = tonumber(strsub(guid, 9, 12), 16)
    if id and id > 0 then return id end
    return nil
end
function Replay.ModelOf(boss)
    return ns.replayData.models[boss] or nil
end
local function PixelsPerYard(area, level)
    local byArea = area and ns.mapScale and ns.mapScale[area]
    local size = byArea and byArea[level]
    if not size or not size.w or size.w <= 0 then return DEFAULT_PPY end
    return AREA_W / size.w
end
Replay.PixelsPerYard = PixelsPerYard
function Replay.AreaOf(room)
    local known = ns.maps and ns.maps[room.boss]
    if known and known.area then return known.area end
    local tex = room.tex
    if strsub(tex, 1, 4) == "toc_" then return "TheArgentColiseum" end
    if tex == "halion" then return "TheRubySanctum" end
    if tex == "gunship" then return "IcecrownCitadel" end
    return "Ulduar"
end
Replay.calibLive = {}
function Replay.FixOf(room)
    local f = Replay.calibLive[room.tex]
    if not f then
        local db = ManaCodeRaidHelperDB
        local all = type(db) == "table" and db.calibFix
        f = type(all) == "table" and all[room.tex] or nil
    end
    if type(f) ~= "table" then f = room.fix end
    if type(f) ~= "table" then return nil end
    return f
end
function Replay.FixMatrix(room)
    local f = Replay.FixOf(room)
    if not f then return 1, 0, 0, 0 end
    local ppy = PixelsPerYard(Replay.AreaOf(room), room.floor)
    local k = tonumber(f.scale) or 1
    local a = (tonumber(f.rot) or 0) * math.pi / 180
    return k * cos(a), k * sin(a), (tonumber(f.dx) or 0) * ppy, (tonumber(f.dy) or 0) * ppy
end
function Replay.FixPoint(room, x, y)
    local c, s, dx, dy = Replay.FixMatrix(room)
    local u, v = x - room.cx, y - room.cy
    return room.cx + c * u - s * v + dx, room.cy + s * u + c * v + dy
end
function Replay.RoomOf(boss, level)
    for _, room in pairs(Replay.ROOMS) do
        if room.boss == boss and room.floor == level then return room end
    end
    return nil
end
function Replay.HasRoom(boss)
    for _, room in pairs(Replay.ROOMS) do
        if room.boss == boss then return true end
    end
    return false
end
local function HeightCell(hm, i, j)
    local row = hm.rows[j]
    if not row or i < 1 or i > hm.n then return nil end
    local b = strbyte(row, i)
    if not b or b == HEIGHT_VOID then return nil end
    if b > HEIGHT_SKIP then b = b - 1 end
    return hm.base + hm.q * (b - HEIGHT_ZERO)
end
function Replay.HeightAt(room, x, y)
    local hm = room and ns.roomHeight and ns.roomHeight[room.tex]
    if not hm then return nil end
    local n, span = hm.n, hm.side or room.r / RIM
    local gx = ((x - room.cx - (hm.ox or 0)) / span + 0.5) * n + 0.5
    local gy = ((y - room.cy - (hm.oy or 0)) / span + 0.5) * n + 0.5
    local i, j = floor(gx), floor(gy)
    local fx, fy = gx - i, gy - j
    local sum, weight = 0, 0
    for dj = 0, 1 do
        local wy = dj == 1 and fy or 1 - fy
        for di = 0, 1 do
            local w = (di == 1 and fx or 1 - fx) * wy
            local z = w > 0 and HeightCell(hm, i + di, j + dj)
            if z then
                sum = sum + w * z
                weight = weight + w
            end
        end
    end
    if weight < HEIGHT_MIN_W then return nil end
    return sum / weight
end
local function PickFloor(fight, frames)
    local count, area = {}, {}
    for i = 1, #frames do
        ns.Jobs.Step(4)
        local fr = frames[i]
        local n = 0
        for name, p in pairs(fr.units) do
            if fight.players[name] and not p.stale and (p.x > 0 or p.y > 0) then n = n + 1 end
        end
        count[fr.floor] = (count[fr.floor] or 0) + n
        area[fr.floor] = area[fr.floor] or fr.map
    end
    for _, room in pairs(Replay.ROOMS) do
        if room.boss == fight.boss and room.alias then
            for level in pairs(room.alias) do
                if count[level] then
                    count[room.floor] = (count[room.floor] or 0) + count[level]
                    area[room.floor] = area[room.floor] or area[level]
                    count[level] = nil
                end
            end
        end
    end
    local best, bestN = nil, -1
    for level, n in pairs(count) do
        local weight = n
        if Replay.RoomOf(fight.boss, level) then weight = weight * 4 end
        if weight > bestN then best, bestN = level, weight end
    end
    local known = ns.maps and ns.maps[fight.boss]
    local name = (known and known.area) or (best and area[best]) or nil
    return best or 0, name
end
local function NewTrack(name)
    return { name = name, class = ns.Encounters.ClassOf(name), n = 0,
             t = {}, x = {}, y = {}, hp = {}, dz = {}, old = {}, cur = 1, hx = 0, hy = 1 }
end
local function Push(tr, t, x, y, hp, dz, old)
    local n = tr.n + 1
    tr.n = n
    tr.t[n], tr.x[n], tr.y[n], tr.hp[n], tr.dz[n] = t, x, y, hp, dz
    if old then tr.old[n] = true end
end
local function Bisect(ts, n, t)
    if n == 0 or ts[1] > t then return 0 end
    local lo, hi = 1, n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if ts[mid] <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end
local function Seek(tr, t)
    local ts, n, cur = tr.t, tr.n, tr.cur
    if n == 0 or ts[1] > t then return 0 end
    if cur >= 1 and cur <= n and ts[cur] <= t then
        local steps = 0
        while cur < n and ts[cur + 1] <= t and steps < SEEK_STEPS do
            cur = cur + 1
            steps = steps + 1
        end
        if cur == n or ts[cur + 1] > t then
            tr.cur = cur
            return cur
        end
    end
    cur = Bisect(ts, n, t)
    tr.cur = cur
    return cur
end
local function PosAt(tr, i, t, hold)
    if i < 1 then return -1, -1 end
    local x0 = tr.x[i]
    if x0 < 0 then return -1, -1 end
    local y0 = tr.y[i]
    local t0 = tr.t[i]
    local j = i + 1
    if hold and t - t0 > hold then
        if j > tr.n or tr.t[j] - t0 > hold then return -1, -1 end
    end
    if j > tr.n then return x0, y0 end
    local x1 = tr.x[j]
    local t1 = tr.t[j]
    if x1 < 0 or t1 <= t0 then return x0, y0 end
    local from = t0
    if t1 - t0 > LERP_GAP then
        if hold then return x0, y0 end
        from = t1 - SNAP
        if t < from then return x0, y0 end
    end
    local k = (t - from) / (t1 - from)
    if k > 1 then k = 1 elseif k < 0 then k = 0 end
    return x0 + (x1 - x0) * k, y0 + (tr.y[j] - y0) * k
end
function Replay.PosAtTime(tr, t)
    return PosAt(tr, Bisect(tr.t, tr.n, t), t, nil)
end
function Replay.PosHold(tr, t, hold)
    return PosAt(tr, Seek(tr, t), t, hold)
end
function Replay.IndexAt(tr, t)
    return Bisect(tr.t, tr.n, t)
end
Replay.NewTrack = NewTrack
Replay.Push = Push
local function FillTracks(fight, frames, level, byName, tracks, deaths, alias)
    local lastRef, lastHp, lastX, lastY, deadAt, gapped = {}, {}, {}, {}, {}, {}
    local total = #frames
    for i = 1, total do
        ns.Jobs.Step(8)
        ns.Jobs.Progress(i, total)
        local fr = frames[i]
        local k = fr.floor ~= level and alias and alias[fr.floor] or nil
        local onFloor = fr.floor == level or k ~= nil
        for name, p in pairs(fr.units) do
            local tr = byName[name]
            if not tr and fight.players[name] then
                tr = NewTrack(name)
                byName[name] = tr
                tracks[#tracks + 1] = tr
            end
            local px, py = p.x, p.y
            local valid = onFloor and (px > 0 or py > 0)
            if valid and k then
                px, py = px * k[1] + k[2], py * k[3] + k[4]
                valid = px >= 0 and px <= 1 and py >= 0 and py <= 1
            end
            if tr and (lastRef[name] ~= p or valid == (gapped[name] or false)) then
                lastRef[name] = p
                local hp = p.hp or 0
                local top = p.max
                local pct = hp > 0 and (top and top > 0 and min(1, hp / top) or 1) or 0
                local x = valid and px * AREA_W or -1
                local y = valid and py * AREA_H or -1
                if hp == 0 and (lastHp[name] or 1) > 0 then
                    deadAt[name] = fr.t
                    local mx = valid and x or lastX[name]
                    local my = valid and y or lastY[name]
                    if mx then deaths[#deaths + 1] = { t = fr.t, x = mx, y = my, name = name } end
                elseif hp > 0 then
                    deadAt[name] = nil
                end
                lastHp[name] = hp
                if valid then lastX[name], lastY[name] = x, y end
                gapped[name] = not valid
                Push(tr, fr.t, x, y, pct, deadAt[name] or 0, valid and p.stale)
            end
        end
    end
end
local function Moved(tr, i)
    return tr.x[i] ~= tr.x[i - 1] or tr.y[i] ~= tr.y[i - 1]
end
local function Mend(tr)
    local X, Y, T, old = tr.x, tr.y, tr.t, tr.old
    local n, fixed = tr.n, 0
    local i = 3
    while i < n do
        if X[i] >= 0 and X[i - 1] >= 0 and X[i - 2] >= 0 and not old[i] and not Moved(tr, i) and Moved(tr, i - 1) then
            local j = i
            while j < n and X[j + 1] == X[i] and Y[j + 1] == Y[i] do j = j + 1 end
            local a, b = i - 1, j + 1
            if b <= n and X[b] >= 0 and not old[b] and T[b] - T[a] <= MEND_GAP and T[b] > T[a] then
                for m = i, j do
                    local k = (T[m] - T[a]) / (T[b] - T[a])
                    X[m], Y[m] = X[a] + (X[b] - X[a]) * k, Y[a] + (Y[b] - Y[a]) * k
                    fixed = fixed + 1
                end
            end
            i = j + 1
        else
            i = i + 1
        end
    end
    return fixed
end
local function MarkOrder(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.name < b.name
end
local function SnapOne(scene, tr, ts)
    local T, dz = tr.t, tr.dz
    local i = Bisect(T, tr.n, ts)
    if i >= 1 and dz[i] > 0 then return false end
    local j0, jd = i + 1, nil
    for j = j0, tr.n do
        if T[j] > ts + DEATH_SNAP then break end
        if dz[j] > 0 then
            jd = j
            break
        end
    end
    if not jd or T[jd] ~= dz[jd] then return false end
    local d0 = dz[jd]
    for m = j0, jd - 1 do dz[m] = ts end
    local m = jd
    while m <= tr.n and dz[m] == d0 do
        dz[m] = ts
        m = m + 1
    end
    T[j0] = ts
    local marks = scene.deaths
    for q = 1, #marks do
        if marks[q].name == tr.name and marks[q].t == d0 then marks[q].t = ts end
    end
    return true
end
function Replay.SnapDeaths(scene, ks, ts)
    local done = 0
    for i = 1, #ks do
        local tr = scene.tracks[ks[i]]
        if tr and SnapOne(scene, tr, ts[i]) then done = done + 1 end
    end
    if done > 0 then tsort(scene.deaths, MarkOrder) end
    scene.snapped = done
    return done
end
local function FillGaps(scene, frames)
    local ts, kinds, since, floors = {}, {}, {}, {}
    local n, prev, prevFloor = 0, false, nil
    local level = scene.floor
    local alias = scene.room and scene.room.alias or {}
    for i = 1, #frames do
        ns.Jobs.Step(8)
        local fr = frames[i]
        local kind = false
        if fr.lost then
            kind = "lost"
        elseif fr.floor ~= level and not alias[fr.floor] then
            kind = "away"
        end
        if kind ~= prev or (kind == "away" and fr.floor ~= prevFloor) then
            n = n + 1
            ts[n], kinds[n], since[n], floors[n] = fr.t, kind, fr.lost or fr.t, fr.floor
            prev, prevFloor = kind, fr.floor
        end
    end
    scene.gapT, scene.gapKind, scene.gapSince, scene.gapFloor = ts, kinds, since, floors
end
function Replay.GapAt(scene, t)
    local ts = scene.gapT
    local i = ts and Bisect(ts, #ts, t) or 0
    if i < 1 or not scene.gapKind[i] then return nil, 0, 0 end
    return scene.gapKind[i], scene.gapSince[i], scene.gapFloor[i]
end
local function FillBoss(frames, level)
    local tr, name = nil, nil
    for i = 1, #frames do
        ns.Jobs.Step(2)
        local fr = frames[i]
        local list = fr.floor == level and fr.npcs
        if list then
            for k = 1, #list do
                local npc = list[k]
                if npc.boss then
                    tr = tr or NewTrack(npc.name)
                    name = name or npc.name
                    Push(tr, fr.t, npc.x * AREA_W, npc.y * AREA_H, 1, 0)
                    break
                end
            end
        end
    end
    return tr, name
end
local function Pick(list, k)
    local n = #list
    if n == 0 then return 0 end
    return list[max(1, min(n, floor((n - 1) * k + 1.5)))]
end
local function FitCircle(scene)
    local room = scene.room
    if room then
        scene.cx, scene.cy, scene.r = room.cx, room.cy, room.r
        local out, all = 0, 0
        local l, r, t, b = room.cx - room.r, room.cx + room.r, room.cy - room.r, room.cy + room.r
        local tracks = scene.tracks
        for k = 1, #tracks do
            local tr = tracks[k]
            for i = 1, tr.n, 4 do
                ns.Jobs.Step()
                local x, y = tr.x[i], tr.y[i]
                if x >= 0 then
                    all = all + 1
                    local dx, dy = x - room.cx, y - room.cy
                    if dx * dx + dy * dy > room.r * room.r * OUT_K then
                        out = out + 1
                        if x < l then l = x elseif x > r then r = x end
                        if y < t then t = y elseif y > b then b = y end
                    end
                end
            end
        end
        if all > 0 and out >= all * OUT_SHARE then
            scene.cx, scene.cy = (l + r) / 2, (t + b) / 2
            scene.r = sqrt((r - l) * (r - l) + (b - t) * (b - t)) / 2
        end
        return
    end
    local xs, ys = {}, {}
    local tracks = scene.tracks
    for k = 1, #tracks do
        local tr = tracks[k]
        for i = 1, tr.n do
            ns.Jobs.Step()
            if tr.x[i] >= 0 then
                xs[#xs + 1] = tr.x[i]
                ys[#ys + 1] = tr.y[i]
            end
        end
    end
    if #xs == 0 then
        scene.cx, scene.cy, scene.r = AREA_W / 2, AREA_H / 2, MIN_R
        return
    end
    tsort(xs)
    ns.Jobs.Yield()
    tsort(ys)
    ns.Jobs.Yield()
    local l, r = Pick(xs, FIT_LO), Pick(xs, FIT_HI)
    local t, b = Pick(ys, FIT_LO), Pick(ys, FIT_HI)
    scene.cx, scene.cy = (l + r) / 2, (t + b) / 2
    local half = sqrt((r - l) * (r - l) + (b - t) * (b - t)) / 2
    scene.r = max(MIN_R, half * FIT_PAD, scene.ppy * 15)
end
local function FillGrid(scene)
    local gx, gy = {}, {}
    local step = GRID_YD * scene.ppy
    local r = scene.r
    local n = floor(r / step)
    for i = -n, n do
        for j = -n, n do
            local dx, dy = i * step, j * step
            if dx * dx + dy * dy <= r * r then
                gx[#gx + 1] = scene.cx + dx
                gy[#gy + 1] = scene.cy + dy
            end
        end
    end
    local ring = 48
    for k = 1, ring do
        local a = k / ring * 2 * math.pi
        gx[#gx + 1] = scene.cx + cos(a) * r
        gy[#gy + 1] = scene.cy + sin(a) * r
    end
    scene.gx, scene.gy = gx, gy
end
local CLASS_ORDER = {
    WARRIOR = 1, DEATHKNIGHT = 2, PALADIN = 3, DRUID = 4, SHAMAN = 5,
    PRIEST = 6, ROGUE = 7, HUNTER = 8, MAGE = 9, WARLOCK = 10,
}
local function TrackOrder(a, b)
    local ca = a.class and CLASS_ORDER[a.class] or 99
    local cb = b.class and CLASS_ORDER[b.class] or 99
    if ca ~= cb then return ca < cb end
    return a.name < b.name
end
local function NewState()
    return { vis = false, stale = false, x = 0, y = 0, hx = 0, hy = 1, speed = 0, dead = false, deadFor = 0, hp = 1 }
end
local function FirstSeen(fight, frames)
    local lo, first = fight.from - PRE_PULL, fight.from
    for i = 1, #frames do
        local fr = frames[i]
        if fr.t >= lo and fr.t < first then
            for _, p in pairs(fr.units) do
                if p.x > 0 or p.y > 0 then
                    first = fr.t
                    break
                end
            end
        end
    end
    return first
end
local function FillAlt(fight, frames, scene)
    local room
    for _, r in pairs(Replay.ROOMS) do
        if r.boss == fight.boss and r.floor ~= scene.floor then room = r end
    end
    if not room then return nil end
    local byName, on, lastHp, deadAt, lastX, lastY = {}, {}, {}, {}, {}, {}
    local deaths, n = {}, 0
    for i = 1, #frames do
        ns.Jobs.Step(8)
        local fr = frames[i]
        local here = fr.floor == room.floor
        for name, p in pairs(fr.units) do
            if fight.players[name] then
                local hp = p.hp or 0
                local valid = here and not p.stale and (p.x > 0 or p.y > 0)
                local x = valid and p.x * AREA_W or -1
                local y = valid and p.y * AREA_H or -1
                if hp == 0 and (lastHp[name] or 1) > 0 then
                    deadAt[name] = fr.t
                    local mx = valid and x or (on[name] and lastX[name])
                    if mx then deaths[#deaths + 1] = { t = fr.t, x = mx, y = valid and y or lastY[name], name = name } end
                elseif hp > 0 then
                    deadAt[name] = nil
                end
                lastHp[name] = hp
                if valid or on[name] then
                    local tr = byName[name]
                    if not tr then
                        tr = NewTrack(name)
                        byName[name] = tr
                    end
                    local top = p.max
                    local pct = hp > 0 and (top and top > 0 and min(1, hp / top) or 1) or 0
                    Push(tr, fr.t, x, y, pct, deadAt[name] or 0)
                    if valid then
                        n = n + 1
                        lastX[name], lastY[name] = x, y
                    end
                    on[name] = valid
                end
            end
        end
    end
    local alt = {
        fight = fight, from = scene.from, pull = scene.pull, to = scene.to, area = scene.area, floor = room.floor,
        room = room, ppy = PixelsPerYard(scene.area, room.floor), tracks = {}, states = {}, deaths = deaths,
        bossState = NewState(), base = scene, byName = {}, n = n, mended = 0,
    }
    for k = 1, #scene.tracks do
        local name = scene.tracks[k].name
        alt.tracks[k] = byName[name] or NewTrack(name)
        alt.states[k] = NewState()
        alt.byName[name] = k
    end
    FillGaps(alt, frames)
    FitCircle(alt)
    FillGrid(alt)
    return alt
end
function Replay.Build(fight, frames)
    ns.Jobs.Band(0, 0.1)
    local level, area = PickFloor(fight, frames)
    local scene = {
        fight = fight, from = FirstSeen(fight, frames), pull = fight.from, to = fight.to, area = area, floor = level,
        room = Replay.RoomOf(fight.boss, level), ppy = PixelsPerYard(area, level),
        tracks = {}, states = {}, deaths = {}, bossState = NewState(),
    }
    ns.Jobs.Band(0.1, 0.6)
    FillTracks(fight, frames, level, {}, scene.tracks, scene.deaths, scene.room and scene.room.alias)
    local mended = 0
    for k = 1, #scene.tracks do mended = mended + Mend(scene.tracks[k]) end
    scene.mended = mended
    FillGaps(scene, frames)
    tsort(scene.tracks, TrackOrder)
    for k = 1, #scene.tracks do scene.states[k] = NewState() end
    ns.Jobs.Band(0.6, 0.7)
    scene.boss, scene.bossName = FillBoss(frames, level)
    FitCircle(scene)
    FillGrid(scene)
    scene.alt = FillAlt(fight, frames, scene)
    return scene
end
local function SampleOne(st, tr, t, ppy, boss, lead)
    local i = Seek(tr, t)
    if i == 0 and lead and tr.n > 0 and tr.t[1] - t <= LEAD_HOLD then i = 1 end
    local x, y = PosAt(tr, i, t, nil)
    if x < 0 then
        st.vis = false
        return
    end
    st.vis = true
    st.x, st.y = x, y
    local dz = tr.dz[i]
    st.dead = dz > 0
    st.deadFor = dz > 0 and (t - dz) or 0
    st.hp = i > 0 and tr.hp[i] or 1
    st.stale = tr.old[i] == true
    if st.stale then
        st.speed = 0
        st.hx, st.hy = tr.hx, tr.hy
        return
    end
    local back = i
    local want = t - LOOK
    while back > 1 and tr.t[back] > want do back = back - 1 end
    local x0, y0 = PosAt(tr, back, want, nil)
    st.speed = 0
    if x0 >= 0 then
        local dx, dy = x - x0, y - y0
        local d = sqrt(dx * dx + dy * dy)
        st.speed = d / ppy / LOOK
        if st.speed >= MOVE_YPS and not st.dead then
            tr.hx, tr.hy = dx / d, dy / d
        elseif boss.vis and not st.dead then
            local bx, by = boss.x - x, boss.y - y
            local bd = sqrt(bx * bx + by * by)
            if bd > ppy * 0.5 and bd <= ppy * MELEE_YD then
                tr.hx, tr.hy = bx / bd, by / bd
            end
        end
    end
    st.hx, st.hy = tr.hx, tr.hy
end
local function SampleBoss(scene, t)
    local st, tr = scene.bossState, scene.boss
    local hp = scene.layers and ns.ReplayLayers.BossHp(scene, t)
    st.hp, st.hpOk = hp or 1, hp ~= nil
    if not tr then
        st.vis = false
        return
    end
    local i = Seek(tr, t)
    local x, y = PosAt(tr, i, t, BOSS_GAP)
    st.vis = x >= 0
    st.x, st.y = x, y
    local fx = tr.fx and i > 0 and tr.fx[i]
    if fx and (fx ~= 0 or tr.fy[i] ~= 0) then st.hx, st.hy = fx, tr.fy[i] end
end
function Replay.Sample(scene, t)
    SampleBoss(scene, t)
    local boss = scene.bossState
    local tracks, states, ppy = scene.tracks, scene.states, scene.ppy
    local shown = 0
    local nearD, nearK = nil, nil
    local lead = scene.base == nil
    for k = 1, #tracks do
        local st = states[k]
        SampleOne(st, tracks[k], t, ppy, boss, lead)
        if st.vis then
            shown = shown + 1
            if boss.vis and not st.dead then
                local dx, dy = st.x - boss.x, st.y - boss.y
                local d = dx * dx + dy * dy
                if not nearD or d < nearD then nearD, nearK = d, k end
            end
        end
    end
    if boss.vis and nearK and nearD > 0 and not (scene.boss and scene.boss.fx) then
        local d = sqrt(nearD)
        boss.hx, boss.hy = (states[nearK].x - boss.x) / d, (states[nearK].y - boss.y) / d
    end
    return shown
end
local function InWave(scene, name, t)
    local souls = scene.layers and scene.layers.souls
    local waves = souls and souls.waves
    for w = 1, waves and #waves or 0 do
        local wave = waves[w]
        if wave.from > t then break end
        if t < wave.to then
            for i = 1, #wave.spans do
                local s = wave.spans[i]
                if s.name == name and s.from <= t and (t < s.to or s.died) then return true end
            end
        end
    end
    return false
end
local function OnAlt(tr, t)
    return tr ~= nil and tr.n > 0 and PosAt(tr, Seek(tr, t), t, SOUL_HOLD) >= 0
end
function Replay.Inside(scene, t, inside, list)
    for k in pairs(inside) do inside[k] = nil end
    for i = #list, 1, -1 do list[i] = nil end
    local souls = scene.layers and scene.layers.souls
    local waves = souls and souls.waves
    for w = 1, waves and #waves or 0 do
        local wave = waves[w]
        if wave.from > t then break end
        if t < wave.to then
            for i = 1, #wave.spans do
                local s = wave.spans[i]
                if s.from <= t and (t < s.to or s.died) and not inside[s.name] then
                    inside[s.name] = true
                    list[#list + 1] = s.name
                end
            end
        end
    end
    local alt = scene.alt
    for k = 1, alt and #alt.tracks or 0 do
        local tr = alt.tracks[k]
        if not inside[tr.name] and OnAlt(tr, t) then
            inside[tr.name] = true
            list[#list + 1] = tr.name
        end
    end
    tsort(list)
    return #list
end
function Replay.InsideOne(scene, name, t)
    if InWave(scene, name, t) then return true end
    local alt = scene.alt
    local k = alt and alt.byName[name]
    return k ~= nil and OnAlt(alt.tracks[k], t)
end
function Replay.Plan(scene)
    if scene.plan then return scene.plan end
    local raw, out = {}, {}
    scene.plan = out
    if not scene.alt then return out end
    local inside, list, on = {}, {}, false
    local tracks = scene.tracks
    local t = scene.from
    while t <= scene.to do
        Replay.Inside(scene, t, inside, list)
        local alive, inAlive = 0, 0
        for k = 1, #tracks do
            local tr = tracks[k]
            local i = Bisect(tr.t, tr.n, t)
            if not (i > 0 and tr.dz[i] > 0) then
                alive = alive + 1
                if inside[tr.name] then inAlive = inAlive + 1 end
            end
        end
        local want = inAlive * 2 > alive
        if want ~= on then
            raw[#raw + 1] = t
            on = want
        end
        t = t + PLAN_STEP
    end
    if on then raw[#raw + 1] = scene.to + PLAN_STEP end
    local joined = {}
    for i = 1, #raw - 1, 2 do
        local n = #joined
        if n > 0 and raw[i] - joined[n] < PLAN_JOIN then
            joined[n] = raw[i + 1]
        else
            joined[n + 1], joined[n + 2] = raw[i], raw[i + 1]
        end
    end
    for i = 1, #joined - 1, 2 do
        if joined[i + 1] - joined[i] >= PLAN_MIN then
            local n = #out
            out[n + 1], out[n + 2] = joined[i], joined[i + 1]
        end
    end
    return out
end
function Replay.AltAt(scene, t)
    local plan = scene.plan
    local n = plan and #plan or 0
    if n == 0 then return false end
    return Bisect(plan, n, t) % 2 == 1
end
function Replay.Prep(scene)
    local alt = scene.alt
    if not alt then return end
    local L = scene.layers
    if L and alt.layers == nil then
        local over = { np = 0, nh = 0, nb = 0, nc = 0, adds = {}, hitbox = 0 }
        if L.chase ~= nil then over.chase = false end
        if L.spread ~= nil then over.spread = false end
        alt.layers = setmetatable(over, { __index = L })
    end
    Replay.Plan(scene)
end
function Replay.Aim(cam)
    cam.c, cam.s = cos(cam.angle), sin(cam.angle)
    local t = cam.tilt
    cam.a = cam.persp * sqrt(max(0, 1 - t * t)) / max(1, cam.r)
end
function Replay.Project(cam, x, y)
    local dx, dy = x - cam.cx, y - cam.cy
    local c, s = cam.c, cam.s
    local ry = dx * s + dy * c
    local z = 1 - cam.a * ry
    if z < Z_MIN then return 0, 0, 0 end
    local k = 1 / z
    return (dx * c - dy * s) * cam.zoom * k, (ry * cam.tilt * k - cam.lift) * cam.zoom, k
end
function Replay.Unproject(cam, sx, sy)
    local t = cam.tilt
    local v = sy / cam.zoom + cam.lift
    local den = t + cam.a * v
    if den <= 0 or den * Z_MIN > t then return cam.cx, cam.cy, 0 end
    local k = den / t
    local rx = sx / (cam.zoom * k)
    local ry = v / den
    local c, s = cam.c, cam.s
    return cam.cx + rx * c + ry * s, cam.cy - rx * s + ry * c, k
end
function Replay.Facing(cam, hx, hy)
    local c, s = cam.c, cam.s
    return atan2(hx * c - hy * s, hx * s + hy * c)
end
function Replay.North(cam)
    return atan2(cam.s, cam.c * cam.tilt)
end
function Replay.Frame(cam)
    Replay.Aim(cam)
    local r, a, t = cam.r, cam.a, cam.tilt
    local top = -r * t / (1 + a * r)
    local bottom = r * t / (1 - a * r)
    local half = r
    for i = 1, FIT_SAMPLES do
        local ry = r * (2 * i / FIT_SAMPLES - 1)
        local w = sqrt(max(0, r * r - ry * ry)) / (1 - a * ry)
        if w > half then half = w end
    end
    cam.lift = (top + bottom) / 2
    return min(cam.w * 0.94 / (2 * half), cam.h * 0.92 / max(1e-6, bottom - top))
end
function Replay.Fit(cam, scene)
    cam.cx, cam.cy = scene.cx, scene.cy
    cam.r = max(1, scene.r)
    cam.zoom = Replay.Frame(cam)
end
local function ScreenY(cam, ry)
    return (ry * cam.tilt / (1 - cam.a * ry) - cam.lift) * cam.zoom
end
local function DepthAt(cam, sy)
    local v = sy / cam.zoom + cam.lift
    return v / (cam.tilt + cam.a * v)
end
local function Chord(r, d)
    local q = r * r - d * d
    if q <= 0 then return 0 end
    return sqrt(q)
end
local fixC, fixS, fixX, fixY = 1, 0, 0, 0
local function Corner(cam, room, span, x, ry, k, st, slot)
    local rx = x / (cam.zoom * k)
    local c, s = cam.c, cam.s
    local px = cam.cx + rx * c + ry * s - room.cx
    local py = cam.cy - rx * s + ry * c - room.cy
    local u = (fixC * px - fixS * py + fixX) / span + 0.5
    local v = (fixS * px + fixC * py + fixY) / span + 0.5
    if u < 0 or u > 1 or v < 0 or v > 1 then
        Replay.texOut = Replay.texOut + 1
        u, v = min(1, max(0, u)), min(1, max(0, v))
    end
    st[slot], st[slot + 1] = u, v
end
local function RowSpan(cam, r, span, ex, ey, ra, rb)
    local a, zoom = cam.a, cam.zoom
    local rm = min(max(ey, ra), rb)
    local ka, kb, km = 1 / (1 - a * ra), 1 / (1 - a * rb), 1 / (1 - a * rm)
    local ha, hb, hm = Chord(r, ra - ey), Chord(r, rb - ey), Chord(r, rm - ey)
    local xl = min((ex - ha) * ka, (ex - hb) * kb, (ex - hm) * km) * zoom
    local xr = max((ex + ha) * ka, (ex + hb) * kb, (ex + hm) * km) * zoom
    local safe = span * 0.5 * TEX_SAFE
    local sa, sb = Chord(safe, ra - ey), Chord(safe, rb - ey)
    local hw = cam.w / 2
    xl = max(floor(max(xl, -hw)), ceil(max((ex - sa) * ka, (ex - sb) * kb) * zoom))
    xr = min(ceil(min(xr, hw)), floor(min((ex + sa) * ka, (ex + sb) * kb) * zoom))
    return xl, xr
end
local function Slot(out, i)
    local st = out[i]
    if not st then
        st = {}
        out[i] = st
    end
    return st
end
local function PlanRows(cam, room, ex, ey, top, bottom, near)
    local r, a = room.r, cam.a
    local span = r / RIM
    local stepY = max(1, ceil((bottom - top) / ROW_SCREEN))
    local stepR = 2 * r / ROW_DEPTH
    local rows, need, ya = 0, 0, top
    while ya < bottom and rows < ROWS do
        rows = rows + 1
        local yb = bottom
        local ra = DepthAt(cam, ya)
        if rows < ROWS then
            local step = stepR
            if a > 0 then step = min(step, (1 - a * ra) * K_STEP / a) end
            yb = min(bottom, ya + stepY, floor(ScreenY(cam, min(near, ra + step))))
            if yb <= ya then yb = ya + 1 end
        end
        local rb = DepthAt(cam, yb)
        local ka, kb = 1 / (1 - a * ra), 1 / (1 - a * rb)
        local xl, xr = RowSpan(cam, r, span, ex, ey, ra, rb)
        local n = 0
        if xr > xl then
            n = max(1, min(COLS_MAX, ceil((xr - xl) * (kb - ka) / ((ka + kb) * CELL_ERR))))
        end
        rowY[rows], rowL[rows], rowR[rows], rowN[rows] = ya, xl, xr, n
        need = need + n
        ya = yb
    end
    rowY[rows + 1] = ya
    return rows, need
end
function Replay.Strips(cam, room, out)
    local r, a = room.r, cam.a
    local dx, dy = room.cx - cam.cx, room.cy - cam.cy
    local ex = dx * cam.c - dy * cam.s
    local ey = dx * cam.s + dy * cam.c
    local far, near = ey - r, ey + r
    if a > 0 then near = min(near, (1 - Z_MIN) / a) end
    if near <= far or cam.zoom <= 0 or cam.tilt <= 0 then return 0 end
    local hh = cam.h / 2
    local top = max(ceil(ScreenY(cam, far)), -hh)
    local bottom = min(floor(ScreenY(cam, near)), hh)
    if bottom - top < 1 then return 0 end
    local rows, need = PlanRows(cam, room, ex, ey, top, bottom, near)
    local fit = 1
    if need > STRIPS then fit = (STRIPS - rows) / max(1, need - rows) end
    local span = r / RIM
    fixC, fixS, fixX, fixY = Replay.FixMatrix(room)
    local used = 0
    for i = 1, rows do
        local n, xl, xr = rowN[i], rowL[i], rowR[i]
        if n > 0 then
            n = 1 + floor((n - 1) * fit)
            local ya, yb = rowY[i], rowY[i + 1]
            local ra, rb = DepthAt(cam, ya), DepthAt(cam, yb)
            local ka, kb = 1 / (1 - a * ra), 1 / (1 - a * rb)
            local x0 = xl
            for j = 1, n do
                local x1 = j == n and xr or floor(xl + (xr - xl) * j / n + 0.5)
                if x1 > x0 and used < STRIPS then
                    used = used + 1
                    local st = Slot(out, used)
                    st.l, st.t, st.w, st.h = x0, ya, x1 - x0, yb - ya
                    Corner(cam, room, span, x0, ra, ka, st, 1)
                    Corner(cam, room, span, x0, rb, kb, st, 3)
                    Corner(cam, room, span, x1, ra, ka, st, 5)
                    Corner(cam, room, span, x1, rb, kb, st, 7)
                    x0 = x1
                end
            end
        end
    end
    return used
end
function Replay.Load(fight, onDone)
    ns.Jobs.Cancel(JOB_KEY)
    ns.Encounters.Positions(fight, function(frames)
        if not frames or #frames == 0 then
            onDone(nil)
            return
        end
        ns.Jobs.Run(JOB_KEY, function()
            ns.Jobs.Label("job.replay")
            local scene = Replay.Build(fight, frames)
            ns.Jobs.Band(0.7, 1)
            if ns.ReplayLayers then ns.ReplayLayers.Build(scene) end
            return scene
        end, onDone, "iso.data", true)
    end)
end
function Replay.Cancel()
    ns.Jobs.Cancel(JOB_KEY)
end
