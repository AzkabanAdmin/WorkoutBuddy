-- ui/window.lua
-- The settings window: header with search, page navigation on the left and
-- a scrolling page on the right. Pages are lists of rows ("specs"); the
-- renderer builds each row once, then only repositions and refreshes it.
--
-- Spec fields: type (section, toggle, slider, select, input, button,
-- buttons, text, custom), label, desc, keywords, hidden(), disabled(),
-- get(), set(v), plus type-specific fields. Labels and descriptions may be
-- functions. Every spec with a label is found by the search.

local _, WorkoutBuddy = ...
local UI = WorkoutBuddy.UI

local Settings = { pages = {}, order = {} }
WorkoutBuddy.SettingsUI = Settings

local WIN_W, WIN_H = 900, 620
local NAV_W = 190
local HEADER_H = 52
local PAD = 16
local CONTROL_GAP = 16

local function Value(v, ...)
    if type(v) == "function" then return v(...) end
    return v
end

------------------------------------------------------------------------
-- Page registry
------------------------------------------------------------------------
--- page = { key, label, icon, order, specs = function() return {...} end,
--           count = function() return "4/12" end, onShow = function() end }
function Settings:AddPage(page)
    self.pages[page.key] = page
    table.insert(self.order, page)
    table.sort(self.order, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

function Settings:Specs(page)
    if not page.specList then page.specList = Value(page.specs) or {} end
    return page.specList
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
local CONTROL_W = { toggle = 40, slider = 290, select = 230, input = 130, button = 150 }

local function BuildControl(row, spec)
    local t = spec.type
    if t == "toggle" then
        row.control = UI.Switch(row, function(v) spec.set(v); Settings:Changed() end)
    elseif t == "slider" then
        row.control = UI.Slider(row, spec.width or CONTROL_W.slider, spec.min, spec.max, spec.step,
            function(v) spec.set(v); Settings:Changed(true) end, spec.unit, spec.percent)
    elseif t == "select" then
        row.control = UI.Dropdown(row, spec.width or CONTROL_W.select, {
            values = function() return Value(spec.values) or {} end,
            get = spec.get,
            set = function(v) spec.set(v); Settings:Changed() end,
            placeholder = spec.placeholder,
        })
    elseif t == "input" then
        row.control = UI.Input(row, spec.width or CONTROL_W.input, {
            placeholder = spec.placeholder,
            onCommit = function(text)
                if spec.validate then
                    local err = spec.validate(text)
                    if err then
                        Settings:Status("|cFFFF5555" .. err .. "|r")
                        row.control:SetText(tostring(spec.get() or ""))
                        return
                    end
                end
                spec.set(text)
                Settings:Changed()
            end,
        })
    elseif t == "button" then
        row.control = UI.Button(row, Value(spec.text) or "OK", spec.width or CONTROL_W.button, 24, spec.kind, function()
            if spec.confirm then
                UI.Confirm(Value(spec.confirm), function() spec.func(); Settings:Changed() end)
            else
                spec.func()
                Settings:Changed()
            end
        end)
    end
end

local function BuildRow(parent, spec)
    local row = CreateFrame("Frame", nil, parent)
    row.spec = spec
    if spec.type == "section" then
        row.bar = UI.Tex(row, "ARTWORK", "accent")
        row.bar:SetSize(3, 16)
        row.bar:SetPoint("TOPLEFT", 0, -10)
        row.title = UI.Text(row, "GameFontNormalLarge", "title")
        row.title:SetPoint("TOPLEFT", 10, -9)
        row.line = UI.Tex(row, "ARTWORK", "border")
        row.line:SetHeight(1)
        row.line:SetPoint("TOPLEFT", 0, -32)
        row.line:SetPoint("TOPRIGHT", 0, -32)
        row.desc = UI.Text(row, "GameFontHighlightSmall", "muted")
        row.desc:SetPoint("TOPLEFT", 0, -40)
        row.desc:SetPoint("TOPRIGHT", 0, -40)
        row.desc:SetJustifyV("TOP")
        return row
    end
    if spec.type == "text" then
        row.desc = UI.Text(row, spec.font or "GameFontHighlight", spec.role or "text")
        row.desc:SetPoint("TOPLEFT", 12, -4)
        row.desc:SetPoint("TOPRIGHT", -12, -4)
        row.desc:SetJustifyV("TOP")
        return row
    end
    if spec.type == "custom" then
        spec.build(row)
        return row
    end
    if spec.type == "buttons" then
        row.buttons = {}
        for i, b in ipairs(spec.items) do
            local btn = UI.Button(row, Value(b.text), b.width or 140, 24, b.kind, function()
                if b.confirm then
                    UI.Confirm(Value(b.confirm), function() b.func(); Settings:Changed() end)
                else
                    b.func()
                    Settings:Changed()
                end
            end)
            -- one anchor each: the first sits at the row's left, the rest follow it
            if i == 1 then
                btn:SetPoint("TOPLEFT", 12, -6)
            else
                btn:SetPoint("LEFT", row.buttons[i - 1], "RIGHT", 8, 0)
            end
            row.buttons[i] = btn
        end
        return row
    end

    row.hover = UI.Tex(row, "BACKGROUND", "hover")
    row.hover:SetAllPoints(row)
    row.hover:Hide()
    row.flash = UI.Tex(row, "BACKGROUND", "accent", 0.18)
    row.flash:SetAllPoints(row)
    row.flash:Hide()
    row.label = UI.Text(row, "GameFontHighlight", "text")
    row.label:SetPoint("TOPLEFT", 12, -8)
    row.desc = UI.Text(row, "GameFontHighlightSmall", "muted")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
    row.desc:SetJustifyV("TOP")
    BuildControl(row, spec)
    if row.control then row.control:SetPoint("RIGHT", row, "RIGHT", -12, 0) end
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    return row
end

--- Place and refresh one row; returns its height.
local function LayoutRow(row, spec, width)
    row:SetWidth(width)
    local disabled = spec.disabled and spec.disabled() or false
    if spec.type == "section" then
        row.title:SetText(Value(spec.label) or "")
        local d = Value(spec.desc)
        row.desc:SetText(d or "")
        row.desc:SetShown(d ~= nil and d ~= "")
        local h = 40
        if d and d ~= "" then h = 44 + (row.desc:GetStringHeight() or 12) end
        row:SetHeight(h)
        return h
    elseif spec.type == "text" then
        row.desc:SetText(Value(spec.text) or "")
        local h = (row.desc:GetStringHeight() or 14) + 10
        row:SetHeight(h)
        return h
    elseif spec.type == "custom" then
        local h = spec.layout(row, width) or 0
        row:SetHeight(h)
        return h
    elseif spec.type == "buttons" then
        local prev
        for i, b in ipairs(spec.items) do
            local btn = row.buttons[i]
            btn:SetLabel(Value(b.text))
            local shown = not (b.hidden and b.hidden())
            btn:SetShown(shown)
            btn:SetEnabledState(not (b.disabled and b.disabled()))
            if shown then
                btn:ClearAllPoints()
                if prev then btn:SetPoint("LEFT", prev, "RIGHT", 8, 0) else btn:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -6) end
                prev = btn
            end
        end
        row:SetHeight(36)
        return 36
    end

    row.label:SetText(Value(spec.label) or "")
    local cw = row.control and row.control:GetWidth() or 0
    local textW = width - 24 - cw - CONTROL_GAP
    row.label:SetWidth(textW)
    local d = Value(spec.desc)
    row.desc:SetWidth(textW)
    row.desc:SetText(d or "")
    row.desc:SetShown(d ~= nil and d ~= "")
    row.label:SetAlpha(disabled and 0.5 or 1)
    local c = row.control
    if c then
        if spec.type == "toggle" then
            c:SetValue(spec.get())
            c:SetDisabled(disabled)
        elseif spec.type == "slider" then
            c:SetValue(spec.get())
            c:SetDisabled(disabled)
        elseif spec.type == "select" then
            c:Refresh()
            c:SetDisabled(disabled)
        elseif spec.type == "input" then
            if not c.edit:HasFocus() then c:SetText(tostring(spec.get() or "")) end
            c:SetDisabled(disabled)
        elseif spec.type == "button" then
            c:SetLabel(Value(spec.text) or "OK")
            c:SetEnabledState(not disabled)
        end
    end
    local h = 16 + (row.label:GetStringHeight() or 14)
    if d and d ~= "" then h = h + 3 + (row.desc:GetStringHeight() or 12) end
    h = math.max(h, 40)
    row:SetHeight(h)
    return h
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function Settings:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "WorkoutBuddySettings", UIParent)
    self.frame = f
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    UI.Box(f, "bg", "border")
    tinsert(UISpecialFrames, f:GetName())

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)
    header.bg = UI.Tex(header, "BACKGROUND", "header")
    header.bg:SetAllPoints(header)
    header.line = UI.Tex(header, "ARTWORK", "accent", 0.7)
    header.line:SetHeight(1)
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 14, 0)
    icon:SetTexture(WorkoutBuddy.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = UI.Text(header, "GameFontNormalLarge", "title")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 6)
    title:SetText("Workout Buddy")
    local sub = UI.Text(header, "GameFontHighlightSmall", "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText("Version " .. tostring(WorkoutBuddy.VERSION))
    local close = UI.IconButton(header, "Interface\\Buttons\\UI-StopButton", 18, "Close", function() f:Hide() end)
    close:SetPoint("RIGHT", -14, 0)
    self.search = UI.Input(header, 260, {
        placeholder = "Search settings...",
        onChange = function(text) Settings:SetSearch(text) end,
    })
    self.search:SetPoint("RIGHT", close, "LEFT", -14, 0)
    self.search.edit:SetScript("OnEscapePressed", function(e)
        if (e:GetText() or "") ~= "" then
            Settings.search:SetText("")
            Settings:SetSearch("")
        else
            e:ClearFocus()
        end
    end)

    -- Navigation
    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", 1, -HEADER_H - 1)
    nav:SetPoint("BOTTOMLEFT", 1, 1)
    nav:SetWidth(NAV_W)
    nav.bg = UI.Tex(nav, "BACKGROUND", "nav")
    nav.bg:SetAllPoints(nav)
    nav.line = UI.Tex(nav, "ARTWORK", "border")
    nav.line:SetWidth(1)
    nav.line:SetPoint("TOPRIGHT")
    nav.line:SetPoint("BOTTOMRIGHT")
    self.nav = nav
    self.navButtons = {}

    -- Page area
    self.status = UI.Text(f, "GameFontHighlightSmall", "muted")
    self.status:SetPoint("BOTTOMLEFT", NAV_W + PAD, 10)
    self.status:SetPoint("BOTTOMRIGHT", -PAD, 10)
    self.scroll = UI.Scroll(f)
    self.scroll:SetPoint("TOPLEFT", NAV_W + PAD, -HEADER_H - 10)
    self.scroll:SetPoint("BOTTOMRIGHT", -8, 28)

    f:SetScript("OnHide", function()
        UI.CloseMenu()
        if WorkoutBuddy.ItemUse.StopCapture then WorkoutBuddy.ItemUse:StopCapture() end
    end)
    f:Hide()
    self:BuildNav()
    return f
end

function Settings:BuildNav()
    for i, page in ipairs(self.order) do
        local b = CreateFrame("Button", nil, self.nav)
        b:SetHeight(34)
        b:SetPoint("TOPLEFT", 0, -10 - (i - 1) * 36)
        b:SetPoint("TOPRIGHT", -1, -10 - (i - 1) * 36)
        b.hl = UI.Tex(b, "HIGHLIGHT", "hover")
        b.hl:SetAllPoints(b)
        b.sel = UI.Tex(b, "BACKGROUND", "accent", 0.16)
        b.sel:SetAllPoints(b)
        b.mark = UI.Tex(b, "ARTWORK", "accent")
        b.mark:SetWidth(3)
        b.mark:SetPoint("TOPLEFT")
        b.mark:SetPoint("BOTTOMLEFT")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 14, 0)
        b.icon:SetTexture(page.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label = UI.Text(b, "GameFontHighlight", "text")
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b.label:SetText(page.label)
        b.count = UI.Text(b, "GameFontHighlightSmall", "muted")
        b.count:SetPoint("RIGHT", -12, 0)
        b.count:SetJustifyH("RIGHT")
        b:SetScript("OnClick", function()
            if Settings.searchText ~= "" then
                Settings.search:SetText("")
                Settings.searchText = ""
            end
            Settings:Show(page.key)
        end)
        b.page = page
        self.navButtons[i] = b
    end
end

function Settings:UpdateNav()
    for _, b in ipairs(self.navButtons) do
        local active = self.searchText == "" and b.page.key == self.current
        b.sel:SetShown(active)
        b.mark:SetShown(active)
        b.count:SetText(b.page.count and b.page.count() or "")
    end
end

------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------
Settings.searchText = ""

function Settings:Status(text)
    if self.status then self.status:SetText(text or "") end
end

local function HideAll(content)
    for _, child in ipairs({ content:GetChildren() }) do child:Hide() end
end

--- Lay out rows for a list of specs inside the scroll content.
function Settings:LayoutSpecs(specs, rowsKey, y, width)
    local content = self.scroll.content
    for _, spec in ipairs(specs) do
        if not (spec.hidden and spec.hidden()) then
            spec[rowsKey] = spec[rowsKey] or BuildRow(content, spec)
            local row = spec[rowsKey]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            local h = LayoutRow(row, spec, width)
            row:Show()
            row.y = y
            y = y + h + (spec.type == "section" and 4 or 2)
        end
    end
    return y
end

function Settings:Render()
    if not (self.frame and self.frame:IsShown()) then return end
    local content = self.scroll.content
    local width = (self.scroll:GetWidth() or (WIN_W - NAV_W - PAD - 8)) - 12
    if width < 100 then width = WIN_W - NAV_W - PAD - 20 end
    content:SetWidth(width)
    HideAll(content)
    local y
    if self.searchText ~= "" then
        y = self:RenderSearch(width)
    else
        local page = self.pages[self.current]
        y = self:LayoutSpecs(self:Specs(page), "_row", 0, width)
    end
    content:SetHeight(math.max(y + 20, 10))
    self.scroll:UpdateBar()
    self:UpdateNav()
end

--- Something changed: refresh values and layout. Sliders pass quick=true
-- (no full re-layout needed while dragging).
function Settings:Changed(quick)
    if quick then self:UpdateNav() return end
    self:Render()
end

function Settings:Refresh()
    self:Render()
end

------------------------------------------------------------------------
-- Search
------------------------------------------------------------------------
local function SearchText(page, section, spec)
    local parts = { page.label, section or "", Value(spec.label) or "", Value(spec.desc) or "", spec.keywords or "" }
    if spec.search then parts[#parts + 1] = spec.search.label or ""; parts[#parts + 1] = spec.search.desc or "" end
    return table.concat(parts, " "):lower()
end

local function Matches(text, words)
    for _, w in ipairs(words) do
        if not text:find(w, 1, true) then return false end
    end
    return true
end

--- Specs matching the search, grouped by page: { {page=, specs={...}}, ... }
function Settings:SearchResults(text)
    local words = {}
    for w in tostring(text or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local groups = {}
    if #words == 0 then return groups end
    for _, page in ipairs(self.order) do
        local found, section = {}, nil
        for _, spec in ipairs(self:Specs(page)) do
            if spec.type == "section" then
                section = Value(spec.label)
            elseif (spec.label or spec.search) and not (spec.hidden and spec.hidden())
                and Matches(SearchText(page, section, spec), words) then
                found[#found + 1] = spec
            end
        end
        if #found > 0 then groups[#groups + 1] = { page = page, specs = found } end
    end
    return groups
end

function Settings:RenderSearch(width)
    local groups = self:SearchResults(self.searchText)
    self.searchHeads = self.searchHeads or {}
    local y = 0
    if #groups == 0 then
        local h = self.searchHeads.none or { type = "text", text = "No settings match. Try a shorter word, like \"potion\", \"sound\" or \"quiet\".", role = "muted" }
        self.searchHeads.none = h
        return self:LayoutSpecs({ h }, "_row", y, width)
    end
    for _, g in ipairs(groups) do
        local head = self.searchHeads[g.page.key] or { type = "section", label = g.page.label }
        self.searchHeads[g.page.key] = head
        y = self:LayoutSpecs({ head }, "_row", y, width)
        local list = {}
        for _, spec in ipairs(g.specs) do
            if spec.type == "custom" then
                -- custom areas show as a link to their page
                spec._link = spec._link or {
                    type = "button", label = spec.search.label, desc = spec.search.desc, text = "Go to " .. g.page.label,
                    func = function() Settings:GoTo(g.page.key, spec) end,
                }
                list[#list + 1] = spec._link
            else
                list[#list + 1] = spec
            end
        end
        y = self:LayoutSpecs(list, "_srow", y, width)
    end
    return y
end

function Settings:SetSearch(text)
    self.searchText = strtrim(text or "")
    self.scroll:ScrollTo(0)
    self:Render()
end

--- Leave the search and jump to a setting on its page, briefly highlighted.
function Settings:GoTo(pageKey, spec)
    self.search:SetText("")
    self.searchText = ""
    self:Show(pageKey)
    local row = spec and spec._row
    if row and row.y then
        self.scroll:ScrollTo(row.y - 20)
        if row.flash then
            row.flash:Show()
            C_Timer.After(1.2, function() row.flash:Hide() end)
        end
    end
end

------------------------------------------------------------------------
-- Opening
------------------------------------------------------------------------
function Settings:Show(pageKey)
    self:Create()
    local page = self.pages[pageKey or self.current or (self.order[1] and self.order[1].key)]
    if not page then return end
    local changed = self.current ~= page.key
    self.current = page.key
    if page.onShow and (changed or not self.frame:IsShown()) then page.onShow() end
    if changed then self.scroll:ScrollTo(0) end
    self:Status("")
    self.frame:Show()
    self:Render()
end

function Settings:Toggle(pageKey)
    self:Create()
    if self.frame:IsShown() and (not pageKey or pageKey == self.current) then
        self.frame:Hide()
    else
        self:Show(pageKey)
    end
end

function Settings:IsShown()
    return self.frame and self.frame:IsShown()
end

--- Open every page and list overlapping controls ("Page: A overlaps B").
-- Used by /wob uicheck and the offline tests.
function Settings:CheckLayout()
    local before = self.current
    local found = {}
    for _, page in ipairs(self.order) do
        self:Show(page.key)
        for _, issue in ipairs(UI.FindOverlaps(self.frame)) do
            found[#found + 1] = page.label .. ": " .. issue
        end
        for _, issue in ipairs(UI.FindZeroSize(self.frame)) do
            found[#found + 1] = page.label .. ": " .. issue
        end
    end
    self:Show(before)
    return found
end

------------------------------------------------------------------------
-- Entry in the game's own Options > AddOns list
------------------------------------------------------------------------
function Settings:RegisterBlizzardPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Workout Buddy"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Workout Buddy")
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetText("Settings have their own window. Type /wob or click below.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    open:SetText("Open Workout Buddy settings")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        Settings:Show()
    end)
    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        local category = _G.Settings.RegisterCanvasLayoutCategory(panel, "Workout Buddy")
        _G.Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    self.blizzardPanel = panel
end

------------------------------------------------------------------------
-- Addon hooks used across the code
------------------------------------------------------------------------
function WorkoutBuddy:InitConfig()
    Settings:RegisterBlizzardPanel()
end

function WorkoutBuddy:OpenConfig(pageKey)
    Settings:Toggle(pageKey)
end

function WorkoutBuddy:NotifyConfigChanged()
    if Settings:IsShown() then Settings:Refresh() end
end

function WorkoutBuddy:ForceFullConfigRefresh()
    self.TriggerList:ResetVisibility()
    if Settings:IsShown() then Settings:Refresh() end
end
