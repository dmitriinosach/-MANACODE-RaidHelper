local ADDON, ns = ...
local floor = math.floor
local format = string.format
local gsub = string.gsub
local sub = string.sub
local strlower = string.lower
local LABEL_MAX = 24
local CMD_MAX = 80
local MAX = 4
local HEAD_H = 16
local ROW_H = 26
local LABEL_X = 0
local LABEL_W = 150
local CMD_X = 158
local CMD_W = 260
local DEL_X = 426
local ART = "Interface\\AddOns\\" .. ADDON .. "\\art\\panel\\"
local T = ns.T
local Kit = ns.Kit
local S = ns.Settings
local Cmd = {}
ns.ServerCmd = Cmd
Cmd.MAX = MAX
local byKey = {}
for i = 1, #ns.serverCmds do byKey[ns.serverCmds[i].key] = ns.serverCmds[i] end
local last = setmetatable({}, { __mode = "k" })
local function Opt()
    local s = ns.GetDB().settings
    local o = s.serverCmd
    if type(o) ~= "table" or (o.list ~= nil and type(o.list) ~= "table") then
        o = {}
        s.serverCmd = o
    end
    return o
end
local defaults
local function Defaults()
    if defaults then return defaults end
    defaults = {}
    for i = 1, #ns.serverCmds do defaults[i] = { key = ns.serverCmds[i].key, cmd = ns.serverCmds[i].cmd } end
    return defaults
end
function Cmd.List()
    return Opt().list or Defaults()
end
local function Own()
    local o = Opt()
    if not o.list then
        o.list = {}
        for i, d in ipairs(Defaults()) do o.list[i] = { key = d.key, cmd = d.cmd } end
    end
    return o.list
end
local function Clean(text, limit)
    local s = gsub(gsub(tostring(text or ""), "|", ""), "%c", "")
    s = s:match("^%s*(.-)%s*$") or ""
    if #s <= limit then return s end
    s = sub(s, 1, limit)
    local i = #s
    while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
    if i > 0 and s:byte(i) >= 0xC0 then
        local need = s:byte(i) >= 0xF0 and 4 or s:byte(i) >= 0xE0 and 3 or 2
        if #s - i + 1 < need then s = sub(s, 1, i - 1) end
    end
    return s
end
local function InGroup()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end
function Cmd.Label(i)
    local e = Cmd.List()[i]
    if not e then return "" end
    if e.label then return e.label end
    local d = e.key and byKey[e.key]
    return d and T(d.label) or format(T("scmd.new"), i)
end
function Cmd.Title(i)
    local e = Cmd.List()[i]
    local d = e and not e.label and e.key and byKey[e.key]
    return d and T(d.title or d.label) or Cmd.Label(i)
end
function Cmd.Command(i)
    local e = Cmd.List()[i]
    return e and e.cmd or ""
end
function Cmd.SetLabel(i, text)
    local e = Own()[i]
    if not e then return end
    local v = Clean(text, LABEL_MAX)
    local d = e.key and byKey[e.key]
    e.label = (v ~= "" and not (d and v == T(d.label))) and v or nil
end
function Cmd.SetCommand(i, text)
    local e = Own()[i]
    if not e then return end
    local v = Clean(text, CMD_MAX)
    local c = sub(v, 1, 1)
    if v ~= "" and c ~= "." and c ~= "/" then v = "." .. v end
    e.cmd = v
