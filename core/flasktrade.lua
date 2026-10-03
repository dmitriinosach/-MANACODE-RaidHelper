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
local INSPECT_WAIT = 2
local SPLIT_TRIES = 10
local Trade = {}
ns.FlaskTrade = Trade
local F = ns.Flasks
local R = ns.FlaskRole
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
local function Offered(id)
    local n = 0
    for i = 1, GIVE_SLOTS do
        local name, _, count = GetTradePlayerItemInfo(i)
        if name and LinkId(GetTradePlayerItemLink(i)) == id then n = n + (count or 1) end
    end
    return n
end
local function FindSlot(id, left)
    local bb, bs, bc, sb, ss, sc
    local locked = 0
    for bag = 0, BAGS do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            if LinkId(GetContainerItemLink(bag, slot)) == id then
                local _, count, isLocked = GetContainerItemInfo(bag, slot)
                count = count or 1
                if isLocked then
                    locked = locked + count
                elseif count == left then
                    return bag, slot, count, false
                elseif count > left then
                    if not bc or count < bc then bb, bs, bc = bag, slot, count end
                elseif not sc or count > sc then
                    sb, ss, sc = bag, slot, count
                end
            end
        end
    end
    local busy = locked > Offered(id)
    if bb then return bb, bs, bc, busy end
    if sb then return sb, ss, sc, busy end
    return nil, nil, 0, busy
end
local function EmptySlot()
    for bag = 0, BAGS do
        local free, family = GetContainerNumFreeSlots(bag)
        if (free or 0) > 0 and (family or 0) == 0 then
            for slot = 1, GetContainerNumSlots(bag) or 0 do
                if not GetContainerItemInfo(bag, slot) then return bag, slot end
            end
        end
    end
    return nil, nil
end
local function FreeSlot()
    for i = 1, GIVE_SLOTS do
        if not (cur.slots and cur.slots[i]) and not GetTradePlayerItemInfo(i) then return i end
    end
    return nil
end
local function Ours()
    local it = cur.item
    if not it or not cur.slots or (cur.put or 0) < 1 or cur.put ~= cur.need then return false end
    local n = 0
    for i = 1, ALL_SLOTS do
        local name, _, c = GetTradePlayerItemInfo(i)
        if name then
            if not cur.slots[i] or LinkId(GetTradePlayerItemLink(i)) ~= it.id then return false end
            n = n + (c or 1)
        end
    end
    return n == cur.put and (GetPlayerTradeMoney() or 0) == 0
end
local function Arm()
    local it = cur.item
    if not it then return nil end
    local n = Offered(it.id)
    if n < 1 then return nil end
    return { item = it, kind = cur.kind, forced = cur.forced, count = n, stock = Stock(it.id) }
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
    elseif plan.why == "own" then
        key = T("flask.tell.own")
    end
    if key then SendChatMessage(key, "WHISPER", nil, plan.name) end
end
local function Drop(ts, bag, slot)
    PickupContainerItem(bag, slot)
    if not CursorHasItem() then return false end
    ClickTradeButton(ts)
    if CursorHasItem() then
        ClearCursor()
        return false
    end
    return true
end
local function Split(bag, slot, n)
    local eb, es = EmptySlot()
    if not eb then
        cur.status = "nosplit"
        return false
    end
    SplitContainerItem(bag, slot, n)
    if not CursorHasItem() then
        cur.status = "pick"
        return false
    end
    PickupContainerItem(eb, es)
    if CursorHasItem() then
        ClearCursor()
        cur.status = "pick"
        return false
    end
    cur.split = true
    return true
end
local function Forget()
    cur.item, cur.kind, cur.forced = nil, nil, nil
    cur.need, cur.put, cur.slots = nil, nil, nil
    cur.split, cur.waits, cur.pending = nil, nil, nil
end
local function Failed()
    if cur.status == "split" then return end
    Say(format(T("flask.put." .. cur.status), F.ItemName(cur.item)))
    if (cur.put or 0) == 0 then Forget() end
end
local Retry
local function Wait()
    cur.waits = (cur.waits or 0) + 1
    if cur.waits > SPLIT_TRIES then
        cur.status = "pick"
        return false
    end
    cur.status = "split"
    After(DELAY, Retry)
    return false
end
local function Fill()
    local id = cur.item.id
    while cur.put < cur.need do
        if CursorHasItem() then
            cur.status = "cursor"
            return false
        end
        local ts = FreeSlot()
        if not ts then
            cur.status = "full"
            return false
        end
        local left = cur.need - cur.put
        local bag, slot, count, busy = FindSlot(id, left)
        if bag and count <= left and (count == left or not cur.split) then
            if not Drop(ts, bag, slot) then
                cur.status = "pick"
                return false
            end
            cur.slots[ts] = count
            cur.put = cur.put + count
            cur.pending, cur.split, cur.waits = true, nil, nil
        elseif bag and count > left and not cur.split then
            if not Split(bag, slot, left) then return false end
            return Wait()
        elseif busy or cur.split then
            return Wait()
        else
            cur.status = "bags"
            return false
        end
    end
    cur.status = "placed"
    return true
