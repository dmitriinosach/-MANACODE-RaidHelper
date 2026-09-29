local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local tsort = table.sort
local concat = table.concat
local WHO_MAX = 12
local ICON_FRAME_SIZE = 17
local SHIELD_SIZE = 13
local MARK_SIZE = 12
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ART = "Interface\\AchievementFrame\\UI-Achievement-"
local TITLE_BAR = ART .. "Title"
local ICON_FRAME = ART .. "IconFrame"
local TINY_SHIELD = ART .. "TinyShield"
local READY = "Interface\\RaidFrame\\ReadyCheck-"
local BAR_COORD = { 0, 0.9765625, 0, 0.3125 }
local FRAME_COORD = { 0, 0.5625, 0, 0.5625 }
local TINY_COORD = { 0, 0.625, 0, 0.625 }
local COLOR = {
    done = "text.good",
    fail = "text.bad",
    short = "text.warn",
    open = "text.muted",
    nodata = "text.off",
}
local MARK = {
    done = READY .. "Ready",
    fail = READY .. "NotReady",
    short = READY .. "Waiting",
    open = READY .. "Waiting",
    nodata = READY .. "Waiting",
}
local DIM = "text.muted"
local View = {}
ns.AchView = View
local raidPanel
local function T(key)
    return ns.T(key)
end
local function Short(n)
    return ns.BadgeTips.Short(n or 0)
end
local function Clock(sec)
    return ns.BadgeTips.Clock(max(0, sec or 0))
end
local function Paint(token, text)
    return ns.Kit.Hex(token) .. text .. "|r"
end
function View.Name(id)
    local name, desc, icon = ns.Achievements.Info(id)
    return name or format(T("ach.unknown"), id), desc, icon or UNKNOWN_ICON
end
function View.Progress(r)
    local def, k = r.def, r.def.kind
    if k == "auraLonger" then return format(T("ach.p.longer"), r.value, r.limit) end
    if k == "maxStack" then return format(T("ach.p.stack"), r.value, r.limit) end
    if k == "reachStack" then return format(T("ach.p.reach"), r.value, r.need) end
    if k == "auraCount" then return format(T("ach.p.count"), r.value, r.limit) end
    if k == "casts" then return format(T("ach.p.casts"), r.value) end
    if k == "hitBy" then return format(T("ach.p.hits"), r.value) end
    if k == "deathBy" then return format(T("ach.p.deaths"), r.value) end
    if k == "hitOver" then return format(T("ach.p.big"), Short(r.value), Short(r.limit)) end
    if k == "noKill" then return format(T("ach.p.nokill"), r.value) end
    if k == "killed" then return T(r.value > 0 and "ach.p.killed" or "ach.p.notkilled") end
    if k == "lastDied" then return r.last and format(T("ach.p.last"), r.last) or "" end
    if k == "killSpan" then return format(T("ach.p.span"), floor(r.value), r.limit) end
    if k == "timeLimit" then return format(T("ach.p.time"), Clock(r.value), Clock(r.limit)) end
    if k == "aliveAt" then
        return format(T(def.count == "types" and "ach.p.types" or "ach.p.units"), r.value, r.need)
    end
    if k == "visits" then return format(T("ach.p.visits"), r.value, r.limit) end
    if k == "vampire" then return format(T("ach.p.vampires"), r.value) end
    return T("ach.p.nodata")
end
function View.Status(status, personal)
    if personal then return Paint(COLOR.open, T("ach.s.personal")) end
    return Paint(COLOR[status] or COLOR.nodata, T("ach.s." .. status))
