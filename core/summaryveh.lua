local _, ns = ...
local Veh = {}
ns.SummaryVeh = Veh
local band = bit.band
local NpcKey = ns.NpcKey
local IsBoss = ns.IsBossOf
local Captive = ns.SummaryAcc.Captive
local F_BY_PLAYER = ns.F.BY_PLAYER
local F_HOSTILE = ns.F.HOSTILE
local RIDE_BOUNCE = ns.SummaryAcc.RIDE_BOUNCE
local SEAT_NEAR = 2
local function Stint(s, fight, i, st, from, to)
    local bd = s.badges[i]
    if not st.live or (not bd.prepull and from < fight.from) then return end
    local a, z = math.max(from, fight.from), math.min(to, fight.to)
    if z < a then return end
    st.n = st.n + 1
    st.times[#st.times + 1] = a - fight.from
    st.outs = st.outs or {}
    st.outs[#st.outs + 1] = z - fight.from
    st.sec = (st.sec or 0) + z - a
    if bd.wave and s.track then
        st.waves = st.waves or {}
        st.waves[st.n] = ns.Phases.WaveAt(s.track.res, bd.wave, a - fight.from)
    end
    s.icons[i] = s.icons[i] or bd.id
end
local function Ride(s, fight, p, ts, on, gun)
    local seats = s.seatT
    if on and seats then
        local n = #seats + 1
        seats[n], s.seatWho[n], s.seatGun[n] = ts, p.name, gun or false
    end
    if s.useful then Captive(s.useful, p.name, ts, on) end
    local badges = s.badges
    for i = 1, s.own do
        local bd = badges[i]
        if bd.kind == "vehicle" then
            local st = p.badges[i]
            local first = not st.seen
            st.seen = true
            if on then
                if st.on and st.off and ts - st.off <= RIDE_BOUNCE then
                    st.off = nil
                elseif not st.on or st.off then
                    if st.on then Stint(s, fight, i, st, st.on, st.off) end
                    st.on, st.off = ts, nil
                    st.live = not bd.phase or (s.track ~= nil and s.track.key == bd.phase)
                end
            elseif st.on then
                st.off = st.off or ts
            elseif first and bd.prepull then
                st.live = true
                Stint(s, fight, i, st, fight.from, ts)
            end
        end
    end
end
local function RideEnd(s, fight)
    for i = 1, #s.badges do
        if s.badges[i].kind == "vehicle" then
            for k = 1, #s.players do
                local st = s.players[k].badges[i]
                if st.on then Stint(s, fight, i, st, st.on, st.off or fight.to) end
                st.on, st.off = nil, nil
            end
        end
    end
end
local function Sight(s, guid, flags, ts)
    local ep = s.gunOpen[guid]
    if band(flags, F_BY_PLAYER) == 0 then
        s.gunOpen[guid] = nil
        return nil
    end
    if not ep then
        ep = { guid = guid, from = ts, to = ts, hits = 0, ship = 0, kills = 0, dmg = 0, boss = 0 }
        s.gunOpen[guid] = ep
        s.gunEps[#s.gunEps + 1] = ep
    end
    ep.to = ts
    return ep
end
local function Gun(s, fight, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a4, a5)
    local guns = s.guns
    if sub == "PARTY_KILL" then
        local ep = s.killEp
        if ep and dstGUID == s.killDst and ts == s.killTs and srcName and s.byName[srcName] then
            ep.votes = ep.votes or {}
            ep.votes[srcName] = (ep.votes[srcName] or 0) + 1
        end
        return false
    end
    local dstKey, srcKey = NpcKey(dstGUID), NpcKey(srcGUID)
    if dstGUID and dstFlags and dstKey and guns[dstKey] then Sight(s, dstGUID, dstFlags, ts) end
    if not (srcGUID and srcFlags and srcKey and guns[srcKey]) then return false end
    local ep = Sight(s, srcGUID, srcFlags, ts)
    if not ep or not sub:find("_DAMAGE", 1, true) then return true end
    local amount = tonumber(a4) or 0
    if dstKey and s.gun.ships[dstKey] then
        ep.hits = ep.hits + 1
        ep.ship = ep.ship + amount
    elseif dstFlags and band(dstFlags, F_HOSTILE) > 0 and not (dstName and s.byName[dstName]) then
        if ts >= fight.from and ts <= fight.to then
            ep.dmg = ep.dmg + amount
            if IsBoss(fight, dstGUID) then ep.boss = ep.boss + amount end
        end
        if (tonumber(a5) or 0) > 0 then
            ep.kills = ep.kills + 1
            s.killEp, s.killDst, s.killTs = ep, dstGUID, ts
        end
    end
    return true
end
local function Busy(s, who, ep)
    local eps = s.gunEps
    for k = 1, #eps do
        local o = eps[k]
        if o ~= ep and o.rider == who and o.from <= ep.to and o.to >= ep.from then return true end
    end
    return false
end
local function Seat(s, ep, byGun)
    local best, gap
    for k = 1, #s.seatT do
        local t, g, who = s.seatT[k], s.seatGun[k], s.seatWho[k]
        local d = math.abs(t - ep.from)
        local fits
        if byGun then
            fits = g == ep.guid and t <= ep.to
        else
            fits = not g and d <= SEAT_NEAR and not Busy(s, who, ep)
        end
        if fits and (not gap or d < gap) then best, gap = who, d end
    end
    return best
end
local function Voted(ep)
    local best, n
    for who, c in pairs(ep.votes or {}) do
        if not n or c > n then best, n = who, c end
    end
    return best
end
local function GunEnd(s, fight)
    local b = s.gun
    if not b then return end
    local eps = s.gunEps
    local pets = ns.GetDB().pets or {}
    for k = 1, #eps do eps[k].rider = Seat(s, eps[k], true) or Voted(eps[k]) end
    for k = 1, #eps do
        local ep = eps[k]
        if not ep.rider then ep.rider = Seat(s, ep, false) end
        local owner = pets[ep.guid]
        if not ep.rider and owner and s.byName[owner] and not Busy(s, owner, ep) then ep.rider = owner end
    end
    for k = 1, #eps do
        local ep = eps[k]
        local near, gap
        for j = 1, #eps do
            local o = eps[j]
            local d = math.abs(o.from - ep.from)
            if not ep.rider and o.rider and o.guid == ep.guid and (not gap or d < gap) then near, gap = o.rider, d end
        end
        if near and not Busy(s, near, ep) then ep.rider = near end
    end
    local vi
    for i = 1, #s.badges do
        if not vi and s.badges[i].kind == "vehicle" then vi = i end
    end
    for k = 1, #s.players do
        local st = vi and s.players[k].badges[vi]
        if st and st.seen and (st.sec or 0) > 0 then
            local name = s.players[k].name
            b.secs[name] = st.sec
            b.by[name] = b.by[name] or 0
        end
    end
    local nobody = ns.T("sum.k.nogunner")
    for k = 1, #eps do
        local ep = eps[k]
        local p = ep.rider and s.byName[ep.rider]
        local who = p and ep.rider or nobody
        if p then
            local st = vi and p.badges[vi]
            if st and not st.seen then
                st.live = true
                Stint(s, fight, vi, st, ep.from, ep.to)
                b.secs[who] = st.sec
            end
        end
        b.total = b.total + ep.ship
        b.by[who] = (b.by[who] or 0) + ep.ship
        b.hits[who] = (b.hits[who] or 0) + ep.hits
        b.kills[who] = (b.kills[who] or 0) + ep.kills
        b.all[who] = (b.all[who] or 0) + ep.dmg
    end
end
Veh.Ride = Ride
Veh.RideEnd = RideEnd
Veh.Gun = Gun
Veh.GunEnd = GunEnd
