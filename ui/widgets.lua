local _, ns = ...
function ns.MakeButton(parent, name, kind)
    local b = ns.Kit.Button(parent, name, kind)
    b.tipTitle = false
    return b
end
function ns.MakeRowButton(parent, width)
    local r = ns.Kit.Row(parent, width)
    r.tipAnchor = "ANCHOR_LEFT"
    return r
end
ns.Tip = ns.Kit.Tip
function ns.FitText(fs, text, width)
    fs:SetWidth(width)
    fs:SetText(text)
    if fs:GetStringWidth() <= width then return end
    local cut = text
    while #cut > 1 do
        local i = #cut
        while i > 1 do
            local b = cut:byte(i)
            if b < 128 or b >= 192 then break end
            i = i - 1
        end
        cut = cut:sub(1, i - 1)
        fs:SetText(cut .. "…")
        if fs:GetStringWidth() <= width then return end
    end
    fs:SetText("…")
end
function ns.Num(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local sign, digits = s:match("^(%-?)(%d+)$")
    if not digits then return s end
    local sep = ns.lang == "enUS" and "," or " "
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    grouped = grouped:gsub("^" .. sep, "")
    return sign .. grouped
end
ns.widgetsLoaded = true
