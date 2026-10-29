local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 12
local ROW_H = 18
local CHIP_H = 18
local CHIP_PAD = 10
local CHIP_GAP = 4
local CHIP_ROW = 22
local LABEL_W = 48
local SEL_H = 20
local SEL_ROW = 24
local BASE = "GameFontHighlightSmall"
local CAPF = "GameFontNormalSmall"
local pult, sel, count, countCap, testFs, roles, nextFs, runBtn, spamCap, raidCap, raidFold, readyBtn, buffBtn
local breakLbl, pullLbl, lootCap, lootSel, threshCap, threshSel, raidEnd
local timerPool, timerW
local openOn = {}
local built = false
local function tplOptions()
    local out = {}
    for _, t in ipairs(ns.Tpl.List()) do
        out[#out + 1] = { key = t.key, label = ns.Tpl.Name(t) }
    end
    return out
end
local function tab()
    return ns.window.Current and ns.window:Current() or "raid"
end
local function sectionOpen(name)
    local cur = tab()
    if cur == "raid" or cur == nil then return true end
    return openOn[cur .. ":" .. name] or false
end
local function toggleSection(name)
    local cur = tab()
    if cur == "raid" then return end
    openOn[cur .. ":" .. name] = not openOn[cur .. ":" .. name] or nil
end
local function foldText(fold, open)
    fold:SetText(open and "-" or "+")
    fold.tipTitle = ns.T(open and "tipFoldClose" or "tipFoldOpen")
end
local function lootOptions()
    local out = {}
    local _, master = ns.RaidCmd.LootMethod()
    for _, k in ipairs(ns.RaidCmd.LOOT) do
        local label = ns.T("lootM_" .. k)
        if k == "master" then label = label:format(master or UnitName("player")) end
        out[#out + 1] = { key = k, label = label }
    end
    return out
end
local function threshOptions()
    local out = {}
    for _, n in ipairs(ns.RaidCmd.THRESH) do
        out[#out + 1] = { key = n, label = ns.T("lootT_" .. n) }
    end
    return out
end
local function setState(b, can, why)
    if can then
        b:Enable()
        b.tip = nil
    else
        b:Disable()
        b.tip = why
    end
end
local function chip(t, x, y, can)
    local b = timerPool:Acquire()
    b:SetText(t.label)
    local w = math.ceil((b.text:GetStringWidth() or 0) + CHIP_PAD)
    if x + w > timerW then
        x, y = LABEL_W, y + CHIP_ROW
    end
    b:SetSize(w, CHIP_H)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", x, -y)
    b.tipTitle = t.title
    b.tip = can and t.tip or ns.T("tipNeedOfficer")
    if can then b:Enable() else b:Disable() end
    b.onClick = t.run
    return x + w + CHIP_GAP, y
end
local function timerRows(can)
    local T = ns.Timers
    timerPool:Reset()
    if not T.HasDBM() then
        breakLbl:Hide()
        pullLbl:Hide()
        timerPool:HideExtras()
        return 0
    end
    local rows = { { kind = "break", lbl = breakLbl, items = {} }, { kind = "pull", lbl = pullLbl, items = {} } }
    for _, t in ipairs(T.List()) do
        local row = t.kind == "pull" and rows[2] or rows[1]
        local d = T.Duration(t.sec)
        row.items[#row.items + 1] = { label = T.Short(t.sec), title = ns.T(t.kind == "pull" and "tipPull" or "tipBreak", d),
            tip = ns.T("tipTimerAll"), run = function() T.Run(t) end }
    end
    rows[2].items[#rows[2].items + 1] = { label = ns.T("actCancelShort"), title = ns.T("actCancelTitle"),
        tip = ns.T("actCancelTip"), run = function() T.Cancel() end }
    local y = 8
    for _, row in ipairs(rows) do
        if #row.items > 0 then
            row.lbl:ClearAllPoints()
            row.lbl:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", 0, -(y + math.floor((CHIP_H - ns.LineH(BASE)) / 2)))
            row.lbl:Show()
            local x = LABEL_W
            for _, it in ipairs(row.items) do x, y = chip(it, x, y, can) end
            y = y + CHIP_ROW
        else
            row.lbl:Hide()
        end
    end
    timerPool:HideExtras()
    return y - 8 + 4
end
local function lootRows(top)
    local R = ns.RaidCmd
    local y = top + 6
    lootCap:ClearAllPoints()
    lootCap:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", 0, -(y + math.floor((SEL_H - ns.LineH(BASE)) / 2)))
    lootSel:ClearAllPoints()
    lootSel:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", LABEL_W, -y)
    lootSel:SetWidth(timerW - LABEL_W)
    local method = R.LootMethod()
    lootSel:SetOptions(lootOptions(), method)
    setState(lootSel, R.CanLoot())
    y = y + SEL_ROW
    threshCap:ClearAllPoints()
    threshCap:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", 0, -(y + math.floor((SEL_H - ns.LineH(BASE)) / 2)))
    threshSel:ClearAllPoints()
    threshSel:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", LABEL_W, -y)
    threshSel:SetWidth(timerW - LABEL_W)
    threshSel:SetOptions(threshOptions(), R.LootThreshold())
    setState(threshSel, R.CanThreshold())
    return y + SEL_ROW
end
local function showRaid(on)
    for _, f in ipairs({ readyBtn, buffBtn, lootCap, lootSel, threshCap, threshSel }) do
        if on then f:Show() else f:Hide() end
    end
    if not on then
        breakLbl:Hide()
        pullLbl:Hide()
        timerPool:Reset()
        timerPool:HideExtras()
    end
end
local function refresh()
    if not built then return end
    local S = ns.Session
    local tpl = S.Template()
    sel:SetOptions(tplOptions(), tpl.key)
    local n, size = S.Count()
    count:SetText(n .. ns.Hex("text.secondary") .. "/" .. size .. "|r")
    if ns.Test.Active() then testFs:Show() else testFs:Hide() end
    local need, total = S.Needs()
    for _, grp in ipairs(ns.GROUP_ORDER) do
        local r = roles[grp]
        local have = total[grp] - need[grp]
        r.val:SetText(have .. "/" .. total[grp])
        ns.PaintText(r.val, need[grp] == 0 and "sem.ready" or "text.primary")
    end
    local can = ns.RaidCmd.Officer()
    local open = sectionOpen("raid")
    if tab() == "raid" then raidFold:Hide() else raidFold:Show() end
    foldText(raidFold, open)
    showRaid(open)
    local dy = -20
    if open then
        setState(readyBtn, can, ns.T("tipNeedOfficer"))
        local h = timerRows(can)
        h = lootRows(h)
        dy = -(h + 20)
    end
    local marksOpen = sectionOpen("marks")
    if ns.PultMarks then
        ns.PultMarks.SetCollapsed(not marksOpen, function()
            toggleSection("marks")
            refresh()
        end)
        ns.PultMarks.Place(open and buffBtn or raidCap, dy)
    end
    local P = ns.Spam
    if P.Running() then
        runBtn:SetText(ns.T("btnStop"))
        runBtn:Enable()
        runBtn.tip = nil
        local c, left = P.Next()
        if not P.Fits() then
            nextFs:SetText(ns.Hex("sem.notReady") .. ns.T("spamTooLong") .. "|r")
        elseif c then
            nextFs:SetText(c.label .. "  " .. ns.Hex("text.title") .. math.ceil(left) .. " " .. ns.T("sec") .. "|r")
        else
            nextFs:SetText("")
        end
    else
        runBtn:SetText(ns.T("btnStart"))
        nextFs:SetText("")
        if P.CanStart() then
            runBtn:Enable()
            runBtn.tip = nil
        else
            runBtn:Disable()
            runBtn.tip = ns.T(P.Blocker() or "tipNoChannels")
        end
    end
end
local function fitRows()
    for _, grp in ipairs(ns.GROUP_ORDER) do
        roles[grp].label:SetHeight(ns.Fit(CAPF, ROW_H - 4, 0))
    end
    nextFs:SetHeight(ns.Fit(BASE, 14, 0))
end
local function onFont()
    if not built then return end
    fitRows()
    refresh()
end
local function label(text)
    local fs = ns.Str(pult, BASE)
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(LABEL_W - 4)
    ns.PaintText(fs, "text.secondary")
    return fs
end
local function build()
    pult = ns.window:Pult()
    local w = pult:GetWidth() - PAD * 2
    sel = ns.MakeSelect(pult)
    sel:SetPoint("TOPLEFT", pult, "TOPLEFT", PAD, -32)
    sel:SetWidth(w)
    sel.onPick = function(key) ns.Session.SetTemplate(key) end
    count = ns.Str(pult, "GameFontHighlightLarge")
    count:SetPoint("TOPLEFT", sel, "BOTTOMLEFT", 0, -12)
    ns.PaintText(count, "text.primary")
    countCap = ns.Str(pult, BASE)
    countCap:SetPoint("LEFT", count, "RIGHT", 6, -1)
    countCap:SetText(ns.T("countInGroups"))
    ns.PaintText(countCap, "text.secondary")
    testFs = ns.Str(pult, CAPF)
    testFs:SetPoint("LEFT", countCap, "RIGHT", 6, 0)
    testFs:SetText(ns.T("testTag"))
    ns.PaintText(testFs, "text.tag")
    testFs:Hide()
    roles = {}
    local prev = count
    for _, grp in ipairs(ns.GROUP_ORDER) do
        local r = {}
        r.label = ns.Str(pult, CAPF)
        r.label:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == count and -8 or -4)
        r.label:SetText(ns.T("grpTitle_" .. grp))
        ns.PaintText(r.label, "text.secondary")
        r.val = ns.Str(pult, BASE)
        r.val:SetPoint("RIGHT", pult, "RIGHT", -PAD, 0)
        r.val:SetPoint("TOP", r.label, "TOP", 0, 0)
        roles[grp] = r
        prev = r.label
    end
    spamCap = ns.Caption(pult, ns.T("pultSpam"), w)
    spamCap:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
    nextFs = ns.Str(pult, BASE)
    nextFs:SetPoint("TOPLEFT", spamCap, "BOTTOMLEFT", 0, -8)
    nextFs:SetWidth(w)
    nextFs:SetJustifyH("LEFT")
    ns.PaintText(nextFs, "text.primary")
    runBtn = ns.MakeKitButton(pult)
    runBtn:SetPoint("TOPLEFT", nextFs, "BOTTOMLEFT", 0, -6)
    runBtn:SetWidth(w)
    runBtn:SetHeight(26)
    runBtn.onClick = function() ns.Spam.Toggle() end
    raidCap = ns.Caption(pult, ns.T("pultRaid"), w - 24)
    raidCap:SetPoint("TOPLEFT", runBtn, "BOTTOMLEFT", 0, -20)
    raidFold = ns.MakeKitButton(pult)
    raidFold:SetSize(18, 16)
    raidFold:SetPoint("LEFT", raidCap, "LEFT", w - 18, 0)
    raidFold.onClick = function()
        toggleSection("raid")
        refresh()
    end
    readyBtn = ns.MakeKitButton(pult)
    readyBtn:SetPoint("TOPLEFT", raidCap, "BOTTOMLEFT", 0, -8)
    readyBtn:SetWidth(w)
    readyBtn:SetText(ns.T("btnReady"))
    readyBtn.onClick = function()
        if ns.RaidCmd.Ready() and root.Shell and root.Shell.Open then root.Shell.Open("raid") end
    end
    buffBtn = ns.MakeKitButton(pult)
    buffBtn:SetPoint("TOPLEFT", readyBtn, "BOTTOMLEFT", 0, -6)
    buffBtn:SetWidth(w)
    buffBtn:SetText(ns.T("btnBuffCheck"))
    buffBtn.tipTitle = ns.T("btnBuffCheck")
    buffBtn.tip = ns.T("tipBuffCheck")
    buffBtn.onClick = function() ns.ReadyUI.Check() end
    breakLbl = label(ns.T("timerKindBreak"))
    pullLbl = label(ns.T("timerKindPull"))
    lootCap = label(ns.T("lootMethodCap"))
    threshCap = label(ns.T("lootThreshCap"))
    lootSel = ns.MakeSelect(pult)
    lootSel:SetHeight(SEL_H)
    lootSel.tipTitle = ns.T("lootMethodCap")
    lootSel.onPick = function(k) ns.RaidCmd.SetLoot(k) end
    threshSel = ns.MakeSelect(pult)
    threshSel:SetHeight(SEL_H)
    threshSel.tipTitle = ns.T("lootThreshCap")
    threshSel.onPick = function(k) ns.RaidCmd.SetThreshold(k) end
    fitRows()
    timerW = w
    timerPool = ns.NewPool(function() return ns.MakeKitButton(pult) end)
    if ns.PultMarks then ns.PultMarks.Build(pult, w) end
    built = true
    refresh()
    local acc = 0
    pult:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        if ns.Spam.Running() then refresh() end
    end)
end
ns.Session.OnChange(refresh)
ns.Spam.OnRun(refresh)
ns.OnFont(onFont)
local function tagged()
    return built and testFs:IsShown() and true or false
end
ns.Pult = {
    Build = build, Refresh = refresh, Tagged = tagged,
    Parts = function() return raidCap, raidFold, readyBtn, buffBtn, lootSel, threshSel, timerPool end,
    Chips = function() return timerPool end,
}
ns.window:OnBuild(build)
