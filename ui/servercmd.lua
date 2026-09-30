local _, ns = ...
local format = string.format
local gsub = string.gsub
local sub = string.sub
local LABEL_MAX = 24
local CMD_MAX = 80
local HEAD_H = 16
local ROW_H = 26
local WHAT_W = 212
local LABEL_X = 220
local LABEL_W = 120
local CMD_X = 348
local CMD_W = 170
local T = ns.T
local Kit = ns.Kit
local S = ns.Settings
local Cmd = {}
ns.ServerCmd = Cmd
local byKey = {}
for i = 1, #ns.serverCmds do byKey[ns.serverCmds[i].key] = ns.serverCmds[i] end
local last = {}
local function Opt()
    local s = ns.GetDB().settings
    local o = s.serverCmd
    if type(o) ~= "table" then
        o = {}
        s.serverCmd = o
    end
    return o
end
local function Over(key)
    local v = Opt()[key]
    return type(v) == "table" and v or nil
end
local function Clean(text, limit)
    local s = gsub(gsub(tostring(text or ""), "|", ""), "%c", "")
    s = s:match("^%s*(.-)%s*$") or ""
    return sub(s, 1, limit)
end
local function Store(key, field, v)
    local o = Opt()
    local cur = Over(key) or {}
    cur[field] = v
    o[key] = (cur.label ~= nil or cur.cmd ~= nil) and cur or nil
end
local function InGroup()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end
function Cmd.Label(key)
    local d = byKey[key]
    local o = Over(key)
    if o and o.label then return o.label end
    return d and T(d.label) or key
end
function Cmd.Command(key)
    local d = byKey[key]
    local o = Over(key)
    if o and o.cmd then return o.cmd end
    return d and d.cmd or ""
end
function Cmd.SetLabel(key, text)
    local d = byKey[key]
    if not d then return end
    local v = Clean(text, LABEL_MAX)
    Store(key, "label", (v ~= "" and v ~= T(d.label)) and v or nil)
end
function Cmd.SetCommand(key, text)
    local d = byKey[key]
    if not d then return end
    local v = Clean(text, CMD_MAX)
    if v ~= "" and sub(v, 1, 1) ~= "." then v = "." .. v end
    Store(key, "cmd", v ~= d.cmd and v or nil)
end
function Cmd.IsDefault()
    return next(Opt()) == nil
end
function Cmd.Reset()
    local s = ns.GetDB().settings
    s.serverCmd = {}
end
function Cmd.State(key)
    local d = byKey[key]
    if not d or Cmd.Command(key) == "" then return false, nil end
    if d.group and not InGroup() then return false, T("scmd.nogroup") end
    local at = last[key]
    if at and GetTime() - at < ns.serverCmdGap then return false, T("scmd.wait") end
    return true, nil
end
function Cmd.Send(key)
    if not Cmd.State(key) then return false end
    last[key] = GetTime()
    SendChatMessage(Cmd.Command(key), "SAY")
    return true
end
function Cmd.Tip(key)
    local d = byKey[key]
    return format(T("scmd.tip"), d and T(d.what) or key, Cmd.Command(key))
end
local actions = {}
local function Action(key)
    local a = actions[key]
    if a then return a end
    a = { key = key, label = "", title = "", tip = "" }
    a.state = function() return Cmd.State(key) end
    a.run = function() Cmd.Send(key) end
    actions[key] = a
    return a
end
local function Rows()
    local items = {}
    for i = 1, #ns.serverCmds do
        local key = ns.serverCmds[i].key
        if Cmd.Command(key) ~= "" then
            local a = Action(key)
            a.label = Cmd.Label(key)
            a.title = a.label
            a.tip = Cmd.Tip(key)
            items[#items + 1] = a
        end
    end
    if #items == 0 then return {} end
    return { { title = T("scmd.row"), items = items } }
end
if ns.Shell and ns.Shell.Actions then ns.Shell.Actions(Rows, 110) end
local function Caption(r, token, x, w)
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", r, "LEFT", x, 0)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    return fs
end
local function BuildHead(r)
    Caption(r, "text.muted", 0, WHAT_W):SetText(T("scmd.set.head.what"))
    Caption(r, "text.muted", LABEL_X, LABEL_W):SetText(T("scmd.set.head.label"))
    Caption(r, "text.muted", CMD_X, CMD_W):SetText(T("scmd.set.head.cmd"))
end
local function Edit(r, x, w, limit, tip, commit)
    local e = Kit.Edit(r, false)
    e:SetWidth(w)
    e:SetMaxLetters(limit)
    e:SetPoint("LEFT", r, "LEFT", x, 0)
    e.tip = tip
    e:SetScript("OnEscapePressed", function(self)
        self.revert = true
        self:ClearFocus()
    end)
    e.onCommit = function(text)
        if e.revert then
            e.revert = nil
        else
            commit(text)
        end
        if S and S.Refresh then S.Refresh() end
    end
    return e
end
local function BuildRow(r, it)
    local key = it.cmdKey
    r.what = Caption(r, "text.primary", 0, WHAT_W)
    r.label = Edit(r, LABEL_X, LABEL_W, LABEL_MAX, T("scmd.set.label.tip"),
        function(text) Cmd.SetLabel(key, text) end)
    r.cmd = Edit(r, CMD_X, CMD_W, CMD_MAX, T("scmd.set.cmd.tip"),
        function(text) Cmd.SetCommand(key, text) end)
end
local function RefreshRow(r, it)
    local key = it.cmdKey
    local d = byKey[key]
    r.what:SetText(T(d.what))
    r.label.tipTitle = T(d.label)
    r.cmd.tipTitle = T(d.label)
    if not r.label:HasFocus() then r.label:SetValue(Cmd.Label(key)) end
    if not r.cmd:HasFocus() then r.cmd:SetValue(Cmd.Command(key)) end
end
if S and S.Section then
    local items = {
        { kind = "text", key = "hint", text = "scmd.set.hint", token = "text.secondary", order = 1 },
        { kind = "custom", key = "head", height = HEAD_H, build = BuildHead, order = 2 },
    }
    for i = 1, #ns.serverCmds do
        items[#items + 1] = { kind = "custom", key = ns.serverCmds[i].key, cmdKey = ns.serverCmds[i].key,
            height = ROW_H, build = BuildRow, refresh = RefreshRow, order = 10 + i }
    end
    items[#items + 1] = { kind = "button", key = "reset", text = "scmd.set.reset", tip = "scmd.set.reset.tip",
        order = 100, run = Cmd.Reset, enabled = function() return not Cmd.IsDefault() end }
    S.Section("guild", "servercmd", { label = "scmd.set", order = 20, items = items })
end
