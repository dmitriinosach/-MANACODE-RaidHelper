local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local ICONS = 10
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GPList = {}
ns.GPList = GPList
GPList.WIDE = { rowh = 22, namew = 140, gpw = 70, btnw = 96, icon = 18, iconw = 40, proofw = 22 }
GPList.COMPACT = { rowh = 20, namew = 72, gpw = 34, btnw = 46, icon = 14, iconw = 30, proofw = 16, small = true }
local listeners = {}
function GPList.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function GPList.Changed()
    for i = 1, #listeners do listeners[i]() end
end
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
local function Icon(id)
    if type(id) == "string" then return id end
    return id and ns.Effects and ns.Effects.IconById(id) or UNKNOWN_ICON
end
local function ClassRGB(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return cc.r, cc.g, cc.b end
    local c = ns.Badges.style.noClass
    return c[1], c[2], c[3]
end
function GPList.Small(b)
    if b.kitStyle then return end
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
end
function GPList.Pending(events)
    local issued = ns.GetDB().gpIssued
    local gp = 0
    for k = 1, #events do
        if not issued[events[k].key] then gp = gp + events[k].gp end
    end
    return gp
end
function GPList.Confirm(text, yes, onYes)
    ns.Kit.Confirm(text, yes, onYes)
end
function GPList.CanGP()
    local epgp = _G.EPGP
    if type(epgp) ~= "table" or type(epgp.IncGPBy) ~= "function" then
        ns.Print(ns.T("sum.gp.noepgp"))
        return false
    end
    if type(epgp.CanIncGPBy) == "function" and not epgp:CanIncGPBy("FailWatch", 1) then
        ns.Print(ns.T("sum.gp.norights"))
        return false
    end
    return true
end
local function Member(epgp, name)
    if type(epgp.GetEPGP) ~= "function" then return true end
    local ok, ep = pcall(epgp.GetEPGP, epgp, name)
    return ok and ep ~= nil
end
local function IssueOne(fight, item, issued, epgp)
    local gp, labels, seen = 0, {}, {}
    for e = 1, #item.events do
        local ev = item.events[e]
        if not issued[ev.key] then
            gp = gp + ev.gp
            if not seen[ev.reason] then
                seen[ev.reason] = true
                labels[#labels + 1] = ev.reason
            end
        end
    end
    if gp <= 0 then return nil end
    if not Member(epgp, item.name) then return false end
    local reason = ns.Penalties.EpgpReason()
    if reason == "" then reason = format("FailWatch: %s — %s", fight.boss, concat(labels, ", ")) end
    local ok = pcall(epgp.IncGPBy, epgp, item.name, reason:sub(1, 200), gp)
    if not ok then return false end
    for e = 1, #item.events do issued[item.events[e].key] = true end
    return true
end
function GPList.Issue(fight, batch)
    if not fight or not batch or not GPList.CanGP() then return end
    local total, names = 0, 0
    for k = 1, #batch do
        local gp = GPList.Pending(batch[k].events)
        if gp > 0 then
            total = total + gp
            names = names + 1
        end
    end
    if total == 0 then return end
    GPList.Confirm(format(ns.T("sum.gp.ask"), total, names), ns.T("sum.gp.yes"), function()
        local issued = ns.GetDB().gpIssued
        local epgp = _G.EPGP
        if type(epgp) ~= "table" then return end
        local failed = {}
        for k = 1, #batch do
            if IssueOne(fight, batch[k], issued, epgp) == false then failed[#failed + 1] = batch[k].name end
        end
        if #failed > 0 then ns.Print(format(ns.T("gp.notgiven"), concat(failed, ", "))) end
        GPList.Changed()
    end)
end
local function OpenMenu(menu)
    ns.Tip.Hide()
    ns.Kit.Menu(menu)
end
local function HitEvents(hit, name)
    local reason = ns.Penalties.Reason(hit.rule)
    local out = {}
    for k = 1, #hit.events do
        local ev = hit.events[k]
        out[k] = { key = ev.key, gp = ev.gp, reason = reason, t = ev.t, bumped = ev.bumped, name = name,
            manual = ev.info and ev.info.manual or nil }
    end
    return out
end
function GPList.ManualMenu(fight, name)
    if not fight or not ns.Penalties then return end
    local rules = ns.Penalties.Choices(fight.boss)
    local menu = { { text = format(ns.T("sum.gp.add"), name), isTitle = true, notCheckable = true } }
    for i = 1, #rules do
        local r = rules[i]
        menu[#menu + 1] = {
            text = format(ns.T("gp.menu.rule"), ns.Penalties.Reason(r), r.gp or 0),
            notCheckable = true,
            func = function()
                ns.Penalties.AddManual(fight, name, r.key)
                GPList.Changed()
            end,
        }
    end
    OpenMenu(menu)
end
local function EventMenu(fight, hit, name)
    local issued = ns.GetDB().gpIssued
    local rule = hit.rule
    local menu = { { text = ns.Penalties.Reason(rule), isTitle = true, notCheckable = true } }
    local events = HitEvents(hit, name)
    for k = 1, #events do
        local ev = events[k]
        local when = ev.t and Clock(ev.t - fight.from) or ns.T("sum.gp.whole")
        local done = issued[ev.key]
        menu[#menu + 1] = {
            text = format(ns.T(done and "sum.gp.itemdone" or "sum.gp.item"), when, ev.gp),
            notCheckable = true,
            disabled = done,
            func = function() GPList.Issue(fight, { { name = name, events = { ev } } }) end,
        }
        if rule.wipe and not ev.bumped and not done then
            menu[#menu + 1] = {
                text = format(ns.T("sum.gp.bump"), when, rule.wipe),
                notCheckable = true,
                func = function()
                    ns.Penalties.Bump(ev.key)
                    GPList.Changed()
                end,
            }
        end
        if k == #events and ev.manual and not done then
            menu[#menu + 1] = {
                text = format(ns.T("gp.menu.unmanual"), when),
                notCheckable = true,
                func = function()
                    ns.Penalties.RemoveManual(fight, name, rule.key, ev.key)
                    GPList.Changed()
                end,
            }
        end
    end
    OpenMenu(menu)
end
local function FirstAt(list)
    return ns.ReplayLink and ns.ReplayLink.First(list, "t") or nil
end
local function HitLines(fight, hit)
    local lines = ns.BadgeTips.Hit(fight, hit, ns.Penalties.Reason(hit.rule))
    if ns.ReplayLink then ns.ReplayLink.Tag(lines, fight, FirstAt(hit.events)) end
    return lines
end
local function Guards(p, hits)
    local out, by = {}, {}
    for h = 1, #hits do
        local kind = hits[h].rule.kind
        for e = 1, (kind == "death" or kind == "anydeath") and #hits[h].events or 0 do
            local t = hits[h].events[e].t
            for k = 1, t and #p.deathInfo or 0 do
                local d = p.deathInfo[k]
                if math.abs(d.t - t) < 0.01 and d.ready and not d.late and not d.tail then
                    local m = by[d.ready]
                    if not m then
                        m = { id = d.ready, n = 0, times = {} }
                        by[d.ready] = m
                        out[#out + 1] = m
                    end
                    m.n = m.n + 1
                    m.times[m.n] = d.t
                end
            end
        end
    end
    return out
end
function GPList.Build(fight, summary)
    local pens, totals = {}, {}
    if ns.Penalties and summary then pens, totals = ns.Penalties.Evaluate(summary, fight) end
    local items, all, pending = {}, {}, 0
    for i = 1, #((summary and summary.players) or {}) do
        local p = summary.players[i]
        local hits = pens[p.name]
        if hits and #hits > 0 then
            local events = {}
            for h = 1, #hits do
                local ev = HitEvents(hits[h], p.name)
                for e = 1, #ev do events[#events + 1] = ev[e] end
            end
            local item = { name = p.name, class = p.class, hits = hits, events = events,
                total = totals[p.name] or 0, pending = GPList.Pending(events), guards = Guards(p, hits) }
            items[#items + 1] = item
            pending = pending + item.pending
        end
    end
    tsort(items, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    for i = 1, #items do all[i] = items[i] end
    return { pens = pens, totals = totals, items = items, pending = pending, all = all }
end
local function RowMouseUp(self, button)
    local list = self:GetParent()
    if button == "RightButton" and self.who and list.fight then GPList.ManualMenu(list.fight, self.who) end
    if button == "LeftButton" and self.item and ns.ReplayLink then
        ns.ReplayLink.Shift(list.fight, FirstAt(self.item.events))
    end
end
local function RowEnter(self)
    local item = self.item
    if not item then return end
    local lines = ns.BadgeTips.GPRow(item, ns.Penalties.Reason)
    if ns.ReplayLink then ns.ReplayLink.Tag(lines, self.list.fight, FirstAt(item.events)) end
    ns.Tip.Show(self, lines)
end
local function RowLeave(self)
    ns.Tip.Hide()
end
local function ListWheel(self, delta)
    local list = self.list or self
    if list.onWheel then list.onWheel(delta) end
end
local function MarkClick(mark)
    local list = mark:GetParent():GetParent()
    if mark.hit and list.fight then EventMenu(list.fight, mark.hit, mark.player) end
end
local function Row(f, k)
    local r = f.rows[k]
    if r then return r end
    local L = f.L
    r = CreateFrame("Frame", nil, f)
    r:SetHeight(L.rowh)
    r:EnableMouse(true)
    r:SetScript("OnMouseUp", RowMouseUp)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
    r.list = f
    r.name = r:CreateFontString(nil, "OVERLAY", L.small and "GameFontHighlightSmall" or "GameFontHighlight")
    r.name:SetPoint("LEFT", L.small and 4 or 10, 0)
    r.name:SetWidth(L.namew)
    r.name:SetJustifyH("LEFT")
    r.icons = {}
    r.gp = r:CreateFontString(nil, "OVERLAY", L.small and "GameFontNormalSmall" or "GameFontNormal")
    r.gp:SetPoint("RIGHT", -(L.btnw + L.proofw + (L.small and 6 or 14)), 0)
    r.gp:SetWidth(L.gpw)
    r.gp:SetJustifyH("RIGHT")
    r.btn = ns.MakeButton(r, f.prefix .. k)
    r.btn:SetWidth(L.btnw)
    r.btn:SetHeight(L.rowh - 4)
    r.btn:SetPoint("RIGHT", L.small and -2 or -8, 0)
    if L.small then GPList.Small(r.btn) end
    r.btn.onClick = function()
        if f.fight and r.btn.batch then GPList.Issue(f.fight, r.btn.batch) end
    end
    if ns.ProofView then
        r.proof = ns.ProofView.Button(r, L.proofw - 4)
        r.proof:SetPoint("RIGHT", -(L.btnw + (L.small and 3 or 10)), 0)
    end
    f.rows[k] = r
    return r
end
local function FillRow(r, item, fight, icons)
    local L = r.list.L
    r.who = item.name
    r.item = item
    r.name:SetWidth(L.namew)
    r.name:SetText(item.name)
    r.name:SetTextColor(ClassRGB(item.class))
    local guards = item.guards or {}
    local nh = #item.hits
    local pair = #guards > 0 and "death" or nil
    for i = 1, max(icons, #r.icons) do
        local hit = i <= icons and item.hits[i] or nil
        local guard = not hit and i <= icons and guards[i - nh] or nil
        local b = r.icons[i]
        if (hit or guard) and not b then
            b = ns.Badges.Mark(r, L.icon)
            b:Layout(L.iconw - 2)
            b:SetPoint("LEFT", (L.small and 4 or 10) + L.namew + (i - 1) * L.iconw, 0)
            r.icons[i] = b
        end
        if hit then
            local info = hit.events[1] and hit.events[1].info
            local count = info and info.missing and tostring(info.have or 0) or tostring(#hit.events)
            if i == icons and #item.hits > icons then count = "+" .. (#item.hits - icons + 1) end
            local kind = hit.rule.kind
            b:SetModel({
                icon = Icon(hit.icon),
                count = count,
                verdict = "red",
                pair = (kind == "death" or kind == "anydeath") and pair or nil,
                lines = HitLines(fight, hit),
                onClick = MarkClick,
                fight = fight,
                at = FirstAt(hit.events),
                proof = { fight = fight, name = item.name, hits = { hit } },
            })
            b.hit, b.player = hit, item.name
            b:Show()
        elseif guard then
            b:SetModel({
                icon = Icon(guard.id),
                count = tostring(guard.n),
                verdict = "yellow",
                pair = pair,
                lines = ns.BadgeTips.Ready(guard, fight),
                fight = fight,
                at = guard.times[1],
            })
            b.hit, b.player = nil, item.name
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    r.gp:SetText(format(ns.T(L.small and "gp.sum.short" or "sum.gp.sum"), item.total))
    r.btn.batch = { item }
    if item.pending > 0 then
        r.btn.text:SetText(ns.T("sum.gp.give"))
        r.btn:Enable()
    else
        r.btn.text:SetText(ns.T("sum.gp.done"))
        r.btn:Disable()
    end
    r.btn:Show()
    if r.proof then
        r.proof.ask = { fight = fight, name = item.name, hits = item.hits }
        r.proof:Show()
    end
end
local function Draw(self, fight, model, width, offset, slots)
    local L = self.L
    self.fight = fight
    offset = offset or 0
    local items = model.items
    local shown = max(0, min(#items - offset, slots or #items))
    local room = width - L.namew - L.gpw - L.btnw - L.proofw - (L.small and 16 or 40)
    local icons = max(1, min(ICONS, floor(room / L.iconw)))
    for k = 1, shown do
        local r = Row(self, k)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -((k - 1) * L.rowh))
        r:SetPoint("TOPRIGHT", 0, -((k - 1) * L.rowh))
        FillRow(r, items[k + offset], fight, icons)
        r:Show()
    end
    for k = shown + 1, #self.rows do self.rows[k]:Hide() end
    if #items == 0 then
        local r = Row(self, 1)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, 0)
        r:SetPoint("TOPRIGHT", 0, 0)
        r.who, r.item = nil, nil
        r.name:SetWidth(max(L.namew, width - 20))
        r.name:SetText(ns.T(L.small and "gp.none.short" or "sum.gp.none"))
        local muted = ns.Badges.style.muted
        r.name:SetTextColor(muted[1], muted[2], muted[3])
        for i = 1, #r.icons do r.icons[i]:Hide() end
        r.gp:SetText("")
        r.btn:Hide()
        if r.proof then
            r.proof.ask = nil
            r.proof:Hide()
        end
        r:Show()
    end
    local h = max(1, shown) * L.rowh
    self:SetWidth(width)
    self:SetHeight(h)
    return h
end
function GPList.New(parent, prefix, layout)
    local f = CreateFrame("Frame", nil, parent)
    f.rows = {}
    f.prefix = prefix
    f.L = layout or GPList.WIDE
    f.Draw = Draw
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", ListWheel)
    return f
end
