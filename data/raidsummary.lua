local _, ns = ...
ns.consumeCast = {
    [53755] = { cat = "flask", item = "Настой ледяного змея", id = 46376 },
    [53760] = { cat = "flask", item = "Настой бесконечной ярости", id = 46377 },
    [53758] = { cat = "flask", item = "Настой каменной крови", id = 46379 },
    [54212] = { cat = "flask", item = "Настой чистого колдунства", id = 46378 },
    [53752] = { cat = "flask", item = "Слабый настой крепости", id = 40079 },
    [67016] = { cat = "flask", item = "Настой севера", id = 47499, free = true },
    [67017] = { cat = "flask", item = "Настой севера", id = 47499, free = true },
    [67018] = { cat = "flask", item = "Настой севера", id = 47499, free = true },
    [53748] = { cat = "elixir", item = "Эликсир чрезвычайной силы", id = 40073 },
    [53749] = { cat = "elixir", item = "Эликсир гуру", id = 40076 },
    [53751] = { cat = "elixir", item = "Мощный эликсир стойкости", id = 40078 },
    [60346] = { cat = "elixir", item = "Эликсир скорости молнии", id = 44331 },
    [60347] = { cat = "elixir", item = "Эликсир могучего разума", id = 44332 },
    [53908] = { cat = "potion", item = "Зелье быстроты", id = 40211 },
    [53909] = { cat = "potion", item = "Зелье дикой магии", id = 40212 },
    [53762] = { cat = "potion", item = "Зелье несокрушимости", id = 40093 },
    [53753] = { cat = "potion", item = "Зелье ночных кошмаров", id = 40081 },
    [43186] = { cat = "potion", item = "Рунический флакон с зельем маны", id = 33448 },
    [43185] = { cat = "potion", item = "Рунический флакон с лечебным зельем", id = 33447 },
    [67490] = { cat = "potion", item = "Рунический набор для инъекций маны", id = 42545 },
    [67489] = { cat = "potion", item = "Рунический набор для инъекций лечения", id = 41166 },
    [28499] = { cat = "potion", item = "Сверхмощное зелье маны", id = 22832 },
    [28508] = { cat = "potion", item = "Зелье разрушения", id = 22839 },
    [67019] = { cat = "flask", item = "Настой севера", id = 47499, free = true },
    [45543] = { cat = "other", item = "Бинты из ледяной ткани", id = 34721 },
    [45544] = { cat = "other", item = "Плотные бинты из ледяной ткани", id = 34722 },
    [53808] = { cat = "other", item = "Карломасло", id = 40195 },
    [8213] = { cat = "food", item = "Вареная неправильная рыба", id = 6657 },
    [26681] = { cat = "other", item = "Одеколон" },
    [26682] = { cat = "other", item = "Духи" },
    [70233] = { cat = "other", item = "Духи \"Победа\"" },
    [70234] = { cat = "other", item = "Духи \"Чаровница\"" },
    [70235] = { cat = "other", item = "Духи \"Вместе навсегда\"" },
    [70242] = { cat = "other", item = "Одеколон \"Бравада\"" },
    [70243] = { cat = "other", item = "Одеколон \"ДОБЛЕСТЬ\"" },
    [70244] = { cat = "other", item = "Одеколон \"Волшебство\"" },
}
ns.consumeCreate = {
    [57426] = { cat = "food", item = "Рыбный пир", id = 43015 },
    [57301] = { cat = "food", item = "Великий пир", id = 34753 },
}
ns.consumeEnchant = {}
ns.consumeAura = {
    [28714] = { cat = "potion", item = "Огненный зев", id = 22788 },
}
for spell, c in pairs(ns.consumeGen or {}) do
    if not ns.consumeCast[spell] and not ns.consumeCreate[spell] and not ns.consumeAura[spell] then
        ns.consumeCast[spell] = c
    end
end
ns.raidFinal = {
    IcecrownCitadel = ns.ENC.lichking,
    Ulduar = { ns.ENC.yogg, ns.ENC.algalon },
    TheRubySanctum = ns.ENC.halion,
    TheArgentColiseum = ns.ENC.anubarak,
    Naxxramas = 15990,
    TheEyeofEternity = 28859,
    OnyxiasLair = 10184,
    TheObsidianSanctum = 28860,
}
ns.raidArt = {
    IcecrownCitadel = "LoadScreenIcecrownCitadel",
    Ulduar = "LoadScreenUlduarRaid",
    TheRubySanctum = "LoadScreenRubySanctum",
    TheArgentColiseum = "LoadScreenArgentRaid",
}
ns.encRaid = {}
for _, r in ipairs(ns.raidBosses) do
    for _, id in ipairs(r.list) do ns.encRaid[id] = r.map end
end
function ns.RaidArtFile(boss, map)
    local key = type(boss) == "number" and ns.encRaid[boss] or map
    return key and ns.raidArt[key] or nil
end
ns.raidEncounters = {
    IcecrownCitadel = 12,
    TheRubySanctum = 1,
    TheArgentColiseum = 5,
    Ulduar = 14,
    Naxxramas = 15,
    TheEyeofEternity = 1,
    OnyxiasLair = 1,
    TheObsidianSanctum = 1,
}
ns.raidCut = {
    [ns.ENC.lichking] = true,
}
ns.lootGems = {
    { 28118, 28120 }, 28123, 28362, 28363, { 32193, 32231 }, 32249, 33135, { 35758, 35761 }, 36766, 36767,
    { 36917, 36934 }, 37503, { 38545, 38550 }, { 40111, 40182 }, { 42142, 42146 }, { 42148, 42158 }, 44066,
    { 45879, 45881 }, 45883, 49110,
}
ns.lootShard = 50274
