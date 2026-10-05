local _, ns = ...
local format = string.format
local gmatch, gsub, lower = string.gmatch, string.gsub, string.lower
local concat = table.concat
local RAID_MAX = 40
local PARTY_MAX = 5
local HOLD = 60
local SAY_GAP = 1.5
local WORDS_MAX = 120
local DEF = { words = "+, инв, inv, invite", guild = false }
local Auto = {}
ns.AutoInvite = Auto
Auto.DEF = DEF
local on = false
local listeners = {}
local capSources = {}
local pending = {}
local queue = {}
local said = {}
local told = {}
local toldAt = 0
local guild
local wordSet
local wordSrc
local function LowA(a)
    return "\208" .. string.char(a:byte() + 32)
end
local function LowR(a)
    return "\209" .. string.char(a:byte() - 32)
end
local function Lower(s)
    s = gsub(gsub(gsub(lower(s), "\208\129", "\209\145"), "\208([\144-\159])", LowA), "\208([\160-\175])", LowR)
    return s
end
Auto.Lower = Lower
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
local function Opt()
    local s = ns.GetDB().settings
    local o = s.autoInvite
    if type(o) ~= "table" then
        o = {}
        s.autoInvite = o
    end
    for k, v in pairs(DEF) do
        if type(o[k]) ~= type(v) then o[k] = v end
    end
    return o
end
function Auto.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function Auto.CapSource(fn)
    capSources[#capSources + 1] = fn
end
function Auto.IsOn()
    return on
end
function Auto.WordsText()
    return Opt().words
end
function Auto.SetWordsText(text)
    local list = {}
    for w in gmatch(gsub(tostring(text or ""), "[|%c]", ""), "[^,]+") do
        w = w:match("^%s*(.-)%s*$")
        if w ~= "" then list[#list + 1] = w end
    end
    local v = concat(list, ", ")
    Opt().words = v ~= "" and v:sub(1, WORDS_MAX) or DEF.words
    Notify()
end
function Auto.GuildOnly()
    return Opt().guild
end
function Auto.SetGuildOnly(v)
    Opt().guild = v and true or false
    if v and IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
    Notify()
end
local function Words()
    local src = Opt().words
    if wordSet and wordSrc == src then return wordSet end
    wordSet, wordSrc = {}, src
    for w in gmatch(src, "[^,]+") do
        w = Lower(w:match("^%s*(.-)%s*$"))
        if w ~= "" then wordSet[w] = true end
    end
    return wordSet
end
function Auto.Match(text)
    local set = Words()
    local s = Lower(tostring(text or "")):match("^%s*(.-)%s*$")
    if s == "" then return false end
    if set[s] then return true end
    for w in gmatch(s, "%S+") do
        if set[w] then return true end
        local core = w:match("^%p*(.-)%p*$")
        if core ~= "" and set[core] then return true end
    end
    return false
end
local function Group()
    return GetNumRaidMembers() or 0, GetNumPartyMembers() or 0
end
function Auto.CanInvite()
    local raid, party = Group()
    if raid > 0 then return (IsRaidLeader() or IsRaidOfficer()) and true or false end
    if party > 0 then return IsPartyLeader() and true or false end
    return true
end
function Auto.Cap()
    for i = 1, #capSources do
        local n = tonumber(capSources[i]())
        if n and n > 0 then return n < RAID_MAX and n or RAID_MAX end
    end
    return RAID_MAX
end
local function InGroup(name)
    return (UnitInRaid(name) or UnitInParty(name)) and true or false
end
local function Expire()
    local now = GetTime()
    for name, at in pairs(pending) do
        if now - at > HOLD or InGroup(name) then pending[name] = nil end
    end
    for name, at in pairs(queue) do
        if now - at > HOLD then queue[name] = nil end
    end
end
local function Pending()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end
local function Members()
    local raid, party = Group()
    if raid > 0 then return raid end
    return party + 1
end
local function Ignored(name)
    local want = Lower(name)
    for i = 1, (GetNumIgnores and GetNumIgnores() or 0) do
        local n = GetIgnoreName(i)
        if n and Lower(n) == want then return true end
    end
    return false
end
local function ReadGuild()
    guild = {}
    if not (IsInGuild and IsInGuild()) then return end
    for i = 1, (GetNumGuildMembers(true) or 0) do
        local n = GetGuildRosterInfo(i)
        if n then guild[Lower(n)] = true end
    end
end
local function InGuild(name)
    if not guild then ReadGuild() end
    return guild[Lower(name)] == true
end
local function SayOnce(key, text)
    if said[key] then return end
    said[key] = true
    ns.Print(text)
end
local ticker = CreateFrame("Frame")
ticker:Hide()
local function Flush()
    ticker:Hide()
    if #told == 0 then return end
    if #told == 1 then
        ns.Print(format(ns.T("ainv.invited"), told[1]))
    else
        ns.Print(format(ns.T("ainv.invited.many"), #told, concat(told, ", ")))
    end
    told = {}
end
local function Tell(name)
    told[#told + 1] = name
    toldAt = GetTime()
    ticker:Show()
end
ticker:SetScript("OnUpdate", function()
    if GetTime() - toldAt >= SAY_GAP then Flush() end
end)
local function Convert()
    local raid, party = Group()
    if raid == 0 and party > 0 and IsPartyLeader() then ConvertToRaid() end
end
function Auto.Try(name)
    if not on then return "off" end
    if type(name) ~= "string" or name == "" or name == UnitName("player") then return "self" end
    Expire()
    if InGroup(name) then return "member" end
    if pending[name] or queue[name] then return "pending" end
    if Ignored(name) then return "ignored" end
    if Opt().guild and not InGuild(name) then return "guild" end
    if not Auto.CanInvite() then
        SayOnce("rights", ns.T("ainv.norights"))
        return "rights"
    end
    said.rights = nil
    local cap = Auto.Cap()
    if Members() + Pending() >= cap then
        SayOnce("full" .. cap, format(ns.T("ainv.full"), cap))
        return "full"
    end
    local raid = Group()
    if raid == 0 and Members() + Pending() >= PARTY_MAX then
        queue[name] = GetTime()
        Convert()
        return "queued"
    end
    InviteUnit(name)
    pending[name] = GetTime()
    Tell(name)
    return "invited"
end
function Auto.Whisper(author, text)
    if not on or not Auto.Match(text) then return nil end
    return Auto.Try(author)
end
local function Drain()
    if not on or (GetNumRaidMembers() or 0) == 0 then return end
    local list = {}
    for name in pairs(queue) do list[#list + 1] = name end
    table.sort(list, function(a, b) return queue[a] < queue[b] end)
    queue = {}
    for i = 1, #list do Auto.Try(list[i]) end
end
function Auto.Switch(v)
    v = v and true or false
    if on == v then return end
    on = v
    pending, queue, said = {}, {}, {}
    if on then
        guild = nil
        if Opt().guild and IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        local key = Opt().guild and "ainv.on.guild" or "ainv.on"
        ns.Print(format(ns.T(key), Opt().words))
        local raid, party = Group()
        if raid == 0 and party + 1 >= PARTY_MAX then Convert() end
    else
        Flush()
        ns.Print(ns.T("ainv.off"))
    end
    Notify()
end
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, msg, author)
    if event == "CHAT_MSG_WHISPER" then
        Auto.Whisper(author, msg)
    elseif event == "GUILD_ROSTER_UPDATE" then
        guild = nil
    elseif on then
        Expire()
        local raid, party = Group()
        if raid == 0 and (party + 1 >= PARTY_MAX or (party > 0 and next(queue))) then Convert() end
        Drain()
    end
end)
