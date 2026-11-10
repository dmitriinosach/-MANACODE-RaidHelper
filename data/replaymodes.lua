local _, ns = ...
local TANK_FX = { 871, 48792, 498, 12975, 55233, 22812, 61336, 48707, 10278, 6940, 33206, 47788, 642, 66233, 31821 }
local LIFT = {}
for i = 1, #TANK_FX do LIFT[TANK_FX[i]] = 200 end
ns.replayModes = {
    order = { "normal", "heal", "tank", "dd" },
    healWin = 3,
    bigHit = 20000,
    hitMin = 1000,
    merge = 2,
    rows = 4000,
    modes = {
        normal = { key = "normal", label = "iso.mode.normal", tip = "iso.mode.normal.tip" },
        heal = {
            key = "heal", label = "iso.mode.heal", tip = "iso.mode.heal.tip", pick = "heal",
            alpha = { tank = 1, heal = 1, dd = 0.4, healed = 1, focus = 1 },
            ring = { "tank" },
            bigPct = true,
            mana = "heal",
            casts = "heal",
            raid = true,
            low = 0.35,
            feed = { kinds = { death = true }, heals = true, big = true },
        },
        tank = {
            key = "tank", label = "iso.mode.tank", tip = "iso.mode.tank.tip", pick = "tank",
            alpha = { tank = 1, heal = 1, dd = 0.4, focus = 1 },
            aggro = 1.6,
            swap = 1.5,
            bossArrows = true,
            bossIcon = 1.8,
            lift = LIFT,
            liftOn = "tank",
            feed = { kinds = { boss = true, taunt = true, def = true, help = "tank" } },
        },
        dd = {
            key = "dd", label = "iso.mode.dd", tip = "iso.mode.dd.tip", pick = "dd",
            alpha = { tank = 0.5, heal = 0.5, dd = 0.5, focus = 1 },
            fx = 12,
            buffs = true,
            bright = 1.6,
            feed = { kinds = {}, own = true, taken = true },
        },
    },
}
