local _, ns = ...
ns.summaries[ns.ENC.marrowgar] = {
    badges = {
        { kind = "aura", spell = 62418, tip = "sum.b.impale" },
        { kind = "hit", spell = 69138, gap = 2, pool = 6, tip = "sum.b.coldflame" },
        { kind = "death", spells = { 69138 }, id = 70825, tip = "sum.b.coldflamedeath" },
        { kind = "death", spells = { 70814 }, id = 70814, tip = "sum.b.saberdeath" },
        { kind = "death", spells = { 69076 }, id = 70836, neutral = true, tip = "sum.b.stormdeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.spikes", names = { 36619 } },
        { kind = "taken", label = "sum.k.coldflame", spells = { 69138 } },
    },
}
