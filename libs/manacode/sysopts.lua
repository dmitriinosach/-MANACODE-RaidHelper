local _, ns = ...
local format = string.format
local max = math.max
local min = math.min
local upper = string.upper
local PAD = 16
local CHECK = 26
local CHECK_X = PAD - 3
local COL = CHECK_X + CHECK + 2
local ROW = 26
local BTN_W = 200
local BTN_MIN = 80
local BTN_H = 22
local HEAD_GAP = 10
local HEAD_H = 18
local LABEL_H = 16
local GAP = 6
local KEY_W = 160
local MODS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local SysOpts = {}
ns.SysOpts = SysOpts
local function Text(v, T)
    if type(v) == "function" then v = v() end
    if T and type(v) == "string" then return T(v) end
    return v
end
local function Enabled(it)
    return not it.enabled or it.enabled() and true or false
end
local function TipEnter(self)
    local it, T = self.item, self.T
    if not it or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Text(it.label, T) or "")
    local tip = Text(it.tip, T)
    if tip and tip ~= "" then GameTooltip:AddLine(tip, nil, nil, nil, true) end
    GameTooltip:Show()
end
local function TipLeave()
    if GameTooltip then GameTooltip:Hide() end
end
local function Current(it)
    local list, cur = it.options and it.options() or {}, it.get and it.get()
    for i = 1, #list do
        if list[i].key == cur then return i, list end
    end
    return 0, list
end
local function Version(def)
    local v = Text(def.version)
    if not v or v == "" then return "" end
    if def.verKey then return format(Text(def.verKey, def.T), v) end
    return v
end
function SysOpts.Panel(def)
    local T = def.T
    local panel = CreateFrame("Frame", def.frame, UIParent)
    panel:Hide()
    panel.name = def.name
    panel.parent = def.parent
    local rows = {}
    panel.rows = rows
    local built = false
    local before
    local function Fit()
        local w = panel:GetWidth() or 0
        if not built or w <= 0 then return end
        local room = max(BTN_MIN, w - COL - PAD)
        for i = 1, #rows do
            local r = rows[i]
            if r.button then r.button:SetWidth(min(r.want, room)) end
            if r.label and r.item.kind == "cycle" then r.label:SetWidth(room) end
        end
    end
    local function Refresh()
        if not built then return end
        panel.sub:SetText(Version(def))
        for i = 1, #rows do
            local r, it = rows[i], rows[i].item
            local on = Enabled(it)
            if r.check then
                r.check:SetChecked(it.get and it.get() and true or false)
                if on then r.check:Enable() else r.check:Disable() end
                r.label:SetFontObject(on and GameFontHighlight or GameFontDisable)
            elseif r.button then
                if it.kind == "cycle" then
                    local at, list = Current(it)
                    r.button:SetText(Text(list[at] and list[at].label, T) or "—")
                    r.label:SetFontObject(on and GameFontHighlight or GameFontDisable)
                else
                    r.button:SetText(Text(it.label, T) or "")
                    local fs = r.button:GetFontString()
                    r.want = max(BTN_W, (fs and fs:GetStringWidth() or 0) + 40)
                end
                if on then r.button:Enable() else r.button:Disable() end
            end
        end
        Fit()
    end
    panel.Refresh = Refresh
    local function Remember()
        if before then return end
        before = {}
        for i = 1, #rows do
            local it = rows[i].item
            if it.get and it.set then before[i] = it.get() end
        end
    end
    local function Put(it, v)
        if it.get and it.get() == v then return end
        it.set(v)
    end
    local function Cycle(it, step)
        local at, list = Current(it)
        if #list == 0 then return end
        local nxt = (at - 1 + step) % #list + 1
        if at == 0 then nxt = 1 end
        Put(it, list[nxt].key)
    end
    local function Tip(r, w)
        w.item, w.T = r.item, T
        w:SetScript("OnEnter", TipEnter)
        w:SetScript("OnLeave", TipLeave)
    end
    local function Build()
        built = true
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
        title:SetText(def.name)
        local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        sub:SetJustifyH("LEFT")
        panel.title, panel.sub = title, sub
        local list = Text(def.items) or {}
        local y = -PAD - 34
        for i = 1, #list do
            local it = list[i]
            local r = { item = it }
            rows[i] = r
            if it.kind == "head" then
                y = y - HEAD_GAP
                local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
                fs:SetText(Text(it.label, T) or "")
                r.head = fs
                y = y - HEAD_H
            elseif it.kind == "check" then
                local c = CreateFrame("CheckButton", def.frame .. "Check" .. i, panel, "UICheckButtonTemplate")
                c:SetWidth(CHECK)
                c:SetHeight(CHECK)
                c:SetPoint("TOPLEFT", panel, "TOPLEFT", CHECK_X, y)
                c:SetScript("OnClick", function(self)
                    it.set(self:GetChecked() and true or false)
                    Refresh()
                end)
                Tip(r, c)
                local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                fs:SetPoint("LEFT", panel, "TOPLEFT", COL, y - CHECK / 2)
                fs:SetJustifyH("LEFT")
                fs:SetText(Text(it.label, T) or "")
                r.check, r.label = c, fs
                y = y - ROW
            elseif it.kind == "cycle" or it.kind == "button" then
                y = y - 2
                if it.kind == "cycle" then
                    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", COL, y)
                    fs:SetJustifyH("LEFT")
                    fs:SetText(Text(it.label, T) or "")
                    r.label = fs
                    y = y - LABEL_H - 2
                end
                local b = CreateFrame("Button", def.frame .. "Button" .. i, panel, "UIPanelButtonTemplate")
                b:SetHeight(BTN_H)
                b:SetPoint("TOPLEFT", panel, "TOPLEFT", COL, y)
                y = y - BTN_H - GAP
                r.want = BTN_W
                if it.kind == "cycle" then
                    b:SetWidth(BTN_W)
                    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    b:SetScript("OnClick", function(_, button)
                        Cycle(it, button == "RightButton" and -1 or 1)
                        Refresh()
                    end)
                else
                    b:SetScript("OnClick", function()
                        if it.close then
                            before = nil
                            if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
                        end
                        if it.run then it.run() end
                        Refresh()
                    end)
                end
                Tip(r, b)
                r.button = b
            end
        end
    end
    panel.refresh = function()
        if not built then Build() end
        Remember()
        Refresh()
    end
    panel.okay = function() before = nil end
    panel.cancel = function()
        if not before then return end
        local was = before
        before = nil
        for i = 1, #rows do
            local it = rows[i].item
            if was[i] ~= nil then Put(it, was[i]) end
        end
        Refresh()
    end
    panel.default = function()
        for i = 1, #rows do
            local it = rows[i].item
            if it.default ~= nil and it.set then Put(it, it.default) end
        end
        Refresh()
    end
    panel:SetScript("OnShow", panel.refresh)
    panel:SetScript("OnSizeChanged", Fit)
    if InterfaceOptionsFrame and InterfaceOptionsFrame.HookScript then
        InterfaceOptionsFrame:HookScript("OnHide", function() before = nil end)
    end
    if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
    return panel
