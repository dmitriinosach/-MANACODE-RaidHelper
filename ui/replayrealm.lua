local ADDON, ns = ...
local sqrt = math.sqrt
local floor = math.floor
local cos = math.cos
local sin = math.sin
local max = math.max
local min = math.min
local pi = math.pi
local tconcat = table.concat
local tsort = table.sort
local format = string.format
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local LINE = ART .. "line"
local RIM = ART .. "rim"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MODES = { mine = true, both = true, phys = true, twi = true }
local DEFAULT = "mine"
local ORB_YD = 1.6
local ORB_Z = 2
local BEAM_W = 6
local IDLE_W = 2
local FLASH = 0.8
local FLASH_YD = 2.5
local FLASH_DRAW = 16
local POOL_DRAW = 48
local MAX_PX = 4000
local COUNT_PAD = 8
local COUNT_H = 18
local SW_GAP = 4
local SW_KEY = { "phys", "twi" }
local SW_TEXT = { "iso.world.physN", "iso.world.twiN" }
local V = {}
ns.ReplayRealmView = V
local Kit = ns.Kit
local Replay = ns.Replay
local Core = ns.ReplayRealm
local st = { mode = nil, orbs = {}, beams = {}, flashes = {}, pools = {}, booms = {}, byName = {}, used = 0, usedP = 0,
             usedB = 0, show = { true, true }, inW = { {}, {} }, swText = {}, swTip = {} }
local view
local sw = {}
local hw, hh = 0, 0
local function Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function V.Mode()
    if not st.mode then
        local m = Saved().world
        st.mode = MODES[m or ""] and m or DEFAULT
    end
    return st.mode
end
function V.SetMode(mode)
    if not MODES[mode] then return end
    st.mode = mode
    Saved().world = mode
    if V.onChange then V.onChange() end
end
function V.Has(scene)
    return scene ~= nil and scene.layers ~= nil and scene.layers.realm ~= nil
end
local function Tex(parent, path, layer, token)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(path)
    tex:SetVertexColor(Kit.Color(token))
    tex:Hide()
    return tex
end
function V.Build(v, marks)
    view = v
    for i = 1, POOL_DRAW do st.pools[i] = Tex(marks, CIRCLE, "BACKGROUND", "sem.rep.fire") end
    for i = 1, 4 do st.booms[i] = Tex(marks, RIM, "ARTWORK", "sem.rep.blast") end
    for i = 1, 2 do st.beams[i] = Tex(marks, LINE, "ARTWORK", "sem.rep.cutter") end
    for i = 1, 4 do st.orbs[i] = Tex(marks, CIRCLE, "ARTWORK", "sem.rep.orb") end
    for i = 1, FLASH_DRAW do st.flashes[i] = Tex(marks, RIM, "ARTWORK", "sem.rep.cutterHit") end
    for w = 1, 2 do
        local b = Kit.Button(v)
        b:SetHeight(COUNT_H)
        b:SetWidth(120)
        b:SetFrameLevel(v:GetFrameLevel() + 8)
        b.tipTitle = false
        b.key = SW_KEY[w]
        b.onClick = function() V.SetMode(SW_KEY[w]) end
        b:Hide()
        sw[w] = b
    end
    sw[1]:SetPoint("TOPLEFT", v, "TOPLEFT", COUNT_PAD, -COUNT_PAD)
    sw[2]:SetPoint("LEFT", sw[1], "RIGHT", SW_GAP, 0)
end
local function HideAll()
    for i = 1, #st.beams do st.beams[i]:Hide() end
    for i = 1, #st.orbs do st.orbs[i]:Hide() end
    for i = 1, #st.flashes do st.flashes[i]:Hide() end
    for i = 1, #st.pools do st.pools[i]:Hide() end
    for i = 1, #st.booms do st.booms[i]:Hide() end
    st.used, st.usedP, st.usedB = 0, 0, 0
end
function V.Use(scene)
    if not view then return end
    HideAll()
    for w = 1, #sw do sw[w]:Hide() end
    st.byName, st.counted = {}, nil
    for k = 1, scene and #scene.tracks or 0 do st.byName[scene.tracks[k].name] = k end
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
local function Twilight(scene, name, t)
    return Core.In(scene.layers.realm.spans[name], t)
end
V.Twilight = Twilight
local function RealmOf(R, name, s, t, rec)
    if Core.In(R.spans[name], t) then return 2 end
    if rec and R.p2 and t >= R.p2 and s.stale and not s.dead then return rec == 2 and 1 or 2 end
    return 1
