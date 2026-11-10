local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local tsort = table.sort
local KEEP_DONE = 20
local PENDING_TTL = 7 * 86400
local REMIND_TTL = 6 * 3600
local REASON_MAX = 120
local STEP = 10
local EP = {}
ns.RaidEP = EP
EP.WHEN = { "ask", "kill", "zone", "group", "off" }
local model
local modelFor
local listeners = {}
local frame = CreateFrame("Frame")
local inGroup = false
local inRaidZone = false
local function Store()
    local db = ns.GetDB()
    if type(db.raidep) ~= "table" then db.raidep = {} end
    local s = db.raidep
    if type(s.rules) ~= "table" then s.rules = {} end
    if type(s.done) ~= "table" then s.done = {} end
    if type(s.custom) ~= "table" then s.custom = {} end
    if s.when == nil then s.when = "ask" end
    return s
end
local function Changed()
    for i = 1, #listeners do listeners[i]() end
end
function EP.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function EP.When()
    return Store().when
end
function EP.Notify()
    return Store().quiet ~= true
end
function EP.SetNotify(on)
    Store().quiet = (not on) or nil
    Changed()
end
local function Ask(why)
    if EP.Notify() and ns.RaidEPView then ns.RaidEPView.Prompt(why) end
end
function EP.SetWhen(key)
    for i = 1, #EP.WHEN do
        if EP.WHEN[i] == key then Store().when = key end
    end
    Changed()
end
function EP.StandbyPct()
    local v = Store().standby
    return type(v) == "number" and v or ns.raidEp.STANDBY
end
function EP.SetStandbyPct(n)
    Store().standby = n and max(0, floor(n)) or nil
    Changed()
end
function EP.MinGuild()
    local v = Store().minGuild
    return type(v) == "number" and v or ns.raidEp.MIN_GUILD
end
function EP.SetMinGuild(n)
    Store().minGuild = n and max(0, floor(n)) or nil
    Changed()
end
function EP.Customs()
    return Store().custom
