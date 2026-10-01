local _, ns = ...
local max = math.max
local min = math.min
local abs = math.abs
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local atan2 = math.atan2
local pi = math.pi
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ADD_POOL = 6
local LOAD_WAIT = 3
local HOLD = 1.5
local BOSS_MIN = 64
local BOSS_MAX = 160
local BOSS_VIEW = 0.38
local ADD_MIN = 30
local ADD_MAX = 80
local ADD_YD = 2.5
local BOSS_YD = 4
local ASPECT_MIN = 0.7
local ASPECT_MAX = 1.5
local SHADOW_K = 0.7
local EDGE = 2
local FIT_MIN = 0.6
local TURN_RATE = 2.5
local TURN_DEAD = 0.15
local SNAP_T = 1
local FACE_EPS = 0.02
local STEP = 0.5
local WALK_ON = 3
local WALK_YPS = 2.5
local STOP_YPS = 1.2
local DWELL = 2
local GRACE = 0.3
local FADE = 0.25
local SWING_SHOW = 0.7
local CAST_MIN = 1.5
local ADD_HOLD = 4
local DEATH_END = 40
local DEATH_LEAD = 2.5
local SEQ_STAND = 0
local SEQ_DEATH = 1
local SEQ_WALK = 4
local SEQ_RUN = 5
local ATTACKS = { 17, 18, 16 }
local CASTS = { 53, 54 }
local MODES = { off = true, boss = true, all = true }
local DEFAULT_MODE = "boss"
local ANIMS = { calm = true, full = true }
local DEFAULT_ANIM = "calm"
local M = {}
ns.ReplayModels = M
local Replay = ns.Replay
local Kit = ns.Kit
local slots = {}
local drawn = {}
local holder, view
local base = 0
local scene
local bossSrc = {}
local warned = false
local stats = { models = 0, wait = 0, bad = 0 }
M.stats = stats
M.BOSS_MAX = BOSS_MAX
M.BOSS_VIEW = BOSS_VIEW
M.camIndex = nil
M.pos = nil
M.fit = 1
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function M.Mode()
    local v = Saved().models3d
    if MODES[v] then return v end
    return DEFAULT_MODE
end
function M.SetMode(v)
    if not MODES[v] then return end
    Saved().models3d = v
    if M.onChange then M.onChange(v) end
end
function M.Anim()
    local v = Saved().modelAnim
    if ANIMS[v] then return v end
    return DEFAULT_ANIM
end
function M.SetAnim(v)
    if not ANIMS[v] then return end
    Saved().modelAnim = v
end
local function Len(def, seq)
    return def and def.seq and def.seq[seq]
end
local function PickSeq(def, list)
    if not def or not def.seq then return nil end
    for i = 1, #list do
        if def.seq[list[i]] then return list[i] end
    end
    return nil
end
local function Last(ts, n, t)
    if n == 0 or ts[1] > t then return 0 end
    local lo, hi = 1, n
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if ts[mid] <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end
local function ModelPath(slot)
    local ok, p = pcall(slot.m.GetModel, slot.m)
    if ok and type(p) == "string" and p ~= "" then return p end
    return nil
end
local function Loaded(slot)
    slot.state, slot.hold = "ok", HOLD
    slot.facing, slot.seq, slot.ms = nil, nil, nil
end
local function Start(slot, i)
    local m = slot.m
    local s = slot.src and slot.src[i]
    slot.si = i
    slot.on, slot.alpha, slot.off = false, 0, 0
    m:SetAlpha(0)
    slot.shadow:Hide()
    if not s then
        slot.state = "bad"
        return
    end
    local key = s.kind .. ":" .. tostring(s.v)
    local have = ModelPath(slot)
    if key == slot.key and have and s.from ~= "retry" then
        slot.path = have
        return Loaded(slot)
    end
    slot.facing, slot.path = nil, nil
    slot.stale = key ~= slot.key and have or nil
    slot.key = key
    if m.ClearModel then pcall(m.ClearModel, m) end
    local ok = pcall(s.kind == "npc" and m.SetCreature or m.SetModel, m, s.v)
    if not ok then return Start(slot, i + 1) end
    slot.state, slot.wait = "wait", LOAD_WAIT
end
local function OnShowModel(self)
    local slot = self.slot
    if slot and slot.src then Start(slot, slot.si) end
