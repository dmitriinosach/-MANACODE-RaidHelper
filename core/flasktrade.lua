local _, ns = ...
local format = string.format
local match = string.match
local tonumber = tonumber
local BAGS = 4
local GIVE_SLOTS = 6
local ALL_SLOTS = 7
local DELAY = 0.3
local ACCEPT_WAIT = 1.5
local STOCK_WAIT = 2
local BLOCK_AFTER = 2
local Trade = {}
ns.FlaskTrade = Trade
local F = ns.Flasks
local T = ns.T
local cur = { id = 0, open = false }
local fails = 0
local blocked = false
local tasks = {}
local listeners = {}
local frame = CreateFrame("Frame")
local function Changed()
    for i = 1, #listeners do listeners[i]() end
end
function Trade.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function Trade.State()
    return cur
end
function Trade.AutoBlocked()
    return blocked
end
local function Say(text)
    ns.Print(text)
end
local function After(sec, fn, any)
    tasks[#tasks + 1] = { at = GetTime() + sec, id = not any and cur.id or nil, fn = fn }
    frame:Show()
end
local function LinkId(link)
    return link and tonumber(match(link, "item:(%d+)")) or nil
end
local function Stock(id)
    return GetItemCount(id) or 0
end
local function FindSlot(id)
    for bag = 0, BAGS do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            if LinkId(GetContainerItemLink(bag, slot)) == id then
                local _, count, locked = GetContainerItemInfo(bag, slot)
                if not locked then return bag, slot, count or 1 end
            end
        end
    end
    return nil, nil, 0
end
local function FreeSlot()
    for i = 1, GIVE_SLOTS do
        if not GetTradePlayerItemInfo(i) then return i end
    end
    return nil
end
local function Ours()
    if not cur.slot or not cur.item then return false end
    for i = 1, ALL_SLOTS do
        local name, _, n = GetTradePlayerItemInfo(i)
        if i == cur.slot then
            if LinkId(GetTradePlayerItemLink(i)) ~= cur.item.id or (n or 1) ~= 1 then return false end
        elseif name then
            return false
        end
    end
    return (GetPlayerTradeMoney() or 0) == 0
end
local function Holds()
    if not cur.slot or not cur.item then return false end
    return LinkId(GetTradePlayerItemLink(cur.slot)) == cur.item.id
end
local function TargetEmpty()
    for i = 1, ALL_SLOTS do
        if GetTradeTargetItemInfo(i) then return false end
    end
    return (GetTargetTradeMoney() or 0) == 0
end
local function Reason(plan)
    local who = plan.name
    if plan.why == "norm" then return format(T("flask.why.norm"), who, plan.n, plan.norm) end
    if plan.why == "gap" then return format(T("flask.why.gap"), who, F.Minutes(plan.wait or 0)) end
    if plan.why == "own" then return format(T("flask.why.own"), who, plan.has or 0) end
    if plan.why == "bags" then return format(T("flask.why.bags"), F.ItemName(plan.item)) end
    return format(T("flask.why.role"), who)
end
Trade.Reason = Reason
local function Whisper(plan)
    if not F.Get("whisper") then return end
    local key
    if plan.why == "norm" then
        key = format(T("flask.tell.norm"), plan.norm)
    elseif plan.why == "gap" then
        key = format(T("flask.tell.gap"), F.Minutes(plan.wait or 0))
    elseif plan.why == "own" then
        key = T("flask.tell.own")
    end
    if key then SendChatMessage(key, "WHISPER", nil, plan.name) end
end
local function Put(item, kind, forced)
    if CursorHasItem() then
        cur.status = "cursor"
        return false
    end
    local bag, slot, count = FindSlot(item.id)
    if not bag then
        cur.status = "bags"
        return false
    end
    local ts = FreeSlot()
    if not ts then
        cur.status = "full"
        return false
    end
    if count > 1 then SplitContainerItem(bag, slot, 1) else PickupContainerItem(bag, slot) end
    if not CursorHasItem() then
        cur.status = "pick"
        return false
    end
    ClickTradeButton(ts)
    if CursorHasItem() then
        ClearCursor()
        cur.status = "pick"
        return false
    end
    cur.slot, cur.item, cur.kind, cur.forced = ts, item, kind, forced or nil
    cur.stock = Stock(item.id)
    cur.pending, cur.armed = true, nil
    cur.status = "placed"
    return true
end
local function Forget()
    cur.slot, cur.item, cur.kind, cur.forced, cur.stock = nil, nil, nil, nil, nil
    cur.pending, cur.armed = nil, nil
end
local function Withdraw()
    if not cur.slot or CursorHasItem() then return end
    if GetTradePlayerItemInfo(cur.slot) then
        ClickTradeButton(cur.slot)
        if CursorHasItem() then ClearCursor() end
    end
    Forget()
end
local function TryAccept()
    if not cur.open or cur.accepted or cur.done or not Ours() then return end
    if not TargetEmpty() then
        if cur.status ~= "offer" then Say(format(T("flask.trade.offer"), cur.partner)) end
        cur.status = "offer"
        Changed()
        return
    end
    if not F.Get("auto") or blocked then
        cur.status = "press"
        Changed()
        return
    end
    if InCombatLockdown() then return end
    cur.tries = true
    cur.status = "accepting"
    AcceptTrade()
    After(ACCEPT_WAIT, function()
        if not cur.open or cur.accepted or cur.done then return end
        fails = fails + 1
        if fails >= BLOCK_AFTER and not blocked then
            blocked = true
            Say(T("flask.trade.noauto"))
        end
        cur.status = "press"
        Changed()
    end)
    Changed()
end
local function ItemChanged(slot)
    if cur.item and (slot == nil or slot == cur.slot) then
        if Holds() then
            cur.pending = nil
        elseif not cur.pending then
            Forget()
            cur.status = "removed"
            Changed()
        end
    end
    TryAccept()
end
local function Plan(force)
    if not cur.open or not cur.partner then return end
    if InCombatLockdown() then
        cur.status = "combat"
        Changed()
        return
    end
    local plan = F.Decide(cur.partner, time(), Stock)
    cur.plan = plan
    local give = plan.give or (force and plan.item and plan.why ~= "bags")
    if give then
        if cur.item and cur.item ~= plan.item then Withdraw() end
        if plan.warn == "own" then Say(format(T("flask.warn.own"), plan.name, plan.has or 0)) end
        if not cur.item and not Put(plan.item, plan.kind, not plan.give) then
            Say(format(T("flask.put." .. cur.status), F.ItemName(plan.item)))
        end
    else
        cur.status = plan.why
        Say(Reason(plan))
        Whisper(plan)
    end
    Changed()
end
local function Clear()
    cur = { id = cur.id + 1, open = false }
end
local function Partner()
    local name = UnitName("npc")
    if name and name ~= "" then return name end
    local fs = TradeFrameRecipientNameText
    local text = fs and fs.GetText and fs:GetText()
    if text and text ~= "" then return text end
    return nil
end
local function OnShow()
    Clear()
    if not F.IsOn() then return end
    local name = Partner()
    if not name then return end
    cur.open, cur.partner = true, name
    if not (UnitInRaid(name) or UnitInParty(name)) then
        cur.status = "stranger"
        Changed()
        return
    end
    if InCombatLockdown() then
        cur.status = "combat"
        Say(T("flask.trade.combat"))
        Changed()
        return
    end
    F.ScanAura(name)
    cur.status = "wait"
    Changed()
    After(DELAY, function() Plan(false) end)
end
local function Complete(s)
    if s.done or not s.item or not s.partner or not s.armed then return end
    s.done = true
    F.Record(s.partner, s.item, s.kind, time(), s.forced)
    local plan = s.plan
    local n = plan and plan.n + 1 or 1
    Say(format(T("flask.trade.given"), F.ItemName(s.item), s.partner, n, plan and plan.norm or n))
    Changed()
end
local function OnClosed()
    if not cur.open then return end
    cur.open = false
    if cur.item and cur.armed and not cur.done then
        local id, stock, sess = cur.item.id, cur.stock or 0, cur
        After(STOCK_WAIT, function()
            if not sess.done and not sess.cancelled and Stock(id) < stock then Complete(sess) end
        end, true)
    end
    Changed()
end
local function Resume()
    if not cur.open or cur.status ~= "combat" or not cur.partner then return end
    if not (UnitInRaid(cur.partner) or UnitInParty(cur.partner)) then
        cur.status = "stranger"
        Changed()
        return
    end
    F.ScanAura(cur.partner)
    cur.status = cur.item and "placed" or "wait"
    Plan(false)
    TryAccept()
end
local function Info(msg)
    if msg == nil then return end
    if msg == ERR_TRADE_COMPLETE then
        Complete(cur)
    elseif ERR_TRADE_CANCELLED and msg == ERR_TRADE_CANCELLED then
        cur.cancelled = true
    end
end
function Trade.Choose(kind)
    if not cur.open or not cur.partner then return end
    F.SetHand(cur.partner, kind)
    local want = F.Item(kind)
    if cur.item and cur.item ~= want then Withdraw() end
    Plan(false)
end
function Trade.Force()
    if not cur.open or not cur.partner then return end
    Plan(true)
end
function Trade.Accept()
    if not cur.open or InCombatLockdown() then return end
    AcceptTrade()
end
function Trade.Switch(on)
    local ok, why = F.SetOn(on)
    if not ok then
        Say(T("flask.on.group"))
        return false, why
    end
    if on then fails, blocked = 0, false end
    Say(T(on and "flask.on" or "flask.off"))
    return true, nil
end
local function OnUpdate(self)
    local now = GetTime()
    local i = 1
    while i <= #tasks do
        local t = tasks[i]
        if now >= t.at then
            table.remove(tasks, i)
            if t.id == nil or t.id == cur.id then t.fn() end
        else
            i = i + 1
        end
    end
    if #tasks == 0 then self:Hide() end
end
local function OnEvent(_, event, a, b)
    if event == "TRADE_SHOW" then
        OnShow()
    elseif event == "TRADE_CLOSED" then
        OnClosed()
    elseif event == "UI_INFO_MESSAGE" or event == "UI_ERROR_MESSAGE" then
        Info(a)
    elseif not cur.open then
        if (event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED") and F.IsOn() and not F.InGroup() then
            F.SetOn(false)
            Say(T("flask.off.group"))
        end
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        ItemChanged(a)
    elseif event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
        TryAccept()
    elseif event == "TRADE_ACCEPT_UPDATE" then
        cur.accepted = a == 1
        cur.armed = (a == 1 or b == 1) and Holds() or nil
        if cur.accepted and cur.tries then
            fails = 0
            cur.status = "accepted"
        end
        Changed()
    elseif event == "PLAYER_REGEN_DISABLED" then
        cur.status = "combat"
        Changed()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Resume()
    end
end
frame:Hide()
frame:SetScript("OnUpdate", OnUpdate)
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_CLOSED")
frame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
frame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
frame:RegisterEvent("TRADE_MONEY_CHANGED")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("UI_INFO_MESSAGE")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
