local _, ns = ...
local format = string.format
local floor = math.floor
local min = math.min
local concat = table.concat
local tsort = table.sort
local tremove = table.remove
local LIMIT = 255
local TAG = "[MRH]"
local RECENT = 10
local TIMES = 4
local LINKS = 4
local GUARD = 10
local DEATHS_MAX = 4
local GAP = 0.5
local DUP = 4
local QUEUE = 24
local STEP = 8
local LINK = "^|c%x%x%x%x%x%x%x%x|H[^|]*|h[^|]*|h|r"
local CHANNELS = { "RAID", "PARTY", "GUILD", "OFFICER", "WHISPER", "SAY" }
local KNOWN = { RAID = true, PARTY = true, GUILD = true, OFFICER = true, WHISPER = true, SAY = true }
local DEATH_KINDS = { death = true, anydeath = true }
local Proof = {}
ns.Proof = Proof
Proof.LIMIT = LIMIT
Proof.TAG = TAG
Proof.GAP = GAP
Proof.DUP = DUP
Proof.CHANNELS = CHANNELS
local queue = {}
local sentAt = {}
local nextAt = 0
local pump = CreateFrame("Frame")
pump:Hide()
local function T(key)
    return ns.T(key)
end
local function Plain(s)
    return (tostring(s or ""):gsub("[|\r\n]", ""))
end
local function Short(n)
    if n >= 1e6 then return format("%.1f", n / 1e6) .. ns.T("num.m") end
    if n >= 1e4 then return format("%d", floor(n / 1e3 + 0.5)) .. ns.T("num.k") end
    if n >= 1e3 then return format("%.1f", n / 1e3) .. ns.T("num.k") end
    return tostring(floor(n + 0.5))
end
local function Dec(v)
    return ns.Dec(format("%.1f", v))
end
local function Clock(sec)
    if sec < 0 then sec = 0 end
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
function Proof.Link(id, name)
    local link = id and GetSpellLink and GetSpellLink(id)
    if type(link) == "string" and link:find(LINK) then return link end
    if not name and id and GetSpellInfo then name = GetSpellInfo(id) end
    return Plain(name or "?")
end
local Link = Proof.Link
local function Spell(e)
    if e.spell == "#melee" then return T("proof.melee") end
    return Link(e.id, e.spell)
end
local function Player(fight, name, s)
    s = s or (ns.Summary and ns.Summary.Get(fight))
    if not s then return nil, nil end
    for i = 1, #s.players do
        if s.players[i].name == name then return s.players[i], s end
    end
    return nil, s
end
local function DeathAt(p, t)
    if not (p and t) then return nil end
    for i = 1, #p.deathInfo do
        local d = p.deathInfo[i]
        if math.abs(d.t - t) < 0.01 then return d end
    end
    return nil
end
local function Killer(d, name, boss, bare)
    local k = d.killer
    if not k then return T("proof.nokiller") end
    local out = format(T("proof.killer"), Spell(k))
    if (k.amount or 0) > 0 then out = out .. " " .. Short(k.amount) end
    local own = k.srcKey and (k.srcKey == boss or ns.bosses[k.srcKey] == boss)
    if not bare and k.src and k.src ~= name and not own then out = out .. format(T("proof.from"), Plain(k.src)) end
    return out
