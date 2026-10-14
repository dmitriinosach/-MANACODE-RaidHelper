local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local find = string.find
local concat = table.concat
local tsort = table.sort
local BACK = 5
local AHEAD = 1
local KILL_SLACK = 0.3
local HP_STEP = 0.5
local SAME_T = 0.05
local FRONT = 0.5
local POS_BACK = 0.2
local BYTES = 1300
local SEP = " ; "
local ITEM = " / "
local LIMITS = { { 10, 8, 6 }, { 6, 5, 4 }, { 4, 3, 3 }, { 3, 2, 2 }, { 3, 0, 2 }, { 1, 0, 1 } }
local FIRST_DEATHS = 3
local ONE_PHASE = "fight"
local ZONE_GAP = 2
local ZONE_MAX = 20
local FLASK_BACK = 65
local FLASK_MAX = 4
local BERSERK = { 26662, 47008, 64238 }
local BERSERK_SET = {}
for i = 1, #BERSERK do BERSERK_SET[BERSERK[i]] = true end
local KIND = { death = "death", anydeath = "death", hit = "zone", mindps = "dps", mindmg = "dps", chased = "mech",
               mccast = "mech", mcweapon = "mech", expect = "mech", killer = "mech", caused = "mech", earlypull = "other" }
local PREP = { ["any.prep"] = true }
local AVOID = { rule = true, waverule = true, noheal = true }
local ALLY = { ally = true, link = true, mc = true, dep = true }
local FLASK_CAT = { flask = true, elixir = true, food = true }
local R = {}
ns.FableRec = R
R.BACK, R.AHEAD, R.BYTES = BACK, AHEAD, BYTES
local function W()
    return ns.fableWords.w
