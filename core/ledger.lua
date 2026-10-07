local _, ns = ...
local format = string.format
local concat = table.concat
local floor = math.floor
local max = math.max
local min = math.min
local tremove = table.remove
local MAX_REASON = 200
local MAX_LOG = 2000
local EP_MEMO = 30
local HOT = { "slack", "death", "wipe" }
local HOT_SUM = { slack = 200, death = 400, wipe = 800 }
local LEGACY = { s = "gp", old = true }
local Ledger = {}
ns.Ledger = Ledger
Ledger.HOT = HOT
Ledger.ORDER = { "gp", "ep", "dkp" }
local epMemo = {}
local function Store()
    return ns.GetDB().faults
end
local function Epgp()
    local e = _G.EPGP
    if type(e) ~= "table" then return nil end
    return e
end
local function EpOf(e, name)
    if type(e.GetEPGP) ~= "function" then return nil end
    local ok, ep = pcall(e.GetEPGP, e, name)
    if not ok or type(ep) ~= "number" then return nil end
    local m = epMemo[name]
    if m and ep == m.was and GetTime() - m.at < EP_MEMO then return m.now, ep end
    return ep, ep
end
local function Member(e, name)
    if type(e.GetEPGP) ~= "function" then return true end
    local ok, ep = pcall(e.GetEPGP, e, name)
    return ok and ep ~= nil
end
local function Cut(s, n)
    if #s <= n then return s end
    local i = n
    while i > 0 do
        local c = s:byte(i + 1)
        if not c or c < 128 or c >= 192 then break end
        i = i - 1
    end
    return s:sub(1, i)
end
local function ReadyBy(fn)
    return function()
        local e = Epgp()
        if not e or type(e[fn]) ~= "function" then return false, "led.err.noepgp" end
        return true
    end
end
local function CanBy(ready, fn)
    return function(n)
        local ok, why = ready()
        if not ok then return false, why end
        local e = Epgp()
        if type(e[fn]) == "function" and not e[fn](e, "FailWatch", (n and n ~= 0) and n or 1) then
            return false, "led.err.rights"
        end
        return true
    end
end
local GP = { key = "gp", label = "led.sys.gp", unit = "led.unit.gp", ask = "led.ask.gp" }
GP.Ready = ReadyBy("IncGPBy")
GP.Can = CanBy(GP.Ready, "CanIncGPBy")
GP.Give = function(name, reason, n)
    local e = Epgp()
    if not e or not Member(e, name) then return nil end
    local ok = pcall(e.IncGPBy, e, name, reason, n)
    if not ok then return nil end
    return n
end
local EP = { key = "ep", label = "led.sys.ep", unit = "led.unit.ep", ask = "led.ask.ep" }
EP.Ready = ReadyBy("IncEPBy")
EP.Can = CanBy(EP.Ready, "CanIncEPBy")
EP.Give = function(name, reason, n)
    local e = Epgp()
    local ep, raw = nil, nil
    if e then ep, raw = EpOf(e, name) end
    if not ep then return nil end
    local fact = n
    if n > 0 then fact = min(n, max(0, ep)) end
    if fact == 0 then return 0 end
    local ok = pcall(e.IncEPBy, e, name, reason, -fact)
    if not ok then return nil end
    epMemo[name] = { was = raw, now = ep - fact, at = GetTime() }
    return fact
end
local qdkpDirty = false
local function QdkpLoaded()
    return type(_G.QDKP2_AddTotals) == "function" and type(_G.QDKP2_GetNet) == "function"
        and type(_G.QDKP2_OfficerMode) == "function" and type(_G.QDKP2_IsInGuild) == "function"
        and type(_G.QDKP2_GetMain) == "function" and type(_G.QDKP2GUI_Main) == "table"
end
local function NetOf(name)
    local ok, net = pcall(_G.QDKP2_GetNet, name)
    if ok and type(net) == "number" then return net end
    return nil
end
local function QdkpMember(name)
    if not _G.QDKP2_IsInGuild(name) then return false end
    local note = _G.QDKP2note
    local ok, main = pcall(_G.QDKP2_GetMain, name)
    return ok and type(note) == "table" and note[main] ~= nil
end
local DKP = { key = "dkp", label = "led.sys.dkp", unit = "led.unit.dkp", ask = "led.ask.dkp" }
DKP.Ready = function()
    if not QdkpLoaded() then return false, "led.err.noqdkp" end
    if not _G.QDKP2_ACTIVE then return false, "led.err.qdkpoff" end
    return true
end
DKP.Can = function()
    local ok, why = DKP.Ready()
    if not ok then return false, why end
    if not _G.QDKP2_OfficerMode() then return false, "led.err.qdkprights" end
    return true
