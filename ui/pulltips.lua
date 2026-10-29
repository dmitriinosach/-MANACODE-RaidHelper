local _, ns = ...
local format = string.format
local min = math.min
local max = math.max
local concat = table.concat
local TIMES = 8
local NAMES = 3
local TONE = { green = "good", yellow = "warn", none = "dim" }
local PT = {}
ns.PullTips = PT
local function T(key)
    return ns.T(key)
end
local Clock = ns.Clock
local function Put(out, kind, left, right, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, tone = tone }
end
local function Outcome(u)
    if u.why == "late" then return T("sum.tt.pi.late"), "warn" end
    if u.why == "early" then return T("sum.tt.pi.early"), "warn" end
    if u.why == "wrong" then
        return u.aura and format(T("sum.tt.pi.wrong"), ns.SpellName(u.aura)) or T("sum.tt.pi.noaura"), "warn"
    end
    if u.why == "ended" then return format(T("sum.tt.pi.ended"), Clock(max(0, u.off or 0))), "warn" end
    if u.a then
        if u.since == nil then return T("sum.tt.pi.unknown"), "good" end
        if u.since < 0 then return T("sum.tt.pi.aurapull"), "good" end
        return format(T("sum.tt.pi.aura"), Clock(u.since)), "good"
    end
    return u.took and u.took > 0 and format(T("sum.tt.pi.took"), ns.Short(u.took)) or nil, "good"
end
local function UseLine(out, u)
    local name = ns.SpellName(u.id)
    local left = u.a and format("%s %s–%s", name, Clock(u.a), Clock(u.b)) or format("%s %s", name, Clock(u.t))
    local right, tone = Outcome(u)
    Put(out, "sub", left, right, tone)
end
local function Ep(out, e, g)
    Put(out, "row", Clock(e.te), format(T("sum.tt.pi.hit"), ns.Short(e.dmg), e.hits), TONE[g or "none"])
    for q = 1, #e.uses do UseLine(out, e.uses[q]) end
    for q = 1, #e.ready do
        Put(out, "sub", ns.SpellName(e.ready[q]), T("sum.tt.pi.ready"), g == "yellow" and "warn" or "dim")
    end
    for q = 1, #e.cd do
        Put(out, "sub", ns.SpellName(e.cd[q].id), format(T("sum.tt.pi.cd"), Clock(e.cd[q].at)), "dim")
    end
    for q = 1, #e.never do Put(out, "sub", ns.SpellName(e.never[q]), T("sum.tt.pi.never"), "dim") end
    if #e.died > 0 then
        local names = {}
        for q = 1, min(NAMES, #e.died) do names[q] = e.died[q] end
        local who = concat(names, ", ") .. (#e.died > NAMES and format(T("sum.tip.more"), #e.died - NAMES) or "")
        Put(out, "sub", format(T("sum.tt.pi.died"), #e.died), who, "bad")
    end
end
function PT.Lines(st, def, left, class)
    local out = {}
    out[1] = { kind = "head", left = left or T(def.tip), right = format(T("sum.tt.of"), st.hits, st.n), class = class }
    for k = 1, min(TIMES, st.n) do
        local e = st.eps and st.eps[k]
        if e then Ep(out, e, st.grades and st.grades[k]) end
    end
    if st.n > TIMES then Put(out, "sub", (format(T("sum.tip.more"), st.n - TIMES):gsub("^%s+", ""))) end
    return out
end
function PT.Badge(st, def)
    return PT.Lines(st, def)
end
function PT.Text(b, who, v)
    local g = b.pull and b.pull[who]
    local text = format(T("sum.tt.of"), v, b.total)
    if g == "yellow" or g == "green" then return ns.Kit.Hex("badge." .. g) .. text .. "|r" end
    return text
end
function PT.Row(s, b, who, class)
    local p = s.byName and s.byName[who]
    for i = 1, #(s.badges or {}) do
        local st = s.badges[i].kind == "pullin" and p and p.badges[i]
        if st then return PT.Lines(st, s.badges[i], who, class) end
    end
    return { { kind = "head", left = who, right = PT.Text(b, who, b.by[who] or 0), class = class } }
end
