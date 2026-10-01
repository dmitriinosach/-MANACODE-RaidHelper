local _, ns = ...
ns.summaries[ns.ENC.council] = {
    badges = {
        { kind = "bounce", names = { 38454 }, id = 72080, tip = "sum.b.kinetic" },
        { kind = "death", spells = { 72037, 72817 }, id = 72814, tip = "sum.b.vortexdeath" },
        { kind = "death", spells = { 64566, 72787 },
          srcs = { 38332, 38451 }, id = 72791, tip = "sum.b.flamedeath" },
        { kind = "emote", patterns = { "Огни Инферно движутся к", "Жаркое пламя тянется к",
          "Empowered Flames speed toward" }, id = 72040, tip = "sum.b.flametarget" },
        { kind = "death", spells = { 72999 }, id = 72999, tip = "sum.b.prisondeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.nucleus", names = { 38369 } },
        { kind = "taken", label = "sum.k.prison", spells = { 72999 }, absorbed = true, stacks = true },
    },
}
