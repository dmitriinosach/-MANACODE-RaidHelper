local _, ns = ...
local format = string.format
local max = math.max
local floor = math.floor
local ceil = math.ceil
local Kit = ns.Kit
local LO = ns.Lockouts
local MARGIN = 12
local BAR_ROOM = 14
local CAP_H = 22
local NOTE_H = 18
local HEAD_H = 22
local GAP = 10
local COL_GAP = 10
local CARD_PAD = 8
local TILE = 44
local TILE_GAP = 8
local TEXT_X = 8
local LVL_W = 60
local CARD_MIN_W = 260
local CLOSE_GAP = 4
local LOW_ALPHA = 0.55
local TOP_LEVEL = 80
local MINE_SCALE = 0.85
local BASE = { CAP_H = CAP_H, NOTE_H = NOTE_H, HEAD_H = HEAD_H, CARD_PAD = CARD_PAD, TILE = TILE, TILE_GAP = TILE_GAP,
    TEXT_X = TEXT_X, LVL_W = LVL_W }
local LINE_H = 14
local LockView = {}
ns.LockView = LockView
local host
local pane
local content
local mine
local caption
local pools = { card = {}, tile = {}, note = {} }
local used = { card = 0, tile = 0, note = 0 }
local function Dims()
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true))
    local B = BASE
    CAP_H, NOTE_H, HEAD_H, LINE_H = ceil(B.CAP_H * k), ceil(B.NOTE_H * k), ceil(B.HEAD_H * k), ceil(14 * k)
    CARD_PAD, TILE, TILE_GAP = ceil(B.CARD_PAD * k), ceil(B.TILE * k), ceil(B.TILE_GAP * k)
    TEXT_X, LVL_W = ceil(B.TEXT_X * k), ceil(B.LVL_W * k)
end
local function AskRemove(card)
    local c, key = card.char, card.key
    if not c or not key then return end
    Kit.Confirm(format(ns.T("cd.remove.ask"), c.name), ns.T("cd.remove.yes"), function() LO.Remove(key) end)
end
local function Str(parent, font)
    local fs = Kit.Str(parent, font)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    Kit.Text(fs, "text.primary")
    return fs
end
local function MakeCard()
    local card = CreateFrame("Frame", nil, mine)
    Kit.Skin(card, "panel")
    local head = Kit.Row(card, 100)
    head.text:Hide()
    head.tipAnchor = "ANCHOR_CURSOR"
    card.head = head
    card.name = Str(head, "GameFontNormal")
    card.level = Str(head, "GameFontHighlightSmall")
    Kit.Text(card.level, "text.secondary")
    card.state = Str(head, "GameFontHighlightSmall")
    card.state:SetJustifyH("RIGHT")
    Kit.Text(card.state, "text.good")
    card.state:SetText(ns.T("cd.current"))
    local close = Kit.GlyphButton(head, "close")
    close.tipTitle = ns.T("cd.remove")
    close:SetPoint("RIGHT", head, "RIGHT", -CLOSE_GAP, 0)
    close.onClick = function() AskRemove(card) end
    close:Hide()
    card.close = close
    head:HookScript("OnEnter", function() if card.char and not card.current then close:Show() end end)
    head:HookScript("OnLeave", function()
        if not (MouseIsOver and MouseIsOver(close)) then close:Hide() end
    end)
    close:HookScript("OnLeave", function()
        if not (MouseIsOver and MouseIsOver(head)) then close:Hide() end
    end)
    return card
end
local function Take(kind)
    used[kind] = used[kind] + 1
    local pool = pools[kind]
    local f = pool[used[kind]]
    if not f then
        if kind == "card" then
            f = MakeCard()
        elseif kind == "tile" then
            f = Kit.InstTile(mine)
        else
            f = Kit.Row(mine, 100)
            f.text:Hide()
            f.cols = { Str(f, "GameFontHighlightSmall") }
        end
        pool[used[kind]] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
end
local function HideAll()
    for kind, pool in pairs(pools) do
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
end
local function DrawNote(text, y, w)
    local row = Take("note")
    row:SetPoint("TOPLEFT", mine, "TOPLEFT", 0, -y)
    row:SetWidth(w)
    row:SetHeight(NOTE_H)
    row.tipTitle = false
    local fs = row.cols[1]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", TEXT_X, 0)
    fs:SetWidth(max(60, w - TEXT_X - 4))
    fs:SetHeight(LINE_H)
    fs:SetText(text)
    Kit.Text(fs, "text.muted")
    return y + NOTE_H
end
local function CardSize(n, cw)
    local per = max(1, floor((cw - CARD_PAD * 2 + TILE_GAP) / (TILE + TILE_GAP)))
    local lines = ceil(n / per)
    local h = CARD_PAD + HEAD_H + CARD_PAD
    if lines > 0 then h = h + lines * TILE + (lines - 1) * TILE_GAP + CARD_PAD end
    return per, h
