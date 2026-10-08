local _, ns = ...
local min = math.min
local max = math.max
local floor = math.floor
local abs = math.abs
local tsort = table.sort
local MATCH = 0.5
local CUT_HOLD = 0.5
local INST_LIFE = 1.2
local INST_MAX = 3
local FW = "FW_CAST"
local K_CAST, K_CHAN, K_MOVED, K_CUT = 1, 2, 3, 0
local RU = { CUT_HOLD = CUT_HOLD, INST_LIFE = INST_LIFE, INST_MAX = INST_MAX }
ns.ReplayUnits = RU
local DAMAGE = {
    SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_HEAL = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
    SPELL_AURA_APPLIED = true,
}
local AUTO = {
    [75] = true, [5019] = true, [3018] = true, [2764] = true,
    [31930] = true, [44949] = true, [70769] = true, [75495] = true,
}
local castMs = {}
local function CastTime(id)
    if not id then return 0 end
    local v = castMs[id]
    if v == nil then
        local _, _, _, _, _, _, ms = GetSpellInfo(id)
        v = tonumber(ms) or 0
        castMs[id] = v
    end
    return v / 1000
end
function RU.New(scene)
    local names = {}
    for k = 1, #scene.tracks do names[scene.tracks[k].name] = true end
    return { names = names, open = {}, fw = {}, succ = {}, done = {}, out = {}, inst = {},
             stats = { casts = 0, chans = 0, ends = 0, cuts = 0, guessed = 0, instants = 0 } }
