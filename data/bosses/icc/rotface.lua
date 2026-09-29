local _, ns = ...
ns.summaries["Гниломорд"] = {
    deps = {
        dispel = { { spell = "Мутировавшая инфекция", type = "Disease", dur = 12 } },
        mechs = {
            { key = "bigooze", text = "sum.dd.m.bigooze", srcs = { "Большой слизнюк" }, melee = true, by = "tank" },
            { key = "smallooze", text = "sum.dd.m.smallooze", srcs = { "Малый слизнюк" }, melee = true },
        },
    },
    badges = {
        { kind = "death", spells = { "Брызги слизи" }, id = 73190, tip = "sum.b.spraydeath" },
        { kind = "death", spells = { "Липкая жижа", "Поток слизнюков" }, id = 71208, tip = "sum.b.rotpuddledeath" },
        { kind = "death", srcs = { "Малый слизнюк", "Большой слизнюк" }, id = 73027, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.oozedeath" },
        { kind = "death", spells = { "Губительный газ" }, id = 73174, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.gasdeath" },
        { kind = "aura", spell = "Мутировавшая инфекция", tip = "sum.b.infection" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.spray", spells = { "Брызги слизи" } },
        { kind = "taken", label = "sum.k.rotpuddle", spells = { "Липкая жижа", "Поток слизнюков" } },
        { kind = "taken", label = "sum.k.rotgas", spells = { "Губительный газ" } },
    },
}
