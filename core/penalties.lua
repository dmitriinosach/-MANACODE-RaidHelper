local _, ns = ...
local floor = math.floor
local format = string.format
local concat = table.concat
local tremove = table.remove
local tsort = table.sort
local DEFAULT = "spartans"
local HIT_GAP = 2
local DEATH_WINDOW = 6
local MELEE_SHARE = 0.15
local MAX_SHORT = 64
local MELEE_CLASS = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, PALADIN = true }
local RANGED_CLASS = { HUNTER = true, MAGE = true, WARLOCK = true, PRIEST = true }
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local ICONS = {
    mcweapon = "Interface\\Icons\\INV_Sword_04",
    mindmg = "Interface\\Icons\\Ability_Warrior_BattleShout",
    mindps = "Interface\\Icons\\Ability_Warrior_BattleShout",
    manual = "Interface\\Icons\\INV_Misc_Note_02",
}
local SYS = {
    gp = { sum = "gp", wipe = "wipe", step = "step" },
    ep = { sum = "ep", wipe = "epwipe", step = "epstep" },
    dkp = { sum = "dkp", wipe = "dkpwipe", step = "dkpstep" },
}
local NUMS = { gp = true, wipe = true, step = true, ep = true, epwipe = true, epstep = true, dkp = true,
    dkpwipe = true, dkpstep = true }
local FIELDS = { on = true, mode = true, short = true }
for f in pairs(NUMS) do FIELDS[f] = true end
local MODES = { once = true, each = true, grow = true }
local Penalties = {}
ns.Penalties = Penalties
Penalties.SYS = SYS
Penalties.NUMS = NUMS
local function Store()
    return ns.GetDB().gp
end
local NONE = {}
local function Mine()
    local f = ns.GetDB().faults
    return f and f.rules or NONE
end
function Penalties.FightKey(fight)
    return string.format("%s|%d", fight.boss, floor(fight.from))
end
function Penalties.Label()
    local p = ns.penaltyPresets[DEFAULT]
    return p and p.name or DEFAULT
