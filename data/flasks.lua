local _, ns = ...
ns.flaskItems = {
    { key = "stone", id = 46379, spell = 53758, name = "Настой каменной крови" },
    { key = "wyrm", id = 46376, spell = 53755, name = "Настой ледяного змея" },
    { key = "rage", id = 46377, spell = 53760, name = "Настой бесконечной ярости" },
    { key = "mojo", id = 46378, spell = 54212, name = "Настой чистого колдунства" },
}
ns.flaskKinds = { "tank", "sp", "ap" }
ns.flaskDefault = { tank = "stone", sp = "wyrm", ap = "rage" }
ns.flaskClass = { ROGUE = "ap", HUNTER = "ap", MAGE = "sp", WARLOCK = "sp", PRIEST = "sp" }
ns.flaskTankClass = { WARRIOR = true, DEATHKNIGHT = true, PALADIN = true, DRUID = true }
ns.flaskDpsClass = { WARRIOR = "ap", DEATHKNIGHT = "ap", PALADIN = "ap" }
ns.flaskAlchemy = { [67016] = true, [67017] = true, [67018] = true }
