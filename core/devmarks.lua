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
    { key = "rot_nw", label = "dev.mark.rot_nw", short = "dev.mark.rot_nw.s", toggle = true },
    { key = "rot_ne", label = "dev.mark.rot_ne", short = "dev.mark.rot_ne.s", toggle = true },
    { key = "rot_sw", label = "dev.mark.rot_sw", short = "dev.mark.rot_sw.s", toggle = true },
    { key = "rot_se", label = "dev.mark.rot_se", short = "dev.mark.rot_se.s", toggle = true },
    { key = "put_green", label = "dev.mark.put_green", room = "putricide" },
    { key = "put_red", label = "dev.mark.put_red", room = "putricide" },
}
local byKey = {}
for i = 1, #Marks.list do byKey[Marks.list[i].key] = Marks.list[i] end
function Marks.Clean(text)
    local s = gsub(gsub(tostring(text or ""), "|", ""), "%c", "")
    s = s:match("^%s*(.-)%s*$") or ""
    return sub(s, 1, TEXT_MAX)
end
function Marks.Here(def)
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then SetMapToCurrentZone() end
    local x, y = GetPlayerMapPosition("player")
    if not x or (x == 0 and y == 0) then return nil end
    local lvl = GetCurrentMapDungeonLevel() or 0
    local text = format("%.4f,%.4f,%d", x, y, lvl)
    local R = ns.Replay
    local room = R and def.room and R.ROOMS[def.room]
    if not room or room.floor ~= lvl then return text end
    local ppy = R.PixelsPerYard(R.AreaOf(room), lvl)
    return text, (x * R.AREA_W - room.cx) / ppy, (y * R.AREA_H - room.cy) / ppy
end
function Marks.Label(key, text)
    local def = byKey[tostring(key)]
    if def and def.room and text and text ~= "" then return format(ns.T("dev.mark.at"), ns.T(def.label), Marks.Clean(text)) end
    if def and def.toggle and (text == "on" or text == "off") then
        return format(ns.T("dev.mark." .. text), ns.T(def.label))
    end
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
    local def = byKey[key]
    if def and def.room then
        s = Marks.Here(def)
        if not s then return false, ns.T("dev.mark.nopos") end
    end
    if not custom and not byKey[key] then return false, ns.T("dev.mark.unknown") end
    if custom and s == "" then return false, ns.T("dev.mark.empty") end
    local rec = ns.Recorder
    if not rec or not rec.Mark then return false, ns.T("dev.mark.norec") end
    local who = UnitName("player")
    if not rec.Mark(SUB, nil, who, 0, nil, nil, 0, key, s) then return false, ns.T("dev.mark.norec") end
    return true, Marks.Line(key, s)
end
function Marks.Def(key)
    return byKey[key]
end
Marks.on = {}
function Marks.Toggle(key)
    local def = byKey[key]
    if not def or not def.toggle then return false, ns.T("dev.mark.unknown") end
    local on = not Marks.on[key]
    local s = on and "on" or "off"
    local rec = ns.Recorder
    if not rec or not rec.Mark then return false, ns.T("dev.mark.norec") end
    if not rec.Mark(SUB, nil, UnitName("player"), 0, nil, nil, 0, key, s) then return false, ns.T("dev.mark.norec") end
    Marks.on[key] = on
    return true, Marks.Line(key, s)
end
