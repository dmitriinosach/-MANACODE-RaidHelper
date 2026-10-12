local _, ns = ...
local format = string.format
local tinsert = table.insert
local tremove = table.remove
local ICON_SPELL = 47528
local ICON = "Interface\\Icons\\Spell_DeathKnight_MindFreeze"
local CHECK = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local CROSS = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
local GLYPH = "|T%s:14:14:0:0:64:64:5:59:5:59|t "
local ERRORS = { limit = true, budget = true, guild = true, parse = true, busy = true, timeout = true, norec = true }
local BUSY = { queue = true, build = true, wait = true }
local LIST_MAX = 5
local SEP = " / "
local NONE = "—"
local GRADE_TONE = { ["справедливо"] = "text.bad", ["спорно"] = "text.warn", ["несправедливо"] = "text.good" }
local View = {}
ns.FableView = View
local hovered
local buttons = setmetatable({}, { __mode = "k" })
local counters = setmetatable({}, { __mode = "k" })
local function T(key)
    return ns.T(key)
end
function View.Icon()
    local icon = GetSpellInfo and select(3, GetSpellInfo(ICON_SPELL))
    return icon or ICON
end
function View.Ask(fight, who, at, rule, reason, grade)
    if not (fight and who and at and ns.Fable) then return nil end
    return ns.Fable.Make(fight, who, at, rule, reason, grade)
end
local function List(x)
    if not x then return {} end
    if x.key then return { x } end
    return x
