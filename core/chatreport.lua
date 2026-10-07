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
    if n >= 1e6 then return format("%.1f", n / 1e6) .. T("num.m") end
    if n >= 1e3 then return format("%.1f", n / 1e3) .. T("num.k") end
    return tostring(floor(n + 0.5))
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
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
        local v = (heal and p.heal or p.dmg) or 0
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
