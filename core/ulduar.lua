local _, ns = ...
local format = string.format
local min = math.min
local floor = math.floor
local tsort = table.sort
local TIMES = 8
local Uld = {}
ns.Uld = Uld
local function T(key)
    return ns.T(key)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Find(s, spell, kind, low)
    local want = ns.SpellKey(spell)
    for i = 1, s.own do
        local bd = s.badges[i]
        if bd.kind == kind and (low == nil or (bd.low == true) == low) and ns.SpellKey(bd.spell) == want then return i end
    end
    return nil
end
local function SanityTip(st, ins, who, class)
    local Tips = ns.BadgeTips
    local out = { { kind = "head", left = who, right = st.min and tostring(st.min) or "—", class = class } }
    Put(out, "row", T("sum.uld.min"), st.min and tostring(st.min) or "—")
    Put(out, "row", T("sum.uld.fin"), st.fin and tostring(st.fin) or "—")
    local n = ins and ins.n or 0
    if n > 0 then
        Put(out, "row", T("sum.uld.insane"), format("x%d", n), nil, "bad")
        for k = 1, min(TIMES, n) do Put(out, "sub", Tips.Clock(ins.times[k])) end
        if n > TIMES then Put(out, "sub", (format(T("sum.tip.more"), n - TIMES):gsub("^%s+", ""))) end
    end
    return out
end
local function SanityView(b, s, classOf)
    local si = Find(s, b.def.spell, "stack", true)
    local ii = b.def.insane and Find(s, b.def.insane, "aura")
    if not si then return nil end
    local rows, insane = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        local st, ins = p.badges[si], ii and p.badges[ii] or nil
        local n = ins and ins.n or 0
        if st and (st.n > 0 or n > 0) then
            rows[#rows + 1] = { p = p, st = st, ins = ins, n = n }
            if n > 0 then insane = insane + 1 end
        end
    end
    tsort(rows, function(x, y)
        local mx, my = x.st.min or 101, y.st.min or 101
        if mx ~= my then return mx < my end
        return x.p.name < y.p.name
    end)
    local icon = ii and (s.icons[ii] or s.badges[ii].id or b.def.insane) or false
    local out = {}
    for k = 1, #rows do
        local r = rows[k]
        local class = classOf and classOf(r.p.name) or nil
        out[k] = { who = r.p.name, class = class,
                   cells = { r.st.min and tostring(r.st.min) or "—", r.st.fin and tostring(r.st.fin) or "—" },
                   marks = { r.n > 0 and icon and { id = icon, n = r.n } or false },
                   lines = SanityTip(r.st, r.ins, r.p.name, class) }
    end
    local label = T(b.def.label)
    local tip = { { kind = "head", left = label, right = tostring(#rows) } }
    Put(tip, "row", T("sum.uld.insanecount"), tostring(insane), nil, insane > 0 and "bad" or nil)
    return { title = format(T("sum.k.title"), label, #rows), cols = { T("sum.uld.min"), T("sum.uld.fin") },
             heads = { icon }, rows = out, tip = tip, span = 1 }
end
local function Held(eps)
    local sec, peak = 0, 0
    for k = 1, #eps do
        sec = sec + eps[k].d
        if eps[k].pk > peak then peak = eps[k].pk end
    end
    return sec, peak
end
local function StacksView(b, s, classOf)
    local si = Find(s, b.def.spell, "stack", false)
    if not si then return nil end
    local rows, whole = {}, 0
    for i = 1, #s.players do
        local p = s.players[i]
        local st = p.badges[si]
        local eps = st and st.eps
        if eps and eps[1] then
            local sec, peak = Held(eps)
            rows[#rows + 1] = { p = p, st = st, sec = sec, peak = peak }
            whole = whole + sec
        end
    end
    tsort(rows, function(x, y)
        if x.sec ~= y.sec then return x.sec > y.sec end
        return x.p.name < y.p.name
    end)
    local out = {}
    for k = 1, #rows do
        local r = rows[k]
        local class = classOf and classOf(r.p.name) or nil
        local lines = { { kind = "head", left = r.p.name, right = format(T("sum.tt.sec"), floor(r.sec + 0.5)),
                          class = class } }
        local list = ns.StackTips.Badge(r.st, s.badges[si])
        for n = 2, #list do lines[#lines + 1] = list[n] end
        out[k] = { who = r.p.name, class = class,
                   cells = { tostring(r.peak), format(T("sum.tt.sec"), floor(r.sec + 0.5)), tostring(#r.st.eps) },
                   marks = {}, lines = lines }
    end
    local label = T(b.def.label)
    local tip = { { kind = "head", left = label, right = format(T("sum.tt.sec"), floor(whole + 0.5)) } }
    return { title = format(T("sum.k.title"), label, #rows), cols = { T("sum.uld.peak"), T("sum.uld.time"), T("sum.tt.count") },
             heads = {}, rows = out, tip = tip, span = 1 }
end
function Uld.View(b, s, classOf)
    local kind = b.def.kind
    if not s or not s.players then return nil end
    if kind == "sanity" then return SanityView(b, s, classOf) end
    if kind == "stacks" and ns.StackTips then return StacksView(b, s, classOf) end
    return nil
end