end
DKP.Give = function(name, reason, n)
    local ok, why = DKP.Can()
    if not ok then return nil, why end
    if not QdkpMember(name) then return nil, "led.err.qdkpmember" end
    local before = NetOf(name)
    if not before then return nil, "led.err.qdkpmember" end
    local done = pcall(_G.QDKP2_AddTotals, name, nil, n, nil, reason, true)
    local after = NetOf(name)
    local fact = after and before - after or 0
    if fact ~= 0 then qdkpDirty = true end
    if not done and fact == 0 then return nil, "led.err.qdkp" end
    if fact ~= n then return fact, "led.err.qdkpcut" end
    return fact
end
DKP.Flush = function()
    if not qdkpDirty then return end
    qdkpDirty = false
    if _G.QDKP2_SENDTRIG_MODIFY and type(_G.QDKP2_UploadAll) == "function" then pcall(_G.QDKP2_UploadAll) end
end
local SYSTEMS = { gp = GP, ep = EP, dkp = DKP }
function Ledger.Get(key)
    return SYSTEMS[key]
end
function Ledger.Key()
    local db = ns.GetDB and ns.GetDB()
    local k = db and db.faults and db.faults.system
    if SYSTEMS[k] then return k end
    return "gp"
end
function Ledger.Active()
    return SYSTEMS[Ledger.Key()]
end
function Ledger.Label(key)
    return ns.T(SYSTEMS[key or Ledger.Key()].label)
end
function Ledger.Unit(key)
    return ns.T(SYSTEMS[key or Ledger.Key()].unit)
end
local function Changed()
    if ns.RaidSummary and ns.RaidSummary.GPDirty then ns.RaidSummary.GPDirty() end
    if ns.GPList then ns.GPList.Changed() end
end
function Ledger.Select(key)
    if not SYSTEMS[key] then return false end
    Store().system = key
    Changed()
    return true
end
function Ledger.Done(key)
    local db = ns.GetDB()
    local rec = db.faults and db.faults.done[key]
    if rec then return rec end
    local old = db.gpIssued
    if old and old[key] then return LEGACY end
    return nil
end
function Ledger.Pending(events)
    local n = 0
    for k = 1, #events do
        local ev = events[k]
        if ev.n > 0 and not Ledger.Done(ev.key) then n = n + ev.n end
    end
    return n
end
function Ledger.HotSum(kind, sys)
    local by = Store().hot[sys or Ledger.Key()]
    local v = by and by[kind]
    if type(v) == "number" then return v end
    return HOT_SUM[kind] or 0
end
function Ledger.SetHot(kind, sys, n)
    if not HOT_SUM[kind] or not SYSTEMS[sys] then return end
    local hot = Store().hot
    if type(n) == "number" then n = max(0, floor(n + 0.5)) end
    if n == HOT_SUM[kind] then n = nil end
    local by = hot[sys] or {}
    by[kind] = n
    hot[sys] = next(by) and by or nil
end
function Ledger.HotLabel(kind)
    return ns.T("led.hot." .. kind)
end
local function Compose(boss, parts)
    local name = boss and ns.EncName and ns.EncName(boss) or tostring(boss or "")
    return Cut(format(ns.T("led.reason"), name, concat(parts, ", ")), MAX_REASON)
