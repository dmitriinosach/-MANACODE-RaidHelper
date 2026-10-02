local _, ns = ...
local floor = math.floor
local max = math.max
local tsort = table.sort
local GOLD = 0.6180339887
local FALL = "fall"
local GROW = "grow"
local Platform = {}
ns.ReplayPlatform = Platform
Platform.FALL = FALL
Platform.GROW = GROW
function Platform.Def(boss)
    return boss and ns.replayPlatform and ns.replayPlatform[boss] or nil
end
local function Hit(cast, id)
    local n = tonumber(id)
    if not n then return false end
    local key = ns.SpellKey(n)
    for i = 1, #cast.ids do
        if cast.ids[i] == n or ns.SpellKey(cast.ids[i]) == key then return true end
    end
    return false
end
function Platform.Match(def, id, name)
    if Hit(def.quake, id) then return "quake" end
    if Hit(def.winter, id) then return "winter" end
    return nil
end
function Platform.Add(list, cast, ts, success)
    local start = success and ts - cast.cast or ts
    local n = #list
    if n > 0 and start - list[n] < cast.gap then
        if start < list[n] then list[n] = start end
        return
    end
    list[n + 1] = start
end
local function ByTime(a, b)
    return a.t < b.t
end
function Platform.Timeline(def, quakes, winters)
    local casts = {}
    for i = 1, #quakes do casts[#casts + 1] = { t = quakes[i] + def.quake.delay, kind = FALL, cast = quakes[i] } end
    for i = 1, #winters do casts[#casts + 1] = { t = winters[i] + def.winter.delay, kind = GROW, cast = winters[i] } end
    tsort(casts, ByTime)
    local out, whole = {}, true
    for i = 1, #casts do
        local e = casts[i]
        if e.kind == FALL and whole then
            out[#out + 1] = e
            whole = false
        elseif e.kind == GROW and not whole then
            out[#out + 1] = e
            whole = true
        end
    end
    return out
end
local function Frac(x)
    return x - floor(x)
end
function Platform.Offset(def, ring, kind, sector, band)
    if kind == FALL then
        return Frac((sector * ring.bands + band) * GOLD) * ring.n * ring.bands * def.fall.stagger
    end
    return band * def.grow.band + Frac(sector * GOLD) * def.grow.spread
end
function Platform.Span(def, ring, kind)
    if kind == FALL then return ring.n * ring.bands * def.fall.stagger + def.fall.fall end
    return (ring.bands - 1) * def.grow.band + def.grow.spread + def.grow.grow
end
function Platform.Piece(tl, def, ring, sector, band, t)
    local alpha, dz, ice = 1, 0, false
    for i = 1, #tl do
        local e = tl[i]
        local s = e.t + Platform.Offset(def, ring, e.kind, sector, band)
        if t < s then return alpha, dz, ice end
        if e.kind == FALL then
            local F = def.fall
            local u = (t - s) / F.fall
            if u < 1 then
                local fade = F.fade < 1 and max(0, (u - F.fade) / (1 - F.fade)) or 0
                return 1 - fade, -F.depth * u * u, ice
            end
            alpha, dz, ice = 0, 0, false
        else
            local G = def.grow
            local u = (t - s) / G.grow
            if u < 1 then
                local v = 1 - u
                return u, -G.rise * v * v, true
            end
            alpha, dz, ice = 1, 0, true
        end
    end
    return alpha, dz, ice
end
function Platform.State(tl, def, ring, t)
    local done = 0
    for i = 1, #tl do
        local e = tl[i]
        if t >= e.t then
            if t < e.t + Platform.Span(def, ring, e.kind) then return true, done end
            done = i
        end
    end
    return false, done
end
function Platform.Next(tl, kind, from)
    for i = 1, #tl do
        if tl[i].kind == kind and tl[i].t >= from then return tl[i] end
    end
    return nil
end
