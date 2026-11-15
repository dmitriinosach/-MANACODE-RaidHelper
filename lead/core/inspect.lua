local ADDON, root = ...
root = ManaCodeRaidHelper or root
root.Lead = root.Lead or {}
local ns = root.Lead
local I = {}
local PRIORITY = { hand = 3, inspect = 2, whisper = 1 }
local TABS = {
    DEATHKNIGHT = { "bdk", "fdk", "uh" },
    DRUID       = { "owl", "cat", "rdru" },
    HUNTER      = { "hunt", "hunt", "hunt" },
    MAGE        = { "arc", "fire", nil },
    PALADIN     = { "hpal", "ppal", "rpal" },
    PRIEST      = { "disc", "holy", "sp" },
    ROGUE       = { "combat", "combat", "combat" },
    SHAMAN      = { "ele", "enh", "rsham" },
    WARLOCK     = { "affli", "demo", "destro" },
    WARRIOR     = { nil, "fury", "pwar" },
}
local function specOfGroup(class, group, keep)
    local best, bestPts = nil, -1
    for t = 1, 3 do
        local _, _, pts = GetTalentTabInfo(t, true, nil, group)
        pts = pts or 0
        if pts > bestPts then best, bestPts = t, pts end
    end
    if bestPts <= 0 then return nil end
    local key = TABS[class] and TABS[class][best]
    if key == "cat" and keep == "bear" then key = "bear" end
    return key, best
end
local function canWrite(src)
    return (PRIORITY[src or ""] or 0) <= PRIORITY.inspect
end
local function apply(m)
    local p = ns.Session.Player(m.name)
    local groups = GetNumTalentGroups(true) or 1
    local active = GetActiveTalentGroup(true) or 1
    local main, tree = specOfGroup(m.class, active, p.spec)
    local other = groups > 1 and specOfGroup(m.class, active == 1 and 2 or 1, p.off) or nil
    if not (tree or other) then return end
    p = ns.Session.EditPlayer(m.name)
    p.tree = tree
    if main and canWrite(p.specSrc) then p.spec, p.specSrc = main, "inspect" end
    if other and other ~= p.spec and canWrite(p.offSrc) then p.off, p.offSrc = other, "inspect" end
end
function I.Running()
    if ns.Test.Active() then return false end
    local raid, party = ns.Compat.GroupSize()
    if raid > 0 then return ns.RaidCmd.Officer() end
    return party > 0 and IsPartyLeader() and true or false
end
local function read(unit, name)
    local m = ns.Session.Member(name)
    if not m or m.fake or not m.class then return end
    apply({ name = name, class = m.class, unit = unit })
    ns.Session.AutoPlace(name)
    ns.Session.Changed()
end
if root.Specs then
    root.Specs.Want(I.Running)
    root.Specs.OnRead(read)
end
