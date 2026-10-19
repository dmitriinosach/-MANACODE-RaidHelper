local _, ns = ...
ns.summaries[ns.ENC.festergut] = {
    badges = {
        { kind = "stack", spell = 72103, tip = "sum.b.inoculated" },
        { kind = "stack", spell = 72553, tip = "sum.b.bloat" },
        { kind = "aura", spell = 72273, tip = "sum.b.vilegas", exact = true, want = "shed",
          shed = { [69240] = 6, [71218] = 6, [73019] = 6, [73020] = 6 } },
        { kind = "aura", spell = 69279, tip = "sum.b.spore", exact = true, want = "full", shed = { [69279] = 12 } },
        { kind = "aura", spell = 72550, tip = "sum.b.goo",
          shed = { [70853] = 15, [72458] = 15, [72873] = 20, [72874] = 20 } },
        { kind = "death", spells = { 73032 }, id = 73032, tip = "sum.b.blightdeath" },
        { kind = "death", spells = { 72273 }, id = 73020, neutral = true, tip = "sum.b.gasdeath" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.vilegas", spells = { 72273 } },
    },
    stacks = {
        { spell = 72103 },
        { spell = 72553 },
    },
}
