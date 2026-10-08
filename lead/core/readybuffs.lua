local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local R = {}
ns.ReadyBuffs = R
local AURAS = 40
local EVERY = 2
local HOLD = 300
local GIVERS = 3
local CHAT_MAX = 240
local result
local checking = false
local listeners = {}
local names = {}
local function spellName(id)
    local n = names[id]
    if n == nil then
        n = ns.Compat.SpellName(id) or false
        names[id] = n
    end
    return n or nil
end
local function notify()
    for _, fn in ipairs(listeners) do fn() end
end
function R.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function needOf(class, tree)
    local t = ns.READY_NEED[class]
    if not t then return {} end
    if tree and t[tree] then return t[tree] end
    local out = {}
    for flag in pairs(t[1]) do
        local all = true
        for i = 2, #t do
            if not t[i][flag] then all = false end
        end
        if all then out[flag] = true end
    end
    return out
end
local function readAuras(unit)
    local a = { names = {}, ids = {}, own = {} }
    for i = 1, AURAS do
        local name, caster, id = ns.Compat.Buff(unit, i)
        if not name then break end
        a.names[name] = true
        if id then a.ids[id] = true end
        if caster and UnitIsUnit(caster, unit) then a.own[name] = true end
    end
    return a
end
local function has(a, list, own)
    for _, id in ipairs(list) do
        local n = spellName(id)
        if own then
            if n and a.own[n] then return true end
        elseif a.ids[id] or (n and a.names[n]) then
            return true
        end
    end
    return false
