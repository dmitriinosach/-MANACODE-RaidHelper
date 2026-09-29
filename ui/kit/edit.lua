local _, ns = ...
local Kit = ns.Kit
local edits = {}
local function PaintEdit(e)
    local g = Kit.Theme().edit
    Kit.Backdrop(e.kitFrame or e, g, e.focused and g.borderFocus or g.border)
end
local function SetValue(self, text)
    self.quiet = true
    self:SetText(text or "")
    self.quiet = nil
end
local function FocusGained(self)
    self.focused = true
    PaintEdit(self)
end
local function FocusLost(self)
    self.focused = nil
    PaintEdit(self)
    if self.onCommit then self.onCommit(self:GetText()) end
end
local function ClearFocus(self)
    self:ClearFocus()
end
local function TextChanged(self)
    if self.quiet then return end
    if self.onChange then self.onChange(self:GetText()) end
end
local function EditEnter(self)
    Kit.TipShow(self)
end
function Kit.Edit(parent, multi, name)
    local e = CreateFrame("EditBox", name, parent)
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(6, 6, 3, 3)
    e:SetAutoFocus(false)
    e:SetHeight(Kit.Space.ctl)
    if multi then e:SetMultiLine(true) end
    e.SetValue = SetValue
    e:SetScript("OnEditFocusGained", FocusGained)
    e:SetScript("OnEditFocusLost", FocusLost)
    e:SetScript("OnEscapePressed", ClearFocus)
    if not multi then e:SetScript("OnEnterPressed", ClearFocus) end
    e:SetScript("OnTextChanged", TextChanged)
    e:SetScript("OnEnter", EditEnter)
    e:SetScript("OnLeave", Kit.TipHide)
    edits[#edits + 1] = e
    PaintEdit(e)
    return e
end
Kit.OnTheme(function()
    for i = 1, #edits do PaintEdit(edits[i]) end
end)
