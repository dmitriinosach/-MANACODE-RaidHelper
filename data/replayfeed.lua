local _, ns = ...
ns.replayFeed = {
    kinds = {
        { key = "boss", icon = 72350, label = "rep.k.boss", tip = "rep.k.boss.tip" },
        { key = "phase", icon = "phase", label = "rep.k.phase", tip = "rep.k.phase.tip" },
        { key = "death", icon = "death", label = "rep.k.death", tip = "rep.k.death.tip" },
        { key = "help", icon = 1044, label = "rep.k.help", tip = "rep.k.help.tip" },
        { key = "dispel", icon = 4987, label = "rep.k.dispel", tip = "rep.k.dispel.tip" },
        { key = "kick", icon = 1766, label = "rep.k.kick", tip = "rep.k.kick.tip" },
        { key = "def", icon = 45438, label = "rep.k.def", tip = "rep.k.def.tip" },
        { key = "hero", icon = 32182, label = "rep.k.hero", tip = "rep.k.hero.tip" },
    },
    help = {
        [1044] = true,
        [10278] = true,
        [6940] = true,
        [1038] = true,
        [19752] = true,
        [64205] = "raid",
        [31821] = "raid",
        [33206] = true,
        [47788] = true,
        [64901] = "raid",
        [64843] = "raid",
        [10060] = true,
        [29166] = true,
        [34477] = true,
        [57933] = true,
    },
    hero = {
        [32182] = true,
        [54131] = true,
    },
    bosses = {
        [ns.ENC.deathwhisper] = {
            casts = { 72016 },
            auras = { 71237 },
            dispels = { 71237 },
        },
        [ns.ENC.festergut] = {
            auras = { 69279, 72550 },
        },
        [ns.ENC.putricide] = {
            casts = { 70341 },
        },
        [ns.ENC.council] = {
            casts = { 71822, 72037, 71718, 72040 },
        },
        [ns.ENC.sindragosa] = {
            casts = { 71049 },
            auras = { 69762, 70126 },
        },
        [ns.ENC.lichking] = {
            dispels = { 73787, 5229 },
        },
        [ns.ENC.halion] = {
            casts = { 8873, 75956, 75879, 75063 },
            auras = { 74562, 74792 },
            hits = { [77846] = 15 },
            dispels = { 74562, 74792 },
        },
        [39751] = {
            casts = { 75125, 74509 },
        },
        [39747] = {
            casts = { 8873, 5229 },
            auras = { 74453 },
            dispels = { 5229 },
        },
        [39746] = {
            casts = { 48560 },
        },
        [ns.ENC.beasts] = {
            casts = { 67649, 67617, 67662, 63414 },
            auras = { 67652 },
            dispels = { 5229 },
        },
        [ns.ENC.jaraxxus] = {
            casts = { 67900, 66255, 67009 },
            auras = { 67051, 66200 },
        },
        [ns.ENC.champions] = {
            casts = { 32182, 54131 },
        },
        [ns.ENC.twins] = {
            casts = { 67305, 67157, 66046, 67261, 67258 },
            dispels = { 67298, 67283 },
        },
        [ns.ENC.anubarak] = {
            auras = { 68510, 67574 },
        },
        [ns.ENC.ignis] = {
            casts = { 62681, 62488 },
            auras = { 63477 },
        },
        [ns.ENC.xt002] = {
            casts = { 62775, 63849 },
            auras = { 65120, 64234 },
        },
        [ns.ENC.ironcouncil] = {
            casts = { 61878, 61973, 63490, 63489, 61920 },
            auras = { 61888 },
            dispels = { 63489 },
        },
        [ns.ENC.kologarn] = {
            auras = { 63981 },
        },
        [ns.ENC.hodir] = {
            casts = { 61968, 63511 },
        },
        [ns.ENC.auriaya] = {
            casts = { 64386, 64678, 64688 },
        },
        [ns.ENC.thorim] = {
            auras = { 62130 },
        },
        [ns.ENC.freya] = {
            casts = { 62859 },
            auras = { 62861 },
        },
        [ns.ENC.mimiron] = {
            casts = { 65026, 64529, 63631, 63027, 64623,
                      63414, 64383 },
        },
        [ns.ENC.vezax] = {
            casts = { 62662, 63364 },
            auras = { 63276 },
        },
        [ns.ENC.yogg] = {
            casts = { 64059, 64189, 64465 },
            auras = { 63830 },
        },
        [ns.ENC.algalon] = {
            casts = { 64596, 64584 },
        },
    },
}
