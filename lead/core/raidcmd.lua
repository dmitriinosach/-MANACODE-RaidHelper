local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local R = {}
ns.RaidCmd = R
local DIFFS = { 1, 2, 3, 4 }
local LOOT = { "freeforall", "roundrobin", "master", "group", "needbeforegreed" }
local THRESH = { 2, 3, 4 }
R.LOOT, R.THRESH = LOOT, THRESH
local testLoot, testThresh = "group", 2
local function testActive()
    return ns.Test ~= nil and ns.Test.Active()
end
local function testOnly()
    return testActive() and ns.Compat.GroupSize() == 0
end
function R.Officer()
    if testActive() then return true end
    local raid = ns.Compat.GroupSize()
    return raid > 0 and (IsRaidLeader() or IsRaidOfficer()) and true or false
end
function R.Leader()
    if testActive() then return true end
    local raid, party = ns.Compat.GroupSize()
    if raid > 0 then return IsRaidLeader() and true or false end
    if party > 0 then return IsPartyLeader() and true or false end
    return true
end
function R.Ready()
    if not R.Officer() then return false end
    if testOnly() then return true end
    DoReadyCheck()
    return true
end
function R.CanConvert()
    if testActive() then return false end
    local raid, party = ns.Compat.GroupSize()
    return raid == 0 and party > 0 and IsPartyLeader() and true or false
end
function R.Convert()
    if not R.CanConvert() then return false end
    ConvertToRaid()
    return true
end
function R.LootMethod()
    if testOnly() then return testLoot, UnitName("player") end
    local method, pm, rm = GetLootMethod()
    local master
    if method == "master" then
        if rm then
            master = GetRaidRosterInfo(rm)
        elseif pm == 0 then
            master = UnitName("player")
        elseif pm then
            master = UnitName("party" .. pm)
        end
    end
    return method or "group", master
end
function R.LootThreshold()
    if testOnly() then return testThresh end
    return GetLootThreshold() or 2
end
function R.CanLoot()
    if R.Leader() then return true end
    return false, ns.T("tipNeedLeader")
end
function R.CanThreshold()
    if R.Leader() then return true end
    local method, master = R.LootMethod()
    if method == "master" and master == UnitName("player") then return true end
    return false, ns.T("tipNeedLeaderOrMaster")
end
function R.SetLoot(method, master)
    if not R.CanLoot() then return false end
    if testOnly() then
        testLoot = method
        ns.Session.Changed()
        return true
    end
    if method == "master" then
        SetLootMethod("master", master or UnitName("player"))
    else
        SetLootMethod(method)
    end
    return true
end
function R.SetThreshold(n)
    if not R.CanThreshold() then return false end
    if testOnly() then
        testThresh = n
        ns.Session.Changed()
        return true
    end
    SetLootThreshold(n)
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
        id = t.kind .. ":" .. t.sec,
        label = d,
        short = ns.Timers.Short(t.sec),
        title = ns.T(pull and "tipPull" or "tipBreak", d),
        tip = ns.T(pull and "actPullTip" or "actBreakTip"),
        state = timerState,
        run = function() ns.Timers.Run(t) end,
    }
end
local function diffItem(n)
    return {
        id = "diff:" .. n,
        label = ns.T("actDiff" .. n),
        short = ns.T("actDiffShort" .. n),
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
            id = "keep",
            check = true,
            label = "", title = "", tip = "",
            state = function() return true, nil, ns.Marks.Enabled() end,
            run = function() ns.Marks.SetEnabled(not ns.Marks.Enabled()) end,
        } }
        for i = 1, ns.Marks.COUNT do
            markItems[#markItems + 1] = {
                id = "mark:" .. i,
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
    return { id = "marks", title = ns.T("actMarksRow"), items = markItems, status = ns.Marks.Status }
end
function R.Rows()
    local breaks, pulls = {}, {}
    for _, t in ipairs(ns.Timers.List()) do
        local list = t.kind == "pull" and pulls or breaks
        list[#list + 1] = timerItem(t)
    end
    pulls[#pulls + 1] = {
        id = "cancel",
        label = ns.T("actCancel"),
        short = ns.T("actCancelShort"),
        title = ns.T("actCancelTitle"),
        tip = ns.T("actCancelTip"),
        state = timerState,
        run = function() ns.Timers.Cancel() end,
    }
    local diffs = {}
    for _, n in ipairs(DIFFS) do diffs[#diffs + 1] = diffItem(n) end
    return {
        { id = "break", title = ns.T("timerKindBreak"), items = breaks },
        { id = "pull", title = ns.T("timerKindPull"), items = pulls },
        { id = "raid", title = ns.T("pultRaid"), items = {
            {
                id = "ready",
                label = ns.T("btnReady"),
                short = ns.T("actReadyShort"),
                title = ns.T("btnReady"),
                tip = ns.T("actReadyTip"),
                state = officerState,
                run = R.ReadyAndOpen,
            },
            {
                id = "wipe",
                label = ns.T("btnMarksWipe"),
                short = ns.T("actMarksWipeShort"),
                title = ns.T("btnMarksWipe"),
                tip = ns.T("actMarksTip"),
                state = marksState,
                run = function() ns.Marks.ClearAll() end,
            },
        } },
        marksRow(),
        { id = "diff", title = ns.T("actDiffRow"), short = ns.T("actDiffRowShort"), items = diffs },
    }
end
if root.Shell and root.Shell.Actions then root.Shell.Actions(R.Rows) end
