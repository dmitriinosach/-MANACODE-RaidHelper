local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local PREFIX = "MRHTP"
local KIND = "T"
local NAME_MAX = 48
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
function TS.FromBot(sender)
    return root.Fable ~= nil and fold(sender) == fold(root.Fable.Bot())
end
function TS.OnMessage(body, sender, chan)
    if chan ~= "WHISPER" or not TS.FromBot(sender) then return end
    local id = body:match("^Q(%x%x%x%x)$")
    if not id then return end
    root.Comm.Queue(PREFIX, root.Fable.Split(KIND, id, TS.Payload()), "WHISPER", sender)
end
root.Comm.On(PREFIX, TS.OnMessage)
