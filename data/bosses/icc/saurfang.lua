local _, ns = ...
ns.summaries["Саурфанг Смертоносный"] = {
    badges = {
        { kind = "aura", spell = "Метка падшего воителя", tip = "sum.b.mark" },
        { kind = "aura", spell = "Кипящая кровь", tip = "sum.b.boil" },
        { kind = "applied", spells = {
            "Молот правосудия", "Оглушение", "Гнев небес", "Оглушить", "Калечение",
            "Наскок", "Подлый трюк", "Отгрызть", "Ударная волна",
        }, names = { "Кровавое чудовище" }, id = 10308, tip = "sum.b.beaststun" },
        { kind = "death", srcs = { "Кровавое чудовище" }, id = 72172, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.beastdeath" },
    },
    blocks = {
        { kind = "damageTo", label = "sum.k.beasts", names = { "Кровавое чудовище" } },
    },
}
