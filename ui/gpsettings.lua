local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local PAD = 12
local HEAD = 104
local ROWH = 24
local WHEEL = 3
local TEXTW = 270
local NUMW = 52
local MODEW = 96
local SHORTW = 140
local RESETW = 90
local HOTW = 52
local MODES = { "once", "each", "grow" }
local View = {}
ns.GPSettings = View
local frame, listBox, banner, pageText, guildText, publishBtn, resetAllBtn, searchBox
local query = ""
local heads = {}
local hotBoxes = {}
local rows = {}
local items = {}
local offset = 0
local slots = 0
local function Changed()
    if ns.GPList then ns.GPList.Changed() end
end
local function LowA(a)
    return "\208" .. string.char(a:byte() + 32)
end
local function LowR(a)
    return "\209" .. string.char(a:byte() - 32)
end
local function Lower(s)
    s = s:lower():gsub("\208\129", "\209\145"):gsub("\208([\144-\159])", LowA):gsub("\208([\160-\175])", LowR)
    return s
end
local function Matches(r)
    if query == "" then return true end
    local hay = Lower(ns.T(r.text) .. " " .. ns.Penalties.Short(r) .. " " ..
        (r.boss == ns.penaltyAny and ns.T("gpset.any") or ns.EncName(r.boss)))
    return hay:find(query, 1, true) ~= nil
end
local function BuildItems()
    items = {}
    local all = ns.Penalties.All()
    local lastBoss
    for i = 1, #all do
        local r = all[i]
        if Matches(r) then
            if r.boss ~= lastBoss then
                lastBoss = r.boss
                items[#items + 1] = { head = r.boss == ns.penaltyAny and ns.T("gpset.any") or ns.EncName(r.boss) }
            end
            items[#items + 1] = { rule = r }
        end
    end
end
local function Reload()
    BuildItems()
    View.Refresh()
    Changed()
end
local function FieldOf(box)
    if box.what then return ns.Penalties.SYS[ns.Ledger.Key()][box.what] end
    return box.field
end
local function Commit(box, numeric)
    local key = box.editKey
    box.editKey = nil
    if not key then return end
    local text = box:GetText()
    local value
    if numeric then
        value = tonumber(text)
        if text == "" then value = nil end
        if value then value = floor(value + 0.5) end
    else
        value = text
    end
    ns.Penalties.Set(key, FieldOf(box), value)
    Reload()
end
local function MakeBox(parent, name, width, what, field)
    local numeric = what ~= nil
    local box = ns.Kit.Edit(parent, false, name)
    box:SetWidth(width)
    box:SetHeight(20)
    box.what, box.field = what, field
    if numeric then box:SetNumeric(true) end
    box:HookScript("OnEditFocusGained", function(self)
        local rule = self:GetParent().rule
        self.editKey = rule and rule.key or nil
    end)
    box:HookScript("OnEditFocusLost", function(self) Commit(self, numeric) end)
    box:SetScript("OnEscapePressed", function(self)
        self.editKey = nil
        self:ClearFocus()
        View.Refresh()
    end)
    return box
end
local function OnCheck(self)
    local rule = self:GetParent().rule
    if not rule then return end
    ns.Penalties.Set(rule.key, "on", self:GetChecked() and true or false)
    Reload()
end
local function OnMode(row)
    local rule = row.rule
    if not rule then return end
    local cur = rule.mode or "each"
    local nextMode = MODES[1]
    for i = 1, #MODES do
        if MODES[i] == cur then nextMode = MODES[i % #MODES + 1] end
    end
    ns.Penalties.Set(rule.key, "mode", nextMode)
    Reload()
end
local function OnReset(row)
    local rule = row.rule
    if rule and ns.Penalties.Reset(rule.key) then Reload() end
end
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, listBox)
    r:SetHeight(ROWH)
    r:SetPoint("TOPLEFT", 0, -((i - 1) * ROWH))
    r:SetPoint("TOPRIGHT", 0, -((i - 1) * ROWH))
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) View.Scroll(delta) end)
    r.head = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ns.Kit.Text(r.head, "text.title")
    r.head:SetPoint("LEFT", 4, 0)
    r.check = ns.Kit.Check(r, "HTP_FailWatchGPCheck" .. i)
    r.check:SetWidth(22)
    r.check:SetHeight(22)
    r.check:SetPoint("LEFT", 0, 0)
    r.check.onToggle = function() OnCheck(r.check) end
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 26, 0)
    r.text:SetWidth(TEXTW)
    r.text:SetJustifyH("LEFT")
    local x = 26 + TEXTW + 6
    r.mode = ns.MakeButton(r, "HTP_FailWatchGPMode" .. i, "quiet")
    r.mode:SetWidth(MODEW)
    r.mode:SetHeight(20)
    r.mode:SetPoint("LEFT", x, 0)
    r.mode.onClick = function() OnMode(r) end
    x = x + MODEW + 12
    r.gp = MakeBox(r, "HTP_FailWatchGPCost" .. i, NUMW, "sum")
    r.gp:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.wipe = MakeBox(r, "HTP_FailWatchGPWipe" .. i, NUMW, "wipe")
    r.wipe:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.step = MakeBox(r, "HTP_FailWatchGPStep" .. i, NUMW, "step")
    r.step:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.short = MakeBox(r, "HTP_FailWatchGPShort" .. i, SHORTW, nil, "short")
    r.short:SetPoint("LEFT", x, 0)
    x = x + SHORTW + 10
    r.reset = ns.MakeButton(r, "HTP_FailWatchGPReset" .. i, "danger")
    r.reset:SetWidth(RESETW)
    r.reset:SetHeight(20)
    r.reset:SetPoint("LEFT", x, 0)
    r.reset.text:SetText(ns.T("gpset.reset"))
    r.reset.onClick = function() OnReset(r) end
    rows[i] = r
    return r
