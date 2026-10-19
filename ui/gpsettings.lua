local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local Kit = ns.Kit
local U = Kit.FontGrow
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
local searchLabel, proofBtn, hotTitle, hintText
local query = ""
local heads = {}
local hotBoxes = {}
local hotLabels = {}
local edits = {}
local rows = {}
local items = {}
local offset = 0
local slots = 0
local rowh, head = ROWH, HEAD
local placed
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
local function Track(box)
    edits[#edits + 1] = box
    local font = Kit.FontFor("ChatFontNormal", true)
    if font then box:SetFontObject(font) end
    return box
end
local function MakeBox(parent, name, width, what, field)
    local numeric = what ~= nil
    local box = Track(ns.Kit.Edit(parent, false, name))
    box:SetWidth(width)
    box:SetHeight(U(20))
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
local function Cols()
    local c = { text = U(26), num = U(NUMW), mode = U(MODEW), short = U(SHORTW), reset = U(RESETW), ctl = U(20) }
    local avail = frame and (frame:GetWidth() or 0) - PAD * 2 or 0
    if avail < 100 then avail = 1100 end
    local rest = c.text + 6 + c.mode + 12 + (c.num + 10) * 3 + c.short + 10 + c.reset
    c.tw = max(U(150), min(U(TEXTW), avail - rest))
    local x = c.text + c.tw + 6
    c.xMode = x
    x = x + c.mode + 12
    c.xSum = x
    x = x + c.num + 10
    c.xWipe = x
    x = x + c.num + 10
    c.xStep = x
    x = x + c.num + 10
    c.xShort = x
    x = x + c.short + 10
    c.xReset = x
    return c
end
local function PlaceRow(r, i, c)
    r:SetHeight(rowh)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -((i - 1) * rowh))
    r:SetPoint("TOPRIGHT", 0, -((i - 1) * rowh))
    r.check:SetWidth(U(22))
    r.check:SetHeight(U(22))
    r.text:SetWidth(c.tw)
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", c.text, 0)
    r.mode:SetWidth(c.mode)
    r.mode:SetHeight(c.ctl)
    r.mode:ClearAllPoints()
    r.mode:SetPoint("LEFT", c.xMode, 0)
    local at = { { r.gp, c.xSum, c.num }, { r.wipe, c.xWipe, c.num }, { r.step, c.xStep, c.num },
        { r.short, c.xShort, c.short } }
    for k = 1, #at do
        at[k][1]:SetWidth(at[k][3])
        at[k][1]:SetHeight(c.ctl)
        at[k][1]:ClearAllPoints()
        at[k][1]:SetPoint("LEFT", at[k][2], 0)
    end
    r.reset:SetWidth(c.reset)
    r.reset:SetHeight(c.ctl)
    r.reset:ClearAllPoints()
    r.reset:SetPoint("LEFT", c.xReset, 0)
