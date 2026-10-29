local _, ns = ...
local tsort = table.sort
local tremove = table.remove
local AGE = 8 * 3600
local MAX_WHO = 40
local MAX_LINES = 5
local MAX_TEXT = 120
local LIMIT = 255
local WORDS = { ["софт"] = true, ["Софт"] = true, ["СОФТ"] = true, ["sr"] = true, ["SR"] = true, ["Sr"] = true,
    ["soft"] = true, ["Soft"] = true, ["SOFT"] = true }
local EVENTS = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_WHISPER" }
local Soft = {}
ns.Soft = Soft
local listeners = {}
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
function Soft.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Store()
    local fl = ns.GetDB().faults
    local s = fl.soft
    if type(s) ~= "table" or type(s.by) ~= "table" then
        s = { t = 0, by = {} }
        fl.soft = s
    end
    return s
end
local function Cut(s, n)
    if #s <= n then return s end
    local i = n
    while i > 0 do
        local c = s:byte(i + 1)
        if not c or c < 128 or c >= 192 then break end
        i = i - 1
    end
    return s:sub(1, i)
end
function Soft.Parse(msg)
    if type(msg) ~= "string" then return nil end
    local word, rest = msg:match("^%s*([^%s:]+)%s*:?%s*(.-)%s*$")
    if not word or not WORDS[word] or rest == "" then return nil end
    return Cut(rest, MAX_TEXT)
end
function Soft.OnChat(who, msg)
    local text = Soft.Parse(msg)
    if not text or type(who) ~= "string" or who == "" then return false end
    who = who:match("^([^%-]+)") or who
    local s, now = Store(), time()
    if now - (s.t or 0) > AGE then s.by = {} end
    s.t = now
    local lines = s.by[who]
    if not lines then
        local n = 0
        for _ in pairs(s.by) do n = n + 1 end
        if n >= MAX_WHO then return false end
        lines = {}
        s.by[who] = lines
    end
    lines[#lines + 1] = { t = now, text = text }
    while #lines > MAX_LINES do tremove(lines, 1) end
    Notify()
    return true
end
function Soft.List()
    local s = Store()
    if time() - (s.t or 0) > AGE then return {} end
    local out = {}
    for who, lines in pairs(s.by) do
        if lines[1] then out[#out + 1] = { who = who, lines = lines, t = lines[#lines].t } end
    end
    tsort(out, function(a, b) return a.who < b.who end)
    return out
end
function Soft.Of(who)
    local s = Store()
    if time() - (s.t or 0) > AGE then return nil end
    local lines = s.by[who]
    return lines and lines[1] and lines or nil
end
function Soft.Count()
    return #Soft.List()
end
function Soft.Clear()
    local s = Store()
    s.t, s.by = 0, {}
    Notify()
end
function Soft.Lines()
    local list = Soft.List()
    local out = {}
    for i = 1, #list do
        local parts = {}
        for k = 1, #list[i].lines do parts[k] = list[i].lines[k].text end
        out[#out + 1] = Cut(list[i].who .. ": " .. table.concat(parts, "; "), LIMIT)
    end
    return out
end
function Soft.Report()
    return (ns.Proof.SendLines(Soft.Lines(), "RAID", nil, "soft"))
end
local frame = CreateFrame("Frame")
for i = 1, #EVENTS do frame:RegisterEvent(EVENTS[i]) end
frame:SetScript("OnEvent", function(_, _, msg, author) Soft.OnChat(author, msg) end)
