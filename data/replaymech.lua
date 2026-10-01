local _, ns = ...
ns.replayMech = {
    traps = {
        [ns.ENC.lichking] = {
            cast = { 73539, 73540 }, castTime = 0.5, boom = { 73529 }, arm = 4.5, life = 60, r = 3, blast = 10,
            slack = 3, join = 0.5, tone = "sem.rep.trap",
        },
    },
    zones = {
        [ns.ENC.council] = {
            { cast = { 72037 }, summon = { 72037 }, hit = { 71944, 72812, 72813, 72814 }, life = 30, r = 12, link = 3,
              tone = "sem.rep.vortex" },
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
