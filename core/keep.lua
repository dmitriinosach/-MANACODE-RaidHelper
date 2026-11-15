local _, ns = ...
local format = string.format
local sort = table.sort
local Keep = {}
ns.Keep = Keep
local CFG = { "settings", "prices", "recording", "fxUser", "mapPoint", "mapX", "mapY" }
local note = nil
local noteN = 0
local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
local function Char()
    if type(ManaCodeRaidHelperChar) ~= "table" then ManaCodeRaidHelperChar = {} end
    return ManaCodeRaidHelperChar
end
local function Restore(db, cfg)
    for i = 1, #CFG do
        local k = CFG[i]
        if cfg[k] ~= nil then db[k] = cfg[k] end
    end
    if type(db.faults) ~= "table" then db.faults = {} end
    if type(cfg.rules) == "table" then db.faults.rules = cfg.rules end
    if cfg.system ~= nil then db.faults.system = cfg.system end
    if cfg.proof ~= nil then
        if type(db.gp) ~= "table" then db.gp = {} end
        db.gp.proof = cfg.proof
    end
end
local function Merge(db, rec)
    local mine = type(rec.segments) == "table" and rec.segments or {}
    if type(db.segments) ~= "table" or #db.segments == 0 then
        db.segments = mine
    else
        local list = db.segments
        for i = 1, #mine do list[#list + 1] = mine[i] end
        sort(list, function(a, b)
            local x, y = tonumber(a.t0) or 0, tonumber(b.t0) or 0
            if x ~= y then return x < y end
            return (tonumber(a.t1) or 0) < (tonumber(b.t1) or 0)
        end)
    end
    if type(rec.live) == "table" and not db.live then db.live = rec.live end
    db.total = (tonumber(db.total) or 0) + (tonumber(rec.total) or 0)
end
function Keep.Load(db, lost)
    local ch = Char()
    ch.lead = nil
    local cfg = type(ch.cfg) == "table" and ch.cfg or nil
    if cfg and (tonumber(cfg.at) or 0) > (tonumber(db.cfgAt) or 0) then
        Restore(db, cfg)
        if lost then note = "keep.cfg" end
    end
    if lost then
        local n = type(ch.acct) == "table" and tonumber(ch.acct.segs) or 0
        if n > 0 then note, noteN = "keep.lost", n end
    end
    if db.testSet then return end
    local s = db.settings
    if type(ch.rec) == "table" then
        Merge(db, ch.rec)
    elseif type(s) == "table" and s.recChar then
        local was = type(db.recChars) == "table" and tonumber(db.recChars[CharKey()]) or 0
        if was > 0 then note, noteN = "keep.lostchar", was end
    end
    ch.rec = nil
    if type(db.recChars) == "table" then db.recChars[CharKey()] = nil end
end
function Keep.Logout()
    local db = ManaCodeRaidHelperDB
    if type(db) ~= "table" then return end
    local ch = Char()
    local now = time()
    local s = type(db.settings) == "table" and db.settings or {}
    if s.recChar and not db.testSet and not (ns.RecLock and ns.RecLock()) then
        local segs = type(db.segments) == "table" and db.segments or {}
        ch.rec = { segments = segs, live = db.live, total = db.total }
        db.segments, db.live, db.total = {}, nil, 0
        if type(db.recChars) ~= "table" then db.recChars = {} end
        db.recChars[CharKey()] = #segs
    end
    local fl = type(db.faults) == "table" and db.faults or {}
    local gp = type(db.gp) == "table" and db.gp or {}
    db.cfgAt = now
    ch.cfg = {
        at = now, settings = db.settings, prices = db.prices, recording = db.recording, fxUser = db.fxUser,
        mapPoint = db.mapPoint, mapX = db.mapX, mapY = db.mapY, rules = fl.rules, system = fl.system, proof = gp.proof,
    }
    ch.acct = { segs = type(db.segments) == "table" and #db.segments or 0, at = now }
    ch.lead = nil
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if note then ns.Print(format(ns.T(note), noteN)) end
    note = nil
end)
