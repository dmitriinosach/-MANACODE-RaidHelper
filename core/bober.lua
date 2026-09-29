local _, ns = ...
local strmatch, strsub, gmatch, gsub, format = string.match, string.sub, string.gmatch, string.gsub, string.format
local floor, max, min = math.floor, math.max, math.min
local tsort, tinsert = table.sort, table.insert
local FORMAT = 12
local INDEX_KEY = "bober.index"
local MODES = { "ih", "iu", "in", "rh", "rn", "jh", "ju", "jn", "qh", "qn" }
local RS = { rh = true, rn = true, qh = true, qn = true }
local CELL = { surf = 1, prof = 2, lich = 3, hal = 1 }
local ICC_BOSSES = { "surf", "prof", "lich" }
local RS_BOSSES = { "hal" }
local ROLE_ORDER = { "t", "h", "d" }
local Bober = {}
ns.Bober = Bober
Bober.FORMAT = FORMAT
Bober.ICC_BOSSES = ICC_BOSSES
Bober.RS_BOSSES = RS_BOSSES
Bober.CODE = {
    ["Саурфанг Смертоносный"] = "surf",
    ["Профессор Мерзоцид"] = "prof",
    ["Король-лич"] = "lich",
    ["Халион"] = "hal",
}
local recs = {}
local arch = {}
local benchCache = {}
local byName
local indexWait = {}
local modeList
local function Meta()
    local m = PlayerRaidsMeta
    return type(m) == "table" and m or nil
end
function Bober.State()
    local m = Meta()
    if not m or type(PlayerRaidsData) ~= "table" then return "none", nil end
    local v = tonumber(m.v)
    if v ~= FORMAT then return "format", v end
    if not m.baked or m.baked == "" or next(PlayerRaidsData) == nil then return "none", v end
    return "ok", v
end
function Bober.Ready()
    return (Bober.State()) == "ok"
