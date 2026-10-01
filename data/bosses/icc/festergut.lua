local _, ns = ...
ns.summaries[ns.ENC.festergut] = {
    badges = {
        { kind = "stack", spell = 72103, tip = "sum.b.inoculated" },
        { kind = "stack", spell = 72553, tip = "sum.b.bloat" },
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
