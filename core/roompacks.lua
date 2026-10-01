local _, ns = ...
local Rooms = { live = {}, height = {} }
ManaCodeRaidHelperRooms = Rooms
ns.roomLive, ns.roomHeight = Rooms.live, Rooms.height
local PREFIX = "ManaCode_RaidHelper_"
local Packs = { LIST = { "ICC", "RS", "ULD" } }
ns.RoomPacks = Packs
local tried = {}
function Packs.Name(code)
    return PREFIX .. code
end
function Packs.Label(code)
    return ns.T("pack." .. code)
end
function Packs.State(code)
    local name = PREFIX .. code
    if IsAddOnLoaded(name) then return "on" end
    local _, _, _, _, _, reason = GetAddOnInfo(name)
    if reason == "MISSING" then return "missing" end
    if tried[code] == false then return "off" end
    return "idle"
end
function Packs.Load(room)
    local code = room and room.pack
    if not code then return false end
    if Rooms.live[room.tex] then return true end
    local name = PREFIX .. code
    if not IsAddOnLoaded(name) and tried[code] == nil then
        tried[code] = LoadAddOn(name) and true or false
    end
    return Rooms.live[room.tex] ~= nil
end
function Packs.Missing(room)
    if not room or not room.pack or Rooms.live[room.tex] then return nil end
    local state = Packs.State(room.pack)
    if state == "missing" or state == "off" then return room.pack end
    return nil
end
function Packs.Hint(room)
    local code = Packs.Missing(room)
    if not room then
        for _, c in ipairs(Packs.LIST) do
            local state = Packs.State(c)
            if (state == "missing" or state == "off") and Packs.HasRooms(c) then
                code = c
                break
            end
        end
    end
    if not code then return "" end
    local key = Packs.State(code) == "off" and "pack.off" or "pack.missing"
    return string.format(ns.T(key), Packs.Label(code))
end
function Packs.HasRooms(code)
    local rooms = ns.Replay and ns.Replay.ROOMS
    if not rooms then return false end
    for _, room in pairs(rooms) do
        if room.pack == code then return true end
    end
    return false
end
