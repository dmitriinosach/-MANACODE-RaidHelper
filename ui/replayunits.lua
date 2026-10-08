local _, ns = ...
local floor = math.floor
local max = math.max
local tostring = tostring
local format = string.format
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GAP = 1
local BAR_H = 2
local BIG_H = 5
local BAR_K = 0.8
local BIG_W = 34
local MIN_W = 10
local Q = 100
local PCT_SIZE = 9
local BADGE_MIN = 11
local BADGE_K = 0.6
local ICON_K = 0.66
local CB_W = 72
local CB_H = 10
local IN_K = 0.8
local IN_RISE = 0.5
local IN_Q = 20
local V = { stats = { mana = 0, casts = 0, inst = 0 } }
ns.ReplayUnitsView = V
local Kit = ns.Kit
local RU = ns.ReplayUnits
local Figs = ns.ReplayFigs
local st = { data = nil, focus = nil }
local pctFont
local function PctFont()
    if pctFont then return pctFont end
    pctFont = CreateFont("HTP_FailWatchUnitPct")
    pctFont:SetFontObject(GameFontHighlightSmall)
    local path = GameFontHighlightSmall:GetFont()
    if path then pctFont:SetFont(path, PCT_SIZE, "OUTLINE") end
    return pctFont
end
local function EnsureMana(fig)
    if fig.mpBg then return end
    fig.mpBg = fig:CreateTexture(nil, "ARTWORK")
    fig.mpBg:SetTexture(WHITE)
    Kit.Hue(fig.mpBg, "sem.rep.manaBg")
    fig.mpBg:Hide()
    fig.mpFill = fig:CreateTexture(nil, "OVERLAY")
    fig.mpFill:SetTexture(WHITE)
    Kit.Hue(fig.mpFill, "sem.rep.mana")
    fig.mpFill:SetPoint("TOPLEFT", fig.mpBg, "TOPLEFT", 0, 0)
    fig.mpFill:SetPoint("BOTTOMLEFT", fig.mpBg, "BOTTOMLEFT", 0, 0)
    fig.mpFill:Hide()
end
local function EnsureBadge(fig)
    if fig.csIcon then return end
    fig.csIcon = fig:CreateTexture(nil, "ARTWORK")
    fig.csIcon:Hide()
    fig.csRing = fig:CreateTexture(nil, "OVERLAY")
    fig.csArcOk = fig.csRing:SetTexture(Figs.ARC_TEX) and true or false
    fig.csRing:Hide()
end
local function HideMana(fig)
    if not fig.mpOn then return end
    fig.mpOn, fig.mpKey, fig.mpQ = false, nil, nil
    fig.mpBg:Hide()
    fig.mpFill:Hide()
    if fig.mpPct then fig.mpPct:Hide() end
end
function V.Use(scene)
    st.data = scene and (scene.units or (scene.base and scene.base.units)) or nil
end
function V.Focus(name)
    st.focus = name
end
local function Pct(fig)
    if fig.mpPct then return fig.mpPct end
    local fs = fig:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(PctFont())
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, "sem.rep.mana")
    fig.mpPct = fs
    return fs
end
local function PutMana(fig, v, big)
    EnsureMana(fig)
    local w = big and max(BIG_W, fig.uw or 0) or max(MIN_W, (fig.uw or 0) * BAR_K)
    local h = big and BIG_H or BAR_H
    local key = floor(fig.under + 0.5) * 4096 + floor(w + 0.5) * 2 + (big and 1 or 0)
    if fig.mpKey ~= key then
        fig.mpKey, fig.mpQ = key, nil
        local bg = fig.mpBg
        bg:ClearAllPoints()
        bg:SetWidth(w)
        bg:SetHeight(h)
        bg:SetPoint("TOP", fig, "CENTER", 0, fig.under - GAP)
        fig.mpW = w
        if big then
            local fs = Pct(fig)
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", bg, "RIGHT", 2, 0)
        end
    end
    local q = floor(v * Q + 0.5)
    if fig.mpQ ~= q then
        fig.mpQ = q
        fig.mpFill:SetWidth(max(0.01, fig.mpW * q / Q))
        if big then
            fig.mpTxt = tostring(q) .. "%"
            Pct(fig):SetText(fig.mpTxt)
        end
    end
    if not fig.mpOn then
        fig.mpOn = true
        fig.mpBg:Show()
    end
    if q > 0 then fig.mpFill:Show() else fig.mpFill:Hide() end
    if fig.mpPct then
        if big then fig.mpPct:Show() else fig.mpPct:Hide() end
    end
