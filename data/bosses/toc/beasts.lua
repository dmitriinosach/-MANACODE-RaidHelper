local _, ns = ...
local BEASTS = "Звери Нордскола"
ns.bosses["Гормок Пронзающий Бивень"] = BEASTS
ns.bosses["Кислотная Утроба"] = BEASTS
ns.bosses["Жуткая Чешуя"] = BEASTS
ns.bosses["Ледяной Рев"] = BEASTS
ns.bossLast[BEASTS] = { ["Ледяной Рев"] = true }
ns.summaries[BEASTS] = {
    badges = {
        { kind = "hit", spell = "Огненная бомба", gap = 3, tip = "sum.b.toc.firebomb" },
        { kind = "hit", spell = "Лужа жижи", gap = 3, tip = "sum.b.toc.slime" },
        { kind = "aura", spell = "Паралитический токсин", tip = "sum.b.toc.toxin" },
        { kind = "aura", spell = "Горящая желчь", tip = "sum.b.toc.bile" },
        { kind = "death", spells = { "Огненная бомба", "Лужа жижи" }, id = 66317, tip = "sum.b.toc.beastfire" },
        { kind = "stack", spell = "Прокалывание", tip = "sum.b.toc.impale" },
    },
    stacks = { { spell = "Прокалывание" } },
    blocks = {
        { kind = "damageTo", label = "sum.k.toc.snobolds", names = { "Снобольд-вассал" } },
        { kind = "taken", label = "sum.k.toc.beastpools", spells = { "Огненная бомба", "Лужа жижи" } },
        { kind = "dispels", label = "sum.k.toc.rage", spell = "Кипящая ярость" },
    },
}
