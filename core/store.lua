local _, ns = ...
local floor = math.floor
local concat = table.concat
local tremove = table.remove
local type = type
local tostring = tostring
local tonumber = tonumber
local unpack = unpack
local find = string.find
local match = string.match
local sub = string.sub
local byte = string.byte
local format = string.format
local abs = math.abs
local SEEK_SLACK = 5000
local MB = 1048576
local WEEK = 7 * 86400
local TRIES_MIN, TRIES_MAX, TRIES_DEF = 10, 100, 50
local MB_MIN, MB_MAX, MB_DEF = 50, 300, 150
local ROTATE_KEY = "store.rotate"
local ROTATE_TICK = 2
local APPLY_DELAY = 5
local ASK_AGAIN = 30
local DAY_FMT = "%Y-%m-%d"
local B_COMMA = 44
local B_S = 115
local B_B = 98
local B_R = 114
local HEAD8 = "^(%d+),(%d+),([^,\n]*),([^,\n]*),([^,\n]*),([^,\n]*),([^,\n]*),([^,\n]*)()"
local HEADQ = "^(%d+),(%d+),[^,\n]*,([^,\n]*),[^,\n]*,[^,\n]*,([^,\n]*)"
local FIELD_END = "[,\n]"
local Store = {}
ns.Store = Store
local indexBySeg = setmetatable({}, { __mode = "k" })
local tagBySeg = setmetatable({}, { __mode = "k" })
local lookBySeg = setmetatable({}, { __mode = "k" })
local tailBySeg = setmetatable({}, { __mode = "k" })
local rot = { want = false, prepped = false, acc = 0, entered = false, measured = false }
local rotFrame = CreateFrame("Frame")
rotFrame:Hide()
local function GetIndex(seg)
    local index = indexBySeg[seg]
    if not index then
        index = {}
        local dict = seg.dict
        for i = 1, #dict do
            index[dict[i]] = i
        end
        indexBySeg[seg] = index
    end
    return index
end
local function Lookup(seg)
    local look = lookBySeg[seg]
    if not look then
        local dict = seg.dict
        look = setmetatable({}, { __index = function(t, k)
            local v = dict[tonumber(k)] or false
            t[k] = v
            return v
        end })
        lookBySeg[seg] = look
    end
    return look
end
local function TailLookup(seg)
    local look = tailBySeg[seg]
    if not look then
        local dict = seg.dict
        look = setmetatable({}, { __index = function(t, k)
            local v = dict[tonumber(sub(k, 2))] or false
            t[k] = v
            return v
        end })
        tailBySeg[seg] = look
    end
    return look
end
local function DecodeTail(tlook, s)
    local n = tonumber(s)
    if n then
        return n
    end
    local head = byte(s, 1)
    if head == B_S then
        return tlook[s] or nil
    elseif head == B_B then
        return s == "b1"
    elseif head == B_R then
        return sub(s, 2)
    end
    return nil
end
function Store.Open(ts)
    local db = ns.GetDB()
    db.live = ns.RecCodec.Open(ts, ns.Raid and ns.Raid.Current() or nil)
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
local function IsNew(seg)
    return seg ~= nil and seg.v == ns.RecCodec.VERSION
end
Store.IsNew = IsNew
function Store.Append(ts, subtype, ...)
    local db = ns.GetDB()
    local seg = db.live
    if not IsNew(seg) then
        return false
    end
    ns.RecCodec.Append(seg, ts, subtype, ...)
    db.total = db.total + 1
    return true
end
function Store.Hp(ts, name, hp, hpMax, force)
    local seg = ns.GetDB().live
    if not IsNew(seg) then return false end
    return ns.RecCodec.Hp(seg, ts, name, hp, hpMax, force)
end
function Store.Pos(ts, name, x, y, force)
    local seg = ns.GetDB().live
    if not IsNew(seg) then return false end
    return ns.RecCodec.Pos(seg, ts, name, x, y, force)
