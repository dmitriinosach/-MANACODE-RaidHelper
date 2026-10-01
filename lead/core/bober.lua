local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local B = {}
ns.Bober = B
local BOSSES = { "lich", "prof", "surf", "hal" }
local ROLE = { tank = "t", heal = "h", melee = "d", ranged = "d" }
local PARSE = {
    { 100, "parse.p100" }, { 99, "parse.p99" }, { 95, "parse.p95" },
    { 75, "parse.p75" }, { 50, "parse.p50" }, { 25, "parse.p25" },
}
local CACHE_MAX = 400
local cache = {}
local cached = 0
local waiting = false
local function src()
    local b = root.Bober
    if b and b.Ready() then return b end
    return nil
end
function B.Ready()
    return src() ~= nil
end
function B.Reset()
    cache = {}
    cached = 0
end
local function prefs()
    local db = ns.Store.DB()
    db.bober = db.bober or {}
    return db.bober
end
local function defaultPick(tpl)
    local key = tpl.base or tpl.key or ""
    local big = (tpl.size or 25) > 10
    if key:find("^rs") then return (big and "rh" or "qh") .. ".hal" end
    return (big and "ih" or "jh") .. ".lich"
end
function B.Pick()
    local tpl = ns.Session.Template()
    local v = prefs()[tpl.key] or defaultPick(tpl)
    local mode, boss = v:match("^(%a+)%.(%a+)$")
    return mode, boss, v
end
function B.SetPick(v)
    prefs()[ns.Session.Template().key] = v
    B.Reset()
    ns.Session.Changed()
end
function B.Label(mode, boss)
    return ns.T("bbPick", ns.T("bbBoss_" .. boss), ns.T("bbMode_" .. mode))
