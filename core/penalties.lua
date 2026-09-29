local _, ns = ...
local floor = math.floor
local tsort = table.sort
local tinsert = table.insert
local DEFAULT = "spartans"
local HIT_GAP = 2
local DEATH_WINDOW = 6
local MELEE_SHARE = 0.15
local MELEE_CLASS = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, PALADIN = true }
local RANGED_CLASS = { HUNTER = true, MAGE = true, WARLOCK = true, PRIEST = true }
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local ICONS = {
    mcweapon = "Interface\\Icons\\INV_Sword_04",
    mindmg = "Interface\\Icons\\Ability_Warrior_BattleShout",
    mindps = "Interface\\Icons\\Ability_Warrior_BattleShout",
    manual = "Interface\\Icons\\INV_Misc_Note_02",
}
local FIELDS = { on = true, mode = true, gp = true, wipe = true, step = true, reason = true }
local Penalties = {}
ns.Penalties = Penalties
local function Store()
    return ns.GetDB().gp
end
function Penalties.FightKey(fight)
    return string.format("%s|%d", fight.boss, floor(fight.from))
end
function Penalties.Active()
    local name = Store().preset
    if ns.penaltyPresets[name] or Store().own[name] then return name end
    return DEFAULT
end
function Penalties.IsOwn(name)
    return Store().own[name] ~= nil
