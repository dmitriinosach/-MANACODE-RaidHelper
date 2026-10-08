local _, ns = ...
ns.zoneBuff = {
    map = "IcecrownCitadel",
    id = 73825,
    ids = { 73762, 73824, 73825, 73826, 73827, 73828, 73816, 73818, 73819, 73820, 73821, 73822 },
}
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
    { id = ns.zoneBuff.id, ids = ns.zoneBuff.ids, map = ns.zoneBuff.map },
}
ns.tankSigns = {
    [71] = { class = "WARRIOR" },
    [48263] = { class = "DEATHKNIGHT" },
    [9634] = { class = "DRUID" },
    [5487] = { class = "DRUID" },
}
ns.tankSpec = {
    trees = { WARRIOR = 3, PALADIN = 2, DRUID = 2 },
    forms = { DRUID = { [5487] = true, [9634] = true, [768] = false } },
    classes = { WARRIOR = true, PALADIN = true, DRUID = true, DEATHKNIGHT = true },
    manaMax = { PALADIN = 10000 },
    defense = 400,
}
ns.tankAuras = {
    [ns.ENC.lanathel] = { [70445] = true },
}