end
local function Add(c, name, rec)
    local list = c.out[name]
    if not list then
        list = {}
        c.out[name] = list
    end
    list[#list + 1] = rec
end
local function Cap(rec, ts)
    local want = rec.to or (rec.from + CastTime(rec.id))
    if want > rec.from and want < ts then return want end
    return ts
end
local function Close(c, name, ts, cut)
    local rec = c.open[name]
    if not rec then return end
    c.open[name] = nil
    if cut then
        rec.stop, rec.cut = ts, true
        c.stats.cuts = c.stats.cuts + 1
    else
        rec.stop = Cap(rec, ts)
        c.done[name] = { id = rec.id, ts = ts }
    end
end
local function Noise(id)
    return id == nil or AUTO[id] == true or (ns.recProcs ~= nil and ns.recProcs[id] ~= nil)
end
local function OnSucc(c, name, ts, id)
    local s = { ts = ts, id = id }
    c.succ[name] = s
    local d = c.done[name]
    if d and d.id == id and ts - d.ts <= MATCH then return end
    if Noise(id) then return end
    local rec = { t = ts, id = id }
    s.inst = rec
    local list = c.inst[name]
    if not list then
        list = {}
        c.inst[name] = list
    end
    list[#list + 1] = rec
end
local function TakeFw(c, name, ts, kind)
    local p = c.fw[name]
    if p and p.kind == kind and abs(p.ts - ts) <= MATCH then
        c.fw[name] = nil
        return p
    end
    return nil
end
local function OpenChan(c, name, from, id, left)
    Close(c, name, from, false)
    local rec = { from = from, to = from + left / 1000, id = id, chan = true }
    c.open[name] = rec
    c.stats.chans = c.stats.chans + 1
    Add(c, name, rec)
end
local function OnFw(c, ts, name, kind, left)
    local rec = c.open[name]
    if kind == K_CAST then
        if rec and not rec.chan and not rec.to and abs(rec.from - ts) <= MATCH then
            rec.to = ts + (left or 0) / 1000
            c.stats.ends = c.stats.ends + 1
        else
            c.fw[name] = { ts = ts, kind = kind, left = left or 0 }
        end
    elseif kind == K_CHAN then
        local s = c.succ[name]
        if s and abs(s.ts - ts) <= MATCH then
            c.succ[name] = nil
            if s.inst then s.inst.drop = true end
            OpenChan(c, name, ts, s.id, left or 0)
        else
            c.fw[name] = { ts = ts, kind = kind, left = left or 0 }
        end
    elseif kind == K_MOVED then
        if rec and left then rec.to = ts + left / 1000 end
    elseif kind == K_CUT then
        Close(c, name, ts, true)
    end
end
function RU.Event(c, ts, sub, src, dst, a1, a2, a4)
    if sub == FW then
        if src and c.names[src] then OnFw(c, ts, src, tonumber(a1) or -1, tonumber(a2)) end
        return
    end
    if sub == "SPELL_INTERRUPT" then
        if dst and c.open[dst] then Close(c, dst, ts, true) end
        return
    end
    if sub == "UNIT_DIED" then
        if dst and c.open[dst] then Close(c, dst, ts, false) end
        return
    end
    if not src or not c.names[src] then return end
    local id = tonumber(a1)
    if sub == "SPELL_CAST_START" then
        Close(c, src, ts, false)
        local rec = { from = ts, id = id }
        local p = TakeFw(c, src, ts, K_CAST)
        if p then
            rec.to = p.ts + p.left / 1000
            c.stats.ends = c.stats.ends + 1
        end
        c.open[src] = rec
        c.stats.casts = c.stats.casts + 1
        Add(c, src, rec)
    elseif sub == "SPELL_CAST_SUCCESS" then
        local rec = c.open[src]
        if rec and not rec.chan and rec.id == id then
            c.open[src] = nil
            rec.stop = ts
            return
        end
        local p = TakeFw(c, src, ts, K_CHAN)
        if p then
            OpenChan(c, src, p.ts, id, p.left)
        else
            OnSucc(c, src, ts, id)
        end
    elseif DAMAGE[sub] then
        local rec = c.open[src]
        if rec and not rec.chan and not rec.to and rec.id == id then
            c.open[src] = nil
            rec.stop = ts
            c.done[src] = { id = id, ts = ts }
        end
    end
end
local function Finish(c, to)
    for name in pairs(c.open) do
        local rec = c.open[name]
        local want = rec.to or (rec.from + CastTime(rec.id))
        if want > rec.from then
            rec.stop = min(want, max(rec.from, to))
        else
            rec.stop = rec.from
        end
        if not rec.to then c.stats.guessed = c.stats.guessed + 1 end
        c.open[name] = nil
    end
    local out = {}
    for name, list in pairs(c.out) do
        tsort(list, function(a, b) return a.from < b.from end)
        local F, R = {}, {}
        for i = 1, #list do
            local rec = list[i]
            if not rec.to then rec.to = rec.stop end
            if rec.stop and rec.stop > rec.from then
                R[#R + 1] = rec
                F[#F + 1] = rec.from
            end
        end
        if #R > 0 then out[name] = { F = F, R = R, i = 1 } end
    end
    return out
end
local function ByT(a, b)
    return a.t < b.t
end
local function FinishInst(c)
    local out = {}
    for name, list in pairs(c.inst) do
        tsort(list, ByT)
        local T, R = {}, {}
        for i = 1, #list do
            local rec = list[i]
            if not rec.drop then
                T[#T + 1], R[#R + 1] = rec.t, rec.id
            end
        end
        if #T > 0 then
            out[name] = { T = T, R = R, i = 1 }
            c.stats.instants = c.stats.instants + #T
        end
    end
    return out
end
local function ManaOf(segs, name, from, to)
    local T, V, held
    for i = 1, #segs do
        local seg = segs[i]
        if ns.Store.IsNew(seg) and seg.mana then
            for ts, mp, mpMax in ns.Decode.Mana(seg, name, from, to) do
                if ts > to then break end
                if mpMax > 0 then
                    local v = min(1, mp / mpMax)
                    if ts < from then
                        held = v
                    else
                        if not T then T, V = {}, {} end
                        if held then
                            T[#T + 1], V[#V + 1] = from, held
                            held = nil
                        end
                        T[#T + 1], V[#V + 1] = ts, v
                    end
                end
            end
        end
    end
    if held then T, V = { from }, { held } end
    return T and { t = T, v = V, i = 1 } or nil
end
function RU.Build(scene, segs, c)
    local out = { mana = {}, casts = c and Finish(c, scene.fight.to) or {}, inst = c and FinishInst(c) or {},
                  stats = c and c.stats or {} }
    local from, to = scene.from or scene.fight.from, scene.fight.to
    for k = 1, #scene.tracks do
        local name = scene.tracks[k].name
        out.mana[name] = ManaOf(segs, name, from, to)
    end
    scene.units = out
    return out
end
local function Seek(T, i, t)
    local n = #T
    if n == 0 or t < T[1] then return 0 end
    if i < 1 or i > n then i = 1 end
    if T[i] <= t and (i == n or T[i + 1] > t) then return i end
    if T[i] <= t and i < n and T[i + 1] <= t and (i + 1 == n or T[i + 2] > t) then return i + 1 end
    local lo, hi = 1, n
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if T[mid] <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end
RU.Seek = Seek
function RU.ManaAt(m, t)
    if not m then return nil end
    local i = Seek(m.t, m.i, t)
    if i == 0 then return nil end
    m.i = i
    return m.v[i]
end
function RU.CastAt(cs, t)
    if not cs then return nil, 0, 0 end
    local i = Seek(cs.F, cs.i, t)
    if i == 0 then return nil, 0, 0 end
    cs.i = i
    local rec = cs.R[i]
    local stop = rec.stop
    if t >= stop and not (rec.cut and t < stop + CUT_HOLD) then return nil, 0, 0 end
    local span = rec.to - rec.from
    local at = min(t, stop)
    local p = span > 0 and min(1, max(0, (at - rec.from) / span)) or 1
    return rec, p, max(0, rec.to - at)
end
local INST_HOLD = 0.4
function RU.InstAt(ins, t)
    if not ins then return 0, 0 end
    local T = ins.T
    local j = Seek(T, ins.i, t)
    if j == 0 then return 0, 0 end
    ins.i = j
    local n = 0
    while n < INST_MAX and j - n >= 1 and t - T[j - n] < INST_LIFE do n = n + 1 end
    if n == 0 then return 0, 0 end
    return j, n
end
function RU.InstAlpha(age)
    if age <= INST_HOLD then return 1 end
    if age >= INST_LIFE then return 0 end
    return 1 - (age - INST_HOLD) / (INST_LIFE - INST_HOLD)
end
