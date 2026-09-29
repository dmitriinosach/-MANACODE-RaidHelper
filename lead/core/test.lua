local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local X = {}
ns.Test = X
local RESERVE = 3
local RESERVE_GROUP = 8
local fake
local waitSize
function X.Active()
    return fake ~= nil
end
local function build(size)
    local all = ns.Compat.GuildMembers()
    if #all == 0 then return false end
    table.sort(all, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    local me = UnitName("player")
    local list = {}
    for _, g in ipairs(all) do
        if g.name ~= me then list[#list + 1] = g end
        if #list >= size + RESERVE then break end
    end
    fake = {}
    for i, g in ipairs(list) do
        local sub = i <= size and math.floor((i - 1) / 5) + 1 or RESERVE_GROUP
        fake[i] = { index = i, name = g.name, class = g.class, sub = sub, online = g.online,
            dead = (i == 4), rank = (i == 1) and 2 or ((i == 2) and 1 or 0),
            role = (i == 2) and "MAINTANK" or nil, ml = (i == 1), mark = (i == 3) and 8 or nil }
    end
    return true
end
local function done()
    ns.Session.Invalidate()
    ns.Session.Changed()
end
function X.Start(size)
    size = tonumber(size) or ns.Session.Template().size
    if not IsInGuild() then
        ns.say(ns.T("testNoGuild"))
        return
    end
    if build(size) then
        ns.say(ns.T("testOn", #fake))
        done()
    else
        waitSize = size
        ns.Compat.RefreshGuild()
        ns.say(ns.T("testWait"))
    end
end
function X.Stop()
    if not fake then return end
    fake = nil
    ns.say(ns.T("testOff"))
    done()
end
function X.Roster()
    return fake
end
local function byIndex(i)
    for _, m in ipairs(fake or {}) do
        if m.index == i then return m end
    end
end
local function byName(name)
    for _, m in ipairs(fake or {}) do
        if m.name == name then return m end
    end
end
function X.Move(index, sub)
    local m = byIndex(index)
    if m then m.sub = sub end
    done()
end
function X.Swap(i1, i2)
    local a, b = byIndex(i1), byIndex(i2)
    if a and b then a.sub, b.sub = b.sub, a.sub end
    done()
end
function X.Mark(name, idx)
    for _, m in ipairs(fake or {}) do
        if m.mark == idx and idx ~= 0 then m.mark = nil end
    end
    local m = byName(name)
    if m then m.mark = (idx ~= 0) and idx or nil end
    done()
end
function X.Act(key, name, on)
    local m = byName(name)
    if not m then return end
    if key == "mt" or key == "ma" then
        local role = key == "mt" and "MAINTANK" or "MAINASSIST"
        m.role = (not on) and role or nil
    elseif key == "assist" then
        m.rank = on and 0 or 1
    elseif key == "ml" then
        for _, x in ipairs(fake) do x.ml = false end
        m.ml = true
    elseif key == "kick" then
        for i, x in ipairs(fake) do
            if x == m then table.remove(fake, i) break end
        end
    end
    done()
end
local f = ns.NewFrame("Frame")
ns.Listen(f, "GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function()
    if not waitSize then return end
    local size = waitSize
    if build(size) then
        waitSize = nil
        ns.say(ns.T("testOn", #fake))
        done()
    end
end)
