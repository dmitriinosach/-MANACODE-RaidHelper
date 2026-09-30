local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local tconcat = table.concat
local SIDE = ns.FightList and ns.FightList.WIDTH or 240
local EFFW = 232
local MARGIN = 6
local GAP = 6
local ROW = 15
local RULER = 34
local RULERTOP = 15
local RULERGAP = 2
local HEADH = 36
local FOOTH = 8
local SIDETOP = 34
local SIDEBOT = 12
local FXTOP = 34
local FXBOT = 22
local MINROWS = 5
local GUTTERMIN = 120
local GUTTERMAX = 240
local GUTTERSHARE = 0.2
local PLOTMIN = 220
local MARKW = 52
local MARKGAP = 8
local ICONMIN = 10
local ICONMAX = 20
local SWING_SPELL = 6603
local SWING_ICON = "Interface\\Icons\\INV_Sword_04"
local ICONSHARE = 0.6
local FXROW = 18
local INDENT = 11
local FXPAD = 3
local FXBAR = FXROW - FXPAD * 2
local MISSH = 5
local THEAD = 14
local TOPPAD = 6
local HANDLEH = 7
local TRACKMAX = 600
local NAMEX = 3
local READOUTW = 110
local PHASEW = 90
local SKULLSZ = 16
local ZEROBAR = 2
local DOTMIN = 4
local DOTMAX = 12
local DOTSHARE = 0.14
local TRACKS = {
    { key = "boss",   min = 24, want = 68, color = "sem.lane.boss" },
    { key = "casts",  min = 22, want = 38, color = "sem.lane.casts" },
    { key = "auras",  rows = "auras",  color = "sem.lane.auras" },
    { key = "healed", rows = "healed", color = "sem.lane.healed" },
    { key = "taken",  rows = "taken",  color = "sem.lane.taken" },
    { key = "hp",     min = 34, want = 80, color = "sem.lane.hp" },
    { key = "threat", min = 24, want = 48, color = "sem.lane.threat" },
}
local TL = {}
ns.Timeline = TL
local frame, canvas, ruler, overlay, statusText, titleText, bareNote
local cursorLine, cursorLabel, cursorBg, hpDot
local detailAnchor, rowGlow
local lastBounds
local auraBar
local trackHeads = {}
local gutter, nameW = GUTTERMIN, GUTTERMIN - 6
local blockPool, barPool = {}, {}
local usedBlocks, usedBars = 0, 0
local fight, player, data
local lead, tail = 0, 0
local SelectPlayer
local viewFrom, viewTo = 0, 1
local dragging, dragX, dragFrom, dragY, dragScroll
local auraRows = {}
local hitRows, healRows = {}, {}
local trackScroll, trackTotal = 0, 0
local readouts = {}
local panelMissing = false
local catHeads = {}
local foldTracks, foldCats
local lineH = 11
local dropMode = false
local handles, resize = {}, nil
local function Folds()
    if not foldTracks then
        local ui = ns.GetDB().settings.ui
        if type(ui.trackFold) ~= "table" then ui.trackFold = {} end
        if type(ui.fxFold) ~= "table" then ui.fxFold = {} end
        foldTracks, foldCats = ui.trackFold, ui.fxFold
    end
    return foldTracks, foldCats
end
local function TrackFolded(key)
    local tracks = Folds()
    return tracks[key] == true
end
local function CatFolded(key)
    local _, cats = Folds()
    return cats[key] == true
end
local function FoldMark(label, folded)
    return (folded and "+ " or "- ") .. label
