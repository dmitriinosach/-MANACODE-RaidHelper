local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PREFIX = "MRHTP"
local KIND = "T"
local NAME_MAX = 48
local MAX_MSG = 240
local TS = {}
ns.TplShare = TS
TS.PREFIX = PREFIX
local function fold(name)
    return (name or ""):gsub("%-.*$", ""):lower()
end
local function field(s)
    s = tostring(s or ""):gsub("[%c|~;,%.]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #s > NAME_MAX then s = s:sub(1, NAME_MAX) end
    return s
end
local function slotText(slot)
    local parts = { field(slot.role), tostring(tonumber(slot.grp) or 0) }
    if slot.specs then
        for _, sp in ipairs(slot.specs) do parts[#parts + 1] = field(sp) end
    end
    return table.concat(parts, ".")
end
function TS.Encode(t)
    local slots = {}
    for i, s in ipairs(t.slots or {}) do slots[i] = slotText(s) end
    return table.concat({ field(t.key), tostring(tonumber(t.size) or 0), field(ns.Tpl.Name(t)), table.concat(slots, ",") }, ";")
end
function TS.Payload()
    local active = ns.Session and ns.Session.State and ns.Session.State().tpl or ""
    local out = { "A=" .. field(active) }
    for _, t in ipairs(ns.Tpl.List()) do out[#out + 1] = TS.Encode(t) end
    return table.concat(out, "~")
end
function TS.BotInGuild()
    local bot = fold(ns.tplBot)
    local members = ns.Compat.GuildMembers()
    for i = 1, #members do
        if fold(members[i].name) == bot then return true end
    end
    return false
end
function TS.FromBot(sender)
    return fold(sender) == fold(ns.tplBot) and TS.BotInGuild()
end
function TS.Split(id, text)
    local total = 1
    while true do
        local out, pos, n = {}, 1, 0
        repeat
            n = n + 1
            local head = string.format("%s%s:%d/%d:", KIND, id, n, total)
            local stop = pos + MAX_MSG - #head - 1
            if stop < #text then
                while stop >= pos do
                    local b = text:byte(stop + 1)
                    if not b or b < 0x80 or b >= 0xC0 then break end
                    stop = stop - 1
                end
            end
            out[n] = head .. text:sub(pos, stop)
            pos = stop + 1
        until pos > #text
        if n == total then return out end
        total = n
    end
end
function TS.OnMessage(body, sender, chan)
    if chan ~= "WHISPER" or fold(sender) ~= fold(ns.tplBot) then return end
    local id = body:match("^Q(%x%x%x%x)$")
    if not id or not TS.BotInGuild() then return end
    root.Comm.Queue(PREFIX, TS.Split(id, TS.Payload()), "WHISPER", sender)
end
root.Comm.On(PREFIX, TS.OnMessage)
