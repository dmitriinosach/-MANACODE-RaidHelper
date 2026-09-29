local _, ns = ...
local HALION = "Халион"
local MARKS = { "Пылающий огонь", "Метка пылающего огня", "Пожирание души", "Метка пожирания" }
local SIDE = {
    ["Пылающий огонь"] = "sum.b.rs.fire",
    ["Метка пылающего огня"] = "sum.b.rs.fire",
    ["Пожирание души"] = "sum.b.rs.dark",
    ["Метка пожирания"] = "sum.b.rs.dark",
}
ns.bosses["Халион"] = HALION
ns.bosses["Halion Controller"] = HALION
ns.bossPhases = ns.bossPhases or {}
ns.bossPhases[HALION] = {
    steps = {
        { key = "p1", label = "ph.p1" },
        { key = "p2", label = "ph.rs.twilight", on = { { "SPELL_DAMAGE", 75483, 75484, 75485, 75486 } } },
        { key = "p3", label = "ph.rs.both", on = {
            { "SPELL_CAST_START", 75063 },
            { "SPELL_AURA_APPLIED", 74826, 74827, 74828, 74829, 74830, 74831, 74832, 74833, 74834, 74835, 74836 },
        } },
    },
}
ns.summaries[HALION] = {
    deps = { tankHits = { "Рассекающий удар" } },
    cureLabels = SIDE,
    cureNote = "sum.b.rs.curednote",
    badges = {
        { kind = "aura", spell = "Пылающий огонь", tip = "sum.b.rs.combust" },
        { kind = "aura", spell = "Пожирание души", tip = "sum.b.rs.consume" },
        { kind = "stack", spell = "Метка пылающего огня", id = 74567, tip = "sum.b.rs.combustmark" },
        { kind = "stack", spell = "Метка пожирания", id = 74795, tip = "sum.b.rs.consumemark" },
        { kind = "death", spells = { "Падение метеора" }, id = 75879, tip = "sum.b.rs.meteordeath" },
        { kind = "death", spells = { "Лезвие сумерек", "Сумеречная пульсация" }, id = 77846,
          tip = "sum.b.rs.cutterdeath" },
        { kind = "death", spells = { "Возгорание", "Пожирание" }, id = 75884, tip = "sum.b.rs.puddledeath" },
        { kind = "death", srcs = { "Живое адское пламя", "Живой огонь" }, id = 75887, neutral = true,
          note = "sum.b.nograde", tip = "sum.b.rs.adddeath" },
    },
    blocks = {
        { kind = "removed", label = "sum.k.rs.marks", spells = MARKS },
        { kind = "taken", label = "sum.k.rs.marktaken", spells = { "Пылающий огонь", "Пожирание души" } },
        { kind = "taken", label = "sum.k.rs.puddles", spells = { "Возгорание", "Пожирание" } },
        { kind = "taken", label = "sum.k.rs.meteor", spells = { "Падение метеора" } },
        { kind = "taken", label = "sum.k.rs.cutter", spells = { "Лезвие сумерек", "Сумеречная пульсация" } },
        { kind = "damageTo", label = "sum.k.rs.adds", names = { "Живое адское пламя", "Живой огонь" } },
    },
}
