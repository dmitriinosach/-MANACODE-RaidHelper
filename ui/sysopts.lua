local _, ns = ...
local function Replay()
    local Iso, RL, E = ns.ReplayIso, ns.ReplayLink, ns.Encounters
    if not (Iso and RL and E) then return end
    if Iso.IsShown() then
        Iso.Hide()
        return
    end
    E.Scan(function()
        local f = E.Fights()[1]
        if RL.Can(f) then
            RL.Open(f)
        else
            ns.Print(ns.T("keys.replay.none"))
        end
    end)
end
local KEYS = {
    { id = "window", label = "keys.window", run = function() ns.Shell.Toggle() end },
    { id = "panel", label = "keys.panel", run = function() ns.Shell.TogglePanel() end },
    { id = "mini", label = "keys.mini", run = function() if ns.Panel then ns.Panel.ToggleMini() end end },
    { id = "replay", label = "keys.replay", run = Replay },
}
local function From(cat, sec, key, default)
    local it = ns.Settings.Find(cat, sec, key)
    if not it then return nil end
    local out = { kind = it.kind == "check" and "check" or "cycle", label = it.label, tip = it.tip,
                  get = it.get, set = it.set, enabled = it.enabled }
    if it.default ~= nil then out.default = it.default else out.default = default end
    if it.kind == "choice" then
        out.options = function()
            return type(it.options) == "function" and it.options() or it.options or {}
        end
    end
    return out
end
local function Items()
    local list = {}
    local function add(it)
        if it then list[#list + 1] = it end
    end
    add({ kind = "head", label = "set.panel" })
    add(From("panel", "panel", "when"))
    add(From("panel", "panel", "compact"))
    add({ kind = "head", label = "set.rec.where" })
    add(From("rec", "where", "raid", true))
    add(From("rec", "where", "party", false))
    add({ kind = "head", label = "set.theme" })
    add(From("look", "theme", "theme"))
    add({ kind = "button", label = "sysopts.open", tip = "sysopts.open.tip", close = true,
          run = function() ns.Settings.Open() end })
    return list
end
local HEADER = "MANACODERAIDHELPER"
local view = {}
ns.SysOptsView = view
if ns.Settings and not ns.ReadOnly then
    local S = ns.Settings
    S.Category("keys", { label = "set.cat.keys", sub = "set.cat.keys.sub", order = 27, group = "general" })
    local items = {}
    for i = 1, #KEYS do
        local k = KEYS[i]
        items[i] = { kind = "key", key = k.id, label = k.label, tip = "set.keys.tip", command = HEADER .. "_" .. k.id:upper() }
    end
    S.Section("keys", "keys", { label = "set.keys", order = 10, items = items })
end
ns.OnReady(function()
    if view.panel or not ns.SysOpts then return end
    local readOnly = ns.ReadOnly or not ns.Settings
    view.panel, view.keys = ns.SysOpts.Register({
        name = "ManaCode Raid Helper",
        T = ns.T,
        version = ns.AddonVersion,
        verKey = "sysopts.ver",
        frame = "ManaCodeRaidHelperOptions",
        items = not readOnly and Items or nil,
        keys = { header = HEADER, global = "ManaCodeRaidHelperKey", list = KEYS },
    })
end)
