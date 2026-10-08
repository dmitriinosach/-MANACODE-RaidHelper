local _, ns = ...
ns.pullTimer = {
    early = 2,
    window = 180,
    dup = 1.5,
    min = 1,
    max = 180,
    icon = 100,
    addon = { ["DBMv4-PT"] = "pt", ["DBMv4-Pizza"] = "pizza" },
    pizza = { ["Атака"] = true, ["Pull in"] = true, ["Pull en"] = true, ["Pull dans"] = true },
    chat = {
        "Атака через (%d+) сек",
        "Пулл через (%d+)",
        "пулл через (%d+)",
        "Пул через (%d+)",
        "пул через (%d+)",
        "Pull in (%d+)",
        "pull in (%d+)",
    },
    minutes = { "мин", "min" },
}
ns.pullSniff = {
    hit = 4,
    kill = 10,
    share = 0.25,
    icon = 53,
}
ns.awardIcons = {
    jopo = 53,
    top5 = 1719,
    buffed = 57933,
    rod = 324,
    first = 5384,
    alive = 642,
    puddles = 49938,
}
