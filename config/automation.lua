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
        trigger = { name = "", event = "PLAYER_LEVEL_UP", action = action or "workout", enabled = true, options = {} }
    end

    if self.triggerEditor then
        AceGUI:Release(self.triggerEditor)
        self.triggerEditor = nil
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Event Trigger")
    frame:SetWidth(420)
    frame:SetHeight(300)
    frame:EnableResize(false)
    frame:SetLayout("List")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        if save then
            AceGUI:Release(save)
        end
        self.triggerEditor = nil
    end)
    self.triggerEditor = frame
    -- Use default layout spacing
    if frame.content then
        frame.content:ClearAllPoints()
        frame.content:SetPoint("TOPLEFT", 17, -27)
        frame.content:SetPoint("BOTTOMRIGHT", -17, 40)
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
    eventDrop:SetWidth(380)
    frame:AddChild(eventDrop)

    local optionsGroup = AceGUI:Create("SimpleGroup")
    optionsGroup:SetFullWidth(true)
    optionsGroup:SetLayout("Flow")
    frame:AddChild(optionsGroup)



    local save = AceGUI:Create("Button")
    save:SetText("Save")
    save:SetWidth(80)
    frame:AddChild(save)
    save.frame:SetParent(frame.frame)
    save.frame:ClearAllPoints()
    -- Anchor Save beside the window's close button
    save.frame:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", -50, -6)
    -- Remove from layout so reflows don't reposition it
    for i, child in ipairs(frame.children) do
        if child == save then
            table.remove(frame.children, i)
            break
        end
    end

    -- Internal helpers
    local function buildEventOptions(evt)
        optionsGroup:ReleaseChildren()
        local link = "https://wowpedia.fandom.com/wiki/" .. evt
        local info = AceGUI:Create("InteractiveLabel")
        info:SetFullWidth(true)
        info:SetText("More info: "..link)
        info:SetCallback("OnClick", function() WorkoutBuddy:CopyToClipboard(link) end)
        optionsGroup:AddChild(info)

        if evt == "UNIT_HEALTH" then
            local unit = AceGUI:Create("Dropdown")
            unit:SetLabel("Unit")
            unit:SetList({player="Player", target="Target", focus="Focus", pet="Pet"})
            unit:SetValue(trigger.options.unit or "player")
            unit:SetWidth(120)
            unit:SetCallback("OnValueChanged", function(_,_,v) trigger.options.unit = v end)

            local op = AceGUI:Create("Dropdown")
            op:SetLabel("Operator")
            op:SetList({["<"]="<", ["<="]="<=", [">"]=">", [">="]=">=", ["=="]="==", ["~="]="~="})
            op:SetValue(trigger.options.op or "<")
            op:SetWidth(80)
            op:SetCallback("OnValueChanged", function(_,_,v) trigger.options.op = v end)

            local val = AceGUI:Create("EditBox")
            val:SetLabel("Value (%)")
            val:SetWidth(80)
            val:SetText(trigger.options.value or "50")
            val:SetCallback("OnTextChanged", function(_,_,v) trigger.options.value = v end)

            optionsGroup:AddChild(unit)
            optionsGroup:AddChild(op)
            optionsGroup:AddChild(val)
        elseif evt == "PLAYER_UPDATE_RESTING" then
            local rest = AceGUI:Create("Dropdown")
            rest:SetLabel("State")
            rest:SetList({resting="Resting", active="Not Resting"})
            rest:SetValue(trigger.options.state or "resting")
            rest:SetWidth(150)
            rest:SetCallback("OnValueChanged", function(_,_,v) trigger.options.state = v end)
            optionsGroup:AddChild(rest)
        end
    end

    local function updateFields(val)
        buildEventOptions(val)
        frame:DoLayout()
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
        GameTooltip:SetOwner(eventDrop.dropdown, "ANCHOR_RIGHT")
        GameTooltip:SetText(evt, 1, 1, 1)
        if tip then
            GameTooltip:AddLine(tip, nil, nil, nil, true)
        end
        GameTooltip:AddLine("Click to copy link", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    eventDrop:SetCallback("OnEnter", showEventTip)
    eventDrop:SetCallback("OnLeave", GameTooltip_Hide)

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
    -- Buttons sit above the frame's status bar
end
