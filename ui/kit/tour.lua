local _, ns = ...
local Kit = ns.Kit
local max = math.max
local min = math.min
local sin = math.sin
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local pi = math.pi
local format = string.format
local W = 340
local PAD = 10
local GAP = 8
local ROWS = 24
local COL_GAP = 14
local ICON = 16
local ICON_GAP = 6
local ROW_GAP = 4
local BTN_W = 90
local BTN_H = 20
local EDGE = 2
local RING_OUT = 4
local RING_IN = -3
local MARGIN = 8
local LIFT = 8
local DIM_A = 0.55
local CARD_A = 0.94
local PULSE_HZ = 1.5
local RING_LOW = 0.35
local HOLD = 0.9
local RETARGET = 0.5
local DIRTY = 3
local MOVE = 0.5
local Tour = {}
Kit.Tour = Tour
local st = { steps = {}, index = 1, running = false, lit = {}, phase = 0, dirty = 0, retarget = 0, w = W }
local over
local card
local ring
local dim
local bands = {}
local title, counter, body, ok
local skip, back, nextBtn
local rows = {}
local function TextH(fs, fallback)
    local h = fs:GetStringHeight()
    if not h or h < 1 then return fallback end
    return ceil(h)
end
local function Clamp(v, lo, hi)
    if hi < lo then return lo end
    return max(lo, min(hi, v))
end
local function Level(f)
    return f and f.GetFrameLevel and f:GetFrameLevel() or 0
end
local function Btn(key, fn)
    local b = Kit.Button(card)
    b:SetWidth(BTN_W)
    b:SetHeight(BTN_H)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b:SetText(ns.T(key))
    b.onClick = fn
    return b
end
local function NewRow()
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:Hide()
    local text = Kit.Str(card, "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    Kit.Text(text, "text.primary")
    text:Hide()
    return { icon = icon, text = text }
end
local function BuildRing()
    ring = CreateFrame("Frame", nil, over)
    local spec = {
        { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
    }
    for i = 1, #spec do
        local s = spec[i]
        local e = ring:CreateTexture(nil, "OVERLAY")
        e:SetPoint(s[1], ring, s[1], 0, 0)
        e:SetPoint(s[2], ring, s[2], 0, 0)
        if s[3] then e:SetHeight(EDGE) else e:SetWidth(EDGE) end
        Kit.Paint(e, "sem.pick")
    end
    ring:Hide()
end
local function BuildCard()
    card = CreateFrame("Frame", nil, over)
    card:EnableMouse(true)
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(card)
    Kit.Paint(bg, "surface.shade", CARD_A)
    local line = card:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
    line:SetHeight(EDGE)
    Kit.Paint(line, "sem.pick")
    title = Kit.Str(card, "GameFontNormal")
    title:SetJustifyH("LEFT")
    Kit.Text(title, "text.title")
    counter = Kit.Str(card, "GameFontNormalSmall")
    counter:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -PAD)
    Kit.Text(counter, "text.secondary")
    ok = Kit.Str(card, "GameFontNormalSmall")
    ok:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -PAD)
    ok:SetText(ns.T("tour.ok"))
    Kit.Text(ok, "text.good")
    ok:Hide()
    body = Kit.Str(card, "GameFontHighlight")
    body:SetJustifyH("LEFT")
    Kit.Text(body, "text.primary")
    for i = 1, ROWS do rows[i] = NewRow() end
    skip = Btn("tour.skip", function() Tour.Close("skip") end)
    skip:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", PAD, PAD)
    nextBtn = Btn("tour.next", function() Tour.Next() end)
    nextBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -PAD, PAD)
    back = Btn("tour.back", function() Tour.Back() end)
    back:SetPoint("RIGHT", nextBtn, "LEFT", -GAP, 0)
