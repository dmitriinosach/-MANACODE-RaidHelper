local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local R = {}
ns.RaidCmd = R
local DIFFS = { 1, 2, 3, 4 }
function R.Officer()
    local raid = ns.Compat.GroupSize()
    return raid > 0 and (IsRaidLeader() or IsRaidOfficer()) and true or false
end
function R.Leader()
    local raid, party = ns.Compat.GroupSize()
    if raid > 0 then return IsRaidLeader() and true or false end
    if party > 0 then return IsPartyLeader() and true or false end
    return true
end
function R.Ready()
    if not R.Officer() then return false end
    DoReadyCheck()
    return true
end
function R.ReadyAndOpen()
    if not R.Ready() then return false end
    ns.Compat.OpenRaidFrame()
    return true
end
function R.SetDifficulty(n)
    if not R.Leader() or ns.Compat.InInstance() then return false end
    return ns.Compat.SetRaidDifficulty(n)
end
local function officerState()
    if R.Officer() then return true end
    return false, ns.T("tipNeedOfficer")
end
local function timerState()
    if not ns.Timers.HasDBM() then return false, ns.T("tipNeedDbm") end
    return officerState()
end
local function marksState()
    if ns.Marks.CanMark() then return true end
    return false, ns.T("tipNeedOfficer")
end
local function timerItem(t)
    local d = ns.Timers.Duration(t.sec)
    local pull = t.kind == "pull"
    return {
        label = d,
        title = ns.T(pull and "tipPull" or "tipBreak", d),
        tip = ns.T(pull and "actPullTip" or "actBreakTip"),
        state = timerState,
        run = function() ns.Timers.Run(t) end,
    }
end
local function diffItem(n)
    return {
        label = ns.T("actDiff" .. n),
        title = ns.T("actDiffTitle" .. n),
        tip = ns.T("actDiffTip"),
        state = function()
            local on = ns.Compat.RaidDifficulty() == n
            if not R.Leader() then return false, ns.T("tipNeedLeader"), on end
            if ns.Compat.InInstance() then return false, ns.T("actDiffInside"), on end
            return true, nil, on
        end,
        run = function() R.SetDifficulty(n) end,
    }
end
local function openMarks()
    ns.Marks.SetOpen(true)
    if root.Shell and root.Shell.Open then root.Shell.Open("raid") end
end
local markItems
local function marksRow()
    if not markItems then
        markItems = { {
            check = true,
            label = "", title = "", tip = "",
            state = function() return true, nil, ns.Marks.Enabled() end,
            run = function() ns.Marks.SetEnabled(not ns.Marks.Enabled()) end,
        } }
        for i = 1, ns.Marks.COUNT do
            markItems[#markItems + 1] = {
                label = "", title = "",
                icon = function(tex) ns.Icon.Mark(tex, i) end,
                tip = function() return ns.Marks.Describe(i) end,
                state = function()
                    local e = ns.Marks.View(i)
                    local on = e and e.owner and e.now and true or false
                    if not ns.Marks.CanMark() then return false, ns.T("tipNeedOfficer"), on end
                    return true, nil, on
                end,
                run = function() if ns.Marks.Target(i) == "none" then openMarks() end end,
                alt = function() ns.Marks.Release(i) end,
            }
        end
    end
    local keep = markItems[1]
    keep.label, keep.title, keep.tip = ns.T("marksKeep"), ns.T("marksKeepTitle"), ns.T("tipMarksKeep")
    for i = 1, ns.Marks.COUNT do
        local it = markItems[i + 1]
        it.title, it.hint = ns.T("mark" .. i), ns.T("marksTipHow")
    end
    return { title = ns.T("actMarksRow"), items = markItems, status = ns.Marks.Status }
end
function R.Rows()
    local breaks, pulls = {}, {}
    for _, t in ipairs(ns.Timers.List()) do
        local list = t.kind == "pull" and pulls or breaks
        list[#list + 1] = timerItem(t)
    end
    pulls[#pulls + 1] = {
        label = ns.T("actCancel"),
        title = ns.T("actCancelTitle"),
        tip = ns.T("actCancelTip"),
        state = timerState,
        run = function() ns.Timers.Cancel() end,
    }
    local diffs = {}
    for _, n in ipairs(DIFFS) do diffs[#diffs + 1] = diffItem(n) end
    return {
        { title = ns.T("timerKindBreak"), items = breaks },
        { title = ns.T("timerKindPull"), items = pulls },
        { title = ns.T("pultRaid"), items = {
            {
                label = ns.T("btnReady"),
                title = ns.T("btnReady"),
                tip = ns.T("actReadyTip"),
                state = officerState,
                run = R.ReadyAndOpen,
            },
            {
                label = ns.T("btnMarksWipe"),
                title = ns.T("btnMarksWipe"),
                tip = ns.T("actMarksTip"),
                state = marksState,
                run = function() ns.Marks.ClearAll() end,
            },
        } },
        marksRow(),
        { title = ns.T("actDiffRow"), items = diffs },
    }
end
if root.Shell and root.Shell.Actions then root.Shell.Actions(R.Rows) end
