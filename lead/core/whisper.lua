local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local W = {}
ns.Whisper = W
local PRIORITY = { hand = 3, inspect = 2, whisper = 1 }
local UTF8 = "[" .. string.char(192) .. "-" .. string.char(255) .. "]["
    .. string.char(128) .. "-" .. string.char(191) .. "]*"
local ENDING = 4
local STEM = 6
local lowerMap
local function lower(s)
    if not lowerMap then
        lowerMap = {}
        local up, lo = {}, {}
        for ch in ns.CYR_UPPER:gmatch(UTF8) do up[#up + 1] = ch end
        for ch in ns.CYR_LOWER:gmatch(UTF8) do lo[#lo + 1] = ch end
        for i = 1, #up do lowerMap[up[i]] = lo[i] end
    end
    s = s:lower()
    return (s:gsub(UTF8, function(ch) return lowerMap[ch] or ch end))
end
local phrases
local function dictionary()
    if phrases then return phrases end
    phrases = {}
    for key, list in pairs(ns.SLANG) do
        for _, ph in ipairs(list) do
            local words = {}
            for w in lower(ph):gmatch("[^%s]+") do words[#words + 1] = w end
            phrases[#phrases + 1] = { key = key, words = words, len = #ph }
        end
    end
    table.sort(phrases, function(a, b)
        if #a.words ~= #b.words then return #a.words > #b.words end
        return a.len > b.len
    end)
    return phrases
end
local function words(text)
    local out = {}
    local s = lower(text):gsub("[%p%d]", " ")
    for w in s:gmatch("[^%s]+") do out[#out + 1] = w end
    return out
end
local function wordFits(w, pw, single)
    if w == pw then return true end
    if not single or not w or #pw < STEM then return false end
    return #w > #pw and #w - #pw <= ENDING and w:sub(1, #pw) == pw
end
local function matchAt(ws, i, ph)
    local single = #ph.words == 1
    for k = 1, #ph.words do
        if not wordFits(ws[i + k - 1], ph.words[k], single) then return false end
    end
    return true
end
function W.Parse(text)
    local ws = words(text or "")
    local used = {}
    local found = {}
    for _, ph in ipairs(dictionary()) do
        for i = 1, #ws - #ph.words + 1 do
            local free = true
            for k = 0, #ph.words - 1 do
                if used[i + k] then free = false end
            end
            if free and matchAt(ws, i, ph) then
                for k = 0, #ph.words - 1 do used[i + k] = true end
                found[#found + 1] = { key = ph.key, at = i }
            end
        end
    end
    table.sort(found, function(a, b) return a.at < b.at end)
    local spec, off
    for _, hit in ipairs(found) do
        if not spec then
            spec = hit.key
        elseif hit.key ~= spec and not off and ns.SPEC[hit.key].class == ns.SPEC[spec].class then
            off = hit.key
        end
    end
    local gs = (text or ""):match("(%d[%.,]%d)") or (text or ""):match("(%d%d%d%d)")
    return spec, off, gs
end
local function waiting()
    local g = ns.Session.State()
    g.waiting = g.waiting or {}
    return g.waiting
end
function W.Waiting()
    local out = {}
    for name, w in pairs(waiting()) do
        out[#out + 1] = { name = name, spec = w.spec, off = w.off, gs = w.gs, text = w.text, at = w.at }
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end
function W.Drop(name)
    waiting()[name] = nil
    ns.Session.Changed()
end
function W.Clear()
    local g = ns.Session.State()
    g.waiting = {}
end
local function learn(name, spec, off)
    local p = ns.Session.Player(name)
    if spec and (PRIORITY[p.specSrc or ""] or 0) <= PRIORITY.whisper then
        p.spec, p.specSrc = spec, "whisper"
    end
    if off and (PRIORITY[p.offSrc or ""] or 0) <= PRIORITY.whisper then
        p.off, p.offSrc = off, "whisper"
    end
end
function W.Take(name, text)
    if not ns.Session.Active() or not name then return end
    local spec, off, gs = W.Parse(text)
    if not spec then return end
    learn(name, spec, off)
    if ns.Session.Member(name) then
        W.Place(name, spec)
    else
        waiting()[name] = { spec = spec, off = off, gs = gs, text = text, at = time() }
    end
    ns.Session.Changed()
end
function W.Place(name, spec)
    local S = ns.Session
    if S.SlotOf(name) then return end
    local m = S.Member(name)
    spec = spec or S.Player(name).spec
    if not m or not m.work or not spec then return end
    local tpl = S.Template()
    local exact, loose = {}, {}
    for i, slot in ipairs(tpl.slots) do
        if not S.SlotPlayer(i) and ns.Tpl.SpecFits(slot.role, spec) then
            local sig = slot.role .. ":" .. table.concat(slot.specs or {}, ",")
            local named = false
            for _, k in ipairs(slot.specs or {}) do
                if k == spec then named = true end
            end
            if named then
                exact[sig] = exact[sig] or i
            elseif not slot.specs then
                loose[sig] = loose[sig] or i
            end
        end
    end
    local function only(t)
        local one, n = nil, 0
        for _, i in pairs(t) do one, n = i, n + 1 end
        return n == 1 and one or nil
    end
    local pick = next(exact) and only(exact) or only(loose)
    if pick then S.Assign(pick, name) end
end
function W.Invite(name)
    InviteUnit(name)
end
local f = ns.NewFrame("Frame")
ns.Listen(f, "CHAT_MSG_WHISPER")
ns.Listen(f, "RAID_ROSTER_UPDATE")
ns.Listen(f, "PARTY_MEMBERS_CHANGED")
f:SetScript("OnEvent", function(self, event, msg, author)
    if event == "CHAT_MSG_WHISPER" then
        W.Take(author, msg)
        return
    end
    if not ns.Session.Active() then return end
    local list = waiting()
    local moved = false
    for name, w in pairs(list) do
        if ns.Session.Member(name) then
            list[name] = nil
            W.Place(name, w.spec)
            moved = true
        end
    end
    if moved then ns.Session.Changed() end
end)
