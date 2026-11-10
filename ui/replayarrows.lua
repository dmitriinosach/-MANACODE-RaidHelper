local ADDON, ns = ...
local min = math.min
local sqrt = math.sqrt
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local LINE = ART .. "line"
local CONE = ART .. "cone"
local ARROW_DRAW = 30
local BOSS_DRAW = 4
local ICON_DRAW = 5
local LINE_W = 2
local HEAD_L = 10
local HEAD_W = 9
local GAP = 8
local SIDE = 3
local MIN_LEN = 14
local ICON = 14
local ALL_A = 0.55
local DIM_A = 0.18
local MODES = { all = true, focus = true, off = true }
local V = {}
ns.ReplayArrowsView = V
local Kit = ns.Kit
local RD = ns.ReplayDraw
local Affine = RD.Affine
local Replay = ns.Replay
local AR = ns.ReplayArrows
local shafts, heads, icons = {}, {}, {}
local bossIdx = {}
local used = { arrow = 0, icon = 0 }
local view
local hw, hh = 0, 0
local ICON_TC = { 0.07, 0.07, 0.07, 0.93, 0.93, 0.07, 0.93, 0.93 }
local st = { focus = nil, data = nil, boss = false, bossK = 1 }
local probe = { arrows = 0, heal = 0, boss = 0, icons = 0, toBoss = 0, toAdd = 0, short = 0, off = 0 }
local iconOf = {}
local Tex = RD.Tex
function V.Build(v, layer)
    view = v
    for i = 1, ARROW_DRAW + BOSS_DRAW do
        shafts[i] = Tex(layer, LINE, "BORDER")
        heads[i] = Tex(layer, CONE, "BORDER")
    end
    for i = 1, ICON_DRAW do
        icons[i] = layer:CreateTexture(nil, "ARTWORK")
        icons[i]:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icons[i]:SetWidth(ICON)
        icons[i]:SetHeight(ICON)
        icons[i].size = ICON
        icons[i]:Hide()
    end
end
local function HideRange(list, from, to)
    for i = from + 1, to do list[i]:Hide() end
end
local function HideAll()
    HideRange(shafts, 0, used.arrow)
    HideRange(heads, 0, used.arrow)
    HideRange(icons, 0, used.icon)
    used.arrow, used.icon = 0, 0
    probe.arrows, probe.heal, probe.boss, probe.icons, probe.toBoss, probe.toAdd = 0, 0, 0, 0, 0, 0