end
local function Bar(fig, layer, token)
    local tex = fig:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    Kit.Hue(tex, token)
    tex:Hide()
    return tex
end
local function Label(fig, justify)
    local fs = fig:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(PctFont())
    fs:SetJustifyH(justify)
    Kit.Text(fs, "sem.rep.castText")
    fs:Hide()
    return fs
end
local function EnsureBar(fig)
    if fig.cbBg then return end
    fig.cbBg = Bar(fig, "ARTWORK", "sem.rep.castBg")
    fig.cbBg:SetWidth(CB_W)
    fig.cbBg:SetHeight(CB_H)
    fig.cbFill = Bar(fig, "OVERLAY", "sem.rep.cast")
    fig.cbFill:SetPoint("TOPLEFT", fig.cbBg, "TOPLEFT", 0, 0)
    fig.cbFill:SetPoint("BOTTOMLEFT", fig.cbBg, "BOTTOMLEFT", 0, 0)
    fig.cbIcon = fig:CreateTexture(nil, "ARTWORK")
    fig.cbIcon:SetWidth(CB_H)
    fig.cbIcon:SetHeight(CB_H)
    fig.cbIcon:SetPoint("RIGHT", fig.cbBg, "LEFT", -1, 0)
    fig.cbIcon:Hide()
    fig.cbTime = Label(fig, "LEFT")
    fig.cbTime:SetPoint("LEFT", fig.cbBg, "RIGHT", 2, 0)
    fig.cbName = Label(fig, "CENTER")
    fig.cbName:SetPoint("TOP", fig.cbBg, "BOTTOM", 0, -1)
end
local function HideBar(fig)
    if not fig.cbOn then return end
    fig.cbOn, fig.cbRec, fig.cbY, fig.cbTok, fig.cbQ, fig.cbT = false, nil, nil, nil, nil, nil
    fig.cbBg:Hide()
    fig.cbFill:Hide()
    fig.cbIcon:Hide()
    fig.cbTime:Hide()
    fig.cbName:Hide()
end
local function HideCast(fig)
    HideBar(fig)
    if not fig.csOn then return end
    fig.csOn, fig.csRec, fig.csKey, fig.csTok, fig.csArc = false, nil, nil, nil, nil
    fig.csIcon:Hide()
    fig.csRing:Hide()
end
local function ToneOf(rec, t)
    if rec.cut and t >= rec.stop then return "sem.rep.castCut" end
    return rec.chan and "sem.rep.castChan" or "sem.rep.cast"
end
local function PutBadge(fig, rec, p, tok)
    EnsureBadge(fig)
    local uw = fig.uw or 0
    local key = floor((fig.hy or 0) + 0.5) * 4096 + floor(uw + 0.5)
    if fig.csKey ~= key then
        fig.csKey = key
        local d = max(BADGE_MIN, uw * BADGE_K)
        local x, y = uw / 2 + d / 2, fig.hy or 0
        local ring, icon = fig.csRing, fig.csIcon
        ring:ClearAllPoints()
        ring:SetWidth(d)
        ring:SetHeight(d)
        ring:SetPoint("CENTER", fig, "CENTER", x, y)
        icon:ClearAllPoints()
        icon:SetWidth(d * ICON_K)
        icon:SetHeight(d * ICON_K)
        icon:SetPoint("CENTER", fig, "CENTER", x, y)
    end
    if fig.csRec ~= rec then
        fig.csRec = rec
        Kit.Icon.Spell(fig.csIcon, rec.id)
    end
    if fig.csTok ~= tok then
        fig.csTok = tok
        Kit.Hue(fig.csRing, tok)
    end
    local arc = Figs.ARC_N
    if tok ~= "sem.rep.castCut" then arc = Figs.ArcOf(rec.chan and 1 - p or p) end
    if fig.csArc ~= arc then
        fig.csArc = arc
        Figs.ArcFrame(fig.csRing, arc)
    end
    if not fig.csOn then
        fig.csOn = true
        fig.csIcon:Show()
        if fig.csArcOk then fig.csRing:Show() end
    end
