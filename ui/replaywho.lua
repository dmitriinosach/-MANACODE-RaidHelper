local _, ns = ...
local format, floor = string.format, math.floor
local Kit = ns.Kit
local Who = {}
ns.ReplayWho = Who
function Who.Name(name, class)
    class = class or ns.Encounters.ClassOf(name)
    if not class then return name end
    local r, g, b = Kit.ClassColor(class)
    return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), name)
end
function Who.List(names, skip, limit)
    limit = limit or 5
    local out, n = {}, 0
    for i = 1, #names do
        if names[i] ~= skip then
            n = n + 1
            if n <= limit then out[#out + 1] = Who.Name(names[i]) end
        end
    end
    if n == 0 then return nil end
    local text = table.concat(out, ", ")
    return n > limit and format(ns.T("rep.f.more"), text, n - limit) or text
end
function Who.Use(by, names, skip)
    local actor = Who.Name(by)
    local target = Who.List(names, skip)
    return target and format(ns.T("rep.mk.to"), actor, target) or actor
end
function Who.Row(text, time)
    return { kind = "row", left = text, right = time, tone = "dim" }
end
