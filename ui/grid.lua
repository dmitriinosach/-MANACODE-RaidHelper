local _, ns = ...
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local Grid = {}
ns.Grid = Grid
function Grid.Fit(width, minW, gap)
    local cols = max(1, floor((width + gap) / (minW + gap)))
    return cols, (width - gap * (cols - 1)) / cols
end
function Grid.Span(col, cols, width, gap)
    local cell = (width - gap * (cols - 1)) / cols
    local x = floor((col - 1) * (cell + gap) + 0.5)
    local right = floor(col * (cell + gap) - gap + 0.5)
    return x, right - x
end
function Grid.Cells(n, width, minW, gap, flow, spans)
    width = floor(width)
    local out = {}
    if n <= 0 then return out end
    local fit = Grid.Fit(width, minW, gap)
    local units, total = {}, 0
    for k = 1, n do
        units[k] = min(fit, max(1, spans and spans[k] or 1))
        total = total + units[k]
    end
    local per = flow and ceil(total / ceil(total / fit)) or fit
    local i, r = 0, 0
    while i < n do
        r = r + 1
        local used, count = 0, 0
        while i + count < n and (count == 0 or used + units[i + count + 1] <= per) do
            count = count + 1
            used = used + units[i + count]
        end
        local across = flow and used or per
        local c = 1
        for k = 1, count do
            local u = units[i + k]
            local x = Grid.Span(c, across, width, gap)
            local rx, rw = Grid.Span(c + u - 1, across, width, gap)
            out[i + k] = { x = x, w = rx + rw - x, row = r }
            c = c + u
        end
        i = i + count
    end
    return out
end
function Grid.Place(list, left, top, width, minW, gap, flow, under)
    local n = #list
    local spans
    for k = 1, n do
        local sp = list[k].span
        if type(sp) == "number" and sp > 1 then
            spans = spans or {}
            spans[k] = sp
        end
    end
    local cells = Grid.Cells(n, width, minW, gap, flow, spans)
    local i = 1
    while i <= n do
        local row, tallest, last = cells[i].row, 0, i
        while last <= n and cells[last].row == row do
            local f, cell = list[last], cells[last]
            local h = f:Layout(cell.w) + (under and under[last] or 0)
            if h > tallest then tallest = h end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", left + cell.x, -top)
            f:Show()
            last = last + 1
        end
        for k = i, last - 1 do
            list[k]:SetHeight(tallest - (under and under[k] or 0))
        end
        top = top + tallest + gap
        i = last
    end
    return top
end