end
local function SetBox(box, value)
    if not box:HasFocus() then box:SetText(value ~= nil and tostring(value) or "") end
    ns.Kit.Tone(box, "text.bright")
end
local function FillRow(r, item)
    local controls = { r.check, r.text, r.mode, r.gp, r.wipe, r.step, r.short, r.reset }
    if item.head then
        r.rule = nil
        for i = 1, #controls do controls[i]:Hide() end
        r.head:SetText(item.head)
        r.head:Show()
        return
    end
    r.head:Hide()
    for i = 1, #controls do controls[i]:Show() end
    local rule = item.rule
    local sys = ns.Ledger.Key()
    r.rule = rule
    r.check:SetChecked(rule.on and true or false)
    local label = ns.T(rule.text)
    if rule.kind == "manual" then label = label .. " " .. ns.Kit.Hex("text.note") .. ns.T("gpset.manual") .. "|r" end
    if rule.unverified then label = label .. " " .. ns.Kit.Hex("text.bad") .. "?|r" end
    r.text:SetText(label)
    ns.Kit.Tone(r.text, rule.on and "text.bright" or "text.off")
    r.mode.text:SetText(ns.T("gpset.mode." .. (rule.mode or "each")))
    SetBox(r.gp, ns.Penalties.Amount(rule, sys, "sum"))
    SetBox(r.wipe, ns.Penalties.Amount(rule, sys, "wipe"))
    SetBox(r.step, ns.Penalties.Amount(rule, sys, "step"))
    SetBox(r.short, ns.Penalties.Short(rule))
    if ns.Penalties.IsChanged(rule.key) then r.reset:Enable() else r.reset:Disable() end
end
local function GuildLine()
    local G = ns.GPGuild
    if not G then return "" end
    if not IsInGuild() then return ns.T("gpg.status.noguild") end
    local st = G.Status()
    if not st.seen then return ns.T("gpg.status.wait") end
    local guild = st.guild and tostring(st.guild) or ns.T("gpg.v.none")
    local mine = st.mine and tostring(st.mine) or ns.T("gpg.v.builtin")
    return format(ns.T("gpg.status"), guild, mine)
