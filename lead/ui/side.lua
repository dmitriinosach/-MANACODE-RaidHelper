local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local W = 280
local EDGE = 12
local ROW_H = 44
local ARROW = "Interface\\Buttons\\UI-SpellbookIcon-%sPage-%s"
local HEAD_H = 24
local PAD = 8
local WHEEL = 36
local TOGGLE_OUT = 14
local ROW_W = W - EDGE * 2 - PAD * 2 - 4
local NAME = "GameFontNormalSmall"
local INFO = "GameFontHighlightSmall"
local side, toggle, scroll, child, unHead, waitHead, emptyFs
local unPool, waitPool
local built = false
ns.Side = {}
function ns.Side.Open()
    return ns.Store.DB().sideOpen ~= false
end
local function rowH()
    return ns.Fit(INFO, ROW_H, 31)
end
local function headH()
    return ns.Fit("GameFontNormal", HEAD_H, 6)
end
local function fitRow(r, line)
    r:SetHeight(rowH() - 2)
    r.name:SetHeight(ns.LineH(NAME))
    line:SetHeight(ns.LineH(INFO))
end
local function header(text)
    local fs = ns.Str(child, "GameFontNormal")
    ns.PaintTitle(fs)
    fs.base = text
    return fs
end
local function newUnRow()
    local r = ns.NewFrame("Frame", nil, child)
    r:SetSize(ROW_W, ROW_H - 2)
    ns.Skin(r, "card")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    r:SetScript("OnLeave", ns.TipHide)
    r.spec = r:CreateTexture(nil, "ARTWORK")
    r.spec:SetSize(18, 18)
    r.spec:SetPoint("TOPLEFT", r, "TOPLEFT", 7, -6)
    r.name = ns.Str(r, NAME)
    r.name:SetPoint("LEFT", r.spec, "RIGHT", 5, 0)
    r.name:SetWidth(ROW_W - 118)
    r.name:SetJustifyH("LEFT")
    r.info = ns.Str(r, INFO)
    r.info:SetPoint("TOPLEFT", r.spec, "BOTTOMLEFT", 0, -3)
    r.info:SetWidth(ROW_W - 92)
    r.info:SetJustifyH("LEFT")
    ns.PaintText(r.info, "text.secondary")
    r.btns = {}
    for i = 1, 3 do
        local b = ns.MakeKitButton(r)
        b:SetSize(24, 22)
        b.role = b:CreateTexture(nil, "OVERLAY")
        b.role:SetSize(14, 14)
        b.role:SetPoint("CENTER", b, "CENTER", 0, 0)
        b:SetPoint("RIGHT", r, "RIGHT", -4 - (i - 1) * 26, 0)
        r.btns[i] = b
    end
    return r
end
local function newWaitRow()
    local r = ns.NewFrame("Frame", nil, child)
    r:SetSize(ROW_W, ROW_H - 2)
    ns.Skin(r, "card")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    r:SetScript("OnLeave", ns.TipHide)
    r.spec = r:CreateTexture(nil, "ARTWORK")
    r.spec:SetSize(18, 18)
    r.spec:SetPoint("TOPLEFT", r, "TOPLEFT", 7, -6)
    r.name = ns.Str(r, NAME)
    r.name:SetPoint("LEFT", r.spec, "RIGHT", 5, 0)
    r.name:SetWidth(110)
    r.name:SetJustifyH("LEFT")
    r.text = ns.Str(r, INFO)
    r.text:SetPoint("TOPLEFT", r.spec, "BOTTOMLEFT", 0, -3)
    r.text:SetWidth(ROW_W - 100)
    r.text:SetJustifyH("LEFT")
    ns.PaintText(r.text, "text.secondary")
    r.drop = ns.MakeKitButton(r)
    r.drop:SetSize(22, 22)
    r.drop:SetText("x")
    r.drop.tip = ns.T("tipWaitDrop")
    r.drop:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.invite = ns.MakeKitButton(r)
    r.invite:SetSize(52, 22)
    r.invite:SetText(ns.T("btnInviteShort"))
    r.invite:SetPoint("RIGHT", r.drop, "LEFT", -3, 0)
    return r
end
local function fillUn(r, m)
    fitRow(r, r.info)
    local p = ns.Session.Player(m.name)
    ns.Icon.Who(r.spec, p.spec, m.class)
    r.name:SetText(m.name)
    local lock = ns.RaidPane.LockText(m.name)
    if lock then ns.Tone(r.name, "text.bad") else ns.ClassText(r.name, m.class) end
    local grp = m.work and ns.T("grpN", m.sub) or (ns.Hex("text.muted") .. ns.T("grpReserve", m.sub) .. "|r")
    local parse = ns.Bober.ParseText(m.name, m.unit)
    r.info:SetText(grp .. "  " .. ns.RaidPane.GsText(m.name) .. (parse and ("  " .. parse) or ""))
    ns.RaidPane.SpecTip(r, m)
    r.tip = ns.Bober.Tip(r.tip, m.name, m.unit)
    if lock then r.tip = ns.Hex("text.bad") .. lock .. "|r\n" .. (r.tip or "") end
    ns.RaidPane.FillSlotButtons(r.btns, m)
