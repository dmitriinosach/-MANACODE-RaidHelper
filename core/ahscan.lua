local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local tsort = table.sort
local format = string.format
local PER_PAGE = 50
local MAX_PAGES = 20
local SHARE = 0.05
local LOTS = 2
local GAP = 0.3
local SETTLE = 0.3
local REREAD = 3
local TIMEOUT = 10
local RETRY = 2
local NAME_BYTES = 63
local Scan = {}
ns.AhScan = Scan
local open = false
local hooked = false
local sending = false
local st = { on = false, paused = false, queue = {}, i = 0, page = 0, pages = 0, lots = {}, rereads = 0, tries = 0,
             nextAt = 0, found = 0, missing = 0 }
local listeners = {}
local driver
local function Store()
    local db = ns.GetDB()
    if type(db.ahPrices) ~= "table" then db.ahPrices = {} end
    return db.ahPrices
end
local function Notify()
    for i = 1, #listeners do listeners[i]() end
end
function Scan.OnChange(fn)
    listeners[#listeners + 1] = fn
end
function Scan.IsOpen()
    return open
end
function Scan.IsOn()
    return st.on
end
function Scan.IsPaused()
    return st.on and st.paused
end
function Scan.Progress()
    local it = st.queue[st.i]
    return st.on and st.i or 0, #st.queue, it and ns.ConsumableName(it.id, it.spell, it.item) or nil, st.page + 1, max(1, st.pages)
end
function Scan.Get(id)
    if not id then return nil end
    local p = Store()[id]
    if type(p) ~= "table" or type(p.p) ~= "number" or p.p <= 0 then return nil end
    return p
end
function Scan.Stats()
    local n, last = 0, nil
    for _, p in pairs(Store()) do
        if type(p) == "table" and type(p.p) == "number" and p.p > 0 then
            n = n + 1
            if type(p.t) == "number" and (not last or p.t > last) then last = p.t end
        end
    end
    return n, last
end
function Scan.Pick(lots)
    if #lots == 0 then return nil, 0 end
    tsort(lots, function(a, b) return a.u < b.u end)
    local units = 0
    for i = 1, #lots do units = units + lots[i].n end
    local need = units * SHARE
    local got = 0
    for i = 1, #lots do
        got = got + lots[i].n
        if got >= need or i >= LOTS or i == #lots then return lots[i].u, units end
    end
    return lots[#lots].u, units
end
function Scan.Query(name)
    if #name <= NAME_BYTES then return name end
    local out = ""
    for word in name:gmatch("%S+") do
        local cand = out == "" and word or out .. " " .. word
        if #cand > NAME_BYTES then break end
        out = cand
    end
    return out ~= "" and out or name
end
local function LinkId(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end
local function Stop()
    st.on, st.paused, st.why = false, false, nil
    st.sentAt, st.readAt = nil, nil
    if driver then driver:Hide() end
end
local function Done()
    local found, missing = st.found, st.missing
    Stop()
    ns.Print(format(ns.T("ah.done"), found, found + missing, missing))
    if ns.RaidSummaryView and ns.RaidSummaryView.Refresh then ns.RaidSummaryView.Refresh() end
    Notify()
end
local function NextItem()
    local it = st.queue[st.i]
    local price, units = Scan.Pick(st.lots)
    if it and price then
        Store()[it.id] = { p = floor(price + 0.5), t = time(), n = units, l = #st.lots }
        st.found = st.found + 1
    elseif it then
        st.missing = st.missing + 1
    end
    st.i, st.page, st.pages, st.lots, st.tries = st.i + 1, 0, 0, {}, 0
    if st.i > #st.queue then
        Done()
        return
    end
    Notify()
end
local function Send()
    local it = st.queue[st.i]
    if not it then return Done() end
    sending = true
    local ok = pcall(QueryAuctionItems, Scan.Query(ns.ItemName(it.id, it.item)), nil, nil, nil, nil, nil, st.page, nil, nil)
    sending = false
    if not ok then
        st.tries = st.tries + 1
        st.nextAt = GetTime() + TIMEOUT / 2
        return
    end
    st.sentAt, st.readAt, st.rereads = GetTime(), nil, 0
end
local function Read()
    local it = st.queue[st.i]
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    local got, partial = {}, false
    for i = 1, batch do
        local name, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
        local link = GetAuctionItemLink("list", i)
        if not name then
            partial = true
        else
            local id = LinkId(link)
            local same = id and id == it.id or (not id and name == ns.ItemName(it.id, it.item))
            if same and (buyout or 0) > 0 and (count or 0) > 0 then
                got[#got + 1] = { u = buyout / count, n = count }
            end
        end
    end
    if partial and st.rereads < REREAD then
        st.rereads = st.rereads + 1
        st.readAt = GetTime() + SETTLE
        return
    end
    for i = 1, #got do st.lots[#st.lots + 1] = got[i] end
    st.sentAt, st.readAt, st.tries = nil, nil, 0
    st.pages = ceil(total / PER_PAGE)
    st.nextAt = GetTime() + GAP
    if st.page + 1 < st.pages and st.page + 1 < MAX_PAGES then
        st.page = st.page + 1
        Notify()
        return
    end
    NextItem()
end
local function Tick(now)
    if not st.on or st.paused then return end
    if st.sentAt then
        if st.readAt and now >= st.readAt then return Read() end
        if not st.readAt and now - st.sentAt > TIMEOUT then
            st.sentAt = nil
            st.tries = st.tries + 1
            if st.tries > RETRY then return NextItem() end
        end
        return
    end
    if now < st.nextAt then return end
    if st.tries > RETRY then return NextItem() end
    if not CanSendAuctionQuery or not CanSendAuctionQuery("list") then return end
    Send()
end
local function OnForeign()
    if sending or not st.on or st.paused then return end
    st.paused, st.why = true, "manual"
    st.sentAt, st.readAt = nil, nil
    if driver then driver:Hide() end
    ns.Print(ns.T("ah.paused"))
    Notify()
end
local function Hook()
    if hooked or type(hooksecurefunc) ~= "function" or type(QueryAuctionItems) ~= "function" then return end
    hooked = true
    hooksecurefunc("QueryAuctionItems", OnForeign)
end
function Scan.Start()
    if not open or st.on then return false end
    local items = ns.RaidCost.Items()
    local queue = {}
    for i = 1, #items do
        if items[i].id then queue[#queue + 1] = items[i] end
    end
    if #queue == 0 then return false end
    Hook()
    st.on, st.paused, st.why = true, false, nil
    st.queue, st.i, st.page, st.pages, st.lots = queue, 1, 0, 0, {}
    st.sentAt, st.readAt, st.rereads, st.tries, st.nextAt = nil, nil, 0, 0, 0
    st.found, st.missing = 0, 0
    if driver then driver:Show() end
    Notify()
    return true
end
function Scan.Resume()
    if not open or not st.on or not st.paused then return false end
    st.paused, st.why = false, nil
    st.page, st.pages, st.lots, st.tries = 0, 0, {}, 0
    st.nextAt = GetTime() + GAP
    if driver then driver:Show() end
    Notify()
    return true
end
function Scan.Cancel(why)
    if not st.on then return end
    local done, total = st.i - 1, #st.queue
    Stop()
    ns.Print(format(ns.T(why == "closed" and "ah.closed" or "ah.cancel"), done, total))
    if ns.RaidSummaryView and ns.RaidSummaryView.Refresh then ns.RaidSummaryView.Refresh() end
    Notify()
end
function Scan.Toggle()
    if not st.on then
        Scan.Start()
    elseif st.paused then
        Scan.Resume()
    else
        Scan.Cancel()
    end
end
driver = CreateFrame("Frame")
driver:Hide()
local acc = 0
driver:SetScript("OnUpdate", ns.Prof.Wrap("bg.ahscan", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.1 then return end
    acc = 0
    Tick(GetTime())
end))
local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
ev:SetScript("OnEvent", ns.Prof.Wrap("bg.ahscan", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        open = true
        Hook()
        Notify()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if not open then return end
        open = false
        if st.on then Scan.Cancel("closed") else Notify() end
    elseif st.on and not st.paused and st.sentAt and not st.readAt then
        st.readAt = GetTime() + SETTLE
    end
end))
