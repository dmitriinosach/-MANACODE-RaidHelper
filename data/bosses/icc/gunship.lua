local _, ns = ...
ns.summaries[ns.ENC.gunship] = {
    badges = {
        { kind = "vehicle", id = 69400, prepull = true, tip = "sum.b.cannon" },
        { kind = "hit", spell = 69680, src = 36982, gap = 3, grade = "yellow", rule = "gunship.rocket",
          tip = "sum.b.gunrocket" },
        { kind = "death", srcs = { 36948, 36939 }, id = 15284,
          tip = "sum.b.gunbossdeath" },
    },
    blocks = {
        { kind = "cannons", label = "sum.k.cannons", ships = { 37215, 37540 } },
        { kind = "taken", label = "sum.k.gunboss", spells = { 15284, 70309 },
          srcs = { 36939, 36948 } },
    },
}
