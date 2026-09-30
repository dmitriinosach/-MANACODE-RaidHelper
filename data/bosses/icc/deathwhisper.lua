local _, ns = ...
ns.summaries["Леди Смертный Шепот"] = {
    badges = {
        { kind = "chased", npc = "Мстительный дух", grade = "red", tip = "sum.b.shade", excuse = {
            sec = 3, mc = "Господство над разумом",
            auras = {
                ["Ментальный крик"] = "fear", ["Страх"] = "fear", ["Устрашающий крик"] = "fear",
                ["Вой ужаса"] = "fear", ["Молот правосудия"] = "stun", ["Перехват"] = "stun",
                ["Неистовство Тьмы"] = "stun", ["Кольцо льда"] = "root", ["Тайфун"] = "knock",
            },
            moved = { ["Хватка смерти"] = "grip", ["Тайфун"] = "knock", ["Гром и молния"] = "knock" },
        } },
        { kind = "blast", src = "Мстительный дух", spell = "Вспышка мщения", grade = "yellow",
          off = true, tip = "sum.b.shadeblast" },
        { kind = "death", spells = { "Смерть и разложение" }, id = 72110, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.dnddeath" },
        { kind = "death", srcs = { "Мстительный дух" }, id = 72012, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.shadedeath" },
        { kind = "death", srcs = {
            "Фанатик культа", "Приверженец культа", "Воскрешенный фанатик", "Искаженный приверженец",
            "Мумифицированный фанатик", "Воскрешенный последователь", "Дарнаван",
        }, id = 72494, neutral = true, note = "sum.b.nograde", tip = "sum.b.trashdeath" },
        { kind = "stack", spell = "Прикосновение незначительности", tip = "sum.b.insignif" },
    },
    stacks = { { spell = "Прикосновение незначительности" } },
    mcDrain = {
        DRUID = {
            { spell = "Звездопад", id = 53201, ids = { 48505, 53199, 53200, 53201 }, cd = 90 },
            { spell = "Тайфун", id = 61384, ids = { 50516, 53223, 53225, 53226, 53227, 61384 }, cd = 20 },
        },
        PRIEST = {
            { spell = "Ментальный крик", id = 10890, ids = { 8122, 8124, 10888, 10890 }, cd = 30 },
        },
        PALADIN = {
            { spell = "Молот правосудия", id = 10308, ids = { 853, 5588, 5589, 10308 }, cd = 60 },
            { spell = "Божественная буря", id = 53385, ids = { 53385 }, cd = 10 },
        },
        DEATHKNIGHT = {
            { spell = "Хватка смерти", id = 49576, ids = { 49576 }, cd = 35 },
            { spell = "Удушение", id = 47476, ids = { 47476 }, cd = 120 },
            { spell = "Смерть и разложение", id = 49938, ids = { 43265, 49936, 49937, 49938 }, cd = 30,
              tactic = true },
        },
        ROGUE = {
            { spell = "Долой оружие", id = 51722, ids = { 51722 }, cd = 60 },
        },
        WARRIOR = {
            { spell = "Перехват", id = 20252, ids = { 20252 }, cd = 30 },
            { spell = "Устрашающий крик", id = 5246, ids = { 5246 }, cd = 120, tactic = true },
            { spell = "Вихрь клинков", id = 46924, ids = { 46924 }, cd = 90, tactic = true },
        },
        WARLOCK = {
            { spell = "Вой ужаса", id = 17928, ids = { 5484, 17928 }, cd = 40, tactic = true },
            { spell = "Неистовство Тьмы", id = 47847, ids = { 30283, 30413, 30414, 47846, 47847 }, cd = 20,
              tactic = true },
        },
        SHAMAN = {
            { spell = "Гром и молния", id = 59159, ids = { 51490, 59156, 59158, 59159 }, cd = 45, tactic = true },
        },
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
