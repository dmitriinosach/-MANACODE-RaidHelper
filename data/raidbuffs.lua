local _, ns = ...
local DK, DRU, HUN, MAG = "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE"
local PAL, PRI, ROG, SHA = "PALADIN", "PRIEST", "ROGUE", "SHAMAN"
local LOCK, WAR = "WARLOCK", "WARRIOR"
ns.raidBuffs = {
    rows = {
        { key = "buff", groups = {
            { key = "pal", bless = true, items = {
                { key = "kings", src = { { cls = PAL, id = 25898 } }, auras = { 25898, 20217, 69378, 72586 } },
                { key = "might", need = "phys", src = { { cls = PAL, id = 48934 } }, auras = { 48934, 48932, 47436 } },
                { key = "wisdom", need = "mana", src = { { cls = PAL, id = 48938 } }, auras = { 48938, 48936, 58777 } },
                { key = "sanct", extra = true, src = { { cls = PAL, tree = 2, id = 25899 } }, auras = { 25899, 20911 } },
            } },
            { key = "priest", items = {
                { key = "stam", src = { { cls = PRI, id = 48162 } }, auras = { 48162, 48161, 69377, 48102 } },
                { key = "spirit", need = "spell", src = { { cls = PRI, tree = 1, id = 48074 } },
                    auras = { 48074, 48073, 54424, 48104 } },
            } },
            { key = "druid", items = {
                { key = "wild", src = { { cls = DRU, id = 48470 } }, auras = { 48470, 48469, 69381, 72588 } },
            } },
            { key = "mage", items = {
                { key = "int", need = "mana", src = { { cls = MAG, id = 43002 } },
                    auras = { 43002, 42995, 61316, 61024, 54424, 48100 } },
            } },
            { key = "melee", items = {
                { key = "meleeHaste", src = { { cls = DK, tree = 2, id = 55610 }, { cls = SHA, id = 8512, party = true } } },
                { key = "apPct", src = { { cls = DK, tree = 1, id = 53138 }, { cls = HUN, tree = 2, id = 19506 },
                    { cls = SHA, tree = 2, id = 30809 } } },
                { key = "meleeCrit", src = { { cls = DRU, tree = 2, id = 17007 }, { cls = WAR, tree = 2, id = 29801 } } },
            } },
            { key = "spell", items = {
                { key = "spellPower", src = { { cls = SHA, tree = 1, id = 57722, party = true },
                    { cls = SHA, id = 58656, party = true }, { cls = LOCK, tree = 2, id = 47240 } } },
                { key = "spellHaste", src = { { cls = SHA, id = 3738, party = true } } },
                { key = "spellCrit", src = { { cls = DRU, tree = 1, id = 24907 }, { cls = SHA, tree = 1, id = 51470 } } },
            } },
            { key = "all", items = {
                { key = "haste", src = { { cls = DRU, tree = 1, id = 48396 }, { cls = PAL, tree = 3, id = 53648 } } },
                { key = "damage", src = { { cls = HUN, tree = 1, id = 34460 }, { cls = PAL, tree = 3, id = 31869 },
                    { cls = MAG, tree = 1, id = 31583 } } },
            } },
            { key = "heal", items = {
                { key = "healTaken", src = { { cls = DRU, tree = 3, id = 33891 }, { cls = PAL, tree = 2, id = 20140 } } },
                { key = "replenish", src = { { cls = PRI, tree = 3, id = 48160 }, { cls = PAL, tree = 3, id = 31878 },
                    { cls = HUN, tree = 3, id = 53292 }, { cls = LOCK, tree = 3, id = 54118 }, { cls = MAG, tree = 3, id = 44561 } } },
            } },
        } },
        { key = "debuff", groups = {
            { key = "phys", items = {
                { key = "armorMajor", src = { { cls = WAR, id = 47467 }, { cls = ROG, id = 8647 } } },
                { key = "armorMinor", src = { { cls = DRU, id = 770 }, { cls = LOCK, id = 50511 } } },
                { key = "physTaken", src = { { cls = WAR, tree = 1, id = 29859 }, { cls = ROG, tree = 2, id = 58413 } } },
            } },
            { key = "spell", items = {
                { key = "spellTaken", src = { { cls = DK, tree = 3, id = 51161 }, { cls = DRU, tree = 1, id = 48511 },
                    { cls = LOCK, id = 47865 } } },
                { key = "spellHitTaken", src = { { cls = PRI, tree = 3, id = 33198 }, { cls = DRU, tree = 1, id = 33602 } } },
            } },
            { key = "crit", items = {
                { key = "critTaken", src = { { cls = PAL, tree = 3, id = 54499 }, { cls = SHA, tree = 1, id = 30708 },
                    { cls = ROG, tree = 1, id = 58410 } } },
            } },
        } },
        { key = "raidcd", count = true, groups = {
            { key = "hero", items = {
                { key = "heroism", src = { { cls = SHA, id = 2825, ally = 32182 } } },
            } },
            { key = "rez", items = {
                { key = "battleRez", src = { { cls = DRU, id = 48477 }, { cls = DK, id = 61999 }, { cls = LOCK, id = 47883 } } },
            } },
            { key = "mana", items = {
                { key = "hymnHope", src = { { cls = PRI, id = 64901 } } },
                { key = "manaTide", src = { { cls = SHA, tree = 3, id = 16190, party = true } } },
                { key = "innervate", src = { { cls = DRU, id = 29166 } } },
            } },
            { key = "healCd", items = {
                { key = "divineHymn", src = { { cls = PRI, id = 64843 } } },
                { key = "tranquility", src = { { cls = DRU, id = 48447, party = true } } },
            } },
            { key = "def", items = {
                { key = "auraMastery", src = { { cls = PAL, tree = 1, id = 31821 } } },
                { key = "divineSacrifice", src = { { cls = PAL, tree = 2, id = 64205 } } },
            } },
        } },
        { key = "cd", count = true, groups = {
            { key = "save", items = {
                { key = "painSuppression", src = { { cls = PRI, tree = 1, id = 33206 } } },
                { key = "guardianSpirit", src = { { cls = PRI, tree = 2, id = 47788 } } },
                { key = "fearWard", src = { { cls = PRI, id = 6346 } } },
                { key = "handSacrifice", src = { { cls = PAL, id = 6940 } } },
                { key = "handProtection", src = { { cls = PAL, id = 10278 } } },
                { key = "layOnHands", src = { { cls = PAL, id = 48788 } } },
            } },
            { key = "dps", items = {
                { key = "powerInfusion", src = { { cls = PRI, tree = 1, id = 10060 } } },
                { key = "hysteria", src = { { cls = DK, tree = 1, id = 49016 } } },
            } },
            { key = "threat", items = {
                { key = "misdirection", src = { { cls = HUN, id = 34477 } } },
                { key = "tricks", src = { { cls = ROG, id = 57934 } } },
                { key = "shatter", src = { { cls = WAR, id = 64382 } } },
            } },
        } },
    },
    raid = {},
    bless = {},
    paladin = PAL,
}
for _, group in ipairs(ns.raidBuffs.rows[1].groups) do
    for _, it in ipairs(group.items) do
        if it.auras then
            local list = group.bless and ns.raidBuffs.bless or ns.raidBuffs.raid
            list[#list + 1] = { key = it.key, cls = it.src[1].cls, tree = it.src[1].tree, need = it.need,
                extra = it.extra, auras = it.auras }
        end
    end
end
local PHYS, CAST = { phys = true }, { spell = true, mana = true }
local HYB = { phys = true, mana = true }
ns.raidBuffs.need = {
    WARRIOR = { PHYS, PHYS, PHYS },
    ROGUE = { PHYS, PHYS, PHYS },
    DEATHKNIGHT = { PHYS, PHYS, PHYS },
    HUNTER = { HYB, HYB, HYB },
    MAGE = { CAST, CAST, CAST },
    WARLOCK = { CAST, CAST, CAST },
    PRIEST = { CAST, CAST, CAST },
    PALADIN = { CAST, HYB, HYB },
    SHAMAN = { CAST, HYB, CAST },
    DRUID = { CAST, PHYS, CAST },
}
