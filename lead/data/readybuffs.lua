local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local DRU, MAG, PAL, PRI = "DRUID", "MAGE", "PALADIN", "PRIEST"
ns.READY_RAID = {
    { key = "stam", cls = PRI, auras = { 48162, 48161 } },
    { key = "spirit", cls = PRI, tree = 1, need = "spell", auras = { 48074, 48073, 54424 } },
    { key = "shadow", cls = PRI, auras = { 48170, 48169, 48943 } },
    { key = "int", cls = MAG, need = "mana", auras = { 43002, 42995, 61316, 61024, 54424 } },
    { key = "wild", cls = DRU, auras = { 48470, 48469 } },
}
ns.READY_BLESS = {
    { key = "kings", auras = { 25898, 20217 } },
    { key = "might", need = "phys", auras = { 48934, 48932, 47436 } },
    { key = "wisdom", need = "mana", auras = { 48938, 48936, 58777 } },
    { key = "sanct", extra = true, auras = { 25899, 20911 } },
}
ns.READY_PALADIN = PAL
local PHYS, CAST = { phys = true }, { spell = true, mana = true }
local HYB = { phys = true, mana = true }
ns.READY_NEED = {
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
local AURA = { 48942, 54043, 19746, 32223, 48943, 48945, 48947, own = true, label = "aura" }
local INNER = { 48168 }
local FEL = { 47893 }
local WATER = { 57960 }
local ARMOR = { 43046, 43024 }
ns.READY_OWN = {
    bdk = { { 48263 } },
    fdk = { { 48266 } },
    uh = { { 48265 }, { 49222 } },
    hunt = { { 61847, 27044 } },
    HUNTER = { { 61847, 27044 } },
    fire = { { 43046 } },
    arc = { ARMOR },
    MAGE = { ARMOR },
    hpal = { { 20166, label = "seal" }, AURA },
    ppal = { { 31801, 53736, label = "seal" }, { 25780 }, AURA },
    rpal = { { 31801, 53736, 20375, label = "seal" }, AURA },
    PALADIN = { { 31801, 53736, 20375, 20166, label = "seal" }, AURA },
    disc = { INNER },
    holy = { INNER },
    sp = { INNER, { 15286 } },
    PRIEST = { INNER },
    rsham = { WATER },
    ele = { WATER },
    enh = { { 49281 } },
    SHAMAN = { { 57960, 49281 } },
    demo = { FEL },
    affli = { FEL },
    destro = { FEL },
    WARLOCK = { FEL },
}
ns.READY_ICON = { pot = 53755, food = 57399 }
