local _, ns = ...
local format = string.format
local concat = table.concat
local tremove = table.remove
local tsort = table.sort
local floor = math.floor
local max = math.max
local PREFIX = "MRHGP"
local DEFAULT = "spartans"
local CHUNK = 200
local MAX_PARTS = 64
local MAX_TEXT = 200
local MAX_BOSS = 96
local MAX_KEY = 48
local MAX_EXTRA = 100
local MAX_NUM = 100000
local MAX_VER = 1000000
local MAX_BUF = 8
local SEND_GAP = 0.3
local WAIT_LO, WAIT_HI = 10, 40
local ASK_EVERY = 30
local ROSTER_GAP = 15
local STALE = 60
local ANSWER_GAP = 60
local INFO_LIMIT = 500
local ADLER = 65521
local TWO32 = 4294967296
local FNV_BASIS = 2166136261
local FNV_LOW = 403
local FNV_HIGH = 16777216
local ORDER = { "on", "mode", "gp", "wipe", "step", "reason" }
local XORDER = { "boss", "on", "mode", "gp", "wipe", "step", "reason" }
local RSET = { on = true, mode = true, gp = true, wipe = true, step = true, reason = true }
local XSET = { boss = true, on = true, mode = true, gp = true, wipe = true, step = true, reason = true }
local MODES = { once = true, each = true, grow = true }
local NUMS = { gp = true, wipe = true, step = true }
local ESC = { ["~"] = "~t", [";"] = "~s", [","] = "~c", ["="] = "~e", [":"] = "~o" }
local UNESC = { t = "~", s = ";", c = ",", e = "=", o = ":" }
local BLOCK = "%-FW%-.-%-FW%-"
local ANCHOR = "%-FW%-%s*@GP:(%d+):(%x+):([^%s:]+)%s*%-FW%-"
local SUM_LEN = 16
local GPGuild = {}
ns.GPGuild = GPGuild
GPGuild.PREFIX = PREFIX
GPGuild.CHUNK = CHUNK
local state = {
    rosterSeen = false,
    bufs = {},
    nbufs = 0,
    out = {},
    nextSend = 0,
    askedAt = -1e9,
    rosterLast = -1e9,
    answeredAt = -1e9,
}
local listeners = {}
local cache, cacheSum, cacheV
local frame = CreateFrame("Frame")
frame:Hide()
local function Store()
    local db = ns.GetDB()
    return db and db.gp and db.gp.guild
end
local function Xor8(x, y)
    local r, pow = 0, 1
    for _ = 1, 8 do
        local a, b = x % 2, y % 2
        if a ~= b then r = r + pow end
        x, y, pow = (x - a) / 2, (y - b) / 2, pow * 2
    end
    return r
end
function GPGuild.Sum(s)
    local h = FNV_BASIS
    local a, b = 1, 0
    local n = #s
    for i = 1, n do
        local lo = h % 256
        h = h - lo + Xor8(lo, s:byte(i))
        h = (h * FNV_LOW + (h % 256) * FNV_HIGH) % TWO32
        a = (a + s:byte(n - i + 1)) % ADLER
        b = (b + a) % ADLER
    end
    return format("%04x%04x%04x%04x", floor(h / 65536), h % 65536, b, a)
end
local function Cut(s, n)
    if #s <= n then return s end
    local i = n
    while i > 0 do
        local c = s:byte(i + 1)
        if not c or c < 128 or c >= 192 then break end
        i = i - 1
    end
    return s:sub(1, i)
end
local function Text(s, n)
    if type(s) ~= "string" then return "" end
    s = s:gsub("[%c|]", ""):gsub("^%s+", "")
    s = Cut(s, n or MAX_TEXT):gsub("%s+$", "")
    return s
end
GPGuild.Text = Text
local function Esc(s)
    return (s:gsub("[~;,=:]", ESC))
end
local function Unesc(s)
    local bad = false
    local out = s:gsub("~(.?)", function(c)
        local r = UNESC[c]
        if not r then
            bad = true
            return ""
        end
        return r
    end)
    if bad then return nil end
    return out
end
local function Encode(f, v)
    if f == "on" then return v and "1" or "0" end
    if f == "mode" then return MODES[v] and v or nil end
    if f == "boss" and type(v) == "number" then return tostring(floor(v)) end
    if NUMS[f] then
        if type(v) ~= "number" then return nil end
        v = floor(v + 0.5)
        if v < 0 or v > MAX_NUM then return nil end
        return tostring(v)
    end
    local t = Text(v, f == "boss" and MAX_BOSS or MAX_TEXT)
    if t == "" then return nil end
    return Esc(t)
