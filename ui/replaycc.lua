local ADDON, ns = ...
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local CYC_TEX = ART .. "cyclone"
local CYC_SHADE = ART .. "cyclone_shade"
local CYC_N = 8
local CYC_COLS = 4
local CYC_FPS = 10
local CYC_K = 2.6
local CYC_DOWN = 0.25
local PICS = { sheep = ART .. "sheep", frog = ART .. "frog" }
local PIC_K = 1.15
local RING = ART .. "ring128"
local RING_PAD = 5
local LINE = ART .. "line"
local LINE_DRAW = 16
local LINE_W = 3
local LINE_GAP = 10
local LINE_SHOW = 4
local LINE_FADE = 1
local LINE_A = 0.85
local FOE = "sem.rep.ccFoe"
local lines = {}
local V = { stats = { lines = 0, cyc = 0 }, lines = lines }
ns.ReplayCcView = V
local Kit = ns.Kit
local used = 0
local active = {}
local na = 0
function V.Attach(fig)
    local cyc = fig:CreateTexture(nil, "OVERLAY")
    cyc:SetTexture(CYC_TEX)
    Kit.Hue(cyc, "sem.rep.cyclone")
    cyc:Hide()
    fig.ccCyc = cyc
    local shade = fig:CreateTexture(nil, "BORDER")
    shade:SetTexture(CYC_SHADE)
    Kit.Hue(shade, "sem.rep.cycloneShade")
    shade:SetAllPoints(cyc)
    shade:Hide()
    fig.ccShade = shade
    local pic = fig:CreateTexture(nil, "OVERLAY")
    pic:SetPoint("CENTER", fig.icon, "CENTER", 0, 0)
    pic:Hide()
    fig.ccPic = pic
    local ring = fig:CreateTexture(nil, "BORDER")
    ring:SetTexture(RING)
    ring:SetPoint("TOPLEFT", fig, "TOPLEFT", -RING_PAD, RING_PAD)
    ring:SetPoint("BOTTOMRIGHT", fig, "BOTTOMRIGHT", RING_PAD, -RING_PAD)
    ring:Hide()
    fig.ccRing = ring
end
function V.Build(parent)
    for i = 1, LINE_DRAW do
        local tex = parent:CreateTexture(nil, "BORDER")
        tex:SetTexture(LINE)
        tex:Hide()
        lines[i] = tex
    end
end
local function ByColor(scene, by)
    local tr = by and by > 0 and scene.tracks[by]
    if tr and tr.class then return Kit.ClassColor(tr.class) end
    local r, g, b = Kit.Color(FOE)
    return r, g, b
end
function V.Set(fig, scene, kind, by, from)
    if not fig.ccCyc then return end
    if fig.ccKind ~= kind or fig.ccBy ~= by then
        fig.ccKind, fig.ccBy = kind, by
        if kind == "cyclone" then
            fig.ccCyc:Show()
            fig.ccShade:Show()
        else
            fig.ccCyc:Hide()
            fig.ccShade:Hide()
        end
        local pic = PICS[kind or ""]
        if pic then
            fig.ccPic:SetTexture(pic)
            Kit.Hue(fig.ccPic, "sem.rep." .. kind)
            fig.ccPic:Show()
        else
            fig.ccPic:Hide()
        end
        ns.ReplayFigs.Pale(fig, pic ~= nil)
        if kind == "ring" then
            fig.ccRing:SetVertexColor(ByColor(scene, by))
            fig.ccRing:Show()
        else
            fig.ccRing:Hide()
        end
        fig.ccFrame, fig.ccW = nil, nil
    end
    fig.ccFrom = from
    if kind then
        na = na + 1
        active[na] = fig
    end
end
function V.Reset()
    for i = na, 1, -1 do active[i] = nil end
    na = 0
