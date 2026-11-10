local _, ns = ...
local MENU = "HTP_FailWatchReplayView"
local W = 330
local PAD = 10
local TITLE_H = 18
local LABEL_W = 78
local BTN_H = 20
local ROW = 24
local GAP = 4
local CHECK = 20
local SIZE_VALUE_W = 40
local View = {}
ns.ReplayViewMenu = View
local Kit = ns.Kit
local max = math.max
local ceil = math.ceil
local m = { W = W, label = LABEL_W, btn = BTN_H, row = ROW, check = CHECK, title = TITLE_H }
local function Metrics()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true), Kit.FontScale("GameFontNormalSmall", true))
    local pt = max(Kit.FontSize("GameFontHighlightSmall", true), Kit.FontSize("GameFontNormalSmall", true))
    m.W = ceil(W * k)
    m.label = ceil(LABEL_W * k)
    m.btn = max(BTN_H, ceil(pt * 1.15) + 6)
    m.row = m.btn + (ROW - BTN_H)
    m.check = max(CHECK, m.btn)
    m.title = max(TITLE_H, ceil(Kit.FontSize("GameFontNormalSmall", true) * 1.15) + 4)
end
local st = { rows = {}, rects = {}, items = {}, hasWorld = false, hasThrone = false }
local function Opts(prefix, tipPrefix, keys)
    local out = {}
    for i = 1, #keys do
        out[i] = { key = keys[i], label = ns.T(prefix .. keys[i]), tip = ns.T(tipPrefix .. keys[i]) }
    end
    return out
end
local function Rect(name, x, y, w, h)
    st.rects[#st.rects + 1] = { name = name, x = x, y = y, w = w, h = h }
end
local function PlaceRow(row, y)
    local menu = st.menu
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", menu, "TOPLEFT", PAD, -(y + m.btn / 2))
    row.label:SetWidth(m.label)
    local world = row.key == "world"
    local r0 = #st.rects + 1
    Rect(row.key .. ".label", PAD, y, m.label, m.btn)
    local n = #row.btns
    local x0 = PAD + m.label + GAP
    local w = (m.W - x0 - PAD - GAP * (n - 1)) / n
    for i = 1, n do
        local b = row.btns[i]
        local x = x0 + (i - 1) * (w + GAP)
        b:SetWidth(w)
        b:SetHeight(m.btn)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -y)
        Rect(row.key .. "." .. b.key, x, y, w, m.btn)
    end
    if world then
        for i = r0, #st.rects do st.rects[i].world = true end
    end
end
local function Place()
    local menu = st.menu
    if not menu then return end
    Metrics()
    menu:SetWidth(m.W)
    st.rects = {}
    st.title:ClearAllPoints()
    st.title:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -PAD)
    local y = PAD + m.title
    local tail = false
    for i = 1, #st.items do
        local it = st.items[i]
        if it.kind == "row" then
            if (it.row.key ~= "world" or st.hasWorld) and (it.row.key ~= "throne" or st.hasThrone) then
                PlaceRow(it.row, y)
                y = y + m.row
            end
        elseif it.kind == "slider" then
            local obj = it.obj
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -y)
            obj:SetWidth(m.W - PAD * 2)
            obj:SetHeight(m.btn)
            obj:SetLabelWidth(LABEL_W)
            Rect(it.name, PAD, y, m.W - PAD * 2, m.btn)
            y = y + m.row
        else
            if not tail then
                y = y + GAP
                tail = true
            end
            local obj = it.obj
            if it.kind == "wide" then y = y + GAP end
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -y)
            if it.kind == "wide" then
                obj:SetWidth(m.W - PAD * 2)
                obj:SetHeight(m.btn)
                Rect(it.name, PAD, y, m.W - PAD * 2, m.btn)
                y = y + m.row
            else
                obj:SetWidth(m.check)
                obj:SetHeight(m.check)
                Rect(it.name, PAD, y, m.W - PAD * 2, m.check)
                y = y + m.row
            end
        end
    end
    st.h = y + PAD - GAP
    st.hNow = st.h
    menu:SetHeight(st.h)
end
local function Mark(row, cur)
    for i = 1, #row.btns do row.btns[i]:SetActive(row.btns[i].key == cur) end
