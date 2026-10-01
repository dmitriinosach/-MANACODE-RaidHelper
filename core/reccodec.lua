local _, ns = ...
local floor = math.floor
local band = bit.band
local concat = table.concat
local type = type
local select = select
local tostring = tostring
local tonumber = tonumber
local wipe = wipe
local match = string.match
local gsub = string.gsub
local tremove = table.remove
local sub = string.sub
local byte = string.byte
local gmatch = string.gmatch
local VERSION = 2
local CHUNK = 512
local POINTS = 256
local FLAG_MASK = 0xFFFF
local HP_STEP = 0.01
local UNITS_PER_YARD = 8
local MAP_UNITS = 10000
local ITEM = "\30"
local FIELD = "\31"
local TAIL_SLOTS = 12
local P, Q, N, F, S, G, X = 1, 2, 3, 4, 5, 6, 7
local KIND = { P = P, Q = Q, N = N, F = F, S = S, G = G, X = X }
local DAMAGE = { P, N, N, X, X, X, F, F, X, X }
local SWING_DAMAGE = { N, N, X, F, F, F, F, F, X }
local HEAL = { P, N, N, N, F }
local MISSED = { P, S, G }
local SWING_MISSED = { S, G }
local AURA = { P, S, G }
local SPELL = { P }
local INTERRUPT = { P, Q }
local DISPEL = { P, Q, S }
local ENERGIZE = { P, G, G }
local ENV = { S, G, G, G, G, G, G, G, G, G }
local LAYOUTS = {
    SPELL_DAMAGE = DAMAGE, SPELL_PERIODIC_DAMAGE = DAMAGE, RANGE_DAMAGE = DAMAGE,
    SPELL_BUILDING_DAMAGE = DAMAGE, DAMAGE_SHIELD = DAMAGE, DAMAGE_SPLIT = DAMAGE,
    SWING_DAMAGE = SWING_DAMAGE,
    SPELL_HEAL = HEAL, SPELL_PERIODIC_HEAL = HEAL,
    SPELL_MISSED = MISSED, SPELL_PERIODIC_MISSED = MISSED, RANGE_MISSED = MISSED,
    DAMAGE_SHIELD_MISSED = MISSED, SPELL_BUILDING_MISSED = MISSED,
    SWING_MISSED = SWING_MISSED,
    SPELL_AURA_APPLIED = AURA, SPELL_AURA_REMOVED = AURA, SPELL_AURA_REFRESH = AURA,
    SPELL_AURA_APPLIED_DOSE = AURA, SPELL_AURA_REMOVED_DOSE = AURA,
    SPELL_CAST_START = SPELL, SPELL_CAST_SUCCESS = SPELL, SPELL_SUMMON = SPELL, SPELL_CREATE = SPELL,
    SPELL_INSTAKILL = SPELL, SPELL_RESURRECT = SPELL,
    SPELL_INTERRUPT = INTERRUPT, SPELL_DISPEL = DISPEL, SPELL_STOLEN = DISPEL,
    SPELL_ENERGIZE = ENERGIZE, SPELL_PERIODIC_ENERGIZE = ENERGIZE,
    ENVIRONMENTAL_DAMAGE = ENV,
}
local Codec = {}
ns.RecCodec = Codec
Codec.VERSION = VERSION
Codec.KIND = KIND
Codec.LAYOUTS = LAYOUTS
Codec.ITEM = ITEM
Codec.FIELD = FIELD
local states = setmetatable({}, { __mode = "k" })
local function ListBytes(list)
    local n = 0
    if type(list) ~= "table" then return n end
    for i = 1, #list do n = n + #list[i] + 1 end
    return n
end
local function NewDicts(st)
    st.ag, st.ak, st.an, st.af = {}, {}, {}, {}
    st.sp, st.sk, st.spn, st.sps, st.si = {}, {}, {}, {}, {}
    st.lastMs, st.dict = 0, 0
