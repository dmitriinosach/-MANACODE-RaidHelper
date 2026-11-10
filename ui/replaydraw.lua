local _, ns = ...
local max = math.max
local min = math.min
local RD = {}
ns.ReplayDraw = RD
RD.MAX_PX = 4000
local MAX_PX = RD.MAX_PX
function RD.Saved()
    local settings = ns.GetDB().settings
    if type(settings.iso) ~= "table" then settings.iso = {} end
    return settings.iso
end
function RD.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
function RD.Tex(layer, path, draw, token)
    local tex = layer:CreateTexture(nil, draw or "BACKGROUND")
    tex:SetTexture(path)
    if token then tex:SetVertexColor(ns.Kit.Color(token)) end
    tex:Hide()
    return tex
end
function RD.Screen(cam, scene, x, y)
    local gx, gy, lift = ns.ReplayGeo.Where(cam, scene, x, y)
    local sx, sy, k = ns.Replay.Project(cam, gx, gy)
    return sx, sy - lift, k
end
local function Inverse(ox, oy, ux, uy, vx, vy, x, y)
    local det = ux * vy - uy * vx
    if det == 0 then return 0, 0 end
    local dx, dy = x - ox, y - oy
    return (dx * vy - dy * vx) / det, (ux * dy - uy * dx) / det
end
RD.Inverse = Inverse
function RD.Affine(tex, view, hw, hh, ox, oy, ux, uy, vx, vy)
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
function RD.Disc(tex, view, hw, hh, sx, sy, rw, rh)
    if rw * 2 > MAX_PX then
        tex:Hide()
        return false
    end
    local LV = ns.ReplayLayersView
    if LV and LV.Sharp then LV.Sharp(tex, rw) end
    rh = max(0.5, rh)
    return ns.Kit.Crop(tex, view, hw, hh, sx - rw, sy - rh, sx + rw, sy + rh)
end
