local _, ns = ...
local format = string.format
local floor = math.floor
local huge = math.huge
local PERIOD = 5
local SOON = 600
local AURAS = 40
local LIST = 10
local GROW = 60
local LONG = 3000
local CAST_SLACK = 10
local SEEN_MAX = 200
local SUB = "FW_FLASK"
local Ready = {}
ns.FlaskReady = Ready
Ready.PERIOD = PERIOD
Ready.SOON = SOON
Ready.SUB = SUB
local members = {}
local count = 0
local scanAt
local dirty = true
local RAID, PARTY = ns.Units.raid, ns.Units.party
local FED, FED_EN, FED_ES = ns.T("flaskrow.fed"), ns.LEN and ns.LEN["flaskrow.fed"], ns.LES and ns.LES["flaskrow.fed"]
local function Cat(id)
    if not id then return nil end
    local c = (ns.consumeCast and ns.consumeCast[id]) or (ns.consumeGen and ns.consumeGen[id])
    return c and c.cat or nil
end
local seenEnd = {}
local seenId = {}
local castAt = {}
local seenN = 0
function Ready.Cast(name)
    if name then castAt[name] = GetTime() end
end
local function Observe(name, id, ends, dur)
    if not (ends and ends > 0 and dur and dur >= LONG) then return end
    local was, wasId = seenEnd[name], seenId[name]
    if not was then
        seenN = seenN + 1
        if seenN > SEEN_MAX then
            wipe(seenEnd)
            wipe(seenId)
            wipe(castAt)
            seenN = 1
        end
    end
    seenEnd[name], seenId[name] = ends, id
    if not was or (id == wasId and ends <= was + GROW) then return end
    local R = ns.Recorder
    local since = R and R.HearSince()
    local drank = ends - dur
    if not since or drank < since then return end
    local cast = castAt[name]
    if cast and cast >= drank - CAST_SLACK then return end
    R.Mark(SUB, nil, name, 0, nil, nil, 0, id)
end
local function Slot(i)
    local m = members[i]
    if not m then
        m = {}
        members[i] = m
    end
    m.name, m.class, m.why, m.flask, m.elixEnd, m.food = nil, nil, nil, nil, nil, nil
    m.elix = 0
    return m
end
local function Earlier(a, b)
    if a and a < b then return a end
    return b
end
local function ReadAuras(m, unit)
    for i = 1, AURAS do
        local aura, _, _, _, _, dur, expires, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then break end
        local ends = (expires and expires > 0) and expires or huge
        local cat = Cat(id)
        if cat == "flask" then
            m.flask = Earlier(m.flask, ends)
            Observe(m.name, id, expires, dur)
        elseif cat == "elixir" then
            m.elix = m.elix + 1
            m.elixEnd = Earlier(m.elixEnd, ends)
        elseif aura == FED or aura == FED_EN or aura == FED_ES then
            m.food = Earlier(m.food, ends)
        end
    end
end
local function Add(unit)
    local name = UnitName(unit)
    if not name then return end
    count = count + 1
    local m = Slot(count)
    m.name = name
    local _, class = UnitClass(unit)
    m.class = class
    if not UnitIsConnected(unit) then
        m.why = "offline"
    elseif not UnitIsVisible(unit) then
        m.why = "far"
    else
        ReadAuras(m, unit)
    end
end
local auraName = {}
local function Look(unit)
    local name = UnitName(unit)
    if not name or not UnitIsVisible(unit) then return end
    local had = seenId[name]
    if had then
        local an = auraName[had]
        if an == nil then
            an = GetSpellInfo(had) or false
            auraName[had] = an
        end
        if an then
            local aura, _, _, _, _, dur, expires, _, _, _, id = UnitAura(unit, an)
            if aura and Cat(id) == "flask" then
                Observe(name, id, expires, dur)
                return
            end
        end
    end
    for i = 1, AURAS do
        local aura, _, _, _, _, dur, expires, _, _, _, id = UnitAura(unit, i, "HELPFUL")
        if not aura then return end
        if Cat(id) == "flask" then
            Observe(name, id, expires, dur)
            return
        end
    end
