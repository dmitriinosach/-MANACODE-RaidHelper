local _, ns = ...
local SUBS = { SWING_MISSED = true, SPELL_MISSED = true, RANGE_MISSED = true }
local OVER = 3
local Parry = {}
ns.Parry = Parry
function Parry.Begin(s, fight)
    for i = 1, #s.badges do
        local bd = s.badges[i]
        if bd.kind == "parry" then
            local npcs = {}
            for k = 1, #(bd.names or {}) do npcs[ns.NpcKeyOf(bd.names[k]) or 0] = true end
            return { s = s, i = i, npcs = npcs, hits = {}, subs = SUBS, from = fight.from, to = fight.to }
        end
    end
    return nil
end
function Parry.Feed(st, ts, sub, srcName, dstKey, a1, a4)
    if ts < st.from or ts > st.to then return end
    if not (dstKey and st.npcs[dstKey] and srcName and st.s.byName[srcName]) then return end
    local swing = sub == "SWING_MISSED"
    if (swing and a1 or a4) ~= "PARRY" then return end
    local list = st.hits[srcName]
    if not list then
        list = {}
        st.hits[srcName] = list
    end
    list[#list + 1] = { t = ts, id = swing and 0 or (tonumber(a1) or 0) }
end
local function InPhase(s, phases, t)
    if not phases then return true end
    local key = s.phases and ns.Phases.At(s.phases, t - s.from)
    for k = 1, #phases do
        if phases[k] == key then return true end
    end
    return false
end
function Parry.Finish(st)
    local s, i = st.s, st.i
    local bd = s.badges[i]
    for name, list in pairs(st.hits) do
        local p = s.byName[name]
        if p and p.role ~= "tank" then
            local b = p.badges[i]
            local at = {}
            for k = 1, #list do
                local h = list[k]
                if InPhase(s, bd.phases, h.t) then
                    b.n = b.n + 1
                    b.times[#b.times + 1] = h.t - s.from
                    b.ids = b.ids or {}
                    b.cnt = b.cnt or {}
                    local j = at[h.id]
                    if not j then
                        j = #b.ids + 1
                        at[h.id] = j
                        b.ids[j], b.cnt[j] = h.id, 0
                    end
                    b.cnt[j] = b.cnt[j] + 1
                end
            end
            if b.n >= (bd.over or OVER) then b.grade = "yellow" end
        end
    end
    s.icons[i] = s.icons[i] or bd.id
    for k = 1, #s.blocks do
        local blk = s.blocks[k]
        if blk.def.kind == "parries" then
            blk.parry = {}
            for _, p in ipairs(s.players) do
                local b = p.badges[i]
                if b.n > 0 then
                    blk.by[p.name] = b.n
                    blk.total = blk.total + b.n
                    blk.parry[p.name] = { n = b.n, ids = b.ids, cnt = b.cnt, times = b.times, grade = b.grade }
                end
            end
        end
    end
end
