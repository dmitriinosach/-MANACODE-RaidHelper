local _, ns = ...
local strmatch, strsub, gmatch, gsub, format = string.match, string.sub, string.gmatch, string.gsub, string.format
local floor, max, min = math.floor, math.max, math.min
local tsort, tconcat = table.sort, table.concat
local FORMAT = 13
local INDEX_KEY = "bober.index"
local ZONES = {
    icc = { "marrowgar", "deathwhisper", "saurfang", "festergut", "rotface", "putricide", "council", "lanathel",
        "valithria", "sindragosa", "lichking" },
    rs = { "halion" },
    toc = { "northrendbeasts", "jaraxxus", "champions", "valkyr", "anubarak" },
}
local LAST = { icc = "lichking", rs = "halion", toc = "anubarak" }
local CARD = { icc = { "saurfang", "putricide", "lichking" }, rs = { "halion" }, toc = { "anubarak" } }
local ENC_ALIAS = { beasts = "northrendbeasts", twins = "valkyr" }
local ROLE_ORDER = { "t", "h", "d" }
local Bober = {}
ns.Bober = Bober
Bober.FORMAT = FORMAT
Bober.ZONES = ZONES
local recs = {}
local blocks = {}
local files = {}
local benchCache = {}
local byName
local indexWait = {}
local codes
local function Root()
    local r = PlayerRaids13
    return type(r) == "table" and r or nil
end
local function Meta()
    local r = Root()
    local m = r and r.meta
    return type(m) == "table" and m or nil
end
local function Players()
    local r = Root()
    local p = r and r.players
    return type(p) == "table" and p or nil
end
function Bober.State()
    local m = Meta()
    local v = m and tonumber(m.v)
    if not v then
        local old = PlayerRaidsMeta
        v = type(old) == "table" and tonumber(old.v)
        if v and v ~= FORMAT then return "format", v end
        return "none", nil
    end
    if v ~= FORMAT then return "format", v end
    local p = Players()
    if not m.baked or m.baked == "" or not p or next(p) == nil then return "none", v end
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
function Bober.Mode(zone, size, heroic)
    return zone .. ((size or 25) > 10 and "25" or "10") .. (heroic and "h" or "n")
end
function Bober.Zone(mode)
    return strmatch(mode or "", "^(%a+)")
end
function Bober.Bosses(mode)
    return CARD[Bober.Zone(mode) or ""] or CARD.icc
end
function Bober.Last(mode)
    return LAST[Bober.Zone(mode) or ""] or LAST.icc
end
function Bober.Code(npc)
    if not codes and ns.ENC then
        local zoneOf, byNpc = {}, {}
        for zone, list in pairs(ZONES) do
            for i = 1, #list do zoneOf[list[i]] = zone end
        end
        for key, id in pairs(ns.ENC) do
            local code = ENC_ALIAS[key] or key
            if zoneOf[code] then byNpc[id] = code end
        end
        codes = { zone = zoneOf, npc = byNpc }
    end
    if not codes then return nil, nil end
    local code = npc and codes.npc[npc]
    if not code then return nil, nil end
    return code, codes.zone[code]
