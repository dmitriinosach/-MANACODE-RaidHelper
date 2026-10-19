local ADDON, ns = ...
local max = math.max
local min = math.min
local sqrt = math.sqrt
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local LINE = ART .. "line"
local CONE = ART .. "cone"
local ARROW_DRAW = 30
local BOSS_DRAW = 4
local ICON_DRAW = 5
local MAX_PX = 4000
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
local Replay = ns.Replay
local AR = ns.ReplayArrows
local RU = ns.ReplayUnits
local shafts, heads, icons = {}, {}, {}
local bossIdx = {}
local used = { arrow = 0, icon = 0 }
local view
local hw, hh = 0, 0
local st = { focus = nil, data = nil, units = nil }
local probe = { arrows = 0, heal = 0, boss = 0, icons = 0, toBoss = 0, toAdd = 0, short = 0, off = 0 }
local iconOf = {}
local function Tex(layer, path, draw)
    local tex = layer:CreateTexture(nil, draw)
    tex:SetTexture(path)
    tex:Hide()
    return tex
end
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
    st.units = scene and (scene.units or (scene.base and scene.base.units)) or nil
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
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function V.Mode()
    local m = Saved().arrows
    return MODES[m] and m or "all"
end
function V.SetMode(m)
    Saved().arrows = MODES[m] and m ~= "all" and m or nil
    if m == "off" and view then HideAll() end
end
local function Inverse(ox, oy, ux, uy, vx, vy, x, y)
    local det = ux * vy - uy * vx
    if det == 0 then return 0, 0 end
    local dx, dy = x - ox, y - oy
    return (dx * vy - dy * vx) / det, (ux * dy - uy * dx) / det
end
local function PutAffine(tex, ox, oy, ux, uy, vx, vy)
    local l = min(ox, ox + ux, ox + vx, ox + ux + vx)
    local r = max(ox, ox + ux, ox + vx, ox + ux + vx)
    local t = min(oy, oy + uy, oy + vy, oy + uy + vy)
    local b = max(oy, oy + uy, oy + vy, oy + uy + vy)
    if r - l > MAX_PX or b - t > MAX_PX then
        tex:Hide()
        return false
    end
    l, t, r, b = max(l, -hw), max(t, -hh), min(r, hw), min(b, hh)
    if r - l < 1 or b - t < 1 then
        tex:Hide()
        return false
    end
    local ulx, uly = Inverse(ox, oy, ux, uy, vx, vy, l, t)
    local llx, lly = Inverse(ox, oy, ux, uy, vx, vy, l, b)
    local urx, ury = Inverse(ox, oy, ux, uy, vx, vy, r, t)
    local lrx, lry = Inverse(ox, oy, ux, uy, vx, vy, r, b)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", view, "CENTER", l, -t)
    tex:SetWidth(r - l)
    tex:SetHeight(b - t)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    tex:Show()
    return true
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
local function Screen(cam, scene, x, y)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
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
        local _, _, icon = GetSpellInfo(id)
        tex = icon or false
        iconOf[id] = tex
    end
    return tex or nil
end
local function PutIcon(ni, tex, x, y)
    local ic = tex and icons[ni + 1]
    if not ic or x < -hw or x > hw or y < -hh or y > hh then return ni end
    if ic.tex ~= tex then
        ic.tex = tex
        ic:SetTexture(tex)
    end
    ic:ClearAllPoints()
    ic:SetPoint("CENTER", view, "CENTER", x, -y)
    ic:Show()
    return ni + 1
end
local function SpellNow(name, t)
    local u = st.units
    if not u then return nil end
    local rec = RU.CastAt(u.casts and u.casts[name], t)
    if rec and rec.id then return rec.id end
    local ins = u.inst and u.inst[name]
    local j = RU.InstAt(ins, t)
    if j > 0 and t - ins.T[j] < 1 then return ins.R[j] end
    return nil
end
function V.Place(scene, cam, t)
    if not view then return end
    local data = st.data
    local mode = V.Mode()
    if not data or mode == "off" then
        if used.arrow + used.icon > 0 then HideAll() end
        return
    end
    hw, hh = cam.w / 2, cam.h / 2
    local focus = st.focus
    probe.short, probe.off = 0, 0
    local na, ni, nh, nb, nTo, nAdd = 0, 0, 0, 0, 0, 0
    local lanes = data.lanes
    for k = 1, #scene.tracks do
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
                        if mine then ni = PutIcon(ni, IconOf(SpellNow(name, t)), mx, my) end
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
                        ok, mx, my = V.Arrow(shafts[na + 1], heads[na + 1], ax, ay, bx, by, LINE_W + 1, HEAD_L, HEAD_W,
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
                        ni = PutIcon(ni, IconOf(data.boss.I[j]), mx, my)
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
