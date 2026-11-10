local _, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local tostring = tostring
local format = string.format
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GAP = 1
local Q = 100
local NICK_PT = 9
local FOCUS_PT = 12
local PCT_PT = 10
local TIME_PT = 7
local TARGET_PT = 7
local FOCUS_TARGET_PT = 8
local BAR_H = 3
local BIG_H = 8
local BAR_K = 1.15
local BIG_W = 40
local MIN_W = 10
local CB_H = 8
local CB_TXT_EM = 2
local CB_ROW_K = 1.15
local SPELL_PT = 6
local FOCUS_SPELL_PT = 7
local CB_BG_A = 0.35
local ZOOM_K = 1.6
local SIZE_MIN, SIZE_MAX, SIZE_STEP, SIZE_DEFAULT = 80, 160, 10, 100
local K_Q = 20
local ROLE_GAP = 2
local ROLE_PAD = 3
local NICK_W = 2.6
local NICK_FOCUS_W = 4
local NICK_MIN = 18
local NICK_GAP = 1
local PAD = 1
local NICK_TRIES = 3
local PARTS = { 6, 1, 2, 3, 4, 5 }
local FONT_PREFIX = "HTP_FailWatchRepLabel"
local V = { stats = { mana = 0, casts = 0, rage = 0, hidden = 0 } }
ns.ReplayUnitsView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local RU = ns.ReplayUnits
local st = { data = nil, focus = nil, k = 1, gen = 0, hw = math.huge, hh = math.huge }
local RX1, RX2, RY1, RY2, RO, RK = {}, {}, {}, {}, {}, {}
local nRect = 0
local order = {}
local fonts = {}
local function Face(f, size)
    local base = Kit.FontFor("GameFontHighlightSmall", true) or GameFontHighlightSmall
    f:SetFontObject(base)
    local path = base:GetFont()
    if path then f:SetFont(path, size, "OUTLINE") end
end
local function FontOf(pt)
    local size = max(6, floor((pt + Kit.FontDelta()) * st.k + 0.5))
    local f = fonts[size]
    if not f then
        f = CreateFont(FONT_PREFIX .. size)
        Face(f, size)
        fonts[size] = f
    end
    return f, size
end
Kit.OnFont(function()
    for size, f in pairs(fonts) do Face(f, size) end
    st.gen = st.gen + 1
end)
local function Px(v)
    return floor(v * st.k + 0.5)
end
local Saved = RD.Saved
function V.Size()
    local v = tonumber(Saved().labelSize) or SIZE_DEFAULT
    if v < SIZE_MIN then v = SIZE_MIN elseif v > SIZE_MAX then v = SIZE_MAX end
    return v, SIZE_MIN, SIZE_MAX, SIZE_STEP
end
function V.SetSize(v)
    v = floor((tonumber(v) or SIZE_DEFAULT) / SIZE_STEP + 0.5) * SIZE_STEP
    if v < SIZE_MIN then v = SIZE_MIN elseif v > SIZE_MAX then v = SIZE_MAX end
    Saved().labelSize = v ~= SIZE_DEFAULT and v or nil
end
function V.Scale(zoom)
    local z = sqrt(max(0, zoom or 1))
    if z < 1 then z = 1 elseif z > ZOOM_K then z = ZOOM_K end
    return floor(z * V.Size() / SIZE_DEFAULT * K_Q + 0.5) / K_Q
end
local function Sized(fs, pt, key, fig)
    local f, size = FontOf(pt)
    if fig[key] ~= size then
        fig[key] = size
        fs:SetFontObject(f)
    end
    return size
end
local function Vis(region, on)
    if on then region:Show() else region:Hide() end
end
local function RoleOf(fig)
    local role = fig.role
    if role == "tank" or role == "heal" then return role end
    return nil
