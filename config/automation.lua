-- config/automation.lua
-- Editor window for custom triggers.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local AceGUI = LibStub("AceGUI-3.0")

local WIKI = "https://warcraft.wiki.gg/wiki/"

local ACTIONS = {
    workout = "Suggest a random workout",
    fixed = "Add a set workout every time",
    open_frame = "Open the workout window",
}
local ACTION_ORDER = { "workout", "fixed", "open_frame" }

--- Open the trigger editor.
-- @param action string "workout", "fixed" or "open_frame" for a new trigger
-- @param index  number index of an existing trigger to edit, or nil
-- @param event  string starting event for a new trigger (e.g. "ITEM_USED")
function WorkoutBuddy:OpenTriggerEditor(action, index, event)
    local TM = self.TriggerManager
    TM:BuildCatalog()

    local triggers = self.db.profile.triggers
    local original = index and triggers[index]
    local t = original and CopyTable(original)
        or { name = "", event = event or "PLAYER_LEVEL_UP", action = action or "workout", enabled = true, options = {} }
    t.options = type(t.options) == "table" and t.options or {}
    t._lastPass = nil

    if self.triggerEditor then
        self.triggerEditor:Hide() -- releases the old window via OnClose
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(original and "Edit Trigger" or "New Trigger")
    frame:SetStatusText(t.event == TM.ITEM_USED and "Add the items to count, then choose the workout."
        or "Pick a game event, then choose what happens when it fires.")
    frame:SetWidth(480)
    frame:SetHeight(640)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget)
        WorkoutBuddy.ItemUse:StopCapture()
        AceGUI:Release(widget)
        if self.triggerEditor == widget then self.triggerEditor = nil end
    end)
    self.triggerEditor = frame

    -- Name
    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel("Name")
    nameBox:SetFullWidth(true)
    nameBox:DisableButton(true)
    nameBox:SetText(t.name or "")
    nameBox:SetCallback("OnTextChanged", function(_, _, val) t.name = val end)
    frame:AddChild(nameBox)

    -- Action and enabled
    local actionDrop = AceGUI:Create("Dropdown")
    actionDrop:SetLabel("When it fires")
    actionDrop:SetList(ACTIONS, ACTION_ORDER)
    actionDrop:SetValue(ACTIONS[t.action] and t.action or "workout")
    actionDrop:SetRelativeWidth(0.6)
    frame:AddChild(actionDrop)

    local enabledBox = AceGUI:Create("CheckBox")
    enabledBox:SetLabel("Enabled")
    enabledBox:SetValue(t.enabled ~= false)
    enabledBox:SetRelativeWidth(0.35)
    enabledBox:SetCallback("OnValueChanged", function(_, _, val) t.enabled = val end)
    frame:AddChild(enabledBox)

    -- Event selection
    local catList = {}
    for _, cat in ipairs(TM.CategoryOrder) do catList[cat] = cat end

    local catDrop = AceGUI:Create("Dropdown")
    catDrop:SetLabel("Event category")
    catDrop:SetList(catList, TM.CategoryOrder)
    catDrop:SetRelativeWidth(0.4)
    frame:AddChild(catDrop)

    local eventDrop = AceGUI:Create("Dropdown")
    eventDrop:SetLabel("Event")
    eventDrop:SetRelativeWidth(0.58)
    frame:AddChild(eventDrop)

    local customEvent = AceGUI:Create("EditBox")
    customEvent:SetLabel("Or type any event name")
    customEvent:SetFullWidth(true)
    customEvent:DisableButton(true)
    frame:AddChild(customEvent)

    local optionsGroup = AceGUI:Create("SimpleGroup")
    optionsGroup:SetFullWidth(true)
    optionsGroup:SetLayout("Flow")
    frame:AddChild(optionsGroup)

    -- Lua condition
    local condition = AceGUI:Create("MultiLineEditBox")
    condition:SetLabel("Advanced: Lua condition (optional)")
    condition:SetFullWidth(true)
    condition:SetNumLines(5)
    condition:DisableButton(true)
    condition:SetText(t.custom or "")
    condition:SetCallback("OnTextChanged", function(_, _, val) t.custom = val end)
    frame:AddChild(condition)

    local condHelp = AceGUI:Create("Label")
    condHelp:SetFullWidth(true)
    local helpText = "|cFF888888The event's arguments are available as '...'. Return true to fire. Example: local unit = ...; return unit == 'player'|r"
    if t.imported then
        helpText = "|cFFFF8800This trigger came from an import. Read the condition above before saving; saving enables it.|r\n" .. helpText
    end
    condHelp:SetText(helpText)
    frame:AddChild(condHelp)

    -- Buttons
    local save = AceGUI:Create("Button")
    save:SetText("Save")
    save:SetRelativeWidth(0.5)
    frame:AddChild(save)

    local cancel = AceGUI:Create("Button")
    cancel:SetText("Cancel")
    cancel:SetRelativeWidth(0.48)
    cancel:SetCallback("OnClick", function() frame:Hide() end)
    frame:AddChild(cancel)

    ------------------------------------------------------------------
    local function CurrentEvent()
        if t.event == "CUSTOM" then return t.customEvent end
        return t.event
    end

    local function BuildEventOptions()
        optionsGroup:ReleaseChildren()
        local evt = CurrentEvent() or ""

        local info = AceGUI:Create("InteractiveLabel")
        info:SetFullWidth(true)
        local help = WorkoutBuddy.EventHelp[evt]
        local isItem = (t.event == TM.ITEM_USED)
        if isItem then
            info:SetText("|cFFFFFFFF" .. (help or "") .. "|r")
        else
            info:SetText((help and ("|cFFFFFFFF" .. help .. "|r\n") or "") ..
                "|cFF66BBFFClick for the event's wiki link|r")
            info:SetCallback("OnClick", function() WorkoutBuddy:CopyToClipboard(WIKI .. evt) end)
        end
        optionsGroup:AddChild(info)

        if isItem then
            local IU = WorkoutBuddy.ItemUse
            t.options.preset = t.options.preset or "named"
            local preset = AceGUI:Create("Dropdown")
            preset:SetLabel("Count when I use")
            preset:SetList(IU.PRESET_LABELS, IU.PRESET_ORDER)
            preset:SetValue(t.options.preset)
            preset:SetWidth(200)
            preset:SetCallback("OnValueChanged", function(_, _, v)
                t.options.preset = v
                BuildEventOptions()
            end)
            optionsGroup:AddChild(preset)
            if t.options.preset == "named" then
                local function AddItem(name)
                    local before = t.options.items or ""
                    t.options.items = IU.AddName(before, name)
                    BuildEventOptions()
                    if t.options.items ~= before then
                        frame:SetStatusText("|cFF66FF66Added " .. IU.CleanName(name) .. ".|r")
                    end
                end

                -- What is counted now, with a Remove button each
                local added = IU.NameList(t.options.items)
                local listHead = AceGUI:Create("Label")
                listHead:SetFullWidth(true)
                listHead:SetText(#added > 0 and "|cFFFFD700Counting:|r"
                    or "|cFF888888Nothing added yet. Pick from your bags, use the item, or type its name below.|r")
                optionsGroup:AddChild(listHead)
                for _, name in ipairs(added) do
                    local label = AceGUI:Create("Label")
                    label:SetText("  " .. name)
                    label:SetRelativeWidth(0.7)
                    optionsGroup:AddChild(label)
                    local remove = AceGUI:Create("Button")
                    remove:SetText("Remove")
                    remove:SetRelativeWidth(0.28)
                    remove:SetCallback("OnClick", function()
                        t.options.items = IU.RemoveName(t.options.items, name)
                        BuildEventOptions()
                    end)
                    optionsGroup:AddChild(remove)
                end

                -- 1. Pick from the bags
                local bag = AceGUI:Create("Dropdown")
                bag:SetLabel("Add from your bags")
                local bagList, bagOrder = {}, {}
                for i, item in ipairs(IU:BagItems()) do
                    bagList[i] = (item.icon and ("|T" .. item.icon .. ":16|t ") or "") .. item.displayName
                    bagOrder[#bagOrder + 1] = i
                end
                if #bagOrder == 0 then bag:SetText("|cFF888888No usable items in your bags|r") end
                bag:SetList(bagList, bagOrder)
                bag:SetRelativeWidth(0.58)
                bag:SetCallback("OnValueChanged", function(_, _, i)
                    local item = IU:BagItems()[i]
                    if item then AddItem(item.displayName) end
                end)
                optionsGroup:AddChild(bag)

                -- 2. Use the item and it is added
                local capture = AceGUI:Create("Button")
                capture:SetText("Use an item to add it")
                capture:SetRelativeWidth(0.4)
                capture:SetCallback("OnClick", function()
                    local ok = IU:Capture(function(name)
                        if WorkoutBuddy.triggerEditor ~= frame then return end -- editor was closed
                        if name then
                            AddItem(name)
                        else
                            frame:SetStatusText("Stopped waiting. Click \"Use an item to add it\" to try again.")
                        end
                    end, 30)
                    frame:SetStatusText(ok and "|cFFFFD700Now use the item (drink the potion, eat the food...). Waiting 30 seconds.|r"
                        or "|cFFFF5555This game client cannot watch item use.|r")
                end)
                optionsGroup:AddChild(capture)

                -- 3. Type, shift-click or drag, with suggestions from the bags
                local typed = AceGUI:Create("EditBox")
                typed:SetLabel("Or type a name (shift-click or drag an item here works too)")
                typed:SetFullWidth(true)
                typed:SetText("")
                local suggest = AceGUI:Create("SimpleGroup")
                suggest:SetFullWidth(true)
                suggest:SetLayout("Flow")
                local function ShowSuggestions(text)
                    suggest:ReleaseChildren()
                    for _, item in ipairs(IU:Suggest(text, 5)) do
                        local s = AceGUI:Create("InteractiveLabel")
                        s:SetFullWidth(true)
                        s:SetText("    |cFF66BBFF+|r " .. (item.icon and ("|T" .. item.icon .. ":14|t ") or "")
                            .. item.displayName .. " |cFF888888(in your bags, click to add)|r")
                        s:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        s:SetCallback("OnClick", function() AddItem(item.displayName) end)
                        suggest:AddChild(s)
                    end
                    suggest:DoLayout()
                    optionsGroup:DoLayout()
                    frame:DoLayout()
                end
                typed:SetCallback("OnTextChanged", function(_, _, v) ShowSuggestions(v) end)
                typed:SetCallback("OnEnterPressed", function(_, _, v)
                    if IU.CleanName(v) ~= "" then AddItem(v) end -- Add button, Enter, or a dragged item
                end)
                optionsGroup:AddChild(typed)
                optionsGroup:AddChild(suggest)
            end
        end

        if t.action == "fixed" then
            local first = WorkoutBuddy.db.profile.workouts[1]
            t.workout = t.workout or { name = first and first.name or "Push-ups",
                amount = first and first.amount or 3, unit = first and first.unit or "reps" }

            local heading = AceGUI:Create("Heading")
            heading:SetText("Workout to add each time")
            heading:SetFullWidth(true)
            optionsGroup:AddChild(heading)

            local wName = AceGUI:Create("EditBox")
            local wAmount = AceGUI:Create("EditBox")
            local wUnit = AceGUI:Create("EditBox")

            local pick = AceGUI:Create("Dropdown")
            pick:SetLabel("Pick from your list")
            local list, order = {}, {}
            for i, w in ipairs(WorkoutBuddy.db.profile.workouts) do
                list[i] = w.name .. ((w.unit and w.unit ~= "") and (" (" .. w.unit .. ")") or "")
                order[#order + 1] = i
            end
            pick:SetList(list, order)
            pick:SetFullWidth(true)
            pick:SetCallback("OnValueChanged", function(_, _, i)
                local w = WorkoutBuddy.db.profile.workouts[i]
                if not w then return end
                t.workout = { name = w.name, amount = t.workout.amount, unit = w.unit or "" }
                wName:SetText(t.workout.name)
                wUnit:SetText(t.workout.unit)
            end)
            optionsGroup:AddChild(pick)

            wName:SetLabel("Workout")
            wName:SetWidth(200)
            wName:DisableButton(true)
            wName:SetText(t.workout.name or "")
            wName:SetCallback("OnTextChanged", function(_, _, v) t.workout.name = v end)
            optionsGroup:AddChild(wName)

            wAmount:SetLabel("Amount")
            wAmount:SetWidth(80)
            wAmount:DisableButton(true)
            wAmount:SetText(tostring(t.workout.amount or ""))
            wAmount:SetCallback("OnTextChanged", function(_, _, v) t.workout.amount = tonumber(v) end)
            optionsGroup:AddChild(wAmount)

            wUnit:SetLabel("Unit")
            wUnit:SetWidth(100)
            wUnit:DisableButton(true)
            wUnit:SetText(t.workout.unit or "")
            wUnit:SetCallback("OnTextChanged", function(_, _, v) t.workout.unit = v end)
            optionsGroup:AddChild(wUnit)

            local note = AceGUI:Create("Label")
            note:SetFullWidth(true)
            note:SetText("|cFF888888Every time counts: ten potions at 3 push-ups add one row of Push-ups x30.|r")
            optionsGroup:AddChild(note)
        end

        if t.event == "UNIT_HEALTH" then
            local unit = AceGUI:Create("Dropdown")
            unit:SetLabel("Unit")
            unit:SetList({ player = "Player", target = "Target", focus = "Focus", pet = "Pet" },
                { "player", "target", "focus", "pet" })
            unit:SetValue(t.options.unit or "player")
            unit:SetWidth(120)
            unit:SetCallback("OnValueChanged", function(_, _, v) t.options.unit = v end)

            local op = AceGUI:Create("Dropdown")
            op:SetLabel("Health is")
            op:SetList({ ["<"] = "below", ["<="] = "at or below", [">"] = "above", [">="] = "at or above",
                ["=="] = "exactly", ["~="] = "not" }, { "<", "<=", ">", ">=", "==", "~=" })
            op:SetValue(t.options.op or "<")
            op:SetWidth(120)
            op:SetCallback("OnValueChanged", function(_, _, v) t.options.op = v end)

            local val = AceGUI:Create("EditBox")
            val:SetLabel("Percent")
            val:SetWidth(80)
            val:DisableButton(true)
            val:SetText(tostring(t.options.value or "50"))
            val:SetCallback("OnTextChanged", function(_, _, v) t.options.value = tonumber(v) end)

            optionsGroup:AddChild(unit)
            optionsGroup:AddChild(op)
            optionsGroup:AddChild(val)
        elseif t.event == "PLAYER_UPDATE_RESTING" then
            local rest = AceGUI:Create("Dropdown")
            rest:SetLabel("Fire when")
            rest:SetList({ resting = "Entering a rest area", active = "Leaving a rest area" }, { "resting", "active" })
            rest:SetValue(t.options.state or "resting")
            t.options.state = t.options.state or "resting"
            rest:SetWidth(200)
            rest:SetCallback("OnValueChanged", function(_, _, v) t.options.state = v end)
            optionsGroup:AddChild(rest)
        end
        optionsGroup:DoLayout()
        frame:DoLayout()
    end

    local function SetCategory(cat)
        local list, order = {}, TM.EventCategories[cat] or {}
        for _, evt in ipairs(order) do list[evt] = evt end
        eventDrop:SetList(list, order)
    end

    -- Initial state
    local startEvent = CurrentEvent() or "PLAYER_LEVEL_UP"
    local startCat = TM.CategoryOf(startEvent)
    local inCatalog = false
    for _, evt in ipairs(TM.EventCategories[startCat] or {}) do
        if evt == startEvent then inCatalog = true break end
    end
    if inCatalog and t.event ~= "CUSTOM" then
        catDrop:SetValue(startCat)
        SetCategory(startCat)
        eventDrop:SetValue(startEvent)
    else
        customEvent:SetText(startEvent)
        t.event, t.customEvent = "CUSTOM", startEvent
    end
    BuildEventOptions()

    actionDrop:SetCallback("OnValueChanged", function(_, _, val)
        t.action = val
        BuildEventOptions()
    end)

    catDrop:SetCallback("OnValueChanged", function(_, _, cat)
        SetCategory(cat)
        local first = (TM.EventCategories[cat] or {})[1]
        eventDrop:SetValue(first)
        t.event, t.customEvent = first, nil
        customEvent:SetText("")
        BuildEventOptions()
    end)
    eventDrop:SetCallback("OnValueChanged", function(_, _, evt)
        t.event, t.customEvent = evt, nil
        customEvent:SetText("")
        BuildEventOptions()
    end)
    eventDrop:SetCallback("OnEnter", function(widget)
        local evt = widget:GetValue()
        if not evt then return end
        GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(evt, 1, 1, 1, 1)
        local tip = WorkoutBuddy.EventHelp[evt]
        if tip then GameTooltip:AddLine(tip, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    eventDrop:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    customEvent:SetCallback("OnTextChanged", function(_, _, val)
        val = strtrim(string.upper(val or ""))
        if val == "" then return end
        t.event, t.customEvent = "CUSTOM", val
        catDrop:SetValue(nil)
        eventDrop:SetValue(nil)
    end)
    customEvent:SetCallback("OnEnterPressed", function() BuildEventOptions() end)

    save:SetCallback("OnClick", function()
        local evt = CurrentEvent()
        if not TM.IsTriggerEventValid(evt) then
            frame:SetStatusText("|cFFFF5555'" .. tostring(evt) .. "' is not an event this game client knows.|r")
            return
        end
        -- A catalog event typed by hand is stored as a normal event
        if t.event == "CUSTOM" then
            for _, known in ipairs(TM.EventCategories[TM.CategoryOf(evt)] or {}) do
                if known == evt then
                    t.event, t.customEvent = evt, nil
                    break
                end
            end
        end
        if t.event == TM.ITEM_USED and (t.options.preset or "named") == "named"
            and #WorkoutBuddy.ItemUse.ParseNames(t.options.items) == 0 then
            frame:SetStatusText("|cFFFF5555Name at least one item or spell, or pick a preset.|r")
            return
        end
        if t.action == "fixed" then
            t.workout = WorkoutBuddy.CleanSetWorkout(t.workout)
            if not t.workout then
                frame:SetStatusText("|cFFFF5555Enter the workout to add each time.|r")
                return
            end
        else
            t.workout = nil
        end
        if t.custom and strtrim(t.custom) == "" then t.custom = nil end
        if t.custom then
            local ok, err = loadstring(t.custom)
            if not ok then
                frame:SetStatusText("|cFFFF5555Condition error: " .. tostring(err) .. "|r")
                return
            end
        end
        t.imported = nil
        t._lastPass = nil
        t.name = strtrim(t.name or "")
        if t.name == "" and t.event == TM.ITEM_USED then
            -- Name it after what it counts, e.g. "Major Mana Potion" or "Any potion"
            local preset = t.options.preset or "named"
            t.name = preset == "named" and table.concat(WorkoutBuddy.ItemUse.NameList(t.options.items), ", ")
                or WorkoutBuddy.ItemUse.PRESET_LABELS[preset] or ""
        end

        if original then
            wipe(original)
            for k, v in pairs(t) do original[k] = v end
        else
            table.insert(triggers, t)
        end
        TM:Reset()
        self:RebuildCustomEventToggles()
        self:NotifyConfigChanged()
        frame:Hide()
    end)
end
