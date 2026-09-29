local _, ns = ...
ns.summaries["Кровавая королева Лана'тель"] = {
    death = { link = "Пакт Омраченных" },
    stats = {
        { kind = "deaths", label = "sum.s.pactkills", spells = { "Пакт Омраченных" } },
    },
    badges = {
        { kind = "aura", spell = "Пакт Омраченных", tip = "sum.b.pact" },
        { kind = "killer", spells = { "Пакт Омраченных" }, id = 71340, tip = "sum.b.pactkill" },
        { kind = "death", spells = { "Пакт Омраченных" }, id = 71340, tip = "sum.b.pactdeath" },
        { kind = "aura", spell = "Роящиеся тени", tip = "sum.b.shadows" },
        { kind = "death", spells = { "Роящиеся тени" }, id = 72637, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.shadowsdeath" },
        { kind = "killer", spells = { "Кровавый всплеск" }, id = 71483, tip = "sum.b.splashkill" },
    },
    blocks = {
        { kind = "friendly", label = "sum.k.pact", spells = { "Пакт Омраченных" } },
        { kind = "taken", label = "sum.k.lanashadows", spells = { "Роящиеся тени" } },
        { kind = "dispels", label = "sum.k.fear", spell = "Внушение страха", totems = { "Тотем трепета" } },
    },
}
