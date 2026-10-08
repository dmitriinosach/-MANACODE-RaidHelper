local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local I = {}
ns.Inspect = I
local MIN_ITEMS = 15
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
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
local function avgIlvl(unit)
    local sum, n = 0, 0
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        local lvl = link and ns.Compat.ItemLevel(link)
        if lvl then
            sum, n = sum + lvl, n + 1
        end
    end
    if n < MIN_ITEMS then return nil end
    return sum / n
end
local function canWrite(src)
    return (PRIORITY[src or ""] or 0) <= PRIORITY.inspect
end
local function apply(m)
    local p = ns.Session.Player(m.name)
    local groups = GetNumTalentGroups(true) or 1
    local active = GetActiveTalentGroup(true) or 1
    local main, tree = specOfGroup(m.class, active, p.spec)
    p.tree = tree
    if main and canWrite(p.specSrc) then p.spec, p.specSrc = main, "inspect" end
    if groups > 1 then
        local other = specOfGroup(m.class, active == 1 and 2 or 1, p.off)
        if other and other ~= p.spec and canWrite(p.offSrc) then p.off, p.offSrc = other, "inspect" end
    end
    p.ilvl = avgIlvl(m.unit) or p.ilvl
    p.inspectedAt = time()
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
    ns.Session.Changed()
end
if root.Specs then
    root.Specs.Want(I.Running)
    root.Specs.OnRead(read)
end
function I.Ilvl(name)
    return ns.Session.Player(name).ilvl
end
