local _, ns = ...
local SLAG, JETS, SCORCH = 63477, 63472, 63475
ns.summaries[ns.ENC.ignis] = {
    badges = {
        { kind = "aura", spell = SLAG, tip = "sum.b.uld.slag" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.uld.jets", spells = { JETS } },
        { kind = "taken", label = "sum.k.uld.scorch", spells = { SCORCH, 63473 } },
    },
}
