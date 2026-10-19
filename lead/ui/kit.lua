local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local Kit = root.Kit
local C = Kit.C
ns.Kit = Kit
ns.C = C
ns.EDGE = C["text.title"]
ns.DANGER = C["text.bad"]
ns.Theme = setmetatable({}, {
    __index = function(_, k) return Kit.Theme()[k] end,
})
ns.Fill = Kit.Solid
ns.Backdrop = Kit.Backdrop
ns.Skin = Kit.Skin
ns.PaintTitle = Kit.Title
ns.PaintText = Kit.Text
ns.PaintToken = Kit.Paint
ns.Tone = Kit.Tone
ns.ClassText = Kit.ClassText
ns.Hex = Kit.Hex
ns.PaintWindow = Kit.Window
ns.MakePanel = Kit.Panel
ns.Caption = Kit.Caption
ns.ClassColor = Kit.ClassColor
ns.MakeKitButton = Kit.Button
ns.StyleButton = Kit.StyleButton
ns.MakeCheck = Kit.Check
ns.MakeEdit = Kit.Edit
ns.MakeSelect = Kit.Select
ns.PopupList = Kit.Popup
ns.SelectClose = Kit.SelectClose
ns.TipShow = Kit.TipShow
ns.TipHide = Kit.TipHide
ns.FLAG_TEX = Kit.FLAG_TEX
ns.NOTE_TEX = Kit.NOTE_TEX
ns.DICE_TEX = Kit.DICE_TEX
ns.DOT_TEX = Kit.DOT_TEX
ns.QMARK = Kit.QMARK
ns.Icon = {
    Class = Kit.Icon.Class,
    Role = Kit.Icon.Role,
    RoleBig = Kit.Icon.RoleBig,
    Mark = Kit.Icon.Mark,
}
function ns.Icon.Spec(tex, key)
    local sp = key and ns.SPEC[key]
    Kit.Icon.Spell(tex, sp and sp.icon)
end
function ns.Icon.Who(tex, key, token)
    if key then ns.Icon.Spec(tex, key) else Kit.Icon.Class(tex, token) end
end
local function stockSize(base)
    local o = _G[base]
    local _, size = o and o.GetFont and o:GetFont()
    return size or 12
end
function ns.Str(parent, base, layer)
    if Kit.Str then return Kit.Str(parent, base, layer) end
    return parent:CreateFontString(nil, layer or "OVERLAY", base)
end
function ns.FontSize(base)
    if Kit.FontSize then return Kit.FontSize(base, true) end
    return stockSize(base)
end
function ns.FontScale(base)
    if Kit.FontScale then return math.max(1, Kit.FontScale(base, true)) end
    return 1
end
function ns.OnFont(fn)
    if Kit.OnFont then Kit.OnFont(fn) end
end
function ns.LineH(base, lines)
    return math.ceil(ns.FontSize(base) * 1.2) * (lines or 1)
end
function ns.Fit(base, h, pad, lines)
    return math.max(h, ns.LineH(base, lines) + (pad or 0))
end
function ns.Wide(base, w)
    return math.ceil(w * ns.FontScale(base))
end
