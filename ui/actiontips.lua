local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local TIMES = 8
local KICK_TIMES = 15
local GLYPH = "|T%s:14:14:0:0:64:64:5:59:5:59|t"
local Tips = {}
ns.ActionTips = Tips
local function T(key)
    return ns.T(key)
end
local function Clock(sec)
    return ns.BadgeTips.Clock(max(0, sec))
end
local function Put(out, kind, left, right, mid, tone)
    out[#out + 1] = { kind = kind, left = left, right = right, mid = mid, tone = tone }
end
local function Head(out, text, right)
    out[#out + 1] = { kind = "head", left = text, right = right }
end
local function More(out, n)
    if n > TIMES then Put(out, "sub", (format(T("sum.tip.more"), n - TIMES):gsub("^%s+", ""))) end
end
local function Tone(ok, all)
    if ok == 0 and all > 0 then return "bad" end
    if ok == all and all > 0 then return "good" end
    return nil
end
local function Miss(kind)
    return ns.L["sum.miss." .. tostring(kind)] or tostring(kind)
end
function Tips.Glyph(id)
    local tex = id and ns.Effects and ns.Effects.IconById(id)
    if not tex and id and GetSpellTexture then tex = GetSpellTexture(id) end
    return tex and format(GLYPH, tex) or nil
end
local function Spell(id, name)
    return Tips.Glyph(id) or (name or "?")
end
function Tips.rebuff(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.count"), tostring(st.n))
    for k = 1, min(TIMES, st.n) do
        local dup = st.dups and st.dups[k]
        Put(out, "sub", Clock(st.times[k]) .. " " .. Spell(st.ids and st.ids[k], st.spells[k]), st.notes[k],
            dup and format(T("sum.tt.dupof"), dup) or nil, dup and "bad" or nil)
    end
    More(out, st.n)
    return out
end
function Tips.rebuffed(st, def)
    local out = {}
    Head(out, T(def.tip))
    for k = 1, st.n do
        local glyph = Tips.Glyph(st.rezId and st.rezId[k])
        Put(out, "row", (glyph and (glyph .. " ") or "") .. st.rezBy[k], Clock(st.times[k]),
            not glyph and st.rezSp[k] or nil)
        local any = false
        for m = 1, #st.rt do
            if st.rk[m] == k then
                any = true
                local dup = st.rd[m]
                Put(out, "sub", Clock(st.rt[m]) .. " " .. Spell(st.ri and st.ri[m], st.rs[m]), st.rg[m],
                    dup and format(T("sum.tt.dupof"), dup) or nil, dup and "bad" or nil)
            end
        end
        if not any then Put(out, "sub", T("sum.tt.norebuff"), nil, nil, "dim") end
        if st.miss[k] then
            Put(out, "row", T("sum.tt.missing"), nil, nil, "bad")
            local m = 0
            for name in tostring(st.miss[k]):gmatch("[^,]+") do
                m = m + 1
                local glyph = Tips.Glyph(st.missId and st.missId[k] and st.missId[k][m])
                Put(out, "sub", (glyph and (glyph .. " ") or "") .. (name:gsub("^%s+", "")))
            end
        end
    end
    return out
end
function Tips.cc(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.ok"), format(T("sum.tt.of"), st.hits, st.n), nil, Tone(st.hits, st.n))
    ns.BadgeTips.Uses(out, st, true)
    for k = 1, min(TIMES, st.n) do
        local ok = st.res[k] == "ok"
        local what
        if ok then
            what = st.outs[k] and format(T("sum.tt.held"), floor(st.outs[k] + 0.5)) or T("sum.tt.landed")
        else
            what = Miss(st.res[k])
        end
        Put(out, "sub", Clock(st.times[k]), st.notes[k], st.spells[k] .. " — " .. what, ok and "good" or "dim")
    end
    More(out, st.n)
    return out
end
function Tips.wrath(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.wrathok"), format(T("sum.tt.of"), st.hits, st.n), nil, Tone(st.hits, st.n))
    Put(out, "row", T("sum.tt.stunned"), tostring(st.amount))
    for k = 1, min(TIMES, st.n) do
        local c = st.cnt[k]
        Put(out, "sub", Clock(st.times[k]), format(T("sum.tt.stunof"), c, max(c, st.hitn[k])), nil,
            c > 0 and "good" or "dim")
    end
    More(out, st.n)
    return out
end
local function WhyText(why)
    local Dec = ns.BadgeTips.Dec
    if why.k == "mc" then
        if why.left then return format(T("sum.tt.shadewhy.mcleft"), why.sp, Dec(why.left, 1)) end
        return format(T("sum.tt.shadewhy.mc"), why.sp)
    end
    local src = why.src or "?"
    if why.mc then src = format(T("sum.tt.shadewhy.ctl"), src) end
    local text = format(T("sum.tt.shadewhy"), T("sum.tt.shadewhy." .. why.k), why.sp, src, Clock(why.at),
        Dec(why.gap, 1))
    if why.left and why.left < why.gap - 0.05 then
        text = text .. format(T("sum.tt.shadewhy.left"), Dec(why.left, 1))
    end
    return text
end
function Tips.chased(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.count"), tostring(st.n))
    for k = 1, min(TIMES, st.n) do
        local cnt = st.cnt and st.cnt[k]
        Put(out, "sub", Clock(st.times[k]), st.dmgs and st.dmgs[k] and ns.BadgeTips.Short(st.dmgs[k]) or nil,
            cnt and format(T("sum.tt.shadehit"), cnt) or nil)
        local why = st.why and st.why[k]
        if why then Put(out, "sub", WhyText(why), nil, nil, "good") end
    end
    More(out, st.n)
    return out
end
function Tips.blast(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.count"), tostring(st.n))
    Put(out, "row", T("sum.tt.dmg"), ns.BadgeTips.Short(st.amount))
    for k = 1, min(TIMES, st.n) do
        Put(out, "sub", Clock(st.times[k]), ns.BadgeTips.Short(st.dmgs[k] or 0),
            format(T("sum.tt.shadeof"), st.notes[k]))
    end
    More(out, st.n)
    return out
end
function Tips.bounce(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.bounced"), tostring(st.n))
    local list = {}
    for key, n in pairs(st.by or {}) do list[#list + 1] = { key = key, n = n } end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.key < b.key
    end)
    for k = 1, #list do
        local key = list[k].key
        if key:sub(1, 1) == "#" then key = T("sum.cat." .. key:sub(2)) end
        Put(out, "sub", key, format("x%d", list[k].n))
    end
    return out
end
local function Pct(v)
    return format("%d%%", floor(v * 100 + 0.5))
end
function Tips.sunder(st, def)
    local out = {}
    Head(out, T(def.tip))
    Put(out, "row", T("sum.tt.sunder.n"), tostring(st.n))
    if st.hits > 0 then Put(out, "sub", T("sum.tt.sunder.re"), tostring(st.hits), nil, "dim") end
    if (st.made or 0) > 0 then Put(out, "row", T("sum.tt.sunder.made"), tostring(st.made), nil, "good") end
    local list = st.bosses or {}
    local exposed = false
    for k = 1, #list do
        local b = list[k]
        if #list > 1 then Put(out, "row", b.name, nil, nil, "dim") end
        if b.five then
            Put(out, "sub", T("sum.tt.sunder.five"), Clock(b.five), b.by or nil)
        else
            Put(out, "sub", T("sum.tt.sunder.five"), T("sum.tt.sunder.never"), nil, "bad")
        end
        Put(out, "sub", T("sum.tt.sunder.up"), Pct(b.up))
        if b.ex > 0 then
            exposed = true
            Put(out, "sub", T("sum.tt.sunder.ex"), Pct(b.ex), b.exBy or nil, "bad")
        end
    end
    if not exposed and #list > 0 then Put(out, "sub", T("sum.tt.sunder.ex"), T("sum.tt.sunder.noex"), nil, "dim") end
    return out
end
local function Spans(out, st, off)
    local total, unsure = 0, false
    for k = 1, st.n do
        local a = st.times[k]
        local len = max(0, (st.till and st.till[k] or a) - a)
        local unk = st.unsure and st.unsure[k] or false
        if unk then unsure = true end
        if not (off and unk) then total = total + len end
    end
    Put(out, "row", T(off and "sum.tt.rfury.off" or "sum.tt.rfury.on"), format(T("sum.tt.sec"), floor(total + 0.5)))
    for k = 1, min(TIMES, st.n) do
        local a = st.times[k]
        local b = st.till and st.till[k] or a
        local span = Clock(a) .. "–" .. Clock(b)
        if st.unsure and st.unsure[k] then
            Put(out, "sub", span, T("sum.tt.rfury.unk"), nil, "dim")
        else
            Put(out, "sub", span, format(T("sum.tt.sec"), floor(b - a + 0.5)), nil,
                off and b - a > (st.lim or 0) and "bad" or nil)
        end
    end
    More(out, st.n)
    return unsure
end
function Tips.rfuryoff(st, def)
    local out = {}
    Head(out, T(def.tip))
    Spans(out, st, true)
    return out
end
function Tips.rfuryon(st, def)
    local out = {}
    Head(out, T(def.tip))
    Spans(out, st, false)
    return out
end
function Tips.Shades(b, who, class)
    local out = {}
    if who then
        out[1] = { kind = "head", left = who, right = format(T("sum.tt.shadecaught"), b.hits[who] or 0), class = class }
    else
        Head(out, T(b.def.label))
        Put(out, "row", T("sum.tt.summoned"), tostring(b.summoned))
        Put(out, "row", T("sum.tt.caught"), tostring(b.caught))
        Put(out, "row", T("sum.tt.shadehits"), tostring(b.hit))
        Put(out, "row", T("sum.tt.dmg"), ns.BadgeTips.Short(b.total))
    end
    local shown = 0
    for k = 1, #b.at do
        if not who or b.vic[k] == who then
            shown = shown + 1
            if shown <= KICK_TIMES then
                Put(out, "sub", Clock(b.at[k]), b.vic[k] or "?",
                    format(T("sum.tt.shadehit"), b.cnt[k]) .. ", " .. ns.BadgeTips.Short(b.dmg[k]))
            end
        end
    end
    if shown > KICK_TIMES then
        Put(out, "sub", (format(T("sum.tip.more"), shown - KICK_TIMES):gsub("^%s+", "")))
    end
    return out
end
local function KickResult(k, i)
    local res, sp = k.res[i], k.sp[i]
    if res == "ok" then return sp and format(T("sum.kick.ok"), sp) or T("sum.kick.okq") end
    if res == "miss" then return format(T("sum.kick.miss"), Miss(sp)) end
    if res == "late" then return format(T("sum.kick.late"), tostring(sp)) end
    if res == "fail" then return sp and format(T("sum.kick.fail"), sp) or T("sum.kick.failq") end
    return T("sum.kick.idle")
end
function Tips.Kick(k)
    local out = {}
    Head(out, k.name or "?", T("sum.tt.kind.kick"))
    Put(out, "row", T("sum.tt.kicked"), format(T("sum.tt.of"), k.n, k.all), nil, Tone(k.n, k.all))
    for i = 1, min(KICK_TIMES, k.all) do
        Put(out, "sub", Clock(k.at[i]), k.tgt[i], KickResult(k, i), k.res[i] == "ok" and "good" or "dim")
    end
    if k.all > KICK_TIMES then
        Put(out, "sub", (format(T("sum.tip.more"), k.all - KICK_TIMES):gsub("^%s+", "")))
    end
    return out
end
