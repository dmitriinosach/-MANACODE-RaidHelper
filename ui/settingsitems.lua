local _, ns = ...
local format = string.format
local floor = math.floor
local concat = table.concat
local S = ns.Settings
local Kit = ns.Kit
local T = ns.T
local MB = 1048576
local function Opt()
    return ns.GetDB().settings
end
local function Secs(v)
    if v == floor(v) then return format(T("set.unit.sec"), v) end
    return format(T("set.unit.sec1"), ns.Fixed(v))
end
local function Pct(v)
    return format("%d%%", v)
end
local function Percent(v)
    return floor(v * 100 + 0.5)
end
local function RefreshViews()
    local SV = ns.SummaryView
    local f = SV and SV.Fight and SV.Fight()
    if f then SV.Show(f) end
    local RV = ns.RaidSummaryView
    if RV and RV.IsShown and RV.IsShown() then RV.Refresh() end
end
local function Retune(key)
    if ns.TuneGrades(key) then
        if ns.Digest then ns.Digest.Forget() end
        if ns.Summary then ns.Summary.Reset() end
        if ns.RaidSummary then ns.RaidSummary.Reset() end
    elseif key == "preview" and ns.DeathPreview then
        ns.DeathPreview.Reset()
    end
    RefreshViews()
end
ns.OnTune(Retune)
local function Keys(list, prefix)
    local out = {}
    for i = 1, #list do out[i] = { key = list[i], label = prefix .. list[i] } end
    return out
end
local function Themes()
    local out = {}
    for i = 1, #Kit.order do
        local key = Kit.order[i]
        out[i] = { key = key, label = Kit.Get(key).labelKey }
    end
    return out
end
local function Langs()
    local out = {}
    local keys = { "auto", "enUS", "ruRU" }
    for i = 1, #keys do
        out[i] = { key = keys[i], label = "set.lang." .. keys[i], tip = "set.lang.tip" }
    end
    return out
end
S.Section("look", "lang", {
    label = "set.lang",
    order = 5,
    items = {
        { kind = "choice", key = "lang", buttons = true, label = "set.lang.pick", options = Langs, default = "auto",
          get = function() return ns.LangSetting() end,
          set = function(k) ns.SetLangSetting(k) end },
    },
})
S.Section("look", "theme", {
    label = "set.theme",
    order = 10,
    items = {
        { kind = "choice", key = "theme", buttons = true, label = "set.theme.pick", options = Themes, default = "dark",
          get = Kit.Key, set = function(k) Kit.SetTheme(k) end },
    },
})
S.Section("look", "window", {
    label = "set.window",
    order = 20,
    items = {
        { kind = "slider", key = "scale", label = "set.window.scale", tip = "set.window.scale.tip",
          min = 70, max = 130, step = 5, fmt = Pct, default = 100,
          get = function() return Percent((ns.Shell.Scale())) end,
          set = function(v) ns.Shell.SetScale(v / 100) end },
        { kind = "slider", key = "font", label = "set.window.font", tip = "set.window.font.tip",
          min = select(2, Kit.FontDelta()), max = select(3, Kit.FontDelta()), step = 1, default = 0,
          fmt = function(v) return format(T("set.unit.pt"), v > 0 and ("+" .. v) or tostring(v)) end,
          get = function() return (Kit.FontDelta()) end,
          set = function(v) Kit.SetFontDelta(v) end },
        { kind = "choice", key = "face", label = "set.window.face", tip = "set.window.face.tip",
          default = "client",
          options = function() return Keys(Kit.FontFaces(), "set.window.face.") end,
          get = Kit.FontFace, set = function(k) Kit.SetFontFace(k) end },
    },
})
S.Section("panel", "panel", {
    label = "set.panel",
    order = 10,
    items = {
        { kind = "choice", key = "when", label = "set.panel.when", tip = "set.panel.when.tip", default = "always",
          options = function() return Keys(ns.Panel.WHENS, "set.panel.when.") end,
          get = function() return ns.Panel.When() end,
          set = function(k) ns.Panel.SetWhen(k) end },
        { kind = "check", key = "lock", label = "set.panel.lock", tip = "panel.lock.tip", default = false,
          get = function() return ns.Panel.IsLocked() end,
          set = function(on) ns.Panel.SetLocked(on) end },
        { kind = "slider", key = "scale", label = "set.panel.scale", tip = "set.panel.scale.tip",
          min = 60, max = 150, step = 5, fmt = Pct, default = 100,
          get = function() return Percent((ns.Panel.Scale())) end,
          set = function(v) ns.Panel.SetScale(v / 100) end },
        { kind = "check", key = "compact", label = "panel.compact", tip = "panel.compact.tip", default = false,
          get = function() return ns.Panel.Compact() end,
          set = function(on) ns.Panel.SetCompact(on) end },
    },
})
local function RecState()
    local lock = ns.RecLock()
    if lock then return T("rec.lock." .. lock) end
    local key = "set.rec.off"
    if ns.Recorder.IsOn() then key = ns.Recorder.IsPaused() and "set.rec.paused" or "set.rec.on" end
    return T(key)
