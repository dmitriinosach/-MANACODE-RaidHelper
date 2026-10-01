local _, ns = ...
local BEASTS = ns.ENC.beasts
ns.bosses[34796] = BEASTS
ns.bosses[35144] = BEASTS
ns.bosses[34799] = BEASTS
ns.bosses[34797] = BEASTS
ns.bossLast[BEASTS] = { [34797] = true }
ns.summaries[BEASTS] = {
    badges = {
        { kind = "hit", spell = 66313, gap = 3, tip = "sum.b.toc.firebomb" },
        { kind = "hit", spell = 67640, gap = 3, tip = "sum.b.toc.slime" },
        { kind = "aura", spell = 67620, tip = "sum.b.toc.toxin" },
        { kind = "aura", spell = 66869, tip = "sum.b.toc.bile" },
        { kind = "death", spells = { 66313, 67640 }, id = 66317, tip = "sum.b.toc.beastfire" },
        { kind = "stack", spell = 62418, tip = "sum.b.toc.impale" },
    },
    stacks = { { spell = 62418 } },
    blocks = {
        { kind = "damageTo", label = "sum.k.toc.snobolds", names = { 34800 } },
        { kind = "taken", label = "sum.k.toc.beastpools", spells = { 66313, 67640 } },
        { kind = "dispels", label = "sum.k.toc.rage", spell = 66759 },
    },
}
