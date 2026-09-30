local ADDON, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local exp = math.exp
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SIDE_TEX = ART .. "chip_side"
local ARC_TEX = ART .. "hparc"
local RES = {
    [128] = { ring = ART .. "ring128", disc = ART .. "disc128", share = 0.035 },
    [256] = { ring = ART .. "ring256", disc = ART .. "disc256", share = 0.0325 },
}
local ARC_N = 32
local ARC_COLS = 8
local ARC_W = 1024
local ARC_H = 512
local ARC_F = 128
local ARC_IN = 2.5
local ARC_SHARE = 10 / (ARC_F - 2 * ARC_IN)
local ARC_EDGE = 1.5 / (ARC_F - 2 * ARC_IN)
local TRAIL_A = 0.3
local HP_Q = 64
local HP_RATE = 10
local HP_EPS = 0.004
local CHIP_MIN = 0.15
local BIG_PX = 48
local EDGE = 1.5
local TUCK = 1
local DISC = 22
local BOSS_K = 1.5
local CHIP_H = 11
local DROP_K = 1.08
local CHIP_DROP_K = 1.2
local CHIP_DROP_X = 0.12
local VOL_ICON = 18
local VOL_SHADOW = 22
local VOL_LIFT = 9
local VOL_PAD = 4
local VOL_DEAD_K = 0.5
local PLATE_A = 0.9
local DOT = 11
local DOT_X = -1
local DOT_Y = 2
local SIDE_W = 128
local SIDE_H = 256
local SIDE_BASE = SIDE_H - 2 - 62 * 0.55
local SIDE_RY = 62 * 0.55
local SIDE_TOP = 1
local SIDE_BOTTOM = SIDE_H - 2
local SIDE_RX = 62 / 64
local CROWD_A = 0.8
local CROWD_OVER = 0.7
local KINDS = { "disc", "chip", "vol" }
local NEXT = { disc = "chip", chip = "vol", vol = "disc" }
local ROLE_TOKEN = { tank = "sem.rep.tank", heal = "sem.rep.heal", boss = "sem.lane.boss" }
local DD_TOKEN = "sem.rep.dd"
local DD_ARC = "sem.rep.ddHp"
local Figs = { KINDS = KINDS, ARC_N = ARC_N }
ns.ReplayFigs = Figs
local Kit = ns.Kit
local st = { kind = "chip", hp = true, arcOk = true, px = 1 }
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function Figs.Kind()
    return st.kind
end
function Figs.HpOn()
    return Saved().figHp ~= false
end
local function UpdateButton()
    local b = st.btn
    if not b then return end
    b.text:SetText(ns.T("iso.figs." .. st.kind))
    b.tip = ns.T("iso.tip.figs." .. st.kind)
end
function Figs.Load()
    local v = Saved().figs
    local was = st.kind
    st.kind = NEXT[v] and v or "chip"
    st.hp = Figs.HpOn()
    UpdateButton()
    if was ~= st.kind and Figs.Refresh then Figs.Refresh() end
end
local function Arc(fig)
    return st.hp and st.arcOk and not fig.isBoss and st.kind ~= "chip"
end
function Figs.ArcOk()
    return st.arcOk
end
local function Plate(fig)
    local tok = fig.rimOver or (fig.mcOn and "sem.rep.mc")
    if tok then
        Kit.Hue(fig.side, tok)
    else
        fig.side:SetVertexColor(fig.cr, fig.cg, fig.cb, PLATE_A)
    end
end
function Figs.Rim(fig, over)
    if over ~= nil then fig.rimOver = over or nil end
    local tok = fig.rimOver or (fig.mcOn and "sem.rep.mc") or fig.rimTok
    if tok == DD_TOKEN and Arc(fig) then tok = DD_ARC end
    fig.rimNow = tok
    Kit.Hue(fig.ring, tok)
    local _, _, _, a = Kit.Color(tok)
    Kit.Hue(fig.trail, tok, a * TRAIL_A)
    if st.kind == "vol" and fig.cr then Plate(fig) end
end
local function Refresh()
    local figs = st.figs
    if not figs then return end
    for k = 1, #figs do
        local fig = figs[k]
        fig.sQ = nil
        fig.alpha = nil
        if fig.rimTok then Figs.Rim(fig) end
    end
end
Figs.Refresh = Refresh
function Figs.SetKind(kind)
    st.kind = NEXT[kind] and kind or "chip"
    Saved().figs = st.kind
    Refresh()
    UpdateButton()
end
function Figs.SetHp(on)
    st.hp = on and true or false
    Saved().figHp = st.hp
    Refresh()
end
function Figs.Bind(figs, view)
    st.figs = figs
    st.px = view.GetEffectiveScale and view:GetEffectiveScale() or 1
    if type(st.px) ~= "number" or st.px <= 0 then st.px = 1 end
