local ADDON, ns = ...
local format = string.format
local max = math.max
local min = math.min
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local ICON = 18
local SHADOW = 22
local LIFT = 9
local DEPTH_K = 0.12
local DEPTH_FADE = 0.2
local SCALE_MIN = 0.35
local SCALE_MAX = 3
local DEATH_POOL = 64
local DOT_POOL = 320
local DOT = 3
local START_TILT = ns.ReplayIsoCam.START_TILT
local HUGE = 1e9
local STALE_ALPHA = 0.35
local ADD_K = 0.85
local IsoFigs = {}
ns.ReplayIsoFigs = IsoFigs
local Replay = ns.Replay
local Kit = ns.Kit
local LayersView = ns.ReplayLayersView
local Follow = ns.ReplayFollow
local Figs = ns.ReplayFigs
local Shield = ns.ReplayShield
local Geo = ns.ReplayGeo
local Realm = ns.ReplayRealmView
local Soul = ns.ReplaySoulView
local ui
local run
local cam
local strips, stripData, dots, figs, deathTex = {}, {}, {}, {}, {}
local order, depth = {}, {}
local afigs, all = {}, {}
local addList = { x = {}, y = {}, icon = {}, chase = {}, hp = {}, debuff = {} }
local addState = { dead = false, hp = 1, stale = false, speed = 0, vis = true }
Figs.BindAdds(afigs)
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function NewFigure(parent)
    local fig = CreateFrame("Frame", nil, parent)
    fig:SetWidth(SHADOW)
    fig:SetHeight(SHADOW * START_TILT)
    Figs.Build(fig)
    fig.shown = false
    fig.sx, fig.sy, fig.scale, fig.kz = 0, 0, 1, 1
    LayersView.Attach(fig)
    Follow.Attach(fig)
    fig:Hide()
    return fig
end
local function ConfigFigure(fig, tr, scene)
    fig.isBoss = tr == nil
    fig.sQ, fig.mQ, fig.rank, fig.sDead = nil, nil, nil, nil
    if tr then
        fig.name = tr.name
        fig.cr, fig.cg, fig.cb = Kit.ClassColor(tr.class)
        LayersView.Role(fig, tr.class, run.roles[tr.name])
        Figs.Config(fig, tr.class, run.roles[tr.name])
    else
        LayersView.Clear(fig)
        fig.name = format(ns.T("iso.boss"), scene.bossName or ns.EncName(scene.fight.boss))
        fig.cr, fig.cg, fig.cb = Kit.Color("sem.lane.boss")
        Figs.Config(fig, nil, "boss")
    end
end
local Parts = Figs.Parts
local function DrawFigure(fig, s, sx, sy, scale, flat, elapsed, k)
    scale = scale * Figs.Grow(fig, elapsed)
    Figs.Sprite(fig, s, scale, flat, elapsed)
    fig.baseA = ((s.stale or s.ghost) and STALE_ALPHA or 1) * (run.focusA[k] or 1)
    fig:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
    fig.sx, fig.sy, fig.scale = sx, sy, scale
    if not fig.shown then
        fig.shown = true
        fig:Show()
    end
    Parts(fig, true, not s.dead)
end
local function HideFigure(fig)
    if fig.shown then
        fig.shown = false
        fig:Hide()
    end
end
local function SortFigures(count)
    for i = 2, count do
        local v = order[i]
        local d = depth[v]
        local j = i - 1
        while j >= 1 and depth[order[j]] > d do
            order[j + 1] = order[j]
            j = j - 1
        end
        order[j + 1] = v
    end
    local base = run.levelBase
    for r = 1, count do
        local fig = all[order[r]]
        if fig.rank ~= r then
            fig.rank = r
            fig:SetFrameLevel(base + r * 2)
        end
    end
end
local function DepthScale(sy, k)
    local fade = run.flat and 0 or max(0, 1 - cam.persp / DEPTH_FADE)
    local lean = 1 + DEPTH_K * fade * Clamp(sy / (cam.h / 2), -1, 1)
    return Clamp(run.figScale * k * lean, SCALE_MIN, SCALE_MAX)
