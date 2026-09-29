local _, ns = ...
local defs = ns.achDefs or { fight = {}, raid = {} }
ns.achDefs = defs
local F, R = defs.fight, defs.raid
local BEASTS = { "Звери Нордскола", "Ледяной Рев" }
local WORMS = { "Звери Нордскола", "Кислотная Утроба", "Жуткая Чешуя" }
local JARAXXUS = { "Лорд Джараксус" }
local CHAMPIONS = { "Чемпионы фракций" }
local TWINS = { "Валь'киры-близнецы", "Эйдис Погибель Тьмы", "Фьола Погибель Света" }
local ANUB = { "Ануб'арак" }
F[#F + 1] = { key = "toc.snobolds", zone = "toc", bosses = BEASTS, id = { [10] = 3797, [25] = 3813 },
    kind = "aliveAt", count = "units", short = true, names = { "Снобольд-вассал" },
    need = { [10] = 2, [25] = 4 } }
F[#F + 1] = { key = "toc.worms", zone = "toc", bosses = WORMS, id = { [10] = 3936, [25] = 3937 },
    kind = "killSpan", names = { "Кислотная Утроба", "Жуткая Чешуя" }, limit = 10 }
F[#F + 1] = { key = "toc.mistress", zone = "toc", bosses = JARAXXUS, id = { [10] = 3996, [25] = 3997 },
    kind = "aliveAt", count = "units", short = true, names = { "Госпожа Боли" }, need = 2 }
F[#F + 1] = { key = "toc.twins", zone = "toc", bosses = TWINS, id = { [10] = 3799, [25] = 3815 },
    kind = "timeLimit", limit = 180 }
R[#R + 1] = { key = "toc.crusade", zone = "toc", kind = "bosses", id = { [10] = 3917, [25] = 3916 },
    bosses = { BEASTS, JARAXXUS, CHAMPIONS, TWINS, ANUB } }
R[#R + 1] = { key = "toc.crusade.h", zone = "toc", kind = "bosses", heroic = true, id = { [10] = 3918, [25] = 3812 },
    bosses = { BEASTS, JARAXXUS, CHAMPIONS, TWINS, ANUB } }
