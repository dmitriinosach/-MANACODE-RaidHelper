local _, ns = ...
local tsort = table.sort
local max = math.max
local ceil = math.ceil
local MASS_WINDOW = 5
local MASS_SHARE = 0.6
local MASS_MIN = 5
local Deaths = {}
ns.Deaths = Deaths
Deaths.KILL_WINDOW = 3
Deaths.WIPE_SPAN = 30
function Deaths.Wiped(times, players, at)
    local need = max(MASS_MIN, ceil(players * MASS_SHARE))
    local n = 0
    for k = #times, 1, -1 do
        if at - times[k] > Deaths.WIPE_SPAN then break end
        n = n + 1
    end
    return n >= need
end
function Deaths.ByScript(boss, id)
    local list = boss and ns.scriptedKills and ns.scriptedKills[boss]
    local n = id and tonumber(id)
    return list ~= nil and n ~= nil and list[n] ~= nil
end
local function Earlier(a, b)
    return a.t < b.t
end
function Deaths.MarkWaves(quiet, players)
    tsort(quiet, Earlier)
    local need = max(MASS_MIN, ceil(players * MASS_SHARE))
    local lo = 1
    for hi = 1, #quiet do
        while quiet[hi].t - quiet[lo].t > MASS_WINDOW do lo = lo + 1 end
        if hi - lo + 1 >= need then
            for k = lo, hi do quiet[k].scripted = true end
        end
    end
end
