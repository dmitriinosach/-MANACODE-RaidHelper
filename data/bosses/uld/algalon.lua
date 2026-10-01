local _, ns = ...
local BANG, SMASH, HOLE, BARRAGE = 64584, 64598, 65108, 64607
ns.summaries[ns.ENC.algalon] = {
    badges = {
        { kind = "hit", spell = BANG, gap = 2, tip = "sum.b.uld.bang" },
        { kind = "hit", spell = HOLE, gap = 2, tip = "sum.b.uld.hole" },
        { kind = "hit", spell = SMASH, gap = 2, tip = "sum.b.uld.smash" },
        { kind = "death", spells = { BANG, SMASH, HOLE }, id = BANG, neutral = true, tip = "sum.b.uld.algadeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.uld.stars", names = { 32955 } },
        { kind = "damageTo", label = "sum.k.uld.constel", names = { 33052 } },
        { kind = "taken", label = "sum.k.uld.hole", spells = { HOLE } },
        { kind = "taken", label = "sum.k.uld.bang", spells = { BANG } },
        { kind = "taken", label = "sum.k.uld.barrage", spells = { BARRAGE } },
    },
}