end
function Ledger.ReasonOf(boss, events)
    local parts, at = {}, {}
    for i = 1, #events do
        local ev = events[i]
        local short = ev.short or "?"
        local id = (ev.wipe and "w:" or "r:") .. short
        local p = at[id]
        if not p then
            p = { short = short, wipe = ev.wipe, n = 0 }
            at[id] = p
            parts[#parts + 1] = p
        end
        p.n = p.n + 1
    end
    local texts = {}
    for i = 1, #parts do
        local p = parts[i]
        texts[i] = p.short .. (p.n > 1 and format(ns.T("led.times"), p.n) or "") .. (p.wipe and ns.T("led.wipe") or "")
    end
    return Compose(boss, texts)
end
local function Me()
    return UnitName("player") or "?"
end
local function RaidOf(fight)
    if fight and ns.Raid and ns.Raid.Key then return ns.Raid.Key(fight.raid) end
    return nil
end
local function Append(row)
    local log = Store().log
    log[#log + 1] = row
    while #log > MAX_LOG do tremove(log, 1) end
end
local function Write(fight, name, sys, fact, want, reason, kind, keys, hot)
    Append({ t = time(), by = Me(), raid = RaidOf(fight), fk = fight and ns.Penalties.FightKey(fight) or nil,
        rl = fight and fight.raid and ns.Raid and ns.Raid.Label and ns.Raid.Label(fight.raid) or nil,
        boss = fight and fight.boss or nil, who = name, s = sys.key, n = fact, want = want, r = reason, kind = kind,
        hot = hot, keys = keys })
end
function Ledger.Issue(fight, batch)
    local res = { given = {}, failed = {} }
    local sys = Ledger.Active()
    local ok, why = sys.Can(1)
    if not ok then
        res.why = why
        return res
    end
    local done = Store().done
    for b = 1, #batch do
        local item = batch[b]
        local open, want = {}, 0
        for e = 1, #item.events do
            local ev = item.events[e]
            if ev.n > 0 and not Ledger.Done(ev.key) then
                open[#open + 1] = ev
                want = want + ev.n
            end
        end
        if want > 0 then
            local reason = Ledger.ReasonOf(fight.boss, open)
            local fact, why = sys.Give(item.name, reason, want)
            if why and not res.why then res.why = why end
            if fact == nil then
                res.failed[#res.failed + 1] = item.name
            else
                local left, keys, now, me = fact, {}, time(), Me()
                for e = 1, #open do
                    local ev = open[e]
                    local n = min(ev.n, left)
                    left = left - n
                    keys[e] = ev.key
                    done[ev.key] = { s = sys.key, n = n, t = now, by = me, who = item.name,
                        r = Ledger.ReasonOf(fight.boss, { ev }) }
                end
                Write(fight, item.name, sys, fact, want, reason, "rule", keys)
                res.given[#res.given + 1] = { name = item.name, n = fact, want = want }
            end
        end
    end
    if sys.Flush then sys.Flush() end
    Changed()
    return res
end
local function HandKey(fight, name, kind)
    local base = format("%s|%s|@%s|", ns.Penalties.FightKey(fight), name, kind)
    local done, k = Store().done, 1
    while done[base .. k] do k = k + 1 end
    return base .. k
end
function Ledger.GiveHot(fight, name, kind, ev)
    if not HOT_SUM[kind] then return nil, "led.err.kind" end
    if ev and Ledger.Done(ev.key) then return nil, "led.err.done" end
    local sys = Ledger.Active()
    local want = Ledger.HotSum(kind)
    if want <= 0 then return nil, "led.err.zero" end
    local ok, why = sys.Can(want)
    if not ok then return nil, why end
    local label = Ledger.HotLabel(kind)
    local text = ev and format(ns.T("led.hot.of"), label, ev.short or "?") or label
    local reason = Compose(fight.boss, { text })
    local fact, cut = sys.Give(name, reason, want)
    if sys.Flush then sys.Flush() end
    if fact == nil then return nil, cut or "led.err.member" end
    local key = ev and ev.key or HandKey(fight, name, kind)
    Store().done[key] = { s = sys.key, n = fact, t = time(), by = Me(), who = name, r = reason, hot = kind,
        hand = not ev or nil }
    Write(fight, name, sys, fact, want, reason, ev and "hot" or "hand", { key }, kind)
    Changed()
    return fact, cut
end
function Ledger.CanUndo(key)
    local rec = Store().done[key]
    return rec ~= nil and type(rec.n) == "number" and SYSTEMS[rec.s] ~= nil
end
local function RowOf(key)
    local log = Store().log
    for i = #log, 1, -1 do
        local keys = log[i].keys or {}
        for k = 1, #keys do
            if keys[k] == key and log[i].kind ~= "undo" then return log[i] end
        end
    end
    return nil
end
function Ledger.Undo(key)
    local rec = Store().done[key]
    if not rec then return false, Ledger.Done(key) and "led.err.unknown" or "led.err.none" end
    if type(rec.n) ~= "number" or not rec.who then return false, "led.err.unknown" end
    local sys = SYSTEMS[rec.s]
    if not sys then return false, "led.err.unknown" end
    local reason = Cut(format(ns.T("led.undo"), rec.r or ""), MAX_REASON)
    if rec.n > 0 then
        local ok, why = sys.Can(-rec.n)
        if not ok then return false, why end
        local fact, why = sys.Give(rec.who, reason, -rec.n)
        if sys.Flush then sys.Flush() end
        if fact == nil then return false, why or "led.err.member" end
    end
    Store().done[key] = nil
    local row = RowOf(key)
    Append({ t = time(), by = Me(), raid = row and row.raid, fk = row and row.fk, rl = row and row.rl, boss = row and row.boss,
        who = rec.who, s = rec.s, n = -rec.n, r = reason, kind = "undo", hot = rec.hot, keys = { key } })
    Changed()
    return true
end
function Ledger.Log(raid, alt)
    local log = Store().log
    if not raid then return log end
    local out = {}
    for i = 1, #log do
        local r = log[i].raid
        if r == raid or (alt and r == alt) then out[#out + 1] = log[i] end
    end
    return out
end
function Ledger.Hand(fight)
    local fk = ns.Penalties.FightKey(fight)
    local out, seen = {}, {}
    local log, done = Store().log, Store().done
    for i = 1, #log do
        local row = log[i]
        local key = row.kind == "hand" and row.fk == fk and row.keys and row.keys[1]
        if key and done[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key = key, who = row.who, kind = row.hot, done = done[key] }
        end
    end
    return out
end
function Ledger.Sums(rows)
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        out[r.s] = (out[r.s] or 0) + (r.n or 0)
    end
    return out
end
