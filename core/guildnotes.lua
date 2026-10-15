local _, ns = ...
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type
local D = ns.guildNotes
local CHAIN = 5
local ROSTER_GAP = 15
local SRC_ORDER = { "qdkp", "officer", "note", "list" }
local SRC_RANK = { qdkp = 1, officer = 2, note = 3, list = 4 }
local GuildNotes = {}
ns.GuildNotes = GuildNotes
GuildNotes.SRC_ORDER = SRC_ORDER
local cyr = {}
do
    local up, lo = {}, {}
    for ch in D.upper:gmatch("[\192-\255][\128-\191]*") do up[#up + 1] = ch end
    for ch in D.lower:gmatch("[\192-\255][\128-\191]*") do lo[#lo + 1] = ch end
    for i = 1, #up do cyr[up[i]] = lo[i] end
end
local function Set(list)
    local out = {}
    for i = 1, #list do out[list[i]] = true end
    return out
end
local WORDS = {}
for key, list in pairs(D.specWords) do
    for i = 1, #list do WORDS[list[i]] = { specs = { key } } end
end
for word, keys in pairs(D.multiWords) do WORDS[word] = { specs = keys } end
for role, list in pairs(D.roleWords) do
    for i = 1, #list do WORDS[list[i]] = { role = role } end
end
for cls, list in pairs(D.classWords) do
    for i = 1, #list do WORDS[list[i]] = WORDS[list[i]] or { class = cls } end
end
local ALT = Set(D.altWords)
local ALTS = Set(D.altsWords)
local GSW = Set(D.gsWords)
local KW = Set(D.kWords)
function GuildNotes.Lower(s)
    return (s:lower():gsub("[\208\209][\128-\191]", cyr))
end
local Lower = GuildNotes.Lower
function GuildNotes.IsWord(word)
    return WORDS[word] ~= nil or ALT[word] or ALTS[word] or GSW[word] or KW[word] or false
end
local function Around(before, after)
    local w = before:match("([^%s%d%p]+)[%s%p]*$")
    local a = after:match("^%s*([^%s%d%p]+)")
    local kw = (w and GSW[w]) or (a and GSW[a]) or false
    return kw, (a and KW[a]) or false
end
local RANK = { kw = 5, k = 4, dec = 3, n4 = 2, n3 = 1 }
function GuildNotes.Gs(s)
    local best, bestHow, bestRank = nil, nil, 0
    local g = D.gs
    for st, num, en in s:gmatch("()(%d+[%.,]?%d*)()") do
        local int, frac = num:match("^(%d+)[%.,](%d*)$")
        int = int or num
        local kw, k = Around(s:sub(max(1, st - 16), st - 1), s:sub(en, en + 10))
        local v, how = nil, nil
        if frac and #frac > 2 then
            v = nil
        elseif k then
            v = tonumber(int .. "." .. (frac ~= "" and frac or "0"))
            if v and v < 10 then v, how = v * 1000, "k" elseif v and v >= 1000 then how = "k" else v = nil end
        elseif frac and frac ~= "" then
            v = tonumber(int .. "." .. frac)
            if v and v < 10 then v, how = v * 1000, "dec" else v = nil end
        elseif #int == 4 then
            v, how = tonumber(int), "n4"
        elseif #int == 3 then
            v, how = tonumber(int) * 10, "n3"
        end
        if v then
            if kw then how = "kw" end
            local lo, hi = g.lo, g.hi
            if how == "kw" or how == "k" then lo, hi = g.wideLo, g.wideHi end
            local r = RANK[how]
            if v >= lo and v <= hi and r > bestRank then
                best, bestHow, bestRank = floor(v + 0.5), how, r
            end
        end
    end
    return best, bestHow
end
local function ClassSpecs(class, role)
    local out = {}
    for key, sp in pairs(D.specs) do
        if sp.class == class and sp.role and (sp.role == role or (role == "dd" and sp.role ~= "tank"
            and sp.role ~= "heal")) then
            out[#out + 1] = key
        end
    end
    return out
end
local function CommonRole(keys)
    local role = nil
    for i = 1, #keys do
        local r = D.specs[keys[i]].role
        if not r or (role and r ~= role) then return nil end
        role = r
    end
    return role
end
local function OfClass(keys, class)
    if not class then return keys end
    local out = {}
    for i = 1, #keys do
        if D.specs[keys[i]].class == class then out[#out + 1] = keys[i] end
    end
    return out
end
local function Resolve(out, groups, roles)
    local first = groups[1]
    if first and #first == 1 then
        out.spec = first[1]
    elseif first then
        out.role = CommonRole(first)
    end
    if out.spec == "feral" then
        for i = 1, #roles do
            if roles[i] == "tank" then out.spec = "bear" break end
            if roles[i] == "melee" or roles[i] == "dd" then out.spec = "cat" break end
        end
    end
    local second = groups[2]
    if second and #second == 1 and second[1] ~= out.spec then out.off = second[1] end
    if out.spec then
        out.role = D.specs[out.spec].role
        return
    end
    if out.role or not roles[1] then return end
    local role = roles[1]
    local keys = out.cls and ClassSpecs(out.cls, role) or {}
    if #keys == 1 then
        out.spec = keys[1]
        out.role = D.specs[keys[1]].role
    elseif #keys > 1 and role == "dd" then
        out.role = CommonRole(keys) or role
    else
        out.role = role
    end
end
function GuildNotes.Parse(text, class, findName, self)
    local out = {}
    if type(text) ~= "string" then return out end
    local s = Lower(text:gsub("[%c|]", " "))
    local trimmed = s:match("^%s*(.-)%s*$")
    if trimmed == "" then return out end
    if trimmed:match("^%d+%s*,%s*%d+$") then
        out.epgp = true
        return out
    end
    local me = self and Lower(self) or nil
    local who = findName and findName(trimmed)
    if who and Lower(who) ~= me then
        out.main = who
        return out
    end
    out.gs, out.gsHow = GuildNotes.Gs(s)
    local groups, roles, names = {}, {}, {}
    local alt, alts = false, false
    for tok in s:gmatch("[^%s%p]+") do
        if not tok:find("%d") then
            local w = WORDS[tok]
            if w then
                if w.specs then groups[#groups + 1] = w.specs end
                if w.role then roles[#roles + 1] = w.role end
                if w.class and not out.cls then out.cls = w.class end
            elseif ALT[tok] then
                alt = true
            elseif ALTS[tok] then
                alts = true
            elseif findName and tok ~= me then
                local n = findName(tok)
                if n then names[#names + 1] = n end
            end
        end
    end
    local cls = class or out.cls
    local kept = {}
    for i = 1, #groups do
        local g = OfClass(groups[i], cls)
        if #g > 0 then kept[#kept + 1] = g end
    end
    out.cls = cls
    Resolve(out, kept, roles)
    if out.cls == class then out.cls = nil end
    if alts and #names > 0 then
        out.alts = names
    elseif alt and #names == 1 then
        out.main = names[1]
    end
    return out
end
local members = {}
local byLower = {}
local links = {}
local altsOf = {}
local dirty = true
local loaded = false
local askedAt = -1e9
local function FindName(lower)
    return byLower[lower]
end
local function QdkpMain(name)
    local fn = _G.QDKP2_GetMain
    if type(fn) ~= "function" then return nil end
    local ok, main = pcall(fn, name)
    if ok and type(main) == "string" and main ~= name and members[main] then return main end
    return nil
end
local function Pick(m, field)
    local o, p = m.off[field], m.pub[field]
    if o ~= nil then
        m[field], m[field .. "Src"] = o, "officer"
    elseif p ~= nil then
        m[field], m[field .. "Src"] = p, "note"
    end
end
local function Offer(cands, name, src, main)
    if not main or main == name or not members[main] then return end
    local c = cands[name]
    if not c then
        c = {}
        cands[name] = c
    end
    c[src] = main
end
local function Choose(name, c)
    local main, src = nil, nil
    for i = 1, #SRC_ORDER do
        local s = SRC_ORDER[i]
        if c[s] then
            main, src = c[s], s
            break
        end
    end
    if not main then return nil end
    local srcs = {}
    for i = 1, #SRC_ORDER do
        if c[SRC_ORDER[i]] == main then srcs[#srcs + 1] = SRC_ORDER[i] end
    end
    return { main = main, src = src, srcs = srcs }
end
local function BuildLinks()
    local cands = {}
    for name, m in pairs(members) do
        Offer(cands, name, "qdkp", QdkpMain(name))
        Offer(cands, name, "officer", m.off.main)
        Offer(cands, name, "note", m.pub.main)
        local list = m.off.alts or m.pub.alts
        for i = 1, #(list or {}) do Offer(cands, list[i], "list", name) end
    end
    links, altsOf = {}, {}
    for name, c in pairs(cands) do links[name] = Choose(name, c) end
    for name in pairs(links) do
        local root, seen = name, { [name] = true }
        for _ = 1, CHAIN do
            local up = links[root]
            if not up or seen[up.main] then break end
            root = up.main
            seen[root] = true
        end
        if root ~= name then
            links[name].main = root
            altsOf[root] = altsOf[root] or {}
            altsOf[root][name] = links[name].src
        else
            links[name] = nil
        end
    end
end
function GuildNotes.Refresh()
    if not dirty then return end
    dirty = false
    local n = GetNumGuildMembers and GetNumGuildMembers(true) or 0
    local fresh, lowers = {}, {}
    for i = 1, n do
        local name, _, rankIndex, level, _, _, note, officer, online, _, cls = GetGuildRosterInfo(i)
        if type(name) == "string" and name ~= "" then
            fresh[name] = { name = name, class = cls, level = tonumber(level) or 0, rank = tonumber(rankIndex) or 99,
                online = online and true or false, note = note or "", officer = officer or "" }
            lowers[Lower(name)] = name
        end
    end
    if n > 0 then loaded = true end
    members, byLower = fresh, lowers
    for name, m in pairs(members) do
        m.off = GuildNotes.Parse(m.officer, m.class, FindName, name)
        m.pub = GuildNotes.Parse(m.note, m.class, FindName, name)
        Pick(m, "role")
        Pick(m, "spec")
        Pick(m, "gs")
    end
    BuildLinks()
end
function GuildNotes.Ask()
    if not IsInGuild() or not GuildRoster then return end
    local now = GetTime()
    if now - askedAt < ROSTER_GAP then return end
    askedAt = now
    GuildRoster()
end
function GuildNotes.Loaded()
    GuildNotes.Refresh()
    return loaded
end
function GuildNotes.Member(name)
    GuildNotes.Refresh()
    return name and members[name] or nil
end
function GuildNotes.Members()
    GuildNotes.Refresh()
    return members
end
function GuildNotes.MainOf(name)
    GuildNotes.Refresh()
    local l = links[name]
    if l then return l.main, l.src, l.srcs end
    return name, nil, nil
end
function GuildNotes.AltsOf(main)
    GuildNotes.Refresh()
    return altsOf[main] or {}
end
function GuildNotes.Links()
    GuildNotes.Refresh()
    return altsOf
end
function GuildNotes.SrcRank(src)
    return SRC_RANK[src or ""] or 99
end
function GuildNotes.Invalidate()
    dirty = true
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.guildnotes", function()
    dirty = true
end))
