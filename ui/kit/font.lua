local ADDON, ns = ...
local Kit = ns.Kit
local floor = math.floor
local ceil = math.ceil
local max = math.max
local pairs = pairs
local DMIN, DMAX = -2, 6
local PREFIX = "ManaCodeRaidHelperFont_"
local FACES = { "client", "pt", "roboto", "firac", "fira", "lib", "mont" }
local FONT_DIR = "Interface\\AddOns\\" .. ADDON .. "\\art\\fonts\\"
local FACE_FILE = {
    pt = FONT_DIR .. "PTSansNarrow-Regular.ttf",
    roboto = FONT_DIR .. "Roboto-Regular.ttf",
    firac = FONT_DIR .. "FiraSansCondensed-Medium.ttf",
    fira = FONT_DIR .. "FiraSans-Medium.ttf",
    lib = FONT_DIR .. "LiberationSans-Regular.ttf",
    mont = FONT_DIR .. "Montserrat-Regular.ttf",
}
local FACE_PLUS = { pt = 1, firac = 1, mont = -1 }
local WEAK = { __mode = "k" }
local fonts = {}
local bound = {}
local listeners = {}
local boundTo = setmetatable({}, WEAK)
local pending = setmetatable({}, WEAK)
local delta, face = 0, "client"
local function Saved()
    local db = ns.GetDB and ns.GetDB()
    local s = type(db) == "table" and db.settings
    if type(s) == "table" then return s end
    return nil
end
local function Clamp(v)
    v = floor((tonumber(v) or 0) + 0.5)
    if v < DMIN then return DMIN end
    if v > DMAX then return DMAX end
    return v
end
local function Stock(base)
    local o = _G[base]
    if type(o) == "table" and o.GetFont then return o end
    return nil
end
local probe
local function Draws(font)
    if not font:GetFont() then return false end
    if not probe then
        local holder = CreateFrame("Frame")
        holder:Hide()
        probe = holder:CreateFontString(nil, "OVERLAY")
    end
    probe:SetFontObject(font)
    return (pcall(probe.SetText, probe, "Ab"))
end
local function Apply(e)
    local file = FACE_FILE[face]
    if file then
        local size = max(6, e.size + delta + (FACE_PLUS[face] or 0))
        if e.font:SetFont(file, size, e.flags) and Draws(e.font) then
            e.cur = size
            return
        end
    end
    e.cur = max(6, e.size + delta)
    e.font:SetFont(e.path, e.cur, e.flags)
    if not Draws(e.font) then
        local stock = Stock(e.base)
        if stock then e.font:CopyFontObject(stock) end
        e.cur = e.size
    end
end
local function Get(base)
    local e = fonts[base]
    if e ~= nil then return e or nil end
    local stock = Stock(base)
    local path, size, flags
    if not stock then
        fonts[base] = false
        return nil
    end
    path, size, flags = stock:GetFont()
    if not (path and size) then return nil end
    local f = CreateFont(PREFIX .. base)
    f:CopyFontObject(stock)
    e = { font = f, base = base, path = path, size = floor(size + 0.5), flags = flags or "", cur = floor(size + 0.5) }
    Apply(e)
    if not f:GetFont() then
        fonts[base] = false
        return nil
    end
    fonts[base] = e
    return e
end
local function Rebind(fs, e)
    local r, g, b, a = fs:GetTextColor()
    local sr, sg, sb, sa = fs:GetShadowColor()
    local jh, jv = fs:GetJustifyH(), fs:GetJustifyV()
    fs:SetFontObject(e.font)
    if r then fs:SetTextColor(r, g, b, a) end
    if sr then fs:SetShadowColor(sr, sg, sb, sa) end
    if jh then fs:SetJustifyH(jh) end
    if jv then fs:SetJustifyV(jv) end
end
local function ApplyAll()
    for _, e in pairs(fonts) do
        if e then
            Apply(e)
            local set = bound[e]
            if set then
                for fs in pairs(set) do Rebind(fs, e) end
            end
        end
    end
    for i = 1, #listeners do listeners[i]() end
