local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local Comm = {}
ns.Comm = Comm
local shared = root.Comm
function Comm.On(prefix, fn)
    shared.On(prefix, fn)
end
function Comm.Clean(text)
    return shared.Clean(text)
end
function Comm.Send(prefix, msg, chan)
    ns.Compat.SendAddon(prefix, msg, chan)
end
