local _, ns = ...
ns.replayCue = {
    rings = {
        [ns.ENC.sindragosa] = {
            { cast = { 71049 }, sub = "SPELL_CAST_START", hit = { 71049 }, lead = 5, slack = 2, r = 25, flash = 1,
              tone = "sem.rep.cold", flashTone = "sem.rep.coldFlash" },
        },
    },
    arrows = {
        [ns.ENC.lanathel] = { { cast = { 71477 }, dur = 3, tone = "sem.rep.bite" } },
    },
    links = {
        [ns.ENC.lanathel] = { { aura = { 70445 }, tone = "sem.rep.mirror" } },
    },
}
