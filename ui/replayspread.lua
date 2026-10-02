local ADDON, ns = ...
local max = math.max
local min = math.min
local RIM = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\rim"
local RING_DRAW = 30
local MARK_DRAW = 30
local MARK_YD = 1.6
local MAX_PX = 4000
local V = {}
ns.ReplaySpreadView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Core = ns.ReplaySpread
local rings, marks = {}, {}
local used = { ring = 0, mark = 0 }
local view
local hw, hh = 0, 0
local near, bad = {}, {}
local probe = { rings = 0, bad = 0, marks = 0, list = {} }
function V.Build(v, layer)
    view = v
    for i = 1, RING_DRAW do
        local tex = layer:CreateTexture(nil, "BORDER")
        tex:SetTexture(RIM)
        tex:Hide()
        rings[i] = tex
    end
    for i = 1, MARK_DRAW do
        local tex = layer:CreateTexture(nil, "BORDER")
        tex:SetTexture(RIM)
        tex:SetVertexColor(Kit.Color("sem.rep.spreadBad"))
        tex:Hide()
        marks[i] = tex
    end
end
local function HideFrom(n, m)
    for i = n + 1, used.ring do rings[i]:Hide() end
    for i = m + 1, used.mark do marks[i]:Hide() end
    used.ring, used.mark = n, m
end
function V.Use(scene)
    if not view then return end
    used.ring, used.mark = #rings, #marks
    HideFrom(0, 0)
end
local function PutDisc(tex, sx, sy, rw, rh)
    if rw * 2 > MAX_PX or sx + rw < -hw or sx - rw > hw or sy + rh < -hh or sy - rh > hh then
        tex:Hide()
        return false
    end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", view, "CENTER", sx, -sy)
    tex:SetWidth(rw * 2)
    tex:SetHeight(max(1, rh * 2))
    tex:Show()
    return true
end
local function Screen(cam, scene, st)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, st.x, st.y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
local function Ring(tex, cam, scene, st, yd)
    local sx, sy, k = Screen(cam, scene, st)
    if k <= 0 then
        tex:Hide()
        return false, 0
    end
    local rw = yd * scene.ppy * cam.zoom * k
    return PutDisc(tex, sx, sy, rw, rw * min(1, cam.tilt * k)), rw / (scene.ppy * cam.zoom * k)
end
function V.Place(scene, cam, t)
    if not view then return end
    local list = scene.layers and scene.layers.spread
    local n, m, nb = 0, 0, 0
    local plist = probe.list
    if list and #list > 0 then
        hw, hh = cam.w / 2, cam.h / 2
        local states, ppy = scene.states, scene.ppy
        for j in pairs(bad) do bad[j] = nil end
        for i = 1, #list do
            local w = list[i]
            if w.from > t or n >= RING_DRAW then break end
            local st = states[w.k]
            if w.to > t and st and st.vis and not st.dead then
                local cnt = Core.Near(states, w.k, w.r * ppy, near)
                for j = 1, cnt do bad[near[j]] = true end
                local tex = rings[n + 1]
                local ok, yd = Ring(tex, cam, scene, st, w.r)
                if ok then
                    n = n + 1
                    tex:SetVertexColor(Kit.Color(cnt > 0 and "sem.rep.spreadBad" or "sem.rep.spread"))
                    if cnt > 0 then nb = nb + 1 end
                    local e = plist[n] or {}
                    e.k, e.yd, e.bad, e.tex = w.k, yd, cnt > 0, tex
                    plist[n] = e
                end
            end
        end
        for j in pairs(bad) do
            if m >= MARK_DRAW then break end
            if Ring(marks[m + 1], cam, scene, states[j], MARK_YD) then m = m + 1 end
        end
    end
    probe.rings, probe.bad, probe.marks = n, nb, m
    HideFrom(n, m)
end
function V.Probe()
    return probe
end
