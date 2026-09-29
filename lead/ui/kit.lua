local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local Kit = root.Kit
local C = Kit.C
ns.Kit = Kit
ns.Space = Kit.Space
ns.C = C
ns.EDGE = C["text.title"]
ns.DANGER = C["text.bad"]
ns.Theme = setmetatable({}, {
    __index = function(_, k) return Kit.Theme()[k] end,
})
ns.Fill = Kit.Solid
ns.PlainFrame = Kit.PlainFrame
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
