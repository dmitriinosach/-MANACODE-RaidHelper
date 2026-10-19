local _, ns = ...
local Kit = ns.Kit
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local GLOW_INSET, GLOW_A = 3, 0.10
local buttons = {}
local checks = {}
local BTN_PAD = 8
local BTN_FONT = "GameFontNormalSmall"
local autoW = setmetatable({}, { __mode = "k" })
local function FitWidth(b)
    local w = b.wantW
    if not w then return end
    local need = 0
    local t = b.text
    if t and not b.icon and Kit.FontScale(BTN_FONT, true) > 1 then
        local s = t:GetText()
        if s and s ~= "" then need = ceil(t:GetStringWidth() or 0) + BTN_PAD * 2 end
    end
    b.rawSetWidth(b, max(w, need))
end
local function GrowWidth(self, w)
    self.wantW = w
    FitWidth(self)
end
local function GrowText(self, text)
    self.rawSetText(self, text)
    FitWidth(self)
end
Kit.OnFont(function()
    for b in pairs(autoW) do FitWidth(b) end
end)
Kit.BUTTON_KINDS = { main = true, quiet = true, icon = true, danger = true, hot = true }
function Kit.StyleButton(b)
    local base = Kit.Theme().button
    local bt = b.kind and base[b.kind] or base
    local bg, br, t
    if b.btnDisabled and b.active then
        bg, br, t = base.bgActive, base.borderActive, base.textOff
    elseif b.btnDisabled then
        bg, br, t = b.kind and bt.bg or base.bgOff, base.borderOff, base.textOff
    elseif b.active then
        bg, br, t = base.bgActive, base.borderActive, base.textActive
    elseif b.pressed then
        bg, br, t = bt.bgDown, bt.borderHover, bt.textHover or base.textHover
    elseif b.hovered then
        bg, br, t = bt.bgHover, bt.borderHover, bt.textHover or base.textHover
    else
        bg, br, t = bt.bg, bt.border, bt.text or base.text
    end
    if b.tint and not b.btnDisabled then t = b.tint end
    b:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    b:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1)
    b.text:SetTextColor(t[1], t[2], t[3])
    if b.icon and b.kind == "icon" then b.icon:SetVertexColor(t[1], t[2], t[3]) end
    if b.hovered and not b.pressed and not b.btnDisabled then
        local g = bt.glow or base.glow
        b.glow:SetTexture(g[1], g[2], g[3], GLOW_A)
        b.glow:Show()
    else
        b.glow:Hide()
    end
end
local SEG = 0.125
local PART_GLYPH = 12
local function Turn(tx, x0, x1)
    tx:SetTexCoord(x0, 1, x1, 1, x0, 0, x1, 0)
end
local function Shown(tx, on)
    if on then tx:Show() else tx:Hide() end
end
local function Cut(b)
    if not b.active then return 0 end
    local below = b.below or 0
    return max(0, below - min(below, Kit.Theme().tab.join or 0))
