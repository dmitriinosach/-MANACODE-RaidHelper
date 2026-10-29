local _, ns = ...
local NAMES = {
    ["enc.36612"] = { "Лорд Ребрад", "Lord Marrowgar", "Lord Tuétano" },
    ["enc.36855"] = { "Леди Смертный Шепот", "Lady Deathwhisper", "Lady Susurramuerte" },
    ["enc.36948"] = { "Бой на кораблях", "Gunship Battle", "Batalla de cañoneras" },
    ["enc.37813"] = { "Саурфанг Смертоносный", "Deathbringer Saurfang", "Libramuerte Colmillosauro" },
    ["enc.36626"] = { "Тухлопуз", "Festergut", "Panzachancro" },
    ["enc.36627"] = { "Гниломорд", "Rotface", "Carapútrea" },
    ["enc.36678"] = { "Профессор Мерзоцид", "Professor Putricide", "Profesor Putricidio" },
    ["enc.37970"] = { "Совет кровавых принцев", "Blood Prince Council", "Consejo de príncipes de sangre" },
    ["enc.37955"] = { "Кровавая королева Лана'тель", "Blood-Queen Lana'thel", "Reina de sangre Lana'thel" },
    ["enc.36789"] = { "Валитрия Сноходица", "Valithria Dreamwalker", "Valithria Caminasueños" },
    ["enc.36853"] = { "Синдрагоса", "Sindragosa", "Sindragosa" },
    ["enc.36597"] = { "Король-лич", "The Lich King", "El Rey Exánime" },
    ["enc.33113"] = { "Огненный Левиафан", "Flame Leviathan", "Leviatán de llamas" },
    ["enc.33118"] = { "Повелитель Горнов Игнис", "Ignis the Furnace Master", "Ignis, el Maestro del Horno" },
    ["enc.33186"] = { "Острокрылая", "Razorscale", "Tajoescama" },
    ["enc.33293"] = { "Разрушитель XT-002", "XT-002 Deconstructor", "Desconstructor XT-002" },
    ["enc.32867"] = { "Железное собрание", "Assembly of Iron", "Asamblea de Hierro" },
    ["enc.32930"] = { "Кологарн", "Kologarn", "Kologarn" },
    ["enc.33515"] = { "Ауриайя", "Auriaya", "Auriaya" },
    ["enc.32845"] = { "Ходир", "Hodir", "Hodir" },
    ["enc.32865"] = { "Торим", "Thorim", "Thorim" },
    ["enc.32906"] = { "Фрейя", "Freya", "Freya" },
    ["enc.33350"] = { "Мимирон", "Mimiron", "Mimiron" },
    ["enc.33271"] = { "Генерал Везакс", "General Vezax", "General Vezax" },
    ["enc.33288"] = { "Йогг-Сарон", "Yogg-Saron", "Yogg-Saron" },
    ["enc.32871"] = { "Алгалон Наблюдатель", "Algalon the Observer", "Algalon el Observador" },
    ["enc.39863"] = { "Халион", "Halion", "Halion" },
    ["enc.34796"] = { "Звери Нордскола", "Northrend Beasts", "Bestias de Rasganorte" },
    ["enc.34780"] = { "Лорд Джараксус", "Lord Jaraxxus", "Lord Jaraxxus" },
    ["enc.34441"] = { "Чемпионы фракций", "Faction Champions", "Campeones de la facción" },
    ["enc.34497"] = { "Валь'киры-близнецы", "Twin Val'kyr", "Valkirias gemelas" },
    ["enc.34564"] = { "Ануб'арак", "Anub'arak", "Anub'arak" },
    ["enc.31144"] = { "Тренировочный манекен", "Training Dummy", "Muñeco de entrenamiento" },
    ["sum.shed.by.45438"] = { "глыба", "Ice Block", "Bloque de hielo" },
    ["sum.shed.by.642"] = { "бабл", "bubble", "burbuja" },
    ["sum.shed.by.31224"] = { "плащ", "Cloak", "Capa" },
    ["sum.shed.by.10278"] = { "длань защиты", "Hand of Protection", "Mano de protección" },
    ["tl.fixate.shade"] = { "Цель мстительного духа", "Vengeful Shade target", "Objetivo de la sombra vengativa" },
    ["zone.IcecrownCitadel"] = { "Цитадель Ледяной Короны", "Icecrown Citadel", "Ciudadela de la Corona de Hielo" },
    ["zone.TheRubySanctum"] = { "Рубиновое святилище", "The Ruby Sanctum", "El Sagrario Rubí" },
    ["zone.TheArgentColiseum"] = { "Испытание крестоносца", "Trial of the Crusader", "Prueba del Cruzado" },
    ["zone.Ulduar"] = { "Ульдуар", "Ulduar", "Ulduar" },
    ["zone.Naxxramas"] = { "Наксрамас", "Naxxramas", "Naxxramas" },
    ["zone.TheEyeofEternity"] = { "Око Вечности", "The Eye of Eternity", "El Ojo de la Eternidad" },
    ["zone.TheObsidianSanctum"] = { "Обсидиановое святилище", "The Obsidian Sanctum", "El Sagrario Obsidiana" },
    ["zone.OnyxiasLair"] = { "Логово Ониксии", "Onyxia's Lair", "Guarida de Onyxia" },
    ["zone.VaultofArchavon"] = { "Склеп Аркавона", "Vault of Archavon", "La Cámara de Archavon" },
    ["zone.TrialoftheGrandCrusader"] = { "Испытание великого крестоносца", "Trial of the Grand Crusader", "Prueba del Gran Cruzado" },
}
local L = ns.L
local LEN = ns.LEN
local LES = ns.LES
for key, pair in pairs(NAMES) do
    L[key] = pair[1]
    if LEN then LEN[key] = pair[2] end
    if LES then LES[key] = pair[3] end
end
ns.zoneByName = {}
for key, pair in pairs(NAMES) do
    local map = key:match("^zone%.(.+)$")
    if map then
        ns.zoneByName[pair[1]] = map
        ns.zoneByName[pair[2]] = map
        ns.zoneByName[pair[3]] = map
    end
end
