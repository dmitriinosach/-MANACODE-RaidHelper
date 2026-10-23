local _, ns = ...
local format = string.format
local CLEAR_WINDOW = 10
local TABS = {
    log = "log", ["разбор"] = "log",
    gp = "gp", ["гп"] = "gp",
    spam = "spam",
    tpl = "tpl",
    raid = "raid",
}
local clearAskedAt = 0
local function Help()
    ns.Print(ns.T("slash.help"))
    local extra = ns.Shell.CommandHelp()
    for i = 1, #extra do
        ns.Print(extra[i])
    end
end
local Slash = {}
ns.Slash = Slash
function Slash.Diag()
    local parts = {
        { "core/store.lua", ns.Store },
        { "core/recorder.lua", ns.Recorder },
        { "core/meter.lua", ns.Meter },
        { "core/effects.lua", ns.Effects },
        { "core/encounters.lua", ns.Encounters },
        { "core/index.lua", ns.Index },
        { "core/autorec.lua", ns.AutoRec },
        { "data/effect_defaults.lua", ns.effectDefaults },
        { "ui/kit/*.lua", ns.Kit and ns.Kit.Icon },
        { "ui/widgets.lua", ns.widgetsLoaded },
        { "ui/shell.lua", ns.Shell },
        { "ui/effects.lua", ns.EffectPanel },
        { "core/fighttree.lua", ns.FightTree },
        { "ui/fightlist.lua", ns.FightList },
        { "ui/jobbar.lua", ns.JobBar },
        { "ui/timeline.lua", ns.Timeline },
        { "ui/timelinelinks.lua", ns.TimelineLinks },
        { "core/raid.lua", ns.Raid },
        { "ui/kit/slider.lua", ns.Kit and ns.Kit.Slider },
        { "ui/settings.lua", ns.Settings },
        { "ui/settingsitems.lua", ns.Settings and ns.Settings.itemsLoaded },
        { "ui/panel.lua", ns.Panel },
        { "ui/panelwidgets.lua", ns.Panel and ns.Panel.Get and ns.Panel.Get("count") },
        { "ui/panelrows.lua", ns.PanelRows },
        { "ui/prof.lua", ns.ProfView },
        { "core/cpumeter.lua", ns.CpuMeter },
        { "core/summary.lua", ns.Summary },
        { "ui/badges.lua", ns.Badges },
        { "ui/summary.lua", ns.SummaryView },
        { "data/summaries.lua", ns.summaries },
        { "data/bosses/icc/*.lua", ns.summaries and ns.summaries[ns.ENC.lichking] },
        { "data/penalties.lua", ns.penaltyPresets },
        { "core/penalties.lua", ns.Penalties },
        { "core/comm.lua", ns.Comm },
        { "core/gpguild.lua", ns.GPGuild },
        { "ui/gpsettings.lua", ns.GPSettings },
        { "ui/gplist.lua", ns.GPList },
        { "ui/gpsignal.lua", ns.GPSignal },
        { "core/proof.lua", ns.Proof },
        { "ui/proof.lua", ns.ProofView },
        { "core/replay.lua", ns.Replay },
        { "ui/replayfollow.lua", ns.ReplayFollow },
        { "ui/replayiso.lua", ns.ReplayIso },
        { "ui/devtool.lua", ns.DevTool },
        { "core/bober.lua", ns.Bober },
        { "core/expect.lua", ns.Expect },
        { "ui/expect.lua", ns.ExpectView },
    }
    local missing = 0
    for i = 1, #parts do
        local ok = parts[i][2] ~= nil
        if not ok then missing = missing + 1 end
        ns.Print(format("%s %s", ok and (ns.Kit.Hex("sem.win") .. ns.T("slash.diag.loaded") .. "|r") or (ns.Kit.Hex("sem.wipe") .. ns.T("slash.diag.missing") .. "|r"), parts[i][1]))
    end
    if ns.Panel and not ns.Panel.IsEnabled() then
        ns.Print(ns.T("slash.diag.panelhidden"))
    end
    if ns.Bober then ns.Print(ns.Bober.Diag()) end
    if ns.widgetFallback then
        ns.Print(ns.T("slash.diag.fallback"))
    end
    if missing > 0 then
        ns.Print(ns.T("slash.diag.restart"))
    else
        local shown, trashed = ns.Effects.Counts()
        ns.Print(format(ns.T("slash.diag.ok"), shown, trashed))
    end
end
function Slash.Rescan()
    if ns.Encounters.ResetCache() then
        if ns.Summary then ns.Summary.Reset() end
        if ns.Digest then ns.Digest.Clear() end
        if ns.RaidSummary then ns.RaidSummary.Reset() end
        if ns.Timeline and ns.Timeline.Hide then ns.Timeline.Hide() end
        ns.Print(ns.T("slash.rescan.done"))
    else
        ns.Print(ns.T("slash.rescan.busy"))
    end
end
function Slash.Prof()
    if ns.ProfView then
        ns.ProfView.Toggle()
    else
        ns.Print(ns.T("slash.diag.restart"))
    end
end
function Slash.Cpu(arg)
    local C = ns.CpuMeter
    if not C then
        ns.Print(ns.T("slash.diag.restart"))
        return
    end
    local out
    if arg == "on" or arg == "вкл" then
        out = C.Set(true)
    elseif arg == "off" or arg == "выкл" then
        out = C.Set(false)
    else
        out = C.Report()
    end
    for i = 1, #out do ns.Print(out[i]) end
    return out
