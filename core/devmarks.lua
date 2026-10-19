local _, ns = ...
local format = string.format
local gsub = string.gsub
local sub = string.sub
local SUB = "FW_MARK"
local CUSTOM = "custom"
local TEXT_MAX = 60
local Marks = {}
ns.DevMarks = Marks
Marks.SUB = SUB
Marks.CUSTOM = CUSTOM
local OLD = { lk_fall = "dev.mark.lk_fall", lk_back = "dev.mark.lk_back", rot_nw = "dev.mark.rot_nw",
    rot_ne = "dev.mark.rot_ne", rot_sw = "dev.mark.rot_sw", rot_se = "dev.mark.rot_se",
    sind_up = "dev.mark.sind_up", sind_down = "dev.mark.sind_down", vali_portal = "dev.mark.vali_portal",
    put_green = "dev.mark.put_green", put_red = "dev.mark.put_red" }
local OLD_AT = { put_green = true, put_red = true }
function Marks.Clean(text)
    local s = gsub(gsub(tostring(text or ""), "|", ""), "%c", "")
    s = s:match("^%s*(.-)%s*$") or ""
    return sub(s, 1, TEXT_MAX)
end
function Marks.Label(key, text)
    local k = tostring(key)
    local old = OLD[k]
    if old and OLD_AT[k] and text and text ~= "" then
        return format(ns.T("dev.mark.at"), ns.T(old), Marks.Clean(text))
    end
    if old and (text == "on" or text == "off") then return format(ns.T("dev.mark." .. text), ns.T(old)) end
    if old then return ns.T(old) end
    local s = Marks.Clean(text)
    if s ~= "" then return s end
    return Marks.Clean(key)
end
function Marks.Line(key, text)
    return format(ns.T("dev.mark.line"), Marks.Label(key, text))
end
function Marks.Write(text)
    local s = Marks.Clean(text)
    if s == "" then return false, ns.T("dev.mark.empty") end
    local rec = ns.Recorder
    if not rec or not rec.Mark then return false, ns.T("dev.mark.norec") end
    local who = UnitName("player")
    if not rec.Mark(SUB, nil, who, 0, nil, nil, 0, CUSTOM, s) then return false, ns.T("dev.mark.norec") end
    return true, Marks.Line(CUSTOM, s)
end