end
local function Build()
    over = CreateFrame("Frame", nil, UIParent)
    dim = over:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(over)
    Kit.Paint(dim, "surface.shade", DIM_A)
    for i = 1, 4 do
        local t = over:CreateTexture(nil, "BACKGROUND")
        Kit.Paint(t, "surface.shade", DIM_A)
        t:Hide()
        bands[i] = t
    end
    BuildRing()
    BuildCard()
    over:SetScript("OnHide", function() Tour.Close("hide") end)
    over:SetScript("OnSizeChanged", function() Tour.Layout() end)
    over:SetScript("OnMouseWheel", function() end)
    over:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", function(_, elapsed) Tour.Tick(elapsed) end))
    over:Hide()
end
local function Seat(host, o)
    over:SetParent(host)
    over:ClearAllPoints()
    over:SetAllPoints(host)
    local strata = o.strata or (host.GetFrameStrata and host:GetFrameStrata()) or "HIGH"
    local lv = min(120, max(Level(host), Level(o.above)) + LIFT)
    local list = { { over, 0 }, { ring, 1 }, { card, 3 }, { skip, 4 }, { back, 4 }, { nextBtn, 4 } }
    for i = 1, #list do
        local f = list[i][1]
        f:SetFrameStrata(strata)
        f:SetFrameLevel(lv + list[i][2])
    end
    over:EnableMouse(o.dim and true or false)
    over:EnableMouseWheel(o.dim and true or false)
