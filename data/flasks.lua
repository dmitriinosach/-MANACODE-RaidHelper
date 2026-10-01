local _, ns = ...
ns.flaskItems = {
    { key = "stone", id = 46379, spell = 53758 },
    { key = "wyrm", id = 46376, spell = 53755 },
    { key = "rage", id = 46377, spell = 53760 },
    { key = "mojo", id = 46378, spell = 54212 },
}
ns.flaskKinds = { "tank", "sp", "ap" }
ns.flaskDefault = { tank = "stone", sp = "wyrm", ap = "rage" }
ns.flaskClass = { ROGUE = "ap", HUNTER = "ap", MAGE = "sp", WARLOCK = "sp", PRIEST = "sp" }
ns.flaskTankClass = { WARRIOR = true, DEATHKNIGHT = true, PALADIN = true, DRUID = true }
ns.flaskDpsClass = { WARRIOR = "ap", DEATHKNIGHT = "ap", PALADIN = "ap" }
ns.flaskStance = {
    WARRIOR = { [71] = "tank", [2457] = "ap", [2458] = "ap" },
    DEATHKNIGHT = { [48263] = "tank", [48266] = "ap", [48265] = "ap" },
    DRUID = { [5487] = "tank", [9634] = "tank", [768] = "ap", [24858] = "sp", [33891] = "sp" },
    PALADIN = { [25780] = "tank" },
}
ns.flaskTalent = {
    WARRIOR = { "ap", "ap", "tank" },
    PALADIN = { "sp", "tank", "ap" },
    SHAMAN = { "sp", "ap", "sp" },
    DRUID = { "sp", "form", "sp" },
}
ns.flaskAlchemy = { [67016] = true, [67017] = true, [67018] = true }
