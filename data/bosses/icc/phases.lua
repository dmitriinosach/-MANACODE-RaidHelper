local _, ns = ...
ns.bossPhases = ns.bossPhases or {}
local FIGHT = { key = "fight", label = "ph.fight" }
ns.bossPhases[ns.ENC.marrowgar] = {
    steps = { FIGHT },
    waves = {
        storm = { label = "ph.w.storm", on = { "SPELL_AURA_APPLIED", 69076 }, stop = { "SPELL_AURA_REMOVED", 69076 } },
        spike = { label = "ph.w.spike", on = { "SPELL_CAST_START", 69057, 70826, 72088, 72089 } },
    },
}
ns.bossPhases[ns.ENC.deathwhisper] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "p2", label = "ph.p2", on = { { "SPELL_AURA_REMOVED", 70842 } } },
    },
    waves = {
        mc = { label = "ph.w.mc", on = { "SPELL_CAST_SUCCESS", 71289 } },
    },
}
ns.bossPhases[ns.ENC.gunship] = {
    steps = { FIGHT },
    waves = {
        freeze = { label = "ph.w.freeze", on = { "SPELL_CAST_START", 69705 } },
    },
}
ns.bossPhases[ns.ENC.saurfang] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "frenzy", label = "ph.frenzy", on = { { "SPELL_AURA_APPLIED", 72737 } } },
    },
    waves = {
        beasts = { label = "ph.w.beasts", on = { "SPELL_SUMMON", 72172, 72173, 72356, 72357, 72358 } },
        mark = { label = "ph.w.mark", on = { "SPELL_AURA_APPLIED", 72293 } },
    },
}
ns.bossPhases[ns.ENC.festergut] = {
    steps = { FIGHT },
    waves = {
        inhale = { label = "ph.w.inhale", on = { "SPELL_CAST_START", 69165 } },
        blight = { label = "ph.w.blight", on = { "SPELL_CAST_START", 69195, 71219, 73031, 73032 } },
        spores = { label = "ph.w.spores", on = { "SPELL_AURA_APPLIED", 69279 } },
    },
}
ns.bossPhases[ns.ENC.rotface] = {
    steps = { FIGHT },
    waves = {
        spray = { label = "ph.w.spray", on = { "SPELL_CAST_START", 69508 } },
        infection = { label = "ph.w.infection", on = { "SPELL_CAST_SUCCESS", 69674, 71224, 73022, 73023 } },
    },
}
local PUTRICIDE_T = {
    { "SPELL_CAST_START", 71617, 72842, 72843 },
    { "SPELL_AURA_APPLIED", 70352, 74118, 70353, 74119 },
}
ns.bossPhases[ns.ENC.putricide] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "t1", label = "ph.t1", on = PUTRICIDE_T },
        { key = "p2", label = "ph.p2", on = {
            { "SPELL_AURA_REMOVED", 71615, 71618 },
            { "SPELL_CAST_START", 72851, 72852, delay = 35.6 },
        } },
        { key = "t2", label = "ph.t2", on = PUTRICIDE_T },
        { key = "p3", label = "ph.p3", on = {
            { "SPELL_AURA_REMOVED", 71615, 71618 },
            { "SPELL_CAST_START", 73121, 73122, delay = { [10] = 40, [25] = 28.7 } },
        } },
    },
    waves = {
        experiment = { label = "ph.w.experiment", on = { "SPELL_CAST_START", 70351, 71966, 71967, 71968 } },
        goo = { label = "ph.w.goo", on = { "SPELL_CAST_SUCCESS", 72615, 72295, 74280, 74281 } },
        bomb = { label = "ph.w.bomb", on = { "SPELL_CAST_SUCCESS", 71255 } },
    },
}
ns.bossPhases[ns.ENC.council] = {
    steps = { FIGHT },
    waves = {
        invocation = { label = "ph.w.invocation", on = { "SPELL_AURA_APPLIED", 70952, 70981, 70982 } },
    },
}
ns.bossPhases[ns.ENC.lanathel] = {
    steps = { FIGHT },
    waves = {
        air = { label = "ph.w.air", on = { "SPELL_CAST_SUCCESS", 73070 }, stop = { "SPELL_AURA_REMOVED", 71772 } },
        pact = { label = "ph.w.pact", on = { "SPELL_AURA_APPLIED", 71340 } },
        shadows = { label = "ph.w.shadows", on = { "SPELL_CAST_SUCCESS", 71264 } },
    },
}
ns.bossPhases[ns.ENC.valithria] = {
    steps = {
        FIGHT,
        { key = "dream", label = "ph.dream", on = { { "SPELL_CAST_START", 71189 } } },
    },
    waves = {
        suppress = { label = "ph.w.suppress", on = { "SPELL_CAST_SUCCESS", 70588 }, gap = 15 },
    },
}
ns.bossPhases[ns.ENC.sindragosa] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "p2", label = "ph.p2", on = { { "SPELL_AURA_APPLIED", 70127, 72528, 72529, 72530 } } },
    },
    waves = {
        tomb = { label = "ph.w.tomb", on = { "SPELL_CAST_START", 69712 } },
        blistering = { label = "ph.w.blistering", on = { "SPELL_CAST_START", 71049 } },
        unchained = { label = "ph.w.unchained", on = { "SPELL_CAST_SUCCESS", 69762 } },
    },
}
ns.bossPhases[ns.ENC.lichking] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "t1", label = "ph.t1", on = { { "SPELL_CAST_START", 68981, 74270, 74271, 74272 } } },
        { key = "p2", label = "ph.p2", on = { { "SPELL_CAST_START", 72262 } } },
        { key = "t2", label = "ph.t2", on = { { "SPELL_CAST_START", 72259, 74273, 74274, 74275 } } },
        { key = "p3", label = "ph.p3", on = { { "SPELL_CAST_START", 72262 } } },
        { key = "fury", label = "ph.fury", on = { { "SPELL_CAST_START", 72350 } } },
    },
    waves = {
        valkyr = { label = "ph.w.valkyr", on = { "SPELL_SUMMON", 69037 }, gap = 15 },
        horror = { label = "ph.w.horror", on = { "SPELL_CAST_START", 70372 } },
        spirit = { label = "ph.w.spirit", on = { "SPELL_CAST_SUCCESS", 69200 } },
        vile = { label = "ph.w.vile", on = { "SPELL_CAST_START", 70498 } },
        harvest = { label = "ph.w.harvest", on = { "SPELL_CAST_SUCCESS", 73654, 74295, 74296, 74297 } },
    },
}