end
local function RefreshGuild()
    local G = ns.GPGuild
    local st = G and G.Status()
    guildText:SetText(GuildLine())
    ns.Kit.Text(guildText, (st and st.synced) and "sem.win" or "badge.link")
    if st and st.officer then publishBtn:Show() else publishBtn:Hide() end
end
local function RefreshHead()
    local sys = ns.Ledger.Key()
    local n = ns.Penalties.Changed()
    banner:SetText(format(ns.T("gpset.mine"), ns.Penalties.Label(), n))
    if n > 0 then resetAllBtn:Enable() else resetAllBtn:Disable() end
    for kind, box in pairs(hotBoxes) do
        if not box:HasFocus() then box:SetText(tostring(ns.Ledger.HotSum(kind, sys))) end
    end
    local unit = ns.Ledger.Unit(sys)
    heads.sum:SetText(format(ns.T("gpset.col.sum"), unit))
end
function View.Refresh()
    if not frame or not frame:IsVisible() then return end
    RefreshHead()
    RefreshGuild()
    slots = max(1, floor(listBox:GetHeight() / ROWH))
    offset = max(0, min(offset, #items - slots))
    for i = 1, slots do
        local r = Row(i)
        local item = items[i + offset]
        if item then
            FillRow(r, item)
            r:Show()
        else
            r:Hide()
        end
    end
    for i = slots + 1, #rows do rows[i]:Hide() end
    pageText:SetText(format(ns.T("gpset.page"), min(#items, offset + 1), min(#items, offset + slots), #items))
end
function View.Search(text)
    query = Lower(ns.Penalties.Clean(text))
    offset = 0
    BuildItems()
    View.Refresh()
end
function View.Scroll(delta)
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus.editKey then focus:ClearFocus() end
    offset = offset - delta * WHEEL
    View.Refresh()
end
local function DoPublish()
    local G = ns.GPGuild
    if not G or not ns.GPList then return end
    if not G.CanPublish() then
        ns.Print(ns.T("gpg.err.rights"))
        return
    end
    local st = G.Status()
    local v = max(st.guild or 0, st.mine or 0) + 1
    ns.GPList.Confirm(format(ns.T("gpg.ask"), ns.Penalties.Label(), v), ns.T("gpg.yes"), function()
        local _, key, a, b = G.Publish()
        ns.Print(format(ns.T(key), a or 0, b or 0))
        Reload()
    end)
end
local function DoResetAll()
    if not ns.GPList or ns.Penalties.Changed() == 0 then return end
    ns.GPList.Confirm(format(ns.T("gpset.resetall.ask"), ns.Penalties.Changed()), ns.T("gpset.resetall"), function()
        ns.Penalties.ResetAll()
        Reload()
    end)
end
local function TopButton(parent, name, width, label, onClick, kind)
    local b = ns.MakeButton(parent, name, kind)
    b:SetWidth(width)
    b:SetHeight(22)
    b.text:SetText(ns.T(label))
    b.onClick = onClick
    return b
end
local function HotBox(kind, anchor)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ns.Kit.Text(label, "text.title")
    label:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
    label:SetText(ns.Ledger.HotLabel(kind))
    local box = ns.Kit.Edit(frame, false, "HTP_FailWatchGPHot" .. kind)
    box:SetWidth(HOTW)
    box:SetHeight(20)
    box:SetNumeric(true)
    box:SetPoint("LEFT", label, "RIGHT", 6, 0)
    box:HookScript("OnEditFocusLost", function(self)
        ns.Ledger.SetHot(kind, ns.Ledger.Key(), tonumber(self:GetText()))
        self:SetText(tostring(ns.Ledger.HotSum(kind)))
        Changed()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ns.Ledger.HotSum(kind)))
        self:ClearFocus()
    end)
    hotBoxes[kind] = box
    return box
end
function View.Attach(host)
    frame = host
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ns.Kit.Text(searchLabel, "text.title")
    searchLabel:SetPoint("TOPLEFT", PAD, -12)
    searchLabel:SetText(ns.T("gpset.search"))
    searchBox = ns.Kit.Edit(frame, false, "HTP_FailWatchGPSearch")
    searchBox:SetWidth(150)
    searchBox:SetHeight(20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetScript("OnTextChanged", function(self) View.Search(self:GetText()) end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    local last = searchBox
    if ns.ProofView then
        local proofBtn = ns.ProofView.Setting(frame, "HTP_FailWatchGPProof")
        proofBtn:SetWidth(230)
        proofBtn:SetHeight(22)
        proofBtn:SetPoint("LEFT", searchBox, "RIGHT", 18, 0)
        last = proofBtn
    end
    local hotTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ns.Kit.Text(hotTitle, "text.title")
    hotTitle:SetPoint("LEFT", last, "RIGHT", 24, 0)
    hotTitle:SetText(ns.T("gpset.hot"))
    local anchor = hotTitle
    for i = 1, #ns.Ledger.HOT do anchor = HotBox(ns.Ledger.HOT[i], anchor) end
    guildText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildText:SetPoint("TOPLEFT", PAD, -44)
    guildText:SetWidth(360)
    guildText:SetJustifyH("LEFT")
    publishBtn = TopButton(frame, "HTP_FailWatchGPPublish", 220, "gpg.publish", DoPublish, "main")
    publishBtn:SetPoint("TOPLEFT", PAD + 370, -38)
    banner = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    banner:SetPoint("TOPLEFT", PAD, -72)
    ns.Kit.Text(banner, "badge.link")
    resetAllBtn = TopButton(frame, "HTP_FailWatchGPResetAll", 150, "gpset.resetall", DoResetAll, "danger")
    resetAllBtn:SetPoint("TOPLEFT", PAD + 370, -66)
    local cols = {
        { "rule", ns.T("gpset.col.rule"), 26 },
        { "mode", ns.T("gpset.col.mode"), 26 + TEXTW + 6 },
        { "sum", "", 26 + TEXTW + 6 + MODEW + 12 },
        { "wipe", ns.T("gpset.col.wipe"), 26 + TEXTW + 6 + MODEW + 12 + NUMW + 10 },
        { "step", ns.T("gpset.col.step"), 26 + TEXTW + 6 + MODEW + 12 + (NUMW + 10) * 2 },
        { "short", ns.T("gpset.col.short"), 26 + TEXTW + 6 + MODEW + 12 + (NUMW + 10) * 3 },
    }
    for i = 1, #cols do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ns.Kit.Text(fs, "text.title")
        fs:SetPoint("TOPLEFT", PAD + cols[i][3], -(HEAD - 14))
        fs:SetText(cols[i][2])
        heads[cols[i][1]] = fs
    end
    listBox = CreateFrame("Frame", nil, frame)
    listBox:SetPoint("TOPLEFT", PAD, -HEAD)
    listBox:SetPoint("BOTTOMRIGHT", -PAD, 30)
    listBox:EnableMouseWheel(true)
    listBox:SetScript("OnMouseWheel", function(_, delta) View.Scroll(delta) end)
    pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.Kit.Text(pageText, "text.off")
    pageText:SetPoint("BOTTOMRIGHT", -PAD, 10)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.Kit.Text(hint, "text.off")
    hint:SetPoint("BOTTOMLEFT", PAD, 10)
    hint:SetText(ns.T("gpset.hint"))
    if ns.GPGuild then ns.GPGuild.OnChange(function() View.Opened() end) end
    if ns.GPList then ns.GPList.OnChange(function() View.Refresh() end) end
end
function View.Opened()
    if not ns.Penalties or not frame then return end
    if ns.GPGuild and frame:IsVisible() then ns.GPGuild.Refresh() end
    BuildItems()
    View.Refresh()
end
