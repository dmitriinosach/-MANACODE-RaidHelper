local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local PAD = 12
local HEAD = 120
local ROWH = 24
local WHEEL = 3
local TEXTW = 270
local NUMW = 52
local MODEW = 96
local REASONW = 200
local RESETW = 90
local MODES = { "once", "each", "grow" }
local View = {}
ns.GPSettings = View
local frame, listBox, presetBtn, nameBox, copyBtn, renameBtn, deleteBtn, banner, pageText
local guildText, publishBtn, epgpBox, addBtn
local rows = {}
local items = {}
local offset = 0
local slots = 0
local function Editable()
    return ns.Penalties.IsOwn(ns.Penalties.Active())
end
local function Changed()
    if ns.GPList then ns.GPList.Changed() end
end
local function BuildItems()
    items = {}
    local all = ns.Penalties.All()
    local lastBoss
    for i = 1, #all do
        local r = all[i]
        if r.boss ~= lastBoss then
            lastBoss = r.boss
            items[#items + 1] = { head = r.boss == ns.penaltyAny and ns.T("gpset.any") or ns.EncName(r.boss) }
        end
        items[#items + 1] = { rule = r }
    end
end
local function Reload()
    BuildItems()
    View.Refresh()
    Changed()
end
local function Commit(box, numeric)
    local key = box.editKey
    box.editKey = nil
    if not key or not Editable() then return end
    local text = box:GetText()
    local value
    if numeric then
        value = tonumber(text)
        if text == "" then value = nil end
        if value then value = floor(value + 0.5) end
    else
        value = text
    end
    ns.Penalties.Set(key, box.field, value)
    Reload()
end
local function MakeBox(parent, name, width, field, numeric)
    local box = ns.Kit.Edit(parent, false, name)
    box:SetWidth(width)
    box:SetHeight(20)
    box.field = field
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
    if not rule or not Editable() then return end
    ns.Penalties.Set(rule.key, "on", self:GetChecked() and true or false)
    Reload()
end
local function OnMode(row)
    local rule = row.rule
    if not rule or not Editable() then return end
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
    if not rule or not Editable() then return end
    if not ns.Penalties.IsOwnRule(rule.key) then
        if ns.Penalties.Reset(rule.key) then Reload() end
        return
    end
    if not ns.GPList then return end
    local key = rule.key
    ns.GPList.Confirm(format(ns.T("gpset.removeask"), ns.Penalties.Reason(rule)), ns.T("gpset.remove"), function()
        if ns.Penalties.RemoveRule(key) then Reload() end
    end)
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
    r.mode = ns.MakeButton(r, "HTP_FailWatchGPMode" .. i)
    r.mode:SetWidth(MODEW)
    r.mode:SetHeight(20)
    r.mode:SetPoint("LEFT", x, 0)
    r.mode.onClick = function() OnMode(r) end
    x = x + MODEW + 12
    r.gp = MakeBox(r, "HTP_FailWatchGPCost" .. i, NUMW, "gp", true)
    r.gp:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.wipe = MakeBox(r, "HTP_FailWatchGPWipe" .. i, NUMW, "wipe", true)
    r.wipe:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.step = MakeBox(r, "HTP_FailWatchGPStep" .. i, NUMW, "step", true)
    r.step:SetPoint("LEFT", x, 0)
    x = x + NUMW + 10
    r.reason = MakeBox(r, "HTP_FailWatchGPReason" .. i, REASONW, "reason", false)
    r.reason:SetPoint("LEFT", x, 0)
    x = x + REASONW + 10
    r.reset = ns.MakeButton(r, "HTP_FailWatchGPReset" .. i)
    r.reset:SetWidth(RESETW)
    r.reset:SetHeight(20)
    r.reset:SetPoint("LEFT", x, 0)
    r.reset.text:SetText(ns.T("gpset.reset"))
    r.reset.onClick = function() OnReset(r) end
    rows[i] = r
    return r
end
local function SetBox(box, value, editable)
    if not box:HasFocus() then box:SetText(value ~= nil and tostring(value) or "") end
    box:EnableMouse(editable)
    ns.Kit.Tone(box, editable and "text.bright" or "text.off")
end
local function FillRow(r, item, editable)
    local controls = { r.check, r.text, r.mode, r.gp, r.wipe, r.step, r.reason, r.reset }
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
    r.rule = rule
    r.check:SetChecked(rule.on and true or false)
    if editable then r.check:Enable() else r.check:Disable() end
    local label = ns.T(rule.text)
    if rule.kind == "manual" then label = label .. " " .. ns.Kit.Hex("text.note") .. ns.T("gpset.manual") .. "|r" end
    if rule.custom then label = label .. " " .. ns.Kit.Hex("text.note") .. ns.T("gpset.rule." .. rule.custom) .. "|r" end
    if rule.unverified then label = label .. " " .. ns.Kit.Hex("text.bad") .. "?|r" end
    r.text:SetText(label)
    ns.Kit.Tone(r.text, rule.on and "text.bright" or "text.off")
    r.mode.text:SetText(ns.T("gpset.mode." .. (rule.mode or "each")))
    if editable then r.mode:Enable() else r.mode:Disable() end
    SetBox(r.gp, rule.gp, editable)
    SetBox(r.wipe, rule.wipe, editable)
    SetBox(r.step, rule.step, editable)
    SetBox(r.reason, rule.reason, editable)
    local own = editable and ns.Penalties.IsOwnRule(rule.key)
    r.reset.text:SetText(ns.T(own and "gpset.remove" or "gpset.reset"))
    if not editable then
        r.reset:Hide()
    elseif own or ns.Penalties.IsChanged(rule.key) then
        r.reset:Enable()
    else
        r.reset:Disable()
    end
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
    if not epgpBox:HasFocus() then epgpBox:SetText(ns.Penalties.EpgpReason()) end
end
function View.Refresh()
    if not frame or not frame:IsVisible() then return end
    local active = ns.Penalties.Active()
    local editable = Editable()
    presetBtn.text:SetText(format(ns.T("gpset.preset"), ns.Penalties.Label(active)))
    if editable then
        banner:SetText(format(ns.T("gpset.own"), ns.Penalties.Label(ns.Penalties.BaseOf(active) or "")))
        renameBtn:Enable()
        deleteBtn:Enable()
        addBtn:Enable()
    else
        banner:SetText(ns.T("gpset.readonly"))
        renameBtn:Disable()
        deleteBtn:Disable()
        addBtn:Disable()
    end
    RefreshGuild()
    slots = max(1, floor(listBox:GetHeight() / ROWH))
    offset = max(0, min(offset, #items - slots))
    for i = 1, slots do
        local r = Row(i)
        local item = items[i + offset]
        if item then
            FillRow(r, item, editable)
            r:Show()
        else
            r:Hide()
        end
    end
    for i = slots + 1, #rows do rows[i]:Hide() end
    pageText:SetText(format(ns.T("gpset.page"), offset + 1, min(#items, offset + slots), #items))
end
function View.Scroll(delta)
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus.editKey then focus:ClearFocus() end
    offset = offset - delta * WHEEL
    View.Refresh()
end
local function PresetMenu()
    local menu = { { text = ns.T("gpset.pick"), isTitle = true, notCheckable = true } }
    local names = ns.Penalties.Names()
    local active = ns.Penalties.Active()
    for i = 1, #names do
        local name = names[i]
        menu[#menu + 1] = {
            text = ns.Penalties.Label(name),
            checked = name == active,
            func = function()
                ns.Penalties.Select(name)
                offset = 0
                Reload()
            end,
        }
    end
    ns.Kit.Menu(menu, presetBtn)
end
local function TypedName()
    local name = ns.Penalties.Clean(nameBox:GetText())
    if name == "" then
        ns.Print(ns.T("gpset.noname"))
        return nil
    end
    if ns.Penalties.Taken(name, ns.Penalties.Active()) then
        ns.Print(format(ns.T("gpset.taken"), name))
        return nil
    end
    return name
end
local function Typed()
    nameBox:SetText("")
    nameBox:ClearFocus()
end
local function DoCopy()
    local name = TypedName()
    if not name or not ns.Penalties.Copy(name) then
        if name then ns.Print(format(ns.T("gpset.taken"), name)) end
        return
    end
    Typed()
    offset = 0
    Reload()
end
local function DoRename()
    local old = ns.Penalties.Active()
    if not ns.Penalties.IsOwn(old) then return end
    if ns.Penalties.Clean(nameBox:GetText()) == old then return Typed() end
    local name = TypedName()
    if not name then return end
    if not ns.Penalties.Rename(old, name) then
        ns.Print(format(ns.T("gpset.taken"), name))
        return
    end
    Typed()
    Reload()
end
local function DoDelete()
    local name = ns.Penalties.Active()
    if not ns.Penalties.IsOwn(name) or not ns.GPList then return end
    ns.GPList.Confirm(format(ns.T("gpset.delask"), name), ns.T("gpset.delete"), function()
        if ns.Penalties.Delete(name) then
            offset = 0
            Reload()
        end
    end)
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
    local label = ns.Penalties.Label(ns.Penalties.Active())
    ns.GPList.Confirm(format(ns.T("gpg.ask"), label, v), ns.T("gpg.yes"), function()
        local _, key, a, b = G.Publish()
        ns.Print(format(ns.T(key), a or 0, b or 0))
        Reload()
    end)
end
local function AddRule(boss)
    local key = ns.Penalties.AddRule(boss)
    if not key then return end
    BuildItems()
    for i = 1, #items do
        if items[i].rule and items[i].rule.key == key then offset = i - 1 end
    end
    View.Refresh()
    Changed()
end
local function AddMenu()
    if not Editable() then return end
    local menu = { { text = ns.T("gpset.addpick"), isTitle = true, notCheckable = true } }
    local seen = {}
    for i = 1, #items do
        local rule = items[i].rule
        if rule and not seen[rule.boss] then
            seen[rule.boss] = true
            local boss = rule.boss
            menu[#menu + 1] = {
                text = boss == ns.penaltyAny and ns.T("gpset.any") or ns.EncName(boss),
                func = function() AddRule(boss) end,
            }
        end
    end
    ns.Kit.Menu(menu, addBtn)
end
local function CommitEpgp()
    ns.Penalties.SetEpgpReason(epgpBox:GetText())
    RefreshGuild()
end
local function TopButton(parent, name, width, label, onClick)
    local b = ns.MakeButton(parent, name)
    b:SetWidth(width)
    b:SetHeight(22)
    b.text:SetText(ns.T(label))
    b.onClick = onClick
    return b
end
function View.Attach(host)
    frame = host
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -12)
    title:SetText(ns.T("gpset.title"))
    presetBtn = TopButton(frame, "HTP_FailWatchGPPreset", 240, "gpset.pick", PresetMenu)
    presetBtn:SetPoint("TOPLEFT", PAD - 2, -34)
    nameBox = ns.Kit.Edit(frame, false, "HTP_FailWatchGPNewName")
    nameBox:SetWidth(160)
    nameBox:SetHeight(22)
    nameBox:SetPoint("LEFT", presetBtn, "RIGHT", 18, 0)
    nameBox:SetScript("OnEnterPressed", DoCopy)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    copyBtn = TopButton(frame, "HTP_FailWatchGPCopy", 150, "gpset.copy", DoCopy)
    copyBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    renameBtn = TopButton(frame, "HTP_FailWatchGPRename", 120, "gpset.rename", DoRename)
    renameBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    deleteBtn = TopButton(frame, "HTP_FailWatchGPDelete", 90, "gpset.delete", DoDelete)
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 6, 0)
    if ns.ProofView then
        local proofBtn = ns.ProofView.Setting(frame, "HTP_FailWatchGPProof")
        proofBtn:SetWidth(200)
        proofBtn:SetHeight(22)
        proofBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 18, 0)
    end
    guildText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildText:SetPoint("TOPLEFT", PAD, -66)
    guildText:SetWidth(360)
    guildText:SetJustifyH("LEFT")
    publishBtn = TopButton(frame, "HTP_FailWatchGPPublish", 220, "gpg.publish", DoPublish)
    publishBtn:SetPoint("TOPLEFT", PAD + 370, -60)
    local epgpLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epgpLabel:SetPoint("LEFT", publishBtn, "RIGHT", 18, 0)
    epgpLabel:SetText(ns.T("gpset.epgp"))
    epgpBox = ns.Kit.Edit(frame, false, "HTP_FailWatchGPEpgp")
    epgpBox:SetWidth(110)
    epgpBox:SetHeight(22)
    epgpBox:SetPoint("LEFT", epgpLabel, "RIGHT", 8, 0)
    epgpBox:HookScript("OnEditFocusLost", CommitEpgp)
    epgpBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    epgpBox:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.Penalties.EpgpReason())
        self:ClearFocus()
    end)
    addBtn = TopButton(frame, "HTP_FailWatchGPAdd", 150, "gpset.add", AddMenu)
    addBtn:SetPoint("LEFT", epgpBox, "RIGHT", 18, 0)
    banner = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    banner:SetPoint("TOPLEFT", PAD, -92)
    ns.Kit.Text(banner, "badge.link")
    local heads = {
        { ns.T("gpset.col.rule"), 26 },
        { ns.T("gpset.col.mode"), 26 + TEXTW + 6 },
        { ns.T("gpset.col.gp"), 26 + TEXTW + 6 + MODEW + 12 },
        { ns.T("gpset.col.wipe"), 26 + TEXTW + 6 + MODEW + 12 + NUMW + 10 },
        { ns.T("gpset.col.step"), 26 + TEXTW + 6 + MODEW + 12 + (NUMW + 10) * 2 },
        { ns.T("gpset.col.reason"), 26 + TEXTW + 6 + MODEW + 12 + (NUMW + 10) * 3 },
    }
    for i = 1, #heads do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", PAD + heads[i][2], -(HEAD - 14))
        fs:SetText(heads[i][1])
    end
    listBox = CreateFrame("Frame", nil, frame)
    listBox:SetPoint("TOPLEFT", PAD, -HEAD)
    listBox:SetPoint("BOTTOMRIGHT", -PAD, 30)
    listBox:EnableMouseWheel(true)
    listBox:SetScript("OnMouseWheel", function(_, delta) View.Scroll(delta) end)
    pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pageText:SetPoint("BOTTOMRIGHT", -PAD, 10)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", PAD, 10)
    hint:SetText(ns.T("gpset.hint"))
    if ns.GPGuild then ns.GPGuild.OnChange(function() View.Opened() end) end
end
function View.Opened()
    if not ns.Penalties or not frame then return end
    if ns.GPGuild and frame:IsVisible() then ns.GPGuild.Refresh() end
    BuildItems()
    View.Refresh()
end