end
function Figs.Button(parent, anchor, height)
    local b = Kit.Button(parent)
    b:SetWidth(128)
    b:SetHeight(height)
    b:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
    b.onClick = function() Figs.SetKind(NEXT[st.kind]) end
    st.btn = b
    Figs.Load()
    UpdateButton()
    return b
end
local function ArcFrame(tex, f)
    local col = (f - 1) % ARC_COLS
    local row = floor((f - 1) / ARC_COLS)
    tex:SetTexCoord((col * ARC_F + ARC_IN) / ARC_W, ((col + 1) * ARC_F - ARC_IN) / ARC_W,
        (row * ARC_F + ARC_IN) / ARC_H, ((row + 1) * ARC_F - ARC_IN) / ARC_H)
end
function Figs.ArcOf(hp)
    return max(1, min(ARC_N, ceil(hp * ARC_N - 1e-6)))
end
function Figs.Build(fig)
    fig.shadow = fig:CreateTexture(nil, "BACKGROUND")
    fig.side = fig:CreateTexture(nil, "BORDER")
    fig.side:SetTexture(SIDE_TEX)
    fig.side:Hide()
    fig.trail = fig:CreateTexture(nil, "BORDER")
    st.arcOk = fig.trail:SetTexture(ARC_TEX) and true or false
    ArcFrame(fig.trail, ARC_N)
    fig.ring = fig:CreateTexture(nil, "ARTWORK")
    fig.trail:SetAllPoints(fig.ring)
    fig.trail:Hide()
    fig.icon = fig:CreateTexture(nil, "ARTWORK")
    fig.dot = fig:CreateTexture(nil, "OVERLAY")
    fig.dot:Hide()
    fig.rimTok = DD_TOKEN
end
function Figs.Config(fig, class, role)
    fig.clsTok = class
    fig.role = role or "dd"
    fig.rimTok = ROLE_TOKEN[role or ""] or DD_TOKEN
    fig.res, fig.skin, fig.hpNow, fig.hpQ = nil, nil, nil, nil
    Figs.Rim(fig)
end
local function Skin(fig)
    local kind = st.kind
    if fig.skin == kind then return end
    fig.skin = kind
    local vol = kind == "vol"
    local lead = fig.role == "tank" or fig.role == "heal"
    if fig.role == "boss" then
        fig.icon:SetTexture(MARKS)
        fig.icon:SetTexCoord(0.75, 1, 0.25, 0.5)
    elseif vol and lead then
        Kit.Icon.RoleBig(fig.icon, fig.role)
    elseif vol then
        Kit.Icon.Class(fig.icon, fig.clsTok)
    else
        Kit.Icon.ClassCircle(fig.icon, fig.clsTok)
    end
    fig.dotWant = vol and lead
    if fig.dotWant then Kit.Icon.ClassCircle(fig.dot, fig.clsTok) end
    fig.ring:SetDrawLayer(vol and "BORDER" or "ARTWORK")
    if vol then
        fig.shadow:SetTexture(CIRCLE)
        fig.shadow:SetTexCoord(0, 1, 0, 1)
    else
        fig.side:SetTexture(SIDE_TEX)
    end
    fig.res = nil
end
local function Res(fig, d)
    local res = d * st.px >= BIG_PX and 256 or 128
    local R = RES[res]
    if fig.res ~= res then
        fig.res = res
        fig.ringTex = nil
        if st.kind == "vol" then
            fig.side:SetTexture(R.disc)
            fig.side:SetTexCoord(0, 1, 0, 1)
        else
            fig.shadow:SetTexture(R.disc)
            fig.shadow:SetTexCoord(0, 1, 0, 1)
        end
    end
    return R
end
local function RingTex(fig, R, arc)
    if arc and fig.ringTex ~= ARC_TEX then
        if fig.ring:SetTexture(ARC_TEX) then
            fig.ringTex, fig.arcF = ARC_TEX, nil
            Kit.Hue(fig.ring, fig.rimNow or fig.rimTok)
        else
            st.arcOk, arc = false, nil
            fig.ringTex = nil
            Refresh()
        end
    end
    if arc then
        if fig.arcF ~= arc then
            fig.arcF = arc
            ArcFrame(fig.ring, arc)
        end
        return ARC_SHARE, ARC_EDGE
    end
    if fig.ringTex ~= R.ring then
        fig.ring:SetTexture(R.ring)
        fig.ring:SetTexCoord(0, 1, 0, 1)
        fig.ringTex, fig.arcF = R.ring, nil
        Kit.Hue(fig.ring, fig.rimNow or fig.rimTok)
    end
    return R.share, EDGE / fig.res
