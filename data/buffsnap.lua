local _, ns = ...
ns.buffSnap = {
    { id = 25780, class = "PALADIN" },
    { id = 31801, class = "PALADIN" }, { id = 53736, class = "PALADIN" }, { id = 20375, class = "PALADIN" },
    { id = 20166, class = "PALADIN" }, { id = 20165, class = "PALADIN" }, { id = 21084, class = "PALADIN" },
    { id = 20164, class = "PALADIN" },
    { id = 2457, class = "WARRIOR" }, { id = 71, class = "WARRIOR" }, { id = 2458, class = "WARRIOR" },
    { id = 48266, class = "DEATHKNIGHT" }, { id = 48263, class = "DEATHKNIGHT" }, { id = 48265, class = "DEATHKNIGHT" },
    { id = 768, class = "DRUID" }, { id = 9634, class = "DRUID" }, { id = 24858, class = "DRUID" },
    { id = 33891, class = "DRUID" },
    { id = 15473, class = "PRIEST" },
    { id = 61847, class = "HUNTER" }, { id = 34074, class = "HUNTER" },
}
ns.tankSigns = {
    [71] = { class = "WARRIOR" },
    [48263] = { class = "DEATHKNIGHT" },
    [9634] = { class = "DRUID" },
    [5487] = { class = "DRUID" },
    [25780] = { class = "PALADIN", weak = true },
}
ns.tankAuras = {
    [ns.ENC.lanathel] = { [70445] = true },
}
