local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
ns.Store = {}
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