end
local function PrepNick(fig, big)
    local fs = fig.nkFs
    if not fs then
        fs = fig:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        fs:Hide()
        fig.nkFs = fs
        fig.nkRole = fig:CreateTexture(nil, "OVERLAY")
        fig.nkRole:Hide()
    end
    local size = Sized(fs, big and FOCUS_PT or NICK_PT, "nkSize", fig)
    local role = RoleOf(fig)
    local y = floor((fig.top or 0) + ns.ReplayLayersView.BadgesUp(fig) + NICK_GAP + 0.5)
    local w = floor(max(NICK_MIN * st.k, (fig.uw or 0) * (big and NICK_FOCUS_W or NICK_W)) + 0.5)
    if fig.nkName ~= fig.name or fig.nkS ~= size or fig.nkWide ~= w or fig.nkBig ~= big or fig.nkRoleOn ~= role
        or fig.nkGen ~= st.gen then
        fig.nkName, fig.nkS, fig.nkWide, fig.nkBig, fig.nkGen, fig.nkY = fig.name, size, w, big, st.gen, nil
        fig.nkTxt = fig.name or ""
        Kit.Text(fs, big and "sem.rep.focusText" or "sem.rep.nick")
        local icon = role and size + ROLE_PAD or 0
        fig.nkH = max(size, icon)
        local room = w - (role and icon + ROLE_GAP or 0)
        fs:SetWidth(room)
        fs:SetText(fig.nkTxt)
        fig.nkW = room
        local text = min(room, fs:GetStringWidth() or room)
        fig.nkTW = text + (role and icon + ROLE_GAP or 0)
        fig.nkShift = role and (icon + ROLE_GAP) / 2 or 0
        local tex = fig.nkRole
        if role then
            Kit.Icon.RoleBig(tex, role)
            tex:SetWidth(icon)
            tex:SetHeight(icon)
            tex:ClearAllPoints()
            tex:SetPoint("RIGHT", fs, "CENTER", -text / 2 - ROLE_GAP, 0)
        end
        fig.nkRoleOn = role
    end
    if fig.nkY ~= y then
        fig.nkY, fig.nkLift = y, 0
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOM", fig, "CENTER", fig.nkShift, y)
    end
    return y, size
end
local function ShowNick(fig, on)
    if (fig.nkOn or false) == on then return end
    fig.nkOn = on
    Vis(fig.nkFs, on)
    Vis(fig.nkRole, on and fig.nkRoleOn ~= nil)
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
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, fig.mpTok or "sem.rep.mana")
    fs:Hide()
    fig.mpPct = fs
    return fs
end
local function EnsureMana(fig, token)
    if not fig.mpBg then
        fig.mpBg = fig:CreateTexture(nil, "ARTWORK")
        fig.mpBg:SetTexture(WHITE)
        Kit.Tint(fig.mpBg, "sem.rep.manaBg")
        fig.mpBg:Hide()
        fig.mpFill = fig:CreateTexture(nil, "OVERLAY")
        fig.mpFill:SetTexture(WHITE)
        fig.mpFill:SetPoint("TOPLEFT", fig.mpBg, "TOPLEFT", 0, 0)
        fig.mpFill:SetPoint("BOTTOMLEFT", fig.mpBg, "BOTTOMLEFT", 0, 0)
        fig.mpFill:Hide()
    end
    if fig.mpTok ~= token then
        fig.mpTok = token
        Kit.Tint(fig.mpFill, token)
        if fig.mpPct then Kit.Text(fig.mpPct, token) end
    end
end
local function PrepMana(fig, v, big, token)
    EnsureMana(fig, token)
    local w = max(big and Px(BIG_W) or MIN_W, (fig.uw or 0) * BAR_K)
    local h = max(1, Px(big and BIG_H or BAR_H))
    local size = big and Sized(Pct(fig), PCT_PT, "mpSize", fig) or 0
    local key = ((floor(fig.under + 0.5) * 4096 + floor(w + 0.5)) * 64 + h) * 64 + size
    if fig.mpKey ~= key or fig.mpGen ~= st.gen then
        fig.mpKey, fig.mpGen, fig.mpQ = key, st.gen, nil
        local bg = fig.mpBg
        bg:ClearAllPoints()
        bg:SetWidth(w)
        bg:SetHeight(h)
        bg:SetPoint("TOP", fig, "CENTER", 0, fig.under - GAP)
        fig.mpW, fig.mpH = w, h
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
            local text = tostring(q) .. "%"
            if fig.mpTxt ~= text then
                fig.mpTxt = text
                Pct(fig):SetText(text)
            end
        end
    end
    fig.mpBigNow = big
    return h
