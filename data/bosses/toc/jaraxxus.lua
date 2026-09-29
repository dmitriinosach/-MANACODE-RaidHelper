local _, ns = ...
local JARAXXUS = "Лорд Джараксус"
ns.bosses["Лорд Джараксус"] = JARAXXUS
ns.summaries[JARAXXUS] = {
    badges = {
        { kind = "aura", spell = "Испепеление плоти", tip = "sum.b.toc.flesh" },
        { kind = "aura", spell = "Пламя Легиона", tip = "sum.b.toc.legion" },
        { kind = "hit", spell = "Геенна скверны", gap = 3, tip = "sum.b.toc.inferno" },
        { kind = "death", spells = { "Геенна скверны" }, id = 68718, tip = "sum.b.toc.infernodeath" },
    },
    blocks = {
        { kind = "casts", label = "sum.k.toc.fireball", spells = { "Огненный шар Скверны" }, srcs = { JARAXXUS } },
        { kind = "dispels", label = "sum.k.toc.netherpower", spell = "Сила Пустоты" },
        { kind = "removed", label = "sum.k.toc.jaracleanse", spells = { "Огненный шар Скверны" } },
        { kind = "damageTo", label = "sum.k.toc.jaradds", names = { "Госпожа Боли", "Врата Пустоты", "Адский вулкан" } },
        { kind = "taken", label = "sum.k.toc.jarafire", spells = { "Пламя Легиона", "Геенна скверны" } },
    },
}
