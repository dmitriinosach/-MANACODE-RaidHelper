local _, ns = ...
local Deaths = {}
ns.SummaryDeaths = Deaths
local SpellKey = ns.SpellKey
local function DropFake(s, fight)
    for i = 1, #s.players do
        local p = s.players[i]
        local at, info = {}, {}
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            if ns.Encounters.RealDeath(fight, p.name, d.t) then
                info[#info + 1] = d
                at[#at + 1] = d.t
            end
        end
        p.deathInfo, p.deathAt = info, at
    end
end
local function DropScripted(s, boss)
    local quiet = {}
    for i = 1, #s.players do
        local p = s.players[i]
        for k = 1, #p.deathInfo do
            local d = p.deathInfo[k]
            if not d.killer then
                quiet[#quiet + 1] = d
            elseif ns.Deaths.ByScript(boss, d.killer.id) then
                d.scripted = true
            end
        end
    end
    ns.Deaths.MarkWaves(quiet, #s.players)
    for i = 1, #s.players do
        local p = s.players[i]
        local at, info = {}, {}
        p.scripted = 0
        for k = 1, #p.deathInfo do
            if p.deathInfo[k].scripted then
                p.scripted = p.scripted + 1
            else
                info[#info + 1] = p.deathInfo[k]
                at[#at + 1] = p.deathInfo[k].t
            end
        end
        p.deathInfo, p.deathAt = info, at
    end
end
local function Unseated(s, p, t, win)
    for i = 1, #s.badges do
        local outs = s.badges[i].kind == "vehicle" and p.badges[i].outs
        for k = 1, outs and #outs or 0 do
            local gap = t - (s.from + outs[k])
            if gap >= 0 and gap <= win then return true end
        end
    end
    return false
end
Deaths.Unseated = Unseated
local function DeathFits(s, bd, p, d, spells, srcs)
    local killer = d.killer
    if bd.spells or bd.srcs then
        if not (killer and ((killer.key and spells[killer.key]) or (killer.srcKey and srcs[killer.srcKey]))) then
            return false
        end
    end
    if bd.phases then
        local key = s.phases and ns.Phases.At(s.phases, d.t - s.from)
        local hit = false
        for k = 1, #bd.phases do
            if bd.phases[k] == key then hit = true end
        end
        if not hit then return false end
    end
    return not (bd.skipRide and Unseated(s, p, d.t, bd.skipRide))
end
Deaths.DeathFits = DeathFits
local function PoolKilled(bd, d)
    if d.tail then return false end
    local sum = {}
    for k = 1, #(d.recent or {}) do
        local e = d.recent[k]
        if e.key and d.t - e.t <= bd.pool then sum[e.key] = (sum[e.key] or 0) + (e.amount or 0) end
    end
    local want = SpellKey(bd.spell)
    local mine = sum[want]
    if not mine then return false end
    if d.killer and d.killer.key == want then return true end
    for key, v in pairs(sum) do
        if key ~= want and v > mine then return false end
    end
    return true
end
function Deaths.PoolGrade(bd, p)
    for k = 1, #p.deathInfo do
        if PoolKilled(bd, p.deathInfo[k]) then return "red" end
    end
    return "yellow"
end
local function DeathBadges(s)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "hit" and bd.pool then
            for k = 1, #s.players do
                local p = s.players[k]
                local st = p.badges[i]
                if st.n > 0 then st.grade = Deaths.PoolGrade(bd, p) end
                if st.n > 0 and bd.red and (st.peak or 0) >= bd.red then st.grade = "red" end
            end
        end
        if bd.kind == "hit" and bd.tank then
            for k = 1, #s.players do
                local p = s.players[k]
                if p.role == "tank" and p.badges[i].n > 0 then p.badges[i].grade = bd.tank end
            end
        end
        if bd.kind == "ticks" then
            for k = 1, #s.players do
                local st = s.players[k].badges[i]
                local last
                for t = 1, #(st.ticks or {}) do
                    local ts = st.ticks[t]
                    if not last or ts - last > (bd.gap or 5) then
                        st.n = st.n + 1
                        st.times[#st.times + 1] = ts - s.from
                    end
                    last = ts
                end
                st.ticks = nil
            end
        end
        if bd.kind == "killer" then
            local spells = {}
            ns.SpellSet(bd.spells, spells)
            s.icons[i] = bd.id
            for k = 1, #s.players do
                local victim = s.players[k]
                for d = 1, #victim.deathInfo do
                    local killer = victim.deathInfo[d].killer
                    local kp = killer and killer.src and killer.src ~= victim.name
                        and killer.key and spells[killer.key] and s.byName[killer.src]
                    if kp then
                        local st = kp.badges[i]
                        st.n = st.n + 1
                        st.times[#st.times + 1] = victim.deathInfo[d].t - s.from
                        st.notes[#st.notes + 1] = victim.name
                    end
                end
            end
        end
        if bd.kind == "death" then
            local spells, srcs = {}, {}
            ns.SpellSet(bd.spells, spells)
            ns.NpcSet(bd.srcs, srcs)
            s.icons[i] = bd.id
            for k = 1, #s.players do
                local p = s.players[k]
                local st = p.badges[i]
                for d = 1, #p.deathInfo do
                    local info = p.deathInfo[d]
                    if DeathFits(s, bd, p, info, spells, srcs) then
                        st.n = st.n + 1
                        st.times[#st.times + 1] = info.t - s.from
                        if not info.tail then st.grade = ns.DeathGrade.Worse(st.grade, info.grade) end
                    end
                end
            end
        end
        if bd.notank then
            for k = 1, #s.players do
                local st = s.players[k].role == "tank" and s.players[k].badges[i]
                if st then st.n, st.hits, st.amount, st.times, st.grade = 0, 0, 0, {}, nil end
            end
        end
    end
end
Deaths.DropFake = DropFake
Deaths.DropScripted = DropScripted
Deaths.DeathBadges = DeathBadges
