local _, ns = ...
ns.mapAreas = {
    [605] = "IcecrownCitadel",
    [530] = "Ulduar",
    [544] = "TheArgentColiseum",
    [610] = "TheRubySanctum",
}
ns.mapTerrain = {
    Ulduar = true,
}
ns.mapScale = {
    IcecrownCitadel = {
        [0] = { w = 12200.0, h = 8133.3 },
        [1] = { w = 1355.5, h = 903.6 },
        [2] = { w = 1067.0, h = 711.3 },
        [3] = { w = 195.5, h = 130.3 },
        [4] = { w = 773.7, h = 515.8 },
        [5] = { w = 1148.7, h = 765.8 },
        [6] = { w = 373.7, h = 249.1 },
        [7] = { w = 293.3, h = 195.5 },
        [8] = { w = 247.9, h = 165.3 },
    },
    Ulduar = {
        [1] = { w = 3287.5, h = 2191.7 },
        [2] = { w = 669.5, h = 446.3 },
        [3] = { w = 1328.5, h = 885.6 },
        [4] = { w = 910.5, h = 607.0 },
        [5] = { w = 1569.5, h = 1046.3 },
        [6] = { w = 619.5, h = 413.0 },
    },
    TheArgentColiseum = {
        [0] = { w = 2600.0, h = 1733.3 },
        [1] = { w = 370.0, h = 246.7 },
        [2] = { w = 740.0, h = 493.3 },
    },
    TheRubySanctum = {
        [0] = { w = 752.1, h = 502.1 },
    },
}
ns.maps = {
    [ns.ENC.marrowgar] = {
        area = "IcecrownCitadel",
        rooms = {
            [1] = { flip = true, crop = { 0.3085, 0.4534, 0.4501, 0.6381 } },
        },
    },
    [ns.ENC.deathwhisper] = {
        area = "IcecrownCitadel",
        rooms = {
            [1] = { flip = true, crop = { 0.3292, 0.4337, 0.6450, 0.8863 } },
        },
    },
    [ns.ENC.saurfang] = {
        area = "IcecrownCitadel",
        rooms = {
            [3] = { crop = { 0.3105, 0.7539, 0.1864, 0.8651 } },
        },
    },
    [ns.ENC.festergut] = {
        area = "IcecrownCitadel",
        rooms = {
            [5] = { crop = { 0.1558, 0.2422, 0.5997, 0.7113 } },
        },
    },
    [ns.ENC.rotface] = {
        area = "IcecrownCitadel",
        rooms = {
            [5] = { crop = { 0.1516, 0.2409, 0.3560, 0.4957 } },
        },
    },
    [ns.ENC.putricide] = {
        area = "IcecrownCitadel",
        rooms = {
            [5] = { crop = { 0.0516, 0.1560, 0.4674, 0.6240 } },
        },
    },
    [ns.ENC.council] = {
        area = "IcecrownCitadel",
        rooms = {
            [5] = { crop = { 0.4428, 0.5772, 0.0548, 0.2187 } },
        },
    },
    [ns.ENC.lanathel] = {
        area = "IcecrownCitadel",
        rooms = {
            [6] = { crop = { 0.3870, 0.6082, 0.2165, 0.6579 } },
        },
    },
    [ns.ENC.valithria] = {
        area = "IcecrownCitadel",
        rooms = {
            [5] = { crop = { 0.7208, 0.8119, 0.6434, 0.8395 } },
        },
    },
    [ns.ENC.sindragosa] = {
        area = "IcecrownCitadel",
        rooms = {
            [4] = { crop = { 0.3071, 0.4421, 0.0799, 0.2581 } },
        },
    },
    [ns.ENC.lichking] = {
        area = "IcecrownCitadel",
        rooms = {
            [7] = { crop = { 0.3452, 0.7955, 0.1062, 0.8227 } },
            [8] = { crop = { 0.3026, 0.6116, 0.2848, 0.7961 }, note = "frostmourne" },
        },
    },
}
