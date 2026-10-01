local _, ns = ...
ns.summaries[ns.ENC.lanathel] = {
    death = { link = 71340 },
    stats = {
        { kind = "deaths", label = "sum.s.pactkills", spells = { 71340 } },
    },
    badges = {
        { kind = "aura", spell = 71340, tip = "sum.b.pact" },
        { kind = "killer", spells = { 71340 }, id = 71340, tip = "sum.b.pactkill" },
        { kind = "death", spells = { 71340 }, id = 71340, tip = "sum.b.pactdeath" },
        { kind = "aura", spell = 71264, tip = "sum.b.shadows" },
        { kind = "death", spells = { 71264 }, id = 72637, neutral = true, tip = "sum.b.shadowsdeath" },
        { kind = "killer", spells = { 71483 }, id = 71483, tip = "sum.b.splashkill" },
    },
    blocks = {
        { kind = "friendly", label = "sum.k.pact", spells = { 71340 } },
        { kind = "taken", label = "sum.k.lanashadows", spells = { 71264 } },
        { kind = "dispels", label = "sum.k.fear", spell = 73070, totems = { 5913 } },
    },
}
