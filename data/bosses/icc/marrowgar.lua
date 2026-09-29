local _, ns = ...
ns.summaries["Лорд Ребрад"] = {
    badges = {
        { kind = "aura", spell = "Прокалывание", tip = "sum.b.impale" },
        { kind = "hit", spell = "Холодное пламя", gap = 2, tip = "sum.b.coldflame" },
        { kind = "death", spells = { "Холодное пламя" }, id = 70825, tip = "sum.b.coldflamedeath" },
        { kind = "death", spells = { "Костерез" }, id = 70814, tip = "sum.b.saberdeath" },
        { kind = "death", spells = { "Вихрь костей" }, id = 70836, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.stormdeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.spikes", names = { "Костяной шип" } },
        { kind = "taken", label = "sum.k.coldflame", spells = { "Холодное пламя" } },
    },
}
