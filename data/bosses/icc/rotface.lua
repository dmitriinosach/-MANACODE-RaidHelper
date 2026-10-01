local _, ns = ...
ns.summaries[ns.ENC.rotface] = {
    deps = {
        dispel = { { spell = 73023, type = "Disease", dur = 12 } },
        mechs = {
            { key = "bigooze", text = "sum.dd.m.bigooze", srcs = { 36899 }, melee = true, by = "tank" },
            { key = "smallooze", text = "sum.dd.m.smallooze", srcs = { 36897 }, melee = true },
        },
    },
    badges = {
        { kind = "death", spells = { 69508 }, id = 73190, tip = "sum.b.spraydeath" },
        { kind = "death", spells = { 69774, 71588 }, id = 71208, tip = "sum.b.rotpuddledeath" },
        { kind = "death", srcs = { 36897, 36899 }, id = 73027, neutral = true, tip = "sum.b.oozedeath" },
        { kind = "death", spells = { 72273 }, id = 73174, neutral = true, tip = "sum.b.gasdeath" },
        { kind = "aura", spell = 73023, tip = "sum.b.infection" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.spray", spells = { 69508 } },
        { kind = "taken", label = "sum.k.rotpuddle", spells = { 69774, 71588 } },
        { kind = "taken", label = "sum.k.rotgas", spells = { 72273 } },
    },
}
