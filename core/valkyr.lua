local _, ns = ...
local format = string.format
local max = math.max
local floor = math.floor
local tsort = table.sort
local Valkyr = {}
ns.Valkyr = Valkyr
local function T(key)
    return ns.T(key)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function RideIndex(b, s)
    for i = 1, #(s.badges or {}) do
        local bd = s.badges[i]
        if bd.kind == "vehicle" and bd.wave == b.def.wave then return i end
    end
    return nil
end
local function RowTip(b, who, st, class)
    local Tips = ns.BadgeTips
    local v = b.by[who] or 0
    local out = { { kind = "head", left = who, right = Tips.Short(v), class = class } }
    Put(out, "row", T(b.normal and "sum.tt.total" or "sum.tt.useful"), Tips.Short(v))
    local full = b.full and b.full.by and b.full.by[who] or 0
    if not b.normal and full > 0 then Put(out, "row", T("sum.vk.full"), Tips.Short(full), nil, "dim") end
    local waves = b.waves and b.waves[who] or {}
    local shown = 0
    for w = 1, #(b.waveList or {}) do
        if waves[w] then
            Put(out, "sub", format(T("sum.tt.wave"), w), Tips.Short(waves[w]))
            shown = shown + 1
        end
    end
    Tips.Abil(out, b.ab and b.ab[who], shown > 0)
    local n = st and st.n or 0
    Put(out, "sep")
    if n == 0 then
        Put(out, "row", T("sum.vk.grab"), T("sum.vk.never"), nil, "dim")
    else
        Put(out, "row", T("sum.vk.grab"), format("x%d", n), format(T("sum.tt.sec"), floor((st.sec or 0) + 0.5)))
        for k = 1, n do
            local a, z = st.times[k], st.outs and st.outs[k]
            local w = st.waves and st.waves[k]
            local left = w and format("%s, %s", Tips.Clock(a), format(T("sum.tt.wave"), w)) or Tips.Clock(a)
            Put(out, "sub", left, z and format(T("sum.vk.held"), z - a) or nil)
        end
    end
    return out
end
function Valkyr.View(b, s, classOf)
    if b.def.kind ~= "usefulTo" or not s or not s.players then return nil end
    local ri = RideIndex(b, s)
    local stats, names = {}, {}
    for i = 1, #s.players do
        local p = s.players[i]
        local st = ri and p.badges and p.badges[ri]
        if st and (st.n or 0) > 0 then stats[p.name] = st end
        if (b.by[p.name] or 0) > 0 or stats[p.name] then names[#names + 1] = p.name end
    end
    for who in pairs(b.by) do
        if not s.byName or not s.byName[who] then
            local dup = false
            for i = 1, #names do dup = dup or names[i] == who end
            if not dup then names[#names + 1] = who end
        end
    end
    tsort(names, function(x, y)
        local vx, vy = b.by[x] or 0, b.by[y] or 0
        if vx ~= vy then return vx > vy end
        return x < y
    end)
    local Short = ns.BadgeTips.Short
    local icon = ri and (s.icons and s.icons[ri] or s.badges[ri].id) or false
    local rows = {}
    for i = 1, #names do
        local who = names[i]
        local st = stats[who]
        local v = b.by[who] or 0
        local class = classOf and classOf(who) or nil
        local cells = { v > 0 and Short(v) or "—", format("%.1f%%", v * 100 / max(1, b.total)) }
        rows[i] = { who = who, class = class, cells = cells,
                    marks = { st and icon and { id = icon, n = st.n } or false },
                    lines = RowTip(b, who, st, class) }
    end
    local label = T(b.label or b.def.label)
    local tip = { { kind = "head", left = label, right = Short(b.total) } }
    return { title = format(T("sum.k.title"), label, Short(b.total)),
             cols = { T(b.normal and "sum.tt.total" or "sum.vk.col"), T("sum.vk.share") },
             heads = { icon }, rows = rows, tip = tip, span = 1 }
end
