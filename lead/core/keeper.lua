local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local K = {}
ns.Keeper = K
K.PREFIX = "MRHMK"
local GRACE = 2
local TIE = 2
local REPLY_GAP = 5
local MAX_AGE = 86400
local peers = {}
local replied = {}
local since
local function forget()
    for k in pairs(peers) do peers[k] = nil end
    for k in pairs(replied) do replied[k] = nil end
end
local function age()
    return math.floor(GetTime() - since)
end
function K.Update(want)
    if ns.Test.Active() then return end
    local raid = ns.Compat.GroupSize()
    if raid == 0 then
        since = nil
        forget()
        return
    end
    if want and not since then
        since = GetTime()
        ns.Comm.Send(K.PREFIX, "ON:0", "RAID")
    elseif not want and since then
        since = nil
        ns.Comm.Send(K.PREFIX, "OFF", "RAID")
    end
end
local function better(a, b)
    if not b then return true end
    if a.lead ~= b.lead then return a.lead end
    if math.abs(a.at - b.at) > TIE then return a.at < b.at end
    return a.name < b.name
end
function K.Who()
    if ns.Test.Active() then return UnitName("player") end
    local best
    if since then
        best = { name = UnitName("player"), at = since, lead = IsRaidLeader() and true or false }
    end
    for name, at in pairs(peers) do
        local m = ns.Session.Member(name)
        if m and m.online and (m.rank or 0) >= 1 then
            local c = { name = name, at = at, lead = m.rank == 2 }
            if better(c, best) then best = c end
        end
    end
    return best and best.name
end
function K.Mine()
    if ns.Test.Active() then return true end
    if not since or GetTime() - since < GRACE then return false end
    return K.Who() == UnitName("player")
end
function K.Peers()
    local out = {}
    for name in pairs(peers) do out[#out + 1] = name end
    table.sort(out)
    return out
end
ns.Comm.On(K.PREFIX, function(msg, sender, chan)
    if chan ~= "RAID" and chan ~= "PARTY" then return end
    local kind, n = msg:match("^(%u+):?(%d*)$")
    if kind == "ON" or kind == "RE" then
        n = tonumber(n) or 0
        if n > MAX_AGE then n = MAX_AGE end
        peers[sender] = GetTime() - n
        if kind == "ON" and since then
            local t = replied[sender]
            if not t or GetTime() - t > REPLY_GAP then
                replied[sender] = GetTime()
                ns.Comm.Send(K.PREFIX, "RE:" .. age(), "RAID")
            end
        end
    elseif kind == "OFF" then
        peers[sender] = nil
    else
        return
    end
    if ns.Marks then ns.Marks.Poke() end
end)
