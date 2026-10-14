local _, ns = ...
local STARS = "Environments\\Stars\\"
ns.replaySky = {
    icecrown = {
        model = STARS .. "IceCrownSky",
        bowl = { day = STARS .. "ICECROWN_SKYBOWLA", night = STARS .. "ICECROWN_SKYBOWLA_NIGHT", u0 = 0.6, u1 = 0.95,
                 at = { -180, 1, -72, 0.969, -55, 0.934, -39, 0.887, -24, 0.821, -10, 0.734, 4, 0.516, 19, 0.275,
                        33, 0.169, 48, 0.096, 62, 0.048, 77, 0.019, 90, 0 } },
        haze = { day = STARS .. "ICECROWN_SKYBOWLA", night = STARS .. "ICECROWN_SKYBOWLA_NIGHT", deg = 90,
                 at = { 0, 0.49, 11.5, 0.252, 27, 0.005 } },
        clouds = { day = STARS .. "ICECROWN_CLOUDCOVER", night = STARS .. "ICECROWN_CLOUDCOVER_NIGHT", deg = 45,
                   drift = 133.333, tint = "ffffff",
                   at = { 4, 2.93, 0, 6, 2.46, 0.13, 8, 2.28, 0.25, 10, 2, 0.5, 15, 1.68, 0.8, 20, 1.56, 0.83,
                          25, 1.25, 0.9, 36, 1, 0.95, 50, 0.75, 1, 62, 0.45, 1, 77, 0, 1 } },
        fade = {
            night = { 0, 1, 360, 1, 540, 0, 1080, 0, 1200, 1, 1440, 1 },
            day = { 0, 0, 300, 0, 360, 1, 1200, 1, 1320, 0, 1440, 0 },
            cloudDay = { 0, 0, 62.5, 0, 75, 1, 225.2, 1, 250.2, 0, 300, 0, 360, 1, 1080.9, 1, 1200.9, 0, 1440, 0 },
            cloudNight = { 0, 1, 75, 1, 112.5, 0, 200.2, 0, 225.2, 1, 360, 1, 540, 0, 960.9, 0, 1080.9, 1, 1440, 1 },
        },
        light = {
            0, { top = "000000", mid = "30799e", hor = "30799e", fog = "00313d" },
            720, { top = "21556d", mid = "3e9ac5", hor = "3e9ac5", fog = "00405a" },
        },
    },
}