end
local function Plain(s)
    return (tostring(s or ""):gsub("[%c|]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
local Clock = ns.Clock
local function Rel(dt)
    local s = format("%.2f", dt)
    if s == "-0.00" then s = "0.00" end
    if dt >= 0.005 then s = "+" .. s end
    return s
end
function R.Cut(text, limit)
    if #text <= limit then return text end
    local cut = limit
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end
local function Mode(fight)
    local raid = (ns.Expect and ns.Expect.RaidOf and ns.Expect.RaidOf(fight)) or fight.raid
    local size = ns.RaidSize(fight, raid)
    if not raid then return tostring(size), W().diff end
    local d = ns.Raid and ns.Raid.Wanted and ns.Raid.Wanted(raid) or raid.diff or 1
    return tostring(size), (raid.heroic or d >= 3) and W().hard or W().norm
end
local function Phase(fight, at)
    local P = ns.Phases
    local res = P and (P.Get(fight) or P.Scan(fight))
    if not res then return nil end
    local sec = at - fight.from
    local key = P.At(res, sec)
    if not key or key == ONE_PHASE then return nil end
    local n = key:match("^p(%d+)$")
    if n then return format(W().phase, n) end
    for k = 1, #res.spans do
        local sp = res.spans[k]
        if sp.key == key and sp.label then return Plain(ns.T(sp.label)) end
    end
    return Plain(key)
end
local function Who(fight, p, who)
    local words = ns.fableWords
    local cls = (p and p.class) or (ns.Encounters.ClassOf and ns.Encounters.ClassOf(who))
    local parts = { Plain(who), cls and words.class[cls] or W().class }
    local trees = cls and words.tree[cls]
    parts[#parts + 1] = (p and p.tree and trees and trees[p.tree]) or W().spec
    parts[#parts + 1] = (p and p.role and words.role[p.role]) or W().role
    return concat(parts, " ")
end
local function Position(scene, who, t)
    if not scene then return W().pos end
    local k
    for i = 1, #scene.tracks do
        if scene.tracks[i].name == who then k = i end
    end
    if not k then return W().pos end
    ns.Replay.Sample(scene, t)
    local st, boss = scene.states[k], scene.bossState
    if not (st and st.vis and boss and boss.vis and (scene.ppy or 0) > 0) then return W().pos end
    local dx, dy = st.x - boss.x, st.y - boss.y
    local d = sqrt(dx * dx + dy * dy)
    local out = format(W().yd, floor(d / scene.ppy + 0.5))
    if not (scene.boss and scene.boss.fx) or d <= 0 then return out end
    local c = (dx * boss.hx + dy * boss.hy) / d
    local side = c > FRONT and W().front or (c < -FRONT and W().back or W().side)
    return out .. " " .. side
end
local function Flow(list, t, src, spell, n, over)
    local last = list[#list]
    if last and last.src == src and last.spell == spell and t - last.t <= SAME_T then
        last.n, last.times = last.n + n, last.times + 1
        last.over = max(last.over, over)
        return
    end
    list[#list + 1] = { t = t, src = src, spell = spell, n = n, over = over, times = 1 }
end
local function Scan(idx, who, at, death)
    local hits, heals = {}, {}
    local from, to = at - BACK, death and at + KILL_SLACK or at + AHEAD
    local mine = idx.who[who] or {}
    local i = ns.Index.Seek(idx, mine, from - 1)
    while mine[i] do
        ns.Jobs.Step()
        local ts, sub, _, srcName, _, _, dstName, _, a1, a2, a3, a4, a5 = ns.Index.Read(idx, mine, i, 5)
        i = i + 1
        if ts and ts > to then break end
        if ts and sub and ts >= from and dstName == who then
            if find(sub, "_DAMAGE", 1, true) then
                local n, over, spell
                if sub == "ENVIRONMENTAL_DAMAGE" then
                    n, over, spell = tonumber(a2) or 0, tonumber(a3) or 0, ns.EnvName(a1)
                elseif find(sub, "SWING", 1, true) then
                    n, over, spell = tonumber(a1) or 0, tonumber(a2) or 0, W().swing
                else
                    n, over, spell = tonumber(a4) or 0, tonumber(a5) or 0, a2 or a1
                end
                if n > 0 then Flow(hits, ts, Plain(srcName or "?"), Plain(spell), n, max(0, over)) end
            elseif find(sub, "_HEAL", 1, true) then
                local eff = (tonumber(a4) or 0) - (tonumber(a5) or 0)
                if eff > 0 then Flow(heals, ts, Plain(srcName or "?"), Plain(a2 or a1), eff, 0) end
            end
        end
    end
    if death then
        local kill
        for k = #hits, 1, -1 do
            if hits[k].t <= at + KILL_SLACK and (hits[k].over > 0 or not kill) then
                kill = k
                if hits[k].over > 0 then break end
            end
        end
        if kill then hits[kill].kill = true end
    end
    return hits, heals
end
local function Hp(pv, at, death)
    if not (pv and #pv.hpT > 0) then return nil end
    local out = {}
    local steps = floor(((death and 0 or AHEAD) + BACK) / HP_STEP + 0.5)
    for k = 0, steps do
        local t = at - BACK + k * HP_STEP
        if death and k == steps then t = t + KILL_SLACK end
        local v = pv.hpV[1]
        for j = 1, #pv.hpT do
            if pv.hpT[j] <= t + 1e-6 then v = pv.hpV[j] else break end
        end
        out[#out + 1] = floor(v * 100 + 0.5)
    end
    return out
end
local function Auras(pv, at)
    if not pv then return {} end
    local best = {}
    for k = 1, #pv.spanAura do
        if pv.spanFrom[k] <= at and pv.spanTo[k] >= at - pv.bin then
            local row = pv.spanAura[k]
            best[row] = max(best[row] or 0, pv.spanStack[k] or 1)
        end
    end
    local rows = {}
    for row in pairs(best) do rows[#rows + 1] = row end
    tsort(rows, function(a, b)
        if best[a] ~= best[b] then return best[a] > best[b] end
        return a < b
    end)
    local out = {}
    for k = 1, #rows do
        local row = rows[k]
        local n = best[row]
        out[k] = Plain(pv.auraLabel[row]) .. (n > 1 and (" " .. n) or "")
    end
    return out
end
local function SpellName(id)
    return id and ns.SpellName and Plain(ns.SpellName(id)) or nil
end
local function Guards(pv, d, at, death)
    local out, seen = {}, {}
    for k = 1, pv and #pv.defT or 0 do
        local t = pv.defT[k]
        if t >= at - BACK and t <= at + (death and 0 or AHEAD) then
            out[#out + 1] = format(W().used, Plain(pv.defLabel[k]), Rel(t - at))
            seen[pv.defId[k]] = true
        end
    end
    if d and d.used and not seen[d.used] then
        local name = SpellName(d.used)
        if name then out[#out + 1] = format(W().used, name, "") end
    end
    local ready = d and SpellName(d.ready)
    if ready then
        out[#out + 1] = d.readyN and format(W().readyN, ready, d.readyN) or format(W().ready, ready)
    elseif death and d and d.grade then
        out[#out + 1] = W().noready
    end
    if pv and pv.lockLabel then out[#out + 1] = format(W().lock, Plain(pv.lockLabel)) end
    for k = 1, #out do out[k] = out[k]:gsub(" $", "") end
    return out
end
local function DeathOf(p, at)
    local best
    for k = 1, p and #p.deathInfo or 0 do
        local d = p.deathInfo[k]
        if math.abs(d.t - at) < 0.05 then best = d end
    end
    return best
end
local function Grade(d, grade)
    if d and d.grade then
        local why = ns.BadgeTips and ns.BadgeTips.Verdict and ns.BadgeTips.Verdict(d)
        return why and (d.grade .. " " .. Plain(why)) or d.grade
    end
    if d and d.tail then return Plain(ns.T("sum.dg.tail")) end
    return grade
end
function R.Kind(rule)
    if not rule then return "death" end
    if PREP[rule.key] then return "flask" end
    local k = KIND[rule.kind]
    if k then return k end
    if rule.kind == "manual" and rule.boss ~= ns.penaltyAny then return "mech" end
    return "other"
end
local function ClassRole(cls, role)
    local words = ns.fableWords
    return (cls and words.class[cls] or W().class) .. " " .. (role and words.role[role] or W().role)
end
local function KilledBy(killer)
    if not killer then return "?" end
    if killer.spell == "#melee" then return W().swing end
    return Plain(killer.spell or "?")
end
local function AllDeaths(s)
    local out = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do out[#out + 1] = { t = p.deathInfo[k].t, p = p, d = p.deathInfo[k] } end
    end
    tsort(out, function(a, b) return a.t < b.t end)
    return out
end
local function Berserk(fight, idx)
    if not idx then return nil end
    local name = ns.SpellName and ns.SpellName(BERSERK[1])
    local common = idx.common
    for i = 1, #common do
        ns.Jobs.Step()
        local ts, _, _, _, _, _, _, _, a1, a2 = ns.Index.Read(idx, common, i, 2)
        local id = tonumber(a1)
        if ts and ((id and BERSERK_SET[id]) or (name and a2 == name)) then return ts end
    end
    return nil
end
local function BossHp(scene, t)
    if not scene then return nil end
    ns.Replay.Sample(scene, t)
    local b = scene.bossState
    if b and b.hpOk and b.hp then return floor(b.hp * 100 + 0.5) end
    return nil
end
local function Raid(fight, s, idx, scene, ask, at, death)
    local w = W()
    local parts = {}
    local head = (fight.killed and w.won or w.wipe) .. " " .. Clock(fight.to - fight.from)
    local hp = BossHp(scene, ask.whole and fight.to - 0.5 or at)
    if hp then head = head .. " " .. format(w.bosshp, hp) end
    local zerk = Berserk(fight, idx)
    if zerk then head = head .. " " .. format(w.berserk, Clock(zerk - fight.from)) end
    parts[1] = head
    local list = AllDeaths(s)
    if #list > 0 then
        local tail
        for k = 1, #list do
            if list[k].d.tail and (not tail or list[k].t < tail) then tail = list[k].t end
        end
        if not ask.whole then
            local n, own = 0, false
            for k = 1, #list do
                if list[k].t < at - 0.05 then n = n + 1 end
                if death and list[k].p.name == ask.who and math.abs(list[k].t - at) < 0.05 then own = true end
            end
            local order = own and format(w.order, n + 1, #list) or format(w.before, n, #list)
            if at >= list[1].t then order = order .. " " .. format(w.since, floor(at - list[1].t + 0.5)) end
            if tail and at >= tail - 0.05 then order = order .. " " .. w.tail end
            parts[#parts + 1] = order
        elseif tail then
            parts[#parts + 1] = format(w.tailat, Clock(tail - fight.from))
        end
        local first = {}
        for k = 1, min(FIRST_DEATHS, #list) do
            local x = list[k]
            local who = x.p.name == ask.who and Plain(x.p.name) or ClassRole(x.p.class, x.p.role)
            first[k] = concat({ Clock(x.t - fight.from), who, KilledBy(x.d.killer) }, " ")
        end
        parts[#parts + 1] = w.first .. concat(first, ", ")
    else
        parts[#parts + 1] = w.nodeaths
    end
    local t = ask.whole and fight.to or at - 0.05
    local tanks, tanksUp, heals, healsUp = 0, 0, 0, 0
    for i = 1, #s.players do
        local p = s.players[i]
        local up = true
        for k = 1, #p.deathInfo do
            if p.deathInfo[k].t < t then up = false end
        end
        if p.role == "tank" then
            tanks = tanks + 1
            if up then tanksUp = tanksUp + 1 end
        elseif p.role == "heal" then
            heals = heals + 1
            if up then healsUp = healsUp + 1 end
        end
    end
    parts[#parts + 1] = format(w.up, tanksUp, tanks, healsUp, heals)
    return w.raid .. concat(parts, ITEM)
end
local function Dps(s, p)
    local dur = max(1, ns.Totals.Time(s))
    local list, sum = {}, 0
    for i = 1, #s.players do
        local q = s.players[i]
        sum = sum + q.dmg
        if q.role == "dps" then list[#list + 1] = q end
    end
    tsort(list, function(a, b) return a.dmg > b.dmg end)
    local rank = 0
    for i = 1, #list do
        if list[i] == p then rank = i end
    end
    return p.dmg / dur, rank, #list, sum / dur
end
local function DpsClues(fight, s, p, ask)
    local w, info, out = W(), ask.info or {}, {}
    if not p then return out end
    local dps, rank, of, raid = Dps(s, p)
    if ask.rule and ask.rule.kind == "mindmg" and info.amount then
        out[1] = format(w.dmgneed, floor(info.amount), floor(info.need or 0), info.melee and w.melee or w.ranged)
    elseif info.amount then
        out[1] = format(w.dpsneed, floor(info.amount + 0.5), floor(info.need or 0))
    else
        out[1] = format(w.dps, floor(dps + 0.5))
    end
    if rank > 0 then out[#out + 1] = format(w.rank, rank, of) end
    out[#out + 1] = format(w.raiddps, floor(raid + 0.5))
    local dur = ns.Totals.Time(s)
    if p.eff then
        local line = format(w.eff, Clock(min(p.eff, dur)), Clock(dur))
        if p.lost and p.lost.dead then line = line .. " " .. format(w.deadfor, Clock(p.lost.dead)) end
        out[#out + 1] = line
    end
    if s.combat and s.combat < dur - 1 then out[#out + 1] = format(w.idle, Clock(dur - s.combat)) end
    if p.tree and p.class then
        local n, sum = 0, 0
        for i = 1, #s.players do
            local q = s.players[i]
            if q ~= p and q.class == p.class and q.tree == p.tree then n, sum = n + 1, sum + q.dmg end
        end
        if n > 0 then out[#out + 1] = format(w.same, floor(sum / n / max(1, dur) + 0.5), n) end
    end
    local ex = ns.Expect and ns.Expect.Of and ns.Expect.Of(fight, s)
    local mine = ex and ex.by and ex.by[p.name]
    if mine and mine.exp then out[#out + 1] = format(w.usual, floor(mine.exp + 0.5), mine.n or 0) end
    local B = ns.Bober
    if B and B.Ready and B.Ready() and B.FindId and B.Get then
        local rec = B.Get((B.FindId(p.name)))
        if rec and rec.gs then out[#out + 1] = format(w.gs, rec.gs) end
    end
    return out
end
local function DeathClues(ask, d)
    local w, out = W(), {}
    if not d then return out end
    local why, rule = d.why, ask.rule
    if AVOID[why or ""] or (rule and rule.sure and why == rule.sure) then
        out[1] = w.avoid
    elseif ALLY[why or ""] then
        out[1] = w.byally
    elseif d.tail then
        out[1] = w.intail
    elseif why then
        out[1] = w.unavoid
    end
    if rule and rule.ticks and rule.spells and d.recent then
        local want, n = {}, 0
        for i = 1, #rule.spells do want[ns.SpellKey(rule.spells[i]) or rule.spells[i]] = true end
        for i = 1, #d.recent do
            if want[d.recent[i].key] then n = n + 1 end
        end
        out[#out + 1] = format(w.ticks, n)
    end
    if d.react and d.react > 0 then out[#out + 1] = format(w.react, d.react) end
    return out
end
local function ZoneClues(idx, who, at, rule)
    local out = {}
    if not (idx and rule.spells) then return out end
    local want = {}
    for i = 1, #rule.spells do want[ns.SpellKey(rule.spells[i]) or rule.spells[i]] = true end
    local gap = rule.gap or ZONE_GAP
    local mine = idx.who[who] or {}
    local i = ns.Index.Seek(idx, mine, at - 1)
    local n, first, last, sum = 0, nil, nil, 0
    while mine[i] do
        ns.Jobs.Step()
        local ts, sub, _, _, _, _, dstName, _, a1, _, _, a4, _, _, _, _, a9 = ns.Index.Read(idx, mine, i, 9)
        i = i + 1
        if ts and (ts > at + ZONE_MAX or (last and ts - last > gap)) then break end
        if ts and ts >= at - 0.5 and dstName == who and sub and want[ns.SpellKey(tonumber(a1) or a1) or 0]
            and (find(sub, "_DAMAGE", 1, true) or find(sub, "_MISSED", 1, true)) then
            n = n + 1
            first = first or ts
            last = ts
            sum = sum + (tonumber(a4) or 0) + (tonumber(a9) or 0)
        end
    end
    if n > 0 then out[1] = format(W().zone, n, last - first, floor(sum)) end
    return out
end
local function FlaskClues(fight, idx, who)
    local w, out = W(), {}
    if not idx then return out end
    local cast = ns.consumeCast or {}
    local mine = idx.who[who] or {}
    local i = ns.Index.Seek(idx, mine, fight.from - FLASK_BACK)
    while mine[i] and #out < FLASK_MAX do
        ns.Jobs.Step()
        local ts, sub, _, srcName, _, _, dstName, _, a1 = ns.Index.Read(idx, mine, i, 1)
        i = i + 1
        if ts and ts > fight.to then break end
        local c = ts and cast[tonumber(a1) or 0]
        if c and FLASK_CAT[c.cat] then
            local when = ts - fight.from
            local clock = Clock(when, true)
            if sub == "SPELL_CAST_SUCCESS" and srcName == who then
                out[#out + 1] = format(w.drank, Plain(c.item), clock)
            elseif sub == "SPELL_AURA_REMOVED" and dstName == who then
                out[#out + 1] = format(w.faded, Plain(c.item), clock)
            elseif sub == "SPELL_AURA_APPLIED" and dstName == who then
                out[#out + 1] = format(w.gained, Plain(c.item), clock)
            end
        end
    end
    if #out == 0 then out[1] = w.noflask end
    return out
end
local function MechClues(fight, s, p, ask)
    local w, rule, info, out = W(), ask.rule, ask.info or {}, {}
    local kind = rule and rule.kind
    if info.manual or kind == "manual" then
        out[1] = w.manual
    elseif kind == "chased" and ask.at then
        out[1] = format(w.chased, Clock(ask.at - fight.from))
    elseif kind == "mccast" then
        out[1] = format(w.mccast, Plain(SpellName(tonumber(info.note)) or info.note))
    elseif kind == "mcweapon" and info.ctl then
        local c = info.ctl
        out[1] = format(w.mcw, floor((c.to or c.t) - c.t + 0.5), #(c.hits or {}))
        if c.ratio then out[2] = format(w.ratio, c.ratio) end
    elseif kind == "expect" then
        local duty = rule.by and p and p.class and rule.by[p.class]
        out[1] = format(w.expect, Plain(duty and SpellName(duty.id) or "?"), rule.min or 1, info.have or 0)
    elseif kind == "killer" or kind == "caused" then
        local v = info.victim and s.byName[info.victim]
        local victim = v and ClassRole(v.class, v.role) or "?"
        if kind == "killer" then
            out[1] = format(w.killer, victim, Plain(SpellName(rule.spells and rule.spells[1]) or "?"))
        else
            local what = info.dep and ns.DeathDeps and ns.DeathDeps.What and ns.DeathDeps.What(info.dep)
            out[1] = format(w.caused, victim, Plain(what or "?"))
        end
    elseif kind == "earlypull" and info.early then
        out[1] = format(w.early, info.early, info.sec or 0)
    end
    return out
end
local function Clues(fight, idx, s, p, ask, d, at)
    local kind = ask.kind
    if kind == "dps" then return DpsClues(fight, s, p, ask) end
    if kind == "death" then return DeathClues(ask, d) end
    if kind == "zone" then return ZoneClues(idx, ask.who, at, ask.rule) end
    if kind == "flask" then return FlaskClues(fight, idx, ask.who) end
    return MechClues(fight, s, p, ask)
end
function R.Collect(fight, idx, s, pv, scene, ask, at, death)
    local who = ask.who
    local p = s and s.byName and s.byName[who]
    ask.kind = ask.kind or R.Kind(ask.rule)
    local size, diff = Mode(fight)
    local head = { Plain(ns.EncName(fight.boss)), size, diff }
    if ask.whole then
        head[#head + 1] = W().whole .. " " .. Clock(fight.to - fight.from)
    else
        local phase = Phase(fight, at)
        if phase then head[#head + 1] = phase end
        head[#head + 1] = Clock(at - fight.from)
    end
    local fault
    if ask.reason then
        fault = format(W().fault, Plain(ask.reason)) .. ((death or ask.whole) and "" or (" " .. W().alive))
    elseif not death then
        fault = W().alive
    end
    local d = death and DeathOf(p, at) or nil
    local info = {
        head = concat(head, " "),
        kind = W().kind .. ns.fableWords.kind[ask.kind],
        raid = Raid(fight, s, idx, scene, ask, at, death),
        fault = fault,
        who = Who(fight, p, who),
        clues = Clues(fight, idx, s, p, ask, d, at),
        hits = {},
        heals = {},
        auras = {},
        guards = {},
        grade = Grade(d, ask.grade),
        death = death,
        whole = ask.whole,
        at = at,
    }
    if not ask.whole and idx then
        info.pos = Position(scene, who, death and at - POS_BACK or at)
        info.hits, info.heals = Scan(idx, who, at, death)
        info.hp = Hp(pv, at, death)
        info.auras = Auras(pv, at)
        info.guards = Guards(pv, d, at, death)
    end
    return info
end
local function Flows(list, limit, at)
    if #list == 0 then return W().none end
    local first = max(1, #list - limit + 1)
    local parts = {}
    if first > 1 then
        local n, sum = 0, 0
        for k = 1, first - 1 do n, sum = n + list[k].times, sum + list[k].n end
        parts[1] = format(W().more, n, sum)
    end
    for k = first, #list do
        local f = list[k]
        local s = concat({ Rel(f.t - at), f.src, f.spell, tostring(f.n) }, " ")
        if f.times > 1 then s = s .. " " .. format(W().times, f.times) end
        if f.kill then
            s = s .. " " .. W().kill
            if f.over > 0 then s = s .. " " .. format(W().over, f.over) end
        end
        parts[#parts + 1] = s
    end
    return concat(parts, ITEM)
end
local function Items(list, limit)
    if #list == 0 then return W().none end
    local parts = {}
    for k = 1, min(limit, #list) do parts[k] = list[k] end
    return concat(parts, ITEM)
end
local function Join(info, lim)
    local parts = { info.head, info.kind, info.raid }
    if info.fault then parts[#parts + 1] = info.fault end
    parts[#parts + 1] = info.who
    if #info.clues > 0 then parts[#parts + 1] = W().clues .. concat(info.clues, ITEM) end
    if not info.whole and info.pos then
        parts[#parts + 1] = info.pos
        parts[#parts + 1] = W().hits .. Flows(info.hits, lim[1], info.at)
        if lim[2] > 0 then parts[#parts + 1] = W().heals .. Flows(info.heals, lim[2], info.at) end
        parts[#parts + 1] = info.hp and (W().hp .. concat(info.hp, " ")) or W().nohp
        parts[#parts + 1] = W().auras .. Items(info.auras, lim[3])
    end
    if #info.guards > 0 then parts[#parts + 1] = W().guards .. concat(info.guards, ITEM) end
    if info.grade then parts[#parts + 1] = W().grade .. info.grade end
    return concat(parts, SEP)
end
function R.Text(info)
    local text
    for k = 1, #LIMITS do
        text = Join(info, LIMITS[k])
        if #text <= BYTES then return text end
    end
    return R.Cut(text, BYTES)
end
function R.Build(ask, onDone)
    local fight, who = ask.fight, ask.who
    local DP = ns.DeathPreview
    ask.kind = ask.kind or R.Kind(ask.rule)
    ns.Summary.Compute(fight, function(s)
        local at, death = ask.at or fight.to, false
        if ask.dead then
            death = true
        elseif ask.kind == "death" and ask.at then
            at, death = DP.Anchor(fight, who, ask.at)
        end
        ask.death = death
        local function Run(pv)
            DP.Scene(fight, function(scene)
                ns.Index.Get(fight, function(idx)
                    if not idx and not ask.whole then return onDone(nil) end
                    ns.Jobs.Run("fable:" .. ask.key, function()
                        return R.Text(R.Collect(fight, idx, s, pv, scene, ask, at, death))
                    end, onDone, "prev.data", true)
                end, true)
            end, true)
        end
        if ask.whole then return Run(nil) end
        DP.Request(fight, who, at, death, Run)
    end)
end
