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
local TURN_RATE = 6
local SNAP_T = 1
local FACE_EPS = 0.02
local LOOK = 0.5
local SWING_SHOW = 0.7
local ADD_HOLD = 4
local DEATH_END = 40
local DEATH_LEAD = 2.5
local SEQ_STAND = 0
local SEQ_DEATH = 1
local SEQ_WALK = 4
local SEQ_RUN = 5
local ATTACKS = { 17, 18, 16 }
local CASTS = { 53, 54 }
local DEF_LEN = { [0] = 2000, [1] = 2000, [4] = 1000, [5] = 700 }
local MODES = { off = true, boss = true, all = true }
local DEFAULT_MODE = "boss"
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
local function Len(def, seq)
    if def and def.seq then return def.seq[seq] end
    return DEF_LEN[seq]
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
local function Start(slot, i)
    local m = slot.m
    local s = slot.src and slot.src[i]
    slot.si = i
    slot.facing, slot.path, slot.on = nil, nil, false
    m:SetAlpha(0)
    slot.shadow:Hide()
    if not s then
        slot.state = "bad"
        return
    end
    local key = s.kind .. ":" .. tostring(s.v)
    slot.stale = key ~= slot.key and ModelPath(slot) or nil
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
    if not ok or not m or not m.SetCreature or not m.SetSequenceTime or not m.SetFacing then return nil end
    m:EnableMouse(false)
    m:Hide()
    local shadow = holder:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(CIRCLE)
    Kit.Tint(shadow, "sem.rep.drop")
    shadow:Hide()
    local slot = { m = m, shadow = shadow, boss = i == 1, si = 1, state = "idle", wait = 0, hold = 0, yd = BOSS_YD,
                   aspect = 1, lastT = -1e9, w = 0, h = 0, sx = 0, sy = 0, seq = SEQ_STAND, ms = 0, on = false,
                   level = 0, lost = 0 }
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
    slot.state, slot.on, slot.head = "idle", false, nil
    slot.m:Hide()
    slot.shadow:Hide()
end
local function Assign(slot, owner, src, def, yd, aspect)
    slot.owner, slot.src, slot.def, slot.si = owner, src, def, 1
    slot.yd, slot.aspect, slot.head, slot.lastT = yd, aspect, nil, -1e9
    if slot.m:IsShown() then
        Start(slot, 1)
    else
        slot.m:Show()
    end
