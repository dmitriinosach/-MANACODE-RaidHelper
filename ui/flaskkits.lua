local _, ns = ...
local format = string.format
local floor, max, min = math.floor, math.max, math.min
local ICON = 16
local LABEL_W = 220
local SEL_W = 200
local BTN_W = 76
local ADD_W = 110
local COUNT_W = 26
local BAGS_W = 96
local ROW_MAX = 560
local MENU_ICON = 14
local PICK_W = 320
local PICK_ROWS = 14
local PICK_ROW = 18
local PICK_PAD = 6
local PICK_BAR = 10
local PICK_COUNT = 30
local RETRY = 1
local RETRIES = 5
local F = ns.Flasks
local Kit = ns.Kit
local S = ns.Settings
local T = ns.T
local ed = { blocks = {} }
local KitView = {}
ns.FlaskKitView = KitView
local retry = CreateFrame("Frame")
retry:Hide()
retry.left, retry.tries = 0, 0
local function Sizes()
    local ctl = Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
    return ctl + 4, ctl, Kit.Space.row, floor(LABEL_W * Kit.FontScale("GameFontNormalSmall", true) + 0.5)
end
local function Btn(parent, text, tip, run, kind)
    local b = Kit.Button(parent, nil, kind)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetText(text)
    b.tipTitle = false
    b.tip = tip
    b.onClick = function() run(b) end
    return b
