local _, ns = ...
ns.summaries["Синдрагоса"] = {
    badges = {
        { kind = "aura", spell = "Освобожденная магия", tip = "sum.b.unchained" },
        { kind = "stack", spell = "Неустойчивость", tip = "sum.b.instability" },
        { kind = "stack", spell = "Обморожение", tip = "sum.b.frostbite" },
        { kind = "aura", spell = "Ледяной склеп", tip = "sum.b.tomb" },
        { kind = "death", spells = { "Обжигающий холод" }, id = 71049, tip = "sum.b.colddeath" },
        { kind = "death", spells = { "Ответный удар" }, id = 71046, tip = "sum.b.backlashdeath" },
        { kind = "killer", spells = { "Ответный удар" }, id = 71046, tip = "sum.b.backlashkill" },
        { kind = "death", spells = { "Ледяная бомба" }, id = 71055, tip = "sum.b.bombdeath" },
        { kind = "death", spells = { "Удушье" }, id = 71665, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.asphyxdeath" },
        { kind = "death", spells = { "Рассекающий удар", "Мощный удар хвостом" }, id = 19983, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.cleavedeath" },
    },
    blocks = {
        { kind = "friendly", label = "sum.k.backlash", spells = { "Ответный удар" } },
        { kind = "damageTo", label = "sum.k.tomb", names = { "Ледяной склеп" } },
    },
}