end
local function ModeInfo(sn, mode)
    local key = sn .. "." .. mode
    local hit = files[key]
    if hit ~= nil then return hit or nil end
    local r = Root()
    local m = r and type(r.modes) == "table" and r.modes[key]
    if type(m) ~= "table" or type(m.players) ~= "table" then
        files[key] = false
        return nil
    end
    local list, index = {}, {}
    for code in gmatch(type(m.bosses) == "string" and m.bosses or "", "[^,%s]+") do
        list[#list + 1] = code
        index[code] = #list
    end
    if #list == 0 then
        for i, code in ipairs(ZONES[Bober.Zone(mode) or ""] or {}) do index[code] = i end
    end
    hit = { file = m, index = index }
    files[key] = hit
    return hit
end
local function Cell(c, il)
    if not c or c == "" then return false end
    local role, v, p, i, flag = strmatch(c, "^([dht])(%d*):?(%d*):?(%d*):?(%w*)$")
    if not role then return false end
    return { role = role, value = tonumber(v), parse = tonumber(p), ilvl = tonumber(i) or il, unbuff = flag == "u" }
end
local function Stat(s)
    if not s or s == "" then return nil end
    local spec, _, _, better, of, avg, top, place, topOf = strsplit(",", s)
    local st = { spec = spec, better = tonumber(better), of = tonumber(of), avg = tonumber(avg),
        top = tonumber(top), place = tonumber(place), topOf = tonumber(topOf) }
    if not st.better and not st.top then return nil end
    return st
end
local function Season(id, sn, raw)
    local gs, last, spec, raids, _, _, _, _, stat = strsplit(";", raw)
    local s = { id = id, season = sn, gs = tonumber(gs), last = last, spec = spec ~= "" and spec or nil, raids = {},
        stat = Stat(stat), modes = {} }
    for entry in gmatch(raids or "", "[^,]+") do
        local mode, n = strmatch(entry, "^(%w+)%.(%d+)")
        if mode then s.raids[mode] = tonumber(n) end
    end
    return s
end
local function Block(id, sn)
    local key = id * 100 + sn
    local hit = blocks[key]
    if hit ~= nil then return hit or nil end
    local r = Root()
    local f = r and type(r.seasons) == "table" and r.seasons[sn]
    local raw = type(f) == "table" and type(f.players) == "table" and f.players[id]
    hit = type(raw) == "string" and raw ~= "" and Season(id, sn, raw) or false
    blocks[key] = hit
    return hit or nil
end
local function RaidDate(info, rid)
    local t = info.file.raids
    local raw = type(t) == "table" and rid and t[rid]
    return type(raw) == "string" and strmatch(raw, "^(%d*)") or ""
end
local function Raids(s, mode)
    local hit = s.modes[mode]
    if hit then return hit end
    local out = {}
    local info = ModeInfo(s.season, mode)
    local raw = info and info.file.players[s.id]
    local list = type(raw) == "string" and strmatch(raw, "^[^|]*|[^|]*|(.*)$")
    for entry in gmatch(list or "", "[^/]+") do
        local parts = { strsplit(",", entry) }
        local rid, il = tonumber(parts[1]), tonumber(parts[2])
        local cells = {}
        for b = 3, #parts do cells[b - 2] = Cell(parts[b], il) end
        out[#out + 1] = { rid = rid, ilvl = il, cells = cells, index = info.index, date = RaidDate(info, rid) }
    end
    s.modes[mode] = out
    return out
end
local function Hist(s)
    local out = {}
    for entry in gmatch(s or "", "[^/]+") do
        local mode, boss, kills = strmatch(entry, "^(%w+)%.(%a+)%.(%d+)")
        if mode then
            out[mode] = out[mode] or {}
            out[mode][boss] = tonumber(kills)
        end
    end
    return out
end
local function Row(id, raw)
    local name, class, _, hist = strmatch(raw, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if not name then return nil end
    local m = Meta()
    local cur = m and tonumber(m.season)
    return { id = id, name = name, class = class, hist = Hist(hist), cur = cur and Block(id, cur) or nil }
end
function Bober.Get(id)
    if not id or not Bober.Ready() then return nil end
    local hit = recs[id]
    if hit ~= nil then return hit or nil end
    local raw = Players()[id]
    local rec = type(raw) == "string" and Row(id, raw) or nil
    recs[id] = rec or false
    return rec
end
local function SeasonList()
    local m = Meta()
    local cur = m and tonumber(m.season)
    local list = {}
    for _, sn in ipairs(m and type(m.seasons) == "table" and m.seasons or {}) do
        sn = tonumber(sn)
        if sn then list[#list + 1] = sn end
    end
    if cur and #list == 0 then list[1] = cur end
    tsort(list, function(a, b) return a > b end)
    return list
end
local function Blocks(rec)
    local out = {}
    local list = SeasonList()
    for i = 1, #list do
        local s = Block(rec.id, list[i])
        if s then out[#out + 1] = s end
    end
    return out
end
local function MainRole(s, mode)
    local n = { d = 0, h = 0, t = 0 }
    for _, raid in ipairs(Raids(s, mode)) do
        for _, c in pairs(raid.cells) do
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
    local list = Blocks(rec)
    local spec
    for i = 1, #list do
        local r = MainRole(list[i], mode)
        if r then return r end
        spec = spec or list[i].spec
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
    if not rec or not boss then return out end
    out.role = role or Bober.Role(rec, mode) or "d"
    local list = {}
    local all = Blocks(rec)
    for k = 1, #all do
        for _, raid in ipairs(Raids(all[k], mode)) do
            local bi = raid.index[boss]
            local c = bi and raid.cells[bi]
            if c and c.value and c.role == out.role and not c.unbuff then
                list[#list + 1] = { v = c.value, il = raid.ilvl or c.ilvl, date = tonumber(raid.date) or 0 }
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
    for _, raid in ipairs(Raids(s, mode)) do
        for _, c in pairs(raid.cells) do
            local p = c and c.role == role and not c.unbuff and c.parse
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
    local cur = m and tonumber(m.season)
    if not cur or not mode or not boss then return nil end
    local key = mode .. "." .. boss
    local hit = benchCache[key]
    if hit ~= nil then return hit or nil end
    local out = false
    local info = ModeInfo(cur, mode)
    local all = info and info.file.bench
    local raw = type(all) == "table" and all[boss]
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
    local all = Players() or {}
    for id, raw in pairs(all) do
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
            if type(name) == "string" and all[id] then map[name] = id end
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
    recs, blocks, files, benchCache, byName = {}, {}, {}, {}, nil
end
local function LoadedModes()
    local m = Meta()
    local cur = m and tonumber(m.season)
    local r = Root()
    local out = {}
    for key in pairs(cur and r and type(r.modes) == "table" and r.modes or {}) do
        local sn, mode = strmatch(tostring(key), "^(%d+)%.(%w+)$")
        if tonumber(sn) == cur then out[#out + 1] = mode end
    end
    tsort(out)
    return #out > 0 and tconcat(out, ", ") or "-"
end
function Bober.Diag()
    local st, v = Bober.State()
    if st == "ok" then
        local m = Meta()
        return format(ns.T("bober.diag.ok"), Bober.Baked() or "?", tonumber(m.count) or 0, tostring(m.season),
            LoadedModes(), byName and ns.T("bober.diag.indexed") or "")
    end
    if st == "format" then return format(ns.T("bober.diag.format"), tostring(v), FORMAT) end
    return ns.T("bober.diag.none")
end
