local _, ns = ...
local ROOTS, BOMB = 62861, 64587
ns.summaries[ns.ENC.freya] = {
    badges = {
        { kind = "aura", spell = ROOTS, tip = "sum.b.uld.roots" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.uld.natbomb", spells = { BOMB } },
    },
}
