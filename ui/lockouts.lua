local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local ceil = math.ceil
local concat = table.concat
local Kit = ns.Kit
local LO = ns.Lockouts
local MARGIN = 12
local BAR_ROOM = 14
local CAP_H = 22
local HINT_H = 16
local SUM_H = 20
local CHAR_H = 22
local SAVE_H = 20
local NOTE_H = 18
local GAP = 10
local CHAR_GAP = 6
local ICON = 16
local INDENT = 22
local TEXT_X = 8
local SIZE_W = 80
local KILLS_W = 90
local LEFT_W = 130
local LVL_W = 60
local STATE_W = 200
local SUM_LABEL_W = 70
local SUM_COL_W = 110
local CLOSE_GAP = 4
local BASE = { CAP_H = CAP_H, HINT_H = HINT_H, SUM_H = SUM_H, CHAR_H = CHAR_H, SAVE_H = SAVE_H, NOTE_H = NOTE_H,
    ICON = ICON, INDENT = INDENT, TEXT_X = TEXT_X, SIZE_W = SIZE_W, KILLS_W = KILLS_W, LEFT_W = LEFT_W, LVL_W = LVL_W,
    STATE_W = STATE_W, SUM_LABEL_W = SUM_LABEL_W, SUM_COL_W = SUM_COL_W }
local LINE_H = 14
local ICC = "IcecrownCitadel"
local SIZES = { 10, 25 }
local LockView = {}
ns.LockView = LockView
local host
local pane
local content
local caption, hint
local pools = { sum = {}, char = {}, save = {}, note = {} }
local used = { sum = 0, char = 0, save = 0, note = 0 }
local function Dims(w)
    local k = max(1, Kit.FontScale("GameFontHighlightSmall", true))
    local B = BASE
    local kc = max(1, min(k, w / (B.INDENT + B.ICON + 6 + 150 + B.SIZE_W + B.KILLS_W + B.LEFT_W + 8)))
    CAP_H, HINT_H, SUM_H, CHAR_H = ceil(B.CAP_H * k), ceil(B.HINT_H * k), ceil(B.SUM_H * k), ceil(B.CHAR_H * k)
    SAVE_H, NOTE_H, LINE_H = ceil(B.SAVE_H * k), ceil(B.NOTE_H * k), ceil(14 * k)
    ICON, INDENT, TEXT_X = ceil(B.ICON * k), ceil(B.INDENT * kc), ceil(B.TEXT_X * kc)
    SIZE_W, KILLS_W, LEFT_W, LVL_W = ceil(B.SIZE_W * kc), ceil(B.KILLS_W * kc), ceil(B.LEFT_W * kc), ceil(B.LVL_W * kc)
    STATE_W, SUM_LABEL_W, SUM_COL_W = ceil(B.STATE_W * kc), ceil(B.SUM_LABEL_W * kc), ceil(B.SUM_COL_W * kc)
end
local function Cols(row, n, font)
    row.cols = {}
    for i = 1, n do
        local fs = Kit.Str(row, font or "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        Kit.Text(fs, "text.primary")
        row.cols[i] = fs
    end
    row.text:Hide()
end
local function AskRemove(key, row)
    local c = row.char
    if not c then return end
    Kit.Confirm(format(ns.T("cd.remove.ask"), c.name), ns.T("cd.remove.yes"), function() LO.Remove(key) end)
end
local function Make(kind)
    local row = Kit.Row(content, 100)
    if kind == "sum" then
        Cols(row, 4)
    elseif kind == "char" then
        Cols(row, 3, "GameFontNormal")
        local close = Kit.GlyphButton(row, "close")
        close.tipTitle = ns.T("cd.remove")
        close:SetPoint("RIGHT", row, "RIGHT", -CLOSE_GAP, 0)
        close.onClick = function() if row.key then AskRemove(row.key, row) end end
        row.close = close
    elseif kind == "save" then
        Cols(row, 4)
        row.icon = row:CreateTexture(nil, "ARTWORK")
    else
        Cols(row, 1)
    end
    return row
end
local function Take(kind, y, w)
    used[kind] = used[kind] + 1
    local pool = pools[kind]
    local row = pool[used[kind]]
    if not row then
        row = Make(kind)
        pool[used[kind]] = row
    end
    row:SetHeight((kind == "sum" and SUM_H) or (kind == "char" and CHAR_H) or (kind == "save" and SAVE_H) or NOTE_H)
    for i = 1, #row.cols do row.cols[i]:SetHeight(LINE_H) end
    if row.icon then
        row.icon:SetWidth(ICON)
        row.icon:SetHeight(ICON)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row, "LEFT", INDENT, 0)
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    row:SetWidth(w)
    row.tipTitle, row.tip, row.tipLines = false, nil, nil
    row:Show()
    return row
