local _, ns = ...
ns.summaries[ns.ENC.sindragosa] = {
    badges = {
        { kind = "aura", spell = 69762, tip = "sum.b.unchained" },
        { kind = "stack", spell = 69766, tip = "sum.b.instability" },
        { kind = "stack", spell = 70106, tip = "sum.b.frostbite" },
        { kind = "aura", spell = 69675, tip = "sum.b.tomb" },
        { kind = "death", spells = { 71049 }, id = 71049, tip = "sum.b.colddeath" },
        { kind = "death", spells = { 71046 }, id = 71046, tip = "sum.b.backlashdeath" },
        { kind = "killer", spells = { 71046 }, id = 71046, tip = "sum.b.backlashkill" },
        { kind = "death", spells = { 64623 }, id = 71055, tip = "sum.b.bombdeath" },
        { kind = "death", spells = { 71665 }, id = 71665, neutral = true, tip = "sum.b.asphyxdeath" },
        { kind = "death", spells = { 15284, 71077 }, id = 19983, neutral = true, tip = "sum.b.cleavedeath" },
        { kind = "stack", spell = 72530, tip = "sum.b.buffet" },
    },
    stacks = {
        { spell = 69766, over = 3 },
        { spell = 70106 },
        { spell = 72530 },
        lap = { wave = "tomb", phase = "p1", before = "stk.air.before", after = "stk.air.after" },
    },
    blocks = {
        { kind = "friendly", label = "sum.k.backlash", spells = { 71046 } },
        { kind = "damageTo", label = "sum.k.tomb", names = { 36980 } },
    },
}
