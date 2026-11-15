local ADDON, root = ...
root = ManaCodeRaidHelper or root
root.Lead = root.Lead or {}
local ns = root.Lead
ns.Store = {}
local KEEP_NOTES = 300
local KEEP_ALL = 1000
local function charKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName() or "?"
    return name .. "-" .. realm
end
local function ensure()
    ManaCodeRaidLeadDB = ManaCodeRaidLeadDB or {}
    local db = ManaCodeRaidLeadDB
    db.version = db.version or 1
    db.tab = db.tab or 1
    db.players = db.players or {}
    db.chars = db.chars or {}
    local key = charKey()
    db.chars[key] = db.chars[key] or {}
    return db, db.chars[key]
end
function ns.Store.DB()
    local db = ensure()
    return db
end
function ns.Store.Char()
    local _, ch = ensure()
    return ch
end
local function newer(a, b)
    if a.seen ~= b.seen then return a.seen > b.seen end
    return a.name < b.name
end
function ns.Store.CleanPlayers(players, oldest)
    local notes, rest = {}, {}
    for name, p in pairs(players) do
        if type(p) ~= "table" then
            players[name] = nil
        else
            p.ilvl, p.inspectedAt = nil, nil
            if p.note then
                notes[#notes + 1] = { name = name, seen = p.seen or 0 }
            elseif not p.seen or (oldest and p.seen < oldest) then
                players[name] = nil
            else
                rest[#rest + 1] = { name = name, seen = p.seen }
            end
        end
    end
    table.sort(notes, newer)
    for i = #notes, KEEP_NOTES + 1, -1 do
        players[notes[i].name] = nil
        notes[i] = nil
    end
    for _, e in ipairs(notes) do rest[#rest + 1] = e end
    table.sort(rest, newer)
    for i = #rest, KEEP_ALL + 1, -1 do players[rest[i].name] = nil end
end
local function oldestRaid()
    local Rec = root.Store
    if not (Rec and Rec.Segments) or (root.RecLock and root.RecLock()) then return nil end
    local t
    for _, seg in Rec.Segments() do
        local t0 = tonumber(seg.t0)
        if t0 and (not t or t0 < t) then t = t0 end
    end
    return t
end
if root.OnReady then
    root.OnReady(function() ns.Store.CleanPlayers(ns.Store.DB().players, oldestRaid()) end)
end
