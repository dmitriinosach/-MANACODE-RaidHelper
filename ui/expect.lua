local _, ns = ...
local format = string.format
local floor = math.floor
local View = {}
ns.ExpectView = View
local function Short(n)
    return ns.BadgeTips.Short(n)
end
local function Tone(got, exp, kill)
    if not kill then return "text.muted" end
    local k = got / math.max(1, exp)
    if k >= ns.Tune("expectGood") / 100 then return "badge.green" end
    if k >= ns.Tune("expectFair") / 100 then return "badge.yellow" end
    return "badge.red"
end
local function Get(fight, s)
    if not ns.Expect then return nil end
    return ns.Expect.Of(fight, s, function()
        if ns.SummaryView and ns.SummaryView.Fight() == fight then ns.SummaryView.Refresh() end
    end)
end
local function Insert(lines, add)
    if not lines then return end
    local at = #lines + 1
    if lines[#lines] and lines[#lines].kind == "foot" then at = #lines end
    for i = 1, #add do
        table.insert(lines, at, add[i])
        at = at + 1
    end
end
local function Source(res, out)
    local B = ns.Bober
    out[#out + 1] = { kind = "note", left = format(ns.T("exp.tt.src"), ns.T("exp.mode." .. res.mode),
        B.Baked() or "?") }
    if not res.kill then out[#out + 1] = { kind = "note", left = ns.T("exp.tt.wipe") } end
end
function View.Personal(fight, s, p, m)
    if p.role ~= "dps" then return end
    local res = Get(fight, s)
    local row = res and res.by[p.name]
    if not row or row.role == "h" then return end
    local tone = Tone(row.got, row.exp, res.kill)
    local key = res.kill and "exp.personal" or "exp.personal.wipe"
    m.sub = (m.sub ~= "" and (m.sub .. "  ") or "") .. ns.Kit.Hex(tone) .. format(ns.T(key), Short(row.exp)) .. "|r"
    local right = Short(row.exp)
    if res.kill then
        right = format(ns.T("exp.tt.expof"), right, floor(row.got * 100 / math.max(1, row.exp) + 0.5))
    end
    Insert(m.lines, { { kind = "sep" },
        { kind = "row", left = ns.T("exp.tt.exp"), right = right,
          tone = res.kill and (tone == "badge.green" and "good" or (tone == "badge.red" and "bad" or nil)) or nil },
        { kind = "sub", left = format(ns.T("exp.tt.kills"), row.n), tone = "dim" } })
end
function View.Total(fight, s, m)
    local res = Get(fight, s)
    if not res or res.have == 0 then return end
    local tone = Tone(res.got, res.sum, res.kill)
    local key = res.kill and "exp.total" or "exp.total.wipe"
    m.subs = m.subs or {}
    m.subs[#m.subs + 1] = ns.Kit.Hex(tone) .. format(ns.T(key), Short(res.sum)) .. "|r"
    local out = { { kind = "head", left = ns.T("exp.tt.head") },
        { kind = "row", left = ns.T("exp.tt.sum"), right = Short(res.sum) },
        { kind = "sub", left = format(ns.T("exp.tt.have"), res.have, res.of) },
        { kind = "row", left = ns.T("exp.tt.they"), right = Short(res.got) } }
    if res.kill then
        out[#out + 1] = { kind = "row", left = ns.T("exp.tt.ratio"),
            right = format("%d%%", floor(res.got * 100 / math.max(1, res.sum) + 0.5)) }
    end
    if res.pctExp then out[#out + 1] = { kind = "row", left = ns.T("exp.tt.pctexp"), right = tostring(floor(res.pctExp)) } end
    if res.pctAll then
        out[#out + 1] = { kind = "row", left = ns.T("exp.tt.pctall"), right = tostring(floor(res.pctAll)) }
        out[#out + 1] = { kind = "sub", left = format(ns.T("exp.tt.all"), Short(res.all)) }
    end
    out[#out + 1] = { kind = "sep" }
    Source(res, out)
    if not m.lines then
        m.lines = out
        return
    end
    m.lines[#m.lines + 1] = { kind = "sep" }
    for i = 1, #out do m.lines[#m.lines + 1] = out[i] end
end
