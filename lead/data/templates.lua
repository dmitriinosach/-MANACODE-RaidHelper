local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local function slots(list)
    local out = {}
    for _, s in ipairs(list) do
        for _ = 1, s.n or 1 do
            out[#out + 1] = { role = s.role, specs = s.specs, cap = s.cap, mark = s.mark }
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
            { role = "tank",   specs = { "bdk" }, cap = "Тьма: танк" },
            { role = "heal",   specs = { "hpal", "rsham" }, cap = "Тьма: хил" },
            { role = "heal",   specs = { "rsham", "rdru", "holy" }, cap = "Тьма: хил" },
            { role = "melee",  specs = { "rpal" }, n = 2, cap = "Тьма: мили" },
            { role = "melee",  n = 5, cap = "Тьма: мили" },
            { role = "tank",   specs = { "bdk" }, cap = "Свет: МТ" },
            { role = "tank",   specs = { "ppal", "pwar", "bear" }, cap = "Свет: ОТ" },
            { role = "heal",   specs = { "hpal" }, cap = "Свет: хил" },
            { role = "heal",   specs = { "rsham", "rdru", "disc" }, cap = "Свет: хил" },
            { role = "melee",  specs = { "uh" }, cap = "Свет: мили" },
            { role = "melee",  specs = { "combat" }, cap = "Свет: мили" },
            { role = "melee",  specs = { "cat" }, cap = "Свет: мили" },
            { role = "ranged", specs = { "demo" }, cap = "Свет: рдд" },
            { role = "ranged", specs = { "sp" }, cap = "Свет: рдд" },
            { role = "ranged", specs = { "fire", "arc" }, cap = "Свет: рдд" },
            { role = "ranged", specs = { "owl" }, cap = "Свет: рдд" },
            { role = "ranged", specs = { "hunt" }, cap = "Свет: рдд" },
            { role = "ranged", n = 3, cap = "Свет: рдд" },
        }),
    },
}
ns.TEMPLATE = {}
for _, t in ipairs(ns.TEMPLATES) do ns.TEMPLATE[t.key] = t end
