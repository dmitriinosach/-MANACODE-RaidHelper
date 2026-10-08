local _, ns = ...
local type = type
local tonumber = tonumber
local unpack = unpack
local find = string.find
local match = string.match
local strsub = string.sub
local byte = string.byte
local gmatch = string.gmatch
local SEEK_SLACK = 5000
local B_COMMA = 44
local B_SEMI = 59
local B_S = 115
local B_B = 98
local B_G = 103
local FIELD_END = "[,;]"
local HEAD = "^(-?%d*),(g?)(%d+),([^,;]*),([^,;]*)()"
local Decode = {}
ns.Decode = Decode
local K = ns.RecCodec.KIND
local P, Q, N, F, S, X = K.P, K.Q, K.N, K.F, K.S, K.X
local LAYOUTS = ns.RecCodec.LAYOUTS
local tables = setmetatable({}, { __mode = "k" })
local function List(v)
    if type(v) == "table" then return v end
    local out = {}
    if type(v) ~= "string" or v == "" then return out end
    for item in gmatch(v .. "\30", "([^\30]*)\30") do out[#out + 1] = item end
    return out
end
local function Memo(a, b, c, fill)
    local mt = { __index = function(t, k)
        fill(k)
        return rawget(t, k)
    end }
    setmetatable(a, mt)
    setmetatable(b, mt)
    setmetatable(c, mt)
end
function Decode.Tables(seg)
    local T = tables[seg]
    if T then return T end
    local actors, spells, strs = List(seg.actors), List(seg.spells), List(seg.strs)
    T = { AG = {}, AN = {}, AF = {}, PI = {}, PN = {}, PS = {}, STR = {}, strs = strs, actors = actors }
    local AG, AN, AF = T.AG, T.AN, T.AF
    Memo(AG, AN, AF, function(k)
        local c = find(k, ":", 1, true)
        local id = tonumber(c and strsub(k, 1, c - 1) or k)
        local e = id and actors[id]
        local g, n, f = "", "", "0"
        if e then g, n, f = match(e, "^([^\31]*)\31([^\31]*)\31(%-?%d*)$") end
        rawset(AG, k, g ~= "" and g or false)
        rawset(AN, k, n ~= "" and n or false)
        if g ~= "" and n ~= "" then ns.NoteNpc(g, n) end
        rawset(AF, k, (c and tonumber(strsub(k, c + 1))) or tonumber(f) or 0)
    end)
    local PI, PN, PS = T.PI, T.PN, T.PS
    Memo(PI, PN, PS, function(k)
        local e = spells[tonumber(k) or 0]
        local i, n, s
        if e then i, n, s = match(e, "^([^\31]*)\31([^\31]*)\31([^\31]*)$") end
        rawset(PI, k, tonumber(i) or false)
        rawset(PN, k, (n and n ~= "") and n or false)
        if n and n ~= "" then ns.NoteSpell(i, n) end
        rawset(PS, k, tonumber(s) or false)
    end)
    local STR = T.STR
    setmetatable(STR, { __index = function(t, k)
        local v = strs[tonumber(k) or 0] or false
        rawset(t, k, v)
        return v
    end })
    tables[seg] = T
    return T
end
function Decode.IdOf(seg, s)
    local T = Decode.Tables(seg)
    local index = T.index
    if not index or T.indexN ~= #T.strs then
        index = {}
        for i = 1, #T.strs do index[T.strs[i]] = i end
        T.index, T.indexN = index, #T.strs
    end
    return index[s]
end
local function Generic(T, s)
    local n = tonumber(s)
    if n then return n end
    local head = byte(s, 1)
    if head == B_S then return T.STR[strsub(s, 2)] or nil end
    if head == B_B then return s == "b1" end
    return nil
end
local ret = {}
local function DecodeAt(seg, T, s, at, ms, maxTail)
    local _, gen, subId, src, dst, pos = match(s, HEAD, at)
    if not subId then return 0 end
    local subtype = T.STR[subId] or nil
    ret[1] = seg.t0 + ms / 1000
    ret[2] = subtype
    local AG, AN, AF = T.AG, T.AN, T.AF
    ret[3] = AG[src] or nil
    ret[4] = AN[src] or nil
    ret[5] = AF[src]
    ret[6] = AG[dst] or nil
    ret[7] = AN[dst] or nil
    ret[8] = AF[dst]
    local n = 8
    local limit = maxTail and (8 + maxTail) or 64
    local ch = byte(s, pos)
    local layout = gen == "" and subtype and LAYOUTS[subtype] or nil
    if not layout then
        while ch == B_COMMA and n < limit do
            local start = pos + 1
            local stop = find(s, FIELD_END, start)
            local field
            if stop then
                field = strsub(s, start, stop - 1)
                ch = byte(s, stop)
                pos = stop
            else
                field = strsub(s, start)
                ch = nil
            end
            n = n + 1
            if field == "" then ret[n] = nil else ret[n] = Generic(T, field) end
        end
        return n
    end
    for li = 1, #layout do
        if n >= limit then break end
        local kind = layout[li]
        if kind == X then
            n = n + 1
            ret[n] = nil
        else
            local field = ""
            if ch == B_COMMA then
                local start = pos + 1
                local stop = find(s, FIELD_END, start)
                if stop then
                    field = strsub(s, start, stop - 1)
                    ch = byte(s, stop)
                    pos = stop
                else
                    field = strsub(s, start)
                    ch = nil
                end
            end
            if kind == P or kind == Q then
                ret[n + 1] = T.PI[field] or nil
                ret[n + 2] = T.PN[field] or nil
                ret[n + 3] = T.PS[field] or nil
                n = n + 3
            else
                n = n + 1
                if kind == N then
                    ret[n] = field == "" and 0 or tonumber(field)
                elseif field == "" then
                    ret[n] = nil
                elseif kind == S then
                    ret[n] = T.STR[field] or nil
                elseif kind == F then
                    ret[n] = tonumber(field)
                else
                    ret[n] = Generic(T, field)
                end
            end
        end
    end
    if n > limit then n = limit end
    return n
end
local function ChunkStart(chunk)
    return tonumber(match(chunk, "^(-?%d*)")) or 0
end
local curSeg, curS, curAt, curMs = nil, nil, 0, 0
function Decode.TimeAt(seg, s, at)
    local p, ms
    if curSeg == seg and curS == s and curAt <= at then
        p, ms = curAt, curMs
    else
        p, ms = 1, ChunkStart(s)
    end
    while p < at do
        local nx = find(s, ";", p, true)
        if not nx or nx >= at then break end
        p = nx + 1
        ms = ms + (tonumber(match(s, "^(-?%d*)", p)) or 0)
    end
    curSeg, curS, curAt, curMs = seg, s, p, ms
    return seg.t0 + ms / 1000, ms
end
function Decode.Forget()
    curSeg, curS, curAt, curMs = nil, nil, 0, 0
end
function Decode.Drop(seg)
    tables[seg] = nil
    Decode.Forget()
end
function Decode.Chunk(seg, s, maxTail)
    local T = Decode.Tables(seg)
    local pos, ms = 1, nil
    return function()
        while pos do
            local at = pos
            local nx = find(s, ";", at, true)
            pos = nx and nx + 1 or nil
            local d = tonumber(match(s, "^(-?%d*)", at)) or 0
            ms = ms and ms + d or d
            local n = DecodeAt(seg, T, s, at, ms, maxTail)
            if n > 0 then return unpack(ret, 1, n) end
        end
        return nil
    end
end
function Decode.Decode(seg, s, at, maxTail)
    local _, ms = Decode.TimeAt(seg, s, at)
    local n = DecodeAt(seg, Decode.Tables(seg), s, at, ms, maxTail)
    if n == 0 then return nil end
    return unpack(ret, 1, n)
end
local function FirstChunk(seg, from)
    local chunks = seg.chunks
    local ci = 1
    if from then
        local startMs = (from - seg.t0) * 1000 - SEEK_SLACK
        while ci < #chunks and ChunkStart(chunks[ci + 1]) < startMs do ci = ci + 1 end
    end
    return ci
end
local function Walk(seg, from, to)
    return { seg = seg, ci = FirstChunk(seg, from) - 1, s = nil, pos = 1, ms = 0, bi = 0, done = false,
             stopMs = to and (to - seg.t0) * 1000 + SEEK_SLACK or nil }
end
local function Next(w)
    if w.done then return nil, 0, 0, 0 end
    local seg = w.seg
    while true do
        local s = w.s
        if s then
            local at = w.pos
            if at > 1 then
                w.ms = w.ms + (tonumber(match(s, "^(-?%d*)", at)) or 0)
            else
                w.ms = ChunkStart(s)
            end
            local nx = find(s, ";", at, true)
            if nx then w.pos = nx + 1 else w.s = nil end
            return s, at, w.ci, w.ms
        end
        if w.bi > 0 or w.ci >= #seg.chunks then
            local buf = seg.buf
            w.bi = w.bi + 1
            local line = buf and buf[w.bi]
            if not line then
                w.done = true
                return nil, 0, 0, 0
            end
            if w.bi == 1 then
                w.ms = ChunkStart(line)
            else
                w.ms = w.ms + (tonumber(match(line, "^(-?%d*)")) or 0)
            end
            return line, 1, 0, w.ms
        end
        w.ci = w.ci + 1
        local chunk = seg.chunks[w.ci]
        if w.stopMs and ChunkStart(chunk) > w.stopMs then
            w.done = true
            return nil, 0, 0, 0
        end
        w.s, w.pos = chunk, 1
    end
end
local function SkipSet(seg, names)
    if not names then return nil end
    local set = {}
    for k, v in pairs(names) do
        local id = Decode.IdOf(seg, type(k) == "string" and k or v)
        if id then set[tostring(id)] = true end
    end
    return set
end
function Decode.Events(seg, from, to, skip, maxTail)
    local T = Decode.Tables(seg)
    local w = Walk(seg, from, to)
    local fromMs = from and (from - seg.t0) * 1000 - 1 or nil
    local toMs = to and (to - seg.t0) * 1000 + 1 or nil
    local skipIds = SkipSet(seg, skip)
    return function()
        while true do
            local s, at, _, ms = Next(w)
            if not s then return nil end
            if (not fromMs or ms >= fromMs) and (not toMs or ms <= toMs) then
                if not (skipIds and skipIds[match(s, "^%-?%d*,g?(%d+)", at)]) then
                    local n = DecodeAt(seg, T, s, at, ms, maxTail)
                    if n > 0 then return unpack(ret, 1, n) end
                end
            end
        end
    end
end
function Decode.Heads(seg, from, to)
    local T = Decode.Tables(seg)
    local STR, AN, AG = T.STR, T.AN, T.AG
    local w = Walk(seg, from, to)
    local t0 = seg.t0
    local fromMs = from and (from - t0) * 1000 - 1 or nil
    local toMs = to and (to - t0) * 1000 + 1 or nil
    return function()
        while true do
            local s, at, ci, ms = Next(w)
            if not s then return nil end
            if (not fromMs or ms >= fromMs) and (not toMs or ms <= toMs) then
                local _, _, subId, src, dst = match(s, HEAD, at)
                if subId then
                    curSeg, curS, curAt, curMs = seg, s, at, ms
                    return s, at, ci, t0 + ms / 1000, STR[subId] or nil, AN[src] or nil, AN[dst] or nil,
                        AG[src] or nil, AG[dst] or nil
                end
            end
        end
    end
end
local function StreamChunks(seg, store, kind, name)
    local list = store and store[name] or nil
    local live = ns.RecCodec.LiveBuf(seg, kind, name)
    if live and #live > 0 then
        local out = {}
        for i = 1, #(list or {}) do out[i] = list[i] end
        out[#out + 1] = table.concat(live, ";")
        return out
    end
    return list or {}
end
local function Points(seg, kind, name, from, to)
    local chunks = StreamChunks(seg, seg[kind], kind, name)
    local t0 = seg.t0
    local ci = 1
    if from then
        local fromMs = (from - t0) * 1000
        while ci < #chunks and ChunkStart(chunks[ci + 1]) <= fromMs do ci = ci + 1 end
    end
    local toMs = to and (to - t0) * 1000 or nil
    local s, pos, ms, a, b = nil, 1, 0, 0, 0
    local isPos = kind == "pos"
    return function()
        while true do
            if not s then
                s = chunks[ci]
                if not s then return nil end
                ci = ci + 1
                pos = 1
            end
            local first = pos == 1
            local d, v1, v2, nx = match(s, "^(-?%d*),(-?%d*),?(-?%d*)()", pos)
            if not nx then
                s = nil
            else
                if byte(s, nx) == B_SEMI then pos = nx + 1 else s = nil end
                if first then ms = tonumber(d) or 0 else ms = ms + (tonumber(d) or 0) end
                if toMs and ms > toMs then return nil end
                if isPos then
                    if first then
                        a, b = tonumber(v1) or 0, tonumber(v2) or 0
                    else
                        a, b = a + (tonumber(v1) or 0), b + (tonumber(v2) or 0)
                    end
                else
                    a = tonumber(v1) or 0
                    if v2 ~= "" then b = tonumber(v2) or b end
                end
                return t0 + ms / 1000, a, b
            end
        end
    end
end
function Decode.Hp(seg, name, from, to)
    return Points(seg, "hp", name, from, to)
end
function Decode.Pos(seg, name, from, to)
    return Points(seg, "pos", name, from, to)
end
function Decode.Mana(seg, name, from, to)
    return Points(seg, "mana", name, from, to)
end
function Decode.Names(seg, kind)
    local out, seen = {}, {}
    local store = seg[kind]
    for name in pairs(store or {}) do
        seen[name] = true
        out[#out + 1] = name
    end
    for name in pairs(ns.RecCodec.LiveBufs(seg, kind) or {}) do
        if not seen[name] then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end
function Decode.Maps(seg)
    local out = {}
    local maps = seg.maps
    if type(maps) == "table" then maps = table.concat(maps, ";") end
    if type(maps) ~= "string" then return out end
    local ms = 0
    for d, area, level, name in gmatch(maps, "(-?%d*),(%d*):(%d*):([^;]*)") do
        ms = #out == 0 and (tonumber(d) or 0) or ms + (tonumber(d) or 0)
        out[#out + 1] = { t = seg.t0 + ms / 1000, area = tonumber(area) or 0, level = tonumber(level) or 0,
                          name = name ~= "" and name or nil }
    end
    return out
end
