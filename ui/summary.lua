local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local MARGIN = 8
local GAP = 6
local TILEMIN = 190
local DETAILMIN = 200
local TOTALMIN = 140
local HEADH = 20
local GPTITLE = 6
local GPPRESET = 22
local GPBTNS = 40
local GPHEAD = 66
local GPHOVER = 36
local GPLINE = 28
local GPGAP = 12
local BTNH = 20
local BTNPAD = 24
local BTNMIN = 60
local WHEEL = 40
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SKULL_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local CTL_ICON = "Interface\\Icons\\INV_Sword_04"
local CTL_SPELL = 71289
local TRANQ_SPELL = 19801
local RELAYOUT_DELAY = 0.15
local ROLE_ORDER = { "tank", "heal", "dps" }
local ARROWS = { given = "out", rebuff = "out", got = "in", rebuffed = "in" }
local LINKED = { rebuff = true, rebuffed = true, cc = true, blast = true }
local View = {}
ns.SummaryView = View
local Badges = ns.Badges
local Grid = ns.Grid
local style = Badges.style
local host, scroll, content, bg, hint
local fight, summary
local offset = 0
local stats, panels, heads, tiles = {}, {}, {}, {}
local failPanel
local laid
local Render
local pens = {}
local gpModel
local lastW = 0
local relayoutAt = 0
local pump = CreateFrame("Frame")
pump:Hide()
local Tips = ns.BadgeTips
local Short = Tips.Short
local Clock = Tips.Clock
local function Icon(id)
    if type(id) == "string" then return id end
    return id and ns.Effects.IconById(id) or UNKNOWN_ICON
end
local function PageWheel(delta)
    if not content then return end
    local most = max(0, content:GetHeight() - host:GetHeight())
    offset = max(0, min(most, offset - delta * WHEEL))
    scroll:SetVerticalScroll(offset)
end
local function Stat(i)
    stats[i] = stats[i] or Badges.Total(content)
    return stats[i]
end
local function Panel(i)
    panels[i] = panels[i] or Badges.Detail(content)
    return panels[i]
end
local function Head(i)
    local fs = heads[i]
    if fs then return fs end
    fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    heads[i] = fs
    return fs
end
local function OpenTimeline(name)
    if ns.Timeline and ns.Timeline.SelectPlayer then ns.Timeline.SelectPlayer(name) end
end
local function OpenManual(name)
    if fight and ns.GPList then ns.GPList.ManualMenu(fight, name) end
end
local function Tile(i)
    tiles[i] = tiles[i] or Badges.Personal(content)
    return tiles[i]
end
local function Verdict(bad)
    if bad then return "red" end
    return nil
end
local function First(list, key)
    return ns.ReplayLink and ns.ReplayLink.First(list, key) or nil
end
local function Replay(m, t, kind)
    if fight.foreign or ns.Store.Bare(fight) then return m end
    m.fight, m.at = fight, t
    m.preview = ns.DeathPreview and ns.DeathPreview.Wants(kind) or nil
    if ns.TimelineLinks and m.lines then ns.TimelineLinks.Tag(m.lines, fight, t) end
    return m
end
local function Proof(p, test, deaths)
    if not ns.Proof or fight.foreign then return nil end
    return ns.Proof.Ask(fight, p.name, pens[p.name], test, deaths)