end
local function fillWait(r, w)
    fitRow(r, r.text)
    local sp = w.spec and ns.SPEC[w.spec]
    ns.Icon.Spec(r.spec, w.spec)
    r.name:SetText(w.name)
    local lock = ns.RaidPane.LockText(w.name)
    if lock then
        ns.Tone(r.name, "text.bad")
    elseif sp then
        ns.ClassText(r.name, sp.class)
    else
        ns.Tone(r.name, "text.primary")
    end
    local parse = ns.Bober.ParseText(w.name, nil, w.spec)
    r.text:SetText((parse and (parse .. "  ") or "") .. (w.text or ""))
    r.tipTitle = w.name
    r.tip = ns.Bober.Tip((sp and ns.T("specFull_" .. w.spec) or "") .. "\n" .. (w.text or ""), w.name, nil, w.spec)
    if lock then r.tip = ns.Hex("text.bad") .. lock .. "|r\n" .. (r.tip or "") end
    r.invite.tipTitle = ns.T("btnInvite")
    r.invite.tip = w.name
    r.invite.onClick = function() ns.Whisper.Invite(w.name) end
    r.drop.onClick = function() ns.Whisper.Drop(w.name) end
end
local function layout()
    local S = ns.Session
    local un = S.Unassigned()
    local wait = ns.Whisper.Waiting()
    local y = 4
    local step, head = rowH(), headH()
    ns.RaidPane.LockTarget()
    unPool:Reset()
    waitPool:Reset()
    unHead:ClearAllPoints()
    unHead:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
    local work, reserve = S.UnassignedCounts()
    unHead:SetText(ns.T("unTitle") .. "  " .. work
        .. (reserve > 0 and ("  " .. ns.Hex("text.muted") .. ns.T("unReserve", reserve) .. "|r") or ""))
    y = y + head
    for _, m in ipairs(un) do
        local r = unPool:Acquire()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        fillUn(r, m)
        y = y + step
    end
    if #un == 0 then
        emptyFs:ClearAllPoints()
        emptyFs:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
        emptyFs:SetText(ns.T(S.InGroup() and "sideAllPlaced" or "sideNoGroup"))
        emptyFs:Show()
        y = y + ns.Fit(INFO, 20, 4)
    else
        emptyFs:Hide()
    end
    y = y + 10
    if #wait > 0 then
        waitHead:ClearAllPoints()
        waitHead:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
        waitHead:SetText(ns.T("waitTitle") .. "  " .. #wait)
        waitHead:Show()
        y = y + head
        for _, w in ipairs(wait) do
            local r = waitPool:Acquire()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            fillWait(r, w)
            y = y + step
        end
    else
        waitHead:Hide()
    end
    unPool:HideExtras()
    waitPool:HideExtras()
    child:SetHeight(math.max(1, y))
    local maxScroll = math.max(0, y - scroll:GetHeight())
    if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
end
local function paintToggle()
    local dir = ns.Side.Open() and "Prev" or "Next"
    toggle:SetNormalTexture(ARROW:format(dir, "Up"))
    toggle:SetPushedTexture(ARROW:format(dir, "Down"))
    toggle.tipTitle = ns.T(ns.Side.Open() and "tipSideClose" or "tipSideOpen")
end
local function refresh()
    if not built then return end
    paintToggle()
    toggle:ClearAllPoints()
    toggle:SetPoint("CENTER", ns.Side.Open() and side or ns.window:Outer(), "RIGHT", TOGGLE_OUT, 0)
    local open = ns.Side.Open() and side:GetParent():IsVisible()
    local shown = side:GetParent():IsVisible()
    ns.window:ClampRight(open and -(W - 6) or (shown and -(TOGGLE_OUT + 18) or 0))
    if ns.Side.Open() then
        side:Show()
        layout()
    else
        side:Hide()
    end
end
local function build()
    local win = ns.window:Pult():GetParent()
    local outer = ns.window:Outer()
    side = ns.NewFrame("Frame", nil, win)
    side:SetWidth(W)
    side:SetPoint("TOPLEFT", outer, "TOPRIGHT", -6, 0)
    side:SetPoint("BOTTOMLEFT", outer, "BOTTOMRIGHT", -6, 0)
    side:SetFrameLevel(win:GetFrameLevel())
    ns.PaintWindow(side)
    side:EnableMouse(true)
    ns.window:Handle(side)
    local page = ns.Fill(side, "BORDER")
    ns.PaintToken(page, "surface.page")
    page:SetPoint("TOPLEFT", side, "TOPLEFT", EDGE, -EDGE)
    page:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -EDGE, EDGE)
    local panel = ns.MakePanel(side)
    panel:SetPoint("TOPLEFT", side, "TOPLEFT", EDGE, -EDGE)
    panel:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -EDGE, EDGE)
    scroll = ns.NewFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)
    child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(ROW_W + 4, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
        local v = self:GetVerticalScroll() - delta * WHEEL
        if v < 0 then v = 0 end
        if v > maxScroll then v = maxScroll end
        self:SetVerticalScroll(v)
    end)
    unHead = header()
    waitHead = header()
    emptyFs = ns.Str(child, INFO)
    ns.PaintText(emptyFs, "text.secondary")
    unPool = ns.NewPool(newUnRow)
    waitPool = ns.NewPool(newWaitRow)
    toggle = ns.NewFrame("Button", nil, win)
    toggle:SetSize(32, 32)
    toggle:SetFrameLevel(win:GetFrameLevel() + 20)
    toggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    toggle:SetScript("OnEnter", function(self) ns.TipShow(self) end)
    toggle:SetScript("OnLeave", ns.TipHide)
    toggle:SetScript("OnClick", function()
        ns.Sfx.Ui("click")
        ns.Store.DB().sideOpen = not ns.Side.Open()
        ns.Session.Changed()
    end)
    built = true
    refresh()
end
ns.Session.OnChange(refresh)
ns.OnFont(refresh)
ns.Side.Build = build
ns.Side.Refresh = refresh
ns.window:OnBuild(build)
