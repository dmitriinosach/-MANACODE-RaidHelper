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
Marks.list = {
    { key = "lk_fall", label = "dev.mark.lk_fall" },
    { key = "lk_back", label = "dev.mark.lk_back" },
    { key = "sind_up", label = "dev.mark.sind_up" },
    { key = "sind_down", label = "dev.mark.sind_down" },
    { key = "vali_portal", label = "dev.mark.vali_portal" },
}
local byKey = {}
for i = 1, #Marks.list do byKey[Marks.list[i].key] = Marks.list[i] end
function Marks.Clean(text)
    local s = gsub(gsub(tostring(text or ""), "|", ""), "%c", "")
    s = s:match("^%s*(.-)%s*$") or ""
    return sub(s, 1, TEXT_MAX)
end
function Marks.Label(key, text)
    local def = byKey[tostring(key)]
    if def then return ns.T(def.label) end
    local s = Marks.Clean(text)
    if s ~= "" then return s end
    return Marks.Clean(key)
end
function Marks.Line(key, text)
    return format(ns.T("dev.mark.line"), Marks.Label(key, text))
end
function Marks.Write(key, text)
    local custom = key == CUSTOM
    local s = custom and Marks.Clean(text) or nil
    if not custom and not byKey[key] then return false, ns.T("dev.mark.unknown") end
    if custom and s == "" then return false, ns.T("dev.mark.empty") end
    local rec = ns.Recorder
    if not rec or not rec.Mark then return false, ns.T("dev.mark.norec") end
    local who = UnitName("player")
    if not rec.Mark(SUB, nil, who, 0, nil, nil, 0, key, s) then return false, ns.T("dev.mark.norec") end
    return true, Marks.Line(key, s)
end
