local ADDON, ns = ...
local format = string.format
local floor = math.floor
local SPAN = 5
local LAST = 4
local TOTAL = 4
local V = { stats = { shown = 0 } }
ns.ReplayTombView = V
local Kit = ns.Kit
local T = ns.T
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\ring256"
local BAR_H = 4
local GAP = 2
local MK = 14
local MK_ICON = 0.66
local MK_RING = 1.25
local tip = { i = -1, sec = -1, dead = false, rule = false }
local HOLD = 5
local function TombOf(scene, fig, k, t, hold)
    if not (fig and fig.shown) then return nil end
    local tb = ns.ReplayTomb.At(scene.layers, k, t, hold and HOLD or nil)
    if tb and t <= tb.to and not (fig.domeOn and fig.domeLook == "tomb") then return nil end
    return tb
end
local function Build(fig)
    local bg = fig:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(WHITE)
    Kit.Tint(bg, "sem.rep.castBg")
    bg:SetHeight(BAR_H)
    bg:Hide()
    local fill = fig:CreateTexture(nil, "OVERLAY")
    fill:SetTexture(WHITE)
    Kit.Tint(fill, "sem.rep.addHp")
    fill:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)
    fill:Hide()
    local fs = fig:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(ns.ReplayFigs.PctFont())
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    Kit.Text(fs, "sem.rep.pct")
    fs:SetPoint("LEFT", bg, "RIGHT", GAP, 0)
    fs:Hide()
    fig.tbBg, fig.tbFill, fig.tbFs = bg, fill, fs
end
local function BuildMark(fig)
    local disc = fig:CreateTexture(nil, "BORDER")
    disc:SetTexture(CIRCLE)
    Kit.Tint(disc, "sem.rep.castBg")
    disc:SetWidth(MK)
    disc:SetHeight(MK)
    disc:SetPoint("RIGHT", fig.tbBg, "LEFT", -GAP, 0)
    disc:Hide()
    local icon = fig:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(MK * MK_ICON)
    icon:SetHeight(MK * MK_ICON)
    icon:SetPoint("CENTER", disc, "CENTER", 0, 0)
    icon:Hide()
    local rim = fig:CreateTexture(nil, "OVERLAY")
    rim:SetTexture(RING)
    Kit.Tint(rim, "sem.rep.valkyr")
    rim:SetWidth(MK * MK_RING)
    rim:SetHeight(MK * MK_RING)
    rim:SetPoint("CENTER", disc, "CENTER", 0, 0)
    rim:Hide()
    fig.tbMkBg, fig.tbMk, fig.tbMkRim = disc, icon, rim
end
local function ShowMark(fig, on)
    on = on and fig.tbMark and true or false
    if (fig.tbMkOn or false) == on then return end
    fig.tbMkOn = on
    if on then
        fig.tbMkBg:Show()
        fig.tbMk:Show()
        fig.tbMkRim:Show()
    elseif fig.tbMkBg then
        fig.tbMkBg:Hide()
        fig.tbMk:Hide()
        fig.tbMkRim:Hide()
    end
end
function V.Want(scene, fig, k, t)
    if k == 1 then V.stats.shown = 0 end
    local L = scene.layers
    local tb = L and L.tombOf and TombOf(scene, fig, k, t)
    local carrier = not tb and L and L.carryOf and ns.ReplayLayers.CarriedBy(L, k, t)
    if not (tb or carrier) then return false end
    if not fig.tbBg then Build(fig) end
    local frac
    if tb then
        frac = select(2, ns.ReplayTomb.Hp(tb, t))
    else
        frac = ns.ReplayLayers.AddHp(carrier, t) or 1
    end
    local mark = carrier and carrier.icon or false
    if mark and not fig.tbMkBg then BuildMark(fig) end
    if fig.tbMark ~= mark then
        fig.tbMark, fig.tbY = mark, nil
        if mark then
            if type(mark) == "number" then Kit.Icon.Spell(fig.tbMk, mark) else
                fig.tbMk:SetTexture(mark)
                fig.tbMk:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            end
        end
    end
    local p = floor(frac * 100 + 0.5)
    local w = fig.uw or 0
    if fig.tbP ~= p then
        fig.tbP, fig.tbTxt = p, p .. "%"
        fig.tbFs:SetText(fig.tbTxt)
    end
    if fig.tbBarW ~= w then
        fig.tbBarW = w
        fig.tbBg:SetWidth(math.max(1, w))
    end
    local fw = w * frac
    if fig.tbFillW ~= fw then
        fig.tbFillW = fw
        fig.tbFill:SetWidth(math.max(0.01, fw))
    end
    fig.tbW = (mark and MK + GAP or 0) + w + GAP + (fig.tbFs:GetStringWidth() or 0)
    fig.tbH = math.max(BAR_H, ns.ReplayFigs.PCT_H, mark and MK or 0)
    V.stats.shown = V.stats.shown + 1
    return true
