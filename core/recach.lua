local _, ns = ...
local ACH_LINK = "|Hachievement:(%d+):"
local ACH_DUP = 30
local ACH_MAX = 512
local RecAch = { EVENTS = { "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT" } }
ns.RecAch = RecAch
local achSeen = {}
local achN = 0
local function InGroup(name)
    local slots, _, _, slotName, slotPlayer = ns.Recorder.Roster(true)
    for k = 1, slots do
        if slotPlayer[k] and slotName[k] == name then return true end
    end
    return false
end
function RecAch.On(msg, sender)
    if not ns.Recorder.InZone() or type(msg) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local id = tonumber(msg:match(ACH_LINK))
    if not id then return end
    local name = sender:match("^([^%-]+)") or sender
    if not InGroup(name) then return end
    local key = name .. ":" .. id
    local now = GetTime()
    if achSeen[key] and now - achSeen[key] < ACH_DUP then return end
    if not achSeen[key] then
        achN = achN + 1
        if achN > ACH_MAX then
            wipe(achSeen)
            achN = 1
        end
    end
    achSeen[key] = now
    ns.Recorder.Mark("FW_ACH", nil, name, 0, nil, nil, 0, id)
end