end
local function ShowMana(fig, on)
    if not fig.mpBg then return end
    if (fig.mpOn or false) ~= on then
        fig.mpOn = on
        Vis(fig.mpBg, on)
    end
    local fill = on and (fig.mpQ or 0) > 0
    if (fig.mpFillOn or false) ~= fill then
        fig.mpFillOn = fill
        Vis(fig.mpFill, fill)
    end
    local pct = on and fig.mpBigNow == true
    if fig.mpPct and (fig.mpPctOn or false) ~= pct then
        fig.mpPctOn = pct
        Vis(fig.mpPct, pct)
    end
end
local function Bar(fig, layer, token)
    local tex = fig:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    Kit.Tint(tex, token)
    tex:Hide()
    return tex
end
local function Label(fig, justify)
    local fs = fig:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    Kit.Text(fs, "sem.rep.castText")
    fs:Hide()
    return fs
end
local function EnsureBar(fig)
    if fig.cbBg then return end
    fig.cbBg = Bar(fig, "ARTWORK", "sem.rep.castBg")
    fig.cbFill = Bar(fig, "OVERLAY", "sem.rep.cast")
    fig.cbFill:SetPoint("TOPLEFT", fig.cbBg, "TOPLEFT", 0, 0)
    fig.cbFill:SetPoint("BOTTOMLEFT", fig.cbBg, "BOTTOMLEFT", 0, 0)
    fig.cbIcon = fig:CreateTexture(nil, "ARTWORK")
    fig.cbIcon:SetPoint("RIGHT", fig.cbBg, "LEFT", -GAP, 0)
    fig.cbIcon:Hide()
    fig.cbTime = Label(fig, "CENTER")
    fig.cbTime:SetPoint("CENTER", fig.cbBg, "CENTER", 0, 0)
    fig.cbSide = fig:CreateTexture(nil, "ARTWORK")
    fig.cbSide:SetPoint("LEFT", fig.cbBg, "RIGHT", GAP, 0)
    fig.cbSide:Hide()
end
local function PlaceAction(fig, top)
    local h = max(1, Px(CB_H))
    local icon = h
    local size = Sized(fig.cbTime, TIME_PT, "cbTimeSize", fig)
    local w = max(floor(size * CB_TXT_EM + 2.5), floor((fig.uw or 0) * CB_ROW_K + 0.5) - icon - GAP)
    local row = max(h, icon)
    local y = top - row / 2
    if fig.cbY ~= y or fig.cbIconW ~= icon or fig.cbW ~= w then
        fig.cbY = y
        fig.cbBg:ClearAllPoints()
        fig.cbBg:SetPoint("CENTER", fig, "CENTER", (icon + GAP) / 2, y)
    end
    if fig.cbW ~= w then
        fig.cbW, fig.cbQ = w, nil
        fig.cbBg:SetWidth(w)
        fig.cbTime:SetWidth(w)
    end
    if fig.cbH ~= h then
        fig.cbH = h
        fig.cbBg:SetHeight(h)
    end
    if fig.cbIconW ~= icon then
        fig.cbIconW = icon
        fig.cbIcon:SetWidth(icon)
        fig.cbIcon:SetHeight(icon)
        fig.cbSide:SetWidth(icon)
        fig.cbSide:SetHeight(icon)
    end
    fig.cbRow = row
    return top - row
