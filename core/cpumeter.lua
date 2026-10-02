local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local sort = table.sort
local sub = string.sub
local gsub = string.gsub
local TOP = 8
local SKADA = "Skada"
local CVAR = "scriptProfile"
local MINE = ADDON .. "_"
local PARTS = { "hot.log", "hot.rec", "hot.aura", "hot.rng", "hot.realm", "hot.comm", "hot.panel", "hot.bg" }
local WIN_PARTS = { "ui.iso", "ui.tl", "ui.page", "ui.click", "ui.sum", "ui.other", "bg" }
local IS_PART, IS_WIN = {}, {}
for i = 1, #PARTS do IS_PART[PARTS[i]] = true end
for i = 1, #WIN_PARTS do IS_WIN[WIN_PARTS[i]] = true end
local ONCE = {
    ["scan.frame"] = "scan", ["idx.frame"] = "scan", ["digest.refresh"] = "totals",
    ["sum.frame"] = "sum", ["raidsum.frame"] = "sum", ["ach.frame"] = "sum",
    ["tl.data"] = "tl", ["map.data"] = "tl", ["thr.data"] = "tl", ["thr.player"] = "tl",
    ["iso.data"] = "iso", ["prev.data"] = "prev", ["prev.map"] = "prev",
}
local CpuMeter = {}
ns.CpuMeter = CpuMeter
local profiled = type(GetCVar) == "function" and GetCVar(CVAR) == "1" or false
local session = nil
local last = nil
local winS = nil
function CpuMeter.IsMine(name)
    return name == ADDON or sub(name, 1, #MINE) == MINE
end
function CpuMeter.IsSkada(name)
    return sub(name, 1, #SKADA) == SKADA and name ~= "SkadaCPU"
end
function CpuMeter.Group(name, loaded)
    local key = (gsub(name, "%-Core$", ""))
    if key == "SkadaCPU" then return key end
    local best = key
    for other in pairs(loaded) do
        local k = (gsub(other, "%-Core$", ""))
        if #k >= 3 and #k < #best and sub(key, 1, #k) == k then best = k end
    end
    return best
end
function CpuMeter.Profiled()
    return profiled
end
function CpuMeter.Wanted()
    return type(GetCVar) == "function" and GetCVar(CVAR) == "1" or false
end
local function Snap()
    local p0 = debugprofilestop()
    UpdateAddOnCPUUsage()
    local out = {}
    for i = 1, GetNumAddOns() do
        if IsAddOnLoaded(i) then out[(GetAddOnInfo(i))] = GetAddOnCPUUsage(i) or 0 end
    end
    return out, max(0, debugprofilestop() - p0)
end
local function Sum(idx)
    local s = 0
    for i = 1, #idx do s = s + (GetAddOnCPUUsage(idx[i]) or 0) end
    return s
end
local function ByMs(a, b)
    if a.ms ~= b.ms then return a.ms > b.ms end
    return a.name < b.name
end
function CpuMeter.Diff(a, b, cost)
    local rows, total, mine, skada, count = {}, 0, 0, 0, 0
    local byKey = {}
    for name, ms in pairs(b) do
        local d = max(0, ms - (a[name] or 0))
        count = count + 1
        if CpuMeter.IsMine(name) then
            mine = mine + d
        else
            total = total + d
            if CpuMeter.IsSkada(name) then skada = skada + d end
            local key = CpuMeter.Group(name, b)
            byKey[key] = (byKey[key] or 0) + d
        end
    end
    for key, d in pairs(byKey) do
        if d > 0 then rows[#rows + 1] = { name = key, ms = d } end
    end
    mine = max(0, mine - (cost or 0))
    total = total + mine
    rows[#rows + 1] = { name = ADDON, ms = mine, mine = true }
    sort(rows, ByMs)
    return rows, total, mine, skada, count
end
local function Begin(boss, enc)
    local s = { boss = boss, enc = enc, at = GetTime(), cost = 0, mineIdx = {}, skadaIdx = {}, mine0 = 0, skada0 = 0 }
    if profiled then
        s.start, s.cost = Snap()
        for i = 1, GetNumAddOns() do
            local name = GetAddOnInfo(i)
            if IsAddOnLoaded(i) and name then
                if CpuMeter.IsMine(name) then
                    s.mineIdx[#s.mineIdx + 1] = i
                    s.mine0 = s.mine0 + (s.start[name] or 0)
                elseif CpuMeter.IsSkada(name) then
                    s.skadaIdx[#s.skadaIdx + 1] = i
                    s.skada0 = s.skada0 + (s.start[name] or 0)
                end
            end
        end
    end
    session = s
    ns.Prof.FightStart()
    ns.Prof.Skip(s.cost)
end
local function Finish()
    local s = session
    if not s then return nil end
    session = nil
    local f = ns.Prof.FightStop()
    local r = { boss = s.boss, enc = s.enc and ns.EncName(s.enc) or nil, at = time(),
        dur = f and f.dur or (GetTime() - s.at), own = f and f.ms or 0, worst = f and f.worst or 0, by = f and f.by or {} }
    if s.start then
        local b = Snap()
        local rows, total, mine, skada, count = CpuMeter.Diff(s.start, b, s.cost)
        r.total, r.mine, r.count = total, mine, count
        r.skada = #s.skadaIdx > 0 and skada or nil
        r.rows = {}
        for i = 1, #rows do
            if i <= TOP then r.rows[i] = rows[i] end
            if rows[i].mine then
                r.rank = i
                if i > TOP then r.rows[TOP + 1] = rows[i] end
            end
        end
    end
    last = r
    if s.boss then ns.GetDB().cpuLast = r end
    return r
end
function CpuMeter.Pull(enc)
    if session and session.boss then return end
    if session then
        session = nil
        ns.Prof.FightStop()
    end
    Begin(true, enc)
end
function CpuMeter.Close(enc)
    if not (session and session.boss) then return end
    if enc ~= nil then session.enc = enc end
    local r = Finish()
    if r and profiled then CpuMeter.Print(r) end
end
function CpuMeter.Running()
    return session ~= nil
end
function CpuMeter.Last()
    local r = ns.GetDB().cpuLast
    return type(r) == "table" and r or nil
end
local function Ms(v)
    if v >= 100 then return format("%.0f", v) end
    if v >= 10 then return ns.Dec(format("%.1f", v)) end
    return ns.Dec(format("%.2f", v))
end
CpuMeter.Ms = Ms
function CpuMeter.Lines(r)
    local T = ns.T
    local dur = max(1, r.dur or 0)
    local sec = floor(dur + 0.5)
    local out = { format(T("cpu.head"), r.enc or T("cpu.fight"), format("%d:%02d", floor(sec / 60), sec % 60)) }
    local rows = r.rows
    if rows and r.total then
        local total = max(r.total, 0.001)
        for i = 1, #rows do
            local row = rows[i]
            local name = row.mine and format(T("cpu.mine"), row.name) or row.name
            out[#out + 1] = format(T("cpu.row"), row.mine and r.rank or i, name, Ms(row.ms), Ms(row.ms / dur),
                format("%.0f", row.ms / total * 100))
        end
        out[#out + 1] = format(T("cpu.total"), r.count or #rows, Ms(r.total), Ms(r.total / dur))
    end
    out[#out + 1] = format(T("cpu.own"), Ms(r.own or 0), Ms((r.own or 0) / dur), Ms(r.worst or 0))
    local parts = {}
    local by = {}
    for key, v in pairs(r.by or {}) do
        local k = IS_PART[key] and key or "hot.bg"
        by[k] = (by[k] or 0) + v
    end
    for i = 1, #PARTS do
        local v = by[PARTS[i]] or 0
        if v >= 0.005 then parts[#parts + 1] = { key = PARTS[i], ms = v } end
    end
    sort(parts, function(a, b) return a.ms > b.ms end)
    for i = 1, #parts do parts[i] = format("%s %s", T("cpu.part." .. parts[i].key), Ms(parts[i].ms / dur)) end
    if #parts > 0 then out[#out + 1] = format(T("cpu.parts"), table.concat(parts, "; ")) end
    out[#out + 1] = T(rows and "cpu.warn" or "cpu.hint")
    return out
end
function CpuMeter.Print(r)
    local lines = CpuMeter.Lines(r)
    for i = 1, #lines do ns.Print(lines[i]) end
end
function CpuMeter.State()
    local want = CpuMeter.Wanted()
    if want == profiled then return ns.T(profiled and "cpu.state.on" or "cpu.state.off") end
    return ns.T(want and "cpu.state.wait" or "cpu.state.offwait")
end
function CpuMeter.Set(on)
    on = on and true or false
    if CpuMeter.Wanted() == on and profiled == on then
        return { ns.T(on and "cpu.already.on" or "cpu.already.off") }
    end
    SetCVar(CVAR, on and "1" or "0")
    if profiled == on then return { CpuMeter.State() } end
    local out = { ns.T(on and "cpu.on" or "cpu.off") }
    if on then out[2] = ns.T("cpu.warn") end
    if ns.Kit and ns.Kit.Confirm and ReloadUI then
        ns.Kit.Confirm(ns.T("cpu.reload"), ns.T("cpu.reload.yes"), ReloadUI)
    end
    return out
end
function CpuMeter.Report()
    local r = CpuMeter.Last()
    local out = { CpuMeter.State() }
    local lines = r and CpuMeter.Lines(r) or { ns.T("cpu.none") }
    for i = 1, #lines do out[#out + 1] = lines[i] end
    local w = CpuMeter.WinLast()
    if w then
        lines = CpuMeter.WinLines(w)
        for i = 1, #lines do out[#out + 1] = lines[i] end
    end
    return out
end
function CpuMeter.Live()
    local s = session
    if not s then
        local r = last or CpuMeter.Last()
        if not r then return nil, nil, false, profiled end
        local dur = max(1, r.dur or 0)
        return (r.mine or r.own or 0) / dur, r.skada and r.skada / dur, false, r.mine ~= nil
    end
    local dur = max(1, GetTime() - s.at)
    if s.start then
        local p0 = debugprofilestop()
        UpdateAddOnCPUUsage()
        local mine, skada = Sum(s.mineIdx), #s.skadaIdx > 0 and Sum(s.skadaIdx) or nil
        mine = max(0, mine - s.mine0 - s.cost)
        local cost = max(0, debugprofilestop() - p0)
        s.cost = s.cost + cost
        ns.Prof.Skip(cost)
        return mine / dur, skada and max(0, skada - s.skada0) / dur, true, true
    end
    local f = ns.Prof.Fight()
    return (f and f.ms or 0) / dur, nil, true, false
end
function CpuMeter.Stats()
    local s = session
    if s then
        local f = ns.Prof.Fight()
        return f and max(f.worst, f.frameMs) or 0, GetTime() - s.at
    end
    local r = last or CpuMeter.Last()
    if not r then return 0, 0 end
    return r.worst or 0, r.dur or 0
end
function CpuMeter.OnceGroup(key)
    return ONCE[key] or "other"
end
local function WinResult(f, s)
    local jobs, once = {}, 0
    for key, o in pairs(f.once or {}) do
        local g = CpuMeter.OnceGroup(key)
        local j = jobs[g]
        if not j then
            j = { ms = 0, n = 0, max = 0, runs = 0 }
            jobs[g] = j
        end
        j.ms, j.n, j.runs = j.ms + o.ms, j.n + o.n, j.runs + o.runs
        if o.max > j.max then j.max = o.max end
        once = once + o.ms
    end
    local r = { at = time(), dur = f.dur or 0, own = f.ms, once = once, worst = f.worst, by = f.by, jobs = jobs }
    if s.start then
        UpdateAddOnCPUUsage()
        r.mine = max(0, Sum(s.idx) - s.mine0 - s.cost)
    end
    return r
end
function CpuMeter.WinCheck()
    local open = (ns.Shell and ns.Shell.IsOpen and ns.Shell.IsOpen())
        or (ns.ReplayIso and ns.ReplayIso.IsShown and ns.ReplayIso.IsShown()) or false
    if open and not winS then
        local s = { idx = {}, mine0 = 0, cost = 0 }
        winS = s
        ns.Prof.WinStart()
        if profiled then
            local p0 = debugprofilestop()
            UpdateAddOnCPUUsage()
            for i = 1, GetNumAddOns() do
                local name = GetAddOnInfo(i)
                if name and IsAddOnLoaded(i) and CpuMeter.IsMine(name) then
                    s.idx[#s.idx + 1] = i
                    s.mine0 = s.mine0 + (GetAddOnCPUUsage(i) or 0)
                end
            end
            s.start = true
            s.cost = max(0, debugprofilestop() - p0)
            ns.Prof.Skip(s.cost)
        end
    elseif not open and winS then
        local s = winS
        winS = nil
        local f = ns.Prof.WinStop()
        if f then ns.GetDB().cpuWin = WinResult(f, s) end
    end
end
function CpuMeter.WinLast()
    local r = ns.GetDB().cpuWin
    return type(r) == "table" and r or nil
end
function CpuMeter.WinLive()
    local w = ns.Prof.Win()
    if w then
        local dur = GetTime() - w.at
        local once = 0
        for _, o in pairs(w.once) do once = once + o.ms end
        return w.ms / max(1, dur), max(w.worst, w.frameMs), true, dur, once
    end
    local r = CpuMeter.WinLast()
    if not r then return nil, 0, false, 0, 0 end
    return (r.own or 0) / max(1, r.dur or 0), r.worst or 0, false, r.dur or 0, r.once or 0
end
function CpuMeter.WinLines(r)
    local T = ns.T
    local dur = max(1, r.dur or 0)
    local sec = floor(dur + 0.5)
    local own, once = r.own or 0, r.once or 0
    local out = { format(T("cpu.win.head"), format("%d:%02d", floor(sec / 60), sec % 60), Ms(own + once), Ms(once)),
        format(T("cpu.win.steady"), Ms(own), Ms(own / dur), Ms(r.worst or 0)) }
    local sums = { bg = 0 }
    for key, v in pairs(r.by or {}) do
        if IS_WIN[key] then
            sums[key] = (sums[key] or 0) + v
        elseif sub(key, 1, 3) == "ui." then
            sums["ui.other"] = (sums["ui.other"] or 0) + v
        else
            sums.bg = sums.bg + v
        end
    end
    local parts = {}
    for i = 1, #WIN_PARTS do
        local v = sums[WIN_PARTS[i]] or 0
        if v >= 0.005 then parts[#parts + 1] = { name = WIN_PARTS[i], ms = v } end
    end
    sort(parts, ByMs)
    for i = 1, #parts do parts[i] = format("%s %s", T("cpu.win.part." .. parts[i].name), Ms(parts[i].ms / dur)) end
    if #parts > 0 then out[#out + 1] = format(T("cpu.win.parts"), table.concat(parts, "; ")) end
    local jobs = {}
    for g, j in pairs(r.jobs or {}) do jobs[#jobs + 1] = { name = g, ms = j.ms, j = j } end
    sort(jobs, ByMs)
    for i = 1, #jobs do
        local j = jobs[i].j
        out[#out + 1] = format(T("cpu.win.once"), T("cpu.once." .. jobs[i].name), Ms(j.ms), max(1, j.runs), Ms(j.max))
    end
    if r.mine then out[#out + 1] = format(T("cpu.win.prof"), Ms(r.mine), Ms(r.mine / dur)) end
    return out
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.bg", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if not session then Begin(false, nil) end
    elseif session and not session.boss then
        Finish()
    end
end))
