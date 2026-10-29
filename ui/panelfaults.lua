local _, ns = ...
local format = string.format
local tsort = table.sort
local max = math.max
local Panel = ns.Panel
local Kit = ns.Kit
local GAP = 4
local BTN_PAD = 10
local BTN_INSET = 1
local TIP_MAX = 12
local ICON = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local W = {}
local fight
local summary
local list = {}
local faultRows = {}
local function GiveWidth(b)
    local h = Panel.RowH() - BTN_INSET * 2
    b:SetHeight(h)
    b:SetWidth(max(h * 2, (b.text:GetStringWidth() or 0) + BTN_PAD))
end
Kit.OnFont(function()
    for i = 1, #faultRows do
        local row = faultRows[i]
        GiveWidth(row.give)
        if row.give:IsShown() then Panel.Reserve(row, nil, row.give:GetWidth() + GAP) end
    end
end)
local skipped = {}
local ver, seenVer = 0, -1
local on = false
local asked
local function Newer(a, b)
    if a.t ~= b.t then return a.t > b.t end
    if a.item.name ~= b.item.name then return a.item.name < b.item.name end
    return a.ev.key < b.ev.key
end
local function Collect(f, s)
    for i = #list, 1, -1 do list[i] = nil end
    local model = ns.GPList.Build(f, s)
    for i = 1, #model.items do
        local item = model.items[i]
        for e = 1, #item.events do
            local ev = item.events[e]
            if ev.n > 0 and not ns.Ledger.Done(ev.key) then
                list[#list + 1] = { ev = ev, item = item, t = ev.t or f.to or 0 }
            end
        end
    end
    tsort(list, Newer)
end
local function Ask(f)
    local S = ns.Summary
    local s = S.Peek(f)
    if s or not on or asked == f or UnitAffectingCombat("player") then return s end
    if S.Busy and S.Busy(f) then return nil end
    asked = f
    S.Of(f, function() ver = ver + 1 end)
    return S.Peek(f)
end
local function Refresh()
    local E = ns.Encounters
    if not (E and E.Ready()) then return end
    local f = E.Fights()[1]
    local s = f and Ask(f)
    if f == fight and s == summary and ver == seenVer then return end
    fight, summary, seenVer = f, s, ver
    if f and s then
        Collect(f, s)
    else
        for i = #list, 1, -1 do list[i] = nil end
    end
end
local function Head()
    local first, more = nil, 0
    for i = 1, #list do
        if not skipped[list[i].ev.key] then
            if first then more = more + 1 else first = list[i] end
        end
    end
    return first, more
end
local function Tone(x)
    return x.ev.grade == "yellow" and "warn" or "bad"
end
local function CanGive(x)
    return ns.Ledger.Get(x.item.sys or ns.Ledger.SysOf(x.item.name)).Can(x.ev.n)
end
local function GiveShown(row, on)
    if (row.give:IsShown() and true or false) == on then return end
    if on then row.give:Show() else row.give:Hide() end
    Panel.Reserve(row, nil, on and (row.give:GetWidth() + GAP) or 0)
end
local function Draw(row)
    local x, more
    if Panel.Ctx().raid then x, more = Head() end
    row.cur = x
    if not x then
        GiveShown(row, false)
        row.key = nil
        Panel.Label(row, ns.T("set.panel.row.faults"))
        Panel.Empty(row, Panel.Ctx().raid and "none" or "noraid")
        return
    end
    local ev, item = x.ev, x.item
    if row.key ~= ev.key then
        row.key = ev.key
        Panel.Label(row, item.name, item.class or "")
    end
    local text = format(ns.T("panel.faults.what"), ev.short or "?", ev.n)
    if more > 0 then text = text .. format(ns.T("panel.faults.more"), more) end
    Panel.Value(row, text, Tone(x))
    GiveShown(row, true)
    local ok = CanGive(x)
    if ok ~= row.ok then
        row.ok = ok
        if ok then row.give:Enable() else row.give:Disable() end
    end
end
local function Give(x)
    if not (x and fight) then return end
    ns.GPList.Issue(fight, { { name = x.item.name, sys = x.item.sys, events = { x.ev } } })
end
local function Skip(x)
    if not x then return end
    skipped[x.ev.key] = true
end
local function TipLines()
    local lines = { { kind = "head", left = format(ns.T("panel.faults.head"), fight and ns.EncName(fight.boss) or "") } }
    local unit = ns.Ledger.Unit()
    local total, shown, skip = 0, 0, 0
    for i = 1, #list do
        local x = list[i]
        if skipped[x.ev.key] then
            skip = skip + 1
        else
            total = total + x.ev.n
            shown = shown + 1
            if shown <= TIP_MAX then
                lines[#lines + 1] = { kind = "row", class = x.item.class,
                    left = format(ns.T("panel.faults.row"), x.item.name, x.ev.short or "?"),
                    right = tostring(x.ev.n), tone = x.ev.grade == "yellow" and "warn" or "bad" }
            end
        end
    end
    if shown > TIP_MAX then
        lines[#lines + 1] = { kind = "note", left = format(ns.T("panel.faults.rest"), shown - TIP_MAX) }
    end
    lines[#lines + 1] = { kind = "row", left = ns.T("panel.faults.total"), right = format("%d %s", total, unit) }
    if skip > 0 then lines[#lines + 1] = { kind = "note", left = format(ns.T("panel.faults.skipped"), skip) } end
    lines[#lines + 1] = { kind = "note", left = format(ns.T("panel.faults.sys"), ns.Ledger.Label()) }
    local x = Head()
    local ok, why = true, nil
    if x then ok, why = CanGive(x) end
    if not ok then lines[#lines + 1] = { kind = "note", left = ns.T(why or "led.err.noepgp"), tone = "bad" } end
    lines[#lines + 1] = { kind = "foot", left = ns.T("panel.faults.foot") }
    return lines
end
local function GiveEnter(b)
    local x = Head()
    if not x then return end
    local ok, why = CanGive(x)
    local lines = { { kind = "head", left = format(ns.T("panel.faults.give.tip"), x.ev.n, ns.Ledger.Unit(x.item.sys)) },
        { kind = "row", class = x.item.class, left = format(ns.T("panel.faults.row"), x.item.name, x.ev.short or "?") } }
    if not ok then lines[#lines + 1] = { kind = "note", left = ns.T(why or "led.err.noepgp"), tone = "bad" } end
    lines[#lines + 1] = { kind = "foot", left = ns.T("panel.faults.skip") }
    ns.Panel.Tip(b, lines)
end
local function GiveClick(b, button)
    local row = b:GetParent()
    if button == "RightButton" then
        Skip(row.cur)
    else
        Give(row.cur)
    end
    Refresh()
    Draw(row)
end
function W.Probe()
    return { list = list, skipped = skipped, fight = fight }
end
function W.Reset()
    for k in pairs(skipped) do skipped[k] = nil end
    asked = nil
    ver = ver + 1
end
ns.PanelFaults = W
if ns.GPList and ns.GPList.OnChange then
    ns.GPList.OnChange(function() ver = ver + 1 end)
end
Panel.Widget({
    key = "faults",
    order = 25,
    label = "set.panel.row.faults",
    rate = 1,
    Live = function(v) on = v end,
    Build = function(row)
        Panel.Line(row, ICON, ns.T("set.panel.row.faults"))
        local b = ns.Kit.Button(row, nil, "quiet")
        b:SetText(ns.T("panel.faults.give"))
        GiveWidth(b)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.tipTitle = false
        b.onClick = GiveClick
        b:HookScript("OnEnter", GiveEnter)
        b:HookScript("OnLeave", ns.Tip.Hide)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        b:Hide()
        row.give = b
        faultRows[#faultRows + 1] = row
        Draw(row)
    end,
    Update = function(row)
        if Panel.Ctx().raid then Refresh() end
        Draw(row)
    end,
    Tip = function()
        if not Panel.Ctx().raid then
            return { { kind = "head", left = ns.T("set.panel.row.faults"), right = Panel.EmptyText("noraid") },
                { kind = "foot", left = ns.T("panel.faults.click") } }
        end
        Refresh()
        return TipLines()
    end,
    Click = function(row, button)
        if button == "RightButton" then
            Skip(row.cur)
            Refresh()
            Draw(row)
            return
        end
        local f = fight
        if ns.Shell and ns.Shell.FoldTo then ns.Shell.FoldTo("faults") end
        if ns.ShellMini and ns.ShellMini.Pick then ns.ShellMini.Pick(f) end
    end,
})
