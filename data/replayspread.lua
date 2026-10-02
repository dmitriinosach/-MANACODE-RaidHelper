local _, ns = ...
ns.replaySpread = {
    hold = 0.5,
    bosses = {
        [ns.ENC.lanathel] = {
            { r = 6, open = { 71772 }, span = 14, hit = { 71446, 71478, 71479, 71480 }, lead = 2,
              splash = { 71447, 71481, 71482, 71483 } },
            { r = 6, hit = { 71818, 71819, 71820, 71821 }, lead = 2, splash = { 71447, 71481, 71482, 71483 } },
        },
        [ns.ENC.festergut] = {
            { r = 8, cast = { 69240, 71218, 73019, 73020 }, aura = { 69240, 71218, 73019, 73020 },
              splash = { 69244, 71288, 73173, 73174 } },
        },
        [ns.ENC.rotface] = {
            { r = 8, aura = { 72272, 72273 }, splash = { 69244, 71288, 73173, 73174 } },
        },
        [ns.ENC.sindragosa] = {
            { r = 10, aura = { 70126 }, splash = { 70157 } },
        },
    },
}
