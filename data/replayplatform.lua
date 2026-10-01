local _, ns = ...
ns.replayPlatform = {
    [ns.ENC.lichking] = {
        room = "lichking",
        quake = { ids = { 72262 }, delay = 0.3, gap = 20 },
        winter = { ids = { 68981, 74270, 74271, 74272, 72259, 74273, 74274, 74275 },
                   delay = 1.0, gap = 20 },
        fall = { stagger = 0.06, fall = 1.8, depth = 14, fade = 0.35 },
        grow = { band = 1.2, spread = 0.8, grow = 1.4, rise = 3 },
        markFall = "lk_fall",
        markBack = "lk_back",
    },
}
