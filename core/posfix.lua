local _, ns = ...
local format = string.format
local PosFix = {}
ns.PosFix = PosFix
local SUB = "FW_POSFIX"
PosFix.SUB = SUB
local LOST_HOLD = 0.5
local STEP = 1
local RETRY = 30
local LOG_MAX = 30
local function Try(fn, ...)
    pcall(fn, ...)
end
local function Level(n)
    if n ~= 0 then Try(SetDungeonMapLevel, n) else Try(SetDungeonMapLevel, 0) end
end
local function Zone()
    Try(SetMapToCurrentZone)
end
local function BySelf()
    Zone()
    local n = GetNumDungeonMapLevels() or 0
    for level = 1, n do
        Level(level)
        local x, y = GetPlayerMapPosition("player")
        if (x or 0) > 0 or (y or 0) > 0 then return end
    end
end
PosFix.list = {
    { key = "none", run = function() end },
    { key = "zone", run = Zone },
    { key = "scan", run = function() Zone() ns.RecMap.Pick() end },
    { key = "lvl0", run = function() Level(0) end },
    { key = "self", run = BySelf },
    { key = "cont", run = function() Try(SetMapZoom, GetCurrentMapContinent() or 0) Zone() end },
    { key = "world", run = function() Try(SetMapZoom, 0) Zone() end },
    { key = "wmap", run = function()
        local wm = WorldMapFrame
        if wm and not wm:IsShown() then
            wm:Show()
            Zone()
            wm:Hide()
        end
        Zone()
    end },
    { key = "good", run = function()
        Zone()
        local good = ns.RecMap.Level()
        if good then Level(good) end
    end },
}
local state = "idle"
local lostSeen, stepAt, retryAt = nil, 0, 0
local baseArea, baseLevel = nil, 0
local step = 0
local log = {}
local function Note(s)
    log[#log + 1] = s
    if #log > LOG_MAX then table.remove(log, 1) end
end
local function Diag(on, alive)
    local x, y = GetPlayerMapPosition("player")
    local me = ((x or 0) > 0 or (y or 0) > 0) and 1 or 0
    local wm = WorldMapFrame and WorldMapFrame:IsShown() and 1 or 0
    local bf = BattlefieldMinimap and BattlefieldMinimap:IsShown() and 1 or 0
    return format("on=%d/%d me=%d area=%s lvl=%d/%d wm=%d bf=%d", on, alive, me, tostring(GetCurrentMapAreaID() or 0),
        GetCurrentMapDungeonLevel() or 0, GetNumDungeonMapLevels() or 0, wm, bf)
end
local function Write(now, kind, key, on, alive)
    local diag = Diag(on, alive)
    ns.Store.Append(now, SUB, nil, UnitName("player"), 0, nil, nil, 0, kind, key, on, diag)
    Note(format("%.1f %s %s %s", now, kind, key, diag))
end
local function Back()
    if GetCurrentMapAreaID() ~= baseArea then Zone() end
    if (GetCurrentMapDungeonLevel() or 0) ~= baseLevel then Level(baseLevel) end
end
local function Done(now, on, alive)
    Write(now, "ok", PosFix.list[step].key, on, alive)
    ns.RecMap.Keep()
    state = "idle"
end
local function FixStep(now)
    local first = false
    if now - stepAt >= STEP then
        if step >= #PosFix.list then
            Write(now, "fail", "", ns.RecMap.Count())
            state, retryAt = "gave", now + RETRY
            return
        end
        step, stepAt, first = step + 1, now, true
    end
    PosFix.list[step].run()
    local on, alive = ns.RecMap.Count()
    if first then Write(now, "try", PosFix.list[step].key, on, alive) end
    if on > 0 then
        Done(now, on, alive)
    else
        Back()
    end
end
function PosFix.Busy()
    return state == "fix"
end
function PosFix.Step(now)
    local live = ns.Store.Live()
    if not (live and live.pull) then
        state, lostSeen = "idle", nil
        return
    end
    local on, alive = ns.RecMap.Count()
    if state == "fix" then
        if on > 0 then
            Done(now, on, alive)
            return
        end
        FixStep(now)
        return
    end
    if on > 0 or alive == 0 then
        if state == "gave" and on > 0 then
            Write(now, "back", "", on, alive)
            state = "idle"
        end
        lostSeen = nil
        return
    end
    if state == "gave" and now < retryAt then return end
    lostSeen = lostSeen or now
    if now - lostSeen < LOST_HOLD then return end
    step, stepAt, state = 0, now - STEP, "fix"
    baseArea, baseLevel = GetCurrentMapAreaID(), GetCurrentMapDungeonLevel() or 0
    Write(now, "lost", "", on, alive)
    FixStep(now)
end
function PosFix.Log()
    return log
end
local QUAKE_NEAR = 20
local NOISE_ALIVE = 2
local TIMES_MAX = 4
local DIAG = "on=(%d+)/(%d+) me=(%d+) area=(%S+) lvl=(%d+)/(%d+) wm=(%d+) bf=(%d+)"
local FIX_NAME = {
    none = "iso.pfx.fix.none", zone = "iso.pfx.fix.zone", scan = "iso.pfx.fix.scan", lvl0 = "iso.pfx.fix.lvl0",
    self = "iso.pfx.fix.self", cont = "iso.pfx.fix.cont", world = "iso.pfx.fix.world", wmap = "iso.pfx.fix.wmap",
    good = "iso.pfx.fix.good",
}
function PosFix.FixName(key)
    local k = FIX_NAME[key]
    return k and ns.T(k) or tostring(key)
end
local function Quote(key)
    return format(ns.T("iso.pfx.q"), PosFix.FixName(key))
end
local function Clock(sec)
    sec = math.max(0, math.floor(sec))
    return format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local function Secs(x)
    return format("%g", math.floor(x * 10 + 0.5) / 10)
end
function PosFix.Episodes(L, pull, tailAt)
    local out = {}
    local T = L and L.pfxT
    if not T or #T == 0 then return out end
    local quakes = L.pfQuake or {}
    local ep
    local function Close()
        if not ep then return end
        if ep.ok then
            ep.kind = "fixed"
        elseif ep.fail then
            ep.kind = ep.back and "back" or "failed"
        else
            ep.kind = "open"
        end
        if ep.alive <= NOISE_ALIVE then
            ep.noise = "alive"
        elseif tailAt and ep.lost >= tailAt then
            ep.noise = "tail"
        end
        out[#out + 1] = ep
        ep = nil
    end
    for i = 1, #T do
        local k = L.pfxKind[i]
        if k == "lost" then
            Close()
            local on, alive, me, area, lvl, lvls, wm, bf = tostring(L.pfxDiag[i] or ""):match(DIAG)
            ep = { lost = T[i], sec = math.max(0, math.floor(T[i] - pull)), on = tonumber(on) or 0,
                   alive = tonumber(alive) or 99, me = me == "1", area = area or "?", lvl = tonumber(lvl) or 0,
                   lvls = tonumber(lvls) or 0, wm = wm == "1", bf = bf == "1", tries = {} }
            for q = #quakes, 1, -1 do
                if quakes[q] <= T[i] then
                    if T[i] - quakes[q] <= QUAKE_NEAR then ep.quake = T[i] - quakes[q] end
                    break
                end
            end
        elseif ep then
            if k == "try" then
                ep.tries[#ep.tries + 1] = { fix = L.pfxFix[i], after = T[i] - ep.lost }
            elseif k == "ok" then
                ep.ok, ep.fix = T[i], L.pfxFix[i]
                Close()
            elseif k == "fail" then
                ep.fail = T[i]
            elseif k == "back" then
                ep.back = T[i]
                Close()
            end
        end
    end
    Close()
    return out
end
function PosFix.Totals(eps)
    local t = { n = #eps, real = 0, fixed = 0, back = 0, failed = 0, noise = 0 }
    for i = 1, #eps do
        local ep = eps[i]
        if ep.noise then
            t.noise = t.noise + 1
        else
            t.real = t.real + 1
            if ep.kind == "fixed" then
                t.fixed = t.fixed + 1
            elseif ep.kind == "back" then
                t.back = t.back + 1
            else
                t.failed = t.failed + 1
            end
        end
    end
    return t
end
function PosFix.TotalLine(t)
    local parts = {}
    if t.fixed > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.t.fixed"), t.fixed) end
    if t.back > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.t.back"), t.back) end
    if t.noise > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.t.noise"), t.noise) end
    if t.failed > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.t.failed"), t.failed) end
    return format(ns.T("iso.pfx.total"), t.n, table.concat(parts, ", "))
end
local function TimeList(list)
    local out = {}
    for i = 1, math.min(#list, TIMES_MAX) do out[i] = Clock(list[i]) end
    local s = table.concat(out, ", ")
    if #list > TIMES_MAX then s = s .. format(ns.T("iso.pfx.l.more"), #list - TIMES_MAX) end
    return s
end
function PosFix.Line(eps, dev)
    local fixed, back, failed, names, seen, noise = {}, {}, {}, {}, {}, 0
    for i = 1, #eps do
        local ep = eps[i]
        if ep.noise then
            noise = noise + 1
        elseif ep.kind == "fixed" then
            fixed[#fixed + 1] = ep.sec
            if not seen[ep.fix] then
                seen[ep.fix] = true
                names[#names + 1] = Quote(ep.fix)
            end
        elseif ep.kind == "back" then
            back[#back + 1] = ep.sec
        else
            failed[#failed + 1] = ep.sec
        end
    end
    if #fixed + #back + #failed == 0 then
        if noise == 0 or not dev then return nil end
        return format(ns.T("iso.pfx.l.noise"), noise)
    end
    local parts = {}
    if #fixed > 0 then
        parts[#parts + 1] = format(ns.T(#names > 1 and "iso.pfx.l.fixedN" or "iso.pfx.l.fixed1"),
            table.concat(names, ", "), TimeList(fixed))
    end
    if #back > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.l.back"), TimeList(back)) end
    if #failed > 0 then parts[#parts + 1] = format(ns.T("iso.pfx.l.failed"), TimeList(failed)) end
    local body = table.concat(parts, "; ")
    if #fixed == 0 then return format(ns.T("iso.pfx.l.lead"), #back + #failed, body) end
    return format(ns.T("iso.pfx.l.head"), body)
end
local function PlaceText(ep, ctx)
    local parts = {}
    if ctx and ctx.raid then parts[1] = ctx.raid end
    parts[#parts + 1] = ep.lvl == 0 and ns.T("iso.pfx.p.lvl0") or format(ns.T("iso.pfx.p.lvl"), ep.lvl, ep.lvls)
    parts[#parts + 1] = ns.T(ep.wm and "iso.pfx.p.wm1" or "iso.pfx.p.wm0")
    if ep.bf then parts[#parts + 1] = ns.T("iso.pfx.p.bf1") end
    return table.concat(parts, ", ")
end
local function Outcome(ep)
    if ep.kind == "fixed" then
        return format(ns.T("iso.pfx.e.ok"), Secs(ep.ok - ep.lost), Quote(ep.fix))
    elseif ep.kind == "back" then
        return format(ns.T("iso.pfx.e.back"), #ep.tries, Secs(ep.back - ep.lost))
    elseif ep.kind == "failed" then
        return format(ns.T("iso.pfx.e.failed"), #ep.tries)
    end
    return ns.T("iso.pfx.e.open")
end
function PosFix.EpisodeText(ep, ctx)
    if ep.noise then
        local why = ep.noise == "alive" and format(ns.T("iso.pfx.n.alive"), ep.alive) or ns.T("iso.pfx.n.tail")
        return format(ns.T("iso.pfx.e.noise"), Clock(ep.sec), why)
    end
    local s = format(ns.T("iso.pfx.e.lost"), Clock(ep.sec), ep.alive, ns.T(ep.me and "iso.pfx.e.me1" or "iso.pfx.e.me0"))
    s = s .. " " .. PlaceText(ep, ctx) .. ". " .. Outcome(ep)
    if ep.quake then s = s .. " " .. format(ns.T("iso.pfx.e.quake"), math.floor(ep.quake + 0.5)) end
    return s
end
function PosFix.EpisodeTip(ep, ctx)
    local out = {}
    out[1] = format(ns.T("iso.pfx.f.on"), ep.on, ep.alive)
    out[2] = ns.T(ep.me and "iso.pfx.f.me1" or "iso.pfx.f.me0")
    out[3] = format(ns.T("iso.pfx.f.area"), ep.area, ctx and ctx.raid or "?")
    out[4] = format(ns.T("iso.pfx.f.lvl"), ep.lvl, ep.lvls)
    out[5] = format(ns.T("iso.pfx.f.maps"), ns.T(ep.wm and "iso.pfx.p.open" or "iso.pfx.p.shut"),
        ns.T(ep.bf and "iso.pfx.p.open" or "iso.pfx.p.shut"))
    if ep.noise then
        out[6] = ns.T("iso.pfx.f.noise")
    elseif #ep.tries == 0 then
        out[6] = ns.T("iso.pfx.f.notry")
    else
        local list = {}
        for i = 1, #ep.tries do
            local t = ep.tries[i]
            local s = format(ns.T("iso.pfx.f.try"), Quote(t.fix), Secs(t.after))
            if ep.kind == "fixed" and i == #ep.tries then s = s .. " " .. ns.T("iso.pfx.f.helped") end
            list[i] = s
        end
        out[6] = ns.T("iso.pfx.f.tries") .. " " .. table.concat(list, "; ")
    end
    if ep.quake then out[#out + 1] = format(ns.T("iso.pfx.e.quake"), math.floor(ep.quake + 0.5)) end
    return table.concat(out, "\n")
end
function PosFix.Reset()
    state, lostSeen, step = "idle", nil, 0
end
