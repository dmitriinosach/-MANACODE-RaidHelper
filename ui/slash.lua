local _, ns = ...
local format = string.format
local CLEAR_WINDOW = 10
local TABS = {
    log = "log", ["разбор"] = "log",
    gp = "gp", ["гп"] = "gp",
    spam = "spam",
    tpl = "tpl",
    board = "board",
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
function Slash.Ranging()
    if not ns.Ranging then return end
    local st = ns.Ranging.Status()
    local s = st.session
    if st.broken then
        ns.Print(format(ns.T("rng.status.broken"), st.broken))
    elseif not st.on then
        ns.Print(ns.T("rng.status.off"))
    elseif not s then
        ns.Print(format(ns.T("rng.status.idle"), st.sent, st.got))
    elseif not s.decided then
        local heard = 0
        for _ in pairs(s.peers) do heard = heard + 1 end
        ns.Print(format(ns.T("rng.status.wait"), s.enc, heard))
    elseif not s.active then
        ns.Print(format(ns.T("rng.status.below"), s.enc, s.count, ns.Ranging.MinClients()))
    else
        local me = s.lowFps and "rng.status.lowfps" or (s.me and "rng.status.me" or "rng.status.notme")
        ns.Print(format(ns.T("rng.status.run"), s.enc, s.count, math.min(s.count, ns.Ranging.MEASURERS), ns.T(me),
            s.sent, s.got))
    end
    local last = st.last
    if last.why and last.at then
        ns.Print(format(ns.T("rng.status.last"), date("%H:%M:%S", last.at), ns.T("rng.why." .. last.why)))
    end
    if st.foreign > 0 then ns.Print(format(ns.T("rng.status.foreign"), st.foreign)) end
end
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
        { "ui/prof.lua", ns.ProfView },
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
        { "ui/gpmini.lua", ns.GPMini },
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
    Slash.Ranging()
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
            local far = rest:match("^fog%s+([%d%.]+)$")
            local camera = rest:match("^cam%s*(%-?%d*)$")
            local mpos = rest:match("^mpos%s*(.-)$")
            local mfit = rest:match("^mfit%s+([%d%.]+)$")
            if ns.ReplayIso then ns.ReplayIso.dev = true end
            if not ns.ReplayIso then
                ns.Print(ns.T("slash.diag.restart"))
            elseif far then
                ns.ReplayIso.SetFog(tonumber(far) or 0)
            elseif mfit then
                ns.ReplayModels.SetFit(tonumber(mfit) or 1)
                ns.Print(format(ns.T("iso.mfit"), ns.ReplayModels.fit))
            elseif mpos then
                local x, y, z = mpos:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
                ns.ReplayModels.SetPos(tonumber(x), tonumber(y), tonumber(z))
                ns.Print(x and format(ns.T("iso.mpos"), tonumber(x), tonumber(y), tonumber(z)) or ns.T("iso.mpos.off"))
            elseif rest == "flip" then
                ns.ReplayIso.FlipFace()
            elseif rest == "geo" then
                ns.ReplayIso.SetGeo(not ns.ReplayGeo.on)
            elseif camera then
                local index = tonumber(camera)
                ns.ReplayIso.SetCamera(index and index >= 0 and index or nil)
            else
                ns.ReplayIso.Toggle()
            end
        elseif arg == "ask" then
            ns.AutoRec.DevAsk()
        elseif arg == "lich" then
            ns.AutoRec.DevLich(false)
        elseif arg == "movie" then
            ns.AutoRec.DevLich(true)
        elseif arg == "state" then
            ns.AutoRec.DevState()
        elseif arg == "lock" then
            ns.Raid.DevLock()
        else
            ns.Print(ns.T("dev.help"))
        end
    elseif cmd == "rescan" or cmd == "пересобрать" then
        Slash.Rescan()
    elseif cmd == "prof" or cmd == "замер" then
        Slash.Prof()
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
        local tries, mb = ns.Store.Limits()
        if not ns.Recorder.IsOn() then
            ns.Print(ns.T("slash.status.off"))
        elseif ns.Recorder.IsPaused() then
            ns.Print(ns.T("panel.rec.paused"))
        else
            ns.Print(ns.T("slash.status.on"))
        end
        ns.Print(format(ns.T("slash.status.body"),
            segs, events, bytes / 1048576,
            format(ns.T("slash.status.limit"), tries, mb)))
        local why, enc, at = ns.Recorder.LastClose()
        if why then
            ns.Print(format(ns.T("slash.status.closed"), date("%H:%M:%S", at),
                format(ns.T("rec.close." .. why), enc or "")))
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
