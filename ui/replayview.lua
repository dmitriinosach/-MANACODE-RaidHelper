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
local View = {}
ns.ReplayViewMenu = View
local Kit = ns.Kit
local st = { rows = {}, rects = {}, moves = {}, worldRects = {} }
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
    local shift = has and 0 or ROW
    for i = 1, #st.moves do
        local m = st.moves[i]
        m.obj:ClearAllPoints()
        m.obj:SetPoint("TOPLEFT", st.menu, "TOPLEFT", PAD, -(m.y - shift))
        st.rects[m.ri].y = m.y - shift
    end
    for i = #st.rects, 1, -1 do
        if st.rects[i].world then tremove(st.rects, i) end
    end
    if has then
        for i = 1, #st.worldRects do st.rects[#st.rects + 1] = st.worldRects[i] end
    end
    st.hNow = st.h - shift
    st.menu:SetHeight(st.hNow)
end
function View.Refresh()
    local api = st.api
    if not (api and st.menu) then return end
    Mark(st.rows.figs, ns.ReplayFigs.Kind())
    Mark(st.rows.players, api.Models())
    Mark(st.rows.enemies, ns.ReplayModels.Mode())
    RoomRow(api.Room())
    WorldRow()
    st.heal:SetChecked(api.Heal())
    st.follow:SetChecked(ns.ReplayFollow.On())
    if st.sound then st.sound:SetChecked(ns.ReplayBarsView.Sound()) end
end
local function Pick(key, opt)
    local api = st.api
    if key == "figs" then
        ns.ReplayFigs.SetKind(opt.key)
    elseif key == "players" then
        api.SetModels(opt.key)
    elseif key == "enemies" then
        ns.ReplayModels.SetMode(opt.key)
    elseif key == "room" then
        if ns.ReplayGeo.Has(api.Room()) then api.SetGeo(opt.key == "vol") end
    elseif key == "world" then
        ns.ReplayRealmView.SetMode(opt.key)
    end
    View.Refresh()
end
local function Row(menu, key, caption, opts, y)
    local label = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", menu, "TOPLEFT", PAD, -(y + BTN_H / 2))
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")
    label:SetText(ns.T(caption))
    Kit.Text(label, "text.secondary")
    Rect(key .. ".label", PAD, y, LABEL_W, BTN_H)
    local row = { key = key, label = label, btns = {} }
    local x0 = PAD + LABEL_W + GAP
    local w = (W - x0 - PAD - GAP * (#opts - 1)) / #opts
    for i = 1, #opts do
        local opt = opts[i]
        local b = Kit.Button(menu)
        local x = x0 + (i - 1) * (w + GAP)
        b:SetWidth(w)
        b:SetHeight(BTN_H)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -y)
        b.text:SetText(opt.label)
        b.tip = opt.tip
        b.key = opt.key
        b.onClick = function() Pick(key, opt) end
        row.btns[i] = b
        Rect(key .. "." .. opt.key, x, y, w, BTN_H)
    end
    st.rows[key] = row
end
local function Wide(menu, key, y, fn)
    local b = Kit.Button(menu)
    b:SetWidth(W - PAD * 2)
    b:SetHeight(BTN_H)
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -y)
    b.text:SetText(ns.T(key))
    b.tip = ns.T(key .. ".tip")
    b.onClick = function()
        menu:Hide()
        fn()
    end
    Rect(key == "iso.threat" and "threat" or "tour", PAD, y, W - PAD * 2, BTN_H)
    return b
end
local function Check(menu, key, y, fn)
    local c = Kit.Check(menu)
    c:SetWidth(CHECK)
    c:SetHeight(CHECK)
    c:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -y)
    c.label:SetText(ns.T(key))
    c.tip = ns.T(key .. ".tip")
    c.tipTitle = false
    c.onToggle = fn
    Rect(key, PAD, y, W - PAD * 2, CHECK)
    return c
end
function View.Build(ui, run, api)
    st.api = api
    st.rects = {}
    local menu = CreateFrame("Frame", MENU, ui.frame)
    menu:SetWidth(W)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu:SetPoint("BOTTOMRIGHT", ui.gearBtn, "TOPRIGHT", 0, GAP)
    Kit.Skin(menu, "list")
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -PAD)
    title:SetText(ns.T("iso.view"))
    Kit.Text(title, "text.title")
    local y = PAD + TITLE_H
    Row(menu, "figs", "iso.view.figs", Opts("iso.figs.", "iso.tip.figs.", { "chip", "disc", "vol" }), y)
    y = y + ROW
    Row(menu, "players", "iso.view.players", Opts("iso.fig.", "iso.tip.fig.", { "none", "picked", "all" }), y)
    y = y + ROW
    Row(menu, "enemies", "iso.view.enemies", Opts("iso.m3d.", "iso.tip.m3d.", { "off", "boss", "all" }), y)
    y = y + ROW
    Row(menu, "room", "iso.view.room", Opts("iso.geo.", "iso.tip.geo.", { "vol", "flat" }), y)
    y = y + ROW
    local r0 = #st.rects
    Row(menu, "world", "iso.view.world", Opts("iso.world.", "iso.tip.world.", { "mine", "both", "phys", "twi" }), y)
    st.worldRects, st.moves = {}, {}
    for i = #st.rects, r0 + 1, -1 do
        st.rects[i].world = true
        tinsert(st.worldRects, 1, st.rects[i])
        st.rects[i] = nil
    end
    local function Move(obj, at)
        st.moves[#st.moves + 1] = { obj = obj, y = at, ri = #st.rects }
        return obj
    end
    y = y + ROW + GAP
    st.heal = Move(Check(menu, "iso.focusheal", y, function(on) api.SetHeal(on) end), y)
    y = y + ROW
    st.follow = Move(Check(menu, "iso.follow", y, function(on) ns.ReplayFollow.SetOn(on) end), y)
    y = y + ROW
    if ns.ReplayBarsView then
        st.sound = Move(Check(menu, "iso.barsound", y, function(on) ns.ReplayBarsView.SetSound(on) end), y)
        y = y + ROW
    end
    if ns.ThreatView then
        st.threat = Move(Wide(menu, "iso.threat", y + GAP, ns.ReplayFollow.Threat), y + GAP)
        y = y + GAP + ROW
    end
    st.tour = Move(Wide(menu, "iso.tour", y + GAP, ns.ReplayTour.Start), y + GAP)
    y = y + GAP + ROW
    st.h = y + PAD - GAP
    menu:SetHeight(st.h)
    menu:Hide()
    if type(UIMenus) == "table" then tinsert(UIMenus, MENU) end
    st.menu = menu
    ui.viewMenu = menu
    ui.gearBtn.onClick = View.Toggle
    ns.ReplayFigs.onChange = View.Refresh
    if ns.ReplayRealmView then ns.ReplayRealmView.onChange = View.Refresh end
    st.hNow = st.h
end
function View.Toggle()
    local menu = st.menu
    if not menu then return end
    if menu:IsShown() then
        menu:Hide()
        return
    end
    View.Refresh()
    menu:Show()
    ns.ReplayTour.Note("menu")
end
function View.Hide()
    if st.menu then st.menu:Hide() end
end
function View.Probe()
    return { rects = st.rects, w = W, h = st.hNow or st.h or 0, rows = st.rows, heal = st.heal,
             follow = st.follow, sound = st.sound, threat = st.threat, tour = st.tour, menu = st.menu }
end