end
local function PrepTime(fig, left, cut)
    local q = cut and -1 or floor(left * 10)
    if fig.cbT ~= q then
        fig.cbT = q
        local text = cut and ns.T("iso.cast.cut") or format("%.1f", q / 10)
        fig.cbTime:SetText(text)
        fig.cbTxt = text
    end
end
local function PrepAction(fig, id, share, left, token, top, bare)
    EnsureBar(fig)
    fig.cbBare = bare == true
    local bottom = PlaceAction(fig, top)
    if fig.cbId ~= id then
        fig.cbId = id
        Kit.Icon.Spell(fig.cbIcon, id)
    end
    if fig.cbTok ~= token then
        fig.cbTok = token
        Kit.Tint(fig.cbFill, token)
        Kit.Tint(fig.cbBg, token, CB_BG_A)
    end
    local q = floor(share * fig.cbW + 0.5)
    if fig.cbQ ~= q then
        fig.cbQ = q
        fig.cbFill:SetWidth(max(0.01, min(q, fig.cbW)))
    end
    PrepTime(fig, left, token == "sem.rep.castCut")
    return bottom
end
local function ShowAction(fig, on)
    if not fig.cbBg then return end
    if (fig.cbOn or false) ~= on then
        fig.cbOn = on
        Vis(fig.cbIcon, on)
    end
    local bar = on and not fig.cbBare
    if (fig.cbBarOn or false) ~= bar then
        fig.cbBarOn = bar
        Vis(fig.cbBg, bar)
        Vis(fig.cbTime, bar)
    end
    local side = on and fig.wSide == true
    if (fig.cbSideOn or false) ~= side then
        fig.cbSideOn = side
        Vis(fig.cbSide, side)
    end
    local fill = bar and (fig.cbQ or 0) > 0
    if (fig.cbFillOn or false) ~= fill then
        fig.cbFillOn = fill
        Vis(fig.cbFill, fill)
    end
end
local function PrepSpell(fig, id, top, big)
    if not fig.cbName then fig.cbName = Label(fig, "CENTER") end
    local size = Sized(fig.cbName, big and FOCUS_SPELL_PT or SPELL_PT, "cbNameSize", fig)
    if fig.cbNameY ~= top then
        fig.cbNameY = top
        fig.cbName:ClearAllPoints()
        fig.cbName:SetPoint("TOP", fig, "CENTER", 0, top)
    end
    local w = max(fig.cbW + fig.cbIconW + GAP, Px(BIG_W) * 2, floor((fig.uw or 0) * NICK_FOCUS_W + 0.5))
    if fig.cbNameW ~= w or fig.cbNameId ~= id or fig.cbNameS ~= size then
        fig.cbNameW, fig.cbNameId, fig.cbNameS = w, id, size
        fig.cbName:SetWidth(w)
        fig.cbNameText = ns.SpellName(id)
        fig.cbName:SetText(fig.cbNameText)
        fig.cbNameTW = min(w, fig.cbName:GetStringWidth() or w)
    end
    return top - size
end
local function ShowSpell(fig, on)
    if not fig.cbName or (fig.cbNameOn or false) == on then return end
    fig.cbNameOn = on
    Vis(fig.cbName, on)
end
local shortId = {}
local function BossShort(key)
    if key == nil or key == "" then return nil end
    local id = key
    if type(key) == "string" then
        id = shortId[key]
        if id == nil then
            id = false
            for npc in pairs(ns.bossShort) do
                if ns.NpcName(npc) == key then
                    id = npc
                    break
                end
            end
            shortId[key] = id
        end
        if not id then return nil end
    end
    local short = ns.bossShort[id]
    if short then return ns.T("rep.short." .. short) end
    if ns.bosses[id] then return ns.T("rep.short.boss") end
    return nil
