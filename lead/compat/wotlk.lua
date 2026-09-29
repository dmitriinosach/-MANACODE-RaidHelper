local ADDON, root = ...
root.Lead = root.Lead or {}
local ns = root.Lead
local C = {}
ns.Compat = C
C.family = "wotlk"
function ns.NewFrame(kind, name, parent, template, id)
    return CreateFrame(kind, name, parent, template, id)
end
function ns.Paint(tex, r, g, b, a)
    tex:SetTexture(r, g, b, a)
end
function ns.Gradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetGradientAlpha(orient, r1, g1, b1, a1, r2, g2, b2, a2)
end
function ns.Listen(frame, event)
    frame:RegisterEvent(event)
    return true
end
function C.GroupSize()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    return raid, party
end
function C.UnitGuid(unit)
    return UnitGUID(unit)
end
function C.ItemLevel(link)
    local _, _, _, ilvl = GetItemInfo(link)
    return ilvl
end
function C.RefreshGuild()
    if IsInGuild() then GuildRoster() end
end
function C.GuildMembers()
    local out = {}
    if not IsInGuild() then return out end
    for i = 1, GetNumGuildMembers(true) or 0 do
        local name, _, _, level, _, zone, _, _, online, _, token = GetGuildRosterInfo(i)
        if name and token then
            out[#out + 1] = { name = name, class = token, level = level or 0, zone = zone,
                online = online and true or false }
        end
    end
    return out
end
function C.SpellIcon(id)
    local _, _, tex = GetSpellInfo(id)
    return tex
end
function C.PlaySound(ref)
    PlaySound(ref)
    return true
end
function C.SendAddon(prefix, msg, chan, target)
    SendAddonMessage(prefix, msg, chan, target)
    return true
end
local RAID_TAB = 5
function C.OpenRaidFrame()
    if InCombatLockdown() or not ToggleFriendsFrame or not FriendsFrame then return false end
    if FriendsFrame:IsShown() and FriendsFrame.selectedTab == RAID_TAB then return true end
    ToggleFriendsFrame(RAID_TAB)
    return true
end
function C.RaidDifficulty()
    return GetRaidDifficulty and GetRaidDifficulty() or nil
end
function C.SetRaidDifficulty(n)
    if not SetRaidDifficulty then return false end
    SetRaidDifficulty(n)
    return true
end
function C.InInstance()
    local inside = IsInInstance()
    return inside and true or false
end
