local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local tconcat = table.concat
local MAX_TARGETS = 6
local LABEL_GAP = 2
local LABEL_PAD = 3
local TC = {}
ns.TimelineCast = TC
local function T(key)
    return ns.T(key)
end
function TC.Num(n)
    if n >= 1e6 then return (format("%.2f", n / 1e6):gsub("%.", ",")) .. T("num.m") end
    if n >= 1e5 then return format("%.0f", n / 1e3) .. T("num.k") end
    if n >= 1e3 then return (format("%.1f", n / 1e3):gsub("%.", ",")) .. T("num.k") end
    return tostring(floor(n + 0.5))
end
function TC.Sec(v)
    return (format("%.1f", max(0, v)):gsub("%.", ","))
end
local Num, Sec = TC.Num, TC.Sec
local function MissName(how, short)
    local key = (short and "tl.cast.s." or "tl.cast.miss.") .. tostring(how)
    local text = T(key)
    if text == key then return tostring(how) end
    return text
end
local function TopMiss(miss)
    local best, n = nil, 0
    for how, k in pairs(miss or {}) do
        if k > n or (k == n and best and how < best) then best, n = how, k end
    end
    return best
end
local function Parts(tg, bare)
    local out = {}
    if tg.dmg > 0 then
        local s = format(T("tl.cast.dmg"), Num(tg.dmg))
        if tg.n > 1 and tg.heal == 0 then s = s .. format(T("tl.cast.hits"), tg.n) end
        if tg.heal == 0 and tg.crit == 1 and tg.n == 1 then s = s .. T("tl.cast.crit")
        elseif tg.heal == 0 and tg.crit > 0 then s = s .. format(T("tl.cast.crits"), tg.crit) end
        out[#out + 1] = s
    end
    if tg.heal > 0 then
        local s = format(T("tl.cast.heal"), Num(max(0, tg.heal - tg.over)))
        if tg.over > 0 then s = s .. format(T("tl.cast.over"), Num(tg.over)) end
        if tg.n > 1 and tg.dmg == 0 then s = s .. format(T("tl.cast.hits"), tg.n) end
        if tg.dmg == 0 and tg.crit == 1 and tg.n == 1 then s = s .. T("tl.cast.crit")
        elseif tg.dmg == 0 and tg.crit > 0 then s = s .. format(T("tl.cast.crits"), tg.crit) end
        out[#out + 1] = s
    end
    if tg.miss and not bare then
        local kinds = {}
        for how in pairs(tg.miss) do kinds[#kinds + 1] = how end
        table.sort(kinds)
        for i = 1, #kinds do
            local k = tg.miss[kinds[i]]
            out[#out + 1] = k > 1 and format(T("tl.cast.times"), MissName(kinds[i]), k) or MissName(kinds[i])
        end
    end
    if tg.aura and not bare then
        local key
        if tg.auraTo then key = tg.refresh and "tl.cast.aura.new" or "tl.cast.aura"
        else key = tg.refresh and "tl.cast.aura.newopen" or "tl.cast.aura.open" end
        out[#out + 1] = format(T(key), tg.aura, Sec((tg.auraTo or 0) - (tg.auraAt or 0)))
    end
    if tg.dispel then out[#out + 1] = format(T("tl.cast.dispel"), tg.dispel) end
    if tg.kick then out[#out + 1] = format(T("tl.cast.kick"), tg.kick) end
    return tconcat(out, ", ")
end
local function HitText(hit)
    if hit.amount then return format(T("tl.cast.mob.hit"), Num(hit.amount)) end
    return format(T("tl.cast.mob.miss"), MissName(hit.miss))
end
local function Sub(lines, text)
    lines[#lines + 1] = { kind = "sub", left = text }
end
local function Taunt(lines, it, tg, who, gap)
    local name = tg.name or "?"
    local how = TopMiss(tg.miss)
    if tg.aura then
        local text = tg.auraTo and format(T("tl.cast.taunt.ok"), name, Sec(tg.auraTo - (tg.auraAt or it.t)))
            or format(T("tl.cast.taunt.open"), name)
        lines[#lines + 1] = { text, "text.good", gap }
    elseif how == "IMMUNE" then
        lines[#lines + 1] = { format(T("tl.cast.taunt.immune"), name), "text.bad", gap }
    else
        lines[#lines + 1] = { format(T("tl.cast.taunt.miss"), name, MissName(how)), "text.bad", gap }
    end
    local rest = Parts(tg, true)
    if rest ~= "" then Sub(lines, format(T("tl.cast.target"), name, rest)) end
    local f = tg.follow
    if not f then return end
    local first, away = f.first, f.away
    if not first then
        Sub(lines, format(T("tl.cast.mob.none"), Sec(f.stop)))
    elseif first.who ~= who then
        Sub(lines, format(T("tl.cast.mob.other"), tostring(first.who), Sec(first.dt), HitText(first)))
    else
        Sub(lines, format(T("tl.cast.mob.on"), who, Sec(first.dt), HitText(first)))
        if away then
            local off = tg.auraTo and (tg.auraTo - it.t)
            local after = off and away.dt >= off and format(T("tl.cast.mob.after"), Sec(away.dt - off)) or ""
            Sub(lines, format(T("tl.cast.mob.away"), tostring(away.who), Sec(away.dt), after, HitText(away)))
        else
            Sub(lines, format(T("tl.cast.mob.stay"), who, Sec(f.stop)))
        end
    end
end
function TC.Tip(lines, it, who)
    local res = it.res
    if not res or #res.list == 0 then
        lines[#lines + 1] = { T("tl.cast.none"), "tip.dim", true }
        return
    end
    local gap = true
    for i = 1, #res.list do
        if i > MAX_TARGETS then
            lines[#lines + 1] = { format(T("tl.cast.more"), #res.list - MAX_TARGETS), "tip.dim" }
            break
        end
        local tg = res.list[i]
        if it.taunt and (tg.aura or tg.miss) then
            Taunt(lines, it, tg, who or "?", gap)
            gap = false
        else
            local text = Parts(tg)
            if text ~= "" then
                lines[#lines + 1] = { format(T("tl.cast.target"), tg.name or "?", text), "text.secondary", gap }
                gap = false
            end
        end
    end
    if gap then lines[#lines + 1] = { T("tl.cast.none"), "tip.dim", true } end
end
function TC.Short(it)
    local res = it.res
    if not res then return nil end
    local dmg, heal, landed, how, dispel, kick = 0, 0, false, nil, false, false
    for i = 1, #res.list do
        local tg = res.list[i]
        dmg = dmg + tg.dmg
        heal = heal + max(0, tg.heal - tg.over)
        if tg.aura then landed = true end
        how = how or TopMiss(tg.miss)
        if tg.dispel then dispel = true end
        if tg.kick then kick = true end
    end
    if it.taunt and landed then return T("tl.cast.s.taunt"), "text.good" end
    if it.taunt and how then return MissName(how, true), "text.bad" end
    if kick then return T("tl.cast.s.kick"), nil end
    if dispel then return T("tl.cast.s.dispel"), nil end
    if dmg > 0 then return Num(dmg), nil end
    if heal > 0 then return format(T("tl.cast.s.heal"), Num(heal)), nil end
    if how then return MissName(how, true), "text.bad" end
    return nil
end
function TC.Label(b, it, markW, room)
    local text, tone = TC.Short(it)
    local width = room - markW - LABEL_GAP - LABEL_PAD
    if not text or width < 8 then return 0 end
    b.label:SetPoint("LEFT", markW + LABEL_GAP, 0)
    b.label:SetWidth(width)
    b.label:SetText(text)
    local used = b.label:GetStringWidth()
    if used > width then
        b.label:SetText("")
        return 0
    end
    ns.Kit.Tone(b.label, tone or "text.secondary")
    b.castLabel = true
    return used + LABEL_GAP
end
function TC.Readout(it)
    if not it then return nil end
    local text = TC.Short(it)
    if not text then return it.label end
    return format(T("tl.cast.read"), it.label, text)
end