end
function Store.Map(ts, area, level, mapName)
    local seg = ns.GetDB().live
    if not IsNew(seg) then return false end
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
    if IsNew(seg) then
        local folded = ns.Trash.Close(seg)
        if folded then db.segments[#db.segments + 1] = folded end
        if seg.pull then
            ns.RecCodec.Seal(seg)
            db.segments[#db.segments + 1] = seg
        else
            seg = folded
        end
    else
        if seg.buf and #seg.buf > 0 then
            seg.chunks[#seg.chunks + 1] = concat(seg.buf, "\n")
            wipe(seg.buf)
        end
        db.segments[#db.segments + 1] = seg
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
function Store.Limits()
    local s = ns.GetDB().settings
    return Clamp(s.limitTries, TRIES_MIN, TRIES_MAX, TRIES_DEF), Clamp(s.limitMB, MB_MIN, MB_MAX, MB_DEF)
end
function Store.LimitRange()
    return TRIES_MIN, TRIES_MAX, TRIES_DEF, MB_MIN, MB_MAX, MB_DEF
end
function Store.LimitBytes()
    local _, mb = Store.Limits()
    return mb * MB
end
local function SegTries(seg)
    if seg.bare then return 0 end
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
function Store.Tries()
    local db = ns.GetDB()
    local n = 0
    for i = 1, #db.segments do n = n + SegTries(db.segments[i]) end
    return n
end
function Store.OverLimit()
    local tries, mb = Store.Limits()
    local _, _, bytes = Store.Stats()
    return bytes > mb * MB or Store.Tries() > tries
end
local function FightSegs(fight)
    if fight.segs then return fight.segs end
    if fight.seg and fight.seg > 0 then return { fight.seg } end
    return {}
end
function Store.Bare(fight)
    if not fight or fight.foreign then return false end
    local segs = ns.GetDB().segments
    local list = FightSegs(fight)
    for k = 1, #list do
        local s = segs[list[k]]
        if s and s.bare then return true end
    end
    return false
end
function Store.Strip(i)
    local db = ns.GetDB()
    local seg = db.segments[i]
    if not seg or seg.bare or seg == db.live then return 0 end
    local freed = seg.bytes or 0
    db.total = math.max(0, db.total - (seg.n or 0))
    seg.chunks = {}
    seg.buf, seg.hp, seg.pos, seg.maps = nil, nil, nil, nil
    seg.actors, seg.spells, seg.strs = nil, nil, nil
    if seg.dict then seg.dict = {} end
    seg.n, seg.bytes, seg.bare = 0, 0, true
    indexBySeg[seg], tagBySeg[seg], lookBySeg[seg], tailBySeg[seg] = nil, nil, nil, nil
    if ns.Decode then ns.Decode.Drop(seg) end
    return freed
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
local function Closure(i, bySeg, taken, guard)
    local segs = ns.GetDB().segments
    local ids, seen, fights, have = { i }, { [i] = true }, {}, {}
    local k, blocked = 1, false
    while ids[k] do
        local at = ids[k]
        taken[at] = true
        if not segs[at] or guard(segs[at]) then blocked = true end
        local list = bySeg[at] or {}
        for n = 1, #list do
            local f = list[n]
            if not have[f] then
                have[f] = true
                fights[#fights + 1] = f
                local fs = FightSegs(f)
                for j = 1, #fs do
                    if not seen[fs[j]] then
                        seen[fs[j]] = true
                        ids[#ids + 1] = fs[j]
                    end
                end
            end
        end
        k = k + 1
    end
    if blocked then return nil, ids end
    local g = { segs = {}, fights = fights, tries = 0 }
    for n = 1, #ids do g.segs[n] = segs[ids[n]] end
    for n = 1, #fights do
        if not Store.Bare(fights[n]) then g.tries = g.tries + 1 end
    end
    return g, ids
end
local function Plan(maxTries, mb)
    local segs = ns.GetDB().segments
    local limit = mb * MB
    local guard = Guard()
    local list = ns.Encounters.Fights()
    local bySeg, tries = {}, 0
    for k = 1, #list do
        local f = list[k]
        local fs = FightSegs(f)
        if not Store.Bare(f) then tries = tries + 1 end
        for j = 1, #fs do
            local at = bySeg[fs[j]]
            if not at then
                at = {}
                bySeg[fs[j]] = at
            end
            at[#at + 1] = f
        end
    end
    local _, _, bytes = Store.Stats()
    local plan = { strip = {}, drop = {} }
    local taken, stripped = {}, {}
    for i = 1, #segs do
        if tries <= maxTries and bytes <= limit then break end
        if not taken[i] and not segs[i].bare and not guard(segs[i]) then
            local g, ids = Closure(i, bySeg, taken, guard)
            if g then
                plan.strip[#plan.strip + 1] = g
                tries = tries - g.tries
                for n = 1, #ids do
                    stripped[ids[n]] = true
                    bytes = bytes - (segs[ids[n]].bytes or 0)
                end
            end
        end
    end
    local gone = {}
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
                    bytes = bytes - (stripped[j] and 0 or (s.bytes or 0)) - TotalsBytes(s)
                end
            end
            plan.drop[#plan.drop + 1] = group
        end
    end
    return plan
end
local function Needs(plan)
    local doomed = {}
    for k = 1, #plan.drop do
        for n = 1, #plan.drop[k] do doomed[plan.drop[k][n]] = true end
    end
    local need, freeze = {}, {}
    for k = 1, #plan.strip do
        local g = plan.strip[k]
        local keep = false
        for n = 1, #g.segs do
            local s = g.segs[n]
            if not doomed[s] then
                keep = true
                if not s.bare and not ns.Digest.Frozen(s) then freeze[#freeze + 1] = s end
            end
        end
        for n = 1, keep and #g.fights or 0 do
            local f = g.fights[n]
            if not Store.Bare(f) and not ns.Digest.Has(f) then need[#need + 1] = f end
        end
    end
    return need, freeze
end
local function IndexOf(seg)
    local segs = ns.GetDB().segments
    for i = 1, #segs do
        if segs[i] == seg then return i end
    end
    return nil
end
local function Prep(need, freeze)
    ns.Jobs.Run(ROTATE_KEY, function()
        ns.Jobs.Label("job.rotate")
        for k = 1, #need do
            if not ns.Digest.Has(need[k]) then ns.Summary.Full(need[k]) end
            ns.Jobs.Yield()
        end
        for k = 1, #freeze do
            local s = freeze[k]
            local i = IndexOf(s)
            if i and not s.bare and not ns.Digest.Frozen(s) then ns.Digest.Freeze(s, ns.Digest.Trash(i, s)) end
            ns.Jobs.Yield()
        end
        return true
    end, function() rot.prepped = true end, "store.rotate")
end
local function Kept(g)
    for n = 1, #g.fights do
        local f = g.fights[n]
        if not Store.Bare(f) and not ns.Digest.Has(f) then return false end
    end
    for n = 1, #g.segs do
        local s = g.segs[n]
        if not s.bare and not ns.Digest.Frozen(s) then return false end
    end
    return true
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
    if #ids == 0 then return 0 end
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
    if not plan then return 0 end
    ns.FightTree.Drop(plan)
    return #doomed
end
local function Forms(n, key)
    local forms = ns.T(key)
    return ns.Plural and ns.Plural(n, forms) or match(forms, "^[^|]*")
end
local function Apply(plan)
    local doomed = {}
    for k = 1, #plan.drop do
        for n = 1, #plan.drop[k] do doomed[plan.drop[k][n]] = true end
    end
    local tries, segsDone = 0, 0
    for k = 1, #plan.strip do
        local g = plan.strip[k]
        if Kept(g) then
            local n = g.tries
            for j = 1, #g.segs do
                local s = g.segs[j]
                local i = not doomed[s] and not s.bare and IndexOf(s)
                if i then
                    Store.Strip(i)
                    segsDone = segsDone + 1
                end
            end
            tries = tries + n
        end
    end
    if segsDone > 0 and ns.Index then ns.Index.Reset() end
    local raids, gone = 0, 0
    for k = 1, #plan.drop do
        gone = gone + DropGroup(plan.drop[k])
        raids = raids + 1
    end
    local _, _, bytes = Store.Stats()
    if tries > 0 then
        ns.Print(format(Forms(tries, "store.stripped"), tries, bytes / MB))
    elseif segsDone > 0 then
        ns.Print(format(ns.T("store.stripped.trash"), segsDone, bytes / MB))
    end
    if raids > 0 then
        ns.Print(format(Forms(raids, "store.dropped"), raids, gone, bytes / MB))
    end
    if (tries > 0 or raids > 0) and ns.Settings and ns.Settings.RefreshRecord then ns.Settings.RefreshRecord() end
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
local function RotateStep()
    if rot.after and GetTime() < rot.after then return end
    if not LocksReady() or not Idle() then return end
    if not ns.Encounters.Ready() then
        ns.Encounters.Scan(Noop)
        return
    end
    local plan = Plan(Store.Limits())
    if #plan.strip == 0 and #plan.drop == 0 then
        rot.want, rot.prepped = false, false
        rotFrame:Hide()
        return
    end
    if not rot.prepped then
        local need, freeze = Needs(plan)
        if #need > 0 or #freeze > 0 then
            Prep(need, freeze)
            return
        end
        rot.prepped = true
    end
    if #plan.drop > 0 and ns.Shell and ns.Shell.IsOpen and ns.Shell.IsOpen("log") then return end
    rot.want, rot.prepped = false, false
    rotFrame:Hide()
    Apply(plan)
end
rotFrame:SetScript("OnUpdate", function(self, elapsed)
    rot.acc = rot.acc + elapsed
    if rot.acc < ROTATE_TICK then return end
    rot.acc = 0
    RotateStep()
end)
function Store.Rotate()
    if rot.skip or (ns.RecLock and ns.RecLock()) or not Store.OverLimit() then return false end
    rot.want, rot.prepped, rot.acc = true, false, ROTATE_TICK
    rotFrame:Show()
    return true
end
function Store.Rotating()
    return rot.want
end
function Store.Skipped()
    return rot.skip == true
end
function Store.SetLimits(tries, mb)
    local s = ns.GetDB().settings
    if tries then s.limitTries = Clamp(tries, TRIES_MIN, TRIES_MAX, TRIES_DEF) end
    if mb then s.limitMB = Clamp(mb, MB_MIN, MB_MAX, MB_DEF) end
    rot.skip = nil
    rot.after = GetTime() + APPLY_DELAY
    return Store.Rotate()
end
function Store.Cuts(tries, mb)
    local curTries, curMB = Store.Limits()
    tries = tries and Clamp(tries, TRIES_MIN, TRIES_MAX, TRIES_DEF) or curTries
    mb = mb and Clamp(mb, MB_MIN, MB_MAX, MB_DEF) or curMB
    if tries >= curTries and mb >= curMB then return false end
    local _, _, bytes = Store.Stats()
    return Store.Tries() > tries or bytes > mb * MB
end
local function GroupLabel(group)
    local s = group[1]
    local label = s.raid and ns.Raid and ns.Raid.Label(s.raid) or ns.T("raid.none")
    return label .. " " .. date("%d.%m", floor(s.t0))
end
function Store.Preview(tries, mb)
    local curTries, curMB = Store.Limits()
    tries = tries and Clamp(tries, TRIES_MIN, TRIES_MAX, TRIES_DEF) or curTries
    mb = mb and Clamp(mb, MB_MIN, MB_MAX, MB_DEF) or curMB
    if not (ns.Encounters and ns.Encounters.Ready()) then
        return math.max(0, Store.Tries() - tries), nil
    end
    local plan = Plan(tries, mb)
    local n, raids = 0, {}
    for k = 1, #plan.strip do n = n + plan.strip[k].tries end
    for k = 1, #plan.drop do raids[#raids + 1] = GroupLabel(plan.drop[k]) end
    return n, raids
end
local function Measured()
    rot.measured = true
    if rot.note then
        rot.note = nil
        if Store.OverLimit() then
            local _, _, bytes = Store.Stats()
            ns.Print(format(ns.T("store.kept.over"), bytes / MB, Store.Tries()))
        end
    end
    if rot.entered then Store.Rotate() end
end
function Store.Measure()
    local db = ns.GetDB()
    local need = false
    for i = 1, #db.segments do
        if type(db.segments[i].bytes) ~= "number" then need = true end
    end
    if not need then
        Measured()
        return
    end
    ns.Jobs.Run("store.measure", function()
        for i = 1, #db.segments do
            local seg = db.segments[i]
            if type(seg.bytes) ~= "number" then
                local bytes = 0
                for c = 1, #(seg.chunks or {}) do
                    bytes = bytes + #seg.chunks[c] + 1
                    ns.Jobs.Step()
                end
                seg.bytes = bytes
            end
        end
    end, Measured)
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
function Store.IdOf(seg, s)
    if IsNew(seg) then return ns.Decode.IdOf(seg, s) end
    return GetIndex(seg)[s]
end
function Store.TimeAt(seg, s, at)
    if IsNew(seg) then return (ns.Decode.TimeAt(seg, s, at)) end
    return seg.t0 + tonumber(match(s, "^(%d+)", at)) / 1000
end
local function IdSet(seg, values)
    if not values then return nil end
    local index = GetIndex(seg)
    local set = {}
    for k, v in pairs(values) do
        local name = type(k) == "string" and k or v
        local id = index[name]
        if id then set[tostring(id)] = true end
    end
    return set
end
local function ChunkStart(seg, k)
    local chunk = seg.chunks[k]
    return chunk and tonumber(match(chunk, "^(%d+)")) or nil
end
local function Walker(seg, from, to)
    local chunks = seg.chunks
    local ci = 1
    if from then
        local startMs = (from - seg.t0) * 1000 - SEEK_SLACK
        while ci < #chunks do
            local nextStart = ChunkStart(seg, ci + 1)
            if nextStart and nextStart < startMs then ci = ci + 1 else break end
        end
    end
    ci = ci - 1
    local stopMs = to and (to - seg.t0) * 1000 + SEEK_SLACK or nil
    local cur, pos = nil, 1
    local bi = 0
    local buf = seg.buf
    local done = false
    return function()
        if done then return nil end
        while true do
            if cur then
                local s, at = cur, pos
                local nl = find(s, "\n", at, true)
                if nl then pos = nl + 1 else cur = nil end
                return s, at, ci
            end
            ci = ci + 1
            local chunk = chunks[ci]
            if chunk then
                if stopMs then
                    local first = tonumber(match(chunk, "^(%d+)"))
                    if first and first > stopMs then
                        done = true
                        return nil
                    end
                end
                cur, pos = chunk, 1
            else
                bi = bi + 1
                local line = buf and buf[bi]
                if not line then
                    done = true
                    return nil
                end
                return line, 1, 0
            end
        end
    end
end
local ret = {}
local function DecodeAt(seg, look, tlook, s, at, maxTail)
    local ms, subId, a, b, c, d, e, f, pos = match(s, HEAD8, at)
    if not ms then return 0 end
    ret[1] = seg.t0 + tonumber(ms) / 1000
    ret[2] = look[subId] or nil
    ret[3] = look[a] or nil
    ret[4] = look[b] or nil
    ret[5] = tonumber(c)
    ret[6] = look[d] or nil
    ret[7] = look[e] or nil
    ret[8] = tonumber(f)
    local n = 8
    local limit = maxTail and (8 + maxTail) or 64
    local ch = byte(s, pos)
    while ch == B_COMMA and n < limit do
        local start = pos + 1
        local stop = find(s, FIELD_END, start)
        local field
        if stop then
            field = sub(s, start, stop - 1)
            ch = byte(s, stop)
            pos = stop
        else
            field = sub(s, start)
            ch = nil
        end
        n = n + 1
        if field == "" then
            ret[n] = nil
        else
            ret[n] = DecodeTail(tlook, field)
        end
    end
    return n
end
function Store.Decode(seg, s, at, maxTail)
    if IsNew(seg) then return ns.Decode.Decode(seg, s, at, maxTail) end
    local n = DecodeAt(seg, Lookup(seg), TailLookup(seg), s, at, maxTail)
    if n == 0 then return nil end
    return unpack(ret, 1, n)
end
function Store.Events(seg, from, to, skip, maxTail, onSkip, ctx)
    if IsNew(seg) then return ns.Decode.Events(seg, from, to, skip, maxTail) end
    local look, tlook = Lookup(seg), TailLookup(seg)
    local walk = Walker(seg, from, to)
    local fromMs = from and (from - seg.t0) * 1000 - 1 or nil
    local toMs = to and (to - seg.t0) * 1000 + 1 or nil
    local skipIds = IdSet(seg, skip)
    return function()
        while true do
            local s, at = walk()
            if not s then return nil end
            local ms, subId = match(s, "^(%d+),(%d+)", at)
            if ms and skipIds and skipIds[subId] then
                if onSkip then onSkip(ctx, seg, s, at, ms) end
            elseif ms then
                ms = tonumber(ms)
                if (not fromMs or ms >= fromMs) and (not toMs or ms <= toMs) then
                    local n = DecodeAt(seg, look, tlook, s, at, maxTail)
                    if n > 0 then return unpack(ret, 1, n) end
                end
            end
        end
    end
end
function Store.Heads(seg, from, to)
    if IsNew(seg) then return ns.Decode.Heads(seg, from, to) end
    local look = Lookup(seg)
    local walk = Walker(seg, from, to)
    local t0 = seg.t0
    local fromMs = from and (from - t0) * 1000 - 1 or nil
    local toMs = to and (to - t0) * 1000 + 1 or nil
    return function()
        while true do
            local s, at, ci = walk()
            if not s then return nil end
            local ms, subId, src, dst = match(s, HEADQ, at)
            if ms then
                ms = tonumber(ms)
                if (not fromMs or ms >= fromMs) and (not toMs or ms <= toMs) then
                    return s, at, ci, t0 + ms / 1000, look[subId] or nil, look[src] or nil, look[dst] or nil
                end
            end
        end
    end
end
ns.OnReady(function()
    local st = ns.GetDB().settings
    if st.limitNote then
        st.limitNote = nil
        rot.skip, rot.note = true, true
        local tries, mb = Store.Limits()
        ns.Print(format(ns.T("store.kept"), tries, mb))
    end
    if ns.GetDB().live then
        Store.Close()
    end
    Store.Measure()
end)
local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logoutFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        rot.entered = true
        if rot.measured then Store.Rotate() end
        return
    end
    Store.Close()
end)