end
local function TargetName(scene, target)
    if type(target) == "number" then
        local track = scene.tracks[target]
        if track then return track.name, track.class, false end
        if target == 0 then
            return BossShort(scene.bossName) or BossShort(scene.fight.boss) or ns.T("rep.short.boss"), nil, true
        end
        return nil, nil, true
    end
    if type(target) == "table" then return BossShort(target.npc) or target.name, nil, true end
    if type(target) == "string" and target ~= "" then
        local class = ns.Encounters.ClassOf(target)
        if class == nil then return BossShort(target) or target, nil, true end
        return target, class, false
    end
    return nil, nil, true
end
local function PrepTarget(fig, scene, target, top, big)
    local name, class, mob
    if target ~= nil then name, class, mob = TargetName(scene, target) end
    if not name then return false end
    if not fig.cbTarget then fig.cbTarget = Label(fig, "CENTER") end
    local size = Sized(fig.cbTarget, big and FOCUS_TARGET_PT or TARGET_PT, "cbTargetSize", fig)
    if fig.cbTargetY ~= top then
        fig.cbTargetY = top
        fig.cbTarget:ClearAllPoints()
        fig.cbTarget:SetPoint("TOP", fig, "CENTER", 0, top)
    end
    local w = max(Px(BIG_W) * 2, floor((fig.uw or 0) * NICK_FOCUS_W + 0.5))
    local changed = fig.cbTargetW ~= w or fig.cbTargetName ~= name or fig.cbTargetClass ~= class
        or fig.cbTargetMob ~= mob or fig.cbTargetS ~= size
    if fig.cbTargetW ~= w then
        fig.cbTargetW = w
        fig.cbTarget:SetWidth(w)
    end
    if changed then
        fig.cbTargetName, fig.cbTargetClass, fig.cbTargetMob, fig.cbTargetS = name, class, mob, size
        Kit.Text(fig.cbTarget, mob and "sem.rep.add" or "sem.rep.castText")
        fig.cbTargetText = mob and name or ns.ReplayWho.Name(name, class)
        fig.cbTarget:SetText(fig.cbTargetText)
        fig.cbTargetTW = min(w, fig.cbTarget:GetStringWidth() or w)
    end
    return true
end
local function ShowTarget(fig, on)
    if not fig.cbTarget or (fig.cbTargetOn or false) == on then return end
    fig.cbTargetOn = on
    Vis(fig.cbTarget, on)
end
local function LaneAt(lane, t)
    if not lane then return nil end
    local i = RU.Seek(lane.F, lane.ui or 1, t)
    if i == 0 then return nil end
    lane.ui = i
    if t < lane.T[i] then return lane.G[i] end
    return nil
end
local function PrepActionFor(fig, scene, data, k, t, focus, act, top)
    local ar = scene.layers and scene.layers.arrows
    local rec, p, left = RU.CastAt(data.casts[fig.name], t)
    fig.cbRec = act and rec or nil
    fig.wCast, fig.wTarget, fig.wName, fig.wSide = false, false, false, false
    local ins = act and data.inst and data.inst[fig.name]
    local jOn, jOff = 0, 0
    local j = ins and RU.InstAt(ins, t) or 0
    while j > 0 and t - ins.T[j] < RU.GCD_LIFE and (jOn == 0 or jOff == 0) do
        if ins.O and ins.O[j] then
            if jOff == 0 then jOff = j end
        elseif jOn == 0 then
            jOn = j
        end
        j = j - 1
    end
    local targets = ar and ar.instTargets and ar.instTargets[k]
    local _, nameS = FontOf(focus and FOCUS_SPELL_PT or SPELL_PT)
    local rowTop = top
    local nameTop = rowTop - max(1, Px(CB_H)) - GAP
    local targetTop = nameTop - nameS - GAP
    local target
    if rec and act then
        local cut = rec.cut and t >= rec.stop
        local token = cut and "sem.rep.castCut" or rec.chan and "sem.rep.castChan" or "sem.rep.cast"
        local share = cut and 1 or rec.chan and 1 - p or p
        PrepAction(fig, rec.id, share, left, token, rowTop)
        PrepSpell(fig, rec.id, nameTop, focus)
        fig.wName = true
        if not cut then target = ar and ar.castTargets and ar.castTargets[rec] or rec.aim end
        fig.wCast = true
    elseif jOn > 0 then
        left = RU.GCD_LIFE - (t - ins.T[jOn])
        PrepAction(fig, ins.R[jOn], left / RU.GCD_LIFE, left, "sem.rep.gcd", rowTop)
        target = targets and targets[jOn]
        fig.wCast = true
    elseif jOff > 0 then
        left = RU.GCD_LIFE - (t - ins.T[jOff])
        PrepAction(fig, ins.R[jOff], 1, left, "sem.rep.gcd", rowTop, true)
        target = targets and targets[jOff]
        fig.wCast, jOff = true, 0
    end
    if jOff > 0 and fig.wCast and ins.R[jOff] ~= fig.cbId then
        if fig.cbSideId ~= ins.R[jOff] then
            fig.cbSideId = ins.R[jOff]
            Kit.Icon.Spell(fig.cbSide, fig.cbSideId)
        end
        fig.wSide = true
    end
    if focus and target == nil then target = LaneAt(ar and ar.lanes and ar.lanes[k], t) end
    if (fig.wCast or focus) and PrepTarget(fig, scene, target, targetTop, focus) then fig.wTarget = true end
