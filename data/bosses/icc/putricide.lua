local _, ns = ...
ns.summaries[ns.ENC.putricide] = {
    deps = {
        mechs = {
            { key = "volatile", text = "sum.dd.m.volatile", spells = { 72625 } },
            { key = "gascloud", text = "sum.dd.m.gascloud", spells = { 70701 }, by = "chased" },
            { key = "plague", text = "sum.dd.m.plague", held = "sum.dd.m.plagueheld", spells = { 72856 }, by = "passed" },
        },
    },
    held = { sec = 1, auras = { [70447] = "root", [71615] = "stun", [71618] = "stun" } },
    badges = {
        { kind = "hit", spell = 70341, gap = 2, pool = 6, tip = "sum.b.puddle", off = true, held = true },
        { kind = "aura", spell = 72550, tip = "sum.b.goo", held = true,
          shed = { [70853] = 15, [72458] = 15, [72873] = 20, [72874] = 20 } },
        { kind = "aura", spell = 72620, tip = "sum.b.choke", held = true,
          shed = { [71278] = 15, [72460] = 15, [72619] = 20, [72620] = 20 } },
        { kind = "caught", spell = 70701, aura = 72833, grade = "red", held = true, tip = "sum.b.cloud" },
        { kind = "applied", spells = { 72876 }, names = { 37697, 37562 },
          id = 72876, tip = "sum.b.abomslow" },
        { kind = "death", spells = { 72625 }, id = 72625, neutral = true, tip = "sum.b.oozeblastdeath" },
        { kind = "death", spells = { 70341 }, id = 72869, neutral = true, tip = "sum.b.puddledeath" },
        { kind = "stack", spell = 72507, tip = "sum.b.mutplague" },
        { kind = "stack", spell = 72856, pass = true, tip = "sum.b.unbound" },
    },
    stacks = { { spell = 72507 }, { spell = 72856, pass = true } },
    blocks = {
        { kind = "oozes", label = "sum.k.oozes", green = 37697, red = 37562,
          names = { 37697, 37562 },
          auras = { rt = 72553, gt = 72838,
                    ov = 74118, gv = 74119 },
          icons = { rt = 72833, gt = 72838, ov = 74118, gv = 74119 } },
        { kind = "abom", label = "sum.k.abom", npc = 38285, enter = 70308, power = true,
          slow = 72876, eat = 72527, names = { 37697, 37562 },
          icons = { slow = 72876, eat = 72527 } },
        { kind = "plague", label = "sum.k.unbound", spell = 72856 },
    },
}
