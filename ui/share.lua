local _, ns = ...
local format = string.format
local match = string.match
local LINK_TYPE = "player::mrh:"
local LINK_COLOR = "badge.link"
local CHECK = 24
local EVENTS = {
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
}
local INFORM = { CHAT_MSG_WHISPER_INFORM = true }
local MEMBER = {
    CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true, CHAT_MSG_RAID_WARNING = true, CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true,
}
local LINE_ARG = 9
local HEAD_W = 96
local HEAD_H = 18
local HEAD_PAD = 6
local HEAD_Y = -19
local View = {}
ns.ShareView = View
local Share = ns.Share
local head
local function T(key)
    return ns.T(key)
end
local function Wrap(e, text)
    local hex = ns.Kit.Hex(LINK_COLOR)
    return format("%s|H%s%d|h%s|h|r", hex, LINK_TYPE, e.id, text)
end
local function Filter(self, event, msg, author, ...)
    local line = select(LINE_ARG, ...)
    local out = Share.Linkify(msg, author, INFORM[event], line, Wrap, MEMBER[event])
    if not out then return false end
    return false, out, author, ...
end
function View.EntryOf(link)
    if type(link) ~= "string" then return nil end
    local id = match(link, "^player::mrh:(%d+)$")
    return Share.Entry(tonumber(id))
end
local function OnItemRef(link, text, button)
    local e = View.EntryOf(link)
    if not e or button == "RightButton" then return end
    Share.Open(e)
end
local function ShowLocal(f)
    if ns.Shell then ns.Shell.Open("log") end
    if ns.Timeline and ns.Timeline.ShowFight then ns.Timeline.ShowFight(f) end
end
local function ShowForeign(f)
    if ns.Shell then ns.Shell.Open("log") end
    if ns.Timeline and ns.Timeline.ShowForeign then ns.Timeline.ShowForeign(f) end
end
Share.onLocal = ShowLocal
Share.onForeign = ShowForeign
local function TargetName()
    if not (UnitExists("target") and UnitIsPlayer("target")) then return nil end
    local name = UnitName("target")
    if not name or name == UnitName("player") then return nil end
    return name
end
function View.Menu(anchor, fight)
    local target = TargetName()
    local menu = {
        { text = T("share.menu"), isTitle = true, notCheckable = true },
        { text = T("share.to.raid"), func = function() Share.Post(fight, "RAID") end },
        { text = T("share.to.guild"), disabled = not IsInGuild(), func = function() Share.Post(fight, "GUILD") end },
        { text = target and format(T("share.to.target"), target) or T("share.to.notarget"), disabled = target == nil,
          func = function() Share.Post(fight, "WHISPER", target) end },
    }
    if ns.Tip then ns.Tip.Hide() end
    ns.Kit.Menu(menu, anchor)
end
local function HeadClick(b)
    if b.fight then View.Menu(b, b.fight) end
end
function View.SetFight(f)
    if not head then return end
    local own = f and not f.foreign and f or nil
    head.fight = own
    if own then head:Show() else head:Hide() end
end
function View.Head(host)
    local b = ns.Kit.Button(host)
    b:SetWidth(HEAD_W)
    b:SetHeight(HEAD_H)
    b:SetPoint("RIGHT", host, "TOPRIGHT", -HEAD_PAD, HEAD_Y)
    b.text:SetText(T("share.btn"))
    b.tipTitle = T("share.btn")
    b.tip = T("share.btn.tip")
    b.onClick = HeadClick
    head = b
    View.SetFight(nil)
    return b
end
function View.HeadFrame()
    return head
end
if ns.SummaryView then
    hooksecurefunc(ns.SummaryView, "Show", function(f) View.SetFight(f) end)
    hooksecurefunc(ns.SummaryView, "Hide", function() View.SetFight(nil) end)
end
for i = 1, #EVENTS do ChatFrame_AddMessageEventFilter(EVENTS[i], Filter) end
hooksecurefunc("SetItemRef", OnItemRef)
local check
local function Refresh()
    if check then check:SetChecked(Share.Accepting()) end
end
if ns.Shell and ns.Shell.Section then
    ns.Shell.Section("share", {
        cat = "guild",
        label = "set.share",
        order = 10,
        height = CHECK + 8,
        build = function(body)
            check = ns.Kit.Check(body, "HTP_FailWatchSetShare")
            check:SetWidth(CHECK)
            check:SetHeight(CHECK)
            check.label:SetText(T("set.share.accept"))
            check.tipTitle = T("set.share.accept")
            check.tip = T("set.share.tip")
            check.onToggle = function(on) Share.SetAccepting(on) end
            check:SetPoint("TOPLEFT", 0, 0)
            Refresh()
        end,
        OnShow = Refresh,
    })
end
