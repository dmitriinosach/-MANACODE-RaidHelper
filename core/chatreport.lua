local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local SIZES = { 5, 10, 25 }
local CHANNELS = { "RAID", "PARTY", "GUILD", "OFFICER", "SAY", "WHISPER" }
local KNOWN = { RAID = true, PARTY = true, GUILD = true, OFFICER = true, SAY = true, WHISPER = true }
local Report = {}
ns.ChatReport = Report
Report.SIZES = SIZES
Report.CHANNELS = CHANNELS
local function T(key)
    return ns.T(key)
end
local function Num(n)
    return ns.Short(n, 1, false)
end
local Clock = ns.Clock
local function Saved()
    local s = ns.GetDB().settings
    if type(s.report) ~= "table" then s.report = {} end
    return s.report
end
function Report.Size()
    local n = Saved().n
    for i = 1, #SIZES do
        if SIZES[i] == n then return n end
    end
    return 10
end
function Report.SetSize(n)
    for i = 1, #SIZES do
        if SIZES[i] == n then Saved().n = n end
    end
end
function Report.Channel()
    local c = Saved().ch
    return KNOWN[c or ""] and c or "RAID"
end
function Report.SetChannel(c)
    if KNOWN[c or ""] then Saved().ch = c end
end
function Report.Lines(head, sec, list, n)
    tsort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.who < b.who
    end)
    local total = 0
    for i = 1, #list do total = total + list[i].v end
    sec = max(1, sec)
    local out = { head }
    for i = 1, min(n, #list) do
        local e = list[i]
        out[#out + 1] = format(T("report.row"), i, e.who, Num(e.v / sec), Num(e.v),
            floor(e.v * 100 / max(1, total) + 0.5))
    end
    return out
end
function Report.Summary(fight, s, n, heal)
    local list = {}
    for i = 1, #s.players do
        local p = s.players[i]
        local v = (heal and p.heal or p.goodDmg or p.dmg) or 0
        if v > 0 then list[#list + 1] = { who = p.name, v = v } end
    end
    local head = format(T(heal and "report.head.heal" or "report.head"), ns.EncName(fight.boss),
        T(fight.killed and "report.kill" or "report.wipe"), Clock(s.dur))
    return Report.Lines(head, ns.Totals.Time(s), list, n)
end
function Report.Live(n, heal)
    local M = ns.Meter
    local list = {}
    local by = M and (heal and M.heals or M.who) or {}
    for who, v in pairs(by) do
        if v > 0 then list[#list + 1] = { who = who, v = v } end
    end
    local sec = M and M.FightTime() or 1
    return Report.Lines(format(T(heal and "report.head.live.heal" or "report.head.live"), Clock(sec)), sec, list, n)
end
function Report.Send(lines, want)
    if not KNOWN[want or ""] or #lines < 2 then return 0 end
    Saved().ch = want
    local target
    if want == "WHISPER" then
        target = UnitExists("target") and UnitIsPlayer("target") and UnitName("target") or nil
        if not target then
            ns.Print(T("report.err.target"))
            return 0
        end
    end
    return (ns.Proof.SendLines(lines, want, target, "report"))
end
local LIMIT = 255
function Report.Plain(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|", ""):gsub("[\r\n]+", " "):gsub("%s%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
function Report.Fit(s)
    if #s <= LIMIT then return s end
    local cut = LIMIT - 3
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return s:sub(1, cut) .. "…"
end
function Report.FightCtx(fight, s)
    return format(T("report.ctx.fight"), ns.EncName(fight.boss), T(fight.killed and "report.kill" or "report.wipe"),
        Clock(s and s.dur or 0))
end
function Report.RaidCtx(raid)
    local head = format(T("dc.raid"), ns.Raid.Title(raid), raid.size or 0, raid.heroic and T("dc.hc") or "")
    return raid.from and (head .. ", " .. ns.Date(raid.from)) or head
end
function Report.Detail(title, ctx, rows, n)
    title = Report.Plain(title)
    if ctx == "" then ctx = nil end
    local out = { Report.Fit(ctx and format(T("report.head.detail"), title, Report.Plain(ctx)) or "MRH: " .. title) }
    for i = 1, min(n, #rows) do
        local r = rows[i]
        local line = format("%d. %s %s", i, Report.Plain(r.who), Report.Plain(r.val))
        local rest = {}
        for k = 1, #(r.rest or {}) do
            local x = Report.Plain(r.rest[k])
            if x ~= "" then rest[#rest + 1] = x end
        end
        if #rest > 0 then line = line .. " (" .. table.concat(rest, ", ") .. ")" end
        out[#out + 1] = Report.Fit((line:gsub("%s+$", "")))
    end
    return out
end
function Report.Can(c)
    local raid = (GetNumRaidMembers() or 0) > 0
    if c == "RAID" then return raid end
    if c == "PARTY" then return raid or (GetNumPartyMembers() or 0) > 0 end
    if c == "GUILD" or c == "OFFICER" then return IsInGuild() and true or false end
    if c == "WHISPER" then return (UnitExists("target") and UnitIsPlayer("target")) and true or false end
    return KNOWN[c or ""] == true
end
function Report.SendNow(lines, want)
    if not KNOWN[want or ""] or #lines < 2 then return 0 end
    local target = want == "WHISPER" and UnitExists("target") and UnitIsPlayer("target") and UnitName("target") or nil
    local n, err = ns.Proof.SendLines(lines, want, target, "report")
    if not err then Saved().ch = want end
    return n
end