end
local function Recorder(scene, R, t)
    local me = R.me and st.byName[R.me]
    if me then return Core.In(R.spans[R.me], t) and 2 or 1 end
    local twi, phys = 0, 0
    for k = 1, #scene.tracks do
        local s = scene.states[k]
        if s.vis and not s.stale then
            if Twilight(scene, scene.tracks[k].name, t) then twi = twi + 1 else phys = phys + 1 end
        end
    end
    return twi > phys and 2 or 1
end
local function Switch(R, t, shown)
    if #sw == 0 then return end
    if not (R.p2 and t >= R.p2) then
        if st.counted then
            for w = 1, 2 do sw[w]:Hide() end
            st.counted = nil
        end
        return
    end
    local inW = st.inW
    tsort(inW[1])
    tsort(inW[2])
    local key = (shown[1] and "1" or "0") .. (shown[2] and "1" or "0") .. tconcat(inW[1], ",") .. "|" .. tconcat(inW[2], ",")
    local shared = R.shared or {}
    if next(shared) then key = key .. floor(t) end
    if st.counted == key then return end
    st.counted = key
    for w = 1, 2 do
        local b, list = sw[w], inW[w]
        st.swText[w] = format(ns.T(SW_TEXT[w]), #list)
        b.text:SetText(st.swText[w])
        b:SetWidth(b.text:GetStringWidth() + 16)
        local via = {}
        for i = 1, #list do
            if Core.In(shared[list[i]], t) then via[#via + 1] = list[i] end
        end
        local tip = tconcat(list, ", ")
        if #via > 0 then tip = tip .. "\n" .. format(ns.T("iso.world.shared"), tconcat(via, ", ")) end
        st.swTip[w] = tip
        b.tip = tip
        b:SetActive(shown[w])
        b:Show()
    end
end
function V.Sample(scene, t, figs)
    local R = scene.layers and scene.layers.realm
    if not R then
        if st.dusked then
            for k = 1, #figs do ns.ReplayFigs.Dusk(figs[k], false) end
            st.dusked = false
        end
        if st.counted then
            for w = 1, #sw do sw[w]:Hide() end
            st.counted = nil
        end
        return
    end
    st.dusked = true
    local mode = V.Mode()
    local rec = Recorder(scene, R, t)
    local show = st.show
    show[1] = mode == "both" or mode == "phys" or (mode == "mine" and rec == 1)
    show[2] = mode == "both" or mode == "twi" or (mode == "mine" and rec == 2)
    local inW = st.inW
    for w = 1, 2 do
        for i = #inW[w], 1, -1 do inW[w][i] = nil end
    end
    local n = #scene.tracks
    for k = 1, n do
        local s = scene.states[k]
        local name = scene.tracks[k].name
        local w = RealmOf(R, name, s, t, rec)
        if s.vis and not s.dead then inW[w][#inW[w] + 1] = name end
        if not show[w] then s.vis = false end
        if figs[k] then ns.ReplayFigs.Dusk(figs[k], mode == "both" and w == 2) end
    end
    local b = scene.bossState
    local phys, twi = Core.In(R.boss[1], t), Core.In(R.boss[2], t)
    if not phys and not twi then phys = true end
    if not ((phys and show[1]) or (twi and show[2])) then b.vis = false end
    if figs[n + 1] then ns.ReplayFigs.Dusk(figs[n + 1], mode == "both" and twi and not phys) end
    Switch(R, t, show)
end
function V.HideAdd(scene, a)
    local R = scene.layers and scene.layers.realm
    if not R or not a.npc then return false end
    local rd = ns.replayMech.realms[scene.fight.boss]
    if not rd then return false end
    if not st.sets or st.setsOf ~= rd then
        st.sets, st.setsOf = { {}, {} }, rd
        for i = 1, #rd.phys do st.sets[1][rd.phys[i]] = true end
        for i = 1, #rd.twi do st.sets[2][rd.twi[i]] = true end
    end
    for w = 1, 2 do
        if st.sets[w][a.npc] and not st.show[w] then return true end
    end
    return false
end
local function Screen(cam, scene, x, y, z)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = Replay.Project(cam, gx, gy)
    local up = z * scene.ppy * sqrt(max(0, 1 - cam.tilt * cam.tilt)) * cam.zoom
    return sx, sy - lift - up, k
end
local function PlaceCutter(cut, scene, cam, t)
    local burn = Core.Burning(cut, t)
    local a = Core.Angle(cut, t)
    local rw = ORB_YD * scene.ppy * cam.zoom
    local cr, cg, cb, ca = Kit.Color(burn and "sem.rep.cutter" or "sem.rep.cutterIdle")
    for p = 1, 2 do
        local beam = st.beams[p]
        local o1, o2 = st.orbs[p * 2 - 1], st.orbs[p * 2]
        if p > cut.pairs then
            beam:Hide()
            o1:Hide()
            o2:Hide()
        else
            local ang = a + (p - 1) * pi / 2
            local dx, dy = cut.r * cos(ang), cut.r * sin(ang)
            local ax, ay, ak = Screen(cam, scene, cut.cx + dx, cut.cy + dy, ORB_Z)
            local bx, by, bk = Screen(cam, scene, cut.cx - dx, cut.cy - dy, ORB_Z)
            if ak > 0 then PutDisc(o1, ax, ay, rw * ak, rw * ak) else o1:Hide() end
            if bk > 0 then PutDisc(o2, bx, by, rw * bk, rw * bk) else o2:Hide() end
            local lx, ly = bx - ax, by - ay
            local d = sqrt(lx * lx + ly * ly)
            if ak > 0 and bk > 0 and d >= 2 then
                local w = burn and BEAM_W or IDLE_W
                local nx, ny = -ly / d * w, lx / d * w
                beam:SetVertexColor(cr, cg, cb, ca)
                PutAffine(beam, ax - nx / 2, ay - ny / 2, lx, ly, nx, ny)
            else
                beam:Hide()
            end
        end
    end
    local n = 0
    for i = 1, #cut.hits do
        local h = cut.hits[i]
        if h.t > t then break end
        if t - h.t < FLASH and n < FLASH_DRAW then
            local k = st.byName[h.name]
            local s = k and scene.states[k]
            if s and s.vis and s.x >= 0 then
                local sx, sy, kk = Screen(cam, scene, s.x, s.y, 0)
                local r = FLASH_YD * scene.ppy * cam.zoom * kk * (1 + (t - h.t) / FLASH)
                local tex = st.flashes[n + 1]
                if kk > 0 and PutDisc(tex, sx, sy, r, r * min(1, cam.tilt * kk)) then
                    tex:SetAlpha(1 - (t - h.t) / FLASH)
                    n = n + 1
                end
            end
        end
    end
    for i = n + 1, st.used do st.flashes[i]:Hide() end
    st.used = n
end
local function PlacePuddles(list, scene, cam, t)
    local n, nb = 0, 0
    local zoom = cam.zoom
    for i = 1, #list do
        local p = list[i]
        if p.from > t then break end
        if p.to > t and st.show[p.realm] then
            local sx, sy, k = Screen(cam, scene, p.x, p.y, 0)
            if k > 0 then
                local rw = p.r * zoom * k
                local rh = max(1, rw * min(1, cam.tilt * k))
                if n < POOL_DRAW and PutDisc(st.pools[n + 1], sx, sy, rw, rh) then
                    n = n + 1
                    local r, g, b, a = Kit.Color(p.tone)
                    local grow = min(1, (t - p.from) / 0.3)
                    st.pools[n]:SetVertexColor(r, g, b, a * grow)
                end
                if p.flash and t - p.from < p.flash and nb < #st.booms then
                    local f = (t - p.from) / p.flash
                    if PutDisc(st.booms[nb + 1], sx, sy, rw * (1 + f), rh * (1 + f)) then
                        nb = nb + 1
                        st.booms[nb]:SetAlpha(1 - f)
                    end
                end
            end
        end
    end
    for i = n + 1, st.usedP do st.pools[i]:Hide() end
    for i = nb + 1, st.usedB do st.booms[i]:Hide() end
    st.usedP, st.usedB = n, nb
end
function V.Place(scene, cam, t)
    if not view then return end
    local L = scene.layers
    if not (L and L.realm) then
        HideAll()
        return
    end
    hw, hh = cam.w / 2, cam.h / 2
    PlacePuddles(L.puddles or {}, scene, cam, t)
    local cut = L.cutter
    if not cut or not st.show[2] or t < cut.from or t > cut.to then
        for i = 1, #st.beams do st.beams[i]:Hide() end
        for i = 1, #st.orbs do st.orbs[i]:Hide() end
        for i = 1, st.used do st.flashes[i]:Hide() end
        st.used = 0
        return
    end
    PlaceCutter(cut, scene, cam, t)
end
function V.Probe()
    local shown = { beams = 0, orbs = 0, flashes = st.used, pools = st.usedP, booms = st.usedB,
                    show = { st.show[1], st.show[2] }, sw = {} }
    for w = 1, #sw do
        shown.sw[w] = { shown = sw[w]:IsShown(), active = sw[w].active == true, text = st.swText[w], tip = st.swTip[w],
                        btn = sw[w] }
    end
    for i = 1, #st.beams do if st.beams[i]:IsShown() then shown.beams = shown.beams + 1 end end
    for i = 1, #st.orbs do if st.orbs[i]:IsShown() then shown.orbs = shown.orbs + 1 end end
    return shown
end
