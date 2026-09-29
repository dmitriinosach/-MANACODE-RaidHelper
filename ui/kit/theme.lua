local _, ns = ...
local Kit = ns.Kit or {}
ns.Kit = Kit
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local WHITE = { 1, 1, 1 }
local SOUNDS = {
    open = "igSpellBookOpen",
    tab = "igCharacterInfoTab",
    click = "igCharacterInfoTab",
    checkOn = "igMainMenuOptionCheckBoxOn",
    checkOff = "igMainMenuOptionCheckBoxOff",
}
Kit.Space = {
    pad = 14,
    gap = 12,
    inset = 12,
    row = 6,
    cap = 26,
    ctl = 22,
}
local C = {}
Kit.C = C
local current = Kit.DEFAULT or "dark"
local painters = {}
local WEAK = { __mode = "k" }
local paintKey = setmetatable({}, WEAK)
local paintA = setmetatable({}, WEAK)
local tintKey = setmetatable({}, WEAK)
local tintA = setmetatable({}, WEAK)
local textKey = setmetatable({}, WEAK)
local skinKey = setmetatable({}, WEAK)
local function Saved()
    local db = ns.GetDB and ns.GetDB()
    local s = type(db) == "table" and db.settings
    if type(s) == "table" then return s end
    return nil
end
local function Flatten(t, prefix)
    for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "table" then
            local token = prefix and (prefix .. "." .. k) or k
            if type(v[1]) == "number" then
                local dst = C[token]
                if not dst then
                    dst = {}
                    C[token] = dst
                end
                dst[1], dst[2], dst[3], dst[4] = v[1], v[2], v[3], v[4]
            elseif v[1] == nil and v.bgFile == nil and v.edgeFile == nil then
                Flatten(v, token)
            end
        end
    end
end
function Kit.Theme()
    return Kit.themes[current]
end
function Kit.Key()
    return current
end
function Kit.Get(key)
    return Kit.themes[key]
end
function Kit.Color(token)
    local c = C[token]
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4] or 1
end
function Kit.RGB(token)
    local c = C[token]
    if not c then return 1, 1, 1 end
    return c[1], c[2], c[3]
end
function Kit.Group(group)
    local out = {}
    local prefix = group .. "."
    for token, c in pairs(C) do
        if token:sub(1, #prefix) == prefix then
            local field = token:sub(#prefix + 1)
            if not field:find(".", 1, true) then out[field] = c end
        end
    end
    return out
end
function Kit.OnTheme(fn)
    painters[#painters + 1] = fn
end
function Kit.Backdrop(f, spec, border)
    if f.kitBd ~= spec.backdrop then
        f:SetBackdrop(spec.backdrop)
        f.kitBd = spec.backdrop
    end
    local bg, br = spec.bg, border or spec.border
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    f:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1)
end
function Kit.Paint(tex, token, a)
    paintKey[tex] = token
    paintA[tex] = a
    local c = C[token]
    if c then tex:SetTexture(c[1], c[2], c[3], a or c[4] or 1) end
end
function Kit.Tint(tex, token, a)
    tintKey[tex] = token
    tintA[tex] = a
    local c = C[token]
    if c then tex:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
end
function Kit.Text(fs, token)
    textKey[fs] = token
    local c = C[token]
    if c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end
function Kit.Title(fs)
    Kit.Text(fs, "text.title")
end
function Kit.Tone(fs, token)
    textKey[fs] = nil
    local c = C[token]
    if c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end
function Kit.Shade(tex, token, a)
    paintKey[tex] = nil
    local c = C[token]
    if c then tex:SetTexture(c[1], c[2], c[3], a or c[4] or 1) end
end
function Kit.Hue(tex, token, a)
    tintKey[tex] = nil
    local c = C[token]
    if c then tex:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
end
function Kit.TipAdd(text, token, wrap)
    local c = C[token] or WHITE
    GameTooltip:AddLine(text, c[1], c[2], c[3], wrap)
end
function Kit.Hex(token)
    local c = C[token] or WHITE
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5))
end
function Kit.Skin(f, group)
    skinKey[f] = group
    local g = Kit.Theme()[group]
    if g then Kit.Backdrop(f, g) end
end
function Kit.Fill(tex, d)
    tex:SetTexture(d.tex or d.bgFile or WHITE8)
    local c = d.coord
    if c then
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
    local g = d.grad
    if g then
        local a, b = g.from, g.to
        tex:SetGradientAlpha(g.dir or "VERTICAL", a[1], a[2], a[3], a[4] or 1, b[1], b[2], b[3], b[4] or 1)
    elseif d.color then
        local k = d.color
        tex:SetVertexColor(k[1], k[2], k[3], k[4] or 1)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
    tex:SetAlpha(d.alpha or 1)
    tex:SetBlendMode(d.blend or "BLEND")
    if d.layer then tex:SetDrawLayer(d.layer) end
end
function Kit.Solid(f, layer, r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    local t = f:CreateTexture(nil, layer)
    t:SetTexture(r or 1, g or 1, b or 1, a or 1)
    return t
end
function Kit.PlainFrame(parent, level)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
    return f
end
function Kit.ClassColor(token)
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end
function Kit.ClassText(fs, token)
    textKey[fs] = nil
    fs:SetTextColor(Kit.ClassColor(token))
end
function Kit.Sound(kind)
    local ref = SOUNDS[kind or "click"]
    if ref then PlaySound(ref) end
end
function Kit.Repaint()
    for tex, token in pairs(paintKey) do
        local c = C[token]
        if c then tex:SetTexture(c[1], c[2], c[3], paintA[tex] or c[4] or 1) end
    end
    for tex, token in pairs(tintKey) do
        local c = C[token]
        if c then tex:SetVertexColor(c[1], c[2], c[3], tintA[tex] or c[4] or 1) end
    end
    for fs, token in pairs(textKey) do
        local c = C[token]
        if c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
    end
    local t = Kit.Theme()
    for f, group in pairs(skinKey) do
        local g = t[group]
        if g then Kit.Backdrop(f, g) end
    end
    for i = 1, #painters do painters[i]() end
end
function Kit.SetTheme(key)
    if not Kit.themes[key] then return false end
    local s = Saved()
    if s then s.theme = key end
    if key == current then return true end
    current = key
    Flatten(Kit.themes[current], nil)
    Kit.Repaint()
    return true
end
function Kit.Load()
    local s = Saved()
    local key = s and s.theme
    if not Kit.themes[key or ""] then
        key = Kit.DEFAULT
        if s then s.theme = key end
    end
    if key == current then return end
    current = key
    Flatten(Kit.themes[current], nil)
    Kit.Repaint()
end
Flatten(Kit.themes[current], nil)
if ns.OnReady then ns.OnReady(Kit.Load) end