end
local function PutBar(fig, rec, p, left, tok)
    EnsureBar(fig)
    local y = fig.under - GAP - (fig.mpOn and (BIG_H + GAP) or 0)
    if fig.cbY ~= y then
        fig.cbY = y
        fig.cbBg:ClearAllPoints()
        fig.cbBg:SetPoint("TOP", fig, "CENTER", CB_H / 2, y)
    end
    if fig.cbRec ~= rec then
        fig.cbRec = rec
        Kit.Icon.Spell(fig.cbIcon, rec.id)
        fig.cbName:SetText(rec.id and GetSpellInfo(rec.id) or "")
    end
    if fig.cbTok ~= tok then
        fig.cbTok, fig.cbT = tok, nil
        Kit.Hue(fig.cbFill, tok)
    end
    local cut = tok == "sem.rep.castCut"
    local share = cut and 1 or (rec.chan and 1 - p or p)
    local q = floor(share * CB_W + 0.5)
    if fig.cbQ ~= q then
        fig.cbQ = q
        fig.cbFill:SetWidth(max(0.01, q))
    end
    local tt = cut and -1 or floor(left * 10)
    if fig.cbT ~= tt then
        fig.cbT = tt
        fig.cbTxt = cut and ns.T("iso.cast.cut") or format(ns.T("iso.cast.left"), tt / 10)
        fig.cbTime:SetText(fig.cbTxt)
    end
    if not fig.cbOn then
        fig.cbOn = true
        fig.cbBg:Show()
        fig.cbIcon:Show()
        fig.cbTime:Show()
        fig.cbName:Show()
    end
    if q > 0 then fig.cbFill:Show() else fig.cbFill:Hide() end
end
local function PlaceCast(fig, cs, t, focus)
    local rec, p, left = RU.CastAt(cs, t)
    if not rec then
        HideCast(fig)
        return false
    end
    local tok = ToneOf(rec, t)
    PutBadge(fig, rec, p, tok)
    if focus then PutBar(fig, rec, p, left, tok) else HideBar(fig) end
    return true
end
local function EnsureInst(fig)
    if fig.inTex then return end
    local list = {}
    for k = 1, RU.INST_MAX do
        local tex = fig:CreateTexture(nil, "ARTWORK")
        tex:Hide()
        list[k] = tex
    end
    fig.inTex, fig.inN, fig.inPos, fig.inId, fig.inA = list, 0, {}, {}, {}
end
local function HideInstBar(fig)
    if not fig.ibOn then return end
    fig.ibOn, fig.ibAt, fig.ibA = false, nil, nil
    fig.ibIcon:Hide()
    fig.ibName:Hide()
end
local function HideInst(fig)
    HideInstBar(fig)
    local n = fig.inN or 0
    if n == 0 then return end
    for k = 1, n do
        fig.inTex[k]:Hide()
        fig.inA[k] = nil
    end
    fig.inN = 0
end
local function AlphaQ(a)
    return floor(a * IN_Q + 0.5)
end
local function PutInstBar(fig, id, a)
    if not fig.ibIcon then
        fig.ibIcon = fig:CreateTexture(nil, "ARTWORK")
        fig.ibIcon:SetWidth(CB_H)
        fig.ibIcon:SetHeight(CB_H)
        fig.ibName = Label(fig, "LEFT")
        fig.ibName:SetPoint("LEFT", fig.ibIcon, "RIGHT", 2, 0)
    end
    local at
    if fig.cbOn then
        at = "after"
    else
        at = tostring(fig.under - GAP - (fig.mpOn and (BIG_H + GAP) or 0))
    end
    if fig.ibAt ~= at then
        fig.ibAt = at
        fig.ibIcon:ClearAllPoints()
        if fig.cbOn then
            fig.ibIcon:SetPoint("LEFT", fig.cbTime, "RIGHT", 3, 0)
        else
            fig.ibIcon:SetPoint("TOPRIGHT", fig, "CENTER", CB_H / 2 - CB_W / 2 - 1, tonumber(at))
        end
    end
    if fig.ibId ~= id then
        fig.ibId = id
        Kit.Icon.Spell(fig.ibIcon, id)
        fig.ibTxt = GetSpellInfo(id) or ""
        fig.ibName:SetText(fig.ibTxt)
    end
    local q = AlphaQ(a)
    if fig.ibA ~= q then
        fig.ibA = q
        fig.ibIcon:SetAlpha(q / IN_Q)
        fig.ibName:SetAlpha(q / IN_Q)
    end
    if not fig.ibOn then
        fig.ibOn = true
        fig.ibIcon:Show()
        fig.ibName:Show()
    end