end
function Slash.Merge()
    local merged, skipped = ns.Effects.MergeVariants()
    ns.Print(format(ns.T("slash.merge.done"), merged))
    if #skipped > 0 then
        ns.Print(format(ns.T("slash.merge.skip"), table.concat(skipped, ", ")))
    end
    if ns.Timeline and ns.Timeline.Redraw then ns.Timeline.Redraw() end
    if ns.EffectPanel and ns.EffectPanel.Refresh then ns.EffectPanel.Refresh() end
end
function Slash.Pause()
    if not ns.Recorder.IsOn() then
        ns.Print(ns.T("slash.already_off"))
    elseif ns.Recorder.IsPaused() then
        ns.Recorder.Resume("hand")
    else
        ns.Recorder.Pause()
        ns.Print(ns.T("rec.paused"))
    end
end
local function Handler(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd or ""
    if cmd == "" then
        ns.Shell.Toggle()
    elseif TABS[cmd] then
        ns.Shell.Open(TABS[cmd])
    elseif cmd == "panel" or cmd == "панель" then
        ns.Shell.TogglePanel()
    elseif cmd == "help" then
        Help()
    elseif cmd == "diag" then
        Slash.Diag()
    elseif cmd == "dev" then
        local rest
        arg, rest = arg:match("^(%S*)%s*(.-)$")
        if arg == "" then
            if ns.DevTool then ns.DevTool.Toggle() else ns.Print(ns.T("slash.diag.restart")) end
        elseif arg == "check" then
            ns.AutoRec.DevState()
        elseif arg == "iso" then
            if ns.ReplayIso then ns.ReplayIso.dev = true end
            if not ns.ReplayIso then
                ns.Print(ns.T("slash.diag.restart"))
            elseif rest == "geo" then
                ns.ReplayIso.SetGeo(not ns.ReplayGeo.on)
            else
                ns.ReplayIso.Toggle()
            end
        elseif arg == "ask" then
            ns.AutoRec.DevAsk()
        elseif arg == "lich" then
            ns.AutoRec.DevLich(false)
        elseif arg == "movie" then
            ns.AutoRec.DevLich(true)
        elseif arg == "lock" then
            ns.Raid.DevLock()
        elseif arg == "ver" then
            if ns.VerToast then ns.VerToast.Demo() else ns.Print(ns.T("slash.diag.restart")) end
        else
            ns.Print(ns.T("dev.help"))
        end
    elseif cmd == "rescan" or cmd == "пересобрать" then
        Slash.Rescan()
    elseif cmd == "prof" or cmd == "замер" then
        Slash.Prof()
    elseif cmd == "cpu" or cmd == "цп" then
        Slash.Cpu(arg)
    elseif cmd == "merge" or cmd == "свести" then
        Slash.Merge()
    elseif cmd == "on" then
        if ns.Recorder.IsOn() then
            ns.Print(ns.T("slash.already_on"))
            return
        end
        if ns.RecLock() then
            ns.Print(ns.T("rec.lock." .. ns.RecLock()))
            return
        end
        ns.Recorder.Start()
        if ns.Recorder.IsOn() then
            ns.Print(ns.T("slash.on"))
        end
    elseif cmd == "off" then
        if not ns.Recorder.IsOn() then
            ns.Print(ns.T("slash.already_off"))
            return
        end
        ns.Recorder.Stop()
        ns.Print(ns.T("slash.off"))
    elseif cmd == "all" or cmd == "всё" then
        local on = not (ns.GetDB().settings.recAll == true)
        ns.Recorder.SetAll(on)
        ns.Print(ns.T(on and "slash.all.on" or "slash.all.off"))
    elseif cmd == "pause" or cmd == "пауза" then
        Slash.Pause()
    elseif cmd == "status" then
        local segs, events, bytes = ns.Store.Stats()
        if not ns.Recorder.IsOn() then
            ns.Print(ns.T("slash.status.off"))
        elseif ns.Recorder.IsPaused() then
            ns.Print(ns.T("panel.rec.paused"))
        else
            ns.Print(ns.T("slash.status.on"))
        end
        ns.Print(format(ns.T("slash.status.body"),
            segs, events, ns.Fixed(bytes / 1048576),
            format(ns.T("slash.status.limit"), ns.Store.Limit())))
        local why, enc, at = ns.Recorder.LastClose()
        if why then
            ns.Print(format(ns.T("slash.status.closed"), date("%H:%M:%S", at),
                format(ns.T("rec.close." .. why), ns.EncName(enc))))
        else
            ns.Print(ns.T("slash.status.noclose"))
        end
        if ns.Version then ns.Print(ns.Version.StatusLine()) end
    elseif cmd == "clear" then
        if GetTime() - clearAskedAt <= CLEAR_WINDOW then
            clearAskedAt = 0
            ns.Store.Clear()
            ns.Print(ns.T("slash.clear.done"))
        else
            clearAskedAt = GetTime()
            ns.Print(ns.T("slash.clear.ask"))
        end
    elseif not ns.Shell.RunCommand(cmd, arg) then
        Help()
    end
end
SLASH_MANACODERAIDHELPER1 = "/mrh"
SlashCmdList["MANACODERAIDHELPER"] = Handler
