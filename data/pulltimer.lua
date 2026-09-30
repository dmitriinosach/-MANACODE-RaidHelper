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