end
local function ShapeTab(b)
    local bd = Kit.Theme().window.backdrop
    local e = bd.edgeSize or 16
    local w, full = b:GetWidth() or 0, b.tabH or b:GetHeight() or 0
    local below = b.below or 0
    local cut = min(full, Cut(b))
    local h = full - cut
    local cw, ch = min(e, floor(w / 2)), min(e, h)
    local kx, ky = cw / e, ch / e
    local r = b.rim
    for i = 1, #r do
        r[i]:SetTexture(bd.edgeFile)
        r[i]:ClearAllPoints()
    end
    r[1]:SetTexCoord(4 * SEG, (4 + kx) * SEG, 0, ky)
    r[1]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    r[1]:SetWidth(cw)
    r[1]:SetHeight(ch)
    r[2]:SetTexCoord((6 - kx) * SEG, 6 * SEG, 0, ky)
    r[2]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    r[2]:SetWidth(cw)
    r[2]:SetHeight(ch)
    Turn(r[3], 2 * SEG, (2 + ky) * SEG)
    r[3]:SetPoint("TOPLEFT", r[1], "TOPRIGHT", 0, 0)
    r[3]:SetPoint("BOTTOMRIGHT", r[2], "BOTTOMLEFT", 0, 0)
    r[4]:SetTexCoord(0, kx * SEG, 0, 1)
    r[4]:SetPoint("TOPLEFT", r[1], "BOTTOMLEFT", 0, 0)
    r[4]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, cut)
    r[4]:SetWidth(cw)
    r[5]:SetTexCoord((2 - kx) * SEG, 2 * SEG, 0, 1)
    r[5]:SetPoint("TOPRIGHT", r[2], "BOTTOMRIGHT", 0, 0)
    r[5]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, cut)
    r[5]:SetWidth(cw)
    Shown(r[3], w > cw * 2)
    Shown(r[4], h > ch)
    Shown(r[5], h > ch)
    local ins = bd.insets or {}
    b.fill:ClearAllPoints()
    b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", ins.left or 0, -(ins.top or 0))
    b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -(ins.right or 0), 0)
    below = min(e, below)
    local s = b.seam
    s:SetTexture(bd.edgeFile)
    Turn(s, 2 * SEG, (2 + below / e) * SEG)
    s:ClearAllPoints()
    s:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    s:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    s:SetHeight(max(1, below))
    b.kitEdge = bd.edgeFile
    b.kitCut = cut
    b.rimH = h
end
local function StyleTab(b)
    local tt = Kit.Theme().tab
    local on = b.active and true or false
    if b.kitEdge ~= Kit.Theme().window.backdrop.edgeFile or b.kitCut ~= Cut(b) then ShapeTab(b) end
    local hot = not on and (b.hovered or b.pressed) and true or false
    local spec = tt.fill
    if on then
        spec = tt.fillOn
    elseif hot then
        spec = tt.fillHover
    end
    Kit.Fill(b.fill, spec)
    local e = Kit.C["window.border"]
    for i = 1, #b.rim do b.rim[i]:SetVertexColor(e[1], e[2], e[3], e[4] or 1) end
    b.seam:SetVertexColor(e[1], e[2], e[3], e[4] or 1)
    Shown(b.seam, not on and (b.below or 0) > 0)
    local off = b.btnDisabled and Kit.Theme().button.textOff
    local t = tt.text
    if off then
        t = off
    elseif on then
        t = tt.textOn
    elseif hot then
        t = tt.textHover
    end
    b.text:SetTextColor(t[1], t[2], t[3])
    if b.icon then
        local k = tt.icon
        if off then
            k = off
        elseif on then
            k = tt.iconOn
        elseif hot then
            k = tt.iconHover
        end
        b.icon:SetVertexColor(k[1], k[2], k[3], k[4] or 1)
    end
    b.glow:Hide()
end
local function PrepTab(b)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.rim = {}
    for i = 1, 5 do b.rim[i] = b:CreateTexture(nil, "BORDER") end
    b.seam = b:CreateTexture(nil, "ARTWORK")
    b.seam:Hide()
end
local function Seat(self, below, lift, height)
    self.below = below
    self.lift = lift
    self.tabH = height
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self, "CENTER", 0, lift)
    if self.icon then
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", self, "CENTER", 0, lift)
    end
    ShapeTab(self)
    StyleTab(self)
end
local function Restyle(b)
    local g = Kit.Theme()[b.kitGroup]
    if b.kitBd ~= g.backdrop then
        b:SetBackdrop(g.backdrop)
        b.kitBd = g.backdrop
    end
    b.kitStyle(b)
end
local function Enable(self)
    self.btnDisabled = nil
    if self.nativeEnable then self.nativeEnable(self) end
    self.kitStyle(self)
end
local function Disable(self)
    self.btnDisabled = true
    if self.nativeDisable then self.nativeDisable(self) end
    self.kitStyle(self)
end
local function SetActive(self, on)
    self.active = on and true or false
    self.kitStyle(self)
end
local function OnEnter(self)
    self.hovered = true
    self.kitStyle(self)
    Kit.TipShow(self)
end
local function OnLeave(self)
    self.hovered = false
    self.pressed = nil
    self.kitStyle(self)
    Kit.TipHide()
end
local function OnMouseDown(self)
    if self.btnDisabled then return end
    self.pressed = true
    self.kitStyle(self)