end
local function PlaceAdds(scene, base, elapsed)
    local na = LayersView.Adds(scene, run.t, addList)
    local hw, hh = cam.w / 2, cam.h / 2
    local total, hidden = base, 0
    for j = 1, max(na, #afigs) do
        local fig = afigs[j]
        if not fig and j <= na then
            fig = NewFigure(ui.view)
            afigs[j] = fig
        end
        if fig then
            total = total + 1
            all[total] = fig
            local sx, sy, kz = 0, 0, 0
            if j <= na then
                local x, y, lift = Geo.Where(cam, scene, addList.x[j], addList.y[j])
                sx, sy, kz = Replay.Project(cam, x, y)
                sy = sy - lift
                Figs.ConfigAdd(fig, addList.icon[j], addList.hp[j] ~= nil)
                addState.stale = addList.chase[j]
                addState.hp = addList.hp[j] or 1
            end
            local scale = kz > 0 and DepthScale(sy, kz) * ADD_K or 0
            if j <= na and kz > 0 and sx > -hw + 2 and sx < hw - 2 and sy < hh - 2 and sy - (ICON + LIFT) * scale > -hh then
                fig.kz = kz
                DrawFigure(fig, addState, sx, sy, scale, min(1, cam.tilt * kz), elapsed, total)
                LayersView.AddDebuff(fig, addList.debuff[j])
                depth[total] = sy
            else
                HideFigure(fig)
                LayersView.AddDebuff(fig, false)
                depth[total] = -HUGE
                hidden = hidden + 1
            end
        end
    end
    run.addHidden = hidden
    LayersView.stats.adds = na
    return total
end
local function PlaceFigures(elapsed)
    local scene = run.scene
    local n = #scene.tracks
    local hw, hh = cam.w / 2, cam.h / 2
    local shown = 0
    for k = 1, n + 1 do
        local fig = figs[k]
        all[k] = fig
        local s = k <= n and scene.states[k] or scene.bossState
        local sx, sy, kz = 0, 0, 0
        if s.vis then
            local x, y, lift = Geo.Where(cam, scene, s.x, s.y)
            sx, sy, kz = Replay.Project(cam, x, y)
            sy = sy - lift
        end
        local scale = kz > 0 and DepthScale(sy, kz) or 0
        if kz > 0 and sx > -hw + 2 and sx < hw - 2 and sy < hh - 2 and sy - (ICON + LIFT) * scale > -hh then
            fig.kz = kz
            DrawFigure(fig, s, sx, sy, scale, min(1, cam.tilt * kz), elapsed, k)
            Shield.Place(fig, elapsed)
            shown = shown + 1
            depth[k] = sy
        else
            HideFigure(fig)
            depth[k] = -HUGE
        end
    end
    local total = PlaceAdds(scene, n + 1, elapsed)
    if run.orderN ~= total then
        run.orderN = total
        for k = 1, total do order[k] = k end
        for k = total + 1, #order do order[k] = nil end
    end
    SortFigures(total)
    Figs.Alpha(all, order, total)
    run.shown = shown + (total - n - 1 - run.addHidden)
end
local function PlaceFloor()
    local scene = run.scene
    if Geo.Place(cam, scene.room, scene.ppy) then
        for k = 1, run.stripUsed do strips[k]:Hide() end
        run.stripUsed = 0
        for i = 1, #dots do dots[i]:Hide() end
        return
    end
    local used = 0
    if scene.room and run.hasTex then
        used = Replay.Strips(cam, scene.room, stripData)
        for k = 1, used do
            local tex, d = strips[k], stripData[k]
            tex:SetPoint("TOPLEFT", ui.view, "CENTER", d.l, -d.t)
            tex:SetWidth(d.w)
            tex:SetHeight(d.h)
            tex:SetTexCoord(d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])
            tex:Show()
        end
    end
    for k = used + 1, run.stripUsed do strips[k]:Hide() end
    run.stripUsed = used
    local shown = 0
    if not (scene.room and run.hasTex) then
        local hw, hh = cam.w / 2, cam.h / 2
        for i = 1, min(#scene.gx, DOT_POOL) do
            local sx, sy, k = Replay.Project(cam, scene.gx[i], scene.gy[i])
            if k > 0 and sx > -hw and sx < hw and sy > -hh and sy < hh then
                shown = shown + 1
                local dot = dots[shown]
                dot:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
                dot:Show()
            end
        end
    end
    for i = shown + 1, #dots do dots[i]:Hide() end
end
local function PlaceDeaths()
    local list = run.scene.deaths
    local t = run.t
    local started, gone = 0, 0
    while started < #list and list[started + 1].t <= t do
        started = started + 1
        local to = list[started].to
        if to and to <= t then gone = gone + 1 end
    end
    local key = started * 4096 + gone
    if key == run.deathShown and not run.marksDirty then return end
    run.deathShown = key
    local hw, hh = cam.w / 2, cam.h / 2
    local used = 0
    for i = 1, started do
        local d = list[i]
        if used < DEATH_POOL and not (d.to and d.to <= t) then
            used = used + 1
            local tex = deathTex[used]
            local sx, sy, k = Replay.Project(cam, d.x, d.y)
            if k > 0 and sx > -hw and sx < hw and sy > -hh and sy < hh then
                local size = Clamp(12 * run.figScale * k, 8, 40)
                tex:SetWidth(size)
                tex:SetHeight(size)
                tex:SetPoint("CENTER", ui.view, "CENTER", sx, -sy)
                tex.mark = d
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
    for i = used + 1, #deathTex do deathTex[i]:Hide() end
end
local function UseFloor(room)
    run.hasTex = false
    if room then
        local path = ROOM_PATH .. room.tex
        run.hasTex = true
        for k = 1, #strips do
            if not strips[k]:SetTexture(path) then run.hasTex = false end
        end
    end
    for k = 1, run.stripUsed do strips[k]:Hide() end
    run.stripUsed = 0
    Geo.Use(room)
    if not room then
        ui.hint:SetText(ns.T("iso.notex"))
        ui.hint:Show()
    elseif not run.hasTex then
        ui.hint:SetText(ns.T("iso.notexfile"))
        ui.hint:Show()
    else
        ui.hint:Hide()
    end
end
local function BuildPools()
    local view = ui.view
    for k = 1, Replay.STRIPS do
        local tex = view:CreateTexture(nil, "BORDER")
        tex:Hide()
        strips[k] = tex
    end
    for i = 1, DOT_POOL do
        local dot = view:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(CIRCLE)
        Kit.Tint(dot, "sem.rep.tick")
        dot:SetWidth(DOT)
        dot:SetHeight(DOT)
        dot:Hide()
        dots[i] = dot
    end
    LayersView.Build(view, ui.marks)
    Realm.Build(view, ui.marks)
    ns.ReplaySwarmView.Build(view, ui.marks)
    ns.ReplayOozeView.Build(view, ui.marks)
    ns.ReplayClassView.Build(view, ui.marks)
    ns.ReplaySpreadView.Build(view, ui.marks)
    ns.ReplayCueView.Build(view, ui.marks)
    ns.ReplayArrowsView.Build(view, ui.marks)
    Soul.Build(view, ui.top)
    for i = 1, DEATH_POOL do
        local tex = ui.marks:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(MARKS)
        tex:SetTexCoord(0.5, 0.75, 0.25, 0.5)
        tex:Hide()
        deathTex[i] = tex
    end
    for k = 1, 26 do figs[k] = NewFigure(view) end
end
function IsoFigs.Bind(s)
    ui, run, cam = s.ui, s.run, s.cam
end
IsoFigs.figs = figs
IsoFigs.afigs = afigs
IsoFigs.order = order
IsoFigs.strips = strips
IsoFigs.dots = dots
IsoFigs.deathTex = deathTex
IsoFigs.NewFigure = NewFigure
IsoFigs.ConfigFigure = ConfigFigure
IsoFigs.HideFigure = HideFigure
IsoFigs.PlaceFigures = PlaceFigures
IsoFigs.PlaceFloor = PlaceFloor
IsoFigs.PlaceDeaths = PlaceDeaths
IsoFigs.UseFloor = UseFloor
IsoFigs.BuildPools = BuildPools
