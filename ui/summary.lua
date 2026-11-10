local ADDON, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local tsort = table.sort
local MARGIN = 8
local BAR_ROOM = 8
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
local GPCAP = 7
local BTNH = 20
local BTNPAD = 24
local BTNMIN = 60
local CHATH = 16
local CHATPAD = 14
local BTNGAP = 4
local BAR_A = 0.38
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SKULL_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local CTL_ICON = "Interface\\Icons\\INV_Sword_04"
local CTL_SPELL = 71289
local TRANQ_SPELL = 19801
local ROLE_ORDER = { "tank", "heal", "dps" }
local ARROWS = { given = "out", rebuff = "out", got = "in", rebuffed = "in" }
local LINKED = { rebuff = true, rebuffed = true, cc = true, blast = true, pulled = true }
local View = {}
ns.SummaryView = View
local Badges = ns.Badges
local Grid = ns.Grid
local style = Badges.style
local host, content, bg, hint, art
local pane
local fight, summary
local keep
local stats, panels, heads, tiles = {}, {}, {}, {}
local wides = {}
local failPanel
local rateBtns = {}
local laid
local Render
local pens = {}
local gpModel
local Tips = ns.BadgeTips
local Short = ns.Short
local Rate = Tips.Rate
local Kit = ns.Kit
local function Pt(base)
    return Kit.FontSize(base, true)
end
local function MinW(w)
    return floor(w * max(1, Kit.FontScale("GameFontHighlightSmall", true)) + 0.5)
end
local function FitW(list, base, w)
    local m = MinW(base)
    local big = Kit.FontDelta() > 0
    for i = 1, #list do
        local f = list[i]
        local need = (big or f.wide) and f.Need and f:Need()
        local sp = f.span or 1
        if type(need) == "number" and sp > 1 then need = (need - GAP * (sp - 1)) / sp end
        if type(need) == "number" then m = max(m, need) end
    end
    return math.min(m, w)
end
local function FailMetrics()
    local n, s = Pt("GameFontNormal"), Pt("GameFontHighlightSmall")
    local preset = max(GPPRESET, GPTITLE + n + 4)
    local hover = max(GPHOVER, preset + s + 4)
    local btns = max(GPBTNS, hover + 4)
    local side = GPTITLE + n + 10
    return { line = max(GPLINE, math.ceil(n * 1.15) + 8), preset = preset, hover = hover, btns = btns,
             head = max(GPHEAD, btns + BTNH + 6), side = side, sideHead = side + BTNH + 10 }
end
local function Good(x)
    return x.goodDmg or x.dmg
end
local function AllLine(dmg, sec)
    local key = ns.dpsAll and ns.dpsAll[fight and fight.boss]
    if not key then return "" end
    return ns.Kit.Hex("text.muted") .. format(ns.T(key), Rate(dmg / sec)) .. "|r"
end
local Clock = ns.Clock
local function Icon(id)
    if type(id) == "string" then return id end
    return id and ns.Effects.IconById(id) or UNKNOWN_ICON
end
local function PageWheel(delta)
    return pane ~= nil and pane:Wheel(delta)
end
local function ChatCtx()
    return fight and ns.ChatReport.FightCtx(fight, summary) or ""
end
local function Stat(i)
    stats[i] = stats[i] or Badges.Total(content, true)
    return stats[i]
end
local function Panel(i)
    return Badges.DetailAt(panels, i, content, ChatCtx)
end
local function Head(i)
    local fs = heads[i]
    if fs then return fs end
    fs = Kit.Str(content, "GameFontNormal")
    ns.Kit.Text(fs, "text.title")
    fs:SetJustifyH("LEFT")
    heads[i] = fs
    return fs
end
local function OpenTimeline(name)
    if fight and ns.ReplayLink and ns.ReplayLink.Shift(fight, fight.from, name) then return end
    if ns.Timeline and ns.Timeline.SelectPlayer then ns.Timeline.SelectPlayer(name) end
end
local function OpenManual(name)
    if fight and ns.GPList then ns.GPList.ManualMenu(fight, name) end
end
local function Tile(i)
    tiles[i] = tiles[i] or Badges.Personal(content, true)
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
    if ns.Store.Bare(fight) then return m end
    m.fight, m.at = fight, t
    m.preview = ns.DeathPreview and ns.DeathPreview.Wants(kind) or nil
    if ns.TimelineLinks and m.lines then ns.TimelineLinks.Tag(m.lines, fight, t) end
    return m
end
local function Proof(p, test, deaths)
    if not ns.Proof then return nil end
    return ns.Proof.Ask(fight, p.name, pens[p.name], test, deaths)
end
local function Hidden(def)
    return ns.SumHide ~= nil and fight ~= nil and ns.SumHide.Hidden(fight.boss, def)
end
local function Shows(key)
    return not ns.SumHide or ns.SumHide.Shows(key)
end
local function TombBadge(st, def)
    local list, pts, grade = ns.TombBreak.Shown(st, ns.TombBreak.Limit(def, fight))
    if #list == 0 then return nil, nil end
    return tostring(floor(pts + 0.5)), grade
