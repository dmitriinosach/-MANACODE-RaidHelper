local _, ns = ...
local tonumber = tonumber
local min = math.min
local floor = math.floor
local tsort = table.sort
local AURA_ON, AURA_OFF, AURA_TOUCH, DIED, GROUP, AWAY, VEH, CAST = 1, 2, 3, 4, 5, 6, 7, 8
local FEIGN, FEIGN_WINDOW = 5384, 2
local LIMIT = 60000
local PER_COL = 5
local VALKYR = -1
local HUGE = 1e12
local RR = { VALKYR = VALKYR, PER_COL = PER_COL, SAVED_V = 2 }
ns.ReplayRaid = RR
local SUBS = {
    SPELL_AURA_APPLIED = AURA_ON, SPELL_AURA_REMOVED = AURA_OFF, SPELL_AURA_BROKEN = AURA_OFF,
    SPELL_AURA_BROKEN_SPELL = AURA_OFF, SPELL_AURA_REFRESH = AURA_TOUCH, SPELL_AURA_APPLIED_DOSE = AURA_TOUCH,
    SPELL_AURA_REMOVED_DOSE = AURA_TOUCH, UNIT_DIED = DIED, FW_GROUP = GROUP, FW_AWAY = AWAY, FW_VEH = VEH,
    SPELL_CAST_SUCCESS = CAST,
}
RR.SUBS = SUBS
function RR.New(scene)
    local fight = scene.fight
    local D = ns.replayData
    local v = D and D.valkyr
    local c = { names = ns.Replay.ByK(scene), from = fight.from, to = fight.to, open = {}, seen = {},
                K = {}, S = {}, I = {}, F = {}, T = {}, D = {}, n = 0, group = {}, awayT = {}, awayV = {},
                valkyr = v and v.boss == fight.boss and v.icon or nil, feign = {} }
    for k = 1, #scene.tracks do c.open[k], c.seen[k] = {}, {} end
    return c
end
local function Open(c, k, key, id, ts, debuff)
    if c.n >= LIMIT then return end
    local n = c.n + 1
    c.n = n
    c.K[n], c.S[n], c.I[n], c.F[n], c.T[n], c.D[n] = k, key, id, ts, c.to, debuff
    c.open[k][key] = n
    c.seen[k][key] = true
end
local function Close(c, k, key, ts)
    local open = c.open[k]
    local n = open[key]
    if not n then return end
    c.T[n] = ts
    open[key] = nil
end
local function OnAura(c, kind, ts, k, key, id, debuff)
    local was = c.open[k][key]
    if kind == AURA_ON then
        if not was then Open(c, k, key, id, ts, debuff) end
    elseif kind == AURA_OFF then
        if not was and not c.seen[k][key] then Open(c, k, key, id, c.from, debuff) end
        Close(c, k, key, ts)
    elseif not was and not c.seen[k][key] then
        Open(c, k, key, id, c.from, debuff)
    end
