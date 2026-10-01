local _, ns = ...
local HALION = ns.ENC.halion
local MARKS = { 74562, 74567, 74792, 74795 }
local SIDE = {
    [74562] = "sum.b.rs.fire",
    [74567] = "sum.b.rs.fire",
    [74792] = "sum.b.rs.dark",
    [74795] = "sum.b.rs.dark",
}
ns.bosses[39863] = HALION
ns.bosses[40146] = HALION
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
    deps = { tankHits = { 15284 } },
    cureLabels = SIDE,
    badges = {
        { kind = "aura", spell = 74562, tip = "sum.b.rs.combust" },
        { kind = "aura", spell = 74792, tip = "sum.b.rs.consume" },
        { kind = "stack", spell = 74567, id = 74567, tip = "sum.b.rs.combustmark" },
        { kind = "stack", spell = 74795, id = 74795, tip = "sum.b.rs.consumemark" },
        { kind = "death", spells = { 75879 }, id = 75879, tip = "sum.b.rs.meteordeath" },
        { kind = "death", spells = { 77846, 78862 }, id = 77846,
          tip = "sum.b.rs.cutterdeath" },
        { kind = "death", spells = { 75884, 75876 }, id = 75884, tip = "sum.b.rs.puddledeath" },
        { kind = "death", srcs = { 40681, 40683 }, id = 75887, neutral = true, tip = "sum.b.rs.adddeath" },
    },
    blocks = {
        { kind = "removed", label = "sum.k.rs.marks", spells = MARKS },
        { kind = "taken", label = "sum.k.rs.marktaken", spells = { 74562, 74792 } },
        { kind = "taken", label = "sum.k.rs.puddles", spells = { 75884, 75876 } },
        { kind = "taken", label = "sum.k.rs.meteor", spells = { 75879 } },
        { kind = "taken", label = "sum.k.rs.cutter", spells = { 77846, 78862 } },
        { kind = "targets", label = "sum.k.rs.targets", rest = "sum.rs.t.rest",
          groups = { { label = "sum.rs.t.halion", npcs = { 39863, 40142 } },
                     { label = "sum.rs.t.inferno", npcs = { 40681 } } },
          tags = { [39863] = "sum.rs.t.phys", [40142] = "sum.rs.t.twi" } },
    },
    stacks = { { spell = 74567 }, { spell = 74795 } },
}