end
function V.CastsAll()
    return Saved().castsAll ~= false
end
function V.SetCastsAll(on)
    if on then Saved().castsAll = nil else Saved().castsAll = false end
end
function V.SetRule(rule)
    st.casts = rule and rule.casts or nil
    st.mana = rule and rule.mana or nil
end
function V.CastShown(role, mine)
    if mine then return true end
    if st.casts then return role == st.casts end
    return V.CastsAll()
end
local function Free(k, x1, x2, y1, y2)
    for i = 1, nRect do
        if RO[i] ~= k and x1 < RX2[i] + PAD and x2 + PAD > RX1[i] and y1 < RY2[i] + PAD and y2 + PAD > RY1[i] then
            return false
        end
    end
    return true
end
local function Take(k, kind, x1, x2, y1, y2)
    if x1 < -st.hw or x2 > st.hw or y1 < -st.hh or y2 > st.hh then return false end
    if not Free(k, x1, x2, y1, y2) then return false end
    nRect = nRect + 1
    RX1[nRect], RX2[nRect], RY1[nRect], RY2[nRect], RO[nRect], RK[nRect] = x1, x2, y1, y2, k, kind
    return true
end
local function Settle(fig, k, part)
    local cx, cy = fig.sx or 0, -(fig.sy or 0)
    if part == 1 then
        if not fig.wNick then return end
        local w, h = fig.nkTW or 0, fig.nkH or fig.nkS or 0
        local below = (h - (fig.nkS or 0)) / 2
        local b1 = fig.aTomb and cy + fig.aTombY - PAD
        local b2 = b1 and b1 + (fig.tbH or 0) + PAD * 2
        for step = 0, NICK_TRIES do
            local y = cy + fig.nkY - below + step * (h + PAD + 1)
            if not (b1 and y < b2 and y + h > b1) and Take(k, 1, cx - w / 2, cx + w / 2, y, y + h) then
                fig.aNick, fig.aNickUp = true, step * (h + PAD + 1)
                return
            end
        end
    elseif part == 2 then
        if not fig.wMana then return end
        local top = cy + fig.under - GAP
        local w = fig.mpW or 0
        local right = cx + w / 2 + (fig.mpBigNow and (fig.mpSize or 0) * 2.2 or 0)
        fig.aMana = Take(k, 2, cx - w / 2, right, top - (fig.mpH or 0), top)
    elseif part == 3 then
        if not fig.wCast then return end
        local icon, w, row = fig.cbIconW or 0, fig.cbW or 0, fig.cbRow or 0
        local mid = cx + (icon + GAP) / 2
        local y = cy + fig.cbY
        local right = fig.cbBare and mid - w / 2 - GAP or mid + w / 2 + (fig.wSide and GAP + icon or 0)
        fig.aCast = Take(k, 3, mid - w / 2 - GAP - icon, right, y - row / 2, y + row / 2)
    elseif part == 6 then
        if not fig.wTomb then return end
        local h = fig.nkH or fig.nkS or 0
        local base = cy + (fig.nkY or 0) - (h - (fig.nkS or 0)) / 2 + (fig.aNickUp or 0) + h + PAD + 1
        local x1, th = cx - (fig.uw or 0) / 2, fig.tbH or 0
        for step = 0, NICK_TRIES do
            local y = base + step * (th + PAD + 1)
            if Take(k, 6, x1, x1 + (fig.tbW or 0), y, y + th) then
                fig.aTomb, fig.aTombY = true, y - cy
                return
            end
        end
    elseif part == 4 then
        if not (fig.wName and fig.aCast) then return end
        local w = fig.cbNameTW or 0
        local top = cy + fig.cbNameY
        fig.aName = Take(k, 4, cx - w / 2, cx + w / 2, top - (fig.cbNameS or 0), top)
    elseif part == 5 and fig.wTarget and (not fig.wCast or fig.aCast) then
        local w = fig.cbTargetTW or 0
        local top = cy + fig.cbTargetY
        fig.aTarget = Take(k, 5, cx - w / 2, cx + w / 2, top - (fig.cbTargetS or 0), top)
    end
