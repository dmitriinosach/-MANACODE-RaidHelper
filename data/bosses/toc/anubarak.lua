local _, ns = ...
local ANUB = ns.ENC.anubarak
ns.bosses[34564] = ANUB
ns.summaries[ANUB] = {
    badges = {
        { kind = "aura", spell = 67574, tip = "sum.b.toc.pursue" },
        { kind = "aura", spell = 68510, tip = "sum.b.toc.cold" },
        { kind = "hit", spell = 62418, gap = 3, tip = "sum.b.toc.spikes" },
        { kind = "death", spells = { 62418 }, id = 67574, tip = "sum.b.toc.spikedeath" },
        { kind = "stack", spell = 67847, tip = "sum.b.toc.expose" },
    },
    stacks = { { spell = 67847 } },
    blocks = {
        { kind = "taken", label = "sum.k.toc.spikes", spells = { 62418 } },
        { kind = "taken", label = "sum.k.toc.cold", spells = { 68510 } },
        { kind = "casts", label = "sum.k.toc.strike", spells = { 66134 } },
    },
}
