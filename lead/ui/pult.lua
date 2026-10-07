local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 12
local ROW_H = 18
local pult, sel, count, testFs, roles, nextFs, runBtn, spamCap, readyBtn, buffBtn
local timerPool, timerW
local built = false
local function tplOptions()
    local out = {}
    for _, t in ipairs(ns.Tpl.List()) do
        out[#out + 1] = { key = t.key, label = ns.Tpl.Name(t) }
    end
    return out
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
    readyBtn.tip = not can and ns.T("tipNeedOfficer") or nil
    if can then readyBtn:Enable() else readyBtn:Disable() end
    timerPool:Reset()
    if ns.Timers.HasDBM() then
        local half = (timerW - 6) / 2
        for k, t in ipairs(ns.Timers.List()) do
            local b = timerPool:Acquire()
            local col = (k - 1) % 2
            local rowN = math.floor((k - 1) / 2)
            b:SetSize(half, 20)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", buffBtn, "BOTTOMLEFT", col * (half + 6), -8 - rowN * 24)
            local d = ns.Timers.Duration(t.sec)
            b:SetText(ns.T(t.kind == "pull" and "timerPull" or "timerBreak", d))
            b.tipTitle = ns.T(t.kind == "pull" and "tipPull" or "tipBreak", d)
            b.tip = can and ns.T("tipTimerAll") or ns.T("tipNeedOfficer")
            if can then b:Enable() else b:Disable() end
            b.onClick = function() ns.Timers.Run(t) end
        end
    end
    timerPool:HideExtras()
    local rowsN = ns.Timers.HasDBM() and math.ceil(#ns.Timers.List() / 2) or 0
    if ns.PultMarks then ns.PultMarks.Place(buffBtn, rowsN > 0 and -(rowsN * 24 + 4 + 20) or -20) end
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
            runBtn.tip = ns.T(ns.Test.Active() and "tipTestSpam" or "tipNoChannels")
        end
    end
end
local function build()
    pult = ns.window:Pult()
    local w = pult:GetWidth() - PAD * 2
    sel = ns.MakeSelect(pult)
    sel:SetPoint("TOPLEFT", pult, "TOPLEFT", PAD, -32)
    sel:SetWidth(w)
    sel.onPick = function(key) ns.Session.SetTemplate(key) end
    count = pult:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    count:SetPoint("TOPLEFT", sel, "BOTTOMLEFT", 0, -12)
    ns.PaintText(count, "text.primary")
    testFs = pult:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    testFs:SetPoint("LEFT", count, "RIGHT", 8, 0)
    testFs:SetText(ns.T("testTag"))
    ns.PaintText(testFs, "text.tag")
    testFs:Hide()
    roles = {}
    local prev = count
    for _, grp in ipairs(ns.GROUP_ORDER) do
        local r = {}
        r.label = pult:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.label:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == count and -8 or -4)
        r.label:SetText(ns.T("grpTitle_" .. grp))
        ns.PaintText(r.label, "text.secondary")
        r.val = pult:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.val:SetPoint("RIGHT", pult, "RIGHT", -PAD, 0)
        r.val:SetPoint("TOP", r.label, "TOP", 0, 0)
        r.label:SetHeight(ROW_H - 4)
        roles[grp] = r
        prev = r.label
    end
    spamCap = ns.Caption(pult, ns.T("pultSpam"), w)
    spamCap:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
    nextFs = pult:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nextFs:SetPoint("TOPLEFT", spamCap, "BOTTOMLEFT", 0, -8)
    nextFs:SetWidth(w)
    nextFs:SetJustifyH("LEFT")
    nextFs:SetHeight(14)
    ns.PaintText(nextFs, "text.primary")
    runBtn = ns.MakeKitButton(pult)
    runBtn:SetPoint("TOPLEFT", nextFs, "BOTTOMLEFT", 0, -6)
    runBtn:SetWidth(w)
    runBtn:SetHeight(26)
    runBtn.onClick = function() ns.Spam.Toggle() end
    local raidCap = ns.Caption(pult, ns.T("pultRaid"), w)
    raidCap:SetPoint("TOPLEFT", runBtn, "BOTTOMLEFT", 0, -20)
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
local function tagged()
    return built and testFs:IsShown() and true or false
end
ns.Pult = { Build = build, Refresh = refresh, Tagged = tagged }
ns.window:OnBuild(build)
