local _, ns = ...
local max = math.max
local floor = math.floor
local tsort = table.sort
local CAP_K = 2
local CAP_MIN = 30
local ALERT_FOR = 2.5
local ALERT_MAX = 3
local BAR_MAX = 6
local WHO_GAP = 1.5
local WHO_MAX = 10
local RB = { ALERT_FOR = ALERT_FOR, ALERT_MAX = ALERT_MAX, BAR_MAX = BAR_MAX }
ns.ReplayBars = RB
function RB.Defs(boss)
    local D = ns.replayBars
    if not D or boss == nil then return {} end
    return D.bosses[boss] or {}
end
function RB.New(fight)
    local defs = RB.Defs(fight.boss)
    local by, t, who = {}, {}, {}
    for i = 1, #defs do
        local def = defs[i]
        for s = 1, #def.sub do
            local m = by[def.sub[s]] or {}
            by[def.sub[s]] = m
            for k = 1, #def.spell do m[def.spell[k]] = m[def.spell[k]] or i end
        end
        t[i], who[i] = {}, {}
    end
    return { defs = defs, by = by, players = fight.players or {}, gap = ns.replayBars and ns.replayBars.gap or 3,
             t = t, who = who }
end
function RB.Event(ctx, ts, sub, src, dst, a1)
    local m = ctx.by[sub]
    if not m then return end
    local id = tonumber(a1)
    local i = id and m[id]
    if not i or (src and ctx.players[src]) then return end
    local list, names = ctx.t[i], ctx.who[i]
    local n = #list
    local who = sub ~= "SPELL_SUMMON" and dst ~= src and dst and ctx.players[dst] and dst or nil
    if n > 0 and ts - list[n] <= ctx.gap then
        if who and ts - list[n] <= WHO_GAP then RB.AddWho(names[n], who) end
        return
    end
    list[n + 1] = ts
    names[n + 1] = {}
    if who then RB.AddWho(names[n + 1], who) end
end
function RB.AddWho(list, name)
    if #list >= WHO_MAX then return end
    for i = 1, #list do
        if list[i] == name then return end
    end
    list[#list + 1] = name
end
local function ByTime(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.k < b.k
end
function RB.Done(ctx, L, res, fight)
    local tracks, alerts, phases = {}, {}, {}
    local has = false
    for i = 1, #ctx.defs do
        local def, list = ctx.defs[i], ctx.t[i]
        if #list > 0 then
            tsort(list)
            local tr = { def = def, t = list, who = ctx.who[i], left = 0, total = 0 }
            tracks[#tracks + 1] = tr
            if def.cd then has = true end
            if def.alert then
                for j = 1, #list do alerts[#alerts + 1] = { t = list[j], k = #tracks, who = ctx.who[i][j] } end
            end
        end
    end
    tsort(alerts, ByTime)
    local spans = res and res.spans or {}
    for k = 2, #spans do phases[#phases + 1] = fight.from + spans[k].from end
    L.bars = { pull = fight.from, tracks = tracks, alerts = alerts, phases = phases, has = has }
end
local function NextIdx(list, t)
    local lo, hi = 1, #list
    if hi == 0 or list[hi] <= t then return nil end
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if list[mid] > t then hi = mid else lo = mid + 1 end
    end
    return lo
end
local function LastIdx(list, t)
    local k = NextIdx(list, t)
    if k then return k - 1 end
    return #list
end
local function PhaseStart(B, prev, nextT)
    local start = prev
    local ph = B.phases
    for i = 1, #ph do
        if ph[i] > nextT then break end
        if ph[i] > start then start = ph[i] end
    end
    return start
end
local function ByLeft(a, b)
    if a.left ~= b.left then return a.left < b.left end
    return a.def.spell[1] < b.def.spell[1]
end
function RB.Span(B, tr, t)
    local cd = tr.def.cd
    if not cd then return false end
    local list = tr.t
    local k = NextIdx(list, t)
    if not k then return false end
    local nextT = list[k]
    local start = PhaseStart(B, k > 1 and list[k - 1] or B.pull, nextT)
    local cap = max(cd * CAP_K, CAP_MIN)
    if nextT - start > cap then start = nextT - cap end
    if t < start then return false end
    tr.left, tr.total = nextT - t, nextT - start
    return true
end
function RB.Bars(B, t, out, cap)
    local n = 0
    if B then
        for i = 1, #B.tracks do
            local tr = B.tracks[i]
            if RB.Span(B, tr, t) then
                n = n + 1
                out[n] = tr
            end
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    tsort(out, ByLeft)
    local active = n
    for i = n, (cap or BAR_MAX) + 1, -1 do out[i] = nil end
    return #out, active
end
function RB.Alerts(B, t, out)
    local n = 0
    if B then
        local list = B.alerts
        local lo, hi = 1, #list
        while lo <= hi do
            local mid = floor((lo + hi) / 2)
            if list[mid].t <= t then lo = mid + 1 else hi = mid - 1 end
        end
        for j = hi, 1, -1 do
            local a = list[j]
            if t - a.t >= ALERT_FOR or n >= ALERT_MAX then break end
            n = n + 1
            out[n] = a
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    return n
end
function RB.LastAlert(B, t)
    if not B or #B.alerts == 0 then return nil end
    local list = B.alerts
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if list[mid].t <= t then lo = mid + 1 else hi = mid - 1 end
    end
    return hi > 0 and list[hi].t or nil
end
function RB.Spell(def)
    local name, _, icon = GetSpellInfo(def.spell[1])
    return name or tostring(def.spell[1]), icon
end
function RB.Count(tr, t)
    return LastIdx(tr.t, t)
end
