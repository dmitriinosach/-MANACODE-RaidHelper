local ADDON, ns = ...
local max = math.max
local RING = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\ring256"
local RING_DRAW = 8
local RING_K = 0.9
local V = {}
ns.ReplayModeView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local MO = ns.ReplayMode
local st = { roles = {}, fk = 0, btns = {}, rings = {}, used = 0, active = false }
local healed = {}
local liftK = {}
local Saved = RD.Saved
function V.Key()
    return MO.Def(Saved().mode).key
end
local function Buffs(fk, t, out)
    local R = st.scene and st.scene.raid
    local u = R and R.per[fk]
    if not u then return 0, nil end
    local F, T, D, I = u.F, u.T, u.D, u.I
    local n, nx = 0, nil
    for i = 1, #F do
        if F[i] > t then
            if not nx or F[i] < nx then nx = F[i] end
            break
        end
        if T[i] > t and not D[i] then
            n = n + 1
            out[n] = I[i]
            if not nx or T[i] < nx then nx = T[i] end
        end
    end
    for i = 1, math.floor(n / 2) do out[i], out[n + 1 - i] = out[n + 1 - i], out[i] end
    for i = n + 1, #out do out[i] = nil end
    return n, nx
end
local function Raid(on, low)
    local RV = ns.ReplayRaidView
    if not RV then return end
    local key = on and st.def.key or nil
    if st.raidMode ~= key then
        st.raidMode = key
        RV.Force(key ~= nil)
    end
    local SetLow = RV["SetLow"]
    if SetLow then
        if on and low then
            SetLow(low)
            st.low = true
        elseif st.low then
            SetLow(nil)
            st.low = nil
        end
    end
end
local function Feed()
    local F = ns.ReplayFeed
    local scene = st.scene
    local L = scene and scene.layers
    local def = st.def
    if not (st.active and def.feed and L) then
        st.feedKey = nil
        F.SetSource(nil)
        return
    end
    local key = def.key .. "|" .. st.focus
    if st.feedKey == key and st.feedL == L then return end
    st.feedKey, st.feedL = key, L
    F.SetSource(MO.Feed(L, def, scene, st.roles, st.focus))
end
local function Paint()
    local key = st.def and st.def.key or V.Key()
    for k, b in pairs(st.btns) do b:SetActive(k == key) end
    local one = st.one
    if one then
        local def = MO.Def(key)
        one:SetActive(key ~= "normal")
        one.tip = ns.T(def.tip)
        if one.label ~= def.key then
            one.label = def.key
            one:SetText(ns.T(def.label))
            ns.ReplaySize.Place()
        end
    end
end
local function Apply()
    st.def = MO.Def(Saved().mode)
    local def = st.def
    local scene = st.scene
    st.active = scene ~= nil and MO.Active(def, st.focus, st.roles)
    st.fk = 0
    for k in pairs(liftK) do liftK[k] = nil end
    if scene then
        for k = 1, #scene.tracks do
            local name = scene.tracks[k].name
            if name == st.focus then st.fk = k end
            if def.liftOn and MO.Role(st.roles, name) == def.liftOn then liftK[k] = true end
        end
    end
    local on = st.active
    ns.ReplayUnitsView.SetRule(on and def or nil)
    ns.ReplayFigs.SetBig(on and def.bigPct or false)
    ns.ReplayArrowsView.SetBoss(on and def.bossArrows or false, on and def.bossIcon or 1)
    ns.ReplayLayersView.SetMode(on and {
        bright = def.bright, lift = def.lift, liftK = def.lift and liftK or nil, fx = def.fx,
        extra = def.buffs and Buffs or nil, aggro = def.aggro, swap = def.swap,
    } or nil)
    Raid(on and def.raid or false, def.low)
    Feed()
    if not (on and def.ring) then
        for i = 1, st.used do st.rings[i]:Hide() end
        st.used = 0
    end
    Paint()
    if ns.ReplayIso and ns.ReplayIso.Wake then ns.ReplayIso.Wake() end
end
function V.Active()
    return st.active
end
function V.Set(key)
    local def = MO.Def(key)
    Saved().mode = def.key ~= "normal" and def.key or nil
    Apply()
    if ns.ReplayIso and ns.ReplayIso.Focus and st.scene then ns.ReplayIso.Focus(st.focus) end
end
function V.Use(scene, roles)
    st.scene, st.roles = scene, roles or {}
    st.feedKey = nil
    Apply()
end
function V.Focus(name)
    st.focus = name
    Apply()
end
function V.Alpha(scene, t, A)
    if not st.active then return false end
    local def = st.def
    local L = st.scene and st.scene.layers
    if def.alpha and def.alpha.healed and L then
        MO.Healed(L.mode, st.fk, t, ns.replayModes.healWin, healed)
    else
        for k in pairs(healed) do healed[k] = nil end
    end
    MO.Alpha(def, st.scene, st.roles, st.fk, healed, A)
    for k = #scene.tracks + 1, #A do A[k] = nil end
    return true
end
function V.Place(scene, figs)
    local def = st.def
    if not (st.active and def.ring) then return end
    local n = 0
    local Ellipse = ns.ReplayLayersView.Ellipse
    for k = 1, #scene.tracks do
        local fig = figs[k]
        if n < RING_DRAW and fig and fig.shown and not fig.sDead then
            local role = MO.Role(st.roles, fig.name)
            for i = 1, #def.ring do
                if def.ring[i] == role then
                    local rw = (fig.w or 0) * RING_K
                    if rw >= 2 and Ellipse(st.rings[n + 1], fig.sx, fig.sy, rw, max(1, rw * (fig.flat or 1))) then n = n + 1 end
                end
            end
        end
    end
    for i = n + 1, st.used do st.rings[i]:Hide() end
    st.used = n
end
function V.Build(ui)
    if next(st.btns) then return end
    local D = ns.replayModes
    local Size = ns.ReplaySize
    local list = {}
    for i = 1, #D.order do
        local key = D.order[i]
        local def = D.modes[key]
        st.btns[key] = Size.Tool(ns.T(def.label), ns.T(def.label), ns.T(def.tip), function() V.Set(key) end, i > 1)
        list[i] = st.btns[key]
    end
    st.one = Size.Tool(ns.T(D.modes.normal.label), ns.T("iso.mode"), ns.T(D.modes.normal.tip), function()
        local key = V.Key()
        local next = D.order[1]
        for i = 1, #D.order do
            if D.order[i] == key then next = D.order[i % #D.order + 1] end
        end
        V.Set(next)
    end)
    st.one.label = "normal"
    st.one:Hide()
    Size.Squeeze(list, st.one)
    for i = 1, RING_DRAW do
        local tex = ui.marks:CreateTexture(nil, "BORDER")
        tex:SetTexture(RING)
        Kit.Tint(tex, "sem.rep.tank")
        tex:Hide()
        st.rings[i] = tex
    end
    ui.frame:HookScript("OnHide", function()
        Raid(false, nil)
        st.feedKey = nil
    end)
    ui.frame:HookScript("OnShow", function()
        if st.scene then Apply() end
    end)
    st.def = MO.Def(Saved().mode)
    Paint()
end
function V.Probe()
    return { key = st.def and st.def.key or V.Key(), active = st.active, btns = st.btns, one = st.one, rings = st.rings, used = st.used,
             fk = st.fk, healed = healed, raidMode = st.raidMode }
end