end
local function PlaceCyclone(fig, t)
    local tex = fig.ccCyc
    local iw = fig.icon:GetWidth() or 0
    local w = max(1, floor(iw * CYC_K + 0.5))
    if fig.ccW ~= w then
        fig.ccW = w
        tex:SetWidth(w)
        tex:SetHeight(w)
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOM", fig, "CENTER", 0, -w * CYC_DOWN)
    end
    local f = floor((t - (fig.ccFrom or 0)) * CYC_FPS) % CYC_N
    if f < 0 then f = f + CYC_N end
    if fig.ccFrame ~= f then
        fig.ccFrame = f
        local col, row = f % CYC_COLS, floor(f / CYC_COLS)
        tex:SetTexCoord(col / CYC_COLS, (col + 1) / CYC_COLS, row / 2, (row + 1) / 2)
        fig.ccShade:SetTexCoord(col / CYC_COLS, (col + 1) / CYC_COLS, row / 2, (row + 1) / 2)
    end
end
local function PlacePic(fig)
    local w = max(1, floor((fig.icon:GetWidth() or 0) * PIC_K + 0.5))
    if fig.ccW == w then return end
    fig.ccW = w
    fig.ccPic:SetWidth(w)
    fig.ccPic:SetHeight(w)
end
local function PutLine(a, b, alpha, r, g, bl)
    local tex = lines[used + 1]
    if not tex then return false end
    local dx, dy = b.sx - a.sx, b.sy - a.sy
    local d = sqrt(dx * dx + dy * dy)
    if d < LINE_GAP * 2 + 2 then return false end
    local ux, uy = dx / d, dy / d
    local ox, oy = a.sx + ux * LINE_GAP, a.sy + uy * LINE_GAP
    local len = d - LINE_GAP * 2
    local nx, ny = -uy * LINE_W * 2, ux * LINE_W * 2
    if not ns.ReplayLayersView.Affine(tex, ox - nx / 2, oy - ny / 2, ux * len, uy * len, nx, ny) then return false end
    tex:SetVertexColor(r, g, bl, alpha)
    used = used + 1
    return true
end
function V.Place(scene, t, figs)
    used = 0
    local cyc = 0
    local n = #scene.tracks
    for i = 1, na do
        local fig = active[i]
        if fig.ccKind == "cyclone" and fig.shown then
            PlaceCyclone(fig, t)
            cyc = cyc + 1
        elseif PICS[fig.ccKind] then
            PlacePic(fig)
        end
        local by = fig.ccBy
        local src = by and (by == -1 and figs[n + 1] or by > 0 and figs[by]) or nil
        local age = t - (fig.ccFrom or t)
        if src and src ~= fig and src.shown and fig.shown and age >= 0 and age < LINE_SHOW then
            local a = LINE_A * min(1, (LINE_SHOW - age) / LINE_FADE)
            local r, g, b = ByColor(scene, by)
            PutLine(src, fig, a, r, g, b)
        end
    end
    for i = used + 1, LINE_DRAW do
        if lines[i]:IsShown() then lines[i]:Hide() end
    end
    V.stats.lines, V.stats.cyc = used, cyc
end
local tip = { fig = nil, add = nil, key = nil }
local tipRows = {}
function V.AddHover(scene, fig, t)
    local add = fig and fig.ccAdd
    local n = add and add.ccS and ns.ReplayLayers.AddCc(add, t, tipRows) or 0
    if n == 0 then
        if tip.fig then
            tip.fig, tip.add, tip.key = nil, nil, nil
            Kit.Tip.Hide()
        end
        return
    end
    local key = 0
    local S, F, T, By = add.ccS, add.ccF, add.ccT, add.ccBy
    for i = 1, #S do
        if F[i] <= t and T[i] > t then key = key * 31 % 1000003 + i end
    end
    if tip.fig == fig and tip.add == add and tip.key == key then return end
    tip.fig, tip.add, tip.key = fig, add, key
    local list = ns.replayData.addCcList
    local byK = ns.Replay.ByK(scene)
    local lines = { { kind = "head", left = add.name } }
    for i = 1, #S do
        if F[i] <= t and T[i] > t then
            local who = By[i] or nil
            local k = who and byK[who]
            lines[#lines + 1] = { kind = "row", left = who or "?", class = k and scene.tracks[k].class or nil,
                                  right = ns.SpellName(list[S[i]].name) }
        end
    end
    Kit.Tip.ShowRight(fig, lines)
end
function V.Clear()
    V.Reset()
    for i = 1, LINE_DRAW do lines[i]:Hide() end
    used = 0
end
