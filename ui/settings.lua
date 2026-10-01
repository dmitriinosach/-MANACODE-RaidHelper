local _, ns = ...
local Kit = ns.Kit
local max = math.max
local ceil = math.ceil
local tsort = table.sort
local NAV_W = 184
local NAV_PAD = 6
local NAV_ROW = 22
local NAV_GROUP = 20
local NAV_TEXT = 12
local ACCENT_W = 3
local GAP = 10
local BAR = 6
local BARGAP = 4
local WHEEL = 40
local TITLE_H = 24
local SUB_GAP = 8
local CAP = 20
local INSET = 10
local ROW = 26
local HINT_GAP = 1
local HINT_IN = 26
local TEXT_PAD = 6
local SEC_GAP = 10
local ADV_H = 28
local ADV_BTN = 20
local CHECK = 24
local LABEL_W = 220
local CHOICE_W = 180
local FIELD_W = 120
local BTN_MIN = 120
local BTN_PAD = 24
local SEG_MIN = 72
local SEG_GAP = 4
local ARM = 10
local TICK = 1
local DEFAULT_CAT = "rec"
local GROUPS = { "general", "parse", "lead", "other" }
local RESETTABLE = { check = true, choice = true, slider = true, field = true }
local Settings = {}
ns.Settings = Settings
local cats = {}
local catList = {}
local page, nav, scroll, content, bar, ticker
local current
local offset = 0
local tickAcc = 0
local counter = 0
local navRows = {}
local Layout
local function Next()
    counter = counter + 1
    return counter
end
local function Text(v)
    if type(v) == "function" then return v() or "" end
    if v == nil then return "" end
    return ns.T(v)
end
local function Maybe(v)
    local t = Text(v)
    if t == "" then return nil end
    return t
end
local function Saved()
    local db = ns.GetDB()
    local s = db and db.settings
    if type(s) ~= "table" then return {} end
    if type(s.ui) ~= "table" then s.ui = {} end
    return s
