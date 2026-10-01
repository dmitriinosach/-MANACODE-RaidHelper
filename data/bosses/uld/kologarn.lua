local _, ns = ...
local GRIP, BEAM = 64292, 63976
ns.summaries[ns.ENC.kologarn] = {
    badges = {
        { kind = "aura", spell = GRIP, tip = "sum.b.uld.grip" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.uld.arms", names = { 32933, 32934 } },
        { kind = "taken", label = "sum.k.uld.beam", spells = { BEAM } },
    },
}