end
function Penalties.Names()
    local out = {}
    for name in pairs(ns.penaltyPresets) do out[#out + 1] = name end
    for name in pairs(Store().own) do out[#out + 1] = name end
    tsort(out)
    return out
end
function Penalties.Label(name)
    local p = ns.penaltyPresets[name]
    return p and p.name or name
end
function Penalties.BaseOf(name)
    local own = Store().own[name]
    return own and own.base or nil
end
function Penalties.Select(name)
    if ns.penaltyPresets[name] or Store().own[name] then Store().preset = name end
end
function Penalties.Clean(name)
    local s = tostring(name or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end
local function UpperA(b)
    return "\208" .. string.char(b:byte() + 32)
end
local function UpperR(b)
    return "\209" .. string.char(b:byte() - 32)
end
local function Lower(s)
    s = s:lower():gsub("\208\129", "\209\145"):gsub("\208([\144-\159])", UpperA):gsub("\208([\160-\175])", UpperR)
    return s
end
function Penalties.Taken(name, except)
    local want = Lower(name)
    for key, p in pairs(ns.penaltyPresets) do
        if Lower(key) == want or Lower(p.name or key) == want then return true end
    end
    for own in pairs(Store().own) do
        if own ~= except and Lower(own) == want then return true end
    end
    return false
end
local function Dup(t)
    local c = {}
    for f, v in pairs(t) do c[f] = v end
    return c
end
function Penalties.Copy(name)
    name = Penalties.Clean(name)
    if name == "" or Penalties.Taken(name) then return false end
    local active = Penalties.Active()
    local own = Store().own[active]
    local copy = { base = own and own.base or active, rules = {}, extra = {} }
    if own then
        for key, over in pairs(own.rules) do
            local c = Dup(over)
            if next(c) then copy.rules[key] = c end
        end
        for i = 1, #(own.extra or {}) do copy.extra[i] = Dup(own.extra[i]) end
    end
    Store().own[name] = copy
    Store().preset = name
    return true
end
function Penalties.Rename(old, name)
    name = Penalties.Clean(name)
    local own = Store().own[old]
    if not own or name == "" or name == old or Penalties.Taken(name, old) then return false end
    Store().own[old] = nil
    Store().own[name] = own
    if Store().preset == old then Store().preset = name end
    return true
end
function Penalties.Delete(name)
    if not Store().own[name] then return false end
    Store().own[name] = nil
    if Store().preset == name then Store().preset = DEFAULT end
    return true
end
local function Merge(base, over)
    local r = setmetatable({}, { __index = base })
    r.on = base.on ~= false
    if over then
        for f, v in pairs(over) do r[f] = v end
    end
    return r
end
local function Insert(list, rule)
    local at
    for i = 1, #list do
        if list[i].boss == rule.boss then at = i end
    end
    if at then tinsert(list, at + 1, rule) else list[#list + 1] = rule end
end
local function Extra(x, from)
    local r = setmetatable({}, { __index = x })
    r.kind = "manual"
    r.text = x.reason
    r.custom = from
    r.on = x.on ~= false
    return r
end
local baseOver, baseRules
local function BaseRules(name)
    local preset = ns.penaltyPresets[name] or ns.penaltyPresets[DEFAULT]
    if preset ~= ns.penaltyPresets[DEFAULT] then return preset.rules end
    local over = ns.GPGuild and ns.GPGuild.Overlay()
    if not over then return preset.rules end
    if baseOver == over then return baseRules end
    local out = {}
    for i = 1, #preset.rules do
        local base = preset.rules[i]
        out[i] = over.rules[base.key] and Merge(base, over.rules[base.key]) or base
    end
    for i = 1, #over.extra do Insert(out, Extra(over.extra[i], "guild")) end
    baseOver, baseRules = over, out
    return out
end
local function OwnExtra(own, key)
    local list = own and own.extra
    if not list then return nil end
    for i = 1, #list do
        if list[i].key == key then return list[i], i end
    end
    return nil
end
function Penalties.All()
    local active = Penalties.Active()
    local own = Store().own[active]
    local rules = BaseRules(own and own.base or active)
    local out = {}
    for i = 1, #rules do
        local base = rules[i]
        out[i] = Merge(base, own and own.rules[base.key])
    end
    if own and own.extra then
        for i = 1, #own.extra do Insert(out, Extra(own.extra[i], "own")) end
    end
    return out
end
local function Was(rule, field)
    if field == "on" then return rule.on ~= false end
    if field == "mode" then return rule.mode or "each" end
    return rule[field]
end
local function Find(rules, key)
    for i = 1, #rules do
        if rules[i].key == key then return rules[i] end
    end
    return nil
end
function Penalties.Set(key, field, value)
    local own = Store().own[Penalties.Active()]
    if not own or not FIELDS[field] then return false end
    if field == "reason" then value = ns.GPGuild and ns.GPGuild.Text(value) or Penalties.Clean(value) end
    local x = OwnExtra(own, key)
    if x then
        if field == "on" then value = value and true or false end
        if (field == "gp" or field == "reason") and (value == nil or value == "") then return false end
        x[field] = value
        return true
    end
    local base = Find(BaseRules(own.base), key)
    if not base then return false end
    local was = Was(base, field)
    if field == "reason" and value == "" then value = nil end
    local over = own.rules[key] or {}
    if value == was then value = nil end
    over[field] = value
    own.rules[key] = next(over) and over or nil
    return true
end
function Penalties.IsChanged(key)
    local own = Store().own[Penalties.Active()]
    return own ~= nil and own.rules[key] ~= nil and next(own.rules[key]) ~= nil
end
function Penalties.IsOwnRule(key)
    return OwnExtra(Store().own[Penalties.Active()], key) ~= nil
end
function Penalties.AddRule(boss)
    local own = Store().own[Penalties.Active()]
    if not own or type(boss) ~= "string" or boss == "" then return nil end
    own.extra = own.extra or {}
    local n, key = 0, nil
    repeat
        n = n + 1
        key = string.format("x.%d.%d", time(), n)
    until not OwnExtra(own, key) and not Find(BaseRules(own.base), key)
    own.extra[#own.extra + 1] = { key = key, boss = boss, gp = 200, reason = ns.T("gpset.newrule") }
    return key
end
function Penalties.RemoveRule(key)
    local own = Store().own[Penalties.Active()]
    local _, i = OwnExtra(own, key)
    if not i then return false end
    table.remove(own.extra, i)
    return true
end
function Penalties.Prune(name)
    local own = Store().own[name]
    if not own then return end
    local rules = BaseRules(own.base)
    for key, over in pairs(own.rules) do
        local base = Find(rules, key)
        if base then
            for f, v in pairs(over) do
                if Was(base, f) == v then over[f] = nil end
            end
            if not next(over) then own.rules[key] = nil end
        end
    end
    local list = own.extra or {}
    for i = #list, 1, -1 do
        if Find(rules, list[i].key) then table.remove(list, i) end
    end
end
function Penalties.EpgpReason()
    local r = Store().epgpReason
    if type(r) ~= "string" then return ns.T("gp.epgp.default") end
    return r
end
function Penalties.SetEpgpReason(text)
    Store().epgpReason = Penalties.Clean(text)
end
function Penalties.Reset(key)
    local own = Store().own[Penalties.Active()]
    if not own or not own.rules[key] then return false end
    own.rules[key] = nil
    return true
end
local function ForBoss(rule, boss)
    return rule.boss == boss or rule.boss == ns.penaltyAny
end
function Penalties.Rules(boss)
    local out = {}
    local all = Penalties.All()
    for i = 1, #all do
        local r = all[i]
        if r.on and ForBoss(r, boss) then out[#out + 1] = r end
    end
    return out
end
local function Fill(set, list)
    if not list then return end
    for i = 1, #list do set[list[i]] = true end
end
function Penalties.Watch(boss)
    local w = { hit = {}, mc = {}, targets = {}, casts = {}, npcs = {}, deaths = {} }
    for _, preset in pairs(ns.penaltyPresets) do
        for i = 1, #preset.rules do
            local r = preset.rules[i]
            if ForBoss(r, boss) then
                if r.kind == "hit" then Fill(w.hit, r.spells) end
                if r.kind == "death" then w.deaths[#w.deaths + 1] = r end
                if r.kind == "mccast" then Fill(w.mc, r.spells) end
                if r.kind == "mcweapon" and not w.ctl then w.ctl = r end
                if r.kind == "mindmg" then Fill(w.targets, r.targets) end
                if r.kind == "chased" and r.npc then w.npcs[r.npc] = true end
                if r.kind == "expect" and r.by then
                    for _, b in pairs(r.by) do
                        if b.spell then w.casts[b.spell] = true end
                    end
                end
            end
        end
    end
    return w
end
local function Episodes(times, gap)
    tsort(times)
    local out, last = {}, nil
    for i = 1, #times do
        if not last or times[i] - last > gap then out[#out + 1] = times[i] end
        last = times[i]
    end
    return out
end
local function AsSet(set, list)
    set = set or {}
    Fill(set, list)
    return set
end
local function Applies(rule, fight)
    local raid = fight.raid
    if rule.size and not (raid and raid.size == rule.size) then return false end
    if rule.heroic and raid and raid.heroic == false then return false end
    return true
end
function Penalties.Applies(rule, fight)
    return Applies(rule, fight)
end
local function DeathMatch(rule, d)
    local spells = AsSet(nil, rule.spells)
    local srcs = AsSet(nil, rule.srcs)
    local k = d.killer
    if k and ((k.spell and spells[k.spell]) or (k.src and srcs[k.src])) then return true end
    if rule.ticks and rule.spells then
        local window, n = rule.window or DEATH_WINDOW, 0
        for i = 1, #d.recent do
            local e = d.recent[i]
            if d.t - e.t <= window and spells[e.spell] then n = n + 1 end
        end
        return n >= rule.ticks
    end
    return false
end
Penalties.DeathMatch = DeathMatch
local function Cleansed(p, spell)
    local n = 0
    for _, d in pairs(p.disp) do
        for _, w in pairs(d.what) do
            if not w.purge and (not spell or w.name == spell) then n = n + w.n end
        end
    end
    return n
end
function Penalties.DutyCount(rule, p, fight)
    local duty = rule.by and p.class and rule.by[p.class]
    if not duty or not Applies(rule, fight) then return nil end
    if rule.what == "dispel" then return Cleansed(p, rule.removes) end
    return p.casts[duty.spell] or 0
end
function Penalties.Duties(s, fight, p)
    local out = {}
    local rules = Penalties.Rules(fight.boss)
    for i = 1, #rules do
        local r = rules[i]
        if r.kind == "expect" then
            local n = Penalties.DutyCount(r, p, fight)
            if n then
                out[#out + 1] = { rule = r, n = n, need = r.min or 1, id = r.by[p.class].id }
            end
        end
    end
    return out
end
local function IsMelee(p)
    if p.class and MELEE_CLASS[p.class] then return true end
    if p.class and RANGED_CLASS[p.class] then return false end
    return p.dmg > 0 and p.swingDmg / p.dmg >= MELEE_SHARE
end
local function Detect(rule, p, s, fight)
    local out = {}
    local kind = rule.kind
    if rule.wipeOnly and fight.killed then return out end
    if kind == "death" or kind == "anydeath" then
        local n = #p.deathInfo
        if kind == "anydeath" and not fight.killed then n = n - 1 end
        for i = 1, n do
            local d = p.deathInfo[i]
            if not d.tail and (kind == "anydeath" or (not d.nogp and DeathMatch(rule, d))) then
                out[#out + 1] = { t = d.t }
            end
        end
    elseif kind == "killer" then
        local spells = AsSet(nil, rule.spells)
        for i = 1, #s.players do
            local other = s.players[i]
            for k = 1, #other.deathInfo do
                local d = other.deathInfo[k]
                local killer = d.killer
                if killer and killer.src == p.name and other.name ~= p.name and spells[killer.spell] then
                    out[#out + 1] = { t = d.t, victim = other.name }
                end
            end
        end
        tsort(out, function(a, b) return a.t < b.t end)
    elseif kind == "hit" then
        local times = {}
        for i = 1, #(rule.spells or {}) do
            local list = p.hits[rule.spells[i]]
            if list then
                for k = 1, #list do times[#times + 1] = list[k] end
            end
        end
        local ep = Episodes(times, rule.gap or HIT_GAP)
        for i = 1, #ep do out[i] = { t = ep[i] } end
    elseif kind == "chased" then
        local list = p.chased[rule.npc] or {}
        for i = 1, #list do out[i] = { t = list[i] } end
    elseif kind == "mccast" then
        local spells = AsSet(nil, rule.spells)
        for i = 1, #p.mcCasts do
            local c = p.mcCasts[i]
            if spells[c.spell] then out[#out + 1] = { t = c.t, note = c.spell } end
        end
    elseif kind == "expect" then
        local n = Penalties.DutyCount(rule, p, fight)
        if n and n < (rule.min or 1) then out[1] = { t = nil, missing = true, have = n } end
    elseif kind == "mcweapon" then
        for i = 1, #(p.ctl or {}) do
            local c = p.ctl[i]
            if c.verdict == "red" then out[#out + 1] = { t = c.t, ctl = c } end
        end
    elseif kind == "mindmg" then
        if p.role == "dps" then
            local sum = 0
            for i = 1, #(rule.targets or {}) do sum = sum + (p.targetDmg[rule.targets[i]] or 0) end
            local melee = IsMelee(p)
            local need = melee and rule.melee or rule.ranged
            if need and sum < need then out[1] = { t = nil, amount = sum, need = need, melee = melee } end
        end
    elseif kind == "mindps" then
        if p.role == "dps" and Applies(rule, fight) then
            local dps = p.dmg / (s.combat or s.dur)
            if dps < (rule.dps or 0) then out[1] = { t = nil, amount = dps, need = rule.dps } end
        end
    end
    return out
end
local function RuleIcon(rule, s, p)
    if rule.kind == "death" or rule.kind == "anydeath" then return SKULL end
    if rule.kind == "killer" and rule.spells then
        return s.spellIds[rule.spells[1]] or 71340
    end
    if rule.kind == "expect" then
        local duty = rule.by and p and rule.by[p.class]
        return duty and duty.id or ICONS.manual
    end
    if rule.kind == "chased" then return s.spellIds[rule.npc] or ICONS.manual end
    if rule.spells then
        for i = 1, #rule.spells do
            local id = s.spellIds[rule.spells[i]]
            if id then return id end
        end
    end
    return ICONS[rule.kind] or ICONS.manual
end
local function Manual(fight)
    local byFight = Store().manual[Penalties.FightKey(fight)]
    return byFight or {}
end
function Penalties.Evaluate(s, fight)
    local rules = Penalties.Rules(fight.boss)
    local fk = Penalties.FightKey(fight)
    local bump = Store().bump
    local manual = Manual(fight)
    local out, totals = {}, {}
    for r = 1, #rules do
        local rule = rules[r]
        local first
        local hits = {}
        for i = 1, #s.players do
            local p = s.players[i]
            local found = Detect(rule, p, s, fight)
            local extra = manual[p.name]
            if extra then
                for k = 1, #extra do
                    if extra[k] == rule.key then found[#found + 1] = { t = nil, manual = true } end
                end
            end
            if #found > 0 then
                if rule.mode == "once" then found = { found[1] } end
                local events = {}
                for k = 1, #found do
                    local f = found[k]
                    local gp = rule.gp or 0
                    if rule.mode == "grow" then gp = gp + (rule.step or 0) * (k - 1) end
                    local key = table.concat({ fk, p.name, rule.key, k }, "|")
                    local bumped = bump[key] == true and rule.wipe ~= nil
                    if bumped then gp = rule.wipe end
                    events[k] = { key = key, t = f.t, gp = gp, bumped = bumped, info = f }
                    if rule.firstGp and f.t and (not first or f.t < first.t) then first = events[k] end
                end
                hits[#hits + 1] = { p = p, hit = { rule = rule, events = events, icon = RuleIcon(rule, s, p) } }
            end
        end
        if first and not first.bumped then first.gp = rule.firstGp end
        for i = 1, #hits do
            local name = hits[i].p.name
            out[name] = out[name] or {}
            local list = out[name]
            list[#list + 1] = hits[i].hit
        end
    end
    for name, list in pairs(out) do
        local sum = 0
        for i = 1, #list do
            for k = 1, #list[i].events do sum = sum + list[i].events[k].gp end
        end
        totals[name] = sum
    end
    return out, totals
end
function Penalties.Choices(boss)
    return Penalties.Rules(boss)
end
function Penalties.AddManual(fight, name, key)
    local fk = Penalties.FightKey(fight)
    local byFight = Store().manual[fk] or {}
    Store().manual[fk] = byFight
    byFight[name] = byFight[name] or {}
    local list = byFight[name]
    list[#list + 1] = key
end
function Penalties.RemoveManual(fight, name, key, eventKey)
    local fk = Penalties.FightKey(fight)
    local list = Store().manual[fk] and Store().manual[fk][name]
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == key then
            table.remove(list, i)
            if eventKey then Store().bump[eventKey] = nil end
            if #list == 0 then Store().manual[fk][name] = nil end
            if not next(Store().manual[fk]) then Store().manual[fk] = nil end
            return true
        end
    end
    return false
end
function Penalties.Bump(key)
    Store().bump[key] = true
end
function Penalties.Reason(rule)
    if type(rule.reason) == "string" and rule.reason ~= "" then return rule.reason end
    return ns.T(rule.text)
end
