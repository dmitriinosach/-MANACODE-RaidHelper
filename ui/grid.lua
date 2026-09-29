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
function Grid.Cells(n, width, minW, gap, flow)
    width = floor(width)
    local out = {}
    if n <= 0 then return out end
    local fit = Grid.Fit(width, minW, gap)
    local rows = ceil(n / fit)
    local per = flow and ceil(n / rows) or fit
    local i = 0
    for r = 1, rows do
        local count = min(per, n - i)
        local across = flow and count or per
        for c = 1, count do
            local x, w = Grid.Span(c, across, width, gap)
            out[i + c] = { x = x, w = w, row = r }
        end
        i = i + count
    end
    return out
end
function Grid.Place(list, left, top, width, minW, gap, flow, under)
    local n = #list
    local cells = Grid.Cells(n, width, minW, gap, flow)
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
