local ADDON, ns = ...
local format = string.format
local max = math.max
local floor = math.floor
local min = math.min
local ceil = math.ceil
local concat = table.concat
local tsort = table.sort
local Kit = ns.Kit
local GL = ns.GuildLocks
local GR = ns.GuildRaid
local GB = ns.GuildBober
local GN = ns.GuildNotes
local N = ns.guildNotes
local D = ns.guildLocks
local MARGIN = 12
local CAP_H = 22
local CTRL_H = 28
local SLOT_H = 22
local MAIN_H = 20
local ALT_H = 18
local NOTE_H = 18
local TEXT_X = 8
local FOLD = 14
local NAME_X = 22
local INDENT = 16
local NAME_W = 140
local ON_W = 120
local GS_W = 56
local SPEC_W = 110
local ALTS_W = 0
local STATE_W = 150
local INV_W = 96
local SEL_W = 150
local CHECK_W = 130
local ONLINE_GAP = 28
local ROLECHK_W = 86
local ROLE_SZ = 14
local ROLE_GAP = 3
local RI_SZ = 12
local RAT_SZ = 18
local REBUILD_GAP = 5
local JOB = "guildlocks"
local SPARE = 120
local ROLES = { "tank", "heal", "dd" }
local HEADS = { "main", "on", "gs", "spec", "roles", "cd", "ri" }
local RI_TEX = "Interface\\Icons\\INV_Misc_Book_09"
local RAT_TEX = "Interface\\AddOns\\" .. ADDON .. "\\art\\kit\\rat"
local BASE = { CAP_H = CAP_H, CTRL_H = CTRL_H, SLOT_H = SLOT_H, MAIN_H = MAIN_H, ALT_H = ALT_H, NOTE_H = NOTE_H,
    TEXT_X = TEXT_X, FOLD = FOLD, NAME_X = NAME_X, INDENT = INDENT, NAME_W = NAME_W, ON_W = ON_W, GS_W = GS_W,
    SPEC_W = SPEC_W, ALTS_W = ALTS_W, STATE_W = STATE_W, INV_W = INV_W, SEL_W = SEL_W, CHECK_W = CHECK_W, ROLECHK_W = ROLECHK_W,
    ROLE_SZ = ROLE_SZ, ROLE_GAP = ROLE_GAP, RI_SZ = RI_SZ, RAT_SZ = RAT_SZ }
local LINE_H = 14
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local View = {}
ns.GuildLockView = View
local content
local caption, sel, check, roleCap, sep, ticker
local roleChecks = {}
local rerender
local pools = { slot = {}, main = {}, alt = {}, note = {}, head = {} }
local used = { slot = 0, main = 0, alt = 0, note = 0, head = 0 }
local open = {}
local cache = nil
local builtAt = -1e9
local dirty = true
local pane
local lines = {}
local listTop, listW = 0, 0
local function Dims(w)
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true))
    local B = BASE
    local fixed = B.NAME_X + B.NAME_W + B.ON_W + B.GS_W + B.SPEC_W + B.ALTS_W + 3 * (B.ROLE_SZ + B.ROLE_GAP) + 12
        + B.STATE_W + B.INV_W
    local kc = max(1, min(k, w / fixed))
    CAP_H, CTRL_H, SLOT_H = ceil(B.CAP_H * k), ceil(B.CTRL_H * k), ceil(B.SLOT_H * k)
    MAIN_H, ALT_H, NOTE_H = ceil(B.MAIN_H * k), ceil(B.ALT_H * k), ceil(B.NOTE_H * k)
    LINE_H = ceil(14 * k)
    TEXT_X, FOLD, INDENT = ceil(B.TEXT_X * kc), ceil(B.FOLD * k), ceil(B.INDENT * kc)
    NAME_X, NAME_W, ON_W, GS_W = ceil(B.NAME_X * kc), ceil(B.NAME_W * kc), ceil(B.ON_W * kc), ceil(B.GS_W * kc)
    SPEC_W, ALTS_W, STATE_W, INV_W = ceil(B.SPEC_W * kc), ceil(B.ALTS_W * kc), ceil(B.STATE_W * kc), ceil(B.INV_W * kc)
    SEL_W, CHECK_W, ROLECHK_W = ceil(B.SEL_W * kc), ceil(B.CHECK_W * kc), ceil(B.ROLECHK_W * kc)
    ROLE_SZ, ROLE_GAP, RI_SZ, RAT_SZ = ceil(B.ROLE_SZ * k), B.ROLE_GAP, ceil(B.RI_SZ * k), ceil(B.RAT_SZ * k)
