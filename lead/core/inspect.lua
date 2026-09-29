local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local I = {}
ns.Inspect = I
local STEP = 2
local TIMEOUT = 4
local FRESH = 600
local INSPECT_RANGE = 1
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
local pending, pendingAt, lastAsked
local acc = 0
hooksecurefunc("NotifyInspect", function(unit) lastAsked = unit end)
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
    return key
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
    local main = specOfGroup(m.class, active, p.spec)
    if main and canWrite(p.specSrc) then p.spec, p.specSrc = main, "inspect" end
    if groups > 1 then
        local other = specOfGroup(m.class, active == 1 and 2 or 1, p.off)
        if other and other ~= p.spec and canWrite(p.offSrc) then p.off, p.offSrc = other, "inspect" end
    end
    p.ilvl = avgIlvl(m.unit) or p.ilvl
    p.inspectedAt = time()
end
local function nextTarget()
    local now = time()
    for _, m in ipairs(ns.Session.Roster()) do
        local p = ns.Session.Player(m.name)
        local stale = not p.inspectedAt or now - p.inspectedAt > FRESH
        if stale and m.online and m.unit and not UnitIsUnit(m.unit, "player")
            and CanInspect(m.unit) and CheckInteractDistance(m.unit, INSPECT_RANGE) then
            return m
        end
    end
end
local function busy()
    if InCombatLockdown() then return true end
    if InspectFrame and InspectFrame:IsShown() then return true end
    return false
end
local ticker = ns.NewFrame("Frame")
ticker:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < STEP then return end
    acc = 0
    if not ns.Session.Active() or busy() then return end
    if pending and GetTime() - pendingAt < TIMEOUT then return end
    pending = nil
    local m = nextTarget()
    if not m then return end
    pending, pendingAt = m, GetTime()
    NotifyInspect(m.unit)
end)
local ev = ns.NewFrame("Frame")
ns.Listen(ev, "INSPECT_TALENT_READY")
ev:SetScript("OnEvent", function()
    local m = pending
    if not m then return end
    pending = nil
    if lastAsked ~= m.unit or UnitName(m.unit) ~= m.name then return end
    apply(m)
    if not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
    ns.Session.Changed()
end)
function I.Ilvl(name)
    return ns.Session.Player(name).ilvl
end