end
local function RoomRow(room)
    local row = st.rows.room
    local Geo = ns.ReplayGeo
    local has, missing = Geo.Has(room), Geo.Missing(room)
    local vol, flat = row.btns[1], row.btns[2]
    if not has and not missing then
        row.label:Hide()
        vol:Hide()
        flat:Hide()
        return
    end
    row.label:Show()
    vol:Show()
    flat:Show()
    if has then
        vol:Enable()
        vol.tip = ns.T("iso.tip.geo.vol")
        Mark(row, Geo.on and "vol" or "flat")
    else
        vol:Disable()
        vol.tip = ns.RoomPacks.Hint(room)
        Mark(row, "flat")
    end
end
local function WorldRow()
    local Realm = ns.ReplayRealmView
    local iso = ns.ReplayIso
    local has = Realm ~= nil and iso ~= nil and Realm.Has(iso.Scene())
    local row = st.rows.world
    if has then row.label:Show() else row.label:Hide() end
    for i = 1, #row.btns do
        if has then row.btns[i]:Show() else row.btns[i]:Hide() end
    end
    if has then Mark(row, Realm.Mode()) end
    if st.hasWorld ~= has then
        st.hasWorld = has
        Place()
    end
end
local function ThroneRow()
    local mode, has = ns.ReplayLive.ThroneMode()
    has = has and ns.ReplayGeo.on
    local row = st.rows.throne
    if has then row.label:Show() else row.label:Hide() end
    for i = 1, #row.btns do
        if has then row.btns[i]:Show() else row.btns[i]:Hide() end
    end
    if has then Mark(row, mode) end
    if st.hasThrone ~= has then
        st.hasThrone = has
        Place()
    end
end
function View.Refresh()
    local api = st.api
    if not (api and st.menu) then return end
    Mark(st.rows.figs, ns.ReplayFigs.Kind())
    RoomRow(api.Room())
    ThroneRow()
    Mark(st.rows.cam, ns.ReplayIsoCam.Preset())
    Mark(st.rows.arrows, ns.ReplayArrowsView.Mode())
    WorldRow()
    st.heal:SetChecked(api.Heal())
    st.follow:SetChecked(ns.ReplayFollow.On())
    Mark(st.rows.casts, ns.ReplayUnitsView.CastsAll() and "all" or "focus")
    st.size:SetValue((ns.ReplayUnitsView.Size()))
end
local function Pick(key, opt)
    local api = st.api
    if key == "figs" then
        ns.ReplayFigs.SetKind(opt.key)
    elseif key == "room" then
        if ns.ReplayGeo.Has(api.Room()) then api.SetGeo(opt.key == "vol") end
    elseif key == "cam" then
        ns.ReplayIsoCam.SetPreset(opt.key)
    elseif key == "arrows" then
        ns.ReplayArrowsView.SetMode(opt.key)
    elseif key == "world" then
        ns.ReplayRealmView.SetMode(opt.key)
    elseif key == "throne" then
        ns.ReplayIso.SetThrone(opt.key)
    elseif key == "casts" then
        ns.ReplayUnitsView.SetCastsAll(opt.key == "all")
    end
    View.Refresh()
