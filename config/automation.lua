-- config/automation.lua
-- Editor window for custom triggers.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local AceGUI = LibStub("AceGUI-3.0")

local WIKI = "https://warcraft.wiki.gg/wiki/"

local ACTIONS = { workout = "Suggest a workout", open_frame = "Open the workout window" }
local ACTION_ORDER = { "workout", "open_frame" }

--- Open the trigger editor.
-- @param action string "workout" or "open_frame" for a new trigger
-- @param index  number index of an existing trigger to edit, or nil
function WorkoutBuddy:OpenTriggerEditor(action, index)
    local TM = self.TriggerManager
    TM:BuildCatalog()

    local triggers = self.db.profile.triggers
    local original = index and triggers[index]
    local t = original and CopyTable(original)
        or { name = "", event = "PLAYER_LEVEL_UP", action = action or "workout", enabled = true, options = {} }
    t.options = type(t.options) == "table" and t.options or {}
    t._lastPass = nil

    if self.triggerEditor then
        self.triggerEditor:Hide() -- releases the old window via OnClose
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(original and "Edit Trigger" or "New Trigger")
    frame:SetStatusText("Pick a game event, then choose what happens when it fires.")
    frame:SetWidth(480)
    frame:SetHeight(600)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget)
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
    actionDrop:SetValue(t.action == "open_frame" and "open_frame" or "workout")
    actionDrop:SetRelativeWidth(0.6)
    actionDrop:SetCallback("OnValueChanged", function(_, _, val) t.action = val end)
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
        info:SetText((help and ("|cFFFFFFFF" .. help .. "|r\n") or "") ..
            "|cFF66BBFFClick for the event's wiki link|r")
        info:SetCallback("OnClick", function() WorkoutBuddy:CopyToClipboard(WIKI .. evt) end)
        optionsGroup:AddChild(info)

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
        if not WorkoutBuddy.IsEventValid(evt) then
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
