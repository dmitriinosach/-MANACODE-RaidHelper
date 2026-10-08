local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local function slots(list)
    local out = {}
    for _, s in ipairs(list) do
        for _ = 1, s.n or 1 do
            out[#out + 1] = { role = s.role, specs = s.specs, capKey = s.capKey, mark = s.mark, grp = s.grp }
        end
    end
    return out
end
ns.TEMPLATES = {
    {
        key = "voa10", label = "tplVoa10", size = 10,
        slots = slots({
            { role = "tank", n = 2 },
            { role = "heal", n = 3 },
            { role = "dd",   n = 5 },
        }),
    },
    {
        key = "icc25h", label = "tplIcc25h", size = 25,
        slots = slots({
            { role = "tank",   specs = { "bdk", "bear" } },
            { role = "tank",   specs = { "pwar", "ppal" } },
            { role = "heal",   specs = { "hpal" } },
            { role = "heal",   specs = { "rsham", "rdru", "holy" } },
            { role = "heal",   specs = { "disc" } },
            { role = "melee",  specs = { "fury" } },
            { role = "melee",  specs = { "uh" } },
            { role = "melee",  specs = { "combat" } },
            { role = "melee",  specs = { "cat" } },
            { role = "melee",  specs = { "rpal" }, n = 2 },
            { role = "melee",  n = 2 },
            { role = "ranged", specs = { "demo" } },
            { role = "ranged", specs = { "sp" }, n = 2 },
            { role = "ranged", specs = { "fire", "arc" } },
            { role = "ranged", specs = { "owl" } },
            { role = "ranged", specs = { "hunt" } },
            { role = "ranged", n = 3 },
            { role = "hybrid", n = 3 },
        }),
    },
    {
        key = "rs25h", label = "tplRs25h", size = 25,
        slots = slots({
            { role = "tank",   specs = { "bdk" }, capKey = "capTwiTank", grp = 1 },
            { role = "heal",   specs = { "hpal", "rsham" }, capKey = "capTwiHeal", grp = 1 },
            { role = "heal",   specs = { "rsham", "rdru", "holy" }, capKey = "capTwiHeal", grp = 1 },
            { role = "melee",  specs = { "rpal" }, n = 2, capKey = "capTwiMelee", grp = 1 },
            { role = "melee",  n = 5, capKey = "capTwiMelee", grp = 2 },
            { role = "tank",   specs = { "bdk" }, capKey = "capRealMT", grp = 3 },
            { role = "tank",   specs = { "ppal", "pwar", "bear" }, capKey = "capRealOT", grp = 3 },
            { role = "heal",   specs = { "hpal" }, capKey = "capRealHeal", grp = 3 },
            { role = "heal",   specs = { "rsham", "rdru", "disc" }, capKey = "capRealHeal", grp = 3 },
            { role = "melee",  specs = { "uh" }, capKey = "capRealMelee", grp = 3 },
            { role = "melee",  specs = { "combat" }, capKey = "capRealMelee", grp = 4 },
            { role = "melee",  specs = { "cat" }, capKey = "capRealMelee", grp = 4 },
            { role = "ranged", specs = { "demo" }, capKey = "capRealRanged", grp = 4 },
            { role = "ranged", specs = { "sp" }, capKey = "capRealRanged", grp = 4 },
            { role = "ranged", specs = { "fire", "arc" }, capKey = "capRealRanged", grp = 4 },
            { role = "ranged", specs = { "owl" }, capKey = "capRealRanged", grp = 5 },
            { role = "ranged", specs = { "hunt" }, capKey = "capRealRanged", grp = 5 },
            { role = "ranged", n = 3, capKey = "capRealRanged", grp = 5 },
        }),
    },
}
ns.TEMPLATE = {}
for _, t in ipairs(ns.TEMPLATES) do ns.TEMPLATE[t.key] = t end