end
function V.Show(fig, on, y)
    on = on and fig.tbBg ~= nil
    if on and fig.tbY ~= y then
        fig.tbY = y
        fig.tbBg:ClearAllPoints()
        local x = -(fig.tbBarW or 0) / 2 + (fig.tbMark and MK + GAP or 0)
        fig.tbBg:SetPoint("BOTTOMLEFT", fig, "CENTER", x, y + ((fig.tbH or BAR_H) - BAR_H) / 2)
    end
    ShowMark(fig, on or false)
    if (fig.tbOn or false) == (on or false) then
        if on then
            local fill = (fig.tbFillW or 0) > 0.5
            if fill ~= fig.tbFill:IsShown() then
                if fill then fig.tbFill:Show() else fig.tbFill:Hide() end
            end
        end
        return
    end
    fig.tbOn = on or false
    if on then
        fig.tbBg:Show()
        fig.tbFs:Show()
        if (fig.tbFillW or 0) > 0.5 then fig.tbFill:Show() end
    elseif fig.tbBg then
        fig.tbBg:Hide()
        fig.tbFill:Hide()
        fig.tbFs:Hide()
    end
end
local function ClassOf(scene, name)
    local k = ns.Replay.ByK(scene)[name]
    return k and scene.tracks[k].class or nil
end
local function SpellText(id)
    return id == 0 and T("sum.ab.melee") or ns.SpellName(id)
end
local function HowText(r)
    if r.how == "aoe" then return format(T("rep.tomb.aoe"), r.top and SpellText(r.top) or "") end
    return r.how == "dot" and T("rep.tomb.dot") or T("rep.tomb.aim")
end
local function TotalText(rows)
    local parts = {}
    for i = 1, math.min(#rows, TOTAL) do parts[i] = rows[i].who .. " " .. ns.Short(rows[i].sum) end
    if #rows > TOTAL then parts[#parts + 1] = format(T("rep.tomb.rest"), #rows - TOTAL) end
    return format(T("rep.tomb.total"), table.concat(parts, ", "))
end
function V.Lines(scene, tb, t)
    local RT = ns.ReplayTomb
    local fight = scene.fight
    local def = ns.replayTomb[fight.boss]
    local head = tb.who and format(T("rep.tomb.head"), tb.name, tb.who) or tb.name
    local out = { { kind = "head", left = head, right = RT.Label(tb, t) } }
    local age, rate, eta, broken = RT.State(tb, t, SPAN)
    local state
    if broken then
        state = format(T("rep.tomb.broken"), ns.Clock(age))
    elseif eta then
        state = format(T("rep.tomb.eta"), ns.Clock(age), ns.Short(rate), floor(eta + 0.5))
    else
        state = format(T("rep.tomb.age"), ns.Clock(age))
    end
    out[#out + 1] = { kind = "note", left = state }
    local last = RT.Who(tb, t, SPAN)
    if #last > 0 then
        out[#out + 1] = { kind = "sub", left = format(T("rep.tomb.last"), SPAN), tone = "dim" }
        for i = 1, math.min(#last, LAST) do
            local r = last[i]
            out[#out + 1] = { kind = "row", left = r.who, class = ClassOf(scene, r.who), mid = ns.Short(r.sum),
                              right = HowText(r), tone = "dim" }
        end
    end
    local all = RT.Who(tb, t, nil)
    if #all > 0 then out[#out + 1] = { kind = "text", left = TotalText(all) } end
    if broken and tb.killer then
        out[#out + 1] = { kind = "row", left = T("rep.tomb.kill"),
                          right = format(T("rep.tomb.row"), tb.killer, SpellText(tb.killId or 0)) }
    end
    local rule = broken and RT.Rule(fight, tb)
    local penalty = rule and next(rule) and ns.Penalties.For(def.limit, fight)
    if penalty then
        local names = {}
        for who in pairs(rule) do names[#names + 1] = who end
        table.sort(names)
        for i = 1, #names do
            out[#out + 1] = { kind = "text", tone = "bad", left = format(T("rep.tomb.rule"), ns.Penalties.Reason(penalty),
                names[i], ns.Dec(format("%.1f", rule[names[i]]))) }
        end
    end
    return out
end
function V.Hover(scene, fig, k, t)
    local tb = scene and k and k <= #scene.tracks and TombOf(scene, fig, k, t, true) or nil
    if not tb then
        if tip.fig then
            tip.fig, tip.tb, tip.lines = nil, nil, nil
            Kit.Tip.Hide()
        end
        return
    end
    local i = ns.ReplayTomb.Index(tb, t)
    local sec = floor(t - tb.from)
    local dead = tb.died ~= nil and t >= tb.died
    local rule = tb.rule ~= nil
    if tip.fig == fig and tip.tb == tb and tip.i == i and tip.sec == sec and tip.dead == dead and tip.rule == rule then
        return
    end
    tip.fig, tip.tb, tip.i, tip.sec, tip.dead = fig, tb, i, sec, dead
    tip.lines = V.Lines(scene, tb, t)
    tip.rule = tb.rule ~= nil
    Kit.Tip.ShowRight(fig, tip.lines)
end
function V.Probe(fig)
    return { pct = fig and fig.tbOn and fig.tbTxt or nil, barW = fig and fig.tbOn and fig.tbBarW or nil,
             fillW = fig and fig.tbOn and fig.tbFillW or nil, y = fig and fig.tbOn and fig.tbY or nil,
             shown = V.stats.shown, lines = tip.lines, owner = tip.fig }
end