end
function Kit.Bind(fs, base)
    local e = Get(base)
    if not (e and e.font:GetFont()) then
        local stock = Stock(base)
        if stock and not fs:GetFont() then fs:SetFontObject(stock) end
        if stock then pending[fs] = base end
        return fs
    end
    pending[fs] = nil
    Rebind(fs, e)
    local was = boundTo[fs]
    if was and was ~= e and bound[was] then bound[was][fs] = nil end
    boundTo[fs] = e
    local set = bound[e]
    if not set then
        set = setmetatable({}, WEAK)
        bound[e] = set
    end
    set[fs] = true
    return fs
end
function Kit.Str(parent, base, layer)
    return Kit.Bind(parent:CreateFontString(nil, layer or "OVERLAY", base), base)
end
function Kit.FontFor(base, sized)
    local e = sized and Get(base)
    if e and e.font:GetFont() then return e.font end
    return Stock(base)
end
function Kit.FontSize(base, sized)
    local e = Get(base)
    if not e then return 12 end
    if sized then return e.cur end
    return e.size
end
function Kit.FontScale(base, sized)
    if not sized then return 1 end
    local e = Get(base)
    if not e or e.size <= 0 then return 1 end
    return e.cur / e.size
end
function Kit.FontGrow(v, base)
    return ceil(v * max(1, Kit.FontScale(base or "GameFontHighlightSmall", true)))
end
local GROW = { g = 0, k = 1, wk = 1 }
function Kit.Grow()
    local e = Get("GameFontHighlightSmall")
    if e then
        GROW.g = max(0, ceil((e.cur - e.size) * 1.2))
        GROW.k = max(1, e.cur / max(1, e.size))
        GROW.wk = 1 + (GROW.k - 1) * 0.65
    end
    return GROW
end
function Kit.Sized(f)
    local n = 0
    while f and n < 40 do
        if f.sized then return true end
        f = f.GetParent and f:GetParent() or nil
        n = n + 1
    end
    return false
end
function Kit.FontDelta()
    return delta, DMIN, DMAX
end
function Kit.SetFontDelta(v)
    v = Clamp(v)
    local s = Saved()
    if s then s.fontDelta = v ~= 0 and v or nil end
    if v == delta then return delta end
    delta = v
    ApplyAll()
    return delta
end
function Kit.FontFace()
    return face
end
function Kit.FontFaces()
    return FACES
end
function Kit.SetFontFace(key)
    if not FACE_FILE[key] then key = "client" end
    local s = Saved()
    if s then s.fontFace = key ~= "client" and key or nil end
    if key == face then return end
    face = key
    ApplyAll()
end
function Kit.OnFont(fn)
    listeners[#listeners + 1] = fn
end
local autoH = setmetatable({}, WEAK)
function Kit.GrowH(h, base)
    local extra = Kit.FontSize(base, true) - Kit.FontSize(base, false)
    if extra <= 0 then return h end
    return floor(h + extra * 1.4 + 0.5)
end
local function GrowHeight(self, h)
    self.wantH = h
    self.rawSetHeight(self, Kit.GrowH(h, self.growBase))
end
function Kit.AutoH(f, base)
    f.growBase = base
    if f.rawSetHeight then return end
    f.rawSetHeight = f.SetHeight
    f.SetHeight = GrowHeight
    autoH[f] = true
    local h = f:GetHeight()
    if h and h > 0 then f.wantH = h end
end
Kit.OnFont(function()
    for f in pairs(autoH) do
        if f.wantH then f.rawSetHeight(f, Kit.GrowH(f.wantH, f.growBase)) end
    end
end)
local function Load()
    for fs, base in pairs(pending) do Kit.Bind(fs, base) end
    local s = Saved()
    local d = Clamp(s and s.fontDelta)
    local k = s and FACE_FILE[s.fontFace] and s.fontFace or "client"
    if s then s.fontDelta = d ~= 0 and d or nil end
    if d == delta and k == face then return end
    delta, face = d, k
    ApplyAll()
end
if ns.OnReady then ns.OnReady(Load) end
