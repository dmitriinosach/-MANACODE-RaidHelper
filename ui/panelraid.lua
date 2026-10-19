local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Panel = ns.Panel
local EVENING_GAP = 2 * 3600
local NO_GAP = -1
local ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local state
local seenList, seenN = nil, -1
local want, dirty, watching = false, true, false
local function Noop() end
local function Hm(sec)
    sec = max(0, floor(sec))
    return format("%d:%02d", floor(sec / 3600), floor(sec % 3600 / 60))
end
local function Span(sec)
    sec = max(0, floor(sec))
    if sec >= 3600 then return format("%d:%02d:%02d", floor(sec / 3600), floor(sec % 3600 / 60), sec % 60) end
    return ns.Clock(sec)
end
local function ByFrom(a, b)
    return a.from < b.from
end
local function Evening(raid)
    local spans = {}
    local segs = ns.RaidSummary.Segments(raid)
    for i = 1, #segs do
        local s = segs[i].seg
        spans[#spans + 1] = { s.t0, s.t1 or s.t0 }
    end
    if #spans == 0 then
        local list = ns.FightTree.RaidFights(raid)
        for i = 1, #list do spans[#spans + 1] = { list[i].from, list[i].to } end
        table.sort(spans, function(a, b) return a[1] < b[1] end)
    end
    local at = #spans
    if at == 0 then return raid.from, raid.to end
    local start, lastEnd = spans[at][1], max(raid.to, spans[at][2])
    for i = at - 1, 1, -1 do
        if start - spans[i][2] > EVENING_GAP then break end
        start = min(start, spans[i][1])
    end
    return start, lastEnd
end
local function Compute(raid)
    for k = 1, #raid.encs do
        local enc = raid.encs[k]
        if enc.passed and ns.Raid.IsFinal(raid.map, enc.boss) then return nil end
    end
    local start, lastEnd = Evening(raid)
    local list, mine = ns.FightTree.RaidFights(raid), {}
    for i = 1, #list do
        if list[i].from >= start - 1 then mine[#mine + 1] = list[i] end
    end
    table.sort(mine, ByFrom)
    local st = { key = raid.key, start = start, lastEnd = lastEnd, passed = raid.passed, total = raid.total,
                 tries = #mine, wipes = 0, combat = 0, idle = 0, longest = NO_GAP }
    local prev
    for i = 1, #mine do
        local f = mine[i]
        st.combat = st.combat + max(0, f.to - f.from)
        if not f.killed then
            st.wipes = st.wipes + 1
        elseif not st.killAt or f.to > st.killAt then
            st.killBoss, st.killAt = f.boss, f.to
        end
        if prev then
            local gap = max(0, f.from - prev)
            st.idle = st.idle + gap
            if gap > st.longest then st.longest = gap end
        end
        prev = max(prev or 0, f.to)
    end
    return st
end
local function Sync()
    local E, T = ns.Encounters, ns.FightTree
    if not (E and T and ns.RaidSummary and ns.Raid) then
        state = nil
        return
    end
    if want then
        if E.Ready() then
            want = false
        elseif not UnitAffectingCombat("player") then
            E.Scan(Noop)
        end
    end
    local list = E.Fights()
    if #list == 0 then
        state, seenList, seenN = nil, nil, -1
        return
    end
    if list == seenList and #list == seenN and not dirty then return end
    seenList, seenN, dirty = list, #list, false
    local raid = T.Get()[1]
    state = raid and Compute(raid) or nil
end
local function Active()
    return state ~= nil and time() - state.lastEnd < EVENING_GAP
end
local function Invalidated()
    dirty = true
    if watching then want = true end
end
if ns.Encounters and ns.Encounters.Invalidate then hooksecurefunc(ns.Encounters, "Invalidate", Invalidated) end
Panel.Widget({
    key = "raidtime",
    order = 60,
    label = "set.panel.row.raidtime",
    rate = 1,
    Live = function(on)
        watching = on
        if on then want = true end
    end,
    Build = function(row)
        Panel.Line(row, ICON, ns.T("panel.line.raidtime"))
        Panel.Reserve(row, format(ns.T("panel.raidtime"), "99:59", 99, 99))
        Panel.Value(row, ns.T("panel.nodata"), "muted")
    end,
    Update = function(row)
        Sync()
        if not Active() then
            Panel.Value(row, ns.T("panel.nodata"), "muted")
            return
        end
        Panel.Value(row, format(ns.T("panel.raidtime"), Hm(time() - state.start), state.passed, state.total))
    end,
    Tip = function()
        Sync()
        if not Active() then
            return { { kind = "head", left = ns.T("set.panel.row.raidtime"), right = ns.T("panel.nodata") },
                { kind = "sub", left = ns.T("panel.raidtime.empty") } }
        end
        local st, now = state, time()
        local lines = {
            { kind = "head", left = ns.T("set.panel.row.raidtime"),
              right = format(ns.T("panel.raidtime.bosses"), st.passed, st.total) },
            { kind = "row", left = ns.T("panel.raidtime.start"), right = ns.Date(st.start, "dayTime") },
            { kind = "row", left = ns.T("panel.raidtime.in"), right = Span(now - st.start) },
            { kind = "row", left = ns.T("panel.raidtime.combat"), right = Span(st.combat) },
            { kind = "row", left = ns.T("panel.raidtime.idle"), right = Span(st.idle) },
            { kind = "row", left = ns.T("panel.raidtime.longest"),
              right = st.longest >= 0 and Span(st.longest) or ns.T("panel.raidtime.none") },
            { kind = "row", left = ns.T("panel.raidtime.tries"), right = tostring(st.tries) },
            { kind = "row", left = ns.T("panel.raidtime.wipes"), right = tostring(st.wipes) },
        }
        if st.killAt then
            lines[#lines + 1] = { kind = "row", left = ns.T("panel.raidtime.kill"),
                                  right = format(ns.T("panel.raidtime.ago"), ns.EncName(st.killBoss), Span(now - st.killAt)) }
        else
            lines[#lines + 1] = { kind = "note", left = ns.T("panel.raidtime.nokill") }
        end
        lines[#lines + 1] = { kind = "foot", left = ns.T("panel.raidtime.click") }
        return lines
    end,
    Click = function(row, button)
        if button ~= "LeftButton" or not state or not ns.Shell then return end
        local key = state.key
        ns.Shell.Open("log")
        local TL, E = ns.Timeline, ns.Encounters
        if not (TL and TL.ShowRaid and E) then return end
        local function Show()
            local raid = ns.RaidSummary.Find(key)
            if raid then TL.ShowRaid(raid) end
        end
        if E.Ready() then Show() else E.Scan(Show) end
    end,
})