end
function Bober.Baked()
    local m = Meta()
    local b = m and m.baked
    if type(b) ~= "string" then return nil end
    local y, mo, d = strmatch(b, "^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not y then return nil end
    return format("%s.%s.%s", d, mo, y)
end
function Bober.IdFromGuid(guid)
    if type(guid) ~= "string" or #guid < 8 then return nil end
    return tonumber(strsub(guid, 7), 16)
end
function Bober.IsRS(mode)
    return RS[mode] or false
end
function Bober.Mode(size, heroic, rs)
    local big = (size or 25) > 10
    if rs then
        if big then return heroic and "rh" or "rn" end
        return heroic and "qh" or "qn"
    end
    if big then return heroic and "ih" or "in" end
    return heroic and "jh" or "jn"
end
function Bober.Bosses(mode)
    return RS[mode] and RS_BOSSES or ICC_BOSSES
end
local function ModeOrder()
    if modeList then return modeList end
    local m = Meta()
    local raw = m and m.modes
    if type(raw) == "table" then raw = table.concat(raw, ",") end
    local list = {}
    for mode in gmatch(type(raw) == "string" and raw or "", "%a+") do list[#list + 1] = mode end
    if #list == 0 then list = MODES end
    modeList = list
    return list
end
local function Cell(c)
    if not c or c == "" then return false end
    local role, v, p, g, i, o = strmatch(c, "^([dht])(%d*):?(%d*):?(%d*):?(%d*):?(%d*)$")
    if not role then return false end
    return { role = role, value = tonumber(v), parse = tonumber(p), gear = tonumber(g), ilvl = tonumber(i),
        our = tonumber(o) }
end
local function Hist(s)
    local out = {}
    for mode, boss, kills in gmatch(s or "", "(%a+)%.(%a+)%.(%d+)") do
        out[mode] = out[mode] or {}
        out[mode][boss] = tonumber(kills)
    end
    return out
end
local function Stat(s)
    if not s or s == "" then return nil end
    local spec, _, _, better, of, avg, top, place, topOf = strsplit(",", s)
    local st = { spec = spec, better = tonumber(better), of = tonumber(of), avg = tonumber(avg),
        top = tonumber(top), place = tonumber(place), topOf = tonumber(topOf) }
    if not st.better and not st.top then return nil end
    return st
end
local function Season(block)
    local sn, gs, last, spec, raids, _, _, list, _, _, _, _, stat = strsplit(";", block)
    local s = { season = tonumber(sn), gs = tonumber(gs), last = last, spec = spec, raids = {}, byMode = {},
        stat = Stat(stat) }
    local r = { strsplit(",", raids or "") }
    local order = ModeOrder()
    for i = 1, #order do s.raids[order[i]] = tonumber(r[i]) or 0 end
    for entry in gmatch(list or "", "[^/]+") do
        local body = strmatch(entry, "^(.-),#%-?%d+$") or entry
        local date, mode, _, c1, c2, c3 = strsplit(",", body)
        if mode then
            local byMode = s.byMode[mode]
            if not byMode then
                byMode = {}
                s.byMode[mode] = byMode
            end
            byMode[#byMode + 1] = { date = date, mode = mode, cells = { Cell(c1), Cell(c2), Cell(c3) } }
        end
    end
    return s
end
local function Row(id, raw)
    local name, class, _, hist, rest = strmatch(raw, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|[^|]*|[^|]*|?(.*)$")
    if not name then return nil end
    local rec = { id = id, name = name, class = class, hist = Hist(hist) }
    local block = rest and strmatch(rest, "^([^|]+)")
    if block and block ~= "" then rec.cur = Season(block) end
    return rec
end
function Bober.Get(id)
    if not id or not Bober.Ready() then return nil end
    local hit = recs[id]
    if hit ~= nil then return hit or nil end
    local raw = PlayerRaidsData[id]
    local rec = type(raw) == "string" and Row(id, raw) or nil
    recs[id] = rec or false
    return rec
end
local function Archived(rec, sn)
    local t = type(PlayerRaidsArchive) == "table" and PlayerRaidsArchive[sn]
    if type(t) ~= "table" then return nil end
    local key = rec.id * 100 + sn
    local hit = arch[key]
    if hit == nil then
        local raw = t[rec.id]
        hit = type(raw) == "string" and raw ~= "" and Season(raw) or false
        arch[key] = hit
    end
    return hit or nil
end
local function Blocks(rec)
    local m = Meta()
    local cur = m and tonumber(m.season)
    local list = {}
    for _, sn in ipairs(m and m.seasons or {}) do
        sn = tonumber(sn)
        if sn then list[#list + 1] = sn end
    end
    if cur and #list == 0 then list[1] = cur end
    tsort(list, function(a, b) return a > b end)
    local out = {}
    for i = 1, #list do
        local sn = list[i]
        local s
        if sn == cur then s = rec.cur else s = Archived(rec, sn) end
        if s then out[#out + 1] = s end
    end
    return out
end
local function RaidIlvl(raid)
    local best
    for b = 1, 3 do
        local c = raid.cells[b]
        if c and c.ilvl and (not best or c.ilvl > best) then best = c.ilvl end
    end
    return best
end
local function MainRole(s, mode)
    local n = { d = 0, h = 0, t = 0 }
    for _, raid in ipairs(s.byMode[mode] or {}) do
        for b = 1, 3 do
            local c = raid.cells[b]
            if c and n[c.role] then n[c.role] = n[c.role] + 1 end
        end
    end
    local best, bestN = nil, 0
    for i = 1, #ROLE_ORDER do
        local r = ROLE_ORDER[i]
        if n[r] > bestN then best, bestN = r, n[r] end
    end
    return best
end
local function SpecRole(spec)
    local key = (spec or ""):lower():gsub("[%s_%-]", "")
    if key == "holy" or key == "discipline" or key == "restoration" then return "h" end
    if key == "protection" or key == "guardian" then return "t" end
    return "d"
end
function Bober.Role(rec, mode)
    if not rec then return nil end
    local blocks = Blocks(rec)
    local spec
    for i = 1, #blocks do
        local r = MainRole(blocks[i], mode)
        if r then return r end
        spec = spec or blocks[i].spec
    end
    if spec then return SpecRole(spec) end
    return nil
end
local function PickRecent(list)
    tsort(list, function(x, y) return x.date > y.date end)
    local out = {}
    local ref = list[1] and list[1].il
    local i = 1
    while list[i] do
        local e = list[i]
        if ref and e.il and e.il < ref - 2 then break end
        out[#out + 1] = e
        i = i + 1
    end
    if #out < 3 then
        while list[i] and #out < 5 do
            out[#out + 1] = list[i]
            i = i + 1
        end
    end
    return out, ref
end
function Bober.Stat(rec, mode, boss, role)
    local out = {}
    local bi = CELL[boss]
    if not rec or not bi then return out end
    out.role = role or Bober.Role(rec, mode) or "d"
    local list = {}
    local blocks = Blocks(rec)
    for k = 1, #blocks do
        for _, raid in ipairs(blocks[k].byMode[mode] or {}) do
            local c = raid.cells[bi]
            if c and c.value and c.role == out.role then
                list[#list + 1] = { v = c.value, il = RaidIlvl(raid), date = tonumber(raid.date) or 0 }
            end
        end
    end
    local picked, ref = PickRecent(list)
    if #picked == 0 then return out end
    local sum, mn = 0, nil
    for i = 1, #picked do
        local v = picked[i].v
        sum = sum + v
        if not mn or v < mn then mn = v end
    end
    out.avg, out.min, out.n, out.ilvl = floor(sum / #picked + 0.5), mn, #picked, ref
    return out
end
function Bober.BestParse(rec, mode)
    local s = rec and rec.cur
    if not s then return nil, nil end
    local role = MainRole(s, mode)
    local best
    for _, raid in ipairs(s.byMode[mode] or {}) do
        for b = 1, 3 do
            local c = raid.cells[b]
            local p = c and c.role == role and (c.parse or c.our)
            if p and (not best or p > best) then best = p end
        end
    end
    return best, role
end
function Bober.Kills(rec, mode, boss)
    local h = rec and rec.hist[mode]
    return h and h[boss] or 0
end
function Bober.Bench(mode, boss)
    local m = Meta()
    local all = m and m.bench
    if type(all) ~= "table" or not mode or not boss then return nil end
    local key = mode .. "." .. boss
    local hit = benchCache[key]
    if hit ~= nil then return hit or nil end
    local out = false
    local raw = all[key]
    if type(raw) == "string" then
        local c, _, _, n = strsplit("|", raw)
        local cuts = {}
        for v in gmatch(c or "", "[%d%.]+") do cuts[#cuts + 1] = tonumber(v) end
        if #cuts == 9 then out = { cuts = cuts, n = tonumber(n) or 0 } end
    end
    benchCache[key] = out
    return out or nil
end
function Bober.Percent(bench, v)
    local c = bench.cuts
    if not v or v <= 0 then return 0 end
    if v < c[1] then return 10 * v / c[1] end
    for k = 1, 8 do
        if v < c[k + 1] then return 10 * k + 10 * (v - c[k]) / max(c[k + 1] - c[k], 1) end
    end
    return min(90 + 10 * (v - c[9]) / max(c[9] - c[8], 1), 99)
end
local function Put(map, name, id)
    if name ~= "" and not map[name] then map[name] = id end
end
local function BuildIndex(step)
    local map, prevs = {}, {}
    for id, raw in pairs(PlayerRaidsData) do
        if step then step() end
        local name, prev = strmatch(raw, "^([^|]*)|[^|]*|([^|]*)")
        if name then
            Put(map, name, id)
            if prev ~= "" then prevs[id] = prev end
        end
    end
    for id, prev in pairs(prevs) do
        if step then step() end
        for old in gmatch(prev, "[^,]+") do Put(map, (gsub(old, ":.*$", "")), id) end
    end
    local own = type(PlayerRaidsDB) == "table" and PlayerRaidsDB.names
    if type(own) == "table" then
        for id, name in pairs(own) do
            if type(name) == "string" and PlayerRaidsData[id] then map[name] = id end
        end
    end
    return map
end
local function IndexDone()
    local list = indexWait
    indexWait = {}
    for i = 1, #list do list[i]() end
end
local function StartIndex(fn)
    if fn then indexWait[#indexWait + 1] = fn end
    local jobs = ns.Jobs
    if not jobs then
        byName = BuildIndex(nil)
        IndexDone()
        return
    end
    jobs.Run(INDEX_KEY, function()
        jobs.Label("job.bober")
        return BuildIndex(jobs.Step)
    end, function(map)
        byName = map or {}
        IndexDone()
    end)
end
function Bober.FindId(name, onReady)
    if not name or name == "" or not Bober.Ready() then return nil, false end
    if byName then return byName[name], false end
    StartIndex(onReady)
    return nil, true
end
function Bober.WhenIndexed(fn)
    if byName then
        fn()
    elseif Bober.Ready() then
        StartIndex(fn)
    end
end
function Bober.Indexed()
    return byName ~= nil
end
function Bober.Reset()
    recs, arch, benchCache, byName, modeList = {}, {}, {}, nil, nil
end
function Bober.Diag()
    local st, v = Bober.State()
    if st == "ok" then
        local m = Meta()
        return format(ns.T("bober.diag.ok"), Bober.Baked() or "?", tonumber(m.count) or 0, byName and ns.T("bober.diag.indexed") or "")
    end
    if st == "format" then return format(ns.T("bober.diag.format"), tostring(v), FORMAT) end
    return ns.T("bober.diag.none")
end
