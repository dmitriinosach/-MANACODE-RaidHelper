local _, ns = ...
local STEPS = {
    { key = "zoom", target = "view" },
    { key = "turn", target = "view" },
    { key = "tilt", target = "view" },
    { key = "seek", target = "scrub" },
    { key = "pick", target = "fig" },
    { key = "menu", target = "gear" },
}
local ID = "iso"
local TURN_MIN = 0.35
local TILT_MIN = 0.08
local W = 380
local LIFT = 34
local Tour = {}
ns.ReplayTour = Tour
local Kit = ns.Kit
local KT = Kit.Tour
local st = { up = false, down = false }
local function Target(def)
    local ui = st.ui
    if def.target == "view" then return ui.view end
    if def.target == "scrub" then return ui.scrub end
    if def.target == "gear" then return ui.gearBtn end
    return st.api.Figure()
end
local function Steps()
    local list = {}
    for i = 1, #STEPS do
        local def = STEPS[i]
        list[i] = {
            key = def.key, text = ns.T("iso.tour." .. i), wait = true, inset = def.target == "view",
            target = function() return Target(def) end,
            action = function() st.up, st.down = false, false end,
        }
    end
    return list
end
local function Finish(how)
    if how ~= "hide" and st.api then st.api.Saved().tour = true end
end
function Tour.Bind(ui, api)
    st.ui, st.api = ui, api
end
function Tour.Start()
    local ui = st.ui
    if not ui then return end
    KT.Start(ui.frame, Steps(), {
        id = ID, title = ns.T("iso.tour"), dim = false, width = W, above = ui.top, back = false, onFinish = Finish,
        place = function(card) card:SetPoint("BOTTOM", ui.view, "BOTTOM", 0, LIFT) end,
    })
end
function Tour.Auto()
    if KT.Active(ID) or not st.api then return end
    if st.api.Saved().tour ~= true then
        Tour.Start()
    elseif ns.NewsView then
        ns.NewsView.Iso(st.ui)
    end
end
function Tour.Stop()
    if KT.Active(ID) or KT.Active("news.iso") then KT.Close("hide") end
end
function Tour.Note(kind, v)
    if not KT.Active(ID) then return end
    local p = KT.Probe()
    if p.done or p.key ~= kind then return end
    if kind == "zoom" then
        if (v or 0) > 0 then st.up = true else st.down = true end
        if not (st.up and st.down) then return end
    elseif kind == "turn" and (v or 0) < TURN_MIN then
        return
    elseif kind == "tilt" and (v or 0) < TILT_MIN then
        return
    end
    KT.Done()
end
function Tour.Probe()
    local p = KT.Probe()
    local on = KT.Active(ID)
    return { step = on and p.index or 0, steps = #STEPS, shown = on, done = on and p.done, key = on and p.key or nil,
             target = on and p.target or nil, glow = on and p.ring ~= nil and p.ring:IsShown(), skip = p.skip,
             next = p.next, box = p.card, w = p.w }
end
