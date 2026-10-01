local _, ns = ...
local CHAIN, RUNE, STATIC = 63479, 63490, 63494
ns.summaries[ns.ENC.ironcouncil] = {
    badges = {
        { kind = "aura", spell = STATIC, tip = "sum.b.uld.static" },
    },
    blocks = {
        { kind = "casts", label = "sum.k.uld.chain", spells = { CHAIN }, srcs = { 32857 } },
        { kind = "taken", label = "sum.k.uld.rune", spells = { RUNE } },
    },
}
