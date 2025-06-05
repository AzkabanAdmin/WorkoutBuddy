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
    frame:SetWidth(420)
    frame:SetHeight(300)
    frame:EnableResize(false)
    frame:SetLayout("List")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        self.triggerEditor = nil
    end)
    self.triggerEditor = frame
    -- Use default status bar but adjust content area for our own buttons
    if frame.content then
        frame.content:ClearAllPoints()
        -- leave room for the status bar at the bottom
        frame.content:SetPoint("TOPLEFT", 17, -27)
        frame.content:SetPoint("BOTTOMRIGHT", -17, 55)
    end

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
    eventDrop:SetWidth(360)
    frame:AddChild(eventDrop)

    local customEvent = AceGUI:Create("EditBox")
    customEvent:SetLabel("Custom Event Name")
    customEvent:SetFullWidth(true)
    customEvent:SetText(trigger.customEvent or "")
    frame:AddChild(customEvent)

    local luaBox = AceGUI:Create("MultiLineEditBox")
    luaBox:SetLabel("Lua Condition (return true/false)")
    luaBox:SetNumLines(5)
    luaBox:SetFullWidth(true)
    luaBox:SetText(trigger.custom or "")
    luaBox:DisableButton(true)
    frame:AddChild(luaBox)

    local save = AceGUI:Create("Button")
    save:SetText("Save")
    save:SetWidth(100)

    local closeBtn = AceGUI:Create("Button")
    closeBtn:SetText("Close")
    closeBtn:SetWidth(100)

    local btnGroup = AceGUI:Create("SimpleGroup")
    btnGroup:SetFullWidth(true)
    btnGroup:SetLayout("Flow")
    btnGroup:AddChild(save)
    btnGroup:AddChild(closeBtn)
    frame:AddChild(btnGroup)

    -- Internal helpers
    local function updateFields(val)
        if val == "CUSTOM" then
            customEvent.frame:Show()
        else
            customEvent.frame:Hide()
        end
    end
    updateFields(trigger.event)

    eventDrop:SetCallback("OnValueChanged", function(_, _, val)
        trigger.event = val
        updateFields(val)
    end)
    -- Tooltip showing help for selected event
    local function showEventTip()
        local evt = eventDrop:GetValue()
        local tip = WorkoutBuddy.TriggerManager.EventHelp[evt]
        if tip then
            GameTooltip:SetOwner(eventDrop.dropdown, "ANCHOR_RIGHT")
            GameTooltip:SetText(evt, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end
    eventDrop:SetCallback("OnEnter", showEventTip)
    eventDrop:SetCallback("OnLeave", GameTooltip_Hide)
    customEvent:SetCallback("OnTextChanged", function(_, _, val) trigger.customEvent = val end)
    luaBox:SetCallback("OnTextChanged", function(_, _, val) trigger.custom = val end)

    save:SetCallback("OnClick", function()
        if isNew then
            triggers[#triggers + 1] = trigger
        end
        trigger.action = action
        self.TriggerManager:RegisterEvents()
        self:RebuildCustomEventToggles()
        self:ForceFullConfigRefresh()
        frame:Hide()
    end)
    closeBtn:SetCallback("OnClick", function()
        frame:Hide()
    end)

    -- Buttons sit above the frame's status bar
end
