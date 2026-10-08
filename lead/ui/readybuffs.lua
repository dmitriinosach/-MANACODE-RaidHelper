local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local ICON = 11
local STEP = 12
local SLOTS = 4
local STRIP_H = 24
local STRIP_GAP = 6
local SEND_W = 70
local TIP_ICON = 14
local TIP_GIVERS = 2
local strip
local UI = {}
ns.ReadyUI = UI
local function iconTag(id)
    local tex = id and ns.Compat.SpellIcon(id)
    return tex and ("|T" .. tex .. ":" .. TIP_ICON .. "|t ") or ""
end
local function itemRow(it, res)
    local givers = res and (it.kind == "bless" and res.pals or (it.kind == "raid" and res.givers[it.key])) or nil
    return { kind = "row", left = iconTag(it.icon) .. ns.ReadyBuffs.Label(it),
        right = givers and #givers > 0 and ns.ReadyBuffs.Short(givers, TIP_GIVERS) or nil, tone = "dim" }
end
function UI.Build(c)
    c.rdyBg = ns.Fill(c, "BORDER")
    ns.PaintToken(c.rdyBg, "text.warn", 0.14)
    c.rdyBg:SetAllPoints()
    c.rdyBg:Hide()
    c.rdy = {}
    for i = 1, SLOTS do
        local t = c:CreateTexture(nil, "OVERLAY")
        t:SetSize(ICON, ICON)
        t:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 23 + (i - 1) * STEP, 3)
        t:Hide()
        c.rdy[i] = t
    end
    c.rdyMore = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.rdyMore:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 23 + (SLOTS - 1) * STEP, 2)
    ns.PaintText(c.rdyMore, "text.warn")
    c.rdyMore:Hide()
end
function UI.ClearCell(c)
    if not c.rdy then return end
    c.rdyBg:Hide()
    for _, t in ipairs(c.rdy) do t:Hide() end
    c.rdyMore:Hide()
    c.gs:Show()
end
function UI.TipRows(m)
    local R = ns.ReadyBuffs
    local e = R.Of(m.name)
    if not e then return nil end
    if e.why then return { { kind = "note", left = ns.T("rdyWhy_" .. e.why) } } end
    if #e.lack == 0 then return nil end
    local res = R.Result()
    local out = { { kind = "head", left = ns.T("rdyTipHead") } }
    for _, it in ipairs(e.lack) do out[#out + 1] = itemRow(it, res) end
    return out
end
function UI.FillCell(c, m)
    if not c.rdy then return end
    local e = ns.ReadyBuffs.Of(m.name)
    if not e or e.why then return end
    local n = #e.lack
    if n == 0 then return end
    c.gs:Hide()
    c.rdyBg:Show()
    local icons = n > SLOTS and SLOTS - 1 or n
    for i = 1, icons do
        ns.Kit.Icon.Spell(c.rdy[i], e.lack[i].icon)
        c.rdy[i]:Show()
    end
    if n > icons then
        c.rdyMore:SetText("+" .. (n - icons))
        c.rdyMore:Show()
    end
end
local function stripTip()
    local R = ns.ReadyBuffs
    local res = R.Result()
    local out = {}
    for _, line in ipairs(R.ChatLines()) do out[#out + 1] = line end
    local other = {}
    for _, e in ipairs(res.list) do
        for _, it in ipairs(e.lack) do
            if it.kind ~= "raid" and it.kind ~= "bless" then
                local label = R.Label(it)
                if not other[label] then
                    other[label] = {}
                    other[#other + 1] = label
                end
                local list = other[label]
                list[#list + 1] = e.name
            end
        end
    end
    for _, label in ipairs(other) do out[#out + 1] = label .. ": " .. table.concat(other[label], ", ") end
    local none = {}
    for _, e in ipairs(res.list) do
        if e.why then none[#none + 1] = e.name end
    end
    if #none > 0 then
        out[#out + 1] = ns.Hex("text.muted") .. ns.T("rdyStripNone", #none):gsub("^%s+", "")
            .. " — " .. table.concat(none, ", ") .. "|r"
    end
    out[#out + 1] = ns.Hex("text.muted") .. ns.T("rdyStripAge", math.floor(R.Age() or 0)) .. "|r"
    return table.concat(out, "\n")
end
function UI.BuildStrip(pane)
    strip = ns.MakePanel(pane)
    strip:SetHeight(STRIP_H)
    strip:EnableMouse(true)
    strip:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    strip:SetScript("OnLeave", ns.TipHide)
    strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.PaintText(strip.text, "text.bright")
    strip.text:SetPoint("LEFT", strip, "LEFT", 10, 0)
    strip.send = ns.MakeKitButton(strip)
    strip.send:SetSize(SEND_W, 18)
    strip.send:SetPoint("RIGHT", strip, "RIGHT", -4, 0)
    strip.send:SetText(ns.T("btnRdySend"))
    strip.send.tipTitle = ns.T("btnRdySend")
    strip.send.onClick = function() ns.ReadyBuffs.Send() end
    strip:Hide()
    return strip
end
function UI.FillStrip(pane, top)
    if not strip then return 0 end
    local R = ns.ReadyBuffs
    if not R.Active() then
        strip:Hide()
        return 0
    end
    local bad, seen, none = R.Counts()
    local text = bad > 0 and (ns.Hex("text.warn") .. ns.T("rdyStrip", bad, seen) .. "|r")
        or (ns.Hex("sem.ready") .. ns.T("rdyStripAll", seen) .. "|r")
    if none > 0 then text = text .. ns.Hex("text.muted") .. ns.T("rdyStripNone", none) .. "|r" end
    if R.Checking() then text = text .. ns.Hex("text.secondary") .. ns.T("rdyStripCheck") .. "|r" end
    strip.text:SetText(text)
    strip.tipTitle = ns.T("rdyStripTitle")
    strip.tip = stripTip()
    local lines = #R.ChatLines()
    strip.send.tip = ns.T(lines > 0 and "tipRdySend" or "tipRdyNothing")
    if lines > 0 then strip.send:Enable() else strip.send:Disable() end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -top)
    strip:SetWidth(ns.window.PANE_W)
    strip:Show()
    return STRIP_H + STRIP_GAP
end
function UI.Strip()
    return strip
end
function UI.Check()
    if InCombatLockdown() then
        ns.say(ns.T("tipInCombat"))
        return false
    end
    if not ns.ReadyBuffs.Scan() then
        ns.say(ns.T("tipRdyNoGroup"))
        return false
    end
    if root.Shell and root.Shell.Open then root.Shell.Open("raid") end
    return true
end