end
local function Start(plan, forced)
    local it = plan.item
    local need = plan.left > 0 and plan.left or plan.limit - plan.n
    local have = Stock(it.id)
    cur.item, cur.kind, cur.forced = it, plan.kind, forced or nil
    if have < 1 then
        cur.status = "bags"
        Failed()
        return
    end
    if have < need then
        Say(format(T("flask.put.short"), F.ItemName(it), have, need, plan.name))
        need = have
    end
    cur.need, cur.put, cur.slots = need, 0, {}
    cur.split, cur.waits, cur.many = nil, nil, nil
    if not Fill() then Failed() end
end
Retry = function()
    if not cur.open or not cur.item or not cur.need or cur.put >= cur.need or InCombatLockdown() then return end
    if not Fill() then Failed() end
    Changed()
end
local function Withdraw()
    if not cur.item or CursorHasItem() then return end
    for ts in pairs(cur.slots or {}) do
        if GetTradePlayerItemInfo(ts) then
            ClickTradeButton(ts)
            if CursorHasItem() then ClearCursor() end
        end
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
local function Soon()
    if cur.soon then return end
    cur.soon = true
    After(0, function()
        cur.soon = nil
        TryAccept()
    end)
end
local function ItemChanged()
    if cur.item and (cur.put or 0) > 0 then
        local n = Offered(cur.item.id)
        if n > cur.put then
            Say(format(T("flask.trade.many"), n, F.ItemName(cur.item)))
            Withdraw()
            cur.status, cur.many = "many", n
            Changed()
            return
        end
        if n == cur.put then
            cur.pending = nil
        elseif not cur.pending then
            Forget()
            cur.status = "removed"
            Changed()
            return
        end
    end
    Soon()
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
    local give = plan.give or (force and plan.item and plan.why ~= "bags" and plan.n < plan.limit)
    if give then
        if cur.item and cur.item ~= plan.item then Withdraw() end
        if plan.warn == "own" then Say(format(T("flask.warn.own"), plan.name, plan.has or 0)) end
        if not cur.item then Start(plan, not plan.give) end
    else
        cur.status = plan.why
        Say(Reason(plan))
        Whisper(plan)
    end
    Changed()
end
local function Ripe()
    cur.ripe = true
    if not cur.inspect then Plan(false) end
end
local function Inspected()
    if not cur.inspect then return end
    cur.inspect = nil
    if cur.ripe then Plan(false) end
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
    if R.Want(name) and R.Ask(name) then
        cur.inspect = true
        After(INSPECT_WAIT, Inspected)
    end
    Changed()
    After(DELAY, Ripe)
end
local function Complete(s)
    local a = s.armed
    if s.done or not a or not s.partner then return end
    s.done = true
    F.Record(s.partner, a.item, a.kind, time(), a.forced, a.count)
    local plan = s.plan
    local n = (plan and plan.n or 0) + a.count
    Say(format(T("flask.trade.given"), F.ItemName(a.item), a.count, s.partner, n, plan and plan.norm or n))
    Changed()
end
local function OnClosed()
    if not cur.open then return end
    cur.open = false
    if cur.armed and not cur.done then
        local a, sess = cur.armed, cur
        After(STOCK_WAIT, function()
            if not sess.done and not sess.cancelled and Stock(a.item.id) < a.stock then Complete(sess) end
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
    cur.status = (cur.put or 0) > 0 and "placed" or "wait"
    cur.inspect = nil
    if cur.item and cur.need and cur.put < cur.need then
        cur.waits = nil
        Retry()
    end
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
    cur.inspect = nil
    F.SetHand(cur.partner, kind)
    local want = F.Item(kind)
    if cur.item and cur.item ~= want then Withdraw() end
    Plan(false)
end
function Trade.Force()
    if not cur.open or not cur.partner then return end
    cur.inspect = nil
    Plan(true)
end
function Trade.Accept()
    if not cur.open or InCombatLockdown() then return end
    if cur.item and Offered(cur.item.id) > (cur.put or 0) then return end
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
    elseif event == "INSPECT_TALENT_READY" then
        local who = R.Ready()
        if who and cur.open and who == cur.partner then Inspected() end
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
        ItemChanged()
        if cur.item then cur.armed = Arm() end
    elseif event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
        TryAccept()
    elseif event == "TRADE_ACCEPT_UPDATE" then
        local mine, theirs = a == 1 or a == true, b == 1 or b == true
        cur.accepted = mine
        if mine or theirs then cur.armed = Arm() end
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
frame:SetScript("OnUpdate", ns.Prof.Wrap("bg.flasks", OnUpdate))
frame:SetScript("OnEvent", ns.Prof.Wrap("bg.flasks", OnEvent))
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
frame:RegisterEvent("INSPECT_TALENT_READY")