end
function Tour.Targets(step)
    local found = {}
    local got = step.target and step.target()
    if type(got) ~= "table" then return found end
    if got.GetObjectType or got.IsShown then got = { got } end
    for i = 1, #got do
        local f = got[i]
        if f and f:IsVisible() then found[#found + 1] = f end
    end
    return found
end
local function PlaceRows(list, y, inner, k, cols)
    local size = ceil(ICON * k)
    local n = min(#list, ROWS)
    if n > 0 then y = y + GAP end
    cols = max(1, min(cols, n))
    local per = ceil(n / cols)
    local colW = (inner - (cols - 1) * COL_GAP) / cols
    local top, low = y, y
    for i = 1, ROWS do
        local r, row = rows[i], i <= n and list[i] or nil
        if row then
            local col = floor((i - 1) / per)
            if (i - 1) % per == 0 then y = top end
            local x0 = PAD + col * (colW + COL_GAP)
            local x = x0
            if row.icon then
                r.icon:SetTexture(row.icon)
                r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                if row.tint then
                    Kit.Tint(r.icon, row.tint)
                else
                    Kit.Hue(r.icon, "")
                    r.icon:SetVertexColor(1, 1, 1, 1)
                end
                r.icon:SetWidth(size)
                r.icon:SetHeight(size)
                r.icon:ClearAllPoints()
                r.icon:SetPoint("TOPLEFT", card, "TOPLEFT", x0, -y)
                r.icon:Show()
                x = x0 + size + ICON_GAP
            else
                r.icon:Hide()
            end
            r.text:ClearAllPoints()
            r.text:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y - 1)
            r.text:SetWidth(colW - (x - x0))
            r.text:SetText(row.text)
            r.text:Show()
            y = y + max(size, TextH(r.text, 12) + 2) + ROW_GAP
            if y > low then low = y end
        else
            r.icon:Hide()
            r.text:Hide()
        end
    end
    return low
end
function Tour.Render()
    if not st.running then return end
    local n = #st.steps
    st.index = Clamp(st.index, 1, n)
    local step = st.steps[st.index]
    Tour.Leave(step)
    if step.action and st.shown ~= step then step.action() end
    st.shown = step
    st.doneT, st.retarget = nil, 0
    local o = st.opts
    local k = max(1, Kit.FontScale("GameFontHighlight", true), Kit.FontScale("GameFontNormalSmall", true))
    st.w = ceil((step.width or o.width or W) * k)
    local room = (over:GetWidth() or 0) - MARGIN * 2
    if room > W and st.w > room then st.w = floor(room) end
    local inner = st.w - PAD * 2
    card:SetWidth(st.w)
    counter:SetText(n > 1 and format("%d / %d", st.index, n) or "")
    counter:Show()
    ok:Hide()
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
    title:SetWidth(inner - ceil(50 * k))
    title:SetText(step.title or o.title or "")
    local y = PAD + TextH(title, 14) + GAP / 2
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    body:SetWidth(inner)
    body:SetText(step.text or "")
    y = y + TextH(body, 14)
    y = PlaceRows(step.rows or {}, y, inner, k, step.cols or 1)
    local bh = max(BTN_H, ceil(Kit.FontSize("GameFontNormalSmall", true) * 1.15) + 6)
    local bw = ceil(BTN_W * k)
    for _, b in ipairs({ skip, back, nextBtn }) do
        b:SetWidth(bw)
        b:SetHeight(bh)
    end
    local last = st.index >= n
    nextBtn:SetText(ns.T(last and "tour.done" or "tour.next"))
    if st.index > 1 and o.back ~= false then back:Show() else back:Hide() end
    if last and n > 1 then skip:Hide() else skip:Show() end
    card:SetHeight(y + GAP + bh + PAD)
    st.lit = Tour.Targets(step)
    st.dirty = DIRTY
    Tour.Layout()
end
function Tour.Leave(step)
    local shown = st.shown
    if not shown or shown == step then return end
    st.shown = nil
    if shown.leave then shown.leave() end
end
function Tour.Bounds(frames, pad)
    local ox, oy = over:GetLeft(), over:GetTop()
    if not ox or not oy then return nil end
    local own = over:GetEffectiveScale() or 1
    local l, t, r, b
    for i = 1, #frames do
        local f = frames[i]
        local fl, ft, fr, fb = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom()
        if fl and ft and fr and fb then
            local holder = f.GetEffectiveScale and f or f:GetParent()
            local q = (holder and holder.GetEffectiveScale and holder:GetEffectiveScale() or own) / own
            l, r = min(l or fl * q, fl * q), max(r or fr * q, fr * q)
            t, b = max(t or ft * q, ft * q), min(b or fb * q, fb * q)
        end
    end
    if not l then return nil end
    return l - ox - pad, oy - t - pad, r - ox + pad, oy - b + pad
end
local function Band(tx, x, y, w, h)
    tx:ClearAllPoints()
    tx:SetPoint("TOPLEFT", over, "TOPLEFT", x, -y)
    tx:SetWidth(max(w, 0.01))
    tx:SetHeight(max(h, 0.01))
    tx:Show()
end
local function PlaceCard(l, t, r, b, ow, oh)
    local w, h = st.w, card:GetHeight() or 160
    local x = Clamp((l + r) / 2 - w / 2, MARGIN, ow - w - MARGIN)
    local y
    if (t + b) / 2 < oh / 2 then
        y = b + GAP
        if y + h > oh - MARGIN then y = t - GAP - h end
    else
        y = t - GAP - h
        if y < MARGIN then y = b + GAP end
    end
    card:SetPoint("TOPLEFT", over, "TOPLEFT", x, -Clamp(y, MARGIN, oh - h - MARGIN))
end
function Tour.Layout()
    if not st.running or not over then return end
    local o = st.opts
    local ow, oh = over:GetWidth() or 0, over:GetHeight() or 0
    local step = st.steps[st.index]
    local pad = step and step.inset and RING_IN or RING_OUT
    local l, t, r, b
    if #st.lit > 0 and ow > 0 and oh > 0 then l, t, r, b = Tour.Bounds(st.lit, pad) end
    st.pad, st.box = pad, l and { l, t, r, b } or nil
    card:ClearAllPoints()
    if o.place then o.place(card) end
    if not l then
        for i = 1, 4 do bands[i]:Hide() end
        ring:Hide()
        if o.dim then dim:Show() else dim:Hide() end
        if not o.place then card:SetPoint("CENTER", over, "CENTER", 0, 0) end
        return
    end
    l, r = Clamp(l, 0, ow), Clamp(r, 0, ow)
    t, b = Clamp(t, 0, oh), Clamp(b, 0, oh)
    dim:Hide()
    if o.dim then
        Band(bands[1], 0, 0, ow, t)
        Band(bands[2], 0, b, ow, oh - b)
        Band(bands[3], 0, t, l, b - t)
        Band(bands[4], r, t, ow - r, b - t)
    else
        for i = 1, 4 do bands[i]:Hide() end
    end
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", over, "TOPLEFT", l, -t)
    ring:SetPoint("BOTTOMRIGHT", over, "TOPLEFT", r, -b)
    ring:Show()
    if not o.place then PlaceCard(l, t, r, b, ow, oh) end
end
local function Follow()
    if #st.lit == 0 then return end
    local l, t, r, b = Tour.Bounds(st.lit, st.pad or RING_OUT)
    local box = st.box
    if not l or not box then
        if (l ~= nil) ~= (box ~= nil) then Tour.Layout() end
        return
    end
    if abs(l - box[1]) > MOVE or abs(t - box[2]) > MOVE or abs(r - box[3]) > MOVE or abs(b - box[4]) > MOVE then
        Tour.Layout()
    end
end
function Tour.Tick(elapsed)
    if not st.running then return end
    local dt = max(0, elapsed or 0)
    st.phase = (st.phase + dt * PULSE_HZ) % 1
    ring:SetAlpha(RING_LOW + (1 - RING_LOW) * abs(sin(st.phase * pi)))
    if st.doneT then
        st.doneT = st.doneT + dt
        if st.doneT >= HOLD then Tour.Next() else Follow() end
        return
    end
    st.retarget = st.retarget + dt
    if st.retarget >= RETARGET then
        st.retarget = 0
        local f = st.lit[1]
        if not (f and f:IsVisible()) then
            st.lit = Tour.Targets(st.steps[st.index])
            st.dirty = DIRTY
        end
    end
    if st.dirty > 0 then
        st.dirty = st.dirty - 1
        Tour.Layout()
    else
        Follow()
    end
end
function Tour.Start(host, steps, o)
    if not host or #steps == 0 then return false end
    if st.running then Tour.Close("hide") end
    if not over then Build() end
    Seat(host, o)
    st.steps, st.index, st.opts, st.running, st.shown = steps, 1, o, true, nil
    over:Show()
    Tour.Render()
    return true
end
function Tour.Active(id)
    return st.running and (id == nil or (st.opts and st.opts.id == id)) or false
end
function Tour.Next()
    if not st.running then return end
    if st.index >= #st.steps then
        Tour.Close("done")
        return
    end
    st.index = st.index + 1
    Tour.Render()
end
function Tour.Back()
    if not st.running or st.index <= 1 then return end
    st.index = st.index - 1
    Tour.Render()
end
function Tour.Done()
    if not st.running or st.doneT then return end
    st.doneT = 0
    counter:Hide()
    ok:Show()
end
function Tour.Close(how)
    if not st.running then return end
    st.running = false
    st.lit, st.doneT = {}, nil
    Tour.Leave(nil)
    if over and over:IsShown() then over:Hide() end
    local o = st.opts
    st.opts = nil
    if o and o.onFinish then o.onFinish(how, st.index) end
end
Kit.OnFont(function()
    if st.running then Tour.Render() end
end)
function Tour.Probe()
    local step = st.running and st.steps[st.index] or nil
    return { running = st.running, id = st.opts and st.opts.id, index = st.index, n = #st.steps, step = step,
             key = step and step.key, lit = st.lit, target = st.lit[1], done = st.doneT ~= nil, over = over,
             card = card, ring = ring, bands = bands, rows = rows, skip = skip, back = back, next = nextBtn,
             title = title, body = body, w = st.w }
end
