local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local BTN_H = 18
local BTN_W = 74
local BTN_PAD = 16
local HEAD_PAD = 6
local HEAD_Y = -19
local GEAR_GAP = 4
local Kit = ns.Kit
local T = ns.T
local DV = {}
ns.DiscordView = DV
local btn
function DV.Send(res)
    if #res.sums == 0 then
        ns.Print(T("dc.empty"))
        return
    end
    local post = ns.Discord.Queue(res)
    ns.Print(format(T("dc.queued"), post.raid, #post.bosses))
    if InCombatLockdown() or UnitAffectingCombat("player") then return end
    Kit.Confirm(T("dc.ask"), T("save.btn"), function() ReloadUI() end)
end
local function Click()
    local key = ns.RaidSummaryView and ns.RaidSummaryView.ShownKey()
    local raid = key and ns.RaidSummary.Find(key)
    if not raid then return end
    local res = ns.RaidSummary.Get(raid)
    if not res then
        ns.Print(T("dc.wait"))
        return
    end
    DV.Send(res)
end
local function Place(b, host)
    local gear = ns.SumHide and ns.SumHide.HeadFrame and ns.SumHide.HeadFrame()
    b:ClearAllPoints()
    if gear then
        b:SetPoint("RIGHT", gear, "LEFT", -GEAR_GAP, 0)
    else
        b:SetPoint("RIGHT", host:GetParent() or host, "TOPRIGHT", -HEAD_PAD, HEAD_Y)
    end
end
function DV.Attach(host)
    if btn then return end
    local b = Kit.Button(host)
    b:SetHeight(BTN_H)
    Place(b, host)
    b:HookScript("OnShow", function(self) Place(self, host) end)
    b.text:SetText(T("dc.btn"))
    b:SetWidth(max(BTN_W, floor(b.text:GetStringWidth() + BTN_PAD)))
    b.tipTitle = T("dc.head")
    b.tip = T("dc.tip")
    b.onClick = Click
    btn = b
end
function DV.Button()
    return btn
end
