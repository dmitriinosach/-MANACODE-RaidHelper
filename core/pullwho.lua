local _, ns = ...
local band = bit.band
local format = string.format
local F_PLAYER = ns.F.PLAYER
local F_BY_PLAYER = ns.F.BY_PLAYER
local PullWho = {}
ns.PullWho = PullWho
PullWho.SUB = "FW_PULLER"
local function Person(x)
    return x.owner or (not x.pet and x.src) or nil
end
local function Lead(firsts)
    for i = 1, #firsts do
        if not firsts[i].owner then return firsts[i] end
    end
    return firsts[1]
end
function PullWho.Decide(hit, firsts, touch)
    if not hit or not firsts or not firsts[1] then return hit end
    local who = hit.owner or (not hit.pet and hit.src) or nil
    for i = 1, #firsts do
        local f = firsts[i]
        f.pet = f.owner ~= nil
        if Person(f) == who then return hit end
    end
    local d = ns.pullWho
    local f = Lead(firsts)
    if f.t > hit.t - d.gap or f.t < hit.t - d.window then return hit end
    local person = Person(f)
    local tc = touch and person and touch[person]
    if tc and (tc.t < f.t - d.gap or tc.t > hit.t) then tc = nil end
    return { t = f.t, src = f.src, owner = f.owner, pet = f.owner ~= nil,
             spell = tc and tc.spell or nil, sid = tc and tc.sid or nil, body = (not tc) or nil,
             timer = hit.timer }
end
function PullWho.Who(pull)
    if pull.owner then return format(ns.T("pull.of"), pull.src, pull.owner) end
    if pull.pet then return format(ns.T("tl.pull.pet"), pull.src) end
    return pull.src
end
function PullWho.How(pull)
    if pull.body then return ns.T(pull.pet and "pull.aggro" or "pull.body") end
    return pull.spell or ns.T("tl.pull.melee")
end
function PullWho.Text(pull)
    return format(ns.T("sum.pull.tip"), PullWho.Who(pull), PullWho.How(pull))
end
function PullWho.Begin(fight)
    return { to = fight.from + ns.pullWho.window, firsts = {}, touch = {}, guid = nil }
end
function PullWho.First(pw, ts, srcName, owner, ago)
    if srcName and ts <= pw.to then
        pw.firsts[#pw.firsts + 1] = { t = ts - (tonumber(ago) or 0), src = srcName, owner = owner }
    end
end
function PullWho.Feed(pw, s, ts, sub, K, srcGUID, srcName, srcFlags, dstBoss, a1, a2)
    if s.pull or sub == PullWho.SUB or not dstBoss or not srcFlags or band(srcFlags, F_BY_PLAYER) == 0 then return end
    local pet = band(srcFlags, F_PLAYER) == 0
    if K.dmg or K.miss then
        s.pull = { t = ts, src = srcName, spell = (not K.swing) and a2 or nil, sid = (not K.swing) and tonumber(a1) or nil,
                   pet = pet }
        pw.guid = pet and srcGUID or nil
    elseif (sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED") and srcName then
        local tc = pw.touch[srcName]
        if not tc then
            tc = {}
            pw.touch[srcName] = tc
        end
        tc.t, tc.spell, tc.sid, tc.guid, tc.pet = ts, a2, tonumber(a1), srcGUID, pet
    end
end
function PullWho.Finish(pw, s, owners, pets)
    local hit = s.pull
    if not hit then return end
    local g = pw.guid
    if g then hit.owner = owners[g] or pets[g] end
    if not pw.firsts[1] then return end
    local touch = {}
    for name, tc in pairs(pw.touch) do
        local person = name
        if tc.pet then person = tc.guid and (owners[tc.guid] or pets[tc.guid]) end
        if person then touch[person] = tc end
    end
    s.pull = PullWho.Decide(hit, pw.firsts, touch)
end