end
local function Before(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.at < b.at
end
function Settings.Category(key, def)
    local c = cats[key]
    if not c then
        c = { key = key, sections = {}, at = Next(), order = 0, group = "other" }
        cats[key] = c
        catList[#catList + 1] = c
    end
    if def then
        c.label = def.label or c.label
        c.sub = def.sub or c.sub
        c.order = def.order or c.order
        c.group = def.group or c.group
    end
    return c
end
function Settings.Section(cat, key, def)
    local c = cats[cat] or Settings.Category(cat, nil)
    local sec
    for i = 1, #c.sections do
        if c.sections[i].key == key then sec = c.sections[i] end
    end
    if sec and (not def or sec.defined) then return sec end
    if not sec then
        sec = { key = key, cat = c, def = {}, items = {}, at = Next(), order = 0, adv = false }
        c.sections[#c.sections + 1] = sec
    end
    if not def then return sec end
    sec.def, sec.order, sec.adv, sec.defined = def, def.order or 0, def.advanced and true or false, true
    local items = def.items
    if items then
        for i = 1, #items do Settings.Item(cat, key, items[i]) end
    end
    return sec
end
function Settings.Item(cat, key, item)
    local sec = Settings.Section(cat, key, nil)
    item.at = Next()
    item.order = item.order or 0
    sec.items[#sec.items + 1] = item
    return item
end
function Settings.Categories()
    tsort(catList, Before)
    return catList
end
function Settings.Sections(cat, adv)
    local out = {}
    local c = cats[cat]
    if not c then return out end
    tsort(c.sections, Before)
    for i = 1, #c.sections do
        local s = c.sections[i]
        if s.adv == (adv and true or false) then out[#out + 1] = s end
    end
    return out
end
local function Items(sec)
    tsort(sec.items, Before)
    return sec.items
end
function Settings.Find(cat, key, label)
    local c = cats[cat]
    if not c then return nil end
    for i = 1, #c.sections do
        local s = c.sections[i]
        if s.key == key then
            for k = 1, #s.items do
                local it = s.items[k]
                if it.label == label or it.key == label then return it end
            end
        end
    end
    return nil
end
local function Shown(it)
    return not it.shown or it.shown() and true or false
end
local function Enabled(it)
    return not it.enabled or it.enabled() and true or false
end
local function AtDefault(it)
    if not RESETTABLE[it.kind] or it.default == nil or not it.get or not it.set then return true end
    return it.get() == it.default
end
function Settings.IsDefault(cat, all)
    local c = cats[cat]
    if not c then return true end
    for i = 1, #c.sections do
        local s = c.sections[i]
        if all or s.adv then
            for k = 1, #s.items do
                if not AtDefault(s.items[k]) then return false end
            end
        end
    end
    return true
end
function Settings.Advanced()
    return Saved().adv == true
end
local function Height(n, v)
    if type(n) == "function" then n = n(v) end
    if type(n) ~= "number" then return 0 end
    return max(0, n)
end
local function Label(r, token)
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", r, "TOPLEFT", 0, -ROW / 2)
    fs:SetWidth(LABEL_W - 8)
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function Tip(f, it, title)
    if title then f.tipTitle = Maybe(it.label) or false end
    f.tip = Maybe(it.tip)
    f.tipDim = Maybe(it.warn)
end
local function Apply(it, v)
    if it.set then it.set(v) end
    Settings.Refresh()
end
local function Ask(it, v)
    local text = it.ask and it.ask(v)
    if not text then
        Apply(it, v)
        return
    end
    Kit.Confirm(text, Text(it.askYes or "set.apply"), function() Apply(it, v) end, Settings.Refresh)
end
local function BuildCheck(r, it)
    local c = Kit.Check(r)
    c:SetWidth(CHECK)
    c:SetHeight(CHECK)
    c:SetPoint("LEFT", r, "TOPLEFT", -2, -ROW / 2)
    c.onToggle = function(on) Apply(it, on) end
    r.check = c
    r.Refresh = function()
        c.label:SetText(Text(it.label))
        Tip(c, it, true)
        c:SetChecked(it.get and it.get() and true or false)
        if Enabled(it) then
            c:Enable()
            Kit.Text(c.label, "check.label")
        else
            c:Disable()
            Kit.Text(c.label, "text.off")
        end
    end
    r.indent = HINT_IN
end
local function Options(it)
    local o = it.options
    if type(o) == "function" then o = o() end
    local out = {}
    for i = 1, #(o or {}) do
        local src = o[i]
        out[i] = { key = src.key, label = Text(src.label or src.key), tip = src.tip and Text(src.tip) or nil,
                   tipTitle = src.tip and false or nil }
    end
    return out
end
local function BuildButtons(r, it)
    local segs = {}
    local opts = Options(it)
    local x = LABEL_W
    for i = 1, #opts do
        local o = opts[i]
        local b = Kit.Button(r)
        b:SetText(o.label)
        b.tipTitle = false
        b.tip = o.tip
        b:SetWidth(max(SEG_MIN, b.text:GetStringWidth() + BTN_PAD))
        b:SetPoint("LEFT", r, "TOPLEFT", x, -ROW / 2)
        x = x + b:GetWidth() + SEG_GAP
        b.onClick = function() Apply(it, o.key) end
        b.key = o.key
        segs[i] = b
    end
    r.segs = segs
end
local function BuildChoice(r, it)
    local label = Label(r, "text.primary")
    local sel
    if it.buttons then
        BuildButtons(r, it)
    else
        sel = Kit.Select(r)
        sel:SetWidth(it.width or CHOICE_W)
        sel:SetPoint("LEFT", r, "TOPLEFT", LABEL_W, -ROW / 2)
        sel.onPick = function(k) Apply(it, k) end
        r.sel = sel
    end
    r.Refresh = function()
        label:SetText(Text(it.label))
        local cur = it.get and it.get()
        local on = Enabled(it)
        if sel then
            Tip(sel, it, true)
            sel:SetOptions(Options(it), cur)
            if on then sel:Enable() else sel:Disable() end
        end
        for i = 1, #(r.segs or {}) do
            local b = r.segs[i]
            b:SetActive(b.key == cur)
            if on then b:Enable() else b:Disable() end
        end
        Kit.Text(label, on and "text.primary" or "text.off")
    end
end
local function BuildSlider(r, it)
    local s = Kit.Slider(r, { min = it.min or 0, max = it.max or 1, step = it.step, fmt = it.fmt, labelW = LABEL_W })
    s:SetPoint("LEFT", r, "TOPLEFT", 0, -ROW / 2)
    s:SetPoint("RIGHT", r, "TOPRIGHT", 0, -ROW / 2)
    if it.live then
        s.onChange = function(v) if it.set then it.set(v) end end
    else
        s.onCommit = function(v) Ask(it, v) end
    end
    r.slider = s
    r.Refresh = function()
        s.label:SetText(Text(it.label))
        Tip(s, it, true)
        if not s.dragging and it.get then s:SetValue(it.get()) end
        if Enabled(it) then s:Enable() else s:Disable() end
    end
end
local function BuildField(r, it)
    local label = Label(r, "text.primary")
    local e = Kit.Edit(r, false)
    e:SetWidth(it.width or FIELD_W)
    e:SetPoint("LEFT", r, "TOPLEFT", LABEL_W, -ROW / 2)
    if it.numeric then e:SetNumeric(true) end
    if it.maxLetters then e:SetMaxLetters(it.maxLetters) end
    e:SetScript("OnEscapePressed", function(self)
        self.revert = true
        self:ClearFocus()
    end)
    e.onCommit = function(text)
        if e.revert then
            e.revert = nil
            Settings.Refresh()
            return
        end
        Apply(it, it.numeric and (tonumber(text) or 0) or text)
    end
    r.edit = e
    r.Refresh = function()
        label:SetText(Text(it.label))
        Tip(e, it, true)
        if not e:HasFocus() then
            local v = it.get and it.get()
            e:SetValue(v ~= nil and tostring(v) or "")
        end
    end
end
local function Armed(b)
    return b.armedAt ~= nil and GetTime() - b.armedAt <= ARM
end
local function BuildButton(r, it)
    local label = it.text and it.label and Label(r, "text.primary") or nil
    local b = Kit.Button(r)
    b:SetPoint("LEFT", r, "TOPLEFT", label and LABEL_W or 0, -ROW / 2)
    b.onClick = function()
        if it.confirm and not Armed(b) then
            b.armedAt = GetTime()
            r.Refresh()
            return
        end
        b.armedAt = nil
        if it.run then it.run(b) end
        Settings.Refresh()
    end
    r.button = b
    r.Refresh = function()
        if label then label:SetText(Text(it.label)) end
        if b.armedAt and not Armed(b) then b.armedAt = nil end
        b:SetText(Text(Armed(b) and it.confirm or (it.text or it.label)))
        b:SetWidth(max(it.width or BTN_MIN, b.text:GetStringWidth() + BTN_PAD))
        Tip(b, it, false)
        b.tint = it.danger and Kit.C["text.bad"] or nil
        if Enabled(it) then b:Enable() else b:Disable() end
    end
end
local function BuildText(r, it)
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -TEXT_PAD / 2)
    fs:SetJustifyH("LEFT")
    r.text = fs
    r.Refresh = function()
        fs:SetText(Text(it.text or it.label))
        local tok = it.token
        if type(tok) == "function" then tok = tok() end
        Kit.Text(fs, tok or "text.secondary")
    end
end
local function BuildCustom(r, it)
    if it.build then it.build(r, it) end
    r.Refresh = function()
        if it.refresh then it.refresh(r, it) end
    end
end
local BUILD = {
    check = BuildCheck,
    choice = BuildChoice,
    slider = BuildSlider,
    field = BuildField,
    button = BuildButton,
    text = BuildText,
    custom = BuildCustom,
}
local function BuildItem(parent, it)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW)
    r.indent = 0
    local make = BUILD[it.kind] or BuildText
    make(r, it)
    if it.hint then
        local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        Kit.Text(fs, "text.muted")
        r.hint = fs
    end
    it.w = r
    r.Refresh()
end
local function ItemHeight(it, w)
    local r = it.w
    local h = ROW
    if it.kind == "custom" then
        return Height(it.height, r)
    elseif it.kind == "text" or not BUILD[it.kind] then
        r.text:SetWidth(w)
        h = ceil(r.text:GetStringHeight()) + TEXT_PAD
    end
    if r.hint then
        r.hint:ClearAllPoints()
        r.hint:SetPoint("TOPLEFT", r, "TOPLEFT", r.indent, -(h + HINT_GAP))
        r.hint:SetWidth(max(1, w - r.indent))
        local hint = Text(it.hint)
        r.hint:SetText(hint)
        if hint ~= "" then h = h + HINT_GAP + ceil(r.hint:GetStringHeight()) + 2 end
    end
    return h
end
local function HideSection(sec)
    if sec.frame then sec.frame:Hide() end
    if sec.head then sec.head:Hide() end
    if sec.body then sec.body:Hide() end
end
local function PlaceCustom(sec, holder, y, w)
    local d = sec.def
    if not sec.body then
        sec.head = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec.head:SetJustifyH("LEFT")
        Kit.Title(sec.head)
        sec.body = CreateFrame("Frame", nil, holder)
        d.build(sec.body)
    end
    local label = Text(d.label)
    sec.head:ClearAllPoints()
    sec.head:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    sec.head:SetText(label)
    sec.head:Show()
    if label ~= "" then y = y + CAP end
    sec.body:ClearAllPoints()
    sec.body:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    sec.body:SetWidth(w)
    local bh = Height(d.height, sec.body)
    sec.body:SetHeight(max(1, bh))
    sec.body:Show()
    return y + bh + SEC_GAP
end
local function PlaceSection(sec, holder, y, w)
    if sec.def.build then return PlaceCustom(sec, holder, y, w) end
    local list = Items(sec)
    local any = false
    for i = 1, #list do
        if Shown(list[i]) then any = true end
    end
    if not any then
        HideSection(sec)
        return y
    end
    if not sec.frame then
        sec.frame = CreateFrame("Frame", nil, holder)
        Kit.Skin(sec.frame, "panel")
        sec.head = sec.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec.head:SetPoint("TOPLEFT", sec.frame, "TOPLEFT", INSET, -INSET)
        sec.head:SetJustifyH("LEFT")
        Kit.Title(sec.head)
    end
    local f = sec.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    f:SetWidth(w)
    local iy = INSET - 4
    local label = Text(sec.def.label)
    sec.head:SetText(label)
    if label ~= "" then
        sec.head:Show()
        iy = INSET + CAP - 2
    else
        sec.head:Hide()
    end
    local inner = max(1, w - INSET * 2)
    for i = 1, #list do
        local it = list[i]
        if Shown(it) then
            if not it.w then BuildItem(f, it) end
            local r = it.w
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f, "TOPLEFT", INSET, -iy)
            r:SetWidth(inner)
            local h = ItemHeight(it, inner)
            r:SetHeight(max(1, h))
            r:Show()
            iy = iy + h
        elseif it.w then
            it.w:Hide()
        end
    end
    iy = iy + INSET - 2
    f:SetHeight(iy)
    f:Show()
    return y + iy + SEC_GAP
end
local function RefreshAdv(c)
    local a = c.adv
    if not a then return end
    a.toggle:SetText(c.open and "-" or "+")
    if Settings.IsDefault(c.key, false) then a.reset:Disable() else a.reset:Enable() end
end
local function BuildAdv(c)
    local a = CreateFrame("Button", nil, c.holder)
    a:SetHeight(ADV_H)
    Kit.Skin(a, "panel")
    a:RegisterForClicks("LeftButtonUp")
    a:SetScript("OnClick", function()
        c.open = not c.open
        Kit.Sound("click")
        Layout()
        RefreshAdv(c)
    end)
    a.toggle = Kit.Button(a)
    a.toggle:SetWidth(ADV_BTN)
    a.toggle:SetHeight(ADV_BTN)
    a.toggle:SetPoint("LEFT", a, "LEFT", INSET - 2, 0)
    a.toggle.tipTitle = false
    a.toggle.tip = ns.T("set.adv.open.tip")
    a.toggle.onClick = function() a:GetScript("OnClick")(a) end
    a.label = a:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    a.label:SetPoint("LEFT", a.toggle, "RIGHT", 8, 0)
    a.label:SetText(ns.T("set.adv"))
    Kit.Text(a.label, "text.secondary")
    a.reset = Kit.Button(a)
    a.reset:SetText(ns.T("set.adv.reset"))
    a.reset:SetWidth(max(BTN_MIN, a.reset.text:GetStringWidth() + BTN_PAD))
    a.reset:SetPoint("RIGHT", a, "RIGHT", -(INSET - 2), 0)
    a.reset.tipTitle = false
    a.reset.tip = ns.T("set.adv.reset.tip")
    a.reset.onClick = function() Settings.Reset(c.key, false) end
    c.adv = a
end
local function BuildCat(c)
    local h = CreateFrame("Frame", nil, content)
    h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    c.holder = h
    c.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    c.title:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    c.title:SetJustifyH("LEFT")
    Kit.Title(c.title)
    c.subFs = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.subFs:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -TITLE_H)
    c.subFs:SetJustifyH("LEFT")
    Kit.Text(c.subFs, "text.secondary")
end
local function LayoutCat(c, w)
    local h = c.holder
    h:SetWidth(w)
    c.title:SetText(Text(c.label))
    local y = TITLE_H
    local sub = Text(c.sub)
    if sub ~= "" then
        c.subFs:SetWidth(w)
        c.subFs:SetText(sub)
        c.subFs:Show()
        y = y + ceil(c.subFs:GetStringHeight())
    else
        c.subFs:Hide()
    end
    y = y + SUB_GAP
    local list = Settings.Sections(c.key, false)
    for i = 1, #list do y = PlaceSection(list[i], h, y, w) end
    local advs = Settings.Sections(c.key, true)
    local showAdv = #advs > 0 and Settings.Advanced()
    if showAdv then
        if not c.adv then BuildAdv(c) end
        c.adv:ClearAllPoints()
        c.adv:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -y)
        c.adv:SetWidth(w)
        c.adv:Show()
        RefreshAdv(c)
        y = y + ADV_H + SEC_GAP
    elseif c.adv then
        c.adv:Hide()
    end
    for i = 1, #advs do
        if showAdv and c.open then
            y = PlaceSection(advs[i], h, y, w)
        else
            HideSection(advs[i])
        end
    end
    h:SetHeight(max(1, y))
    return y
