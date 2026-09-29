local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local T = {}
ns.Tpl = T
T.ROLES = { "tank", "heal", "melee", "ranged", "dd", "hybrid" }
T.NAME_MAX = 48
local function copySlots(slots)
    local out = {}
    for i, s in ipairs(slots) do
        local specs
        if s.specs then
            specs = {}
            for k, v in ipairs(s.specs) do specs[k] = v end
        end
        out[i] = { role = s.role, specs = specs, cap = s.cap, mark = s.mark }
    end
    return out
end
local function store()
    local db = ns.Store.DB()
    db.templates = db.templates or {}
    return db.templates
end
local function cut(s, limit)
    if #s <= limit then return s end
    local i = limit
    while i > 0 do
        local b = s:byte(i + 1)
        if not b or b < 128 or b >= 192 then break end
        i = i - 1
    end
    return s:sub(1, i)
end
function T.Clean(s, limit)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("%c", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = cut(s, limit or T.NAME_MAX):gsub("%s+$", "")
    return s
end
function T.Get(key)
    return store()[key] or ns.TEMPLATE[key]
end
function T.Exists(key)
    return T.Get(key) ~= nil
end
function T.Name(tpl)
    if not tpl then return "?" end
    if tpl.name then return tpl.name end
    return ns.T(tpl.label)
end
function T.IsFactory(key)
    return ns.TEMPLATE[key] ~= nil
end
function T.IsCustom(key)
    return store()[key] ~= nil
end
function T.Locked(key)
    return ns.Session.Active() and ns.Session.Template().key == key
end
local function ownNo(t)
    return tonumber(tostring(t.key or ""):match("%d+$")) or 0
end
local function older(a, b)
    local ma, mb = a.made or 0, b.made or 0
    if ma ~= mb then return ma < mb end
    local na, nb = ownNo(a), ownNo(b)
    if na ~= nb then return na < nb end
    return tostring(a.key) < tostring(b.key)
end
function T.List()
    local out = {}
    for _, t in ipairs(ns.TEMPLATES) do out[#out + 1] = T.Get(t.key) end
    local extra = {}
    for key, t in pairs(store()) do
        if not ns.TEMPLATE[key] then extra[#extra + 1] = t end
    end
    table.sort(extra, older)
    for _, t in ipairs(extra) do out[#out + 1] = t end
    return out
end
function T.NameTaken(name, except)
    for _, t in ipairs(T.List()) do
        if t.key ~= except and T.Name(t) == name then return true end
    end
    return false
end
local function freeName(base)
    base = T.Clean(base)
    local name, n = base, 2
    while T.NameTaken(name) do
        local tail = " " .. n
        name = T.Clean(base, T.NAME_MAX - #tail) .. tail
        n = n + 1
    end
    return name
end
function T.Edit(key)
    local s = store()
    if s[key] then return s[key] end
    local f = ns.TEMPLATE[key]
    if not f then return nil end
    s[key] = { key = key, label = f.label, size = f.size, slots = copySlots(f.slots), base = key }
    return s[key]
end
local function editable(key)
    if T.Locked(key) then return nil end
    return T.Edit(key)
end
local function slotOf(key, i)
    local t = T.Get(key)
    return t and i and t.slots[i]
end
function T.Reset(key)
    if not T.IsFactory(key) or not T.IsCustom(key) or T.Locked(key) then return end
    store()[key] = nil
    ns.Session.Invalidate()
    ns.Session.Changed()
end
local function copyTexts(list)
    if not list then return nil end
    local out = {}
    for i, t in ipairs(list) do out[i] = { name = t.name, body = t.body } end
    return out
end
function T.Copy(key)
    local src = T.Get(key)
    if not src then return end
    local n = 1
    local newKey
    repeat
        newKey = "own" .. n
        n = n + 1
    until not T.Exists(newKey)
    store()[newKey] = { key = newKey, name = freeName(ns.T("tplCopyName", T.Name(src))), size = src.size,
        slots = copySlots(src.slots), made = time(), base = src.base or (T.IsFactory(key) and key or nil) }
    local db = ns.Store.DB()
    if db.texts then db.texts[newKey] = copyTexts(db.texts[key]) end
    if db.bober then db.bober[newKey] = db.bober[key] end
    ns.Session.Changed()
    return newKey
end
function T.Delete(key)
    if T.IsFactory(key) or T.Locked(key) or not store()[key] then return end
    store()[key] = nil
    local db = ns.Store.DB()
    if db.texts then db.texts[key] = nil end
    if db.bober then db.bober[key] = nil end
    ns.Session.Invalidate()
    ns.Session.Changed()
end
function T.Rename(key, name)
    if T.IsFactory(key) then return false end
    local t = store()[key]
    if not t then return false end
    name = T.Clean(name)
    if name == "" or name == t.name or T.NameTaken(name, key) then return false end
    t.name = name
    ns.Session.Changed()
    return true
end
function T.SetSize(key, size)
    size = tonumber(size)
    local cur = T.Get(key)
    if not cur or (size ~= 10 and size ~= 25) or cur.size == size then return end
    local t = editable(key)
    if t then
        t.size = size
        ns.Session.Invalidate()
        ns.Session.Changed()
    end
end
function T.AddSlot(key, after, role)
    local t = editable(key)
    if not t then return end
    local n = #t.slots
    local pos = math.min(math.max(tonumber(after) or n, 0), n) + 1
    table.insert(t.slots, pos, { role = ns.ROLE_GROUP[role] and role or "dd" })
    ns.Session.Changed()
    return pos
end
function T.RemoveSlot(key, i)
    if not slotOf(key, i) then return end
    local t = editable(key)
    if not t then return end
    table.remove(t.slots, i)
    ns.Session.Changed()
end
function T.SetRole(key, i, role)
    local was = slotOf(key, i)
    if not was or not ns.ROLE_GROUP[role] or was.role == role then return end
    local t = editable(key)
    if not t then return end
    local s = t.slots[i]
    s.role = role
    if s.specs then
        local keep = {}
        for _, k in ipairs(s.specs) do
            if T.SpecFits(role, k) then keep[#keep + 1] = k end
        end
        s.specs = #keep > 0 and keep or nil
    end
    ns.Session.Changed()
end
function T.SetCap(key, i, cap)
    local was = slotOf(key, i)
    if not was then return end
    cap = T.Clean(cap)
    if cap == "" then cap = nil end
    if was.cap == cap then return end
    local t = editable(key)
    if not t then return end
    t.slots[i].cap = cap
    ns.Session.Changed()
end
function T.SetMark(key, i, mark)
    mark = tonumber(mark)
    if mark and (mark < 1 or mark > 8 or mark ~= math.floor(mark)) then mark = nil end
    local was = slotOf(key, i)
    if not was or was.mark == mark then return end
    local t = T.Edit(key)
    t.slots[i].mark = mark
    ns.Session.Changed()
end
function T.MarkSlots(key, mark)
    local out = {}
    local t = T.Get(key)
    if not t or not mark then return out end
    for i, s in ipairs(t.slots) do
        if s.mark == mark then out[#out + 1] = i end
    end
    return out
end
function T.ToggleSpec(key, i, spec, on)
    local was = slotOf(key, i)
    if not was or (on and not T.SpecFits(was.role, spec)) then return end
    local has = false
    for _, k in ipairs(was.specs or {}) do
        if k == spec then has = true end
    end
    if has == (on and true or false) then return end
    local t = editable(key)
    if not t then return end
    local s = t.slots[i]
    local out = {}
    for _, k in ipairs(s.specs or {}) do
        if k ~= spec then out[#out + 1] = k end
    end
    if on then out[#out + 1] = spec end
    s.specs = #out > 0 and out or nil
    ns.Session.Changed()
end
function T.SpecFits(role, spec)
    local r = ns.SPEC[spec] and ns.SPEC[spec].role
    if not r then return false end
    if role == "hybrid" then return true end
    if role == "dd" then return r == "melee" or r == "ranged" end
    return r == role
end
