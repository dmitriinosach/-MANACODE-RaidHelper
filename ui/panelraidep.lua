local _, ns = ...
local Panel = ns.Panel
local ICON = "Interface\\Icons\\INV_Misc_Coin_02"
Panel.Widget({
    key = "raidep",
    order = 33,
    label = "rep.panel",
    Shown = function() return ns.RaidEP.Pending() ~= nil end,
    Build = function(row)
        Panel.Line(row, ICON, ns.T("rep.panel"))
        Panel.Reserve(row, ns.T("rep.panel.wait"))
    end,
    Update = function(row)
        local md = ns.RaidEP.Peek()
        if md then
            local _, total = ns.RaidEP.Batch(md)
            Panel.Value(row, ns.RaidEPView.Num(total), "text.warn")
        else
            Panel.Value(row, ns.T("rep.panel.wait"), "text.warn")
        end
    end,
    Tip = function(row, tip)
        local p = ns.RaidEP.Pending()
        if not p then return end
        tip.Show(row, { { kind = "head", left = ns.T("rep.panel") },
            { kind = "row", left = ns.Raid.Label({ name = p.name, map = p.map, size = p.size }) },
            { kind = "foot", left = ns.T("rep.panel.click"), key = "lmb" } })
    end,
    Click = function(_, button)
        if button == "LeftButton" then ns.RaidEPView.Open() end
    end,
})