end
local function GetBlock()
    usedBlocks = usedBlocks + 1
    local b = blockPool[usedBlocks]
    if not b then
        b = CreateFrame("Frame", nil, canvas)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetPoint("LEFT", 0, 0)
        b.icon:Hide()
        b.reset = true
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("LEFT", 3, 0)
        b.label:SetJustifyH("LEFT")
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self)
            if not self.tip then return end
            local top, bottom = canvas:GetParent():GetTop(), self:GetBottom()
            if top and bottom and bottom > top then return end
            local icon = self.spellId and ns.Effects.IconById(self.spellId)
            local lines = { { self.tip, "tip.body" } }
            if self.tip2 then lines[#lines + 1] = { self.tip2, "tip.title", true } end
            if self.tip3 then lines[#lines + 1] = { self.tip3 } end
            if self.tip4 then lines[#lines + 1] = { self.tip4 } end
            if self.tip5 then lines[#lines + 1] = { self.tip5, "tip.dim", true } end
            if self.cast and ns.TimelineCast then ns.TimelineCast.Tip(lines, self.cast, player) end
            if self.jumpTo and fight and fight.players[self.jumpTo] then
                lines[#lines + 1] = { format(ns.T("tl.jump"), self.jumpTo), "badge.link", true }
            end
            lines[#lines + 1] = ns.ReplayLink.Line(fight, self.at, player)
            ns.Tip.Show(self, lines, icon)
        end)
        b:SetScript("OnLeave", function() ns.Tip.Hide() end)
        b:SetScript("OnMouseDown", function()
            if ns.FxDrag then ns.FxDrag.Clear() end
        end)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function(self)
            if not self.dragId or not ns.FxDrag then return end
            ns.Tip.Hide()
            ns.FxDrag.Start(self.dragId, self.dragName, self.dragIcon)
        end)
        b:SetScript("OnDragStop", function()
            if ns.FxDrag then ns.FxDrag.Stop() end
        end)
        b:SetScript("OnMouseUp", function(self)
            if ns.FxDrag and ns.FxDrag.Busy() or ns.ReplayLink.Shift(fight, self.at, player) then return end
            if self.onClick then
                ns.Tip.Hide()
                self.onClick(self)
                return
            end
            if self.jumpTo and fight and fight.players[self.jumpTo] then
                ns.Tip.Hide()
                if ns.TimelineLinks then ns.TimelineLinks.Focus(self.jumpTo, self.at, true) else SelectPlayer(self.jumpTo) end
            end
        end)
        blockPool[usedBlocks] = b
    end
    b.onClick = nil
    b.cat = nil
    b.tip3, b.at = nil, nil
    b.tip4 = nil
    b.tip5 = nil
    b.cast = nil
    b.wide = nil
    if b.castLabel then
        b.label:SetPoint("LEFT", 3, 0)
        b.castLabel = nil
    end
    ns.Kit.Tone(b.label, "text.bright")
    b.icon:SetDesaturated(false)
    b.dragId = nil
    b.dragName = nil
    b.dragIcon = nil
    b:Show()
    return b
end
local function GetBar()
    usedBars = usedBars + 1
    local t = barPool[usedBars]
    if not t then
        t = canvas:CreateTexture(nil, "ARTWORK")
        barPool[usedBars] = t
    end
    t:Show()
    return t
end
local function Culprit(it)
    if ns.TimelineLinks then return ns.TimelineLinks.Culprit(it, player) end
    return it.src ~= player and it.src or nil
end
local function ReleaseAll()
    for i = 1, usedBlocks do blockPool[i]:Hide() end
    for i = 1, usedBars do barPool[i]:Hide() end
    usedBlocks, usedBars = 0, 0
    catHeads = {}
end
local function PlotWidth()
    return canvas:GetWidth() - gutter
end
local function XOf(t)
    return gutter + (t - viewFrom) / (viewTo - viewFrom) * PlotWidth()
end
local function Band(y, h)
    return y >= 0 and (y + h) <= canvas:GetHeight() + 1
end
local function Clock(sec)
    local sign = sec < 0 and "-" or ""
    local abs = sec < 0 and -sec or sec
    local m = floor(abs / 60)
    return format("%s%d:%02d", sign, m, floor(abs - m * 60))
end
local function ClockMs(sec)
    local sign = sec < 0 and "-" or ""
    local abs = sec < 0 and -sec or sec
    local m = floor(abs / 60)
    local s = abs - m * 60
    return format("%s%d:%02d.%03d", sign, m, floor(s), floor((s - floor(s)) * 1000))
end
local function FitText(fs, text, width)
    fs:SetWidth(width)
    fs:SetText(text)
    if fs:GetStringWidth() <= width then return end
    local cut = text
    while #cut > 1 do
        local i = #cut
        while i > 1 do
            local b = cut:byte(i)
            if b < 128 or b >= 192 then break end
            i = i - 1
        end
        cut = cut:sub(1, i - 1)
        fs:SetText(cut .. "…")
        if fs:GetStringWidth() <= width then return end
    end
    fs:SetText("…")
end
local function ContentTop(index, bound)
    return TRACKS[index].rows and (bound.y + FXPAD) or bound.y
end
local function TrackWant(track)
    local ui = ns.GetDB().settings.ui
    local set = type(ui.trackH) == "table" and ui.trackH[track.key]
    return set or track.want or track.min
end
local function TrackBounds()
    local counts = { auras = #auraRows, healed = #healRows, taken = #hitRows }
    local view = max(1, canvas:GetHeight() - TOPPAD)
    local want, used = {}, 0
    local shared = {}
    for i = 1, #TRACKS do
        local track = TRACKS[i]
        if TrackFolded(track.key) then
            want[i] = THEAD
            used = used + THEAD
        elseif track.rows then
            local n = counts[track.rows] or 0
            want[i] = THEAD + ((n > 0) and (n * FXROW + FXPAD * 2) or FXROW)
            used = used + want[i]
        else
            want[i] = THEAD + track.min
            used = used + THEAD
            shared[#shared + 1] = i
        end
    end
    local left = view - used
    for j = 1, #shared do
        local i = shared[j]
        local hh = TrackWant(TRACKS[i])
        if hh > left then hh = max(TRACKS[i].min, left) end
        want[i] = THEAD + hh
        left = left - hh
    end
    local total = 0
    for i = 1, #TRACKS do
        total = total + want[i]
    end
    trackScroll = max(0, min(trackScroll, max(0, total - view)))
    total = total + TOPPAD
    local out = {}
    local y = TOPPAD - trackScroll
    for i = 1, #TRACKS do
        local hd = min(THEAD, want[i])
        out[i] = { hy = y, full = want[i], y = y + hd, h = want[i] - hd }
        y = y + want[i]
    end
    return out, total
end
local function SetTrackHeight(key, height)
    local ui = ns.GetDB().settings.ui
    if type(ui.trackH) ~= "table" then ui.trackH = {} end
    ui.trackH[key] = height
    ns.Timeline.Redraw()
end
local function PlaceHandle(index, bound)
    local track = TRACKS[index]
    local h = handles[index]
    if not h then
        h = CreateFrame("Frame", nil, canvas)
        h:SetHeight(HANDLEH)
        h:EnableMouse(true)
        h:SetFrameLevel(canvas:GetFrameLevel() + 6)
        h.tex = h:CreateTexture(nil, "OVERLAY")
        h.tex:SetAllPoints()
        h:SetScript("OnEnter", function(self)
            ns.Kit.Shade(self.tex, "surface.handle")
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(ns.T("tl.track.size"))
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(self)
            if not resize then ns.Kit.Shade(self.tex, "surface.clear") end
            GameTooltip:Hide()
        end)
        h:SetScript("OnMouseDown", function(self, button)
            if button == "RightButton" then
                SetTrackHeight(self.key, nil)
                return
            end
            resize = { key = self.key, min = self.min, h = self.h0,
                       y = GetCursorPosition() / self:GetEffectiveScale() }
        end)
        h:SetScript("OnMouseUp", function() resize = nil end)
        handles[index] = h
    end
    h.key = track.key
    h.min = track.min or FXROW
    h.h0 = bound.h
    if not resize or resize.key ~= track.key then
        ns.Kit.Shade(h.tex, "surface.clear")
    end
    h:SetWidth(canvas:GetWidth())
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0,
        -(bound.hy + bound.full - floor(HANDLEH / 2)))
    h:Show()
end
local function PlaceHandles(bounds)
    for i = 1, #TRACKS do
        local track = TRACKS[i]
        local fits = bounds[i].hy + bounds[i].full < canvas:GetHeight()
        if track.rows or TrackFolded(track.key) or not fits then
            if handles[i] then handles[i]:Hide() end
        else
            PlaceHandle(i, bounds[i])
        end
    end
end
local function DrawGrid(bounds)
    for i = 1, #TRACKS do
        if not Band(bounds[i].hy, bounds[i].full) then
        elseif i % 2 == 0 then
            local bg = GetBar()
            ns.Kit.Shade(bg, "surface.zebra")
            bg:ClearAllPoints()
            bg:SetPoint("TOPLEFT", canvas, "TOPLEFT", gutter, -bounds[i].hy)
            bg:SetWidth(PlotWidth())
            bg:SetHeight(bounds[i].full)
        end
        if bounds[i].hy >= 0 and bounds[i].hy <= canvas:GetHeight() then
            local sep = GetBar()
            ns.Kit.Shade(sep, "surface.grid")
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -bounds[i].hy)
            sep:SetWidth(canvas:GetWidth())
            sep:SetHeight(1)
        end
    end
    local edge = GetBar()
    ns.Kit.Shade(edge, "surface.edge")
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", canvas, "TOPLEFT", gutter - 1, 0)
    edge:SetWidth(1)
    edge:SetHeight(canvas:GetHeight())
end
local rulerPool = {}
local function DrawRuler()
    for i = 1, #rulerPool do rulerPool[i]:Hide() end
    local used = 0
    local span = viewTo - viewFrom
    local steps = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600 }
    local slots = max(4, floor(PlotWidth() / (MARKW + MARKGAP)))
    local step = steps[#steps]
    for i = 1, #steps do
        if span / steps[i] <= slots then step = steps[i] break end
    end
    local t = floor((viewFrom - fight.from) / step) * step + fight.from
    while t <= viewTo do
        if t >= viewFrom then
            local x = XOf(t)
            local line = GetBar()
            ns.Kit.Shade(line, "surface.line")
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, 0)
            line:SetWidth(1)
            line:SetHeight(canvas:GetHeight())
            used = used + 1
            local mark = rulerPool[used]
            if not mark then
                mark = ruler:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                mark:SetJustifyH("LEFT")
                rulerPool[used] = mark
            end
            mark:ClearAllPoints()
            mark:SetPoint("BOTTOMLEFT", ruler, "BOTTOMLEFT", x + 5, 3)
            mark:SetText(Clock(t - fight.from))
            mark:Show()
        end
        t = t + step
    end
end
local function Glued()
    local ui = ns.GetDB().settings.ui
    return ui.glue ~= false
end
local function GlueIds()
    if not data then return {} end
    if not data.glueIds then
        local set = {}
        local lists = { data.healed, data.taken }
        for k = 1, #lists do
            local list = lists[k]
            for i = 1, #list do
                local id = tonumber(list[i].id)
                if id then set[id] = true end
            end
        end
        data.glueIds = set
    end
    return data.glueIds
end
local function BuildAuraRows()
    auraRows = {}
    local cats = ns.Effects.categories
    local buckets = {}
    for i = 1, #cats do
        buckets[cats[i].key] = { bad = {}, good = {}, off = {} }
    end
    buckets[ns.Effects.ROOT] = { bad = {}, good = {}, off = {} }
    local items = data and data.auras
    local glue = Glued()
    if items then
        tsort(items, function(a, b) return a.t < b.t end)
        local index = {}
        for i = 1, #items do
            local a = items[i]
            local id = tonumber(a.id)
            local key = ns.Effects.GlueTo(id) or id
            if id and not (glue and GlueIds()[key]) then
                local row = index[key]
                if not row then
                    row = { label = ns.Effects.Name(key), id = key, kind = a.kind,
                            items = {} }
                    index[key] = row
                    local bucket = buckets[ns.Effects.Category(key)] or buckets.aura
                    local into
                    if not ns.Effects.Tracked(key) then
                        into = bucket.off
                    else
                        into = (a.kind == "debuff") and bucket.bad or bucket.good
                    end
                    into[#into + 1] = row
                end
                row.items[#row.items + 1] = a
                if id ~= key then
                    row.parts = row.parts or {}
                    row.parts[id] = (row.parts[id] or 0) + 1
                end
            end
        end
    end
    local function Emit(key, base)
        local bucket = buckets[key]
        if #bucket.off > 0 or dropMode then
            local hkey = key .. ":off"
            local hfold = not CatFolded(hkey)
            auraRows[#auraRows + 1] = {
                head = true,
                sub = true,
                cat = hkey,
                depth = base,
                label = ns.T("fx.cat.hidden"),
                count = #bucket.off,
                folded = hfold,
            }
            if not hfold then
                for j = 1, #bucket.off do
                    bucket.off[j].depth = base + 1
                    auraRows[#auraRows + 1] = bucket.off[j]
                end
            end
        end
        for j = 1, #bucket.bad do
            bucket.bad[j].depth = base
            auraRows[#auraRows + 1] = bucket.bad[j]
        end
        for j = 1, #bucket.good do
            bucket.good[j].depth = base
            auraRows[#auraRows + 1] = bucket.good[j]
        end
    end
    local root = buckets[ns.Effects.ROOT]
    if #root.bad + #root.good + #root.off > 0 or dropMode then
        Emit(ns.Effects.ROOT, 0)
    end
    for i = 1, #cats do
        local key = cats[i].key
        local bucket = buckets[key]
        local count = #bucket.bad + #bucket.good
        if count > 0 or #bucket.off > 0 or dropMode then
            local folded = CatFolded(key)
            auraRows[#auraRows + 1] = {
                head = true,
                cat = key,
                depth = 0,
                label = ns.Effects.CategoryLabel(key),
                count = count,
                folded = folded,
            }
            if not folded then Emit(key, 1) end
        end
    end
end
local function RowTotal(row, heal)
    local text = format(heal and ns.T("tl.row.heal") or ns.T("tl.row.hit"), ns.Num(row.total), row.hits,
        ns.Plural(row.hits, ns.T(heal and "tl.w.heal" or "tl.w.hit")))
    if row.misses > 0 then text = text .. format(ns.T("tl.row.miss"), row.misses) end
    return text
end
local function MissText(it)
    local word = ns.L["tl.miss." .. it.miss] or it.miss
    if (it.missN or 0) > 0 then return word .. " " .. ns.Num(it.missN) end
    return word
end
local function SplitHot(rows, track)
    local root, hot, off = {}, {}, {}
    for i = 1, #rows do
        local row = rows[i]
        local set = ns.Effects.RowCat(row.id, track)
        local into
        if set == "off" then
            into = off
            row.off = true
        elseif set == "hot" then
            into = hot
        elseif set == "root" then
            into = root
        elseif row.hot or row.spans then
            into = hot
        else
            into = root
        end
        into[#into + 1] = row
    end
    local out = {}
    local function Shelf(bucket, key, label, sub, foldDefault)
        if #bucket == 0 and not dropMode then return end
        local folded = foldDefault ~= CatFolded(key)
        out[#out + 1] = { head = true, cat = key, sub = sub, depth = 0,
                          folded = folded, label = label, count = #bucket }
        if folded then return end
        for i = 1, #bucket do
            bucket[i].depth = 1
            out[#out + 1] = bucket[i]
        end
    end
    Shelf(off, track .. ":off", ns.T("fx.cat.hidden"), true, true)
    for i = 1, #root do
        root[i].depth = 0
        out[#out + 1] = root[i]
    end
    Shelf(hot, track .. ":hot", ns.T("fx.cat.hot"), false, false)
    return out
end
local function AttachSpans(rows)
    if not Glued() or not data or not data.auras then return end
    local byId = {}
    for i = 1, #rows do
        local id = tonumber(rows[i].id)
        if id then byId[id] = rows[i] end
    end
    for i = 1, #data.auras do
        local a = data.auras[i]
        local id = tonumber(a.id)
        local row = byId[ns.Effects.GlueTo(id) or id]
        if row then
            row.spans = row.spans or {}
            row.spans[#row.spans + 1] = a
        end
    end
end
local function BuildAmountRows()
    hitRows = ns.Encounters.GroupRows(data and data.taken)
    healRows = ns.Encounters.GroupRows(data and data.healed)
    AttachSpans(healRows)
    AttachSpans(hitRows)
    healRows = SplitHot(healRows, "healed")
    hitRows = SplitHot(hitRows, "taken")
end
local function DrawPoints(items, bound, color, own)
    if not items then return end
    if own and ns.TimelineGcd
        and ns.TimelineGcd.Draw(data, bound, color, GetBlock, GetBar, XOf, viewFrom, viewTo) then return end
    local TC = own and ns.TimelineCast or nil
    local lastX, shown = -100, 0
    local top = bound.y + 3
    local hh = bound.h - 6
    local iconSize = min(hh, max(ICONMIN, min(ICONMAX, floor(hh * ICONSHARE))))
    for i = 1, #items do
        local it = items[i]
        if it.t >= viewFrom and it.t <= viewTo then
            local x = XOf(it.t)
            if x - lastX >= 2 and shown < 150 then
                shown = shown + 1
                local roomy = (x - lastX) >= iconSize + 2
                local icon = roomy and it.id and ns.Effects.IconById(it.id) or nil
                local b = GetBlock()
                if icon then
                    b:SetWidth(iconSize)
                    b:SetHeight(iconSize)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -(top + (hh - iconSize) / 2))
                    ns.Kit.Shade(b.tex, "surface.clear")
                    b.icon:SetWidth(iconSize)
                    b.icon:SetHeight(iconSize)
                    b.icon:Show()
                    b.icon:SetTexture(icon)
                    lastX = x + iconSize
                else
                    b:SetWidth(3)
                    b:SetHeight(hh)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -top)
                    ns.Kit.Shade(b.tex, color, 0.95)
                    b.icon:Hide()
                    lastX = x
                end
                b.label:SetText("")
                b.tip, b.at = it.label, it.t
                b.jumpTo = nil
                b.spellId = tonumber(it.id)
                if TC then
                    b.cast = it
                    local nx = items[i + 1] and min(XOf(items[i + 1].t), canvas:GetWidth()) or canvas:GetWidth()
                    lastX = lastX + TC.Label(b, it, max(3, lastX - x), nx - x - iconSize - 2)
                end
                b.tip2 = format("%s%s", Clock(it.t - fight.from),
                    it.amount and it.amount > 0
                        and format("  |  %s: %d", it.src or "", it.amount) or "")
            end
        end
    end
end
local function FoldCat(head)
    if not head.cat then return end
    local _, cats = Folds()
    cats[head.cat] = not cats[head.cat] or nil
    ns.Timeline.Redraw()
end
local function DrawHead(row, y, indent)
    local head = GetBlock()
    head:SetWidth(max(nameW, canvas:GetWidth() - indent - 2))
    head:SetHeight(FXBAR)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", canvas, "TOPLEFT", indent, -(y + FXPAD))
    if row.sub then
        ns.Kit.Shade(head.tex, "surface.head")
        ns.Kit.Tone(head.label, "surface.headText")
    else
        ns.Kit.Shade(head.tex, "surface.headOn")
        ns.Kit.Tone(head.label, "surface.headOnText")
    end
    head.icon:Hide()
    head.label:SetPoint("LEFT", 4, 0)
    head.label:SetWidth(max(nameW, canvas:GetWidth() - indent - 10))
    head.label:SetText(row.folded
        and format(ns.T("tl.fx.folded"), FoldMark(row.label, true), row.count)
        or FoldMark(row.label, false))
    head.tip = row.label
    head.jumpTo = nil
    head.spellId = nil
    head.cat = row.cat
    head.onClick = FoldCat
    return head
end
local function DrawAuras(bound)
    if TrackFolded("auras") then return end
    local top = bound.y + FXPAD
    for slot = 1, #auraRows do
        local row = auraRows[slot]
        if not row then break end
        local y = top + (slot - 1) * FXROW
        local indent = NAMEX + (row.depth or 0) * INDENT
        if not Band(y, FXROW) then
        elseif row.head then
            local head = DrawHead(row, y, indent)
            head.tip2 = row.sub and ns.T("tl.fx.hide") or ns.T("tl.fx.fold")
            head.jumpTo = nil
            head.spellId = nil
            head.cat = row.cat
            head.onClick = FoldCat
            catHeads[#catHeads + 1] = { frame = head, tex = head.tex,
                                        cat = row.cat, sub = row.sub }
        else
        local wide = max(24, nameW - indent + NAMEX)
        local gut = GetBlock()
        gut:SetWidth(wide)
        gut:SetHeight(FXBAR)
        gut:ClearAllPoints()
        gut:SetPoint("TOPLEFT", canvas, "TOPLEFT", indent, -(y + FXPAD))
        ns.Kit.Shade(gut.tex, "surface.alt")
        gut.tip = row.label
        gut.jumpTo = nil
        gut.spellId = tonumber(row.id)
        gut.tip2 = format(ns.T("tl.fx.count"), #row.items)
        gut.tip3 = ns.T("tl.fx.move")
        if row.parts then
            local list = {}
            for pid, n in pairs(row.parts) do
                list[#list + 1] = format("%s (%d) — %d", ns.Effects.Name(pid), pid, n)
            end
            tsort(list)
            gut.tip3 = format(ns.T("tl.fx.parts"), table.concat(list, ", "))
        end
        catHeads[#catHeads + 1] = { frame = gut, tex = gut.tex,
                                    cat = "row:" .. row.id, row = true }
        local icon = ns.Effects.IconById(row.id)
        if icon then
            gut.icon:SetWidth(FXBAR)
            gut.icon:SetHeight(FXBAR)
            gut.icon:SetTexture(icon)
            gut.icon:Show()
            gut.label:SetPoint("LEFT", FXBAR + 2, 0)
        else
            gut.icon:Hide()
            gut.label:SetPoint("LEFT", 3, 0)
        end
        gut.dragId = row.id
        gut.dragName = row.label
        gut.dragIcon = icon
        local shown = ns.Effects.Tracked(row.id)
        if shown then
            ns.Kit.Tone(gut.label, "surface.label")
        else
            ns.Kit.Tone(gut.label, "surface.labelOff")
            gut.icon:SetDesaturated(true)
        end
        FitText(gut.label, row.label, wide - 6 - (icon and FXBAR or 0))
        local alpha = shown and 0.92 or 0.30
        for i = 1, #row.items do
            local a = row.items[i]
            local to = a.to or a.t
            if to >= viewFrom and a.t <= viewTo then
                local x0 = XOf(max(a.t, viewFrom))
                local x1 = XOf(min(to, viewTo))
                local b = GetBlock()
                b:SetWidth(max(3, x1 - x0))
                b:SetHeight(FXBAR)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0, -(y + FXPAD))
                if a.kind == "debuff" then
                    ns.Kit.Shade(b.tex, "sem.dmg", alpha)
                else
                    ns.Kit.Shade(b.tex, "sem.heal", alpha)
                end
                b.icon:Hide()
                b.label:SetText("")
                b.tip, b.at = a.label, a.t
                b.spellId = tonumber(a.id)
                b.jumpTo = Culprit(a)
                b.tip2 = format("%s — %s  (%.1f с)%s", Clock(a.t - fight.from),
                    Clock(to - fight.from), to - a.t,
                    a.src and ("  |  " .. a.src) or "")
            end
        end
        end
    end
end
local function DrawAmountRows(rows, bound, color, heal)
    if #rows == 0 then return end
    for slot = 1, #rows do
        local row = rows[slot]
        local y = bound.y + FXPAD + (slot - 1) * FXROW
        local indent = NAMEX + (row.depth or 0) * INDENT
        if row.head then
            if Band(y, FXROW) then
                local head = DrawHead(row, y, indent)
                head.tip2 = row.sub and ns.T("tl.fx.hide") or ns.T("tl.fx.fold")
                catHeads[#catHeads + 1] = { frame = head, tex = head.tex,
                                            cat = row.cat, sub = row.sub }
            end
        elseif Band(y, FXROW) then
        local gut = GetBlock()
        gut:SetWidth(max(24, nameW - indent + NAMEX))
        gut:SetHeight(FXBAR)
        gut:ClearAllPoints()
        gut:SetPoint("TOPLEFT", canvas, "TOPLEFT", indent, -(y + FXPAD))
        ns.Kit.Shade(gut.tex, "surface.alt")
        gut.tip = row.label
        gut.spellId = tonumber(row.id)
        gut.jumpTo = nil
        gut.tip2 = RowTotal(row, heal)
        gut.tip3 = ns.T("tl.row.bind")
        if row.id then
            catHeads[#catHeads + 1] = { frame = gut, tex = gut.tex,
                                        cat = "row:" .. row.id, row = true }
            gut.dragId = row.id
            gut.dragName = row.label
        end
        if row.off then
            ns.Kit.Tone(gut.label, "surface.labelOff")
        end
        local icon = row.swing and (ns.Effects.IconById(SWING_SPELL) or SWING_ICON)
            or ns.Effects.IconById(row.id)
        if icon then
            gut.icon:SetWidth(FXBAR)
            gut.icon:SetHeight(FXBAR)
            gut.icon:SetTexture(icon)
            gut.icon:SetDesaturated(row.off)
            gut.icon:Show()
            gut.dragIcon = icon
            gut.label:SetPoint("LEFT", FXBAR + 2, 0)
        else
            gut.icon:Hide()
            gut.label:SetPoint("LEFT", 3, 0)
        end
        FitText(gut.label, row.label,
            max(24, nameW - indent + NAMEX) - 6 - (icon and FXBAR or 0))
        if row.spans then
            for i = 1, #row.spans do
                local a = row.spans[i]
                local to = a.to or a.t
                if to >= viewFrom and a.t <= viewTo then
                    local x0 = XOf(max(a.t, viewFrom))
                    local band = GetBar()
                    ns.Kit.Shade(band, color, 0.22)
                    band:ClearAllPoints()
                    band:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0, -(y + FXPAD))
                    band:SetWidth(max(2, XOf(min(to, viewTo)) - x0))
                    band:SetHeight(FXBAR)
                end
            end
        end
        local peak = 1
        for i = 1, #row.items do
            if row.items[i].amount > peak then peak = row.items[i].amount end
        end
        local lastX = -100
        for i = 1, #row.items do
            local it = row.items[i]
            if it.t >= viewFrom and it.t <= viewTo then
                local x = XOf(it.t)
                if x - lastX >= 2 then
                    local b = GetBlock()
                    b:SetWidth(3)
                    b:ClearAllPoints()
                    if it.miss then
                        b:SetHeight(MISSH)
                        b:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -(y + FXPAD))
                        ns.Kit.Shade(b.tex, "sem.lane.takenMiss", row.off and 0.30 or 0.95)
                    else
                        local hh = max(2, (it.amount / peak) ^ 0.5 * FXBAR)
                        b:SetHeight(hh)
                        b:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -(y + FXPAD + FXBAR - hh))
                        ns.Kit.Shade(b.tex, color, row.off and 0.30 or 0.95)
                    end
                    b.icon:Hide()
                    b.label:SetText("")
                    b.tip, b.at = it.label, it.t
                    b.spellId = it.swing and SWING_SPELL or tonumber(it.id)
                    b.jumpTo = Culprit(it)
                    local extra = ""
                    if (it.over or 0) > 0 then
                        extra = format(heal and ns.T("tl.tip.overheal") or ns.T("tl.tip.overkill"),
                            it.over)
                    end
                    if (it.absorbed or 0) > 0 and not it.miss then
                        extra = extra .. format(ns.T("tl.tip.absorbed"), it.absorbed)
                    end
                    b.tip2 = format(heal and ns.T("tl.tip.gotheal") or ns.T("tl.tip.gothit"),
                        it.src or "?", player or "?", it.miss and MissText(it) or ns.Num(it.amount), extra)
                    if it.mc then
                        b.tip3 = format(ns.T("tl.tip.mc"), it.src or "?")
                    end
                    if it.victim then
                        b.tip3 = format(ns.T("tl.tip.chaser"), it.victim, it.chaseFor or 0)
                        b.tip4 = format(ns.T("tl.tip.splash"), it.chaseN or 0,
                            ns.Num(it.chaseSum or 0))
                    end
                    b.tip5 = format(ns.T("tl.tip.when"), Clock(it.t - fight.from), RowTotal(row, heal))
                    lastX = x
                end
            end
        end
        end
    end
end
local function DrawHp(bound)
    local hp = data.hp
    if not hp or #hp == 0 then return end
    local top = bound.y + 4
    local hh = bound.h - 8
    for i = 1, #hp do
        local s = hp[i]
        local nextT = hp[i + 1] and hp[i + 1].t or viewTo
        if nextT >= viewFrom and s.t <= viewTo then
            local x0 = XOf(max(s.t, viewFrom))
            local x1 = XOf(min(nextT, viewTo))
            local w = max(1, x1 - x0)
            local t = GetBar()
            if s.pct <= 0 then
                ns.Kit.Shade(t, "sem.death")
                t:SetHeight(ZEROBAR)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0, -(top + hh - ZEROBAR))
            else
                local barH = max(1, s.pct * hh)
                if s.pct < 0.35 then
                    ns.Kit.Shade(t, "sem.hpLow")
                else
                    ns.Kit.Shade(t, "sem.hpOk")
                end
                t:SetHeight(barH)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0, -(top + hh - barH))
            end
            t:SetWidth(w)
        end
    end
end
local deathPool = {}
local skullPool = {}
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local markPool = {}
local headPool = {}
local function PullLabel(pull)
    if not pull or not pull.src then return ns.T("tl.pull") end
    local how = pull.spell or ns.T("tl.pull.melee")
    local who = pull.src
    if pull.owner then
        who = format(ns.T("tl.pull.owner"), pull.src, pull.owner)
    elseif pull.pet then
        who = format(ns.T("tl.pull.pet"), pull.src)
    end
    return format(ns.T("tl.pull.first"), who, how)
end
local function DrawPhases()
    for i = 1, #markPool do markPool[i]:Hide() end
    if not fight then return end
    for i = 1, #headPool do headPool[i]:Hide() end
    local pull = data and data.pull
    local marks = { { t = fight.from, label = PullLabel(pull), head = true },
                    { t = fight.to, label = ns.T("tl.end"), head = true, right = true } }
    local wanted = ns.phases and ns.phases[fight.boss]
    if wanted and data and data.boss then
        for i = 1, #wanted do
            for j = 1, #data.boss do
                if data.boss[j].label == wanted[i].spell then
                    marks[#marks + 1] = { t = data.boss[j].t, label = wanted[i].label,
                                          dim = true }
                    if not wanted[i].every then break end
                end
            end
        end
    end
    local own = data and data.marks
    for i = 1, own and #own or 0 do
        marks[#marks + 1] = { t = own[i].t, label = own[i].label }
    end
    local used = 0
    for i = 1, #marks do
        local m = marks[i]
        if m.t >= viewFrom and m.t <= viewTo then
            used = used + 1
            local b = markPool[used]
            if not b then
                b = CreateFrame("Frame", nil, overlay)
                b.line = b:CreateTexture(nil, "OVERLAY")
                b.line:SetPoint("TOPLEFT", 0, 0)
                b.line:SetWidth(1)
                b.tag = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.tag:SetPoint("TOPLEFT", 3, -1)
                markPool[used] = b
            end
            b:SetWidth(PHASEW)
            b:SetHeight(canvas:GetHeight())
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", overlay, "TOPLEFT", XOf(m.t), 0)
            if m.dim then
                ns.Kit.Shade(b.line, "sem.phaseDim")
                ns.Kit.Tone(b.tag, "sem.phaseDimText")
            else
                ns.Kit.Shade(b.line, "sem.phase")
                ns.Kit.Tone(b.tag, "sem.phaseText")
            end
            b.line:SetHeight(canvas:GetHeight())
            b.tag:SetText(m.head and "" or m.label)
            b:Show()
            if m.head then
                local h = headPool[i]
                if not h then
                    h = ruler:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    h:SetJustifyH("LEFT")
                    headPool[i] = h
                end
                h:ClearAllPoints()
                if m.right then
                    h:SetPoint("TOPRIGHT", ruler, "TOPLEFT", XOf(m.t) - 3, -1)
                else
                    h:SetPoint("TOPLEFT", ruler, "TOPLEFT", XOf(m.t) + 3, -1)
                end
                h:SetText(m.label)
                ns.Kit.Tone(h, "sem.phaseHead")
                h:Show()
            end
        end
    end
end
local function DrawDeaths()
    for i = 1, #deathPool do deathPool[i]:Hide() end
    for i = 1, #skullPool do skullPool[i]:Hide() end
    if not data.deaths then return end
    local used = 0
    for i = 1, #data.deaths do
        local t = data.deaths[i]
        if t >= viewFrom and t <= viewTo then
            used = used + 1
            local x = XOf(t)
            local line = deathPool[used]
            if not line then
                line = overlay:CreateTexture(nil, "OVERLAY")
                deathPool[used] = line
            end
            ns.Kit.Shade(line, "sem.deathLine")
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
            line:SetWidth(1)
            line:SetHeight(canvas:GetHeight())
            line:Show()
            local skull = skullPool[used]
            if not skull then
                skull = overlay:CreateTexture(nil, "OVERLAY")
                skull:SetTexture(SKULL)
                skull:SetWidth(SKULLSZ)
                skull:SetHeight(SKULLSZ)
                skullPool[used] = skull
            end
            skull:ClearAllPoints()
            skull:SetPoint("TOP", overlay, "TOPLEFT", x, -1)
            skull:Show()
        end
    end
end
local function LastBefore(items, t)
    if not items then return nil end
    local found = nil
    for i = 1, #items do
        if items[i].t <= t then found = items[i] else break end
    end
    return found
end
local function ShowReadouts(t)
    if not data then
        for i = 1, #readouts do readouts[i]:Hide() end
        return
    end
    local bounds = TrackBounds()
    local x = XOf(t)
    local flip = (canvas:GetWidth() - x) < READOUTW
    local text = {}
    local b = LastBefore(data.boss, t)
    text[1] = b and b.label or nil
    local c = LastBefore(data.casts, t)
    text[2] = c and (ns.TimelineCast and ns.TimelineCast.Readout(c) or c.label) or nil
    local active = 0
    for slot = 1, #auraRows do
        local list = auraRows[slot].items
        for j = 1, (list and #list or 0) do
            local a = list[j]
            if a.t <= t and (a.to or a.t) >= t then active = active + 1 break end
        end
    end
    text[3] = active > 0 and format(ns.T("tl.read.auras"), active) or nil
    local heal = LastBefore(data.healed, t)
    text[4] = heal and (t - heal.t) < 3 and format("%s: +%d", heal.label, heal.amount) or nil
    local d = LastBefore(data.taken, t)
    text[5] = d and (t - d.t) < 3 and (d.miss and format("%s: %s", d.label, MissText(d))
        or format("%s: %d", d.label, d.amount)) or nil
    local h = LastBefore(data.hp, t)
    if h then
        text[6] = h.hp and format("%d%%  (%d)", floor(h.pct * 100 + 0.5), h.hp)
            or format("%d%%", floor(h.pct * 100 + 0.5))
    end
    text[7] = ns.TimelineThreat and ns.TimelineThreat.Readout(fight, player, t) or nil
    if h and hpDot and not TrackFolded("hp") then
        local b = bounds[6]
        local top = b.y + 4
        local hh = b.h - 8
        local dot = max(DOTMIN, min(DOTMAX, floor(hh * DOTSHARE)))
        hpDot:SetWidth(dot)
        hpDot:SetHeight(dot)
        hpDot:ClearAllPoints()
        hpDot:SetPoint("CENTER", overlay, "TOPLEFT", x, -(top + hh - h.pct * hh))
        hpDot:Show()
    elseif hpDot then
        hpDot:Hide()
    end
    for i = 1, #readouts do
        local fs = readouts[i]
        if text[i] and not TrackFolded(TRACKS[i].key) then
            local ty = bounds[i].y + 2
            fs:ClearAllPoints()
            if flip then
                fs:SetPoint("TOPRIGHT", overlay, "TOPLEFT", x - 4, -ty)
                fs:SetJustifyH("RIGHT")
            else
                fs:SetPoint("TOPLEFT", overlay, "TOPLEFT", x + 4, -ty)
                fs:SetJustifyH("LEFT")
            end
            fs:SetText(text[i])
            fs:Show()
        else
            fs:Hide()
        end
    end
end
local function HideReadouts()
    for i = 1, #readouts do readouts[i]:Hide() end
    if hpDot then hpDot:Hide() end
end
local function Redraw()
    if not player and ns.SummaryView and ns.SummaryView.IsShown() then return end
    local p0 = ns.Prof.on and debugprofilestop()
    ReleaseAll()
    for i = 1, #trackHeads do trackHeads[i]:Hide() end
    if not fight then return end
    local bounds, total = TrackBounds()
    trackTotal = total
    lastBounds = bounds
    if auraBar then
        auraBar:SetHeight(canvas:GetHeight())
        auraBar:ClearAllPoints()
        auraBar:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -1, 0)
        auraBar:SetState(trackScroll, canvas:GetHeight(), total)
        if total > canvas:GetHeight() then auraBar:Show() else auraBar:Hide() end
    end
    DrawGrid(bounds)
    PlaceHandles(bounds)
    DrawRuler()
    if ns.TimelineLinks then ns.TimelineLinks.Paint() end
    local view = canvas:GetHeight()
    for i = 1, #TRACKS do
        local head = trackHeads[i]
        local key = TRACKS[i].key
        local folded = TrackFolded(key)
        local top = max(0, bounds[i].hy)
        local room = min(view, bounds[i].hy + bounds[i].full) - top
        if room < 8 then
            head:Hide()
        else
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", canvas, "TOPLEFT", 1, -(top + 1))
            head:SetWidth(max(24, gutter - 2))
            head:SetHeight(min(room, THEAD - 1))
            head.text:ClearAllPoints()
            head.text:SetPoint("LEFT", 3, 0)
            head.text:SetWidth(max(10, gutter - 7))
            head.text:SetText(FoldMark(ns.T("tl.track." .. key), folded))
            head:Show()
            if not folded and (key == "auras" or key == "healed" or key == "taken") then
                catHeads[#catHeads + 1] = { frame = head, tex = head.bg,
                                            cat = key == "auras" and ns.Effects.ROOT or key }
            end
        end
    end
    DrawAuras(bounds[3])
    if not data then
        local bare = fight and ns.Store.Bare(fight)
        statusText:SetText(ns.T(bare and "rec.bare" or "tl.pickplayer"))
        if bare then bareNote:Show() else bareNote:Hide() end
        return
    end
    bareNote:Hide()
    if not TrackFolded("boss") then
        DrawPoints(data.boss, bounds[1], TRACKS[1].color)
    end
    if not TrackFolded("casts") then
        DrawPoints(data.casts, bounds[2], TRACKS[2].color, true)
    end
    if not TrackFolded("healed") then
        DrawAmountRows(healRows, bounds[4], TRACKS[4].color, true)
    end
    if not TrackFolded("taken") then
        DrawAmountRows(hitRows, bounds[5], TRACKS[5].color, false)
    end
    if not TrackFolded("hp") then
        DrawHp(bounds[6])
    end
    if ns.TimelineThreat then
        ns.TimelineThreat.Draw(bounds[7], TrackFolded("threat"), fight, player, GetBlock, GetBar, XOf, viewFrom, viewTo)
    end
    DrawPhases()
    DrawDeaths()
    local span = max(1, fight.to - fight.from)
    statusText:SetText(format(ns.T("tl.window"),
        Clock(viewFrom - fight.from), Clock(viewTo - fight.from), viewTo - viewFrom,
        floor((data.dmgDone or 0) / span), floor((data.healDone or 0) / span)))
    if p0 then ns.Prof.Add("tl.draw", debugprofilestop() - p0, usedBlocks + usedBars) end
end
function SelectPlayer(name)
    if ns.ThreatView then ns.ThreatView.Hide() end
    if ns.SummaryView then ns.SummaryView.Hide() end
    if ns.EffectPanel then ns.EffectPanel.SetTimeline(true) end
    ruler:Show()
    canvas:GetParent():Show()
    player, data = name, nil
    hitRows, healRows = {}, {}
    BuildAuraRows()
    titleText:SetText(format("%s — %s", fight.boss, name))
    TL.RefreshLists()
    Redraw()
    if ns.Store.Bare(fight) then return end
    statusText:SetText(ns.T("tl.loading"))
    local want = fight
    ns.Encounters.Timeline(fight, name, function(d)
        if not d or fight ~= want or player ~= name then return end
        local p1 = ns.Prof.on and debugprofilestop()
        data = d
        BuildAuraRows()
        BuildAmountRows()
        if p1 then ns.Prof.Add("tl.rows", debugprofilestop() - p1, #auraRows + #hitRows + #healRows) end
        Redraw()
    end)
end
local function SelectFight(f)
    fight = f
    lead = ns.Encounters.Lead(f)
    tail = ns.Encounters.Tail(f)
    viewFrom, viewTo = lead, tail
    player, data = nil, nil
    hitRows, healRows = {}, {}
    if ns.EffectPanel then ns.EffectPanel.SetTimeline(false) end
    BuildAuraRows()
    titleText:SetText(ns.FightList and ns.FightList.Title(f) or f.boss)
    if ns.MapView then ns.MapView.SetFight(f) end
    if ns.RaidSummaryView then ns.RaidSummaryView.Hide() end
    if ns.ThreatView then ns.ThreatView.Follow(f) end
    TL.RefreshLists()
    if ns.SummaryView then
        ReleaseAll()
        ruler:Hide()
        canvas:GetParent():Hide()
        statusText:SetText("")
        ns.SummaryView.Show(f)
    else
        Redraw()
    end
end
function TL.RefreshLists()
    if ns.FightList then ns.FightList.Refresh(fight, player) end
end
local function BuildFrame(host)
    frame = host
    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", MARGIN, -12)
    titleText:SetText(ns.T("tl.title"))
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", titleText, "RIGHT", 16, 0)
    statusText:SetPoint("RIGHT", frame, "TOPRIGHT", -416, -19)
    statusText:SetJustifyH("LEFT")
    statusText:SetHeight(14)
    if ns.FightList then ns.FightList.Attach(frame, MARGIN, SIDETOP, titleText, statusText) end
    if ns.JobBar then ns.JobBar.Attach(frame, statusText) end
end
local function BuildCanvas()
    ruler = CreateFrame("Frame", nil, frame)
    ruler:SetPoint("TOPLEFT", MARGIN + SIDE, -HEADH)
    ruler:SetHeight(RULER)
    local clip = CreateFrame("ScrollFrame", nil, frame)
    clip:SetPoint("TOPLEFT", ruler, "BOTTOMLEFT", 0, -RULERGAP)
    canvas = CreateFrame("Frame", nil, clip)
    clip:SetScrollChild(canvas)
    canvas:EnableMouse(true)
    canvas:EnableMouseWheel(true)
    local cbg = canvas:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    ns.Kit.Paint(cbg, "surface.bg")
    bareNote = CreateFrame("Frame", nil, clip)
    bareNote:SetAllPoints(clip)
    bareNote:SetFrameLevel(canvas:GetFrameLevel() + 20)
    local noteHead = bareNote:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noteHead:SetPoint("BOTTOM", bareNote, "CENTER", 0, 4)
    noteHead:SetText(ns.T("tl.bare.head"))
    ns.Kit.Text(noteHead, "text.title")
    local noteBody = bareNote:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noteBody:SetPoint("TOP", bareNote, "CENTER", 0, -4)
    noteBody:SetWidth(520)
    noteBody:SetText(ns.T("tl.bare.body"))
    ns.Kit.Text(noteBody, "text.secondary")
    bareNote:Hide()
    if ns.SummaryView then
        local host = CreateFrame("Frame", nil, frame)
        host:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, -HEADH)
        host:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
        host:SetFrameLevel(clip:GetFrameLevel() + 40)
        ns.SummaryView.Attach(host)
        if ns.RaidSummaryView then
            local raidHost = CreateFrame("Frame", nil, frame)
            raidHost:SetAllPoints(host)
            raidHost:SetFrameLevel(host:GetFrameLevel() + 1)
            ns.RaidSummaryView.Attach(raidHost)
        end
    end
    if ns.ThreatView then ns.ThreatView.Attach(frame, clip, MARGIN, HEADH) end
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 20)
    if ns.MakeScrollBar then
        auraBar = ns.MakeScrollBar(overlay, MINROWS * ROW)
        auraBar.onScroll = function(offset)
            trackScroll = offset
            Redraw()
        end
    end
    cursorLine = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(cursorLine, "sem.cursor")
    cursorLine:SetWidth(1)
    cursorLine:Hide()
    cursorBg = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(cursorBg, "surface.shade")
    cursorBg:Hide()
    cursorLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.Kit.Text(cursorLabel, "sem.cursorText")
    cursorLabel:Hide()
    hpDot = overlay:CreateTexture(nil, "OVERLAY")
    ns.Kit.Paint(hpDot, "sem.cursorDot")
    hpDot:SetWidth(DOTMIN)
    hpDot:SetHeight(DOTMIN)
    hpDot:Hide()
    rowGlow = canvas:CreateTexture(nil, "BACKGROUND")
    ns.Kit.Paint(rowGlow, "surface.line")
    rowGlow:Hide()
    detailAnchor = CreateFrame("Frame", nil, frame)
    detailAnchor:SetHeight(1)
    detailAnchor:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 0, 0)
    for i = 1, #TRACKS do
        local fs = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ns.Kit.Text(fs, "sem.readout")
        fs:Hide()
        readouts[i] = fs
    end
    for i = 1, #TRACKS do
        local head = CreateFrame("Button", nil, canvas)
        head:SetHeight(THEAD - 1)
        head:SetFrameLevel(canvas:GetFrameLevel() + 10)
        head.key = TRACKS[i].key
        head.bg = head:CreateTexture(nil, "BACKGROUND")
        head.bg:SetAllPoints()
        ns.Kit.Paint(head.bg, "surface.laneHead")
        head.text = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        head.text:SetJustifyH("LEFT")
        ns.Kit.Text(head.text, "surface.laneText")
        head:SetScript("OnEnter", function(self)
            ns.Kit.Paint(self.bg, "surface.laneHeadHover")
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.T("tl.track." .. self.key))
            ns.Kit.TipAdd(ns.T("tl.track.fold"), "text.secondary")
            GameTooltip:Show()
        end)
        head:SetScript("OnLeave", function(self)
            ns.Kit.Paint(self.bg, "surface.laneHeadIdle")
            GameTooltip:Hide()
        end)
        head:SetScript("OnMouseDown", function()
            if ns.FxDrag then ns.FxDrag.Clear() end
        end)
        head:SetScript("OnClick", function(self)
            local tracks = Folds()
            tracks[self.key] = not tracks[self.key] or nil
            Redraw()
        end)
        head:Hide()
        trackHeads[i] = head
    end
    canvas:SetScript("OnMouseWheel", function(self, delta)
        if not fight then return end
        local mx = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
        if IsShiftKeyDown() or mx < gutter then
            trackScroll = trackScroll - delta * 40
            Redraw()
            return
        end
        local left = self:GetLeft() + gutter
        local cx = (GetCursorPosition() / self:GetEffectiveScale() - left) / PlotWidth()
        cx = max(0, min(1, cx))
        local span = viewTo - viewFrom
        local anchor = viewFrom + span * cx
        local newSpan = max(1, min(tail - lead, span * (delta > 0 and 0.75 or 1.3333)))
        viewFrom = anchor - newSpan * cx
        viewTo = viewFrom + newSpan
        if viewFrom < lead then viewFrom = lead viewTo = viewFrom + newSpan end
        if viewTo > tail then viewTo = tail viewFrom = viewTo - newSpan end
        Redraw()
    end)
    canvas:SetScript("OnMouseDown", function(self)
        if not fight then return end
        dragging = true
        local cx, cy = GetCursorPosition()
        dragX = cx / self:GetEffectiveScale()
        dragY = cy / self:GetEffectiveScale()
        dragFrom = viewFrom
        dragScroll = trackScroll
    end)
    canvas:SetScript("OnMouseUp", function() dragging = false end)
    canvas:SetScript("OnUpdate", function(self)
        if resize then
            if not IsMouseButtonDown("LeftButton") then
                resize = nil
            else
                local y = GetCursorPosition() / self:GetEffectiveScale()
                local hh = max(resize.min, min(TRACKMAX, floor(resize.h + resize.y - y)))
                local ui = ns.GetDB().settings.ui
                if type(ui.trackH) ~= "table" then ui.trackH = {} end
                if ui.trackH[resize.key] ~= hh then
                    ui.trackH[resize.key] = hh
                    Redraw()
                end
            end
            return
        end
        if not fight then return end
        local cursor = GetCursorPosition() / self:GetEffectiveScale()
        if dragging then
            local span = viewTo - viewFrom
            local shift = (dragX - cursor) / PlotWidth() * span
            local nf = max(lead, min(tail - span, dragFrom + shift))
            local _, cy = GetCursorPosition()
            local ny = max(0, floor(dragScroll + cy / self:GetEffectiveScale() - dragY))
            if nf ~= viewFrom or ny ~= trackScroll then
                viewFrom = nf
                viewTo = nf + span
                trackScroll = ny
                Redraw()
            end
        end
        local x = cursor - self:GetLeft()
        if self:IsMouseOver() and x >= gutter and x <= self:GetWidth() then
            local t = viewFrom + (x - gutter) / PlotWidth() * (viewTo - viewFrom)
            cursorLine:ClearAllPoints()
            cursorLine:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
            cursorLine:SetHeight(self:GetHeight())
            cursorLine:Show()
            cursorLabel:SetText(ClockMs(t - fight.from))
            cursorBg:SetWidth(cursorLabel:GetStringWidth() + 8)
            cursorBg:SetHeight(cursorLabel:GetStringHeight() + 4)
            cursorBg:ClearAllPoints()
            cursorBg:SetPoint("TOPLEFT", overlay, "TOPLEFT", x + 2, -2)
            cursorBg:Show()
            cursorLabel:ClearAllPoints()
            cursorLabel:SetPoint("LEFT", cursorBg, "LEFT", 4, 0)
            cursorLabel:Show()
            ShowReadouts(t)
            if ns.MapView then ns.MapView.ShowAt(t, player) end
            local _, cy = GetCursorPosition()
            local top = self:GetTop()
            if rowGlow and top and lastBounds then
                local y = top - cy / self:GetEffectiveScale()
                local band = nil
                for i = 1, #lastBounds do
                    local bd = lastBounds[i]
                    if y >= bd.y and y < bd.y + bd.h then
                        local rowsTop = ContentTop(i, bd)
                        band = { y = bd.y, h = bd.h }
                        if TRACKS[i].rows and not TrackFolded(TRACKS[i].key)
                            and y >= rowsTop then
                            local slot = floor((y - rowsTop) / FXROW)
                            band = { y = rowsTop + slot * FXROW, h = FXROW - 1 }
                        end
                        break
                    end
                end
                if band and Band(band.y, band.h) then
                    rowGlow:ClearAllPoints()
                    rowGlow:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -band.y)
                    rowGlow:SetWidth(self:GetWidth())
                    rowGlow:SetHeight(band.h)
                    rowGlow:Show()
                else
                    rowGlow:Hide()
                end
            end
        else
            cursorLine:Hide()
            cursorBg:Hide()
            cursorLabel:Hide()
            if rowGlow then rowGlow:Hide() end
            HideReadouts()
        end
    end)
end
local function BuildTools()
    if ns.MakeButton then
        local fxBtn = ns.MakeButton(frame, "HTP_FailWatchFxToggle")
        fxBtn:SetWidth(104)
        fxBtn:SetHeight(20)
        fxBtn:SetPoint("TOPRIGHT", -MARGIN, -9)
        fxBtn.text:SetText(ns.T("tl.btn.fx"))
        fxBtn.onClick = function() TL.TogglePanel() end
        local mapBtn = ns.MakeButton(frame, "HTP_FailWatchMapToggle")
        mapBtn:SetWidth(84)
        mapBtn:SetHeight(20)
        mapBtn:SetPoint("RIGHT", fxBtn, "LEFT", -6, 0)
        mapBtn.text:SetText(ns.T("tl.btn.map"))
        mapBtn.onClick = function()
            if not ns.MapView then return end
            ns.MapView.Toggle()
            if fight then ns.MapView.SetFight(fight) end
        end
        local glueBtn = ns.MakeButton(frame, "HTP_FailWatchGlueToggle")
        glueBtn:SetWidth(104)
        glueBtn:SetHeight(20)
        glueBtn:SetPoint("RIGHT", mapBtn, "LEFT", -6, 0)
        glueBtn.text:SetText(ns.T(Glued() and "tl.btn.glue.on" or "tl.btn.glue.off"))
        glueBtn.onClick = function()
            local ui = ns.GetDB().settings.ui
            ui.glue = not Glued()
            glueBtn.text:SetText(ns.T(Glued() and "tl.btn.glue.on" or "tl.btn.glue.off"))
            if player then SelectPlayer(player) end
        end
        if ns.EffectPanel then ns.EffectPanel.BindTools(fxBtn, mapBtn, glueBtn) end
        if ns.ThreatView then ns.ThreatView.Button(frame, glueBtn) end
    end
    if ns.FxDrag then
        ns.FxDrag.SetTargets(TL.DropTargets)
        ns.FxDrag.SetHighlight(TL.HighlightDrop)
        ns.FxDrag.SetPhase(TL.SetDropMode)
    end
    BuildAuraRows()
    if ns.EffectPanel and ns.MakeRowButton then
        local fx = ns.EffectPanel.Attach(frame, EFFW)
        fx:SetPoint("TOPRIGHT", -MARGIN, -FXTOP)
        ns.EffectPanel.SetShown(not ns.GetDB().settings.ui.fxHidden)
    else
        panelMissing = true
        ns.Print(format(ns.T("tl.nofx"),
            not ns.EffectPanel and "ui/effects.lua" or "ui/widgets.lua"))
    end
end
function TL.Attach(host)
    BuildFrame(host)
    BuildCanvas()
    BuildTools()
    TL.Layout()
end
function TL.Redraw()
    BuildAuraRows()
    BuildAmountRows()
    Redraw()
end
function TL.DropTargets()
    return catHeads
end
function TL.SetDropMode(on)
    dropMode = on
end
function TL.HighlightDrop(cat)
    for i = 1, #catHeads do
        local target = catHeads[i]
        local tex = target.tex or target.frame.tex
        if target.cat == cat then
            ns.Kit.Paint(tex, "surface.dropOn")
        elseif target.row then
            ns.Kit.Paint(tex, "surface.dropRow")
        elseif target.sub then
            ns.Kit.Paint(tex, "surface.dropSub")
        else
            ns.Kit.Paint(tex, "surface.drop")
        end
    end
end
function TL.TogglePanel()
    if not (ns.EffectPanel and ns.MakeRowButton) then
        ns.Print(format(ns.T("tl.nofx"),
            not ns.EffectPanel and "ui/effects.lua" or "ui/widgets.lua"))
        return
    end
    local ui = ns.GetDB().settings.ui
    ui.fxHidden = not ui.fxHidden
    ns.EffectPanel.SetShown(not ui.fxHidden)
    TL.Layout()
end
function TL.Layout()
    if not frame then return end
    local p0 = ns.Prof.on and debugprofilestop()
    local w, h = frame:GetWidth(), frame:GetHeight()
    local shown = ns.EffectPanel and not panelMissing
        and not ns.GetDB().settings.ui.fxHidden
    local reserve = shown and (EFFW + GAP) or 0
    local plot = max(GUTTERMIN + PLOTMIN, w - MARGIN * 2 - SIDE - reserve)
    gutter = max(GUTTERMIN, min(GUTTERMAX, floor(plot * GUTTERSHARE)))
    nameW = gutter - 6
    ruler:SetWidth(plot)
    canvas:SetWidth(plot)
    canvas:SetHeight(max(THEAD * #TRACKS, h - HEADH - RULER - RULERGAP - FOOTH))
    canvas:GetParent():SetWidth(canvas:GetWidth())
    canvas:GetParent():SetHeight(canvas:GetHeight())
    detailAnchor:SetWidth(plot)
    if ns.FightList then ns.FightList.Layout(h - SIDETOP - SIDEBOT) end
    if shown then
        local p1 = ns.Prof.on and debugprofilestop()
        ns.EffectPanel.Layout(h - FXTOP - FXBOT)
        if p1 then ns.Prof.Add("fx.layout", debugprofilestop() - p1) end
    end
    TL.RefreshLists()
    if ns.RaidSummaryView and ns.RaidSummaryView.IsShown() then
        ns.RaidSummaryView.Relayout()
    elseif ns.SummaryView and ns.SummaryView.IsShown() then
        ns.SummaryView.Relayout()
    else
        Redraw()
    end
    if p0 then ns.Prof.Add("tl.layout", debugprofilestop() - p0) end
end
function TL.Opened()
    if not frame then return end
    if ns.Encounters.Ready() then
        TL.RefreshLists()
        if ns.RaidSummaryView then ns.RaidSummaryView.Land(fight) end
        if ns.Digest then ns.Digest.Refresh() end
        return
    end
    statusText:SetText(ns.T("tl.scanning"))
    ns.Encounters.Scan(function()
        statusText:SetText("")
        if not frame:IsVisible() then return end
        TL.RefreshLists()
        if ns.RaidSummaryView then ns.RaidSummaryView.Land(fight) end
        if ns.Digest then ns.Digest.Refresh() end
    end)
end
function TL.ShowRaid(raid)
    if not frame or not raid or not ns.RaidSummaryView then return end
    fight, player, data = nil, nil, nil
    if ns.ThreatView then ns.ThreatView.Hide() end
    if ns.SummaryView then ns.SummaryView.Hide() end
    if ns.EffectPanel then ns.EffectPanel.SetTimeline(false) end
    ReleaseAll()
    ruler:Hide()
    canvas:GetParent():Hide()
    statusText:SetText("")
    titleText:SetText(ns.RaidSummaryView.Title(raid))
    ns.RaidSummaryView.Show(raid)
    TL.RefreshLists()
end
function TL.SelectPlayer(name)
    if fight and fight.players[name] then SelectPlayer(name) end
end
function TL.View()
    return fight, player, viewFrom, viewTo, lead, tail
end
function TL.SetView(from, to)
    if not fight or to <= from then return end
    viewFrom, viewTo = from, to
    Redraw()
end
function TL.XOf(t)
    return XOf(t)
end
function TL.Overlay()
    return overlay
end
function TL.ShowFight(f)
    if frame and f then SelectFight(f) end
end
function TL.ShowForeign(f)
    if not (frame and f and f.foreign and ns.SummaryView) then return end
    fight, player, data = nil, nil, nil
    if ns.ThreatView then ns.ThreatView.Hide() end
    if ns.RaidSummaryView then ns.RaidSummaryView.Hide() end
    if ns.EffectPanel then ns.EffectPanel.SetTimeline(false) end
    ReleaseAll()
    ruler:Hide()
    canvas:GetParent():Hide()
    statusText:SetText("")
    titleText:SetText(format(ns.T("share.title"), f.foreign.inner, f.foreign.who))
    TL.RefreshLists()
    ns.SummaryView.Show(f)
end
