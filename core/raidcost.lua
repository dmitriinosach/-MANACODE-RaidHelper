local _, ns = ...
local floor = math.floor
local format = string.format
local tsort = table.sort
local COPPER = 10000
local CAT_ORDER = { flask = 1, elixir = 2, potion = 3, food = 4, scroll = 5, other = 6, stone = 7 }
local Cost = {}
ns.RaidCost = Cost
Cost.GOLD_ICON = "Interface\\MoneyFrame\\UI-GoldIcon"
local items
local byName
local function Manual()
    local db = ns.GetDB()
    if type(db.prices) ~= "table" then db.prices = {} end
    return db.prices
end
function Cost.Items()
    if items then return items end
    items = {}
    local seen = {}
    local function Add(map)
        for spell, c in pairs(map or {}) do
            if not c.free and c.id and not seen[c.item] then
                seen[c.item] = true
                items[#items + 1] = { item = c.item, id = c.id, cat = c.cat, spell = tonumber(spell) }
            end
        end
    end
    Add(ns.consumeCast)
    Add(ns.consumeCreate)
    Add(ns.consumeEnchant)
    Add(ns.consumeAura)
    tsort(items, function(a, b)
        local ca, cb = Cost.CatOrder(a.cat), Cost.CatOrder(b.cat)
        if ca ~= cb then return ca < cb end
        return a.item < b.item
    end)
    return items
end
function Cost.Icon(id, spell)
    local tex = id and GetItemIcon and GetItemIcon(id)
    if tex then return tex end
    return spell and ns.Effects and ns.Effects.IconById(spell) or nil
end
function Cost.CatOrder(cat)
    return CAT_ORDER[cat] or 9
end
function Cost.HasAH()
    return type(_G.Atr_GetAuctionPrice) == "function"
end
function Cost.AH(item)
    local fn = _G.Atr_GetAuctionPrice
    if type(fn) ~= "function" then return nil, nil end
    local id = Cost.Id(item)
    local name = id and GetItemInfo and GetItemInfo(id)
    local ok, v = pcall(fn, name or item)
    if (not ok or type(v) ~= "number" or v <= 0) and name and name ~= item then ok, v = pcall(fn, item) end
    if not ok or type(v) ~= "number" or v <= 0 then return nil, nil end
    local stamp = _G.AUCTIONATOR_LAST_SCAN_TIME
    return v, type(stamp) == "number" and stamp or nil
end
function Cost.Manual(item)
    local m = Manual()[item]
    if type(m) ~= "table" or type(m.c) ~= "number" or m.c <= 0 then return nil, nil end
    return m.c, m.t
end
function Cost.Set(item, gold)
    local list = Manual()
    if not gold or gold <= 0 then
        list[item] = nil
    else
        list[item] = { c = floor(gold * COPPER + 0.5), t = time() }
    end
end
function Cost.Id(item)
    if not byName then
        byName = {}
        local list = Cost.Items()
        for i = 1, #list do byName[list[i].item] = list[i].id end
    end
    return byName[item]
end
function Cost.Scan(item)
    local rec = ns.AhScan and ns.AhScan.Get(Cost.Id(item))
    if not rec then return nil, nil, nil end
    return rec.p, rec.t, rec
end
function Cost.Price(item)
    local c, t = Cost.Manual(item)
    if c then return c, "manual", t end
    c, t = Cost.Scan(item)
    if c then return c, "scan", t end
    c, t = Cost.AH(item)
    if c then return c, "ah", t end
    return nil, nil, nil
end
local function Spaced(n)
    local s = tostring(floor(n))
    local sep = ns.lang == "enUS" and "," or " "
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    return (out:gsub("^" .. sep, ""))
end
function Cost.Amount(copper)
    local g = copper / COPPER
    if g > 0 and g < 10 then return ns.Dec(format("%.1f", g)) end
    return Spaced(g + 0.5)
end
function Cost.Gold(copper)
    local g = copper / COPPER
    return format(ns.T(g > 0 and g < 10 and "cost.gold.frac" or "cost.gold"), Cost.Amount(copper))
end
function Cost.GoldIcon(copper)
    return format("%s |T%s:0|t", Cost.Amount(copper), Cost.GOLD_ICON)
end
function Cost.Date(stamp)
    if not stamp then return ns.T("cost.nodate") end
    return date("%d.%m.%Y", stamp)
end
function Cost.Stamp(stamp)
    if not stamp then return ns.T("cost.nodate") end
    return date("%d.%m %H:%M", stamp)
end
