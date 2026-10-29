local _, ns = ...
ns.specHeal = {
    PALADIN = { [1] = true },
    PRIEST = { [1] = true, [2] = true },
    DRUID = { [3] = true },
    SHAMAN = { [3] = true },
}
ns.specSigns = {
    WARRIOR = {
        { mortalStrike = { 12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486 }, bladestorm = { 46924 } },
        { bloodthirst = { 23881, 23892, 23893, 23894, 25251, 30335 } },
        { shockwave = { 46968 }, devastate = { 20243, 30016, 30022, 47497, 47498 }, vigilance = { 50720 } },
    },
    PALADIN = {
        { beacon = { 53563 }, holyShock = { 20473, 20929, 20930, 27174, 33072, 48824, 48825 },
          illumination = { 31842 } },
        { hammer = { 53595 }, holyShield = { 20925, 20927, 20928, 27179, 48951, 48952 },
          avengersShield = { 31935, 32699, 32700, 48826, 48827 } },
        { divineStorm = { 53385 }, crusaderStrike = { 35395 } },
    },
    HUNTER = {
        { bestialWrath = { 19574 }, beastWithin = { 34471 }, intimidation = { 19577 } },
        { chimera = { 53209 }, silencing = { 34490 } },
        { explosive = { 53301, 60051, 60052, 60053 }, blackArrow = { 3674, 63668, 63669, 63670, 63671, 63672 },
          wyvern = { 19386, 24132, 24133, 27068, 49011, 49012 } },
    },
    ROGUE = {
        { mutilate = { 1329, 34411, 34412, 34413, 48663, 48666 }, hunger = { 51662 } },
        { killingSpree = { 51690 }, adrenaline = { 13750 } },
        { shadowDance = { 51713 }, shadowstep = { 36554 } },
    },
    PRIEST = {
        { penance = { 47540, 53005, 53006, 53007 }, painSuppression = { 33206 }, powerInfusion = { 10060 } },
        { circle = { 34861, 34863, 34864, 34865, 34866, 48088, 48089 }, guardian = { 47788 },
          lightwell = { 724, 27870, 27871, 28275, 48086, 48087 } },
        { shadowform = { 15473 }, vampiricTouch = { 34914, 34916, 34917, 48159, 48160 }, dispersion = { 47585 } },
    },
    DEATHKNIGHT = {
        { heartStrike = { 55050, 55258, 55259, 55260, 55261, 55262 }, runeWeapon = { 49028 },
          vampiricBlood = { 55233 }, hysteria = { 49016 } },
        { howlingBlast = { 49184, 51409, 51410, 51411 }, frostStrike = { 49143, 51416, 51417, 51418, 51419, 55268 } },
        { gargoyle = { 49206 }, scourgeStrike = { 55090, 55265, 55270, 55271 } },
    },
    SHAMAN = {
        { thunderstorm = { 51490, 59156, 59158, 59159 }, mastery = { 16166 },
          wrathTotem = { 30706, 57720, 57721, 57722 } },
        { stormstrike = { 17364 }, lavaLash = { 60103 }, feralSpirit = { 51533 }, rage = { 30823 } },
        { riptide = { 61295, 61299, 61300, 61301 }, earthShield = { 974, 32593, 32594, 49283, 49284 },
          manaTide = { 16190 } },
    },
    MAGE = {
        { barrage = { 44425, 44780, 44781 }, arcanePower = { 12042 } },
        { livingBomb = { 44457, 55359, 55360 }, dragonsBreath = { 31661, 33041, 33042, 33043, 42949, 42950 },
          combustion = { 11129 } },
        { deepFreeze = { 44572 }, iceBarrier = { 11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039 },
          waterElemental = { 31687 } },
    },
    WARLOCK = {
        { haunt = { 48181, 59161, 59163, 59164 }, unstable = { 30108, 30404, 30405, 47841, 47843 } },
        { metamorphosis = { 47241 }, empowerment = { 47193 } },
        { chaosBolt = { 50796, 59170, 59171, 59172 }, conflagrate = { 17962 },
          shadowfury = { 30283, 30413, 30414, 47846, 47847 } },
    },
    DRUID = {
        { starfall = { 48505, 53199, 53200, 53201 }, moonkin = { 24858 },
          typhoon = { 50516, 53223, 53225, 53226, 61384 }, forceOfNature = { 33831 } },
        { mangleCat = { 33876, 33982, 33983, 48565, 48566 }, mangleBear = { 33878, 33986, 33987, 48563, 48564 },
          berserk = { 50334 }, instincts = { 61336 } },
        { wildGrowth = { 48438, 53248, 53249, 53251 }, swiftmend = { 18562 }, treeOfLife = { 33891, 34123 } },
    },
}
ns.specSignSnap = { 15473, 24858 }
ns.specSwap = { 63644, 63645 }
