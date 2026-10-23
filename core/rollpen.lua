local _, ns = ...
local format = string.format
local gsub = string.gsub
local tsort = table.sort
local tremove = table.remove
local KEEP = 40
local LIMIT = 255
local Roll = {}
ns.RollPen = Roll
local throws = {}
local seen = {}
local listeners = {}
local pattern
local frame
local listening = false
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
function Roll.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Pattern()
    if pattern ~= nil then return pattern end
    local f = _G.RANDOM_ROLL_RESULT
    if type(f) ~= "string" or f == "" then
        pattern = false
        return false
    end
    local p = gsub(f, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = gsub(p, "%%%%s", "(.+)")
    p = gsub(p, "%%%%d", "(%%d+)")
    pattern = "^" .. p .. "$"
    return pattern
end
function Roll.Parse(msg)
    local p = Pattern()
    if not p or type(msg) ~= "string" then return nil end
    local who, n, lo, hi = msg:match(p)
    n, lo, hi = tonumber(n), tonumber(lo), tonumber(hi)
    if not who or not n or not lo or not hi then return nil end
    return who, n, lo, hi
end
function Roll.OnSystem(msg)
    local who, n, lo, hi = Roll.Parse(msg)
    if not who or seen[who] then return end
    seen[who] = true
    throws[#throws + 1] = { who = who, n = n, lo = lo, hi = hi, t = time() }
    while #throws > KEEP do
        seen[throws[1].who] = nil
        tremove(throws, 1)
    end
    Notify()
end
function Roll.Clear()
    for i = #throws, 1, -1 do throws[i] = nil end
    for k in pairs(seen) do seen[k] = nil end
    Notify()
end
function Roll.Sums(raid, alt)
    local set = type(raid) == "table" and raid or nil
    local rows = set and ns.Ledger.Log() or ns.Ledger.Log(raid, alt)
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        if r.s == "roll" and r.who and (not set or set[r.raid or ""]) then out[r.who] = (out[r.who] or 0) + (r.n or 0) end
    end
    for who, n in pairs(out) do
        if n <= 0 then out[who] = nil end
    end
    return out
end
function Roll.KeysOf(fight)
    local r = fight and fight.raid
    if not (r and ns.Raid and ns.Raid.Key) then return nil, nil end
    return ns.Raid.Key(r), r.id and ns.Raid.DayKey and ns.Raid.DayKey(r) or nil
end
function Roll.List(raid, alt)
    local out = {}
    for who, n in pairs(Roll.Sums(raid, alt)) do out[#out + 1] = { who = who, n = n } end
    tsort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.who < b.who
    end)
    return out
end
function Roll.Throws(raid, alt)
    local sums = Roll.Sums(raid, alt)
    local out = {}
    for i = 1, #throws do
        local t = throws[i]
        t.pen = sums[t.who] or 0
        t.net = t.n - t.pen
        out[i] = t
    end
    tsort(out, function(a, b)
        if a.net ~= b.net then return a.net > b.net end
        if a.n ~= b.n then return a.n > b.n end
        return a.t < b.t
    end)
    return out
end
function Roll.Lines(raid, alt)
    local list = Roll.Throws(raid, alt)
    if not list[1] then return {} end
    local out, line = {}, ns.T("roll.chat.head")
    for i = 1, #list do
        local t = list[i]
        local part = t.pen > 0 and format(ns.T("roll.chat.pen"), t.who, t.net, t.n, t.pen) or format(ns.T("roll.chat.n"), t.who, t.n)
        local sep = line == ns.T("roll.chat.head") and " " or ", "
        if #line + #sep + #part > LIMIT then
            out[#out + 1] = line
            line, sep = "", ""
        end
        line = line .. sep .. part
    end
    out[#out + 1] = line
    return out
end
function Roll.Report(raid, alt)
    return (ns.Proof.SendLines(Roll.Lines(raid, alt), "RAID", nil, "roll"))
end
function Roll.Count()
    return #throws
end
function Roll.Listening()
    return listening
end
function Roll.Sync()
    local want = ns.Ledger.Key() == "roll"
    if want == listening then return end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, _, msg) Roll.OnSystem(msg) end)
    end
    listening = want
    if want then frame:RegisterEvent("CHAT_MSG_SYSTEM") else frame:UnregisterEvent("CHAT_MSG_SYSTEM") end
end
ns.OnReady(Roll.Sync)
