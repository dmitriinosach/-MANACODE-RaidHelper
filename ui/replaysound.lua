local _, ns = ...
local floor = math.floor
local format = string.format
local DBM = "DBM-Core"
local DBM_FILE = "Interface\\AddOns\\DBM-Core\\sounds\\Alert.mp3"
local CLIENT = "RaidWarning"
local GAP = 1.5
local SEEK_MAX = 1
local SPEED_MAX = 2
local ICON = 14
local S = { GAP = GAP, SPEED_MAX = SPEED_MAX }
ns.ReplaySound = S
local Kit = ns.Kit
local RD = ns.ReplayDraw
local st = { played = 0, at = nil, last = nil }
local Saved = RD.Saved
local function Off()
    local saved = Saved()
    if type(saved.sndOff) ~= "table" then saved.sndOff = {} end
    return saved.sndOff
end
function S.On()
    return Saved().barSound ~= false
end
function S.SetOn(on)
    Saved().barSound = on and true or false
end
function S.SpellOn(id)
    return not Off()[tostring(id)]
end
function S.SetSpell(id, on)
    Off()[tostring(id)] = (not on) or nil
end
function S.Source()
    if IsAddOnLoaded and IsAddOnLoaded(DBM) then return "dbm" end
    return "client"
end
function S.Play()
    st.played = st.played + 1
    if S.Source() == "dbm" and pcall(PlaySoundFile, DBM_FILE) then return end
    PlaySound(CLIENT)
end
function S.Abilities(L)
    local out, seen = {}, {}
    local B = L and L.bars
    for i = 1, B and #B.tracks or 0 do
        local def = B.tracks[i].def
        local id = def.spell[1]
        if def.alert and not seen[id] then
            seen[id] = true
            local name, icon = ns.ReplayBars.Spell(def)
            out[#out + 1] = { id = id, name = name, icon = icon }
        end
    end
    local bomb = L and L.bombs and #L.bombs > 0 and L.bombDef
    if bomb and bomb.lead and not seen[bomb.icon] then
        local name, _, icon = GetSpellInfo(bomb.icon)
        out[#out + 1] = { id = bomb.icon, name = name or tostring(bomb.icon), icon = icon }
    end
    return out
end
local function After(list, t0)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if list[mid].t <= t0 then lo = mid + 1 else hi = mid - 1 end
    end
    return lo
end
function S.Due(L, t0, t1)
    local B = L.bars
    if B then
        local list = B.alerts
        for j = After(list, t0), #list do
            local a = list[j]
            if a.t > t1 then break end
            if S.SpellOn(B.tracks[a.k].def.spell[1]) then return true end
        end
    end
    local bombs, def = L.bombs, L.bombDef
    if bombs and def and def.lead and S.SpellOn(def.icon) then
        for i = 1, #bombs do
            local at = bombs[i].t - def.lead
            if at > t0 and at <= t1 then return true end
        end
    end
    return false
end
function S.Step(L, t, playing, speed)
    local last = st.last
    st.last = t
    if not (L and playing and last and t > last and t - last < SEEK_MAX) then return end
    if (tonumber(speed) or 1) > SPEED_MAX or not S.On() then return end
    if not S.Due(L, last, t) then return end
    local now = GetTime()
    if st.at and now - st.at < GAP then return end
    st.at = now
    S.Play()
end
function S.Reset()
    st.last = nil
end
local function Label(a)
    if not a.icon then return a.name end
    return format("|T%s:%d:%d|t %s", a.icon, ICON, ICON, a.name)
end
function S.Menu(anchor, onChange)
    local function Build()
        local scene = ns.ReplayIso and ns.ReplayIso.Scene()
        local list = S.Abilities(scene and scene.layers)
        local items = { { text = ns.T("rep.snd.menu"), isTitle = true } }
        for i = 1, #list do
            local a = list[i]
            items[#items + 1] = { text = Label(a), checked = S.SpellOn(a.id), func = function()
                S.SetSpell(a.id, not S.SpellOn(a.id))
                if onChange then onChange() end
                Kit.Menu(Build, anchor)
            end }
        end
        if #list == 0 then items[#items + 1] = { text = ns.T("rep.snd.none"), note = "text.secondary" } end
        items[#items + 1] = { text = ns.T("rep.snd.test"), tip = ns.T("rep.snd.src." .. S.Source()), func = function()
            S.Play()
            Kit.Menu(Build, anchor)
        end }
        return items
    end
    Kit.Menu(Build, anchor)
end
function S.Tip(L)
    local list = S.Abilities(L)
    local on = 0
    for i = 1, #list do
        if S.SpellOn(list[i].id) then on = on + 1 end
    end
    return format(ns.T("rep.snd.count"), on, #list)
end
function S.Probe()
    return { played = st.played, at = st.at }
end
