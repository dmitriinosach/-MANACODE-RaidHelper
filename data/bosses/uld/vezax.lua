local _, ns = ...
local VAPORS, CRASH, DARK, FLAMES, MARK = 63322, 62659, 63420, 62661, 63276
ns.summaries[ns.ENC.vezax] = {
    badges = {
        { kind = "stack", spell = VAPORS, id = VAPORS, tip = "sum.b.uld.vapors" },
        { kind = "hit", spell = CRASH, gap = 2, tip = "sum.b.uld.crash" },
        { kind = "aura", spell = MARK, tip = "sum.b.uld.mark" },
        { kind = "death", spells = { DARK, CRASH }, id = DARK, neutral = true, tip = "sum.b.uld.vezaxdeath" },
    },
    stacks = { { spell = VAPORS } },
    blocks = {
        { kind = "stacks", label = "sum.k.uld.vapors", spell = VAPORS },
        { kind = "taken", label = "sum.k.uld.crash", spells = { CRASH } },
        { kind = "taken", label = "sum.k.uld.dark", spells = { DARK }, stacks = true },
        { kind = "casts", label = "sum.k.uld.vezflames", spells = { FLAMES }, srcs = { 33271 } },
    },
}
