local _, ns = ...
local format = string.format
local floor = math.floor
local min = math.min
local concat = table.concat
local ROWS = 6
local PEAKS = 12
local StackTips = {}
ns.StackTips = StackTips
local function T(key)
    return ns.T(key)
end
local function Plural(n, forms)
    if ns.Plural then return ns.Plural(n, forms) end
    local one, few, many = forms:match("^([^|]*)|([^|]*)|([^|]*)$")
    if not one then return forms end
    return ns.PluralPick(n, one, few, many)
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
local function Sec(v)
    return floor(v + 0.5)
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Phase(ep)
    if not ep.ph then return nil end
    if ep.lap then return format(T(ep.ph .. "n"), ep.lap) end
    return T(ep.ph)
end
local function Mixed(eps)
    local first = Phase(eps[1])
    for k = 2, #eps do
        if Phase(eps[k]) ~= first then return true end
    end
    return false
end
local function Ending(ep)
    local e = ep.e
    if e == "disp" or e == "hand" or e == "self" then return format(T("stk.e." .. e), ep.by or "?") end
    return T("stk.e." .. tostring(e))
end
local function Held(ep)
    local d, pd = Sec(ep.d), Sec(ep.pd)
    if ep.pk > 1 and pd < d then return format(T("stk.peakat"), ep.pk, d, pd) end
    return format(T("stk.peak"), ep.pk, d)
end
function StackTips.Badge(st, def)
    local eps = st.eps
    local out = {}
    out[1] = { kind = "head", left = T(def.tip) }
    local n = #eps
    local peaks, long, above = {}, eps[1], 0
    for k = 1, n do
        local e = eps[k]
        if k <= PEAKS then peaks[k] = tostring(e.pk) end
        if e.d > long.d then long = e end
        if st.over and e.pk > st.over then above = above + 1 end
    end
    local list = concat(peaks, "/") .. (n > PEAKS and "/..." or "")
    Put(out, "text", format(T("stk.sum"), n, Plural(n, T("stk.eps")), list, Sec(long.d), long.pk))
    if st.over then
        local times = above > 0 and format(Plural(above, T("stk.times")), above) or T("stk.never")
        Put(out, "row", format(T("stk.over"), st.over), times, nil, above > 0 and "warn" or "dim")
    end
    local phases = Mixed(eps)
    for k = 1, min(ROWS, n) do
        local e = eps[k]
        local left = Clock(e.t) .. "–" .. Clock(e.t + e.d)
        local ph = phases and Phase(e)
        if ph then left = left .. ", " .. ph end
        local tone = (st.over and e.pk > st.over) and "warn" or (e.e == "died" and "bad" or nil)
        Put(out, "sub", left, Ending(e), Held(e), tone)
    end
    if n > ROWS then Put(out, "sub", (format(T("sum.tip.more"), n - ROWS):gsub("^%s+", ""))) end
    return out
end