end
local function RecUsed()
    local _, _, bytes = ns.Store.Stats()
    local raids, tries = ns.Store.Count()
    local key = ns.Store.OverLimit() and "set.rec.used.over" or "set.rec.used"
    return format(T(key), bytes / MB, ns.Store.Limit(), raids, tries)
end
local function SetRec(key, on)
    if key == "autoRaid" and on and ns.RecLock() then
        ns.Print(T("rec.lock." .. ns.RecLock()))
        return
    end
    Opt()[key] = on
    if key == "autoRaid" then
        if on then ns.Recorder.Start() else ns.Recorder.Stop() end
    elseif key == "recAll" then
        ns.Recorder.SetAll(on)
    end
    if ns.AutoRec and ns.AutoRec.Refresh then ns.AutoRec.Refresh() end
end
S.Section("rec", "status", {
    label = "set.rec.status",
    order = 10,
    items = {
        { kind = "text", key = "state", tick = true, text = RecState,
          token = function() return ns.RecLock() and "text.warn" or "text.primary" end },
    },
})
S.Section("rec", "what", {
    label = "set.rec.what",
    order = 20,
    items = {
        { kind = "check", key = "raid", label = "set.rec.raid", tip = "set.rec.raid.tip",
          enabled = function() return not ns.RecLock() end,
          get = function() return Opt().autoRaid end, set = function(on) SetRec("autoRaid", on) end },
        { kind = "check", key = "all", label = "set.rec.all", tip = "set.rec.all.tip",
          get = function() return Opt().recAll == true end, set = function(on) SetRec("recAll", on) end },
        { kind = "choice", key = "mana", buttons = true, label = "set.rec.mana", tip = "set.rec.mana.tip",
          default = "heal", options = function() return Keys(ns.RecMana.MODES, "set.rec.mana.") end,
          get = function() return ns.RecMana.Mode() end, set = function(k) ns.RecMana.SetMode(k) end },
    },
})
local BOSS_COLS = 2
local BOSS_COL_W = 250
local BOSS_ROW = 24
local BOSS_CAP = 20
local function BossSizes()
    return Kit.GrowH(BOSS_CAP, "GameFontNormal"), Kit.GrowH(BOSS_ROW, "GameFontNormalSmall"),
        floor(BOSS_COL_W * Kit.FontScale("GameFontNormalSmall", true) + 0.5)
end
local function BuildBosses(r, it)
    r.cap = Kit.Str(r, "GameFontNormal")
    r.cap:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -2)
    Kit.Text(r.cap, "text.secondary")
    r.checks = {}
    r.Place = function()
        local cap, rowH, colW = BossSizes()
        for i = 1, #it.list do
            local col, row = (i - 1) % BOSS_COLS, floor((i - 1) / BOSS_COLS)
            local c = r.checks[i]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", r, "TOPLEFT", col * colW - 2, -(cap + row * rowH))
        end
    end
    for i = 1, #it.list do
        local enc = it.list[i]
        local c = Kit.Check(r)
        c.tipTitle = false
        c.onToggle = function(on)
            ns.RecFilter.SetBoss(enc, on)
            S.Refresh()
        end
        r.checks[i] = c
    end
end
local function RefreshBosses(r, it)
    r.cap:SetText(T("zone." .. it.map))
    for i = 1, #it.list do
        local c, enc = r.checks[i], it.list[i]
        c.label:SetText(ns.EncName(enc))
        c.tip = T("set.rec.boss.tip")
        c:SetChecked(ns.RecFilter.BossOn(enc))
    end