end
local function ScrollTo()
    local most = max(0, content:GetHeight() - scroll:GetHeight())
    if offset > most then offset = most end
    if offset < 0 then offset = 0 end
    scroll:SetVerticalScroll(offset)
    bar:SetState(offset, scroll:GetHeight(), content:GetHeight())
end
Layout = function()
    if not page or not current then return end
    local c = cats[current]
    if not c or not c.holder then return end
    local w = max(1, scroll:GetWidth())
    local h = LayoutCat(c, w)
    content:SetWidth(w)
    content:SetHeight(max(1, h))
    ScrollTo()
end
local function RefreshCat(c)
    for i = 1, #c.sections do
        local s = c.sections[i]
        for k = 1, #s.items do
            local it = s.items[k]
            if it.w then it.w.Refresh() end
        end
    end
    RefreshAdv(c)
end
local function CallSections(c, name)
    for i = 1, #c.sections do
        local s = c.sections[i]
        local fn = s.def[name]
        if fn and s.body then fn(s.body) end
    end
end
local function PaintNav()
    for i = 1, #navRows do
        local r = navRows[i]
        r.on = r.catKey == current
        Kit.StyleRow(r)
        Kit.Text(r.text, r.on and "text.title" or "text.primary")
        if r.on then r.accent:Show() else r.accent:Hide() end
    end
