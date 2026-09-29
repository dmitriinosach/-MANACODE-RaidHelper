local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local BAR_H = 14
local TEXT_PAD = 4
local QUEUE_GAP = 1
local MIN_AGE = 0.3
local BAR_MIN = 240
local JobBar = {}
ns.JobBar = JobBar
local bar
local fill
local label, pct, queue, status
local lead
local function Update()
    if not bar then return end
    local _, frac, text, queued, age = ns.Jobs.State()
    if not frac or age < MIN_AGE then
        if bar:IsShown() then
            bar:Hide()
            status:SetAlpha(1)
            if lead then lead:SetAlpha(1) end
        end
        return
    end
    status:SetAlpha(0)
    if lead then lead:SetAlpha(0) end
    local from = (lead or status):GetLeft()
    local to = status:GetRight()
    bar:SetWidth((from and to) and max(BAR_MIN, to - from) or BAR_MIN)
    bar:Show()
    fill:SetWidth(max(1, bar:GetWidth() * frac))
    label:SetText(text)
    pct:SetText(format(ns.T("job.pct"), floor(frac * 100)))
    if queued > 1 then
        queue:SetText(format(ns.T("job.queue"), queued - 1))
        queue:Show()
    else
        queue:Hide()
    end
end
function JobBar.Attach(host, statusText)
    status = statusText
    lead = ns.ReplayLink and ns.ReplayLink.HeadFrame()
    bar = CreateFrame("Frame", nil, host)
    bar:SetHeight(BAR_H)
    bar:SetPoint("RIGHT", statusText, "RIGHT", 0, 0)
    bar:SetWidth(BAR_MIN)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    ns.Kit.Paint(track, "progress.track")
    fill = bar:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", 0, 0)
    fill:SetWidth(1)
    ns.Kit.Paint(fill, "progress.fill")
    pct = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pct:SetPoint("RIGHT", -TEXT_PAD, 0)
    pct:SetJustifyH("RIGHT")
    ns.Kit.Text(pct, "progress.text")
    label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", TEXT_PAD, 0)
    label:SetPoint("RIGHT", pct, "LEFT", -TEXT_PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetHeight(BAR_H)
    ns.Kit.Text(label, "progress.text")
    queue = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    queue:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", TEXT_PAD, -QUEUE_GAP)
    queue:SetJustifyH("LEFT")
    ns.Kit.Text(queue, "progress.queue")
    queue:Hide()
    bar:Hide()
    Update()
end
ns.Jobs.OnChange(Update)
