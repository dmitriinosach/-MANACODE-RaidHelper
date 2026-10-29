local _, ns = ...
local format = string.format
local floor = math.floor
local concat = table.concat
local W = 236
local PAD = 8
local GAP = 4
local BTN_H = 20
local LINE_GAP = 3
local GLOW = "Interface\\Buttons\\CheckButtonHilight"
local GLOW_OUT = 6
local F = ns.Flasks
local Trade = ns.FlaskTrade
local Kit = ns.Kit
local S = ns.Settings
local T = ns.T
local View = {}
ns.FlaskView = View
local pop, title, who, line, warn, glow, glowTex
local kindBtn = {}
local forceBtn, acceptBtn, cancelBtn
local function Word(n, key)
    return ns.Plural and ns.Plural(n, T(key)) or T(key)
end
function View.Given()
    local n, people = F.Stats()
    return format(T("flask.set.given"), n, Word(n, "flask.w.flask"), people, Word(people, "flask.w.people"))
end
function View.LogLines()
    local rows = F.Rows()
    if #rows == 0 then return { T("flask.log.empty") } end
    local n, people = F.Stats()
    local out = { format(T("flask.log.head"), n, Word(n, "flask.w.flask"), people, Word(people, "flask.w.people")) }
    for i = 1, #rows do
        local r = rows[i]
        local parts = {}
        for id, c in pairs(r.items) do
            parts[#parts + 1] = F.ItemName(F.ById(id) or { id = id, name = tostring(id) }) .. " x" .. c
        end
        table.sort(parts)
        local hand = r.hand > 0 and format(T("flask.log.hand"), r.hand) or ""
        out[#out + 1] = format(T("flask.log.row"), r.name, r.n, concat(parts, ", "), date("%H:%M", r.last)) .. hand
    end
    out[#out + 1] = T("flask.log.note")
    return out
end
local function Short(it)
    return T("flask.short." .. it.key)
end
function View.BagLine()
    local list = F.Bags()
    local parts = {}
    for i = 1, #list do
        local e = list[i]
        local s = Short(e.item) .. " " .. e.n
        parts[i] = e.n > 0 and s or (Kit.Hex("text.warn") .. s .. "|r")
    end
    return format(T("flask.bags"), concat(parts, ", "))
end
function View.AnnounceText()
    local norm = F.Norm(UnitName("player") or "")
    return format(T("flask.say"), norm)
end
function View.Announce()
    if not F.IsOn() or not F.InGroup() then return end
    SendChatMessage(View.AnnounceText(), (GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY")
end
function View.PrintLog()
    local lines = View.LogLines()
    for i = 1, #lines do ns.Print(lines[i]) end
end
local function LogTip()
    return concat(View.LogLines(), "\n")
end
local function StatusText(s)
    local st = s.status or "wait"
    local item = F.ItemName(s.item)
    if (s.put or 0) > 1 then item = item .. " x" .. s.put end
    if st == "placed" or st == "accepting" or st == "accepted" or st == "press" then
        return format(T("flask.st." .. st), item)
    end
    if st == "wait" or st == "offer" or st == "stranger" or st == "combat" or st == "removed" or st == "split" then
        return T("flask.st." .. st)
    end
    if st == "many" then return format(T("flask.st.many"), s.many or 0) end
    if st == "cursor" or st == "full" or st == "pick" or st == "nosplit" or st == "bags" then
        return format(T("flask.put." .. st), F.ItemName(s.plan and s.plan.item))
    end
    if s.plan then return Trade.Reason(s.plan) end
    return ""
end
local function WhoText(s)
    local p = s.plan
    if not p then return s.partner or "" end
    local alch = p.alch and T("flask.pop.alch") or ""
    if not p.kind then return format(T("flask.pop.who.none"), p.name, p.n, p.norm) .. alch end
    return format(T("flask.pop.who"), p.name, T("flask.kind." .. p.kind), T("flask.src." .. (p.src or "hand")),
        p.n, p.norm) .. alch
end
local function HandText(s)
    local parts
    for i = 1, #(s.armed or {}) do
        local a = s.armed[i]
        if a.manual then
            parts = parts or {}
            parts[#parts + 1] = F.ItemName(a.item) .. " x" .. a.count
        end
    end
    return parts and format(T("flask.st.hand"), concat(parts, ", ")) or nil
end
local function Layout()
    local U = ns.Kit.FontGrow
    local w, pad, gap, bh = U(W), U(PAD), U(GAP), U(BTN_H)
    pop:SetWidth(w)
    local y = -pad
    local inner = w - pad * 2
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", pad, y)
    y = y - title:GetStringHeight() - LINE_GAP
    for _, fs in ipairs({ who, line, warn }) do
        fs:SetWidth(inner)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", pad, y)
        if fs:IsShown() then y = y - floor(fs:GetStringHeight() + 0.5) - LINE_GAP end
    end
    y = y - gap
    local bw = floor((inner - gap * 2) / 3)
    for i, kind in ipairs(ns.flaskKinds) do
        local b = kindBtn[kind]
        b:SetWidth(bw)
        b:SetHeight(bh)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pad + (i - 1) * (bw + gap), y)
    end
    y = y - bh - gap
    local half = floor((inner - gap) / 2)
    forceBtn:SetWidth(half)
    forceBtn:SetHeight(bh)
    forceBtn:ClearAllPoints()
    forceBtn:SetPoint("TOPLEFT", pad, y)
    acceptBtn:SetWidth(half)
    acceptBtn:SetHeight(bh)
    acceptBtn:ClearAllPoints()
    acceptBtn:SetPoint("TOPLEFT", pad + half + gap, y)
    y = y - bh
    if cancelBtn:IsShown() then
        y = y - gap
        cancelBtn:SetWidth(inner)
        cancelBtn:SetHeight(bh)
        cancelBtn:ClearAllPoints()
        cancelBtn:SetPoint("TOPLEFT", pad, y)
        y = y - bh
    end
    y = y - pad
    pop:SetHeight(-y)
end
local function Label(parent, token)
    local fs = Kit.Str(parent, "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function Btn(text, tip, run)
    local b = Kit.Button(pop)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetHeight(BTN_H)
    b:SetText(text)
    b.tipTitle = text
    b.tip = tip
    b.onClick = function() run() end
    return b
end
local function Build()
    pop = CreateFrame("Frame", nil, UIParent)
    pop:SetFrameStrata("DIALOG")
    pop:SetClampedToScreen(true)
    pop:EnableMouse(true)
    pop.sized = true
    Kit.Skin(pop, "float")
    title = Kit.Str(pop, "GameFontNormalSmall")
    Kit.Title(title)
    title:SetText(T("flask.pop.title"))
    who = Label(pop, "text.primary")
    line = Label(pop, "text.secondary")
    warn = Label(pop, "text.warn")
    for _, kind in ipairs(ns.flaskKinds) do
        kindBtn[kind] = Btn(T("flask.kind." .. kind), T("flask.kind.tip"), function() Trade.Choose(kind) end)
    end
    forceBtn = Btn(T("flask.btn.force"), T("flask.btn.force.tip"), Trade.Force)
    acceptBtn = Btn(T("flask.btn.accept"), T("flask.btn.accept.tip"), Trade.Accept)
    cancelBtn = Btn(T("flask.btn.cancel"), T("flask.btn.cancel.tip"), Trade.Cancel)
    glow = CreateFrame("Frame", nil, pop)
    glowTex = glow:CreateTexture(nil, "OVERLAY")
    glowTex:SetTexture(GLOW)
    glowTex:SetBlendMode("ADD")
    glowTex:SetAllPoints()
    Kit.Tint(glowTex, "badge.link")
    glow:Hide()
    pop:Hide()
end
local function Place()
    pop:ClearAllPoints()
    local tf = TradeFrame
    if tf and tf.IsShown and tf:IsShown() then
        pop:SetPoint("TOPLEFT", tf, "TOPRIGHT", -30, -12)
    else
        pop:SetPoint("CENTER", UIParent, "CENTER", 260, 80)
    end
end
local function Glow(on)
    local btn = TradeFrameTradeButton
    if not on or not btn then
        glow:Hide()
        return
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -GLOW_OUT, GLOW_OUT)
    glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", GLOW_OUT, -GLOW_OUT)
    glow:Show()
end
function View.Refresh()
    local s = Trade.State()
    if not s.open or not s.partner or not F.IsOn() then
        if pop then pop:Hide() end
        return
    end
    if not pop then Build() end
    who:SetText(WhoText(s))
    line:SetText(StatusText(s))
    local p = s.plan
    local notes = {}
    if s.otherGuild then
        notes[#notes + 1] = format(T("flask.warn.guild"), s.partner, s.guild or T("flask.guild.none"))
    end
    if p and p.warn == "own" then notes[#notes + 1] = format(T("flask.warn.own"), p.name, p.has or 0) end
    if s.status == "press" and s.press then notes[#notes + 1] = T("flask.press." .. s.press) end
    local hand = HandText(s)
    if hand then notes[#notes + 1] = hand end
    if #notes > 0 then
        warn:SetText(concat(notes, "\n"))
        warn:Show()
    else
        warn:Hide()
    end
    local kind = s.kind or (p and p.kind)
    for k, b in pairs(kindBtn) do b:SetActive(k == kind) end
    local placed = (s.put or 0) > 0
    local st = s.status or "wait"
    if not placed and not s.armed and st ~= "wait" and st ~= "split" then cancelBtn:Show() else cancelBtn:Hide() end
    if p and not placed and p.item and p.n < p.limit and s.status ~= "combat" and s.status ~= "stranger" then
        forceBtn:Enable()
    else
        forceBtn:Disable()
    end
    local press = s.status == "press"
    if placed and not s.accepted and s.status ~= "combat" then acceptBtn:Enable() else acceptBtn:Disable() end
    acceptBtn:SetActive(press)
    Place()
    Layout()
    Glow(press)
    pop:Show()
end
function View.IsShown()
    return pop ~= nil and pop:IsShown() and true or false
end
function View.Buttons()
    return { kindBtn.tank, kindBtn.sp, kindBtn.ap, forceBtn, acceptBtn, cancelBtn }
end
function View.Note()
    if not pop or not warn:IsShown() then return "" end
    return warn:GetText() or ""
end
function View.Lines()
    if not pop then return "", "" end
    return who:GetText() or "", line:GetText() or ""
end
function View.Glowing()
    return glow ~= nil and glow:IsShown() and true or false
end
Trade.OnChange(View.Refresh)
Kit.OnFont(function()
    if pop and pop:IsShown() then Layout() end
end)
F.OnChange(function()
    View.Refresh()
    if S and S.Refresh then S.Refresh() end
end)
local function Switch(on)
    Trade.Switch(on)
end
local function Rows()
    return {
        { id = "flasks", title = T("flask.act.row"), items = {
            {
                id = "toggle",
                label = T("flask.act.toggle"),
                title = T("set.cat.flasks"),
                tip = function() return T("flask.act.toggle.tip") .. "\n\n" .. View.BagLine() end,
                state = function()
                    local on = F.IsOn()
                    if not on and not F.InGroup() then return false, T("flask.act.nogroup"), false end
                    return true, nil, on
                end,
                run = function() Switch(not F.IsOn()) end,
            },
            {
                id = "say",
                label = T("flask.act.say"),
                title = T("flask.act.say"),
                tip = function() return format(T("flask.act.say.tip"), View.AnnounceText()) end,
                state = function()
                    if not F.InGroup() then return false, T("flask.act.nogroup"), false end
                    if not F.IsOn() then return false, T("flask.act.say.off"), false end
                    return true, nil, false
                end,
                run = View.Announce,
            },
            {
                id = "log",
                label = T("flask.act.log"),
                title = View.Given(),
                tip = T("flask.act.log.tip"),
                state = function() return true end,
                run = View.PrintLog,
            },
        } },
    }
end
if ns.Shell and ns.Shell.Actions then ns.Shell.Actions(Rows, 100) end
local function Command(arg)
    local sub = (arg or ""):match("^(%S*)")
    if sub == "log" then
        View.PrintLog()
    elseif sub == "reset" then
        F.Reset()
        ns.Print(T("flask.log.reset"))
    else
        Switch(not F.IsOn())
    end
end
if ns.Shell and ns.Shell.Command then
    ns.Shell.Command("flasks", Command, function() return T("cmd.flasks") end)
end
local function ItemOptions()
    local out = {}
    for i = 1, #ns.flaskItems do
        local it = ns.flaskItems[i]
        out[i] = { key = it.key, label = function() return F.ItemName(it) end }
    end
    return out
end
local function KindItem(kind, order)
    return { kind = "choice", key = kind, label = "flask.set.what." .. kind, tip = "flask.set.what.tip",
             options = ItemOptions, default = ns.flaskDefault[kind], order = order,
             get = function() return F.ItemKey(kind) end,
             set = function(k) F.SetItem(kind, k) end }
end
local function Slider(key, label, lo, hi, step, fmt, order)
    return { kind = "slider", key = key, label = label, tip = label .. ".tip", min = lo, max = hi, step = step,
             fmt = fmt, default = F.DEF[key], order = order,
             get = function() return F.Get(key) end,
             set = function(v) F.Set(key, v) end }
end
local function Hours(v)
    local s = v == floor(v) and format("%d", v) or ns.Dec(format("%.1f", v))
    return format(T("flask.unit.hours"), s)
end
local function Pcs(v)
    return format(T("flask.unit.pcs"), v)
end
if S and S.Category then
    S.Category("flasks", { label = "set.cat.flasks", sub = "set.cat.flasks.sub", order = 75, group = "other" })
    S.Section("flasks", "state", {
        label = "flask.set.state",
        order = 10,
        items = {
            { kind = "text", key = "state", tick = true,
              text = function() return T(F.IsOn() and "flask.set.on" or "flask.set.off") end,
              token = function() return F.IsOn() and "text.good" or "text.muted" end },
            { kind = "button", key = "toggle", tick = true, tip = "flask.set.toggle.tip",
              text = function() return T(F.IsOn() and "flask.set.toggle.off" or "flask.set.toggle.on") end,
              run = function() Switch(not F.IsOn()) end },
            { kind = "button", key = "say", tick = true, text = "flask.act.say",
              tip = function() return format(T("flask.act.say.tip"), View.AnnounceText()) end,
              enabled = function() return F.IsOn() and F.InGroup() end,
              run = View.Announce },
            { kind = "text", key = "bags", tick = true, text = View.BagLine, token = "text.secondary" },
            { kind = "text", key = "given", tick = true, text = View.Given, token = "text.primary" },
            { kind = "button", key = "log", text = "flask.set.log", tip = LogTip, run = View.PrintLog },
            { kind = "button", key = "reset", text = "flask.set.reset", confirm = "flask.set.reset.ask",
              tip = "flask.set.reset.tip", danger = true, order = 100,
              run = function()
                  F.Reset()
                  ns.Print(T("flask.log.reset"))
              end },
        },
    })
    S.Section("flasks", "what", {
        label = "flask.set.what",
        order = 20,
        items = { KindItem("tank", 10), KindItem("sp", 20), KindItem("ap", 30) },
    })
    S.Section("flasks", "norm", {
        label = "flask.set.norm",
        order = 30,
        items = {
            Slider("hours", "flask.set.hours", 1, 8, 0.5, Hours, 10),
            Slider("limit", "flask.set.limit", 1, 4, 1, Pcs, 20),
        },
    })
    S.Section("flasks", "rules", {
        label = "flask.set.rules",
        order = 40,
        items = {
            { kind = "check", key = "auto", label = "flask.set.auto", tip = "flask.set.auto.tip", default = true,
              get = function() return F.Get("auto") end, set = function(on) F.Set("auto", on and true or false) end },
            { kind = "choice", key = "own", label = "flask.set.own", tip = "flask.set.own.tip", default = "warn",
              options = {
                  { key = "skip", label = "flask.set.own.skip" },
                  { key = "warn", label = "flask.set.own.warn" },
                  { key = "ignore", label = "flask.set.own.ignore" },
              },
              get = function() return F.Get("own") end, set = function(k) F.Set("own", k) end },
            { kind = "check", key = "whisper", label = "flask.set.whisper", tip = "flask.set.whisper.tip",
              default = false,
              get = function() return F.Get("whisper") end,
              set = function(on) F.Set("whisper", on and true or false) end },
        },
    })
    S.Section("flasks", "alch", {
        label = "flask.set.alch",
        order = 50,
        items = {
            { kind = "field", key = "list", label = "flask.set.alch.list", tip = "flask.set.alch.tip", width = 220,
              maxLetters = 240, hint = "flask.set.alch.hint",
              get = F.AlchemistText, set = F.SetAlchemistText },
        },
    })
end
