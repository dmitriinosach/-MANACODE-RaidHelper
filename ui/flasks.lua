local ADDON, ns = ...
local format = string.format
local floor, max, ceil = math.floor, math.max, math.ceil
local concat = table.concat
local W = 320
local PAD = 8
local GAP = 4
local BTN_H = 20
local LINE_GAP = 3
local ICON = 14
local LEFT_SHARE = 0.62
local SAY_MAX = 250
local STATE_MAIN_W = 150
local STATE_BTN_W = 100
local GLOW = "Interface\\Buttons\\CheckButtonHilight"
local GLOW_OUT = 6
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local F = ns.Flasks
local Trade = ns.FlaskTrade
local Kit = ns.Kit
local S = ns.Settings
local T = ns.T
local View = {}
ns.FlaskView = View
local pop, title, who, line, warn, give, rest, glow, glowTex
local kindBtn = {}
local forceBtn, acceptBtn, cancelBtn
local function Word(n, key)
    return ns.Plural and ns.Plural(n, T(key)) or T(key)
end
View.Word = Word
function View.Given()
    local n, people = F.Stats()
    return format(T("flask.set.given"), n, Word(n, "flask.w.item"), people, Word(people, "flask.w.people"))
end
local function ItemN(id, n)
    return F.Name(id) .. " x" .. n