end
function Ready.Pull()
    local n = GetNumRaidMembers() or 0
    if n > 0 then
        for i = 1, n do Look(RAID[i]) end
        return
    end
    Look("player")
    for i = 1, GetNumPartyMembers() or 0 do Look(PARTY[i]) end
end
local function Scan()
    count = 0
    local n = GetNumRaidMembers() or 0
    if n > 0 then
        for i = 1, n do Add(RAID[i]) end
    else
        Add("player")
        for i = 1, GetNumPartyMembers() or 0 do Add(PARTY[i]) end
    end
    for i = count + 1, #members do members[i] = nil end
    scanAt = GetTime()
    dirty = false
end
local function Pot(m)
    if m.flask then return true, m.flask end
    if m.elix >= 2 then return true, m.elixEnd end
    return false, nil
end
local function IsReady(m)
    return not m.why and Pot(m) and m.food ~= nil
end
function Ready.Has(m)
    return (Pot(m)), m.food ~= nil
end
function Ready.Tick(force)
    if UnitAffectingCombat("player") then return false end
    local now = GetTime()
    if not force and not dirty and scanAt and now - scanAt < PERIOD then return false end
    Scan()
    return true
end
function Ready.Dirty()
    dirty = true
end
function Ready.Counts()
    local ready = 0
    for i = 1, count do
        if IsReady(members[i]) then ready = ready + 1 end
    end
    return ready, count, scanAt ~= nil
end
function Ready.Members()
    return members
end
local Clock = ns.Clock
local function Section(rows, title, list, tone)
    if #list == 0 then return end
    rows[#rows + 1] = { kind = "row", left = title, right = tostring(#list), tone = tone }
    for i = 1, #list do
        if i > LIST then
            rows[#rows + 1] = { kind = "sub", left = format(ns.T("flaskrow.more"), #list - LIST) }
            break
        end
        rows[#rows + 1] = list[i]
    end
end
local function Who(m, right)
    return { kind = "sub", left = m.name, class = m.class, right = right }
end
local function SoonText(m, now)
    local _, potEnd = Pot(m)
    local key, ends = nil, huge
    if potEnd and potEnd - now < SOON then
        key, ends = m.flask and "flaskrow.flask" or "flaskrow.elixir", potEnd
    end
    if m.food and m.food - now < SOON and m.food < ends then
        key, ends = "flaskrow.food", m.food
    end
    if not key then return nil end
    return format(ns.T(key), Clock(ends - now))
end
function Ready.TipRows()
    local ready, total, known = Ready.Counts()
    local rows = { { kind = "head", left = ns.T("flaskrow.head"), right = known and format("%d/%d", ready, total) or nil } }
    if not known then
        rows[2] = { kind = "note", left = ns.T("flaskrow.never") }
        return rows
    end
    local now = GetTime()
    local noPot, noFood, soon, none = {}, {}, {}, {}
    for i = 1, count do
        local m = members[i]
        if m.why then
            none[#none + 1] = Who(m, ns.T("flaskrow.why." .. m.why))
        else
            if not Pot(m) then
                noPot[#noPot + 1] = Who(m, m.elix == 1 and ns.T("flaskrow.elix1") or nil)
            end
            if not m.food then noFood[#noFood + 1] = Who(m) end
            local s = SoonText(m, now)
            if s then soon[#soon + 1] = Who(m, s) end
        end
    end
    Section(rows, ns.T("flaskrow.nopot"), noPot, "bad")
    Section(rows, ns.T("flaskrow.nofood"), noFood, "bad")
    Section(rows, format(ns.T("flaskrow.soon"), floor(SOON / 60)), soon, "warn")
    Section(rows, ns.T("flaskrow.none"), none, "dim")
    local age = Clock(now - scanAt)
    rows[#rows + 1] = { kind = "note",
        left = format(ns.T(UnitAffectingCombat("player") and "flaskrow.fight" or "flaskrow.age"), age) }
    return rows
end
local watch = CreateFrame("Frame")
watch:RegisterEvent("RAID_ROSTER_UPDATE")
watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
watch:SetScript("OnEvent", Ready.Dirty)
