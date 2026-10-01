local _, ns = ...
local CHAMPIONS = ns.ENC.champions
local NAMES = {
    34458, 34451, 34459, 34448,
    34449, 34445, 34456,
    34447, 34441, 34454, 34444, 34455,
    34450, 34453,
    34461, 34460, 34469, 34467,
    34468, 34471, 34465, 34466,
    34473, 34472, 34470, 34463,
    34474, 34475,
}
for i = 1, #NAMES do ns.bosses[NAMES[i]] = CHAMPIONS end
ns.summaries[CHAMPIONS] = {
    badges = {
        { kind = "applied", spells = {
            61305, 33786, 6215, 11641, 2094, 2070, 8643,
            10308, 20066, 10890, 5246, 65877,
            1852, 25, 48817, 8983, 49802, 49803, 1833, 47481,
        }, names = NAMES, id = 118, tip = "sum.b.toc.champcc" },
    },
    blocks = {
        { kind = "dispels", label = "sum.k.toc.bubble", spell = 642 },
        { kind = "removed", label = "sum.k.toc.champcleanse", spells = {
            61305, 6215, 11641, 20066, 10890, 10308,
            45524, 1852, 13809, 65877,
        } },
    },
}
