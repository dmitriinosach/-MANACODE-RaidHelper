local _, ns = ...
ns.summaries["Профессор Мерзоцид"] = {
    deps = {
        mechs = { { key = "volatile", text = "sum.dd.m.volatile", spells = { "Взрыв слизнюка" } } },
    },
    badges = {
        { kind = "aura", spell = "Выделения неустойчивого слизнюка", tip = "sum.b.ooze" },
        { kind = "aura", spell = "Газовое вздутие", tip = "sum.b.gas" },
        { kind = "aura", spell = "Слизнюкообразное состояние", tip = "sum.b.oozevar" },
        { kind = "aura", spell = "Газообразное состояние", tip = "sum.b.gasvar" },
        { kind = "hit", spell = "Лужа слизи", gap = 2, tip = "sum.b.puddle" },
        { kind = "aura", spell = "Вязкая гадость", tip = "sum.b.goo",
          shed = { [70853] = 15, [72458] = 15, [72873] = 20, [72874] = 20 } },
        { kind = "aura", spell = "Удушливый газ", tip = "sum.b.choke",
          shed = { [71278] = 15, [72460] = 15, [72619] = 20, [72620] = 20 } },
        { kind = "applied", spells = { "Рвотный слизнюк" }, names = { "Неустойчивый слизнюк", "Облако газа" },
          id = 72876, tip = "sum.b.abomslow" },
        { kind = "death", spells = { "Взрыв слизнюка" }, id = 72625, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.oozeblastdeath" },
        { kind = "death", spells = { "Лужа слизи" }, id = 72869, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.puddledeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.oozes", names = {
            "Неустойчивый слизнюк", "Облако газа",
        } },
        { kind = "damageTo", label = "sum.k.greenooze", names = { "Неустойчивый слизнюк" } },
        { kind = "damageTo", label = "sum.k.redooze", names = { "Облако газа" } },
        { kind = "healTo", label = "sum.k.abomheal", names = { "Мутировавшее поганище" } },
    },
}
