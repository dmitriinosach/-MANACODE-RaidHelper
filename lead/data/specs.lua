local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
ns.GROUP_ORDER = { "tank", "heal", "dd" }
ns.ROLE_GROUP = {
    tank   = "tank",
    heal   = "heal",
    melee  = "dd",
    ranged = "dd",
    dd     = "dd",
    hybrid = "dd",
}
ns.CLASSES = {
    { token = "DEATHKNIGHT", specs = {
        { key = "bdk",  role = "tank",   on = true,  icon = 49028 },
        { key = "fdk",  role = "melee",  on = true,  icon = 49184 },
        { key = "uh",   role = "melee",  on = true,  icon = 49206 },
    } },
    { token = "DRUID", specs = {
        { key = "bear", role = "tank",   on = true,  icon = 61336 },
        { key = "rdru", role = "heal",   on = true,  icon = 48438 },
        { key = "cat",  role = "melee",  on = true,  icon = 50334 },
        { key = "owl",  role = "ranged", on = true,  icon = 48505 },
    } },
    { token = "HUNTER", classOnly = true, specs = {
        { key = "hunt", role = "ranged", on = true,  icon = 53209 },
    } },
    { token = "MAGE", specs = {
        { key = "fire", role = "ranged", on = true,  icon = 44457 },
        { key = "arc",  role = "ranged", on = false, icon = 44425 },
    } },
    { token = "PALADIN", specs = {
        { key = "ppal", role = "tank",   on = true,  icon = 53595 },
        { key = "hpal", role = "heal",   on = true,  icon = 53563 },
        { key = "rpal", role = "melee",  on = true,  icon = 53385 },
    } },
    { token = "PRIEST", specs = {
        { key = "disc", role = "heal",   on = true,  icon = 47540 },
        { key = "holy", role = "heal",   on = true,  icon = 47788 },
        { key = "sp",   role = "ranged", on = true,  icon = 47585 },
    } },
    { token = "ROGUE", specs = {
        { key = "combat", role = "melee", on = true, icon = 51690 },
    } },
    { token = "SHAMAN", specs = {
        { key = "rsham", role = "heal",   on = true, icon = 61295 },
        { key = "enh",   role = "melee",  on = true, icon = 51533 },
        { key = "ele",   role = "ranged", on = true, icon = 51490 },
    } },
    { token = "WARLOCK", specs = {
        { key = "demo",   role = "ranged", on = true,  icon = 59672 },
        { key = "affli",  role = "ranged", on = true,  icon = 48181 },
        { key = "destro", role = "ranged", on = false, icon = 50796 },
    } },
    { token = "WARRIOR", specs = {
        { key = "pwar", role = "tank",  on = true, icon = 46968 },
        { key = "fury", role = "melee", on = true, icon = 23881 },
    } },
}
ns.SPEC = {}
for _, cls in ipairs(ns.CLASSES) do
    for _, sp in ipairs(cls.specs) do
        sp.class = cls.token
        ns.SPEC[sp.key] = sp
    end
end
