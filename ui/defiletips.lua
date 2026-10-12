local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local TIMES = 8
local function T(key)
    return ns.T(key)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Clock(sec)
    return ns.BadgeTips.Clock(max(0, sec))
end
local function More(out, n)
    if n > TIMES then Put(out, "sub", (format(T("sum.tip.more"), n - TIMES):gsub("^%s+", ""))) end
end
local function Carry(st, def)
    local out = { { kind = "head", left = T(def.tip), right = format("x%d", st.n) } }
    Put(out, "row", T("sum.tt.defhurt"), tostring(st.hits), nil, "bad")
    Put(out, "row", T("sum.tt.dmg"), ns.BadgeTips.Short(st.amount))
    for k = 1, min(TIMES, st.n) do
        local grow, size = st.grow and st.grow[k] or 0, st.size and st.size[k] or 0
        Put(out, "sub", Clock(st.times[k]), format(T("sum.tt.defsize"), grow, size),
            format(T("sum.tt.defcnt"), st.cnt and st.cnt[k] or 0), "warn")
        Put(out, "sub", st.notes[k], nil, nil, "dim")
    end
    More(out, st.n)
    return out
end
local function Stood(st, def)
    local out = { { kind = "head", left = T(def.tip), right = format("x%d", st.n) } }
    Put(out, "row", T("sum.tt.defticks"), tostring(st.hits))
    Put(out, "row", T("sum.tt.dmg"), ns.BadgeTips.Short(st.amount))
    for k = 1, min(TIMES, st.n) do
        local ticks = st.ticks and st.ticks[k] or 0
        Put(out, "sub", Clock(st.times[k]), ns.BadgeTips.Short(st.dmgs and st.dmgs[k] or 0),
            format(T("sum.tt.defticks.n"), ticks), ticks > 1 and "bad" or "warn")
    end
    More(out, st.n)
    return out
end
function ns.ActionTips.defile(st, def)
    if def.part == "carry" then return Carry(st, def) end
    return Stood(st, def)
end
function ns.ActionTips.frenzy(st, def)
    local out = { { kind = "head", left = T(def.tip), right = format("x%d", st.n) } }
    for k = 1, min(TIMES, st.n) do
        Put(out, "sub", Clock(st.times[k]), format(T("sum.tt.frheld"), ns.Dec(st.notes[k] or "?")), nil, "warn")
    end
    More(out, st.n)
    return out
end
function ns.ActionTips.spirit(st, def)
    local out = { { kind = "head", left = T(def.tip), right = format("x%d", st.n) } }
    Put(out, "row", T("sum.tt.defhurt"), tostring(st.hits), nil, "bad")
    Put(out, "row", T("sum.tt.dmg"), ns.BadgeTips.Short(st.amount))
    for k = 1, min(TIMES, st.n) do
        Put(out, "sub", Clock(st.times[k]), ns.BadgeTips.Short(st.dmgs and st.dmgs[k] or 0),
            format(T("sum.tt.defcnt"), st.cnt and st.cnt[k] or 0), "warn")
        Put(out, "sub", st.notes[k], nil, nil, "dim")
    end
    More(out, st.n)
    return out
end