end
local function Activate(c)
    if not c.holder then BuildCat(c) end
    c.holder:Show()
    Layout()
    RefreshCat(c)
    CallSections(c, "OnShow")
    Layout()
    PaintNav()
end
local function Resolve(key)
    if key and cats[key] then return key end
    if cats[DEFAULT_CAT] then return DEFAULT_CAT end
    local list = Settings.Categories()
    return list[1] and list[1].key or nil
end
function Settings.Select(key)
    key = Resolve(key)
    if not key or not page then return end
    if key == current then
        Layout()
        return
    end
    local old = current and cats[current]
    if old and old.holder then
        CallSections(old, "OnHide")
        old.holder:Hide()
    end
    current = key
    Saved().ui.setCat = key
    offset = 0
    Activate(cats[key])
end
function Settings.Current()
    return current
end
local function NavClick(row)
    Kit.Sound("tab")
    Settings.Select(row.catKey)
end
local function BuildNav()
    local y = NAV_PAD
    local list = Settings.Categories()
    for g = 1, #GROUPS do
        local grp = GROUPS[g]
        local any = false
        for i = 1, #list do
            if list[i].group == grp then any = true end
        end
        if any then
            local fs = nav:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            fs:SetPoint("TOPLEFT", nav, "TOPLEFT", NAV_PAD + NAV_TEXT, -(y + 6))
            fs:SetText(ns.T("set.group." .. grp))
            Kit.Text(fs, "nav.group")
            y = y + NAV_GROUP
            for i = 1, #list do
                local c = list[i]
                if c.group == grp then
                    local r = Kit.Row(nav, NAV_W - NAV_PAD * 2)
                    r:SetHeight(NAV_ROW)
                    r:SetPoint("TOPLEFT", nav, "TOPLEFT", NAV_PAD, -y)
                    r.text:ClearAllPoints()
                    r.text:SetPoint("LEFT", r, "LEFT", NAV_TEXT, 0)
                    r.text:SetText(Text(c.label))
                    r.accent = r:CreateTexture(nil, "ARTWORK")
                    r.accent:SetWidth(ACCENT_W)
                    r.accent:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
                    r.accent:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
                    Kit.Paint(r.accent, "nav.accent")
                    r.catKey = c.key
                    r.onClick = NavClick
                    navRows[#navRows + 1] = r
                    y = y + NAV_ROW
                end
            end
            y = y + 4
        end
    end
end
local function Wheel(_, delta)
    offset = offset - delta * WHEEL
    ScrollTo()
end
local function Tick(_, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK then return end
    tickAcc = 0
    local c = current and cats[current]
    if not c then return end
    for i = 1, #c.sections do
        local s = c.sections[i]
        for k = 1, #s.items do
            local it = s.items[k]
            if it.w and (it.tick or it.confirm) and it.w:IsShown() then it.w.Refresh() end
        end
    end
end
local function Build(host)
    page = host
    nav = CreateFrame("Frame", nil, page)
    Kit.Skin(nav, "panel")
    nav:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    nav:SetWidth(NAV_W)
    BuildNav()
    scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", GAP, 0)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -(BAR + BARGAP), 0)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", Wheel)
    scroll:SetScript("OnSizeChanged", function() Layout() end)
    bar = Kit.ScrollBar(page, 1)
    bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    bar.onScroll = function(want)
        offset = want
        ScrollTo()
    end
    ticker = CreateFrame("Frame", nil, page)
    ticker:SetScript("OnUpdate", Tick)
end
local function ShowPage()
    if not current then
        current = Resolve(Saved().ui.setCat)
        if not current then return end
    end
    Activate(cats[current])
end
local function HidePage()
    local c = current and cats[current]
    if c then CallSections(c, "OnHide") end
end
function Settings.Refresh()
    if not page or not page:IsVisible() then return end
    local c = current and cats[current]
    if not c or not c.holder then return end
    RefreshCat(c)
    Layout()
end
Settings.RefreshRecord = Settings.Refresh
function Settings.SetAdvanced(on)
    Saved().adv = on and true or nil
    Settings.Refresh()
end
function Settings.Reset(cat, all)
    local n = 0
    local c = cats[cat]
    if not c then return 0 end
    for i = 1, #c.sections do
        local s = c.sections[i]
        if all or s.adv then
            for k = 1, #s.items do
                local it = s.items[k]
                if not AtDefault(it) then
                    it.set(it.default)
                    n = n + 1
                end
            end
        end
    end
    Settings.Refresh()
    return n
end
function Settings.Open(cat)
    ns.Shell.Open("settings")
    if cat then Settings.Select(cat) end
end
function Settings.Widget(item)
    return item.w
end
function ns.Shell.Section(key, def)
    return Settings.Section(def.cat or "svc", key, def)
end
function ns.Shell.SectionResized()
    Layout()
end
Settings.Category("look", { label = "set.cat.look", sub = "set.cat.look.sub", order = 10, group = "general" })
Settings.Category("panel", { label = "set.cat.panel", sub = "set.cat.panel.sub", order = 20, group = "general" })
Settings.Category("rec", { label = "set.cat.rec", sub = "set.cat.rec.sub", order = 30, group = "parse" })
Settings.Category("parse", { label = "set.cat.parse", sub = "set.cat.parse.sub", order = 40, group = "parse" })
Settings.Category("gp", { label = "set.cat.gp", sub = "set.cat.gp.sub", order = 50, group = "parse" })
Settings.Category("cost", { label = "set.cat.cost", sub = "set.cat.cost.sub", order = 60, group = "parse" })
Settings.Category("lead", { label = "set.cat.lead", sub = "set.cat.lead.sub", order = 70, group = "lead" })
Settings.Category("guild", { label = "set.cat.guild", sub = "set.cat.guild.sub", order = 80, group = "other" })
Settings.Category("svc", { label = "set.cat.svc", sub = "set.cat.svc.sub", order = 90, group = "other" })
Kit.OnTheme(PaintNav)
ns.Shell.Register("settings", {
    label = "shell.tab.settings",
    order = 100,
    right = true,
    icon = Kit.GEAR_TEX,
    build = Build,
    OnShow = ShowPage,
    OnHide = HidePage,
    OnSize = function() Layout() end,
})
