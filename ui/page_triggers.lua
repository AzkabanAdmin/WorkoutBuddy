-- ui/page_triggers.lua
-- Triggers page: one list of "when to work out" entries (built-in and
-- custom look the same), each with what it gives, plus a guided form for
-- adding or editing a trigger, and the suggestion settings.

local _, WorkoutBuddy = ...
local UI = WorkoutBuddy.UI
local Settings = WorkoutBuddy.SettingsUI

local function P() return WorkoutBuddy.db.profile end
local function TL() return WorkoutBuddy.TriggerList end
local function TM() return WorkoutBuddy.TriggerManager end
local function IU() return WorkoutBuddy.ItemUse end

local ROW_H = 48

------------------------------------------------------------------------
-- "Gives" choices shared by the list and the form
------------------------------------------------------------------------
local function WorkoutKey(w) return (w.name or "") .. "|" .. (w.unit or "") end

local function WorkoutLabel(w)
    return (w.name or "?") .. ((w.unit and w.unit ~= "") and ("  |cFF888888" .. w.unit .. "|r") or "")
end

--- Dropdown values for what a trigger gives. current = the set workout now.
local function GivesValues(allowOpen, current)
    local values = { { value = "random", text = "A random workout from my list" } }
    local seen = {}
    for _, w in ipairs(P().workouts) do
        local k = WorkoutKey(w)
        if not seen[k] then
            seen[k] = true
            values[#values + 1] = { value = "w:" .. k, text = WorkoutLabel(w) }
        end
    end
    if current and not seen[WorkoutKey(current)] then
        values[#values + 1] = { value = "w:" .. WorkoutKey(current), text = WorkoutLabel(current) }
    end
    if allowOpen then values[#values + 1] = { value = "open", text = "Just open the workout window" } end
    return values
end

local function GivesValue(gives)
    if gives.mode == "set" and gives.workout then return "w:" .. WorkoutKey(gives.workout) end
    return gives.mode
end

--- The workout behind a "w:name|unit" choice (from the list, or the current one).
local function WorkoutFor(value, current)
    local key = value:sub(3)
    for _, w in ipairs(P().workouts) do
        if WorkoutKey(w) == key then return { name = w.name, amount = tonumber(w.amount) or 1, unit = w.unit or "" } end
    end
    if current and WorkoutKey(current) == key then return current end
end

------------------------------------------------------------------------
-- Trigger list rows
------------------------------------------------------------------------
local function BuildEntryRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    UI.Box(r, "panel", "border")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.switch = UI.Switch(r, function(on)
        TL():SetEnabled(r.entry, on)
        Settings:Changed()
    end)
    r.switch:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r.remove = UI.IconButton(r, "Interface\\Buttons\\UI-StopButton", 16, "Remove this trigger", function()
        local e = r.entry
        if e.kind == "custom" then
            UI.Confirm("Remove the trigger '" .. e.label .. "'?", function() TL():Remove(e); Settings:Changed() end)
        else
            TL():Remove(e)
            Settings:Changed()
        end
    end)
    r.remove:SetPoint("RIGHT", -10, 0)
    r.edit = UI.Button(r, "Edit", 50, 22, nil, function() Settings:OpenTriggerForm(r.entry.index) end)
    r.edit:SetPoint("RIGHT", r.remove, "LEFT", -8, 0)
    r.amount = UI.Input(r, 50, {
        onCommit = function(text)
            local n = tonumber(text)
            local g = r.entry.gives
            if not n or n < 0 or g.mode ~= "set" then
                r.amount:SetText(tostring(g.workout and g.workout.amount or ""))
                return
            end
            local w = { name = g.workout.name, amount = n, unit = g.workout.unit }
            TL():SetGives(r.entry, "set", w)
            Settings:Changed()
        end,
    })
    r.gives = UI.Dropdown(r, 210, {
        values = function()
            if not r.entry then return {} end -- not assigned yet (first build)
            return GivesValues(r.entry.kind == "custom", r.entry.gives.workout)
        end,
        get = function() return r.entry and GivesValue(r.entry.gives) end,
        set = function(v)
            local e = r.entry
            if not e then return end
            if v == "random" or v == "open" then
                TL():SetGives(e, v)
            else
                local w = WorkoutFor(v, e.gives.workout)
                if w then
                    -- keep the amount already chosen when switching between set workouts
                    if e.gives.mode == "set" and e.gives.workout then w.amount = e.gives.workout.amount end
                    TL():SetGives(e, "set", w)
                end
            end
            Settings:Changed()
        end,
    })
    r.label = UI.Text(r, "GameFontHighlight", "text")
    r.label:SetPoint("TOPLEFT", r.switch, "TOPRIGHT", 12, 6)
    r.label:SetWordWrap(false)
    r.sub = UI.Text(r, "GameFontHighlightSmall", "muted")
    r.sub:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
    r.sub:SetWordWrap(false)
    return r
end

local function LayoutEntryRow(r, e, width)
    r.entry = e
    r:SetWidth(width)
    r.icon:SetTexture(e.icon)
    r.icon:SetDesaturated(not e.enabled)
    r.switch:SetValue(e.enabled)
    r.switch:SetDisabled(e.locked)
    r.label:SetText(e.label)
    r.sub:SetText(e.sub or "")
    r.label:SetAlpha(e.enabled and 1 or 0.55)
    r.edit:SetShown(e.canOpen)
    -- right side: [gives][x amount][edit][remove]
    local right = e.canOpen and r.edit or r.remove
    r.gives:ClearAllPoints()
    r.amount:ClearAllPoints()
    local isSet = e.gives.mode == "set" and e.gives.workout
    r.amount:SetShown(isSet and true or false)
    if isSet then
        r.amount:SetPoint("RIGHT", right, "LEFT", -10, 0)
        r.amount:SetText(tostring(e.gives.workout.amount or ""))
        r.gives:SetPoint("RIGHT", r.amount, "LEFT", -6, 0)
    else
        r.gives:SetPoint("RIGHT", right, "LEFT", -10, 0)
    end
    r.gives:Refresh()
    local textW = width - 10 - 28 - 10 - 36 - 12 - 210 - (isSet and 56 or 0) - (e.canOpen and 58 or 0) - 44
    r.label:SetWidth(math.max(80, textW))
    r.sub:SetWidth(math.max(80, textW))
    r:Show()
end

local listSpec = {
    type = "custom",
    search = { label = "Your triggers", desc = "Triggers list: when to work out, random or set workout, you die, boss, potions, items" },
    build = function(row)
        row.entryRows = {}
        row.addBtn = UI.Button(row, "+ Add a trigger", 150, 26, "primary", function() Settings:OpenTriggerForm() end)
        row.addBtn:SetPoint("TOPLEFT", 0, -4)
        row.empty = UI.Text(row, "GameFontHighlight", "muted")
        row.empty:SetText("No triggers are on. Click \"+ Add a trigger\" to choose when to work out.")
    end,
    layout = function(row, width)
        if Settings.form then return Settings:LayoutTriggerForm(row, width) end
        if row.form then row.form:Hide() end
        row.addBtn:Show()
        local entries = TL():Entries()
        local y = 38
        for i, e in ipairs(entries) do
            local r = row.entryRows[i] or BuildEntryRow(row)
            row.entryRows[i] = r
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            LayoutEntryRow(r, e, width)
            y = y + ROW_H + 6
        end
        for i = #entries + 1, #row.entryRows do row.entryRows[i]:Hide() end
        row.empty:ClearAllPoints()
        row.empty:SetPoint("TOPLEFT", 4, -y)
        row.empty:SetShown(#entries == 0)
        if #entries == 0 then y = y + 24 end
        return y + 4
    end,
}

------------------------------------------------------------------------
-- Add / edit form
------------------------------------------------------------------------
local WHEN_TILES = {
    { kind = "item", label = "I use an item", desc = "Potions, healthstones, food...", icon = "Interface\\Icons\\INV_Potion_76" },
    { kind = "health", label = "My health drops", desc = "Below a percent you choose", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { kind = "rest", label = "Inn or city", desc = "Entering or leaving a rest area", icon = "Interface\\Icons\\Spell_Nature_Sleep" },
    { kind = "event", label = "Any game event", desc = "Advanced: pick from the full list", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

local PRESET_CHIPS = { "named", "potion", "healthstone", "food", "flask", "consumable" }
local PRESET_TEXT = { named = "Specific items", potion = "Any potion", healthstone = "Healthstone",
    food = "Food or drink", flask = "Flask or elixir", consumable = "Any consumable" }

local function KindOf(t)
    if not t or not t.event then return nil end
    if t.event == TM().ITEM_USED then return "item" end
    if t.event == "UNIT_HEALTH" then return "health" end
    if t.event == "PLAYER_UPDATE_RESTING" then return "rest" end
    return "event"
end

--- Open the form. index edits a custom trigger; event starts a new one
-- with that event (e.g. "ITEM_USED").
function Settings:OpenTriggerForm(index, event)
    local t
    if index and P().triggers[index] then
        t = CopyTable(P().triggers[index])
    else
        t = { name = "", enabled = true, options = {}, action = "fixed" }
        if event then t.event = event end
    end
    t.options = type(t.options) == "table" and t.options or {}
    if t.action == "fixed" and not t.workout then
        local first = P().workouts[1]
        t.workout = first and { name = first.name, amount = tonumber(first.amount) or 1, unit = first.unit or "" }
            or { name = "Push-ups", amount = 3, unit = "reps" }
    end
    if t.event == "CUSTOM" then t.event = t.customEvent end
    self.form = { t = t, index = index, kind = KindOf(t), eventFilter = "", typed = "" }
    if self.form.kind == "item" then t.options.preset = t.options.preset or "named" end
    self:Show("triggers")
    self.scroll:ScrollTo(0)
    self:Status(index and "Editing a trigger." or "Choose when to work out, then what it gives.")
end

function Settings:CloseTriggerForm()
    WorkoutBuddy.ItemUse:StopCapture()
    self.form = nil
    self:Status("")
    self:Render()
end

local function Head(form, key, text)
    local h = form.heads[key]
    if not h then
        h = UI.Text(form, "GameFontNormal", "title")
        form.heads[key] = h
    end
    h:SetText(text)
    return h
end

local function BuildForm(row)
    local f = CreateFrame("Frame", nil, row)
    row.form = f
    f.heads = {}
    f.tiles = {}
    f.title = UI.Text(f, "GameFontNormalLarge", "title")
    f.back = UI.Button(f, "Back to the list", 130, 22, nil, function() Settings:CloseTriggerForm() end)

    -- When
    f.whenIcon = f:CreateTexture(nil, "ARTWORK")
    f.whenIcon:SetSize(24, 24)
    f.whenIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.whenText = UI.Text(f, "GameFontHighlight", "text")
    f.change = UI.Button(f, "Change", 70, 22, nil, function()
        local form = Settings.form
        form.t.event, form.kind, form.builtin = nil, nil, nil
        Settings:Render()
    end)

    -- Item details
    f.presets = {}
    for i, key in ipairs(PRESET_CHIPS) do
        f.presets[i] = UI.Chip(f, PRESET_TEXT[key], function()
            Settings.form.t.options.preset = key
            Settings:Render()
        end)
        f.presets[i].key = key
    end
    f.itemChips = {}
    f.bag = UI.Dropdown(f, 250, {
        placeholder = "Add from your bags",
        values = function()
            local values = {}
            for i, item in ipairs(IU():BagItems()) do
                values[#values + 1] = { value = i, text = item.displayName, icon = item.icon }
            end
            if #values == 0 then values[1] = { value = 0, text = "|cFF888888No usable items in your bags|r" } end
            return values
        end,
        get = function() return nil end,
        set = function(i)
            local item = IU():BagItems()[i]
            if item then Settings:AddFormItem(item.displayName) end
        end,
    })
    f.capture = UI.Button(f, "Use an item to add it", 170, 24, nil, function()
        local ok = IU():Capture(function(name)
            if not Settings.form then return end
            if name then
                Settings:AddFormItem(name)
            else
                Settings:Status("Stopped waiting. Click \"Use an item to add it\" to try again.")
            end
        end, 30)
        Settings:Status(ok and "|cFFFFD700Now use the item: drink the potion, eat the food... Waiting 30 seconds.|r"
            or "|cFFFF5555This game client cannot watch item use.|r")
    end)
    f.capture.tipTitle = "Use an item to add it"
    f.capture.tipText = "Click, then use the item in game. It is added to the list automatically."
    f.typed = UI.Input(f, 300, {
        placeholder = "Type a name, or shift-click an item",
        onChange = function(text)
            Settings.form.typed = text
            Settings:LayoutSuggestions()
        end,
        onCommit = function(text)
            if IU().CleanName(text) ~= "" and Settings.form then
                Settings.form.typed = ""
                Settings:AddFormItem(text)
            end
        end,
    })
    f.suggestions = {}

    -- Health details
    f.unit = UI.Dropdown(f, 120, {
        values = function()
            return { { value = "player", text = "My health" }, { value = "target", text = "Target's health" },
                { value = "focus", text = "Focus's health" }, { value = "pet", text = "Pet's health" } }
        end,
        get = function() return Settings.form.t.options.unit or "player" end,
        set = function(v) Settings.form.t.options.unit = v end,
    })
    f.op = UI.Dropdown(f, 130, {
        values = function()
            return { { value = "<", text = "drops below" }, { value = "<=", text = "is at or below" },
                { value = ">", text = "rises above" }, { value = ">=", text = "is at or above" } }
        end,
        get = function() return Settings.form.t.options.op or "<" end,
        set = function(v) Settings.form.t.options.op = v end,
    })
    f.value = UI.Input(f, 60, {
        onCommit = function(text)
            local n = tonumber(text)
            if n and n >= 0 and n <= 100 then Settings.form.t.options.value = n end
            f.value:SetText(tostring(Settings.form.t.options.value or 50))
        end,
    })
    f.pct = UI.Text(f, "GameFontHighlight", "text")
    f.pct:SetText("%")

    -- Rest details
    f.restChips = {
        UI.Chip(f, "Entering an inn or city", function() Settings.form.t.options.state = "resting"; Settings:Render() end),
        UI.Chip(f, "Leaving an inn or city", function() Settings.form.t.options.state = "active"; Settings:Render() end),
    }

    -- Any event
    f.eventSearch = UI.Input(f, 300, {
        placeholder = "Search events, e.g. LOOT or MAIL",
        onChange = function(text)
            Settings.form.eventFilter = text
            Settings.form.eventOffset = 0
            Settings:LayoutEventList()
        end,
    })
    f.eventRows = {}
    f.eventHelp = UI.Text(f, "GameFontHighlightSmall", "muted")
    f.eventHelp:SetJustifyV("TOP")
    f.luaSwitch = UI.Switch(f, function(on)
        Settings.form.showLua = on
        if not on then Settings.form.t.custom = nil end
        Settings:Render()
    end)
    f.luaLabel = UI.Text(f, "GameFontHighlight", "text")
    f.luaLabel:SetText("Add a Lua condition (advanced)")
    f.lua = UI.Multiline(f, 400, 70)
    f.lua.edit:SetScript("OnTextChanged", function(e) if Settings.form then Settings.form.t.custom = e:GetText() end end)
    f.luaHelp = UI.Text(f, "GameFontHighlightSmall", "muted")
    f.luaHelp:SetText("The event's arguments are available as '...'. Return true to fire. Example: local unit = ...; return unit == 'player'")

    -- Then
    f.thenChips = {
        UI.Chip(f, "A random workout", function() Settings:SetFormGives("random") end),
        UI.Chip(f, "A set workout", function() Settings:SetFormGives("set") end),
        UI.Chip(f, "Just open the window", function() Settings:SetFormGives("open") end),
    }
    f.pick = UI.Dropdown(f, 220, {
        placeholder = "Pick from your list",
        values = function()
            local values = {}
            for i, w in ipairs(P().workouts) do values[#values + 1] = { value = i, text = WorkoutLabel(w) } end
            return values
        end,
        get = function() return nil end,
        set = function(i)
            local w = P().workouts[i]
            local t = Settings.form.t
            if w then t.workout = { name = w.name, amount = t.workout and t.workout.amount or w.amount, unit = w.unit or "" } end
            Settings:Render()
        end,
    })
    f.wName = UI.Input(f, 180, { placeholder = "Workout", onCommit = function(v) Settings.form.t.workout.name = v end })
    f.wAmount = UI.Input(f, 60, { placeholder = "3", onCommit = function(v) Settings.form.t.workout.amount = tonumber(v) end })
    f.wUnit = UI.Input(f, 90, { placeholder = "reps", onCommit = function(v) Settings.form.t.workout.unit = v end })
    f.everyTime = UI.Text(f, "GameFontHighlightSmall", "muted")
    f.everyTime:SetText("Every time counts. Repeats add up in one row: ten potions at 3 push-ups make Push-ups x30.")

    -- Name and save
    f.name = UI.Input(f, 300, { placeholder = "Optional: named after what it counts", onCommit = function(v) Settings.form.t.name = v end })
    f.save = UI.Button(f, "Save trigger", 140, 28, "primary", function() Settings:SaveTriggerForm() end)
    f.cancel = UI.Button(f, "Cancel", 100, 28, nil, function() Settings:CloseTriggerForm() end)
    return f
end

--- Everything the form owns, hidden before each layout.
local function HideFormParts(f)
    for _, region in ipairs({ f.whenIcon, f.whenText, f.change, f.bag, f.capture, f.typed, f.unit, f.op, f.value, f.pct,
        f.eventSearch, f.eventHelp, f.luaSwitch, f.luaLabel, f.lua, f.luaHelp, f.pick, f.wName, f.wAmount, f.wUnit,
        f.everyTime }) do
        region:Hide()
    end
    for _, list in ipairs({ f.tiles, f.presets, f.itemChips, f.suggestions, f.restChips, f.eventRows, f.thenChips }) do
        for _, w in pairs(list) do w:Hide() end
    end
    for _, h in pairs(f.heads) do h:Hide() end
end

local function Place(region, f, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    region:Show()
end

local function Tile(f, i)
    local tile = f.tiles[i]
    if not tile then
        tile = CreateFrame("Button", nil, f)
        tile:SetSize(200, 46)
        UI.Box(tile, "panel", "border")
        tile.hl = UI.Tex(tile, "HIGHLIGHT", "accent", 0.15)
        tile.hl:SetAllPoints(tile)
        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetSize(26, 26)
        tile.icon:SetPoint("LEFT", 10, 0)
        tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tile.label = UI.Text(tile, "GameFontHighlight", "text")
        tile.label:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 8, 2)
        tile.label:SetPoint("RIGHT", -6, 0)
        tile.label:SetWordWrap(false)
        tile.desc = UI.Text(tile, "GameFontHighlightSmall", "muted")
        tile.desc:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -2)
        tile.desc:SetPoint("RIGHT", -6, 0)
        tile.desc:SetWordWrap(false)
        tile:SetScript("OnClick", function(self) self.onPick() end)
        f.tiles[i] = tile
    end
    return tile
end

function Settings:SetFormGives(mode)
    local t = self.form.t
    if mode == "set" then
        t.action = "fixed"
        if not t.workout then
            local first = P().workouts[1]
            t.workout = first and { name = first.name, amount = tonumber(first.amount) or 1, unit = first.unit or "" }
                or { name = "Push-ups", amount = 3, unit = "reps" }
        end
    elseif mode == "open" then
        t.action = "open_frame"
    else
        t.action = "workout"
    end
    self:Render()
end

function Settings:AddFormItem(name)
    local t = self.form and self.form.t
    if not t then return end
    local before = t.options.items or ""
    t.options.items = IU().AddName(before, name)
    t.options.preset = "named"
    self.form.typed = ""
    self:Render()
    if t.options.items ~= before then
        self:Status("|cFF66FF66Added " .. IU().CleanName(name) .. ".|r")
    end
end

--- Suggestions under the item box, updated while typing without a full
-- re-layout (so the box keeps focus).
function Settings:LayoutSuggestions()
    local row = self.triggerListRow
    local f = row and row.form
    if not (f and self.form) then return end
    for _, s in ipairs(f.suggestions) do s:Hide() end
    local y = f.suggestY or 0
    for i, item in ipairs(IU():Suggest(self.form.typed or "", 5)) do
        local s = f.suggestions[i]
        if not s then
            s = CreateFrame("Button", nil, f)
            s:SetSize(300, 20)
            s.hl = UI.Tex(s, "HIGHLIGHT", "accent", 0.2)
            s.hl:SetAllPoints(s)
            s.icon = s:CreateTexture(nil, "ARTWORK")
            s.icon:SetSize(16, 16)
            s.icon:SetPoint("LEFT", 4, 0)
            s.text = UI.Text(s, "GameFontHighlightSmall", "text")
            s.text:SetPoint("LEFT", s.icon, "RIGHT", 6, 0)
            s:SetScript("OnClick", function(self) Settings:AddFormItem(self.name) end)
            f.suggestions[i] = s
        end
        s.name = item.displayName
        s.icon:SetTexture(item.icon)
        s.text:SetText(item.displayName .. "  |cFF888888in your bags, click to add|r")
        Place(s, f, 0, y + (i - 1) * 21)
    end
end

local function EventCatalog()
    TM():BuildCatalog()
    if not Settings.allEvents then
        local all = {}
        for _, cat in ipairs(TM().CategoryOrder) do
            for _, evt in ipairs(TM().EventCategories[cat]) do
                if evt ~= TM().ITEM_USED then all[#all + 1] = evt end
            end
        end
        table.sort(all)
        Settings.allEvents = all
    end
    return Settings.allEvents
end

local EVENT_ROWS = 8

function Settings:LayoutEventList()
    local row = self.triggerListRow
    local f = row and row.form
    if not (f and self.form) then return end
    local filter = strtrim(self.form.eventFilter or ""):upper()
    local matches = {}
    for _, evt in ipairs(EventCatalog()) do
        if filter == "" or evt:find(filter, 1, true) then matches[#matches + 1] = evt end
    end
    -- a typed event that is not in the catalog can still be used if valid
    if filter ~= "" and #matches == 0 and TM().IsTriggerEventValid(filter) then matches[1] = filter end
    local offset = math.max(0, math.min(self.form.eventOffset or 0, #matches - EVENT_ROWS))
    self.form.eventOffset = offset
    for i = 1, EVENT_ROWS do
        local r = f.eventRows[i]
        if not r then
            r = CreateFrame("Button", nil, f)
            r:SetSize(300, 20)
            r.hl = UI.Tex(r, "HIGHLIGHT", "accent", 0.2)
            r.hl:SetAllPoints(r)
            r.sel = UI.Tex(r, "BACKGROUND", "accent", 0.25)
            r.sel:SetAllPoints(r)
            r.text = UI.Text(r, "GameFontHighlightSmall", "text")
            r.text:SetPoint("LEFT", 6, 0)
            r:EnableMouseWheel(true)
            r:SetScript("OnMouseWheel", function(_, delta)
                Settings.form.eventOffset = (Settings.form.eventOffset or 0) - delta * 3
                Settings:LayoutEventList()
            end)
            r:SetScript("OnClick", function(self)
                Settings.form.t.event = self.evt
                Settings:Render()
            end)
            f.eventRows[i] = r
        end
        local evt = matches[i + offset]
        if evt then
            r.evt = evt
            r.text:SetText(evt)
            r.sel:SetShown(Settings.form.t.event == evt)
            Place(r, f, 0, (f.eventListY or 0) + (i - 1) * 21)
        else
            r:Hide()
        end
    end
    f.eventCount = #matches
end

function Settings:LayoutTriggerForm(row, width)
    self.triggerListRow = row
    row.addBtn:Hide()
    row.empty:Hide()
    for _, r in ipairs(row.entryRows) do r:Hide() end
    local f = row.form or BuildForm(row)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT")
    f:SetWidth(width)
    f:Show()
    HideFormParts(f)
    local form, t = self.form, self.form.t
    local y = 0

    f.title:SetText(form.index and "Edit trigger" or "New trigger")
    Place(f.title, f, 0, y + 2)
    f.back:ClearAllPoints()
    f.back:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
    f.back:Show()
    y = y + 36

    -- 1. When
    Place(Head(f, "when", "1. When"), f, 0, y)
    y = y + 22
    if not (form.kind or form.builtin) then
        local tiles = {}
        for _, b in ipairs(TL():AvailableBuiltins()) do
            tiles[#tiles + 1] = { builtin = b.key, label = b.label, desc = b.desc, icon = b.icon }
        end
        for _, w in ipairs(WHEN_TILES) do
            if w.kind ~= "item" or TM().IsTriggerEventValid("ITEM_USED") then tiles[#tiles + 1] = w end
        end
        local cols = 3
        local tileW = math.floor((width - (cols - 1) * 8) / cols)
        for i, info in ipairs(tiles) do
            local tile = Tile(f, i)
            tile:SetWidth(tileW)
            tile.icon:SetTexture(info.icon)
            tile.label:SetText(info.label)
            tile.desc:SetText(info.desc or "")
            tile.onPick = function()
                if info.builtin then
                    form.builtin = info.builtin
                    t.action = "workout"
                else
                    form.kind = info.kind
                    if info.kind == "item" then t.event = TM().ITEM_USED; t.options.preset = t.options.preset or "named"
                    elseif info.kind == "health" then t.event = "UNIT_HEALTH"
                    elseif info.kind == "rest" then t.event = "PLAYER_UPDATE_RESTING"; t.options.state = t.options.state or "resting"
                    else t.event = nil end
                end
                Settings:Render()
            end
            Place(tile, f, ((i - 1) % cols) * (tileW + 8), y + math.floor((i - 1) / cols) * 54)
        end
        y = y + math.ceil(#tiles / cols) * 54 + 6
        f.save:Hide()
        f.cancel:Hide()
        f.name:Hide()
        return y + 10
    end

    -- chosen: summary line
    local summaryIcon, summary
    if form.builtin then
        local b = TL().BUILTIN_BY_KEY[form.builtin]
        summaryIcon, summary = b.icon, b.label
    else
        for _, w in ipairs(WHEN_TILES) do
            if w.kind == form.kind then summaryIcon, summary = w.icon, w.label end
        end
        if form.kind == "event" and t.event then summary = "Game event: " .. t.event end
    end
    f.whenIcon:SetTexture(summaryIcon)
    Place(f.whenIcon, f, 0, y)
    f.whenText:SetText(summary or "")
    Place(f.whenText, f, 32, y + 5)
    if not form.index then
        f.change:ClearAllPoints()
        f.change:SetPoint("LEFT", f.whenText, "RIGHT", 12, 0)
        f.change:Show()
    end
    y = y + 34

    -- 2. Details
    if form.kind == "item" then
        Place(Head(f, "details", "2. Which items"), f, 0, y)
        y = y + 22
        local x = 0
        for _, chip in ipairs(f.presets) do
            chip:SetSelected((t.options.preset or "named") == chip.key)
            if x + chip:GetWidth() > width then x = 0; y = y + 28 end
            Place(chip, f, x, y)
            x = x + chip:GetWidth() + 6
        end
        y = y + 32
        if (t.options.preset or "named") == "named" then
            local names = IU().NameList(t.options.items)
            x = 0
            for i, name in ipairs(names) do
                local chip = f.itemChips[i]
                if not chip then
                    chip = UI.Chip(f, "", function(self)
                        local ft = Settings.form.t
                        ft.options.items = IU().RemoveName(ft.options.items, self.name)
                        Settings:Render()
                    end)
                    f.itemChips[i] = chip
                end
                chip.name = name
                chip.label:SetText(name .. "  |cFFFF6666x|r")
                chip:SetWidth((chip.label:GetStringWidth() or 60) + 20)
                chip:SetSelected(true)
                chip.tipTitle = "Click to remove"
                if x + chip:GetWidth() > width then x = 0; y = y + 28 end
                Place(chip, f, x, y)
                x = x + chip:GetWidth() + 6
            end
            if #names == 0 then
                local hint = Head(f, "noitems", "|cFF888888Nothing added yet. Use any of the three ways below.|r")
                Place(hint, f, 0, y + 4)
            end
            y = y + 32
            Place(f.bag, f, 0, y)
            f.bag:Refresh()
            Place(f.capture, f, 262, y)
            y = y + 32
            Place(f.typed, f, 0, y)
            if not f.typed.edit:HasFocus() then f.typed:SetText(form.typed or "") end
            y = y + 28
            f.suggestY = y
            self:LayoutSuggestions()
            y = y + 5 * 21 + 4
        else
            local d = Head(f, "presetdesc", "|cFF888888Counts every " .. PRESET_TEXT[t.options.preset]:lower()
                .. " you use. Names are matched in English on clients without item groups.|r")
            Place(d, f, 0, y)
            y = y + 22
        end
    elseif form.kind == "health" then
        Place(Head(f, "details", "2. When exactly"), f, 0, y)
        y = y + 22
        Place(f.unit, f, 0, y); f.unit:Refresh()
        Place(f.op, f, 128, y); f.op:Refresh()
        Place(f.value, f, 266, y)
        if not f.value.edit:HasFocus() then f.value:SetText(tostring(t.options.value or 50)) end
        Place(f.pct, f, 332, y + 5)
        y = y + 34
    elseif form.kind == "rest" then
        Place(Head(f, "details", "2. When exactly"), f, 0, y)
        y = y + 22
        f.restChips[1]:SetSelected((t.options.state or "resting") == "resting")
        f.restChips[2]:SetSelected(t.options.state == "active")
        Place(f.restChips[1], f, 0, y)
        Place(f.restChips[2], f, f.restChips[1]:GetWidth() + 6, y)
        y = y + 32
    elseif form.kind == "event" then
        Place(Head(f, "details", "2. Which event"), f, 0, y)
        y = y + 22
        Place(f.eventSearch, f, 0, y)
        y = y + 28
        f.eventListY = y
        self:LayoutEventList()
        y = y + EVENT_ROWS * 21 + 4
        local help = t.event and WorkoutBuddy.EventHelp[t.event]
        f.eventHelp:SetWidth(width)
        f.eventHelp:SetText(t.event and ("|cFFFFFFFF" .. t.event .. "|r" .. (help and (": " .. help) or "")) or "Click an event to choose it.")
        Place(f.eventHelp, f, 0, y)
        y = y + (f.eventHelp:GetStringHeight() or 14) + 10
        form.showLua = form.showLua or (t.custom ~= nil and t.custom ~= "")
        f.luaSwitch:SetValue(form.showLua)
        Place(f.luaSwitch, f, 0, y)
        Place(f.luaLabel, f, 46, y + 2)
        y = y + 26
        if form.showLua then
            f.lua:SetWidth(width)
            f.lua.edit:SetWidth(width - 14)
            if not f.lua.edit:HasFocus() then f.lua:SetText(t.custom or "") end
            Place(f.lua, f, 0, y)
            y = y + 76
            f.luaHelp:SetWidth(width)
            Place(f.luaHelp, f, 0, y)
            y = y + (f.luaHelp:GetStringHeight() or 14) + 8
        end
    end

    -- 3. Then
    Place(Head(f, "then", form.builtin and "2. Then add" or "3. Then"), f, 0, y)
    y = y + 22
    local mode = (t.action == "fixed") and "set" or (t.action == "open_frame" and "open") or "random"
    local x = 0
    for i, chip in ipairs(f.thenChips) do
        local show = not (i == 3 and form.builtin)
        if show then
            chip:SetSelected(({ "random", "set", "open" })[i] == mode)
            Place(chip, f, x, y)
            x = x + chip:GetWidth() + 6
        end
    end
    y = y + 32
    if mode == "set" then
        t.workout = t.workout or { name = "", amount = 3, unit = "reps" }
        Place(f.pick, f, 0, y); f.pick:Refresh()
        y = y + 30
        Place(f.wName, f, 0, y)
        Place(f.wAmount, f, 188, y)
        Place(f.wUnit, f, 256, y)
        if not f.wName.edit:HasFocus() then f.wName:SetText(t.workout.name or "") end
        if not f.wAmount.edit:HasFocus() then f.wAmount:SetText(tostring(t.workout.amount or "")) end
        if not f.wUnit.edit:HasFocus() then f.wUnit:SetText(t.workout.unit or "") end
        y = y + 28
        f.everyTime:SetWidth(width)
        Place(f.everyTime, f, 0, y)
        y = y + 20
    end

    -- Name and save (custom triggers only; built-ins have fixed names)
    if not form.builtin then
        Place(Head(f, "name", "4. Name"), f, 0, y + 4)
        y = y + 26
        Place(f.name, f, 0, y)
        if not f.name.edit:HasFocus() then f.name:SetText(t.name or "") end
        y = y + 34
    else
        f.name:Hide()
        y = y + 6
    end
    Place(f.save, f, 0, y)
    Place(f.cancel, f, 148, y)
    y = y + 40
    f:SetHeight(y)
    return y
end

function Settings:SaveTriggerForm()
    local form = self.form
    if not form then return end
    local t = form.t
    -- pick up anything typed but not yet committed
    local f = self.triggerListRow and self.triggerListRow.form
    if f then
        if t.workout and f.wName:IsShown() then
            t.workout.name = f.wName:GetText()
            t.workout.amount = tonumber(f.wAmount:GetText()) or t.workout.amount
            t.workout.unit = f.wUnit:GetText()
        end
        if f.name:IsShown() then t.name = f.name:GetText() end
    end
    if form.builtin then
        local mode = (t.action == "fixed") and "set" or "random"
        TL():AddBuiltin(form.builtin, mode, t.workout)
        self:Status("|cFF66FF66Added " .. TL().BUILTIN_BY_KEY[form.builtin].label .. ".|r")
        self.form = nil
        WorkoutBuddy.ItemUse:StopCapture()
        self:Render()
        return true
    end
    local ok, err = TL():SaveCustom(t, form.index)
    if not ok then
        self:Status("|cFFFF5555" .. err .. "|r")
        return false
    end
    self.form = nil
    WorkoutBuddy.ItemUse:StopCapture()
    self:Status("|cFF66FF66Trigger saved.|r")
    self:Render()
    return true
end

------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------
Settings:AddPage({
    key = "triggers",
    label = "Triggers",
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    order = 1,
    onShow = function() TL():ResetVisibility() end,
    count = function()
        local on = 0
        for _, e in ipairs(TL():Entries()) do if e.enabled then on = on + 1 end end
        return tostring(on)
    end,
    specs = function()
        return {
            { type = "section", label = "When to work out",
                desc = "Each trigger adds a workout to your queue: a random one from your list, or a set workout, like 5 burpees every time you die." },
            { type = "toggle", label = "Suggest workouts automatically",
                desc = "Turn off to pause every trigger. /wob now still works.", keywords = "pause resume enable",
                get = function() return P().enabled end, set = function(v) WorkoutBuddy:SetEnabled(v) end },
            listSpec,
            { type = "slider", label = "Minutes of play before a break",
                desc = "For the \"Playing for a while\" trigger.", keywords = "play timer sedentary",
                hidden = function() return not P().event_map.play_timer end,
                min = 10, max = 120, step = 5, unit = "min",
                get = function() return P().play_timer_minutes end,
                set = function(v) P().play_timer_minutes = v end },

            { type = "section", label = "Suggestions" },
            { type = "slider", label = "Minimum time between random suggestions",
                desc = "Random suggestions sooner than this after the last one are skipped. Set workouts always count.",
                keywords = "cooldown flood spam", min = 0, max = 900, step = 15,
                unit = "seconds",
                get = function() return P().suggest_cooldown end, set = function(v) P().suggest_cooldown = v end },
            { type = "toggle", label = "Show new workouts in my chat window",
                desc = "Only you can see these lines. Workout Buddy never posts to say, party, raid or guild on its own; sharing is always a button you click (Stats page). Skipped during combat; the recap after the fight covers it.",
                keywords = "message print announce chat private",
                get = function() return P().notify.chat end, set = function(v) P().notify.chat = v end },
            { type = "select", label = "Sound for new workouts", keywords = "audio alert",
                values = function()
                    local list = {}
                    for name in pairs(WorkoutBuddy.Sounds:GetList()) do list[#list + 1] = name end
                    table.sort(list, function(a, b) if a == "None" then return true elseif b == "None" then return false end return a < b end)
                    local values = {}
                    for _, name in ipairs(list) do values[#values + 1] = { value = name, text = name } end
                    return values
                end,
                get = function() return P().notify.sound or "None" end,
                set = function(v) P().notify.sound = v; WorkoutBuddy.Sounds:Play(v) end },
            { type = "toggle", label = "Avoid the same random workout twice in a row",
                get = function() return P().avoid_repeat end, set = function(v) P().avoid_repeat = v end },
            { type = "toggle", label = "Show a message in chat when the addon loads",
                get = function() return P().login_message end, set = function(v) P().login_message = v end },
        }
    end,
})