end
local function OnMouseUp(self)
    if not self.pressed then return end
    self.pressed = nil
    self.kitStyle(self)
end
local function OnClick(self, button)
    if self.btnDisabled then return end
    Kit.Sound(self.clickSfx)
    if self.onClick then self.onClick(self, button) end
end
local ClickWrap = ns.Prof.Wrap("ui.click", OnClick)
local function Make(parent, group, style, prep, name)
    local b = CreateFrame("Button", name, parent)
    b.kitGroup = group
    b.kitStyle = style
    if group == "button" then
        Kit.AutoH(b, BTN_FONT)
        b.rawSetWidth, b.rawSetText = b.SetWidth, b.SetText
        b.SetWidth, b.SetText = GrowWidth, GrowText
        autoW[b] = true
    end
    b:SetHeight(Kit.Space.ctl)
    b.glow = b:CreateTexture(nil, "ARTWORK")
    b.glow:SetTexture(1, 1, 1, GLOW_A)
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", GLOW_INSET, -GLOW_INSET)
    b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -GLOW_INSET, GLOW_INSET)
    b.glow:Hide()
    b.text = Kit.Str(b, BTN_FONT)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetJustifyH("CENTER")
    Kit.Halo(b.text)
    b:SetFontString(b.text)
    b:SetPushedTextOffset(1, -1)
    b.nativeEnable, b.nativeDisable = b.Enable, b.Disable
    b.Enable = Enable
    b.Disable = Disable
    b.SetActive = SetActive
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:SetScript("OnMouseDown", OnMouseDown)
    b:SetScript("OnMouseUp", OnMouseUp)
    b:SetScript("OnClick", ClickWrap)
    if prep then prep(b) end
    buttons[#buttons + 1] = b
    Restyle(b)
    return b
end
function Kit.ButtonFont(b, base)
    local old = b.text
    old:SetText("")
    old:Hide()
    local fs = Kit.Str(b, base)
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    Kit.Halo(fs)
    b:SetFontString(fs)
    b.text = fs
    b.kitStyle(b)
end
function Kit.Button(parent, name, kind)
    local b = Make(parent, "button", Kit.StyleButton, nil, name)
    if kind then Kit.ButtonKind(b, kind) end
    return b
end
function Kit.ButtonKind(b, kind)
    b.kind = Kit.BUTTON_KINDS[kind] and kind or nil
    b.kitStyle(b)
end
function Kit.IconButton(parent, tex, size, name)
    local b = Make(parent, "button", Kit.StyleButton, nil, name)
    size = size or 16
    b:SetWidth(size + 6)
    b:SetHeight(size + 6)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetTexture(tex)
    b.icon:SetWidth(size)
    b.icon:SetHeight(size)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    Kit.ButtonKind(b, "icon")
    return b
end
local TOOL_PAD = 10
local TOOL_MIN = 60
local TOOL_ICON = 10
local TOOL_ICONGAP = 3
local labeled = setmetatable({}, { __mode = "k" })
local function SetLabel(self, text)
    self.labelText = text
    labeled[self] = true
    self.text:SetText(text)
    local w = (self.text:GetStringWidth() or 0) + TOOL_PAD * 2
    if self.icon then
        w = w + TOOL_ICON + TOOL_ICONGAP
        self.text:ClearAllPoints()
        self.text:SetPoint("CENTER", self, "CENTER", (TOOL_ICON + TOOL_ICONGAP) / 2, 0)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("RIGHT", self.text, "LEFT", -TOOL_ICONGAP, 0)
    end
    self:SetWidth(max(self.minW or TOOL_MIN, floor(w + 0.5)))
end
Kit.OnFont(function()
    for b in pairs(labeled) do SetLabel(b, b.labelText) end
end)
function Kit.ToolButton(parent, name, icon, kind)
    local b = Kit.Button(parent, name, kind)
    local h = Kit.Space.tool
    b:SetHeight(h)
    b:SetWidth(h)
    if icon then
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetWidth(TOOL_ICON)
        b.icon:SetHeight(TOOL_ICON)
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.icon:SetTexture(icon)
    end
    b.tipTitle = false
    b.SetLabel = SetLabel
    return b
end
local function Chain(bar, f, prev)
    f:ClearAllPoints()
    if not prev then
        f:SetPoint(bar.side, bar.anchor, bar.rel, bar.x, bar.y)
    elseif bar.side == "RIGHT" then
        f:SetPoint("RIGHT", prev, "LEFT", -Kit.Space.toolGap, 0)
    else
        f:SetPoint("LEFT", prev, "RIGHT", Kit.Space.toolGap, 0)
    end
end
local function Layout(bar)
    local prev
    for i = 1, #bar.items do
        local f = bar.items[i]
        if f:IsShown() then
            Chain(bar, f, prev)
            prev = f
        end
    end
    Chain(bar, bar.tail, prev)
end
local function Add(bar, b)
    bar.items[#bar.items + 1] = b
    b:HookScript("OnShow", function() Layout(bar) end)
    b:HookScript("OnHide", function() Layout(bar) end)
    Layout(bar)
    return b
end
function Kit.ToolBar(host, side, anchor, rel, x, y)
    local tail = CreateFrame("Frame", nil, host)
    tail:SetWidth(1)
    tail:SetHeight(Kit.Space.tool)
    local bar = { items = {}, side = side, anchor = anchor, rel = rel, x = x or 0, y = y or 0, tail = tail,
                  Add = Add, Layout = Layout }
    Layout(bar)
    return bar
end
function Kit.Tab(parent, icon, size)
    local b = Make(parent, "tab", StyleTab, PrepTab)
    b.clickSfx = "tab"
    b.tipTitle = false
    b.Seat = Seat
    if icon then
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetTexture(icon)
        b.icon:SetWidth(size or 16)
        b.icon:SetHeight(size or 16)
    end
    Seat(b, 0, 0)
    return b
end
local function StylePart(b)
    local tt = Kit.Theme().tab
    local off = b.btnDisabled and Kit.Theme().button.textOff
    local hot = not off and (b.hovered or b.pressed) and true or false
    if hot then
        Kit.Fill(b.fill, tt.fillHover)
        b.fill:Show()
    else
        b.fill:Hide()
    end
    local t = off or (hot and tt.textHover) or tt.text
    b.text:SetTextColor(t[1], t[2], t[3])
    local k = off or (hot and tt.iconHover) or tt.icon
    if b.glyph then
        for i = 1, #b.glyph do b.glyph[i]:SetTexture(k[1], k[2], k[3], k[4] or 1) end
    end
    if b.icon then
        local d = b.pressed and 1 or 0
        b.icon:ClearAllPoints()
        b.icon:SetPoint("CENTER", b, "CENTER", d, -d)
    end
    b.glow:Hide()
end
local function PrepPart(b)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:Hide()
end
function Kit.TabPart(parent, glyph)
    local b = Make(parent, "tab", StylePart, PrepPart)
    if glyph then
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetWidth(PART_GLYPH)
        b.icon:SetHeight(PART_GLYPH)
        b.glyph = {}
        Kit.Glyph(b, glyph)
    end
    return b
end
local function StyleCheck(c)
    local ck = Kit.Theme().check
    c:SetNormalTexture(ck.box.tex)
    c:SetPushedTexture(ck.down.tex)
    c:SetHighlightTexture(ck.hover.tex, "ADD")
    c:SetCheckedTexture(ck.mark.tex)
    c:SetDisabledCheckedTexture(ck.markOff.tex)
end
local function CheckClick(self)
    local on = self:GetChecked() and true or false
    Kit.Sound(on and "checkOn" or "checkOff")
    if self.onToggle then self.onToggle(on) end
end
local CheckWrap = ns.Prof.Wrap("ui.click", CheckClick)
local function CheckEnter(self)
    Kit.TipShow(self)
end
function Kit.Check(parent, name)
    local c = CreateFrame("CheckButton", name, parent)
    c:SetWidth(24)
    c:SetHeight(24)
    StyleCheck(c)
    c.label = Kit.Str(c, "GameFontNormalSmall")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    Kit.Text(c.label, "check.label")
    c:SetScript("OnClick", CheckWrap)
    c:SetScript("OnEnter", CheckEnter)
    c:SetScript("OnLeave", Kit.TipHide)
    checks[#checks + 1] = c
    return c
end
function Kit.StyleRow(r)
    local c = Kit.C[r.on and "row.bgOn" or (r.hovered and "row.bgHover" or "row.bg")]
    r.bg:SetTexture(c[1], c[2], c[3], c[4] or 1)
end
local function RowClick(self, button)
    if button == "RightButton" then
        if self.onRightClick then self.onRightClick(self) end
    elseif self.onClick then
        self.onClick(self)
    end
end
local RowWrap = ns.Prof.Wrap("ui.click", RowClick)
local function RowEnter(self)
    self.hovered = true
    Kit.StyleRow(self)
    Kit.TipShow(self)
end
local function RowLeave(self)
    self.hovered = false
    Kit.StyleRow(self)
    Kit.TipHide()
end
function Kit.Row(parent, width)
    local r = CreateFrame("Button", nil, parent)
    r:SetWidth(width)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    Kit.AutoH(r, "GameFontHighlightSmall")
    r.text = Kit.Str(r, "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 0, 0)
    Kit.Text(r.text, "row.text")
    r.text:SetJustifyH("LEFT")
    r.tipTitle = false
    r:SetScript("OnClick", RowWrap)
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
    Kit.StyleRow(r)
    return r
end
Kit.OnTheme(function()
    for i = 1, #buttons do Restyle(buttons[i]) end
    for i = 1, #checks do StyleCheck(checks[i]) end
end)
local confirm
local function Answer(f, yes)
    local fn = yes and f.onYes or f.onNo
    f.onYes, f.onNo = nil, nil
    f:Hide()
    if fn then fn() end
end
local function ConfirmHide(f)
    if f.onYes or f.onNo then Answer(f, false) end
end
local function ConfirmButton(f, name, yes)
    local b = Kit.Button(f, name)
    b.tipTitle = false
    b:SetWidth(120)
    b:SetHeight(22)
    if yes then
        b:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
    else
        b:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
    end
    b.onClick = function() Answer(f, yes) end
    return b
end
local function BuildConfirm()
    local f = CreateFrame("Frame", "HTP_FailWatchConfirm", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetWidth(380)
    f:SetHeight(120)
    f:SetPoint("CENTER", 0, 120)
    Kit.Skin(f, "plate")
    f:EnableMouse(true)
    tinsert(UISpecialFrames, "HTP_FailWatchConfirm")
    f.text = Kit.Str(f, "GameFontHighlight")
    f.text:SetPoint("TOP", 0, -16)
    f.text:SetWidth(340)
    f.yes = ConfirmButton(f, "HTP_FailWatchConfirmYes", true)
    f.no = ConfirmButton(f, "HTP_FailWatchConfirmNo", false)
    f:SetScript("OnHide", ConfirmHide)
    return f
end
function Kit.Confirm(text, yes, onYes, onNo, no)
    local f = confirm or BuildConfirm()
    confirm = f
    local was = f.onNo
    f.onYes, f.onNo = nil, nil
    if was then was() end
    f.text:SetText(text)
    f.yes.text:SetText(yes)
    f.no.text:SetText(no or ns.T("kit.no"))
    f.onYes, f.onNo = onYes, onNo
    Kit.ConfirmSize(f)
    f:Show()
end
function Kit.ConfirmSize(f)
    local k = Kit.FontScale("GameFontHighlight", true)
    f:SetWidth(floor(380 * k + 0.5))
    f.text:SetWidth(floor(340 * k + 0.5))
    f.yes:SetWidth(floor(120 * k + 0.5))
    f.no:SetWidth(floor(120 * k + 0.5))
    local th = f.text:GetHeight() or 0
    f:SetHeight(max(120, floor(16 + th + 16 + f.yes:GetHeight() + 14 + 0.5)))
end
Kit.OnFont(function()
    if confirm and confirm:IsShown() then Kit.ConfirmSize(confirm) end
end)
function Kit.Confirming()
    return confirm ~= nil and confirm:IsShown() and (confirm.onYes ~= nil or confirm.onNo ~= nil)
end