end
local function TileTip(v, kills, now)
    local left = LO.Left(v.to - now)
    if v.extended then left = format(ns.T("cd.left.ext"), left) end
    local lines = {
        format(ns.T(v.heroic and "cd.size.h" or "cd.size.n"), v.size),
        format(ns.T("cd.tip.left"), left),
        format(ns.T("cd.tip.reset"), ns.Date(v.to, "dayTime")),
        format(ns.T("cd.tip.id"), v.id),
    }
    if kills and #kills > 0 then
        lines[#lines + 1] = ns.T("cd.tip.kills")
        for i = 1, #kills do lines[#lines + 1] = "  " .. ns.EncName(kills[i]) end
    end
    return LO.Title(v), lines
end
local function DrawCard(r, saves, kills, x, y, cw, h, per, now)
    local c = r.char
    local card = Take("card")
    card.key, card.char, card.current = r.key, c, r.current
    card:SetPoint("TOPLEFT", mine, "TOPLEFT", x, -y)
    card:SetWidth(cw)
    card:SetHeight(h)
    card:SetAlpha((c.level or 0) < TOP_LEVEL and LOW_ALPHA or 1)
    local head = card.head
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
    head:SetWidth(cw - CARD_PAD * 2)
    head:SetHeight(HEAD_H)
    head.tipTitle = c.name
    head.tipLines = { format(ns.T("cd.tip.realm"), c.realm ~= "" and c.realm or "?") }
    local name = card.name
    name:ClearAllPoints()
    name:SetPoint("LEFT", head, "LEFT", 2, 0)
    name:SetHeight(LINE_H)
    name:SetText(c.name)
    Kit.ClassText(name, c.class)
    name:SetWidth(max(40, name:GetStringWidth() + 4))
    card.level:ClearAllPoints()
    card.level:SetPoint("LEFT", name, "RIGHT", 6, 0)
    card.level:SetWidth(LVL_W)
    card.level:SetHeight(LINE_H)
    card.level:SetText(format(ns.T("cd.level"), c.level or 0))
    card.state:ClearAllPoints()
    card.state:SetPoint("RIGHT", head, "RIGHT", -4, 0)
    card.state:SetWidth(max(40, cw - CARD_PAD * 2 - LVL_W - name:GetWidth() - 16))
    card.state:SetHeight(LINE_H)
    if r.current then card.state:Show() else card.state:Hide() end
    card.close:Hide()
    local level = card:GetFrameLevel() + 3
    for i = 1, #saves do
        local v = saves[i]
        local tile = Take("tile")
        Kit.InstTileSet(tile, TILE, LO.Icon(v), v.size, v.heroic)
        local col, line = (i - 1) % per, floor((i - 1) / per)
        tile:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + col * (TILE + TILE_GAP),
            -(CARD_PAD + HEAD_H + CARD_PAD + line * (TILE + TILE_GAP)))
        tile:SetFrameLevel(level)
        tile:SetAlpha(1)
        tile.tipTitle, tile.tipLines = TileTip(v, kills[v.id] and kills[v.id][c.name], now)
    end
end
local function DrawCards(rows, y, w)
    local cols = w >= CARD_MIN_W * 2 + COL_GAP and 2 or 1
    local cw = floor((w - COL_GAP * (cols - 1)) / cols)
    local now = time()
    local kills = LO.Kills(rows)
    for i = 1, #rows, cols do
        local h, list = 0, {}
        for k = 0, cols - 1 do
            local r = rows[i + k]
            if r then
                local saves = LO.Saves(r.char)
                local per, ch = CardSize(#saves, cw)
                list[#list + 1] = { r = r, saves = saves, per = per }
                h = max(h, ch)
            end
        end
        for k = 1, #list do
            local e = list[k]
            DrawCard(e.r, e.saves, kills, (k - 1) * (cw + COL_GAP), y, cw, h, e.per, now)
        end
        y = y + h + COL_GAP
    end
    return y
end
local function Render()
    if not host or not host:IsShown() or not pane then return end
    pane:Laid()
    HideAll()
    local full = max(300, host:GetWidth())
    content:SetWidth(full)
    local w = max(280, full - MARGIN * 2 - BAR_ROOM)
    local inner = w / MINE_SCALE
    mine:SetWidth(inner)
    Dims()
    local y = 0
    caption:ClearAllPoints()
    caption:SetPoint("TOPLEFT", mine, "TOPLEFT", 0, -y)
    caption.rule:SetWidth(max(1, inner - caption:GetStringWidth() - 6))
    y = y + CAP_H
    local rows = LO.Chars(time())
    if #rows == 0 then
        y = DrawNote(ns.T("cd.empty"), y, inner) + GAP
    else
        y = DrawCards(rows, y, inner)
    end
    mine:SetHeight(max(1, y))
    y = ns.GuildLockView.Draw(MARGIN + y * MINE_SCALE + GAP, w)
    content:SetHeight(max(host:GetHeight(), y + MARGIN))
    pane:Rescroll()
end
local function Build(page)
    host = page
    host.sized = true
    pane = Kit.ScrollPage(page, { fill = true, bar = "deck", inset = MARGIN, relayout = Render, prof = "ui.cd",
        onScroll = function() ns.GuildLockView.Scrolled() end })
    content = pane.content
    mine = CreateFrame("Frame", nil, content)
    mine:SetScale(MINE_SCALE)
    mine:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN / MINE_SCALE, -MARGIN / MINE_SCALE)
    caption = Kit.Caption(mine, ns.T("cd.mine"), 200)
    Kit.Bind(caption, "GameFontNormal")
    ns.GuildLockView.Build(content, Render, pane)
end
function LockView.Probe()
    return { pools = pools, used = used, caption = caption, pane = pane }
end
LockView.Render = Render
LO.OnChange(Render)
Kit.OnFont(Render)
if ns.ReadOnly then return end
ns.Shell.Register("cd", {
    label = "shell.tab.cd",
    order = 50,
    build = Build,
    OnShow = function()
        ns.GuildLockView.Opened()
        Render()
        LO.Refresh()
    end,
    OnSize = function() if pane then pane:Relayout() end end,
    OnTheme = Render,
})
