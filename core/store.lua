local _, ns = ...
local floor = math.floor
local tremove = table.remove
local type = type
local tostring = tostring
local tonumber = tonumber
local abs = math.abs
local MB = 1048576
local WEEK = 7 * 86400
local MB_MIN, MB_MAX, MB_DEF = 50, 300, 250
local ROTATE_TICK = 2
local APPLY_DELAY = 5
local ASK_AGAIN = 30
local DAY_FMT = "%Y-%m-%d"
local Store = {}
ns.Store = Store
local rot = { want = false, acc = 0, entered = false, measured = false }
local rotFrame = CreateFrame("Frame")
rotFrame:Hide()
function Store.Open(ts)
    local db = ns.GetDB()
    db.live = ns.RecCodec.Open(ts, ns.Raid and ns.Raid.Bound() or nil)
    if ns.Encounters and ns.Encounters.Dummy() then db.live.dummy = true end
end
function Store.MarkBoss(name)
    local db = ns.GetDB()
    local seg = db and db.live
    if not seg then
        return
    end
    seg.bosses = seg.bosses or {}
    seg.bosses[name] = true
end
function Store.Live()
    local db = ns.GetDB()
    return db and db.live or nil
end
function Store.Append(ts, subtype, ...)
    local db = ns.GetDB()
    local seg = db.live
    if not seg then
        return false
    end
    ns.RecCodec.Append(seg, ts, subtype, ...)
    db.total = db.total + 1
    return true
end
function Store.Map(ts, area, level, mapName)
    local seg = ns.GetDB().live
    if not seg then return false end
    return ns.RecCodec.Map(seg, ts, area, level, mapName)
