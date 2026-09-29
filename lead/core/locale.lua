local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
ns.locales = ns.locales or {}
local DEFAULT = "ruRU"
function ns.T(key, ...)
    local own = ns.locales[GetLocale()]
    local s = own and own[key]
    if s == nil then
        local base = ns.locales[DEFAULT]
        s = base and base[key]
    end
    if s == nil then return "[" .. tostring(key) .. "]" end
    if select("#", ...) > 0 then return s:format(...) end
    return s
end
