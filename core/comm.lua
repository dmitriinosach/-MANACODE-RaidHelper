local _, ns = ...
local MAX_LEN = 240
local RATE = 800
local BURST = 400
local OVERHEAD = 40
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
local out = {}
local avail = BURST
local lastAt = nil
local pacer = CreateFrame("Frame")
pacer:Hide()
local function Cost(m)
    return #m.prefix + #m.msg + OVERHEAD
end
local function Drain()
    local now = GetTime()
    if lastAt then avail = math.min(BURST, avail + (now - lastAt) * RATE) end
    lastAt = now
    while out[1] and avail >= Cost(out[1]) do
        local m = table.remove(out, 1)
        avail = avail - Cost(m)
        Comm.Send(m.prefix, m.msg, m.chan, m.target)
    end
    if not out[1] then pacer:Hide() end
end
function Comm.Queue(prefix, msgs, chan, target)
    for i = 1, #msgs do out[#out + 1] = { prefix = prefix, msg = msgs[i], chan = chan, target = target } end
    pacer:Show()
    Drain()
end
function Comm.Queued()
    return #out
end
pacer:SetScript("OnUpdate", ns.Prof.Wrap("hot.comm", Drain))
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