end
local function Apply(fig)
    if fig.aNick and fig.nkLift ~= fig.aNickUp then
        fig.nkLift = fig.aNickUp
        fig.nkFs:ClearAllPoints()
        fig.nkFs:SetPoint("BOTTOM", fig, "CENTER", fig.nkShift, fig.nkY + fig.nkLift)
    end
    ShowNick(fig, fig.aNick)
    ShowMana(fig, fig.aMana)
    ShowAction(fig, fig.aCast)
    ShowSpell(fig, fig.aName)
    ShowTarget(fig, fig.aTarget)
    local TV = ns.ReplayTombView
    if TV and (fig.wTomb or fig.tbOn) then TV.Show(fig, fig.aTomb, fig.aTombY) end
    return (fig.wTomb and not fig.aTomb and 1 or 0) + (fig.wNick and not fig.aNick and 1 or 0) + (fig.wMana and not fig.aMana and 1 or 0)
        + (fig.wCast and not fig.aCast and 1 or 0) + (fig.wName and not fig.aName and 1 or 0)
        + (fig.wTarget and not fig.aTarget and 1 or 0)
end
local function Before(figs, a, b)
    local fa, fb = figs[a], figs[b]
    local pa = fa.name == st.focus and 2 or fa.role == "tank" and 1 or 0
    local pb = fb.name == st.focus and 2 or fb.role == "tank" and 1 or 0
    if pa ~= pb then return pa > pb end
    return (fa.sy or 0) > (fb.sy or 0)
