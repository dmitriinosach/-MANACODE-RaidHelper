local _, ns = ...
local max = math.max
local sort = table.sort
local TICK = 1
local HITCH = 0.1
local TOP = 10
local TOP_FRAMES = 8
local TOP_EVENTS = 6
local TOP_SPIKE = 3
local SPIKES = 5
local MIN_MS = 0.05
local EVENTS = {
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "UNIT_HEALTH", "UNIT_POWER", "UNIT_MANA", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_TARGET", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "BAG_UPDATE",
    "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE",
    "WORLD_MAP_UPDATE", "MINIMAP_UPDATE_TRACKING", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "UPDATE_INSTANCE_INFO", "QUEST_LOG_UPDATE", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN",
    "UNIT_INVENTORY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED",
}
local Live = { HITCH = HITCH, EVENTS = EVENTS, addons = {}, events = {}, frames = {}, spikes = {}, cost = 0, nFrames = 0 }
ns.CpuLive = Live
local frame = CreateFrame("Frame")
frame:Hide()
local running, withFrames = false, false
local acc = 0
local secA, hitA, rate = {}, {}, {}
local secE = {}
local secF = setmetatable({}, { __mode = "k" })
local hitF = setmetatable({}, { __mode = "k" })
local frameRate = setmetatable({}, { __mode = "k" })
function Live.Profiled()
    return ns.CpuMeter ~= nil and ns.CpuMeter.Profiled() and UpdateAddOnCPUUsage ~= nil
end
function Live.Running()
    return running
end
function Live.Frames()
    return withFrames
end
local function ByMs(a, b)
    if a.ms ~= b.ms then return a.ms > b.ms end
    return a.name < b.name
end
local function Top(list, n)
    sort(list, ByMs)
    for i = #list, n + 1, -1 do list[i] = nil end
    return list
end
local function FrameName(f)
    local name = f.GetName and f:GetName()
    if name then return name end
    local p = f.GetParent and f:GetParent()
    local pn = p and p.GetName and p:GetName()
    return pn and (pn .. " > ?") or "?"
end
local function AddonUsage()
    UpdateAddOnCPUUsage()
    local cur = {}
    for i = 1, GetNumAddOns() do cur[i] = GetAddOnCPUUsage(i) or 0 end
    return cur
end
local function FrameDeltas(base, dt, want, mirror)
    local out, n = {}, 0
    local f = EnumerateFrames()
    while f do
        n = n + 1
        local u = GetFrameCPUUsage(f, false) or 0
        local was = base[f]
        base[f] = u
        if mirror then mirror[f] = u end
        if was then
            local d = want and (u - was - (want[f] or 0) * dt) or (u - was) / dt
            if not want then frameRate[f] = d end
            if d >= MIN_MS then out[#out + 1] = { name = FrameName(f), ms = d } end
        end
        f = EnumerateFrames(f)
    end
    return out, n
end
local function Tick(dt)
    local p0 = debugprofilestop()
    local cur = AddonUsage()
    local rows = {}
    for i = 1, #cur do
        local d = (cur[i] - (secA[i] or cur[i])) / dt
        rate[i] = d
        if d >= MIN_MS then rows[#rows + 1] = { name = (GetAddOnInfo(i)) or "?", ms = d } end
        secA[i], hitA[i] = cur[i], cur[i]
    end
    Live.addons = Top(rows, TOP)
    local ev = {}
    for i = 1, #EVENTS do
        local u = GetEventCPUUsage and GetEventCPUUsage(EVENTS[i]) or 0
        local d = (u - (secE[i] or u)) / dt
        secE[i] = u
        if d >= MIN_MS then ev[#ev + 1] = { name = EVENTS[i], ms = d } end
    end
    Live.events = Top(ev, TOP_EVENTS)
    if withFrames then
        local fr, n = FrameDeltas(secF, dt, nil, hitF)
        Live.frames, Live.nFrames = Top(fr, TOP_FRAMES), n
    end
    Live.cost = debugprofilestop() - p0
    if Live.onTick then Live.onTick() end
end
local function Spike(ms, dt)
    local cur = AddonUsage()
    local rows = {}
    for i = 1, #cur do
        local d = cur[i] - (hitA[i] or cur[i]) - max(0, rate[i] or 0) * dt
        hitA[i] = cur[i]
        if d >= 1 then rows[#rows + 1] = { name = (GetAddOnInfo(i)) or "?", ms = d } end
    end
    local frames = {}
    if withFrames then
        local all = FrameDeltas(hitF, dt, frameRate)
        for i = 1, #all do
            if all[i].ms >= 1 then frames[#frames + 1] = all[i] end
        end
        frames = Top(frames, TOP_SPIKE)
    end
    table.insert(Live.spikes, 1, { at = GetTime(), ms = ms, addons = Top(rows, TOP_SPIKE), frames = frames })
    for i = #Live.spikes, SPIKES + 1, -1 do Live.spikes[i] = nil end
end
local sinceTick = 0
function Live.Step(elapsed)
    if not running then return end
    acc = acc + elapsed
    sinceTick = sinceTick + elapsed
    if elapsed >= HITCH then
        Spike(elapsed * 1000, sinceTick)
        if Live.onTick then Live.onTick() end
    end
    if acc >= TICK then
        Tick(acc)
        acc, sinceTick = 0, 0
    end
end
function Live.Start()
    if running or not Live.Profiled() then return end
    running, acc, sinceTick = true, 0, 0
    Live.addons, Live.events, Live.frames, Live.spikes, Live.nFrames = {}, {}, {}, {}, 0
    local cur = AddonUsage()
    for i = 1, #cur do secA[i], hitA[i], rate[i] = cur[i], cur[i], 0 end
    for i = 1, #EVENTS do secE[i] = GetEventCPUUsage and GetEventCPUUsage(EVENTS[i]) or 0 end
    frame:Show()
end
function Live.Stop()
    running = false
    frame:Hide()
end
function Live.SetFrames(on)
    withFrames = on and true or false
    for f in pairs(secF) do secF[f] = nil end
    for f in pairs(hitF) do hitF[f] = nil end
    for f in pairs(frameRate) do frameRate[f] = nil end
    Live.frames, Live.nFrames = {}, 0
end
frame:SetScript("OnUpdate", function(_, elapsed) Live.Step(elapsed) end)
