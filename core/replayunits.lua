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
local VPOW = "FW_VPOW"
local K_CAST, K_CHAN, K_MOVED, K_CUT = 1, 2, 3, 0
local RU = { CUT_HOLD = CUT_HOLD, INST_LIFE = INST_LIFE, INST_MAX = INST_MAX, GCD_LIFE = 1 }
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
    return { names = ns.Replay.ByK(scene), open = {}, fw = {}, succ = {}, wait = {}, done = {}, out = {}, inst = {}, vpow = {},
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
local function Live(c, name, ts)
    local rec = c.open[name]
    if not rec then return nil end
    local want = rec.to or (rec.from + CastTime(rec.id))
    if want > rec.from and ts > want + MATCH then
        c.open[name] = nil
        rec.stop = want
        return nil
    end
    return rec
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
local function OpenChan(c, name, from, id, left, aim)
    Close(c, name, from, false)
    local rec = { from = from, to = from + left / 1000, id = id, chan = true, aim = aim }
    c.open[name] = rec
    c.stats.chans = c.stats.chans + 1
    Add(c, name, rec)
    return rec
end
local function OnFw(c, ts, name, kind, left, aim, spell)
    local rec = Live(c, name, ts)
    if kind == K_CAST then
        if rec and not rec.chan and not rec.to and abs(rec.from - ts) <= MATCH then
            rec.to = ts + (left or 0) / 1000
            rec.aim = aim
            c.stats.ends = c.stats.ends + 1
        else
            c.fw[name] = { ts = ts, kind = kind, left = left or 0, aim = aim }
        end
    elseif kind == K_CHAN then
        local s = c.succ[name]
        if s and abs(s.ts - ts) <= MATCH then
            c.succ[name] = nil
            if s.inst then s.inst.drop = true end
            OpenChan(c, name, ts, s.id, left or 0, aim)
        else
            local p = { ts = ts, kind = kind, left = left or 0, aim = aim }
            c.fw[name] = p
            if spell then
                local rec = OpenChan(c, name, ts, nil, left or 0, aim)
                rec.name = spell
                p.rec = rec
                c.wait[name] = rec
            end
        end
    elseif kind == K_MOVED then
        if rec and left then rec.to = ts + left / 1000 end
    elseif kind == K_CUT then
        Close(c, name, ts, true)
    end
end
function RU.Event(c, ts, sub, src, dst, a1, a2, a3, id)
    if sub == FW then
        if src and c.names[src] then OnFw(c, ts, src, tonumber(a1) or -1, tonumber(a2), dst ~= "" and dst or nil, a3) end
        return
    end
    if sub == VPOW then
        if src and c.names[src] then
            local v, vMax = tonumber(a1) or 0, tonumber(a2) or 0
            local list = c.vpow[src]
            if not list then
                list = { t = {}, v = {}, i = 1 }
                c.vpow[src] = list
            end
            local n = #list.t + 1
            list.t[n], list.v[n] = ts, vMax > 0 and min(1, max(0, v / vMax)) or false
        end
        return
    end
    if sub == "SPELL_INTERRUPT" then
        if dst and Live(c, dst, ts) then Close(c, dst, ts, true) end
        return
    end
    if sub == "UNIT_DIED" then
        if dst and c.open[dst] then Close(c, dst, ts, false) end
        return
    end
    if not src or not c.names[src] then return end
    id = id or tonumber(a1)
    local w = c.wait[src]
    if w and id and a2 == w.name then
        w.id = id
        c.wait[src] = nil
    end
    if sub == "SPELL_CAST_START" then
        Close(c, src, ts, false)
        local rec = { from = ts, id = id }
        local p = TakeFw(c, src, ts, K_CAST)
        if p then
            rec.to = p.ts + p.left / 1000
            rec.aim = p.aim
            c.stats.ends = c.stats.ends + 1
        end
        c.open[src] = rec
        c.stats.casts = c.stats.casts + 1
        Add(c, src, rec)
    elseif sub == "SPELL_CAST_SUCCESS" then
        local rec = Live(c, src, ts)
        if rec and not rec.chan and rec.id == id then
            c.open[src] = nil
            rec.stop = ts
            return
        end
        local p = TakeFw(c, src, ts, K_CHAN)
        if p and p.rec then
            if p.rec.name ~= a2 then
                c.fw[src] = p
                OnSucc(c, src, ts, id)
            end
        elseif p then
            OpenChan(c, src, p.ts, id, p.left, p.aim)
        else
            OnSucc(c, src, ts, id)
        end
    elseif DAMAGE[sub] then
        local rec = Live(c, src, ts)
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
            if rec.stop and rec.stop > rec.from and (rec.id or not rec.name) then
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
local offKeys
local function Listed(id)
    if not id then return false end
    if ns.defensives and ns.defensives[id] then return true end
    if not offKeys then
        offKeys = {}
        ns.SpellSet(ns.actions and ns.actions.kicks, offKeys)
        for k in pairs(ns.castGcd and ns.castGcd.offGcd or {}) do offKeys[ns.SpellKey(k)] = true end
    end
    local key = ns.SpellKey(id)
    return key ~= nil and offKeys[key] == true
end
function RU.MarkOff(ins, casts)
    local pair = ns.castGcd and ns.castGcd.pair or 0.3
    local T, R, O = ins.T, ins.R, {}
    local F, CR = casts and casts.F or {}, casts and casts.R or {}
    local ci, lastOn, stop = 1, nil, nil
    for j = 1, #T do
        local t = T[j]
        while ci <= #F and F[ci] <= t do
            lastOn, stop = F[ci], CR[ci].stop
            ci = ci + 1
        end
        local off = Listed(R[j]) or (stop ~= nil and t < stop) or (lastOn ~= nil and t - lastOn < pair)
        O[j] = off
        if not off then lastOn = t end
    end
    ins.O = O
end
local function ManaOf(segs, name, from, to)
    local T, V, held
    for i = 1, #segs do
        local seg = segs[i]
        if seg.mana then
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
                  vpow = c and c.vpow or {}, stats = c and c.stats or {} }
    for name, ins in pairs(out.inst) do RU.MarkOff(ins, out.casts[name]) end
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
    return m.v[i] or nil
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