end
function V.Place(scene, t, figs, n, zoom, cam)
    st.k = V.Scale(zoom or 1)
    st.hw, st.hh = cam and cam.w / 2 or math.huge, cam and cam.h / 2 or math.huge
    local data = st.data
    local all = V.CastsAll()
    local shown, casting, rage = 0, 0, 0
    local m = 0
    local TV = ns.ReplayTombView
    for k = 1, n do
        local fig = figs[k]
        local s = scene.states[k]
        local alive = data and fig.shown and fig.under and not (s and s.dead)
        local focus = fig.name == st.focus
        fig.wNick, fig.wMana, fig.wCast, fig.wTarget, fig.wName = false, false, false, false, false
        if fig.shown and fig.icon then
            PrepNick(fig, focus)
            fig.wNick = true
        end
        fig.wTomb = TV and fig.shown and TV.Want(scene, fig, k, t) or false
        if alive then
            local veh = data.vpow and RU.ManaAt(data.vpow[fig.name], t)
            local mn = not veh and (focus or st.mana ~= "heal" or fig.role == st.mana) and data.mana[fig.name]
            local v = veh or (mn and RU.ManaAt(mn, t))
            local top = fig.under - GAP - max(1, Px(focus and BIG_H or BAR_H)) - GAP
            if v then
                PrepMana(fig, v, focus, veh and "sem.rep.rage" or "sem.rep.mana")
                fig.wMana = true
                if veh then rage = rage + 1 else shown = shown + 1 end
            end
            local act = focus or (st.casts and fig.role == st.casts) or (not st.casts and all)
            PrepActionFor(fig, scene, data, k, t, focus, act, top)
            if fig.wCast then casting = casting + 1 end
        else
            fig.cbRec = nil
        end
        if fig.shown then
            m = m + 1
            order[m] = k
        else
            ShowNick(fig, false)
            ShowMana(fig, false)
            ShowAction(fig, false)
            ShowSpell(fig, false)
            ShowTarget(fig, false)
            if TV and fig.tbOn then TV.Show(fig, false) end
        end
    end
    for i = m + 1, #order do order[i] = nil end
    for i = 2, m do
        local v = order[i]
        local j = i - 1
        while j >= 1 and Before(figs, v, order[j]) do
            order[j + 1] = order[j]
            j = j - 1
        end
        order[j + 1] = v
    end
    nRect = 0
    local hidden = 0
    local first = m > 0 and figs[order[1]].name == st.focus and 1 or 0
    for i = 1, m do
        local fig = figs[order[i]]
        fig.aNick, fig.aMana, fig.aCast, fig.aName, fig.aTarget, fig.aNickUp = false, false, false, false, false, 0
        fig.aTomb, fig.aTombY = false, nil
    end
    if first == 1 then
        for p = 1, #PARTS do Settle(figs[order[1]], order[1], PARTS[p]) end
    end
    for p = 1, #PARTS do
        for i = first + 1, m do Settle(figs[order[i]], order[i], PARTS[p]) end
    end
    for i = 1, m do hidden = hidden + Apply(figs[order[i]]) end
    V.stats.mana, V.stats.casts, V.stats.rage, V.stats.hidden = shown, casting, rage, hidden
end
function V.Nick(fig)
    return fig and fig.nkOn and fig.nkTxt or nil
end
function V.Rects()
    local out = {}
    for i = 1, nRect do out[i] = { RX1[i], RX2[i], RY1[i], RY2[i], RO[i], RK[i] } end
    return out
end
function V.Probe(fig)
    local cast = fig.wCast and fig.cbRec or nil
    return { mana = fig.wMana and fig.mpQ or nil, big = fig.wMana and fig.mpBigNow == true or false,
             w = fig.wMana and fig.mpW or nil, h = fig.wMana and fig.mpH or nil, pct = fig.mpTxt,
             bar = fig.wMana and fig.mpTok or nil,
             cast = cast, fill = fig.wCast and fig.cbQ or nil,
             actionW = fig.wCast and (fig.cbW + fig.cbIconW + GAP) or nil,
             bare = fig.wCast and fig.cbBare or nil, side = fig.wSide and fig.cbSideId or nil,
             tone = fig.wCast and fig.cbTok or nil, id = fig.wCast and fig.cbId or nil,
             left = fig.wCast and not fig.cbBare and fig.cbTxt or nil,
             target = fig.wTarget and fig.cbTargetText or nil,
             spell = fig.wName and fig.cbNameText or nil, spellSize = fig.cbNameSize,
             nick = fig.wNick and fig.nkTxt or nil, nickW = fig.wNick and fig.nkW or nil,
             nickSize = fig.wNick and fig.nkSize or nil, role = fig.wNick and fig.nkRoleOn or nil,
             timeSize = fig.cbTimeSize, targetSize = fig.cbTargetSize, k = st.k,
             shown = { nick = fig.nkOn or false, mana = fig.mpOn or false, cast = fig.cbOn or false,
                       spell = fig.cbNameOn or false, target = fig.cbTargetOn or false },
             inst = 0 }
end
