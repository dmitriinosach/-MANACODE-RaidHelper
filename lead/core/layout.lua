local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local L = {
    GROUPS = 8,
    SEATS = 5,
}
ns.Layout = L
function L.Work(size)
    return math.floor((size or 25) / 5)
end
local function take(room, from, last, step)
    for g = from, last, step do
        if room[g] > 0 then
            room[g] = room[g] - 1
            return g
        end
    end
end
function L.Groups(tpl)
    local out, room = {}, {}
    for g = 1, L.GROUPS do room[g] = L.SEATS end
    local slots = tpl and tpl.slots or {}
    for i, s in ipairs(slots) do
        local g = tonumber(s.grp)
        if g and g >= 1 and g <= L.GROUPS then
            out[i] = g
            room[g] = room[g] - 1
        end
    end
    local heal = math.max(1, L.Work(tpl and tpl.size))
    for i, s in ipairs(slots) do
        if not out[i] and s.role == "tank" then
            out[i] = take(room, 1, L.GROUPS, 1) or 1
        end
    end
    for i, s in ipairs(slots) do
        if not out[i] and s.role == "heal" then
            out[i] = take(room, heal, 1, -1) or take(room, heal + 1, L.GROUPS, 1) or heal
        end
    end
    for i in ipairs(slots) do
        if not out[i] then out[i] = take(room, 1, L.GROUPS, 1) or L.GROUPS end
    end
    return out
end
function L.Ghosts(tpl, taken)
    local out = {}
    for g = 1, L.GROUPS do out[g] = {} end
    for i, g in ipairs(L.Groups(tpl)) do
        if not taken[i] then
            local list = out[g]
            list[#list + 1] = i
        end
    end
    return out
end
function L.Sort(list)
    local seats, count, ops = {}, {}, {}
    for g = 1, L.GROUPS do count[g] = 0 end
    for k, m in ipairs(list) do
        seats[k] = { key = m.key, sub = m.sub, want = m.want }
        count[m.sub] = (count[m.sub] or 0) + 1
    end
    local moved = true
    while moved do
        moved = false
        for _, m in ipairs(seats) do
            local t = m.want
            if t and t ~= m.sub then
                if count[t] < L.SEATS then
                    ops[#ops + 1] = { kind = "move", a = m.key, g = t }
                    count[m.sub] = count[m.sub] - 1
                    count[t] = count[t] + 1
                    m.sub = t
                    moved = true
                else
                    local x
                    for _, o in ipairs(seats) do
                        if o.sub == t and o.want ~= t then
                            if o.want == m.sub then
                                x = o
                                break
                            end
                            x = x or o
                        end
                    end
                    if x then
                        ops[#ops + 1] = { kind = "swap", a = m.key, b = x.key }
                        x.sub, m.sub = m.sub, t
                        moved = true
                    end
                end
            end
        end
    end
    return ops
end