end
local function Seat(row, kind)
    row:SetHeight((kind == "main" and MAIN_H) or (kind == "alt" and ALT_H) or (kind == "slot" and SLOT_H) or NOTE_H)
    for i = 1, #row.cols do row.cols[i]:SetHeight(LINE_H) end
    if row.info then row.info:SetHeight(LINE_H) end
    if row.roles then
        for i = 1, #ROLES do
            row.roles[ROLES[i]]:SetWidth(ROLE_SZ)
            row.roles[ROLES[i]]:SetHeight(ROLE_SZ)
        end
        row.rat:SetWidth(RAT_SZ)
        row.rat:SetHeight(RAT_SZ)
        row.ri:SetWidth(RI_SZ + 6)
        row.ri:SetHeight(RI_SZ + 6)
        row.ri.icon:SetWidth(RI_SZ)
        row.ri.icon:SetHeight(RI_SZ)
        row.invite:SetHeight(max(12, (kind == "main" and MAIN_H or ALT_H) - 2))
    end
    if row.fold then
        row.fold:SetWidth(FOLD)
        row.fold:SetHeight(FOLD)
    end
end
local function Make(kind)
    local row = Kit.Row(content, 100)
    local n = (kind == "main" and 6) or (kind == "alt" and 5) or (kind == "head" and #HEADS) or 1
    row.cols = {}
    for i = 1, n do
        local fs = Kit.Str(row, (kind == "main" and "GameFontNormal") or (kind == "head" and "GameFontNormalSmall")
            or "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        Kit.Text(fs, kind == "head" and "text.secondary" or "text.primary")
        row.cols[i] = fs
    end
    row.text:Hide()
    if kind == "main" or kind == "alt" then
        row.roles = {}
        for i = 1, #ROLES do
            local t = row:CreateTexture(nil, "ARTWORK")
            Kit.Icon.Role(t, ROLES[i])
            row.roles[ROLES[i]] = t
        end
        local ri = Kit.IconButton(row, RI_TEX, RI_SZ)
        ri.tipTitle = ns.T("gl.ri")
        ri.tip = ns.T("gl.ri.tip")
        ri.onClick = function(b) if b.char then ns.Bober.Open(b.char) end end
        row.ri = ri
        row.rat = row:CreateTexture(nil, "ARTWORK")
        row.rat:SetTexture(RAT_TEX)
        row.rat:Hide()
        row.info = Kit.Str(row, "GameFontHighlightSmall")
        row.info:SetJustifyH("LEFT")
        row.info:SetWordWrap(false)
        Kit.Text(row.info, "text.secondary")
        local inv = Kit.Button(row)
        Kit.RoundButton(inv)
        inv:SetText(ns.T("gl.invite"))
        inv.onClick = function(b) if b.who then InviteUnit(b.who) end end
        row.invite = inv
    end
    if kind == "main" then
        row.fold = row:CreateTexture(nil, "ARTWORK")
        row.fold:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.onClick = function(r)
            local p = r.person
            if p and #p.chars > 1 then
                open[p.name] = not open[p.name] or nil
                if rerender then rerender() end
            end
        end
    end
    row.tipAnchor = "ANCHOR_CURSOR"
    Seat(row, kind)
    return row
end
local function Take(kind, y, w)
    used[kind] = used[kind] + 1
    local pool = pools[kind]
    local row = pool[used[kind]]
    if not row then
        row = Make(kind)
        pool[used[kind]] = row
    end
    Seat(row, kind)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    row:SetWidth(w)
    row.tipTitle, row.tip, row.tipLines, row.person = false, nil, nil, nil
    row:Show()
    return row
end
local function HideAll()
    for kind, pool in pairs(pools) do
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
end
local function Put(fs, x, width, text, token, right)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", fs:GetParent(), "LEFT", x, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(right and "RIGHT" or "LEFT")
    fs:SetText(text)
    if token then Kit.Text(fs, token) end
    fs:Show()
end
local function Src(src)
    local key = "gl.src." .. tostring(src or "other")
    local s = ns.T(key)
    if s == key then return ns.T("gl.src.other") end
    return s
end
local function SpecName(spec, class)
    local sp = N.specs[spec]
    class = class or (sp and sp.class)
    local trees = class and N.trees[class]
    if not trees then return nil end
    local want = (spec == "bear" or spec == "cat") and "feral" or spec
    for i = 1, #trees do
        if trees[i] == want then return ns.T("spec." .. class .. "." .. i) end
    end
    return nil
end
local function SlotLabel(slot)
    local L = ns.Lead
    local cap = L and L.Tpl and L.Tpl.Cap and L.Tpl.Cap(slot)
    local base = cap or ns.T("gl.role." .. tostring(slot.role or "dd"))
    if type(slot.specs) ~= "table" or not slot.specs[1] then return base end
    local names, seen = {}, {}
    for i = 1, #slot.specs do
        local s = SpecName(slot.specs[i])
        if s and not seen[s] then
            seen[s] = true
            names[#names + 1] = s
        end
    end
    if #names == 0 then return base end
    return base .. " (" .. concat(names, "/") .. ")"
end
local function TplName(tpl)
    local L = ns.Lead
    if L and L.Tpl and L.Tpl.Name then return L.Tpl.Name(tpl) end
    return tostring(tpl.name or tpl.key or "?")
end
local function PersonState(p)
    local state, gs = 2, 0
    for i = 1, #p.chars do
        local c = p.chars[i]
        if c.saved == false then state = 0 elseif c.saved == nil and state == 2 then state = 1 end
        if (c.gs or 0) > gs then gs = c.gs end
    end
    return state, gs
end
local function Known(p)
    for i = 1, #p.chars do
        if p.chars[i].saved ~= nil then return true end
    end
    return false
end
local rank = {}
local function Order(a, b)
    local ra, rb = rank[a], rank[b]
    local sa, ga, sb, gb = ra[1], ra[2], rb[1], rb[2]
    if sa ~= sb then return sa < sb end
    if (a.online ~= nil) ~= (b.online ~= nil) then return a.online ~= nil end
    if ga ~= gb then return ga > gb end
    return a.name < b.name
end
local function Compute()
    local r = GR.Get(GR.Pick())
    local q = GR.Query(r)
    local gsMin = GL.GsMin(q)
    local all = GL.Available(q, gsMin, true, ns.Jobs.Step)
    ns.Jobs.Yield()
    local people = {}
    for i = 1, #all do
        local p, chars = all[i], {}
        for j = 1, #p.chars do
            if (p.chars[j].level or 0) >= D.level then chars[#chars + 1] = p.chars[j] end
        end
        if #chars > 0 then
            p.chars = chars
            people[#people + 1] = p
        end
    end
    local onl, known = {}, 0
    for i = 1, #all do
        if all[i].online then onl[#onl + 1] = all[i] end
    end
    rank = {}
    for i = 1, #people do
        local p = people[i]
        if Known(p) then known = known + 1 end
        rank[p] = { PersonState(p) }
    end
    tsort(people, Order)
    rank = {}
    ns.Jobs.Yield()
    local tpl = GR.Template(r)
    return { raid = r, q = q, gsMin = gsMin, people = people, total = #all, online = #onl, tpl = tpl, known = known,
        slots = tpl and GL.Slots(tpl, onl) or nil }
end
local function Rebuild()
    builtAt, dirty = GetTime(), false
    ns.Jobs.Cancel(JOB)
    ns.Jobs.Run(JOB, Compute, function(c)
        if not c then return end
        cache = c
        if content and content:IsVisible() and rerender then rerender() end
    end, "ui.gl")
end
local function Schedule()
    if ticker and not ticker:IsShown() then ticker:Show() end
end
local function State(c)
    if (c.level or 0) < D.level then return format(ns.T("cd.level"), c.level or 0), "text.off" end
    if c.saved == true then return format(ns.T("gl.state.saved"), ns.Date(c.save and c.save.ends)), "text.bad" end
    if c.saved == false then return ns.T("gl.state.free"), "text.good" end
    return "", "text.off"
end
local function Xs()
    local roles = NAME_X + NAME_W + ON_W + GS_W + SPEC_W + ALTS_W + 6
    local state = roles + #ROLES * (ROLE_SZ + ROLE_GAP) + 6
    local invite = state + STATE_W + 6
    return roles, state, invite, invite + INV_W + 8
end
local function Invite(b, who, online, x)
    if not who or who == UnitName("player") then
        b:Hide()
        return
    end
    b.who = who
    b:ClearAllPoints()
    b:SetPoint("LEFT", b:GetParent(), "LEFT", x, 0)
    b:SetWidth(INV_W)
    b.tipTitle = format(ns.T("gl.invite.tip"), who)
    local why = nil
    if not online then
        why = ns.T("gl.invite.off")
    elseif UnitInRaid(who) or UnitInParty(who) then
        why = ns.T("gl.invite.in")
    elseif GetNumRaidMembers() > 0 and not (IsRaidLeader() or IsRaidOfficer()) then
        why = ns.T("gl.invite.raid")
    elseif GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 and not IsPartyLeader() then
        why = ns.T("gl.invite.party")
    end
    b.tipDim = why
    if why then b:Disable() else b:Enable() end
    b:Show()
end
local function Best(p, main)
    if main and main.saved == false then return main end
    local free, unknown = nil, nil
    for i = 1, #p.chars do
        local c = p.chars[i]
        if c.saved == false then free = free or c elseif c.saved == nil then unknown = unknown or c end
    end
    if free then return free end
    if main and main.saved == nil then return main end
    return unknown or main or p.chars[1]
end
local function SpecText(c)
    local s = c.spec and SpecName(c.spec, c.class)
    if s then return s end
    if c.role then return ns.T("gl.role." .. c.role) end
    return "—"
end
local function CharLines(c, main)
    local lines = {}
    if main then lines[#lines + 1] = format(ns.T("gl.tip.main"), main, Src(c.link)) end
    lines[#lines + 1] = format(ns.T("gl.tip.level"), c.level or 0)
    if c.gs then
        lines[#lines + 1] = format(ns.T("gl.tip.gs"), c.gs, Src(c.gsSrc))
        if c.gsOk == false then lines[#lines + 1] = format(ns.T("gl.tip.gs.low"), cache and cache.gsMin or 0) end
    else
        lines[#lines + 1] = ns.T("gl.tip.gs.none")
    end
    local s = c.spec and SpecName(c.spec, c.class)
    if s then
        lines[#lines + 1] = format(ns.T("gl.tip.spec"), s, Src(c.roleSrc))
    elseif c.role then
        lines[#lines + 1] = format(ns.T("gl.tip.role"), ns.T("gl.role." .. c.role), Src(c.roleSrc))
    else
        lines[#lines + 1] = ns.T("gl.tip.role.none")
    end
    local label = cache and GR.Label(cache.raid) or ""
    local v = c.save
    if v and v.src == "bober" and v.raid then
        local r = v.raid
        lines[#lines + 1] = format(ns.T(c.saved and "gl.tip.save.bober" or "gl.tip.same.bober"), label,
            ns.Date(GB.Time(r.date)), r.killed or 0, r.total or 0)
    elseif c.saved == true and v then
        lines[#lines + 1] = format(ns.T("gl.tip.save"), label, v.id, ns.Date(v.ends, "dayTime"), Src(v.src))
    elseif c.saved == false and v then
        lines[#lines + 1] = format(ns.T("gl.tip.same"), label, v.id)
    elseif c.saved == false then
        lines[#lines + 1] = format(ns.T("gl.tip.free"), label)
    else
        lines[#lines + 1] = format(ns.T("gl.tip.unknown"), label)
    end
    return lines
end
local function InfoText(r)
    local lg = GB.LeadGuild(r)
    local lead = (r.lead or "?") .. ((lg and lg ~= r.guild) and format(" (%s)", lg) or "")
    return format(ns.T("gl.info"), ns.Date(GB.Time(r.date)), lead, r.guild or ns.T("gl.info.pug"))
end
local function FillChar(row, c, x, w)
    local cols = row.cols
    Put(cols[1], x, NAME_W - (x - NAME_X), c.name)
    Kit.ClassText(cols[1], c.class)
    Put(cols[3], NAME_X + NAME_W + ON_W, GS_W, c.gs and tostring(c.gs) or "—",
        c.gsOk == false and "text.warn" or "text.secondary")
    Put(cols[4], NAME_X + NAME_W + ON_W + GS_W, SPEC_W, SpecText(c), "text.secondary")
    local x0, sx, ivx, rix = Xs()
    local state, token = State(c)
    Put(cols[5], sx, STATE_W, state, token)
    Invite(row.invite, c.saved ~= true and c.name or nil, c.online, ivx)
    row.rat:Hide()
    local roles = c.roles or {}
    for i = 1, #ROLES do
        local t = row.roles[ROLES[i]]
        t:ClearAllPoints()
        t:SetPoint("LEFT", row, "LEFT", x0 + (i - 1) * (ROLE_SZ + ROLE_GAP), 0)
        t:SetAlpha(1)
        if roles[ROLES[i]] then t:Show() else t:Hide() end
    end
    local ri = row.ri
    ri.char = c.name
    ri:ClearAllPoints()
    ri:SetPoint("LEFT", row, "LEFT", rix, 0)
    if GB.Rec(c.name) then ri:Show() else ri:Hide() end
    local ix = rix + RI_SZ + 12
    local r = c.cur
    Put(row.info, ix, max(10, w - ix - 4), r and InfoText(r) or "", r and c.rat and "text.warn" or "text.secondary")
end
local function Rat(row, p)
    local who = nil
    for i = 1, #p.chars do
        local c = p.chars[i]
        if c.rat then
            who = who or {}
            who[#who + 1] = format(ns.T("gl.tip.rat"), c.name, c.cur.guild or ns.T("gl.info.pug"), c.cur.lead or "?")
        end
    end
    if not who then return nil end
    local name = row.cols[1]
    row.rat:ClearAllPoints()
    row.rat:SetPoint("LEFT", row, "LEFT", NAME_X + math.min(NAME_W - RAT_SZ, name:GetStringWidth() + 4), 0)
    row.rat:Show()
    return who
end
local function RolesPass(p)
    local any = false
    for i = 1, #ROLES do
        if GR.RoleOn(ROLES[i]) then
            any = true
            for j = 1, #p.chars do
                if p.chars[j].roles and p.chars[j].roles[ROLES[i]] then return true end
            end
        end
    end
    return not any
end
local function Split(p)
    local main, alts = nil, {}
    for i = 1, #p.chars do
        local c = p.chars[i]
        if c.name == p.name then main = c else alts[#alts + 1] = c end
    end
    return main, alts
end
local function DrawMain(p, y, w)
    local row = Take("main", y, w)
    row.person = p
    local main, alts = Split(p)
    local cols = row.cols
    if main then
        FillChar(row, main, NAME_X, w)
        row.tipLines = CharLines(main, nil)
    else
        Put(cols[1], NAME_X, NAME_W, p.name, "text.primary")
        for i = 3, 5 do cols[i]:SetText("") end
        for i = 1, #ROLES do row.roles[ROLES[i]]:Hide() end
        row.ri:Hide()
        row.rat:Hide()
        row.invite:Hide()
        row.info:SetText("")
        row.tipLines = {}
    end
    local best = Best(p, main)
    local _, sx, ivx = Xs()
    if best and best ~= main then
        local text, token = State(best)
        if best.saved == false then text = format(ns.T("gl.state.free.alt"), best.name) end
        Put(cols[5], sx, STATE_W, text, token)
    end
    local who = p.online or (main and main.name) or nil
    Invite(row.invite, PersonState(p) ~= 2 and who or nil, p.online ~= nil, ivx)
    local rat = Rat(row, p)
    for i = 1, rat and #rat or 0 do row.tipLines[#row.tipLines + 1] = rat[i] end
    local on, token = ns.T("gl.off"), "text.off"
    if p.online == p.name then
        on, token = ns.T("gl.on"), "text.good"
    elseif p.online then
        on, token = format(ns.T("gl.on.alt"), p.online), "text.good"
    end
    Put(cols[2], NAME_X + NAME_W, ON_W, on, token)
    cols[6]:SetText("")
    if #alts > 0 then
        row.fold:SetTexture(open[p.name] and MINUS or PLUS)
        row.fold:Show()
        local names = {}
        for i = 1, #alts do names[i] = alts[i].name end
        row.tipLines[#row.tipLines + 1] = format(ns.T("gl.tip.alts"), concat(names, ", "))
    else
        row.fold:Hide()
    end
    row.tipTitle = p.name
end
local function DrawAlt(p, c, y, w)
    local r = Take("alt", y, w)
    FillChar(r, c, NAME_X + INDENT, w)
    Put(r.cols[2], NAME_X + NAME_W, ON_W, ns.T(c.online and "gl.on" or "gl.off"), c.online and "text.good" or "text.off")
    r.tipTitle = c.name
    r.tipLines = CharLines(c, p.name)
end
local function Place()
    for _, kind in ipairs({ "main", "alt" }) do
        local pool = pools[kind]
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
    if #lines == 0 then return end
    local vh = pane and pane.view:GetHeight() or 0
    if vh <= 0 then vh = GetScreenHeight() end
    local off = pane and pane.offset or 0
    local top, bottom = off - SPARE, off + vh + SPARE
    local y = listTop
    for i = 1, #lines do
        local e = lines[i]
        local h = e.c and ALT_H or MAIN_H
        if y > bottom then break end
        if y + h >= top then
            if e.c then DrawAlt(e.p, e.c, y, listW) else DrawMain(e.p, y, listW) end
        end
        y = y + h
    end
end
local function DrawHead(y, w)
    local row = Take("head", y, w)
    local cols = row.cols
    local x0, sx, _, rix = Xs()
    local xs = { NAME_X, NAME_X + NAME_W, NAME_X + NAME_W + ON_W, NAME_X + NAME_W + ON_W + GS_W, x0, sx, rix }
    local ws = { NAME_W, ON_W, GS_W, SPEC_W, sx - x0, STATE_W, max(10, w - rix - 4) }
    local ri = ns.Bober and ns.Bober.Ready()
    for i = 1, #HEADS do
        Put(cols[i], xs[i], ws[i], (HEADS[i] ~= "ri" or ri) and ns.T("gl.head." .. HEADS[i]) or "")
    end
    return y + NOTE_H
end
local function RolesText(s)
    local parts = {}
    for i = 1, #ROLES do
        local g = ROLES[i]
        local t = format(ns.T("gl.slots.role." .. g), s.have[g], s.need[g])
        if s.have[g] < s.need[g] then t = Kit.Hex("text.warn") .. t .. "|r" end
        parts[i] = t
    end
    return concat(parts, ", ")
end
local function DrawSlots(y, w)
    local row = Take("slot", y, w)
    local c = cache
    if not c or not c.tpl or not c.slots then
        Put(row.cols[1], TEXT_X, w - TEXT_X, format(ns.T("gl.slots.notpl"), c and c.raid.size or 0) .. "  —  "
            .. format(ns.T("gl.known"), c and c.known or 0, c and #c.people or 0), "text.muted")
        return y + SLOT_H
    end
    local s = c.slots
    Put(row.cols[1], TEXT_X, w - TEXT_X, format(ns.T("gl.slots"), s.filled, s.total, RolesText(s)) .. "  —  "
        .. format(ns.T("gl.known"), c.known or 0, #c.people), s.filled >= s.total and "text.good" or "text.primary")
    row.tipTitle = format(ns.T("gl.slots.tipTitle"), GR.Label(c.raid), TplName(c.tpl))
    local lines = { format(ns.T("gl.slots.tip.online"), c.online), format(ns.T("gl.gs"), c.gsMin),
        ns.T("gl.slots.tip.unknown") }
    local took = {}
    if #s.picks > 0 then lines[#lines + 1] = ns.T("gl.slots.tip.picks") end
    for i = 1, #s.picks do
        local pk = s.picks[i]
        took[pk.slot] = true
        local who = pk.char == pk.person and pk.person or format("%s (%s)", pk.person, pk.char)
        lines[#lines + 1] = format(ns.T("gl.slots.tip.pick"), SlotLabel(c.tpl.slots[pk.slot]), who)
    end
    if s.filled < s.total then lines[#lines + 1] = ns.T("gl.slots.tip.lack") end
    for i = 1, #c.tpl.slots do
        if not took[i] then lines[#lines + 1] = "  " .. SlotLabel(c.tpl.slots[i]) end
    end
    row.tipLines = lines
    return y + SLOT_H
end
local function DrawNote(text, y, w)
    local row = Take("note", y, w)
    Put(row.cols[1], TEXT_X, max(60, w - TEXT_X - 4), text, "text.muted")
    return y + NOTE_H
end
local function Options()
    local list = GR.List()
    local out = {}
    for i = 1, #list do out[i] = { key = list[i].key, label = GR.Label(list[i]) } end
    return out
end
local function Controls(on)
    local list = { sel, check, roleCap, sep }
    for i = 1, #ROLES do list[#list + 1] = roleChecks[ROLES[i]] end
    for i = 1, #list do
        if on then list[i]:Show() else list[i]:Hide() end
    end
end
function View.Draw(y, w)
    HideAll()
    lines = {}
    if not content then return y end
    Dims(w)
    caption:SetHeight(CAP_H - 4)
    caption:ClearAllPoints()
    caption:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    caption.rule:SetWidth(max(1, w - caption:GetStringWidth() - 6))
    y = y + CAP_H
    if not (IsInGuild and IsInGuild()) then
        Controls(false)
        return DrawNote(ns.T("gl.noguild"), y, w)
    end
    if not GN.Loaded() then
        GN.Ask()
        Controls(false)
        return DrawNote(ns.T("gl.loading"), y, w)
    end
    Controls(true)
    sel:SetWidth(SEL_W)
    sel:SetHeight(Kit.FontGrow(20))
    sel:ClearAllPoints()
    sel:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN + TEXT_X, -y)
    sel:SetOptions(Options(), GR.Pick())
    check:ClearAllPoints()
    check:SetPoint("TOPRIGHT", content, "TOPLEFT", MARGIN + w - CHECK_W, -y + 2)
    check:SetChecked(GR.OnlineOnly())
    for i = 1, #ROLES do
        local rc = roleChecks[ROLES[i]]
        rc:ClearAllPoints()
        rc:SetPoint("TOPRIGHT", content, "TOPLEFT", MARGIN + w - CHECK_W - ONLINE_GAP - (#ROLES - i + 1) * ROLECHK_W,
            -y + 2)
        rc:SetChecked(GR.RoleOn(ROLES[i]))
    end
    roleCap:ClearAllPoints()
    roleCap:SetPoint("RIGHT", roleChecks[ROLES[1]], "LEFT", -4, 0)
    sep:ClearAllPoints()
    sep:SetPoint("CENTER", check, "LEFT", -floor(ONLINE_GAP / 2), 0)
    sep:SetHeight(max(10, CTRL_H - 10))
    y = y + CTRL_H
    if not ns.Jobs.Busy(JOB) and (not cache or (dirty and GetTime() - builtAt >= REBUILD_GAP)) then
        Rebuild()
    elseif dirty then
        Schedule()
    end
    if not cache then return DrawNote(ns.T("gl.counting"), y, w) end
    if #cache.people == 0 then return DrawNote(ns.T(cache.total > 0 and "gl.empty.level" or "gl.empty"), y, w) end
    y = DrawSlots(y, w)
    y = DrawHead(y, w)
    local only = GR.OnlineOnly()
    listTop, listW = y, w
    for i = 1, #cache.people do
        local p = cache.people[i]
        if (p.online or not only) and RolesPass(p) then
            lines[#lines + 1] = { p = p }
            y = y + MAIN_H
            if open[p.name] then
                local _, alts = Split(p)
                for k = 1, #alts do
                    lines[#lines + 1] = { p = p, c = alts[k] }
                    y = y + ALT_H
                end
            end
        end
    end
    if #lines == 0 then return DrawNote(ns.T(only and "gl.empty.online" or "gl.empty"), y, w) end
    Place()
    return y
end
function View.Scrolled()
    if content and content:IsVisible() then Place() end
end
function View.Opened()
    dirty = true
    GN.Ask()
    GB.Warm(GL.Invalidate)
end
function View.Build(parent, redraw, page)
    content, rerender, pane = parent, redraw, page
    caption = Kit.Caption(content, ns.T("gl.title"), 200)
    sel = Kit.Select(content)
    Kit.Bind(sel.text, "GameFontNormalSmall")
    Kit.Bind(caption, "GameFontNormal")
    sel.tipTitle = ns.T("gl.raid")
    sel.onPick = function(key)
        GR.SetPick(key)
        Rebuild()
    end
    sep = content:CreateTexture(nil, "ARTWORK")
    Kit.Paint(sep, "text.title", 0.4)
    sep:SetWidth(1)
    roleCap = Kit.Str(content, "GameFontNormalSmall")
    roleCap:SetJustifyH("RIGHT")
    roleCap:SetText(ns.T("gl.hasrole"))
    Kit.Text(roleCap, "text.secondary")
    check = Kit.Check(content)
    Kit.Bind(check.label, "GameFontNormalSmall")
    check.label:SetText(ns.T("gl.online"))
    check.tipTitle = false
    check.onToggle = function(on)
        GR.SetOnlineOnly(on)
        redraw()
    end
    for i = 1, #ROLES do
        local group = ROLES[i]
        local rc = Kit.Check(content)
        Kit.Bind(rc.label, "GameFontNormalSmall")
        rc.label:SetText(ns.T("gl.role." .. group))
        rc.tipTitle = ns.T("gl.filter.role")
        rc.tip = ns.T("gl.filter.role.tip")
        rc.onToggle = function(on)
            GR.SetRole(group, on)
            redraw()
        end
        roleChecks[group] = rc
    end
    ticker = CreateFrame("Frame", nil, content)
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self)
        if GetTime() - builtAt < REBUILD_GAP then return end
        self:Hide()
        if dirty and content:IsVisible() then redraw() end
    end)
end
function View.Probe()
    return { pools = pools, used = used, open = open, sel = sel, check = check, roleChecks = roleChecks, roleCap = roleCap,
        caption = caption, cache = function() return cache end, ticker = ticker, lines = function() return lines end }
end
local group = CreateFrame("Frame")
group:RegisterEvent("PARTY_MEMBERS_CHANGED")
group:RegisterEvent("RAID_ROSTER_UPDATE")
group:SetScript("OnEvent", function()
    if content and content:IsVisible() and rerender then rerender() end
end)
GL.OnChange(function()
    dirty = true
    if content and content:IsVisible() then Schedule() end
end)
