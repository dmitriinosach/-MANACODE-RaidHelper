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
}