end
function V.Use(scene)
    st.data = scene and scene.layers and scene.layers.arrows or nil
    if not view then return end
    HideRange(shafts, 0, #shafts)
    HideRange(heads, 0, #heads)
    HideRange(icons, 0, #icons)
    for i = 1, #icons do icons[i].tex = nil end
    used.arrow, used.icon = 0, 0
end
function V.Focus(name)
    st.focus = name
end
local Saved = RD.Saved
function V.Mode()
    local m = Saved().arrows
    return MODES[m] and m or "all"
end
function V.SetMode(m)
    Saved().arrows = MODES[m] and m ~= "all" and m or nil
    if m == "off" and view then HideAll() end
end
function V.SetBoss(force, k)
    st.boss = force and true or false
    st.bossK = k or 1
end
local function PutAffine(tex, ox, oy, ux, uy, vx, vy)
    return Affine(tex, view, hw, hh, ox, oy, ux, uy, vx, vy)
end
function V.Arrow(shaft, head, ax, ay, bx, by, w, hl, hwid, gap, side)
    local dx, dy = bx - ax, by - ay
    local d = sqrt(dx * dx + dy * dy)
    gap, hl = min(gap, d * 0.2), min(hl, d * 0.35)
    hwid = min(hwid, hl)
    if d < MIN_LEN then
        shaft:Hide()
        head:Hide()
        probe.short = probe.short + 1
        return false, 0, 0
    end
    local ux, uy = dx / d, dy / d
    local ox, oy = -uy * side, ux * side
    local tx, ty = bx - ux * gap + ox, by - uy * gap + oy
    local hx, hy = tx - ux * hl, ty - uy * hl
    local sx, sy = ax + ux * gap + ox, ay + uy * gap + oy
    local nx, ny = -uy * w * 2, ux * w * 2
    local wx, wy = -uy * hwid, ux * hwid
    if not PutAffine(shaft, sx - nx / 2, sy - ny / 2, hx - sx, hy - sy, nx, ny) then
        head:Hide()
        probe.off = probe.off + 1
        return false, 0, 0
    end
    if not PutAffine(head, tx - wx / 2, ty - wy / 2, hx - tx, hy - ty, wx, wy) then
        shaft:Hide()
        return false, 0, 0
    end
    return true, (sx + hx) / 2, (sy + hy) / 2
end
local Screen = RD.Screen
local function Target(scene, cam, tg, t)
    local x, y
    if type(tg) == "number" then
        local s = tg == 0 and scene.bossState or scene.states[tg]
        if not (s and s.vis) or s.dead then return 0, 0, false end
        x, y = s.x, s.y
    else
        if tg.from > t or tg.to <= t then return 0, 0, false end
        x, y = Replay.PosHold(tg, t, math.huge)
        if not x or x < 0 then return 0, 0, false end
    end
    local sx, sy, k = Screen(cam, scene, x, y)
    return sx, sy, k > 0
end
local function IconOf(id)
    if not id or id == 0 then return nil end
    local tex = iconOf[id]
    if tex == nil then
        tex = ns.SpellIcon(id) or false
        iconOf[id] = tex
    end
    return tex or nil
end
local function PutIcon(ni, tex, x, y, size)
    local ic = tex and icons[ni + 1]
    if not ic then return ni end
    if ic.tex ~= tex then
        ic.tex = tex
        ic:SetTexture(tex)
    end
    local half = (size or ICON) / 2
    if not Kit.Crop(ic, view, hw, hh, x - half, y - half, x + half, y + half, ICON_TC) then return ni end
    return ni + 1
end
function V.Place(scene, cam, t)
    if not view then return end
    local data = st.data
    local mode = V.Mode()
    local off = mode == "off"
    if not data or (off and not st.boss) then
        if used.arrow + used.icon > 0 then HideAll() end
        return
    end
    hw, hh = cam.w / 2, cam.h / 2
    local focus = st.focus
    probe.short, probe.off = 0, 0
    local na, ni, nh, nb, nTo, nAdd = 0, 0, 0, 0, 0, 0
    local lanes = data.lanes
    for k = 1, off and 0 or #scene.tracks do
        local name = scene.tracks[k].name
        local mine = name == focus
        local lane = (mode == "all" or mine) and lanes[k]
        local s = lane and scene.states[k]
        if s and s.vis and not s.dead and na < ARROW_DRAW then
            local tg, heal = AR.At(lane, t)
            if tg and tg ~= k then
                local bx, by, okB = Target(scene, cam, tg, t)
                local ax, ay, kA = Screen(cam, scene, s.x, s.y)
                if okB and kA > 0 then
                    local ok, mx, my = V.Arrow(shafts[na + 1], heads[na + 1], ax, ay, bx, by,
                        mine and LINE_W + 1 or LINE_W, HEAD_L, HEAD_W, GAP, SIDE)
                    if ok then
                        na = na + 1
                        local r, g, b, a = Kit.Color(heal and "sem.rep.aimHeal" or "sem.rep.aimHit")
                        a = a * (mine and 1 or focus and DIM_A or ALL_A)
                        shafts[na]:SetVertexColor(r, g, b, a)
                        heads[na]:SetVertexColor(r, g, b, a)
                        if heal then nh = nh + 1 end
                        if tg == 0 then nTo = nTo + 1 elseif type(tg) == "table" then nAdd = nAdd + 1 end
                    end
                end
            end
        end
    end
    local b = scene.bossState
    if b and b.vis and not b.dead then
        local m = AR.BossAt(data.boss, t, bossIdx, BOSS_DRAW)
        if m > 0 then
            local ax, ay, kA = Screen(cam, scene, b.x, b.y)
            for q = 1, m do
                local j = bossIdx[q]
                local tk = data.boss.G[j]
                local bx, by, okB = Target(scene, cam, tk, t)
                if kA > 0 and okB then
                    local ok, mx, my
                    if tk == b.hk then
                        ok, mx, my = true, (ax + bx) / 2, (ay + by) / 2
                    else
                        local w = st.boss and (LINE_W + 1) * st.bossK or LINE_W + 1
                        ok, mx, my = V.Arrow(shafts[na + 1], heads[na + 1], ax, ay, bx, by, w, HEAD_L, HEAD_W,
                            GAP, SIDE)
                        if ok then
                            na = na + 1
                            local r, g, bb, a = Kit.Color("sem.rep.aimBoss")
                            shafts[na]:SetVertexColor(r, g, bb, a)
                            heads[na]:SetVertexColor(r, g, bb, a)
                        end
                    end
                    if ok then
                        nb = nb + 1
                        ni = PutIcon(ni, IconOf(data.boss.I[j]), mx, my, st.boss and ICON * st.bossK or ICON)
                    end
                end
            end
        end
    end
    HideRange(shafts, na, used.arrow)
    HideRange(heads, na, used.arrow)
    HideRange(icons, ni, used.icon)
    used.arrow, used.icon = na, ni
    probe.arrows, probe.heal, probe.boss, probe.icons, probe.toBoss, probe.toAdd = na, nh, nb, ni, nTo, nAdd
end
function V.Probe()
    return probe
end
