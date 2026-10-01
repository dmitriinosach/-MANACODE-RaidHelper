local _, ns = ...
local GRAVITY, LIGHT, LIGHT_DMG = 64234, 65121, 65120
ns.summaries[ns.ENC.xt002] = {
    badges = {
        { kind = "aura", spell = GRAVITY, tip = "sum.b.uld.gravity" },
        { kind = "aura", spell = LIGHT, tip = "sum.b.uld.light" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.uld.heart", names = { 33329 } },
        { kind = "taken", label = "sum.k.uld.light", spells = { LIGHT_DMG } },
        { kind = "taken", label = "sum.k.uld.gravity", spells = { GRAVITY } },
    },
}