end
function Penalties.Clean(name)
    local s = tostring(name or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end
local function Merge(base, over)
    local r = setmetatable({}, { __index = base })
    r.on = base.on ~= false
    if over then
        for f, v in pairs(over) do r[f] = v end
    end
    return r
end
local baseOver, baseRules
local function BaseRules()
    local preset = ns.penaltyPresets[DEFAULT]
    local over = ns.GPGuild and ns.GPGuild.Overlay()
    if not over then return preset.rules end
    if baseOver == over then return baseRules end
    local out = {}
    for i = 1, #preset.rules do
        local base = preset.rules[i]
        out[i] = over.rules[base.key] and Merge(base, over.rules[base.key]) or base
    end
    baseOver, baseRules = over, out
    return out
end
function Penalties.All()
    local rules = BaseRules()
    local mine = Mine()
    local out = {}
    for i = 1, #rules do out[i] = Merge(rules[i], mine[rules[i].key]) end
    return out
end
function Penalties.Amount(rule, sys, what)
    local f = SYS[sys or "gp"] or SYS.gp
    what = what or "sum"
    local v = rule[f[what]]
    if v == nil and f ~= SYS.gp then v = rule[SYS.gp[what]] end
    return v
end
function Penalties.Reason(rule)
    return ns.T(rule.text)
end
function Penalties.Short(rule)
    if type(rule.short) == "string" and rule.short ~= "" then return rule.short end
    return ns.L["sum.p." .. rule.key .. ".s"] or Penalties.Reason(rule)
end
local function ShortText(s)
    if ns.GPGuild then return ns.GPGuild.Text(s, MAX_SHORT) end
    return Penalties.Clean(s):sub(1, MAX_SHORT)
end
local ALT = {}
for sys, f in pairs(SYS) do
    if sys ~= "gp" then
        for what, name in pairs(f) do ALT[name] = SYS.gp[what] end
    end
end
local function Was(rule, field, over)
    if field == "on" then return rule.on ~= false end
    if field == "mode" then return rule.mode or "each" end
    if field == "short" then return Penalties.Short(rule) end
    local alt = ALT[field]
    if alt and rule[field] == nil then
        local v = over and over[alt]
        if v == nil then v = rule[alt] end
        return v
    end
    return rule[field]
end
local function Find(rules, key)
    for i = 1, #rules do
        if rules[i].key == key then return rules[i] end
    end
    return nil
end
function Penalties.Set(key, field, value)
    if not FIELDS[field] then return false end
    local base = Find(BaseRules(), key)
    if not base then return false end
    if field == "on" then value = value and true or false end
    if field == "mode" and not MODES[value] then return false end
    if field == "short" then
        value = ShortText(value)
        if value == "" then value = nil end
    end
    if NUMS[field] and value ~= nil then
        if type(value) ~= "number" then return false end
        value = math.max(0, floor(value + 0.5))
    end
    local mine = Mine()
    if mine == NONE then return false end
    local over = mine[key] or {}
    if value ~= nil and value == Was(base, field, over) then value = nil end
    over[field] = value
    mine[key] = next(over) and over or nil
    return true
end
function Penalties.IsChanged(key)
    local over = Mine()[key]
    return over ~= nil and next(over) ~= nil
end
function Penalties.Changed()
    local n = 0
    for _, over in pairs(Mine()) do
        if next(over) then n = n + 1 end
    end
    return n
end
function Penalties.Reset(key)
    local mine = Mine()
    if not mine[key] then return false end
    mine[key] = nil
    return true
end
function Penalties.ResetAll()
    local mine = Mine()
    for key in pairs(mine) do mine[key] = nil end
end
function Penalties.Prune()
    local rules = BaseRules()
    local mine = Mine()
    for key, over in pairs(mine) do
        local base = Find(rules, key)
        if base then
            for f, v in pairs(over) do
                if Was(base, f, over) == v then over[f] = nil end
            end
        end
        if not base or not next(over) then mine[key] = nil end
    end
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
    for i = 1, #list do set[ns.SpellKey(list[i]) or list[i]] = true end
end
local function FillN(set, list)
    if not list then return end
    for i = 1, #list do set[ns.NpcKeyOf(list[i]) or list[i]] = true end
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
                if r.kind == "mindmg" then FillN(w.targets, r.targets) end
                if r.kind == "chased" and r.npc then w.npcs[ns.NpcKeyOf(r.npc)] = true end
                if r.kind == "expect" and r.by then
                    for _, b in pairs(r.by) do
                        if b.spell then w.casts[ns.SpellKey(b.spell)] = true end
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
    local srcs = {}
    FillN(srcs, rule.srcs)
    local k = d.killer
    if k and ((k.key and spells[k.key]) or (k.srcKey and srcs[k.srcKey])) then return true end
    if rule.ticks and rule.spells then
        local window, n = rule.window or DEATH_WINDOW, 0
        for i = 1, #d.recent do
            local e = d.recent[i]
            if d.t - e.t <= window and e.key and spells[e.key] then n = n + 1 end
        end
        return n >= rule.ticks
    end
    return false
end
Penalties.DeathMatch = DeathMatch
local function Cleansed(p, spell)
    local want = ns.SpellKey(spell)
    local n = 0
    for _, d in pairs(p.disp) do
        for _, w in pairs(d.what) do
            if not w.purge and (not want or ns.SpellKey(w.id) == want) then n = n + w.n end
        end
    end
    return n
end
function Penalties.DutyCount(rule, p, fight)
    local duty = rule.by and p.class and rule.by[p.class]
    if not duty or not Applies(rule, fight) then return nil end
    if rule.what == "dispel" then return Cleansed(p, rule.removes) end
    return p.casts[ns.SpellKey(duty.spell) or 0] or 0
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
function Penalties.Hangs(s, p, spell)
    local want = ns.SpellKey(spell)
    for i = 1, #(s.badges or {}) do
        local bd = s.badges[i]
        local st = bd.shed and ns.SpellKey(bd.spell) == want and p.badges and p.badges[i]
        local list = type(st) == "table" and st.hangs
        if list and #list > 0 then return list end
    end
    return nil
end
local function ShedOf(rule, s, p)
    if rule.kind ~= "hit" then return nil end
    local out
    for i = 1, #(rule.spells or {}) do
        local list = Penalties.Hangs(s, p, rule.spells[i])
        if list then
            out = out or {}
            out[#out + 1] = { spell = rule.spells[i], hangs = list }
        end
    end
    return out
end
function Penalties.ShedName(id)
    local key = ns.SpellKey(id)
    if not key then return tostring(id) end
    return rawget(ns.L, "sum.shed.by." .. key) or ns.SpellName(key)
end
function Penalties.ShedText(list, whole)
    local shed, full, by, seen, secs = 0, 0, {}, {}, {}
    for i = 1, #list do
        local h = list[i]
        if h.off == "shed" then
            shed = shed + 1
            local name = h.by and Penalties.ShedName(h.by)
            if name and not seen[name] then
                seen[name] = true
                by[#by + 1] = name
            end
        end
        local sec = tostring(floor((h.dur or 0) + 0.5))
        secs[i] = format(ns.T(h.off == "died" and "sum.shed.died" or "sum.shed.sec"), sec)
        if (h.full or 0) > full then full = h.full end
    end
    local last = tremove(secs)
    local held = #secs > 0 and format(ns.T("sum.shed.and"), concat(secs, ", "), last) or last
    local text = format(ns.T("sum.shed.text"), #list, shed, #by > 0 and format(" (%s)", concat(by, ", ")) or "",
        held)
    if whole and full > 0 then text = text .. format(ns.T("sum.shed.of"), full) end
    return text
end
function Penalties.CureText(list)
    local known, names, seen = false, {}, {}
    local defs = ns.defensives or {}
    for i = 1, #list do
        local cure = list[i].cure
        if cure then known = true end
        for k = 1, #(cure or {}) do
            local id = cure[k].left <= 0 and defs[cure[k].id] and cure[k].id
            local short = id and Penalties.ShedName(id)
            if short and not seen[short] then
                seen[short] = true
                names[#names + 1] = short
            end
        end
    end
    if #names > 0 then return format(ns.T("sum.shed.could"), concat(names, ", ")) end
    return known and ns.T("sum.shed.none") or nil
end
function Penalties.Grade(hit)
    for k = 1, #hit.events do
        if hit.events[k].grade ~= "yellow" then return "red" end
    end
    return #hit.events > 0 and "yellow" or "red"
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
            local theirs = d.why == "dep"
            if not d.tail and not theirs and (kind == "anydeath" or (not d.nogp and DeathMatch(rule, d))) then
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
                if killer and killer.src == p.name and other.name ~= p.name and killer.key and spells[killer.key] then
                    out[#out + 1] = { t = d.t, victim = other.name }
                end
            end
        end
        tsort(out, function(a, b) return a.t < b.t end)
    elseif kind == "caused" then
        local list = ns.DeathDeps and ns.DeathDeps.Caused(s, p, rule) or {}
        for i = 1, #list do out[i] = { t = list[i].t, victim = list[i].victim, dep = list[i].dep } end
    elseif kind == "hit" then
        local times = {}
        for i = 1, #(rule.spells or {}) do
            local list = p.hits[ns.SpellKey(rule.spells[i]) or 0]
            if list then
                for k = 1, #list do times[#times + 1] = list[k] end
            end
        end
        local ep = Episodes(times, rule.gap or HIT_GAP)
        for i = 1, #ep do out[i] = { t = ep[i] } end
        local sheds = ShedOf(rule, s, p)
        for i = 1, #(sheds or {}) do
            local list = sheds[i].hangs
            for k = 1, #list do
                if list[k].off == "shed" then
                    out[#out + 1] = { t = fight.from + list[k].t, grade = "yellow", hang = list[k] }
                end
            end
        end
        if sheds then tsort(out, function(a, b) return a.t < b.t end) end
    elseif kind == "chased" then
        local list = p.chased[ns.NpcKeyOf(rule.npc) or 0] or {}
        for i = 1, #list do
            if not (ns.Shades and ns.Shades.Excused(s, p, rule.npc, list[i] - fight.from)) then
                out[#out + 1] = { t = list[i] }
            end
        end
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
            for i = 1, #(rule.targets or {}) do sum = sum + (p.targetDmg[ns.NpcKeyOf(rule.targets[i])] or 0) end
            local melee = IsMelee(p)
            local need = melee and rule.melee or rule.ranged
            if need and sum < need then out[1] = { t = nil, amount = sum, need = need, melee = melee } end
        end
    elseif kind == "mindps" then
        if p.role == "dps" and Applies(rule, fight) then
            local dps = p.dmg / ns.Totals.Time(s)
            if dps < (rule.dps or 0) then out[1] = { t = nil, amount = dps, need = rule.dps } end
        end
    elseif kind == "earlypull" then
        local v = ns.PullTimer and ns.PullTimer.EarlyOf(s, p.name)
        if v then out[1] = { t = s.pull.t, grade = "yellow", early = v.early, sec = v.sec, setter = v.who } end
    end
    return out
end
local function RuleIcon(rule, s, p)
    if rule.kind == "death" or rule.kind == "anydeath" then return SKULL end
    if rule.kind == "killer" and rule.spells then
        return s.spellIds[ns.SpellKey(rule.spells[1])] or 71340
    end
    if rule.kind == "expect" then
        local duty = rule.by and p and rule.by[p.class]
        return duty and duty.id or ICONS.manual
    end
    if rule.kind == "chased" then return s.spellIds[ns.NpcKeyOf(rule.npc) or 0] or ICONS.manual end
    if rule.kind == "earlypull" then return ns.pullTimer and ns.pullTimer.icon or ICONS.manual end
    if rule.spells then
        for i = 1, #rule.spells do
            local id = s.spellIds[ns.SpellKey(rule.spells[i]) or 0]
            if id then return id end
        end
    end
    return ICONS[rule.kind] or ICONS.manual
end
local function Manual(fight)
    local byFight = Store().manual[Penalties.FightKey(fight)]
    return byFight or {}
end
local function OnceOf(found)
    for k = 1, #found do
        if found[k].grade ~= "yellow" then return found[k] end
    end
    return found[1]
end
function Penalties.Evaluate(s, fight, sys)
    sys = sys or (ns.Ledger and ns.Ledger.Key()) or "gp"
    local rules = Penalties.Rules(fight.boss)
    local fk = Penalties.FightKey(fight)
    local bump = Store().bump
    local manual = Manual(fight)
    local out, totals = {}, {}
    for r = 1, #rules do
        local rule = rules[r]
        local first
        local hits = {}
        local sum = Penalties.Amount(rule, sys, "sum") or 0
        local step = Penalties.Amount(rule, sys, "step") or 0
        local wipe = Penalties.Amount(rule, sys, "wipe")
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
                if rule.mode == "once" then found = { OnceOf(found) } end
                local events, nr, ny, paid = {}, 0, 0, 0
                for k = 1, #found do
                    local f = found[k]
                    local yellow = f.grade == "yellow"
                    if yellow then ny = ny + 1 else nr = nr + 1 end
                    local key = table.concat({ fk, p.name, rule.key, yellow and ("y" .. ny) or nr }, "|")
                    local bumped = bump[key] == true and (yellow or wipe ~= nil)
                    local gp = sum
                    if not yellow or bumped then paid = paid + 1 end
                    if rule.mode == "grow" then gp = gp + step * (paid - 1) end
                    if bumped and not yellow then gp = wipe end
                    if yellow and not bumped then gp = 0 end
                    events[k] = { key = key, t = f.t, n = gp, bumped = bumped, wipe = (bumped and not yellow) or nil, info = f,
                        grade = f.grade }
                    if rule.firstGp and f.t and not yellow and (not first or f.t < first.t) then first = events[k] end
                end
                hits[#hits + 1] = { p = p, hit = { rule = rule, events = events, icon = RuleIcon(rule, s, p),
                    shed = ShedOf(rule, s, p) } }
            end
        end
        if first and not first.bumped then
            local orig = Find(BaseRules(), rule.key)
            local base = tonumber(orig and orig.gp) or 0
            first.n = base > 0 and floor(rule.firstGp * sum / base + 0.5) or rule.firstGp
        end
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
            for k = 1, #list[i].events do sum = sum + list[i].events[k].n end
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
function Penalties.Unbump(key)
    Store().bump[key] = nil
end
