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
function B.Needs(class, tree)
    local t = ns.READY_NEED[class]
    if not t then return {} end
    if tree and t[tree] then return t[tree] end
    local out = {}
    for flag in pairs(t[1]) do
        local all = true
        for i = 2, #t do
            if not t[i][flag] then all = false end
        end
        if all then out[flag] = true end
    end
    return out
end
function B.Item(def, list)
    local it = { def = def, have = 0, src = {}, unsure = {}, party = true }
    local got, maybe = {}, {}
    for k, src in ipairs(def.src) do
        local who = {}
        for _, m in ipairs(list) do
            local f = fits(src, m)
            if f then
                who[#who + 1] = m
                got[m.name] = true
                if not src.bless then
                    it.other = true
                    if not src.party then it.party = false end
                end
            elseif f == nil then
                maybe[m.name] = m
            end
        end
        it.src[k] = { def = src, who = who }
        if src.bless then it.blessable = true end
    end
    for name in pairs(got) do
        it.have = it.have + 1
        maybe[name] = nil
    end
    for _, m in ipairs(list) do
        if maybe[m.name] then it.unsure[#it.unsure + 1] = m end
    end
    if not it.other then it.party = false end
    return it
end
local PAL = "PALADIN"
local function bless(byKey, list)
    local pals, sanct = 0, false
    for _, m in ipairs(list) do
        if m.class == PAL then
            pals = pals + 1
            if m.tree == 2 then sanct = true end
        end
    end
    for _, it in pairs(byKey) do
        it.pals, it.need, it.got = pals, 0, 0
    end
    for _, m in ipairs(list) do
        local need = B.Needs(m.class, m.tree)
        local kind = need.phys and (need.mana and "hybrid" or "phys") or "caster"
        local left = pals
        for _, key in ipairs(ns.BLESS_ORDER[kind]) do
            local it = byKey[key]
            if it then
                it.need = it.need + 1
                if it.other then
                    it.got = it.got + 1
                elseif left > 0 and (key ~= "damageTaken" or sanct) then
                    left = left - 1
                    it.got = it.got + 1
                end
            end
        end
    end
end
function B.State(it)
    if it.other then return "full" end
    if it.blessable and it.pals and it.pals > 0 and it.need > 0 then
        if it.got >= it.need then return "full" end
        if it.got > 0 then return "part" end
    elseif it.have > 0 then
        return "full"
    end
    if #it.unsure > 0 then return "unsure" end
    return "none"
end
function B.Rows(list)
    list = list or B.Members()
    local out, byKey = {}, {}
    for r, row in ipairs(ns.BUFF_ROWS) do
        local items = {}
        for k, def in ipairs(row.items) do
            local it = B.Item(def, list)
            it.row = row.key
            items[k] = it
            if it.blessable then byKey[def.key] = it end
        end
        out[r] = { key = row.key, items = items }
    end
    bless(byKey, list)
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
