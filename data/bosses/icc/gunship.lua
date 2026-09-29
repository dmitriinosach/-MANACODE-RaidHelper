local _, ns = ...
ns.summaries["Бой на кораблях"] = {
    badges = {
        { kind = "vehicle", id = 69400, prepull = true, tip = "sum.b.cannon" },
        { kind = "death", srcs = { "Мурадин Бронзобород", "Верховный правитель Саурфанг" }, id = 15284,
          tip = "sum.b.gunbossdeath" },
    },
    blocks = {
        { kind = "cannons", label = "sum.k.cannons", ships = { "Молот Оргрима", "Усмиритель небес" } },
        { kind = "taken", label = "sum.k.gunboss", spells = { "Рассекающий удар", "Ранящий бросок" },
          srcs = { "Верховный правитель Саурфанг", "Мурадин Бронзобород" } },
    },
}
