local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local Kit = ns.Kit
local LEAD = 5
local PLAY_TEX = "Interface\\OptionsFrame\\VoiceChat-Play"
local MINIPAD = 4
local RL = {}
ns.ReplayLink = RL
RL.LEAD = LEAD
local head
local save
local function Clock(sec)
    local m = floor(sec / 60)
    return format("%d:%02d", m, floor(sec - m * 60))
end
function RL.TryText(f)
    local out = format("%s %s", ns.T(f.killed and "fl.win" or "fl.wipe"), Clock(f.to - f.from))
    local spot = ns.FightTree and ns.FightTree.Spot(f)
    if spot then return format(ns.T("rp.try"), ns.EncName(f.boss), spot.n, out) end
    return format(ns.T("rp.try.bare"), ns.EncName(f.boss), out)
end
function RL.Start(fight, t)
    if not (fight and t) then return nil end
    return max(0, t - fight.from - LEAD)
end
function RL.Open(fight, t, who)
    if not (fight and ns.ReplayIso) then return false end
    ns.ReplayIso.Open(fight, RL.Start(fight, t), who)
    return true
end
function RL.Shift(fight, t, who)
    if not (fight and t and IsShiftKeyDown and IsShiftKeyDown()) then return false end
    ns.Tip.Hide()
    return RL.Open(fight, t, who)
end
function RL.Line(fight, t, who)
    local s = RL.Start(fight, t)
    if not (s and ns.ReplayIso) then return nil end
    return { kind = "foot", left = format(ns.T("rp.shift"), Clock(s)) }
end
function RL.Tag(lines, fight, t)
    lines[#lines + 1] = RL.Line(fight, t)
    return lines
end
function RL.First(list, key)
    local best
    for i = 1, #(list or {}) do
        local v = list[i]
        if key then v = v[key] end
        if v and (not best or v < best) then best = v end
    end
    return best
end
local function HeadClick(b)
    local TL = ns.Timeline
    local f, who
    if TL and TL.View then f, who = TL.View() end
    RL.Open(b.fight, nil, f == b.fight and who or nil)
end
function RL.Head(host)
    local b = Kit.ToolButton(host, nil, PLAY_TEX)
    b:SetLabel(ns.T("rp.btn"))
    b.tipTitle = ns.T("rp.head")
    b.onClick = HeadClick
    head = b
    RL.SetFight(nil)
    return b
end
function RL.SaveHead(host)
    local b = Kit.ToolButton(host)
    b:SetLabel(ns.T("save.btn"))
    b.tipTitle = ns.T("save.head")
    b.tip = ns.T("save.tip")
    b.onClick = function()
        if InCombatLockdown() or UnitAffectingCombat("player") then
            ns.Print(ns.T("save.combat"))
            return
        end
        Kit.Confirm(ns.T("save.ask"), ns.T("save.btn"), function() ReloadUI() end)
    end
    save = b
    if head and not head:IsShown() then b:Hide() end
    return b
end
function RL.HeadFrame()
    return head
end
function RL.SaveFrame()
    return save
end
function RL.SetFight(f)
    if not head then return end
    head.fight = f
    if f then head:Show() else head:Hide() end
    if save then
        if f then save:Show() else save:Hide() end
    end
    if f and ns.ReplayIso then
        head:Enable()
        Kit.Tint(head.icon, "text.good")
        head.tip = RL.TryText(f)
        head.tipDim = ns.T("rp.head.click")
    else
        head:Disable()
        Kit.Tint(head.icon, "button.textOff")
        head.tip = ns.T(f and "rp.head.none" or "rp.head.off")
        head.tipDim = nil
    end
end
local function MiniEnter(self)
    Kit.Tint(self.icon, "text.good")
    local row = self:GetParent()
    if row.hover then row.hover:Show() end
    if not self.fight then return end
    ns.Tip.Show(self, {
        { kind = "head", left = ns.T("rp.mini") },
        { kind = "row", left = RL.TryText(self.fight) },
        { kind = "foot", left = ns.T("rp.mini.click") },
    })
end
local function MiniLeave(self)
    Kit.Tint(self.icon, "text.muted")
    local row = self:GetParent()
    if row.hover then row.hover:Hide() end
    ns.Tip.Hide()
end
local function MiniClick(self)
    ns.Tip.Hide()
    RL.Open(self.fight, nil)
end
function RL.Mini(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size + MINIPAD)
    b:SetHeight(size + MINIPAD)
    b:RegisterForClicks("LeftButtonUp")
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetWidth(size)
    b.icon:SetHeight(size)
    b.icon:SetPoint("CENTER", 1, 0)
    b.icon:SetTexture(PLAY_TEX)
    Kit.Tint(b.icon, "text.muted")
    b:SetScript("OnEnter", MiniEnter)
    b:SetScript("OnLeave", MiniLeave)
    b:SetScript("OnClick", MiniClick)
    if not ns.ReplayIso then b:Hide() end
    return b
end
