local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local B = {}
ns.Buffs = B
local TREES = 3
local TREE_OF, KEY_OF = {}, {}
for _, cls in ipairs(ns.CLASSES) do
    KEY_OF[cls.token] = {}
    for _, sp in ipairs(cls.specs) do
        if sp.tree then
            TREE_OF[sp.key] = sp.tree
            KEY_OF[cls.token][sp.tree] = KEY_OF[cls.token][sp.tree] or sp.key
        end
    end
end
function B.OwnTree()
    local group = GetActiveTalentGroup and GetActiveTalentGroup(false, false) or nil
    local best, top = nil, 0
    for t = 1, TREES do
        local _, _, pts = GetTalentTabInfo(t, false, false, group)
        pts = tonumber(pts) or 0
        if pts > top then best, top = t, pts end
    end
    return best
end
function B.Who(m)
    local p = ns.Store.DB().players[m.name]
    local tree
    if m.name == UnitName("player") then
        tree = B.OwnTree()
    elseif root.Specs and root.Specs.Of then
        tree = root.Specs.Of(m.name)
    end
    tree = tree or (p and p.tree) or (p and p.spec and TREE_OF[p.spec]) or nil
    local key = p and p.spec
    if not key and tree then key = KEY_OF[m.class or ""] and KEY_OF[m.class][tree] end
    return key, tree
end
function B.Members()
    local out = {}
    for _, m in ipairs(ns.Session.Roster()) do
        if m.work and m.name and m.class then
            local key, tree = B.Who(m)
            out[#out + 1] = { name = m.name, class = m.class, key = key, tree = tree, online = m.online }
        end
    end
    return out
end
function B.SpellOf(src)
    if src.ally and UnitFactionGroup and UnitFactionGroup("player") == "Alliance" then return src.ally end
    return src.id
end
local function fits(src, m)
    if m.class ~= src.cls then return false end
    if not src.tree then return true end
    if m.tree == nil then return nil end
    return m.tree == src.tree
end
function B.Item(def, list)
    local it = { def = def, have = 0, src = {}, unsure = {}, pals = 0 }
    local got, maybe = {}, {}
    for k, src in ipairs(def.src) do
        local who = {}
        for _, m in ipairs(list) do
            local f = fits(src, m)
            if f then
                who[#who + 1] = m
                got[m.name] = true
            elseif f == nil then
                maybe[m.name] = m
            end
        end
        it.src[k] = { def = src, who = who }
    end
    for name in pairs(got) do
        it.have = it.have + 1
        maybe[name] = nil
    end
    for _, m in ipairs(list) do
        if maybe[m.name] then it.unsure[#it.unsure + 1] = m end
        if def.bless and m.class == "PALADIN" then it.pals = it.pals + 1 end
    end
    return it
end
function B.Rows(list)
    list = list or B.Members()
    local out = {}
    for r, row in ipairs(ns.BUFF_ROWS) do
        local items = {}
        for k, def in ipairs(row.items) do items[k] = B.Item(def, list) end
        out[r] = { key = row.key, items = items }
    end
    return out
end
local function reqKey(slot)
    local specs = {}
    for k, s in ipairs(slot.specs or {}) do specs[k] = s end
    table.sort(specs)
    return slot.role .. ":" .. table.concat(specs, ",")
end
function B.Comp(list)
    list = list or B.Members()
    local S = ns.Session
    local tpl = S.Template()
    local reqs, byKey, missing = {}, {}, 0
    for i, slot in ipairs(tpl.slots) do
        local k = reqKey(slot)
        local r = byKey[k]
        if not r then
            r = { role = slot.role, specs = slot.specs, need = 0, have = 0, who = {} }
            byKey[k] = r
            reqs[#reqs + 1] = r
        end
        r.need = r.need + 1
        if S.SlotTaken(i) then
            r.have = r.have + 1
            r.who[#r.who + 1] = S.SlotPlayer(i)
        else
            missing = missing + 1
        end
    end
    local counts, unknown = {}, {}
    for _, m in ipairs(list) do
        if m.key then
            local c = counts[m.key]
            if not c then
                c = { key = m.key, who = {} }
                counts[m.key] = c
            end
            c.who[#c.who + 1] = m
        else
            unknown[#unknown + 1] = m
        end
    end
    local specs = {}
    for _, cls in ipairs(ns.CLASSES) do
        for _, sp in ipairs(cls.specs) do
            if counts[sp.key] then specs[#specs + 1] = counts[sp.key] end
        end
    end
    return { reqs = reqs, missing = missing, specs = specs, unknown = unknown, total = #list }
end
