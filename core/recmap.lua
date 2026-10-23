local _, ns = ...
local RecMap = {}
ns.RecMap = RecMap
local mapArea, mapLevel, mapName = nil, nil, nil
local goodArea, goodLevel = nil, nil
local levelOk = true
local viewArea, viewLevel, viewCont, viewZone, viewHere = nil, 0, 0, 0, nil
function RecMap.Level()
    return goodLevel
end
function RecMap.Reset()
    mapArea, mapLevel, mapName = nil, nil, nil
    levelOk = true
end
local function CountOnMap()
    local slots, slotUnit, _, _, slotPlayer = ns.Recorder.Roster(true)
    local on, alive = 0, 0
    for k = 1, slots do
        local unit = slotUnit[k]
        if slotPlayer[k] and not UnitIsDeadOrGhost(unit) then
            alive = alive + 1
            local x, y = GetPlayerMapPosition(unit)
            if (x or 0) > 0 or (y or 0) > 0 then on = on + 1 end
        end
    end
    return on, alive
end
local function TryLevel(level)
    SetDungeonMapLevel(level)
    return CountOnMap()
end
local function PickLevel()
    local on, alive = CountOnMap()
    local was = GetCurrentMapDungeonLevel() or 0
    local area = GetCurrentMapAreaID()
    if on * 2 > alive then
        if was > 0 then goodArea, goodLevel = area, was end
        return true
    end
    local n = GetNumDungeonMapLevels() or 0
    if n < 2 then return on > 0 end
    local first = goodLevel and goodArea == area and goodLevel ~= was and goodLevel <= n and goodLevel or nil
    local best, bestOn = was, on
    if first then
        local c = TryLevel(first)
        if c > bestOn then best, bestOn = first, c end
    end
    if bestOn * 2 <= alive then
        for level = 1, n do
            if level ~= was and level ~= first then
                local c = TryLevel(level)
                if c > bestOn then best, bestOn = level, c end
                if c * 2 > alive then break end
            end
        end
    end
    if bestOn == 0 then best = first or was end
    if best == 0 then
        SetMapToCurrentZone()
    elseif best ~= GetCurrentMapDungeonLevel() then
        SetDungeonMapLevel(best)
    end
    if bestOn == 0 then return false end
    goodArea, goodLevel = area, best
    return true
end
local function ReadMap()
    local area, level, name = GetCurrentMapAreaID(), GetCurrentMapDungeonLevel(), GetMapInfo() or ""
    if area == mapArea and level == mapLevel and name == mapName then return false end
    mapArea, mapLevel, mapName = area, level, name
    return ns.Store.Map(ns.Recorder.Now(), area, level, name)
end
local function Borrow(refresh)
    local area, level = GetCurrentMapAreaID(), GetCurrentMapDungeonLevel() or 0
    if area == goodArea and level == goodLevel and CountOnMap() > 0 then return end
    viewArea, viewLevel = area, level
    viewCont, viewZone = GetCurrentMapContinent() or 0, GetCurrentMapZone() or 0
    SetMapToCurrentZone()
    viewHere = GetCurrentMapAreaID()
    if refresh or levelOk then
        levelOk = PickLevel()
    elseif goodLevel and viewHere == goodArea and goodLevel ~= GetCurrentMapDungeonLevel() then
        SetDungeonMapLevel(goodLevel)
    end
end
function RecMap.Restore()
    local area = viewArea
    if not area then return end
    viewArea = nil
    if area ~= viewHere then
        if viewZone > 0 then SetMapZoom(viewCont, viewZone) else SetMapZoom(viewCont) end
    end
    if GetCurrentMapAreaID() == area and viewLevel > 0 and (GetCurrentMapDungeonLevel() or 0) ~= viewLevel then
        SetDungeonMapLevel(viewLevel)
    end
end
function RecMap.Read(withPos, refresh)
    if withPos then
        if WorldMapFrame:IsShown() then
            Borrow(refresh)
            return ReadMap()
        end
        if refresh then SetMapToCurrentZone() end
        if refresh or (levelOk and CountOnMap() == 0) then
            levelOk = PickLevel()
        end
        return ReadMap()
    elseif not mapArea then
        return ReadMap()
    end
    return false
end
