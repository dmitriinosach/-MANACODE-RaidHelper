local _, ns = ...
ns.summaries["Совет кровавых принцев"] = {
    badges = {
        { kind = "dmgto", names = { "Темное ядро" }, id = 71943, tip = "sum.b.nucleus" },
        { kind = "dmgto", names = { "Кинетическая бомба" }, soak = true, id = 72080, tip = "sum.b.kinetic" },
        { kind = "death", spells = { "Сотрясающий вихрь", "Могучий вихрь" }, id = 72814, tip = "sum.b.vortexdeath" },
        { kind = "death", spells = { "Пламя", "Опаляющая вспышка" },
          srcs = { "Шар пламени", "Шар пламени преисподней" }, id = 72791, tip = "sum.b.flamedeath" },
        { kind = "emote", patterns = { "Огни Инферно движутся к", "Жаркое пламя тянется к",
          "Empowered Flames speed toward" }, id = 72040, tip = "sum.b.flametarget" },
        { kind = "death", spells = { "Темница Тьмы" }, id = 72999, tip = "sum.b.prisondeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.nucleus", names = { "Темное ядро" } },
        { kind = "damageTo", label = "sum.k.kinetic", names = { "Кинетическая бомба" }, soak = true },
        { kind = "taken", label = "sum.k.prison", spells = { "Темница Тьмы" } },
    },
}