end
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, listBox)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) View.Scroll(delta) end)
    r.head = Kit.Str(r, "GameFontNormal")
    ns.Kit.Text(r.head, "text.title")
    r.head:SetPoint("LEFT", 4, 0)
    r.check = ns.Kit.Check(r, "HTP_FailWatchGPCheck" .. i)
    r.check:SetPoint("LEFT", 0, 0)
    r.check.onToggle = function() OnCheck(r.check) end
    r.text = Kit.Str(r, "GameFontHighlightSmall")
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.mode = ns.MakeButton(r, "HTP_FailWatchGPMode" .. i, "quiet")
    Kit.Bind(r.mode.text, "GameFontNormalSmall")
    r.mode.onClick = function() OnMode(r) end
    r.gp = MakeBox(r, "HTP_FailWatchGPCost" .. i, NUMW, "sum")
    r.wipe = MakeBox(r, "HTP_FailWatchGPWipe" .. i, NUMW, "wipe")
    r.step = MakeBox(r, "HTP_FailWatchGPStep" .. i, NUMW, "step")
    r.short = MakeBox(r, "HTP_FailWatchGPShort" .. i, SHORTW, nil, "short")
    r.reset = ns.MakeButton(r, "HTP_FailWatchGPReset" .. i, "danger")
    Kit.Bind(r.reset.text, "GameFontNormalSmall")
    r.reset.text:SetText(ns.T("gpset.reset"))
    r.reset.onClick = function() OnReset(r) end
    PlaceRow(r, i, Cols())
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
local function Place()
    local w = floor(frame:GetWidth() or 0)
    local key = U(100) .. ":" .. w
    if placed == key then return end
    placed = key
    rowh = U(ROWH)
    local ctl, ctl2 = U(20), U(22)
    local c1, c2, c3 = U(18), U(49), U(77)
    searchLabel:ClearAllPoints()
    searchLabel:SetPoint("LEFT", frame, "TOPLEFT", PAD, -c1)
    searchBox:SetWidth(U(150))
    searchBox:SetHeight(ctl)
    local x1 = PAD + (searchLabel:GetStringWidth() or 0) + 6 + U(150)
    if proofBtn then
        proofBtn:SetWidth(U(230))
        proofBtn:SetHeight(ctl2)
        proofBtn:ClearAllPoints()
        proofBtn:SetPoint("LEFT", searchBox, "RIGHT", 18, 0)
        x1 = x1 + 18 + U(230)
    end
    local need = 24 + (hotTitle:GetStringWidth() or 0)
    for i = 1, #hotLabels do
        need = need + 14 + (hotLabels[i]:GetStringWidth() or 0) + 6 + U(HOTW)
    end
    local wrap = w > 0 and x1 + need > w - PAD
    head = wrap and U(HEAD) + U(24) or U(HEAD)
    hotTitle:ClearAllPoints()
    if wrap then
        hotTitle:SetPoint("LEFT", frame, "TOPLEFT", PAD, -U(101))
    else
        hotTitle:SetPoint("LEFT", proofBtn or searchBox, "RIGHT", 24, 0)
    end
    local anchor = hotTitle
    for i = 1, #hotLabels do
        local label, box = hotLabels[i], hotBoxes[hotLabels[i].kind]
        label:ClearAllPoints()
        label:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
        box:SetWidth(U(HOTW))
        box:SetHeight(ctl)
        box:ClearAllPoints()
        box:SetPoint("LEFT", label, "RIGHT", 6, 0)
        anchor = box
    end
    guildText:SetWidth(U(360))
    guildText:ClearAllPoints()
    guildText:SetPoint("LEFT", frame, "TOPLEFT", PAD, -c2)
    publishBtn:SetWidth(U(220))
    publishBtn:SetHeight(ctl2)
    publishBtn:ClearAllPoints()
    publishBtn:SetPoint("TOPLEFT", PAD + U(370), -U(38))
    banner:SetWidth(U(360))
    banner:ClearAllPoints()
    banner:SetPoint("LEFT", frame, "TOPLEFT", PAD, -c3)
    resetAllBtn:SetWidth(U(150))
    resetAllBtn:SetHeight(ctl2)
    resetAllBtn:ClearAllPoints()
    resetAllBtn:SetPoint("TOPLEFT", PAD + U(370), -U(66))
    listBox:ClearAllPoints()
    listBox:SetPoint("TOPLEFT", PAD, -head)
    listBox:SetPoint("BOTTOMRIGHT", -PAD, U(30))
    local cols = Cols()
    local at = { rule = cols.text, mode = cols.xMode, sum = cols.xSum, wipe = cols.xWipe, step = cols.xStep,
        short = cols.xShort }
    for name, fs in pairs(heads) do
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", frame, "TOPLEFT", PAD + at[name], -(head - U(8)))
    end
    pageText:ClearAllPoints()
    pageText:SetPoint("BOTTOMRIGHT", -PAD, U(10))
    hintText:ClearAllPoints()
    hintText:SetPoint("BOTTOMLEFT", PAD, U(10))
    for i = 1, #rows do PlaceRow(rows[i], i, cols) end
