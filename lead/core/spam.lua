local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local P = {}
ns.Spam = P
local MAX_CHARS = 255
local MIN_EVERY = 15
local DEF_EVERY = 60
local STAGGER = 2
local LOOT = { "none", "roll", "rollBoe", "rollBoeShards", "sr1", "sr2", "sr3", "sr4", "epgp", "epAuc", "noSoft" }
P.LOOT = LOOT
local SPECIAL = {
    { key = "SAY",   label = "chanSay" },
    { key = "YELL",  label = "chanYell" },
    { key = "GUILD", label = "chanGuild" },
}
local running = false
local nextAt = {}
local lastFits = true
local function texts()
    local db = ns.Store.DB()
    db.texts = db.texts or {}
    local key = ns.Session.Template().key
    local list = db.texts[key]
    if not list or #list == 0 then
        list = { { name = ns.T("textMain"), body = ns.T("textDefault") } }
        db.texts[key] = list
    end
    return list
end
function P.Texts()
    return texts()
end
function P.TextIndex()
    local g = ns.Session.State()
    local list = texts()
    if not list[g.text] then g.text = 1 end
    return g.text
end
function P.Body()
    return texts()[P.TextIndex()].body
end
function P.SetBody(body)
    texts()[P.TextIndex()].body = body
    ns.Session.Changed()
end
function P.PickText(i)
    if not texts()[i] then return end
    ns.Session.State().text = i
    ns.Session.Changed()
