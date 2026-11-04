local _, ns = ...
local pairs = pairs
local tremove = table.remove
local LIMIT = 50
local SIDE = { Button4 = -1, Button5 = 1 }
local Nav = {}
ns.ShellNav = Nav
local places = {}
local list = {}
local index = 0
local depth = 0
local going = false
local back, fwd
local watched = {}
local down = {}
function Nav.Place(key, spec)
    places[key] = spec
end
local function Read()
    local Shell = ns.Shell
    local tab = Shell and Shell.Current()
    if not tab then return nil end
    local p = places[tab]
    return { tab = tab, place = p and p.read() or nil }
end
local function Same(a, b)
    if a.tab ~= b.tab then return false end
    if a.place == nil or b.place == nil then return a.place == b.place end
    local p = places[a.tab]
    return not p or p.same(a.place, b.place)
end
local function Valid(e)
    local p = e.place and places[e.tab]
    return not (p and p.valid) or p.valid(e.place) and true or false
end
local function Commit()
    local cur = Read()
    if not cur then return end
    local top = list[index]
    if top and (Same(top, cur) or (top.tab == cur.tab and top.place == nil)) then
        list[index] = cur
        return
    end
    for i = #list, index + 1, -1 do list[i] = nil end
    list[#list + 1] = cur
    if #list > LIMIT then tremove(list, 1) end
    index = #list
end
local function Target(step)
    local i = index + step
    while list[i] and not Valid(list[i]) do i = i + step end
    return list[i] and i or nil
end
local function Label(e)
    local p = e.place and places[e.tab]
    local text = p and p.label(e.place)
    if text then return text end
    return ns.Shell and ns.Shell.Label(e.tab) or e.tab
end
local function Arrow(b, step)
    if not b then return end
    local i = Target(step)
    if i then b:Enable() else b:Disable() end
    b.tip = i and Label(list[i]) or ns.T(step < 0 and "nav.back.none" or "nav.fwd.none")
    if b.hovered then ns.Kit.TipShow(b) end
end
function Nav.Paint()
    Arrow(back, -1)
    Arrow(fwd, 1)
end
function Nav.Run(fn, ...)
    if going then return fn(...) end
    if depth == 0 then Commit() end
    depth = depth + 1
    local ok, a, b = pcall(fn, ...)
    depth = depth - 1
    if not ok then error(a, 0) end
    if depth == 0 then
        Commit()
        Nav.Paint()
    end
    return a, b
end
local function Go(e)
    local Shell = ns.Shell
    if Shell.Current() ~= e.tab then Shell.Open(e.tab) end
    local p = e.place and places[e.tab]
    if p then p.write(e.place) end
end
function Nav.Step(step)
    local Shell = ns.Shell
    if going or not (Shell and Shell.IsOpen()) then return false end
    Commit()
    local i = Target(step)
    if not i then
        Nav.Paint()
        return false
    end
    index = i
    if ns.Tip then ns.Tip.Hide() end
    going = true
    local ok, err = pcall(Go, list[i])
    going = false
    if not ok then error(err, 0) end
    Nav.Paint()
    return true
end
function Nav.Back()
    return Nav.Step(-1)
end
function Nav.Forward()
    return Nav.Step(1)
end
function Nav.Arrows(b, f)
    back, fwd = b, f
    b.tipTitle, b.tipDim = ns.T("nav.back"), ns.T("nav.back.key")
    f.tipTitle, f.tipDim = ns.T("nav.fwd"), ns.T("nav.fwd.key")
    b.onClick = Nav.Back
    f.onClick = Nav.Forward
    Nav.Paint()
end
local function Over()
    for i = 1, #watched do
        if watched[i]:IsVisible() and MouseIsOver(watched[i]) then return true end
    end
    return false
end
local function Poll()
    if not IsMouseButtonDown then return end
    for button, step in pairs(SIDE) do
        local now = IsMouseButtonDown(button) and true or false
        if now and not down[button] and Over() then Nav.Step(step) end
        down[button] = now
    end
end
function Nav.Watch(frame, strip)
    watched = { frame, strip }
    local pump = CreateFrame("Frame", nil, frame)
    pump:SetScript("OnUpdate", Poll)
end
function Nav.Probe()
    return list, index
end
function Nav.Reset()
    list, index, depth, going = {}, 0, 0, false
    Nav.Paint()
end
