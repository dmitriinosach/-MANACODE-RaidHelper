local ADDON, ns = ...
ns.L = {}
ns.LEN = {}
ns.lang = "ruRU"
ns.langMissing = {}
local ruKept = {}
function ns.LangSetting()
    local db = ns.GetDB and ns.GetDB()
    local set = db and db.settings and db.settings.lang
    if set == "enUS" or set == "ruRU" then return set end
    return "auto"
end
function ns.LangResolve(set)
    set = set or ns.LangSetting()
    if set == "enUS" or set == "ruRU" then return set end
    return GetLocale() == "ruRU" and "ruRU" or "enUS"
end
function ns.SetLangSetting(set)
    if set ~= "enUS" and set ~= "ruRU" then set = "auto" end
    local db = ns.GetDB()
    if db.settings.lang == set then return end
    db.settings.lang = set
    ns.Print(ns.T("set.lang.reload"))
end
function ns.ApplyLang(lang)
    lang = lang or ns.LangResolve()
    local L = ns.L
    for k, v in pairs(ruKept) do
        if v == false then L[k] = nil else L[k] = v end
        ruKept[k] = nil
    end
    local missing = {}
    ns.langMissing = missing
    ns.lang = lang
    if lang ~= "enUS" then return end
    for k in pairs(L) do
        if ns.LEN[k] == nil then missing[#missing + 1] = k end
    end
    table.sort(missing)
    for k, v in pairs(ns.LEN) do
        local was = L[k]
        ruKept[k] = was == nil and false or was
        L[k] = v
    end
end
function ns.PluralPick(n, one, few, many)
    if ns.lang == "enUS" then
        if n == 1 then return one end
        return many
    end
    local n10, n100 = n % 10, n % 100
    if n10 == 1 and n100 ~= 11 then return one end
    if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then return few end
    return many
end
function ns.Dec(s)
    if ns.lang == "enUS" then return s end
    return (s:gsub("%.", ","))
end
local preFrames = nil
if type(EnumerateFrames) == "function" then
    preFrames = {}
    local f = EnumerateFrames()
    while f do
        preFrames[f] = true
        f = EnumerateFrames(f)
    end
end
ns.Prof = { on = false, rows = {}, keys = setmetatable({}, { __mode = "k" }) }
local Prof = ns.Prof
local fight = nil
local win = nil
local cur = nil
local curT = nil
function Prof.Add(key, ms, items)
    local r = Prof.rows[key]
    if not r then
        r = { n = 0, ms = 0, last = 0, max = 0, items = 0 }
        Prof.rows[key] = r
    end
    r.n = r.n + 1
    r.ms = r.ms + ms
    r.last = ms
    if ms > r.max then r.max = ms end
    r.items = r.items + (items or 0)
end
function Prof.Reset()
    wipe(Prof.rows)
end
function Prof.Busy()
    return fight ~= nil or win ~= nil or Prof.on
end
local function Acc(f, key, ms, t)
    if f.skip > 0 then
        ms = ms - f.skip
        f.skip = 0
    end
    if ms < 0 then return end
    f.ms = f.ms + ms
    f.by[key] = (f.by[key] or 0) + ms
    if t == f.frameT then
        f.frameMs = f.frameMs + ms
    else
        if f.frameMs > f.worst then f.worst = f.frameMs end
        f.frameT, f.frameMs = t, ms
    end
end
function Prof.Hot(key, ms)
    if ms < 0 then return end
    if fight or win then
        local t = GetTime()
        if fight then Acc(fight, key, ms, t) end
        if win then Acc(win, key, ms, t) end
    end
    if Prof.on then Prof.Add(key, ms, 1) end
end
local function Move(f, key, parent, ms)
    local by = f.by
    by[key] = (by[key] or 0) + ms
    by[parent] = (by[parent] or 0) - ms
end
function Prof.Part(key, parent, ms)
    if ms < 0 or key == parent then return end
    if fight then Move(fight, key, parent, ms) end
    if win then Move(win, key, parent, ms) end
    if Prof.on then Prof.Add(key, ms, 1) end
end
function Prof.Skip(ms)
    if ms <= 0 or not cur or curT ~= GetTime() then return end
    if fight then fight.skip = fight.skip + ms end
    if win then win.skip = win.skip + ms end
end
function Prof.Once(key, ms)
    local w = win
    if not w or ms < 0 then return end
    local o = w.once[key]
    if not o then
        o = { ms = 0, n = 0, max = 0, runs = 0 }
        w.once[key] = o
    end
    o.ms = o.ms + ms
    o.n = o.n + 1
    if ms > o.max then o.max = ms end
    w.skip = w.skip + ms
end
function Prof.OnceEnd(key)
    local o = win and win.once[key]
    if o then o.runs = o.runs + 1 end
end
function Prof.Wrap(key, fn)
    local w = function(...)
        if not fight and not win and not Prof.on then return fn(...) end
        local t = GetTime()
        local outer = cur
        if outer and curT ~= t then outer = nil end
        cur, curT = key, t
        local p0 = debugprofilestop()
        fn(...)
        local ms = debugprofilestop() - p0
        cur = outer
        if outer then Prof.Part(key, outer, ms) else Prof.Hot(key, ms) end
    end
    Prof.keys[w] = key
    return w
end
local function NewSession()
    return { at = GetTime(), ms = 0, worst = 0, frameT = nil, frameMs = 0, skip = 0, by = {} }
end
local function Close(f)
    if f.frameMs > f.worst then f.worst = f.frameMs end
    f.dur = GetTime() - f.at
    return f
end
function Prof.FightStart()
    fight = NewSession()
end
function Prof.FightStop()
    local f = fight
    if not f then return nil end
    fight = nil
    return Close(f)
end
function Prof.Fight()
    return fight
end
function Prof.WinStart()
    win = NewSession()
    win.once = {}
end
function Prof.WinStop()
    local f = win
    if not f then return nil end
    win = nil
    return Close(f)
end
function Prof.Win()
    return win
end
local JOB_BUDGET = 25
local JOB_BUDGET_TIGHT = 8
local JOB_CHECK = 64
local NOTE_GAP = 0.2
local Jobs = {}
ns.Jobs = Jobs
local queue = {}
local jobByKey = {}
local frameStart = 0
local budget = JOB_BUDGET
local ticks = 0
local inJob = false
local running = nil
local listeners = {}
local lastNote = 0
local dirty = false
local jobFrame = CreateFrame("Frame")
jobFrame:Hide()
local function Drop(job)
    for i = 1, #queue do
        if queue[i] == job then
            table.remove(queue, i)
            break
        end
    end
    if jobByKey[job.key] == job then jobByKey[job.key] = nil end
    dirty = true
    jobFrame:Show()
end
local function Frac(job)
    local f = job.lo
    if job.pt > 0 then
        local k = job.pd / job.pt
        if k > 1 then k = 1 elseif k < 0 then k = 0 end
        f = job.lo + (job.hi - job.lo) * k
    end
    if f > job.shown then job.shown = f end
    return job.shown
end
local JOB_SPEED = { gentle = 8, normal = JOB_BUDGET, fast = 40 }
Jobs.SPEEDS = { "gentle", "normal", "fast" }
function Jobs.Speed()
    local db = ns.GetDB()
    local k = type(db) == "table" and type(db.settings) == "table" and db.settings.jobSpeed
    if JOB_SPEED[k or ""] then return k end
    return "normal"
end
function Jobs.SetSpeed(key)
    if not JOB_SPEED[key or ""] then return end
    ns.GetDB().settings.jobSpeed = key ~= "normal" and key or nil
end
function Jobs.Budget()
    if UnitAffectingCombat("player") then return JOB_BUDGET_TIGHT end
    local _, kind = GetInstanceInfo()
    if kind and kind ~= "none" then return JOB_BUDGET_TIGHT end
    return JOB_SPEED[Jobs.Speed()]
end
local function OverBudget()
    local spent = debugprofilestop() - frameStart
    return spent > budget or spent < 0
end
function Jobs.Run(key, fn, onDone, prof, urgent)
    local job = jobByKey[key]
    if job then
        if onDone then job.done[#job.done + 1] = onDone end
        if urgent and queue[1] ~= job then
            Drop(job)
            jobByKey[key] = job
            table.insert(queue, 1, job)
        end
        return false
    end
    job = { key = key, co = coroutine.create(fn), done = {}, prof = prof, spent = 0, at = GetTime(),
            pd = 0, pt = 0, lo = 0, hi = 1, shown = 0 }
    if onDone then job.done[1] = onDone end
    jobByKey[key] = job
    if urgent then
        table.insert(queue, 1, job)
    else
        queue[#queue + 1] = job
    end
    jobFrame:Show()
    return true
end
function Jobs.Busy(key)
    return jobByKey[key] ~= nil
end
function Jobs.Cancel(key)
    local job = jobByKey[key]
    if job then Drop(job) end
end
function Jobs.Step(weight)
    ticks = ticks + (weight or 1)
    if ticks < JOB_CHECK then return end
    ticks = 0
    if inJob and OverBudget() then coroutine.yield() end
end
function Jobs.Yield()
    ticks = 0
    if inJob and OverBudget() then coroutine.yield() end
end
function Jobs.Label(label, counted)
    local job = running
    if job then
        job.label = label
        job.counted = counted
    end
end
function Jobs.Progress(done, total)
    local job = running
    if job then
        job.pd = done
        job.pt = total
    end
end
function Jobs.Band(lo, hi)
    local job = running
    if job then
        Frac(job)
        job.lo = lo
        job.hi = hi
        job.pd = 0
        job.pt = 0
    end
end
local function Caption(job)
    local text = ns.T(job.label)
    if not job.counted then return text end
    local total = job.pt
    local cur = math.floor(job.pd) + 1
    if cur > total then cur = total end
    return string.format(text, cur, total)
end
function Jobs.State()
    local n = #queue
    for i = 1, n do
        local job = queue[i]
        if job.label then
            return job.key, Frac(job), Caption(job), n, GetTime() - job.at
        end
    end
    if n > 0 then return queue[1].key, nil, nil, n, GetTime() - queue[1].at end
    return nil, nil, nil, 0, 0
end
function Jobs.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Notify()
    if queue[1] then dirty = true end
    if not dirty then return end
    local now = GetTime()
    if now - lastNote < NOTE_GAP then return end
    lastNote = now
    dirty = false
    for i = 1, #listeners do listeners[i]() end
end
local function Finish(job, ok, ...)
    Drop(job)
    if job.prof and ns.Prof.on then ns.Prof.Add(job.prof .. ".total", job.spent) end
    if win then Prof.OnceEnd(job.prof or "job") end
    local done = job.done
    for i = 1, #done do
        if ok then done[i](...) else done[i](nil) end
    end
end
jobFrame:SetScript("OnUpdate", Prof.Wrap("hot.bg", function(self)
    frameStart = debugprofilestop()
    budget = Jobs.Budget()
    while queue[1] do
        local job = queue[1]
        local t0 = debugprofilestop()
        inJob = true
        running = job
        ticks = 0
        local ok, a, b, c = coroutine.resume(job.co)
        running = nil
        inJob = false
        local spent = debugprofilestop() - t0
        job.spent = job.spent + spent
        if job.prof and ns.Prof.on then ns.Prof.Add(job.prof, spent) end
        if win then Prof.Once(job.prof or "job", spent) end
        if not ok then
            ns.Print(tostring(a))
            Finish(job, false)
        elseif coroutine.status(job.co) == "dead" then
            Finish(job, true, a, b, c)
        end
        if OverBudget() then break end
    end
    Notify()
    if not queue[1] and not dirty then self:Hide() end
end))
local readyCallbacks = {}
function ns.OnReady(fn)
    readyCallbacks[#readyCallbacks + 1] = fn
end
function ns.T(key)
    return ns.L[key] or key
end
function ns.EnvName(kind)
    return ns.L["env." .. tostring(kind)] or ns.L["env.OTHER"]
end
function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Raid Helper:|r " .. text)
end
local OLD_ADDON = "HTP_FailWatch"
local SHIP_ADDON = "ManaCode_RaidHelper"
local scratch = nil
local recLock = nil
local testListeners = {}
function ns.GetDB()
    return scratch or ManaCodeRaidHelperDB
end
function ns.TestSet()
    local db = ns.GetDB()
    local t = type(db) == "table" and db.testSet
    if type(t) == "table" then
        return tostring(t.id or "?"), type(t.title) == "string" and t.title or nil
    end
    if type(t) == "string" or type(t) == "number" then
        return tostring(t), type(db.testTitle) == "string" and db.testTitle or nil
    end
    return nil, nil
end
function ns.RecLock()
    if recLock then return recLock end
    if ns.TestSet() then return "test" end
    return nil
end
function ns.OnTestSet(fn)
    testListeners[#testListeners + 1] = fn
end
function ns.LeaveTest()
    if recLock or not ns.TestSet() then return false end
    local db = ns.GetDB()
    db.testSet = nil
    db.testTitle = nil
    if ns.Recorder and ns.Recorder.Start then ns.Recorder.Start() end
    for i = 1, #testListeners do testListeners[i]() end
    ns.Print(ns.T("test.left"))
    return true
end
local function Newer(db, rec)
    local top = nil
    local fmt = db.fmt
    local v = type(fmt) == "table" and tonumber(fmt.rec) or nil
    if v and v > rec then top = v end
    local list = { db.live }
    local segs = db.segments
    if type(segs) == "table" then
        for i = 1, #segs do list[#list + 1] = segs[i] end
    end
    for i = 1, #list do
        local s = list[i]
        local sv = type(s) == "table" and tonumber(s.v) or nil
        if sv and sv > rec and (not top or sv > top) then top = sv end
    end
    return top
end
local function AddonVersion()
    if not GetAddOnMetadata then return nil end
    return GetAddOnMetadata(ADDON, "Version")
end
ns.AddonVersion = AddonVersion
local function OldFolder()
    if ADDON ~= SHIP_ADDON or not IsAddOnLoaded then return end
    if IsAddOnLoaded(OLD_ADDON) then ns.Print(ns.T("old.folder")) end
end
ns.TUNE = { react = 3, tail = 40, waveMin = 5, waveStep = 1, rebuff = 90, expectGood = 100, expectFair = 85,
            preview = 8 }
local TUNE_GRADE = { react = true, tail = true, waveMin = true, waveStep = true, rebuff = true }
local TUNE_ORDER = { "react", "tail", "waveMin", "waveStep", "rebuff" }
local tuneListeners = {}
local function TuneStore()
    local db = ns.GetDB()
    local s = type(db) == "table" and db.settings
    local t = type(s) == "table" and s.tune
    if type(t) == "table" then return t end
    return nil
end
function ns.Tune(key)
    local t = TuneStore()
    local v = t and t[key]
    if type(v) == "number" then return v end
    return ns.TUNE[key]
end
function ns.SetTune(key, v)
    local def = ns.TUNE[key]
    if not def then return end
    local s = ns.GetDB().settings
    if type(s.tune) ~= "table" then s.tune = {} end
    if type(v) ~= "number" or v == def then v = nil end
    if s.tune[key] == v then return end
    s.tune[key] = v
    if not next(s.tune) then s.tune = nil end
    for i = 1, #tuneListeners do tuneListeners[i](key) end
end
function ns.TuneGrades(key)
    return TUNE_GRADE[key] == true
end
function ns.OnTune(fn)
    tuneListeners[#tuneListeners + 1] = fn
end
function ns.TuneSig()
    local t = TuneStore()
    if not t then return "" end
    local out = ""
    for i = 1, #TUNE_ORDER do
        local k = TUNE_ORDER[i]
        local v = t[k]
        if type(v) == "number" and v ~= ns.TUNE[k] then out = out .. "|" .. k .. "=" .. tostring(v) end
    end
    return out
end
local LIMIT_MB = 250
local LIMIT_MB_KEPT = 300
local function ApplyDefaults(db)
    if type(db.settings) ~= "table" then db.settings = {} end
    if type(db.settings.ui) ~= "table" then db.settings.ui = {} end
    if db.settings.lang ~= "enUS" and db.settings.lang ~= "ruRU" then db.settings.lang = "auto" end
    if type(db.segments) ~= "table" then db.segments = {} end
    local kept = type(db.settings.limitMB) ~= "number" and #db.segments > 0
    if type(db.settings.limitMB) ~= "number" or db.settings.limitMB <= 0 then
        db.settings.limitMB = kept and LIMIT_MB_KEPT or LIMIT_MB
    end
    if kept then db.settings.limitNote = true end
    db.settings.limit, db.settings.limitTries = nil, nil
    if type(db.settings.autoRaid) ~= "boolean" then db.settings.autoRaid = true end
    if type(db.settings.autoParty) ~= "boolean" then db.settings.autoParty = false end
    if db.settings.tune ~= nil and type(db.settings.tune) ~= "table" then db.settings.tune = nil end
    if type(db.total) ~= "number" then db.total = 0 end
    if type(db.classes) ~= "table" then db.classes = {} end
    if type(db.pets) ~= "table" then db.pets = {} end
    if type(db.gpIssued) ~= "table" then db.gpIssued = {} end
    if type(db.prices) ~= "table" then db.prices = {} end
    if type(db.gp) ~= "table" then db.gp = {} end
    db.gp.preset, db.gp.own, db.gp.epgpReason = nil, nil, nil
    if type(db.gp.manual) ~= "table" then db.gp.manual = {} end
    if type(db.gp.bump) ~= "table" then db.gp.bump = {} end
    db.gp.mini = nil
    if type(db.gp.proof) ~= "string" then db.gp.proof = "RAID" end
    if type(db.gp.guild) ~= "table" then db.gp.guild = {} end
    if type(db.faults) ~= "table" then db.faults = {} end
    local fl = db.faults
    if fl.system ~= "gp" and fl.system ~= "ep" and fl.system ~= "dkp" then fl.system = "gp" end
    if type(fl.done) ~= "table" then fl.done = {} end
    if type(fl.log) ~= "table" then fl.log = {} end
    if type(fl.rules) ~= "table" then fl.rules = {} end
    if type(fl.hot) ~= "table" then fl.hot = {} end
    if db.recording ~= true then db.recording = false end
    if db.recAuto ~= 1 then
        db.recAuto = 1
        db.recording = true
        db.settings.autoRaid = true
    end
end
local function InstallWidgetFallback()
    if ns.MakeButton and ns.MakeRowButton then return end
    ns.MakeButton = ns.MakeButton or function(parent, name)
        local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate2")
        b.text = b:GetFontString()
        b:SetScript("OnClick", function(self)
            if self.onClick then self.onClick() end
        end)
        return b
    end
    ns.MakeRowButton = ns.MakeRowButton or function(parent, width)
        local r = CreateFrame("Button", nil, parent)
        r:SetWidth(width)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture(1, 1, 1, 0)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 0, 0)
        r.text:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self.onRightClick then self.onRightClick(self) end
            elseif self.onClick then
                self.onClick(self)
            end
        end)
        r:SetScript("OnEnter", function(self)
            if not self.on then self.bg:SetTexture(1, 1, 1, 0.08) end
            if not self.tipTitle and not self.tipLink then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if self.tipLink then
                GameTooltip:SetHyperlink(self.tipLink)
                GameTooltip:AddLine(" ")
            else
                GameTooltip:AddLine(self.tipTitle)
            end
            if self.tipLines then
                for i = 1, #self.tipLines do
                    GameTooltip:AddLine(self.tipLines[i], 0.75, 0.75, 0.75)
                end
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            if not self.on then self.bg:SetTexture(1, 1, 1, 0) end
            GameTooltip:Hide()
        end)
        return r
    end
    ns.widgetFallback = true
end
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        OldFolder()
        return
    end
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    if type(ManaCodeRaidHelperDB) ~= "table" then
        ManaCodeRaidHelperDB = {}
    end
    local db = ManaCodeRaidHelperDB
    local rec = ns.RecCodec and ns.RecCodec.VERSION
    local newer = rec and Newer(db, rec)
    if newer then
        recLock = "newer"
        scratch = {}
        db = scratch
    end
    ApplyDefaults(db)
    ns.ApplyLang()
    if recLock or ns.TestSet() then
        db.recording = false
        db.settings.autoRaid = false
        db.paused = nil
    end
    if rec and not recLock then db.fmt = { rec = rec, addon = AddonVersion() } end
    InstallWidgetFallback()
    for i = 1, #readyCallbacks do
        readyCallbacks[i]()
    end
    if preFrames then
        local own = setmetatable({}, { __mode = "k" })
        local f = EnumerateFrames()
        while f do
            if not preFrames[f] then own[f] = true end
            f = EnumerateFrames(f)
        end
        preFrames = nil
        ns.ownFrames = own
    end
    if newer then ns.Print(string.format(ns.T("fmt.newer"), newer, rec)) end
end)
