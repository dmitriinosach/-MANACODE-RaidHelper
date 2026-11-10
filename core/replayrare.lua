local _, ns = ...
local abs = math.abs
local R = {}
ns.ReplayRare = R
local function FromSummary(fight)
    local s = fight and ns.Summary and ns.Summary.Peek(fight)
    if not (s and s.players) then return nil end
    local tail
    for i = 1, #s.players do
        local info = s.players[i].deathInfo or {}
        for k = 1, #info do
            local d = info[k]
            if d.tail and d.t and (not tail or d.t < tail) then tail = d.t end
        end
    end
    local cause
    if ns.DeathDeps and not fight.killed then
        local ok, c = pcall(ns.DeathDeps.FirstCause, s, fight, nil)
        if ok then cause = c end
    end
    return tail and tail - fight.from, cause and cause.t - fight.from, cause and cause.who
end
local function Has(L, i, who)
    if L.fdWho[i] == who then return true end
    local all = L.fdAll and L.fdAll[i]
    for k = 1, all and #all or 0 do
        if all[k] == who then return true end
    end
    return false
end
function R.Mark(L, fight, out)
    out = out or {}
    for i = #out, 1, -1 do out[i] = nil end
    local D = ns.replayRare
    local set = {}
    for id, v in pairs(fight and D.bosses[fight.boss] or {}) do set[ns.SpellKey(id) or id] = v end
    local valkyr = ns.replayData and ns.replayData.valkyr and ns.replayData.valkyr.icon
    local tail, cause, who = FromSummary(fight)
    local n, best, bestD = 0, nil, nil
    for i = 1, L.nf or 0 do
        local kind, icon, t = L.fdKind[i], L.fdIcon[i], L.fdT[i]
        local id = type(icon) == "number" and icon or nil
        local rare = false
        if kind == "death" then
            rare = icon ~= "death" or not tail or t < tail
        elseif kind == "hero" then
            rare = true
        elseif kind == "phase" then
            rare = icon == "phase"
        elseif kind == "def" then
            local d = id and ns.defensives and ns.defensives[id]
            rare = d ~= nil and not d.item and d.cd >= D.defCd
        elseif kind == "boss" and id then
            local v = id == valkyr or set[ns.SpellKey(id) or id]
            rare = v == true or (v == "on" and L.fdWho[i] ~= false)
        end
        if rare then
            out[i] = true
            n = n + 1
        else
            out[i] = false
        end
        if cause then
            local dt = abs(t - cause)
            if dt <= D.near and (not bestD or dt < bestD or (dt == bestD and who and Has(L, i, who))) then
                best, bestD = i, dt
            end
        end
    end
    if best and not out[best] then
        out[best] = true
        n = n + 1
    end
    return out, n
end
