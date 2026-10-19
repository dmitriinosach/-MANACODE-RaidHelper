local _, ns = ...
local DRU, MAG, PAL, PRI = "DRUID", "MAGE", "PALADIN", "PRIEST"
ns.raidBuffs = {
    raid = {
        { key = "stam", cls = PRI, auras = { 48162, 48161, 69377, 48102 } },
        { key = "spirit", cls = PRI, tree = 1, need = "spell", auras = { 48074, 48073, 54424, 48104 } },
        { key = "shadow", cls = PRI, auras = { 48170, 48169, 48943 } },
        { key = "int", cls = MAG, need = "mana", auras = { 43002, 42995, 61316, 61024, 54424, 48100 } },
        { key = "wild", cls = DRU, auras = { 48470, 48469, 69381, 72588 } },
    },
    bless = {
        { key = "kings", auras = { 25898, 20217, 69378, 72586 } },
        { key = "might", need = "phys", auras = { 48934, 48932, 47436 } },
        { key = "wisdom", need = "mana", auras = { 48938, 48936, 58777 } },
        { key = "sanct", extra = true, auras = { 25899, 20911 } },
    },
    paladin = PAL,
}
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