end
local function HideAll()
    for kind, pool in pairs(pools) do
        for i = 1, #pool do pool[i]:Hide() end
        used[kind] = 0
    end
end
local function Put(fs, x, width, text, token, right)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", fs:GetParent(), "LEFT", x, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(right and "RIGHT" or "LEFT")
    fs:SetText(text)
    if token then Kit.Text(fs, token) end
    fs:Show()
end
local function Names(list)
    if #list == 0 then return ns.T("cd.sum.nobody") end
    return concat(list, ", ")
end
local function DrawSummary(y, w)
    local sum = LO.Summary(ICC, SIZES)
    for i = 1, #SIZES do
        local size = SIZES[i]
        local cell = sum[size]
        local row = Take("sum", y, w)
        local c = row.cols
        Put(c[1], TEXT_X, SUM_LABEL_W, format(ns.T("cd.sum"), size), "text.title")
        Put(c[2], TEXT_X + SUM_LABEL_W, SUM_COL_W, format(ns.T("cd.sum.free"), #cell.free),
            #cell.free > 0 and "text.good" or "text.muted")
        Put(c[3], TEXT_X + SUM_LABEL_W + SUM_COL_W, SUM_COL_W, format(ns.T("cd.sum.n"), #cell.normal), "text.secondary")
        Put(c[4], TEXT_X + SUM_LABEL_W + SUM_COL_W * 2, SUM_COL_W, format(ns.T("cd.sum.h"), #cell.heroic),
            "text.secondary")
        row.tipTitle = format(ns.T("cd.sum.tipTitle"), ns.T("zone." .. ICC), size)
        row.tipLines = {
            format(ns.T("cd.sum.tip.free"), Names(cell.free)),
            format(ns.T("cd.sum.tip.n"), Names(cell.normal)),
            format(ns.T("cd.sum.tip.h"), Names(cell.heroic)),
        }
        y = y + SUM_H
    end
    return y
end
local function DrawChar(r, y, w)
    local c = r.char
    local row = Take("char", y, w)
    row.key, row.char = r.key, c
    local cols = row.cols
    Put(cols[1], TEXT_X, max(40, w - TEXT_X - LVL_W - STATE_W - 30), c.name)
    Kit.ClassText(cols[1], c.class)
    cols[1]:SetWidth(max(40, cols[1]:GetStringWidth() + 4))
    cols[2]:ClearAllPoints()
    cols[2]:SetPoint("LEFT", cols[1], "RIGHT", 6, 0)
    cols[2]:SetWidth(LVL_W)
    cols[2]:SetText(format(ns.T("cd.level"), c.level or 0))
    Kit.Text(cols[2], "text.secondary")
    local state, token = "", "text.muted"
    if r.current then
        state, token = ns.T("cd.current"), "text.good"
    elseif r.stale then
        state, token = format(ns.T("cd.stale"), ns.Date(c.at)), "text.warn"
    end
    Put(cols[3], w - STATE_W - 30, STATE_W, state, token, true)
    if r.current then row.close:Hide() else row.close:Show() end
    row.tipTitle = c.name
    row.tipLines = {
        format(ns.T("cd.tip.realm"), c.realm ~= "" and c.realm or "?"),
        format(ns.T("cd.tip.at"), ns.Date(c.at, "dayTime")),
    }
    return y + CHAR_H
end
local function DrawSave(v, kills, now, y, w)
    local row = Take("save", y, w)
    row.icon:SetTexture(LO.Icon(v))
    local cols = row.cols
    local x = INDENT + ICON + 6
    local right = w - LEFT_W - 8
    local title = LO.Title(v)
    Put(cols[1], x, max(60, right - KILLS_W - SIZE_W - x), title, "text.primary")
    Put(cols[2], right - KILLS_W - SIZE_W, SIZE_W,
        format(ns.T(v.heroic and "cd.size.h" or "cd.size.n"), v.size), v.heroic and "text.warn" or "text.secondary")
    local n = kills and #kills or 0
    Put(cols[3], right - KILLS_W, KILLS_W, n > 0 and format("%d %s", n, ns.Plural(n, ns.T("cd.kills.n"))) or "",
        "text.secondary")
    local left = LO.Left(v.to - now)
    if v.extended then left = format(ns.T("cd.left.ext"), left) end
    Put(cols[4], right, LEFT_W, left, "text.primary", true)
    row.tipTitle = title
    local lines = {
        format(ns.T("cd.tip.id"), v.id),
        format(ns.T("cd.tip.reset"), ns.Date(v.to, "dayTime")),
    }
    if v.extended then lines[#lines + 1] = ns.T("cd.tip.ext") end
    if n > 0 then
        lines[#lines + 1] = ns.T("cd.tip.kills")
        for i = 1, n do lines[#lines + 1] = "  " .. ns.EncName(kills[i]) end
    end
    row.tipLines = lines
    return y + SAVE_H
end
local function DrawNote(text, y, w, x)
    local row = Take("note", y, w)
    Put(row.cols[1], x or TEXT_X, max(60, w - (x or TEXT_X) - 4), text, "text.muted")
    return y + NOTE_H
end
local function Render()
    if not host or not host:IsShown() or not pane then return end
    pane:Laid()
    HideAll()
    local full = max(300, host:GetWidth())
    content:SetWidth(full)
    local w = max(280, full - MARGIN * 2 - BAR_ROOM)
    Dims(w)
    hint:SetHeight(LINE_H)
    local y = MARGIN
    caption:ClearAllPoints()
    caption:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -y)
    caption.rule:SetWidth(max(1, w - caption:GetStringWidth() - 6))
    y = y + CAP_H
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN + TEXT_X, -y)
    hint:SetWidth(w - TEXT_X)
    y = y + HINT_H + 4
    y = DrawSummary(y, w) + GAP
    local now = time()
    local rows = LO.Chars(now)
    if #rows == 0 then
        y = DrawNote(ns.T("cd.empty"), y, w)
    end
    local kills = LO.Kills(rows)
    for i = 1, #rows do
        local r = rows[i]
        y = DrawChar(r, y, w)
        local saves = LO.Saves(r.char)
        if #saves == 0 then y = DrawNote(ns.T("cd.none"), y, w, INDENT) end
        for k = 1, #saves do
            local v = saves[k]
            y = DrawSave(v, kills[v.id] and kills[v.id][r.char.name], now, y, w)
        end
        y = y + CHAR_GAP
    end
    y = ns.GuildLockView.Draw(y + GAP, w)
    content:SetHeight(max(host:GetHeight(), y + MARGIN))
    pane:Rescroll()
end
local function Build(page)
    host = page
    host.sized = true
    pane = Kit.ScrollPage(page, { fill = true, bar = "deck", inset = MARGIN, relayout = Render, prof = "ui.cd" })
    content = pane.content
    caption = Kit.Caption(content, ns.T("cd.mine"), 200)
    Kit.Bind(caption, "GameFontNormal")
    hint = Kit.Str(content, "GameFontHighlightSmall")
    hint:SetJustifyH("LEFT")
    hint:SetText(ns.T("cd.hint"))
    Kit.Text(hint, "text.muted")
    ns.GuildLockView.Build(content, Render)
end
function LockView.Probe()
    return { pools = pools, used = used, caption = caption, hint = hint, pane = pane }
end
LockView.Render = Render
LO.OnChange(Render)
Kit.OnFont(Render)
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