end
function RR.Event(c, ts, sub, src, dst, a1, a2, a4, sk)
    local kind = SUBS[sub]
    if not kind then return end
    if kind <= AURA_TOUCH then
        local k = dst and c.names[dst]
        local id = tonumber(a1)
        if k and sk and id then OnAura(c, kind, ts, k, sk, id, a4 == "DEBUFF") end
    elseif kind == CAST then
        local k = tonumber(a1) == FEIGN and src and c.names[src]
        if k then c.feign[k] = ts end
    elseif kind == DIED then
        local k = dst and c.names[dst]
        local f = k and c.feign[k]
        if k and not (f and ts - f <= FEIGN_WINDOW) then
            for key in pairs(c.open[k]) do Close(c, k, key, ts) end
        end
    elseif kind == GROUP then
        local g = tonumber(a1)
        if g and type(a2) == "string" then
            for name in a2:gmatch("[^,]+") do c.group[name] = g end
        end
    elseif kind == AWAY then
        local k = src and c.names[src]
        local v = tonumber(a1)
        if k and v then
            local T, V = c.awayT[k], c.awayV[k]
            if not T then
                T, V = {}, {}
                c.awayT[k], c.awayV[k] = T, V
            end
            T[#T + 1], V[#V + 1] = ts, v
        end
    elseif kind == VEH and c.valkyr then
        local k = src and c.names[src]
        if k then
            if tonumber(a1) == 1 then
                if not c.open[k][VALKYR] then Open(c, k, VALKYR, c.valkyr, ts, true) end
            else
                Close(c, k, VALKYR, ts)
            end
        end
    end
end
function RR.Done(c, scene)
    local per, info = {}, {}
    local who = {}
    for k = 1, #scene.tracks do per[k] = { F = {}, T = {}, S = {}, I = {}, D = {} } end
    local idx = {}
    for i = 1, c.n do idx[i] = i end
    local F = c.F
    tsort(idx, function(a, b)
        if F[a] ~= F[b] then return F[a] < F[b] end
        return a < b
    end)
    for j = 1, c.n do
        local i = idx[j]
        local k, key = c.K[i], c.S[i]
        local u = per[k]
        local m = #u.F + 1
        u.F[m], u.T[m], u.S[m], u.I[m], u.D[m] = F[i], c.T[i], key, c.I[i], c.D[i]
        local a = info[key]
        if not a then
            a = { key = key, id = c.I[i], debuff = c.D[i], n = 0 }
            info[key] = a
            who[key] = {}
        end
        if not who[key][k] then
            who[key][k] = true
            a.n = a.n + 1
        end
    end
    local out = { per = per, info = info, group = c.group, awayT = c.awayT, awayV = c.awayV, n = c.n }
    scene.raid = out
    return out
end
local presets = {}
local groupsOf = {}
local gof
local gkey
local function Put(out, id, prio)
    local key = ns.SpellKey(id)
    if key and (out[key] == nil or out[key] < prio) then
        out[key] = prio
        gof[key] = gkey
    end
end
local function FromData(out, from, boss, prio)
    local D = ns.replayData
    if from == "valkyr" then
        if D and D.valkyr and D.valkyr.boss == boss then
            out[VALKYR] = prio
            gof[VALKYR] = gkey
        end
    elseif from == "tomb" then
        local def = ns.replayTomb and ns.replayTomb[boss]
        for i = 1, def and #def.aura or 0 do Put(out, def.aura[i], prio) end
    elseif from == "control" then
        local ids = D and D.control and D.control.ids
        for i = 1, ids and #ids or 0 do Put(out, ids[i], prio - i * 0.001) end
    elseif from == "boss" then
        local own = ns.replayRaid.bosses and ns.replayRaid.bosses[boss]
        for i = 1, own and #own or 0 do Put(out, own[i], prio + 0.5 - i * 0.001) end
        local s = ns.summaries and ns.summaries[boss]
        local badges = s and s.badges
        for i = 1, badges and #badges or 0 do
            local b = badges[i]
            if (b.kind == "aura" or b.kind == "stack") and b.spell then Put(out, b.spell, prio - i * 0.001) end
        end
        local stacks = s and s.stacks
        for i = 1, stacks and #stacks or 0 do Put(out, stacks[i].spell, prio - 0.5) end
        local states = D and D.states
        for i = 1, states and #states or 0 do
            local st = states[i]
            if st.imp and not st.cast and not st.aim and (st.boss == nil or st.boss == boss) then
                Put(out, st.name, prio - 0.6)
            end
        end
    end
end
function RR.Preset(boss)
    local out = presets[boss or false]
    if out then return out end
    out, gof = {}, {}
    local data = ns.replayRaid
    for g = 1, #data.groups do
        local grp = data.groups[g]
        gkey = grp.key
        for i = 1, grp.ids and #grp.ids or 0 do Put(out, grp.ids[i], grp.prio - i * 0.01) end
        for i = 1, grp.from and #grp.from or 0 do FromData(out, grp.from[i], boss, grp.prio - i * 0.1) end
    end
    presets[boss or false], groupsOf[boss or false] = out, gof
    gof, gkey = nil, nil
    return out
end
function RR.GroupOf(boss, key)
    RR.Preset(boss)
    return groupsOf[boss or false][key]
end
function RR.Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    local s = settings.iso.raid
    if type(s) ~= "table" or s.v ~= RR.SAVED_V then
        s = { v = RR.SAVED_V }
        settings.iso.raid = s
    end
    return s
end
function RR.GroupsOff()
    local s = RR.Saved()
    if type(s.groups) ~= "table" then s.groups = {} end
    return s.groups
end
function RR.Picks()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    local p = settings.iso.raidAuras
    if type(p) ~= "table" then
        p = {}
        settings.iso.raidAuras = p
    end
    return p
end
function RR.Want(boss)
    local base, picks = RR.Preset(boss), RR.Picks()
    local gmap, off = groupsOf[boss or false], RR.GroupsOff()
    local out = {}
    for key, prio in pairs(base) do
        if picks[key] == true or (picks[key] ~= false and off[gmap[key]] ~= false) then out[key] = prio end
    end
    local custom = ns.replayRaid.custom
    for key, on in pairs(picks) do
        if on == true and out[key] == nil then out[key] = custom end
    end
    return out
end
function RR.SetPick(key, on, boss)
    local picks = RR.Picks()
    local g = RR.GroupOf(boss, key)
    local inBase = RR.Preset(boss)[key] ~= nil and RR.GroupsOff()[g] ~= false
    if on == inBase then picks[key] = nil else picks[key] = on end
end
function RR.Filter(R, want)
    for _, u in pairs(R.per) do
        if u.want ~= want then
            local W = {}
            for i = 1, #u.S do
                if want[u.S[i]] then W[#W + 1] = i end
            end
            u.W, u.want = W, want
        end
    end
end
function RR.Shown(u, want, t, out, cap)
    local W = u.W
    local F, T, S = u.F, u.T, u.S
    local lo, hi, n = -HUGE, HUGE, 0
    for j = 1, W and #W or 0 do
        local i = W[j]
        local f = F[i]
        if f > t then
            if f < hi then hi = f end
            break
        end
        local e = T[i]
        if e > t then
            if e < hi then hi = e end
            if f > lo then lo = f end
            local p = want[S[i]] or 0
            local at = n + 1
            while at > 1 and (want[S[out[at - 1]]] or 0) < p do at = at - 1 end
            if at <= cap then
                for m = min(n, cap - 1), at, -1 do out[m + 1] = out[m] end
                out[at] = i
                n = min(n + 1, cap)
            end
        elseif e > lo then
            lo = e
        end
    end
    for m = n + 1, #out do out[m] = nil end
    return n, lo, hi
end
function RR.All(u, t)
    local list = {}
    local F, T = u.F, u.T
    for i = 1, #F do
        if F[i] > t then break end
        if T[i] > t then list[#list + 1] = i end
    end
    local D = u.D
    tsort(list, function(a, b)
        if D[a] ~= D[b] then return D[a] == true end
        return F[a] < F[b]
    end)
    return list
end
function RR.Away(R, k, t)
    local T = R.awayT[k]
    if not T then return 0 end
    local v = 0
    for i = 1, #T do
        if T[i] > t then break end
        v = R.awayV[k][i]
    end
    return v
end
function RR.Seen(R, want)
    local list = {}
    for _, a in pairs(R.info) do list[#list + 1] = a end
    tsort(list, function(a, b)
        local pa, pb = want[a.key], want[b.key]
        if (pa ~= nil) ~= (pb ~= nil) then return pa ~= nil end
        if pa and pb and pa ~= pb then return pa > pb end
        if a.debuff ~= b.debuff then return a.debuff end
        if a.n ~= b.n then return a.n > b.n end
        return a.key < b.key
    end)
    return list
end
local ROLE_ORDER = { tank = 1, heal = 2 }
function RR.Columns(scene, roles)
    local R = scene.raid
    local tracks = scene.tracks
    local list = {}
    for k = 1, #tracks do list[k] = k end
    local function Role(k) return ROLE_ORDER[roles[tracks[k].name] or ""] or 3 end
    tsort(list, function(a, b)
        local ra, rb = Role(a), Role(b)
        if ra ~= rb then return ra < rb end
        return tracks[a].name < tracks[b].name
    end)
    local cols = {}
    local groups = R and R.group
    if groups and next(groups) then
        local byG, keys, rest = {}, {}, {}
        for i = 1, #list do
            local k = list[i]
            local g = groups[tracks[k].name]
            if g then
                if not byG[g] then
                    byG[g] = {}
                    keys[#keys + 1] = g
                end
                local c = byG[g]
                c[#c + 1] = k
            else
                rest[#rest + 1] = k
            end
        end
        tsort(keys)
        for i = 1, #keys do cols[#cols + 1] = byG[keys[i]] end
        for i = 1, #rest, PER_COL do
            local c = {}
            for j = i, min(#rest, i + PER_COL - 1) do c[#c + 1] = rest[j] end
            cols[#cols + 1] = c
        end
        return cols
    end
    for i = 1, #list, PER_COL do
        local c = {}
        for j = i, min(#list, i + PER_COL - 1) do c[#c + 1] = list[j] end
        cols[#cols + 1] = c
    end
    return cols
end
function RR.Hp(tr, t, cur)
    local T, n = tr.t, tr.n
    if n == 0 or t < T[1] then return 1, false end
    local i = cur[tr] or 1
    if i > n then i = n end
    while i > 1 and T[i] > t do i = i - 1 end
    while i < n and T[i + 1] <= t do i = i + 1 end
    cur[tr] = i
    local dz = tr.dz[i] or 0
    local hp = tr.hp[i] or 1
    if hp < 0 then hp = 0 elseif hp > 1 then hp = 1 end
    return hp, dz > 0
end
function RR.Q(v)
    return floor(v * 100 + 0.5)
end
