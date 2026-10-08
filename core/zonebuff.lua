local _, ns = ...
local SNAP_SUB = "FW_BUFFSNAP"
local SNAP_LEAD = 5
local SUBS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true,
               SPELL_AURA_APPLIED_DOSE = true, [SNAP_SUB] = true }
local ZB = {}
ns.ZoneBuff = ZB
ZB.ON = "on"
ZB.OFF = "off"
local idSet
local function Ids()
    if idSet then return idSet end
    idSet = {}
    local data = ns.zoneBuff
    for i = 1, data and #data.ids or 0 do idSet[data.ids[i]] = true end
    return idSet
end
function ZB.InZone(fight)
    local data = ns.zoneBuff
    if not (data and fight) then return false end
    local db = ns.GetDB and ns.GetDB()
    local seg = db and db.segments and fight.seg and db.segments[fight.seg]
    local map = seg and ns.Encounters and ns.Encounters.MapOf(seg) or (fight.raid and fight.raid.map)
    return map == data.map
end
function ZB.Begin(fight)
    if not ZB.InZone(fight) then return nil end
    return { from = fight.from, to = fight.to, seen = false, snap = nil, subs = SUBS }
end
function ZB.Feed(st, ts, sub, id, on)
    if not Ids()[tonumber(id) or 0] then return end
    if sub == SNAP_SUB then
        if ts >= st.from - SNAP_LEAD and ts <= st.to then st.snap = type(on) == "string" and on ~= "" end
    elseif ts >= st.from and ts <= st.to then
        st.seen = true
    end
end
function ZB.Finish(st)
    if st.seen or st.snap == true then return ZB.ON end
    if st.snap == false then return ZB.OFF end
    return nil
end
function ZB.Of(fight)
    if not fight then return nil end
    local s = ns.Summary and ns.Summary.Peek(fight)
    if s then return s.zoneBuff end
    return ns.Digest and ns.Digest.ZoneBuff(fight) or nil
end
function ZB.Unbuffed(fight)
    return fight ~= nil and fight.killed == true and ZB.Of(fight) == ZB.OFF
end
