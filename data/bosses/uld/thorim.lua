local _, ns = ...
local CHARGE, SHOCK = 62466, 62017
ns.summaries[ns.ENC.thorim] = {
    blocks = {
        { kind = "taken", label = "sum.k.uld.charge", spells = { CHARGE } },
        { kind = "taken", label = "sum.k.uld.shock", spells = { SHOCK } },
    },
}