end
local function people(roster)
    local out = {}
    for _, m in ipairs(roster) do
        if m.name and m.class then
            local key, tree = ns.Buffs.Who(m)
            out[#out + 1] = { m = m, name = m.name, class = m.class, key = key, tree = tree }
        end
    end
    return out
end
local function giversOf(list)
    local out, pals = {}, {}
    for _, def in ipairs(ns.READY_RAID) do
        local who = {}
        for _, p in ipairs(list) do
            if p.m.online and p.class == def.cls and (not def.tree or p.tree == def.tree) then
                who[#who + 1] = p.name
            end
        end
        out[def.key] = who
    end
    for _, p in ipairs(list) do
        if p.m.online and p.class == ns.READY_PALADIN then pals[#pals + 1] = p.name end
    end
    return out, pals
end
local function lackRaid(e, a, need, givers)
    for _, def in ipairs(ns.READY_RAID) do
        if #givers[def.key] > 0 and (not def.need or need[def.need]) and not has(a, def.auras) then
            e.lack[#e.lack + 1] = { kind = "raid", key = def.key, icon = def.auras[1] }
        end
    end
end
local function lackBless(e, a, need, pals)
    if pals == 0 then return end
    local want, miss, have = 0, {}, 0
    for _, def in ipairs(ns.READY_BLESS) do
        local on = has(a, def.auras)
        if def.extra then
            if on then have = have + 1 end
        elseif not def.need or need[def.need] then
            want = want + 1
            if on then have = have + 1 else miss[#miss + 1] = def end
        end
    end
    local short = math.min(pals, want) - have
    for i = 1, math.min(short, #miss) do
        local def = miss[i]
        e.lack[#e.lack + 1] = { kind = "bless", key = def.key, icon = def.auras[1] }
    end
end
local function lackOwn(e, a, p)
    local defs = (p.key and ns.READY_OWN[p.key]) or ns.READY_OWN[p.class]
    for _, def in ipairs(defs or {}) do
        if not has(a, def, def.own) then
            e.lack[#e.lack + 1] = { kind = "own", ids = def, label = def.label, icon = def[1] }
        end
    end
end
local function lackPots(e, fm, F)
    if not fm or fm.why then return end
    local pot, food = F.Has(fm)
    if not pot then e.lack[#e.lack + 1] = { kind = "pot", icon = ns.READY_ICON.pot, elix = fm.elix } end
    if not food then e.lack[#e.lack + 1] = { kind = "food", icon = ns.READY_ICON.food } end
end
local function why(m)
    if m.fake then return "test" end
    if not m.unit then return "far" end
    if not m.online or not UnitIsConnected(m.unit) then return "offline" end
    if UnitIsDeadOrGhost(m.unit) then return "dead" end
    if not UnitIsVisible(m.unit) then return "far" end
    return nil
end
local function potsByName()
    local F = root.FlaskReady
    if not (F and F.Tick and F.Members and F.Has) or (ns.Test and ns.Test.Active()) then return {}, nil end
    F.Tick(true)
    local out = {}
    for _, fm in ipairs(F.Members()) do
        if fm.name then out[fm.name] = fm end
    end
    return out, F
end
function R.Scan()
    if InCombatLockdown() then return false end
    local raid, party = ns.Compat.GroupSize()
    if raid + party == 0 and not (ns.Test and ns.Test.Active()) then return false end
    local list = people(ns.Session.Roster())
    local givers, pals = giversOf(list)
    local pots, F = potsByName()
    local res = { at = GetTime(), list = {}, by = {}, givers = givers, pals = pals }
    for _, p in ipairs(list) do
        local e = { name = p.name, class = p.class, lack = {} }
        e.why = why(p.m)
        if not e.why then
            local a = readAuras(p.m.unit)
            local need = needOf(p.class, p.tree)
            lackRaid(e, a, need, givers)
            lackBless(e, a, need, #pals)
            lackOwn(e, a, p)
            if F then lackPots(e, pots[p.name], F) end
        end
        res.list[#res.list + 1] = e
        res.by[p.name] = e
    end
    result = res
    notify()
    return true
end
function R.Checking()
    return checking
end
function R.Active()
    if not result then return false end
    return checking or GetTime() - result.at < HOLD
end
function R.Of(name)
    if not R.Active() then return nil end
    return result.by[name]
end
function R.Counts()
    if not R.Active() then return 0, 0, 0 end
    local bad, seen, none = 0, 0, 0
    for _, e in ipairs(result.list) do
        if e.why then
            none = none + 1
        else
            seen = seen + 1
            if #e.lack > 0 then bad = bad + 1 end
        end
    end
    return bad, seen, none
end
function R.Result()
    return R.Active() and result or nil
end
function R.Age()
    return result and (GetTime() - result.at) or nil
end
function R.Label(it)
    if it.kind == "raid" or it.kind == "bless" then return ns.T("rdy_" .. it.key) end
    if it.kind == "pot" then return it.elix == 1 and ns.T("rdyPotElix") or ns.T("rdyPot") end
    if it.kind == "food" then return ns.T("rdyFood") end
    if it.label then return ns.T("rdyOwn_" .. it.label) end
    local out = {}
    for _, id in ipairs(it.ids) do out[#out + 1] = spellName(id) or ("#" .. id) end
    return table.concat(out, ns.T("rdyOr"))
end
local function short(list, n)
    n = n or GIVERS
    local out = {}
    for i = 1, math.min(#list, n) do out[i] = list[i] end
    local s = table.concat(out, ", ")
    if #list > n then s = s .. " +" .. (#list - n) end
    return s
end
R.Short = short
local function chatLine(label, givers, who)
    local head = ns.T("rdyChatLine", label, short(givers))
    local s, n = head, 0
    for i, name in ipairs(who) do
        local add = (i == 1 and "" or ", ") .. name
        if #s + #add > CHAT_MAX then
            s = s .. " +" .. (#who - n)
            break
        end
        s, n = s .. add, n + 1
    end
    return s
end
function R.ChatLines()
    local res = R.Result()
    if not res then return {} end
    local out = {}
    local function add(kind, key, givers)
        local who = {}
        for _, e in ipairs(res.list) do
            for _, it in ipairs(e.lack) do
                if it.kind == kind and it.key == key then who[#who + 1] = e.name end
            end
        end
        if #who > 0 then out[#out + 1] = chatLine(ns.T("rdy_" .. key), givers, who) end
    end
    for _, def in ipairs(ns.READY_BLESS) do
        if not def.extra then add("bless", def.key, res.pals) end
    end
    for _, def in ipairs(ns.READY_RAID) do add("raid", def.key, res.givers[def.key]) end
    return out
end
function R.Send()
    local lines = R.ChatLines()
    if #lines == 0 then return 0 end
    local raid, party = ns.Compat.GroupSize()
    local chan = raid > 0 and "RAID" or (party > 0 and "PARTY") or nil
    for _, line in ipairs(lines) do
        if chan and not (ns.Test and ns.Test.Active()) then SendChatMessage(line, chan) else ns.say(line) end
    end
    return #lines
end
function R.Clear()
    if not result then return end
    result = nil
    notify()
end
local f = ns.NewFrame("Frame")
ns.Listen(f, "READY_CHECK")
ns.Listen(f, "READY_CHECK_FINISHED")
ns.Listen(f, "PLAYER_REGEN_DISABLED")
ns.Listen(f, "UNIT_AURA")
local acc, shown = 0, false
local dirty = false
f:SetScript("OnEvent", function(_, ev, unit)
    if ev == "UNIT_AURA" then
        if result and not checking and type(unit) == "string"
            and (unit == "player" or unit:find("^raid%d") or unit:find("^party%d")) then
            dirty = true
        end
    elseif ev == "READY_CHECK" then
        checking, acc = true, 0
        R.Scan()
    elseif ev == "READY_CHECK_FINISHED" then
        checking = false
        R.Scan()
    else
        checking = false
        R.Clear()
    end
end)
f:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < EVERY then return end
    acc = 0
    if checking then
        R.Scan()
        return
    end
    if dirty and R.Active() then
        dirty = false
        local at = result.at
        if R.Scan() and result then result.at = at end
    end
    local on = R.Active()
    if shown and not on then notify() end
    shown = on
end)