end
local function Decode(f, s)
    if f == "on" then
        if s == "1" then return true end
        if s == "0" then return false end
        return nil
    end
    if f == "mode" then return MODES[s] and s or nil end
    if f == "boss" and #s <= 6 and s:match("^%d+$") then return tonumber(s) end
    if NUMS[f] then
        if #s > 6 or not s:match("^%d+$") then return nil end
        local n = tonumber(s)
        if n > MAX_NUM then return nil end
        return n
    end
    local t = Unesc(s)
    t = t and Text(t, f == "boss" and MAX_BOSS or MAX_TEXT)
    if not t or t == "" then return nil end
    return t
end
local function Record(tag, key, fields, order)
    local parts = {}
    for i = 1, #order do
        local f = order[i]
        if fields[f] ~= nil then
            local s = Encode(f, fields[f])
            if s then parts[#parts + 1] = f .. "=" .. s end
        end
    end
    if #parts == 0 then return nil end
    return tag .. Esc(key) .. ":" .. concat(parts, ",")
end
local function KeyOk(key)
    return type(key) == "string" and #key <= MAX_KEY and key:match("^[%w%._]+$") ~= nil
end
local function Raw(model)
    local out, keys, seen = {}, {}, {}
    for key in pairs(model.rules) do
        if KeyOk(key) then keys[#keys + 1] = key end
    end
    tsort(keys)
    for i = 1, #keys do
        out[#out + 1] = Record("R", keys[i], model.rules[keys[i]], ORDER)
    end
    for i = 1, #model.extra do
        local x = model.extra[i]
        if i <= MAX_EXTRA and KeyOk(x.key) and not seen[x.key] and Encode("boss", x.boss) and Encode("gp", x.gp) then
            seen[x.key] = true
            out[#out + 1] = Record("X", x.key, x, XORDER)
        end
    end
    return concat(out, ";")
end
function GPGuild.Parse(data)
    if type(data) ~= "string" then return nil end
    local model, seen = { rules = {}, extra = {} }, {}
    for rec in data:gmatch("[^;]+") do
        local tag, raw, body = rec:match("^([RX])([^:]*):(.*)$")
        local key = raw and Unesc(raw)
        if KeyOk(key) then
            local allowed = tag == "X" and XSET or RSET
            local fields = {}
            for pair in body:gmatch("[^,]+") do
                local f, s = pair:match("^(%a+)=(.*)$")
                if f and allowed[f] then fields[f] = Decode(f, s) end
            end
            if tag == "R" then
                if next(fields) then model.rules[key] = fields end
            elseif fields.boss and fields.gp and not seen[key] and #model.extra < MAX_EXTRA then
                seen[key] = true
                fields.key = key
                model.extra[#model.extra + 1] = fields
            end
        end
    end
    return model
end
function GPGuild.Serialize(model)
    return Raw(GPGuild.Parse(Raw(model)))
end
function GPGuild.Exact(data)
    local model = GPGuild.Parse(data)
    return model ~= nil and Raw(model) == data
end
function GPGuild.Overlay()
    local g = Store()
    if not g or type(g.data) ~= "string" or not g.v then return nil end
    if cache and cacheSum == g.sum and cacheV == g.v then return cache end
    cache, cacheSum, cacheV = GPGuild.Parse(g.data), g.sum, g.v
    return cache
end
function GPGuild.ReadAnchor(text)
    local v, sum, by = (text or ""):match(ANCHOR)
    if not v or #v > 7 or #sum ~= SUM_LEN or #by > 48 then return nil, nil, nil end
    return tonumber(v), sum:lower(), by
end
function GPGuild.Block(v, sum, by)
    return format("-FW-\n@GP:%d:%s:%s\n-FW-", v, sum, by)
end
function GPGuild.WithAnchor(text, v, sum, by)
    local block = GPGuild.Block(v, sum, by)
    text = text or ""
    local s, e = text:find(BLOCK)
    if s then return text:sub(1, s - 1) .. block .. text:sub(e + 1) end
    if text == "" then return block end
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    return text .. block
end
local function Letters(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end
local function InfoLimit()
    local box = _G.GuildInfoEditBox
    local n = box and box.GetMaxLetters and box:GetMaxLetters()
    if type(n) == "number" and n > 0 then return n end
    return INFO_LIMIT
end
function GPGuild.Split(data)
    local parts, pos, n = {}, 1, #data
    while pos <= n do
        local piece = Cut(data:sub(pos, pos + CHUNK), CHUNK)
        if piece == "" then piece = data:sub(pos, pos + CHUNK - 1) end
        parts[#parts + 1] = piece
        pos = pos + #piece
    end
    if #parts == 0 then parts[1] = "" end
    return parts
end
function GPGuild.OnChange(fn)
    listeners[#listeners + 1] = fn
end
local function Notify()
    for i = 1, #listeners do listeners[i]() end
    if ns.GPList then ns.GPList.Changed() end
end
local function Accept(v, sum, data, by)
    local g = Store()
    if not g then return end
    g.v, g.sum, g.data, g.at, g.by = v, sum, data, time(), by
    cache = nil
    state.pending = nil
    Notify()
end
local function RankOf(name)
    if not name then return nil end
    for i = 1, GetNumGuildMembers(true) or 0 do
        local n, _, rank = GetGuildRosterInfo(i)
        if n == name then return rank end
    end
    return nil
end
function GPGuild.Trusted(sender, by)
    if not sender or not by then return false end
    if sender == by then return true end
    local rs = RankOf(sender)
    if not rs then return false end
    local rb = RankOf(by)
    if rb then return rs <= rb end
    return rs == 0
end
local function Roster()
    if not IsInGuild() then return end
    local now = GetTime()
    if now - state.rosterLast >= ROSTER_GAP then
        state.rosterLast = now
        state.rosterAt = nil
        GuildRoster()
    elseif not state.rosterAt then
        state.rosterAt = state.rosterLast + ROSTER_GAP
        frame:Show()
    end
end
local function Ask(v)
    local now = GetTime()
    if state.askedV == v and now - state.askedAt < ASK_EVERY then return end
    state.askedV, state.askedAt = v, now
    ns.Comm.Send(PREFIX, "NEED:" .. v, "GUILD")
end
local function Broadcast(v, data)
    local parts = GPGuild.Split(data)
    if #parts > MAX_PARTS then return 0 end
    state.sending = v
    for i = 1, #parts do
        state.out[#state.out + 1] = format("P:%d:%d:%d:%s", v, i, #parts, parts[i])
    end
    frame:Show()
    return #parts
end
local function Got(v, sum, data, by)
    Accept(v, sum, data, by)
    ns.Print(format(ns.T("gpg.got"), v, by))
end
local function OnRoster()
    local g = Store()
    if not g or not IsInGuild() then return end
    state.rosterSeen = true
    local v, sum, by = GPGuild.ReadAnchor(GetGuildInfoText() or "")
    local changed = v ~= state.anchorV or sum ~= state.anchorSum or by ~= state.anchorBy
    state.anchorV, state.anchorSum, state.anchorBy = v, sum, by
    if v and not (g.v == v and g.sum == sum) then
        local p = state.pending
        if p and p.v == v and GPGuild.Sum(p.data) == sum and GPGuild.Trusted(p.by, by) then
            return Got(v, sum, p.data, p.by)
        end
        Ask(v)
    end
    if changed then Notify() end
end
local function Complete(v, data, sender)
    if not GPGuild.Exact(data) then return end
    local sum = GPGuild.Sum(data)
    local g = Store()
    if g.v == v and g.sum == sum then return end
    if state.anchorV == v then
        if state.anchorSum == sum and GPGuild.Trusted(sender, state.anchorBy) then Got(v, sum, data, sender) end
        return
    end
    if state.anchorV and state.anchorV > v then return end
    state.pending = { v = v, data = data, by = sender }
    Roster()
end
local function OnNeed(v)
    local g = Store()
    if not g or g.v ~= v or type(g.data) ~= "string" then return end
    if state.answer or state.sending == v then return end
    if state.anchorV ~= v or state.anchorSum ~= g.sum then return end
    if not GPGuild.Trusted(UnitName("player"), state.anchorBy) then return end
    local now = GetTime()
    if now - state.answeredAt < ANSWER_GAP then return end
    state.answeredAt = now
    state.answer = { v = v, at = now + math.random(WAIT_LO, WAIT_HI) / 10 }
    frame:Show()
end
local function OnPart(sender, v, i, n, part)
    if v < 1 or v > MAX_VER or n < 1 or n > MAX_PARTS or i < 1 or i > n then return end
    local g = Store()
    if not g then return end
    if state.anchorV == v and not GPGuild.Trusted(sender, state.anchorBy) then return end
    if state.answer and state.answer.v == v then state.answer = nil end
    if g.v == v and state.anchorV == v and g.sum == state.anchorSum then return end
    local buf = state.bufs[sender]
    if not buf or buf.v ~= v or buf.n ~= n then
        if not buf then
            if state.nbufs >= MAX_BUF then return end
            state.nbufs = state.nbufs + 1
        end
        buf = { v = v, n = n, parts = {}, got = 0 }
        state.bufs[sender] = buf
    end
    buf.at = GetTime()
    if not buf.parts[i] then
        buf.parts[i] = part
        buf.got = buf.got + 1
    end
    frame:Show()
    if buf.got < n then return end
    state.bufs[sender] = nil
    state.nbufs = state.nbufs - 1
    Complete(v, concat(buf.parts, "", 1, n), sender)
end
local function OnMessage(body, sender, chan)
    if chan ~= "GUILD" then return end
    local need = body:match("^NEED:(%d+)$")
    if need and #need <= 7 then return OnNeed(tonumber(need)) end
    local v, i, n, part = body:match("^P:(%d+):(%d+):(%d+):(.*)$")
    if v and #v <= 7 and #i <= 3 and #n <= 3 then
        OnPart(sender, tonumber(v), tonumber(i), tonumber(n), part)
    end
end
local function TickOut(now)
    if not state.out[1] then
        state.sending = nil
        return false
    end
    if now >= state.nextSend then
        ns.Comm.Send(PREFIX, tremove(state.out, 1), "GUILD")
        state.nextSend = now + SEND_GAP
    end
    return true
end
frame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local busy = TickOut(now)
    local a = state.answer
    if a then
        busy = true
        if now >= a.at then
            state.answer = nil
            local g = Store()
            if g and g.v == a.v and type(g.data) == "string" then Broadcast(a.v, g.data) end
        end
    end
    if state.rosterAt then
        busy = true
        if now >= state.rosterAt then Roster() end
    end
    for sender, buf in pairs(state.bufs) do
        busy = true
        if now - buf.at > STALE then
            state.bufs[sender] = nil
            state.nbufs = state.nbufs - 1
        end
    end
    if not busy then self:Hide() end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if not Store() then return end
    if event == "GUILD_ROSTER_UPDATE" then return OnRoster() end
    Roster()
end)
ns.Comm.On(PREFIX, OnMessage)
local function Field(rule, f)
    if f == "on" then return rule.on ~= false end
    if f == "mode" then return rule.mode or "each" end
    if f == "reason" then
        if type(rule.reason) == "string" and rule.reason ~= "" then return rule.reason end
        return nil
    end
    return rule[f]
end
GPGuild.Field = Field
function GPGuild.FromActive()
    local builtin = {}
    local preset = ns.penaltyPresets[DEFAULT]
    for i = 1, #preset.rules do builtin[preset.rules[i].key] = preset.rules[i] end
    local model = { rules = {}, extra = {} }
    local all = ns.Penalties.All()
    for i = 1, #all do
        local r = all[i]
        if r.custom then
            model.extra[#model.extra + 1] = { key = r.key, boss = r.boss, on = r.on, mode = r.mode, gp = r.gp,
                wipe = r.wipe, step = r.step, reason = r.reason }
        elseif builtin[r.key] then
            local diff = {}
            for k = 1, #ORDER do
                local f = ORDER[k]
                local now = Field(r, f)
                if now ~= nil and now ~= Field(builtin[r.key], f) then diff[f] = now end
            end
            if next(diff) then model.rules[r.key] = diff end
        end
    end
    return model
end
function GPGuild.CanPublish()
    return (IsInGuild() and CanEditGuildInfo()) and true or false
end
function GPGuild.Publish()
    if not IsInGuild() then return false, "gpg.err.guild" end
    if not CanEditGuildInfo() then return false, "gpg.err.rights" end
    if not state.rosterSeen then
        Roster()
        return false, "gpg.err.wait"
    end
    local data = GPGuild.Serialize(GPGuild.FromActive())
    if #GPGuild.Split(data) > MAX_PARTS then return false, "gpg.err.big" end
    local text = GetGuildInfoText() or ""
    local g = Store()
    local me = UnitName("player")
    local v = max(GPGuild.ReadAnchor(text) or 0, g.v or 0, state.anchorV or 0) + 1
    local sum = GPGuild.Sum(data)
    local new = GPGuild.WithAnchor(text, v, sum, me)
    local limit = InfoLimit()
    if Letters(new) > limit then return false, "gpg.err.long", Letters(new), limit end
    SetGuildInfoText(new)
    state.anchorV, state.anchorSum, state.anchorBy = v, sum, me
    local active = ns.Penalties.Active()
    Accept(v, sum, data, me)
    ns.Penalties.Prune(active)
    return true, "gpg.done", v, Broadcast(v, data)
end
function GPGuild.Status()
    local g = Store() or {}
    return {
        seen = state.rosterSeen,
        by = state.anchorBy,
        guild = state.anchorV,
        mine = g.v,
        synced = g.v ~= nil and g.v == state.anchorV and g.sum == state.anchorSum,
        officer = GPGuild.CanPublish(),
    }
end
function GPGuild.Refresh()
    Roster()
end
