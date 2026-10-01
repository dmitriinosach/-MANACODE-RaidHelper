local _, ns = ...
local JARAXXUS = ns.ENC.jaraxxus
ns.bosses[34780] = JARAXXUS
ns.summaries[JARAXXUS] = {
    badges = {
        { kind = "aura", spell = 67051, tip = "sum.b.toc.flesh" },
        { kind = "aura", spell = 66200, tip = "sum.b.toc.legion" },
        { kind = "hit", spell = 67047, gap = 3, tip = "sum.b.toc.inferno" },
        { kind = "death", spells = { 67047 }, id = 68718, tip = "sum.b.toc.infernodeath" },
    },
    blocks = {
        { kind = "casts", label = "sum.k.toc.fireball", spells = { 66965 }, srcs = { JARAXXUS } },
        { kind = "dispels", label = "sum.k.toc.netherpower", spell = 67009 },
        { kind = "removed", label = "sum.k.toc.jaracleanse", spells = { 66965 } },
        { kind = "damageTo", label = "sum.k.toc.jaradds", names = { 34826, 34825, 34813 } },
        { kind = "taken", label = "sum.k.toc.jarafire", spells = { 66200, 67047 } },
    },
}