end
local function NewSlot(i)
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, holder)
    if not ok or not m or not m.SetCreature or not m.SetSequenceTime or not m.SetSequence or not m.SetFacing then
        return nil
    end
    m:EnableMouse(false)
    m:Hide()
    local shadow = holder:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(CIRCLE)
    Kit.Tint(shadow, "sem.rep.drop")
    shadow:Hide()
    local slot = { m = m, shadow = shadow, boss = i == 1, si = 1, state = "idle", wait = 0, hold = 0, yd = BOSS_YD,
                   aspect = 1, lastT = -1e9, w = 0, h = 0, sx = 0, sy = 0, on = false, alpha = 0, off = 0, level = 0 }
    m.slot = slot
    m:SetScript("OnShow", OnShowModel)
    return slot
end
function M.Build(v, level)
    view = v
    holder = CreateFrame("Frame", nil, v)
    holder:SetAllPoints(v)
    holder:SetFrameLevel(level)
    base = level + 1
    for i = 1, ADD_POOL + 1 do
        local slot = NewSlot(i)
        if not slot then break end
        slots[i] = slot
    end
    M.ready = slots[1] ~= nil
end
function M.Levels()
    return ADD_POOL + 3
end
local function Release(slot)
    if slot.owner then slot.owner.mdl, slot.owner.mdlOwn = nil, nil end
    slot.owner, slot.src, slot.def, slot.path = nil, nil, nil, nil
    slot.state, slot.on, slot.head, slot.walk, slot.mt = "idle", false, nil, nil, nil
    slot.m:Hide()
    slot.shadow:Hide()
end
local function Assign(slot, owner, src, def, yd, aspect)
    slot.owner, slot.src, slot.def, slot.si = owner, src, def, 1
    slot.yd, slot.aspect, slot.head, slot.lastT = yd, aspect, nil, -1e9
    slot.walk, slot.mt, slot.since = nil, nil, nil
    if slot.m:IsShown() then
        Start(slot, 1)
    else
        slot.m:Show()
    end
