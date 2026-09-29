local _, ns = ...
local defs = ns.achDefs or { fight = {}, raid = {} }
ns.achDefs = defs
local F, R = defs.fight, defs.raid
local LEVIATHAN = { "Огненный Левиафан" }
local IGNIS = { "Повелитель Горнов Игнис" }
local RAZOR = { "Острокрылая" }
local XT = { "Разрушитель XT-002" }
local IRON = { "Железное собрание", "Сталелом", "Мастер рун Молгейм", "Буревестник Брундир" }
local KOLOGARN = { "Кологарн" }
local AURIAYA = { "Ауриайя" }
local HODIR = { "Ходир" }
local THORIM = { "Торим" }
local FREYA = { "Фрейя" }
local MIMIRON = { "Мимирон", "Воздушное судно" }
local VEZAX = { "Генерал Везакс" }
local YOGG = { "Йогг-Сарон" }
local ALGALON = { "Алгалон Наблюдатель" }
local COUNCIL = { "Сталелом", "Мастер рун Молгейм", "Буревестник Брундир" }
F[#F + 1] = { key = "uld.stokin", zone = "uld", bosses = IGNIS, id = { [10] = 2930, [25] = 2929 },
    kind = "timeLimit", limit = 240 }
F[#F + 1] = { key = "uld.faster", zone = "uld", bosses = XT, id = { [10] = 2937, [25] = 2938 },
    kind = "timeLimit", limit = 205 }
F[#F + 1] = { key = "uld.heart", zone = "uld", bosses = XT, id = { [10] = 3058, [25] = 3059 },
    kind = "killed", names = { "Сердце Разрушителя" } }
F[#F + 1] = { key = "uld.gravity", zone = "uld", bosses = XT, id = { [10] = 2934, [25] = 2936 },
    kind = "deathBy", spells = { "Гравитационная бомба" } }
F[#F + 1] = { key = "uld.steel", zone = "uld", bosses = IRON, id = { [10] = 2941, [25] = 2944 },
    kind = "lastDied", names = COUNCIL, last = "Сталелом" }
F[#F + 1] = { key = "uld.molgeim", zone = "uld", bosses = IRON, id = { [10] = 2940, [25] = 2943 },
    kind = "lastDied", names = COUNCIL, last = "Мастер рун Молгейм" }
F[#F + 1] = { key = "uld.brundir", zone = "uld", bosses = IRON, id = { [10] = 2939, [25] = 2942 },
    kind = "lastDied", names = COUNCIL, last = "Буревестник Брундир" }
F[#F + 1] = { key = "uld.arms", zone = "uld", bosses = KOLOGARN, id = { [10] = 2951, [25] = 2952 },
    kind = "noKill", names = { "Левая рука", "Правая рука" } }
F[#F + 1] = { key = "uld.cats", zone = "uld", bosses = AURIAYA, id = { [10] = 3006, [25] = 3007 },
    kind = "noKill", names = { "Часовой святилища" } }
F[#F + 1] = { key = "uld.cold", zone = "uld", bosses = HODIR, id = { [10] = 2967, [25] = 2968 },
    kind = "maxStack", spell = "Трескучий мороз", limit = 2 }
F[#F + 1] = { key = "uld.shadow", zone = "uld", bosses = VEZAX, id = { [10] = 2996, [25] = 2997 },
    kind = "hitBy", spells = { "Темное сокрушение" } }
F[#F + 1] = { key = "uld.saronite", zone = "uld", bosses = VEZAX, id = { [10] = 3181, [25] = 3188 },
    kind = "killed", names = { "Саронитовый враг" } }
local BOSSES = { LEVIATHAN, IGNIS, RAZOR, XT, IRON, KOLOGARN, AURIAYA, HODIR, THORIM, FREYA, MIMIRON, VEZAX, YOGG }
R[#R + 1] = { key = "uld.siege", zone = "uld", kind = "bosses", id = { [10] = 2886, [25] = 2887 },
    bosses = { LEVIATHAN, IGNIS, RAZOR, XT } }
R[#R + 1] = { key = "uld.antechamber", zone = "uld", kind = "bosses", id = { [10] = 2888, [25] = 2889 },
    bosses = { IRON, KOLOGARN, AURIAYA } }
R[#R + 1] = { key = "uld.keepers", zone = "uld", kind = "bosses", id = { [10] = 2890, [25] = 2891 },
    bosses = { HODIR, THORIM, FREYA, MIMIRON } }
R[#R + 1] = { key = "uld.descent", zone = "uld", kind = "bosses", id = { [10] = 2892, [25] = 2893 },
    bosses = { VEZAX, YOGG } }
R[#R + 1] = { key = "uld.secrets", zone = "uld", kind = "bosses", id = { [10] = 2894, [25] = 2895 },
    bosses = { ALGALON } }
R[#R + 1] = { key = "uld.champion", zone = "uld", kind = "cleanKills", id = { [10] = 2903, [25] = 2904 },
    bosses = BOSSES }
R[#R + 1] = { key = "uld.tears", zone = "uld", kind = "noDeaths", id = { [10] = 3004, [25] = 3005 },
    bosses = { ALGALON } }
