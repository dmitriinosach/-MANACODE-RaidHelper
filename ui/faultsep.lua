local _, ns = ...
local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local Kit = ns.Kit
local CELL_GAP = 10
local EDIT_W = 62
local NAME_W = 120
local COL_GAP = 6
local COL_EDGE = 2
local CHK_W = 24
local WHO_MIN = 56
local WHO_LEAST = 24
local BTN_PAD = 18
local EDIT_PAD = 16
local SUM_SAMPLE = "000 000"
local ROLES = { "tank", "heal", "dps" }
local SHARE_LABEL = { "rep.share.100", "rep.share.50", "rep.share.25" }
local ASK_TOP = 120
local View = {}
ns.RaidEPView = View
local box, list, rules, foot, sb
local cells = {}
local perKeys = {}
local lay = { x = {}, w = {}, hide = {} }
local probe = {}
local m = { bar = 26, rowh = 20, btnh = 20 }
local busy = false
local cur
local function Num(n)
    local s = tostring(floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^ ", ""))
end
View.Num = Num
local function ModeLabel(k)
    return ns.L["rep.mode." .. k] or k:upper()
end
local function Dur(sec)
    return format("%d:%02d", floor(sec / 3600), floor(sec % 3600 / 60))
end
local function SetEdit(e, text)
    if e:HasFocus() then return end
    e.quiet = true
    e:SetText(text)
    if e.SetCursorPosition then e:SetCursorPosition(0) end
    e.quiet = false
end
local function OnCommit(e, fn)
    e:HookScript("OnEditFocusLost", function(self)
        local t = (self:GetText() or ""):gsub("%s", "")
        fn(t ~= "" and tonumber(t) or nil)
    end)
end
local function NumEdit(parent)
    local e = Kit.Edit(parent)
    e:SetWidth(Kit.FontGrow(EDIT_W))
    e:SetMaxLetters(7)
    e:SetJustifyH("RIGHT")
    return e
end
local function Search(e, onPick)
    e.onChange = function(text)
        local hits = ns.RaidEP.Find(text, 10)
        if not hits[1] then
            Kit.SelectClose()
            return
        end
        local opts = {}
        for i = 1, #hits do
            local h = hits[i]
            local label = h.main
            if h.alts[1] then label = label .. " " .. Kit.Hex("text.note") .. "(" .. table.concat(h.alts, ", ") .. ")|r" end
            opts[i] = { key = i, label = label }
        end
        Kit.Popup(e, opts, function(key)
            local h = hits[key]
            if h then onPick(h.main) end
        end)
    end
end
local function Cell(k)
    local c = cells[k]
    if c then return c end
    c = CreateFrame("Frame", nil, rules)
    c.check = Kit.Check(c)
    c.label = Kit.Str(c, "GameFontHighlightSmall")
    c.label:SetWordWrap(false)
    c.name = Kit.Edit(c)
    c.name:SetMaxLetters(40)
    c.edit = NumEdit(c)
    c.edit2 = NumEdit(c)
    c.del = Kit.Button(c, nil, "quiet")
    c.del:SetText("x")
    c.del.onClick = function() if c.onDel then c.onDel() end end
    c.check.onToggle = function(on) if c.onToggle then c.onToggle(on) end end
    OnCommit(c.edit, function(n) if c.onEdit then c.onEdit(n) end end)
    OnCommit(c.edit2, function(n) if c.onEdit2 then c.onEdit2(n) end end)
    c.name:HookScript("OnEditFocusLost", function(self) if c.onName then c.onName(self:GetText()) end end)
    cells[k] = c
    return c
end
local function Lay(c, region, x, w)
    region:ClearAllPoints()
    region:SetPoint("LEFT", c, "LEFT", x, 0)
    if w then region:SetWidth(w) end
    region:Show()
    return x + (w or floor(region:GetStringWidth() + 0.5)) + 4
end
local function FillCell(c, spec)
    local x = 0
    c.onToggle, c.onEdit, c.onEdit2, c.onName, c.onDel = spec.toggle, spec.edit, spec.edit2, spec.rename, spec.drop
    local ew = Kit.FontGrow(EDIT_W)
    if spec.toggle then
        c.check:SetChecked(spec.on)
        c.check.tipTitle, c.check.tip = spec.label, spec.tip
        Lay(c, c.check, -4, 24)
        x = 20
    else
        c.check:Hide()
    end
    if spec.rename then
        c.label:Hide()
        c.name.tipTitle, c.name.tip = ns.T("rep.custom"), ns.T("rep.custom.tip")
        x = Lay(c, c.name, x, Kit.FontGrow(NAME_W))
    else
        c.name:Hide()
        c.label:SetText(spec.label)
        Kit.Text(c.label, spec.own and "text.warn" or "text.secondary")
        x = Lay(c, c.label, x)
    end
    if spec.edit2 then
        c.edit2.tipTitle, c.edit2.tip = spec.label, spec.tip2
        x = Lay(c, c.edit2, x, floor(ew * 0.7))
    else
        c.edit2:Hide()
    end
    c.edit.tipTitle, c.edit.tip = spec.label, spec.tip
    x = Lay(c, c.edit, x, ew) - 4
    if spec.drop then
        c.del:SetHeight(Kit.Space.ctl)
        c.del.tipTitle, c.del.tip = ns.T("rep.custom.drop"), nil
        x = Lay(c, c.del, x + 2, Kit.Space.ctl) - 4
    else
        c.del:Hide()
    end
    c:SetWidth(x)
    c:SetHeight(Kit.Space.ctl)
    c:Show()
    if spec.rename then SetEdit(c.name, spec.label) end
    if spec.edit2 then SetEdit(c.edit2, tostring(spec.v2 or 0)) end
    SetEdit(c.edit, tostring(spec.v or 0))
    return x
end
local function OwnTip(mode, field)
    if not ns.RaidEP.Own(mode, field) then return nil end
    local base = ns.raidEp.modes[mode]
    local grp, key = field:match("^(%a+)%.(.+)$")
    local v = base and (grp and (base[grp] and base[grp][key]) or base[field]) or 0
    return format(ns.T("rep.rule.preset"), Num(v or 0))
end
local function CondTip(md, mode, key)
    local own = OwnTip(mode, key)
    local fact
    if key == "nowipe" then fact = format(ns.T("rep.f.nowipe.tip"), md.wipes)
    elseif key == "fast" then fact = format(ns.T("rep.f.fast.tip"), Dur(md.dur))
    elseif key == "sindra" then fact = ns.T(md.conds.sindra and "rep.f.sindra.yes" or "rep.f.sindra.no")
    elseif key == "top5" then fact = ns.T("rep.f.top5.tip") end
    if own then return fact .. "\n" .. own end
    return fact
end
local function Specs(md)
    local E = ns.RaidEP
    local mode = E.ModeNow(md)
    local out = {}
    local function Field(field)
        out[#out + 1] = { label = ns.T("rep.f." .. field), v = E.Rule(mode, field), own = E.Own(mode, field),
            tip = OwnTip(mode, field), edit = function(n) E.SetRule(mode, field, n) end }
    end
    local function Cond(key, always)
        if not always and E.Rule(mode, key) <= 0 and not E.Own(mode, key) then return end
        local spec = { label = ns.T("rep.f." .. key), v = E.Rule(mode, key), own = E.Own(mode, key),
            tip = CondTip(md, mode, key), on = E.On(md, key),
            toggle = function(on) E.SetOn(key, false, on) end, edit = function(n) E.SetRule(mode, key, n) end }
        if key == "fast" then
            spec.v2, spec.tip2 = E.Rule(mode, "fastMin"), ns.T("rep.f.fastMin.tip")
            spec.own = spec.own or E.Own(mode, "fastMin")
            spec.edit2 = function(n) E.SetRule(mode, "fastMin", n) end
        end
        out[#out + 1] = spec
    end
    Field("base")
    for _, f in ipairs({ "heal", "tank", "rl", "perBoss" }) do
        if E.Rule(mode, f) > 0 or E.Own(mode, f) then Field(f) end
    end
    Cond("top5", true)
    Cond("nowipe")
    Cond("fast")
    Cond("sindra")
    if E.Rule(mode, "ach") > 0 or E.Own(mode, "ach") then
        local p = E.Pending()
        out[#out + 1] = { label = ns.T("rep.f.ach"), v = E.Rule(mode, "ach"), v2 = p and p.edit.ach or 0,
            own = E.Own(mode, "ach"), tip2 = ns.T("rep.f.ach.tip"),
            edit = function(n) E.SetRule(mode, "ach", n) end, edit2 = function(n) E.SetAch(n or 0) end }
    end
    for _, k in ipairs(E.Keys(mode, "flags")) do
        out[#out + 1] = { label = ns.T("rep.flag." .. k), v = E.Rule(mode, "flags." .. k), own = E.Own(mode, "flags." .. k),
            on = E.On(md, k, true), toggle = function(on) E.SetOn(k, true, on) end,
            edit = function(n) E.SetRule(mode, "flags." .. k, n) end }
    end
    for _, k in ipairs(E.Keys(mode, "per")) do
        local own = OwnTip(mode, "per." .. k)
        local spec = { label = ns.T("rep.pers." .. k), v = E.Rule(mode, "per." .. k), own = E.Own(mode, "per." .. k),
            tip = ns.T("rep.per." .. k) .. (own and "\n" .. own or ""),
            edit = function(n) E.SetRule(mode, "per." .. k, n) end }
        if k == "help" then
            local ownLvl = OwnTip(mode, "helpIlvl")
            spec.v2, spec.tip2 = E.Rule(mode, "helpIlvl"), ns.T("rep.f.helpIlvl.tip") .. (ownLvl and "\n" .. ownLvl or "")
            spec.own = spec.own or E.Own(mode, "helpIlvl")
            spec.edit2 = function(n) E.SetRule(mode, "helpIlvl", n) end
        end
        out[#out + 1] = spec
    end
    local customs = E.Customs()
    for i = 1, #customs do
        out[#out + 1] = { label = customs[i].name, v = customs[i].n, on = E.CustomOn(i),
            toggle = function(on) E.SetCustomOn(i, on) end, edit = function(n) E.SetCustom(i, nil, n or 0) end,
            rename = function(t) E.SetCustom(i, t, nil) end, drop = function() E.DropCustom(i) end }
    end
    return out
end
local function PaintRules(md)
    local specs = Specs(md)
    local w = rules:GetWidth() or 0
    if w <= 1 then w = 600 end
    local x, y, h = 0, 0, Kit.Space.ctl + 4
    for i = 1, #specs do
        local c = Cell(i)
        local cw = FillCell(c, specs[i])
        if x > 0 and x + cw > w then x, y = 0, y + h end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", rules, "TOPLEFT", x, -y)
        x = x + cw + CELL_GAP
    end
    for i = #specs + 1, #cells do cells[i]:Hide() end
    local add = rules.add
    add.text:SetText(ns.T("rep.custom.add"))
    add:SetWidth(max(Kit.FontGrow(60), floor(add.text:GetStringWidth() + 0.5) + 24))
    add:SetHeight(Kit.Space.ctl)
    if x > 0 and x + add:GetWidth() > w then x, y = 0, y + h end
    add:ClearAllPoints()
    add:SetPoint("TOPLEFT", rules, "TOPLEFT", x, -y)
    return y + h
end
local function BoxSize()
    local w, h = box:GetWidth() or 0, box:GetHeight() or 0
    return w > 1 and w or 600, h > 1 and h or 400
end
local function Need(kind, text)
    local fs = probe[kind]
    fs:SetText(text)
    local w = floor((fs:GetStringWidth() or 0) + 0.999)
    if kind == "btn" then return w + BTN_PAD end
    if kind == "edit" then return w + EDIT_PAD end
    return w + 2
end
local function ShareCells()
    local opts = {}
    for s = 1, #ns.raidEp.SHARES do opts[s] = { key = s, label = ns.T(SHARE_LABEL[s]) } end
    return opts
end
local function Columns(md, width)
    local w, hide = {}, {}
    w.chk = CHK_W
    w.was = max(Need("text", ns.T("rep.col.was")), Need("text", format("%d/%d", md.kills, md.kills)))
    box.head.share:SetCells(ShareCells(), 1)
    w.share = max(Need("text", ns.T("rep.col.share")), box.head.share:Measure(10000))
    w.role = Need("text", ns.T("rep.col.role"))
    for i = 1, #ROLES do w.role = max(w.role, Need("text", ns.T("rep.role." .. ROLES[i]))) end
    w.top = max(Need("text", ns.T("rep.col.top")), Need("btn", ns.T("rep.top5")))
    local order = { "chk", "who", "was", "share", "role", "top" }
    for k = 1, #perKeys do
        w["p" .. k] = Need("btn", ns.T("rep.pers." .. perKeys[k]))
        order[#order + 1] = "p" .. k
    end
    w.n = max(Need("text", ns.T("rep.col.n")), Need("edit", SUM_SAMPLE))
    order[#order + 1] = "n"
    local least = Kit.FontGrow(WHO_MIN)
    local gap, cols = COL_GAP, 0
    local function Rest()
        local used = COL_EDGE * 2
        cols = 0
        for i = 1, #order do
            local key = order[i]
            if not hide[key] then
                used = used + (w[key] or 0) + gap
                cols = cols + 1
            end
        end
        return width - used + gap
    end
    if Rest() < least then hide.role = true end
    if Rest() < least then hide.was = true end
    local floorW = min(least, Kit.FontGrow(WHO_LEAST))
    local rest = Rest()
    if rest < floorW then gap = max(2, COL_GAP - ceil((floorW - rest) / max(1, cols - 1))) end
    w.who = max(floorW, Rest())
    local x, at = COL_EDGE, {}
    for i = 1, #order do
        local key = order[i]
        if not hide[key] then
            at[key] = x
            x = x + w[key] + gap
        end
    end
    lay.x, lay.w, lay.hide, lay.gap = at, w, hide, gap
end
local function At(r, key, region, w)
    if lay.hide[key] then
        region:Hide()
        return false
    end
    region:ClearAllPoints()
    region:SetPoint("LEFT", r, "LEFT", lay.x[key], 0)
    if w then region:SetWidth(w) end
    return true
end
local function RowEnter(self)
    if self.lines then ns.Tip.Show(self, self.lines) end
end
local function Lit(btn, on)
    btn.tint = on and { Kit.RGB("text.good") } or nil
    btn:SetActive(on)
end
local function PerBtn(r, k)
    r.pb = r.pb or {}
    local btn = r.pb[k]
    if btn then return btn end
    btn = Kit.Button(r, nil, "quiet")
    btn.onClick = function()
        local it, key = r.item, perKeys[k]
        if it and it.kind == "row" and key and cur then ns.RaidEP.SetPer(it.r, key, not ns.RaidEP.Per(cur, it.r, key)) end
    end
    r.pb[k] = btn
    return btn
end
local function HidePer(r, from)
    for k = from or 1, #(r.pb or {}) do r.pb[k]:Hide() end
end
local function Row(wheel)
    local r = CreateFrame("Frame", nil, box)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, d) wheel(d) end)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", function() ns.Tip.Hide() end)
    r.check = Kit.Check(r)
    r.check.onToggle = function(on)
        local it = r.item
        if not it then return end
        if it.kind == "row" then ns.RaidEP.SetChecked(it.r, on) else ns.RaidEP.SetStandbyOn(it.i, on) end
    end
    for _, k in ipairs({ "who", "was", "role" }) do
        r[k] = Kit.Str(r, "GameFontHighlightSmall")
        r[k]:SetWordWrap(false)
        r[k]:SetJustifyH(k == "who" and "LEFT" or "RIGHT")
    end
    r.share = Kit.Segments(r, function(key)
        if r.item and r.item.kind == "row" then ns.RaidEP.SetShare(r.item.r, ns.raidEp.SHARES[key]) end
    end)
    r.to = Kit.Edit(r)
    r.to:SetMaxLetters(24)
    r.to.tipTitle, r.to.tip = ns.T("rep.to"), ns.T("rep.to.tip")
    Search(r.to, function(main)
        if r.item and r.item.kind == "row" then ns.RaidEP.SetTarget(r.item.r, main) end
    end)
    r.to:HookScript("OnEditFocusLost", function(self)
        local it = r.item
        if it and it.kind == "row" and (self:GetText() or ""):gsub("%s", "") == "" then ns.RaidEP.SetTarget(it.r, nil) end
    end)
    r.top = Kit.Button(r, nil, "quiet")
    r.top.onClick = function()
        local it = r.item
        if it and it.kind == "row" and cur then ns.RaidEP.SetTop5(it.r, not ns.RaidEP.Top5(cur, it.r)) end
    end
    r.drop = Kit.Button(r, nil, "quiet")
    r.drop:SetText("x")
    r.drop.onClick = function() if r.item and r.item.i then ns.RaidEP.DropStandby(r.item.i) end end
    r.n = NumEdit(r)
    r.n:SetMaxLetters(9)
    Kit.EditFlat(r.n)
    OnCommit(r.n, function(n)
        local it = r.item
        if not it then return end
        if it.kind == "row" then ns.RaidEP.SetSum(it.r, n) else ns.RaidEP.SetStandbySum(it.i, n) end
    end)
    return r
end
local function Put(r, k)
    r:ClearAllPoints()
    r:SetHeight(m.rowh + 2)
    local y = list.top + (m.rowh + 2) * k
    r:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
    r:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -y)
end
local function WhoText(row)
    local alts = {}
    for i = 1, #row.chars do
        if row.chars[i] ~= row.name then alts[#alts + 1] = row.chars[i] end
    end
    local s = row.name
    if alts[1] then s = s .. " " .. Kit.Hex("text.note") .. "(" .. table.concat(alts, ", ") .. ")|r" end
    if row.epgp == false then s = s .. " " .. Kit.Hex("text.warn") .. ns.T("rep.noguild") .. "|r" end
    if row.left then s = s .. " " .. Kit.Hex("text.warn") .. format(ns.T("rep.left"), date("%H:%M", row.left)) .. "|r" end
    return s
end
local function HelpWhy(md, row)
    local st, need, slot, lvl = ns.RaidEP.Help(md, row)
    if need <= 0 then return nil end
    if st == "ok" then return format(ns.T("rep.help.ok"), need) end
    if st == "low" then
        return format(ns.T("rep.help.low"), need, ns.GearLvl.SlotName(slot), lvl > 0 and tostring(lvl) or ns.T("rep.help.empty"))
    end
    return ns.T("rep.help.none")
end
local function ShareIndex(share)
    local S = ns.raidEp.SHARES
    local best, d = 1, 2
    for s = 1, #S do
        if math.abs(S[s] - share) < d then best, d = s, math.abs(S[s] - share) end
    end
    return best
end
local function RowTip(md, row, parts, own)
    local lines = { { kind = "head", left = row.name } }
    lines[#lines + 1] = { kind = "row", left = ns.T("rep.tip.was"), right = format("%d/%d", row.present, md.kills) }
    if row.epgp ~= false then
        lines[#lines + 1] = { kind = "row", left = ns.T("rep.col.role"), right = ns.T("rep.role." .. row.role) }
    end
    if row.dmg > 0 then lines[#lines + 1] = { kind = "row", left = ns.T("rep.tip.dmg"), right = Num(row.dmg) } end
    local to = ns.RaidEP.Target(row)
    if to and to ~= row.name then lines[#lines + 1] = { kind = "row", left = ns.T("rep.to"), right = to } end
    local sum = 0
    for i = 1, #parts do
        local p = parts[i]
        local left
        if p.key == "core" then
            left = format(ns.T("rep.tip.core"), ns.T(SHARE_LABEL[ShareIndex(p.arg)]))
        elseif p.key == "custom" then
            left = p.arg
        else
            local grp, key = p.key:match("^(%a+)%.(.+)$")
            left = grp and ns.T("rep.per." .. key) or ns.T(ns.L["rep.tip." .. p.key] and "rep.tip." .. p.key or "rep.f." .. p.key)
        end
        sum = sum + p.n
        lines[#lines + 1] = { kind = "row", left = left, right = "+" .. Num(p.n) }
    end
    if own then lines[#lines + 1] = { kind = "row", left = ns.T("rep.tip.own"), right = Num(sum) } end
    return lines
end
local function FillPlayer(r, md, row)
    local E = ns.RaidEP
    local n, parts, own = E.Sum(md, row)
    local to = E.Target(row)
    r.check:Show()
    r.check:SetChecked(E.Checked(row))
    if to then r.check:Enable() else r.check:Disable() end
    r.check.tipTitle, r.check.tip = row.name, not to and ns.T("rep.to.need") or nil
    At(r, "chk", r.check)
    r.who:SetText(WhoText(row))
    Kit.ClassText(r.who, row.class)
    At(r, "who", r.who, lay.w.who)
    r.was:SetText(format("%d/%d", row.present, md.kills))
    Kit.Text(r.was, row.final and "text.primary" or "text.warn")
    r.was:Show()
    At(r, "was", r.was, lay.w.was)
    r.share:SetCells(ShareCells(), ShareIndex(E.ShareOf(row)))
    r.share:Measure(lay.w.share)
    r.share:Place(lay.w.share)
    r.share:Show()
    At(r, "share", r.share)
    if row.epgp == false then
        local from = lay.x.role or lay.x.top
        r.role:Hide()
        r.to:Show()
        r.to:SetHeight(m.rowh)
        SetEdit(r.to, to or "")
        r.to:ClearAllPoints()
        r.to:SetPoint("LEFT", r, "LEFT", from, 0)
        r.to:SetWidth(lay.x.n - (lay.gap or COL_GAP) - from)
        HidePer(r)
        r.top:Hide()
    else
        r.to:Hide()
        r.role:SetText(ns.T("rep.role." .. row.role))
        Kit.Text(r.role, "text.secondary")
        r.role:Show()
        At(r, "role", r.role, lay.w.role)
        local top = E.Top5(md, row)
        r.top:SetText(ns.T("rep.top5"))
        Lit(r.top, top)
        r.top.tipTitle = ns.T("rep.f.top5")
        r.top.tip = format(ns.T(row.top5 and "rep.top5.tip.yes" or "rep.top5.tip.no"), Num(E.Rule(E.ModeNow(md), "top5")))
        r.top:SetHeight(m.rowh)
        At(r, "top", r.top, lay.w.top)
        r.top:Show()
        local mode = E.ModeNow(md)
        for k = 1, #perKeys do
            local key = perKeys[k]
            local btn = PerBtn(r, k)
            local on = E.Per(md, row, key)
            btn:SetText(ns.T("rep.pers." .. key))
            Lit(btn, on)
            btn.tipTitle = ns.T("rep.per." .. key)
            local tip = format(ns.T("rep.per.sum"), Num(E.Rule(mode, "per." .. key)))
            local why = key == "help" and HelpWhy(md, row)
                or row.why and row.why[key] and format(ns.T("rep.per.why." .. key), row.why[key])
            if why then tip = tip .. "\n" .. why end
            btn.tip = tip
            btn:SetHeight(m.rowh)
            At(r, "p" .. k, btn, lay.w["p" .. k])
            btn:Show()
        end
        HidePer(r, #perKeys + 1)
    end
    r.drop:Hide()
    r.n:Show()
    r.n:SetHeight(m.rowh)
    SetEdit(r.n, Num(n))
    Kit.EditFlat(r.n, own and Kit.C["text.warn"] or nil)
    Kit.Text(r.n, own and "text.warn" or "text.bright")
    r.n.tipTitle = ns.T("rep.col.n")
    r.n.tip = own and ns.T("rep.own") or nil
    At(r, "n", r.n, lay.w.n)
    r.lines = RowTip(md, row, parts, own)
end
local function FillStandby(r, md, i)
    local s = ns.RaidEP.Standby()[i]
    r.check:Show()
    r.check:Enable()
    r.check:SetChecked(s.c)
    r.check.tipTitle, r.check.tip = s.name, nil
    At(r, "chk", r.check)
    r.who:SetText(s.name)
    Kit.ClassText(r.who, nil)
    At(r, "who", r.who, lay.w.who)
    r.was:Hide()
    r.share:Hide()
    r.to:Hide()
    r.top:Hide()
    r.role:SetText(format(ns.T("rep.standby.pct"), ns.RaidEP.StandbyPct()))
    Kit.Text(r.role, "text.secondary")
    r.role:Show()
    At(r, "share", r.role, lay.w.share)
    HidePer(r)
    r.drop:Show()
    r.drop:SetHeight(m.rowh)
    r.drop.tipTitle, r.drop.tip = ns.T("rep.standby.drop"), nil
    At(r, "top", r.drop, m.rowh + 4)
    r.n:Show()
    r.n:SetHeight(m.rowh)
    SetEdit(r.n, Num(ns.RaidEP.StandbySum(md, s)))
    Kit.EditFlat(r.n, s.n and Kit.C["text.warn"] or nil)
    Kit.Text(r.n, s.n and "text.warn" or "text.bright")
    r.n.tipTitle = ns.T("rep.col.n")
    r.n.tip = s.n and ns.T("rep.own") or nil
    At(r, "n", r.n, lay.w.n)
    r.lines = nil
end
local function Fill(r, item, k)
    Put(r, k)
    r.item = item
    if not cur then return end
    if item.kind == "row" then FillPlayer(r, cur, item.r) else FillStandby(r, cur, item.i) end
end
local function Wheel(d)
    if list:Wheel(d) then View.Paint() end
end
local function Confirm(md)
    local batch, total = ns.RaidEP.Batch(md)
    if not batch[1] then return end
    Kit.Confirm(format(ns.T("rep.confirm"), #batch, Num(total), md.title), ns.T("rep.award"), function()
        local res, why = ns.RaidEP.Award(md)
        if not res then
            ns.Print(format(ns.T("rep.auto.cant"), ns.T(why or "led.err.noepgp")))
            return
        end
        if res.given > 0 then ns.Print(format(ns.T("rep.auto.done"), res.given, res.total)) end
        if res.failed[1] then ns.Print(format(ns.T("rep.failed"), table.concat(res.failed, ", "))) end
    end)
end
local function RemindMenu(anchor)
    Kit.Menu({
        { text = ns.T("rep.remind"), isTitle = true },
        { text = ns.T("rep.remind.zone"), func = function() ns.RaidEP.Remind("zone") end },
        { text = ns.T("rep.remind.group"), func = function() ns.RaidEP.Remind("group") end },
    }, anchor)
end
function View.Build(parent, btn)
    box = CreateFrame("Frame", nil, parent)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, d) Wheel(d) end)
    box:SetScript("OnSizeChanged", function(self, w) if (w or 0) > 1 and self:IsVisible() then View.Paint() end end)
    box.title = Kit.Str(box, "GameFontNormal")
    Kit.Text(box.title, "text.title")
    box.title:SetPoint("TOPLEFT", 0, -2)
    box.title:SetJustifyH("LEFT")
    box.title:SetWordWrap(false)
    box.mode = btn(box, "HTP_FailWatchRaidEpMode", "quiet", function() View.ModeMenu(box.mode) end)
    box.reset = btn(box, "HTP_FailWatchRaidEpReset", "quiet", function()
        if cur then ns.RaidEP.ResetRules(ns.RaidEP.ModeNow(cur)) end
    end)
    box.reset.tip = ns.T("rep.reset.tip")
    rules = CreateFrame("Frame", nil, box)
    rules.add = btn(rules, "HTP_FailWatchRaidEpCustomAdd", "quiet", function() ns.RaidEP.AddCustom() end)
    rules.add.tip = ns.T("rep.custom.add.tip")
    probe.text = Kit.Str(box, "GameFontHighlightSmall")
    probe.btn = Kit.Str(box, "GameFontNormalSmall")
    probe.edit = Kit.Str(box, "ChatFontNormal")
    for _, fs in pairs(probe) do fs:Hide() end
    box.head = Row(Wheel)
    for _, k in ipairs({ "check", "share", "drop", "n", "to", "top" }) do box.head[k]:Hide() end
    box.headPer = {}
    box.headTop = Kit.Str(box.head, "GameFontHighlightSmall")
    box.headTop:SetWordWrap(false)
    box.headShare = Kit.Str(box.head, "GameFontHighlightSmall")
    box.headShare:SetWordWrap(false)
    box.headN = Kit.Str(box.head, "GameFontHighlightSmall")
    box.headN:SetJustifyH("RIGHT")
    box.headN:SetWordWrap(false)
    box.empty = Kit.Str(box, "GameFontDisableSmall")
    Kit.Text(box.empty, "text.off")
    box.empty:SetJustifyH("LEFT")
    box.empty:SetJustifyV("TOP")
    list = Kit.List(function() return Row(Wheel) end, Fill, { step = 3 })
    sb = CreateFrame("Frame", nil, box)
    sb.cap = Kit.Str(sb, "GameFontNormalSmall")
    Kit.Text(sb.cap, "text.title")
    sb.cap:SetPoint("LEFT", sb, "LEFT", 0, 0)
    sb.edit = Kit.Edit(sb)
    sb.edit:SetMaxLetters(24)
    sb.edit.tipTitle, sb.edit.tip = ns.T("rep.standby.add"), ns.T("rep.standby.add.tip")
    Search(sb.edit, function(main) View.AddStandby(main) end)
    sb.add = btn(sb, "HTP_FailWatchRaidEpStandby", "quiet", function() View.AddStandby() end)
    sb.edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        View.AddStandby()
    end)
    foot = CreateFrame("Frame", nil, box)
    foot.sum = Kit.Str(foot, "GameFontNormal")
    foot.sum:SetPoint("LEFT", foot, "LEFT", 0, 0)
    foot.give = btn(foot, "HTP_FailWatchRaidEpGive", "main", function() if cur then Confirm(cur) end end)
    foot.later = btn(foot, "HTP_FailWatchRaidEpLater", "quiet", function() RemindMenu(foot.later) end)
    foot.later.tip = ns.T("rep.remind.tip")
    foot.drop = btn(foot, "HTP_FailWatchRaidEpDrop", "quiet", function()
        Kit.Confirm(ns.T("rep.drop.ask"), ns.T("rep.drop"), function() ns.RaidEP.Drop() end)
    end)
    foot.undo = btn(foot, "HTP_FailWatchRaidEpUndo", "danger", function() View.Undo(1) end)
    foot.chat = btn(foot, "HTP_FailWatchRaidEpChat", "quiet", function()
        ns.ProofView.ReportMenu(foot.chat, function(n) return View.ChatLines(n) end, "report.menu.list", true, "report.none.list")
    end)
    ns.RaidEP.OnChange(function() View.Paint() end)
    return box
end
function View.ChatLines(n, md)
    md = md or cur
    if not md then return {} end
    local batch = ns.RaidEP.Batch(md)
    local list = {}
    for i = 1, #batch do list[i] = batch[i] end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local rows = {}
    for i = 1, #list do
        local e = list[i]
        rows[i] = { who = e.name, val = Num(e.n) .. " EP", rest = { e.from, e.standby and ns.T("report.standby") or nil } }
    end
    return ns.ChatReport.Detail(ns.T("report.t.ep"), md.title, rows, n)
end
function View.AddStandby(main)
    Kit.SelectClose()
    local name = main
    if not name then
        local hits = ns.RaidEP.Find(sb.edit:GetText(), 2)
        name = hits[1] and not hits[2] and hits[1].main or sb.edit:GetText()
    end
    local got, why = ns.RaidEP.AddStandby(name)
    if got then
        sb.edit.quiet = true
        sb.edit:SetText("")
        sb.edit.quiet = false
        sb.edit:ClearFocus()
    elseif why == "dup" then
        ns.Print(ns.T("rep.standby.dup"))
    end
end
function View.Undo(i)
    local rec = ns.RaidEP.Done()[i]
    if not rec or rec.undone then return end
    Kit.Confirm(format(ns.T("rep.undo.ask"), rec.title or "", #rec.list, Num(rec.total)), ns.T("rep.undo"), function()
        if ns.RaidEP.Done()[i] ~= rec then return end
        local ok, why = ns.RaidEP.Undo(i)
        if not ok then ns.Print(format(ns.T("rep.auto.cant"), ns.T(why or "led.err.none"))) end
    end)
end
function View.ModeMenu(anchor)
    if not cur then return end
    local E = ns.RaidEP
    local now = E.ModeNow(cur)
    local items = { { text = ns.T("rep.mode.pick"), isTitle = true } }
    for _, k in ipairs(ns.raidEp.ORDER) do
        local text = ModeLabel(k)
        if k == cur.auto then text = text .. " " .. Kit.Hex("text.note") .. ns.T("rep.mode.auto") .. "|r" end
        items[#items + 1] = { text = text, checked = k == now, func = function() E.SetMode(k ~= cur.auto and k or nil) end }
    end
    Kit.Menu(items, anchor)
end
local function Fit(b, text)
    b.text:SetText(text)
    b:SetWidth(max(Kit.FontGrow(60), floor(b.text:GetStringWidth() + 0.5) + 24))
    b:SetHeight(m.btnh)
end
function View.Place(bar, rowh, btnh)
    m.bar, m.rowh, m.btnh = bar, rowh, btnh
end
local function Items(md)
    local out = {}
    for i = 1, #md.rows do out[#out + 1] = { kind = "row", r = md.rows[i] } end
    local s = ns.RaidEP.Standby()
    for i = 1, #s do out[#out + 1] = { kind = "sb", i = i } end
    return out
end
local function PaintHead()
    local h = box.head
    h.who:SetText(ns.T("rep.col.who"))
    At(h, "who", h.who, lay.w.who)
    h.was:SetText(ns.T("rep.col.was"))
    h.was:Show()
    At(h, "was", h.was, lay.w.was)
    box.headShare:SetText(ns.T("rep.col.share"))
    At(h, "share", box.headShare, lay.w.share)
    h.role:SetText(ns.T("rep.col.role"))
    h.role:Show()
    At(h, "role", h.role, lay.w.role)
    box.headTop:SetText(ns.T("rep.col.top"))
    At(h, "top", box.headTop, lay.w.top)
    for k = 1, max(#perKeys, #box.headPer) do
        local fs = box.headPer[k]
        if not fs then
            fs = Kit.Str(h, "GameFontHighlightSmall")
            fs:SetWordWrap(false)
            fs:SetJustifyH("CENTER")
            box.headPer[k] = fs
        end
        box.headPerHit = box.headPerHit or {}
        local hit = box.headPerHit[k]
        if not hit then
            hit = CreateFrame("Frame", nil, h)
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", RowEnter)
            hit:SetScript("OnLeave", function() ns.Tip.Hide() end)
            box.headPerHit[k] = hit
        end
        if perKeys[k] then
            local key = perKeys[k]
            fs:SetText(ns.T("rep.pers." .. key))
            Kit.Text(fs, "text.secondary")
            At(h, "p" .. k, fs, lay.w["p" .. k])
            fs:Show()
            hit:SetAllPoints(fs)
            hit.lines = { { kind = "head", left = ns.T("rep.per." .. key) },
                { kind = "row", left = format(ns.T("rep.per.sum"), Num(ns.RaidEP.Rule(ns.RaidEP.ModeNow(cur), "per." .. key))) } }
            hit:Show()
        else
            fs:Hide()
            hit:Hide()
        end
    end
    box.headN:SetText(ns.T("rep.col.n"))
    At(h, "n", box.headN, lay.w.n)
    for _, fs in ipairs({ h.who, h.was, box.headShare, h.role, box.headTop, box.headN }) do Kit.Text(fs, "text.secondary") end
end
local function PaintFoot()
    local w = BoxSize()
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(m.btnh + 4)
    sb:ClearAllPoints()
    sb:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 4)
    sb:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 4)
    sb:SetHeight(m.btnh + 4)
    sb.cap:SetText(format(ns.T("rep.standby"), ns.RaidEP.StandbyPct()))
    sb.edit:ClearAllPoints()
    sb.edit:SetPoint("LEFT", sb.cap, "RIGHT", 8, 0)
    sb.edit:SetWidth(min(Kit.FontGrow(160), w * 0.3))
    Fit(sb.add, ns.T("rep.standby.add"))
    sb.add:ClearAllPoints()
    sb.add:SetPoint("LEFT", sb.edit, "RIGHT", 4, 0)
    Fit(foot.give, ns.T("rep.award"))
    foot.give:ClearAllPoints()
    foot.give:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
    Fit(foot.later, ns.T("rep.remind"))
    foot.later:ClearAllPoints()
    foot.later:SetPoint("RIGHT", foot.give, "LEFT", -4, 0)
    Fit(foot.drop, ns.T("rep.drop"))
    foot.drop:ClearAllPoints()
    foot.drop:SetPoint("RIGHT", foot.later, "LEFT", -4, 0)
    Fit(foot.chat, ns.T("report.btn"))
    foot.chat:ClearAllPoints()
    foot.chat:SetPoint("RIGHT", foot.drop, "LEFT", -4, 0)
end
local function Note(text)
    box.empty:SetText(text)
    box.empty:ClearAllPoints()
    box.empty:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -(m.bar + 6))
    box.empty:SetPoint("RIGHT", box, "RIGHT", -4, 0)
    box.empty:Show()
end
local function PaintIdle()
    for _, r in ipairs({ rules, box.head, sb, box.mode, box.reset, foot.give, foot.later, foot.drop, foot.chat }) do r:Hide() end
    list:Draw({}, 0)
    foot:Show()
    box.title:SetText(ns.T("rep.title.idle"))
    local rec = ns.RaidEP.Done()[1]
    local text = ns.T("rep.idle")
    if rec then
        text = format(ns.T(rec.undone and "rep.last.undone" or "rep.last"), ns.Date(rec.at, "dayTime"), rec.title or "",
            #rec.list, Num(rec.total)) .. "\n\n" .. text
    end
    Note(text)
    foot.sum:SetText("")
    PaintFoot()
    if rec and not rec.undone then
        Fit(foot.undo, ns.T("rep.undo"))
        foot.undo:ClearAllPoints()
        foot.undo:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
        foot.undo:Show()
    else
        foot.undo:Hide()
    end
    sb:Hide()
end
local function GiveTip(can, why, batch)
    if not can then return ns.T(why or "led.err.noepgp") end
    if not batch[1] then return ns.T("rep.give.none") end
    return nil
end
local function PaintTitle(md)
    local E = ns.RaidEP
    local guild = format(ns.T("rep.guild"), md.guild, E.MinGuild())
    if md.guild < E.MinGuild() then guild = Kit.Hex("text.warn") .. guild .. "|r" end
    box.title:SetText(format(ns.T("rep.title"), md.title, md.kills, md.total, md.wipes, Dur(md.dur)) .. ", " .. guild)
end
local function PaintModel(md)
    cur = md
    local E = ns.RaidEP
    box.empty:Hide()
    foot.undo:Hide()
    for _, r in ipairs({ rules, box.head, sb, box.mode, foot, foot.give, foot.later, foot.drop, foot.chat }) do r:Show() end
    local mode = E.ModeNow(md)
    perKeys = E.Keys(mode, "per")
    PaintTitle(md)
    Fit(box.mode, format(ns.T("rep.mode"), ModeLabel(mode)))
    box.mode:ClearAllPoints()
    box.mode:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 2)
    box.mode.tip = mode ~= md.auto and format(ns.T("rep.mode.tip"), ModeLabel(md.auto)) or nil
    box.title:SetPoint("RIGHT", box.mode, "LEFT", -8, 0)
    rules:ClearAllPoints()
    rules:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -m.bar)
    rules:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -m.bar)
    local rh = PaintRules(md)
    local own = false
    for _, f in ipairs(ns.raidEp.FIELDS) do if E.Own(mode, f) then own = true end end
    for _, k in ipairs(E.Keys(mode, "flags")) do if E.Own(mode, "flags." .. k) then own = true end end
    for _, k in ipairs(E.Keys(mode, "per")) do if E.Own(mode, "per." .. k) then own = true end end
    if own then
        Fit(box.reset, ns.T("rep.reset"))
        box.reset:ClearAllPoints()
        box.reset:SetPoint("RIGHT", box.mode, "LEFT", -4, 0)
        box.title:SetPoint("RIGHT", box.reset, "LEFT", -8, 0)
        box.reset:Show()
    else
        box.reset:Hide()
    end
    rules:SetHeight(rh)
    list.top = m.bar + rh + 4
    box.head:ClearAllPoints()
    box.head:SetHeight(m.rowh)
    box.head:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -list.top)
    box.head:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -list.top)
    Columns(md, (BoxSize()))
    PaintHead()
    PaintFoot()
    local room = select(2, BoxSize()) - list.top - m.rowh - (m.btnh + 4) * 2 - 8
    list:Draw(Items(md), max(1, floor(room / (m.rowh + 2))))
    local batch, total = E.Batch(md)
    foot.sum:SetText(format(ns.T("rep.sum"), #batch, Num(total)))
    local can, why = E.CanAward()
    if can and batch[1] then foot.give:Enable() else foot.give:Disable() end
    if batch[1] then foot.chat:Enable() else foot.chat:Disable() end
    local tip = GiveTip(can, why, batch)
    foot.give.tipTitle, foot.give.tip = tip and ns.T("rep.award") or nil, tip
end
function View.Paint()
    if not box or not box:IsVisible() then return end
    local E = ns.RaidEP
    if not E.Pending() then
        cur = nil
        PaintIdle()
        return
    end
    local md = E.Peek()
    if md then
        PaintModel(md)
        return
    end
    for _, r in ipairs({ rules, box.head, sb, foot, box.mode, box.reset }) do r:Hide() end
    list:Draw({}, 0)
    box.title:SetText(ns.T("rep.title.idle"))
    Note(ns.T("rep.busy"))
    if busy then return end
    busy = true
    E.Model(function(got, why)
        busy = false
        if got then
            View.Paint()
        elseif box:IsVisible() then
            Note(ns.T("rep.why." .. (why or "fail")))
        end
    end)
end
function View.Open()
    if ns.FaultsPage then ns.FaultsPage.Open("ep") end
end
local ask
local function AskButton(f, name, kind, onClick)
    local b = Kit.Button(f, name, kind)
    b.tipTitle = false
    b:SetHeight(22)
    b.onClick = function()
        f.answered = true
        f:Hide()
        onClick()
    end
    return b
end
local function BuildAsk()
    local f = CreateFrame("Frame", "HTP_FailWatchRaidEpAsk", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    Kit.Skin(f, "plate")
    f:EnableMouse(true)
    tinsert(UISpecialFrames, "HTP_FailWatchRaidEpAsk")
    f.text = Kit.Str(f, "GameFontHighlight")
    f.text:SetPoint("TOP", 0, -16)
    f.now = AskButton(f, "HTP_FailWatchRaidEpAskNow", "main", function() View.Open() end)
    f.zone = AskButton(f, "HTP_FailWatchRaidEpAskZone", nil, function() ns.RaidEP.Remind("zone") end)
    f.group = AskButton(f, "HTP_FailWatchRaidEpAskGroup", nil, function() ns.RaidEP.Remind("group") end)
    f:SetScript("OnHide", function(self)
        if not self.answered then ns.RaidEP.Remind(nil) end
        self.answered = nil
    end)
    return f
end
local function SizeAsk(f)
    local list = { f.now, f.zone, f.group }
    local row, gap = 0, 8
    for _, b in ipairs(list) do
        b:SetWidth(floor(b.text:GetStringWidth() + 0.5) + 28)
        row = row + b:GetWidth()
    end
    row = row + gap * (#list - 1)
    local w = max(floor(380 * Kit.FontScale("GameFontHighlight", true) + 0.5), row + 32)
    f:SetWidth(w)
    f.text:SetWidth(w - 40)
    local x = -row / 2
    for _, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", f, "BOTTOM", x, 14)
        x = x + b:GetWidth() + gap
    end
    f:SetHeight(max(110, floor(16 + (f.text:GetHeight() or 0) + 16 + 22 + 14 + 0.5)))
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -ASK_TOP)
end
function View.Prompt(why)
    local p = ns.RaidEP.Pending()
    if not p then return end
    ask = ask or BuildAsk()
    local title = ns.Raid.Label({ name = p.name, map = p.map, size = p.size })
    ask.text:SetText(format(ns.T("rep.ask." .. why), title))
    ask.now.text:SetText(ns.T("rep.ask.now"))
    ask.zone.text:SetText(ns.T("rep.remind.zone"))
    ask.group.text:SetText(ns.T("rep.remind.group"))
    ask.answered = nil
    SizeAsk(ask)
    ask:Show()
end
