local _, ns = ...
local defs = ns.achDefs or { fight = {}, raid = {} }
ns.achDefs = defs
local F, R = defs.fight, defs.raid
local BEASTS = { ns.ENC.beasts, 34797 }
local WORMS = { ns.ENC.beasts, 35144, 34799 }
local JARAXXUS = { ns.ENC.jaraxxus }
local CHAMPIONS = { ns.ENC.champions }
local TWINS = { ns.ENC.twins, 34496, 34497 }
local ANUB = { ns.ENC.anubarak }
F[#F + 1] = { key = "toc.snobolds", zone = "toc", bosses = BEASTS, id = { [10] = 3797, [25] = 3813 },
    kind = "aliveAt", count = "units", short = true, names = { 34800 },
    need = { [10] = 2, [25] = 4 } }
F[#F + 1] = { key = "toc.worms", zone = "toc", bosses = WORMS, id = { [10] = 3936, [25] = 3937 },
    kind = "killSpan", names = { 35144, 34799 }, limit = 10 }
F[#F + 1] = { key = "toc.mistress", zone = "toc", bosses = JARAXXUS, id = { [10] = 3996, [25] = 3997 },
    kind = "aliveAt", count = "units", short = true, names = { 34826 }, need = 2 }
F[#F + 1] = { key = "toc.twins", zone = "toc", bosses = TWINS, id = { [10] = 3799, [25] = 3815 },
    kind = "timeLimit", limit = 180 }
R[#R + 1] = { key = "toc.crusade", zone = "toc", kind = "bosses", id = { [10] = 3917, [25] = 3916 },
    bosses = { BEASTS, JARAXXUS, CHAMPIONS, TWINS, ANUB } }
R[#R + 1] = { key = "toc.crusade.h", zone = "toc", kind = "bosses", heroic = true, id = { [10] = 3918, [25] = 3812 },
    bosses = { BEASTS, JARAXXUS, CHAMPIONS, TWINS, ANUB } }