end
function M.Use(sc)
    scene = sc
    warned = false
    for i = 1, #slots do Release(slots[i]) end
    for k in pairs(bossSrc) do bossSrc[k] = nil end
    if not sc then return end
    local def = Replay.ModelOf(sc.fight.boss)
    local L = sc.layers
    local g = L and L.bossNpc
    if g then bossSrc[#bossSrc + 1] = { kind = "npc", v = g, from = "guid" } end
    if def and def.npc and def.npc ~= g then bossSrc[#bossSrc + 1] = { kind = "npc", v = def.npc, from = "data" } end
    if def and def.m2 then bossSrc[#bossSrc + 1] = { kind = "m2", v = def.m2, from = "m2" } end
end
local function Load(slot, elapsed)
    if slot.state == "wait" then
        local p = ModelPath(slot)
        slot.wait = slot.wait - elapsed
        if p and (p ~= slot.stale or (slot.wait <= 0 and not slot.boss)) then
            slot.state, slot.hold, slot.path = "ok", HOLD, p
        elseif slot.wait <= 0 then
            Start(slot, slot.si + 1)
        end
    elseif slot.state == "ok" and slot.hold > 0 then
        slot.hold = slot.hold - elapsed
        slot.facing = nil
    end
end
local function Heading(slot, hx, hy, t, elapsed)
    local want = atan2(hy, hx)
    local head = slot.head
    if not head or abs(t - slot.lastT) > SNAP_T then
        head = want
    else
        local d = (want - head + pi) % (2 * pi) - pi
        head = head + d * min(1, elapsed * TURN_RATE)
    end
    slot.head, slot.lastT = head, t
    return head
end
local function Speed(tr, t, ppy, hold)
    local x1, y1, x0, y0
    if hold then
        x1, y1 = Replay.PosHold(tr, t, hold)
        x0, y0 = Replay.PosHold(tr, t - LOOK, hold)
    else
        x1, y1 = Replay.PosAtTime(tr, t)
        x0, y0 = Replay.PosAtTime(tr, t - LOOK)
    end
    if x1 < 0 or x0 < 0 then return 0, 0, 0 end
    local dx, dy = x1 - x0, y1 - y0
    return sqrt(dx * dx + dy * dy) / ppy / LOOK, dx, dy
end
local function Move(def, speed, t)
    local seq = SEQ_STAND
    if speed >= Replay.RUN_YPS and Len(def, SEQ_RUN) then
        seq = SEQ_RUN
    elseif speed >= Replay.MOVE_YPS and Len(def, SEQ_WALK) then
        seq = SEQ_WALK
    end
    return seq, (t * 1000) % (Len(def, seq) or DEF_LEN[SEQ_STAND])
end
local function BossMotion(def, sc, t, speed)
    local L = sc.layers
    local died = L and L.bossDied
    if not died and sc.fight.killed then died = sc.to end
    local dieLen = Len(def, SEQ_DEATH)
    if died and dieLen then
        local lead = min(dieLen / 1000, DEATH_LEAD)
        local from = min(died, sc.to) - lead
        if t >= from then return SEQ_DEATH, min(1, (t - from) / lead) * (dieLen - DEATH_END) end
    end
    if speed >= Replay.MOVE_YPS or not L then return Move(def, speed, t) end
    local i = Last(L.bcT, L.nbc, t)
    local cast = i > 0 and t - L.bcT[i] < L.bcD[i] and PickSeq(def, CASTS)
    if cast then return cast, min((t - L.bcT[i]) * 1000, Len(def, cast) - DEATH_END) end
    local j = Last(L.bsT, #L.bsT, t)
    local hit = j > 0 and t - L.bsT[j] < SWING_SHOW and PickSeq(def, ATTACKS)
    if hit then return hit, min((t - L.bsT[j]) * 1000, Len(def, hit) - DEATH_END) end
    return Move(def, speed, t)
end
local function Frame(slot, cam, sx, sy, k, figScale)
    local lo, hi
    if slot.boss then
        lo, hi = BOSS_MIN * figScale * k, min(BOSS_MAX, cam.h * BOSS_VIEW)
    else
        lo, hi = ADD_MIN * figScale * k, ADD_MAX
    end
    local least = min(lo, hi)
    local h = Clamp(slot.yd * scene.ppy * cam.zoom * k * M.fit, least, hi)
    local aspect = Clamp(slot.aspect, ASPECT_MIN, ASPECT_MAX)
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
    if slot.hold > 0 then
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
    slot.seq, slot.ms = seq, ms
    m:SetSequenceTime(seq, ms)
end
local function Visible(slot, on)
    if slot.on == on then return end
    slot.on = on
    slot.m:SetAlpha(on and 1 or 0)
    if on then slot.shadow:Show() else slot.shadow:Hide() end
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
    if slot.state ~= "ok" or not b.vis then
        Visible(slot, false)
        return false
    end
    local sx, sy, k = Replay.Project(cam, b.x, b.y)
    if k <= 0 or not Frame(slot, cam, sx, sy, k, figScale) then
        Visible(slot, false)
        return false
    end
    local speed = scene.boss and Speed(scene.boss, t, scene.ppy, nil) or 0
    local seq, ms = BossMotion(slot.def, scene, t, speed)
    Pose(slot, cam, Heading(slot, b.hx, b.hy, t, elapsed), faceSign, seq, ms)
    Visible(slot, true)
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
        Visible(slot, false)
        a.mdl = nil
        return
    end
    local speed, dx, dy = Speed(a, t, scene.ppy, ADD_HOLD)
    local hx, hy = a.hx, a.hy
    if speed >= Replay.MOVE_YPS then
        local d = sqrt(dx * dx + dy * dy)
        hx, hy = dx / d, dy / d
        a.hx, a.hy = hx, hy
    end
    local seq, ms = Move(nil, speed, t)
    Pose(slot, cam, Heading(slot, hx, hy, t, elapsed), faceSign, seq, ms)
    Visible(slot, true)
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
            Assign(slot, a, { { kind = "npc", v = a.npc, from = "guid" } }, nil, def and def.h or ADD_YD, 1)
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
        if slot.state == "ok" then slot.hold = HOLD end
    end
end
function M.SetCamera(index)
    M.camIndex = index
    if index then return Rehold() end
    for i = 1, #slots do
        local slot = slots[i]
        if slot.src and slot.state ~= "idle" then Start(slot, slot.si) end
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
            { kind = "choice", key = "models3d", buttons = true, label = "set.replay.m3d", tip = "set.replay.m3d.tip",
              options = { { key = "off", label = "set.replay.m3d.off" }, { key = "boss", label = "set.replay.m3d.boss" },
                          { key = "all", label = "set.replay.m3d.all" } },
              default = DEFAULT_MODE, get = M.Mode, set = M.SetMode },
        },
    })
end
