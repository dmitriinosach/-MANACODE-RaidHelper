local _, ns = ...
local format = string.format
local gsub = string.gsub
local find = string.find
local gmatch = string.gmatch
local byte = string.byte
local concat = table.concat
local tsort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local HUGE = math.huge
local TWO32 = 4294967296
local SHORT = 3
local NET_DEPTH = 40
local NET_TABLES = 60000
local EXT_KEY = "&"
local ESC = { ["~"] = "~t", [";"] = "~s" }
local UNESC = { t = "~", s = ";" }
local Codec = {}
ns.Codec = Codec
local out, n = {}, 0
local ids, nid = {}, 0
local strs, nstr = {}, 0
local extOf = nil
local dropKeys = nil
local flat = false
local onPath = {}
local function Esc(s)
    if find(s, "[~;]") then return (gsub(s, "[~;]", ESC)) end
    return s
end
local function Unesc(s)
    if find(s, "~", 1, true) then return (gsub(s, "~(.)", UNESC)) end
    return s
end
local function Num(v)
    if v ~= v then return "N;" end
    if v == HUGE then return "n1e999;" end
    if v == -HUGE then return "n-1e999;" end
    if v % 1 == 0 and v > -1e15 and v < 1e15 then return format("n%.0f;", v) end
    local s = format("%.14g", v)
    if tonumber(s) ~= v then s = format("%.17g", v) end
    return "n" .. s .. ";"
end
local Val
local function Keyable(k)
    local tk = type(k)
    return tk == "string" or tk == "boolean" or (tk == "number" and k == k)
end
local function Storable(v)
    local tv = type(v)
    return tv == "string" or tv == "number" or tv == "boolean" or tv == "table"
end
local function Table(t)
    if flat then
        if onPath[t] then
            n = n + 1
            out[n] = "x;"
            return
        end
    else
        local id = ids[t]
        if id then
            n = n + 1
            out[n] = "^" .. id .. ";"
            return
        end
    end
    local path = extOf and extOf(t)
    if path then
        n = n + 1
        out[n] = flat and ("{;|;q" .. EXT_KEY .. ";{;") or "&;{;"
        for i = 1, #path do Val(path[i]) end
        n = n + 1
        out[n] = flat and "};};" or "};"
        return
    end
    if flat then
        onPath[t] = true
    else
        nid = nid + 1
        ids[t] = nid
    end
    n = n + 1
    out[n] = "{;"
    local len = #t
    for i = 1, len do
        local v = t[i]
        if Storable(v) then Val(v) else
            n = n + 1
            out[n] = "x;"
        end
    end
    local hash = false
    for k, v in pairs(t) do
        local inArray = type(k) == "number" and k >= 1 and k <= len and k % 1 == 0
        if not inArray and Keyable(k) and Storable(v) and not (dropKeys and dropKeys[k]) then
            if not hash then
                hash = true
                n = n + 1
                out[n] = "|;"
            end
            Val(k)
            Val(v)
        end
    end
    n = n + 1
    out[n] = "};"
    onPath[t] = nil
end
Val = function(v)
    local tv = type(v)
    n = n + 1
    if tv == "number" then
        out[n] = Num(v)
    elseif tv == "string" then
        if #v < SHORT then
            out[n] = "q" .. Esc(v) .. ";"
        else
            local i = strs[v]
            if i then
                out[n] = "r" .. i .. ";"
            else
                nstr = nstr + 1
                strs[v] = nstr
                out[n] = "s" .. Esc(v) .. ";"
            end
        end
    elseif tv == "boolean" then
        out[n] = v and "t;" or "f;"
    elseif tv == "table" then
        n = n - 1
        Table(v)
    else
        out[n] = "x;"
    end
end
function Codec.Encode(v, ext, drop, plain)
    n, nid, nstr = 0, 0, 0
    extOf, dropKeys, flat = ext, drop, plain and true or false
    Val(v)
    local s = concat(out, "", 1, n)
    for i = n, 1, -1 do out[i] = nil end
    for k in pairs(ids) do ids[k] = nil end
    for k in pairs(strs) do strs[k] = nil end
    for k in pairs(onPath) do onPath[k] = nil end
    extOf, dropKeys, flat = nil, nil, false
    return s
