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
local forceBtn, acceptBtn
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
        out[#out + 1] = format(T("flask.log.row"), r.name, r.n, concat(parts, ", "), date("%H:%M", r.last))
    end
    return out
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
    if st == "placed" or st == "accepting" or st == "accepted" or st == "press" then
        return format(T("flask.st." .. st), item)
    end
    if st == "wait" or st == "offer" or st == "stranger" or st == "combat" or st == "removed" or st == "split" then
        return T("flask.st." .. st)
    end
    if st == "many" then return format(T("flask.st.many"), s.many or 0) end
    if st == "cursor" or st == "full" or st == "pick" or st == "nosplit" then
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
local function Layout()
    local y = -PAD
    local inner = W - PAD * 2
    title:SetPoint("TOPLEFT", PAD, y)
    y = y - title:GetStringHeight() - LINE_GAP
    for _, fs in ipairs({ who, line, warn }) do
        fs:SetWidth(inner)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, y)
        if fs:IsShown() then y = y - floor(fs:GetStringHeight() + 0.5) - LINE_GAP end
    end
    y = y - GAP
    local bw = floor((inner - GAP * 2) / 3)
    for i, kind in ipairs(ns.flaskKinds) do
        local b = kindBtn[kind]
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", PAD + (i - 1) * (bw + GAP), y)
    end
    y = y - BTN_H - GAP
    local half = floor((inner - GAP) / 2)
    forceBtn:SetWidth(half)
    forceBtn:ClearAllPoints()
    forceBtn:SetPoint("TOPLEFT", PAD, y)
    acceptBtn:SetWidth(half)
    acceptBtn:ClearAllPoints()
    acceptBtn:SetPoint("TOPLEFT", PAD + half + GAP, y)
    y = y - BTN_H - PAD
    pop:SetHeight(-y)
end
local function Label(parent, token)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function Btn(text, tip, run)
    local b = Kit.Button(pop)
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
    pop:SetWidth(W)
    Kit.Skin(pop, "float")
    title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    if p and p.warn == "own" then
        warn:SetText(format(T("flask.warn.own"), p.name, p.has or 0))
        warn:Show()
    else
        warn:Hide()
    end
    local kind = s.kind or (p and p.kind)
    for k, b in pairs(kindBtn) do b:SetActive(k == kind) end
    local placed = s.item ~= nil
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
    return { kindBtn.tank, kindBtn.sp, kindBtn.ap, forceBtn, acceptBtn }
end
function View.Lines()
    if not pop then return "", "" end
    return who:GetText() or "", line:GetText() or ""
end
function View.Glowing()
    return glow ~= nil and glow:IsShown() and true or false
end
Trade.OnChange(View.Refresh)
F.OnChange(function()
    View.Refresh()
    if S and S.Refresh then S.Refresh() end
end)
local function Switch(on)
    Trade.Switch(on)
end
local function Rows()
    return {
        { title = T("flask.act.row"), items = {
            {
                label = T("flask.act.toggle"),
                title = T("set.cat.flasks"),
                tip = T("flask.act.toggle.tip"),
                state = function()
                    local on = F.IsOn()
                    if not on and not F.InGroup() then return false, T("flask.act.nogroup"), false end
                    return true, nil, on
                end,
                run = function() Switch(not F.IsOn()) end,
            },
            {
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
    local s = v == floor(v) and format("%d", v) or format("%.1f", v):gsub("%.", ",")
    return format(T("flask.unit.hours"), s)
end
local function Mins(v)
    return format(T("flask.unit.min"), v)
end
local function Pcs(v)
    return format(T("flask.unit.pcs"), v)
end
if S and S.Category then
    S.Category("flasks", { label = "set.cat.flasks", sub = "set.cat.flasks.sub", order = 75, group = "lead" })
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
            Slider("gap", "flask.set.gap", 0, 120, 5, Mins, 30),
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