end
local function State(seg)
    local st = states[seg]
    if st then return st end
    st = { hpLast = {}, hpMax = {}, hpBuf = {}, hpMs = {}, hpOut = {},
           px = {}, py = {}, posBuf = {}, posMs = {}, posX = {}, posY = {},
           yw = 1 / UNITS_PER_YARD, yh = 1 / UNITS_PER_YARD }
    NewDicts(st)
    st.dict = ListBytes(seg.actors) + ListBytes(seg.spells) + ListBytes(seg.strs)
    states[seg] = st
    return st
end
function Codec.Open(ts, raid)
    local seg = {
        v = VERSION, raid = raid, t0 = ts, t1 = ts, n = 0, bytes = 0,
        actors = {}, spells = {}, strs = {}, chunks = {}, buf = {},
        hp = {}, pos = {}, maps = {}, bosses = {},
    }
    State(seg)
    return seg
end
function Codec.Is(seg)
    return seg ~= nil and seg.v == VERSION
end
local function Str(seg, st, s)
    local id = st.si[s]
    if id then return id end
    local list = seg.strs
    id = #list + 1
    list[id] = s
    st.si[s] = id
    st.dict = st.dict + #s + 1
    return id
end
local function NewActor(seg, st, g, n, f)
    local key = g .. FIELD .. n
    local id = st.ak[key]
    if id then return id end
    local list = seg.actors
    id = #list + 1
    list[id] = key .. FIELD .. f
    st.dict = st.dict + #list[id] + 1
    st.ak[key] = id
    st.an[id] = n
    st.af[id] = f
    if not st.ag[g] then st.ag[g] = id end
    return id
end
local function Actor(seg, st, guid, name, flags)
    local f = band(flags or 0, FLAG_MASK)
    if guid == nil and name == nil and f == 0 then return "" end
    local g = guid ~= nil and tostring(guid) or ""
    local n = name ~= nil and tostring(name) or ""
    local id = st.ag[g]
    if not id or st.an[id] ~= n then id = NewActor(seg, st, g, n, f) end
    if st.af[id] == f then return id end
    return id .. ":" .. f
end
local function Spell(seg, st, id, name, school)
    local k = st.sp[id]
    local n = name ~= nil and name or false
    local c = school ~= nil and school or false
    if k and st.spn[k] == n and st.sps[k] == c then return k end
    local key = id .. FIELD .. (name or "") .. FIELD .. (school or "")
    k = st.sk[key]
    if k then return k end
    local list = seg.spells
    k = #list + 1
    list[k] = key
    st.dict = st.dict + #key + 1
    st.sk[key] = k
    st.spn[k] = n
    st.sps[k] = c
    if not st.sp[id] then st.sp[id] = k end
    return k
end
local parts = {}
local tail = {}
local function Generic(seg, st, v)
    local tv = type(v)
    if tv == "number" then return v end
    if tv == "string" then return "s" .. Str(seg, st, v) end
    if tv == "nil" then return "" end
    if tv == "boolean" then return v and "b1" or "b0" end
    return "s" .. Str(seg, st, tostring(v))
end
local function Fits(layout, nt)
    local ti = 1
    for li = 1, #layout do
        local kind = layout[li]
        local v = tail[ti]
        if kind == P or kind == Q then
            if type(v) ~= "number" then return false end
            local nm, sc = tail[ti + 1], tail[ti + 2]
            if nm ~= nil and type(nm) ~= "string" then return false end
            if sc ~= nil and type(sc) ~= "number" then return false end
            ti = ti + 3
        else
            if kind == N then
                if type(v) ~= "number" then return false end
            elseif kind == F then
                if v ~= nil and type(v) ~= "number" then return false end
            elseif kind == S then
                if v ~= nil and type(v) ~= "string" then return false end
            end
            ti = ti + 1
        end
    end
    return ti > nt
