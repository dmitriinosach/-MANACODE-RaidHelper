local _, ns = ...
ns.summaries[ns.ENC.saurfang] = {
    badges = {
        { kind = "aura", spell = 72293, tip = "sum.b.mark" },
        { kind = "aura", spell = 72443, tip = "sum.b.boil" },
        { kind = "applied", spells = {
            10308, 25, 48817, 8983, 49802,
            49803, 1833, 47481, 46968,
        }, names = { 38508 }, id = 10308, tip = "sum.b.beaststun" },
        { kind = "death", srcs = { 38508 }, id = 72172, neutral = true, tip = "sum.b.beastdeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.beasts", names = { 38508 } },
    },
}
