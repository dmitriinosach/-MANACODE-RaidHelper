local _, ns = ...
local Kit = ns.Kit or {}
ns.Kit = Kit
function Kit.FadeIn(region)
    region:SetAlpha(1)
end
function Kit.FadeOut(region, done)
    region:SetAlpha(1)
    if done then done() end
end
function Kit.PopIn(region)
    region:SetAlpha(1)
end
function Kit.PopOut(region, done)
    region:SetAlpha(1)
    if done then done() end
end
function Kit.Still(region)
end
function Kit.Moving(region)
    return nil
end
