local ADDON, ns = ...
local format = string.format
local max = math.max
local min = math.min
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi
local ROOM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\art\\rooms\\"
local RIM_TEX = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\rim"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MAP = 136
local PAD = 6
local TITLE_H = 14
local DOTS = 40
local DOT = 9
local BAR_W = 14
local BAR_H = 3
local HOLD = 2
local LOW = 0.35
local RING = 0.6
local V = {}
ns.ReplaySoulView = V
local Kit = ns.Kit
local Replay = ns.Replay
local st = { dots = {}, inside = {}, list = {}, byName = {}, n = 0, shown = 0, placed = 0, hidden = 0, title = nil,
             mode = "soul", mapKey = nil, throne = {}, t = 0 }
local box, map, rim, title
local function NewDot(parent)
    local d = {}
    d.dot = parent:CreateTexture(nil, "OVERLAY")
    d.dot:SetTexture(CIRCLE)
    d.dot:SetWidth(DOT)
    d.dot:SetHeight(DOT)
    d.bg = parent:CreateTexture(nil, "OVERLAY")
    Kit.Paint(d.bg, "sem.rep.bar.bg")
    d.bg:SetWidth(BAR_W)
    d.bg:SetHeight(BAR_H)
    d.fill = parent:CreateTexture(nil, "OVERLAY")
    d.fill:SetHeight(BAR_H - 1)
    d.fill:SetPoint("LEFT", d.bg, "LEFT", 0, 0)
    d.dot:Hide()
    d.bg:Hide()
    d.fill:Hide()
    return d
end
local function HideDot(d)
    d.dot:Hide()
    d.bg:Hide()
    d.fill:Hide()
end
function V.Build(view, top)
    box = CreateFrame("Frame", nil, top)
    box:SetFrameLevel(top:GetFrameLevel() + 1)
    box:SetWidth(MAP + PAD * 2)
    box:SetHeight(MAP + PAD * 3 + TITLE_H)
    box:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", PAD, PAD)
    Kit.Skin(box, "panel")
    title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", box, "TOPLEFT", PAD + 2, -PAD)
    title:SetWidth(MAP)
    title:SetJustifyH("LEFT")
    Kit.Title(title)
    map = box:CreateTexture(nil, "ARTWORK")
    map:SetWidth(MAP)
    map:SetHeight(MAP)
    map:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", PAD, PAD)
    rim = box:CreateTexture(nil, "ARTWORK")
    rim:SetTexture(RIM_TEX)
    Kit.Tint(rim, "sem.rep.soulRim")
    rim:SetAllPoints(map)
    for i = 1, DOTS do st.dots[i] = NewDot(box) end
    box:Hide()
end
local function SetMap(room)
    local key = room and room.tex or ""
    if st.mapKey == key then return end
    st.mapKey = key
    if room and map:SetTexture(ROOM_PATH .. room.tex) then
        local r = Replay.RIM
        map:SetTexCoord(0.5 - r, 0.5 + r, 0.5 - r, 0.5 + r)
        Kit.Hue(map, "sem.rep.icon")
    else
        map:SetTexture(CIRCLE)
        map:SetTexCoord(0, 1, 0, 1)
        Kit.Hue(map, "sem.rep.soulBg")
    end
end
function V.Use(scene)
    st.scene, st.n, st.shown, st.placed, st.hidden, st.title = scene, 0, 0, 0, 0, nil
    st.mode, st.mapKey = "soul", nil
    st.byName = {}
    for k = 1, scene and #scene.tracks or 0 do st.byName[scene.tracks[k].name] = k end
    if not box then return end
    for i = 1, #st.dots do
        HideDot(st.dots[i])
        st.dots[i].key = nil
    end
    box:Hide()
end
function V.Inside(scene, t, inside, list)
    return Replay.Inside(scene, t, inside, list)
end
function V.Sample(scene, t)
    local n = V.Inside(scene, t, st.inside, st.list)
    st.n, st.hidden = n, 0
    if n == 0 then return end
    for k = 1, #scene.tracks do
        local s = scene.states[k]
        if st.inside[scene.tracks[k].name] then
            if s.vis then st.hidden = st.hidden + 1 end
            s.vis = false
        end
    end
end
function V.Hp(scene, name, t)
    local k = st.byName[name]
    local tr = k and scene.tracks[k]
    if not tr then return 1, false, 0 end
    local i = Replay.IndexAt(tr, t)
    if i < 1 then return 1, false, 0 end
    local dz = tr.dz[i] or 0
    return tr.hp[i] or 1, dz > 0, dz
end
local function Ring(slot, count)
    local a = 2 * pi * (slot - 1) / max(1, count) - pi / 2
    return cos(a) * RING, sin(a) * RING
end
function V.Fill(alt, t)
    local base, room = alt.base, alt.room
    local n = st.n
    for i = 1, n do
        local name = st.list[i]
        local k = alt.byName[name]
        local s = k and alt.states[k]
        if s and not s.vis then
            local u, v = Ring(i, n)
            local hp, dead, since = V.Hp(base, name, t)
            s.vis, s.stale, s.speed = true, true, 0
            s.x, s.y = room.cx + u * room.r, room.cy + v * room.r
            s.hp, s.dead, s.deadFor = hp, dead, dead and t - since or 0
        end
    end
