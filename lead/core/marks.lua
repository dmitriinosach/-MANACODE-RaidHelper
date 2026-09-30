local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local M = {}
ns.Marks = M
M.COUNT = 8
local DEBOUNCE = 0.3
local TICK = 1
local FIGHT_N = 3
local FIGHT_WINDOW = 20
local FIGHT_PAUSE = 60
local held, yielded, lent, paused, restores = {}, {}, {}, {}, {}
local listeners = {}
local last
local wait, acc = nil, 0
local fought, pending = false, false
local f
local function clear(t)
    for k in pairs(t) do t[k] = nil end
end
local function prefs()
    local db = ns.Store.DB()
    db.marks = db.marks or {}
    local p = db.marks
    if p.on == nil then p.on = true end
    if p.open == nil then p.open = true end
    return p
end
local function pins()
    local g = ns.Session.State()
    g.pins = g.pins or {}
    return g.pins
end
local function listOf(i)
    local p = pins()
    local v = p[i]
    if type(v) == "string" then
        v = { v }
        p[i] = v
    end
    if type(v) ~= "table" or not v[1] then return nil end
    return v
end
local function notify()
    for _, fn in ipairs(listeners) do fn() end
end
function M.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function M.Poke(now)
    wait = (now == true) and 0 or DEBOUNCE
    if f then f:Show() end
end
local function changed()
    last = nil
    ns.Session.Changed()
    notify()
    M.Poke()
end
function M.Enabled()
    return prefs().on
end
function M.SetEnabled(on)
    prefs().on = on and true or false
    changed()
end
function M.Open()
    return prefs().open
end
function M.SetOpen(on)
    prefs().open = on and true or false
    notify()
end
function M.InRaid()
    if ns.Test.Active() then return true end
    local raid = ns.Compat.GroupSize()
    return raid > 0
end
function M.CanMark()
    if ns.Test.Active() then return true end
    local raid = ns.Compat.GroupSize()
    if raid > 0 then return (IsRaidLeader() or IsRaidOfficer()) and true or false end
    return true
end
local function markOf(c)
    if ns.Test.Active() then
        local m = ns.Session.Member(c.name)
        return m and m.mark
    end
    return GetRaidTargetIndex(c.unit or c.name)
end
local function put(c, i)
    if ns.Test.Active() then
        ns.Test.Mark(c.name, i)
        return
    end
    SetRaidTarget(c.unit or c.name, i)
end
local function dead(c)
    if ns.Test.Active() then
        local m = ns.Session.Member(c.name)
        return not m or m.dead or not m.online
    end
    local u = c.unit
    if not u or UnitName(u) ~= c.name then return false end
    return (UnitIsDeadOrGhost(u) or not UnitIsConnected(u)) and true or false
end
local function state(name)
    local m = ns.Session.Member(name)
    if not m then return "away" end
    if not m.online then return "offline" end
    if m.dead then return "dead" end
    if not m.fake and m.unit and UnitIsDeadOrGhost(m.unit) then return "dead" end
    return "ok", m
