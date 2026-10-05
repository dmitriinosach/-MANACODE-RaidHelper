local _, ns = ...
ns.replayMech = {
    traps = {
        [ns.ENC.lichking] = {
            cast = { 73539, 73540 }, castTime = 0.5, boom = { 73529 }, arm = 4.5, life = 60, r = 3, blast = 10,
            slack = 3, join = 0.5, tone = "sem.rep.trap",
        },
    },
    bombs = {
        [ns.ENC.putricide] = {
            show = "floor", cast = { 71255 }, gas = { 71278, 72460, 72619, 72620 },
            boom = { 71279, 72459, 72621, 72622 }, spawn = 1, fuse = 11, r = 3, blast = 10, reach = 8,
            tone = "sem.rep.gas",
        },
        [ns.ENC.sindragosa] = {
            show = "banner", boom = { 69845, 71053, 71054, 71055 }, lead = 5.5, join = 1, icon = 69845,
        },
    },
    chase = {
        [ns.ENC.putricide] = {
            { npc = 37697, aura = { 70447, 72836, 72837, 72838 } },
            { npc = 37562, aura = { 70672, 72455, 72832, 72833 } },
        },
        [ns.ENC.rotface] = {
            { npc = 36897, spawn = { 69674, 71224, 73022, 73023 }, swing = true, link = 1.5 },
        },
        [ns.ENC.anubarak] = {
            { npc = 34564, aura = { 67574 } },
        },
    },
    winters = {
        [ns.ENC.lichking] = {
            aura = { 68981, 74270, 74271, 74272, 72259, 74273, 74274, 74275 }, hit = { 68983, 73791, 73792, 73793 },
            castTime = 2.5, full = 0.9, r0 = 4, r = 45, tone = "sem.rep.winter",
            tick = 1, wave = 2.5, waves = 4, waveIn = 0.15, edge = 0.35,
            waveTone = "sem.rep.winterWave", edgeTone = "sem.rep.winterEdge",
        },
    },
    souls = {
        [ns.ENC.lichking] = { aura = { 73655, 74276 }, room = "frostmourne" },
    },
    zones = {
        [ns.ENC.council] = {
            { cast = { 72037 }, summon = { 72037 }, hit = { 71944, 72812, 72813, 72814 }, life = 30, r = 12, link = 3,
              tone = "sem.rep.vortex" },
        },
        [ns.ENC.xt002] = {
            { summon = { 64235 }, drop = { 64234 }, hit = { 64206 }, life = 180, r = 10, link = 0.5,
              tone = "sem.rep.shadow" },
            { summon = { 64203 }, drop = { 63024 }, hit = { 64208 }, life = 180, r = 5, link = 0.5,
              tone = "sem.rep.shadow" },
        },
    },
    realms = {
        [ns.ENC.halion] = {
            aura = { 74807 }, leave = { 74812 }, split = { 75063 },
            twi = { 40142, 40083, 40100, 40468, 40469 },
            phys = { 39863, 40681, 40683, 40029 },
            boss = { [39863] = 1, [40142] = 2 },
            gap = 3, pad = 1, join = 15,
            puddles = {
                { aura = 74562, mark = 74567, realm = 1, base = 3, per = 2, max = 20, tone = "sem.rep.fire" },
                { aura = 74792, mark = 74795, realm = 2, base = 3, per = 2, max = 20, tone = "sem.rep.shadow" },
            },
            meteor = { hit = { 75879 }, join = 1, r = 8, burn = 3, flash = 1, realm = 1, tone = "sem.rep.fire" },
        },
    },
    cutters = {
        [ns.ENC.halion] = {
            hit = { 74769, 77844, 77845, 77846 }, pulse = { 78862 },
            pairs = { [40083] = 0, [40100] = 0, [40468] = 1, [40469] = 1 },
            start = { 75476, 75483, 75484, 75485, 75486 },
            cx = 490.66, cy = 362.55, r = 46,
            a0 = 89, wps = 9.85, prior = 8, sigma = 5, near = 4,
            warn = 5, burn = 10, period = 30.1, first = 12,
        },
    },
}