end
local function Put(tex, fig, w, h, x, y)
    tex:ClearAllPoints()
    tex:SetWidth(max(1, w))
    tex:SetHeight(max(1, h))
    tex:SetPoint("CENTER", fig, "CENTER", x, y)
end
local function PlaceSide(fig, w, flat, tall, lift)
    local ry = w / 2 * flat * SIDE_RX
    fig.sideWant = tall >= 1 and ry > 0
    if not fig.sideWant then return end
    local y0 = max(SIDE_TOP, SIDE_BASE - tall * SIDE_RY / ry)
    local side = fig.side
    side:ClearAllPoints()
    side:SetWidth(w)
    side:SetHeight(tall + ry)
    side:SetPoint("TOP", fig, "CENTER", 0, tall + lift)
    side:SetTexCoord(0, 1, y0 / SIDE_H, SIDE_BOTTOM / SIDE_H)
    local r, g, b = Kit.RGB("sem.rep.side")
    side:SetVertexColor(fig.cr * r, fig.cg * g, fig.cb * b)
end
local function Dead(fig, inner, flat)
    Put(fig.icon, fig, inner, inner * flat, 0, 0)
    if not fig.icon:SetDesaturated(true) then Kit.Hue(fig.icon, "sem.rep.gone") end
    fig.top, fig.hy = inner * flat / 2, 0
end
local function Alive(fig)
    fig.icon:SetDesaturated(false)
    Kit.Hue(fig.icon, "sem.rep.icon")
end
local function DrawVol(fig, dead, scale, flat, lift, hp)
    local sw = VOL_SHADOW * scale
    local sh = max(2, sw * flat)
    fig:SetWidth(sw)
    fig:SetHeight(sh)
    fig.w, fig.flat, fig.ringFlat, fig.tall = sw, flat, 1, 0
    Put(fig.shadow, fig, sw, sh, 0, 0)
    Kit.Hue(fig.shadow, "sem.rep.drop")
    local ic = VOL_ICON * scale * (fig.isBoss and BOSS_K or 1)
    fig.ringWant, fig.sideWant, fig.trailWant, fig.dotNow = false, false, false, fig.dotWant
    if dead then
        Dead(fig, ic, VOL_DEAD_K)
        if fig.dotWant then Put(fig.dot, fig, DOT, DOT, ic / 2 + DOT_X, -ic * VOL_DEAD_K / 2 + DOT_Y) end
        return
    end
    local y0 = (VOL_LIFT + lift) * scale
    local cy = y0 + ic / 2
    Put(fig.icon, fig, ic, ic, 0, cy)
    Alive(fig)
    local plate = ic + VOL_PAD
    local R = Res(fig, plate)
    Put(fig.side, fig, plate, plate, 0, cy)
    Plate(fig)
    fig.sideWant, fig.pw = true, plate
    if fig.dotWant then Put(fig.dot, fig, DOT, DOT, ic / 2 + DOT_X, y0 + DOT_Y) end
    local top = y0 + ic
    local arc = Arc(fig) and Figs.ArcOf(hp) or nil
    if arc then
        local share, edge = RingTex(fig, R, arc)
        if fig.ringTex == ARC_TEX then
            local D = (plate - 2 * TUCK) / (1 - 2 * (edge + share))
            Put(fig.ring, fig, D, D, 0, cy)
            fig.rw, fig.ringWant, fig.trailWant = D, true, fig.arcF < ARC_N
            top = max(top, cy + D / 2)
        end
    end
    fig.top, fig.hy = top, cy
end
local function Draw(fig, dead, scale, flat, lift, hp)
    Skin(fig)
    if st.kind == "vol" then return DrawVol(fig, dead, scale, flat, lift, hp) end
    local d = DISC * scale * (fig.isBoss and BOSS_K or 1)
    local R = Res(fig, d)
    local chip = st.kind == "chip"
    local arc = Arc(fig) and Figs.ArcOf(hp) or nil
    local share, edge = RingTex(fig, R, arc)
    if fig.ringTex ~= ARC_TEX then arc = nil end
    local inner = d * (1 - 2 * (edge + share)) + 2 * TUCK
    fig.ringWant = true
    fig:SetWidth(d)
    fig:SetHeight(max(2, d * flat))
    fig.w, fig.flat, fig.rw, fig.ringFlat = d, flat, d, flat
    local up = lift * scale
    local tall = 0
    if chip and not dead then
        tall = CHIP_H * scale * sqrt(max(0, 1 - flat * flat))
        if st.hp and not fig.isBoss then tall = tall * max(CHIP_MIN, hp) end
    end
    fig.tall = tall
    if chip then
        Put(fig.shadow, fig, d * CHIP_DROP_K, d * CHIP_DROP_K * flat, d * CHIP_DROP_X, -d * flat * CHIP_DROP_X)
        Kit.Hue(fig.shadow, "sem.rep.drop")
    else
        Put(fig.shadow, fig, d * DROP_K, d * DROP_K * flat, 0, -d * flat * (DROP_K - 1))
        Kit.Hue(fig.shadow, "sem.rep.dropSoft")
    end
    fig.sideWant, fig.trailWant, fig.dotNow = false, false, false
    if dead then
        Dead(fig, inner, flat)
        return
    end
    if chip then PlaceSide(fig, d, flat, tall, up) end
    local cy = tall + up
    Put(fig.ring, fig, d, d * flat, 0, cy)
    fig.trailWant = arc ~= nil and arc < ARC_N
    Put(fig.icon, fig, inner, inner * flat, 0, cy)
    Alive(fig)
    fig.top, fig.hy = cy + d * flat / 2, cy