end
local function Str(parent, token)
    local fs = Kit.Str(parent, "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function Step(kind, i, d)
    local e = F.KitItems(kind)[i]
    if e then F.KitCount(kind, i, e.n + d) end
end
local function NewRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.name = Str(r, "text.bright")
    r.bags = Str(r, "text.secondary")
    r.bags:SetJustifyH("RIGHT")
    r.minus = Btn(r, "-", T("flask.kit.minus.tip"), function() Step(r.kind, r.i, -1) end, "quiet")
    r.count = Str(r, "text.primary")
    r.count:SetJustifyH("CENTER")
    r.plus = Btn(r, "+", T("flask.kit.plus.tip"), function() Step(r.kind, r.i, 1) end, "quiet")
    r.del = Btn(r, "x", T("flask.kit.del.tip"), function() F.KitRemove(r.kind, r.i) end, "quiet")
    for _, b in ipairs({ r.minus, r.plus, r.del }) do Kit.ExactSize(b) end
    return r
end
local function PlaceRow(r, w, rowH, ctl, gap)
    r:SetWidth(w)
    r:SetHeight(rowH)
    r.icon:SetWidth(ICON)
    r.icon:SetHeight(ICON)
    r.icon:ClearAllPoints()
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    for _, b in ipairs({ r.del, r.plus, r.minus }) do
        b:SetWidth(ctl)
        b:SetHeight(ctl)
        b:ClearAllPoints()
    end
    r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.plus:SetPoint("RIGHT", r.del, "LEFT", -gap * 2, 0)
    r.count:SetWidth(COUNT_W)
    r.count:ClearAllPoints()
    r.count:SetPoint("RIGHT", r.plus, "LEFT", 0, 0)
    r.minus:SetPoint("RIGHT", r.count, "LEFT", 0, 0)
    r.bags:SetWidth(BAGS_W)
    r.bags:ClearAllPoints()
    r.bags:SetPoint("RIGHT", r.minus, "LEFT", -gap * 2, 0)
    r.name:ClearAllPoints()
    r.name:SetPoint("LEFT", r.icon, "RIGHT", gap, 0)
    r.name:SetPoint("RIGHT", r.bags, "LEFT", -gap, 0)
end
local function FillRow(r, kind, i, e)
    r.kind, r.i = kind, i
    r.icon:SetTexture(F.Icon(e.id))
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name:SetText(F.Name(e.id))
    local n = GetItemCount(e.id) or 0
    r.bags:SetText(format(T("flask.kit.bags"), n))
    Kit.Text(r.bags, n > 0 and "text.secondary" or "text.bad")
    r.count:SetText(tostring(e.n))
    if e.n > 1 then r.minus:Enable() else r.minus:Disable() end
    if e.n < F.KIT_MAX then r.plus:Enable() else r.plus:Disable() end
    return GetItemInfo(e.id) ~= nil
end
local pick = { all = {}, shown = {}, query = "" }
local function Lower(text)
    local G = ns.GuildNotes
    return G and G.Lower and G.Lower(text) or text:lower()
end
local function PickSizes()
    return Kit.GrowH(PICK_ROW, "GameFontHighlightSmall"), Kit.GrowH(Kit.Space.ctl, "GameFontNormalSmall")
end
local function RootOf(f)
    while true do
        local up = f:GetParent()
        if not up or up == UIParent then return f end
        f = up
    end
end
local function PickClose()
    if pick.catcher then pick.catcher:Hide() end
end
local function PickFilter()
    local q, out = pick.query, {}
    for i = 1, #pick.all do
        local e = pick.all[i]
        if q == "" or Lower(e.name):find(q, 1, true) then out[#out + 1] = e end
    end
    return out
end
local function PickFill(r, e, k)
    local rowH, ctl = PickSizes()
    r.item = e
    r:SetHeight(rowH)
    r:SetWidth(PICK_W - PICK_PAD * 2 - PICK_BAR)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", pick.frame, "TOPLEFT", PICK_PAD, -(PICK_PAD + ctl + Kit.Space.row + (k - 1) * rowH))
    r.icon:SetTexture(F.Icon(e.id))
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.text:SetText(e.name)
    Kit.Text(r.text, e.n > 0 and "text.bright" or "text.muted")
    r.count:SetText(tostring(e.n))
    Kit.Text(r.count, e.n > 0 and "text.secondary" or "text.off")
    r.tipLink = "item:" .. e.id
end
local function PickRow()
    local r = Kit.Row(pick.frame, PICK_W)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(MENU_ICON)
    r.icon:SetHeight(MENU_ICON)
    r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.count = Str(r, "text.secondary")
    r.count:SetJustifyH("RIGHT")
    r.count:SetWidth(PICK_COUNT)
    r.count:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.text:SetPoint("RIGHT", r.count, "LEFT", -4, 0)
    r.onClick = function(self)
        local e, kind = self.item, pick.kind
        if not (e and kind) then return end
        PickClose()
        F.KitAdd(kind, e.id)
    end
    return r
end
local function PickDraw()
    local f = pick.frame
    if not f then return end
    local rowH, ctl = PickSizes()
    pick.shown = PickFilter()
    local n = #pick.shown
    local slots = max(1, min(PICK_ROWS, n))
    local top = PICK_PAD + ctl + Kit.Space.row
    f:SetWidth(PICK_W)
    f:SetHeight(top + slots * rowH + PICK_PAD)
    pick.edit:SetWidth(PICK_W - PICK_PAD * 2)
    pick.edit:SetHeight(ctl)
    pick.list:Draw(pick.shown, slots)
    if n > slots then
        pick.bar:ClearAllPoints()
        pick.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PICK_PAD, -top)
        pick.bar:SetHeight(slots * rowH)
        pick.bar:SetState(pick.list.offset, slots, n)
        pick.bar:Show()
    else
        pick.bar:Hide()
    end
    if n == 0 then pick.none:Show() else pick.none:Hide() end
    if pick.query == "" then pick.hint:Show() else pick.hint:Hide() end
end
local function PickBuild(anchor)
    local root = RootOf(anchor)
    local c = CreateFrame("Frame", nil, root)
    c:SetAllPoints(root)
    c:SetFrameStrata("FULLSCREEN_DIALOG")
    c:EnableMouse(true)
    c:SetScript("OnMouseDown", PickClose)
    c:SetScript("OnHide", function(self)
        if self:IsShown() then self:Hide() end
        if pick.edit then pick.edit:ClearFocus() end
    end)
    c:Hide()
    local f = CreateFrame("Frame", nil, c)
    f:SetFrameLevel(c:GetFrameLevel() + 10)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f.sized = true
    Kit.Backdrop(f, Kit.Theme().list)
    pick.catcher, pick.frame = c, f
    local e = Kit.Edit(f, false, "ManaCodeRaidHelperFlaskKitFind")
    e:SetFontObject(Kit.FontFor("GameFontHighlightSmall", true))
    e:SetMaxLetters(40)
    e:SetPoint("TOPLEFT", f, "TOPLEFT", PICK_PAD, -PICK_PAD)
    e.tipTitle = false
    e.onChange = function(text)
        pick.query = Lower((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
        pick.list.offset = 0
        PickDraw()
    end
    e:SetScript("OnEscapePressed", PickClose)
    pick.edit = e
    pick.hint = Str(e, "text.off")
    pick.hint:SetPoint("LEFT", e, "LEFT", 8, 0)
    pick.hint:SetText(T("flask.kit.find"))
    pick.none = Str(f, "text.muted")
    pick.none:SetPoint("TOPLEFT", e, "BOTTOMLEFT", 4, -Kit.Space.row - 2)
    pick.none:SetText(T("flask.kit.find.none"))
    pick.bar = Kit.ScrollBar(f, 100)
    pick.bar.onScroll = function(offset)
        pick.list.offset = offset
        PickDraw()
    end
    pick.list = Kit.List(PickRow, PickFill, { clear = function(r) r.item = nil end })
    f:SetScript("OnMouseWheel", function(_, delta)
        if pick.list:Wheel(delta) then PickDraw() end
    end)
end
local function OpenAdd(kind, b)
    Kit.SelectClose()
    if not pick.frame then PickBuild(b) end
    local root = RootOf(b)
    if pick.catcher:GetParent() ~= root then
        pick.catcher:SetParent(root)
        pick.catcher:ClearAllPoints()
        pick.catcher:SetAllPoints(root)
        pick.catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        pick.frame:SetFrameLevel(pick.catcher:GetFrameLevel() + 10)
    end
    pick.kind, pick.all, pick.query = kind, F.AddList(kind), ""
    pick.list.offset = 0
    pick.edit:SetValue("")
    PickDraw()
    local f = pick.frame
    local bottom, floorY = b:GetBottom(), root:GetBottom()
    f:ClearAllPoints()
    if bottom and floorY and bottom - 2 - f:GetHeight() < floorY then
        f:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 2)
    else
        f:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
    end
    pick.catcher:Show()
    pick.edit:SetFocus()
end
function KitView.AddItems(kind, query)
    pick.all, pick.query = F.AddList(kind), Lower(query or "")
    return PickFilter()
end
function KitView.Picker()
    return pick
end
local function NewBlock(kind)
    local body = ed.body
    local bl = { kind = kind, rows = {} }
    bl.head = Kit.Str(body, "GameFontNormalSmall")
    bl.head:SetJustifyH("LEFT")
    Kit.Text(bl.head, "text.title")
    bl.head:SetText(T("flask.kit.role." .. kind))
    bl.add = Btn(body, T("flask.kit.add"), T("flask.kit.add.tip"), function(b) OpenAdd(kind, b) end)
    bl.empty = Str(body, "text.muted")
    bl.empty:SetText(T("flask.kit.empty"))
    return bl
end
local function KitOptions()
    local k, out = F.Kits(), {}
    for i = 1, #k.list do out[i] = { key = i, label = k.list[i].name or format(T("flask.kit.new"), i) } end
    return out
end
local function Build(body)
    ed.body = body
    ed.pickCap = Str(body, "text.primary")
    ed.pickCap:SetText(T("flask.kit.pick"))
    ed.pick = Kit.Select(body)
    ed.pick.tipTitle = false
    ed.pick.tip = T("flask.kit.pick.tip")
    ed.pick.onPick = function(i) F.KitPick(i) end
    ed.new = Btn(body, T("flask.kit.btn.new"), T("flask.kit.btn.new.tip"), F.KitNew)
    ed.copy = Btn(body, T("flask.kit.btn.copy"), T("flask.kit.btn.copy.tip"), F.KitCopy)
    ed.del = Btn(body, T("flask.kit.btn.del"), T("flask.kit.btn.del.tip"), function()
        Kit.Confirm(format(T("flask.kit.btn.del.ask"), F.Kit().name or ""), T("flask.kit.btn.del"),
            function() F.KitDelete() end)
    end, "danger")
    ed.nameCap = Str(body, "text.primary")
    ed.nameCap:SetText(T("flask.kit.name"))
    ed.name = Kit.Edit(body, false, "ManaCodeRaidHelperFlaskKitName")
    ed.name:SetFontObject(Kit.FontFor("GameFontHighlightSmall", true))
    ed.name:SetMaxLetters(40)
    ed.name.tipTitle = false
    ed.name.tip = T("flask.kit.name.tip")
    ed.name.onChange = function(text) F.KitRename(text) end
    ed.name.onCommit = function(text)
        F.KitRename(text)
        KitView.Refresh()
    end
    for i = 1, #ns.flaskKinds do ed.blocks[i] = NewBlock(ns.flaskKinds[i]) end
end
local function Height()
    local rowH, _, gap = Sizes()
    local n = 0
    for i = 1, #ns.flaskKinds do n = n + 1 + max(1, #F.KitItems(ns.flaskKinds[i])) end
    return rowH * (2 + (ed.wrap and 1 or 0) + n) + gap * (1 + #ns.flaskKinds)
end
local function Left(fs, y, rowH, x)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", ed.body, "TOPLEFT", x or 0, -(y + rowH / 2))
end
local function Ctl(f, x, y, w, ctl, rowH)
    f:SetWidth(w)
    f:SetHeight(ctl)
    f:ClearAllPoints()
    f:SetPoint("LEFT", ed.body, "TOPLEFT", x, -(y + rowH / 2))
end
local function PlaceHead(w)
    local rowH, ctl, gap, lw = Sizes()
    local y = 0
    Left(ed.pickCap, y, rowH)
    ed.pick:SetOptions(KitOptions(), F.Kits().cur)
    Ctl(ed.pick, lw, y, SEL_W, ctl, rowH)
    local x = lw + SEL_W + gap
    ed.wrap = x + (BTN_W + gap) * 3 - gap > w
    if ed.wrap then
        x, y = lw, y + rowH
    end
    for _, b in ipairs({ ed.new, ed.copy, ed.del }) do
        Ctl(b, x, y, BTN_W, ctl, rowH)
        x = x + BTN_W + gap
    end
    if #F.Kits().list > 1 then ed.del:Enable() else ed.del:Disable() end
    y = y + rowH
    Left(ed.nameCap, y, rowH)
    Ctl(ed.name, lw, y, SEL_W, ctl, rowH)
    if not ed.name:HasFocus() then ed.name:SetValue(F.Kit().name or "") end
    return y + rowH
end
local function PlaceBlock(bl, y, w)
    local rowH, ctl, gap = Sizes()
    local body, miss = ed.body, false
    local list = F.KitItems(bl.kind)
    y = y + gap
    Left(bl.head, y, rowH)
    Ctl(bl.add, w - ADD_W, y, ADD_W, ctl, rowH)
    local room = #list < F.KIT_ITEMS
    if room then bl.add:Enable() else bl.add:Disable() end
    bl.add.tip = room and T("flask.kit.add.tip") or format(T("flask.kit.full"), F.KIT_ITEMS)
    y = y + rowH
    for k = #bl.rows + 1, #list do bl.rows[k] = NewRow(body) end
    for k = 1, #bl.rows do
        local r = bl.rows[k]
        if list[k] then
            PlaceRow(r, w, rowH, ctl, gap)
            if not FillRow(r, bl.kind, k, list[k]) then miss = true end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            r:Show()
            y = y + rowH
        else
            r:Hide()
        end
    end
    if #list == 0 then
        Left(bl.empty, y, rowH, ICON + gap)
        bl.empty:Show()
        y = y + rowH
    else
        bl.empty:Hide()
    end
    return y, miss
end
function KitView.Refresh()
    local body = ed.body
    if not body then return end
    local w = min(ROW_MAX, max(1, body:GetWidth()))
    local y, miss = PlaceHead(max(1, body:GetWidth())), false
    for i = 1, #ed.blocks do
        local m
        y, m = PlaceBlock(ed.blocks[i], y, w)
        miss = miss or m
    end
    if miss and body:IsVisible() and retry.tries < RETRIES then
        retry.left, retry.tries = RETRY, retry.tries + 1
        retry:Show()
    elseif not miss then
        retry.tries = 0
    end
end
retry:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - elapsed
    if self.left > 0 then return end
    self:Hide()
    KitView.Refresh()
end)
function KitView.Head()
    if not ed.body then return "", "" end
    return ed.pick:GetText() or "", ed.name:GetText() or ""
end
function KitView.Block(kind)
    for i = 1, #ed.blocks do
        if ed.blocks[i].kind == kind then return ed.blocks[i] end
    end
    return nil
end
if S and S.Section then
    S.Section("flasks", "what", {
        label = "flask.set.what",
        order = 20,
        items = {
            { kind = "custom", key = "kits", height = Height,
              build = function(row)
                  Build(row)
                  row.Place = KitView.Refresh
              end,
              refresh = KitView.Refresh },
        },
    })
end
F.OnChange(function() KitView.Refresh() end)
Kit.OnFont(function()
    KitView.Refresh()
    PickClose()
end)
Kit.OnTheme(function()
    if pick.frame then Kit.Backdrop(pick.frame, Kit.Theme().list) end
end)
