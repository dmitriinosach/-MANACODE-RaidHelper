local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local L = {
    GAP = 8,
    CARD_H = 50,
    CARD_STEP = 56,
    CARD_MIN = 190,
    CARD_MAX = 300,
    CHIP_H = 26,
    CHIP_STEP = 30,
    CHIP_GAP = 6,
    CHIP_PAIR = 188,
    BAND_H = 22,
    BAND_STEP = 26,
    PART_H = 16,
    PART_STEP = 18,
    GROUP_GAP = 8,
    SCROLL_W = 14,
}
ns.Layout = L
local KEYS = { "tank", "heal", "melee", "ranged", "dd" }
local function has(list, k)
    for _, v in ipairs(list) do
        if v == k then return true end
    end
    return false
end
local function fits(want, r)
    if want == "hybrid" then return true end
    if want == "dd" then return r == "melee" or r == "ranged" end
    return want == r
end
local function roleOf(seat, want)
    local sp = seat.spec and ns.SPEC[seat.spec]
    if sp then return sp.role end
    local found
    for _, cls in ipairs(ns.CLASSES) do
        if cls.token == seat.class then
            for _, s in ipairs(cls.specs) do
                if fits(want, s.role) then
                    if found and found ~= s.role then return nil end
                    found = s.role
                end
            end
        end
    end
    return found
end
local function home(keys, slot, seat)
    local r = slot.role
    if r ~= "hybrid" then
        if has(keys, r) then return r end
        return "any"
    end
    if not seat then return "any" end
    local role = roleOf(seat, r)
    if not role then return "any" end
    if has(keys, role) then return role end
    if (role == "melee" or role == "ranged") and has(keys, "dd") then return "dd" end
    return "any"
end
function L.Part(slot)
    local cap = slot.cap
    if not cap then return "", nil end
    local p, rest = cap:match("^%s*(.-)%s*:%s*(.-)%s*$")
    if p and p ~= "" and rest and rest ~= "" then return p, rest end
    return "", cap
end
local function bucket(slots, seats)
    local keys = {}
    for _, k in ipairs(KEYS) do
        for _, s in ipairs(slots) do
            if s.role == k then
                keys[#keys + 1] = k
                break
            end
        end
    end
    local parts, seen = { "" }, {}
    for _, s in ipairs(slots) do
        local p = L.Part(s)
        if p ~= "" and not seen[p] then
            seen[p] = true
            parts[#parts + 1] = p
        end
    end
    local split = #parts >= 3
    if not split then parts = { "" } end
    local B = { any = { cards = {}, empty = {}, have = 0, total = 0 } }
    for _, k in ipairs(keys) do B[k] = { cards = {}, empty = {}, have = 0, total = 0 } end
    for i, s in ipairs(slots) do
        local seat = seats[i]
        local own = home(keys, s, nil)
        local p, rest = "", s.cap
        if split then p, rest = L.Part(s) end
        local e = { i = i, part = p, label = rest, slot = s }
        B[own].total = B[own].total + 1
        if seat then
            if seat.taken then B[own].have = B[own].have + 1 end
            local at = B[home(keys, s, seat)]
            at.cards[#at.cards + 1] = e
        else
            B[own].empty[#B[own].empty + 1] = e
        end
    end
    return keys, B, parts
end
local function merge(list, part)
    local out, bySig = {}, {}
    for _, e in ipairs(list) do
        if e.part == part then
            local s = e.slot
            local sig = s.role .. "|" .. (e.label or "") .. "|" .. table.concat(s.specs or {}, "/")
            local c = bySig[sig]
            if not c then
                c = { slots = {}, role = s.role, specs = s.specs, label = e.label }
                bySig[sig] = c
                out[#out + 1] = c
            end
            c.slots[#c.slots + 1] = e.i
        end
    end
    return out
end
local function place(keys, B, parts, W)
    local maxCols = math.max(3, math.floor((W + L.GAP) / (L.CARD_MIN + L.GAP)))
    local cols = {}
    for _, k in ipairs(keys) do cols[#cols + 1] = { k } end
    while #cols > maxCols do
        local a = table.remove(cols, 1)
        for _, k in ipairs(cols[1]) do a[#a + 1] = k end
        cols[1] = a
    end
    local nc = #cols
    local items = {}
    if nc == 0 then return { items = items, h = 0, W = W, cols = 0, cw = 0, used = 0 } end
    local cw = math.min(L.CARD_MAX, math.floor((W - (nc - 1) * L.GAP) / nc))
    local pair = cw >= L.CHIP_PAIR
    local hw = pair and math.floor((cw - L.CHIP_GAP) / 2) or cw
    local ys = {}
    for c = 1, nc do ys[c] = 0 end
    local function group(k, ci)
        local b = B[k]
        local x = (ci - 1) * (cw + L.GAP)
        local y = ys[ci]
        if y > 0 then y = y + L.GROUP_GAP end
        items[#items + 1] = { kind = "band", key = k, x = x, y = y, w = cw, h = L.BAND_H,
            have = b.have, total = b.total }
        y = y + L.BAND_STEP
        for _, p in ipairs(parts) do
            local chips = merge(b.empty, p)
            local cards = {}
            for _, e in ipairs(b.cards) do
                if e.part == p then cards[#cards + 1] = e end
            end
            if #cards + #chips > 0 then
                if p ~= "" then
                    items[#items + 1] = { kind = "part", text = p, x = x, y = y, w = cw, h = L.PART_H }
                    y = y + L.PART_STEP
                end
                for _, e in ipairs(cards) do
                    items[#items + 1] = { kind = "card", i = e.i, label = e.label, x = x, y = y, w = cw, h = L.CARD_H }
                    y = y + L.CARD_STEP
                end
                for j, c in ipairs(chips) do
                    local sub = pair and (j - 1) % 2 or 0
                    c.kind, c.n = "chip", #c.slots
                    c.x, c.y, c.w, c.h = x + sub * (hw + L.CHIP_GAP), y, hw, L.CHIP_H
                    items[#items + 1] = c
                    if sub == 1 or not pair or j == #chips then y = y + L.CHIP_STEP end
                end
            end
        end
        ys[ci] = y
    end
    for ci, col in ipairs(cols) do
        for _, k in ipairs(col) do group(k, ci) end
    end
    if #B.any.cards + #B.any.empty > 0 then
        local ci = 1
        for c = 2, nc do
            if ys[c] < ys[ci] then ci = c end
        end
        group("any", ci)
    end
    local h = 0
    for c = 1, nc do
        if ys[c] > h then h = ys[c] end
    end
    return { items = items, h = h, W = W, cols = nc, cw = cw, used = nc * cw + (nc - 1) * L.GAP }
end
function L.Plan(slots, seats, W, H)
    local keys, B, parts = bucket(slots, seats)
    local r = place(keys, B, parts, W)
    r.scroll = false
    if H and r.h > H then
        r = place(keys, B, parts, W - L.SCROLL_W)
        r.scroll = true
    end
    return r
end