end
Codec.EXT_KEY = EXT_KEY
local stT, stI, stH, stK, stHK, stE = {}, {}, {}, {}, {}, {}
function Codec.Decode(s, resolve, net)
    if type(s) ~= "string" then return nil, false end
    if net then resolve = nil end
    local tabs, ntab = {}, 0
    local list, nlist = {}, 0
    local top = 0
    local cur, idx, hash, key, hasKey, isExt = nil, 0, false, nil, false, false
    local ext = false
    local result, got = nil, false
    local Step = ns.Jobs.Step
    for tag, body in gmatch(s, "(.)([^;]*);") do
        Step(0.25)
        local v, put = nil, true
        if tag == "n" then
            v = tonumber(body)
        elseif tag == "r" then
            v = list[tonumber(body)]
        elseif tag == "s" then
            v = Unesc(body)
            nlist = nlist + 1
            list[nlist] = v
        elseif tag == "{" then
            if net and (top >= NET_DEPTH or ntab >= NET_TABLES) then return nil, false end
            if cur then
                top = top + 1
                stT[top], stI[top], stH[top], stK[top], stHK[top], stE[top] = cur, idx, hash, key, hasKey, isExt
            end
            cur, idx, hash, key, hasKey, isExt = {}, 0, false, nil, false, ext
            if not ext then
                ntab = ntab + 1
                tabs[ntab] = cur
            end
            ext = false
            put = false
        elseif tag == "}" then
            v = cur
            if isExt then
                v = resolve and resolve(v) or nil
                if v == nil then return nil, false end
            end
            if top > 0 then
                cur, idx, hash, key, hasKey, isExt = stT[top], stI[top], stH[top], stK[top], stHK[top], stE[top]
                stT[top] = nil
                top = top - 1
            else
                cur = nil
            end
        elseif tag == "|" then
            hash = true
            put = false
        elseif tag == "^" then
            if net then return nil, false end
            v = tabs[tonumber(body)]
        elseif tag == "q" then
            v = Unesc(body)
        elseif tag == "t" then
            v = true
        elseif tag == "f" then
            v = false
        elseif tag == "&" then
            if net then return nil, false end
            ext = true
            put = false
        elseif tag == "N" then
            v = 0 / 0
        elseif tag ~= "x" then
            return nil, false
        end
        if put then
            if not cur then
                result, got = v, true
            elseif hash then
                if hasKey then
                    if key ~= nil and key == key then cur[key] = v end
                    hasKey = false
                else
                    if net and v ~= nil and not Keyable(v) and v == v then return nil, false end
                    key, hasKey = v, true
                end
            else
                idx = idx + 1
                if v ~= nil then cur[idx] = v end
            end
        end
    end
    for i = top, 1, -1 do stT[i] = nil end
    return result, got and top == 0 and cur == nil
end
local function KeyOrder(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
    return a < b
end
local function DerivedSet(v)
    local k, x = next(v)
    return type(k) == "string" and x == true
end
local function Canon(v, buf, seen)
    local tv = type(v)
    if tv == "table" then
        if seen[v] then
            buf[#buf + 1] = "@"
            return
        end
        seen[v] = true
        local keys = {}
        for k, x in pairs(v) do
            local tx = type(x)
            local derived = (k == "set" or k == "targets") and tx == "table" and DerivedSet(x)
            if Keyable(k) and tx ~= "function" and tx ~= "userdata" and tx ~= "thread" and not derived then
                keys[#keys + 1] = k
            end
        end
        tsort(keys, KeyOrder)
        buf[#buf + 1] = "{"
        for i = 1, #keys do
            local k = keys[i]
            buf[#buf + 1] = tostring(k)
            buf[#buf + 1] = "="
            Canon(v[k], buf, seen)
        end
        buf[#buf + 1] = "}"
        seen[v] = nil
    elseif tv == "number" then
        buf[#buf + 1] = format("%.14g", v)
    elseif tv == "string" or tv == "boolean" then
        buf[#buf + 1] = tostring(v)
    end
    buf[#buf + 1] = ";"
end
local function Hash(s)
    local h1, h2 = 5381, 0
    local len = #s
    for i = 1, len, 8 do
        local a, b, c, d, e, f, g, h = byte(s, i, i + 7)
        h1 = (h1 * 33 + (a or 0) + (b or 0) * 3 + (c or 0) * 7 + (d or 0) * 13) % TWO32
        h1 = (h1 * 33 + (e or 0) + (f or 0) * 3 + (g or 0) * 7 + (h or 0) * 13) % TWO32
        h2 = (h2 * 31 + (a or 0) * 11 + (c or 0) * 5 + (e or 0) * 17 + (g or 0)) % TWO32
        h2 = (h2 * 31 + (b or 0) * 19 + (d or 0) * 23 + (f or 0) * 29 + (h or 0) * 2) % TWO32
    end
    return format("%.0f.%.0f.%.0f", h1, h2, len)
end
function Codec.Sig(...)
    local buf, seen = {}, {}
    for i = 1, select("#", ...) do Canon((select(i, ...)), buf, seen) end
    return Hash(concat(buf))
end