end
function Store.Close()
    local db = ns.GetDB()
    if not db then
        return nil
    end
    local seg = db.live
    if not seg then
        return nil
    end
    db.live = nil
    local folded = ns.Trash.Close(seg)
    if folded then db.segments[#db.segments + 1] = folded end
    if seg.pull then
        ns.RecCodec.Seal(seg)
        db.segments[#db.segments + 1] = seg
    else
        seg = folded
    end
    if ns.Encounters then ns.Encounters.Invalidate() end
    Store.Rotate()
    return seg
end
function Store.Clear()
    local db = ns.GetDB()
    db.segments = {}
    db.live = nil
    db.total = 0
    if ns.Encounters then ns.Encounters.Dropped(nil) end
end
function Store.Remove(i)
    local db = ns.GetDB()
    local seg = db.segments[i]
    if not seg or seg == db.live then return nil end
    tremove(db.segments, i)
    db.total = math.max(0, db.total - (seg.n or 0))
    if ns.Encounters then ns.Encounters.Dropped({ seg }, i) end
    return seg
end
function Store.Strip(seg)
    seg.chunks, seg.buf = {}, {}
    seg.actors, seg.spells, seg.strs = {}, {}, {}
    seg.hp, seg.pos, seg.mana, seg.maps = {}, {}, {}, {}
    seg.bytes = 0
    local db = ns.GetDB()
    db.total = math.max(0, (db.total or 0) - (seg.n or 0))
    seg.n = 0
    seg.bare, seg.lite = true, nil
    if ns.Decode and ns.Decode.Drop then ns.Decode.Drop(seg) end
    if ns.Index and ns.Index.Reset then ns.Index.Reset() end
end
local function TotalsBytes(seg)
    local n = 0
    for _, e in pairs(seg.totals or {}) do
        if type(e) == "table" and type(e.s) == "string" then n = n + #e.s end
    end
    return n
end
function Store.Stats()
    local db = ns.GetDB()
    local segs, events, bytes = #db.segments, 0, 0
    for i = 1, #db.segments do
        local s = db.segments[i]
        events = events + (s.n or 0)
        bytes = bytes + (s.bytes or 0) + TotalsBytes(s)
    end
    if db.live then
        segs = segs + 1
        events = events + db.live.n
        bytes = bytes + db.live.bytes
    end
    return segs, events, bytes
end
local function Clamp(v, lo, hi, def)
    v = tonumber(v)
    if not v then return def end
    v = floor(v)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
function Store.Limit()
    return Clamp(ns.GetDB().settings.limitMB, MB_MIN, MB_MAX, MB_DEF)
end
function Store.LimitRange()
    return MB_MIN, MB_MAX, MB_DEF
end
function Store.LimitBytes()
    return Store.Limit() * MB
end
local function SegTries(seg)
    local scan = seg.scan
    if scan and scan.fights then
        local n = 0
        for k = 1, #scan.fights do
            local f = scan.fights[k]
            if not (seg.cut and ns.Encounters and seg.cut[ns.Encounters.Key(f)]) then n = n + 1 end
        end
        return n
    end
    if seg.pull or (seg.bosses and next(seg.bosses)) then return 1 end
    return 0
end
function Store.OverLimit()
    local _, _, bytes = Store.Stats()
    return bytes > Store.LimitBytes()
end
local function FightSegs(fight)
    if fight.segs then return fight.segs end
    if fight.seg and fight.seg > 0 then return { fight.seg } end
    return {}
end
function Store.Bare(fight)
    if not fight then return false end
    local segs = ns.GetDB().segments
    local list = FightSegs(fight)
    for k = 1, #list do
        local s = segs[list[k]]
        if s and s.bare then return true end
    end
    return false
end
local function SameRaid(r, x, dt)
    if not r or not x then return false end
    if r.id and x.id then return r.id == x.id end
    return r.name == x.name and r.size == x.size and dt <= WEEK
end
local function SameGroup(a, b)
    local ra, rb = a.raid, b.raid
    if ra and rb and ra.id and rb.id then return ra.id == rb.id end
    if (ra == nil) ~= (rb == nil) then return false end
    if ra and (ra.name ~= rb.name or ra.size ~= rb.size) then return false end
    return date(DAY_FMT, floor(a.t0)) == date(DAY_FMT, floor(b.t0))
end
local function LiveLocks(now)
    local out = {}
    local locks = ns.Raid and ns.Raid.Locks and ns.Raid.Locks() or {}
    for i = 1, #locks do
        if locks[i].to > now then out[locks[i].id] = true end
    end
    return out
end
local function Guard()
    local db = ns.GetDB()
    local anchor = db.live or db.segments[#db.segments]
    local cur = ns.Raid and ns.Raid.Current() or nil
    local now = time()
    local locked = LiveLocks(now)
    return function(seg)
        if not anchor or seg == anchor or SameGroup(seg, anchor) then return true end
        if seg.raid and seg.raid.id and locked[seg.raid.id] then return true end
        return SameRaid(seg.raid, cur, abs(now - (seg.t1 or seg.t0)))
    end
end
local function GroupKey(seg)
    local r = seg.raid
    if r and r.id then return "#" .. r.id end
    local day = date(DAY_FMT, floor(seg.t0 or 0))
    if not r then return "|" .. day end
    return tostring(r.name) .. "|" .. tostring(r.size) .. "|" .. day
end
function Store.Count()
    local db = ns.GetDB()
    local seen, raids, tries = {}, 0, 0
    for i = 1, #db.segments + 1 do
        local s = db.segments[i] or (i > #db.segments and db.live)
        if s then
            tries = tries + SegTries(s)
            local key = GroupKey(s)
            if not seen[key] then
                seen[key] = true
                raids = raids + 1
            end
        end
    end
    return raids, tries
end
local function Plan(mb)
    local segs = ns.GetDB().segments
    local limit = mb * MB
    local guard = Guard()
    local _, _, bytes = Store.Stats()
    local drop, gone = {}, {}
    for i = 1, #segs do
        if bytes <= limit then break end
        local seg = segs[i]
        if not gone[i] and not guard(seg) then
            local group = {}
            for j = i, #segs do
                local s = segs[j]
                if not gone[j] and not guard(s) and SameGroup(seg, s) then
                    gone[j] = true
                    group[#group + 1] = s
                    bytes = bytes - (s.bytes or 0) - TotalsBytes(s)
                end
            end
            drop[#drop + 1] = group
        end
    end
    return drop
end
local function IndexOf(seg)
    local segs = ns.GetDB().segments
    for i = 1, #segs do
        if segs[i] == seg then return i end
    end
    return nil
end
local function DropGroup(group)
    local ids, set = {}, {}
    for n = 1, #group do
        local i = IndexOf(group[n])
        if i then
            ids[#ids + 1] = i
            set[i] = true
        end
    end
    if #ids == 0 then return false, 0 end
    local doomed = {}
    local list = ns.Encounters.Fights()
    for k = 1, #list do
        local fs = FightSegs(list[k])
        local mine = #fs > 0
        for j = 1, #fs do
            if not set[fs[j]] then mine = false end
        end
        if mine then doomed[#doomed + 1] = list[k] end
    end
    local plan = ns.FightTree.Plan(doomed, ids)
    if not plan then return false, 0 end
    ns.FightTree.Drop(plan)
    return true, #doomed
end
local function Apply(drop)
    local raids = 0
    for k = 1, #drop do
        if DropGroup(drop[k]) then raids = raids + 1 end
    end
    if raids == 0 then return end
    if ns.Settings and ns.Settings.RefreshRecord then ns.Settings.RefreshRecord() end
end
local function Noop() end
local function Idle()
    local _, _, _, queued = ns.Jobs.State()
    return queued == 0
end
local function LocksReady()
    if not ns.Raid or not ns.Raid.LocksKnown or ns.Raid.LocksKnown() then return true end
    local now = GetTime()
    if not rot.asked or now - rot.asked >= ASK_AGAIN then
        rot.asked = now
        if RequestRaidInfo then RequestRaidInfo() end
    end
    return false
end
local function Stop()
    rot.want = false
    rotFrame:Hide()
end
local function RotateStep()
    if rot.after and GetTime() < rot.after then return end
    if not LocksReady() or not Idle() then return end
    if not ns.Encounters.Ready() then
        ns.Encounters.Scan(Noop)
        return
    end
    local drop = Plan(Store.Limit())
    if #drop == 0 then return Stop() end
    if ns.Shell and ns.Shell.IsOpen and ns.Shell.IsOpen("log") then return end
    Stop()
    Apply(drop)
end
rotFrame:SetScript("OnUpdate", ns.Prof.Wrap("bg.store", function(self, elapsed)
    rot.acc = rot.acc + elapsed
    if rot.acc < ROTATE_TICK then return end
    rot.acc = 0
    RotateStep()
end))
function Store.Rotate()
    if (ns.RecLock and ns.RecLock()) or not Store.OverLimit() then return false end
    rot.want, rot.acc = true, ROTATE_TICK
    rotFrame:Show()
    return true
end
function Store.Rotating()
    return rot.want
end
function Store.SetLimit(mb)
    ns.GetDB().settings.limitMB = Clamp(mb, MB_MIN, MB_MAX, MB_DEF)
    rot.after = GetTime() + APPLY_DELAY
    return Store.Rotate()
end
function Store.Cuts(mb)
    if mb >= Store.Limit() then return false end
    local _, _, bytes = Store.Stats()
    return bytes > mb * MB
end
local function GroupLabel(group)
    local s = group[1]
    local label = s.raid and ns.Raid and ns.Raid.Label(s.raid) or ns.T("raid.none")
    return label .. " " .. ns.Date(s.t0)
end
function Store.Preview(mb)
    local drop = Plan(mb)
    local raids = {}
    for k = 1, #drop do raids[k] = GroupLabel(drop[k]) end
    return raids
end
local function Measured()
    rot.measured = true
    if rot.entered then Store.Rotate() end
end
function Store.Segments()
    local db = ns.GetDB()
    local i = 0
    return function()
        i = i + 1
        local seg = db.segments[i]
        if not seg then
            return nil
        end
        return i, seg
    end
end
function Store.Decode(seg, s, at, maxTail)
    return ns.Decode.Decode(seg, s, at, maxTail)
end
function Store.Events(seg, from, to, maxTail)
    return ns.Decode.Events(seg, from, to, maxTail)
end
function Store.Heads(seg, from, to)
    return ns.Decode.Heads(seg, from, to)
end
ns.OnReady(function()
    if ns.GetDB().live then
        Store.Close()
    end
    Measured()
end)
local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logoutFrame:SetScript("OnEvent", ns.Prof.Wrap("bg.store", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        rot.entered = true
        if rot.measured then Store.Rotate() end
        return
    end
    Store.Close()
end))
