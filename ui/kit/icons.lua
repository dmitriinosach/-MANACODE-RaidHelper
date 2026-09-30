local _, ns = ...
local Kit = ns.Kit
local CLASSES_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CIRCLES_TEX = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CIRCLE_INSET = 3 / 256
local ROLE_TEX = "Interface\\LFGFrame\\LFGRole"
local PORTRAIT = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local MARK_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local HEROIC_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-HEROIC"
local FOLD_TEX = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local CLASS_COORD = {
    WARRIOR = { 0, 0.25, 0, 0.25 },
    MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 },
    SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
    DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}
local ROLE_COORD = {
    dd = { 0.25, 0.5, 0, 1 },
    tank = { 0.5, 0.75, 0, 1 },
    heal = { 0.75, 1, 0, 1 },
}
local PORTRAIT_COORD = {
    heal = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    tank = { 0, 19 / 64, 22 / 64, 41 / 64 },
    dd = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
Kit.FLAG_TEX = {
    leader = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
    assist = "Interface\\GroupFrame\\UI-Group-AssistantIcon",
    mt = "Interface\\GroupFrame\\UI-Group-MainTankIcon",
    ma = "Interface\\GroupFrame\\UI-Group-MainAssistIcon",
    ml = "Interface\\GroupFrame\\UI-Group-MasterLooter",
}
Kit.NOTE_TEX = "Interface\\Icons\\INV_Misc_Note_01"
Kit.DICE_TEX = "Interface\\Icons\\INV_Misc_Dice_01"
Kit.DOT_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
Kit.QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
Kit.GEAR_TEX = "Interface\\WorldMap\\Gear_64Grey"
local Icon = {}
Kit.Icon = Icon
function Icon.Spell(tex, spell)
    local path
    if spell then
        local _, _, icon = GetSpellInfo(spell)
        path = icon
    end
    tex:SetTexture(path or Kit.QMARK)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end
function Icon.Class(tex, token)
    local c = token and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]) or CLASS_COORD[token])
    if c then
        tex:SetTexture(CLASSES_TEX)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        tex:SetTexture(Kit.QMARK)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end
function Icon.ClassCircle(tex, token)
    local c = token and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]) or CLASS_COORD[token])
    if not c then
        tex:SetTexture(Kit.QMARK)
        tex:SetTexCoord(0, 1, 0, 1)
        return false
    end
    tex:SetTexture(CIRCLES_TEX)
    tex:SetTexCoord(c[1] + CIRCLE_INSET, c[2] - CIRCLE_INSET, c[3] + CIRCLE_INSET, c[4] - CIRCLE_INSET)
    return true
end
function Icon.Role(tex, grp)
    local c = ROLE_COORD[grp or "dd"] or ROLE_COORD.dd
    tex:SetTexture(ROLE_TEX)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
function Icon.RoleBig(tex, grp)
    local c = PORTRAIT_COORD[grp or "dd"] or PORTRAIT_COORD.dd
    tex:SetTexture(PORTRAIT)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end
function Icon.Mark(tex, i)
    tex:SetTexture(MARK_TEX:format(i))
    tex:SetTexCoord(0, 1, 0, 1)
end
function Icon.Heroic(tex)
    tex:SetTexture(HEROIC_TEX)
    tex:SetTexCoord(0, 0.5, 0, 0.5625)
end
function Icon.Fold(tex, open)
    tex:SetTexture(FOLD_TEX)
    local a, b = 0.125, 0.875
    if open then
        tex:SetTexCoord(a, b, b, b, a, a, b, a)
    else
        tex:SetTexCoord(a, a, a, b, b, a, b, b)
    end
end
