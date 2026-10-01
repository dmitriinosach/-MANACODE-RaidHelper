local _, ns = ...
local SHOCK, ROCKET, FLAMES = 63631, 63041, 64566
ns.summaries[ns.ENC.mimiron] = {
    blocks = {
        { kind = "taken", label = "sum.k.uld.shockblast", spells = { SHOCK }, srcs = { 33432 } },
        { kind = "taken", label = "sum.k.uld.rocket", spells = { ROCKET } },
        { kind = "taken", label = "sum.k.uld.mimflames", spells = { FLAMES } },
    },
}
