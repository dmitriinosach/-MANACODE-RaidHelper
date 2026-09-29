local ADDON, ns = ...
ns.L = {}
ns.Prof = { on = false, rows = {} }
function ns.Prof.Add(key, ms, items)
    local r = ns.Prof.rows[key]
    if not r then
        r = { n = 0, ms = 0, last = 0, max = 0, items = 0 }
        ns.Prof.rows[key] = r
    end
    r.n = r.n + 1
    r.ms = r.ms + ms
    r.last = ms
    if ms > r.max then r.max = ms end
    r.items = r.items + (items or 0)
end
function ns.Prof.Reset()
    wipe(ns.Prof.rows)
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
    local done = job.done
    for i = 1, #done do
        if ok then done[i](...) else done[i](nil) end
    end
end
jobFrame:SetScript("OnUpdate", function(self)
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
end)
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
local AVG_LINE = 56
local LIMIT_MB = 300
local LIMIT_TRIES = 50
local LIMIT_MB_KEPT = 500
local LIMIT_TRIES_KEPT = 100
local function LimitToMB(db, limit)
    if type(limit) ~= "number" or limit <= 0 or limit == 500000 then return 0 end
    local events, bytes = 0, 0
    for i = 1, #db.segments do
        local seg = db.segments[i]
        events = events + (tonumber(seg.n) or 0)
        bytes = bytes + (tonumber(seg.bytes) or 0)
    end
    local avg = (events > 0 and bytes > 0) and bytes / events or AVG_LINE
    return math.ceil(limit * avg / 1048576)
end
local function ApplyDefaults(db)
    if type(db.settings) ~= "table" then db.settings = {} end
    if type(db.settings.ui) ~= "table" then db.settings.ui = {} end
    if type(db.segments) ~= "table" then db.segments = {} end
    local kept = type(db.settings.limitTries) ~= "number" and #db.segments > 0
    if type(db.settings.limitMB) ~= "number" then
        db.settings.limitMB = LimitToMB(db, db.settings.limit)
    end
    if db.settings.limitMB <= 0 then db.settings.limitMB = kept and LIMIT_MB_KEPT or LIMIT_MB end
    if type(db.settings.limitTries) ~= "number" then
        db.settings.limitTries = kept and LIMIT_TRIES_KEPT or LIMIT_TRIES
    end
    if kept then db.settings.limitNote = true end
    db.settings.limit = nil
    if type(db.settings.autoRaid) ~= "boolean" then db.settings.autoRaid = true end
    if type(db.settings.autoParty) ~= "boolean" then db.settings.autoParty = false end
    if db.settings.tune ~= nil and type(db.settings.tune) ~= "table" then db.settings.tune = nil end
    if type(db.total) ~= "number" then db.total = 0 end
    if type(db.classes) ~= "table" then db.classes = {} end
    if type(db.pets) ~= "table" then db.pets = {} end
    if type(db.gpIssued) ~= "table" then db.gpIssued = {} end
    if type(db.prices) ~= "table" then db.prices = {} end
    if type(db.gp) ~= "table" then db.gp = {} end
    if type(db.gp.preset) ~= "string" then db.gp.preset = "spartans" end
    if type(db.gp.own) ~= "table" then db.gp.own = {} end
    if type(db.gp.manual) ~= "table" then db.gp.manual = {} end
    if type(db.gp.bump) ~= "table" then db.gp.bump = {} end
    if type(db.gp.mini) ~= "boolean" then db.gp.mini = false end
    if type(db.gp.proof) ~= "string" then db.gp.proof = "RAID" end
    if type(db.gp.guild) ~= "table" then db.gp.guild = {} end
    if db.gp.epgpReason ~= nil and type(db.gp.epgpReason) ~= "string" then db.gp.epgpReason = nil end
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
    if newer then ns.Print(string.format(ns.T("fmt.newer"), newer, rec)) end
end)
