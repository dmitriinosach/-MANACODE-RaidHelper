local _, ns = ...
local TWINS = ns.ENC.twins
local FJOLA = 34497
local EYDIS = 34496
ns.bosses[FJOLA] = TWINS
ns.bosses[EYDIS] = TWINS
ns.summaries[TWINS] = {
    badges = {
        { kind = "hit", spell = 66046, gap = 3, tip = "sum.b.toc.vortex" },
        { kind = "hit", spell = 67157, gap = 3, tip = "sum.b.toc.vortex" },
        { kind = "death", spells = { 66046, 67157 }, id = 66058, tip = "sum.b.toc.vortexdeath" },
        { kind = "aura", spell = 67298, tip = "sum.b.toc.touch" },
        { kind = "aura", spell = 67283, tip = "sum.b.toc.touch" },
    },
    blocks = {
        { kind = "casts", label = "sum.k.toc.pact", spells = { 67305 }, srcs = { FJOLA, EYDIS } },
        { kind = "taken", label = "sum.k.toc.vortex", spells = { 66046, 67157 } },
    },
}