end
local function Detail(r, e)
    local k = r.def.kind
    local extra
    if k == "auraLonger" then
        extra = format(T("ach.who.sec"), e.v or 0)
    elseif k == "maxStack" then
        extra = format(T("ach.who.stack"), e.v or 0)
    elseif k == "auraCount" then
        extra = format("#%d", e.v or 0)
    elseif k == "hitBy" then
        extra = format(T("ach.who.hits"), e.n)
    elseif k == "hitOver" then
        extra = Short(e.v or 0) .. (e.note and (", " .. e.note) or "")
    elseif k == "casts" then
        extra = e.n > 1 and format(T("ach.who.times"), e.n) or nil
    elseif k == "visits" then
        local at = {}
        for i = 1, min(#(e.times or {}), 4) do at[i] = Clock(e.times[i]) end
        return format(T("ach.who.visits"), e.v or 0) .. (#at > 0 and (", " .. concat(at, " ")) or "")
    end
    return Clock(e.t) .. (extra and (", " .. extra) or "")
end
local function ResultLines(r, out)
    local k = r.def.kind
    out[#out + 1] = { kind = "row", left = T("ach.tt.status"), right = View.Status(r.status, r.def.personal) }
    out[#out + 1] = { kind = "row", left = T("ach.tt.result"), right = View.Progress(r) }
    if r.status == "open" and not r.def.personal then out[#out + 1] = { kind = "note", left = T("ach.tt.open") } end
    local who = r.who or {}
    if #who > 0 and k ~= "vampire" then
        out[#out + 1] = { kind = "sep" }
        out[#out + 1] = { kind = "head", left = T(k == "noKill" and "ach.tt.what" or "ach.tt.who") }
        for i = 1, min(#who, WHO_MAX) do
            local e = who[i]
            local left = e.name or T("ach.who.none")
            if k == "casts" and e.name then left = left .. " " .. Paint(DIM, T("ach.who.rider")) end
            out[#out + 1] = { kind = "row", left = left, class = e.name and ns.Encounters.ClassOf(e.name) or nil,
                              right = Detail(r, e), tone = r.status == "fail" and "bad" or nil }
        end
    elseif r.status == "fail" then
        out[#out + 1] = { kind = "note", left = T("ach.tt.nobody") }
    end
    if r.alive and #r.alive > 0 then
        out[#out + 1] = { kind = "sep" }
        out[#out + 1] = { kind = "head", left = T("ach.tt.alive") }
        for i = 1, #r.alive do out[#out + 1] = { kind = "sub", left = r.alive[i] } end
    end
    if r.personal then
        local names = {}
        for n in pairs(r.personal) do names[#names + 1] = n end
        tsort(names)
        out[#out + 1] = { kind = "sep" }
        out[#out + 1] = { kind = "head", left = T("ach.tt.vamp"), right = tostring(#names) }
        for i = 1, #names do
            out[#out + 1] = { kind = "row", left = names[i], class = ns.Encounters.ClassOf(names[i]),
                              right = Clock(r.personal[names[i]]) }
        end
        out[#out + 1] = { kind = "note", left = T("ach.tt.vamp.note") }
    end
end
local function BossLines(row, out)
    local progress = format(T(row.scope == "meta" and "ach.p.meta" or "ach.p.bosses"), row.have, row.need)
    out[#out + 1] = { kind = "row", left = T("ach.tt.status"), right = View.Status(row.status) }
    out[#out + 1] = { kind = "row", left = T("ach.tt.kills"), right = progress }
    local missing = row.missing or {}
    if #missing == 0 or row.got then return end
    out[#out + 1] = { kind = "sep" }
    out[#out + 1] = { kind = "head", left = T("ach.tt.missing") }
    for i = 1, min(#missing, WHO_MAX + 8) do
        local text = missing[i]
        if row.scope == "meta" then
            local def = ns.Achievements.Def(text)
            local id = def and row.size and def.id[row.size]
            text = id and View.Name(id) or text
        end
        out[#out + 1] = { kind = "sub", left = text }
    end
end
local function Nicks(got)
    local names = {}
    for name in pairs(got.who) do names[#names + 1] = name end
    tsort(names, function(a, b)
        if got.who[a] ~= got.who[b] then return got.who[a] < got.who[b] end
        return a < b
    end)
    local parts = {}
    for i = 1, #names do
        local r, g, b = ns.Kit.ClassColor(ns.Encounters.ClassOf(names[i]))
        parts[i] = format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5),
            names[i])
    end
    return parts
end
local function GotLines(got, out)
    local parts = Nicks(got)
    out[#out + 1] = { kind = "sep" }
    out[#out + 1] = { kind = "head", left = format(T("ach.tt.got"), #parts),
                      right = got.t and date("%d.%m %H:%M", floor(got.t)) or nil }
    out[#out + 1] = { kind = "text", left = concat(parts, ", ") }
end
function View.Extra(row)
    local out = {}
    if row.result then
        ResultLines(row.result, out)
    elseif row.scope == "raid" or row.scope == "meta" then
        BossLines(row, out)
    end
    if row.got then GotLines(row.got, out) end
    if row.result and row.fight and row.scope == "encounter" and row.fight.raid then
        out[#out + 1] = { kind = "foot", left = format(T("ach.tt.fight"), date("%d.%m %H:%M", floor(row.fight.from))) }
    end
    return out
end
function View.Tip(row)
    local pts = row.points or 0
    local out = { { kind = "head", left = row.name or format(T("ach.unknown"), row.id),
                    right = pts > 0 and format(T("ach.tt.points"), pts) or nil } }
    if row.desc and row.desc ~= "" then out[2] = { kind = "note", left = row.desc } end
    local extra = View.Extra(row)
    if #extra > 0 then
        out[#out + 1] = { kind = "sep" }
        for i = 1, #extra do out[#out + 1] = extra[i] end
    end
    return out
end
function View.Row(row)
    local pts = row.points or 0
    local icon = row.icon or UNKNOWN_ICON
    return { who = row.name or format(T("ach.unknown"), row.id), icon = icon, text = pts > 0 and tostring(pts) or "",
             lines = View.Tip(row), tipIcon = icon, data = row }
end
local function Coord(tex, c)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
local function Deco(row)
    local x = {}
    x.bar = row:CreateTexture(nil, "BACKGROUND")
    x.bar:SetAllPoints(row)
    x.frame = row:CreateTexture(nil, "OVERLAY")
    x.frame:SetWidth(ICON_FRAME_SIZE)
    x.frame:SetHeight(ICON_FRAME_SIZE)
    x.frame:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    x.mark = row:CreateTexture(nil, "ARTWORK")
    x.mark:SetWidth(MARK_SIZE)
    x.mark:SetHeight(MARK_SIZE)
    x.mark:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    x.shield = row:CreateTexture(nil, "ARTWORK")
    x.shield:SetWidth(SHIELD_SIZE)
    x.shield:SetHeight(SHIELD_SIZE)
    x.shield:SetPoint("RIGHT", x.mark, "LEFT", -3, 0)
    row.ach = x
    return x
end
local function HideDeco(x)
    x.bar:Hide()
    x.frame:Hide()
    x.shield:Hide()
    x.mark:Hide()
end
function View.PaintRow(row, e)
    local a = e and e.data
    local x = row.ach
    if not a then
        if x then HideDeco(x) end
        return
    end
    x = x or Deco(row)
    local on = a.status == "done"
    local personal = a.def and a.def.personal
    x.bar:SetTexture(TITLE_BAR)
    Coord(x.bar, BAR_COORD)
    ns.Kit.Tint(x.bar, "ach.bar")
    if on then x.bar:Show() else x.bar:Hide() end
    row.icon:SetDesaturated(not on)
    x.frame:SetTexture(ICON_FRAME)
    Coord(x.frame, FRAME_COORD)
    ns.Kit.Tint(x.frame, on and "ach.art" or "ach.artOff")
    x.frame:Show()
    x.mark:SetTexture(MARK[a.status] or MARK.nodata)
    x.mark:SetDesaturated(true)
    ns.Kit.Tint(x.mark, personal and COLOR.open or COLOR[a.status] or COLOR.nodata)
    x.mark:Show()
    x.shield:SetTexture(TINY_SHIELD)
    Coord(x.shield, TINY_COORD)
    x.shield:SetDesaturated(not on)
    if (a.points or 0) > 0 then x.shield:Show() else x.shield:Hide() end
    row.val:ClearAllPoints()
    row.val:SetPoint("RIGHT", x.shield, "LEFT", -1, 0)
    ns.Kit.Tone(row.val, on and "ach.points" or "ach.pointsOff")
    ns.Kit.Tone(row.name, on and "ach.name" or "ach.nameOff")
end
local function Tally(rows)
    local done, total, chatOnly = 0, 0, true
    for i = 1, #rows do
        local row = rows[i]
        if row.scope ~= "chat" then chatOnly = false end
        if not (row.def and row.def.personal) then
            total = total + 1
            if row.status == "done" then done = done + 1 end
        end
    end
    return done, total, chatOnly
end
function View.Model(rows, pending, onWheel)
    local done, total, chatOnly = Tally(rows)
    local title
    if pending > 0 then
        title = T("ach.raid.wait")
    elseif chatOnly then
        title = format(T("ach.raid.got"), done)
    else
        title = format(T("ach.raid.title"), done, total)
    end
    local list = {}
    for i = 1, #rows do list[i] = View.Row(rows[i]) end
    return { title = title, rows = list, empty = T("ach.none"), onWheel = onWheel, paint = View.PaintRow }
end
function View.RaidItem(parent, raid, got, onWheel, onReady)
    local rows, pending = ns.Achievements.ForRaid(raid, onReady, got)
    if #rows == 0 and pending == 0 then
        if raidPanel then raidPanel:Hide() end
        return nil
    end
    raidPanel = raidPanel or ns.Badges.Detail(parent)
    raidPanel:SetParent(parent)
    raidPanel:SetModel(View.Model(rows, pending, onWheel))
    return raidPanel
end
function View.HideRaid()
    if raidPanel then raidPanel:Hide() end
end
