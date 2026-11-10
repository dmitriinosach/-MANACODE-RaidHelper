local ADDON, ns = ...
local Kit = ns.Kit
local KT = Kit.Tour
local News = ns.News
local ID = "news"
local ID_ISO = "news.iso"
local W = 420
local HEAD_W = 760
local HEAD_COLS = 2
local format = string.format
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local View = {}
ns.NewsView = View
local function Shown(list)
    local out = {}
    for _, f in pairs(list or {}) do
        if type(f) == "table" and f.IsVisible and f:IsVisible() then out[#out + 1] = f end
    end
    return out
end
local SPOTS = {
    ["set.notify"] = { page = "settings", cat = "notify", sec = "notify" },
    ["set.show"] = { page = "settings", cat = "parse", sec = "show" },
    ["shell.theme"] = { find = function()
        local p = ns.Shell and ns.Shell.Probe()
        return p and p.theme
    end },
    ["sum.chat"] = { here = true, find = function()
        return ns.Badges and ns.Badges.ChatShown and ns.Badges.ChatShown()
    end },
    ["gp.ep"] = { page = "gp", can = function() return ns.FaultsPage ~= nil and ns.FaultsPage.TabButton ~= nil end,
                  find = function() return ns.FaultsPage.TabButton("ep") end },
    ["iso.snd"] = { find = function()
        local F = ns.ReplayFeed
        local head = F and F.Ready and F.Ready() and F.Stats().head
        return head and { head.snd, head.sndList }
    end },
    ["iso.casts"] = { can = function() return ns.ReplayViewMenu ~= nil and ns.ReplayViewMenu.Probe().menu ~= nil end,
                      open = function()
                          local V = ns.ReplayViewMenu
                          if not V.Probe().menu:IsShown() then V.Toggle() end
                      end,
                      close = function() ns.ReplayViewMenu.Hide() end,
                      find = function()
                          local row = ns.ReplayViewMenu.Probe().rows.casts
                          if not row then return nil end
                          local list = { row.label }
                          for i = 1, #row.btns do list[#list + 1] = row.btns[i] end
                          return list
                      end },
    ["iso.raid"] = { find = function()
        local V = ns.ReplayRaidView
        local p = V and V.Probe and V.Probe()
        if not p then return nil end
        for _, f in ipairs({ p.open, p.win, p.panel }) do
            if f and f:IsShown() then return f end
        end
        return nil
    end },
    ["iso.mode"] = { find = function()
        local V = ns.ReplayModeView
        local p = V and V.Probe and V.Probe()
        if not p then return nil end
        local list = Shown(p.btns)
        if #list == 0 then list = Shown({ p.one }) end
        return list
    end },
}
View.SPOTS = SPOTS
local function Section(cat, key)
    local S = ns.Settings
    if not S then return nil end
    local list = S.Sections(cat)
    for i = 1, #list do
        if list[i].key == key then return list[i].frame or list[i].body end
    end
    return nil
end
function View.Find(spot)
    if spot.cat then return Shown({ Section(spot.cat, spot.sec) }) end
    local got = spot.find and spot.find()
    if type(got) == "table" and not got.IsVisible then return Shown(got) end
    return Shown({ got })
end
local function Prepare(spot, page)
    if page and ns.Shell and ns.Shell.Current() ~= page then ns.Shell.Open(page) end
    if spot.cat and ns.Settings then ns.Settings.Select(spot.cat) end
    if spot.open then spot.open() end
end
local function Ready(spot)
    if spot.can and not spot.can() then return false end
    if spot.cat then return ns.Settings ~= nil end
    if spot.page or spot.open then return true end
    return #View.Find(spot) > 0
end
local function Row(row)
    local icon = row.tex
    if row.spell then
        local _, _, tex = GetSpellInfo(row.spell)
        icon = tex
    elseif row.art then
        icon = ART .. row.art
    end
    return { icon = icon, tint = row.art and "text.title" or nil, text = ns.T(row.text) }
end
function View.Steps(where, head)
    local D = ns.news
    local list = {}
    if head then
        local rows = {}
        for i = 1, #D.rows do rows[i] = Row(D.rows[i]) end
        list[1] = { key = "news", title = ns.T("news.title"), text = format(ns.T("news.text"), ns.Version.Mine() or "?"),
                    rows = rows, cols = HEAD_COLS, width = HEAD_W }
    end
    local here = ns.Shell and ns.Shell.Current()
    for i = 1, #D.steps do
        local s = D.steps[i]
        local spot = SPOTS[s.spot]
        if s.where == where and spot and Ready(spot) then
            local page = spot.page or (spot.cat and "settings") or (spot.here and here) or nil
            list[#list + 1] = { key = s.spot, title = ns.T(s.title), text = ns.T(s.text),
                                action = (page or spot.open) and function() Prepare(spot, page) end or nil,
                                leave = spot.close,
                                target = function() return View.Find(spot) end }
        end
    end
    return list
end
function View.Start()
    local Shell = ns.Shell
    if not Shell then return false end
    if not Shell.IsOpen() then Shell.Open() end
    local back = Shell.Current()
    local ui = ns.GetDB().settings.ui
    local cat = type(ui) == "table" and ui.setCat or nil
    local steps = View.Steps("shell", true)
    return KT.Start(Shell.Frame(), steps, { id = ID, dim = true, width = W, strata = "DIALOG", onFinish = function()
        News.Seen()
        local S = ns.Settings
        if cat and S and S.Current() ~= cat then S.Select(cat) end
        if type(ui) == "table" then ui.setCat = cat end
        if back and Shell.IsOpen() and Shell.Current() ~= back then Shell.Open(back) end
    end })
end
local wait = CreateFrame("Frame")
wait:Hide()
wait:SetScript("OnUpdate", ns.Prof.Wrap("ui.other", function(self)
    self:Hide()
    if News.Pending() and not KT.Active() and ns.Shell and ns.Shell.IsOpen() then View.Start() end
end))
function View.OnShell()
    if News.Pending() and not KT.Active() then wait:Show() end
end
function View.Iso(ui)
    if not News.IsoPending() or KT.Active() or not ui then return false end
    local steps = View.Steps("iso", false)
    if #steps == 0 then return false end
    return KT.Start(ui.frame, steps, { id = ID_ISO, dim = true, width = W, above = ui.top, strata = "FULLSCREEN_DIALOG",
                                       onFinish = function() News.IsoSeen() end })
end
if ns.Shell and ns.Shell.OnShow then ns.Shell.OnShow(View.OnShell) end
function View.Probe()
    return { tour = KT.Probe(), pending = News.Pending(), iso = News.IsoPending() }
end