end
local function PlaceInst(fig, ins, t, focus)
    local j, n = RU.InstAt(ins, t)
    if n == 0 then
        HideInst(fig)
        return false
    end
    EnsureInst(fig)
    local uw = fig.uw or 0
    local s = floor(max(BADGE_MIN, uw * BADGE_K) * IN_K + 0.5)
    if fig.inS ~= s then
        fig.inS = s
        for k = 1, RU.INST_MAX do
            fig.inTex[k]:SetWidth(s)
            fig.inTex[k]:SetHeight(s)
            fig.inPos[k] = nil
        end
    end
    local life = RU.INST_LIFE
    for k = 1, n do
        local idx = j - k + 1
        local age = t - ins.T[idx]
        local tex = fig.inTex[k]
        local x = floor(-(uw / 2 + s / 2 + 1 + (k - 1) * (s + 1)) + 0.5)
        local y = floor((fig.hy or 0) + IN_RISE * s * age / life + 0.5)
        local pos = x * 65536 + y
        if fig.inPos[k] ~= pos then
            fig.inPos[k] = pos
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", fig, "CENTER", x, y)
        end
        local id = ins.R[idx]
        if fig.inId[k] ~= id then
            fig.inId[k] = id
            Kit.Icon.Spell(tex, id)
        end
        local q = AlphaQ(RU.InstAlpha(age))
        if fig.inA[k] ~= q then
            if not fig.inA[k] then tex:Show() end
            fig.inA[k] = q
            tex:SetAlpha(q / IN_Q)
        end
    end
    for k = n + 1, fig.inN do
        fig.inTex[k]:Hide()
        fig.inA[k] = nil
    end
    fig.inN = n
    if focus then
        PutInstBar(fig, ins.R[j], RU.InstAlpha(t - ins.T[j]))
    else
        HideInstBar(fig)
    end
    return true
end
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function V.CastsAll()
    return Saved().castsAll == true
end
function V.SetCastsAll(on)
    Saved().castsAll = on and true or false
end
function V.Place(scene, t, figs, n)
    local data = st.data
    local all = V.CastsAll()
    local shown, casting, inst = 0, 0, 0
    for k = 1, n do
        local fig = figs[k]
        local s = scene.states[k]
        local alive = data and fig.shown and fig.under and not (s and s.dead)
        local m = alive and data.mana[fig.name]
        local v = m and RU.ManaAt(m, t)
        local focus = fig.name == st.focus
        if v then
            PutMana(fig, v, focus)
            shown = shown + 1
        else
            HideMana(fig)
        end
        local cs = alive and (all or focus) and data.casts[fig.name]
        if cs and PlaceCast(fig, cs, t, focus) then
            casting = casting + 1
        elseif fig.csOn or fig.cbOn then
            HideCast(fig)
        end
        local ins = alive and (all or focus) and data.inst and data.inst[fig.name]
        if ins and PlaceInst(fig, ins, t, focus) then
            inst = inst + 1
        elseif (fig.inN or 0) > 0 or fig.ibOn then
            HideInst(fig)
        end
    end
    V.stats.mana, V.stats.casts, V.stats.inst = shown, casting, inst
end
function V.Probe(fig)
    return { mana = fig.mpOn and fig.mpQ or nil, big = fig.mpPct ~= nil and fig.mpPct:IsShown() or false,
             w = fig.mpOn and fig.mpW or nil, pct = fig.mpTxt,
             cast = fig.csOn and fig.csRec or nil, arc = fig.csOn and fig.csArc or nil, tone = fig.csOn and fig.csTok or nil,
             ring = fig.csOn and fig.csArcOk or false, bar = fig.cbOn and fig.cbQ or nil, left = fig.cbOn and fig.cbTxt or nil,
             inst = fig.inN or 0, instA = (fig.inN or 0) > 0 and fig.inA[1] / IN_Q or nil,
             instId = (fig.inN or 0) > 0 and fig.inId[1] or nil, instPos = fig.inPos and fig.inPos[1] or nil,
             instBar = fig.ibOn and fig.ibTxt or nil, instAt = fig.ibOn and fig.ibAt or nil }
end
