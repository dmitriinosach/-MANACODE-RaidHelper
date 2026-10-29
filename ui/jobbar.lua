local _, ns = ...
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local THIN = 3
local TEXT_PAD = 4
local QUEUE_GAP = 10
local MIN_AGE = 0.3
local BAR_MIN = 180
local EASE = 6
local SWEEP = 1.4
local GLINT = 48
local GLINT_MIN = 24
local GLINT_SHARE = 0.25
local GLINT_A = 0.75
local CLOSE = 0.35
local JobBar = {}
ns.JobBar = JobBar
local bar
local fill, glint
local label, pct, queue, status
local lead
local fades = {}
local want, shown, phase = 0, 0, 0
local vague = false
local closing
local lastPct
local function Fade(a)
    for i = 1, #fades do fades[i]:SetAlpha(a) end
end
local function PaintGlint()
    if not glint then return end
    local r, g, b = ns.Kit.RGB(vague and "progress.fill" or "progress.text")
    glint:SetTexture(r, g, b, 1)
    glint:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, vague and 1 or GLINT_A)
end
local function Close()
    closing = nil
    bar:Hide()
    status:SetAlpha(1)
    Fade(1)
end
local function Tick(self, elapsed)
    local width = self:GetWidth() or 0
    if width <= 0 then return end
    if closing then
        closing = closing + elapsed
        want = 1
        if closing >= CLOSE then return Close() end
    end
    phase = (phase + elapsed / SWEEP) % 1
    local span, seg
    if vague then
        fill:Hide()
        span, seg = width, max(GLINT_MIN, width * GLINT_SHARE)
    else
        shown = shown + (want - shown) * min(1, elapsed * EASE)
        span, seg = max(1, width * min(1, shown)), GLINT
        fill:SetWidth(span)
        fill:Show()
        local p = floor(shown * 100 + 0.5)
        if p ~= lastPct then
            lastPct = p
            pct:SetText(format(ns.T("job.pct"), p))
        end
    end
    local head = phase * (span + seg)
    local left, right = max(0, head - seg), min(span, head)
    if closing or right - left < 1 then
        glint:Hide()
        return
    end
    glint:ClearAllPoints()
    glint:SetPoint("TOPLEFT", self, "BOTTOMLEFT", left, THIN)
    glint:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", left, 0)
    glint:SetWidth(right - left)
    glint:Show()
end
local function Update()
    if not bar then return end
    local _, frac, text, queued, age, unknown = ns.Jobs.State()
    if not frac or age < MIN_AGE then
        if bar:IsShown() and not closing then closing = 0 end
        return
    end
    closing = nil
    status:SetAlpha(0)
    local h = ns.Kit.Space.tool + ns.Kit.Grow().g
    bar:SetHeight(h)
    local own, to = status:GetLeft(), status:GetRight()
    local room = own and to and to - own or 0
    local from = own
    if room >= BAR_MIN then
        Fade(1)
    else
        from = (lead or status):GetLeft()
        Fade(0)
    end
    bar:SetWidth((from and to) and max(BAR_MIN, to - from) or BAR_MIN)
    if not bar:IsShown() or frac < want then
        shown, lastPct = frac, nil
    end
    want = frac
    if (unknown and true or false) ~= vague then
        vague = unknown and true or false
        PaintGlint()
        if vague then pct:SetText("") end
        lastPct = nil
    end
    bar:Show()
    label:SetText(text)
    label:ClearAllPoints()
    label:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, THIN + 2)
    if queued > 1 then
        queue:SetText(format(ns.T("job.queue"), queued - 1))
        queue:Show()
        label:SetPoint("RIGHT", queue, "LEFT", -QUEUE_GAP, 0)
    else
        queue:Hide()
        label:SetPoint("RIGHT", pct, "LEFT", -TEXT_PAD, 0)
    end
end
function JobBar.Attach(host, statusText)
    status = statusText
    lead = ns.ReplayLink and ns.ReplayLink.HeadFrame()
    fades = {}
    local heads = { ReplayLink = true, ThreatView = true }
    for key in pairs(heads) do
        local f = ns[key] and ns[key].HeadFrame and ns[key].HeadFrame()
        if f then fades[#fades + 1] = f end
    end
    local save = ns.ReplayLink and ns.ReplayLink.SaveFrame and ns.ReplayLink.SaveFrame()
    if save then fades[#fades + 1] = save end
    bar = CreateFrame("Frame", nil, host)
    bar:SetHeight(ns.Kit.Space.tool)
    bar:SetPoint("RIGHT", statusText, "RIGHT", 0, 0)
    bar:SetWidth(BAR_MIN)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("BOTTOMLEFT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track:SetHeight(THIN)
    ns.Kit.Paint(track, "progress.track")
    fill = bar:CreateTexture(nil, "BORDER")
    fill:SetPoint("BOTTOMLEFT", 0, 0)
    fill:SetHeight(THIN)
    fill:SetWidth(1)
    ns.Kit.Paint(fill, "progress.fill")
    glint = bar:CreateTexture(nil, "ARTWORK")
    glint:SetHeight(THIN)
    glint:Hide()
    PaintGlint()
    pct = ns.Kit.Str(bar, "GameFontHighlightSmall")
    pct:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, THIN + 2)
    pct:SetJustifyH("RIGHT")
    ns.Kit.Text(pct, "progress.text")
    label = ns.Kit.Str(bar, "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, THIN + 2)
    label:SetPoint("RIGHT", pct, "LEFT", -TEXT_PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    ns.Kit.Text(label, "progress.text")
    queue = ns.Kit.Str(bar, "GameFontDisableSmall")
    queue:SetPoint("BOTTOMRIGHT", pct, "BOTTOMLEFT", -QUEUE_GAP, 0)
    queue:SetJustifyH("RIGHT")
    queue:SetWordWrap(false)
    ns.Kit.Text(queue, "progress.queue")
    queue:Hide()
    bar:SetScript("OnUpdate", Tick)
    bar:Hide()
    Update()
end
ns.Jobs.OnChange(Update)
ns.Kit.OnTheme(PaintGlint)
