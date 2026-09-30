local _, ns = ...
ns.summaries["Профессор Мерзоцид"] = {
    deps = {
        mechs = { { key = "volatile", text = "sum.dd.m.volatile", spells = { "Взрыв слизнюка" } } },
    },
    badges = {
        { kind = "hit", spell = "Лужа слизи", gap = 2, pool = 6, tip = "sum.b.puddle", off = true },
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
        { kind = "stack", spell = "Мутировавшая чума", tip = "sum.b.mutplague" },
    },
    stacks = { { spell = "Мутировавшая чума" } },
    blocks = {
        { kind = "oozes", label = "sum.k.oozes", green = "Неустойчивый слизнюк", red = "Облако газа",
          names = { "Неустойчивый слизнюк", "Облако газа" },
          auras = { rt = "Газовое вздутие", gt = "Выделения неустойчивого слизнюка",
                    ov = "Слизнюкообразное состояние", gv = "Газообразное состояние" },
          icons = { rt = 72833, gt = 72838, ov = 74118, gv = 74119 } },
        { kind = "abom", label = "sum.k.abom", npc = "Мутировавшее поганище", enter = "Мутация", power = true,
          slow = "Рвотный слизнюк", eat = "Съесть слизнюка", names = { "Неустойчивый слизнюк", "Облако газа" },
          icons = { slow = 72876, eat = 72527 } },
    },
}
