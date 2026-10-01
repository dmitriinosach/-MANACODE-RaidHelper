local _, ns = ...
local FREEZE, SHARDS = 61969, 62457
ns.summaries[ns.ENC.hodir] = {
    badges = {
        { kind = "aura", spell = FREEZE, tip = "sum.b.uld.freeze" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.uld.shards", spells = { SHARDS } },
    },
}
