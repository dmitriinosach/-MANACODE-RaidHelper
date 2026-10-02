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
local st = { dots = {}, inside = {}, list = {}, byName = {}, n = 0, shown = 0, placed = 0, hidden = 0, title = nil }
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
function V.Use(scene)
    st.scene, st.n, st.shown, st.placed, st.hidden, st.title = scene, 0, 0, 0, 0, nil
    st.byName = {}
    for k = 1, scene and #scene.tracks or 0 do st.byName[scene.tracks[k].name] = k end
    if not box then return end
    for i = 1, #st.dots do
        HideDot(st.dots[i])
        st.dots[i].key = nil
    end
    box:Hide()
    local side = scene and scene.side
    local path = side and ROOM_PATH .. side.room.tex
    if path and map:SetTexture(path) then
        local r = Replay.RIM
        map:SetTexCoord(0.5 - r, 0.5 + r, 0.5 - r, 0.5 + r)
        Kit.Hue(map, "sem.rep.icon")
    else
        map:SetTexture(CIRCLE)
        map:SetTexCoord(0, 1, 0, 1)
        Kit.Hue(map, "sem.rep.soulBg")
    end
end
local function OnSide(scene, name, t)
    local tr = scene.side and scene.side.tracks[name]
    if not tr then return false end
    local x = Replay.PosHold(tr, t, HOLD)
    return x >= 0
end
function V.Inside(scene, t, inside, list)
    for k in pairs(inside) do inside[k] = nil end
    for i = #list, 1, -1 do list[i] = nil end
    local souls = scene.layers and scene.layers.souls
    local waves = souls and souls.waves or {}
    for w = 1, #waves do
        local wave = waves[w]
        if wave.from > t then break end
        if t < wave.to then
            for i = 1, #wave.spans do
                local s = wave.spans[i]
                if s.from <= t and (t < s.to or s.died) and not inside[s.name] then
                    inside[s.name] = true
                    list[#list + 1] = s.name
                end
            end
        end
    end
    local side = scene.side
    if side then
        for name in pairs(side.tracks) do
            if not inside[name] and OnSide(scene, name, t) then
                inside[name] = true
                list[#list + 1] = name
            end
        end
    end
    table.sort(list)
    return #list
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
    if not tr then return 1, false end
    local i = Replay.IndexAt(tr, t)
    if i < 1 then return 1, false end
    return tr.hp[i] or 1, (tr.dz[i] or 0) > 0
end
local function Where(scene, name, t, slot, count)
    local side = scene.side
    local tr = side and side.tracks[name]
    if tr then
        local x, y = Replay.PosHold(tr, t, HOLD)
        if x >= 0 then
            local room = side.room
            local fx, fy = Replay.FixPoint(room, x, y)
            local u, v = (fx - room.cx) / room.r, (fy - room.cy) / room.r
            local d = sqrt(u * u + v * v)
            if d > 1 then u, v = u / d, v / d end
            return u, v, true
        end
    end
    local a = 2 * pi * (slot - 1) / max(1, count) - pi / 2
    return cos(a) * RING, sin(a) * RING, false
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
function V.Place(scene, t)
    if not box then return end
    local n = st.n
    if n == 0 then
        if box:IsShown() then box:Hide() end
        st.shown, st.placed = 0, 0
        return
    end
    if st.title ~= n then
        st.title = n
        title:SetText(format(ns.T("iso.soul.title"), n))
    end
    if not box:IsShown() then box:Show() end
    local half = MAP / 2
    local shown, placed = 0, 0
    for i = 1, min(n, DOTS) do
        local name = st.list[i]
        local d = st.dots[i]
        local u, v, ok = Where(scene, name, t, i, n)
        local hp, dead = V.Hp(scene, name, t)
        Paint(d, scene, name, hp, dead)
        local px, py = u * half, -v * half
        d.dot:ClearAllPoints()
        d.dot:SetPoint("CENTER", map, "CENTER", px, py)
        d.dot:Show()
        if dead then
            d.bg:Hide()
            d.fill:Hide()
        else
            d.bg:ClearAllPoints()
            d.bg:SetPoint("TOP", d.dot, "BOTTOM", 0, -1)
            d.bg:Show()
            d.fill:SetWidth(max(1, BAR_W * min(1, max(0, hp))))
            d.fill:Show()
        end
        shown = shown + 1
        if ok then placed = placed + 1 end
    end
    for i = shown + 1, #st.dots do HideDot(st.dots[i]) end
    st.shown, st.placed = shown, placed
end
function V.Probe()
    return { inside = st.n, shown = st.shown, placed = st.placed, hidden = st.hidden, box = box ~= nil and box:IsShown(),
             title = st.title and format(ns.T("iso.soul.title"), st.title) or nil, list = st.list }
end
