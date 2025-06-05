local AceGUI = LibStub("AceGUI-3.0")

-- Show the trigger editor for creating or editing custom events.
-- @param action string "workout" or "open_frame" when creating new triggers
-- @param index  number existing trigger index to edit (nil to create new)
function WorkoutBuddy:OpenTriggerEditor(action, index)
    local triggers = self.db.profile.triggers
    local trigger
    local isNew = not index
    if index then
        trigger = triggers[index]
        action = trigger.action
    else
        trigger = { name = "", event = "PLAYER_LEVEL_UP", customEvent = "", custom = "", action = action or "workout", enabled = true }
    end

    if self.triggerEditor then
        AceGUI:Release(self.triggerEditor)
        self.triggerEditor = nil
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Custom Event")
    frame:SetWidth(400)
    frame:SetHeight(260)
    frame:EnableResize(false)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        self.triggerEditor = nil
    end)
    self.triggerEditor = frame

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel("Name")
    nameBox:SetFullWidth(true)
    nameBox:SetText(trigger.name or "")
    nameBox:SetCallback("OnTextChanged", function(_, _, val) trigger.name = val end)
    frame:AddChild(nameBox)

    local eventDrop = AceGUI:Create("Dropdown")
    eventDrop:SetLabel("Event")
    eventDrop:SetList(self.TriggerManager.EventList)
    eventDrop:SetValue(trigger.event)
    eventDrop:SetFullWidth(true)
    frame:AddChild(eventDrop)

    local customEvent = AceGUI:Create("EditBox")
    customEvent:SetLabel("Custom Event Name")
    customEvent:SetFullWidth(true)
    customEvent:SetText(trigger.customEvent or "")
    frame:AddChild(customEvent)

    local luaBox = AceGUI:Create("MultiLineEditBox")
    luaBox:SetLabel("Lua Condition (return true/false)")
    luaBox:SetNumLines(4)
    luaBox:SetFullWidth(true)
    luaBox:SetText(trigger.custom or "")
    frame:AddChild(luaBox)

    local save = AceGUI:Create("Button")
    save:SetText("Save")
    save:SetWidth(120)
    frame:AddChild(save)

    local close = AceGUI:Create("Button")
    close:SetText("Close")
    close:SetWidth(120)
    frame:AddChild(close)

    -- Internal helpers
    local function updateFields(val)
        customEvent:SetDisabled(val ~= "CUSTOM")
    end
    updateFields(trigger.event)

    eventDrop:SetCallback("OnValueChanged", function(_, _, val)
        trigger.event = val
        updateFields(val)
    end)
    customEvent:SetCallback("OnTextChanged", function(_, _, val) trigger.customEvent = val end)
    luaBox:SetCallback("OnTextChanged", function(_, _, val) trigger.custom = val end)

    save:SetCallback("OnClick", function()
        if isNew then
            triggers[#triggers + 1] = trigger
        end
        trigger.action = action
        self.TriggerManager:RegisterEvents()
        self:RebuildCustomEventToggles()
        frame:Hide()
    end)

    close:SetCallback("OnClick", function() frame:Hide() end)
end