end
local function Verdict(st)
    local v = st.verdict ~= "" and st.verdict or T("fable.none")
    if not st.grade then return v end
    local token = GRADE_TONE[st.grade]
    local g = (token and ns.Kit and ns.Kit.Hex) and (ns.Kit.Hex(token) .. st.grade .. "|r") or st.grade
    local parts = { g }
    if st.could and st.could ~= "" and st.could ~= NONE then parts[#parts + 1] = st.could end
    parts[#parts + 1] = v
    return table.concat(parts, SEP)
end
local function Value(st)
    if not st then return T("fable.none"), "dim" end
    if st.st == "queue" then return T("fable.queue"), "dim" end
    if BUSY[st.st] then return T("fable.wait"), "dim" end
    if st.st == "done" then return Verdict(st), nil end
    local code = st.code or "?"
    if code == "offline" then return format(T("fable.err.offline"), ns.Fable.Bot()), "bad" end
    if ERRORS[code] then return T("fable.err." .. code), "bad" end
    return format(T("fable.err.other"), code), "bad"
end
local function Item(ask, k)
    local st = ns.Fable.State(ask.key)
    local when = ask.at and ns.BadgeTips.Clock(ask.at - ask.fight.from) or T("ft.whole")
    local head = format("%d. %s ", k, when)
    if st and st.st == "done" then
        local x = (st.text and st.text ~= "") and (" — " .. st.text) or ""
        return head .. Verdict(st) .. x
    end
    return head .. (Value(st))
end
local function Done(asks)
    local n = 0
    for i = 1, #asks do
        local st = ns.Fable.State(asks[i].key)
        if st and st.st == "done" then n = n + 1 end
    end
    return n
end
local function After(lines)
    local when = T("sum.tt.when")
    for i = 1, #lines do
        if lines[i].kind == "row" and lines[i].left == when then return i end
    end
    for i = 1, #lines do
        if lines[i].kind == "row" then return i end
    end
    return #lines
end
local function FillRow(lines, i, asks)
    local l = lines[i]
    while lines[i + 1] and lines[i + 1].fableSub do tremove(lines, i + 1) end
    if #asks == 1 then
        local st = ns.Fable.State(asks[1].key)
        l.right, l.tone = Value(st)
        if st and st.st == "done" and st.text and st.text ~= "" then
            tinsert(lines, i + 1, { kind = "sub", left = st.text, fableSub = true })
        end
        return
    end
    local done = Done(asks)
    l.right, l.tone = format(T("fable.count"), done, #asks), done < #asks and "dim" or nil
    local n = math.min(LIST_MAX, #asks)
    for k = 1, n do tinsert(lines, i + k, { kind = "sub", left = Item(asks[k], k), fableSub = true }) end
    if #asks > n then
        tinsert(lines, i + n + 1, { kind = "sub", left = format(T("fable.more"), #asks - n), fableSub = true })
    end
end
function View.Fill(lines)
    for i = #lines, 1, -1 do
        local l = lines[i]
        if l.fable then
            FillRow(lines, i, l.fable)
        elseif l.fableHint then
            local asks = l.fableHint
            l.left = T(Done(asks) == #asks and "fable.hint.again" or "fable.hint")
        end
    end
end
function View.Put(lines, asks)
    if not ns.Fable.On() then return lines end
    asks = List(asks)
    if #asks == 0 then return lines end
    tinsert(lines, After(lines) + 1, { kind = "row", left = format(GLYPH, View.Icon()) .. T("fable.row"), fable = asks })
    lines[#lines + 1] = { kind = "foot", left = T("fable.hint"), fableHint = asks }
    View.Fill(lines)
    return lines
end
function View.Enter(owner)
    hovered = owner
    if owner.lines then View.Fill(owner.lines) end
end
function View.Leave(owner)
    if not owner or hovered == owner then hovered = nil end
end
local function Reshow(owner)
    local fn = owner:GetScript("OnEnter")
    if fn then fn(owner) end
end
local function AskList(asks, again)
    local pick = {}
    for i = 1, #asks do
        local st = ns.Fable.State(asks[i].key)
        if not st or st.st == "err" or (again and st.st == "done") then pick[#pick + 1] = asks[i] end
    end
    return ns.Fable.AskAll(pick)
end
function View.Click(owner, button, asks)
    if button ~= "LeftButton" or not (IsAltKeyDown and IsAltKeyDown()) or not ns.Fable.On() then return false end
    asks = List(asks or owner.fable)
    if #asks == 0 then return false end
    AskList(asks, Done(asks) == #asks)
    hovered = owner
    Reshow(owner)
    return true
end
local function Paint(b)
    local asks = b.asks or {}
    local busy, err = false, false
    for i = 1, #asks do
        local st = ns.Fable.State(asks[i].key)
        if st and BUSY[st.st] then busy = true end
        if st and st.st == "err" then err = true end
    end
    local all = #asks > 0 and Done(asks) == #asks
    local tone
    for i = 1, all and #asks or 0 do
        local st = ns.Fable.State(asks[i].key)
        local t = st and GRADE_TONE[st.grade or ""]
        if t and (not tone or t == "text.bad" or (t == "text.warn" and tone == "text.good")) then tone = t end
    end
    b.tint:Hide()
    if busy then
        b.icon:Hide()
        b.mark:Hide()
        b.dots:Show()
        return
    end
    b.dots:Hide()
    b.icon:Show()
    b.icon:SetDesaturated(all and true or false)
    if all or err then
        if tone then
            ns.Kit.Hue(b.tint, tone)
            b.tint:Show()
            b.mark:Hide()
        else
            b.mark:SetTexture(all and CHECK or CROSS)
            b.mark:Show()
            b.tint:Hide()
        end
    else
        b.mark:Hide()
    end
end
local function ButtonClick(b)
    local asks = b.asks or {}
    if #asks == 0 then return end
    AskList(asks, false)
    Paint(b)
    if b.row then
        hovered = b.row
        Reshow(b.row)
    end
end
local function ButtonEnter(b)
    local row = b.row
    local fn = row and row:GetScript("OnEnter")
    if fn then fn(row) end
end
local function ButtonLeave(b)
    local row = b.row
    local fn = row and row:GetScript("OnLeave")
    if fn then fn(row) end
end
function View.Button(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b:RegisterForClicks("LeftButtonUp")
    b.row, b.asks = false, {}
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(View.Icon())
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetWidth(size * 0.7)
    b.mark:SetHeight(size * 0.7)
    b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
    b.mark:Hide()
    b.tint = b:CreateTexture(nil, "OVERLAY")
    b.tint:SetTexture(CHECK)
    b.tint:SetWidth(size * 0.7)
    b.tint:SetHeight(size * 0.7)
    b.tint:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
    b.tint:Hide()
    b.dots = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.dots:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.dots:SetText(T("fable.dots"))
    ns.Kit.Text(b.dots, "text.muted")
    b.dots:Hide()
    b:SetScript("OnClick", ButtonClick)
    b:SetScript("OnEnter", ButtonEnter)
    b:SetScript("OnLeave", ButtonLeave)
    buttons[b] = true
    return b
end
function View.SetButton(b, asks)
    b.asks = List(asks)
    Paint(b)
end
function View.CountText()
    local n = ns.Fable and ns.Fable.On() and ns.Fable.Queued() or 0
    return n > 0 and format(T("fable.queued"), n) or ""
end
function View.Counter(fs)
    counters[fs] = true
    fs:SetText(View.CountText())
end
local function Has(owner, key)
    local asks = List(owner.fable)
    for i = 1, #asks do
        if asks[i].key == key then return true end
    end
    return false
end
local function OnChange(key)
    local text = View.CountText()
    for fs in pairs(counters) do fs:SetText(text) end
    for b in pairs(buttons) do
        if b:IsShown() and b.asks then
            for i = 1, #b.asks do
                if b.asks[i].key == key then
                    Paint(b)
                    break
                end
            end
        end
    end
    local owner = hovered
    if owner and owner:IsVisible() and Has(owner, key) then Reshow(owner) end
end
ns.Fable.OnChange(OnChange)
ns.Shell.Command("fable", function(arg)
    if not ns.Fable.On() then
        ns.Print(T(ns.Fable.Guild() and "fable.off" or "fable.noguild"))
        return
    end
    if arg == "" then
        ns.Print(format(T("fable.bot.now"), ns.Fable.Bot()))
        return
    end
    local name = ns.Fable.SetBot(arg)
    if name then ns.Print(format(T("fable.bot.set"), name)) end
    if ns.Settings and ns.Settings.Refresh then ns.Settings.Refresh() end
end, function() return T("fable.cmd") end)
local function Modes()
    local out = {}
    for i = 1, #ns.Fable.MODE_LIST do
        local k = ns.Fable.MODE_LIST[i]
        out[i] = { key = k, label = "fable.auto." .. k }
    end
    return out
end
local S = ns.Settings
if S and S.Section then
    S.Section("guild", "fable", {
        label = "fable.set",
        order = 30,
        shown = ns.Fable.Guild,
        items = {
            { kind = "check", key = "on", label = "fable.set.on", tip = "fable.set.on.tip", default = false,
              get = function() return ns.GetDB().settings.fableOn == true end,
              set = function(v)
                  ns.Fable.SetOn(v)
                  OnChange("")
                  if S.Refresh then S.Refresh() end
              end },
            { kind = "field", key = "bot", label = "fable.set.bot", tip = "fable.set.bot.tip", width = 160,
              maxLetters = 24, default = ns.Fable.BOT, enabled = ns.Fable.On,
              get = function() return ns.Fable.Bot() end,
              set = function(v) ns.Fable.SetBot(v) end },
            { kind = "choice", key = "auto", buttons = true, label = "fable.set.auto", tip = "fable.set.auto.tip",
              options = Modes, enabled = ns.Fable.On,
              get = function() return ns.Fable.Mode() end,
              set = function(k) ns.Fable.SetMode(k) end },
        },
    })
end
