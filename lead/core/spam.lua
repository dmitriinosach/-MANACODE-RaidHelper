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
local ROLES = { "tank", "heal", "melee", "ranged" }
P.ROLES = ROLES
local MAX_NEED = 40
local running = false
local nextAt = {}
local lastFits = true
local onRun = {}
function P.OnRun(fn)
    onRun[#onRun + 1] = fn
end
local function ran()
    for _, fn in ipairs(onRun) do fn(running) end
    ns.Session.Changed()
end
local function slotRole(slot)
    if slot.role ~= "dd" and slot.role ~= "hybrid" then return slot.role end
    local one
    for _, k in ipairs(slot.specs or {}) do
        local sp = ns.SPEC[k]
        local r = sp and sp.role
        if one and r ~= one then return nil end
        one = r
    end
    return one
end
function P.TemplateNeeds(tpl)
    local out = {}
    for _, r in ipairs(ROLES) do out[r] = 0 end
    local loose = 0
    for _, slot in ipairs(tpl and tpl.slots or {}) do
        local r = slotRole(slot)
        if out[r] then out[r] = out[r] + 1 else loose = loose + 1 end
    end
    for _ = 1, loose do
        if out.melee < out.ranged then out.melee = out.melee + 1 else out.ranged = out.ranged + 1 end
    end
    return out
end
local function needs()
    local g = ns.Session.State()
    if type(g.spamNeeds) ~= "table" then
        g.spamNeeds = P.TemplateNeeds(ns.Session.Template())
    end
    return g.spamNeeds
end
function P.Needs()
    local src, out = needs(), {}
    for _, r in ipairs(ROLES) do out[r] = tonumber(src[r]) or 0 end
    return out
end
function P.Need(role)
    return tonumber(needs()[role]) or 0
end
function P.NeedTotal()
    local n = 0
    for _, v in pairs(P.Needs()) do n = n + v end
    return n
end
function P.SetNeed(role, n)
    local t = needs()
    n = math.floor(tonumber(n) or 0)
    if n < 0 then n = 0 end
    if n > MAX_NEED then n = MAX_NEED end
    if t[role] == n then return end
    t[role] = n
    ns.Session.Changed()
end
function P.AddNeed(role, delta)
    P.SetNeed(role, P.Need(role) + delta)
end
function P.NeedsFromTemplate()
    ns.Session.State().spamNeeds = P.TemplateNeeds(ns.Session.Template())
    ns.Session.Changed()
end
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
    if ns.Lang() ~= "ruRU" then return n == 1 and one or many end
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
            if sp.role == grp then
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
                    if sp.role == grp then total = total + 1 end
                end
                if #picked < total then all = false end
                for _, k in ipairs(picked) do names[#names + 1] = ns.T("spec_" .. k) end
            end
        end
    end
    return names, all
end
local function needParts()
    local need = P.Needs()
    local parts = {}
    for _, grp in ipairs(ROLES) do
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
local function freeText(n, size)
    local free = (size or 0) - (n or 0)
    if free <= 0 then return "" end
    return free .. " " .. plural(free, ns.T("seat1"), ns.T("seat2"), ns.T("seat5"))
end
local function howText()
    local A = root.AutoInvite
    if A and A.IsOn() then
        local w = (A.WordsText() or ""):match("^%s*([^,]-)%s*,") or A.WordsText() or ""
        if w ~= "" then return ns.T("howAuto", w) end
    end
    return ns.T("howWhisper")
end
local function tokens(needs)
    local n, size = ns.Session.Count()
    return {
        tokFree  = freeText(n, size),
        tokLead  = UnitName("player") or "",
        tokHow   = howText(),
        tokDs    = ns.Session.Field("ds") or "",
        tokRaid  = ns.Tpl.Name(ns.Session.Template()),
        tokNeeds = needs,
        tokCount = n .. "/" .. size,
        tokProg  = ns.Session.Field("prog") or "",
        tokReq   = reqText(),
        tokLoot  = lootText(),
        tokTime  = ns.Session.Field("time") or "",
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
    for key, val in pairs(tokens(needs)) do
        local repl = val:gsub("%%", "%%%%")
        for _, words in pairs(ns.locales) do
            local tok = words[key]
            if tok then out = out:gsub(plain(tok), repl) end
        end
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
        local len = #msg
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
    nextAt[key] = (running and on) and GetTime() or nil
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
local function clampEvery(sec)
    sec = math.floor(tonumber(sec) or DEF_EVERY)
    if sec < MIN_EVERY then sec = MIN_EVERY end
    return sec
end
function P.Every()
    return ns.Store.DB().every or DEF_EVERY
end
function P.SetEvery(sec)
    ns.Store.DB().every = clampEvery(sec)
    ns.Session.Changed()
end
function P.OwnEvery()
    return ns.Store.DB().ownEvery and true or false
end
function P.SetOwnEvery(on)
    ns.Store.DB().ownEvery = on and true or nil
    ns.Session.Changed()
end
function P.EveryOf(key)
    if P.OwnEvery() then return chanCfg(key).every end
    return P.Every()
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
    return not ns.Test.Active() and #activeChannels() > 0 and P.NeedTotal() > 0
end
function P.Blocker()
    if ns.Test.Active() then return "tipTestSpam" end
    if #activeChannels() == 0 then return "tipNoChannels" end
    if P.NeedTotal() == 0 then return "tipNoNeeds" end
end
function P.Start()
    if running or not P.CanStart() then return end
    running = true
    local now = GetTime()
    for i, c in ipairs(activeChannels()) do
        nextAt[c.key] = now + (i - 1) * STAGGER
    end
    ns.Session.TryConvert()
    ran()
end
function P.Stop()
    if not running then return end
    running = false
    for k in pairs(nextAt) do nextAt[k] = nil end
    ran()
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
function P.Left(key)
    local t = running and chanCfg(key).on and nextAt[key]
    if not t then return nil end
    return math.max(0, t - GetTime())
end
local ticker = ns.NewFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(self, dt)
    if not running then return end
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    if P.NeedTotal() == 0 then
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
            nextAt[c.key] = now + P.EveryOf(c.key)
        end
    end
end)
