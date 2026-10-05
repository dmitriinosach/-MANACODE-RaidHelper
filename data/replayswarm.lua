local _, ns = ...
ns.replaySwarm = {
    [ns.ENC.lanathel] = {
        cast = { [71264] = true },
        aura = { [71265] = true },
        summon = { [71266] = 90, [72890] = 80 },
        lead = 2.4, span = 6, step = 0.5, life = 80, r = 4,
    },
    [ns.ENC.jaraxxus] = {
        cast = { [66197] = true, [68123] = true, [68124] = true, [68125] = true },
        aura = { [66199] = true, [68126] = true, [68127] = true, [68128] = true },
        summon = { [66200] = 60 },
        lead = 2.4, span = 6, step = 1, life = 60, r = 3, hit = 67072,
        tones = { "sem.rep.fel", "sem.rep.felCore", "sem.rep.felMark" },
    },
}
