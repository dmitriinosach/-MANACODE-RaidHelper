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
    circle = { make = 48018, port = 48020, life = 360, r = 1.5, show = 3 },
    beacon = 53563,
}
