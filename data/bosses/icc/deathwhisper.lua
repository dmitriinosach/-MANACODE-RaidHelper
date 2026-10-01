local _, ns = ...
ns.summaries[ns.ENC.deathwhisper] = {
    badges = {
        { kind = "chased", npc = 38222, grade = "red", tip = "sum.b.shade", excuse = {
            sec = 3, mc = 71289,
            auras = {
                [10890] = "fear", [6215] = "fear", [5246] = "fear",
                [17928] = "fear", [10308] = "stun", [20252] = "stun",
                [30283] = "stun", [42917] = "root", [53227] = "knock",
            },
            moved = { [49560] = "grip", [53227] = "knock", [51490] = "knock" },
        } },
        { kind = "blast", src = 38222, spell = 72012, grade = "yellow",
          off = true, tip = "sum.b.shadeblast" },
        { kind = "death", spells = { 49938 }, id = 72110, neutral = true, tip = "sum.b.dnddeath" },
        { kind = "death", srcs = { 38222 }, id = 72012, neutral = true, tip = "sum.b.shadedeath" },
        { kind = "death", srcs = {
            37890, 37949, 38009, 38136,
            38135, 37949, 38485,
        }, id = 72494, neutral = true, tip = "sum.b.trashdeath" },
        { kind = "stack", spell = 71204, tip = "sum.b.insignif" },
    },
    stacks = { { spell = 71204 } },
    mcDrain = {
        DRUID = {
            { spell = 53190, id = 53201, ids = { 48505, 53199, 53200, 53201 }, cd = 90 },
            { spell = 53227, id = 61384, ids = { 50516, 53223, 53225, 53226, 53227, 61384 }, cd = 20 },
        },
        PRIEST = {
            { spell = 10890, id = 10890, ids = { 8122, 8124, 10888, 10890 }, cd = 30 },
        },
        PALADIN = {
            { spell = 10308, id = 10308, ids = { 853, 5588, 5589, 10308 }, cd = 60 },
            { spell = 53385, id = 53385, ids = { 53385 }, cd = 10 },
        },
        DEATHKNIGHT = {
            { spell = 49560, id = 49576, ids = { 49576 }, cd = 35 },
            { spell = 47476, id = 47476, ids = { 47476 }, cd = 120 },
            { spell = 49938, id = 49938, ids = { 43265, 49936, 49937, 49938 }, cd = 30,
              tactic = true },
        },
        ROGUE = {
            { spell = 51722, id = 51722, ids = { 51722 }, cd = 60 },
        },
        WARRIOR = {
            { spell = 20252, id = 20252, ids = { 20252 }, cd = 30 },
            { spell = 5246, id = 5246, ids = { 5246 }, cd = 120, tactic = true },
            { spell = 46924, id = 46924, ids = { 46924 }, cd = 90, tactic = true },
        },
        WARLOCK = {
            { spell = 17928, id = 17928, ids = { 5484, 17928 }, cd = 40, tactic = true },
            { spell = 30283, id = 47847, ids = { 30283, 30413, 30414, 47846, 47847 }, cd = 20,
              tactic = true },
        },
        SHAMAN = {
            { spell = 51490, id = 59159, ids = { 51490, 59156, 59158, 59159 }, cd = 45, tactic = true },
        },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.adds", names = {
            37890, 37949, 38009,
            38136, 38135,
        } },
        { kind = "friendly", label = "sum.k.friendly" },
        { kind = "shades", label = "sum.k.shades", src = 38222, spell = 72012 },
        { kind = "taken", label = "sum.k.dnd", spells = { 49938 } },
        { kind = "casts", label = "sum.k.frostbolt", spells = { 59638 },
          srcs = { 36855 } },
        { kind = "removed", label = "sum.k.ladycleanse", spells = {
            71237, 72016, 59638,
        } },
    },
}