end
function View.LogLines()
    local t = F.Table()
    if t.given == 0 and t.short == 0 then return { T("flask.log.empty") } end
    local out = { format(T("flask.log.head"), t.given, Word(t.given, "flask.w.item"), t.people,
        Word(t.people, "flask.w.people"), t.short, Word(t.short, "flask.w.people")) }
    local hand = {}
    local rows = F.Rows()
    for i = 1, #rows do hand[rows[i].name] = rows[i].hand end
    for i = 1, #t.rows do
        local r = t.rows[i]
        if r.got > 0 or (r.here and r.short > 0) then
            local parts = {}
            for k = 1, #t.ids do
                local id = t.ids[k]
                local c = r.cells[id]
                if c.norm > 0 or c.got > 0 then parts[#parts + 1] = format("%s %d/%d", F.Name(id), c.got, c.norm) end
            end
            local role = r.kind and T("flask.kind." .. r.kind) or T("flask.log.norole")
            local h = (hand[r.name] or 0) > 0 and format(T("flask.log.hand"), hand[r.name]) or ""
            out[#out + 1] = format(T("flask.log.row"), r.name, role, concat(parts, ", ")) .. h
        end
    end
    out[#out + 1] = T("flask.log.note")
    return out
end
function View.BagLine()
    local list = F.Bags()
    local parts = {}
    for i = 1, #list do
        local e = list[i]
        local s = F.Name(e.id) .. " " .. e.n
        parts[i] = e.n > 0 and s or (Kit.Hex("text.warn") .. s .. "|r")
    end
    if #parts == 0 then return T("flask.bags.none") end
    return format(T("flask.bags"), concat(parts, ", "))
end
function View.AnnounceLines()
    local groups = {}
    for i = 1, #ns.flaskKinds do
        local kind = ns.flaskKinds[i]
        local list, parts = F.KitItems(kind), {}
        for k = 1, #list do parts[k] = ItemN(list[k].id, list[k].n) end
        if #parts > 0 then
            local text = concat(parts, ", ")
            local g
            for k = 1, #groups do
                if groups[k].text == text then g = groups[k] end
            end
            if g then
                g.who[#g.who + 1] = T("flask.say." .. kind)
            else
                groups[#groups + 1] = { text = text, who = { T("flask.say." .. kind) } }
            end
        end
    end
    if #groups == 0 then return { T("flask.say.none") } end
    local parts = {}
    for i = 1, #groups do
        parts[i] = format(T("flask.say.part"), concat(groups[i].who, T("flask.say.and")), groups[i].text)
    end
    local one = format(T("flask.say"), concat(parts, "; "))
    if #one <= SAY_MAX then return { one } end
    local out = { T("flask.say.head") }
    for i = 1, #parts do
        local p = parts[i]
        if #p > SAY_MAX then p = (p:sub(1, SAY_MAX):gsub("[\192-\255][\128-\191]*$", "")) end
        out[#out + 1] = p
    end
    return out
end
function View.AnnounceText()
    return concat(View.AnnounceLines(), "\n")
end
function View.Announce()
    if not F.IsOn() or not F.InGroup() then return end
    local chan = (GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY"
    local lines = View.AnnounceLines()
    for i = 1, #lines do SendChatMessage(lines[i], chan) end
end
function View.PrintLog()
    local lines = View.LogLines()
    for i = 1, #lines do ns.Print(lines[i]) end
end
function View.OpenLog()
    if ns.Shell and ns.Shell.Open then ns.Shell.Open("flasklog") end
end
function View.OpenSettings()
    if S and S.Open then S.Open("flasks") end
end
local function GearIcon(tex)
    tex:SetTexture(ART .. "settings")
    Kit.Tint(tex, "text.primary")
end
local function PutText(s)
    local parts = {}
    for i = 1, #(s.items or {}) do
        local q = s.items[i]
        if q.put > 0 then parts[#parts + 1] = F.Name(q.id) .. (q.put > 1 and (" x" .. q.put) or "") end
    end
    return concat(parts, ", ")
end
local function StatusText(s)
    local st = s.status or "wait"
    if st == "placed" or st == "accepting" or st == "accepted" or st == "press" then
        return format(T("flask.st." .. st), PutText(s))
    end
    if st == "wait" or st == "offer" or st == "stranger" or st == "combat" or st == "removed" or st == "split" then
        return T("flask.st." .. st)
    end
    if st == "many" then return format(T("flask.st.many"), s.many or 0) end
    if st == "cursor" or st == "full" or st == "pick" or st == "nosplit" or st == "bags" then
        local q = s.items and s.items[s.qi or 1]
        local name = q and F.Name(q.id) or (s.plan and Trade.Names(s.plan.list)) or ""
        return format(T("flask.put." .. st), name)
    end
    if s.plan then return Trade.Reason(s.plan) end
    return ""
end
local function WhoText(s)
    local p = s.plan
    if not p then return s.partner or "" end
    local alch = F.IsAlchemist(p.name) and T("flask.pop.alch") or ""
    if not p.kind then return format(T("flask.pop.who.none"), p.name) .. alch end
    return format(T("flask.pop.who"), p.name, T("flask.kind." .. p.kind), T("flask.src." .. (p.src or "hand")),
        p.n, p.norm) .. alch
end
local function HandText(s)
    local parts
    for i = 1, #(s.armed or {}) do
        local a = s.armed[i]
        if a.manual then
            parts = parts or {}
            parts[#parts + 1] = ItemN(a.id, a.count)
        end
    end
    return parts and format(T("flask.st.hand"), concat(parts, ", ")) or nil
end
local function Outgoing(s)
    local out = {}
    if s.items then
        for i = 1, #s.items do out[s.items[i].id] = (out[s.items[i].id] or 0) + s.items[i].put end
    elseif s.plan then
        for i = 1, #s.plan.list do out[s.plan.list[i].id] = s.plan.list[i].put end
    end
    return out
end
function View.Columns(s)
    local out = Outgoing(s)
    local left = { Kit.Hex("text.secondary") .. T("flask.pop.give") .. "|r" }
    local src = s.items or (s.plan and s.plan.list) or {}
    for i = 1, #src do
        local id, n = src[i].id, src[i].put
        if n > 0 then left[#left + 1] = F.IconText(id, ICON) .. " " .. ItemN(id, n) end
    end
    if #left == 1 then left[2] = Kit.Hex("text.muted") .. "—|r" end
    local right = { Kit.Hex("text.secondary") .. T("flask.pop.left") .. "|r" }
    local ids, others = F.KitIds(), s.others or {}
    for i = 1, #ids do
        local id = ids[i]
        local n = max(0, (GetItemCount(id) or 0) - (out[id] or 0))
        local tok = n < (others[id] or 0) and "text.bad" or "text.primary"
        right[#right + 1] = Kit.Hex(tok) .. n .. "|r " .. F.IconText(id, ICON)
    end
    return concat(left, "\n"), concat(right, "\n")
end
local function Widths(inner, gap)
    local n = #ns.flaskKinds
    local bw, half = floor((inner - gap * (n - 1)) / n), floor((inner - gap) / 2)
    local kw, hw = bw, half
    for i = 1, n do
        local b = kindBtn[ns.flaskKinds[i]]
        b:SetWidth(bw)
        kw = max(kw, b:GetWidth())
    end
    for _, b in ipairs({ forceBtn, acceptBtn }) do
        b:SetWidth(half)
        hw = max(hw, b:GetWidth())
    end
    inner = max(inner, kw * n + gap * (n - 1), hw * 2 + gap)
    return inner, floor((inner - gap * (n - 1)) / n), floor((inner - gap) / 2)
end
local function Layout()
    local U = ns.Kit.FontGrow
    local w, pad, gap, bh = U(W), U(PAD), U(GAP), U(BTN_H)
    local inner, bw, half = Widths(w - pad * 2, gap)
    w = inner + pad * 2
    pop:SetWidth(w)
    local y = -pad
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", pad, y)
    y = y - title:GetStringHeight() - LINE_GAP
    for _, fs in ipairs({ who, line, warn }) do
        fs:SetWidth(inner)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", pad, y)
        if fs:IsShown() then y = y - floor(fs:GetStringHeight() + 0.5) - LINE_GAP end
    end
    local lw = floor(inner * LEFT_SHARE)
    give:SetWidth(lw)
    give:ClearAllPoints()
    give:SetPoint("TOPLEFT", pad, y)
    rest:SetWidth(inner - lw)
    rest:ClearAllPoints()
    rest:SetPoint("TOPRIGHT", -pad, y)
    y = y - floor(max(give:GetStringHeight(), rest:GetStringHeight()) + 0.5) - gap * 2
    for i, kind in ipairs(ns.flaskKinds) do
        local b = kindBtn[kind]
        b:SetWidth(bw)
        b:SetHeight(bh)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pad + (i - 1) * (bw + gap), y)
    end
    y = y - bh - gap
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
local function Btn(parent, text, tip, run, act)
    local b = Kit.Button(parent)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetHeight(BTN_H)
    b:SetText(text)
    b.tipTitle = text
    b.tip = tip
    b.tipClick = act
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
    give = Label(pop, "text.primary")
    give:SetJustifyV("TOP")
    rest = Label(pop, "text.primary")
    rest:SetJustifyH("RIGHT")
    rest:SetJustifyV("TOP")
    for _, kind in ipairs(ns.flaskKinds) do
        kindBtn[kind] = Btn(pop, T("flask.kind." .. kind), T("flask.kind.tip"), function() Trade.Choose(kind) end,
            T("flask.kind.act"))
    end
    forceBtn = Btn(pop, T("flask.btn.force"), T("flask.btn.force.tip"), Trade.Force)
    acceptBtn = Btn(pop, T("flask.btn.accept"), T("flask.btn.accept.tip"), Trade.Accept)
    cancelBtn = Btn(pop, T("flask.btn.cancel"), T("flask.btn.cancel.tip"), Trade.Cancel)
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
local function Notes(s)
    local p = s.plan
    local notes = {}
    if s.otherGuild then
        notes[#notes + 1] = format(T("flask.warn.guild"), s.partner, s.guild or T("flask.guild.none"))
    end
    if p and p.warn then notes[#notes + 1] = format(T("flask.warn." .. p.warn), p.name, p.has or 0) end
    if p and p.give and #p.short > 0 then notes[#notes + 1] = format(T("flask.warn.short"), Trade.Names(p.short, true)) end
    if s.status == "press" and s.press then notes[#notes + 1] = T("flask.press." .. s.press) end
    local hand = HandText(s)
    if hand then notes[#notes + 1] = hand end
    return notes
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
    local notes = Notes(s)
    if #notes > 0 then
        warn:SetText(concat(notes, "\n"))
        warn:Show()
    else
        warn:Hide()
    end
    local l, r = View.Columns(s)
    give:SetText(l)
    rest:SetText(r)
    local p = s.plan
    local kind = s.kind or (p and p.kind)
    for k, b in pairs(kindBtn) do b:SetActive(k == kind) end
    local placed = Trade.Put() > 0
    local st = s.status or "wait"
    if not placed and not s.armed and st ~= "wait" and st ~= "split" then cancelBtn:Show() else cancelBtn:Hide() end
    if p and p.skips and not s.accepted and st ~= "combat" and st ~= "stranger" then
        forceBtn:Enable()
    else
        forceBtn:Disable()
    end
    local press = st == "press"
    if placed and not s.accepted and st ~= "combat" then acceptBtn:Enable() else acceptBtn:Disable() end
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
    local out = {}
    for i = 1, #ns.flaskKinds do out[i] = kindBtn[ns.flaskKinds[i]] end
    out[#out + 1] = forceBtn
    out[#out + 1] = acceptBtn
    out[#out + 1] = cancelBtn
    return out
end
function View.Note()
    if not pop or not warn:IsShown() then return "" end
    return warn:GetText() or ""
end
function View.Lines()
    if not pop then return "", "" end
    return who:GetText() or "", line:GetText() or ""
end
function View.ColumnText()
    if not pop then return "", "" end
    return give:GetText() or "", rest:GetText() or ""
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
    if View.LogRefresh then View.LogRefresh() end
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
                run = View.OpenLog,
            },
            {
                id = "kits",
                label = "",
                title = T("flask.act.kits"),
                tip = T("flask.act.kits.tip"),
                icon = GearIcon,
                state = function() return true end,
                run = View.OpenSettings,
            },
        } },
    }
end
if ns.Shell and ns.Shell.Actions then ns.Shell.Actions(Rows, 100) end
local function Command(arg)
    local sub = (arg or ""):match("^(%S*)")
    if sub == "log" then
        View.OpenLog()
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
local state = {}
local function StateSizes()
    local ctl = Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
    return ctl + 4, ctl, Kit.Space.row
end
local function PlaceState()
    local r = state.row
    if not r then return end
    local rowH, ctl, gap = StateSizes()
    local w = max(1, r:GetWidth())
    local x = 0
    for i, b in ipairs({ state.toggle, state.say, state.log }) do
        b:SetWidth(i == 1 and STATE_MAIN_W or STATE_BTN_W)
        b:SetHeight(ctl)
        b:ClearAllPoints()
        b:SetPoint("LEFT", r, "TOPLEFT", x, -rowH / 2)
        x = x + b:GetWidth() + gap
    end
    state.line:SetWidth(w)
    state.line:ClearAllPoints()
    state.line:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -(rowH + LINE_GAP))
    state.bags:SetWidth(w)
    state.bags:ClearAllPoints()
    state.bags:SetPoint("TOPLEFT", state.line, "BOTTOMLEFT", 0, -LINE_GAP)
end
local function StateHeight()
    local rowH = StateSizes()
    if not state.row then return rowH end
    return rowH + LINE_GAP * 3 + ceil(state.line:GetStringHeight()) + ceil(state.bags:GetStringHeight())
end
local function RefreshState()
    if not state.row then return end
    local on, grp = F.IsOn(), F.InGroup()
    state.toggle:SetText(T(on and "flask.set.toggle.off" or "flask.set.toggle.on"))
    state.toggle:SetActive(on)
    state.toggle.tip = (on or grp) and T("flask.set.toggle.tip") or T("flask.act.nogroup")
    if on or grp then state.toggle:Enable() else state.toggle:Disable() end
    state.say.tip = on and format(T("flask.act.say.tip"), View.AnnounceText()) or T("flask.act.say.off")
    if on and grp then state.say:Enable() else state.say:Disable() end
    state.line:SetText(Kit.Hex(on and "text.good" or "text.muted") .. T(on and "flask.set.on" or "flask.set.off")
        .. "|r " .. View.Given())
    state.bags:SetText(View.BagLine())
    PlaceState()
end
local function BuildState(r)
    state.row = r
    state.toggle = Btn(r, T("flask.set.toggle.on"), T("flask.set.toggle.tip"), function() Switch(not F.IsOn()) end)
    state.say = Btn(r, T("flask.act.say"), "", View.Announce)
    state.log = Btn(r, T("flask.set.log"), T("flask.set.log.tip"), View.OpenLog)
    for _, b in ipairs({ state.toggle, state.say, state.log }) do b.tipTitle = false end
    state.line = Label(r, "text.primary")
    state.bags = Label(r, "text.secondary")
    r.Place = PlaceState
end
function View.StateButtons()
    return { state.toggle, state.say, state.log }
end
function View.StateText()
    if not state.row then return "", "" end
    return state.line:GetText() or "", state.bags:GetText() or ""
end
if S and S.Category then
    S.Category("flasks", { label = "set.cat.flasks", sub = "set.cat.flasks.sub", order = 75, group = "other" })
    S.Section("flasks", "state", {
        label = "flask.set.state",
        order = 10,
        items = {
            { kind = "custom", key = "state", tick = true, height = StateHeight, build = BuildState,
              refresh = RefreshState },
        },
    })
    S.Section("flasks", "rules", {
        label = "flask.set.rules",
        order = 40,
        items = {
            { kind = "check", key = "auto", label = "flask.set.auto", tip = "flask.set.auto.tip", default = true,
              get = function() return F.Get("auto") end, set = function(on) F.Set("auto", on and true or false) end },
            { kind = "choice", key = "own", label = "flask.set.own", tip = "flask.set.own.tip", default = "warn",
              hint = "flask.set.own.hint",
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
