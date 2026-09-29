local _, ns = ...
local TWINS = "Валь'киры-близнецы"
local FJOLA = "Фьола Погибель Света"
local EYDIS = "Эйдис Погибель Тьмы"
ns.bosses[FJOLA] = TWINS
ns.bosses[EYDIS] = TWINS
ns.summaries[TWINS] = {
    badges = {
        { kind = "hit", spell = "Светлая воронка", gap = 3, tip = "sum.b.toc.vortex" },
        { kind = "hit", spell = "Темная воронка", gap = 3, tip = "sum.b.toc.vortex" },
        { kind = "death", spells = { "Светлая воронка", "Темная воронка" }, id = 66058, tip = "sum.b.toc.vortexdeath" },
        { kind = "aura", spell = "Касание Света", tip = "sum.b.toc.touch" },
        { kind = "aura", spell = "Касание тьмы", tip = "sum.b.toc.touch" },
    },
    blocks = {
        { kind = "casts", label = "sum.k.toc.pact", spells = { "Договор близнецов" }, srcs = { FJOLA, EYDIS } },
        { kind = "taken", label = "sum.k.toc.vortex", spells = { "Светлая воронка", "Темная воронка" } },
    },
}