end
local function BossItems()
    local out = {
        { kind = "text", key = "hint", text = "set.rec.bosses.hint", token = "text.secondary", order = 1 },
    }
    local raids = ns.raidBosses or {}
    for i = 1, #raids do
        local r = raids[i]
        out[#out + 1] = { kind = "custom", key = r.map, map = r.map, list = r.list, order = 10 + i,
            height = function()
                local cap, rowH = BossSizes()
                return cap + math.ceil(#r.list / BOSS_COLS) * rowH + 4
            end,
            build = BuildBosses, refresh = RefreshBosses }
    end
    return out
end
S.Section("rec", "bosses", {
    label = "set.rec.bosses",
    order = 25,
    items = BossItems(),
})
local mbLo, mbHi, mbDef = ns.Store.LimitRange()
local function LimitAsk(mb)
    if not ns.Store.Cuts(mb) then return nil end
    local raids = ns.Store.Preview(mb)
    if not raids[1] then return T("set.rec.ask.none") end
    return format(T("set.rec.ask"), concat(raids, ", "))
end
S.Section("rec", "store", {
    label = "set.rec.store",
    order = 30,
    items = {
        { kind = "check", key = "party", label = "set.rec.party", tip = "set.rec.party.tip", order = -2,
          get = function() return Opt().autoParty == true end, set = function(on) SetRec("autoParty", on) end },
        { kind = "check", key = "dummy", label = "set.rec.dummy", tip = "set.rec.dummy.tip", order = -1,
          get = function() return ns.Encounters.Dummy() end, set = function(on) ns.Recorder.SetDummy(on) end },
        { kind = "text", key = "used", tick = true, text = RecUsed,
          token = function() return ns.Store.OverLimit() and "text.bad" or "text.primary" end },
        { kind = "slider", key = "mb", label = "set.rec.limit", tip = "set.rec.limit.tip",
          min = mbLo, max = mbHi, step = 10, default = mbDef,
          get = function() return ns.Store.Limit() end,
          ask = LimitAsk,
          set = function(v) ns.Store.SetLimit(v) end },
        { kind = "button", key = "clear", label = "set.rec.clear", confirm = "set.rec.clear.ask",
          tip = "set.rec.clear.tip", danger = true, order = 100,
          run = function()
              ns.Store.Clear()
              ns.Print(T("slash.clear.done"))
          end },
    },
})
local function Tuner(key, label, lo, hi, step, fmt, order)
    return { kind = "slider", key = key, label = label, tip = label .. ".tip", warn = "set.grade.warn",
             min = lo, max = hi, step = step, fmt = fmt, default = ns.TUNE[key], order = order,
             get = function() return ns.Tune(key) end,
             set = function(v) ns.SetTune(key, v) end }
end
local function Deaths(v)
    return format(ns.Plural(v, T("set.unit.deaths")), v)
end
S.Section("parse", "grade", {
    label = "set.grade",
    order = 10,
    advanced = true,
    items = {
        { kind = "text", key = "warn", text = "set.grade.warn", token = "text.warn", order = 0 },
        Tuner("react", "set.grade.react", 1, 6, 0.5, Secs, 10),
        Tuner("tail", "set.grade.tail", 20, 80, 5, Pct, 20),
        Tuner("waveMin", "set.grade.waveMin", 3, 10, 1, Deaths, 30),
        Tuner("waveStep", "set.grade.waveStep", 0.5, 3, 0.5, Secs, 40),
        Tuner("rebuff", "set.grade.rebuff", 30, 180, 10, Secs, 50),
        Tuner("expectGood", "set.grade.good", 80, 120, 5, Pct, 60),
        Tuner("expectFair", "set.grade.fair", 50, 100, 5, Pct, 70),
        Tuner("preview", "set.grade.preview", 5, 15, 1, Secs, 80),
    },
})
S.Section("parse", "jobs", {
    label = "set.parse.jobs",
    order = 20,
    advanced = true,
    items = {
        { kind = "choice", key = "speed", buttons = true, label = "set.parse.speed", tip = "set.parse.speed.tip",
          default = "normal", options = function() return Keys(ns.Jobs.SPEEDS, "set.parse.speed.") end,
          get = function() return ns.Jobs.Speed() end, set = function(k) ns.Jobs.SetSpeed(k) end },
    },
})
local function PresetNow()
    local L = ns.Ledger
    if not L then return "" end
    return format(T("set.gp.preset.now"), L.Label())
end
local function Channels()
    local out = {}
    local list = ns.Proof and ns.Proof.CHANNELS or {}
    for i = 1, #list do out[i] = { key = list[i], label = function() return ns.Proof.Label(list[i]) end } end
    return out
end
S.Section("gp", "preset", {
    label = "set.gp.preset",
    order = 10,
    items = {
        { kind = "text", key = "now", text = PresetNow, token = "text.primary" },
        { kind = "button", key = "edit", label = "set.gp.edit", tip = "set.gp.edit.tip",
          run = function() if ns.FaultsPage then ns.FaultsPage.Open("rules") else ns.Shell.Open("gp") end end },
    },
})
S.Section("gp", "signal", {
    label = "set.gp.signal",
    order = 30,
    items = {
        { kind = "text", key = "who", text = "set.gp.signal.text", token = "text.secondary" },
    },
})
S.Section("gp", "proof", {
    label = "set.gp.proof",
    order = 20,
    items = {
        { kind = "choice", key = "channel", label = "set.gp.channel", tip = "proof.set.tip", options = Channels,
          get = function() return ns.Proof.Channel() end,
          set = function(k)
              ns.Proof.SetChannel(k)
              if ns.ProofView and ns.ProofView.Repaint then ns.ProofView.Repaint() end
          end },
    },
})
local function PauseText()
    local R = ns.Recorder
    return T((R and R.IsOn() and R.IsPaused()) and "set.svc.resume" or "set.svc.pause")
end
local function CpuText()
    local C = ns.CpuMeter
    return T((C and C.Wanted()) and "set.svc.cpu.off" or "set.svc.cpu.on")
end
local function AdvText()
    return T(S.Advanced() and "set.svc.adv.hide" or "set.svc.adv.show")
end
S.Section("svc", "tools", {
    label = "set.svc.tools",
    order = 10,
    items = {
        { kind = "button", key = "adv", text = AdvText, tip = "set.svc.adv.tip",
          run = function() S.SetAdvanced(not S.Advanced()) end },
        { kind = "button", key = "pause", text = PauseText, tip = "set.svc.pause.tip",
          tick = true, enabled = function() return ns.Recorder.IsOn() end,
          run = function() ns.Slash.Pause() end },
        { kind = "button", key = "rescan", text = "set.svc.rescan",
          tip = "set.svc.rescan.tip", confirm = "set.rec.clear.ask", run = function() ns.Slash.Rescan() end },
        { kind = "button", key = "merge", text = "set.svc.merge",
          tip = "set.svc.merge.tip", run = function() ns.Slash.Merge() end },
        { kind = "button", key = "diag", text = "set.svc.diag",
          tip = "set.svc.diag.tip", run = function() ns.Slash.Diag() end },
        { kind = "button", key = "prof", text = "set.svc.prof",
          tip = "set.svc.prof.tip", run = function() ns.Slash.Prof() end },
        { kind = "button", key = "cpu", text = CpuText, tip = "set.svc.cpu.tip", tick = true,
          shown = function() return ns.CpuMeter ~= nil end,
          run = function()
              local out = ns.CpuMeter.Set(not ns.CpuMeter.Wanted())
              for i = 1, #out do ns.Print(out[i]) end
          end },
        { kind = "button", key = "test", text = "set.svc.test", tip = "set.svc.test.tip",
          confirm = "set.rec.clear.ask", tick = true,
          shown = function() return ns.RecLock() == "test" end,
          run = function()
              if ns.LeaveTest() then S.Refresh() end
          end },
    },
})
S.Section("svc", "version", {
    label = "set.svc.version",
    order = 20,
    items = {
        { kind = "check", key = "note", label = "set.svc.vernote", tip = "set.svc.vernote.tip", default = true,
          get = function() return Opt().verNote ~= false end, set = function(on) Opt().verNote = on and true or false end },
    },
})
ns.Shell.Command("adv", function()
    local on = not S.Advanced()
    S.SetAdvanced(on)
    ns.Print(T(on and "set.adv.on" or "set.adv.off"))
end, function() return T("cmd.adv") end)
ns.Shell.Command("theme", function(arg)
    local key = arg:match("^(%S*)")
    if Kit.SetTheme(key) then
        ns.Print(format(T("theme.set"), T(Kit.Get(key).labelKey)))
    else
        ns.Print(format(T("theme.unknown"), concat(Kit.order, ", ")))
    end
end, function() return T("cmd.theme") end)
S.itemsLoaded = true
