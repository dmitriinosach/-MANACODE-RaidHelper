local _, ns = ...
function ns.MakeButton(parent, name)
    local b = ns.Kit.Button(parent, name)
    b.tipTitle = false
    return b
end
local function RowEnter(self)
    self.hovered = true
    if not self.on then ns.Kit.StyleRow(self) end
    if not self.tipTitle and not self.tipLink then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if self.tipLink then
        GameTooltip:SetHyperlink(self.tipLink)
        GameTooltip:AddLine(" ")
    else
        local t = ns.Kit.C["tip.title"]
        GameTooltip:AddLine(self.tipTitle, t[1], t[2], t[3])
    end
    if self.tipLines then
        local d = ns.Kit.C["tip.dim"]
        for i = 1, #self.tipLines do
            GameTooltip:AddLine(self.tipLines[i], d[1], d[2], d[3])
        end
    end
    GameTooltip:Show()
end
local function RowLeave(self)
    self.hovered = false
    if not self.on then ns.Kit.StyleRow(self) end
    GameTooltip:Hide()
end
function ns.MakeRowButton(parent, width)
    local r = ns.Kit.Row(parent, width)
    r.tipTitle = nil
    r:SetScript("OnEnter", RowEnter)
    r:SetScript("OnLeave", RowLeave)
    return r
end
ns.Tip = ns.Kit.Tip
function ns.Num(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local sign, digits = s:match("^(%-?)(%d+)$")
    if not digits then return s end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    grouped = grouped:gsub("^ ", "")
    return sign .. grouped
end
function ns.Plural(n, forms)
    local one, few, many = forms:match("^([^|]*)|([^|]*)|([^|]*)$")
    if not one then return forms end
    local n10, n100 = n % 10, n % 100
    if n10 == 1 and n100 ~= 11 then return one end
    if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then return few end
    return many
end
ns.widgetsLoaded = true