end
function B.Options()
    local bb = src()
    local out = {}
    if not bb then return out end
    local tpl = ns.Session.Template()
    for _, hard in ipairs({ true, false }) do
        for _, boss in ipairs(BOSSES) do
            local mode = bb.Mode(tpl.size, hard, boss == "hal")
            out[#out + 1] = { key = mode .. "." .. boss, label = B.Label(mode, boss) }
        end
    end
    return out
end
local function roleOf(name, spec)
    local key = spec or ns.Session.Player(name).spec
    local sp = key and ns.SPEC[key]
    return sp and ROLE[sp.role] or nil
end
local function onIndex()
    waiting = false
    B.Reset()
    ns.Session.Changed()
end
local function idOf(bb, name, unit)
    local guid = unit and ns.Compat.UnitGuid(unit)
    local id = guid and bb.IdFromGuid(guid)
    if id and bb.Get(id) then return id, false end
    local found, pending = bb.FindId(name, not waiting and onIndex or nil)
    if pending then waiting = true end
    return found, pending
end
local function short(n)
    if n >= 1000 then return ns.T("bbThousand", n / 1000) end
    return tostring(math.floor(n + 0.5))
end
B.Short = short
local function day(d)
    local y, m, dd = tostring(d or ""):match("^(%d%d)(%d%d)(%d%d)$")
    if not y then return nil end
    return dd .. "." .. m .. "." .. y
end
local function tipLines(bb, rec, mode, boss, role)
    local out = { ns.T("bbTipHead", ns.T("bbMode_" .. mode)) }
    local s = rec.cur
    out[#out + 1] = ns.T("bbTipRaids", s and s.raids[mode] or 0)
    local last = bb.IsRS(mode) and "hal" or "lich"
    out[#out + 1] = ns.T("bbTipKills", ns.T("bbBoss_" .. last), bb.Kills(rec, mode, last))
    local parts = {}
    for _, b in ipairs(bb.Bosses(mode)) do
        local st = bb.Stat(rec, mode, b, role)
        if st.avg then parts[#parts + 1] = ns.T("bbBoss_" .. b) .. " " .. short(st.avg) end
    end
    if #parts > 0 then
        out[#out + 1] = ns.T(role == "h" and "bbTipAvgH" or "bbTipAvgD", table.concat(parts, ", "))
    end
    local seen = day(s and s.last)
    if seen then out[#out + 1] = ns.T("bbTipLast", seen) end
    local st = s and s.stat
    if st and st.place and st.topOf then
        out[#out + 1] = ns.T("bbTipPlace", st.place, st.topOf, tostring(st.top or "?"))
    end
    out[#out + 1] = ns.T("bbTipBaked", bb.Baked() or "?")
    return out
end
function B.Info(name, unit, spec)
    local bb = src()
    if not bb or not name then return nil end
    local mode, boss, key = B.Pick()
    local ck = name .. "|" .. key .. "|" .. tostring(spec or ns.Session.Player(name).spec)
    local hit = cache[ck]
    if hit then return hit end
    local id, pending = idOf(bb, name, unit)
    if pending then return nil end
    local rec = bb.Get(id)
    local info = { found = rec ~= nil, mode = mode, boss = boss }
    if rec then
        info.parse = bb.BestParse(rec, mode)
        info.role = roleOf(name, spec) or bb.Role(rec, mode) or "d"
        local st = bb.Stat(rec, mode, boss, info.role)
        info.exp, info.n = st.avg, st.n
        info.lines = tipLines(bb, rec, mode, boss, info.role)
    else
        info.role = roleOf(name, spec)
        info.lines = { ns.T("bbTipHead", ns.T("bbMode_" .. mode)), ns.T("bbTipNone") }
    end
    if cached >= CACHE_MAX then B.Reset() end
    cached = cached + 1
    cache[ck] = info
    return info
end
local function parseTone(p)
    for _, e in ipairs(PARSE) do
        if p >= e[1] then return e[2] end
    end
    return "parse.low"
end
function B.ParseText(name, unit, spec)
    local info = B.Info(name, unit, spec)
    if not info then return nil end
    if not info.found then return ns.Hex("text.muted") .. ns.T("bbNotInLogs") .. "|r" end
    if not info.parse then return ns.Hex("text.muted") .. ns.T("bbNoMode") .. "|r" end
    return ns.Hex(parseTone(info.parse)) .. info.parse .. "|r"
end
function B.ExpText(name, unit)
    local info = B.Info(name, unit)
    if not info or not info.exp then return nil end
    return ns.Hex(info.role == "h" and "text.muted" or "text.primary") .. short(info.exp) .. "|r"
end
function B.Tip(base, name, unit, spec)
    local info = B.Info(name, unit, spec)
    if not info then return base end
    local lines = {}
    if base and base ~= "" then lines[1] = base end
    if info.exp then
        lines[#lines + 1] = ns.T(info.role == "h" and "bbTipExpH" or "bbTipExpD",
            B.Label(info.mode, info.boss), short(info.exp), info.n or 0)
    end
    for _, l in ipairs(info.lines) do lines[#lines + 1] = l end
    return table.concat(lines, "\n")
end
function B.Sum(members)
    local out = { sum = 0, have = 0, of = 0 }
    for _, m in ipairs(members) do
        local info = B.Info(m.name, m.unit)
        local role = (info and info.role) or roleOf(m.name)
        if role ~= "h" then
            out.of = out.of + 1
            if info and info.exp then
                out.sum = out.sum + info.exp
                out.have = out.have + 1
            end
        end
    end
    return out
end
function B.Raid(members)
    local bb = src()
    if not bb then return nil end
    local work = {}
    for _, m in ipairs(members) do
        if m.work then work[#work + 1] = m end
    end
    local out = B.Sum(work)
    local mode, boss = B.Pick()
    out.mode, out.boss = mode, boss
    local bench = bb.Bench(mode, boss)
    if bench and out.sum > 0 then out.pct = math.floor(bb.Percent(bench, out.sum)) end
    return out
end