end
local function DispelMark(d)
    local m = { icon = Icon(d.id), count = tostring(d.n), lines = Tips.Dispel(d) }
    local list = d.list or {}
    local first = list[1]
    if not first then return m end
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
        local play = ns.ReplayLink and ns.ReplayLink.Play(fight, m.at)
        m.lines[#m.lines + 1] = play
        m.lines[#m.lines + 1] = { kind = "foot", key = play and "shift" or "lmb",
            left = format(ns.T("sum.tip.dispelclick"), first.who, Clock(max(0, first.t))) }
    end
    return m
end
local function SniffMark(p, s)
    local jo = p.jopo
    if not jo or not ns.pullSniff then return nil end
    local sec = Tips.Dec(jo.t, 1)
    local lines = { { kind = "head", left = ns.T("rsum.d.jopo") },
        { kind = "row", left = ns.T("sum.jopo.hit"), right = format(ns.T("sum.jopo.at"), sec) } }
    if jo.kill then lines[#lines + 1] = { kind = "row", left = ns.T("sum.jopo.kill"), tone = "bad" } end
    return Replay({ icon = Icon(ns.pullSniff.icon), count = sec, verdict = jo.kill and "red" or "yellow",
        lines = lines }, (s.pull and s.pull.t or fight.from) + jo.t)
end
local function ConsMarks(list, p)
    local cons = p.cons
    if not cons or #cons == 0 then return end
    local by, order = {}, {}
    for k = 1, #cons do
        local e = cons[k]
        local key = e.id or e.item
        if not by[key] then
            by[key] = {}
            order[#order + 1] = key
        end
        local g = by[key]
        g[#g + 1] = e
    end
    for k = 1, #order do
        local g = by[order[k]]
        local e = g[1]
        local tex = e.id and GetItemIcon and GetItemIcon(e.id) or Icon(e.spell)
        list[#list + 1] = Replay({ icon = tex, count = tostring(#g), lines = Tips.Cons(g) }, fight.from + e.t)
    end
end
local function Entries(p, s)
    local list = {}
    local P = ns.Proof
    if p.deaths > 0 then
        local counted, worst = ns.DeathGrade.Skull(p)
        local ready = ns.DeathGrade.Ready(p)
        local pair = #ready > 0 and "death" or nil
        local skull = Replay({ icon = SKULL_ICON, count = counted > 0 and tostring(counted) or "—",
            verdict = worst, pair = pair, lines = Tips.Death(p, fight),
            proof = P and Proof(p, P.IsDeath, true) }, First(p.deathInfo, "t"), "skull")
        list[#list + 1] = skull
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
    local caused = ns.DeathDeps and ns.DeathDeps.Caused(s, p) or {}
    if #caused > 0 then
        local victims, fired = {}, false
        for k = 1, #caused do victims[k] = caused[k].victim end
        for _, hit in ipairs(pens[p.name] or {}) do fired = fired or hit.rule.kind == "caused" end
        local dep = caused[1].dep
        list[#list + 1] = Replay({ icon = Icon(dep.spell and s.spellIds[dep.spell] or SKULL_ICON), count = tostring(#caused),
            verdict = fired and "red" or "yellow", links = victims, lines = Tips.Caused(caused, fight),
            proof = P and fired and Proof(p, P.ByKind("caused")) or nil }, caused[1].t)
    end
    local mark = ns.MindCtl.Mark(p)
    if mark then
        list[#list + 1] = Replay({ icon = mark.armed and CTL_ICON or Icon(CTL_SPELL), count = tostring(mark.count),
            verdict = mark.verdict, links = #mark.kills > 0 and mark.kills or nil, lines = Tips.Control(p, fight),
            proof = P and Proof(p, P.ByKind("mcweapon")) }, First(p.ctl, "t"))
    end
    local early = ns.PullTimer and ns.PullTimer.EarlyOf(s, p.name)
    if early then
        list[#list + 1] = Replay({ icon = Icon(ns.pullTimer.icon), count = Tips.Dec(early.early, 1),
            verdict = "yellow", lines = Tips.EarlyPull(early, s.pull.t),
            proof = P and Proof(p, P.ByKind("earlypull")) }, s.pull.t)
    end
    local sniff = SniffMark(p, s)
    if sniff then list[#list + 1] = sniff end
    local duties = ns.Penalties and ns.Penalties.Duties(s, fight, p) or {}
    local forced, dutyIcon = {}, {}
    for k = 1, #duties do
        local d = duties[k]
        local cover, own = ns.Actions.Covers(s, p, d)
        if type(cover) == "number" then
            forced[cover], dutyIcon[cover] = d.n < d.need, own
        elseif not cover then
            list[#list + 1] = { icon = Icon(d.id), count = tostring(d.n), verdict = Verdict(d.n < d.need),
                lines = Tips.Duty(ns.Penalties.Reason(d.rule), d.n, d.need),
                proof = P and d.n < d.need and Proof(p, P.ByKey(d.rule.key)) or nil }
        end
    end
    local spared = ns.Penalties and ns.Penalties.Spared(s, fight, p) or {}
    for k = 1, #spared do
        list[#list + 1] = { icon = Icon(ns.Penalties.ICONS.mindps), count = Rate(spared[k].amount), verdict = "green",
            lines = Tips.Spared(spared[k]) }
    end
    local fired = {}
    for _, hit in ipairs(pens[p.name] or {}) do
        local grade = ns.Penalties.Grade(hit)
        for _, sp in ipairs(hit.rule.spells or {}) do
            local k = ns.SpellKey(sp)
            fired[k] = fired[k] == "red" and "red" or grade
        end
        if hit.rule.npc then fired[ns.NpcKeyOf(hit.rule.npc)] = "red" end
    end
    for i = 1, #s.badges do
        local st = p.badges[i]
        local bd = s.badges[i]
        if st and (st.n > 0 or (st.removed or 0) > 0 or forced[i] ~= nil) and not Hidden(bd)
            and (bd.kind ~= "tombbreak" or TombBadge(st, bd)) then
            local shown = bd.low and (st.min or 0) or (bd.kind == "stack" and not bd.pass and st.max or st.n)
            local alert = st.cleansed > 0
            local text = alert and format("%d!", shown) or tostring(shown)
            if bd.kind == "stack" and (bd.low and st.min == nil or st.max == 0) then
                text, alert = "—", false
            end
            if bd.kind == "dmgto" then text, alert = Short(st.amount), false end
            local grade
            if bd.low and st.min == 0 then grade = "red" end
            if bd.kind == "cc" or bd.kind == "wrath" then
                text = format("%d/%d", st.hits, st.n)
                grade = ns.Actions.Grade(st.n, st.hits, forced[i])
            end
            if bd.kind == "pullin" then text = format("%d/%d", st.hits, st.n) end
            if bd.kind == "away" and st.avg then text, grade = tostring(floor(st.avg + 0.5)), ns.Away.Grade(st, bd, fight) end
            if bd.kind == "tombbreak" then text, grade = TombBadge(st, bd) end
            if bd.shed and st.hangs then
                local shed = 0
                for k = 1, #st.hangs do
                    if st.hangs[k].off == "shed" then shed = shed + 1 end
                end
                text = format("%d/%d", shed, #st.hangs)
                grade = shed > 0 and (bd.want == "shed" and "green" or "yellow") or nil
            end
            local first = First(st.times)
            local linked = bd.kind == "killer" or bd.kind == "given" or bd.kind == "got"
                or (bd.kind == "applied" and not bd.names) or LINKED[bd.kind] == true
            local what = ns.SpellKey(bd.spell) or ns.NpcKeyOf(bd.npc)
            local ask
            if P and bd.kind == "killer" then
                ask = Proof(p, P.ByKind("killer"))
            elseif P and what and fired[what] then
                ask = Proof(p, P.BySpell(what))
            end
            list[#list + 1] = Replay({ icon = Icon(st.icon or dutyIcon[i] or s.icons[i]),
                proof = ask,
                count = text,
                alert = alert,
                verdict = Verdict(fired[what or ""] == "red" or bd.kind == "killer")
                    or (fired[ns.SpellKey(bd.spell) or ""] == "yellow" and "yellow") or grade or st.grade or bd.grade,
                links = linked and st.notes or (bd.kind == "chased" and st.blasted) or nil,
                arrow = ARROWS[bd.kind],
                lines = Tips.Badge(st, bd, fight) }, first and fight.from + first, bd.kind)
        end
    end
    for k = 1, #p.kickList do
        local kk = p.kickList[k]
        local at = kk.at and kk.at[1]
        list[#list + 1] = Replay({ icon = Icon(kk.id), count = kk.all and format("%d/%d", kk.n, kk.all) or tostring(kk.n),
            verdict = kk.all and ns.Actions.Grade(kk.all, kk.n) or nil, lines = Tips.Kick(kk) }, at and fight.from + at, "kick")
    end
    for k = 1, #p.dispList do
        list[#list + 1] = DispelMark(p.dispList[k])
    end
    if Shows("#cons") then ConsMarks(list, p) end
    return list
end
local function PersonalModel(p, s)
    local value, sub
    local sec = ns.Totals.Time(s)
    if p.role == "heal" then
        value = format(ns.T("sum.hps"), Rate(p.heal / sec))
        sub = ""
    else
        value = format(ns.T("sum.dps"), Rate(Good(p) / sec))
        sub = AllLine(p.dmg, sec)
    end
    local m = {
        name = p.name,
        class = p.class,
        value = value,
        sub = sub,
        marks = Entries(p, s),
        lines = Tips.Player(p, s),
        onClick = OpenTimeline,
        onRightClick = OpenManual,
        onWheel = PageWheel,
    }
    if ns.ExpectView then ns.ExpectView.Personal(fight, s, p, m) end
    return m
end
local function TotalHead(m)
    local right = m.corner and (m.value .. "  " .. m.corner) or m.value
    if m.sub and m.sub ~= "" then right = right .. "  " .. m.sub end
    return { kind = "head", left = m.title, right = right }
end
local function PullTotal(s, m)
    local pull = s.pull
    if not pull or not pull.src then return end
    local W = ns.PullWho
    local icon = (not pull.body) and (pull.sid and ns.SpellIcon(pull.sid) or (not pull.spell and CTL_ICON)) or nil
    local mark = icon and format("|T%s:0|t ", icon) or ""
    local early = pull.timer and pull.timer.early
    m.subs = { mark .. format(ns.T("sum.pull.line"), W.Who(pull), W.How(pull)) }
    if early then m.subs[2] = ns.Kit.Hex("text.warn") .. format(ns.T("sum.pull.early"), Tips.Dec(early, 1)) .. "|r" end
    m.lines = { TotalHead(m), { kind = "text", left = mark .. W.Text(pull) } }
    if pull.timer then
        local key = early and "sum.pull.timerearly" or "sum.pull.timer"
        m.lines[3] = { kind = "text", left = format(ns.T(key), pull.timer.sec, pull.timer.who, Tips.Dec(early or 0, 1)) }
    end
end
local function WipeTotal(s, m)
    local cause = ns.DeathDeps and ns.DeathDeps.FirstCause(s, fight, pens)
    if not cause then return end
    local at = Clock(max(0, cause.t - fight.from))
    m.subs = m.subs or {}
    m.subs[#m.subs + 1] = format(ns.T("sum.dd.firstshort"), cause.who, at)
    m.lines = m.lines or { TotalHead(m) }
    m.lines[#m.lines + 1] = { kind = "text", left = format(ns.T("sum.dd.first"), cause.text, cause.who, at) }
end
local function MarksTotal(s, m)
    local list = s.marks
    if not list or #list == 0 or not ns.DevMarks then return end
    local parts = {}
    m.lines = m.lines or { TotalHead(m) }
    m.lines[#m.lines + 1] = { kind = "text", left = ns.T("sum.marks.head") }
    for i = 1, #list do
        local mk = list[i]
        local at = Clock(max(0, mk.t - fight.from))
        local label = ns.DevMarks.Label(mk.key, mk.text)
        parts[i] = format(ns.T("sum.marks.item"), label, at)
        m.lines[#m.lines + 1] = { kind = "row", left = label, right = at }
    end
    m.subs = m.subs or {}
    m.subs[#m.subs + 1] = format(ns.T("sum.marks.short"), table.concat(parts, ", "))
end
local function ZoneTotal(s, m)
    if not (fight.killed and ns.ZoneBuff and s.zoneBuff == ns.ZoneBuff.OFF) then return end
    m.unbuff = true
    m.subs = m.subs or {}
    m.subs[#m.subs + 1] = ns.T("zb.short")
    m.lines = m.lines or { TotalHead(m) }
    m.lines[#m.lines + 1] = { kind = "text", left = ns.T("zb.kill") }
end
local function RateReport(heal, n)
    if not (fight and summary and ns.ChatReport) then return {} end
    return ns.ChatReport.Summary(fight, summary, n, heal)
end
local function DpsReport(n)
    return RateReport(false, n)
end
local function HpsReport(n)
    return RateReport(true, n)
end
local function AllClick(self, button)
    local who = self.allWho
    if not who then return end
    ns.WidgetModal.Close()
    if button == "RightButton" then OpenManual(who) else OpenTimeline(who) end
end
local function PaintAll(row, e)
    if not e then
        if row.allRank then
            row.allRank:Hide()
            row.allBar:Hide()
            row:SetScript("OnMouseUp", nil)
        end
        row.allWho = nil
        return
    end
    local f = row:GetParent()
    if not row.allRank then
        row.allBar = row:CreateTexture(nil, "BACKGROUND")
        row.allBar:SetTexture(WHITE8)
        row.allBar:SetAlpha(BAR_A)
        row.allBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        row.allBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        row.allRank = Kit.Str(row, "GameFontHighlightSmall")
        row.allRank:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.allRank:SetJustifyH("LEFT")
        Kit.Text(row.allRank, "text.note")
    end
    local r = e.data
    f.probe:SetText(tostring(#f.list))
    row.allRank:SetWidth(math.ceil(f.probe:GetStringWidth() or 0) + 6)
    row.allRank:SetText(r.lead or "")
    row.allRank:Show()
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.allRank, "RIGHT", 0, 0)
    row.name:SetPoint("RIGHT", row.val, "LEFT", -4, 0)
    local width = (f:GetWidth() or 0) - 6 - (f.rowR or 0)
    row.allBar:SetVertexColor(ns.GPList.ClassRGB(r.class))
    row.allBar:SetWidth(max(1, width * math.min(1, r.fill or 0)))
    row.allBar:Show()
    if not e.lines and r.tip then e.lines = r.tip(r.a, r.b, r.c, r.d) end
    row.lines = e.lines
    row.allWho = e.who
    row:SetScript("OnMouseUp", AllClick)
end
local function OpenAll(heal)
    local set = rateBtns[heal and "hps" or "dps"]
    if not (summary and set and set.owner and ns.MiniRows and ns.WidgetModal) then return end
    local out = {}
    ns.MiniRows.Dps(out, summary, heal)
    local rows = {}
    for i = 1, #out do
        local r = out[i]
        if r.kind == "row" then rows[#rows + 1] = { who = r.left, class = r.class, text = r.val, note = r.pct, data = r } end
    end
    ns.WidgetModal.Open(set.owner, { title = ns.T(heal and "sum.s.hps" or "sum.s.dps"), rows = rows,
        empty = ns.T("sum.k.none"), paint = PaintAll, chat = heal and HpsReport or DpsReport })
end
local function OpenDps()
    OpenAll(false)
end
local function OpenHps()
    OpenAll(true)
end
local function HideRate(key)
    local set = rateBtns[key]
    if not set then return end
    if set.chat then set.chat:Hide() end
    set.all:Hide()
    set.owner = nil
end
local function RateButtons(f, heal)
    local key = heal and "hps" or "dps"
    local set = rateBtns[key]
    if not set then
        set = { all = Badges.Expand(f, heal and OpenHps or OpenDps) }
        if ns.ProofView and ns.ChatReport then
            set.chat = ns.ProofView.ReportButton(f, heal and HpsReport or DpsReport, heal)
            set.chat.tip = ns.T(heal and "report.tip.heal" or "report.tip")
        end
        rateBtns[key] = set
    end
    set.owner = f
    local x = BTNGAP
    local b = set.chat
    if b then
        b:SetParent(f)
        b:SetHeight(CHATH)
        b:SetWidth(floor(b.text:GetStringWidth() + 0.5) + CHATPAD)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, -BTNGAP)
        b:SetFrameLevel(f:GetFrameLevel() + 2)
        b:Show()
        x = x + b:GetWidth() + BTNGAP
    end
    local a = set.all
    a:SetParent(f)
    a:ClearAllPoints()
    a:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, -BTNGAP)
    a:SetFrameLevel(f:GetFrameLevel() + 2)
    a:Show()
    return x + a:GetWidth()
end
local function DrawStats(s, w)
    local sec = ns.Totals.Time(s)
    local cells = {
        { "sum.s.result", fight.killed and ns.T("sum.win") or ns.T("sum.wipe"), "",
          ns.Kit.C[fight.killed and "sem.win" or "sem.wipe"] },
    }
    if Shows("#t.dps") then
        cells[#cells + 1] = { "sum.s.dps", Rate(Good(s) / sec), AllLine(s.dmg, sec), ns.Kit.C["sem.stat.dps"] }
    else
        HideRate("dps")
    end
    if Shows("#t.hps") then
        cells[#cells + 1] = { "sum.s.hps", Short(s.heal / sec), Short(s.heal), ns.Kit.C["sem.stat.hps"] }
    else
        HideRate("hps")
    end
    if Shows("#t.deaths") then
        cells[#cells + 1] = { "sum.s.deaths", tostring(s.deaths), "", ns.Kit.C["sem.stat.deaths"] }
    end
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
        if c[1] == "sum.s.result" then
            m.corner = Clock(s.dur)
            PullTotal(s, m)
            WipeTotal(s, m)
            MarksTotal(s, m)
            ZoneTotal(s, m)
        end
        if c[1] == "sum.s.dps" or c[1] == "sum.s.hps" then
            m.lines = Tips.Combat(s, m.title, m.value, c[1] == "sum.s.dps" and s.dmg or s.heal)
        end
        if c[1] == "sum.s.dps" and ns.ExpectView then ns.ExpectView.Total(fight, s, m) end
        if c[1] == "sum.s.dps" or c[1] == "sum.s.hps" then
            local heal = c[1] == "sum.s.hps"
            m.reserve = RateButtons(f, heal)
            m.open = heal and OpenHps or OpenDps
            m.lines[#m.lines + 1] = { kind = "foot", key = "lmb", left = ns.T("sum.all.foot") }
        end
        f:SetModel(m)
        list[i] = f
    end
    return Grid.Place(list, MARGIN, MARGIN, w, FitW(list, TOTALMIN, w), GAP, true)
end
local function OpenPage()
    if ns.FaultsPage then ns.FaultsPage.Open("give", fight) else ns.Print(ns.T("slash.diag.restart")) end
end
local function FitButton(b, text)
    b.text:SetText(text)
    b:SetWidth(max(BTNMIN, floor(b.text:GetStringWidth() + 0.5) + BTNPAD))
end
local function FailHeadEnter(self)
    ns.Tip.Show(self, {
        { kind = "head", left = failPanel.title:GetText() },
        { kind = "note", left = ns.T("sum.gp.hint") },
    })
end
local function FailFolded()
    local folded = ns.GetDB().settings.ui.gpFold
    if folded ~= nil then return folded == true end
    return not (GetNumRaidMembers() > 0 and ns.Raid.IsLead())
end
local function FailLayout(self, width)
    local model = self.model
    local fm = FailMetrics()
    local top = self.inside and fm.line or (fm.sideHead + BTNH + 6)
    local h = top
    local rows = model and #ns.FaultTable.Rows(model, self.list.filter) or 0
    local cap = self.inside and GPCAP or rows
    self.offset = max(0, math.min(self.offset or 0, rows - cap))
    Kit.Arrow(self.arrow, not FailFolded())
    local room = width - 14
    local more = self.inside and rows > GPCAP and not FailFolded()
    if more then self.expand:Show() else self.expand:Hide() end
    if self.inside then
        self.all:ClearAllPoints()
        if more then
            self.all:SetPoint("RIGHT", self.expand, "LEFT", -6, 0)
        else
            self.all:SetPoint("TOPRIGHT", -6, -4)
        end
    end
    if self.inside then
        room = width - 36
        for _, b in ipairs({ self.expand, self.all, self.pop, self.cfg, self.rolls, self.chat }) do
            if b:IsShown() then room = room - b:GetWidth() - 6 end
        end
    end
    if self.titles then
        ns.FaultTable.Pick(self.title, room, self.titles[1], self.titles[2], self.titles[3])
        if self.title:GetText() == "" then self.title:SetText(self.titles[3]) end
    end
    if model and #model.items > 0 and not FailFolded() then
        self.list:Show()
        self.listW = width
        h = top + 2 + self.list:Draw(fight, model, width, self.offset, cap)
    else
        self.list:Hide()
    end
    self:SetWidth(width)
    self:SetHeight(h)
    return h
end
local function FailWheel(f, page)
    return function(delta)
        local rows = f.model and #ns.FaultTable.Rows(f.model, f.list.filter) or 0
        local was = f.offset or 0
        if f.inside and rows > GPCAP then
            f.offset = max(0, math.min(rows - GPCAP, was - delta))
        end
        if f.offset == was then return page(delta) end
        f.list:Draw(fight, f.model, f.listW or f:GetWidth(), f.offset, GPCAP)
        return true
    end
end
local function Inside()
    return not ns.SumSide or ns.SumSide.Inside()
end
local SideWheel = ns.SumSide and ns.SumSide.PageWheel(PageWheel) or PageWheel
local function HeadLine(f, font)
    local fs = Kit.Str(f.head, font)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end
local function FailMode(f, inside)
    local fm = FailMetrics()
    f.inside = inside
    f:SetParent(inside and content or ns.SumSide.Content())
    f.all:ClearAllPoints()
    f.cfg:ClearAllPoints()
    f.pop:ClearAllPoints()
    f.rolls:ClearAllPoints()
    f.chat:ClearAllPoints()
    f.expand:ClearAllPoints()
    if inside then
        f.all:SetPoint("TOPRIGHT", -6, -4)
        f.expand:SetPoint("TOPRIGHT", -6, -(4 + (BTNH - f.expand:GetHeight()) / 2))
        f.pop:SetPoint("RIGHT", f.all, "LEFT", -6, 0)
        f.cfg:SetPoint("RIGHT", f.pop, "LEFT", -6, 0)
        f.rolls:SetPoint("RIGHT", f.cfg, "LEFT", -6, 0)
        f.chat:SetPoint("RIGHT", f.rolls, "LEFT", -6, 0)
    else
        f.cfg:SetPoint("TOPLEFT", 0, -fm.side)
        f.pop:SetPoint("LEFT", f.cfg, "RIGHT", 6, 0)
        f.chat:SetPoint("LEFT", f.pop, "RIGHT", 6, 0)
        f.rolls:SetPoint("TOPLEFT", 0, -(fm.sideHead + 2))
        f.all:SetPoint("TOPRIGHT", 0, -fm.side)
        f.expand:Hide()
    end
    f.head:ClearAllPoints()
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.title:ClearAllPoints()
    f.preset:ClearAllPoints()
    f.arrow:ClearAllPoints()
    if inside then
        if FailFolded() then
            f.head:SetPoint("TOPRIGHT", -6, 0)
        else
            f.head:SetPoint("RIGHT", f.chat, "LEFT", -8, 0)
        end
        f.head:SetHeight(fm.line)
        f.arrow:SetPoint("LEFT", f.head, "LEFT", 8, 0)
        f.title:SetPoint("LEFT", f.arrow, "RIGHT", 4, 0)
        f.preset:SetPoint("LEFT", f.title, "RIGHT", GPGAP, 0)
        f.preset:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
        f.preset:Show()
    else
        f.head:SetPoint("TOPRIGHT", 0, 0)
        f.head:SetHeight(fm.side)
        f.arrow:SetPoint("TOPLEFT", f.head, "TOPLEFT", 0, -GPTITLE - 2)
        f.title:SetPoint("TOPLEFT", f.arrow, "TOPRIGHT", 4, 2)
        f.title:SetPoint("TOPRIGHT", f.head, "TOPRIGHT", 0, -GPTITLE)
        f.preset:Hide()
    end
    local other = inside and f.narrow or f.wide
    other:Hide()
    f.list = inside and f.wide or f.narrow
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", 0, -((inside and fm.line or (fm.sideHead + BTNH + 6)) + 2))
end
local function FailPanel()
    if failPanel then return failPanel end
    local f = CreateFrame("Frame", nil, content)
    f.sized = true
    f.all = ns.MakeButton(f, "HTP_FailWatchGPAll", "main")
    f.all:SetHeight(BTNH)
    f.all.onClick = function()
        if fight and gpModel then ns.GPList.Issue(fight, gpModel.all) end
    end
    f.pop = ns.Kit.IconButton(f, "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\gp.tga", 16, "HTP_FailWatchGPOpen")
    f.pop.tipTitle = false
    f.pop.tip = ns.T("sum.gp.open")
    f.pop.onClick = OpenPage
    f.cfg = ns.MakeButton(f, "HTP_FailWatchGPSys", "quiet")
    f.cfg:SetHeight(BTNH)
    f.cfg.tip = ns.T("gpset.pick")
    f.cfg.onClick = function() if ns.FaultsPage then ns.FaultsPage.SystemMenu(f.cfg) end end
    f.rolls = ns.MakeButton(f, "HTP_FailWatchRollSummary", "quiet")
    f.rolls:SetHeight(BTNH)
    FitButton(f.rolls, ns.T("roll.summary.button"))
    f.rolls.tip = ns.T("roll.summary.tip")
    f.rolls.onClick = function() ns.FaultsRoll.OpenSummary(fight) end
    f.expand = Badges.Expand(f, function() ns.FaultTable.OpenAll(f) end)
    f.chat = Badges.ChatIcon(f, function(n) return ns.GPList.ChatLines(f.fight, ns.Summary.Peek(f.fight), f.model, n) end,
        "report.menu.list", "report.none.list")
    f.head = CreateFrame("Button", nil, f)
    f.head:EnableMouse(true)
    f.head:SetScript("OnEnter", FailHeadEnter)
    f.head:SetScript("OnLeave", function() ns.Tip.Hide() end)
    f.head:SetScript("OnClick", function()
        local ui = ns.GetDB().settings.ui
        ui.gpFold = not FailFolded()
        ns.Tip.Hide()
        if Render then Render() end
    end)
    f.arrow = f.head:CreateTexture(nil, "ARTWORK")
    f.arrow:SetWidth(10)
    f.arrow:SetHeight(10)
    f.title = HeadLine(f, "GameFontNormal")
    ns.Kit.Text(f.title, "text.title")
    f.preset = HeadLine(f, "GameFontHighlightSmall")
    ns.Kit.Text(f.preset, "text.secondary")
    f.narrow = ns.GPList.New(f, "HTP_FailWatchGPRow", ns.GPList.COMPACT, true)
    f.narrow.onWheel = FailWheel(f, SideWheel)
    f.wide = ns.GPList.New(f, "HTP_FailWatchGPWide", nil, true)
    f.wide.onWheel = FailWheel(f, SideWheel)
    f.Layout = FailLayout
    failPanel = f
    return f
end
local function FailItem(model)
    if not model then return nil end
    local f = FailPanel()
    FailMode(f, Inside())
    if Inside() then Badges.Skin(f, style.red) else Badges.Bare(f) end
    if f.fight ~= fight then f.offset = 0 end
    f.fight, f.model = fight, model
    local sums = ns.GPList.SumText(model.by or {})
    f.titles = { ns.GPList.Title(model), format(ns.T("sum.gp.title"), model.ready, sums), format(ns.T("sum.gp.short"), sums) }
    f.title:SetText(f.titles[1])
    f.preset:SetText("")
    FitButton(f.all, ns.GPList.AllText(model))
    FitButton(f.cfg, ns.Ledger.Label())
    FitButton(f.rolls, ns.T("roll.summary.button"))
    if model.pending > 0 then f.all:Enable() else f.all:Disable() end
    if FailFolded() or #model.items == 0 then f.chat:Hide() else f.chat:Show() end
    if ns.ReadOnly or FailFolded() then
        f.all:Hide()
        f.cfg:Hide()
        f.pop:Hide()
        f.rolls:Hide()
    else
        f.all:Show()
        f.cfg:Show()
        f.pop:Show()
        f.rolls:Show()
    end
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
        elseif kind == "parries" then
            text = ns.ActionTips.ParryText(b, who, v)
        elseif kind == "pullins" then
            text = ns.PullTips.Text(b, who, v)
        else
            text = format("%s  %s%s%%|r", Short(v), ns.Kit.Hex("text.note"), ns.Fixed(v * 100 / max(1, b.total)))
        end
        local known = summary.byName and summary.byName[who]
        local class = ns.Encounters.ClassOf(who) or (known and known.class)
        local lines = kind == "shades" and ns.ActionTips.Shades(b, who, class)
            or kind == "pullins" and ns.PullTips.Row(summary, b, who, class) or Tips.Row(b, who, v, class)
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
local function BlockTitle(b, name)
    local kind = b.def.kind
    local label = name or ns.T(b.label or b.def.label)
    if kind == "casts" then return format(ns.T("sum.k.casts"), label, b.total, b.casts) end
    if kind == "shades" then return format(ns.T("sum.k.shadestitle"), label, b.caught, b.summoned) end
    local value = (kind == "dispels" or kind == "removed" or kind == "parries" or kind == "pullins") and tostring(b.total)
        or Short(b.total)
    return format(ns.T("sum.k.title"), label, value)
end
local function BlockPanel(s, i, slot)
    local b = s.blocks[i]
    local f = Panel(slot)
    local mechanic = Tips.Mechanic(b)
    f:SetModel({
        title = BlockTitle(b, mechanic.label),
        icon = mechanic.icon,
        link = mechanic.link,
        tip = mechanic.tip,
        rows = BlockList(b),
        empty = ns.T("sum.k.none"),
        onWheel = PageWheel,
    })
    return f
end
local function ClassOf(who)
    local known = summary.byName and summary.byName[who]
    return ns.Encounters.ClassOf(who) or (known and known.class)
end
local function WidePanel(v, slot, b)
    local f = wides[slot]
    if not f then
        f = Badges.Wide(content, nil, true)
        Badges.ChatHead(f, ChatCtx)
        wides[slot] = f
    end
    local rows = {}
    for i = 1, #v.rows do
        local r = v.rows[i]
        local marks = {}
        for k = 1, #(r.marks or {}) do
            local mk = r.marks[k]
            marks[k] = mk and { icon = Icon(mk.id), count = mk.n and tostring(mk.n) or "" } or false
        end
        rows[i] = { who = r.who, class = r.class, sub = r.sub, cells = r.cells, vals = r.vals, marks = marks,
                    lines = r.lines, tips = r.tips, tones = r.tones, pin = r.pin, tone = r.tone, fight = r.fight, at = r.at }
    end
    local heads, colIcons = {}, {}
    for k = 1, #(v.heads or {}) do heads[k] = v.heads[k] and Icon(v.heads[k]) or false end
    for k = 1, #(v.colIcons or {}) do colIcons[k] = v.colIcons[k] and Icon(v.colIcons[k]) or false end
    local mechanic = Tips.Mechanic(b)
    if v.spell then mechanic = { icon = ns.SpellIcon(v.spell), link = "spell:" .. v.spell } end
    f:SetModel({ title = v.title or BlockTitle(b, mechanic.label), total = v.total, cols = v.cols, heads = heads,
                 colIcons = colIcons, rows = rows, tip = v.tip or mechanic.tip, chat = v.chat,
                 icon = mechanic.icon, link = mechanic.link,
                 empty = ns.T("sum.k.none"), onWheel = PageWheel })
    return f
end
local function DetailGrid(list, y, w)
    local minW = MinW(DETAILMIN)
    local fit, cell = Grid.Fit(math.floor(w), minW, GAP)
    for i = 1, #list do
        local f = list[i]
        f.span = (f.wide and fit > 1 and f:Need() > cell) and 2 or 1
    end
    return Grid.Place(list, MARGIN, y, w, minW, GAP, true)
end
local function DrawBlocks(s, y, w)
    local list = {}
    local np, nw = 0, 0
    for i = 1, #s.blocks do
        local b = s.blocks[i]
        if not Hidden(b.def) then
            local AT = ns.ActionTips
            local v = AT and AT.KickCtlView and AT.KickCtlView(b, s, ClassOf, fight, Replay)
            if v then
                for k = 1, #v - 1 do
                    nw = nw + 1
                    list[#list + 1] = WidePanel(v[k], nw, b)
                end
                v = v[#v]
            end
            if v == nil then v = ns.Putri and ns.Putri.View(b, ClassOf, s) end
            if v == nil then
                v = (ns.Valkyr and ns.Valkyr.View(b, s, ClassOf)) or (ns.Uld and ns.Uld.View(b, s, ClassOf))
                    or (ns.Targets and ns.Targets.View(b, ClassOf)) or (ns.Cures and ns.Cures.View(b, ClassOf))
            end
            if v then
                nw = nw + 1
                list[#list + 1] = WidePanel(v, nw, b)
            elseif v == nil then
                np = np + 1
                list[#list + 1] = BlockPanel(s, i, np)
            end
        end
    end
    local loot = Shows("#loot") and ns.Loot and fight and ns.Loot.FightDetail(fight)
    if loot then
        np = np + 1
        local f = Panel(np)
        f:SetModel({ title = loot.title, rows = loot.rows, empty = loot.empty, onWheel = PageWheel, fit = true })
        list[#list + 1] = f
    end
    for i = np + 1, #panels do panels[i]:Hide() end
    for i = nw + 1, #wides do wides[i]:Hide() end
    return DetailGrid(list, y, w)
end
local function DrawFails(y, w)
    local gp = Shows("#faults") and FailItem(gpModel) or nil
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
            y = Grid.Place(list, MARGIN, y + max(HEADH, Pt("GameFontNormal") + 8), w, MinW(TILEMIN), GAP)
        else
            h:Hide()
        end
    end
    for i = used + 1, #tiles do tiles[i]:Hide() end
    return y
end
function Render()
    if not host or not host:IsShown() then return end
    pane:Laid()
    local file = fight and ns.RaidArtFile and ns.RaidArtFile(fight.boss, fight.raid and fight.raid.map) or nil
    ns.Kit.RaidArtSet(art, host, file)
    if failPanel then failPanel:Hide() end
    for i = 1, #stats do stats[i]:Hide() end
    for i = 1, #panels do panels[i]:Hide() end
    for i = 1, #wides do wides[i]:Hide() end
    for i = 1, #heads do heads[i]:Hide() end
    for i = 1, #tiles do tiles[i]:Hide() end
    Badges.ResetLinks()
    local w = max(200, host:GetWidth() - MARGIN * 2 - BAR_ROOM)
    content:SetWidth(host:GetWidth())
    if not summary then
        laid = {}
        if ns.SumSide then ns.SumSide.Show("fight", {}) end
        local err = fight and ns.Summary.Failed(fight)
        hint:SetText(err and format(ns.T("sum.fail"), err) or ns.T("sum.busy"))
        hint:Show()
        content:SetHeight(host:GetHeight())
        pane:Rescroll()
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
    pane:Rescroll()
    if keep then
        pane:ScrollTo(keep)
        keep = nil
    end
end
function View.Attach(frame)
    host = frame
    bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    ns.Kit.Paint(bg, "surface.page")
    art = ns.Kit.RaidArt(host)
    pane = ns.Kit.ScrollPage(host, { fill = true, bar = "deck", inset = MARGIN,
        relayout = function() Render() end, prof = "ui.sum" })
    content = pane.content
    host.sized = true
    hint = Kit.Str(content, "GameFontHighlight")
    ns.Kit.Text(hint, "text.bright")
    hint:SetPoint("TOPLEFT", MARGIN * 2, -MARGIN * 2)
    hint:SetPoint("RIGHT", host, "RIGHT", -MARGIN * 2, 0)
    hint:SetJustifyH("LEFT")
    host:Hide()
    if ns.SumSide then ns.SumSide.Watch("fight", host, function() Render() end) end
end
function View.Show(f)
    if not host then return end
    fight = f
    pane.offset = 0
    keep = nil
    summary = ns.Summary.Peek(f)
    host:Show()
    Render()
    if not summary then
        ns.Summary.Of(f, function(s)
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
    for i = 1, #wides do
        if wides[i]:IsShown() then out[#out + 1] = wides[i] end
    end
    return out
end
function View.Refresh()
    Render()
end
function View.Fight()
    return fight
end
function View.Offset()
    return pane and pane.offset or 0
end
function View.ScrollTo(y)
    if not pane then return end
    if summary then pane:ScrollTo(y) else keep = y end
end
if ns.GPList then ns.GPList.OnChange(function() Render() end) end
Kit.OnFont(function() Render() end)
function View.Relayout()
    if not host or not host:IsShown() then return end
    ns.Kit.RaidArtFit(art, host)
    pane:Relayout()
end
function View.IsShown()
    return host ~= nil and host:IsShown() and true or false
end
function View.Probe()
    return { host = host, content = content }
end
ns.Jobs.OnChange(function()
    if not summary and fight and View.IsShown() and ns.Summary.Failed(fight) then Render() end
end)
