local _, ns = ...
local SCREECH, FEAR = 64688, 64386
ns.summaries[ns.ENC.auriaya] = {
    badges = {
        { kind = "aura", spell = FEAR, tip = "sum.b.uld.fear" },
    },
    blocks = {
        { kind = "taken", label = "sum.k.uld.screech", spells = { SCREECH } },
    },
}