end
local function Row(menu, key, caption, opts)
    local label = Kit.Str(menu, "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")
    label:SetText(ns.T(caption))
    Kit.Text(label, "text.secondary")
    local row = { key = key, label = label, btns = {} }
    for i = 1, #opts do
        local opt = opts[i]
        local b = Kit.Button(menu)
        Kit.ExactSize(b)
        Kit.Bind(b.text, "GameFontNormalSmall")
        b.text:SetText(opt.label)
        b.tip = opt.tip
        b.key = opt.key
        b.onClick = function() Pick(key, opt) end
        row.btns[i] = b
    end
    st.rows[key] = row
    st.items[#st.items + 1] = { kind = "row", row = row }
end
local WIDE = { ["iso.threat"] = "threat", ["iso.tour"] = "tour", ["iso.camdefault"] = "camdefault" }
local function Wide(menu, key, fn)
    local b = Kit.Button(menu)
    Kit.ExactSize(b)
    Kit.Bind(b.text, "GameFontNormalSmall")
    b.text:SetText(ns.T(key))
    b.tip = ns.T(key .. ".tip")
    b.onClick = function()
        menu:Hide()
        fn()
    end
    st.items[#st.items + 1] = { kind = "wide", obj = b, name = WIDE[key] or key }
    return b
end
local function Check(menu, key, fn)
    local c = Kit.Check(menu)
    Kit.Bind(c.label, "GameFontNormalSmall")
    c.label:SetText(ns.T(key))
    c.tip = ns.T(key .. ".tip")
    c.tipTitle = false
    c.onToggle = fn
    st.items[#st.items + 1] = { kind = "check", obj = c, name = key }
    return c
end
local function SizeSlider(menu)
    local _, lo, hi, step = ns.ReplayUnitsView.Size()
    local s = Kit.Slider(menu, { min = lo, max = hi, step = step, fmt = "%d%%", labelW = LABEL_W, valueW = SIZE_VALUE_W })
    s.label:SetText(ns.T("iso.labels"))
    Kit.Text(s.label, "text.secondary")
    s.tip = ns.T("iso.labels.tip")
    s.onChange = function(v) ns.ReplayUnitsView.SetSize(v) end
    st.items[#st.items + 1] = { kind = "slider", obj = s, name = "labels" }
    return s
end
function View.Build(ui, run, api)
    st.api = api
    st.rects, st.items, st.hasWorld, st.hasThrone = {}, {}, false, false
    local menu = CreateFrame("Frame", MENU, ui.frame)
    menu:SetWidth(W)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu:SetPoint("TOPRIGHT", ui.view, "TOPRIGHT", -ns.ReplayIsoBuild.NAV_W, -GAP)
    st.view = ui.view
    Kit.Skin(menu, "list")
    local title = Kit.Str(menu, "GameFontNormalSmall")
    title:SetText(ns.T("iso.view"))
    Kit.Text(title, "text.title")
    st.title = title
    st.menu = menu
    Row(menu, "figs", "iso.view.figs", Opts("iso.figs.", "iso.tip.figs.", { "chip", "disc", "vol" }))
    Row(menu, "room", "iso.view.room", Opts("iso.geo.", "iso.tip.geo.", { "vol", "flat" }))
    Row(menu, "throne", "iso.view.throne", Opts("iso.throne.", "iso.tip.throne.", { "pic", "faces" }))
    Row(menu, "cam", "iso.view.cam", Opts("iso.cam.", "iso.tip.cam.", ns.ReplayIsoCam.PRESET_KEYS))
    Row(menu, "arrows", "iso.view.arrows", Opts("iso.arrows.", "iso.tip.arrows.", { "all", "focus", "off" }))
    Row(menu, "casts", "iso.view.casts", Opts("iso.casts.", "iso.tip.casts.", { "all", "focus" }))
    st.size = SizeSlider(menu)
    Row(menu, "world", "iso.view.world", Opts("iso.world.", "iso.tip.world.", { "mine", "both", "phys", "twi" }))
    st.heal = Check(menu, "iso.focusheal", function(on) api.SetHeal(on) end)
    st.follow = Check(menu, "iso.follow", function(on) ns.ReplayFollow.SetOn(on) end)
    st.camdef = Wide(menu, "iso.camdefault", function() ns.ReplayIsoCam.DefaultView() end)
    if ns.ThreatView then st.threat = Wide(menu, "iso.threat", ns.ReplayFollow.Threat) end
    st.tour = Wide(menu, "iso.tour", ns.ReplayTour.Start)
    Place()
    menu:Hide()
    if type(UIMenus) == "table" then tinsert(UIMenus, MENU) end
    ui.viewMenu = menu
    ui.gearBtn.onClick = View.Toggle
    ns.ReplayFigs.onChange = View.Refresh
    if ns.ReplayRealmView then ns.ReplayRealmView.onChange = View.Refresh end
end
Kit.OnFont(Place)
function View.Toggle()
    local menu = st.menu
    if not menu then return end
    if menu:IsShown() then
        menu:Hide()
        return
    end
    View.Refresh()
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", st.view, "TOPRIGHT", -ns.ReplayIsoBuild.NAV_W, -GAP)
    menu:Show()
    ns.ReplayTour.Note("menu")
end
function View.Hide()
    if st.menu then st.menu:Hide() end
end
function View.Probe()
    return { rects = st.rects, w = m.W, h = st.hNow or st.h or 0, rows = st.rows, heal = st.heal,
             follow = st.follow, size = st.size, threat = st.threat, tour = st.tour, raid = st.raid, camdef = st.camdef,
             menu = st.menu }
end
