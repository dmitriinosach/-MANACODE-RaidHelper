local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
ns.locales = ns.locales or {}
local DEFAULT = "ruRU"
local CLIENT_LANG = { ruRU = "ruRU", esES = "esES", esMX = "esES" }
function ns.Lang()
    if root.lang then return root.lang end
    return CLIENT_LANG[GetLocale()] or "enUS"
end
function ns.T(key, ...)
    local lang = ns.Lang()
    local own = ns.locales[lang]
    local s = own and own[key]
    if s == nil and lang == "esES" then
        local en = ns.locales.enUS
        s = en and en[key]
    end
    if s == nil then
        local base = ns.locales[DEFAULT]
        s = base and base[key]
    end
    if s == nil then return "[" .. tostring(key) .. "]" end
    if select("#", ...) > 0 then return s:format(...) end
    return s
end
