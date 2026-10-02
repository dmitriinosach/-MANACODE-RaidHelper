local _, ns = ...
local MAX_LEN = 240
local Comm = {}
ns.Comm = Comm
local handlers = {}
function Comm.On(prefix, fn)
    handlers[prefix] = fn
end
function Comm.Clean(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%c|]", "")
    if #text > MAX_LEN then text = text:sub(1, MAX_LEN) end
    return text
end
function Comm.Send(prefix, msg, chan, target)
    SendAddonMessage(prefix, msg, chan, target)
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", ns.Prof.Wrap("hot.comm", function(_, _, prefix, msg, chan, sender)
    local fn = handlers[prefix]
    if not fn then return end
    local who = Comm.Clean(sender)
    if not who or who == "" or who == UnitName("player") then return end
    local body = Comm.Clean(msg)
    if not body then return end
    fn(body, who, chan)
end))