end
function P.NewText(copy)
    local list = texts()
    local body = copy and P.Body() or ns.T("textDefault")
    list[#list + 1] = { name = ns.T("textN", #list + 1), body = body }
    P.PickText(#list)
end
function P.DeleteText()
    local list = texts()
    if #list < 2 then return end
    table.remove(list, P.TextIndex())
    P.PickText(1)
end
local function plural(n, one, few, many)
    if ns.Lang() == "enUS" then return n == 1 and one or many end
    local d, h = n % 10, n % 100
    if d == 1 and h ~= 11 then return one end
    if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
    return many
end
local function groupWord(grp, n)
    return plural(n, ns.T("grp_" .. grp .. "1"), ns.T("grp_" .. grp .. "2"), ns.T("grp_" .. grp .. "5"))
end
local function groupNames(grp)
    local S = ns.Session
    local names, all = {}, true
    for _, cls in ipairs(ns.CLASSES) do
        local inGroup, anyChecked, picked = false, false, {}
        for _, sp in ipairs(cls.specs) do
            if S.Checked(sp.key) then anyChecked = true end
            if ns.ROLE_GROUP[sp.role] == grp then
                inGroup = true
                if S.Checked(sp.key) then picked[#picked + 1] = sp.key end
            end
        end
        if inGroup then
            if not S.ClassChecked(cls.token) then
                all = false
            elseif cls.classOnly or not anyChecked then
                names[#names + 1] = ns.T("clsShort_" .. cls.token)
            else
                local total = 0
                for _, sp in ipairs(cls.specs) do
                    if ns.ROLE_GROUP[sp.role] == grp then total = total + 1 end
                end
                if #picked < total then all = false end
                for _, k in ipairs(picked) do names[#names + 1] = ns.T("spec_" .. k) end
            end
        end
    end
    return names, all
end
local function needParts()
    local need = ns.Session.Needs()
    local parts = {}
    for _, grp in ipairs(ns.GROUP_ORDER) do
        local n = need[grp]
        if n > 0 then
            local names, all = groupNames(grp)
            parts[#parts + 1] = { grp = grp, head = n .. " " .. groupWord(grp, n),
                names = (#names > 0 and not all) and names or nil }
        end
    end
    return parts
end
local CONT = "[" .. string.char(128) .. "-" .. string.char(191) .. "]"
local LEAD = "^[" .. string.char(192) .. "-" .. string.char(255) .. "]" .. CONT .. "*"
local upperMap
local function capital(s)
    if not upperMap then
        upperMap = {}
        local lo, up = {}, {}
        for ch in ns.CYR_LOWER:gmatch("[" .. string.char(192) .. "-" .. string.char(255) .. "]" .. CONT .. "*") do lo[#lo + 1] = ch end
        for ch in ns.CYR_UPPER:gmatch("[" .. string.char(192) .. "-" .. string.char(255) .. "]" .. CONT .. "*") do up[#up + 1] = ch end
        for i = 1, #lo do upperMap[lo[i]] = up[i] end
    end
    local first = s:match(LEAD)
    if first then return (upperMap[first] or first) .. s:sub(#first + 1) end
    return s:sub(1, 1):upper() .. s:sub(2)
end
local function needsText(parts, drop)
    local style = ns.Session.Field("needsStyle") or "count"
    local out = {}
    if style == "count" then
        for i, part in ipairs(parts) do
            local s = part.head
            if part.names and not drop[i] then s = s .. " (" .. table.concat(part.names, ", ") .. ")" end
            out[#out + 1] = s
        end
        return table.concat(out, ", ")
    end
    for i, part in ipairs(parts) do
        if style == "slash" and part.names and not drop[i] then
            for _, name in ipairs(part.names) do out[#out + 1] = capital(name) end
        else
            out[#out + 1] = capital(ns.T("slot_" .. part.grp))
        end
    end
    return table.concat(out, style == "slash" and "/" or ", ")
end
local function utf8len(s)
    local _, extra = s:gsub(CONT, "")
    return #s - extra
end
local function reqText()
    local v = ns.Session.Field("req")
    if not v or v == "" or ns.Session.Field("reqKind") == "none" then return "" end
    return ns.T(ns.Session.Field("reqKind") == "ilvl" and "reqIlvl" or "reqGs", v)
end
local function lootText()
    local k = ns.Session.Field("loot") or "none"
    if k == "none" then return "" end
    return ns.T("loot_" .. k)
end
local function tokens(needs)
    local n, size = ns.Session.Count()
    return {
        [ns.T("tokRaid")]  = ns.Tpl.Name(ns.Session.Template()),
        [ns.T("tokNeeds")] = needs,
        [ns.T("tokCount")] = n .. "/" .. size,
        [ns.T("tokProg")]  = ns.Session.Field("prog") or "",
        [ns.T("tokReq")]   = reqText(),
        [ns.T("tokLoot")]  = lootText(),
        [ns.T("tokTime")]  = ns.Session.Field("time") or "",
    }
end
local function plain(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?%{%}]", "%%%0"))
end
local function tidy(s)
    s = s:gsub("%s+([,%.])", "%1")
    s = s:gsub(",%s*,", ",")
    s = s:gsub(",%s*%.", ".")
    s = s:gsub("%s%s+", " ")
    s = s:gsub("^[%s,]+", "")
    s = s:gsub("[%s,]+$", "")
    return s
end
local function fill(body, needs)
    local out = (body or ""):gsub("%c+", " ")
    for tok, val in pairs(tokens(needs)) do
        out = out:gsub(plain(tok), (val:gsub("%%", "%%%%")))
    end
    return tidy(out)
end
function P.Build()
    local body = P.Body()
    local parts = needParts()
    local drop = {}
    local short = false
    while true do
        local msg = fill(body, needsText(parts, drop))
        local len = utf8len(msg)
        if len <= MAX_CHARS then return msg, len, true, short end
        local worst, most = nil, 0
        for i, part in ipairs(parts) do
            if part.names and not drop[i] and #part.names > most then worst, most = i, #part.names end
        end
        if not worst then return msg, len, false, short end
        drop[worst] = true
        short = true
    end
end
function P.Limit()
    return MAX_CHARS
end
function P.Channels()
    local out = {}
    for _, s in ipairs(SPECIAL) do
        if s.key ~= "GUILD" or IsInGuild() then
            out[#out + 1] = { key = s.key, label = ns.T(s.label) }
        end
    end
    local list = { GetChannelList() }
    for i = 1, #list, 2 do
        local id, name = list[i], list[i + 1]
        if id and name then
            out[#out + 1] = { key = "#" .. name, label = id .. ". " .. name, name = name }
        end
    end
    return out
end
local function chanCfg(key)
    local db = ns.Store.DB()
    db.chans = db.chans or {}
    local c = db.chans[key]
    if not c then
        c = { on = false, every = DEF_EVERY }
        db.chans[key] = c
    end
    return c
end
function P.ChanOn(key) return chanCfg(key).on end
function P.ChanEvery(key) return chanCfg(key).every end
function P.SetChanOn(key, on)
    chanCfg(key).on = on and true or false
    nextAt[key] = nil
    ns.Session.Changed()
end
function P.SetChanEvery(key, sec)
    sec = tonumber(sec) or DEF_EVERY
    if sec < MIN_EVERY then sec = MIN_EVERY end
    chanCfg(key).every = math.floor(sec)
    ns.Session.Changed()
end
function P.MinEvery()
    return MIN_EVERY
end
local function activeChannels()
    local out = {}
    for _, c in ipairs(P.Channels()) do
        if chanCfg(c.key).on then out[#out + 1] = c end
    end
    return out
end
local function send(c, msg)
    if c.name then
        local id = GetChannelName(c.name)
        if id and id > 0 then SendChatMessage(msg, "CHANNEL", nil, id) end
    else
        SendChatMessage(msg, c.key)
    end
end
function P.Running()
    return running
end
function P.Fits()
    return lastFits
end
function P.CanStart()
    return not ns.Test.Active() and #activeChannels() > 0
end
function P.Start()
    if running or not P.CanStart() then return end
    running = true
    local now = GetTime()
    for i, c in ipairs(activeChannels()) do
        nextAt[c.key] = now + (i - 1) * STAGGER
    end
    ns.Session.TryConvert()
    ns.Session.Changed()
end
function P.Stop()
    if not running then return end
    running = false
    for k in pairs(nextAt) do nextAt[k] = nil end
    ns.Session.Changed()
end
function P.Toggle()
    if running then P.Stop() else P.Start() end
end
function P.Next()
    local best, bestC
    for _, c in ipairs(activeChannels()) do
        local t = nextAt[c.key]
        if t and (not best or t < best) then best, bestC = t, c end
    end
    if not best then return nil end
    local left = best - GetTime()
    if left < 0 then left = 0 end
    return bestC, left
end
local ticker = ns.NewFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(self, dt)
    if not running then return end
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    if ns.Session.NeedTotal() == 0 then
        P.Stop()
        return
    end
    local now = GetTime()
    local msg, fits
    for _, c in ipairs(activeChannels()) do
        local t = nextAt[c.key]
        if not t then
            nextAt[c.key] = now
        elseif now >= t then
            if msg == nil then
                local _
                msg, _, fits = P.Build()
                lastFits = fits
            end
            if fits then send(c, msg) end
            nextAt[c.key] = now + chanCfg(c.key).every
        end
    end
end)
local guard = ns.NewFrame("Frame")
ns.Listen(guard, "PLAYER_REGEN_DISABLED")
guard:SetScript("OnEvent", function() P.Stop() end)
