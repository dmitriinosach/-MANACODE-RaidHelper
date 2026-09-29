local _, ns = ...
ns.deathDeps = {
    hold = 5,
    tank = 10,
    lead = 15,
    quiet = 30,
    range = 30,
    posGap = 2,
    posHold = 10,
    by = {
        Disease = { PRIEST = true, PALADIN = true, SHAMAN = true },
        Poison = { DRUID = true, PALADIN = true, SHAMAN = true },
        Magic = { PRIEST = true, PALADIN = true },
        Curse = { MAGE = true, DRUID = true },
    },
}
