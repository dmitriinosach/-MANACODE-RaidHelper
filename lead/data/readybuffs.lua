local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local RB = root.raidBuffs
ns.READY_RAID = RB.raid
ns.READY_BLESS = RB.bless
ns.READY_PALADIN = RB.paladin
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
