local _, ns = ...
ns.replayClass = {
    zones = {
        { aura = 53201, r = 30, dur = 10, tone = "sem.rep.clsStar", icon = 53201, own = true },
        { cast = 51052, r = 7, dur = 10, tone = "sem.rep.clsAmz", icon = 51052 },
    },
    cones = {
        { spell = 53227, len = 30, deg = 90, dur = 1.5, join = 0.6 },
    },
    rings = {
        { aura = 64843, dur = 8, tone = "sem.rep.clsHymn", icon = 64843 },
        { aura = 64901, dur = 8, tone = "sem.rep.clsHope", icon = 64901 },
        { cast = 16190, dur = 12, tone = "sem.rep.clsTide", icon = 16190 },
    },
    jumps = {
        { cast = 1953, min = 5, show = 2 },
        { cast = 781, min = 5, show = 2 },
    },
    trails = {
        { aura = 54861, cast = 55004, dur = 5, step = 0.18, life = 3.2, r = 0.85, tone = "sem.rep.clsBoots",
          core = "sem.rep.clsBootsCore", old = "sem.rep.clsBootsOld" },
    },
    circle = { make = 48018, port = 48020, life = 360, r = 2.6, show = 3 },
    beacon = 53563,
    totemDur = 300,
    totemR = 30,
    totemTone = { fire = "sem.rep.totemFire", earth = "sem.rep.totemEarth", water = "sem.rep.totemWater",
                  air = "sem.rep.totemAir" },
    totems = {
        [58704] = { el = "fire", dur = 60, r = 20 }, [58703] = { el = "fire", dur = 60, r = 20 },
        [58734] = { el = "fire", dur = 20, r = 8 }, [58731] = { el = "fire", dur = 20, r = 8 },
        [58656] = { el = "fire" }, [58652] = { el = "fire" }, [58649] = { el = "fire" },
        [57722] = { el = "fire", r = 40 }, [57721] = { el = "fire", r = 40 }, [57720] = { el = "fire", r = 40 },
        [30706] = { el = "fire", r = 40 },
        [2894] = { el = "fire", dur = 120, r = 0 }, [58745] = { el = "fire" },
        [58753] = { el = "earth" }, [58751] = { el = "earth" }, [58643] = { el = "earth" }, [57622] = { el = "earth" },
        [8143] = { el = "earth" }, [2484] = { el = "earth", dur = 45, r = 10 }, [58582] = { el = "earth", dur = 15, r = 0 },
        [2062] = { el = "earth", dur = 120, r = 0 },
        [58757] = { el = "water" }, [58756] = { el = "water" }, [58774] = { el = "water" }, [58773] = { el = "water" },
        [8170] = { el = "water" }, [58739] = { el = "water" },
        [3738] = { el = "air" }, [8512] = { el = "air" }, [8177] = { el = "air", dur = 45 }, [58749] = { el = "air" },
        [6495] = { el = "air", r = 0 },
    },
    recall = 36936,
    chans = {
        [48156] = { tone = "sem.rep.chanShadow", dur = 3 }, [48155] = { tone = "sem.rep.chanShadow", dur = 3 },
        [53023] = { tone = "sem.rep.chanShadow", dur = 5 }, [53022] = { tone = "sem.rep.chanShadow", dur = 5 },
        [47855] = { tone = "sem.rep.chanShadow", dur = 15 }, [47857] = { tone = "sem.rep.chanShadow", dur = 5 },
        [5138] = { tone = "sem.rep.chanShadow", dur = 5 },
        [42846] = { tone = "sem.rep.chanArcane", dur = 5 }, [42845] = { tone = "sem.rep.chanArcane", dur = 5 },
        [53007] = { tone = "sem.rep.chanHoly", dur = 2 }, [53006] = { tone = "sem.rep.chanHoly", dur = 2 },
        [53005] = { tone = "sem.rep.chanHoly", dur = 2 }, [47540] = { tone = "sem.rep.chanHoly", dur = 2 },
    },
    chains = {
        [55459] = "sem.rep.chainHeal", [55458] = "sem.rep.chainHeal", [49273] = "sem.rep.chainHeal",
        [49271] = "sem.rep.chainBolt", [49270] = "sem.rep.chainBolt", [49269] = "sem.rep.chainBolt",
    },
    chainJoin = 0.4,
    chainShow = 1.5,
    traps = {
        { cast = { 13809 }, hit = { 13810 }, life = 30, arm = 10, r = 10, burn = 30, show = 30, tone = "sem.rep.clsTrapIce",
          icon = 13809, ice = { "sem.rep.clsTrapIceFog", "sem.rep.clsTrapIceCore" } },
    },
}