end
local function PutLayout(seg, st, layout)
    local k, ti = 4, 1
    for li = 1, #layout do
        local kind = layout[li]
        local v = tail[ti]
        if kind == P or kind == Q then
            k = k + 1
            parts[k] = Spell(seg, st, v, tail[ti + 1], tail[ti + 2])
            ti = ti + 3
        else
            if kind ~= X then
                k = k + 1
                if kind == N then
                    parts[k] = v ~= 0 and v or ""
                elseif kind == S then
                    parts[k] = v ~= nil and Str(seg, st, v) or ""
                elseif kind == F then
                    parts[k] = v ~= nil and v or ""
                else
                    parts[k] = Generic(seg, st, v)
                end
            end
            ti = ti + 1
        end
    end
    return k
end
local function Push(seg, line, ts)
    local buf = seg.buf
    local n = #buf + 1
    buf[n] = line
    seg.n = seg.n + 1
    if ts > seg.t1 then seg.t1 = ts end
    seg.bytes = seg.bytes + #line + 1
    if n >= CHUNK then
        seg.chunks[#seg.chunks + 1] = concat(buf, ";")
        wipe(buf)
    end
end
function Codec.Append(seg, ts, subtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local st = states[seg] or State(seg)
    local ms = floor((ts - seg.t0) * 1000 + 0.5)
    local dt = #seg.buf == 0 and ms or ms - st.lastMs
    st.lastMs = ms
    parts[1] = dt ~= 0 and dt or ""
    local subId = st.si[subtype] or Str(seg, st, subtype)
    parts[3] = Actor(seg, st, srcGUID, srcName, srcFlags)
    parts[4] = Actor(seg, st, dstGUID, dstName, dstFlags)
    local nt = select("#", ...)
    if nt > TAIL_SLOTS then nt = TAIL_SLOTS end
    tail[1], tail[2], tail[3], tail[4], tail[5], tail[6],
        tail[7], tail[8], tail[9], tail[10], tail[11], tail[12] = ...
    local layout = LAYOUTS[subtype]
    local k
    if layout and Fits(layout, nt) then
        parts[2] = subId
        k = PutLayout(seg, st, layout)
    else
        parts[2] = "g" .. subId
        k = 4
        for i = 1, nt do
            k = k + 1
            parts[k] = Generic(seg, st, tail[i])
        end
    end
    while k > 4 and parts[k] == "" do k = k - 1 end
    Push(seg, concat(parts, ",", 1, k), ts)
end
local function PutPoint(seg, bufs, store, name, point)
    local buf = bufs[name]
    if not buf then
        buf = {}
        bufs[name] = buf
    end
    local n = #buf + 1
    buf[n] = point
    seg.bytes = seg.bytes + #point + 1
    if n >= POINTS then
        local list = store[name]
        if not list then
            list = {}
            store[name] = list
        end
        list[#list + 1] = concat(buf, ";")
        wipe(buf)
    end
end
local function Stamp(seg, buf, last, ts)
    local ms = floor((ts - seg.t0) * 1000 + 0.5)
    if not buf or #buf == 0 or not last then return ms, ms, true end
    local dt = ms - last
    return dt ~= 0 and dt or "", ms, false
end
function Codec.Hp(seg, ts, name, hp, hpMax, force)
    local st = states[seg] or State(seg)
    local last = st.hpLast[name]
    local lastMax = st.hpMax[name]
    if not force and last ~= nil and hpMax == lastMax then
        if hp == last then return false end
        if hp ~= 0 and last ~= 0 then
            local d = hp - last
            if d < 0 then d = -d end
            if d < hpMax * HP_STEP then return false end
        end
    end
    local buf = st.hpBuf[name]
    local dt, ms, first = Stamp(seg, buf, st.hpMs[name], ts)
    local point
    if first or hpMax ~= st.hpOut[name] then
        point = dt .. "," .. hp .. "," .. hpMax
        st.hpOut[name] = hpMax
    else
        point = dt .. "," .. hp
    end
    st.hpMs[name] = ms
    st.hpLast[name], st.hpMax[name] = hp, hpMax
    if ts > seg.t1 then seg.t1 = ts end
    PutPoint(seg, st.hpBuf, seg.hp, name, point)
    return true
end
function Codec.Pos(seg, ts, name, x, y, force)
    local st = states[seg] or State(seg)
    local lx, ly = st.px[name], st.py[name]
    if not force and lx ~= nil then
        if x == lx and y == ly then return false end
        local zero, was = x == 0 and y == 0, lx == 0 and ly == 0
        if zero == was then
            local dx, dy = (x - lx) * st.yw, (y - ly) * st.yh
            if dx * dx + dy * dy <= 1 then return false end
        end
    end
    local buf = st.posBuf[name]
    local dt, ms, first = Stamp(seg, buf, st.posMs[name], ts)
    local point
    if first then
        point = dt .. "," .. x .. "," .. y
    else
        local dx, dy = x - st.posX[name], y - st.posY[name]
        point = dt .. "," .. (dx ~= 0 and dx or "") .. "," .. (dy ~= 0 and dy or "")
    end
    st.posMs[name] = ms
    st.posX[name], st.posY[name] = x, y
    if ts > seg.t1 then seg.t1 = ts end
    st.px[name], st.py[name] = x, y
    PutPoint(seg, st.posBuf, seg.pos, name, point)
    return true
end
local function YardsPerUnit(area, level, mapName)
    local scale = ns.mapScale or {}
    local byArea = scale[mapName] or (ns.mapAreas and scale[ns.mapAreas[tonumber(area) or 0] or ""])
    local size = byArea and byArea[tonumber(level) or 0]
    if not size then return 1 / UNITS_PER_YARD, 1 / UNITS_PER_YARD end
    return size.w / MAP_UNITS, size.h / MAP_UNITS
end
function Codec.Map(seg, ts, area, level, mapName)
    local st = states[seg] or State(seg)
    local key = tostring(area or 0) .. ":" .. tostring(level or 0) .. ":" .. tostring(mapName or "")
    if key == st.mapKey then return false end
    st.mapKey = key
    st.yw, st.yh = YardsPerUnit(area, level, mapName)
    local ms = floor((ts - seg.t0) * 1000 + 0.5)
    local maps = seg.maps
    local point = (#maps == 0 and ms or ms - (st.mapMs or 0)) .. "," .. key
    st.mapMs = ms
    maps[#maps + 1] = point
    seg.bytes = seg.bytes + #point + 1
    return true
end
function Codec.LiveBuf(seg, kind, name)
    local st = states[seg]
    if not st then return nil end
    local bufs = kind == "hp" and st.hpBuf or st.posBuf
    return bufs[name]
end
function Codec.LiveBufs(seg, kind)
    local st = states[seg]
    if not st then return nil end
    return kind == "hp" and st.hpBuf or st.posBuf
end
local function FlushPoints(bufs, store)
    for name, buf in pairs(bufs) do
        if #buf > 0 then
            local list = store[name]
            if not list then
                list = {}
                store[name] = list
            end
            list[#list + 1] = concat(buf, ";")
            wipe(buf)
        end
    end
end
local function Join(list)
    if type(list) ~= "table" then return list end
    if #list == 0 then return nil end
    return concat(list, ITEM)
end
function Codec.Seal(seg)
    local st = states[seg]
    if seg.buf and #seg.buf > 0 then
        seg.chunks[#seg.chunks + 1] = concat(seg.buf, ";")
    end
    seg.buf = nil
    if st then
        FlushPoints(st.hpBuf, seg.hp)
        FlushPoints(st.posBuf, seg.pos)
        states[seg] = nil
    end
    if ns.Decode then ns.Decode.Tables(seg) end
    seg.actors = Join(seg.actors)
    seg.spells = Join(seg.spells)
    seg.strs = Join(seg.strs)
    seg.maps = #seg.maps > 0 and concat(seg.maps, ";") or nil
    if not next(seg.hp) then seg.hp = nil end
    if not next(seg.pos) then seg.pos = nil end
    if seg.bosses and not next(seg.bosses) then seg.bosses = nil end
    return seg
end
function Codec.Sealed(seg)
    return states[seg] == nil
end
local function Head(s)
    if not s then return nil end
    return tonumber(match(s, "^(-?%d*)")) or 0
end
Codec.Head = Head
function Codec.Flush(seg)
    local buf = seg.buf
    if buf and #buf > 0 then
        seg.chunks[#seg.chunks + 1] = concat(buf, ";")
        wipe(buf)
    end
end
function Codec.FrontOld(seg, cutMs)
    local chunks = seg.chunks
    if not chunks[1] then return false end
    local nxt = Head(chunks[2] or (seg.buf and seg.buf[1]))
    return nxt ~= nil and nxt <= cutMs
end
function Codec.Shift(seg)
    local s = tremove(seg.chunks, 1)
    if s then
        local _, lines = gsub(s, ";", ";")
        seg.n = seg.n - lines - 1
        seg.bytes = seg.bytes - #s - 1
    end
    return s
end
local function CutPoints(pts, isPos, cutMs)
    local n = #pts
    local ms, a, b, keep = 0, 0, 0, 0
    for i = 1, n do
        local d, v1, v2 = match(pts[i], "^(-?%d*),(-?%d*),?(-?%d*)")
        local t = (i == 1 and 0 or ms) + (tonumber(d) or 0)
        if t > cutMs then break end
        ms, keep = t, i
        if not isPos then
            a = tonumber(v1) or 0
            if v2 ~= "" then b = tonumber(v2) or b end
        elseif i == 1 then
            a, b = tonumber(v1) or 0, tonumber(v2) or 0
        else
            a, b = a + (tonumber(v1) or 0), b + (tonumber(v2) or 0)
        end
    end
    if keep == 0 or (keep == 1 and ms == cutMs) then return 0, nil end
    local delta = 0
    for i = 1, keep do delta = delta - #pts[i] - 1 end
    local head = cutMs .. "," .. a .. "," .. b
    delta = delta + #head + 1
    if keep < n then
        local nxt = pts[keep + 1]
        local d = match(nxt, "^(-?%d*)")
        local dd = ms + (tonumber(d) or 0) - cutMs
        local fixed = (dd ~= 0 and dd or "") .. sub(nxt, #d + 1)
        delta = delta + #fixed - #nxt
        pts[keep + 1] = fixed
    end
    pts[keep] = head
    local shift = keep - 1
    if shift > 0 then
        for i = keep, n do pts[i - shift] = pts[i] end
        for i = n - shift + 1, n do pts[i] = nil end
    end
    return delta, keep == n and cutMs or nil
end
local function Split(s)
    local out = {}
    for p in gmatch(s, "[^;]+") do out[#out + 1] = p end
    return out
end
function Codec.TrimStreams(seg, cutMs)
    cutMs = floor(cutMs)
    local st = states[seg]
    for kind, store in pairs({ hp = seg.hp, pos = seg.pos }) do
        local isPos = kind == "pos"
        local bufs = st and (isPos and st.posBuf or st.hpBuf) or {}
        for name, list in pairs(store) do
            while list[1] do
                local nxt = Head(list[2] or (bufs[name] and bufs[name][1]))
                if not nxt or nxt > cutMs then break end
                seg.bytes = seg.bytes - #list[1] - 1
                tremove(list, 1)
            end
            if list[1] and Head(list[1]) < cutMs then
                local pts = Split(list[1])
                local delta = CutPoints(pts, isPos, cutMs)
                list[1] = concat(pts, ";")
                seg.bytes = seg.bytes + delta
            end
        end
        local lastMs = st and (isPos and st.posMs or st.hpMs)
        for name, buf in pairs(bufs) do
            local list = store[name]
            if buf[1] and not (list and list[1]) and Head(buf[1]) < cutMs then
                local delta, last = CutPoints(buf, isPos, cutMs)
                seg.bytes = seg.bytes + delta
                if last then lastMs[name] = last end
            end
        end
    end
end
function Codec.SplitFront(seg, cutMs)
    local s = seg.chunks[1]
    if not s or Head(s) >= cutMs then return nil end
    local pos, ms, n = 1, 0, 0
    while true do
        local d, nx = match(s, "^(-?%d*)[^;]*()", pos)
        local t = (pos == 1 and 0 or ms) + (tonumber(d) or 0)
        if t >= cutMs then
            local rest = t .. sub(s, pos + #d)
            local old = sub(s, 1, pos - 2)
            seg.chunks[1] = rest
            seg.n = seg.n - n
            seg.bytes = seg.bytes - (#s - #rest)
            return old
        end
        ms, n = t, n + 1
        if byte(s, nx) ~= 59 then break end
        pos = nx + 1
    end
    return Codec.Shift(seg)
end
local function Shifted(s, delta)
    local head, rest = match(s, "^(-?%d*)(.*)$")
    return ((tonumber(head) or 0) - delta) .. rest
end
local function ShiftFirst(list, delta)
    if list and list[1] then list[1] = Shifted(list[1], delta) end
end
function Codec.Rebase(seg, t0)
    local delta = floor((t0 - seg.t0) * 1000 + 0.5)
    if delta == 0 then return end
    for i = 1, #seg.chunks do seg.chunks[i] = Shifted(seg.chunks[i], delta) end
    ShiftFirst(seg.buf, delta)
    local st = states[seg]
    for _, store in ipairs({ seg.hp, seg.pos }) do
        for _, list in pairs(store) do
            for i = 1, #list do list[i] = Shifted(list[i], delta) end
        end
    end
    if type(seg.maps) == "table" then ShiftFirst(seg.maps, delta) end
    if st then
        st.lastMs = st.lastMs - delta
        for _, bufs in ipairs({ st.hpBuf, st.posBuf }) do
            for _, buf in pairs(bufs) do ShiftFirst(buf, delta) end
        end
        for _, ms in ipairs({ st.hpMs, st.posMs }) do
            for name, v in pairs(ms) do ms[name] = v - delta end
        end
        if st.mapMs then st.mapMs = st.mapMs - delta end
    end
    seg.t0 = seg.t0 + delta / 1000
    if ns.Decode then ns.Decode.Forget() end
end
function Codec.DictBytes(seg)
    local st = states[seg]
    return st and st.dict or 0
end
function Codec.Size(seg)
    return (seg.bytes or 0) + Codec.DictBytes(seg)
end
local function Pack(...)
    return { n = select("#", ...), ... }
end
function Codec.Compact(seg)
    local st = states[seg]
    if not st or not ns.Decode then return false end
    Codec.Flush(seg)
    local evs, chunks = {}, seg.chunks
    for i = 1, #chunks do
        local s = chunks[i]
        seg.bytes = seg.bytes - #s - 1
        local it = ns.Decode.Chunk(seg, s, TAIL_SLOTS)
        while true do
            local e = Pack(it())
            if e[1] == nil then break end
            if e[2] ~= nil then evs[#evs + 1] = e end
        end
    end
    ns.Decode.Drop(seg)
    for i = #chunks, 1, -1 do chunks[i] = nil end
    seg.actors, seg.spells, seg.strs, seg.n = {}, {}, {}, 0
    NewDicts(st)
    for i = 1, #evs do
        local e = evs[i]
        Codec.Append(seg, unpack(e, 1, e.n))
    end
    return true
end