end
local function candidates(i)
    local out, seen = {}, {}
    for k, n in ipairs(listOf(i) or {}) do
        if not seen[n] then
            seen[n] = true
            out[#out + 1] = { name = n, src = "pin", depth = k }
        end
    end
    local d = 0
    for k, s in ipairs(ns.Session.Template().slots) do
        if s.mark == i then
            local n = ns.Session.SlotPlayer(k)
            if n and not seen[n] then
                seen[n] = true
                d = d + 1
                out[#out + 1] = { name = n, src = "slot", slot = k, cap = s.cap, role = s.role, depth = d }
            end
        end
    end
    for _, c in ipairs(out) do
        local st, m = state(c.name)
        c.state = st
        c.unit = m and m.unit
    end
    return out
end
local function atDepth(e, src, depth)
    for _, c in ipairs(e.list) do
        if c.src == src and c.depth == depth then return c end
    end
end
local function pick(plan, used, src)
    local depth = 1
    while true do
        local more = false
        for i = 1, M.COUNT do
            local e = plan[i]
            local c = not e.owner and atDepth(e, src, depth)
            if c then
                more = true
                if c.state == "ok" and not used[c.name] then
                    e.owner = c
                    used[c.name] = true
                end
            end
        end
        if not more then return end
        depth = depth + 1
    end
end
function M.Plan()
    local plan, used = {}, {}
    for i = 1, M.COUNT do
        plan[i] = { i = i, list = candidates(i) }
    end
    pick(plan, used, "pin")
    pick(plan, used, "slot")
    for i = 1, M.COUNT do
        local e = plan[i]
        local o = e.owner
        if o then
            e.now = markOf(o) == i
            local after = false
            for _, c in ipairs(e.list) do
                if after and c.state == "ok" and not used[c.name] then
                    e.next = c
                    break
                end
                if c == o then after = true end
            end
        end
    end
    return plan
end
function M.HasPlan(plan)
    plan = plan or M.View()
    for i = 1, M.COUNT do
        if plan[i].list[1] then return true end
    end
    return false
end
function M.View(i)
    if not last then last = M.Plan() end
    if i then return last[i] end
    return last
end
function M.Flags(i)
    local now = GetTime()
    return yielded[i] and true or false, lent[i] and true or false,
        (paused[i] and paused[i] > now) and true or false
end
local function hold(i, c)
    for j = 1, M.COUNT do
        if j ~= i and held[j] and held[j].name == c.name then held[j] = nil end
    end
    held[i] = c
end
local function restore(i, name, now)
    local r = restores[i]
    if not r or r.name ~= name then
        r = { name = name }
        restores[i] = r
    end
    for k = #r, 1, -1 do
        if now - r[k] > FIGHT_WINDOW then table.remove(r, k) end
    end
    r[#r + 1] = now
    if #r >= FIGHT_N then
        paused[i] = now + FIGHT_PAUSE
        restores[i] = nil
        ns.say(ns.T("marksFight", ns.T("mark" .. i)))
        return false
    end
    return true
end
local function stay(i, o, fight)
    local h = held[i]
    if not fight or not h or h.name == o.name then return false end
    return markOf(h) == i and not dead(h)
end
local function place(i, e, fight, now)
    local o = e.owner
    if lent[i] or yielded[i] or paused[i] then
        if paused[i] then pending = true end
        return
    end
    if fight and not held[i] then
        pending = true
        return
    end
    if stay(i, o, fight) then return end
    local again = held[i] and held[i].name == o.name
    if again and not restore(i, o.name, now) then
        pending = true
        return
    end
    hold(i, o)
    e.now = true
    put(o, i)
end
function M.Active()
    return prefs().on and M.InRaid() and M.CanMark() and ns.Keeper.Mine()
end
local function keep()
    last = M.Plan()
    pending = false
    local want = prefs().on and M.InRaid() and M.CanMark() and M.HasPlan(last)
    ns.Keeper.Update(want)
    if not M.Active() then
        if want then pending = true end
        return
    end
    local fight = InCombatLockdown()
    local now = GetTime()
    for i = 1, M.COUNT do
        if paused[i] and paused[i] <= now then paused[i] = nil end
        local e = last[i]
        if e.owner and e.now then
            hold(i, e.owner)
        elseif e.owner then
            place(i, e, fight, now)
        elseif e.list[1] then
            pending = true
        end
    end
end
local function taken()
    if not InCombatLockdown() then return end
    for i = 1, M.COUNT do
        local h = held[i]
        if h and not yielded[i] and markOf(h) ~= i and not dead(h) then
            yielded[i] = true
        end
    end
end
local function watch()
    local need = false
    for i = 1, M.COUNT do
        local h = held[i]
        if h and not yielded[i] and not lent[i] then
            local d = dead(h)
            if d ~= (h.dead or false) then
                h.dead = d
                need = true
            end
        end
    end
    return need
end
local function trim(text)
    text = (text or ""):gsub("[%c|]", "")
    text = text:gsub("^[ \t]+", "")
    text = text:gsub("[ \t]+$", "")
    return text
end
function M.Resolve(text)
    text = trim(text)
    if text == "" then return nil end
    local hit, n = nil, 0
    for _, m in ipairs(ns.Session.Roster()) do
        if m.name == text then return text end
        if m.name and m.name:sub(1, #text) == text then hit, n = m.name, n + 1 end
    end
    if n == 1 then return hit end
    return text
end
function M.Pins(i)
    return listOf(i) or {}
end
function M.Pin(i)
    local l = listOf(i)
    return l and l[1]
end
function M.PinText(i)
    return table.concat(M.Pins(i), ", ")
end
local function calm(i)
    lent[i], paused[i], restores[i], yielded[i] = nil, nil, nil, nil
end
function M.SetPins(i, text)
    local out, seen = {}, {}
    for word in trim(text):gmatch("[^ \t,;%.]+") do
        local n = M.Resolve(word)
        if n and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    pins()[i] = out[1] and out or nil
    calm(i)
    changed()
end
local function pinFirst(i, name)
    local p = pins()
    for k = 1, M.COUNT do
        local l = listOf(k)
        if l then
            for j = #l, 1, -1 do
                if l[j] == name then table.remove(l, j) end
            end
            if not l[1] then p[k] = nil end
        end
    end
    local l = listOf(i) or {}
    table.insert(l, 1, name)
    p[i] = l
    calm(i)
end
function M.Target(i)
    if not M.CanMark() then return "rights" end
    if not UnitExists("target") then return "none" end
    local name = UnitName("target")
    local m = UnitIsPlayer("target") and name and ns.Session.Member(name)
    if m then
        pinFirst(i, name)
        local c = { name = name, unit = m.unit }
        hold(i, c)
        if markOf(c) ~= i then put(c, i) end
        changed()
        return "pin"
    end
    lent[i], yielded[i], paused[i] = true, nil, nil
    if GetRaidTargetIndex("target") ~= i then SetRaidTarget("target", i) end
    changed()
    return "once"
end
function M.Release(i)
    if not M.CanMark() then return "rights" end
    pins()[i] = nil
    lent[i], yielded[i], paused[i], restores[i] = nil, nil, nil, nil
    last = M.Plan()
    if not last[i].owner then
        local h = held[i]
        held[i] = nil
        if h and markOf(h) == i then
            put(h, 0)
        elseif UnitExists("target") and GetRaidTargetIndex("target") == i then
            SetRaidTarget("target", 0)
        end
    end
    changed()
    return "free"
end
M.KEY = "RAIDLEAD_MARK"
function M.KeyOf(i)
    local key = GetBindingKey(M.KEY .. i)
    return key and GetBindingText(key, "KEY_")
end
function M.Key(i)
    local r = M.Target(i)
    if r == "rights" then
        ns.say(ns.T("tipNeedOfficer"))
    elseif r == "none" then
        ns.say(ns.T("keysNoTarget"))
    end
    return r
end
function M.KeyRelease()
    if not M.CanMark() then
        ns.say(ns.T("tipNeedOfficer"))
        return "rights"
    end
    if not UnitExists("target") then
        ns.say(ns.T("keysNoTarget"))
        return "none"
    end
    local name = UnitName("target")
    for i = 1, M.COUNT do
        local l = listOf(i)
        if l then
            for j = #l, 1, -1 do
                if l[j] == name then
                    if l[2] then
                        table.remove(l, j)
                        if held[i] and held[i].name == name then held[i] = nil end
                        calm(i)
                        changed()
                        return "free"
                    end
                    return M.Release(i)
                end
            end
        end
    end
    local i = GetRaidTargetIndex("target")
    if i and i >= 1 and i <= M.COUNT then return M.Release(i) end
    ns.say(ns.T("keysNoPin"))
    return "none"
end
BINDING_HEADER_RAIDLEAD = ns.T("keysHeader")
BINDING_NAME_RAIDLEAD_MARK1 = ns.T("keysMark1")
BINDING_NAME_RAIDLEAD_MARK2 = ns.T("keysMark2")
BINDING_NAME_RAIDLEAD_MARK3 = ns.T("keysMark3")
BINDING_NAME_RAIDLEAD_MARK4 = ns.T("keysMark4")
BINDING_NAME_RAIDLEAD_MARK5 = ns.T("keysMark5")
BINDING_NAME_RAIDLEAD_MARK6 = ns.T("keysMark6")
BINDING_NAME_RAIDLEAD_MARK7 = ns.T("keysMark7")
BINDING_NAME_RAIDLEAD_MARK8 = ns.T("keysMark8")
BINDING_NAME_RAIDLEAD_RELEASE = ns.T("keysRelease")
function M.Grab()
    local n = 0
    for _, m in ipairs(ns.Session.Roster()) do
        local i = markOf({ name = m.name, unit = m.unit })
        if i and i >= 1 and i <= M.COUNT then
            pins()[i] = { m.name }
            calm(i)
            n = n + 1
        end
    end
    changed()
    return n
end
function M.ClearAll()
    if not M.CanMark() then return "rights" end
    prefs().on = false
    clear(held)
    for _, m in ipairs(ns.Session.Roster()) do
        local c = { name = m.name, unit = m.unit }
        if markOf(c) then put(c, 0) end
    end
    changed()
    return "off"
end
local STATE_KEY = { ok = "marksStBusy", away = "marksStAway", offline = "marksStOffline", dead = "marksStDead" }
local function ownerLine(c)
    if c.src == "pin" then return ns.T("marksTipPin", c.name) end
    return ns.T("marksTipSlot", c.cap or ns.T("slot_" .. (c.role or "dd")), c.name)
end
function M.Describe(i)
    local e = M.View(i)
    local lines = {}
    local o = e.owner
    if o then
        lines[#lines + 1] = ownerLine(o)
        if o ~= e.list[1] then
            local first = e.list[1]
            lines[#lines + 1] = ns.T("marksTipInstead", first.name, ns.T(STATE_KEY[first.state] or "marksStDead"))
        end
        if e.next then lines[#lines + 1] = ns.T("marksTipNext", e.next.name) end
    elseif e.list[1] then
        local first = e.list[1]
        lines[#lines + 1] = ownerLine(first)
        lines[#lines + 1] = ns.T("marksTipNoOne", ns.T(STATE_KEY[first.state] or "marksStDead"))
    else
        lines[#lines + 1] = ns.T("marksTipFree")
    end
    local yielded, lent, paused = M.Flags(i)
    if yielded then lines[#lines + 1] = ns.T("marksTipYield") end
    if lent then lines[#lines + 1] = ns.T("marksTipLent") end
    if paused then lines[#lines + 1] = ns.T("marksTipPaused") end
    if not M.Enabled() then
        lines[#lines + 1] = ns.T("marksTipOff")
    elseif e.list[1] and M.InRaid() then
        local who = ns.Keeper.Who()
        if who and who ~= UnitName("player") then lines[#lines + 1] = ns.T("marksTipKeeper", who) end
    end
    return table.concat(lines, "\n")
end
function M.Sync()
    keep()
    notify()
end
f = ns.NewFrame("Frame")
ns.Listen(f, "RAID_TARGET_UPDATE")
ns.Listen(f, "RAID_ROSTER_UPDATE")
ns.Listen(f, "PARTY_MEMBERS_CHANGED")
ns.Listen(f, "PLAYER_REGEN_DISABLED")
ns.Listen(f, "PLAYER_REGEN_ENABLED")
ns.Listen(f, "PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "RAID_TARGET_UPDATE" then
        taken()
    elseif event == "PLAYER_REGEN_DISABLED" then
        fought = true
        if next(held) then self:Show() end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        clear(yielded)
        if fought then clear(lent) end
        fought = false
    end
    M.Poke()
end)
f:SetScript("OnUpdate", function(self, dt)
    if wait then
        wait = wait - dt
        if wait > 0 then return end
        wait = nil
        acc = 0
        M.Sync()
    else
        acc = acc + dt
        if acc < TICK then return end
        acc = 0
        if InCombatLockdown() then
            if watch() then
                ns.Session.Invalidate()
                M.Sync()
            end
        elseif pending then
            M.Sync()
        end
    end
    if not wait and not pending and not (InCombatLockdown() and next(held)) then self:Hide() end
end)
ns.Session.OnChange(function() M.Poke() end)
