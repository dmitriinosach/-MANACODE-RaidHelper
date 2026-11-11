local _, ns = ...
ns.flaskItems = {
    { key = "stone", id = 46379, spell = 53758 },
    { key = "wyrm", id = 46376, spell = 53755 },
    { key = "rage", id = 46377, spell = 53760 },
    { key = "mojo", id = 46378, spell = 54212 },
}
ns.flaskKinds = { "tank", "heal", "caster", "ap" }
ns.flaskKit = { roles = {
    tank = { { id = 46379, n = 2 } },
    heal = { { id = 46376, n = 2 } },
    caster = { { id = 46376, n = 2 } },
    ap = { { id = 46377, n = 2 } },
} }
ns.flaskClass = { ROGUE = "ap", HUNTER = "ap", MAGE = "caster", WARLOCK = "caster" }
ns.flaskTankClass = { WARRIOR = true, DEATHKNIGHT = true, PALADIN = true, DRUID = true }
ns.flaskStance = {
    WARRIOR = { [71] = "tank", [2457] = "ap", [2458] = "ap" },
    DEATHKNIGHT = { [48263] = "tank", [48266] = "ap", [48265] = "ap" },
    DRUID = { [5487] = "tank", [9634] = "tank", [768] = "ap", [24858] = "caster", [33891] = "heal" },
    PALADIN = { [25780] = "tank" },
}
ns.flaskTalent = {
    WARRIOR = { "ap", "ap", "tank" },
    PALADIN = { "heal", "tank", "ap" },
    SHAMAN = { "caster", "ap", "heal" },
    DRUID = { "caster", "form", "heal" },
    PRIEST = { "heal", "heal", "caster" },
}
ns.flaskAlchemy = { [67016] = true, [67017] = true, [67018] = true }
ns.flaskAnchor = { 46376, 46377, 46379, 46378, 40211, 40212, 33447, 33448, 40093, 40081, 40073, 40076, 40078, 44331, 44332 }