end
function Figs.Sprite(fig, s, scale, flat, elapsed)
    local want = s.dead and 0 or (s.hp or 1)
    local hp = fig.hpNow
    if not hp or not st.hp then
        hp = want
    elseif hp ~= want then
        hp = hp + (want - hp) * (1 - exp(-HP_RATE * max(0, elapsed or 0)))
        if abs(want - hp) < HP_EPS then hp = want end
    end
    fig.hpNow = hp
    local hq = st.hp and floor(hp * HP_Q + 0.5) or HP_Q
    local lift = fig.lift or 0
    local q = floor(scale * 50 + 0.5) + floor(flat * 100) * 1000 + lift * 1000000
    if fig.sQ == q and fig.sDead == s.dead and fig.hpQ == hq then return end
    fig.sQ, fig.sDead, fig.hpQ = q, s.dead, hq
    Draw(fig, s.dead, scale, flat, lift, hq / HP_Q)
end
local function Toggle(tex, on, fig, key)
    if fig[key] == on then return end
    fig[key] = on
    if on then tex:Show() else tex:Hide() end
end
function Figs.Parts(fig, icon, ring, model)
    Toggle(fig.icon, icon, fig, "iconOn")
    Toggle(fig.ring, ring and fig.ringWant ~= false, fig, "ringOn")
    Toggle(fig.side, ring and fig.sideWant or false, fig, "sideOn")
    Toggle(fig.trail, ring and fig.trailWant or false, fig, "trailOn")
    Toggle(fig.dot, icon and fig.dotNow or false, fig, "dotOn")
    if fig.model then Toggle(fig.model, model, fig, "modelOn") end
end
function Figs.Pulse(fig, extra)
    if st.kind == "vol" and fig.pw then
        fig.side:SetWidth(fig.pw + extra)
        fig.side:SetHeight(fig.pw + extra)
    end
    local w = (fig.rw or 0) + extra
    fig.ring:SetWidth(w)
    fig.ring:SetHeight(max(1, w * (fig.ringFlat or 1)))
end
local function SetA(fig, a)
    if fig.alpha ~= a then
        fig.alpha = a
        fig:SetAlpha(a)
    end
end
function Figs.Alpha(figs, order, count)
    local stand = st.kind == "chip"
    for i = 1, count do
        local fig = figs[order[i]]
        if fig.shown then
            local a = fig.baseA or 1
            if stand and fig.sideOn then
                local reach = (fig.tall or 0) + (fig.w or 0) * (fig.flat or 1)
                for j = i + 1, count do
                    local g = figs[order[j]]
                    if g.shown then
                        local dy = g.sy - fig.sy
                        if dy > reach then break end
                        if dy > 0 and abs(g.sx - fig.sx) < ((fig.w or 0) + (g.w or 0)) / 2 * CROWD_OVER then
                            a = a * CROWD_A
                            break
                        end
                    end
                end
            end
            SetA(fig, floor(a * 100 + 0.5) / 100)
        end
    end
end
function Figs.Probe(fig)
    local n = 0
    for _, key in ipairs({ "shadow", "side", "trail", "ring", "icon", "dot" }) do
        if fig[key] then n = n + 1 end
    end
    return { kind = st.kind, saved = Saved().figs, textures = n, rim = fig.rimTok, side = fig.sideOn or false,
             res = fig.res, hp = fig.hpNow, arc = fig.ringTex == ARC_TEX and fig.arcF or nil,
             trail = fig.trailOn or false, tall = fig.tall, arcOk = st.arcOk }
end
if ns.Settings and ns.Settings.Item then
    ns.Settings.Item("look", "replay", {
        kind = "check", key = "figHp", label = "set.replay.hp", tip = "set.replay.hp.tip", default = true, order = 1,
        get = Figs.HpOn, set = Figs.SetHp,
    })
end