end
local function WhereSoul(name, slot, count)
    local alt = st.scene and st.scene.alt
    local k = alt and alt.byName[name]
    local tr = k and alt.tracks[k]
    if tr and tr.n > 0 then
        local x, y = Replay.PosHold(tr, st.t, HOLD)
        if x >= 0 then
            local room = alt.room
            local fx, fy = Replay.FixPoint(room, x, y)
            local u, v = (fx - room.cx) / room.r, (fy - room.cy) / room.r
            local d = sqrt(u * u + v * v)
            if d > 1 then u, v = u / d, v / d end
            return u, v, true
        end
    end
    local u, v = Ring(slot, count)
    return u, v, false
end
local function WhereThrone(scene, k)
    local s, room = scene.states[k], scene.room
    local x, y, cx, cy, r = s.x, s.y, scene.cx, scene.cy, scene.r
    if room then
        x, y = Replay.FixPoint(room, x, y)
        cx, cy, r = room.cx, room.cy, room.r
    end
    local u, v = (x - cx) / max(1, r), (y - cy) / max(1, r)
    local d = sqrt(u * u + v * v)
    if d > 1 then u, v = u / d, v / d end
    return u, v
end
local function Paint(d, scene, name, hp, dead)
    local key = dead and "dead" or (hp <= LOW and "low" or "ok")
    if d.key == key .. name then return end
    d.key = key .. name
    if dead then
        Kit.Hue(d.dot, "sem.map.dead")
    else
        local k = st.byName[name]
        local tr = k and scene.tracks[k]
        d.dot:SetVertexColor(Kit.ClassColor(tr and tr.class))
    end
    Kit.Shade(d.fill, key == "low" and "sem.hpLow" or "sem.hpOk")
end
local function PutDot(d, u, v, hp, dead)
    local half = MAP / 2
    d.dot:ClearAllPoints()
    d.dot:SetPoint("CENTER", map, "CENTER", u * half, -v * half)
    d.dot:Show()
    if dead then
        d.bg:Hide()
        d.fill:Hide()
        return
    end
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOP", d.dot, "BOTTOM", 0, -1)
    d.bg:Show()
    d.fill:SetWidth(max(1, BAR_W * min(1, max(0, hp))))
    d.fill:Show()
end
local function Open(n, key, room)
    if n == 0 then
        if box:IsShown() then box:Hide() end
        st.shown, st.placed = 0, 0
        return false
    end
    SetMap(room)
    if st.title ~= key .. n then
        st.title = key .. n
        st.text = format(ns.T(key), n)
        title:SetText(st.text)
    end
    if not box:IsShown() then box:Show() end
    return true
end
local function PlaceSoul(scene, t)
    local n = st.n
    st.t = t
    if not Open(n, "iso.soul.title", scene.alt and scene.alt.room) then return end
    local shown, placed = 0, 0
    for i = 1, min(n, DOTS) do
        local name = st.list[i]
        local d = st.dots[i]
        local u, v, ok = WhereSoul(name, i, n)
        local hp, dead = V.Hp(scene, name, t)
        Paint(d, scene, name, hp, dead)
        PutDot(d, u, v, hp, dead)
        shown = shown + 1
        if ok then placed = placed + 1 end
    end
    for i = shown + 1, #st.dots do HideDot(st.dots[i]) end
    st.shown, st.placed = shown, placed
end
local function PlaceThrone(scene, t)
    local list = st.throne
    for i = #list, 1, -1 do list[i] = nil end
    for k = 1, #scene.tracks do
        if not st.inside[scene.tracks[k].name] then list[#list + 1] = k end
    end
    local n = #list
    if not Open(n, "iso.throne.title", scene.room) then return end
    local shown, placed = 0, 0
    for i = 1, min(n, DOTS) do
        local k = list[i]
        local name, d = scene.tracks[k].name, st.dots[i]
        local u, v
        if scene.states[k].vis then
            u, v = WhereThrone(scene, k)
            placed = placed + 1
        else
            u, v = Ring(i, n)
        end
        local hp, dead = V.Hp(scene, name, t)
        Paint(d, scene, name, hp, dead)
        PutDot(d, u, v, hp, dead)
        shown = shown + 1
    end
    for i = shown + 1, #st.dots do HideDot(st.dots[i]) end
    st.shown, st.placed = shown, placed
end
function V.Place(scene, shown, t)
    if not box then return end
    local mode = shown ~= scene and "throne" or "soul"
    if st.mode ~= mode then
        st.mode = mode
        for i = 1, #st.dots do st.dots[i].key = nil end
    end
    if mode == "soul" then PlaceSoul(scene, t) else PlaceThrone(scene, t) end
end
function V.Probe()
    return { inside = st.n, shown = st.shown, placed = st.placed, hidden = st.hidden, box = box ~= nil and box:IsShown(),
             title = box ~= nil and box:IsShown() and st.text or nil, list = st.list, mode = st.mode,
             map = st.mapKey }
end