end
local function Before(d)
    local by, order = {}, {}
    for i = 1, #(d.recent or {}) do
        local e = d.recent[i]
        if e ~= d.killer and d.t - e.t <= RECENT and (e.amount or 0) > 0 then
            local g = by[e.spell]
            if not g then
                g = { e = e, n = 0, sum = 0 }
                by[e.spell] = g
                order[#order + 1] = g
            end
            g.n = g.n + 1
            g.sum = g.sum + e.amount
        end
    end
    if #order == 0 then return nil end
    tsort(order, function(a, b) return a.sum > b.sum end)
    local g = order[1]
    return format(T("proof.before"), format(T("proof.hitsum"), Spell(g.e), g.n, Short(g.sum)), RECENT)
end
local function Guard(p, d)
    local list = ns.defensives or {}
    local last, used = {}, nil
    for k = 1, #(p.guardT or {}) do
        local t, id = p.guardT[k], p.guardId[k]
        if list[id] and t <= d.t then
            if d.t - t <= GUARD then used = { id = id, ago = d.t - t } end
            last[id] = t
        end
    end
    if used then return format(T("proof.guard.used"), Link(used.id, nil), Dec(used.ago)) end
    local ready = {}
    for id, t in pairs(last) do
        if t + list[id].cd <= d.t and (ns.saving or {})[id] then ready[#ready + 1] = id end
    end
    if #ready == 0 then return nil end
    tsort(ready)
    return format(T("proof.guard.ready"), Link(ready[1], nil))
end
local function DeathChain(fight, p, d, name, bare)
    if not d then return { T("proof.nodeath") } end
    local first = Killer(d, name, fight.boss, bare) .. " " .. format(T("proof.at"), Clock(d.t - fight.from))
    local second
    if d.mc then
        second = format(T("proof.mc"), Plain(d.mc.by))
    elseif d.scripted then
        second = T("proof.scripted")
    else
        second = (p and Guard(p, d)) or Before(d)
    end
    return { first, second }
end
local function Times(fight, events)
    local parts = {}
    for k = 1, #events do
        local t = events[k].t
        if t and #parts < TIMES then parts[#parts + 1] = Clock(t - fight.from) end
    end
    if #parts == 0 then return nil end
    local more = #events > TIMES and format(T("proof.more"), #events - TIMES) or ""
    return format(T("proof.times"), concat(parts, ", ") .. more)
end
local function IdOf(s, sp)
    local key = ns.SpellKey(sp)
    return (s and s.spellIds and key and s.spellIds[key]) or key
end
local function HitWhat(rule, p, s, shed)
    local parts, hung, held = {}, {}, {}
    for i = 1, #(shed or {}) do hung[ns.SpellKey(shed[i].spell)] = shed[i].hangs end
    local spells = rule.spells or {}
    for i = 1, #spells do
        local sp = ns.SpellKey(spells[i])
        local n = p and p.hits and p.hits[sp] and #p.hits[sp] or 0
        if hung[sp] then
            local cure = ns.Penalties.CureText(hung[sp])
            held[#held + 1] = (#spells > 1 and (Link(IdOf(s, sp), nil) .. ": ") or "") .. ns.Penalties.ShedText(hung[sp])
                .. (cure and (", " .. cure) or "")
        elseif n > 0 then
            parts[#parts + 1] = format(T("proof.xn"), Link(IdOf(s, sp), nil), n)
        end
    end
    if #held > 0 then
        if #parts > 0 then held[#held + 1] = format(T("proof.hit"), concat(parts, ", ")) end
        return concat(held, "; ")
    end
    if #parts == 0 then parts[1] = Link(IdOf(s, spells[1]), nil) end
    return format(T("proof.hit"), concat(parts, ", "))
end
local function Chain(fight, hit, p, s)
    local rule = hit.rule
    local kind = rule.kind
    local ev1 = hit.events[1]
    local info = ev1 and ev1.info or {}
    if info.manual then return { T("proof.manual") } end
    local out = {}
    if kind == "hit" then
        out[1] = HitWhat(rule, p, s, hit.shed)
    elseif kind == "chased" then
        out[1] = format(T("proof.chased"), Plain(ns.NpcName(ns.NpcKeyOf(rule.npc))), #hit.events)
    elseif kind == "mccast" then
        local seen, names = {}, {}
        for k = 1, #hit.events do
            local sp = hit.events[k].info and hit.events[k].info.note
            if sp and not seen[sp] then
                seen[sp] = true
                names[#names + 1] = Link(IdOf(s, sp), nil)
            end
        end
        out[1] = format(T("proof.mccast"), concat(names, ", "))
    elseif kind == "expect" then
        local duty = rule.by and p and p.class and rule.by[p.class] or {}
        local what = rule.what == "dispel" and "proof.duty.dispel" or "proof.duty"
        out[1] = format(T(what), Link(duty.id, nil), info.have or 0, rule.min or 1)
        if rule.what == "dispel" and rule.removes then
            out[2] = format(T("proof.removes"), Plain(ns.SpellName(ns.SpellKey(rule.removes))))
        end
        return out
    elseif kind == "mcweapon" then
        for k = 1, min(1, #hit.events) do
            local c = hit.events[k].info and hit.events[k].info.ctl
            if c then
                out[#out + 1] = format(T("proof.ctl"), Clock(c.t - fight.from), #(c.hits or {}),
                    Short((c.swing or 0) + (c.abil or 0)))
                if #(c.kills or {}) > 0 then out[#out + 1] = format(T("proof.ctl.kills"), concat(c.kills, ", ")) end
            end
        end
        if #out == 0 then out[1] = format(T("proof.ctl.bare"), Link(rule.aura, nil)) end
        return out
    elseif kind == "mindmg" then
        local names = {}
        for i = 1, #(rule.targets or {}) do names[i] = ns.NpcName(ns.NpcKeyOf(rule.targets[i])) end
        out[1] = format(T("proof.mindmg"), Plain(concat(names, ", ")), Short(info.amount or 0),
            Short(info.need or 0))
        return out
    elseif kind == "mindps" then
        out[1] = format(T("proof.mindps"), Short(info.amount or 0), Short(info.need or 0))
        return out
    elseif kind == "earlypull" and info.early then
        out[1] = format(T("proof.earlypull"), Dec(info.early), info.sec or 0, Plain(info.setter))
        return out
    else
        out[1] = T("proof.rule")
    end
    local times = Times(fight, hit.events)
    if times then out[#out] = out[#out] .. " " .. times end
    return out
end
local function Compose(head, chain)
    local list = {}
    for i = 1, LINKS do
        if chain[i] and chain[i] ~= "" then list[#list + 1] = chain[i] end
    end
    if #list == 0 then return { head } end
    local out = { head .. " —" }
    for i = 1, #list do out[#out + 1] = list[i] .. (i < #list and ";" or "") end
    return out
end
local function DeathClause(fight, head, p, d, name)
    local out = Compose(head, DeathChain(fight, p, d, name))
    if #concat(out, " ") > LIMIT then out = Compose(head, DeathChain(fight, p, d, name, true)) end
    return out
end
local function Head(name, rule, gp, done)
    local reason = ns.Penalties and ns.Penalties.Reason(rule) or rule.key
    return format(T(done and "proof.head.done" or "proof.head"), TAG, Plain(name), Plain(reason), gp)
end
local function Sum(events)
    local issued = ns.GetDB().gpIssued or {}
    local gp, done, first = 0, #events > 0, nil
    for k = 1, #events do
        local ev = events[k]
        gp = gp + (ev.gp or 0)
        if not issued[ev.key] then done = false end
        if ev.t and (not first or ev.t < first) then first = ev.t end
    end
    return gp, done, first
end
local function HitTexts(fight, name, p, s, hit, out)
    local rule = hit.rule
    if DEATH_KINDS[rule.kind] or rule.kind == "killer" or rule.kind == "caused" then
        for k = 1, #hit.events do
            local ev = hit.events[k]
            local gp, done = Sum({ ev })
            local chain, head = nil, Head(name, rule, gp, done)
            if ev.info and ev.info.manual then
                chain = { T("proof.manual") }
            elseif rule.kind == "killer" or rule.kind == "caused" then
                local victim = ev.info and ev.info.victim
                local vp = victim and Player(fight, victim, s)
                local d = DeathAt(vp, ev.t)
                chain = { format(T("proof.victim"), Plain(victim)) }
                if ev.t then chain[1] = chain[1] .. " " .. format(T("proof.at"), Clock(ev.t - fight.from)) end
                if d then chain[2] = Killer(d, victim, fight.boss) end
                if rule.kind == "caused" then
                    chain[1] = format(T("proof.caused"), Plain(victim)) .. (ev.t and (" " .. format(T("proof.at"), Clock(ev.t - fight.from))) or "")
                    local dep = ev.info and ev.info.dep
                    if dep and ns.DeathDeps then chain[2] = Plain(ns.DeathDeps.What(dep)) end
                end
            end
            out[#out + 1] = chain and Compose(head, chain) or DeathClause(fight, head, p, DeathAt(p, ev.t), name)
        end
        return
    end
    local gp, done = Sum(hit.events)
    local head = Head(name, rule, gp, done)
    if gp == 0 and ns.Penalties and ns.Penalties.Grade(hit) == "yellow" then
        head = format(T("proof.head.maybe"), TAG, Plain(name), Plain(ns.Penalties.Reason(rule)))
    end
    out[#out + 1] = Compose(head, Chain(fight, hit, p, s))
end
local function DeathHit(hits, t)
    for i = 1, #(hits or {}) do
        local hit = hits[i]
        if DEATH_KINDS[hit.rule.kind] then
            for k = 1, #hit.events do
                local ev = hit.events[k]
                if ev.t and math.abs(ev.t - t) < 0.01 then return hit, ev end
            end
        end
    end
    return nil, nil
end
function Proof.Clauses(ask)
    local out = {}
    if not (ask and ask.fight and ask.name) then return out end
    local fight, name = ask.fight, ask.name
    local p, s = Player(fight, name, ask.s)
    local hits = ask.hits or {}
    if ask.deaths then
        local list = p and p.deathInfo or {}
        for i = 1, min(DEATHS_MAX, #list) do
            local d = list[i]
            local hit, ev = DeathHit(hits, d.t)
            local head
            if hit then
                local gp, done = Sum({ ev })
                head = Head(name, hit.rule, gp, done)
            else
                head = format(T("proof.head.death"), TAG, Plain(name))
            end
            out[#out + 1] = DeathClause(fight, head, p, d, name)
        end
        for i = 1, #hits do
            if not DEATH_KINDS[hits[i].rule.kind] then HitTexts(fight, name, p, s, hits[i], out) end
        end
        return out
    end
    for i = 1, #hits do HitTexts(fight, name, p, s, hits[i], out) end
    return out
end
local function Words(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        while i <= n and text:byte(i) == 32 do i = i + 1 end
        if i > n then break end
        local j = i
        while j <= n and text:byte(j) ~= 32 do
            local _, b = text:find(LINK, j)
            j = b and b + 1 or j + 1
        end
        out[#out + 1] = text:sub(i, j - 1)
        i = j
    end
    return out
end
local function Cut(s, limit)
    s = s:gsub("|c%x%x%x%x%x%x%x%x|H[^|]*|h([^|]*)|h|r", "%1"):gsub("|", "")
    if #s <= limit then return s end
    local k = limit
    while k > 0 do
        local b = s:byte(k + 1)
        if not b or b < 128 or b >= 192 then break end
        k = k - 1
    end
    return s:sub(1, k)
end
local function Greedy(words, limit)
    local parts, cur = {}, nil
    for i = 1, #words do
        local w = words[i]
        if cur and #cur + 1 + #w > limit then
            parts[#parts + 1] = cur
            cur = TAG .. " " .. w
        else
            cur = cur and (cur .. " " .. w) or w
        end
        if #cur > limit then cur = Cut(cur, limit) end
    end
    if cur then parts[#parts + 1] = cur end
    return parts
end
local function Links(s)
    local _, n = s:gsub("|H", "")
    return n
end
local function Even(text, limit)
    local words = Words(text)
    local parts = Greedy(words, limit)
    if #parts < 2 then return parts end
    local links = Links(text)
    for t = math.ceil(#text / #parts) + STEP, limit, STEP do
        local try = Greedy(words, t)
        if #try == #parts and Links(concat(try, " ")) == links then return try end
    end
    return parts
end
local function Pack(clauses, limit)
    local parts, cur = {}, nil
    for i = 1, #clauses do
        local c = clauses[i]
        if not cur then
            cur = c
        elseif #cur + 1 + #c <= limit then
            cur = cur .. " " .. c
        else
            parts[#parts + 1] = cur
            cur = TAG .. " " .. c
        end
        if #cur > limit then
            local sub = Even(cur, limit)
            for k = 1, #sub - 1 do parts[#parts + 1] = sub[k] end
            cur = sub[#sub]
        end
    end
    if cur then parts[#parts + 1] = cur end
    return parts
end
function Proof.Split(text, limit)
    limit = limit or LIMIT
    if type(text) == "string" then return Even(text, limit) end
    local whole = concat(text, " ")
    local even = Even(whole, limit)
    local packed = Pack(text, limit)
    if #packed <= #even then return packed end
    return even
end
function Proof.Texts(ask)
    local out = {}
    local list = Proof.Clauses(ask)
    for i = 1, #list do out[i] = concat(list[i], " ") end
    return out
end
function Proof.Messages(ask)
    local out = {}
    local list = Proof.Clauses(ask)
    for i = 1, #list do
        local parts = Proof.Split(list[i])
        for k = 1, #parts do out[#out + 1] = parts[k] end
    end
    return out
end
function Proof.Ask(fight, name, hits, test, deaths)
    local list = {}
    for i = 1, #(hits or {}) do
        if test(hits[i]) then list[#list + 1] = hits[i] end
    end
    if #list == 0 and not deaths then return nil end
    return { fight = fight, name = name, hits = list, deaths = deaths }
end
function Proof.IsDeath(hit)
    return DEATH_KINDS[hit.rule.kind] == true
end
function Proof.ByKind(kind)
    return function(hit) return hit.rule.kind == kind end
end
function Proof.ByKey(key)
    return function(hit) return hit.rule.key == key end
end
function Proof.BySpell(what)
    return function(hit)
        local rule = hit.rule
        if rule.npc and ns.NpcKeyOf(rule.npc) == what then return true end
        for i = 1, #(rule.spells or {}) do
            if ns.SpellKey(rule.spells[i]) == what then return true end
        end
        return false
    end
end
function Proof.Channel()
    local db = ns.GetDB()
    local c = db and db.gp and db.gp.proof
    return KNOWN[c or ""] and c or "RAID"
end
function Proof.SetChannel(c)
    if not KNOWN[c or ""] then return false end
    ns.GetDB().gp.proof = c
    return true
end
function Proof.Label(c)
    return T("proof.ch." .. tostring(c))
end
function Proof.Route(want, target)
    local raid = (GetNumRaidMembers() or 0) > 0
    local party = raid or (GetNumPartyMembers() or 0) > 0
    if want == "RAID" then
        if raid then return "RAID", nil, nil end
        if party then return "PARTY", nil, nil end
        return nil, nil, "proof.err.solo"
    elseif want == "PARTY" then
        if party then return "PARTY", nil, nil end
        return nil, nil, "proof.err.solo"
    elseif want == "GUILD" or want == "OFFICER" then
        if IsInGuild() then return want, nil, nil end
        return nil, nil, "proof.err.guild"
    elseif want == "WHISPER" then
        if target and target ~= "" then return "WHISPER", target, nil end
        return nil, nil, "proof.err.target"
    end
    return "SAY", nil, nil
end
local function SendOne()
    local m = tremove(queue, 1)
    if not m then return end
    SendChatMessage(m.text, m.chat, nil, m.target)
    nextAt = GetTime() + GAP
end
pump:SetScript("OnUpdate", function(self)
    if not queue[1] then
        self:Hide()
        return
    end
    if GetTime() >= nextAt then SendOne() end
end)
function Proof.Pending()
    return #queue
end
local function Forget(now)
    for k, t in pairs(sentAt) do
        if now - t >= DUP then sentAt[k] = nil end
    end
end
function Proof.Send(ask, want)
    local msgs = Proof.Messages(ask)
    if #msgs == 0 then return 0, "empty" end
    want = want or Proof.Channel()
    local chat, target, err = Proof.Route(want, ask.name)
    if err then
        ns.Print(T(err))
        return 0, err
    end
    local now = GetTime()
    Forget(now)
    local key = chat .. "|" .. (target or "") .. "|" .. msgs[1]
    if sentAt[key] then
        ns.Print(T("proof.err.dup"))
        return 0, "dup"
    end
    if #queue + #msgs > QUEUE then
        ns.Print(T("proof.err.busy"))
        return 0, "busy"
    end
    sentAt[key] = now
    if chat ~= want then ns.Print(format(T("proof.fallback"), Proof.Label(want), Proof.Label(chat))) end
    for i = 1, #msgs do queue[#queue + 1] = { text = msgs[i], chat = chat, target = target } end
    if now >= nextAt then SendOne() end
    if queue[1] then pump:Show() end
    return #msgs, nil
end
