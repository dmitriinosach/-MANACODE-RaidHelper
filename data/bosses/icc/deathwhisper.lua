local _, ns = ...
ns.summaries["Леди Смертный Шепот"] = {
    badges = {
        { kind = "chased", npc = "Мстительный дух", grade = "red", tip = "sum.b.shade" },
        { kind = "blast", src = "Мстительный дух", spell = "Вспышка мщения", grade = "yellow",
          tip = "sum.b.shadeblast" },
        { kind = "aura", spell = "Господство над разумом", tip = "sum.b.mc" },
        { kind = "death", spells = { "Смерть и разложение" }, id = 72110, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.dnddeath" },
        { kind = "death", srcs = { "Мстительный дух" }, id = 72012, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.shadedeath" },
        { kind = "death", srcs = {
            "Фанатик культа", "Приверженец культа", "Воскрешенный фанатик", "Искаженный приверженец",
            "Мумифицированный фанатик", "Воскрешенный последователь", "Дарнаван",
        }, id = 72494, neutral = true, note = "sum.b.nograde", tip = "sum.b.trashdeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.adds", names = {
            "Фанатик культа", "Приверженец культа", "Воскрешенный фанатик",
            "Искаженный приверженец", "Мумифицированный фанатик",
        } },
        { kind = "friendly", label = "sum.k.friendly" },
        { kind = "shades", label = "sum.k.shades", src = "Мстительный дух", spell = "Вспышка мщения" },
        { kind = "taken", label = "sum.k.dnd", spells = { "Смерть и разложение" } },
        { kind = "casts", label = "sum.k.frostbolt", spells = { "Ледяная стрела" },
          srcs = { "Леди Смертный Шепот" } },
        { kind = "removed", label = "sum.k.ladycleanse", spells = {
            "Проклятие оцепенения", "Залп ледяных стрел", "Ледяная стрела",
        } },
    },
}