end
function SysOpts.Keys(keys, title, T)
    local run = {}
    _G["BINDING_HEADER_" .. keys.header] = title
    for i = 1, #keys.list do
        local k = keys.list[i]
        run[k.id] = k.run
        _G["BINDING_NAME_" .. keys.header .. "_" .. upper(k.id)] = Text(k.label, T)
    end
    _G[keys.global] = function(id)
        local fn = run[id]
        if fn then fn() end
    end
    return run
end
function SysOpts.Register(def)
    local run = def.keys and SysOpts.Keys(def.keys, def.name, def.T) or nil
    local panel = def.items and SysOpts.Panel(def) or nil
    return panel, run
end
function SysOpts.KeyField(button, opts)
    local field = { waiting = false }
    local cmd = opts.command
    function field:Keys()
        if not GetBindingKey then return {} end
        local out = { GetBindingKey(cmd) }
        for i = #out, 1, -1 do
            if not out[i] or out[i] == "" then table.remove(out, i) end
        end
        return out
    end
    local function Paint()
        local text
        if field.waiting then
            text = opts.wait and Text(opts.wait, opts.T) or "..."
        else
            local keys = field:Keys()
            for i = 1, #keys do
                keys[i] = GetBindingText and GetBindingText(keys[i], "KEY_") or keys[i]
            end
            text = keys[1] and table.concat(keys, ", ")
                or (opts.none and Text(opts.none, opts.T)) or NOT_BOUND or "-"
        end
        if opts.paint then opts.paint(button, text, field.waiting) else button:SetText(text) end
    end
    local function Stop()
        field.waiting = false
        button:EnableKeyboard(false)
    end
    local function Save()
        if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
        if opts.onChange then opts.onChange() end
    end
    local function Unbind()
        local keys = field:Keys()
        for i = 1, #keys do SetBinding(keys[i]) end
        return #keys > 0
    end
    function field:Refresh()
        Paint()
    end
    function field:Cancel()
        if not field.waiting then return end
        Stop()
        Paint()
    end
    function field:Click(mouse)
        if mouse == "RightButton" then
            Stop()
            if not (InCombatLockdown and InCombatLockdown()) and Unbind() then Save() end
            Paint()
            return
        end
        if field.waiting or (InCombatLockdown and InCombatLockdown()) then
            field:Cancel()
            return
        end
        field.waiting = true
        button:EnableKeyboard(true)
        Paint()
    end
    button:SetScript("OnKeyDown", function(_, key)
        if not field.waiting or MODS[key] then return end
        Stop()
        if key ~= "ESCAPE" and not (InCombatLockdown and InCombatLockdown()) then
            if IsShiftKeyDown and IsShiftKeyDown() then key = "SHIFT-" .. key end
            if IsControlKeyDown and IsControlKeyDown() then key = "CTRL-" .. key end
            if IsAltKeyDown and IsAltKeyDown() then key = "ALT-" .. key end
            Unbind()
            SetBinding(key, cmd)
            Save()
        end
        Paint()
    end)
    button:HookScript("OnHide", function() field:Cancel() end)
    if opts.own then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouse) field:Click(mouse) end)
    end
    Paint()
    return field
end
function SysOpts.Open(panel)
    if not InterfaceOptionsFrame_OpenToCategory then return end
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
