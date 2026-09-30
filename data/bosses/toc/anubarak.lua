local _, ns = ...
local ANUB = "Ануб'арак"
ns.bosses["Ануб'арак"] = ANUB
ns.summaries[ANUB] = {
    badges = {
        { kind = "aura", spell = "Вас преследует Ануб'арак", tip = "sum.b.toc.pursue" },
        { kind = "aura", spell = "Пронизывающий холод", tip = "sum.b.toc.cold" },
        { kind = "hit", spell = "Прокалывание", gap = 3, tip = "sum.b.toc.spikes" },
        { kind = "death", spells = { "Прокалывание" }, id = 67574, tip = "sum.b.toc.spikedeath" },
        { kind = "stack", spell = "Выявление слабости", tip = "sum.b.toc.expose" },
    },
    stacks = { { spell = "Выявление слабости" } },
    blocks = {
        { kind = "taken", label = "sum.k.toc.spikes", spells = { "Прокалывание" } },
        { kind = "taken", label = "sum.k.toc.cold", spells = { "Пронизывающий холод" } },
        { kind = "casts", label = "sum.k.toc.strike", spells = { "Теневой удар" } },
    },
}
