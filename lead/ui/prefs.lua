local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PAD = 12
local ROW_H = 26
local PANEL_W = 300
local pane, panel, rowPool, addBreak, addPull, resetBtn, noDbm
local built = false
local function newRow()
    local r = ns.NewFrame("Frame", nil, panel)
    r:SetSize(PANEL_W - PAD * 2, ROW_H - 2)
    r.kind = ns.MakeSelect(r)
    r.kind:SetWidth(96)
    r.kind:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.sec = ns.MakeEdit(r)
    r.sec:SetWidth(56)
    r.sec:SetNumeric(true)
    r.sec:SetMaxLetters(4)
    r.sec:SetPoint("LEFT", r.kind, "RIGHT", 8, 0)
    r.unit = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.unit:SetPoint("LEFT", r.sec, "RIGHT", 4, 0)
    r.unit:SetText(ns.T("sec"))
    ns.PaintText(r.unit, "text.secondary")
    r.show = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.show:SetPoint("LEFT", r.unit, "RIGHT", 10, 0)
    ns.PaintText(r.show, "text.muted")
    r.del = ns.MakeKitButton(r)
    r.del:SetSize(22, 20)
    r.del:SetText("x")
    r.del.tip = ns.T("tipTimerDel")
    r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    return r
end
local function refresh()
    if not built or not pane:IsVisible() then return end
    local list = ns.Timers.List()
    rowPool:Reset()
    for i, t in ipairs(list) do
        local r = rowPool:Acquire()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(36 + (i - 1) * ROW_H))
        r.kind:SetOptions({ { key = "break", label = ns.T("timerKindBreak") },
            { key = "pull", label = ns.T("timerKindPull") } }, t.kind)
        r.kind.onPick = function(k) ns.Timers.Set(i, k, nil) end
        if not r.sec.focused then r.sec:SetValue(tostring(t.sec)) end
        r.sec.onChange = nil
        r.sec.onCommit = function(v) ns.Timers.Set(i, nil, v) end
        r.show:SetText(ns.Timers.Duration(t.sec))
        r.del.onClick = function()
            r.sec:ClearFocus()
            ns.Timers.Remove(i)
        end
    end
    rowPool:HideExtras()
    local y = 36 + #list * ROW_H + 8
    addBreak:ClearAllPoints()
    addBreak:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
    addPull:ClearAllPoints()
    addPull:SetPoint("LEFT", addBreak, "RIGHT", 6, 0)
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPLEFT", addBreak, "BOTTOMLEFT", 0, -6)
    if ns.Timers.IsDefault() then
        resetBtn:Disable()
        resetBtn.tip = ns.T("tipTimersDefault")
    else
        resetBtn:Enable()
        resetBtn.tip = nil
    end
    local was = panel:GetHeight()
    panel:SetHeight(y + 60)
    if ns.Timers.HasDBM() then noDbm:Hide() else noDbm:Show() end
    if was ~= y + 60 and root.Shell and root.Shell.SectionResized then root.Shell.SectionResized() end
end
local function height()
    if not built then return 0 end
    return math.max(panel:GetHeight(), noDbm:IsShown() and noDbm:GetHeight() + 10 or 0)
end
local function build()
    pane = ns.window:Prefs()
    panel = ns.MakePanel(pane, ns.T("prefsTimers"))
    panel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    panel:SetWidth(PANEL_W)
    rowPool = ns.NewPool(newRow)
    addBreak = ns.MakeKitButton(panel)
    addBreak:SetSize(130, 22)
    addBreak:SetText(ns.T("btnAddBreak"))
    addBreak.onClick = function() ns.Timers.Add("break") end
    addPull = ns.MakeKitButton(panel)
    addPull:SetSize(130, 22)
    addPull:SetText(ns.T("btnAddPull"))
    addPull.onClick = function() ns.Timers.Add("pull") end
    resetBtn = ns.MakeKitButton(panel)
    resetBtn:SetSize(PANEL_W - PAD * 2, 22)
    resetBtn:SetText(ns.T("btnDefault"))
    resetBtn.onClick = function() ns.Timers.Reset() end
    noDbm = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noDbm:SetPoint("TOPLEFT", panel, "TOPRIGHT", 12, -10)
    noDbm:SetPoint("RIGHT", pane, "RIGHT", -8, 0)
    noDbm:SetJustifyH("LEFT")
    noDbm:SetText(ns.T("prefsNoDbm"))
    ns.PaintText(noDbm, "text.secondary")
    built = true
    pane:SetScript("OnShow", refresh)
    refresh()
end
ns.Session.OnChange(refresh)
ns.PrefsPane = { Build = build, Refresh = refresh, Height = height }
ns.window:OnBuild(build)
