local _, ns = ...
ns.summaries["Тухлопуз"] = {
    badges = {
        { kind = "stack", spell = "Невосприимчивость к гнили", tip = "sum.b.inoculated" },
        { kind = "stack", spell = "Газовое вздутие", tip = "sum.b.bloat" },
        { kind = "death", spells = { "Едкая гниль" }, id = 73032, tip = "sum.b.blightdeath" },
        { kind = "death", spells = { "Губительный газ" }, id = 73020, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.gasdeath" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.vilegas", spells = { "Губительный газ" } },
    },
}