end
function EP.AddCustom()
    local list = Store().custom
    list[#list + 1] = { name = ns.T("rep.custom.new"), n = 0 }
    local p = EP.Pending()
    if p then p.edit.custom = p.edit.custom or {}; p.edit.custom[#list] = true end
    Changed()
end
function EP.SetCustom(i, name, n)
    local c = Store().custom[i]
    if not c then return end
    if name and name:gsub("%s", "") ~= "" then c.name = name:sub(1, 40) end
    if n then c.n = max(0, floor(n)) end
    Changed()
end
function EP.DropCustom(i)
    local list = Store().custom
    if not list[i] then return end
    table.remove(list, i)
    local p = EP.Pending()
    local on = p and p.edit.custom
    if on then
        for k = i, #list do on[k] = on[k + 1] end
        on[#list + 1] = nil
    end
    Changed()
end
function EP.CustomOn(i)
    local p = EP.Pending()
    return p ~= nil and p.edit.custom ~= nil and p.edit.custom[i] == true
end
function EP.SetCustomOn(i, on)
    local p = EP.Pending()
    if not p then return end
    p.edit.custom = p.edit.custom or {}
    p.edit.custom[i] = on and true or nil
    Changed()
end
function EP.Rule(mode, field)
    local own = Store().rules[mode]
    if own and type(own[field]) == "number" then return own[field] end
    local m = ns.raidEp.modes[mode]
    if not m then return 0 end
    local grp, key = field:match("^(%a+)%.(.+)$")
    if grp then return m[grp] and m[grp][key] or 0 end
    return m[field] or 0
end
function EP.Own(mode, field)
    local own = Store().rules[mode]
    return own ~= nil and own[field] ~= nil
end
function EP.SetRule(mode, field, n)
    local rules = Store().rules
    local own = rules[mode] or {}
    own[field] = n and max(0, floor(n)) or nil
    rules[mode] = next(own) and own or nil
    Changed()
end
function EP.ResetRules(mode)
    Store().rules[mode] = nil
    Changed()
end
function EP.Keys(mode, grp)
    local m = ns.raidEp.modes[mode]
    local out = {}
    for k in pairs(m and m[grp] or {}) do out[#out + 1] = k end
    tsort(out)
    return out
end
function EP.Pending()
    local p = Store().pending
    if type(p) ~= "table" then return nil end
    if time() - (p.at or 0) > PENDING_TTL then
        Store().pending = nil
        return nil
    end
    return p
end
function EP.Done()
    return Store().done
end
function EP.ModeOf(map, size, heroic, unbuff)
    local pre = ns.raidEp.PREFIX[map or ""] or "raid"
    local key = format("%s%d%s", pre, size or 25, heroic and "h" or "n")
    if key == "icc25h" and unbuff then return "icc25h0" end
    return key
end
local function Roster()
    local out = {}
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local name = GetRaidRosterInfo(i)
            if name then out[name] = true end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name then out[name] = true end
        end
        if next(out) then out[UnitName("player")] = true end
    end
    return out
end
local function Epgp()
    local e = _G.EPGP
    return type(e) == "table" and type(e.IncEPBy) == "function" and e or nil
end
local function AnnounceMass(e, list)
    local an = type(e.GetModule) == "function" and select(2, pcall(e.GetModule, e, "announce", true)) or nil
    if type(an) ~= "table" or type(an.Announce) ~= "function" then return end
    if type(an.IsEnabled) == "function" and not an:IsEnabled() then return end
    local groups, order = {}, {}
    for i = 1, #list do
        local r = list[i]
        local key = r.reason .. "\1" .. r.n
        local g = groups[key]
        if not g then
            g = { reason = r.reason, n = r.n, names = {} }
            groups[key] = g
            order[#order + 1] = g
        end
        g.names[#g.names + 1] = r.name
    end
    for i = 1, #order do
        local g = order[i]
        pcall(an.Announce, an, "%+d EP (%s): %s", g.n, g.reason, table.concat(g.names, ", "))
    end
end
local function Rights()
    if not Epgp() then return false end
    return type(CanEditOfficerNote) ~= "function" or CanEditOfficerNote() and true or false
end
local function Known(e, name)
    if type(e.GetEPGP) ~= "function" then return true end
    local ok, ep = pcall(e.GetEPGP, e, name)
    return ok and ep ~= nil
end
function EP.CanAward()
    local e = Epgp()
    if not e then return false, "led.err.noepgp" end
    if type(e.CanIncEPBy) == "function" then
        local ok, yes = pcall(e.CanIncEPBy, e, "MRH", 1)
        if ok and not yes then return false, "led.err.rights" end
    end
    return true
end
local function MainOf(name)
    local e = Epgp()
    if e and type(e.GetEPGP) == "function" then
        local ok, ep, _, main = pcall(e.GetEPGP, e, name)
        if ok and ep ~= nil then return type(main) == "string" and main ~= "" and main or name, true end
    end
    local G = ns.GuildNotes
    local main = G and G.MainOf(name) or name
    if e and type(e.GetEPGP) == "function" and main ~= name then
        local ok, ep = pcall(e.GetEPGP, e, main)
        if ok and ep ~= nil then return main, true end
    end
    if e then return main, false end
    return main, nil
end
EP.MainOf = MainOf
local function NewPending(info)
    local lead = UnitName("player")
    for i = 1, GetNumRaidMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if rank == 2 and name then lead = name end
    end
    local p = {
        id = info.id, name = info.name, map = info.map, size = info.size, heroic = info.heroic,
        at = time(), roster = Roster(), left = {}, lead = lead,
        edit = { flags = {}, conds = {}, rows = {}, standby = {}, ach = 0 },
    }
    Store().pending = p
    model, modelFor = nil, nil
    return p
end
local function Awarded(id)
    local done = Store().done
    for i = 1, #done do
        if done[i].id == id and not done[i].undone then return true end
    end
    return false
end
local function Fire(why, dev)
    local p = EP.Pending()
    if not p then return end
    if p.dev and not dev then return end
    if not p.dev then
        if p.lead ~= UnitName("player") or not Rights() then return end
        if why ~= "kill" and time() - (p.at or 0) > REMIND_TTL then return end
    end
    local when = EP.When()
    if when == "off" then return end
    if when == "ask" then
        if why ~= "kill" and p.remind and p.remind ~= why then return end
        Ask(why)
        return
    end
    if when ~= why then return end
    if p.dev then
        EP.AutoAward(why, true)
    elseif EP.CanAward() then
        EP.AutoAward(why)
    else
        Ask(why)
    end
end
local function Begin(raid)
    local id = ns.Raid.Key(raid)
    local p = EP.Pending()
    if p and p.id == id then return p end
    if Awarded(id) then return nil end
    p = NewPending({ id = id, name = raid.name, map = raid.map or ns.Raid.MapNow(), size = raid.size, heroic = raid.heroic })
    Changed()
    return p
end
function EP.Killed(enc)
    if EP.When() == "off" then return end
    local raid = ns.Raid.Current()
    if not raid then return end
    local map = raid.map or ns.Raid.MapNow()
    local last = map and ns.raidEp.END[map]
    if not last or tonumber(enc) ~= last then return end
    if not Rights() then return end
    if GetNumRaidMembers() > 0 and not IsRaidLeader() then return end
    if Begin(raid) then Fire("kill") end
end
function EP.Drop()
    Store().pending = nil
    model, modelFor = nil, nil
    Changed()
end
function EP.Remind(kind)
    local p = EP.Pending()
    if p then
        p.later = true
        p.remind = kind
    end
    Changed()
end
function EP.Later()
    EP.Remind(nil)
end
local function TreeRaid(p)
    local raids = ns.FightTree.Get()
    for i = 1, #raids do
        local r = raids[i]
        if not r.party and r.key == p.id then return r end
    end
    for i = 1, #raids do
        local r = raids[i]
        if not r.party and r.name == p.name and r.size == p.size and p.at >= r.from - 60 and p.at <= r.to + 3600 then
            return r
        end
    end
    return nil
end
local function RoleOf(map)
    local best, n = "dps", map.dps or 0
    if (map.heal or 0) > 0 and map.heal >= n then best, n = "heal", map.heal end
    if (map.tank or 0) > 0 and map.tank >= n then best = "tank" end
    return best
end
local function ShareOf(frac)
    if frac >= 0.75 then return 1 end
    if frac >= 0.4 then return 0.5 end
    return 0.25
end
local function Presence(raid, p, rows)
    local last = ns.raidEp.END[raid.map or p.map or ""]
    local kills, lastAt = 0, nil
    for k = 1, #raid.encs do
        local enc = raid.encs[k]
        local f = enc.passed and ns.FightTree.Decisive(enc)
        if f and f.killed then
            kills = kills + 1
            if enc.boss == last then lastAt = f.to end
            for name in pairs(f.players) do
                local r = rows[MainOf(name)]
                if r then
                    r.present = r.present + 1
                    if enc.boss == last then r.final = true end
                end
            end
        end
    end
    return kills, lastAt
end
local function RowFor(rows, name, class)
    local main, inEpgp = MainOf(name)
    local r = rows[main]
    if not r then
        r = { name = main, chars = {}, class = class, present = 0, kills = 0, final = false, role = "dps", dmg = 0,
            top5 = false, rl = false, share = 1, checked = false, epgp = inEpgp, roles = {} }
        rows[main] = r
    end
    local have = false
    for i = 1, #r.chars do
        if r.chars[i] == name then have = true end
    end
    if not have then r.chars[#r.chars + 1] = name end
    if not r.class and class then r.class = class end
    return r
end
local function RemovesOn(res, boss)
    for i = 1, #(res.sums or {}) do
        local e = res.sums[i]
        if e.fight.boss == boss and e.fight.killed and e.s then
            local out = {}
            for _, b in ipairs(e.s.blocks or {}) do
                local kind = b.def and b.def.kind
                if kind == "dispels" or kind == "removed" then
                    for who, n in pairs(b.by or {}) do out[who] = (out[who] or 0) + n end
                end
            end
            return out
        end
    end
    return nil
end
local function Auto(res, rows)
    local lk, hal = RemovesOn(res, ns.ENC.lichking), RemovesOn(res, ns.ENC.halion)
    for _, r in pairs(rows) do
        r.auto = {}
        r.why = {}
        if r.role ~= "heal" then
            for _, c in ipairs(r.chars) do
                local nl, nh = lk and lk[c] or 0, hal and hal[c] or 0
                if nl > 0 then
                    r.auto.dispel = true
                    r.why.dispel = (r.why.dispel or 0) + nl
                end
                if nh > 0 then
                    if r.class == "PALADIN" and r.role == "dps" then
                        r.auto.freedom = true
                        r.why.freedom = (r.why.freedom or 0) + nh
                    else
                        r.auto.dispel = true
                        r.why.dispel = (r.why.dispel or 0) + nh
                    end
                end
            end
        end
    end
end
local function Top5(list)
    local dd = {}
    for i = 1, #list do
        local r = list[i]
        if r.role == "dps" and r.dmg > 0 and r.epgp ~= false then dd[#dd + 1] = r end
    end
    tsort(dd, function(a, b) return a.dmg > b.dmg end)
    for i = 1, math.min(5, #dd) do dd[i].top5 = true end
end
local function NoAir(raid)
    for k = 1, #raid.encs do
        local enc = raid.encs[k]
        if enc.boss == ns.ENC.sindragosa and enc.passed then
            local f = ns.FightTree.Decisive(enc)
            local ph = f and f.killed and ns.Phases and ns.Phases.Get(f)
            if not ph then return false end
            local p2
            for i = 1, #(ph.spans or {}) do
                if ph.spans[i].key == "p2" then p2 = ph.spans[i].from end
            end
            local tombs = ph.waves and ph.waves.tomb or {}
            for i = 1, #tombs do
                if not p2 or tombs[i] < p2 then return false end
            end
            return true
        end
    end
    return false
end
EP.NoAir = NoAir
local function Make(res, raid, p)
    local rows = {}
    local cut = res.cutAt ~= nil
    for i = 1, #res.players do
        local pl = res.players[i]
        local r = RowFor(rows, pl.name, pl.class)
        r.dmg = r.dmg + (cut and pl.cut or pl.all)
    end
    for i = 1, #res.sums do
        local s = res.sums[i].s
        for k = 1, #(s and s.players or {}) do
            local sp = s.players[k]
            local r = RowFor(rows, sp.name, sp.class)
            r.roles[sp.role] = (r.roles[sp.role] or 0) + 1
        end
    end
    for name in pairs(p.roster or {}) do RowFor(rows, name, nil) end
    local kills, lastAt = Presence(raid, p, rows)
    local lead = p.lead or UnitName("player")
    local list, unbuff = {}, false
    for k = 1, #raid.encs do
        local enc = raid.encs[k]
        if enc.boss == ns.raidEp.END[raid.map or ""] and enc.passed and ns.ZoneBuff then
            unbuff = ns.ZoneBuff.Unbuffed(ns.FightTree.Decisive(enc))
        end
    end
    for _, r in pairs(rows) do
        r.kills = kills
        r.role = RoleOf(r.roles)
        r.roles = nil
        for i = 1, #r.chars do
            if p.roster and p.roster[r.chars[i]] then r.final = true end
            if p.left and p.left[r.chars[i]] then r.left = p.left[r.chars[i]] end
            if r.chars[i] == lead then r.rl = true end
        end
        local frac = kills > 0 and r.present / kills or 0
        r.share = ShareOf(frac)
        if r.final and kills == 0 then r.share = 1 end
        r.checked = (r.final or frac >= 0.25) and r.epgp ~= false
        list[#list + 1] = r
    end
    Top5(list)
    Auto(res, rows)
    tsort(list, function(a, b)
        local ga, gb = a.epgp ~= false, b.epgp ~= false
        if ga ~= gb then return ga end
        if a.checked ~= b.checked then return a.checked end
        if a.present ~= b.present then return a.present > b.present end
        return a.name < b.name
    end)
    local guild = 0
    for i = 1, #list do
        if list[i].epgp ~= false and list[i].final then guild = guild + 1 end
    end
    local dur = max(0, (lastAt or res.to or 0) - (res.from or 0))
    local auto = EP.ModeOf(raid.map or p.map, raid.size or p.size, raid.heroic or p.heroic, unbuff)
    local mode = auto
    local fastMin = EP.Rule(mode, "fastMin")
    return {
        mode = mode, auto = auto, title = ns.Raid.Label(raid), kills = kills, total = res.known or kills,
        wipes = res.wipes or 0, dur = dur, rows = list, unbuff = unbuff, guild = guild,
        conds = { nowipe = (res.wipes or 0) == 0, fast = fastMin > 0 and dur > 0 and dur < fastMin * 60,
            sindra = NoAir(raid), top5 = true },
    }
end
function EP.Model(onDone)
    local p = EP.Pending()
    if not p then return onDone(nil, "none") end
    if model and modelFor == p then return onDone(model) end
    ns.Encounters.Scan(function()
        local raid = TreeRaid(p)
        if not raid then return onDone(nil, "norec") end
        ns.RaidSummary.Compute(raid, function(res)
            if not res then return onDone(nil, "fail") end
            if EP.Pending() ~= p then return onDone(nil, "none") end
            model, modelFor = Make(res, raid, p), p
            onDone(model)
        end)
    end)
end
function EP.Peek()
    local p = EP.Pending()
    return p and modelFor == p and model or nil
end
function EP.ModeNow(m)
    local p = EP.Pending()
    return p and p.edit.mode or m.mode
end
function EP.On(m, key, flag)
    local p = EP.Pending()
    local e = p and p.edit[flag and "flags" or "conds"]
    if e and e[key] ~= nil then return e[key] end
    if flag then return false end
    return m.conds[key] == true
end
function EP.SetOn(key, flag, on)
    local p = EP.Pending()
    if not p then return end
    p.edit[flag and "flags" or "conds"][key] = on and true or false
    Changed()
end
function EP.SetMode(mode)
    local p = EP.Pending()
    if not p then return end
    p.edit.mode = mode
    Changed()
end
function EP.SetAch(n)
    local p = EP.Pending()
    if not p then return end
    p.edit.ach = max(0, floor(n or 0))
    Changed()
end
local function EditOf(name)
    local p = EP.Pending()
    local rows = p.edit.rows
    rows[name] = rows[name] or {}
    return rows[name]
end
function EP.Target(r)
    local p = EP.Pending()
    local e = p and p.edit.rows[r.name]
    if e and e.to then return e.to end
    if r.epgp == false then return nil end
    return r.name
end
function EP.SetTarget(r, main)
    local e = EditOf(r.name)
    e.to = main
    if main and e.c == nil then e.c = true end
    if not main then e.c = nil end
    Changed()
end
function EP.Checked(r)
    if not EP.Target(r) then return false end
    local p = EP.Pending()
    local e = p and p.edit.rows[r.name]
    if e and e.c ~= nil then return e.c end
    return r.checked
end
function EP.Top5(m, r)
    local p = EP.Pending()
    local e = p and p.edit.rows[r.name]
    if e and e.top5 ~= nil then return e.top5 end
    return r.top5 and EP.On(m, "top5")
end
function EP.SetTop5(r, on)
    local e = EditOf(r.name)
    e.top5, e.n = on and true or false, nil
    Changed()
end
function EP.ShareOf(r)
    local p = EP.Pending()
    local e = p and p.edit.rows[r.name]
    return e and e.s or r.share
end
function EP.Per(r, key)
    local p = EP.Pending()
    local e = p and p.edit.rows[r.name]
    if e and e.per and e.per[key] ~= nil then return e.per[key] end
    return r.auto ~= nil and r.auto[key] == true
end
function EP.SetChecked(r, on)
    EditOf(r.name).c = on and true or false
    Changed()
end
function EP.SetShare(r, share)
    local e = EditOf(r.name)
    e.s, e.n = share, nil
    Changed()
end
function EP.SetPer(r, key, on)
    local e = EditOf(r.name)
    e.per = e.per or {}
    e.per[key] = on and true or false
    e.n = nil
    Changed()
end
function EP.SetSum(r, n)
    EditOf(r.name).n = n and max(0, floor(n)) or nil
    Changed()
end
local function Round(n)
    return floor(n / STEP + 0.5) * STEP
end
function EP.Sum(m, r)
    local mode = EP.ModeNow(m)
    local parts = {}
    local function Add(key, n, arg)
        if n and n > 0 then parts[#parts + 1] = { key = key, n = n, arg = arg } end
    end
    local share = EP.ShareOf(r)
    local core = EP.Rule(mode, "base") + EP.Rule(mode, "perBoss") * m.kills
    if r.role == "heal" then core = core + EP.Rule(mode, "heal") end
    if r.role == "tank" then core = core + EP.Rule(mode, "tank") end
    for _, key in ipairs({ "nowipe", "fast", "sindra" }) do
        if EP.On(m, key) then core = core + EP.Rule(mode, key) end
    end
    local customs = EP.Customs()
    for i = 1, #customs do
        if EP.CustomOn(i) then core = core + (customs[i].n or 0) end
    end
    local flags = EP.Keys(mode, "flags")
    for i = 1, #flags do
        if EP.On(m, flags[i], true) then core = core + EP.Rule(mode, "flags." .. flags[i]) end
    end
    Add("core", Round(core * share), share)
    if EP.Top5(m, r) then Add("top5", EP.Rule(mode, "top5")) end
    if r.rl then Add("rl", EP.Rule(mode, "rl")) end
    local p = EP.Pending()
    Add("ach", EP.Rule(mode, "ach") * (p and p.edit.ach or 0))
    local per = EP.Keys(mode, "per")
    for i = 1, #per do
        if EP.Per(r, per[i]) then Add("per." .. per[i], EP.Rule(mode, "per." .. per[i])) end
    end
    local sum = 0
    for i = 1, #parts do sum = sum + parts[i].n end
    local e = p and p.edit.rows[r.name]
    if e and e.n then return e.n, parts, true end
    return sum, parts, false
end
function EP.Standby()
    local p = EP.Pending()
    return p and p.edit.standby or {}
end
function EP.AddStandby(name)
    local p = EP.Pending()
    if not p then return nil, "none" end
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil, "empty" end
    name = name:sub(1, 1):upper() .. name:sub(2)
    local G = ns.GuildNotes
    if G and G.Loaded() then
        local lower = G.Lower(name)
        for n in pairs(G.Members()) do
            if G.Lower(n) == lower then name = n end
        end
    end
    local main = MainOf(name)
    local list = p.edit.standby
    for i = 1, #list do
        if list[i].name == main then return nil, "dup" end
    end
    list[#list + 1] = { name = main, c = true }
    Changed()
    return main
end
function EP.DropStandby(i)
    local p = EP.Pending()
    if p and p.edit.standby[i] then
        table.remove(p.edit.standby, i)
        Changed()
    end
end
function EP.StandbySum(m, s)
    if s.n then return s.n end
    return Round(EP.Rule(EP.ModeNow(m), "base") * EP.StandbyPct() / 100)
end
function EP.SetStandbySum(i, n)
    local p = EP.Pending()
    local s = p and p.edit.standby[i]
    if s then
        s.n = n and max(0, floor(n)) or nil
        Changed()
    end
end
function EP.SetStandbyOn(i, on)
    local p = EP.Pending()
    local s = p and p.edit.standby[i]
    if s then
        s.c = on and true or false
        Changed()
    end
end
function EP.Batch(m)
    local out, total, seen = {}, 0, {}
    for i = 1, #m.rows do
        local r = m.rows[i]
        local n = EP.Sum(m, r)
        local to = EP.Target(r)
        if to and EP.Checked(r) and n > 0 and not seen[to] then
            out[#out + 1] = { name = to, n = n, from = to ~= r.name and r.name or nil }
            seen[to] = true
            total = total + n
        end
    end
    local list = EP.Standby()
    for i = 1, #list do
        local s = list[i]
        local n = EP.StandbySum(m, s)
        if s.c and n > 0 and not seen[s.name] then
            out[#out + 1] = { name = s.name, n = n, standby = true }
            total = total + n
        end
    end
    return out, total
end
local function Reason(m, standby)
    local text = format(ns.T(standby and "rep.reason.standby" or "rep.reason"), m.title)
    if #text > REASON_MAX then text = text:sub(1, REASON_MAX) end
    return text
end
function EP.Award(m)
    local p = EP.Pending()
    if not p then return nil, "none" end
    local ok, why = EP.CanAward()
    if not ok then return nil, why end
    local e = Epgp()
    local batch = EP.Batch(m)
    if #batch == 0 then return nil, "rep.err.empty" end
    local res, list, said = { given = 0, total = 0, failed = {} }, {}, {}
    for i = 1, #batch do
        local b = batch[i]
        local reason = Reason(m, b.standby)
        local done = Known(e, b.name) and pcall(e.IncEPBy, e, b.name, reason, b.n, true)
        if done then
            res.given = res.given + 1
            res.total = res.total + b.n
            list[#list + 1] = { name = b.name, n = b.n }
            said[#said + 1] = { name = b.name, n = b.n, reason = reason }
        else
            res.failed[#res.failed + 1] = b.name
        end
    end
    AnnounceMass(e, said)
    if res.given == 0 then return res end
    local all = Store().done
    table.insert(all, 1, { id = p.id, title = m.title, at = time(), by = UnitName("player"), list = list,
        total = res.total, reason = Reason(m) })
    while #all > KEEP_DONE do table.remove(all) end
    Store().pending = nil
    model, modelFor = nil, nil
    Changed()
    return res
end
function EP.AutoAward(why, dry)
    EP.Model(function(m, err)
        if not m then
            if err ~= "none" then ns.Print(ns.T("rep.auto.fail")) end
            return
        end
        if dry then
            local batch, total = EP.Batch(m)
            ns.Print(format(ns.T("rep.dev.auto"), #batch, total))
            return
        end
        if m.guild < EP.MinGuild() then
            ns.Print(format(ns.T("rep.auto.few"), m.guild, EP.MinGuild()))
            Ask(why or "kill")
            return
        end
        local res, err = EP.Award(m)
        if not res then
            ns.Print(format(ns.T("rep.auto.cant"), ns.T(err or "led.err.noepgp")))
            return
        end
        if res.given > 0 then ns.Print(format(ns.T("rep.auto.done"), res.given, res.total)) end
        if res.failed[1] then ns.Print(format(ns.T("rep.failed"), table.concat(res.failed, ", "))) end
    end)
end
function EP.Undo(i)
    local rec = Store().done[i]
    if not rec or rec.undone then return false, "led.err.none" end
    local ok, why = EP.CanAward()
    if not ok then return false, why end
    local e = Epgp()
    local reason = format(ns.T("led.undo"), rec.reason or "")
    if #reason > REASON_MAX then reason = reason:sub(1, REASON_MAX) end
    local said = {}
    for k = 1, #rec.list do
        if Known(e, rec.list[k].name) and pcall(e.IncEPBy, e, rec.list[k].name, reason, -rec.list[k].n, true) then
            said[#said + 1] = { name = rec.list[k].name, n = -rec.list[k].n, reason = reason }
        end
    end
    AnnounceMass(e, said)
    rec.undone = time()
    Changed()
    return true
end
local function TrackLeft()
    local p = EP.Pending()
    if not p then return end
    local now = Roster()
    if not next(now) then return end
    for name in pairs(p.roster or {}) do
        if not now[name] and not p.left[name] then
            p.left[name] = time()
            model, modelFor = nil, nil
        end
    end
end
local function OnRoster()
    local was = inGroup
    inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if inGroup then
        TrackLeft()
        return
    end
    if was then Fire("group") end
end
local function OnZone()
    local _, kind = GetInstanceInfo()
    local was = inRaidZone
    inRaidZone = kind == "raid"
    if was and not inRaidZone then Fire("zone") end
end
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.raidep", function(_, event)
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        OnRoster()
    else
        if event == "PLAYER_ENTERING_WORLD" then
            local p = Store().pending
            if type(p) == "table" and p.dev then
                Store().pending = nil
                model, modelFor = nil, nil
            end
            inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
        end
        OnZone()
    end
end))
function EP.Find(text, limit)
    local G = ns.GuildNotes
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or not G then return {} end
    local low = G.Lower(text)
    local hits, order = {}, {}
    for name in pairs(G.Members()) do
        if G.Lower(name):find(low, 1, true) then
            local main = MainOf(name)
            if not hits[main] then
                hits[main] = { main = main, alts = {}, first = G.Lower(name):find(low, 1, true) == 1 }
                order[#order + 1] = hits[main]
            end
        end
    end
    for _, h in ipairs(order) do
        for alt in pairs(G.AltsOf and G.AltsOf(h.main) or {}) do h.alts[#h.alts + 1] = alt end
        tsort(h.alts)
    end
    tsort(order, function(a, b)
        if a.first ~= b.first then return a.first end
        return a.main < b.main
    end)
    local out = {}
    for i = 1, math.min(limit or 10, #order) do out[i] = order[i] end
    return out
end
function EP.DevKill()
    local raids = ns.FightTree and ns.FightTree.Get() or {}
    local top
    for i = 1, #raids do
        if not raids[i].party then
            top = raids[i]
            break
        end
    end
    if not top then return { ns.T("rep.dev.norec") } end
    local p = EP.Pending()
    if not (p and p.id == top.key) then
        p = NewPending({ id = top.key, name = top.name, map = top.map, size = top.size, heroic = top.heroic })
        p.dev = true
        if not next(p.roster) then
            local f = top.encs[1] and ns.FightTree.Decisive(top.encs[1])
            for name in pairs(f and f.players or {}) do p.roster[name] = true end
        end
        Changed()
    end
    Fire("kill", true)
    return { format(ns.T("rep.dev.kill"), ns.Raid.Label(top), ns.T("rep.when." .. EP.When())) }
end
function EP.DevGroup()
    if not EP.Pending() then return { ns.T("rep.dev.nopend") } end
    Fire("group", true)
    return { ns.T("rep.dev.group") }
end
function EP.DevZone()
    if not EP.Pending() then return { ns.T("rep.dev.nopend") } end
    Fire("zone", true)
    return { ns.T("rep.dev.zone") }
end
function EP.DevMember()
    local p = EP.Pending()
    if not p then return { ns.T("rep.dev.nopend") } end
    local names = {}
    for name in pairs(p.roster or {}) do
        if not p.left[name] and name ~= UnitName("player") then names[#names + 1] = name end
    end
    tsort(names)
    if not names[1] then return { ns.T("rep.dev.noone") } end
    p.left[names[1]] = time()
    model, modelFor = nil, nil
    Changed()
    return { format(ns.T("rep.dev.member"), names[1]) }
end