end
function View.Refresh()
    if not frame or not frame:IsVisible() then return end
    Place()
    RefreshHead()
    RefreshGuild()
    slots = max(1, floor(listBox:GetHeight() / rowh))
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
local function TopButton(parent, name, label, onClick, kind)
    local b = ns.MakeButton(parent, name, kind)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b.text:SetText(ns.T(label))
    b.onClick = onClick
    return b
end
local function HotBox(kind)
    local label = Kit.Str(frame, "GameFontNormalSmall")
    ns.Kit.Text(label, "text.title")
    label:SetText(ns.Ledger.HotLabel(kind))
    label.kind = kind
    hotLabels[#hotLabels + 1] = label
    local box = Track(ns.Kit.Edit(frame, false, "HTP_FailWatchGPHot" .. kind))
    box:SetNumeric(true)
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
end
function View.Attach(host)
    frame = host
    searchLabel = Kit.Str(frame, "GameFontNormalSmall")
    ns.Kit.Text(searchLabel, "text.title")
    searchLabel:SetText(ns.T("gpset.search"))
    searchBox = Track(ns.Kit.Edit(frame, false, "HTP_FailWatchGPSearch"))
    searchBox:SetScript("OnTextChanged", function(self) View.Search(self:GetText()) end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    if ns.ProofView then
        proofBtn = ns.ProofView.Setting(frame, "HTP_FailWatchGPProof")
        Kit.Bind(proofBtn.text, "GameFontNormalSmall")
    end
    hotTitle = Kit.Str(frame, "GameFontNormalSmall")
    ns.Kit.Text(hotTitle, "text.title")
    hotTitle:SetText(ns.T("gpset.hot"))
    for i = 1, #ns.Ledger.HOT do HotBox(ns.Ledger.HOT[i]) end
    guildText = Kit.Str(frame, "GameFontHighlightSmall")
    guildText:SetJustifyH("LEFT")
    guildText:SetWordWrap(false)
    publishBtn = TopButton(frame, "HTP_FailWatchGPPublish", "gpg.publish", DoPublish, "main")
    banner = Kit.Str(frame, "GameFontHighlightSmall")
    banner:SetJustifyH("LEFT")
    banner:SetWordWrap(false)
    ns.Kit.Text(banner, "badge.link")
    resetAllBtn = TopButton(frame, "HTP_FailWatchGPResetAll", "gpset.resetall", DoResetAll, "danger")
    local cols = {
        { "rule", ns.T("gpset.col.rule") },
        { "mode", ns.T("gpset.col.mode") },
        { "sum", "" },
        { "wipe", ns.T("gpset.col.wipe") },
        { "step", ns.T("gpset.col.step") },
        { "short", ns.T("gpset.col.short") },
    }
    for i = 1, #cols do
        local fs = Kit.Str(frame, "GameFontNormalSmall")
        ns.Kit.Text(fs, "text.title")
        fs:SetText(cols[i][2])
        heads[cols[i][1]] = fs
    end
    listBox = CreateFrame("Frame", nil, frame)
    listBox:EnableMouseWheel(true)
    listBox:SetScript("OnMouseWheel", function(_, delta) View.Scroll(delta) end)
    pageText = Kit.Str(frame, "GameFontDisableSmall")
    ns.Kit.Text(pageText, "text.off")
    hintText = Kit.Str(frame, "GameFontDisableSmall")
    ns.Kit.Text(hintText, "text.off")
    hintText:SetText(ns.T("gpset.hint"))
    frame.sized = true
    placed = nil
    Place()
    if ns.GPGuild then ns.GPGuild.OnChange(function() View.Opened() end) end
    if ns.GPList then ns.GPList.OnChange(function() View.Refresh() end) end
    Kit.OnFont(function()
        for i = 1, #edits do
            local font = Kit.FontFor("ChatFontNormal", true)
            if font then edits[i]:SetFontObject(font) end
        end
        placed = nil
        View.Refresh()
    end)
end
function View.Opened()
    if not ns.Penalties or not frame then return end
    if ns.GPGuild and frame:IsVisible() then ns.GPGuild.Refresh() end
    BuildItems()
    View.Refresh()
end