end
local function AddRetry(list)
    local first = list[1]
    if first and first.kind == "npc" then list[#list + 1] = { kind = "npc", v = first.v, from = "retry" } end
end
function M.Use(sc)
    scene = sc
    for i = 1, #slots do Release(slots[i]) end
    for k in pairs(bossSrc) do bossSrc[k] = nil end
    if not sc then return end
    local def = Replay.ModelOf(sc.fight.boss)
    local L = sc.layers
    local g = L and L.bossNpc
    if g then bossSrc[#bossSrc + 1] = { kind = "npc", v = g, from = "guid" } end
    if def and def.npc and def.npc ~= g then bossSrc[#bossSrc + 1] = { kind = "npc", v = def.npc, from = "data" } end
    if def and def.m2 then bossSrc[#bossSrc + 1] = { kind = "m2", v = def.m2, from = "m2" } end
    AddRetry(bossSrc)
end
local function Load(slot, elapsed)
    if slot.state == "wait" then
        local p = ModelPath(slot)
        slot.wait = slot.wait - elapsed
        if p and (p ~= slot.stale or (slot.wait <= 0 and not slot.boss)) then
            slot.path = p
            Loaded(slot)
        elseif slot.wait <= 0 then
            Start(slot, slot.si + 1)
        end
    elseif slot.state == "ok" and slot.hold > 0 then
        slot.hold = slot.hold - elapsed
        if slot.hold <= 0 then slot.hold, slot.facing, slot.seq, slot.ms = 0, nil, nil, nil end
    end
end
local function Heading(slot, hx, hy, t, elapsed)
    local want = atan2(hy, hx)
    local head = slot.head
    if not head or abs(t - slot.lastT) > SNAP_T then
        head = want
    else
        local d = (want - head + pi) % (2 * pi) - pi
        if abs(d) > TURN_DEAD then
            local step = TURN_RATE * elapsed
            head = head + Clamp(d, -step, step)
        end
    end
    slot.head, slot.lastT = head, t
    return head
end
local function Speed(tr, t0, t1, ppy, hold)
    local x1, y1, x0, y0
    if hold then
        x1, y1 = Replay.PosHold(tr, t1, hold)
        x0, y0 = Replay.PosHold(tr, t0, hold)
    else
        x1, y1 = Replay.PosAtTime(tr, t1)
        x0, y0 = Replay.PosAtTime(tr, t0)
    end
    if x1 < 0 or x0 < 0 then return 0, 0, 0 end
    local dx, dy = x1 - x0, y1 - y0
    return sqrt(dx * dx + dy * dy) / ppy / (t1 - t0), dx, dy
end
local function Walk(slot, tr, t, hold)
    local fresh = not slot.mt or abs(t - slot.mt) > SNAP_T
    local paused = slot.mt == t
    slot.mt = t
    if not tr then
        slot.walk = nil
        return nil
    end
    if paused then return nil end
    if fresh then slot.since = nil end
    if slot.since and t - slot.since < DWELL then return slot.walk end
    local ppy, move = scene.ppy, Replay.MOVE_YPS
    local net = Speed(tr, t - STEP * WALK_ON, t, ppy, hold)
    local was = slot.walk
    if was and not fresh then
        if net < STOP_YPS then slot.walk = nil end
    else
        slot.walk = nil
        local steady = net >= WALK_YPS
        for k = 0, WALK_ON - 1 do
            if not steady then break end
            steady = Speed(tr, t - STEP * (k + 1), t - STEP * k, ppy, hold) >= move
        end
        local def = slot.def
        if steady and net >= Replay.RUN_YPS and Len(def, SEQ_RUN) then
            slot.walk = SEQ_RUN
        elseif steady and (Len(def, SEQ_WALK) or not (def and def.seq)) then
            slot.walk = SEQ_WALK
        end
    end
    if slot.walk ~= was then slot.since = t end
    return slot.walk
end
local function BossMotion(slot, sc, t)
    local def = slot.def
    local L = sc.layers
    local died = L and L.bossDied
    if not died and sc.fight.killed then died = sc.to end
    local dieLen = Len(def, SEQ_DEATH)
    if died and dieLen then
        local lead = min(dieLen / 1000, DEATH_LEAD)
        local from = min(died, sc.to) - lead
        if t >= from then return SEQ_DEATH, min(1, (t - from) / lead) * (dieLen - DEATH_END) end
    end
    local walk = Walk(slot, sc.boss, t, nil)
    if walk then return walk, nil end
    if L and M.Anim() == "full" then
        local i = Last(L.bcT, L.nbc, t)
        local cast = i > 0 and L.bcD[i] >= CAST_MIN and t - L.bcT[i] < L.bcD[i] and PickSeq(def, CASTS)
        if cast then return cast, min((t - L.bcT[i]) * 1000, Len(def, cast) - DEATH_END) end
        local j = Last(L.bsT, #L.bsT, t)
        local hit = j > 0 and t - L.bsT[j] < SWING_SHOW and PickSeq(def, ATTACKS)
        if hit then return hit, min((t - L.bsT[j]) * 1000, Len(def, hit) - DEATH_END) end
    end
    return SEQ_STAND, nil
end
local function Frame(slot, cam, sx, sy, k, figScale)
    local lo, hi
    local aspect = Clamp(slot.aspect, ASPECT_MIN, ASPECT_MAX)
    if slot.boss then
        lo, hi = BOSS_MIN * figScale * k, min(BOSS_MAX, cam.h * BOSS_VIEW)
        local hb = slot.def and slot.def.hit and scene.layers and scene.layers.hitbox or 0
        local span = 2 * hb * scene.ppy * cam.zoom * k / aspect
        if span > lo then lo, hi = span, max(hi, span) end
    else
        lo, hi = ADD_MIN * figScale * k, ADD_MAX
    end
    local least = min(lo, hi)
    local h = Clamp(slot.yd * scene.ppy * cam.zoom * k * M.fit, least, hi)
    local hw, hh = cam.w / 2, cam.h / 2
    if sy > hh - EDGE then return false end
    local room = min(sy + hh - EDGE, (min(sx + hw, hw - sx) - EDGE) * 2 / aspect)
    if room < h then h = room end
    if h < least * FIT_MIN then return false end
    local w = h * aspect
    local m = slot.m
    if abs(w - slot.w) >= 1 or abs(h - slot.h) >= 1 then
        slot.w, slot.h = w, h
        m:SetWidth(w)
        m:SetHeight(h)
    end
    slot.sx, slot.sy = sx, sy
    m:SetPoint("BOTTOM", view, "CENTER", sx, -sy)
    local rw = w * SHADOW_K / 2
    local sh = slot.shadow
    sh:SetWidth(2 * rw)
    sh:SetHeight(max(2, 2 * rw * min(1, cam.tilt * k)))
    sh:SetPoint("CENTER", view, "CENTER", sx, -sy)
    return true
end
local function Pose(slot, cam, head, faceSign, seq, ms)
    local m = slot.m
    if not slot.facing then
        local def = slot.def
        local cami = M.camIndex or (def and def.cam)
        if cami then m:SetCamera(cami) end
        local pos = M.pos or (def and def.pos)
        if pos then m:SetPosition(pos[1], pos[2], pos[3]) end
    end
    local face = faceSign * Replay.Facing(cam, cos(head), sin(head))
    if not slot.facing or abs(face - slot.facing) > FACE_EPS then
        m:SetFacing(face)
        slot.facing = face
    end
    if ms then
        m:SetSequenceTime(seq, ms)
    elseif seq ~= slot.seq or slot.ms then
        m:SetSequence(seq)
    end
    slot.seq, slot.ms = seq, ms
end
local function Visible(slot, on, elapsed, t)
    if not on and slot.on and abs(t - slot.lastT) <= SNAP_T then
        slot.off = slot.off + elapsed
        if slot.off < GRACE then return true end
    end
    slot.off = 0
    if on then
        local a = min(1, slot.alpha + elapsed / FADE)
        if a ~= slot.alpha then
            slot.alpha = a
            slot.m:SetAlpha(a)
        end
    end
    if slot.on == on then return on end
    slot.on = on
    if not on then
        slot.alpha = 0
        slot.m:SetAlpha(0)
    end
    if on then slot.shadow:Show() else slot.shadow:Hide() end
    return on
end
local function PlaceBoss(cam, t, figScale, faceSign, elapsed)
    local slot = slots[1]
    local b = scene.bossState
    if slot.state == "idle" then
        if not b.vis or #bossSrc == 0 then return false end
        local def = Replay.ModelOf(scene.fight.boss)
        local yd = def and def.h or BOSS_YD
        Assign(slot, scene.bossState, bossSrc, def, yd, def and def.w and def.h and def.w / def.h or 1)
    end
    Load(slot, elapsed)
    if slot.state == "bad" then
        if not warned then
            warned = true
            ns.Print(ns.T("iso.bossnomodel"))
        end
        return false
    end
    if slot.state ~= "ok" or not b.vis then return Visible(slot, false, elapsed, t) end
    local sx, sy, k = Replay.Project(cam, b.x, b.y)
    if k <= 0 or not Frame(slot, cam, sx, sy, k, figScale) then return Visible(slot, false, elapsed, t) end
    local seq, ms = BossMotion(slot, scene, t)
    Pose(slot, cam, Heading(slot, b.hx, b.hy, t, elapsed), faceSign, seq, ms)
    Visible(slot, true, elapsed, t)
    drawn[#drawn + 1] = slot
    return true
end
function M.AddAlive(a, t)
    return a.npc ~= nil and a.from <= t and a.to > t and a.n > 0 and (not a.chaseK or t >= a.chaseTo)
end
local function AddDef(name)
    local D = ns.replayData
    local def = D.addModels[name]
    if def == nil then return D.addModelDefault end
    return def
end
local function NextAdd(t, list)
    local best, bestP
    for i = 1, #list do
        local a = list[i]
        if not a.mdlOwn and not a.mdlBad and M.AddAlive(a, t) then
            local def = AddDef(a.name)
            if def and (not bestP or def.prio > bestP) then best, bestP = a, def.prio end
        end
    end
    return best
end
local function PlaceAdd(slot, cam, t, figScale, faceSign, elapsed)
    local a = slot.owner
    Load(slot, elapsed)
    if slot.state == "bad" then
        a.mdlBad = true
        Release(slot)
        return
    end
    local x, y = Replay.PosHold(a, t, ADD_HOLD)
    local sx, sy, k = 0, 0, 0
    if x >= 0 then sx, sy, k = Replay.Project(cam, x, y) end
    if slot.state ~= "ok" or k <= 0 or not Frame(slot, cam, sx, sy, k, figScale) then
        a.mdl = Visible(slot, false, elapsed, t) or nil
        return
    end
    local speed, dx, dy = Speed(a, t - STEP, t, scene.ppy, ADD_HOLD)
    local hx, hy = a.hx, a.hy
    if speed >= Replay.MOVE_YPS then
        local d = sqrt(dx * dx + dy * dy)
        hx, hy = dx / d, dy / d
        a.hx, a.hy = hx, hy
    end
    local walk = Walk(slot, a, t, ADD_HOLD)
    Pose(slot, cam, Heading(slot, hx, hy, t, elapsed), faceSign, walk or SEQ_STAND, nil)
    Visible(slot, true, elapsed, t)
    a.mdl = true
    drawn[#drawn + 1] = slot
end
local function PlaceAdds(cam, t, figScale, faceSign, elapsed)
    local list = scene.layers and scene.layers.adds
    if not list then return end
    for i = 2, #slots do
        local slot = slots[i]
        if slot.owner and not M.AddAlive(slot.owner, t) then Release(slot) end
    end
    for i = 2, #slots do
        local slot = slots[i]
        if not slot.owner then
            local a = NextAdd(t, list)
            if not a then break end
            local def = AddDef(a.name)
            a.mdlOwn = true
            local src = { { kind = "npc", v = a.npc, from = "guid" } }
            AddRetry(src)
            Assign(slot, a, src, def or nil, def and def.h or ADD_YD, 1)
        end
        if slot.owner then PlaceAdd(slot, cam, t, figScale, faceSign, elapsed) end
    end
end
local function Order()
    local n = #drawn
    for i = 2, n do
        local v = drawn[i]
        local j = i - 1
        while j >= 1 and drawn[j].sy > v.sy do
            drawn[j + 1] = drawn[j]
            j = j - 1
        end
        drawn[j + 1] = v
    end
    for r = 1, n do
        local slot = drawn[r]
        if slot.level ~= base + r then
            slot.level = base + r
            slot.m:SetFrameLevel(base + r)
        end
    end
end
function M.Place(cam, t, figScale, faceSign, elapsed)
    for i = #drawn, 1, -1 do drawn[i] = nil end
    stats.models, stats.wait, stats.bad = 0, 0, 0
    if not scene or not M.ready then return false end
    local mode = M.Mode()
    if mode == "off" then
        for i = 1, #slots do
            if slots[i].state ~= "idle" then Release(slots[i]) end
        end
        return false
    end
    local boss = PlaceBoss(cam, t, figScale, faceSign, elapsed)
    if mode == "all" then
        PlaceAdds(cam, t, figScale, faceSign, elapsed)
    else
        for i = 2, #slots do
            if slots[i].state ~= "idle" then Release(slots[i]) end
        end
    end
    Order()
    for i = 1, #slots do
        local st = slots[i].state
        if st == "wait" then stats.wait = stats.wait + 1 elseif st == "bad" then stats.bad = stats.bad + 1 end
    end
    stats.models = #drawn
    return boss
end
local function Rehold()
    for i = 1, #slots do
        local slot = slots[i]
        if slot.state == "ok" then Loaded(slot) end
    end
end
function M.SetCamera(index)
    M.camIndex = index
    if index then return Rehold() end
    for i = 1, #slots do
        local slot = slots[i]
        if slot.src and slot.state ~= "idle" then
            slot.key = nil
            Start(slot, slot.si)
        end
    end
end
function M.SetPos(x, y, z)
    M.pos = x and { x, y or 0, z or 0 } or nil
    Rehold()
end
function M.SetFit(k)
    M.fit = Clamp(k, 0.2, 5)
end
function M.Probe()
    local out = {}
    for i = 1, #slots do
        local slot = slots[i]
        if slot.state ~= "idle" then
            local s = slot.src and slot.src[slot.si]
            out[#out + 1] = { boss = slot.boss, name = slot.owner and slot.owner.name, state = slot.state,
                              from = s and s.from, kind = s and s.kind, v = s and s.v, path = slot.path, on = slot.on,
                              facing = slot.facing, head = slot.head, w = slot.w, h = slot.h, yd = slot.yd,
                              seq = slot.seq, ms = slot.ms, level = slot.level }
        end
    end
    return out
end
if ns.Settings and ns.Settings.Section then
    ns.Settings.Section("look", "replay", {
        label = "set.replay",
        order = 30,
        items = {
            { kind = "choice", key = "room", buttons = true, label = "set.replay.room", tip = "set.replay.room.tip",
              options = { { key = "flat", label = "set.replay.room.flat" }, { key = "real", label = "set.replay.room.real" } },
              default = "real",
              hint = function() return ns.RoomPacks and ns.RoomPacks.Hint(nil) or "" end,
              get = function()
                  local iso = ns.GetDB().settings.iso
                  return type(iso) == "table" and iso.geo == false and "flat" or "real"
              end,
              set = function(k) ns.ReplayIso.SetGeo(k == "real", true) end },
            { kind = "choice", key = "models3d", buttons = true, label = "set.replay.m3d", tip = "set.replay.m3d.tip",
              options = { { key = "off", label = "set.replay.m3d.off" }, { key = "boss", label = "set.replay.m3d.boss" },
                          { key = "all", label = "set.replay.m3d.all" } },
              default = DEFAULT_MODE, get = M.Mode, set = M.SetMode },
            { kind = "choice", key = "modelAnim", buttons = true, label = "set.replay.anim", tip = "set.replay.anim.tip",
              options = { { key = "calm", label = "set.replay.anim.calm" }, { key = "full", label = "set.replay.anim.full" } },
              default = DEFAULT_ANIM, get = M.Anim, set = M.SetAnim },
        },
    })
end
