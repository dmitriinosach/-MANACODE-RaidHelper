local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
ns.ADDON = ADDON
ns.VERSION = "0.1.0"
RaidLeadNS = ns
function ns.say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[MANACODE]|r |cffffdb6bRaidLead|r: " .. tostring(msg))
end