end
local function DispelMark(d)
    local m = { icon = Icon(d.id), count = tostring(d.n), lines = Tips.Dispel(d) }
    local list = d.list or {}
    local first = list[1]
    if not first or fight.foreign then return m end
    local links, seen = {}, {}
    for k = 1, #list do
        local who = list[k].who
        if who and not seen[who] and fight.players[who] then
            seen[who] = true
            links[#links + 1] = who
        end
    end
    m.links = links
    m.fight, m.at = fight, fight.from + first.t
    if first.who and fight.players[first.who] and ns.TimelineLinks then
        local target = { who = first.who, at = m.at }
        m.onClick = function(_, button) ns.TimelineLinks.OpenMark(target, button) end
        m.lines[#m.lines + 1] = { kind = "foot",
            left = format(ns.T("sum.tip.dispelclick"), first.who, Clock(max(0, first.t))) }
    end
    return m
end
local function Entries(p, s)
    local list = {}
    local P = ns.Proof
    if p.deaths > 0 then
        local counted, worst = ns.DeathGrade.Skull(p)
        local ready = ns.DeathGrade.Ready(p)
        local pair = #ready > 0 and "death" or nil
        list[#list + 1] = Replay({ icon = SKULL_ICON, count = counted > 0 and tostring(counted) or "—",
            verdict = worst, pair = pair, lines = Tips.Death(p, fight),
            proof = P and Proof(p, P.IsDeath, true) }, First(p.deathInfo, "t"), "skull")
        for k = 1, #ready do
            local r = ready[k]
            list[#list + 1] = Replay({ icon = Icon(r.id), count = tostring(r.n), verdict = "yellow", pair = pair,
                lines = Tips.Ready(r, fight) }, r.times[1], "skull")
        end
    end
    if p.blame then
        local worst, victims = nil, {}
        for k = 1, #p.blame do
            worst = ns.DeathGrade.Worse(worst, p.blame[k].grade)
            victims[k] = p.blame[k].victim
        end
        list[#list + 1] = Replay({ icon = Icon(TRANQ_SPELL), count = tostring(#p.blame), verdict = worst,
            links = victims, lines = Tips.Blame(p, fight) }, p.blame[1].t)
    end
    local mark = ns.MindCtl.Mark(p)
    if mark then
        list[#list + 1] = Replay({ icon = mark.armed and CTL_ICON or Icon(CTL_SPELL), count = tostring(mark.count),
            verdict = mark.verdict, links = #mark.kills > 0 and mark.kills or nil, lines = Tips.Control(p, fight),
            proof = P and Proof(p, P.ByKind("mcweapon")) }, First(p.ctl, "t"))
    end
    local duties = ns.Penalties and ns.Penalties.Duties(s, fight, p) or {}
    local forced = {}
    for k = 1, #duties do
        local d = duties[k]
        local cover = ns.Actions.Covers(s, p, d)
        if type(cover) == "number" then
            forced[cover] = d.n < d.need
        elseif not cover then
            list[#list + 1] = { icon = Icon(d.id), count = tostring(d.n), verdict = Verdict(d.n < d.need),
                lines = Tips.Duty(ns.Penalties.Reason(d.rule), d.n, d.need),
                proof = P and d.n < d.need and Proof(p, P.ByKey(d.rule.key)) or nil }
        end
    end
    local fired = {}
    for _, hit in ipairs(pens[p.name] or {}) do
        for _, sp in ipairs(hit.rule.spells or {}) do fired[sp] = true end
        if hit.rule.npc then fired[hit.rule.npc] = true end
    end
    for i = 1, #s.badges do
        local st = p.badges[i]
        local bd = s.badges[i]
        if st and (st.n > 0 or (st.removed or 0) > 0 or forced[i] ~= nil) then
            local shown = bd.kind == "stack" and st.max or st.n
            local alert = st.cleansed > 0
            local text = alert and format("%d!", shown) or tostring(shown)
            if bd.kind == "stack" and st.max == 0 then
                text, alert = "—", false
            end
            if bd.kind == "dmgto" then text, alert = Short(st.amount), false end
            local grade
            if bd.kind == "cc" or bd.kind == "wrath" then
                text = format("%d/%d", st.hits, st.n)
                grade = ns.Actions.Grade(st.n, st.hits, forced[i])
            end
            local first = First(st.times)
            local linked = bd.kind == "killer" or bd.kind == "given" or bd.kind == "got"
                or (bd.kind == "applied" and not bd.names) or LINKED[bd.kind] == true
            local what = bd.spell or bd.npc
            local ask
            if P and bd.kind == "killer" then
                ask = Proof(p, P.ByKind("killer"))
            elseif P and what and fired[what] then
                ask = Proof(p, P.BySpell(what))
            end
            list[#list + 1] = Replay({ icon = Icon(st.icon or s.icons[i]),
                proof = ask,
                count = text,
                alert = alert,
                verdict = Verdict(fired[bd.spell or bd.npc or ""] == true or bd.kind == "killer")
                    or grade or st.grade or bd.grade,
                links = linked and st.notes or nil,
                arrow = ARROWS[bd.kind],
                lines = Tips.Badge(st, bd) }, first and fight.from + first, bd.kind)
        end
    end
    for k = 1, #p.kickList do
        local kk = p.kickList[k]
        list[#list + 1] = { icon = Icon(kk.id), count = kk.all and format("%d/%d", kk.n, kk.all) or tostring(kk.n),
            verdict = kk.all and ns.Actions.Grade(kk.all, kk.n) or nil, lines = Tips.Kick(kk) }
    end
    for k = 1, #p.dispList do
        list[#list + 1] = DispelMark(p.dispList[k])
    end
    return list
end
local function PersonalModel(p, s)
    local value, sub
    local sec = ns.Totals.Time(s)
    if p.role == "heal" then
        value = format(ns.T("sum.hps"), Short(p.heal / sec))
        sub = ""
    else
        value = format(ns.T("sum.dps"), Short(p.dmg / sec))
        sub = format(ns.T("sum.boss"), Short(p.bossDmg / sec))
    end
    local m = {
        name = p.name,
        class = p.class,
        value = value,
        sub = sub,
        marks = Entries(p, s),
        lines = Tips.Player(p, s),
        onClick = not fight.foreign and OpenTimeline or nil,
        onRightClick = not fight.foreign and OpenManual or nil,
        onWheel = PageWheel,
    }
    if ns.ExpectView and not fight.foreign then ns.ExpectView.Personal(fight, s, p, m) end
    return m
end
local function PullTotal(s, m)
    local pull = s.pull
    if not pull or not pull.src then return end
    local how = pull.spell or ns.T("tl.pull.melee")
    local who = pull.owner or (pull.pet and format(ns.T("tl.pull.pet"), pull.src)) or pull.src
    local full = pull.owner and format(ns.T("sum.pull.tipby"), who, how, pull.src)
        or format(ns.T("sum.pull.tip"), who, how)
    m.subs = { format(ns.T("sum.pull.short"), pull.owner or pull.src) }
    m.lines = { { kind = "head", left = m.title, right = m.value .. "  " .. m.sub }, { kind = "text", left = full } }
end
local function DrawStats(s, w)
    local sec = ns.Totals.Time(s)
    local cells = {
        { "sum.s.result", fight.killed and ns.T("sum.win") or ns.T("sum.wipe"), Clock(s.dur),
          ns.Kit.C[fight.killed and "sem.win" or "sem.wipe"] },
        { "sum.s.dps", Short(s.dmg / sec), format(ns.T("sum.boss"), Short(s.bossDmg / sec)),
          ns.Kit.C["sem.stat.dps"] },
        { "sum.s.hps", Short(s.heal / sec), Short(s.heal), ns.Kit.C["sem.stat.hps"] },
        { "sum.s.deaths", tostring(s.deaths), "", ns.Kit.C["sem.stat.deaths"] },
    }
    for i = 1, #(s.extra or {}) do
        local x = s.extra[i]
        local color = ns.Kit.C[(x.def.kind == "deaths" and x.n > 0) and "sem.stat.alert" or "sem.stat.extra"]
        cells[#cells + 1] = { x.def.label, tostring(x.n), "", color }
    end
    local list = {}
    for i = 1, #cells do
        local c = cells[i]
        local f = Stat(i)
        local m = { title = ns.T(c[1]), value = c[2], sub = c[3], color = c[4] }
        if c[1] == "sum.s.result" then PullTotal(s, m) end
        if c[1] == "sum.s.dps" or c[1] == "sum.s.hps" then m.lines = Tips.Combat(s, m.title, m.value) end
        if c[1] == "sum.s.dps" and ns.ExpectView and not fight.foreign then ns.ExpectView.Total(fight, s, m) end
        f:SetModel(m)
        list[i] = f
    end
    return Grid.Place(list, MARGIN, MARGIN, w, TOTALMIN, GAP, true)
end
local function PopOut()
    if not fight then return end
    ns.GetDB().gp.mini = true
    local f = fight
    ns.GPList.Changed()
    if ns.GPMini then ns.GPMini.ShowFight(f) end
end
local function FitButton(b, key)
    b.text:SetText(ns.T(key))
    b:SetWidth(max(BTNMIN, floor(b.text:GetStringWidth() + 0.5) + BTNPAD))
end
local function FailHeadEnter(self)
    ns.Tip.Show(self, {
        { kind = "head", left = failPanel.title:GetText() },
        { kind = "note", left = ns.T("sum.gp.hint") },
    })
end
local function FailLayout(self, width)
    local model = self.model
    local top = self.inside and GPLINE or GPHEAD
    local h = top
    if model and #model.items > 0 then
        self.list:Show()
        h = top + 2 + self.list:Draw(fight, model, width)
    else
        self.list:Hide()
    end
    self:SetWidth(width)
    self:SetHeight(h)
    return h
end
local function Inside()
    return not ns.SumSide or ns.SumSide.Inside()
end
local function SideWheel(delta)
    if Inside() then PageWheel(delta) else ns.SumSide.Wheel(delta) end
end
local function HeadLine(f, font)
    local fs = f.head:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end
local function TopLine(fs, head, top)
    fs:SetPoint("TOPLEFT", head, "TOPLEFT", 10, -top)
    fs:SetPoint("TOPRIGHT", head, "TOPRIGHT", -6, -top)
end
local function FailMode(f, inside)
    f.inside = inside
    f:SetParent(inside and content or ns.SumSide.Content())
    f.all:ClearAllPoints()
    f.all:SetPoint("TOPRIGHT", -6, -(inside and 4 or GPBTNS))
    f.head:ClearAllPoints()
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.title:ClearAllPoints()
    f.preset:ClearAllPoints()
    if inside then
        f.head:SetPoint("RIGHT", f.pop, "LEFT", -8, 0)
        f.head:SetHeight(GPLINE)
        f.title:SetPoint("LEFT", f.head, "LEFT", 10, 0)
        f.preset:SetPoint("LEFT", f.title, "RIGHT", GPGAP, 0)
        f.preset:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
    else
        f.head:SetPoint("TOPRIGHT", 0, 0)
        f.head:SetHeight(GPHOVER)
        TopLine(f.title, f.head, GPTITLE)
        TopLine(f.preset, f.head, GPPRESET)
    end
    local other = inside and f.narrow or f.wide
    other:Hide()
    f.list = inside and f.wide or f.narrow
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", 0, -((inside and GPLINE or GPHEAD) + 2))
end
local function FailPanel()
    if failPanel then return failPanel end
    local f = CreateFrame("Frame", nil, content)
    f.all = ns.MakeButton(f, "HTP_FailWatchGPAll")
    f.all:SetHeight(BTNH)
    f.all.onClick = function()
        if fight and gpModel then ns.GPList.Issue(fight, gpModel.all) end
    end
    f.cfg = ns.MakeButton(f, "HTP_FailWatchGPSettings")
    f.cfg:SetHeight(BTNH)
    f.cfg:SetPoint("RIGHT", f.all, "LEFT", -6, 0)
    f.cfg.onClick = function()
        if ns.GPSettings and ns.Shell then ns.Shell.Open("gp") else ns.Print(ns.T("slash.diag.restart")) end
    end
    f.pop = ns.MakeButton(f, "HTP_FailWatchGPPop")
    f.pop:SetHeight(BTNH)
    f.pop:SetPoint("RIGHT", f.cfg, "LEFT", -6, 0)
    f.pop.onClick = PopOut
    f.head = CreateFrame("Frame", nil, f)
    f.head:EnableMouse(true)
    f.head:SetScript("OnEnter", FailHeadEnter)
    f.head:SetScript("OnLeave", function() ns.Tip.Hide() end)
    f.title = HeadLine(f, "GameFontNormal")
    f.preset = HeadLine(f, "GameFontHighlightSmall")
    ns.Kit.Text(f.preset, "text.secondary")
    f.narrow = ns.GPList.New(f, "HTP_FailWatchGPRow", ns.GPList.COMPACT)
    f.narrow.onWheel = SideWheel
    f.wide = ns.GPList.New(f, "HTP_FailWatchGPWide")
    f.wide.onWheel = SideWheel
    f.Layout = FailLayout
    failPanel = f
    return f
end
local function FailItem(model)
    if not model or fight.foreign or ns.GetDB().gp.mini then return nil end
    local f = FailPanel()
    FailMode(f, Inside())
    Badges.Skin(f, style.red)
    f.model = model
    f.title:SetText(format(ns.T("sum.gp.title"), #model.items, model.pending))
    f.preset:SetText(format(ns.T("sum.gp.preset"), ns.Penalties.Label(ns.Penalties.Active())))
    FitButton(f.all, "sum.gp.all")
    FitButton(f.cfg, "sum.gp.cfg")
    FitButton(f.pop, "gp.popout")
    if model.pending > 0 then f.all:Enable() else f.all:Disable() end
    return f
end
local function MissedRow(b)
    return { who = format(ns.T("sum.k.missed"), b.casts - b.total), text = Short(b.missDmg), v = 0,
        lines = Tips.Missed(b) }
end
local function BlockList(b)
    local list = {}
    local kind = b.def.kind
    for who, v in pairs(b.by) do
        local text
        if kind == "dispels" or kind == "casts" or kind == "removed" then
            text = tostring(v)
        elseif kind == "taken" or kind == "shades" or b.def.soak then
            text = format("%s  %sx%d|r", Short(v), ns.Kit.Hex("text.note"), b.hits[who] or 0)
        elseif kind == "cannons" then
            text = format(ns.T("sum.k.gunrow"), Short(v), b.hits[who] or 0, floor(b.secs[who] or 0), b.kills[who] or 0)
        else
            text = format("%s  %s%.1f%%|r", Short(v), ns.Kit.Hex("text.note"), v * 100 / max(1, b.total))
        end
        local known = summary.byName and summary.byName[who]
        local class = ns.Encounters.ClassOf(who) or (known and known.class)
        local lines = kind == "shades" and ns.ActionTips.Shades(b, who, class) or Tips.Row(b, who, v, class)
        list[#list + 1] = { who = who, class = class, v = v, text = text, lines = lines }
    end
    tsort(list, function(a, c) return a.v > c.v end)
    if kind == "casts" and b.casts > b.total then list[#list + 1] = MissedRow(b) end
    if kind == "shades" and #b.at > 0 then
        list[#list + 1] = { who = format(ns.T("sum.k.shadehit"), b.hit), text = Short(b.total), v = 0,
            lines = ns.ActionTips.Shades(b) }
    end
    return list
end
local function BlockTitle(b)
    local kind = b.def.kind
    local label = ns.T(b.label or b.def.label)
    if kind == "casts" then return format(ns.T("sum.k.casts"), label, b.total, b.casts) end
    if kind == "shades" then return format(ns.T("sum.k.shadestitle"), label, b.caught, b.summoned) end
    local value = (kind == "dispels" or kind == "removed") and tostring(b.total) or Short(b.total)
    return format(ns.T("sum.k.title"), label, value)
end
local function BlockPanel(s, i)
    local b = s.blocks[i]
    local f = Panel(i)
    f:SetModel({
        title = BlockTitle(b),
        rows = BlockList(b),
        empty = ns.T("sum.k.none"),
        onWheel = PageWheel,
    })
    return f
end
local function DrawBlocks(s, y, w)
    local n = #s.blocks
    for i = n + 1, #panels do panels[i]:Hide() end
    local list = {}
    for i = 1, n do list[i] = BlockPanel(s, i) end
    return Grid.Place(list, MARGIN, y, w, DETAILMIN, GAP, true)
end
local function DrawFails(y, w)
    local gp = FailItem(gpModel)
    if ns.SumSide then ns.SumSide.Show("fight", gp and { gp } or {}) end
    if not gp or not Inside() then return y end
    return Grid.Place({ gp }, MARGIN, y, w, w, GAP)
end
local function Mark(key, top, bottom)
    if bottom > top then laid[#laid + 1] = { key = key, top = top, bottom = bottom - GAP } end
end
local function DrawTiles(s, y, w)
    local used = 0
    for r = 1, #ROLE_ORDER do
        local role = ROLE_ORDER[r]
        local list = {}
        for i = 1, #s.players do
            local p = s.players[i]
            if p.role == role then
                used = used + 1
                local t = Tile(used)
                t:SetModel(PersonalModel(p, s))
                list[#list + 1] = t
            end
        end
        local h = Head(r)
        if #list > 0 then
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", MARGIN + 2, -(y + 4))
            h:SetText(ns.T("sum.head." .. role))
            ns.Kit.Text(h, "text.title")
            h:Show()
            y = Grid.Place(list, MARGIN, y + HEADH, w, TILEMIN, GAP)
        else
            h:Hide()
        end
    end
    for i = used + 1, #tiles do tiles[i]:Hide() end
    return y
end
function Render()
    if not host or not host:IsShown() then return end
    lastW = floor(host:GetWidth())
    if failPanel then failPanel:Hide() end
    for i = 1, #stats do stats[i]:Hide() end
    for i = 1, #panels do panels[i]:Hide() end
    for i = 1, #heads do heads[i]:Hide() end
    for i = 1, #tiles do tiles[i]:Hide() end
    Badges.ResetLinks()
    local w = max(200, host:GetWidth() - MARGIN * 2)
    content:SetWidth(host:GetWidth())
    if not summary then
        laid = {}
        if ns.SumSide then ns.SumSide.Show("fight", {}) end
        hint:SetText(ns.T("sum.busy"))
        hint:Show()
        content:SetHeight(host:GetHeight())
        return
    end
    hint:Hide()
    gpModel = ns.GPList and ns.GPList.Build(fight, summary)
    pens = gpModel and gpModel.pens or {}
    laid = {}
    local y = DrawStats(summary, w)
    Mark("totals", MARGIN, y)
    local top = y
    y = DrawFails(y, w)
    Mark("gp", top, y)
    top = y
    y = DrawBlocks(summary, y, w)
    Mark("details", top, y)
    top = y
    y = DrawTiles(summary, y, w)
    Mark("players", top, y)
    content:SetHeight(max(host:GetHeight(), y + MARGIN))
    offset = min(offset, max(0, content:GetHeight() - host:GetHeight()))
    scroll:SetVerticalScroll(offset)
end
function View.Attach(frame)
    host = frame
    bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "surface.page")
    scroll = CreateFrame("ScrollFrame", nil, host)
    scroll:SetAllPoints()
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) PageWheel(delta) end)
    hint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", MARGIN * 2, -MARGIN * 2)
    host:Hide()
    if ns.SumSide then ns.SumSide.Watch("fight", host, function() Render() end) end
end
function View.Show(f)
    if not host then return end
    fight = f
    offset = 0
    summary = f.foreign and f.sum or ns.Summary.Get(f)
    host:Show()
    if not f.foreign and ns.GetDB().gp.mini and ns.GPMini and ns.GPMini.IsShown() then ns.GPMini.ShowFight(f) end
    Render()
    if not summary and not f.foreign then
        ns.Summary.Compute(f, function(s)
            if fight ~= f then return end
            summary = s
            Render()
        end)
    end
end
function View.Hide()
    if host then host:Hide() end
    if ns.SumSide then ns.SumSide.Drop("fight") end
end
function View.Blocks()
    return laid or {}
end
function View.Details()
    local out = {}
    for i = 1, #panels do
        if panels[i]:IsShown() then out[#out + 1] = panels[i] end
    end
    return out
end
pump:SetScript("OnUpdate", function(self)
    if GetTime() < relayoutAt then return end
    self:Hide()
    Render()
end)
function View.Refresh()
    Render()
end
function View.Fight()
    if fight and fight.foreign then return nil end
    return fight
end
if ns.GPList then ns.GPList.OnChange(function() Render() end) end
function View.Relayout()
    if not host or not host:IsShown() then return end
    if floor(host:GetWidth()) == lastW then return end
    relayoutAt = GetTime() + RELAYOUT_DELAY
    pump:Show()
end
function View.IsShown()
    return host ~= nil and host:IsShown() and true or false
end