end
function Cmd.Add()
    local list = Own()
    if #list >= MAX then return nil end
    list[#list + 1] = { cmd = "" }
    return #list
end
function Cmd.Remove(i)
    local list = Own()
    if list[i] then table.remove(list, i) end
end
function Cmd.IsDefault()
    return Opt().list == nil
end
function Cmd.Reset()
    Opt().list = nil
end
local function Slash(text)
    local word, args = text:match("^(/%S+)%s*(.*)$")
    if not word then return nil, "" end
    word = strlower(word)
    for name, fn in pairs(SlashCmdList) do
        for k = 1, 9 do
            local w = _G["SLASH_" .. name .. k]
            if type(w) ~= "string" then break end
            if strlower(w) == word then return fn, args end
        end
    end
    return nil, args
end
function Cmd.State(i)
    local e = Cmd.List()[i]
    local text = e and e.cmd or ""
    if text == "" then return false, nil end
    local d = e.key and byKey[e.key]
    if d and d.group and not InGroup() then return false, T("scmd.nogroup") end
    if sub(text, 1, 1) == "/" and not Slash(text) then return false, format(T("scmd.noslash"), text:match("^(/%S+)")) end
    local at = last[e]
    if at and GetTime() - at < ns.serverCmdGap then return false, T("scmd.wait") end
    return true, nil
end
function Cmd.Send(i)
    if not Cmd.State(i) then return false end
    local e = Cmd.List()[i]
    last[e] = GetTime()
    local d = e.key and byKey[e.key]
    if d and d.dismount and IsMounted and IsMounted() and not (IsFlying and IsFlying()) and Dismount then Dismount() end
    if sub(e.cmd, 1, 1) == "/" then
        local fn, args = Slash(e.cmd)
        fn(args)
    else
        SendChatMessage(e.cmd, "SAY")
    end
    return true
end
function Cmd.Tip(i)
    local e = Cmd.List()[i]
    local d = e and not e.label and e.key and byKey[e.key]
    if d then return format(T("scmd.tip"), T(d.what), Cmd.Command(i)) end
    return format(T("scmd.tip.own"), Cmd.Command(i))
end
function Cmd.Edit()
    if #Cmd.List() == 0 then Cmd.Add() end
    if S and S.Open then S.Open("guild") end
end
local actions = {}
local function Action(i)
    local a = actions[i]
    if a then return a end
    a = { n = i, id = "cmd" .. i, label = "", title = "", tip = "" }
    a.state = function() return Cmd.State(i) end
    a.run = function() Cmd.Send(i) end
    actions[i] = a
    return a
end
local function Always() return true end
local editAct = { id = "edit", label = "", title = "", tip = "", state = Always, run = Cmd.Edit,
    icon = function(tex)
        tex:SetTexture(ART .. "settings")
        Kit.Tint(tex, "text.primary")
    end }
local addAct = { id = "add", label = "", title = "", tip = "", state = Always, run = Cmd.Edit }
local function Rows()
    local items = {}
    local list = Cmd.List()
    for i = 1, #list do
        if list[i].cmd ~= "" then
            local a = Action(i)
            a.label = Cmd.Label(i)
            a.title = Cmd.Title(i)
            a.tip = Cmd.Tip(i)
            items[#items + 1] = a
        end
    end
    if #items == 0 then
        addAct.label, addAct.title, addAct.tip = T("scmd.add"), T("scmd.add"), T("scmd.add.tip")
        items[1] = addAct
    else
        editAct.title, editAct.tip = T("scmd.edit"), T("scmd.edit.tip")
        items[#items + 1] = editAct
    end
    return { { id = "server", title = T("scmd.row"), items = items } }
end
if ns.Shell and ns.Shell.Actions then ns.Shell.Actions(Rows, 110) end
local SMALL = "GameFontHighlightSmall"
local function K(n)
    return floor(n * Kit.FontScale(SMALL, true) + 0.5)
end
local function Column(r, obj, x, w)
    local list = r.cols
    if not list then
        list = {}
        r.cols = list
        r.Place = function()
            for i = 1, #list do
                local c = list[i]
                c.obj:ClearAllPoints()
                c.obj:SetPoint("LEFT", r, "LEFT", K(c.x), 0)
                c.obj:SetWidth(K(c.w))
            end
        end
    end
    list[#list + 1] = { obj = obj, x = x, w = w }
    r.Place()
end
local function Caption(r, token, x, w)
    local fs = Kit.Str(r, SMALL)
    fs:SetJustifyH("LEFT")
    Kit.Text(fs, token)
    Column(r, fs, x, w)
    return fs
end
local function BuildHead(r)
    Caption(r, "text.muted", LABEL_X, LABEL_W):SetText(T("scmd.set.head.label"))
    Caption(r, "text.muted", CMD_X, CMD_W):SetText(T("scmd.set.head.cmd"))
end
local function Edit(r, x, w, limit, tip, commit)
    local e = Kit.Edit(r, false)
    e:SetMaxLetters(limit)
    Column(r, e, x, w)
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
    local n = it.n
    r.label = Edit(r, LABEL_X, LABEL_W, LABEL_MAX, T("scmd.set.label.tip"), function(text) Cmd.SetLabel(n, text) end)
    r.cmd = Edit(r, CMD_X, CMD_W, CMD_MAX, T("scmd.set.cmd.tip"), function(text) Cmd.SetCommand(n, text) end)
    r.del = Kit.GlyphButton(r, "close")
    r.del.tipTitle = T("scmd.set.del")
    r.del.onClick = function()
        Cmd.Remove(n)
        if S and S.Refresh then S.Refresh() end
    end
end
local function RefreshRow(r, it)
    local n = it.n
    r.label.tipTitle = Cmd.Title(n)
    r.cmd.tipTitle = Cmd.Title(n)
    if not r.label:HasFocus() then r.label:SetValue(Cmd.Label(n)) end
    if not r.cmd:HasFocus() then r.cmd:SetValue(Cmd.Command(n)) end
    r.del:ClearAllPoints()
    r.del:SetPoint("LEFT", r, "LEFT", K(DEL_X), 0)
end
if S and S.Section then
    local items = {
        { kind = "text", key = "hint", text = "scmd.set.hint", token = "text.secondary", order = 1 },
        { kind = "custom", key = "head", height = function() return Kit.GrowH(HEAD_H, SMALL) end, build = BuildHead, order = 2,
          shown = function() return #Cmd.List() > 0 end },
    }
    for i = 1, MAX do
        items[#items + 1] = { kind = "custom", key = "cmd" .. i, n = i,
            height = function() return Kit.GrowH(ROW_H, SMALL) end, build = BuildRow, refresh = RefreshRow, order = 10 + i,
            shown = function() return Cmd.List()[i] ~= nil end }
    end
    items[#items + 1] = { kind = "button", key = "add", text = "scmd.add", tip = "scmd.add.tip", order = 90,
        run = function()
            Cmd.Add()
            if S.Refresh then S.Refresh() end
        end,
        enabled = function() return #Cmd.List() < MAX end }
    items[#items + 1] = { kind = "button", key = "reset", text = "scmd.set.reset", tip = "scmd.set.reset.tip",
        order = 100, run = Cmd.Reset, enabled = function() return not Cmd.IsDefault() end }
    S.Section("guild", "servercmd", { label = "scmd.set", order = 20, items = items })
end
