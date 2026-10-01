local ADDON, ns = ...
local max = math.max
local min = math.min
local floor = math.floor
local sin = math.sin
local random = math.random
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\replay\\"
local TEX = { dome = ART .. "dome", prism = ART .. "prism", ring = ART .. "ring128" }
local FADE = 0.2
local PAD = 1.14
local WIDTH_K = 1.3
local SHIMMER = 0.12
local SHIMMER_RATE = 3.2
local ASPECT = { dome = 0.9, prism = 0.62 }
local LOW = 0.04
local Shield = {}
ns.ReplayShield = Shield
local Kit = ns.Kit
local lookOf = {}
local lookData
function Shield.Of(i)
    local D = ns.replayData
    if lookData ~= D then
        lookData = D
        lookOf = {}
    end
    local v = lookOf[i]
    if v == nil then
        local def = i > 0 and D.states[i]
        v = def and (D.shields[def.name] or D.shields[def.icon]) or false
        lookOf[i] = v
    end
    return v or nil
end
function Shield.Prio(key)
    local look = key and ns.replayData.looks[key]
    return look and look.prio or 0
end
function Shield.Build(fig)
    fig.dome = fig:CreateTexture(nil, "OVERLAY")
    fig.dome:Hide()
    fig.domePh = random() * 6.28
end
function Shield.Reset(fig)
    fig.look, fig.domeK, fig.domeLook, fig.domeKey, fig.domeA = nil, nil, nil, nil, nil
    if fig.domeOn then
        fig.domeOn = false
        fig.dome:Hide()
    end
end
local function Look(fig, key)
    local look = ns.replayData.looks[key]
    if fig.domeTex ~= look.tex then
        fig.domeTex = look.tex
        fig.dome:SetTexture(TEX[look.tex])
        if look.tex == "prism" then
            fig.dome:SetTexCoord(0, 0.5, 0, 1)
        else
            fig.dome:SetTexCoord(0, 1, 0, 1)
        end
        fig.domeKey = nil
    end
    return look
end
local function Geometry(fig, look)
    local w, flat = fig.w or 0, fig.flat or 1
    local base = w * flat / 2
    local W, H, y
    if look.tex == "ring" then
        W = w * look.k
        H = max(2, W * flat)
        y = 0
    else
        local top = fig.top or base
        if fig.modelOn and fig.model then
            top = max(top, fig.model:GetHeight())
            w = max(w, fig.model:GetWidth())
        end
        H = max((top + base) * PAD, w)
        W = max(w * WIDTH_K, H * (ASPECT[look.tex] or 1)) * look.k
        H = H * look.k
        y = H / 2 - base - H * LOW
    end
    local key = floor(W * 2) + floor(H * 2) * 4096 + floor(y * 2) * 16777216
    if fig.domeKey == key then return end
    fig.domeKey = key
    local dome = fig.dome
    dome:ClearAllPoints()
    dome:SetWidth(max(1, W))
    dome:SetHeight(max(1, H))
    dome:SetPoint("CENTER", fig, "CENTER", 0, y)
end
function Shield.Place(fig, elapsed)
    local dome = fig.dome
    if not dome then return end
    local want = (fig.look and not fig.sDead) and 1 or 0
    local k = fig.domeK or 0
    if k ~= want then
        local step = max(0, elapsed or 0) / FADE
        if k < want then k = min(want, k + step) else k = max(want, k - step) end
        fig.domeK = k
    end
    if fig.look then fig.domeLook = fig.look end
    if k <= 0 or not fig.domeLook then
        if fig.domeOn then
            fig.domeOn = false
            dome:Hide()
        end
        return
    end
    local look = Look(fig, fig.domeLook)
    Geometry(fig, look)
    local wave = sin(GetTime() * SHIMMER_RATE + (fig.domePh or 0))
    local _, _, _, a0 = Kit.Color(look.tone)
    local a = floor(a0 * k * (1 - SHIMMER + SHIMMER * wave) * 100 + 0.5) / 100
    if fig.domeA ~= a or not fig.domeOn then
        fig.domeA = a
        Kit.Hue(dome, look.tone, a)
    end
    if not fig.domeOn then
        fig.domeOn = true
        dome:Show()
    end
end
function Shield.Probe(fig)
    return { look = fig.look, shown = fig.domeOn or false, k = fig.domeK or 0, tex = fig.domeTex, a = fig.domeA }
end
